-- 3D context for the UI: lobby weapon stand and the small match set (Workspace.PivotStage).
-- Client only. Drives the camera (Scriptable), the equipped weapon on the lobby stand, the first-person
-- viewmodel, the target figure and the spectator views. It is a visual stage, not a shooter: hits are
-- decided by the match simulation and the stage only reacts to them.

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local PivotUI = game:GetService("ReplicatedStorage"):WaitForChild("PivotUI")
local Util = require(PivotUI.Util)
local Catalog = require(PivotUI.Data.Catalog)
local WeaponView = require(PivotUI.WeaponView)
local Theme = require(PivotUI.Theme)

local Stage = {}

local STAGE = workspace:WaitForChild("PivotStage")
local LOBBY = STAGE:WaitForChild("Lobby")
local ARENA = STAGE:WaitForChild("Arena")
local MARKS = ARENA:WaitForChild("Marks")

local camera = workspace.CurrentCamera

local function setCamera(cf: CFrame, fov: number)
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cf
	camera.FieldOfView = fov
end

-- Graphics quality (functional setting): low turns off shadows, bloom and the distant set dressing.
function Stage.applyQuality(quality: string)
	local low = quality == "low"
	Lighting.GlobalShadows = not low
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = quality == "high"
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Density = low and 0.18 or 0.32
	end
	for _, d in ARENA:GetChildren() do
		if d.Name == "Tower" or d.Name == "Crane" then
			for _, p in (d:IsA("Model") and d:GetDescendants() or { d }) do
				if p:IsA("BasePart") then
					p.LocalTransparencyModifier = low and 1 or 0
				end
			end
		end
	end
end

local function menuBlur(on: boolean)
	local dof = Lighting:FindFirstChild("PivotMenuDOF")
	if dof then
		dof.Enabled = on
	end
end

---------------------------------------------------------------- lobby stand
-- Shows the equipped primary weapon (with its finish) on the stand behind the lobby UI.
-- Returns a controller with refresh(itemId, finishId), focus("left" | "center") and show(visible).
function Stage.lobby(scope)
	local mount = LOBBY:WaitForChild("WeaponMount")
	local camMark = LOBBY:WaitForChild("LobbyCam")
	setCamera(camMark.CFrame, 50)
	menuBlur(true)
	local current, currentId, currentFinish
	local shown = true
	local yaw = 0.5
	local ctl = {}
	local shift = 0 -- lateral camera offset so the weapon sits in the free part of the layout
	local targetShift = 0
	function ctl.refresh(itemId: string, finishId: string?)
		if itemId == currentId and finishId == currentFinish and current then
			return
		end
		if itemId == currentId and current then
			currentFinish = finishId
			WeaponView.applyFinish(current, finishId)
			return
		end
		if current then
			current:Destroy()
		end
		currentId, currentFinish = itemId, finishId
		local item = Catalog.get(itemId)
		current = WeaponView.model(item)
		if not current then
			return
		end
		WeaponView.applyFinish(current, finishId)
		local _, size = current:GetBoundingBox()
		current:ScaleTo(math.clamp(4.6 / math.max(size.X, 0.1), 1, 3))
		current.Parent = shown and LOBBY or nil
	end
	function ctl.focus(where: string)
		targetShift = where == "left" and 2.6 or (where == "right" and -2.6 or 0)
	end
	-- full-panel tabs hide the weapon and soften the room (3D only; BlurEffect never touches the UI),
	-- so no slice of the weapon or crisp line of the set shows through the gaps between panels
	local panelBlur = Lighting:FindFirstChild("PivotPanelBlur") or Instance.new("BlurEffect")
	panelBlur.Name = "PivotPanelBlur"
	panelBlur.Size = 0
	panelBlur.Parent = Lighting
	function ctl.show(visible: boolean)
		shown = visible
		if current then
			current.Parent = visible and LOBBY or nil
		end
		Util.tween(panelBlur, 0.25, { Size = visible and 0 or 14 })
	end
	local drop = 0
	scope:connect(RunService.RenderStepped, function(dt)
		if not Util.reducedMotion then
			yaw += dt * 0.32
		else
			yaw = 0.5
		end
		shift += (targetShift - shift) * math.min(1, dt * 6)
		if current then
			drop = math.max(0, drop - dt)
			local bob = Util.reducedMotion and 0 or math.sin(os.clock() * 1.3) * 0.06
			current:PivotTo(mount.CFrame * CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, math.rad(-4)))
		end
		camera.CFrame = camMark.CFrame * CFrame.new(shift, 0, 0)
	end)
	scope:add(function()
		if current then
			current:Destroy()
		end
		panelBlur.Size = 0
		menuBlur(false)
	end)
	return ctl
end

---------------------------------------------------------------- match stage
local VIEW_OFFSET = {
	rifle = CFrame.new(1.05, -1.05, -2.35),
	shotgun = CFrame.new(1.1, -1.05, -2.6),
	smg = CFrame.new(0.95, -0.95, -2.1),
	dmr = CFrame.new(1.1, -1.05, -2.7),
	pistol = CFrame.new(0.85, -0.8, -1.7),
}

local function setTeamColor(model: Model, color: Color3)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Team") then
			p.Color = color
		end
	end
end

--[[ Stage.match(scope, opts) -> controller
	opts: mode, finishes, palette ("default" | "colorblind")
	controller.update(m, look, settings): called every frame with the match state
	controller.onEvent(ev): reacts to engine events (hit, kill, shot, retarget, switch, death, respawn) ]]
function Stage.match(scope, opts)
	menuBlur(false)
	local training = opts.mode == "training"
	local camMark = MARKS:WaitForChild(training and "RangeCam" or "MatchCam")
	local palette = Theme.teamPalettes[opts.palette or "default"]
	setCamera(camMark.CFrame, 80)
	local figures = {}
	local function makeFigure(team: string)
		local f = PivotUI.Assets.Figure:Clone()
		setTeamColor(f, team == "enemy" and palette.enemy:Lerp(Color3.new(0, 0, 0), 0.25) or palette.ally:Lerp(Color3.new(0, 0, 0), 0.3))
		f.Parent = ARENA
		table.insert(figures, f)
		return f
	end
	local targetMarks = { MARKS.TargetA, MARKS.TargetB, MARKS.TargetC, MARKS.TargetD }
	local targetIndex = 1
	local target = not training and makeFigure("enemy") or nil
	local ally = not training and makeFigure("ally") or nil
	if ally then
		ally:PivotTo(CFrame.new(0, -100, 0))
	end
	local boards = training and { ARENA.RangeLane.Target1, ARENA.RangeLane.Target2, ARENA.RangeLane.Target3 } or nil
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = target or (boards and boards[1]) or ARENA
	scope:add(highlight)

	local targetCF = target and targetMarks[1].CFrame * CFrame.Angles(0, math.rad(180), 0) or nil
	local fallT = nil -- seconds since the kill (figure falls), nil when standing
	local hitT = 99
	local function placeTarget()
		if not target then
			return
		end
		targetIndex = targetIndex % #targetMarks + 1
		local mark = targetMarks[targetIndex]
		-- face the camera
		local pos = mark.Position
		local look = Vector3.new(camMark.Position.X, pos.Y, camMark.Position.Z)
		targetCF = CFrame.lookAt(pos, look)
	end
	if target then
		placeTarget()
		target:PivotTo(targetCF)
	end

	-- viewmodel
	local view, viewWeapon, viewFinish
	local muzzle = Instance.new("Part")
	muzzle.Name = "PivotMuzzle"
	muzzle.Anchored = true
	muzzle.CanCollide = false
	muzzle.CanQuery = false
	muzzle.CastShadow = false
	muzzle.Material = Enum.Material.Neon
	muzzle.Color = Color3.fromHex("#FFC27A")
	muzzle.Size = Vector3.new(0.25, 0.25, 0.25)
	muzzle.Shape = Enum.PartType.Ball
	muzzle.Transparency = 1
	muzzle.Parent = ARENA
	local flash = Instance.new("PointLight")
	flash.Color = Color3.fromHex("#FFB060")
	flash.Range = 10
	flash.Brightness = 0
	flash.Parent = muzzle
	scope:add(muzzle)
	local muzzleT, recoil, switchT, viewLength = 99, 0, 99, 2

	local function setView(weaponId: string, finishId: string?)
		if weaponId == viewWeapon and finishId == viewFinish then
			return
		end
		if view then
			view:Destroy()
			view = nil
		end
		viewWeapon, viewFinish = weaponId, finishId
		local item = Catalog.get(weaponId)
		view = WeaponView.model(item)
		if view then
			WeaponView.applyFinish(view, finishId)
			local _, size = view:GetBoundingBox()
			viewLength = size.X
			view.Parent = camera
		end
	end

	local ctl = {}
	function ctl.onEvent(ev)
		if ev.kind == "shot" then
			muzzleT = 0
			recoil = math.min(1, recoil + 0.55)
		elseif ev.kind == "hit" then
			hitT = 0
		elseif ev.kind == "kill" then
			if target then
				fallT = 0
			end
		elseif ev.kind == "retarget" then
			-- next target appears after the fall animation
			if target then
				task.delay(0.7, function()
					if target and target.Parent then
						fallT = nil
						placeTarget()
					end
				end)
			end
		elseif ev.kind == "switch" or ev.kind == "respawn" then
			switchT = 0
		end
	end

	local t0 = os.clock()
	function ctl.update(m, look, settings, dt)
		camera = workspace.CurrentCamera
		local fov = settings.graphics.fov
		if m.aiming then
			fov *= 0.72
		end
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 12)
		local sens = settings.controls.sensitivity
		local inv = settings.controls.invertY and -1 or 1
		local spectating = m.spectate ~= nil
		local base
		if spectating then
			local names = { "SpectateA", "SpectateB", "SpectateC" }
			base = MARKS[names[(m.spectate - 1) % 3 + 1]].CFrame
		else
			base = camMark.CFrame
		end
		local yaw = -look.X * math.rad(5) * sens
		local pitch = -look.Y * math.rad(3.5) * sens * inv
		local shake = 0
		if settings.accessibility.screenShake and not Util.reducedMotion then
			shake = recoil * 0.004
		end
		local dead = not m.me.alive and not spectating
		local deathTilt = dead and CFrame.Angles(math.rad(-8), 0, math.rad(6)) * CFrame.new(0, -1.2, 0) or CFrame.identity
		camera.CFrame = base * deathTilt * CFrame.Angles(pitch + shake, yaw, 0)

		-- target figure
		hitT += dt
		highlight.FillTransparency = hitT < 0.09 and 0.35 or 1
		if target then
			local cur = target:GetPivot()
			if fallT then
				fallT += dt
				local p = math.min(1, fallT / 0.45)
				target:PivotTo(targetCF * CFrame.Angles(math.rad(-82) * p * p, 0, 0))
			else
				local sway = Util.reducedMotion and 0 or math.sin((os.clock() - t0) * 0.9) * 1.2
				local goal = targetCF * CFrame.new(sway, 0, 0)
				target:PivotTo(cur:Lerp(goal, math.min(1, dt * 5)))
			end
			target:SetAttribute("Hidden", m.phase == "intro")
		end
		if ally then
			if spectating then
				ally:PivotTo(camera.CFrame * CFrame.new(1.6, -5.3, -7) * CFrame.Angles(0, math.rad(180), 0))
			else
				ally:PivotTo(CFrame.new(0, -100, 0))
			end
		end

		-- viewmodel
		local slot = m.slots[m.active]
		setView(slot.weapon, m.finishes[slot.weapon])
		if view then
			local item = Catalog.get(slot.weapon)
			local visible = m.me.alive and not spectating
			recoil = math.max(0, recoil - dt * 6)
			switchT += dt
			muzzleT += dt
			local off = VIEW_OFFSET[item.class] or VIEW_OFFSET.rifle
			if m.aiming then
				off = CFrame.new(0, -0.62, off.Position.Z * 0.92)
			end
			local sw = math.clamp(1 - switchT / 0.45, 0, 1)
			local reloadTilt = 0
			if m.reload then
				local p = (m.t - m.reload.start) / math.max(0.01, m.reload.untilT - m.reload.start)
				reloadTilt = math.sin(math.clamp(p, 0, 1) * math.pi) * math.rad(28)
			end
			local bob = (Util.reducedMotion and 0 or math.sin(os.clock() * 2) * 0.02)
			local cf = camera.CFrame * off
				* CFrame.new(look.X * 0.05, -sw * 1.4 + bob - look.Y * 0.03, recoil * 0.18)
				* CFrame.Angles(recoil * math.rad(4) + reloadTilt, 0, -reloadTilt * 0.6)
				* CFrame.Angles(0, math.rad(90), 0)
			view:PivotTo(visible and cf or CFrame.new(0, -100, 0))
			local muzzleOn = visible and muzzleT < 0.05
			muzzle.CFrame = cf * CFrame.new(viewLength * 0.52, 0.08, 0)
			muzzle.Transparency = muzzleOn and 0.1 or 1
			flash.Brightness = muzzleOn and 3 or 0
		end
	end

	scope:add(function()
		if view then
			view:Destroy()
		end
		for _, f in figures do
			f:Destroy()
		end
	end)
	return ctl
end

-- Static camera on the arena (results backdrop).
function Stage.results()
	menuBlur(true)
	local camMark = MARKS:WaitForChild("MatchCam")
	setCamera(camMark.CFrame * CFrame.new(3, 7, 16) * CFrame.Angles(math.rad(-6), math.rad(8), 0), 60)
end

-- Cover shot: the dock at dusk from a raised angle (crane, containers, skyline).
function Stage.title()
	menuBlur(false)
	local base = MARKS:WaitForChild("MatchCam").CFrame
	setCamera(base * CFrame.new(10, 9, 22) * CFrame.Angles(math.rad(-9), math.rad(14), 0), 62)
end

return Stage
