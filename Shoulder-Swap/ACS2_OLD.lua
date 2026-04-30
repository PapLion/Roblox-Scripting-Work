local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Running
local ArmaTool
local ArmaClone
local Offset

local GuiModule = require(script:WaitForChild("GUI"))
local CrossHairModule = require(script:WaitForChild("CrossHair"))
local ShellEjectionModule = require(script:WaitForChild("ShellEjection"))
local FireSoundsModule = require(script:WaitForChild("FireSounds"))
local SpringsModule = require(script:WaitForChild("Springs"))
local BoltModule = require(script:WaitForChild("MoveBolt"))
local tweenFoV = require(script:WaitForChild("FOV")).Tween
local newTracer = require(script:WaitForChild("Tracer")).New
local LaserModule = require(script:WaitForChild("Laser"))
local WhizzModule = require(script:WaitForChild("Whizz"))

local RStorage = game:GetService("ReplicatedStorage")
local Engine = RStorage:WaitForChild("ACS_Engine")

local Mod = Engine:WaitForChild("Modulos")
local Evt = Engine:WaitForChild("Eventos")

local PastaHUD = Engine:WaitForChild("HUD")
local PastaFX = Engine:WaitForChild("FX")
local GunMods = Engine:WaitForChild("GunMods")
local GunModelClient = Engine:WaitForChild("GunModels"):WaitForChild("Client")

local Utils = require(Mod:WaitForChild("Utilities"))
local AnimFunctions = require(Mod:WaitForChild("Animation"):WaitForChild("AnimFunctions"))
local SetupMod = require(Mod:WaitForChild("SetupModule"))
local Hitmarker = require(Mod:WaitForChild("Hitmarker"))
local SpringMod = require(Mod:WaitForChild("Spring"))
local ProjectileModule = require(Mod:WaitForChild("Projectile"))
local Lighting = game:GetService("Lighting")
local GunBlur = Lighting:WaitForChild("GunBlur")
local AimBlur = Lighting:WaitForChild("AimBlur")
local supress11 = Lighting:WaitForChild("supblur")
local supress1 = Lighting:WaitForChild("Supcc")

local debugtp, debugp
do
	local debugs = script:WaitForChild("Debugs")
	debugtp = debugs.DebugTP
	debugp = debugs.DebugPrint
end
function dprint(str)
	if debugp.Value then
		print(str)
	end
end

function InvertTable(ot)
	local nt = {}
	for key, value in pairs(ot) do
		nt[value] = key
	end
	return nt
end





-- server config require
local ServerConfig = require(Engine.ServerConfigs:WaitForChild("Config"))
local Keybinds = InvertTable(ServerConfig.Keybinds)
local KeybindsGP = InvertTable(ServerConfig.KeybindsGP)
local RecoilCF = CFrame.new()

function GetSpringModule()
	local rec = Engine.Modulos.SpringModules:FindFirstChild(ServerConfig.SpringModule)
	if not rec then
		rec = Engine.Modulos.SpringModules.Default
	end
	return require(rec)
end

-- [SHOULDER SWAP]
local SHOULDER_SWAP_KEY = string.lower(ServerConfig.ShoulderSwapKey or "i")
local SHOULDER_SWAP_COOLDOWN = ServerConfig.ShoulderSwapCooldown or 0.2
local SHOULDER_LERP_SPEED = ServerConfig.ShoulderSwapLerpSpeed or 0.2

ShoulderSide = "right"
shoulderSwapTrack = nil
lastShoulderSwap = 0
shoulderOffsetCurrent = ServerConfig.ShoulderOffsetStuds or 0.22
shoulderOffsetTarget = shoulderOffsetCurrent
shoulderCameraOffsetCurrent = ServerConfig.ShoulderCameraOffsetX or 0.12
shoulderCameraOffsetTarget = shoulderCameraOffsetCurrent

function GetShoulderOffsetCF()
	return CFrame.new(shoulderOffsetCurrent, 0, 0)
end

function UpdateShoulderOffset(adjust)
	local alpha = math.min(1, SHOULDER_LERP_SPEED * adjust)
	shoulderOffsetCurrent = shoulderOffsetCurrent + (shoulderOffsetTarget - shoulderOffsetCurrent) * alpha
	shoulderCameraOffsetCurrent = shoulderCameraOffsetCurrent + (shoulderCameraOffsetTarget - shoulderCameraOffsetCurrent) * alpha
end

function PlayShoulderSwapAnim(targetSide)
	if not Equipped or not Humanoid then
		return
	end

	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local animId
	if targetSide == "left" then
		animId = ServerConfig.ShoulderSwapAnimRightToLeft
	else
		animId = ServerConfig.ShoulderSwapAnimLeftToRight
	end

	if type(animId) ~= "string" or animId == "" then
		return
	end

	if shoulderSwapTrack then
		shoulderSwapTrack:Stop(0.05)
		shoulderSwapTrack:Destroy()
		shoulderSwapTrack = nil
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	shoulderSwapTrack = animator:LoadAnimation(anim)
	shoulderSwapTrack:Play(0.08, 1, 1)
	anim:Destroy()
end

function SwapShoulder()
	if not Equipped then
		return
	end

	local now = tick()
	if now - lastShoulderSwap < SHOULDER_SWAP_COOLDOWN then
		return
	end
	lastShoulderSwap = now

	if ShoulderSide == "right" then
		ShoulderSide = "left"
		shoulderOffsetTarget = -(ServerConfig.ShoulderOffsetStuds or 0.22)
		shoulderCameraOffsetTarget = -(ServerConfig.ShoulderCameraOffsetX or 0.12)
	else
		ShoulderSide = "right"
		shoulderOffsetTarget = ServerConfig.ShoulderOffsetStuds or 0.22
		shoulderCameraOffsetTarget = ServerConfig.ShoulderCameraOffsetX or 0.12
	end

	PlayShoulderSwapAnim(ShoulderSide)
end
-- [/SHOULDER SWAP]





------------------------------------------

-- list of part names that could be for silencer
local SilencerNames = {
	"Supressor",
	"",
	"Silencer",
	"Silenciador",
}

-------------------------------

function FindSilencer(model)
	for _,name in pairs(SilencerNames) do
		local found = model:FindFirstChild(name)
		if found then
			return found
		end
	end
	return nil
end




--------- WALK SWAY CONSTANTS -----------
BipodReduction = .7

local WVal = 0
local WValBounds = {
	s = .1,		-- standing target
	w = .8,		-- walking target
	sl = .01,	-- standing lerp below threshold
	rl = .05,	-- standing lerp above threshold
	wl = .2,	-- walking lerp
	wb = .2,	-- when standing, threshold to reach before switch to sl lerp
}











ACS_Storage = workspace:WaitForChild("ACS_WorkSpace")

function GetRecoilModule()
	local rec = Engine.Modulos.RecoilModules:FindFirstChild(ServerConfig.RecoilModule)
	if not rec then
		rec = Engine.Modulos.RecoilModules["Default"]
		warn("Didn't find recoil module specified in Server Config, using default")
	end
	return require(rec)
end

local RecoilModule = GetRecoilModule()

local Var
local Settings
local Anims

local TweenService = game:GetService('TweenService')
local RunService = game:GetService("RunService")	
local UIS = game:GetService("UserInputService")
local CS = game:GetService("CollectionService")



local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera
local ToolEquip = false
local Equipped = false
local Swimming = false
local Saude = Character:WaitForChild("Saude")
local Sprinting = Saude:WaitForChild("Stances"):WaitForChild("Correndo")
local StancesVal = Saude:WaitForChild("Stances"):WaitForChild("Stances")

local Spread = require(script.SpreadModule)
local Ammo,StoredAmmo,GLAmmo
local FireRate,BurstFireRate
local Chambered,GLChambered,Emperrado
local Sens,Zeroing
local BSpeed


local DecreasedAimLastShot = false
local LastSpreadUpdate = time()

local AimPartMode = 1
local SpeedPrecision = 0

local falling = false
local OverHeat = false 
local Slideback
local Can_Shoot = true
local Can_Adjust = true
local Safe = false
local AnimDebounce = false
local CancelReload = false
local MouseHeld, BlindFire, RMBHeld
local BipodExists = false

local PlaceHolder = true

local ModStorageFolder = LocalPlayer.PlayerGui:FindFirstChild('ModStorage') or Instance.new('Folder')
ModStorageFolder.Parent = LocalPlayer.PlayerGui
ModStorageFolder.Name = 'ModStorage'

---Start Blizzard Compat Variable Define-----

local GetBlizzardDamageGroup
local HeliHitEvent
if RStorage:FindFirstChild("WeaponFrameworkRep") then
	local Modules = RStorage.WeaponFrameworkRep:FindFirstChild("Modules")
	if Modules and Modules:FindFirstChild("GetBlizzardDamageGroup") then
		GetBlizzardDamageGroup = require(Modules.GetBlizzardDamageGroup) -- RStorage.WeaponFrameworkRep.Modules.GetBlizzardDamageGroup
		HeliHitEvent = RStorage.ACS_Engine.Eventos.BlizzardCompat.HeliHit
	else
		warn("Failed to get Blizzard Damage Group module script, not implementing ACS Blizzard Compatibility")
	end
end

---End Blizzard Compat Variable Define------


---Start Blizzard Compat Variable Define-----

local GetStrikerDamageGroup
local TankHitEvent
if RStorage:FindFirstChild("WeaponFrameworkRep") then
	local Modules = RStorage.WeaponFrameworkRep:FindFirstChild("Modules")
	if Modules and Modules:FindFirstChild("GetStrikerDamageGroup") then
		GetStrikerDamageGroup = require(Modules.GetStrikerDamageGroup)
		TankHitEvent = RStorage.ACS_Engine.Eventos.StrikerCompat.TankHit
	else
		warn("Failed to get Striker Damage Group module script, not implementing ACS Striker Compatibility")
	end
end

---End Blizzard Compat Variable Define------





local Aiming = false
local Reloading = false
local stance = 0
AimBlur.Enabled = false
NVG = false
Bipod = false
CanPlaceBipod = false
CanDeployBipod = false
Silencer = false
IronSights = false
FlashlightEnabled = false

LaserEnabled = false
IRmode = false

local Laser
local Pointer
local LaserLight
local PointerBG
local PointerBGC
local LaserSP
local LaserEP
LaserDist = 999

local Left_Arm, Right_Arm, RAW, LAW
local RUA, LUA, RLAW, LLAW, RHW, LHW
local AnimBase, AnimBaseW, ViewModel, Clone

--// Gun Parts



local V2n, V3n = Vector2.new, Vector3.new



--------------------[ TIME FUNCTIONS ]------------------------------------------------

function Throttle(step) -- streamlined lag throttle function
	local c = 0
	repeat
		if step < (c+2)/60 then
			return c
		end
		c = c + 1
	until c > 5
	return c
end

local OldTick = tick()
local t = 0
local WalkRate = 10 -- 10
local aimoffsetthing = V2n() -- when you turn left/right your gun points left/right of the camera direction, this variable enables this to happen
local offsetrecoil = V2n()

local Walking = false
local wasd = {
	w = false;
	a = false;
	s = false;
	d = false;
}

















local Waval = CFrame.new()
local CloneC1V2



local offsetAim = Instance.new('Part')

--// Char Parts
Humanoid = Character:WaitForChild('Humanoid')
Head = Character:WaitForChild('Head')
Torso = Character:WaitForChild('UpperTorso')
HumanoidRootPart = Character:WaitForChild('HumanoidRootPart')
Neck = Head:WaitForChild('Neck')
if Humanoid.RigType == Enum.HumanoidRigType.R15 then
	CharArmParts = {
		LeftUpperArm = Character:FindFirstChild("LeftUpperArm"),

		LeftLowerArm = Character:FindFirstChild("LeftLowerArm"),
		LeftHand = Character:FindFirstChild("LeftHand"),
		RightUpperArm = Character:FindFirstChild("RightUpperArm"),
		RightLowerArm = Character:FindFirstChild("RightLowerArm"),
		RightHand = Character:FindFirstChild("RightHand")
	}
else
	CharArmParts = {
		LeftArm = Character:FindFirstChild("Left Arm"),
		RightArm = Character:FindFirstChild("Right Arm")
	}
end
Debris = game:GetService("Debris")

WorkspaceServerFolder = ACS_Storage:FindFirstChild("Server")
WorkspaceClientFolder = ACS_Storage:FindFirstChild("Client")

local Ray_Ignore = {Character, WorkspaceServerFolder, Camera, WorkspaceClientFolder}
local Laser_Ignore = {Character, WorkspaceServerFolder, Camera, WorkspaceClientFolder}
local Ray_Ignore_2 = {WorkspaceServerFolder, Camera, WorkspaceClientFolder, ACS_Storage, Character}

if script:FindFirstChild("Ignore") then
	for i, v in pairs(script.Ignore:GetChildren()) do
		table.insert(Ray_Ignore,v.Value)
		table.insert(Laser_Ignore,v.Value)
		table.insert(Ray_Ignore_2,v.Value)
	end
end

local BaseParams = RaycastParams.new()
BaseParams.FilterType = Enum.RaycastFilterType.Exclude
BaseParams.IgnoreWater = true
BaseParams.FilterDescendantsInstances = Ray_Ignore

Evt.AcessId:FireServer(LocalPlayer.UserId)
local Id = Evt.AcessId.OnClientEvent:Wait()

Camera.CameraType = Enum.CameraType.Custom
Camera.CameraSubject = Humanoid



-- ignore part list
local IgnoreAccessoriesList = Utils.ArrayToDict({
	"Ignorable", -- IGNORABLE
	"Top",
	"Helmet",
	"Up",
	"Down",
	"Face",
	"Olho",
	"Headset",
	"HeadCollision",
	"Numero",
	"Vest",
	"Chest",
	"Back",
	"Belt",
	"Leg1", "Leg2",
	"Arm1", "Arm2",
	"FakeWindow", -- using fake windows with glass material solid parts
}, true)

local IgnoreList = IgnoreAccessoriesList

local HeadAccessoriesList = Utils.ArrayToDict({
	"Top",
	"Helmet",
	"Face",
	"Olho",
	"Headset",
	"Numero",
}, true)

local TorsoAccessoriesList = Utils.ArrayToDict({
	"Chest",
	"Vest",
	"Waist",
	"Belt",
	"Back",
}, true)

local LimbsAccessoriesList = Utils.ArrayToDict({
	"Leg1",
	"Leg2",
	"Arm1",
	"Arm2",
}, true)

local TorsoList = Utils.ArrayToDict({
	"UpperTorso",
	"LowerTorso",
	"Torso",
	--"HumanoidRootPart",
}, true)

local LimbsList = Utils.ArrayToDict({
	"LeftFoot",
	"LeftLowerLeg",
	"LeftUpperLeg",
	"RightFoot",
	"RightLowerLeg",
	"RightUpperLeg",
	"LeftHand",
	"LeftLowerArm",
	"LeftUpperArm",
	"RightHand",
	"RightLowerArm",
	"RightUpperArm",

	"Right Arm",
	"Left Arm",
	"Right Leg",
	"Left Leg",
}, true)

local IgnoreNonCollide = Utils.ArrayToDict({
	"EShield",
	"Armor",
	"Head",
}, true)





local SeatsDisableArma = {
	DriverSeat = false,
}

function CheckSeated(Seat)
	return Seat and (SeatsDisableArma[Seat.Parent.Name] or Seat:IsA("VehicleSeat"))
end








-- ricochet locals
local RicochetEnabled = ServerConfig.RicochetEnabled
local RicochetModule = RicochetEnabled and require(script:WaitForChild("Ricochet")) or nil



-- wallbang locals
local BulletPenetration
local WallbangEnabled = ServerConfig.WallbangEnabled
local WallbangMaterialHardness, WallbangSpecialNames
if WallbangEnabled then
	WallbangMaterialHardness = ServerConfig.WallbangMaterialHardness
	WallbangSpecialNames = ServerConfig.WallbangSpecialNames
end
local HeadBase = Camera:FindFirstChild("HeadBase")
if not HeadBase then -- every time you die headbase is still there
	HeadBase = Instance.new("Part")
	HeadBase.Name = "HeadBase"
	HeadBase.Anchored = true
	HeadBase.CanCollide = false
	HeadBase.Transparency = 1
	HeadBase.Size = Vector3.new(0.1, 0.1, 0.1)
	HeadBase.Parent = Camera

	local HeadBaseAtt = Instance.new('Attachment')
	HeadBaseAtt.Parent = HeadBase
end




local StatusClone = GuiModule.GetClone()



if ServerConfig.EnableGPS then
	GPSUI = PastaHUD:WaitForChild("GPShud"):Clone()
	GPSUI.Parent = LocalPlayer.PlayerGui
	GPSUI.GPS.Disabled = false
end

local AttachmentsFolder
do
	local Terrain = workspace:FindFirstChildOfClass("Terrain")
	if not Terrain then
		error("oho no terrain")
	else
		AttachmentsFolder = Terrain:FindFirstChild("ACS_Attachments")
		if not AttachmentsFolder then
			local AttachmentsFolder = Instance.new("Attachment")
			AttachmentsFolder.Name = "ACS_Attachments"
			AttachmentsFolder.Parent = Terrain
		end
	end
end

function ResetWorkspace()
	WorkspaceServerFolder:ClearAllChildren()
	WorkspaceClientFolder:ClearAllChildren()
	AttachmentsFolder:ClearAllChildren()
end

ResetWorkspace()



function ConvertHitToCF(HitPart: BasePart, Pos: Vector3, Norm: Vector3, Dir: Vector3?): CFrame
	local cfw = CFrame.new(Pos, Pos + Norm)
	local off = (HitPart == workspace.Terrain) and cfw or HitPart.CFrame:Inverse() * cfw


	if Dir then
		local ang2 = Norm:Angle(Dir.Unit) - math.pi / 2 -- angle between norm and incoming bullet

		local dir2 = CFrame.fromAxisAngle(Norm:Cross(Dir), -ang2) * Dir -- I don't know how I did this, but it works when you need to flatten a vector to a plane

		local ang = cfw.UpVector:Angle(dir2.Unit, Norm) -- measure angle between bullet hole up-direction and impact direction

		off = off * CFrame.fromAxisAngle(-Vector3.zAxis, ang) -- weird rotation axis, also works.... using offset CFrame (relative only to part, NOT WORLD)
	else
		off = off * CFrame.fromAxisAngle(-Vector3.zAxis, Utils.RANDF(-math.pi, math.pi))
	end

	return off
end

function HitEffect(Ray_Ignore, Position, HitPart, Normal, Material, Settings, BulletPower, HitType)
	local Off = ConvertHitToCF(HitPart, Position, Normal)
	task.defer(function()
		Hitmarker.HitEffect(Ray_Ignore, HitPart, Off, Material, Settings, BulletPower, HitType)
	end)
end

Evt.Hit.OnClientEvent:Connect(function(Player, Position, HitPart, Normal, Material, Settings)
	if Player ~= LocalPlayer then
		local Off = ConvertHitToCF(HitPart, Position, Normal)
		Hitmarker.HitEffect(Ray_Ignore, HitPart, Off, Material, Settings or {}, 1)
	end
end)

Evt.Hit2.OnClientEvent:Connect(function(Player, HitPart, Off, Material, Settings, BulletPower, HitType)
	if Player ~= LocalPlayer then
		Hitmarker.HitEffect(Ray_Ignore, HitPart, Off, Material, Settings, BulletPower, HitType)
	end
end)



------------------------------------------------------------
--\Death Sounds
------------------------------------------------------------

local DeadS = script.Parent.Parent.HumanoidRootPart:WaitForChild("Died")
DeadS.SoundId = "rbxassetid://".. ServerConfig.DeathSoundID

-- single shot
function MuzzleFX(source,light,flash,rate,emit)
	if source then
		for _, v in pairs(source:GetChildren()) do

			if v:IsA("Motor6D") then
				
			
			 elseif Settings.FlashChance and math.random(1,10) <= Settings.FlashChance then 		 
				if  flash and v:IsA("ParticleEmitter")  then -- flash fx
					if emit then
						v:Emit(math.ceil(v.Rate * rate)) 
					else
						v.Enabled = true
						end
		
				elseif light and v:IsA("Light") then -- light fx
					v.Enabled = true
				end
			elseif string.sub(v.Name, 1, 5) == "Smoke" and v:IsA("ParticleEmitter") then
				if emit then
					v:Emit(math.ceil(v.Rate * rate))
				else
					v.Enabled = true
					if not Settings.FlashChance then --some yanderedev type shit but it works and im sleep deprived so stfu
						
						
				if source then
					for _, v in pairs(source:GetChildren()) do

						if v:IsA("Motor6D") then

						elseif string.sub(v.Name, 1, 7) == "FlashFX" then
							if  flash and v:IsA("ParticleEmitter")  then -- flash fx
								if emit then
									v:Emit(math.ceil(v.Rate * rate)) 
								else
									v.Enabled = true
								end

							elseif light and v:IsA("Light") then -- light fx
								v.Enabled = true
							end
						elseif string.sub(v.Name, 1, 5) == "Smoke" and v:IsA("ParticleEmitter") then
							if emit then
								v:Emit(math.ceil(v.Rate * rate))
							else
								v.Enabled = true
							end
						end
					end
				end
			end
			end
	end
	end
end
	end


function StopMuzzleFX(source)
	for _, v in pairs(source:GetChildren()) do
		if v:IsA("Motor6D") then -- don't disable
		elseif (string.sub(v.Name, 1, 7) == "FlashFX" or string.sub(v.Name, 1, 5) == "Smoke") and (v:IsA("Light") or v:IsA("ParticleEmitter")) then
			v.Enabled = false
		end
	end
end

function GunGrip(char)
	return char:WaitForChild("S"..ArmaTool.Name):WaitForChild("Grip")
end



-- settings find/fallback fucntion
function fallback(module,attr,fallback)
	local val = module[attr]
	if not val then
		val = fallback
	end
	return val
end

function fbFolder(folder,attr,instance,fallback)
	local val = folder:FindFirstChild(attr)
	if not val then
		val = Instance.new(instance)
		val.Name = attr
		val.Value = fallback
		val.Parent = folder
	end
	return val
end


-- fallback anims

fbAnims = require(Mod.Animation.DefaultAnims)





Evt.Atirar.OnClientEvent:Connect(function(Player, ArmaName, dur, objs)

	if Player == LocalPlayer and not debugtp.Value or not Player.Character then
		return
	end
	local PlHumanoid = Player.Character:FindFirstChild("Humanoid")
	if not PlHumanoid or PlHumanoid.Health <= 0 then
		return
	end

	local S_Arma = Player.Character:FindFirstChild("S" .. ArmaName)
	if not S_Arma then
		return
	end

	local Counter = S_Arma.Grip:FindFirstChild("Counter")
	if not Counter then
		Counter = Instance.new("IntValue")
		Counter.Name = "Counter"
		Counter.Parent = S_Arma.Grip
	end

	Counter.Value = Counter.Value + 1

	if not dur then
		dur = ServerConfig.MuzzleFXDelay
	end
	
	local emit = ((S_Arma.Grip.Position - Character.Head.Position).Magnitude > 200)

	local sourcepart = S_Arma:FindFirstChild("SmokePart") or S_Arma.Grip:FindFirstChild("Muzzle")
	-- if there is a sourcepart to base from (not applicable without muzzle attachment or smokepart)
	if sourcepart then
		local foundsilencer = FindSilencer(Player.Character['S' .. ArmaName])
		if foundsilencer and foundsilencer.Transparency == 0 then
			local silmuzzle = sourcepart:FindFirstChild("Silencer")
			if silmuzzle then
				MuzzleFX(silmuzzle,true,true,dur,emit) -- why light and flash = true: allow freedom for the dev
			else
				MuzzleFX(sourcepart,false,false,dur,emit)
			end
		else
			MuzzleFX(sourcepart,true,true,dur,emit)
		end
	else
		warn("Did not find any serverside Muzzle FX source part from gun: " .. ArmaName)
		warn("Check the server model of the gun for any 'Muzzle' attachment in Grip or a 'SmokePart' part.")
	end

	local chamber = S_Arma:FindFirstChild("Chamber") or S_Arma.Grip:FindFirstChild("Chamber")
	if chamber then
		MuzzleFX(chamber,true,true,dur,emit)
	end

	-- this is supposed to stop the muzzle fx going off prematurely
	-- now that everything else is done through emit - it's mostly the light to worry about
	task.delay(dur, function()
		Counter.Value = Counter.Value - 1
		if Counter.Value == 0 then
			if sourcepart then
				StopMuzzleFX(sourcepart)
				local silmuzzle = sourcepart:FindFirstChild("Silencer")
				if silmuzzle then
					StopMuzzleFX(silmuzzle)
				end
			end
			if chamber then
				StopMuzzleFX(chamber)
			end
		end
	end)

	if objs then
		for key, val in pairs(FireSoundsModule.DecodeSoundString(objs)) do
			local Sound = S_Arma.Grip:FindFirstChild(key)
			if key then
				task.spawn(FireSoundsModule.SV_FireSound, Player, "Layered", Sound, S_Arma.Grip.Position, val)
			end
		end
	end
end)













function SettingsProfile(profilename, foldername, fallback)
	local prname = Settings[profilename]
	if not prname then return end
	
	local folder = Engine.Templates:FindFirstChild(foldername)
	if not folder then return end
		
	local profile = folder:FindFirstChild(prname)
	local fbprofile = (fallback ~= nil) and folder:FindFirstChild(fallback)
	
	if profile then
		for key, value in pairs(require(profile)) do
			if not Settings[key] then
				Settings[key] = value
			end
		end
	end
	
	if fbprofile then
		for key, value in pairs(require(fbprofile)) do
			if not Settings[key] then
				Settings[key] = value
			end
		end
	end
end

---- GUN SETUP FUNCTION ----

function Setup(Tool)
	dprint("Setup new gun: "..Tool.Name)
	local Torso = Character:FindFirstChild('UpperTorso')
	local Head = Character:FindFirstChild('Head')
	local HumanoidRootPart = Character:FindFirstChild('HumanoidRootPart')

	if not (Torso and Head and HumanoidRootPart) then
		return
	end

	ArmaTool = Tool
	local ClientModel = GunModelClient:FindFirstChild(ArmaTool.Name)

	if not ClientModel then
		warn("Can't find client gun model for '"..ArmaTool.Name.."' in ACS_Engine/GunModels/Client. Make sure there is a model of the same name as tool in the Client folder.")
		Unset()
		return
	end

	ArmaClone = ClientModel:Clone()
	Var = Tool.ACS_Modulo.Variaveis
	Settings = require(Var:WaitForChild("Settings"))
	Anims = require(Var:WaitForChild("Animations"))
	
	local rcname = Settings.RecoilProfile
	if rcname then
		local profile = Engine.Templates.RecoilProfiles:FindFirstChild(rcname)
		if profile then
			for key, value in pairs(require(profile)) do
				if not Settings[key] then
					Settings[key] = value
				end
			end
		end
	end
	
	SettingsProfile("RecoilProfile", "RecoilProfiles")
	SettingsProfile("TracerProfile", "TracerProfiles", "Default")
	
	
	
	
	Silencer = fbFolder(Var,"Suppressor","BoolValue",false)
	Slideback = fbFolder(Var,"Slideback","BoolValue",false)

	OffsetAngle = Settings.OffsetAngle or ServerConfig.OffsetAngle
	OffsetSens = Settings.OffsetSens or ServerConfig.OffsetSens
	
	CanADS = Settings.CanADS or ServerConfig.CanADS
	IronSights = Settings.IronSights or ServerConfig.IronSights
	
	Spread.Setup(Settings)
	CrossHairModule.Setup(Settings, Spread.BSpread, ArmaClone, HeadBase)

	-- special fallback
	local SC_DamageableObjects = ServerConfig.DamageableObjects
	if ServerConfig.ForceDamageableObjectsFallback then
		if Settings.DamageableObjects then
			for obj, value in pairs(SC_DamageableObjects) do
				if not Settings.DamageableObjects[obj] then
					Settings.DamageableObjects[obj] = value
				end
			end
		else
			Settings.DamageableObjects = SC_DamageableObjects
		end
	else
		if not Settings.DamageableObjects then
			Settings.DamageableObjects = SC_DamageableObjects
		end
	end

	FireRate = 60 / Settings.FireRate
	BurstFireRate = 60 / Settings.BurstFireRate

	Sens, Zeroing = Var.Sens, Var.Zeroing
	Ammo, StoredAmmo = Var.Ammo, Var.StoredAmmo
	Chambered, Emperrado = Var.Chambered, Var.Emperrado
	
	if ServerConfig.PresetSens then
		local DefaultSens = Sens:FindFirstChild("Default")
		
		if DefaultSens then
			Sens.Value = DefaultSens.Value
			
		else
			DefaultSens = Instance.new("NumberValue")
			DefaultSens.Value = Sens.Value
			DefaultSens.Parent = Sens
		end
	end

	FireSoundsModule.Setup(Var, Shootable, Settings, ArmaClone.Name, FireRate)
	SpringsModule.Setup(Settings)

	BipodExists = (ArmaClone:FindFirstChild("BipodPoint") ~= nil)
	
	

	BSpeed = Settings.BSpeed
	GLAmmo = fbFolder(Var, "LauncherAmmo", "NumberValue", 0)
	GLChambered = fbFolder(Var, "GLChambered", "BoolValue", false)

	-- setup - wallbang
	if WallbangEnabled then
		BulletPenetration = ServerConfig.WallbangBulletIndex[Settings.BulletType]
		if not BulletPenetration then
			BulletPenetration = Settings.WallbangPenetration or 35 * ServerConfig.WallbangConstant / math.max(100 - Settings.BulletPenetration, 1)
		end
	end



	Evt.Equipar:FireServer(ArmaTool)

	ViewModel = Instance.new("Model")
	ViewModel.Name = Tool.Name

	-- setup AnimBase part (used to view the gun viewmodel) placed inside camera
	AnimBase = Instance.new("Part")
	AnimBase.FormFactor = "Custom"
	AnimBase.CanCollide = false
	AnimBase.Transparency = 1
	AnimBase.Anchored = true
	AnimBase.Name = "AnimBase"
	AnimBase.Size = Vector3.new(0.1, 0.1, 0.1)
	
	AnimBase.Parent = ViewModel

	--AnimBaseW = Instance.new("Motor6D")
	--AnimBaseW.Part0 = AnimBase
	--AnimBaseW.Part1 = HeadBase
	--AnimBaseW.Parent = AnimBase
	--AnimBaseW.Name = "AnimBaseW"
	AnimBase.Anchored = false

	Clone = Instance.new('Motor6D')
	Clone.Name = 'Clone'
	Clone.Parent = AnimBase
	Clone.Part0 = AnimBase
	Clone.Part1 = HeadBase

	ArmaClone.Parent = ViewModel
	ViewModel.Parent = Camera


	-- gun parts welding
	local handle = ArmaClone:WaitForChild("Handle")
	
	local LidHinge = ArmaClone:FindFirstChild("LidHinge")
	local BoltHinge = ArmaClone:FindFirstChild("BoltHinge")
	if Settings.RigWeld then -- all welds have C1 as component part and C0 as root part (every normal part will have handle as Part0)
		for _, Part in pairs(ArmaClone:GetChildren()) do
			if not Part:IsA("BasePart") or Part.Name == "Handle" then
				-- do nothing
			elseif BoltHinge and Part.Name == "Bolt" then
				Utils.WeldComplex(BoltHinge, Part, handle)
			elseif LidHinge and Part.Name == "Lid" then
				Utils.Weld(LidHinge, Part, Part)
			elseif Part:FindFirstChild("HingeMotor") then
				local hinge = Part.HingeMotor.Value
				Part.HingeMotor:Destroy()
				Utils.Weld(hinge, Part, Part)
			else
				Utils.WeldComplex(handle, Part, handle)
			end
		end
	else
		for _, Part in pairs(ArmaClone:GetChildren()) do
			if not Part:IsA("BasePart") or Part.Name == "Handle" then
				-- do nothing
			elseif LidHinge and Part.Name == "Lid" then
				Utils.Weld(Part, LidHinge, Part)
			elseif Part:FindFirstChild("HingeMotor") then
				local hinge = Part.HingeMotor.Value
				Part.HingeMotor:Destroy()
				Utils.Weld(Part, hinge, Part)
			else
				Utils.Weld(Part, handle, Part)
			end
		end
	end

	for _, Part in pairs(ArmaClone:GetChildren()) do
		if Part:IsA('BasePart') then
			Part.Anchored = false
			Part.CanCollide = false
		end
	end
	LoadClientMods()
	RAW, LAW, Right_Arm, Left_Arm, AnimBase, AnimBaseW, RUA, LUA, RLAW, LLAW, RHW, LHW = SetupMod(ViewModel, Utils, Character, RAW, LAW, Right_Arm, Left_Arm, AnimBase, AnimBaseW, Settings, ArmaClone, RUA, LUA, RLAW, LLAW, RHW, LHW)
	Equipped = true
	
	-- [SHOULDER SWAP]
	ShoulderSide = "right"
	lastShoulderSwap = 0
	shoulderOffsetCurrent = ServerConfig.ShoulderOffsetStuds or 0.22
	shoulderOffsetTarget = shoulderOffsetCurrent
	shoulderCameraOffsetCurrent = ServerConfig.ShoulderCameraOffsetX or 0.12
	shoulderCameraOffsetTarget = shoulderCameraOffsetCurrent
	-- [/SHOULDER SWAP]

	local sil = FindSilencer(ArmaClone)
	if sil then
		if Silencer.Value then
			sil.Transparency = 0
		else
			sil.Transparency = 1
		end
		Evt.SilencerEquip:FireServer(ArmaTool, Silencer.Value)
	end

	BoltModule.Setup(handle, Settings, Emperrado.Value, Chambered.Value, Slideback.Value)
	
	dprint("Setup Finished: " .. Tool.Name)
end
function Update_Gui()
	GuiModule.Update_Gui(ArmaClone, Settings,
		Utils.MakeVarDict(Ammo, StoredAmmo, Chambered, Emperrado, Sens, Zeroing, Silencer, GLAmmo, GLChambered),
		{Safe = Safe, LaserEnabled = LaserEnabled, IRmode = IRmode, FlashlightEnabled = FlashlightEnabled}
	)
end

function Unset()
	dprint("Unset Started")
	if Equipped then
		FireSoundsModule.StopLoops(true)
	end

	if ArmaTool then
		Evt.Desequipar:FireServer(ArmaTool, Utils.MakeVarDict(StoredAmmo, Ammo, Chambered, Emperrado, GLChambered))
	end
	UnloadClientMods()

	if ViewModel then
		ViewModel:Destroy()
	end
	Equipped = false
	Aiming = false
	AimBlur.Enabled = false
	Safe = false
	Bipod = false
	FlashlightEnabled = false
	
	CancelReload = false
	Reloading = false
	OverHeat = false
	
	UIS.MouseIconEnabled = true
	UIS.MouseDeltaSensitivity = 1
	
	Camera.CameraType = Enum.CameraType.Custom
	LocalPlayer.CameraMode = Enum.CameraMode.Classic
	
	AimPartMode = 1
	stance = 0
	AimBlur.Enabled = false
	tweenFoV(70, 15)
	TweenService:Create(StatusClone.Efeitos.Aim,TweenInfo.new(.3),{ImageTransparency = 1}):Play()
	
	IRmode = false
	LaserEnabled = false
	Evt.SVLaser:FireServer(Vector3.new(0,0,0),2,nil,ArmaTool,IRmode)
	
	GuiModule.UnsetGui()
	
	CrossHairModule.Unset()
	FireSoundsModule.Unset()
	SpringsModule.Unset()
	WVal = 0

	BlindFire = false
	for _,key in pairs(CharArmParts) do
		key.LocalTransparencyModifier = 0
	end
	
	-- [SHOULDER SWAP]
	ShoulderSide = "right"
	lastShoulderSwap = 0
	shoulderOffsetCurrent = 0
	shoulderOffsetTarget = 0
	shoulderCameraOffsetCurrent = 0
	shoulderCameraOffsetTarget = 0
	if Humanoid then
		local cameraOffset = Humanoid.CameraOffset
		Humanoid.CameraOffset = Vector3.new(0, cameraOffset.Y, cameraOffset.Z)
	end
	if shoulderSwapTrack then
		shoulderSwapTrack:Stop(0)
		shoulderSwapTrack:Destroy()
		shoulderSwapTrack = nil
	end
	-- [/SHOULDER SWAP]
	
	dprint("Unset Finished")
end

do
	for i, model in pairs(Camera:GetChildren()) do
		if model:IsA("Model") then
			local model2 = model:FindFirstChild(model.Name)
			if model2 and model2:FindFirstChild("Handle") then
				model:Destroy() -- destroy remaining acs viewmodel
			end
		end
	end
end
local StGui = game:GetService("StarterGui")
StGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,true)


	
-- Adjust ADS Mesh / REG Mesh function
function DoAdsMesh(trans)
	for _,v in pairs(ArmaClone:GetDescendants()) do
		if v:IsA("BasePart") then
			if v.Name == "REG" then
				if trans == 0 and v:FindFirstChild("Trans") then
					TweenService:Create(v, TweenInfo.new(.1), {Transparency = v.Trans.Value}):Play()
				else
					TweenService:Create(v, TweenInfo.new(.1), {Transparency = trans}):Play()
				end

			elseif v.Name == "ADS" then
				if trans == 1 and v:FindFirstChild("Trans") then
					TweenService:Create(v, TweenInfo.new(.1), {Transparency = v.Trans.Value}):Play()
				else
					TweenService:Create(v, TweenInfo.new(.1), {Transparency = 1 - trans}):Play()
				end
			end
		end
	end
end

function CFF(value)
	return value or CFrame.new()
end

function EvtStancePoses()
	return AnimFunctions.EvtStancePose(stance, Settings, Anims)
end

function Sprint()
	if Equipped then
		if Running and SpeedPrecision > 0 then
			MouseHeld = false
			if Aiming then
				
				UIS.MouseDeltaSensitivity = 1
				ArmaClone.Handle.AimUp:Play()	
				tweenFoV(70,120)
				Aiming = false
				AimBlur.Enabled = false
				CallAimFunction()

				if Settings.adsMesh1 or Settings.adsMesh2 then
					DoAdsMesh(0)
				end
				TweenService:Create(StatusClone.Efeitos.Aim,TweenInfo.new(.3),{ImageTransparency = 1}):Play()
			end

			if (stance > -1 and stance < 4 and stance ~= 1) and not AnimDebounce then -- if stance: Idle (0), Aimed (2), Running (3)
				stance = 3
				Evt.Stance:FireServer(EvtStancePoses())
				SprintAnim()
			end
		elseif not Running or SpeedPrecision == 0 then
			if not Safe and not AnimDebounce then
				if Aiming then
					stance = 2
				else
					stance = 0
					
					AimBlur.Enabled = false
				end
				Evt.Stance:FireServer(EvtStancePoses())
				IdleAnim()
			end
		end
	end
end

Sprinting.Changed:Connect(function(Valor)
	Running = Valor
	Sprint()
end)

function AimObstructed()
	if Aiming then
		UIS.MouseDeltaSensitivity = 1
		ArmaClone.Handle.AimUp:Play()	
		tweenFoV(70,120)
		Aiming = false
		AimBlur.Enabled = false
		if Settings.adsMesh1 or Settings.adsMesh2 then
			DoAdsMesh(0)
		end

		TweenService:Create(StatusClone.Efeitos.Aim,TweenInfo.new(.3),{ImageTransparency = 1}):Play()
	end
end


---------------------[ TWEEN MODULE ]-------------------------------------------------

function Lerp(n,g,t) -- lerp from n to g with t as lerping value
	return n+(g-n)*t
end

local BindedModFunctions: {RBXScriptConnection} = {}
local ActionFunctions = {Aim = {}}

function CallAimFunction()
	for _, func in ipairs(ActionFunctions.Aim) do
		func(Aiming, AimPartMode, Settings)
	end
end

function LoadClientMods()
	for _, Mod in ipairs(GunMods:GetChildren()) do
		if Mod:IsA("LocalScript") then
			local ModClone = Mod:clone()
			ModClone.Parent = ModStorageFolder
			ModClone.Disabled = false
			
		elseif Mod:IsA("ModuleScript") then
			local Module = require(Mod)
			Module.Setup(ArmaClone, ArmaTool, Settings)
			
			if Module.OnRenderStepped then
				local con = RunService.RenderStepped:Connect(Module.OnRenderStepped)
				table.insert(BindedModFunctions, con)
			end
			
			if Module.OnHeartbeat then
				local con = RunService.Heartbeat:Connect(Module.OnHeartbeat)
				table.insert(BindedModFunctions, con)
			end
			
			if Module.OnAim then
				table.insert(ActionFunctions.Aim, Module.OnAim)
			end
		end
	end
end

function UnloadClientMods()
	for _, Mod in ipairs(ModStorageFolder:GetChildren()) do
		if Mod:IsA("LocalScript") then
			Mod:Destroy()
			
		elseif Mod:IsA("ModuleScript") then
			local Module = require(Mod)
			if Module.Unset then
				Module.Unset()
			end
		end
	end
	
	for _, con in ipairs(BindedModFunctions) do
		con:Disconnect()
	end
	
	for name, array in pairs(ActionFunctions) do
		table.clear(array)
	end
end

function CheckForHumanoid(hit)
	local human = false
	local humanoid = nil
	pcall(function()
		if hit then
			if hit.Parent then
				if hit.Parent:FindFirstChildOfClass('Humanoid') then
					humanoid = hit.Parent:FindFirstChildOfClass('Humanoid')
					human = true
				elseif hit.Parent.Parent:FindFirstChildOfClass('Humanoid') then
					humanoid = hit.Parent.Parent:FindFirstChildOfClass('Humanoid')
					human = true
				end
			end
		end
	end)
	return human, humanoid
end

local Tracers = 1
function TracerCalculation()
	local VisibleTracer
	if Settings.RandomTracer then
		VisibleTracer = (math.random(1, 100) <= Settings.TracerChance)
	else
		Tracers = (Tracers + 1) % Settings.TracerEveryXShots
		VisibleTracer = (Tracers == 0)
	end
	
	local LTR = Settings.LastTracerRounds
	local FTR = Settings.FirstTracerRounds
	if LTR and LTR > Ammo.Value or FTR and Ammo.Value > Settings.Ammo - FTR then
		VisibleTracer = true
	end
	
	return VisibleTracer
end

function CreateRainbowColor()
	if Settings.RainbowMode or ServerConfig.ForceRainbowMode then
		return Color3.new(math.random(), math.random(), math.random())
	end
	return nil
end

local BulletIDCounter = 0

local Asin = math.asin
local CFNew, CFAng = CFrame.new, CFrame.Angles
local HalfStep = false
function HeadMovement()
	if _G.Lean or not Character:FindFirstChild("HumanoidRootPart") or not Character:FindFirstChild("Humanoid") or Player.Character:FindFirstChild("Customizing") or Character.Humanoid.Health <= 0 then return; end;
	if not Saude or Saude.Stances.Caido.Value == true then return; end;
	local CameraDirection = Character.HumanoidRootPart.CFrame:toObjectSpace(Camera.CFrame).lookVector
	if Neck then
		HalfStep = not HalfStep
		local neckCFrame = CFNew(0, -.5, 0) * CFAng(0, Asin(CameraDirection.x)/1.15, 0) * CFAng(-Asin(Camera.CFrame.LookVector.y)+Asin(Character.Torso.CFrame.lookVector.Y), 0, 0) * CFAng(-math.rad(90), 0, math.rad(180))
		TweenService:Create(Neck, TweenInfo.new(.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {C1 = neckCFrame}):Play()
		if not HalfStep then return; end;
		Evt.HeadRot:FireServer(neckCFrame)
	end
end


function CreateBullet()
	
	local ID = tostring(BulletIDCounter)
	BulletIDCounter += 1

	local GravityFactor = 196.2 * Settings.BDrop

	local SmokePart = ArmaClone.SmokePart
	local SmokePartCF = SmokePart.CFrame

	local Origin = SmokePart.Position
	local Direction = SmokePartCF.lookVector
	if not Settings.FakeZeroing then
		Direction = Direction + SmokePartCF.upVector * GravityFactor * Zeroing.Value / 2 / (BSpeed * BSpeed)
	end

	local BSpreadVector = Spread.BSpread + SpeedPrecision / Saude.Stances.Mobility.Value * Settings.WalkMultiplier
	
	-- new bulletspread function, distribution biased to center
	local SpreadRadius = math.random() * BSpreadVector / 1024
	local Bulletspread = CFrame.Angles(0, 0, math.random() * math.pi * 2) * CFrame.Angles(math.atan(SpreadRadius), 0, 0)
	
	Direction = (CFrame.lookAt(V3n(), Direction) * Bulletspread).LookVector

	local RainbowModeCode = CreateRainbowColor()

	local Bullet = Engine.FX.Bullet:Clone()
	Bullet.Name = LocalPlayer.Name .. "_Bullet"
	Bullet.Transparency = 1
	Bullet.CFrame = SmokePartCF
	
	
	local TracerResult = TracerCalculation()
	if TracerResult then
		
		local TracerEnabled =  Settings.Tracer or ServerConfig.ForceEnableTracer
		local BulletLightEnabled = Settings.BulletLight or ServerConfig.ForceEnableBulletLight
		local BulletFlareEnabled = Settings.BulletFlare or ServerConfig.ForceEnableBulletFlare

		local TracerColor, BulletFlareColor, BulletLightColor

		if BulletFlareEnabled then
			BulletFlareColor = RainbowModeCode or Settings.BulletFlareColor
			
			local bg = Instance.new("BillboardGui")
			bg.Adornee = Bullet
			bg.Enabled = false

			local flashsize = Utils.RANDMR(32.5, 5)
			bg.Size = UDim2.new(flashsize, 0, flashsize, 0)
			bg.LightInfluence = 0

			local flash = Instance.new("ImageLabel")
			flash.BackgroundTransparency = 1
			flash.Size = UDim2.new(1, 0, 1, 0)
			flash.Position = UDim2.new(0, 0, 0, 0)
			flash.Image = "rbxassetid://1047066405"

			flash.ImageColor3 = RainbowModeCode or Settings.BulletFlareColor
			flash.ImageTransparency = math.random(2, 5)/15
			
			flash.Parent = bg
			bg.Parent = Bullet
			
			task.delay(Utils.RANDF(0.1, 0.2), function()
				if bg then
					bg.Enabled = true
				end
			end)
		end

		if TracerEnabled then
			TracerColor = RainbowModeCode or Settings.TracerColor
			
			task.spawn(function()
				if Settings.TracerDelay then
					task.wait(Settings.TracerDelay)
				end
				if not Bullet then return end
				newTracer(Bullet, ColorSequence.new(TracerColor), Settings.TracerWidth, Settings.TracerLifeTime, Settings.TracerLightEmission, Settings.TracerLightInfluence, Settings.FullTracer, Settings.TracerTexture)
			end)
			
		end

		if BulletLightEnabled then
			BulletLightColor = RainbowModeCode or Settings.BulletLightColor
			
			local BulletLight = Instance.new("PointLight")
			BulletLight.Brightness = Settings.BulletLightBrightness
			BulletLight.Color = BulletLightColor
			BulletLight.Range = Settings.BulletLightRange
			BulletLight.Shadows = true
			BulletLight.Parent = Bullet
		end


		if ServerConfig.ReplicatedBullets then
			local TracerExtra = TracerEnabled and {
				Full = Settings.FullTracer,
				Delay = Settings.TracerDelay,
				Life = Settings.TracerLifetime,
				LE = Settings.TracerLightEmission,
				LI = Settings.TracerLightInfluence,
				Width = Settings.TracerWidth,
				Texture = Settings.TracerTexture,
			} or {}
			local BulletLightExtra = BulletLightEnabled and {
				Brightness = Settings.BulletLightBrightness,
				Color = BulletLightColor,
				Range = Settings.BulletLightRange,
			} or {}
			
			Evt.ServerBullet:FireServer(ID, Origin, Settings.BDrop, Direction.Unit * BSpeed, Settings.Distance, TracerEnabled, TracerColor, BulletFlareEnabled, BulletFlareColor, TracerExtra, BulletLightEnabled, BulletLightExtra)
		end
	end

	Bullet.Parent = WorkspaceClientFolder
	
	local Velocity = Direction.Unit * BSpeed
	return Bullet, Origin, Velocity, Vector3.new(0, -GravityFactor, 0), ID
end





function CalcArmorDamage(hp, def, BulletPen, TravelledDamage)
	local ArmorDamage = 0
	local damage = 0
	local BulletPenInv = 100 - BulletPen

	if hp > 0 and BulletPen < def  then
		damage = TravelledDamage * BulletPen / def
		ArmorDamage = TravelledDamage * BulletPenInv / def

		if ArmorDamage <= 0 then
			ArmorDamage = 0.5
		end

	elseif hp > 0 and BulletPen >= def then
		damage = TravelledDamage
		ArmorDamage = TravelledDamage * BulletPenInv / def

		if ArmorDamage <= 0 then
			ArmorDamage = 1
		end				

	elseif hp <= 0 then
		damage = TravelledDamage

	end

	return damage, ArmorDamage
end

function CalculateDamage(DanoBase,Dist,Vitima,Type)

	local damage = 0
	local VestDamage = 0
	local HelmetDamage = 0
	local TravelledDamage = DanoBase-(math.ceil(Dist)/40)*Settings.FallOfDamage
	local VitimaSaude = Vitima.Parent:FindFirstChild("Saude")
	if VitimaSaude then
		local Protecao = VitimaSaude.Protecao

		local Vest =  Protecao.VestVida
		local Vestfactor = Protecao.VestProtect
		local Helmet = Protecao.HelmetVida
		local Helmetfactor = Protecao.HelmetProtect

		if Type == "Head" then
			damage, HelmetDamage = CalcArmorDamage(Helmet.Value, Helmetfactor.Value, Settings.BulletPenetration, TravelledDamage)
		else
			damage, VestDamage = CalcArmorDamage(Vest.Value, Vestfactor.Value, Settings.BulletPenetration, TravelledDamage)
		end

	else
		damage = TravelledDamage
	end
	damage = math.max(0, damage)
	return damage,VestDamage,HelmetDamage
end



WhizzModule.Connect()

Evt.Suppression.OnClientEvent:Connect(function(Intensity, Tempo)
	if ServerConfig.EnableStatusUI and LocalPlayer.Character and Humanoid.Health > 0 then
		local SuppressGUI = StatusClone.Efeitos.Suppress
		local SuppressFrame = StatusClone.SuppressionFrame
		local newsup = SuppressGUI:Clone()
		newsup.ImageTransparency = 1
		newsup.Parent = SuppressFrame
		local cameraShaker = require(game.ReplicatedStorage.CameraShaker)
		local camera = workspace.CurrentCamera
		local camShake = cameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
			camera.CFrame = camera.CFrame * shakeCFrame
		end)
		camShake:Start()
		camShake:ShakeOnce(.5, 9, 0, .3 * Tempo)
		TweenService:Create(newsup,TweenInfo.new(.25 ,Enum.EasingStyle.Linear,Enum.EasingDirection.In,0,false,0),{ImageTransparency = (Intensity - 1) * -1}):Play()
		print(newsup.ImageTransparency, (Intensity - 1) * -1)
		TweenService:Create(supress11,TweenInfo.new(.7),{Size = 15}):Play()
		TweenService:Create(supress1,TweenInfo.new(.2),{Contrast = .5}):Play()
		TweenService:Create(supress1,TweenInfo.new(.1),{Saturation = -.5}):Play()
		task.delay(0.25,function()
			TweenService:Create(supress11,TweenInfo.new(10),{Size = 0}):Play()
			TweenService:Create(supress1,TweenInfo.new(.1),{Contrast = 0}):Play()
			TweenService:Create(supress1,TweenInfo.new(.1),{Saturation = 0}):Play()
			TweenService:Create(newsup,TweenInfo.new(Tempo/3 ,Enum.EasingStyle.Sine,Enum.EasingDirection.In,0,false,0),{ImageTransparency = 1}):Play()
			Debris:AddItem(newsup, Tempo)
		end)
	end
end)

local RaycastAheadParams = RaycastParams.new()
RaycastAheadParams.IgnoreWater = ServerConfig.IgnoreWater
RaycastAheadParams.FilterDescendantsInstances = Ray_Ignore
RaycastAheadParams.FilterType = Enum.RaycastFilterType.Exclude

local GLRaycastAheadParams = RaycastParams.new()
GLRaycastAheadParams.IgnoreWater = ServerConfig.GLIgnoreWater
GLRaycastAheadParams.FilterDescendantsInstances = Ray_Ignore
GLRaycastAheadParams.FilterType = Enum.RaycastFilterType.Exclude

function EvtHitTable()
	local module = {
		CanBreachDoor = Settings.CanBreachDoor,
		BulletHoleSize = Settings.BulletHoleSize,
		BulletImpactEnergy = Settings.BulletImpactEnergy,
		BulletType = Settings.BulletType,
	}

	if Settings.ExplosiveHit then
		for i, v in ipairs({
			"ExplosiveHit","ExPressure","ExpRadius",
			"DestroyJointRadiusPercent","ExplosionDamagesTerrain","TerrainDamageRadius",
			"ExpSoundDistanceMult","ExpSoundVolumeMult","ExplosionDamage",}) do
			module[v] = Settings[v]
		end
	end

	return module
end

function CastRay(Bullet, Origin, Velocity, Acceleration, ID)
	debug.profilebegin("CastRay Begin")

	local Projectile = ProjectileModule.new(Origin, Velocity, Acceleration)

	local Hit, Pos, Norm, Mat
	local CurrPos = Origin
	local BulletVector
	local WallbangRay
	local BulletPower = 1


	-- CALCULATE PREVPOS (first trace) AT THE MOMENT GUN IS SHOT
	local PrevPos, OtherPos
	local sprcp = RaycastParams.new()
	sprcp.FilterDescendantsInstances = Ray_Ignore
	sprcp.FilterType = Enum.RaycastFilterType.Exclude
	sprcp.IgnoreWater = ServerConfig.IgnoreWater

	-- choose fallback origin part (position for PrevPos)
	if Aiming then
		local AimPart2 = ArmaClone:FindFirstChild("AimPart2")
		if AimPart2 and AimPartMode == 2 then
			OtherPos = AimPart2.Position
		else
			OtherPos = ArmaClone.AimPart.Position
		end
	else
		OtherPos = ArmaClone.Handle.Position
	end

	local SmokePart = ArmaClone.SmokePart
	local cast2 = workspace:Raycast(OtherPos,SmokePart.Position - OtherPos,sprcp)
	if cast2 then
		PrevPos = OtherPos
	else
		PrevPos = SmokePart.Position
	end

	
	


	local TotalDistTraveled = 0
	local recast
	local BulletStopped = false
	local WallbangParts = {}
	local RicoHappened = false
	local RicoPos = Vector3.new(0,0,0)
	local Wallbanged = false
	
	

	local HitRaycastParams = RaycastParams.new()
	HitRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	HitRaycastParams.IgnoreWater = ServerConfig.IgnoreWater

	local WallbangParams
	if WallbangEnabled then
		WallbangParams = RaycastParams.new()
		WallbangParams.FilterType = Enum.RaycastFilterType.Include
		WallbangParams.IgnoreWater = ServerConfig.IgnoreWater
	end

	debug.profileend()




	local function FindMaterial(dict,mat)
		local result = dict[mat]
		if result then
			return result
		else
			return dict["default"]
		end
	end

	local function DoRico()
		if (RicoPos - Pos).Magnitude < ServerConfig.MinRicoTravelDistance or Projectile.Velocity.Magnitude < ServerConfig.MinRicoBulletSpeed then
			BulletHit(Hit, Pos, Norm, BulletVector, Mat, TotalDistTraveled,BulletPower)
			Bullet:Destroy()
			BulletStopped = true
			return
		end

		local Angle = math.deg(math.acos(BulletVector.Unit:Dot(Norm.Unit))) - 90
		local MaxAngle = RicochetModule.GetMaxAngle(Hit, Mat)



		if Angle < MaxAngle then
			--dprint("Bullet Ricochet at angle: "..Angle)
			BulletHit(Hit, Pos, Norm, BulletVector, Mat, TotalDistTraveled, BulletPower*ServerConfig.RicoDamageMult,"Rico")
			
			local VecUnit = BulletVector.Unit
			local NewVel = Projectile.Velocity.Magnitude * (VecUnit - 2 * VecUnit:Dot(Norm) * Norm).Unit
			Bullet.CFrame = CFrame.lookAt(Pos, Pos + NewVel)
			Projectile:SetProperties(Pos, NewVel)
			BulletPower = BulletPower * (1 - RicochetModule.RicochetLoss)
			RicoPos = Pos
			PrevPos = Pos
			RicoHappened = true
			
		else
			BulletHit(Hit, Pos, Norm, BulletVector, Mat, TotalDistTraveled, BulletPower)
			Bullet:Destroy()
			BulletStopped = true
		end
	end






	local c = 0
	local Stepped = RunService.Stepped
	local RaycastThrottle = ServerConfig.RaycastThrottle

	local BulletWhiz = Settings.BulletWhiz
	local WhizzedPlayers, SplashedPlayers
	local SuppressMaxDistance, SuppressTime, SuppressIntensity, BWMaxDistance, BWEmitter, S_Arma, EnableSplashDamage, SplashDistance, SplashDamage
	if BulletWhiz then
		WhizzedPlayers = {}
		SplashedPlayers = {}
		SuppressMaxDistance = Settings.SuppressMaxDistance
		SuppressTime = Settings.SuppressTime or 10
		SuppressIntensity = Settings.SuppressIntensity or 1

		BWMaxDistance = Settings.BWMaxDistance
		BWEmitter = Settings.BWEmitter

		EnableSplashDamage = Settings.EnableSplashDamage
		if EnableSplashDamage then
			SplashDistance = Settings.SplashDistance
			SplashDamage = Settings.SplashDamage
		end
	end
	local WallbangConstant = ServerConfig.WallbangConstant

	while not BulletStopped do
		local step = Stepped:Wait()
		if RaycastThrottle then
			if c == 0 then
				c = Throttle(step)
			else
				c = c - 1
			end
		end

		if c == 0 then
			if not Bullet then
				return
			end
			CurrPos = Projectile.Position
			BulletVector = CurrPos - PrevPos
			Bullet.CFrame = CFrame.lookAt(CurrPos, CurrPos + BulletVector)

			TotalDistTraveled = TotalDistTraveled + (CurrPos - PrevPos).Magnitude
			if TotalDistTraveled > Settings.Distance then
				Bullet:Destroy()
				BulletStopped = true
				break
			end

			if BulletWhiz then
				--debug.profilebegin("Bullet Whizz Loop")
				local BulletVectorUnit = BulletVector.Unit
				local BulletSpeed = Projectile.Velocity.Magnitude
				local BulletType = Settings.BulletType
				local SPPosition = SmokePart.Position
				local SPVector = SmokePart.CFrame.LookVector

				for i, PlayerTarget in ipairs(Players:GetPlayers()) do
					if PlayerTarget:IsA("Player") and (PlayerTarget ~= LocalPlayer or debugtp.Value) and not WhizzedPlayers[PlayerTarget.Name] then

						local TargetChar = PlayerTarget.Character
						if TargetChar then

							local Head = TargetChar:FindFirstChild("Head")
							if Head then

								local HeadPos = TargetChar.Head.Position
								local Angle = (HeadPos - CurrPos).Unit:Dot(BulletVectorUnit) -- angle between bullet travel vector and vector from bullet to head
								local Angle2 = (HeadPos - SPPosition).Unit:Dot(SPVector)

								if Angle < 0 and Angle2 > 0 then -- player head has to be in front of smokepart
									local dist = Ray.new(PrevPos, BulletVectorUnit):Distance(HeadPos) -- shortest path between line and point vector (bullet path, head position)

									if dist <= SuppressMaxDistance then
										Evt.Suppression:FireServer(PlayerTarget, math.clamp(1 - (dist * 0.1), 0, 1), math.clamp(10 - (dist * 0.5), 0, 10))
									end
									if dist <= BWMaxDistance then
										local HeadDist = (SPPosition - HeadPos).Magnitude
										local CrackFactor = math.min(HeadDist / 64 * Angle2, 1) -- this variable adjusts whizz loudness based on distance of target from muzzle AND angle relative to muzzle
										Evt.Whizz:FireServer(PlayerTarget, BulletType, BulletSpeed, BWEmitter * CrackFactor, dist, BWMaxDistance)
									end

									-- splash damage
									if EnableSplashDamage then
										local VitimaHuman = TargetChar.Humanoid
										if dist <= SplashDistance and (ServerConfig.TeamKill or PlayerTarget.Team ~= LocalPlayer.Team) then
											local Dmg,VestDmg,HelmDmg = CalculateDamage(SplashDamage * BulletPower, TotalDistTraveled, VitimaHuman, "Body")
											Evt.Damage:FireServer(VitimaHuman,Dmg,VestDmg,HelmDmg,Id.."__"..LocalPlayer.UserId)
											SplashedPlayers[PlayerTarget.Name] = true
										end
									end

									WhizzedPlayers[PlayerTarget.Name] = true -- add player name to list of already whizzed players
								end
							end
						end
					end
				end
				--debug.profileend()
			end
	
			
			GunBlur.NearIntensity = Settings.BlurIntensity

			GunBlur.FocusDistance = Settings.BlurDistance
			local AheadResult = workspace:Raycast(PrevPos, (CurrPos - PrevPos)*1.25, RaycastAheadParams)

			if AheadResult then
				--debug.profilebegin("Hit2 Cast")
				local Hit2 = AheadResult.Instance
				while not recast do
					if Hit2 then
						local NotHitBody = not Hit2.CanCollide and (not LimbsList[Hit2.Name] and not IgnoreNonCollide[Hit2.Name])
						if NotHitBody or IgnoreList[Hit2.Name] or IgnoreAccessoriesList[Hit2.Parent.Name] then
							table.insert(Ray_Ignore, Hit2)
							RaycastAheadParams.FilterDescendantsInstances = Ray_Ignore
							recast = true
						end
					end

					if recast then
						AheadResult = workspace:Raycast(PrevPos, (CurrPos - PrevPos)*1.25, RaycastAheadParams)
						if AheadResult then
							Hit2 = AheadResult.Instance
						else
							Hit2 = nil
						end
						recast = false
					else
						break
					end
				end
				--debug.profileend()


				HitRaycastParams.FilterDescendantsInstances = Ray_Ignore
				Hit, Pos, Norm, Mat = HitRaycast(CurrPos, PrevPos, HitRaycastParams)

				if Hit then
					--debug.profilebegin("CastRay: Bullet Hit")
					BulletPower = (Projectile.Velocity.Magnitude / BSpeed)^2
					
					if Settings.ExplosiveHit then
						Bullet:Destroy()
						BulletStopped = true
						BulletHit(Hit, Pos, Norm, BulletVector, Mat, TotalDistTraveled, BulletPower)

					elseif WallbangEnabled then
						local WallbangIgnore = table.clone(Ray_Ignore)
						local RayDirection = BulletVector.Unit


						-- continue wallbang loop until all potential parts in casted ray are exhausted or the bullet is stopped, rico also does the same
						-- down the road, once all parts to raycast are exhausted, the function will eventually return Hit as nil, so this stops the loop
						--debug.profilebegin("Wallbanging")
						while Hit and BulletPower >= 0 do
							WallbangParams.FilterDescendantsInstances = {Hit} -- whitelist the part being hit for wallbang raycast



							local CastDist
							if WallbangSpecialNames[Hit.Name] then
								CastDist = BulletPenetration / WallbangSpecialNames[Hit.Name]
							elseif WallbangMaterialHardness[Mat] then
								CastDist = BulletPenetration / WallbangMaterialHardness[Mat.Name]
							else
								CastDist = BulletPenetration / WallbangMaterialHardness["default"]
							end
							local CastDist2 = CastDist * BulletPower * WallbangConstant



							local WBRayPosition = Pos + RayDirection * CastDist2 -- cast ray x studs in front of hit (if cast happens it means wallbang happened)
							local WBRayVector = -RayDirection * CastDist2 -- cast ray opposite of shot direction

							WallbangRay = workspace:Raycast(WBRayPosition, WBRayVector, WallbangParams)
							if WallbangRay then
								--debug.profilebegin("Wallbang Hit")
								local thickness = (WallbangRay.Position - Pos).Magnitude

								table.insert(WallbangIgnore, WallbangRay.Instance)
								BulletHit(Hit, Pos, Norm, BulletVector, Mat, TotalDistTraveled, BulletPower, "In")
								BulletPower = math.max(BulletPower - thickness / CastDist2, 0) -- decrease bullet power after bullet hit effect
								
								Wallbanged = true

								-- for cases where door knob/part was deleted upon initial bullet hit effect
								if Hit then
									local Off = ConvertHitToCF(Hit, WallbangRay.Position, WallbangRay.Normal, WBRayVector)
									local WBHit, WBOff, WBMat, WBPower = Hit, Off, Mat, BulletPower
									task.defer(function()
										Hitmarker.HitEffect(Ray_Ignore, WBHit, WBOff, WBMat, Settings, WBPower, "Out")
									end)


									Evt.Hit2:FireServer(Hit, Off, Mat, EvtHitTable(), Id.."__"..LocalPlayer.UserId, BulletPower, "Out",Velocity)
								end
								--debug.profileend()

								HitRaycastParams.FilterDescendantsInstances = WallbangIgnore
								Hit, Pos, Norm, Mat = HitRaycast(CurrPos,PrevPos,HitRaycastParams)

							elseif RicochetEnabled then
								DoRico()
								break

							else
								Bullet:Destroy()
								BulletStopped = true
								BulletHit(Hit, Pos, Norm, BulletVector, Mat, TotalDistTraveled, BulletPower)
								break
							end
						end
						--debug.profileend()
						
					-- wallbanged through walls

					elseif RicochetEnabled then
						DoRico()

					else
						Bullet:Destroy()
						BulletStopped = true
						BulletHit(Hit, Pos, Norm, BulletVector, Mat, TotalDistTraveled, BulletPower)
					end

					if Projectile then
						local vel = Projectile.Velocity
						Projectile.Velocity = vel.Unit * BSpeed * math.sqrt(BulletPower)
					end
					--debug.profileend()
				end
			end

			-- don't re-assign new prevpos if rico happened
			if Wallbanged then
				Wallbanged = false
				if ServerConfig.ReplicatedWallbang then
					Evt.ServerBullet:FireServer(ID, Bullet.Position, Settings.BDrop, Projectile.Velocity, Settings.Distance - TotalDistTraveled)
				end
			end
			
			if RicoHappened then
				RicoHappened = false
				if ServerConfig.ReplicatedRicochet then
					Evt.ServerBullet:FireServer(ID, Bullet.Position, Settings.BDrop, Projectile.Velocity, Settings.Distance - TotalDistTraveled)
				end
			else
				PrevPos = CurrPos
			end

			if BulletPower <= 0 then
				Bullet:Destroy()
				BulletStopped = true
			end
		end
	end
end



function HitRaycast(CurrPos,PrevPos,Params)
	debug.profilebegin("Bullet hit raycast")
	local result = workspace:Raycast(PrevPos, CurrPos - PrevPos, Params)
	debug.profileend()
	if result then
		return result.Instance, result.Position, result.Normal, result.Material
	end
	return nil, nil, nil, nil
end




function StringV3(V3n)
	return "X " .. V3n.X .. " Y " .. V3n.Y .. " Z " .. V3n.Z
end


function StringCF(CF)
	local pos = CF.Position
	local look = CF.LookVector
	return "Position: ".. StringV3(pos) .. [[ 
	Looking at: ]] .. StringV3(look)
end

function printCF(str,CF)
	print("--" .. str .. [[--
	]] .. StringCF(CF))
end



function InflictDamage(DmgType,TotalDistTraveled,VitimaHuman,BodyPart,DanoModifier)
	local DanoBase = math.random(DmgType[1], DmgType[2]) * DanoModifier
	local Dmg, VestDmg, HelmDmg = CalculateDamage(DanoBase, TotalDistTraveled, VitimaHuman, BodyPart)
	Evt.Damage:FireServer(VitimaHuman, Dmg, VestDmg, HelmDmg, Id.."__"..LocalPlayer.UserId, BodyPart)
end

function FindObj(Hit, DoNotSearchParent)
	local ObjType = Hit:FindFirstChild("ACSObject")
	if not ObjType then
		local PointTo = Hit:FindFirstChild("PointTo") -- has to be object value (points to another instance)
		if PointTo then
			ObjType = FindObj(PointTo.Value) -- recursive finder (if PointTo present)
		elseif Hit.Parent and not DoNotSearchParent then
			ObjType = FindObj(Hit.Parent, true)
		end
	end
	return ObjType
end

function BulletHit(Hit, Pos, Norm, Dir, Mat, TotalDistTraveled, BulletPower, Type)
	if not Type then
		Type = "Hit"
	end

	local FoundHuman,VitimaHuman = CheckForHumanoid(Hit)
	local Off = ConvertHitToCF(Hit, Pos, Norm, Dir)

	task.defer(function()
		Hitmarker.HitEffect(Ray_Ignore, Hit, Off, Mat, Settings, BulletPower, Type)
	end)


	Evt.Hit2:FireServer(Hit, Off, Mat, EvtHitTable(), Id.."__"..LocalPlayer.UserId, BulletPower, Type)

	if FoundHuman and VitimaHuman.Health > 0 then
		if ServerConfig.HitmarkerSound then
			local hurtSound = PastaFX.Hitmarker:Clone()
			hurtSound.Parent = LocalPlayer.PlayerGui
			hurtSound.Volume = 2
			hurtSound.PlayOnRemove = true
			Debris:AddItem(hurtSound,0)	
		end

		if not Settings.ModoTreino then

			-- yep, I'm shooting at a zombie
			local VitimaPlayer = Players:FindFirstChild(VitimaHuman.Parent.Name)
			if VitimaPlayer then

				if VitimaPlayer.Team ~= LocalPlayer.Team then
					if Hit.Name == "Head" or HeadAccessoriesList[Hit.Parent.Name] then
						InflictDamage(Settings.HeadDamage, TotalDistTraveled, VitimaHuman, "Head", BulletPower)
					elseif (Hit.Parent:IsA('Accessory') or Hit.Parent:IsA('Hat')) then
						InflictDamage(Settings.HeadDamage, TotalDistTraveled, VitimaHuman, "Head", BulletPower)
					elseif TorsoList[Hit.Name] or TorsoAccessoriesList[Hit.Parent.Name] then
						InflictDamage(Settings.TorsoDamage, TotalDistTraveled, VitimaHuman, "Body", BulletPower)
					elseif LimbsList[Hit.Name] then
						InflictDamage(Settings.LimbsDamage, TotalDistTraveled, VitimaHuman, "Body", BulletPower)
					end

				elseif ServerConfig.TeamKill then
					if Hit.Name == "Head" or HeadAccessoriesList[Hit.Parent.Name] then
						InflictDamage(Settings.HeadDamage,TotalDistTraveled, VitimaHuman, "Head", BulletPower*ServerConfig.TeamDamageMultiplier)
					elseif (Hit.Parent:IsA('Accessory') or Hit.Parent:IsA('Hat')) then
						InflictDamage(Settings.HeadDamage,TotalDistTraveled, VitimaHuman, "Head", BulletPower*ServerConfig.TeamDamageMultiplier)
					elseif TorsoList[Hit.Name] or TorsoAccessoriesList[Hit.Parent.Name] then
						InflictDamage(Settings.TorsoDamage,TotalDistTraveled, VitimaHuman, "Body", BulletPower*ServerConfig.TeamDamageMultiplier)
					elseif LimbsList[Hit.Name] then
						InflictDamage(Settings.LimbsDamage,TotalDistTraveled, VitimaHuman, "Body", BulletPower*ServerConfig.TeamDamageMultiplier)
					end
				end

			else
				if Hit.Name == "Head" then
					InflictDamage(Settings.HeadDamage, TotalDistTraveled, VitimaHuman, "Head", BulletPower)
				elseif TorsoList[Hit.Name] then
					InflictDamage(Settings.TorsoDamage, TotalDistTraveled, VitimaHuman, "Body", BulletPower)
				else
					InflictDamage(Settings.LimbsDamage, TotalDistTraveled, VitimaHuman, "Body", BulletPower)
				end

			end
		elseif Hit.Name == "Head" or HeadAccessoriesList[Hit.Parent.Name] or (Hit.Parent:IsA('Accessory') or Hit.Parent:IsA('Hat')) or TorsoList[Hit.Name] or TorsoAccessoriesList[Hit.Parent.Name] or LimbsList[Hit.Name] then
			Evt.Treino:FireServer(VitimaHuman)
		end

	elseif Hit then

		local DamageableObjects = Settings.DamageableObjects

		---Start Blizzard Compat Function---------
		if GetBlizzardDamageGroup and Settings.CanDamageBlizzard and Hit:FindFirstChild("StatsPointTo") then
			local dg, heli = GetBlizzardDamageGroup(Hit)
			HeliHitEvent:FireServer(heli,dg,Settings.BlizzardDamage, Id.."__"..LocalPlayer.UserId)
			----End Blizzard Compat Function---------

			---Start Striker Compat Function---------
		elseif GetStrikerDamageGroup and CS:HasTag(Hit,"StrikerTankPart") and Settings.CanDamageStriker and Hit:FindFirstChild("StatsPointTo") then
			local dg, tank = GetStrikerDamageGroup(Hit)
			TankHitEvent:FireServer(tank,dg,Settings.StrikerDamage, Id.."__"..LocalPlayer.UserId)

			----End Striker Compat Function---------

		elseif DamageableObjects then
			local ObjType = FindObj(Hit)
			if ObjType then
				local profile = DamageableObjects[ObjType.Value]
				if profile then
					local health = ObjType.Parent:FindFirstChild("ACSHealth")
					if health then
						local dmg = math.random(profile[1],profile[2])
						Evt.DamageObject:FireServer(Id.."__"..LocalPlayer.UserId, health, dmg)
					else
						warn("ACSHealth Object not found")
					end
				end
			end
		end

	end


end








Humanoid.Running:connect(function(WalkSpeed)
	SpeedPrecision = WalkSpeed
	if WalkSpeed > 1 then
		Walking = true
	else
		Walking = false
	end
end)

function PunchCalc(PunchBase, Range, Dir, Default)
	if not Dir then
		return PunchCalc(PunchBase, Range, Default)
	elseif Dir == "Up" or Dir == "Left" or Dir == "ACW" then
		return PunchBase * Utils.RANDMR(1, Range * 2)
	elseif Dir == "Side" or Dir == "Both" then
		return Utils.RANDMR(0, PunchBase * 2)
	elseif Dir == "Down" or Dir == "Right" or Dir == "CW" then
		return -PunchBase * Utils.RANDMR(1, Range * 2)
	else
		return PunchCalc(PunchBase, Range, Default)
	end
end

function RecoilCalc(Recoil,Dir,Default)
	if not Dir then
		return RecoilCalc(Recoil, Default)
	elseif Dir == "Up" or Dir == "Left" then
		return Recoil
	elseif Dir == "Side" or Dir == "Both" then
		return Utils.RANDMR(0, Recoil * 2)
	elseif Dir == "Down" or Dir == "Right" then
		return -Recoil
	else
		return RecoilCalc(Recoil, Default)
	end
end



function GunFire()
	local Grip = Character:WaitForChild("S"..ArmaTool.Name):WaitForChild("Grip")

	local Counter = Grip:FindFirstChild("Counter")
	if not Counter then
		Counter = Instance.new("IntValue")
		Counter.Name = "Counter"
		Counter.Parent = Grip
	end

	Counter.Value = Counter.Value + 1

	local dur = Settings.MuzzleFXDuration or ServerConfig.MuzzleFXDelay

	local SilencerModel = FindSilencer(ArmaClone)
	local silmuzzle
	if SilencerModel and Silencer.Value then
		silmuzzle = ArmaClone.SmokePart:FindFirstChild("Silencer")
		if silmuzzle then
			MuzzleFX(silmuzzle,true,true,dur)
		else
			MuzzleFX(ArmaClone.SmokePart,false,false,dur)
		end
	else
		MuzzleFX(ArmaClone.SmokePart,true,true,dur)
	end
	MuzzleFX(ArmaClone.Chamber,true,true,dur)

	task.delay(dur, function()
		Counter.Value = Counter.Value - 1
		if Counter.Value == 0 then
			StopMuzzleFX(ArmaClone.SmokePart)
			StopMuzzleFX(ArmaClone.Chamber)
			if SilencerModel and Silencer.Value then
				if silmuzzle then
					StopMuzzleFX(silmuzzle)
				end
			end
		end
	end)



	if Silencer.Value then
		local Sound = FindSilencer(Grip)
		if Sound then
			FireSoundsModule.FireSound(ArmaClone, Sound, Grip.Position)
		else
			warn("No Suppressor Sound Found: " .. ArmaTool.Name)
		end

	else
		local Sound = Grip:FindFirstChild("Fire")
		if Sound then
			FireSoundsModule.FireSound(ArmaClone, Sound, Grip.Position)
		else
			warn("No Fire Sound Found: " .. ArmaTool.Name)
		end

		for _, EchoSound in pairs(Grip:GetChildren()) do
			if string.sub(EchoSound.Name,1,4) == "Echo" then
				FireSoundsModule.FireSound(ArmaClone, EchoSound, Grip.Position)
			end
		end
	end
end

function recoil()
	task.spawn(function()

		local vr, hr, dr, vP, hP, dP



		local VRecoil = Utils.RANDF(Settings.VRecoil[1], Settings.VRecoil[2]) / 1024
		local HRecoil = Utils.RANDF(Settings.HRecoil[1], Settings.HRecoil[2]) / 1024
		local DRecoil = (Settings.DRecoil and Utils.RANDF(Settings.DRecoil[1], Settings.DRecoil[2]) / 1024) or (VRecoil + HRecoil) / 2

		vr = RecoilCalc(VRecoil, Settings.VRecoilDir, "Up")
		hr = RecoilCalc(HRecoil, Settings.HRecoilDir, "Side")
		dr = RecoilCalc(DRecoil, Settings.DRecoilDir, "Side")

		vP = PunchCalc(Settings.VPunchBase, Settings.VPunchRange or 0, Settings.VPunchDir, "Up")
		hP = PunchCalc(Settings.HPunchBase, Settings.HPunchRange or 0, Settings.HPunchDir, "Side")
		dP = PunchCalc(Settings.DPunchBase, Settings.DPunchRange or 0, Settings.DPunchDir, "Side")


		local RecoilPunch = Aiming and ((AimPartMode == 2) and Settings.RecoilPunchAim2 or Settings.RecoilPunchAim) or Settings.RecoilPunch
		local AimRecoilReduction = (AimPartMode == 2) and Settings.AimRecoilReduction2 or Settings.AimRecoilReduction


		if Bipod then
			vr  = vr/3
			hr = hr/3
			dr = dr/3

			vP = vP*1.7
			hP = hP/3
			dP = dP/3

			if Aiming then
				RecoilCF = RecoilModule.BipodAimRecoil(RecoilCF, RecoilPunch, Spread.RecoilPower, vP, hP, dP, AimRecoilReduction)
			else
				RecoilCF = RecoilModule.BipodHipRecoil(RecoilCF, RecoilPunch, Spread.RecoilPower, vP, hP, dP)
			end
		else

			if Aiming then
				RecoilCF = RecoilModule.AimRecoil(RecoilCF, RecoilPunch, Spread.RecoilPower, vP, hP, dP, AimRecoilReduction)
			else
				RecoilCF = RecoilModule.HipRecoil(RecoilCF, RecoilPunch, Spread.RecoilPower, vP, hP, dP)
				offsetrecoil = offsetrecoil + Vector2.xAxis * math.clamp(hP * (Settings.OffsetRecoilMult or ServerConfig.OffsetRecoilMult), -1, 1) * FireRate * 10
			end
		end

		
		
		if ServerConfig.LegacyRecoil then
			Camera.CFrame = Camera.CFrame * CFrame.Angles(vr, hr, 0)
			local c = -vr / 30
			local cx = -hr / 30
			local CAng = CFrame.Angles(c,  cx, 0)
			
			for i = 1, 30 * Settings.AimRecover do
				local CamFocusPos = Camera.Focus.Position
				local CameraCF = Camera.CFrame
				local CameraPos = CameraCF.Position
				Camera.CFrame = CFrame.new(CamFocusPos) * (CameraCF - CameraPos) * CAng * CFrame.new(0, 0, (CamFocusPos - CameraPos).Magnitude)
				RunService.Heartbeat:Wait()
			end
			
		else
			SpringsModule.Recoil(RecoilCF, vr, hr, dr)
		end
	end)

end





local Neck = Head:FindFirstChild("Neck", true)
local YOffset = Neck.C0.Y
local Asin = math.asin
local T = 0.15

oldtick = tick()
xTilt = 0
yTilt = 0
lastPitch = 0
lastYaw = 0
local TVal = 0

local EquippedTool = nil
-- lock first person
Character.ChildAdded:connect(function(Tool)
	if Tool:IsA("Tool") then
		dprint("Found new tool, trying to equip")
		if Tool:FindFirstChild("ACS_Settings") or Tool:FindFirstChild("ACS_Animations") then
			warn(Tool.Name .. "... bruh this gun is acs 2.0 not acs 1.7")
			return
		end
		
		local modulo = Tool:FindFirstChild("ACS_Modulo")
		if not modulo then return end
		
		local acs_setup = modulo:FindFirstChild("ACS_Setup")
		if acs_setup and Humanoid.Health > 0 and not ToolEquip and require(acs_setup).Type == "Gun" then
			for _,key in pairs(CharArmParts) do
				key.LocalTransparencyModifier = 1
			end
			dprint("Trying to equip new ACS gun")
			if Humanoid.Sit and CheckSeated(Humanoid.SeatPart) or Swimming then
				dprint("Swimming or driver seated, no acs gun")
				return
			end

			EquippedTool = Tool
			if Equipped then
				dprint("Tool already equipped? Equip new one")
				Unset()
				Setup(EquippedTool)
				LoadClientMods()
			else
				dprint("No tool equipped atm, equip new one")
				UIS.MouseIconEnabled = false
				LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
				Setup(Tool)
				LoadClientMods()
				
				dprint("Post Setup segment")
				GuiModule.SetupGui()
				Update_Gui()
				Equipping = true
				EquipAnim()
				Equipping = false

				if Settings.ZoomAnim and AimPartMode == 2 then
					ZoomAnim()
				end
				Sprint()
			end
			dprint("Tool Equip Finished")
		
		end
	end
end)

Humanoid.Seated:Connect(function(isSeated, seat)
	if isSeated and CheckSeated(seat) then
		Unset()
		Humanoid:UnequipTools()
		LocalPlayer.CameraMaxZoomDistance = ServerConfig.VehicleMaxZoom
	else
		LocalPlayer.CameraMaxZoomDistance = game.StarterPlayer.CameraMaxZoomDistance
	end
end)

LocalPlayer.Backpack.ChildRemoved:connect(function(toolPart)
	if toolPart:FindFirstChild('ACS_Modulo') then
		Evt.Holster:FireServer(toolPart.Name)
	end
end)

Character.ChildRemoved:connect(function(toolPart)
	if toolPart == ArmaTool and Equipped then
		EquippedTool = nil
		Unset()
	end
end)

function Tween(part,Time,properties,style,direction,de) 
	local tw = game:GetService("TweenService")
	local ti = TweenInfo.new(
		Time or 1,
		style or Enum.EasingStyle.Quint,
		direction or Enum.EasingDirection.Out,
		0,
		false,
		de or 0
	)
	tw:Create(part,ti,properties):Play()
end

function recaimoff(input,min,mult,step)
	local abs_input = math.abs(input)
	local output = abs_input * mult
	local increment = math.clamp(math.max(output, min) * step,0,abs_input)
	if input > 0 then
		return -increment
	else
		return increment
	end


end

function RecoverAimOffset(min,mult,step)
	local x = recaimoff(aimoffsetthing.X,min,mult,step)
	local y = recaimoff(aimoffsetthing.Y,min,mult,step)

	aimoffsetthing = aimoffsetthing + Vector2.new(x,y)
end

function DoOverHeat(bool)
	local foundsilencer = FindSilencer(ArmaClone)
	local sourcepart = ArmaClone.SmokePart
	if foundsilencer and foundsilencer.Transparency == 0 and ArmaClone.SmokePart:FindFirstChild("Silencer") then
		sourcepart = ArmaClone.SmokePart:FindFirstChild("Silencer")
	end

	for i, fx in pairs(sourcepart:GetChildren()) do
		if string.sub(fx.Name,1,8) == "OverHeat" and fx:IsA("ParticleEmitter") then
			fx.Enabled = bool
		elseif string.sub(fx.Name,1,10) == "SmokeTrail" and fx:IsA("Trail") then
			fx.Enabled = bool
		end
	end
end



RunService:BindToRenderStep("ACS_HeadRot", Enum.RenderPriority.Character.Value + 3, function()
	if not Equipped and ServerConfig.DisableHeadRotWhenUnequipped or Character.Humanoid.Health <= 0 or not Neck or Character.Humanoid.PlatformStand or not Character:FindFirstChild "UpperTorso" then
		return
	end
	local CameraDirection = HumanoidRootPart.CFrame:toObjectSpace(Camera.CFrame).lookVector
	local HeadCF = CFrame.new(0, YOffset, 0) * CFrame.Angles(
		-math.asin(Character.UpperTorso.CFrame.lookVector.Y),
		-math.asin(CameraDirection.X/1.15),
		0
	) * CFrame.Angles(math.asin(CameraDirection.Y), 0, 0)
	Neck.C0 = HeadCF * Neck.Transform:Inverse()

	PlaceHolder = not PlaceHolder -- every 4 heartbeats...
	if PlaceHolder then
		return
	end

	-- server replication
	if Clone then
		local CF2 = (Camera.CFrame:Inverse() * HeadBase.CFrame)
		Evt.HeadRot:FireServer(HeadCF, CloneC1V2 * CF2.Rotation)
	else
		Evt.HeadRot:FireServer(HeadCF)
	end

end)



Evt.HeadRot.OnClientEvent:Connect(function(Player,CF,CF2)
	local char = Player.Character
	if Player == LocalPlayer and not debugtp.Value or not char or not char:FindFirstChild "Humanoid" or char:FindFirstChild "Humanoid".Health <= 0 then
		return
	end
	
	if char and char:FindFirstChild "Head" then
		local Neck = char.Head:FindFirstChild("Neck")
		if Neck then
			Neck.C0 = CF * Neck.Transform:Inverse() -- keep neck at level with camera (stop neck moving because of animation)
		end

		if CF2 then
			local AnimBase = char:FindFirstChild("AnimBase")
			if AnimBase then
				AnimBase.AnimBaseW.C0 = CF2:Inverse()
			end
		end
	end
end)







local CloneC1Bipod = CFrame.new()
local LastStepAnim = 0
local Resetting

RunService:BindToRenderStep("ACS_Main", Enum.RenderPriority.Camera.Value + 2, function(Update)

	if not Equipped then
		HeadBase.CFrame = Camera.CFrame

	else
		if LocalPlayer.CameraMode ~= Enum.CameraMode.LockFirstPerson then -- stop the 3rd person equipped gun glitch
			Unset()
			Humanoid:UnequipTools()
		end

		local currtick = tick()
		local tickdiff = currtick - OldTick
		local adjust = tickdiff * 60

		local Adj05 = math.min(1, 0.05 * adjust)
		local Adj15 = math.min(1, .15 * adjust)

		OldTick = currtick
		Update_Gui()
		CrossHairModule.DoCrosshair(Spread.BSpread, Running, stance, Aiming, ArmaClone, Ray_Ignore, Settings, Torso)

		RecoilCF = RecoilCF:Lerp(CFrame.new(), math.min(1, Settings.PunchRecover * adjust))
		SpringsModule.Preset(RecoilCF)

		
		
		
		
		-- Adjust Aim Offset (gun pointed slightly to the left/right)
		if Aiming then
			RecoverAimOffset(0.04,0.08,adjust)
		else
			if BlindFire then
				aimoffsetthing = aimoffsetthing-(UIS:GetMouseDelta()*5*OffsetSens)

			else
				aimoffsetthing = aimoffsetthing-(UIS:GetMouseDelta()*OffsetSens)

				if ServerConfig.RecoverAimOffset then
					RecoverAimOffset(0.02,0.04,adjust)

				elseif Bipod then
					RecoverAimOffset(0.04,0.08,adjust)
				end
			end
			
			if ServerConfig.AimOffsetRecoil then
				aimoffsetthing = aimoffsetthing + offsetrecoil
				offsetrecoil = offsetrecoil:Lerp(Vector2.zero, math.min(Settings.PunchRecover * adjust, 1))
			end
			
			local Adj20 = math.min(1, 0.2 * adjust)
			if aimoffsetthing.Magnitude > OffsetAngle and not BlindFire then
				aimoffsetthing = aimoffsetthing:Lerp(aimoffsetthing.Unit * OffsetAngle, Adj20)

			elseif aimoffsetthing.Magnitude > 60 then
				aimoffsetthing = aimoffsetthing:Lerp(aimoffsetthing.Unit * 60, Adj20)

			elseif aimoffsetthing.X < -30 then
				aimoffsetthing = aimoffsetthing:Lerp(Vector2.new(-30, aimoffsetthing.Y), Adj20)
			end
		end

		
		
		
		
		local HandlePos = ArmaClone.Handle.Position
		local CloneC1Pushback = CFrame.new()
		local ClonePushback = CFrame.new()
		local PushingBack = false

		if not (Aiming and ServerConfig.AimWhenObstructed) and stance == 0 and not Equipping then
			local GunSize = Settings.GunSize

			local Hit, Pos, Norm
			local result = workspace:Raycast(ArmaClone.Handle.Position, ArmaClone.Handle.CFrame.LookVector * GunSize, BaseParams)
			if result then
				Hit, Pos, Norm = result.Instance, result.Position, result.Normal
			end

			if Hit then
				local NotHitBody = not Hit.CanCollide and (not LimbsList[Hit.Name] and not IgnoreNonCollide[Hit.Name])
				if NotHitBody or IgnoreList[Hit.Name] or IgnoreAccessoriesList[Hit.Parent.Name] then
					table.insert(Ray_Ignore, Hit)
					BaseParams.FilterDescendantsInstances = Ray_Ignore
				end
			end

			local Hit2, Pos2
			local result2 = workspace:Raycast(Camera.CFrame.Position, ArmaClone.Handle.Position - Camera.CFrame.Position, BaseParams)
			if result then
				Hit2, Pos2 = result.Instance, result.Position
			end

			-- push gun handle/arms back if it's behind the wall
			if Hit2 and (HandlePos - Pos2).magnitude < GunSize then
				if Aiming then
					AimObstructed()
				end
				CloneC1Pushback = CFrame.new(0,0,(((HandlePos - Pos2).magnitude/GunSize) - 1) * -20)
				PushingBack = true



				-- push gun back if it's touching the wall
			elseif Hit and (HandlePos - Pos).Magnitude < GunSize then
				if Aiming then
					AimObstructed()
				end

				local GunPushbackCF = CFrame.new(0,0,(((HandlePos - Pos).Magnitude/GunSize) - 1) * -2)
				local GunRotValue = (((HandlePos - Pos).Magnitude/Settings.GunSize) - 1) * math.pi * 2
				--print(GunRotValue)
				local GunRotValueH = GunRotValue


				-- vertical gun rotation
				local GunRotValueV = 0
				local VAngle = math.deg(math.acos(Camera.CFrame.UpVector:Dot(Norm)))
				if VAngle > 120 then -- if looking more than 30 degrees down
					GunRotValueV = GunRotValue -- make gun look down
				elseif VAngle < 60 then -- if looking more than 30 degrees up
					GunRotValueV = -GunRotValue -- make gun look up
				end


				-- horizontal gun rotation
				local HAngle = math.deg(math.acos(Camera.CFrame.RightVector:Dot(Norm)))
				if GunRotValueV ~= 0 and HAngle > 60 and HAngle < 120 then
					GunRotValueH = 0 -- no left-right gun rotation
				elseif HAngle > 90 then -- if not bending gun up/down down flip H rotation if gun is left/right of wall
					GunRotValueH = -GunRotValueH -- flip left-right gun rotation
				end


				-- clamp gun rotation values to bounds
				GunRotValueH = math.clamp(GunRotValueH,-math.pi,math.pi)
				GunRotValueV = math.clamp(GunRotValueV,-math.pi,math.pi)



				CloneC1Pushback = GunPushbackCF * CFrame.Angles(0,GunRotValueH,0) * CFrame.Angles(GunRotValueV,0,0)
				ClonePushback = CloneC1Pushback
				PushingBack = true
			end
		end
		
		

		local HumanWalkSpeed = Humanoid.WalkSpeed
		local WalkC = HumanWalkSpeed*0.28
		local WalkT = HumanWalkSpeed*0.05
		
		-- arms movement thingy
		local Adj50 = math.min(1, .5 * adjust)

		if Bipod then
			WVal = Lerp(WVal, 0, math.min(1, WValBounds.rl * adjust))
			TVal = 0
			WalkRate = WalkC / 3
		else
			if Walking or supress11.Size >= 1 and not Humanoid.SeatPart then --seat arms moving fix
				WalkRate = WalkC

				-- arms sway left/right when moving left/right
				if wasd.a then
					TVal = (-.2*WalkT)
				elseif wasd.d then
					TVal = (.2*WalkT)
				else
					TVal = 0
				end
				WVal = Lerp(WVal, WValBounds.w * WalkC * math.sqrt(WalkC), math.min(1, WValBounds.wl * adjust))
			else
				WalkRate = WalkC / 3
				if WVal > WValBounds.wb then
					WVal = Lerp(WVal, WValBounds.s, math.min(1, WValBounds.rl * adjust))
				else
					WVal = Lerp(WVal, WValBounds.s, math.min(1, WValBounds.sl * adjust))
				end
				TVal = 0
			end
		end
		
		
		t = t + tickdiff * WalkRate
		
		
		
		local lk = Camera.CFrame.lookVector
		local lookpitch, lookyaw = math.asin(lk.Y), -math.atan(lk.X / lk.Z)

		local pitchChange = lastPitch - lookpitch
		local yawChange = lastYaw - lookyaw
		pitchChange = pitchChange * ((math.abs(pitchChange) < 1) and 1 or 0)
		yawChange = yawChange * ((math.abs(yawChange) < 1) and 1 or 0)

		yTilt = (yTilt * 0.6 + pitchChange)
		xTilt = (xTilt * 0.6 + yawChange)

		lastPitch = lookpitch
		lastYaw = lookyaw

		local swyval = Aiming and 5 or 8
		local swayVec = SpringsModule.ApplySway(xTilt, yTilt, TVal)
		local TWAY = swayVec.z
		local XSWY = swayVec.X*swyval
		local YSWY = swayVec.Y*swyval
		
		local bm = ServerConfig.BipodSwayMultiplier
		local SwayCF = CFrame.Angles(YSWY * math.rad(5) * bm,-XSWY * math.rad(1.5) * bm,-XSWY * math.rad(3) * bm)
		
		

		local xWalk = (  -math.sin(t*2) - 0.25*math.sin(t)  ) * WVal
		local yWalk = (  math.sin(t*4)/4 - math.cos(t*4)/2 - 0.25*math.cos(t)  ) * WVal
		local zWalk = (  -math.cos(t*2) + math.cos(t*6)/9  ) * WVal -- walk tilt sway

		local Walk = SpringsModule.ApplyWalk(xWalk, yWalk, zWalk)
		local xWalk2 = Walk.X
		local yWalk2 = Walk.Y
		local zWalk2 = Walk.Z
		
		

		Waval = CFrame.new(xWalk2/200, yWalk2/200,0) * CFrame.Angles(yWalk2/100, -xWalk2/400, zWalk2/200) * CFrame.Angles(0, 0, TWAY/20)
		Clone.C0 = Clone.C0:lerp(Waval * SwayCF, math.min(1,.7 * adjust))
		
		
		
		-- handle aiming (AimCF moves gun towards AimPart if needed)
		local AimCF = CFrame.new() -- THIS ONLY HELPS MOVE THE GUN TO AIM POSITION, IT IS NOT PERMANENT AND WILL GO DOWN TO 0 WHEN AIMED
		if Aiming then

			local AimPart = ArmaClone.AimPart
			local AimPartCFrame = AimPart.CFrame
			local HeadBaseCFrame = HeadBase.CFrame
			local AimPartOffset = CFrame.new(0, 0, -ServerConfig.AimPartOffset)

			if NVG and AimPart:FindFirstChild("NVAim") then
				if Bipod then
					if Aiming then
						UIS.MouseDeltaSensitivity = 1
						ArmaClone.Handle.AimUp:Play()	
						tweenFoV(70,120)
						Aiming = false
						AimBlur.Enabled = false
						CallAimFunction()
						stance = 0
					end
				else
					AimCF = (AimPartCFrame * AimPart.NVAim.CFrame):toObjectSpace(HeadBaseCFrame) * AimPartOffset
				end

			else
				if AimPartMode == 2 and ArmaClone:FindFirstChild("AimPart2") then
					AimCF = ArmaClone.AimPart2.CFrame:toObjectSpace(HeadBaseCFrame) * AimPartOffset
				else
					AimCF = AimPartCFrame:toObjectSpace(HeadBaseCFrame) * AimPartOffset
				end
			end
		else
		end





		local Stamina = Character.Saude.Variaveis.Stamina
		local StaminaRatio = 1 - Stamina.Value / Stamina.MaxValue
		local StaminaValue = Settings.SwayBase + StaminaRatio * Settings.MaxSway
		
		

		if BipodExists and not BlindFire then
			debug.profilebegin("Bipod Process")

			local BipodPoint = ArmaClone.BipodPoint
			local Origin, Direction



			if Settings.UseBipodSize then
				local Height = BipodPoint.Size.Y
				local UpVector = BipodPoint.CFrame.UpVector
				if Aiming then
					Origin = BipodPoint.Position + (Height * 0.5 + 0.5) * UpVector -- .5 studs above bipod
					Direction = UpVector * -(Height + 1.5) -- 1 stud deeper than bipod bottom
			else -- legacy acs bipod
				Origin = BipodPoint.Position
				Direction = BipodPoint.CFrame.UpVector * -1.75
			end


			
			local BipodPrev = Bipod
			local result = workspace:Raycast(Origin, Direction, BaseParams)
			if result and (stance == 0 or stance == 2) then
				CanDeployBipod = true

				if Bipod then
					GuiModule.UpdateBipod(2)
					StaminaValue = 0

					if not Aiming then
						local mod

						if Settings.UseBipodSize then
							local BipodBottomPos = BipodPoint.Position - BipodPoint.CFrame.UpVector * BipodPoint.Size.Y * 0.5

							local bipoddist = result.Position - BipodBottomPos

							mod = bipoddist.Magnitude -- - 0.5 -- adjust for mystery variable
							if bipoddist.Y < 0 then -- invert downwards if bipod bottom is above the ground
								mod = -mod
							end
						else
							mod = (1 - (BipodPoint.Position - result.Position).Magnitude) * 1.5
						end

						CloneC1Bipod = CloneC1Bipod:Lerp(CFrame.new(0, Utils.bounds(mod / Adj15, -0.5, 0.5), 0), Adj15)
					end

				else
					GuiModule.UpdateBipod(1)
				end

			else
				GuiModule.UpdateBipod(0)
				Bipod = false
				CanDeployBipod = false
				if BipodPrev then
					local success, result = pcall(coroutine.wrap(BipodLiftedAnim))
					if not success then
						warn("BipodLiftedAnim Error: " .. result)
					end
				end
			end
			debug.profileend()

		else
			GuiModule.UpdateBipod(0)
			CloneC1Bipod = CFrame.new()
		end

		
		
		
		
		-- apply aim offset thing to headbase
		UpdateShoulderOffset(adjust)
		Camera.CFrame = Camera.CFrame * CFrame.new(shoulderCameraOffsetCurrent, 0, 0)
		local ModHeadCF = Camera.CFrame * CFrame.new(0, 0, ServerConfig.HeadCameraOffset)
		local ShoulderOffsetCF = GetShoulderOffsetCF()
		local tickk = tick() * 1.25
		local StaminaCF = CFrame.Angles(
			math.rad(StaminaValue * math.sin(tickk * 2)),
			math.rad(StaminaValue * math.sin(tickk)),
			0
		)
		if aimoffsetthing.Magnitude == 0 then
			HeadBase.CFrame = ModHeadCF * ShoulderOffsetCF * StaminaCF
		else
			local AimOffsetCF = CFrame.new(
				aimoffsetthing.X * .025,
				aimoffsetthing.Y * -.025,
				0
			) * StaminaCF * CFrame.Angles(
				math.rad(aimoffsetthing.Y),
				math.rad(aimoffsetthing.X),
				0
			)
			HeadBase.CFrame = ModHeadCF * ShoulderOffsetCF * AimOffsetCF
		end





		-- NEW CLONE.C1 LERPING SECTION
		CloneC1V2 = CloneC1V2 or CFrame.new()
		
		local RecoilPart = ArmaClone:FindFirstChild("RecoilPart")
		local Offset = HeadBase.CFrame:ToObjectSpace(RecoilPart and RecoilPart.CFrame or ArmaClone.Handle.CFrame)
		
		if Aiming then -- adjust for aiming mode
			Offset = Offset * Clone.C1:Inverse()
		end
		
		if not RecoilPart then -- move offset to where headbase/camera is
			Offset = Offset - Vector3.new(0, 0, ((Settings.PistolRecoil or Settings.GunType == 0) and math.max(-ServerConfig.PistolRecoilOffset, Offset.Z + 0.8) or Offset.Z + 0.2))
		end -- recoil pivot offset 0.8 studs in front of headbase if gun is pistol (insurgency style pistol I think)
		
		local RecoilCF2 = Offset * (ServerConfig.LegacyRecoil and RecoilCF or SpringsModule.GetRecoil()) * Offset:Inverse()
		
		-- apply recoil + pushback if any
		if PushingBack then
			Clone.C1 = Clone.C1:Lerp(CloneC1Pushback * RecoilCF2 * CloneC1Bipod, Adj15)
		CloneC1V2 = CloneC1V2:Lerp(CloneC1Pushback * RecoilCF2 * CloneC1Bipod, Adj15)

		elseif Aiming then
			Clone.C1 = Clone.C1:Lerp(Clone.C1 * RecoilCF2 * AimCF, Adj15)
			CloneC1V2 = CloneC1V2:Lerp(RecoilCF2, Adj15)

		else
			Clone.C1 = Clone.C1:Lerp(RecoilCF2 * CloneC1Bipod, Adj15)
			CloneC1V2 = CloneC1V2:Lerp(RecoilCF2 * CloneC1Bipod, Adj15)
		end





		-- stop overheat after some seconds
		if OverHeat and Can_Shoot then
			task.delay(60,function()
				if Can_Shoot then
					OverHeat = false
				end
			end)
		end



		-- bullet spread adjustment
		Spread.Adjust(Update, FireRate, Can_Shoot)
		DoOverHeat(OverHeat) -- if overheat == true then enabled = true, else false
		
		
		
		if Equipped and LaserEnabled then
			debug.profilebegin("Laser Cast")
			if NVG then
				Pointer.Transparency = 1
				Laser.Enabled = true
				Pointer.PointLight.Enabled = true
			else

				if not ServerConfig.RealisticLaser then
					Laser.Enabled = true
				else
					Laser.Enabled = false
				end

				if IRmode then
					Pointer.Transparency = 1
					Pointer.Transparency = 1
				else
					Pointer.Transparency = 0
					Pointer.PointLight.Enabled = true
				end
			end

			local LaserRay = Ray.new(ArmaClone.LaserPoint.Position, AnimBase.CFrame.lookVector * 999)
			local recs = true
			local Hit, Pos, Normal

			-- fix up invisible parts blocking laser
			while recs do
				Hit, Pos, Normal = workspace:FindPartOnRayWithIgnoreList(LaserRay, Laser_Ignore, false, ServerConfig.LaserIgnoreWater)
				if Hit and (Hit.Transparency >= 1 or Hit.Name == "Ignorable") then
					table.insert(Laser_Ignore, Hit)
				else
					recs = false
				end
			end


			LaserEP.CFrame = CFrame.new(0, 0, -LaserDist)
			Pointer.CFrame =  CFrame.new(Pos, Pos + Normal)


			if Hit then
				LaserDist = (ArmaClone.LaserPoint.Position - Pos).magnitude
			else
				LaserDist = 999
			end
			Evt.SVLaser:FireServer(Pos,1,ArmaClone.LaserPoint.Color,ArmaTool,IRmode)
			debug.profileend()
		end


		if not ServerConfig.LegacyRecoil then
			SpringsModule.AdjustCamera(Camera)
		end

		local curr = tick()
		if Anims.StepAnim and curr - LastStepAnim > Settings.StepAnimDelay then
			LastStepAnim = curr
			StepAnim()
	end
	end
	end
end)

-- firesound client event connection
-- play/pause: objs = nil
-- layered: objs = {SoundId1, SoundId2, SoundId3}
Evt.FireSound.OnClientEvent:Connect(FireSoundsModule.SV_FireSound)

Evt.SVFlash.OnClientEvent:Connect(function(Player,Mode,Arma,Angle,Bright,Color,Range)
	if Player ~= LocalPlayer and Player.Character then
		local Arma = Player.Character:FindFirstChild("S" .. Arma.Name)
		if not Arma then
			return
		end



		local FlashAtt
		local FlashPoint = Arma:FindFirstChild("FlashPoint")
		if FlashPoint then
			FlashAtt = FlashPoint:FindFirstChild("Flash")
		end
		if not FlashAtt then
			FlashAtt = Arma.Grip:FindFirstChild("Flash")
		end

		if not FlashAtt then
			warn("No flash attachment nor flashpoint were found on Gun: "..Arma.Name)
			return
		end

		if Mode == true then

			local Light = Instance.new("SpotLight")
			Light.Angle = Angle
			Light.Brightness = Bright
			Light.Range = Range
			Light.Color = Color
			Light.Parent = FlashAtt

			local bg = Instance.new("BillboardGui")
			bg.Adornee = FlashAtt
			bg.Size = UDim2.new(10, 0, 10, 0)
			bg.Parent = FlashAtt

			local flash = Instance.new("ImageLabel")
			flash.BackgroundTransparency = 1
			flash.Size = UDim2.new(1, 20, 1, 20)
			flash.AnchorPoint = Vector2.new(0.5,0.5)
			flash.Position = UDim2.new(0.5, 0, 0.5, 0)
			flash.Image = "http://www.roblox.com/asset/?id=1847258023"
			flash.ImageColor3 = Color
			flash.ImageTransparency = 0.25
			flash.Rotation = math.random(-45, 45)
			flash.Parent = bg

		else
			local SpotLight = FlashAtt:FindFirstChild("SpotLight")
			if SpotLight then
				SpotLight:Destroy()
			end

			local bg = FlashAtt:FindFirstChild("BillboardGui")
			if bg then
				bg:Destroy()
			end
		end
	end
end)

Evt.SVLaser.OnClientEvent:Connect(function(Player, Position, Modo, Color, Arma, IR)
	if Player ~= LocalPlayer then
		local S_Arma = Player.Character:FindFirstChild('S'.. Arma.Name)
		if not S_Arma then return end

		if Modo == 1 then
			local Dot = WorkspaceClientFolder:FindFirstChild(Player.Name.."_Laser")

			if not Dot then
				local Grip = S_Arma:WaitForChild('Grip')
				local Muzzle = Grip:FindFirstChild("Laser")

				if not Muzzle then
					local LaserPoint = S_Arma:FindFirstChild("LaserPoint")
					if not LaserPoint then return end

					Muzzle = LaserPoint:FindFirstChild("Laser")
					if not Muzzle then
						Muzzle = Instance.new("Attachment")
						Muzzle.Name = "Laser"
						Muzzle.Parent = LaserPoint
					end
				end

				Dot = LaserModule.SV_New(Player.Name.."_Laser", Muzzle, Color)
			end

			Dot.Position = Position	
			local Beam = Dot:FindFirstChild("Beam")

			if NVG then
				Dot.PointLight.Enabled = true
				Dot.Transparency = 0
				if Beam then
					Beam.Enabled = true
				end

			else
				Dot.Transparency = IR and 1 or 0

				if Beam then
					Beam.Enabled = false
				end
				if	Dot.Transparency == 1 then
					Dot.PointLight.Enabled = false
				end
				if	Dot.Transparency == 0 then
					Dot.PointLight.Enabled = true
				end
			end

		elseif Modo == 2 then
			local Dot = WorkspaceClientFolder:FindFirstChild(Player.Name.."_Laser")
			if Dot then
				Dot:Destroy()
			end
		end
	end
end)

function MakeExplosion(Hitmark,expdamage,radius,pressure,djrp)
	local Exp = Instance.new("Explosion")
	Exp.BlastPressure = pressure
	Exp.BlastRadius = radius
	Exp.DestroyJointRadiusPercent = djrp
	Exp.Position = Hitmark.Position
	Exp.Parent = Hitmark
	Exp.Visible = false

	Exp.Hit:connect(function(hitPart, partDistance)

		local FoundHuman,VitimaHuman = CheckForHumanoid(hitPart)
		local damage
		if type(expdamage) == "number" then
			damage = expdamage
		elseif type(expdamage) == "table" then
			damage = math.random(expdamage[1],expdamage[2])
		end
		if FoundHuman == true and VitimaHuman.Health > 0 then
			local distance_factor = partDistance / Exp.BlastRadius    -- get the distance as a Sights between 0 and 1
			distance_factor = 1 - distance_factor                         -- flip the amount, so that lower == closer == more damage
			if distance_factor > 0 then
				Evt.Damage:FireServer(VitimaHuman,(damage*distance_factor),0,0,Id.."__"..LocalPlayer.UserId)
			end
		end
	end)
end

function Launcher()
	GLChambered.Value = false
	
	local Grip = GunGrip(Character)
	FireSoundsModule.FireSound(ArmaClone, Grip:WaitForChild('Fire2'), Grip.Position)

	local M203 = Instance.new("Part")
	M203.Shape = 'Ball'
	M203.CanCollide = false
	M203.Size = Vector3.new(0.25,0.25,0.25)
	M203.Material = Enum.Material.Metal
	M203.Color = Color3.fromRGB(27, 42, 53)
	M203.Parent = WorkspaceClientFolder
	M203.CFrame = ArmaClone.SmokePart2.CFrame
	M203.Velocity = ArmaClone.SmokePart2.CFrame.lookVector*(1250-235.2)


	local Hit2, Pos2, Norm2, Mat2
	local Hit, Pos, Norm, Mat
	local PrevPos = ArmaClone.SmokePart2.Position
	local CurrPos = M203.Position
	local L_260_ = false	
	local recast
	local Heartbeat = RunService.Heartbeat

	while true do
		Heartbeat:Wait()
		CurrPos = M203.Position

		local AheadResult = workspace:Raycast(PrevPos, (CurrPos - PrevPos)*1.25, GLRaycastAheadParams)

		while not recast do
			if Hit2 then
				local NotHitBody = not Hit2.CanCollide and (not LimbsList[Hit2.Name] and not IgnoreNonCollide[Hit2.Name])
				if NotHitBody or IgnoreList[Hit2.Name] or IgnoreAccessoriesList[Hit2.Parent.Name] then
					table.insert(Ray_Ignore, Hit2)
					GLRaycastAheadParams.FilterDescendantsInstances = Ray_Ignore
					recast = true
				end
			end

			if recast then
				AheadResult = workspace:Raycast(PrevPos, (CurrPos - PrevPos)*1.25, GLRaycastAheadParams)
				if AheadResult then
					Hit2 = AheadResult.Instance
				else
					Hit2 = nil
				end
				recast = false
			else
				break
			end
		end

		Hit, Pos, Norm, Mat = workspace:FindPartOnRayWithIgnoreList(Ray.new(PrevPos, (CurrPos - PrevPos)), Ray_Ignore, false, ServerConfig.GLIgnoreWater);

		if Hit and not recast then
			Evt.LauncherHit:FireServer(Pos, Hit, Norm, Mat)
			Hitmarker.Explosion(Pos, Hit, Norm)
			M203:Destroy()

			local Hitmark = Instance.new("Attachment")
			Hitmark.CFrame = CFrame.new(Pos, Pos + Norm)
			Hitmark.Parent = AttachmentsFolder
			Debris:AddItem(Hitmark, 5)

			MakeExplosion(Hitmark,Settings.LauncherDamage,Settings.LauncherRadius,Settings.LauncherPressure,Settings.LauncherDestroyJointRadiusPercent)

			break
		end
		PrevPos = CurrPos
	end
end

Evt.LauncherHit.OnClientEvent:Connect(function(Player, Position, HitPart, Normal)
	if Player ~= LocalPlayer then 
		Hitmarker.Explosion(Position, HitPart, Normal)
	end
end)









------------------------------------------------
-----------[ GUN SHOOTING FUNCTIONS ]-----------
------------------------------------------------

local TimeError = 0

function Emperrar()
	if Settings.CanBreak == true and Chambered.Value == true and (Ammo.Value - 1) > 0 then
		local Jam = math.random(Settings.JamChance)

		if Jam == 1 then
			Emperrado.Value = true
			ArmaClone.Handle.Click:Play()
		end

	end
end

function OBSlideClose() -- open bolt slide close
	if ArmaClone.Bolt:FindFirstChild("SlideClose") then
		ArmaClone.Bolt.SlideClose:Play()
	else
		ArmaClone.Bolt.SlideRelease:Play()
	end
end

function BeforeShot(rate)
	if Settings.OpenBolt then
		local halfrate = rate / 2
		BoltModule.SlideBf(halfrate)
		if Emperrado.Value or Ammo.Value == 0 then
			Chambered.Value = false
			OBSlideClose()
		end
		task.wait(math.max(halfrate + TimeError / 2, 0))
	end
end



function Shootable()
	if Settings.OpenBolt then
		return (not Emperrado.Value and Chambered.Value) -- open bolt slide close bit (when ammo = 0)
	else
		return (Ammo.Value > 0 and not Emperrado.Value and Chambered.Value)
	end
end
if Chambered then
	ArmaClone.Bolt.SlidePull.Played:Connect(function()

		ArmaClone.Chamber.Smoke:Emit(10)
		ShellEjectionModule.EjectShell(ArmaClone, Settings.BulletType)

	
	end)
end

function SpawnShot(rate)
	BeforeShot(rate)
	if not Emperrado.Value and Chambered.Value then
		for _ = 1, Settings.Bullets do
			task.spawn(CastRay, CreateBullet())
			AimBlur.Enabled = false
			local BlurTime = Settings.BlurTime
			if ServerConfig.GunBlur then	
			task.spawn(function() 
					GunBlur.Enabled = true
					task.wait(Settings.BlurTime)
				GunBlur.Enabled = false
			end)
				if ServerConfig.GunBlur  and Aiming and not NVG then 
					task.spawn(function()
				AimBlur.Enabled = false
						task.wait(Settings.BlurTime)
				AimBlur.Enabled = true
			end)
			end	
		end
	end
	
		local success, result = pcall(coroutine.wrap(FireAnim))
		if not success then
			warn("FireAnim Error: " .. result)
		end
		
		local IfAiming = (Aiming and (not NVG or not ArmaClone.AimPart:FindFirstChild("NVAim")))
		local AimFOV = IfAiming and Settings.ChangeFOV[AimPartMode] or 70
		
		if Settings.FOVEffect then
			if IfAiming then
				tweenFoV(Settings.ChangeFOV[AimPartMode] + Settings.FOVEffect[AimPartMode], 11)
			else
				tweenFoV(70 + Settings.FOVEffect[3], 11)
			end
			RunService.RenderStepped:Wait()
			tweenFoV(AimFOV, 120)
			
		elseif ServerConfig.FOVRecoilMult ~= 0 then
			local factor = math.min(20, Settings.RecoilPunch * 2 + (Settings.VPunchBase + Settings.HPunchBase) * math.abs(Settings.MinRecoilPower)) / 20
			
			tweenFoV(AimFOV * math.max(ServerConfig.MinFOVRecoil, 1 - ServerConfig.FOVRecoilMult * factor), 11)
			RunService.RenderStepped:Wait()
			tweenFoV(AimFOV, 120)
		end
		
		recoil()
		GunFire()
	
		
		Evt.Atirar:FireServer(ArmaTool.Name, Settings.MuzzleFXDuration, FireSoundsModule.ConstructSoundString())
		if not Emperrado.Value then
			Ammo.Value = Ammo.Value - 1
			task.delay(rate/2, function()
				ShellEjectionModule.EjectShell(ArmaClone, Settings.BulletType)
			end)
			BoltModule.SlideEx(rate, Settings.Mode, Ammo.Value)
			if not Settings.OpenBolt and Ammo.Value < 1 then
				Chambered.Value = false
				if Settings.SlideLock then
					Slideback.Value = true
				end
			end
		end

		OverHeat = Spread.Shoot()
		
		task.wait(rate / 2)
		if not Settings.OpenBolt and (not Shootable() or not MouseHeld) then
			FireSoundsModule.StopLoops()
		end
	end
end

function FireShot(rate)
	local otime = tick()
	Emperrar()
	task.spawn(SpawnShot, rate)
	task.wait(math.max(rate + TimeError, 0))
	TimeError = otime - tick() + rate + TimeError
end



function BurstShot()
	for i = 1, Settings.BurstShot - 1 do
		if MouseHeld and Shootable() then
			FireShot(BurstFireRate)
		else
			break
		end
	end
	if MouseHeld and Shootable() then
		FireShot(FireRate)
	end
end

function BoltFire()
	Emperrar()
	
	for _ = 1, Settings.Bullets do
		task.spawn(function()
			CastRay(CreateBullet())
		end)
	end	

	local success, result = pcall(coroutine.wrap(FireAnim))
	if not success then
		warn("FireAnim Error: " .. result)
	end

	recoil()
	GunFire()
	Evt.Atirar:FireServer(ArmaTool.Name, Settings.MuzzleFXDuration, FireSoundsModule.ConstructSoundString())
	if Ammo.Value >= 1 then
		Emperrado.Value = true
	end

	OverHeat = Spread.Shoot()
	if Settings.AutoChamber then
		if Aiming or not Aiming then
			SetReloadOn()
			ChamberAnim()
			SetReloadOff()
		end
	end
	task.wait(FireRate)
end














local FireModeOutcomes = {
	["Safe"] = function() 
		ArmaClone.Handle.Click:Play()
	end,
	["Semi"] = function()
		if Shootable() then
			FireShot(FireRate)
		end
	end,
	["Auto"] = function()
		if Settings.BurstFirst then -- an94 functionality
			BurstShot()
		end

		local BurstFire = Settings.BurstFire
		while MouseHeld and Equipped and not Can_Shoot and Shootable() do
			if BurstFire then
				BurstShot()
			else
				FireShot(FireRate)
			end
		end
		if Settings.OpenBolt or not MouseHeld then
			FireSoundsModule.StopLoops()
		end
	end,
	["Burst"] = function()
		BurstShot()
	end,
	["Bolt-Action"] = function()
		if Shootable() then
			BoltFire()
		end
	end,
	["Pump-Action"] = function()
		if Shootable() then
			BoltFire()
		end
	end,
	["Explosive"] = Launcher,
}


local LastClick = 0

function Shoot()
	TimeError = 0
	if Equipped then
		MouseHeld = true

		local CurrentShot = tick()
		if Can_Shoot and not (Reloading or Safe or Running) and CurrentShot - LastClick >= FireRate then

			if Settings.Mode == "Explosive" and not GLChambered.Value
				or Slideback.Value or not Chambered.Value or Emperrado.Value then
				ArmaClone.Handle.Click:Play()
				return

			elseif Settings.OpenBolt then
				if Ammo.Value <= 0 then -- gun ran out of ammo but the bolt cranked back
					OBSlideClose()
					BeforeShot(FireRate) -- gun's bolt hits the barrel
					Chambered.Value = false
					return

				elseif ArmaClone.Bolt:FindFirstChild("SlideFire") then -- gun has ammo, trigger pulled, bolt forward
					ArmaClone.Bolt.SlideFire:Play()
				end
			end

			Can_Shoot = false
			LastClick = CurrentShot
			FireModeOutcomes[Settings.Mode]()
		end
	end

	Can_Shoot = true
	Update_Gui()
end









-- MOUSE BUTTON UP

function StopShooting()
	if Equipped then
		MouseHeld = false
		if Settings.AutoLoop and not Settings.OpenBolt then
			dprint("Mouse Up Stop Shooting")
			FireSoundsModule.StopLoops()
		end
	end
end








function FocusSight(setting)
	if setting then
		TweenService:Create(StatusClone.Efeitos.Aim,TweenInfo.new(.75),{ImageTransparency = 0}):Play()
	else
		TweenService:Create(StatusClone.Efeitos.Aim,TweenInfo.new(.3),{ImageTransparency = 1}):Play()
	end
end





function AimFunction()
	if Running and ServerConfig.AimDisablesRun then
		Sprinting.Value = false
		Running = false
	end
	local CanAim = (Equipped and stance > -2 and not Running and CanADS and not BlindFire) and not Aiming
	if CanAim and (Camera.Focus.p - Camera.CFrame.p).magnitude < 1 and (not Reloading or Settings.ChamberWhileAim) then
		if NVG and ArmaClone.AimPart:FindFirstChild("NVAim") and Bipod then
		else
			if Safe then
				Safe = false
				IdleAnim()
				Update_Gui()
			end
			AimBlur.NearIntensity = Settings.AimBlurIntensity

			AimBlur.FocusDistance = Settings.AimBlurDistance

			stance = 2
		
			Evt.Stance:FireServer(EvtStancePoses())
			Aiming = true
			UIS.MouseDeltaSensitivity = (Sens.Value/100)
			ArmaClone.Handle.AimDown:Play()

			if not NVG or ArmaClone.AimPart:FindFirstChild("NVAim") == nil then
				if ArmaClone:FindFirstChild('AimPart2') ~= nil then
					if AimPartMode == 1 then
						AimBlur.Enabled = true
						tweenFoV(Settings.ChangeFOV[1],120)
						FocusSight(Settings.FocusOnSight)
						if Settings.adsMesh1 then
--[[						TweenService:Create(ArmaClone.REG, TweenInfo.new(0), {Transparency = 1}):Play()
							if ArmaClone:FindFirstChild("REG2") then
								TweenService:Create(ArmaClone.REG2, TweenInfo.new(0), {Transparency = 1}):Play()
							end
							TweenService:Create(ArmaClone.ADS, TweenInfo.new(0), {Transparency = 0}):Play()
]]							
							DoAdsMesh(1)
						end
					elseif AimPartMode == 2 then
						tweenFoV(Settings.ChangeFOV[2],120)
						FocusSight(Settings.FocusOnSight2)
						stance = 4
						Evt.Stance:FireServer(EvtStancePoses())
						if Settings.adsMesh2 then
							DoAdsMesh(1)
						end
					end
				else
					if AimPartMode == 1 then
						AimBlur.Enabled = true
						tweenFoV(Settings.ChangeFOV[1],120)
						FocusSight(Settings.FocusOnSight)
						if Settings.adsMesh1 then
							DoAdsMesh(1)
						end
					elseif AimPartMode == 2 then
						tweenFoV(Settings.ChangeFOV[2],120)
						FocusSight(Settings.FocusOnSight2)
						if Settings.adsMesh2 then
							DoAdsMesh(1)
						end
					end
				end
			else
				tweenFoV(70,120)
				FocusSight(false)
			end
		end
	elseif Aiming and Equipped then
		stance = 0
		Evt.Stance:FireServer(EvtStancePoses())
		UIS.MouseDeltaSensitivity = 1
		ArmaClone.Handle.AimUp:Play()	
		tweenFoV(70,120)
		Aiming = false
		AimBlur.Enabled = false
		FocusSight(false)
		if Settings.adsMesh1 or Settings.adsMesh2 then
			DoAdsMesh(0)
		end
	end
	
	CallAimFunction()
end



--[[Mouse.Button2Up:Connect(function()
	if ServerConfig.HoldToADS and Equipped then
		RMBHeld = false
		if Aiming then
			stance = 0
			Evt.Stance:FireServer(EvtStancePoses())
			UIS.MouseDeltaSensitivity = 1
			ArmaClone.Handle.AimUp:Play()	
			tweenFoV(70,120)
			Aiming = false
				AimBlur.Enabled = false
			DoAdsMesh(0)
			FocusSight(false)
		end
	end
end)]]

function OnMB2Down()
	if Equipped then
		RMBHeld = not RMBHeld
		AimFunction()
		if Aiming then
			RMBHeld = true
		end
	end
end

--Mouse.Button2Down:connect(OnMB2Down)





Humanoid.Died:connect(function()
	dprint("ACS: humanoid died...")
	LocalPlayer.Character.Humanoid.Health = -1
	ResetWorkspace()
	Humanoid:UnequipTools()
	Evt.Rappel.CutEvent:FireServer()
	Unset()
	WhizzModule.Disconnect()
	dprint("Human died Function complete")
end)





local WaterBullet = false

function onStateChanged(_, state)

	local StarterGui = game:GetService("StarterGui")	

	if state == Enum.HumanoidStateType.Swimming then
		Swimming = true
		if Equipped then
			if Settings.Amphibious then
				Settings.BSpeed = math.max(Settings.BSpeed - 800,Settings.BSpeed/4)
				WaterBullet = true
			else
				Unset()
				Humanoid:UnequipTools()
			end
		end

	elseif state ~=  Enum.HumanoidStateType.Swimming then
		Swimming = false
		if Equipped then
			Settings.BSpeed = Settings.BSpeed
			WaterBullet = false
		end
	end

	if ServerConfig.EnableFallDamage then
		if state == Enum.HumanoidStateType.Freefall and not falling then
			RecoilCF = RecoilCF:Lerp(CFrame.new(math.random(.2,.3),4,.3) * CFrame.Angles(math.random(3,4),math.random(3,4),math.random(3,4)), .15)
			falling = true
			local curVel = 0
			local peak = 0

			while falling do
				curVel = HumanoidRootPart.Velocity.magnitude
				peak = peak + 1
				RunService.Heartbeat:Wait()
			end
			local damage = (curVel - (ServerConfig.MaxVelocity)) * ServerConfig.DamageMult
			if damage > 5 and peak > 20 then
				local hurtSound = PastaFX.FallDamage:Clone()
				hurtSound.Parent = LocalPlayer.PlayerGui
				hurtSound.Volume = damage/Humanoid.MaxHealth
				Debris:AddItem(hurtSound,hurtSound.TimeLength)
				hurtSound:Play()
				Evt.Damage:FireServer(Humanoid,damage,0,0,Id.."__"..LocalPlayer.UserId)
			end
		elseif state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Dead then
			falling = false
			RecoilCF = RecoilCF:Lerp(CFrame.new(math.random(.2,.3),-8,.3) * CFrame.Angles(math.random(3,4),math.random(3,4),math.random(3,4)), .15)
		end
	end
end

Humanoid.StateChanged:connect(onStateChanged)





local ServerBulletIDs: {string: {string: {data: {}?, active: boolean}?}?} = {}
-- {UserId: {BulletId: {}}}

function OnServerBullet(Player: Player, ID, Origin, BDrop, Velocity, MaxDist, Tracer, TracerColor, BulletFlare, BulletFlareColor, TracerExtra, BulletLight, BulletLightExtra)
	if Player ~= LocalPlayer and (Player.Character or Player.Name == "AI") then
		
		local UserId2 = tostring(Player.UserId)
		local Profile = ServerBulletIDs[UserId2]
		if not Profile then
			Profile = {}
			ServerBulletIDs[UserId2] = Profile
		end
		
		local BulletData = Profile[ID]
		if BulletData then
			Tracer, TracerColor, BulletFlare, BulletFlareColor, TracerExtra, BulletLight, BulletLightExtra = table.unpack(BulletData.data)
			BulletData.active = true
		else
			dprint("New Bullet!")
			BulletData = {data = {Tracer, TracerColor, BulletFlare, BulletFlareColor, TracerExtra, BulletLight, BulletLightExtra}, active = true}
			Profile[ID] = BulletData
		end
		
		dprint(Utils.V3string(Origin, "Firing Server bullet at") .. Utils.V3string(Velocity.Unit, "\nDirection") .. " \nSpeed: " .. Velocity.Magnitude)
		
		local NewBullet = Engine.FX.Bullet:Clone()
		NewBullet.Name = Player.Name .. "_Bullet"
		NewBullet.Parent = ACS_Storage.Server
		NewBullet.Position = Origin

		if Tracer then
			task.spawn(function()
				if TracerExtra.Delay then
					task.wait(TracerExtra.Delay)
				end
				if not NewBullet then return end

				newTracer(NewBullet, ColorSequence.new(TracerColor), TracerExtra.Width or 0.2, TracerExtra.Life or 0.05, TracerExtra.LE or 1, TracerExtra.LI or 0, TracerExtra.Full, TracerExtra.Texture)
			end)
		end

		if BulletFlare then
			local flare = Instance.new("BillboardGui")
			flare.Adornee = NewBullet

			local size = Utils.RANDF(42.5, 5)
			flare.Size = UDim2.new(size, 0, size, 0)
			flare.LightInfluence = 0
			flare.Enabled = true

			local label = Instance.new("ImageLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, 0, 1, 0)
			label.Position = UDim2.new(0, 0, 0, 0)
			label.Image = "http://www.roblox.com/asset/?id=1047066405"
			label.ImageColor3 = BulletFlareColor
			label.ImageTransparency = math.random(2, 5)/15

			label.Parent = flare
			flare.Parent = NewBullet
		end

		if BulletLight then
			local BulletLight = Instance.new("PointLight")
			BulletLight.Brightness = BulletLightExtra.Brightness or 1
			BulletLight.Color = BulletLightExtra.Color or BulletFlareColor
			BulletLight.Range = BulletLightExtra.Range or 10
			BulletLight.Shadows = true
			BulletLight.Parent = NewBullet
		end
		
		local Projectile = ProjectileModule.new(Origin, Velocity, Vector3.yAxis * -196.2 * BDrop)

		local _ignore = {Player.Character, NewBullet, ACS_Storage}
		local _params = RaycastParams.new()
		_params.FilterDescendantsInstances = _ignore
		_params.FilterType = Enum.RaycastFilterType.Exclude
		_params.IgnoreWater = ServerConfig.IgnoreWater

		local pos = Origin
		local c = 0
		while BulletData.active and NewBullet do
			local step = RunService.Stepped:Wait()
			local newpos = Projectile.Position
			NewBullet.CFrame = CFrame.lookAt(newpos, newpos * 2 - pos)
			if ServerConfig.ServerBulletThrottle then
				if c == 0 then
					c = Throttle(step)
				else
					c = c - 1
				end
			end
			
			BulletData.active = true
			if c == 0 then
				local res = workspace:Raycast(pos, newpos - pos, _params)
				
				--[[local a = Instance.new("Part")
				a.Anchored = true
				a.Size = Vector3.new(.5,.5,.5)
				a.Color = Color3.fromRGB(ID * 37 % 256, ID * 71 % 256, ID * 123 % 256)
				a.Parent = workspace
				a.CanCollide = false
				a.Position = pos

				local b = Instance.new("Part")
				b.Anchored = true
				b.Size = Vector3.new(.5,.5,.5)
				b.Color = Color3.fromRGB(ID * 37 % 256, ID * 71 % 256, ID * 123 % 256)
				b.Parent = workspace
				b.CanCollide = false
				b.Position = newpos

				local bb = Instance.new("Beam")
				bb.Attachment0 = Instance.new("Attachment", a)
				bb.Attachment1 = Instance.new("Attachment", b)
				bb.Texture = "rbxassetid://5352896021"
				bb.Color = ColorSequence.new(Color3.fromRGB(ID * 37 % 256, ID * 71 % 256, ID * 123 % 256))
				bb.FaceCamera = true
				bb.Width0 = .5
				bb.Width1 = 1
				bb.Parent = a]]
				
				if res or (Origin - pos).Magnitude > MaxDist then
					BulletData.active = false
					NewBullet:Destroy()
					dprint(ID .. ": Server Bullet Stopped")
				else
					pos = newpos
				end
			end
		end
		
		task.wait(10)
		if not BulletData.active then
			dprint(ID .. ": Deleting bullet data")
			Profile[ID] = nil
		end
	end
end

-- Evt.ServerBullet:FireAllClients(Player, ID, Origin, BDrop, Velocity, MaxDist, Tracer, TracerColor, BulletFlare, BulletFlareColor, TracerExtra, BulletLight, BulletLightExtra)
Evt.ServerBullet.OnClientEvent:Connect(OnServerBullet)

local AI_IDCounter = 0
-- Evt.ServerBullet:FireAllClients(Player, BulletCF, Tracer, BDrop, Velocity, TracerColor,Ray_Ignore,BulletFlare,BulletFlareColor)
Evt.ACS_AI.AIBullet.OnClientEvent:Connect(function(AIChar, BulletCF, Tracer, BDrop, BSpeed, Direction, TracerColor, Ray_Ignore, BulletFlare, BulletFlareColor)
	local Plr = {
		Character = AIChar,
		Name = (AIChar and AIChar.Name) or "AI",
		UserId = -1,
	}
	local ID = tostring(AI_IDCounter)
	AI_IDCounter += 1
	OnServerBullet(Plr, ID, BulletCF.Position, BDrop, Direction.Unit * BSpeed, 10000, Tracer, TracerColor, BulletFlare, BulletFlareColor, {Full = true}, nil, {})
end)





Evt.ACS_AI.AIShoot.OnClientEvent:Connect(function(Gun, PlaySoundClientside)
	
	if PlaySoundClientside then
		task.delay((Gun.Position - (Head or Camera).Position).Magnitude / ServerConfig.SpeedOfSound, function()
			for i, v in pairs(Gun:GetChildren()) do
				if v:IsA("Sound") and v.Name == "Fire" or string.sub(v.Name, 1, 4) == "Echo" then
					v:Play()
				end
			end
		end)
	end

	for _, v in pairs(Gun.Muzzle:GetChildren()) do
		if v:IsA("Motor6D") then
		elseif string.sub(v.Name,1, 7) == "FlashFX" or string.sub(v.Name,1, 5) == "Smoke" then
			v.Enabled = true
		end
	end
	
	task.wait(1 / 30)

	for _, v in pairs(Gun.Muzzle:GetChildren()) do
		if v:IsA("Motor6D") then
		elseif string.sub(v.Name,1, 7) == "FlashFX" or string.sub(v.Name,1, 5) == "Smoke" then
			v.Enabled = false
		end
	end
end)













------------------------------------------------------------
--\Doors Update
------------------------------------------------------------
local DoorsFolder = ACS_Storage:FindFirstChild("Doors")

local mDistance = 5
local DoorKey = nil

function getNearest()
	local nearest = nil
	local minDistance = mDistance

	local LowerTorso = Character.LowerTorso

	for I,Door in pairs (DoorsFolder:GetChildren()) do
		local Knob = Door.Door:FindFirstChild("Knob")
		if Knob then
			local distance = (Knob.Position - LowerTorso.Position).Magnitude

			if distance < minDistance then
				nearest = Door
				minDistance = distance
			end
		end
	end
	return nearest
end

--[[function Interact(actionName, inputState, inputObj)
	if inputState ~= Enum.UserInputState.Begin then return end

	local nearestDoor = getNearest()

	if nearestDoor == nil then return end

	if (nearestDoor.Door.Knob.Position - Character.LowerTorso.Position).magnitude <= mDistance then
		if nearestDoor then
			if nearestDoor:FindFirstChild("RequiresKey") then
				Key = nearestDoor.RequiresKey.Value
			else
				Key = nil
			end
			Evt.DoorEvent:FireServer(nearestDoor,2,Key)
		end
	end
end]]


function GetNearest(parts, maxDistance,Part)
	local closestPart
	local minDistance = maxDistance
	for _, partToFace in pairs(parts) do
		local distance = (Part.Position - partToFace.Position).magnitude
		if distance < minDistance then
			closestPart = partToFace
			minDistance = distance
		end
	end
	return closestPart
end

--CAS:BindAction("Interact", Interact, false, Enum.KeyCode.G)

Evt.Rappel.PlaceEvent.OnClientEvent:Connect(function(Part)
	local Align = Instance.new('AlignOrientation')
	Align.Parent = Part
	Align.PrimaryAxisOnly = true
	Align.RigidityEnabled = true
	Align.Attachment0 = Character.LowerTorso.WaistCenterAttachment
	Align.Attachment1 = HeadBase:FindFirstChild("Attachment")
end)







local FireModeWheel = {
	"Safe",
	"Bolt-Action",
	"Pump-Action",
	"Semi",
	"Burst",
	"Auto",
	"Explosive",
}



function FireMode()
	if Equipped and not Reloading and not AnimDebounce and Settings.FireModes.ChangeFiremode then
		local FireModeSound = ArmaClone.Handle:FindFirstChild("FireMode") or ArmaClone.Handle.SafetyClick
		FireModeSound:Play()

		local PrevFireMode = Settings.Mode


		-- this bit over here will cycle over all firemodes (in order as declared in FireModeWheel)
		local i = table.find(FireModeWheel,Settings.Mode)
		if i < #FireModeWheel then
			for j = i+1, #FireModeWheel do
				if Settings.FireModes[FireModeWheel[j]] then
					Settings.Mode = FireModeWheel[j]
					break
				end
			end
		end
		if Settings.Mode == PrevFireMode then
			for j = 1, i-1 do
				if Settings.FireModes[FireModeWheel[j]] then
					Settings.Mode = FireModeWheel[j]
					break
				end
			end
		end


		FireMAnim(PrevFireMode, Settings.Mode)
		Update_Gui()
	end
end




function CheckGunFull()
	return (Settings.IncludeChamberedBullet and Ammo.Value == Settings.Ammo + 1 or not Settings.IncludeChamberedBullet and Ammo.Value == Settings.Ammo)
end

function InsertShell()
	if (StoredAmmo.Value > 0) and not AnimDebounce then
		ShellInsertAnim()
	end
end

function ReloadAimOff()
	if Aiming and not Settings.ChamberWhileAim then
		AimFunction()
	end
end

function ReloadAimOn()
	if Running then
		RMBHeld = false
	end
	if not Aiming and RMBHeld then
		AimFunction()
	end
end

function IdleIfRunning()
	if Safe or Running then
		Safe = false
		stance = 0
		Evt.Stance:FireServer(EvtStancePoses())
		IdleAnim()
		Update_Gui()
		task.wait(Settings.IdleTime or 0.3)
	end
end

function SetReloadOn()
	MouseHeld = false
	Can_Shoot = false
	Reloading = true
	ReloadAimOff()
	IdleIfRunning()
end

function SetReloadOff()
	Sprint()
	Update_Gui()

	Can_Shoot = true
	Reloading = false
	ReloadAimOn()
end

function Reload()
	if not Equipped or stance <= -2 then
		return
	end

	CancelReload = false
	if Reloading then
		if AnimDebounce and Settings.ReloadType == 2 and not CancelReload then
			CancelReload = true
			Sprint()
			Update_Gui()
			task.wait(0.3)
		end
	else
		if Settings.Mode == "Explosive" and GLAmmo.Value > 0 and not GLChambered.Value then
			SetReloadOn()
			GLReloadAnim()

			SetReloadOff()

		elseif StoredAmmo.Value > 0 then
			if CheckGunFull() then
				return
			end

			SetReloadOn()

			if Settings.ReloadType == 1 then

				if not Chambered.Value and Settings.ChamberBeforeReload then
					ChamberAnim()
				end

				ReloadAnim()

			elseif Settings.ReloadType == 2 then

				if Ammo.Value == Settings.Ammo and Settings.IncludeChamberedBullet then
					InsertShell()
				else
					for i = 1, Settings.Ammo - Ammo.Value do
						if CancelReload then break end
						InsertShell()
					end
				end

				CancelReload = false

			end

			if not Chambered.Value and Settings.FastReload then
				if Slideback.Value then
					ChamberBKAnim()
				else
					ChamberAnim()
				end
			end

			SetReloadOff()
		end
	end
end



function Chamber()
	if not Equipped or stance <= -2 then
		return
	end
	if Chambered.Value and (Settings.OpenBolt and not Settings.RedundantChamber) then
		return -- stop redundant chambering --> inside the engine
	end

	if not Reloading then
		if Settings.Mode == "Safe" then
			if Settings.AutoSwitchFromSafe then
				FireMode()
			elseif Settings.SafeDisablesChambering then
				return
			end
		end
		Update_Gui()

		SetReloadOn()

		if Slideback.Value then
			ChamberBKAnim()
		else
			ChamberAnim()
		end
		SetReloadOff()
	end
end






function FOSStr(AimMode)
	if AimMode > 1 then
		return "FocusOnSight" .. AimMode
	else
		return "FocusOnSight"
	end
end

function ChangeZoom()
	if Equipped and not AnimDebounce and not Reloading and not (NVG and ArmaClone.AimPart:FindFirstChild("NVAim")) then
		if AimPartMode == 1 then
			AimPartMode = 2
		elseif AimPartMode == 2 then
			AimBlur.Enabled = true
			AimPartMode = 1
		end

		if Aiming then
			tweenFoV(Settings.ChangeFOV[AimPartMode],120)

			if Settings[FOSStr(AimPartMode)] and Aiming then
				TweenService:Create(StatusClone.Efeitos.Aim,TweenInfo.new(.75),{ImageTransparency = 0}):Play()
			else
				TweenService:Create(StatusClone.Efeitos.Aim,TweenInfo.new(.3),{ImageTransparency = 1}):Play()
			end

			if Settings["adsMesh"..AimPartMode] then
				DoAdsMesh(1)
			else
				DoAdsMesh(0)
			end

		else
			TweenService:Create(StatusClone.Efeitos.Aim,TweenInfo.new(.3),{ImageTransparency = 1}):Play()

		end
		if Settings.ADS2Image and  Settings.ADS1Image then	local SightGuis = ArmaClone.ProjectorSight2.SurfaceGui
		local Reticle  = SightGuis.ClippingFrame.Reticle
		local SightGui = ArmaClone.ProjectorSight.SurfaceGui
			if Settings.LPVO then
				if AimPartMode == 2 then
					Reticle.Image	= Settings.ADS2Image
					ArmaClone.Handle.Click:Play()
					ZoomAnim()
				else
					Reticle.Image	= Settings.ADS1Image
					ArmaClone.Handle.Click:Play()
					UnZoomAnim()

				end

				Sprint()
				end
	else	if Settings.ZoomAnim then
			if AimPartMode == 2 then
				ZoomAnim()
			else
				UnZoomAnim()
	
			end

			Sprint()
		end
	end
end
end


function ZeroFunction(ozero)
	if Settings.ManualZeroSound then
	elseif ArmaClone:FindFirstChild("ZeroSound") then
		ArmaClone.ZeroSound.Click:Play()
	else
		ArmaClone.Handle.Click:Play()
	end

	Update_Gui()
	if Anims.ZeroAnim then
		SetReloadOn()
		ZeroAnim(ozero, Zeroing.Value)
		SetReloadOff()
	end
end






----------------------------------------------------------------------------------------------
------------------------------------[TECLAS]--------------------------------------------------
----------------------------------------------------------------------------------------------


local Laserdebounce = false
local ActionTable = {
	Shoot = Shoot,
	Aim = OnMB2Down,
	
	Door = function()
		if Reloading or AnimDebounce then return end
		
		local nearestDoor = getNearest()
		if not nearestDoor then return end

		if (nearestDoor.Door.Knob.Position - Character.LowerTorso.Position).magnitude <= mDistance then
			if nearestDoor then
				if nearestDoor:FindFirstChild("RequiresKey") then
					DoorKey = nearestDoor.RequiresKey.Value
				else
					DoorKey = nil
				end
				Evt.DoorEvent:FireServer(nearestDoor, 2, DoorKey)
			end
		end
	end,

	FireMode = FireMode,
	Zoom = ChangeZoom,

	ZeroDown = function()
		if Equipped and Zeroing.Value > Zeroing.MinValue then
			local ozero = Zeroing.Value
			Zeroing.Value = Zeroing.Value - (Settings.ZeroingIncrement or 100)
			ZeroFunction(ozero)
		end
	end,

	ZeroUp = function()
		if Equipped and Zeroing.Value < Zeroing.MaxValue then
			local ozero = Zeroing.Value
			Zeroing.Value = Zeroing.Value + (Settings.ZeroingIncrement or 100)
			ZeroFunction(ozero)
		end
	end,
	
	
	NVLightDown = function()
		if not Equipped or Reloading or AnimDebounce or IronSights or not ArmaClone:FindFirstChild('ProjectorSight') then
			return
		end
		
		local SightGui = ArmaClone.ProjectorSight.SurfaceGui
		local light = SightGui.LightInfluence
		
		if light < 1.2 then
			if light > -0.2 then
				SightGui.LightInfluence = light + .2
			else
				SightGui.LightInfluence = light + .4
			end
			ArmaClone.Handle.Click:Play()
		end
	end,
	
	NVLightUp = function()
		if not Equipped or Reloading or AnimDebounce or IronSights or not ArmaClone:FindFirstChild('ProjectorSight') then
			return
		end

		local SightGui = ArmaClone.ProjectorSight.SurfaceGui
		local light = SightGui.LightInfluence
		
		if light > -0.2 then
			--if light < 1.2 then
				SightGui.LightInfluence = light - .2
			--else
			--	SightGui.LightInfluence = light - .2
			--end
			ArmaClone.Handle.Click:Play()
		end
	end,

	Reload = Reload,
	Chamber = Chamber,

	MagCheck = function()
		if not Equipped or not Settings.CanCheckMag or Reloading or stance <= -2 then
			return
		end

		SetReloadOn()

		if Safe then
			Safe = false
			stance = 0
			Evt.Stance:FireServer(EvtStancePoses())
			IdleAnim()
			Update_Gui()
			task.wait(0.25)
		end

		CheckAnim()
		SetReloadOff()
	end,

	Laser = function()
		if Equipped and not AnimDebounce and not Reloading and ArmaClone:FindFirstChild("LaserPoint") then
			if ServerConfig.RealisticLaser and ArmaClone.LaserPoint:FindFirstChild("IR") ~= nil then
				if not LaserEnabled and not IRmode then
					LaserEnabled = not LaserEnabled
					IRmode = not IRmode

					if LaserEnabled then

						Evt.SVLaser:FireServer(Vector3.new(0,0,0),1,ArmaClone.LaserPoint.Color,ArmaTool)
						Pointer, PointerBG, PointerBGC, LaserSP, LaserEP, Laser = LaserModule.New(ArmaClone, IRmode)

						if ServerConfig.RealisticLaser then
							Laser.Enabled = false
						end

					else
						Evt.SVLaser:FireServer(Vector3.new(0,0,0),2,nil,ArmaTool,IRmode)
						Pointer:Destroy()
						PointerBG:Destroy()
						PointerBGC:Destroy()
						LaserSP:Destroy()
						LaserEP:Destroy()
						Laser:Destroy()
					end

				elseif LaserEnabled and IRmode then
					IRmode = not IRmode
				elseif LaserEnabled and not IRmode then
					LaserEnabled = not LaserEnabled

					if LaserEnabled then

						Evt.SVLaser:FireServer(Vector3.new(0,0,0),1,ArmaClone.LaserPoint.Color,ArmaTool)
						Pointer, PointerBG, PointerBGC, LaserSP, LaserEP, Laser = LaserModule.New(ArmaClone, IRmode)

						if ServerConfig.RealisticLaser then
							Laser.Enabled = false
						end

					else
						Evt.SVLaser:FireServer(Vector3.new(0,0,0),2,nil,ArmaTool,IRmode)
						Pointer:Destroy()
						PointerBG:Destroy()
						PointerBGC:Destroy()
						LaserSP:Destroy()
						LaserEP:Destroy()
						Laser:Destroy()
					end


				end
			else
				LaserEnabled = not LaserEnabled

				if LaserEnabled then

					Evt.SVLaser:FireServer(Vector3.new(0,0,0),1,ArmaClone.LaserPoint.Color,ArmaTool)
					Pointer, PointerBG, PointerBGC, LaserSP, LaserEP, Laser = LaserModule.New(ArmaClone, IRmode)

					if ServerConfig.RealisticLaser then
						Laser.Enabled = false
					end

				else
					Evt.SVLaser:FireServer(Vector3.new(0,0,0),2,nil,ArmaTool,IRmode)
					Pointer:Destroy()
					PointerBG:Destroy()
					PointerBGC:Destroy()
					LaserSP:Destroy()
					LaserEP:Destroy()
					Laser:Destroy()
				end

			end
			if ArmaClone.Handle:FindFirstChild("LaserOn") then ArmaClone.Handle.LaserOn:Play() 
			else
				ArmaClone.Handle.Click:Play()
			end
		end
	end,
	
	Flashlight = function()
		if Equipped and not AnimDebounce and not Reloading and ArmaClone:FindFirstChild("FlashPoint") then
			FlashlightEnabled = not FlashlightEnabled
			
			local Light = ArmaClone.FlashPoint.Light
			Light.Enabled = FlashlightEnabled
			local LightBeam = ArmaClone.FlashPoint:FindFirstChild("LightBeam")
		
			if LightBeam then
				LightBeam.Enabled = FlashlightEnabled
			end
			if ArmaClone.Handle:FindFirstChild("FlashOn") then ArmaClone.Handle.FlashOn:Play() 
			else
				ArmaClone.Handle.Click:Play()
			if FlashlightEnabled then
				Evt.SVFlash:FireServer(true, ArmaTool, Light.Angle, Light.Brightness, Light.Color, Light.Range)			
			else
				Evt.SVFlash:FireServer(false, ArmaTool, nil, nil, nil, nil)
			end
		end
end
	end,

	Silencer = function()
		if not Equipped or AnimDebounce or Reloading then
			return
		end

		local SilencerModel = FindSilencer(ArmaClone)
		if not SilencerModel then
			return
		end		

		Silencer.Value = not Silencer.Value
		Can_Shoot = false
		
		SetReloadOn()
		if Silencer.Value then
			SilencerOnAnim()
			SilencerModel.Transparency = 0
		else
			SilencerOffAnim()
			SilencerModel.Transparency = 1
		end
		SetReloadOff()
		
		Evt.SilencerEquip:FireServer(ArmaTool, Silencer.Value)
		Can_Shoot = true
	end,

	Bipod = function()
		if not Equipped or AnimDebounce or Reloading or not CanDeployBipod then
			return
		end
		
		local BipodPoint = ArmaClone:FindFirstChild("BipodPoint")
		if not BipodPoint then
			return
		end
		
		if Bipod then
			Bipod = false
			local BipodSound = BipodPoint:FindFirstChild("BipodRetract")
			if not Settings.ManualBipodSound and BipodSound then
				BipodSound:Play()
			end
			BipodUpAnim()
		else
			local BipodSound = BipodPoint:FindFirstChild("BipodDeploy")
			if not Settings.ManualBipodSound and BipodSound then
				BipodSound:Play()
			end
			BipodDownAnim()
			Bipod = true
		end
	end,
	
		

	NightVision = function()
		if Laserdebounce or not Character then
			return
		end

		local helmet = Character:FindFirstChild("Helmet")
		if not helmet then
			return
		end

		local nvg = helmet:FindFirstChild("Up")
		if not nvg then
			return
		end

		Laserdebounce = true
		task.delay(0.8, function()
			NVG = not NVG

			if Aiming and ArmaClone.AimPart:FindFirstChild("NVAim") then
				if NVG then
					AimBlur.Enabled = false
					tweenFoV(70, 120)
					TweenService:Create(StatusClone.Efeitos.Aim, TweenInfo.new(.3), {ImageTransparency = 1}):Play()
				else
					if AimPartMode == 1 then
						AimBlur.Enabled = true
						tweenFoV(Settings.ChangeFOV[1], 120)
						TweenService:Create(StatusClone.Efeitos.Aim, TweenInfo.new(.3), {ImageTransparency = 1}):Play()
					elseif AimPartMode == 2 then
						tweenFoV(Settings.ChangeFOV[2], 120)
						if Settings.FocusOnSight2 then
							TweenService:Create(StatusClone.Efeitos.Aim, TweenInfo.new(.75), {ImageTransparency = 0}):Play()
						else
							TweenService:Create(StatusClone.Efeitos.Aim, TweenInfo.new(.3), {ImageTransparency = 1}):Play()
						end
					end
				end
			end
			Laserdebounce = false
		end)
	end,
	
	BlindFire = function()
		if Equipped and not Aiming and not Bipod then
			BlindFire = not BlindFire
			if BlindFire then
				UIS.MouseDeltaSensitivity = 0.2
			else
				UIS.MouseDeltaSensitivity = 1
			end
		end
	end,
	
	-- [SHOULDER SWAP]
	ShoulderSwap = function()
		SwapShoulder()
	end,
	-- [/SHOULDER SWAP]
}

if _G.LeanPart then
	yahoo = HeadBase.CFrame
	yahoo2 = HeadBase.CFrame.p
	HeadBase.CFrame = HeadBase.CFrame * _G.LeanPart.CFrame
end

local onBegan = {
	MouseButton1 = function()
		if not Equipped or AnimDebounce then
			return
		end

		if ServerConfig.LMBReloadWhenEmpty and Ammo.Value == 0 then
			Reload()
		elseif ServerConfig.LMBChamberWhenJammed and (Emperrado.Value or not Chambered.Value) then
			Chamber()
		else
			Shoot()
		end
	end,
	
	MouseButton2 = OnMB2Down,
	
	Keyboard = function(Key: string)
		if wasd[Key] ~= nil then
			wasd[Key] = true
		end
		
		local Action = Keybinds[Key] or Keybinds[string.lower(Key)] or ""
		local KeyFunc = ActionTable[Action]
		dprint("Key pressed: " .. Key .. " | Action linked: " .. Action)
		if KeyFunc then
			KeyFunc()
		end
	end,
	GamePad1 = function(Btn: string)
		local Action = KeybindsGP[Btn] or ""
		local KeyFunc = ActionTable[Action]
		dprint("Button Pressed: " .. Btn .. " | Action linked: " .. Action)
		if KeyFunc then
			KeyFunc()
		end
	end,
}

UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- [SHOULDER SWAP]
	if input.UserInputType == Enum.UserInputType.Keyboard and string.lower(input.KeyCode.Name) == SHOULDER_SWAP_KEY then
		SwapShoulder()
		return
	end
	-- [/SHOULDER SWAP]
	
	local func = onBegan[input.UserInputType.Name]
	if func then
		func(input.KeyCode.Name)
	end
end)


function OnMB2Up()
	if ServerConfig.HoldToADS and Equipped then
		RMBHeld = false
		if Aiming then
			stance = 0
			Evt.Stance:FireServer(EvtStancePoses())
			UIS.MouseDeltaSensitivity = 1
			ArmaClone.Handle.AimUp:Play()	
			tweenFoV(70,120)
			Aiming = false
			AimBlur.Enabled = false
			DoAdsMesh(0)
			FocusSight(false)
			CallAimFunction()
		end
	end
end

local onEnded = {
	MouseButton1 = StopShooting,
	
	MouseButton2 = OnMB2Up,
	
	Keyboard = function(Key)
		if wasd[Key] ~= nil then
			wasd[Key] = false
		end
	end,
	
	GamePad1 = function(Key)
		local act = KeybindsGP[Key]
		if act == "Aim" then
			OnMB2Up()
		end
	end,
}

UIS.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local func = onEnded[input.UserInputType.Name]
	if func then
		func(input.KeyCode.Name)
	end
end)





-- wheel stance minimum: -2 --> 1
local WheelStance = {
	[1] = function()
		Patrol()
	end,
	[2] = function()
		StanceDown()
	end,
	[3] = function()
		Safe = false
		IdleAnim()
	end,
	[4] = function()
		StanceUp()
	end,
}

UIS.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if input.Position.Z > 0 then -- wheel forward
			if not Equipped then return end

			if Aiming then
				if Sens.Value < Sens.MaxValue then
					Sens.Value = Sens.Value + 5
					Update_Gui()
					UIS.MouseDeltaSensitivity = (Sens.Value/100)
				end

			else
				if not (Reloading or Running) then
					MouseHeld = false
					if stance < 1 then
						Safe = true
						stance = stance + 1
						Evt.Stance:FireServer(EvtStancePoses())

						WheelStance[stance + 3]()

					end
					Update_Gui()
				end
			end
		elseif input.Position.Z < 0 then -- wheel backward
			if not Equipped then return end

			if Aiming then
				if Sens.Value > Sens.MinValue then
					Sens.Value = Sens.Value - 5
					Update_Gui()
					UIS.MouseDeltaSensitivity = (Sens.Value/100)
				end

			else
				if not (Reloading or Running) then
					MouseHeld = false
					if stance > -2 and stance < 2 then
						Safe = true
						stance = stance - 1
						Evt.Stance:FireServer(EvtStancePoses())

						WheelStance[stance + 3]()

					end
					Update_Gui()
				end
			end
		end
	end
end)





---------------------------------------------------
--// CLIENT ANIMS
---------------------------------------------------

function CheckForServerAnims()
	return (ServerConfig.ServerAnimationsEnabled or Settings.ForceServerAnimations) and Var:FindFirstChild("ServerAnimations")
end

local Speedo = nil
-- I don't know what I'm looking at...

function IdleAnim()
		fallback(Anims,"IdleAnim",fbAnims.IdleAnim)(Character, Speedo, {
			AnimBaseW,
			RAW,
			LAW,
			AnimBase.GripW,
			ArmaClone,
			Left_Arm,
			Right_Arm,
			RLAW,
			LLAW,
			RHW,
			LHW,
		})
end

function StanceDown()
	fallback(Anims,"StanceDown",fbAnims.StanceDown)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
end

function StanceUp()
	fallback(Anims,"StanceUp",fbAnims.StanceUp)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
end

function Patrol()
	fallback(Anims,"Patrol",fbAnims.Patrol)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
end

function SprintAnim()
	fallback(Anims,"SprintAnim",fbAnims.SprintAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
end

function EquipAnim()
	AnimDebounce = true
	Can_Shoot = false
	Reloading = true
	if CheckForServerAnims() then
		Evt.Anims:FireServer("EquipAnim", ArmaTool)
	end
	fallback(Anims,"EquipAnim",fbAnims.EquipAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
		StoredAmmo,
		Ammo,
		Settings,
	})
	Reloading = false
	Can_Shoot = true
	AnimDebounce = false
end



function ChamberProcess()
	Slideback.Value = false
	if Ammo.Value > 0 then
		if Chambered.Value == true then
			if Emperrado.Value == true then
				ShellEjectionModule.EjectShell(ArmaClone, Settings.BulletType)
				Ammo.Value = Ammo.Value - 1
				Emperrado.Value = false
			elseif not Settings.OpenBolt then
				ShellEjectionModule.EjectShell(ArmaClone, Settings.BulletType)
				Ammo.Value = Ammo.Value - 1
			end
			if Ammo.Value <= 0 and not Settings.OpenBolt then
				Chambered.Value = false
				if Settings.LockWhenChamber then
					Slideback.Value = true
				end
			end
		else
			Chambered.Value = true
			Emperrado.Value = false
		end
	elseif Settings.OpenBolt then
		Chambered.Value = true
		Emperrado.Value = false
	else
		Chambered.Value = false
		if Settings.LockWhenChamber then
			Slideback.Value = true
		end
	end
end

function ChamberAnim()
	AnimDebounce = true

	if CheckForServerAnims() then
	

		Evt.Anims:FireServer("ChamberAnim", ArmaTool, Utils.MakeVarDict(Ammo, Chambered, Emperrado))
	end
	


	local ChamberedStatus = {Value = false}

	fallback(Anims,"ChamberAnim",fbAnims.ChamberAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Right_Arm,
		Left_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
		ChamberProcess,
		ChamberedStatus,
	})


	if not ChamberedStatus.Value then
		ChamberProcess()
	end
	AnimDebounce = false
	end

function ZoomAnim()
	fallback(Anims,"ZoomAnim",fbAnims.ZoomAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
end

function UnZoomAnim()
	fallback(Anims,"UnZoomAnim",fbAnims.UnZoomAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
end

function ChamberBKAnim()
	AnimDebounce = true

	if CheckForServerAnims() then
		Evt.Anims:FireServer("ChamberBKAnim", ArmaTool, Utils.MakeVarDict(Ammo, Chambered, Emperrado))
	end

	fallback(Anims,"ChamberBKAnim",fbAnims.ChamberBKAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
	local ammoleft = (Ammo.Value > 0)
	if not (not ammoleft and Settings.LockWhenChamberBK) then -- if lockwhenchamberbk is set to true, slideback will not disable while empty
		Slideback.Value = false
		if ammoleft then
			Chambered.Value = true
		end
	end

	AnimDebounce = false
end

function CheckMagFunction()
	GuiModule.CheckMagFunction(ArmaClone, Settings, Ammo.Value)
end

function CheckAnim()
	AnimDebounce = true
	if CheckForServerAnims() then
		Evt.Anims:FireServer("CheckAnim", ArmaTool)
	end
	if not Settings.ManualMagCheck then
		CheckMagFunction()
	end
	fallback(Anims,"CheckAnim",fbAnims.CheckAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		StoredAmmo,
		Ammo,
		Settings,
		Chambered,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
		CheckMagFunction,
	})
	AnimDebounce = false
end

function ShellInsertAnim()
	AnimDebounce = true

	if CheckForServerAnims() then
		Evt.Anims:FireServer("ShellInsertAnim", ArmaTool, Utils.MakeVarDict(StoredAmmo, Ammo, Chambered, Emperrado))
	end

	fallback(Anims, "ShellInsertAnim", fbAnims.ShellInsertAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		StoredAmmo,
		Ammo,
		Settings,
		Chambered,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})

	Evt.Recarregar:FireServer(ArmaTool, Utils.MakeVarDict(StoredAmmo, Ammo, Chambered, Emperrado))
	AnimDebounce = false
end

function ReloadAnim()
	AnimDebounce = true

	if CheckForServerAnims() then
		Evt.Anims:FireServer("ReloadAnim", ArmaTool, Utils.MakeVarDict(StoredAmmo, Ammo, Chambered, Emperrado, Slideback))
	end

	fallback(Anims,"ReloadAnim", fbAnims.ReloadAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		StoredAmmo,
		Ammo,
		Settings,
		Chambered,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})

	Evt.Recarregar:FireServer(ArmaTool, Utils.MakeVarDict(StoredAmmo, Ammo, Chambered, Emperrado))
	AnimDebounce = false
end

function SilencerOnAnim()
	AnimDebounce = true
	if CheckForServerAnims() then
		Evt.Anims:FireServer("SilencerOnAnim", ArmaTool)
	end
	fallback(Anims,"SilencerOnAnim", fbAnims.SilencerOnAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
	AnimDebounce = false
end

function SilencerOffAnim()
	AnimDebounce = true
	if CheckForServerAnims() then
		Evt.Anims:FireServer("SilencerOffAnim", ArmaTool)
	end
	fallback(Anims,"SilencerOffAnim", fbAnims.SilencerOffAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
	AnimDebounce = false
end

function FireAnim()
	if CheckForServerAnims() and require(Var.ServerAnimations).FireAnim then -- extra check clientside to not waste server space
		Evt.Anims:FireServer("FireAnim", ArmaTool)
	end
	fallback(Anims,"FireAnim", fbAnims.FireAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		StoredAmmo,
		Ammo,
		Settings,
		Chambered,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
end

function StepAnim()
	if CheckForServerAnims() and require(Var.ServerAnimations).StepAnim then -- extra check clientside to not waste server space
		Evt.Anims:FireServer("StepAnim", ArmaTool)
	end
	Anims.StepAnim(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		StoredAmmo,
		Ammo,
		Settings,
		Chambered,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
end

function FireMAnim(PrevFireMode, FireMode)
	AnimDebounce = true
	if CheckForServerAnims() then
		Evt.Anims:FireServer("FireMAnim", ArmaTool)
	end
	fallback(Anims,"FireMAnim",fbAnims.FireMAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
		FireMode,
		PrevFireMode,
	})
	AnimDebounce = false
end

function BipodDownAnim()
	AnimDebounce = true
	if CheckForServerAnims() then
		Evt.Anims:FireServer("BipodDown", ArmaTool)
	end
	fallback(Anims,"BipodDown",fbAnims.BipodDown)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
	AnimDebounce = false
end

function BipodUpAnim()
	AnimDebounce = true
	if CheckForServerAnims() then
		Evt.Anims:FireServer("BipodUp", ArmaTool)
	end
	fallback(Anims,"BipodUp",fbAnims.BipodUp)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
	AnimDebounce = false
end

function BipodLiftedAnim()
	AnimDebounce = true
	if CheckForServerAnims() then
		Evt.Anims:FireServer("BipodLifted", ArmaTool)
	end
	fallback(Anims,"BipodLifted",fbAnims.BipodLifted)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Settings,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
	AnimDebounce = false
end

function GLReloadAnim()
	AnimDebounce = true
	if CheckForServerAnims() then
		Evt.Anims:FireServer("GLReloadAnim", ArmaTool, Utils.MakeVarDict(GLChambered, GLAmmo))
	end
	fallback(Anims,"GLReloadAnim",fbAnims.GLReloadAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		StoredAmmo,
		Ammo,
		Settings,
		Chambered,
		Left_Arm,
		Right_Arm,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
	
	GLAmmo.Value -= 1
	GLChambered.Value = true
	
	Evt.Recarregar:FireServer(ArmaTool, Utils.MakeVarDict(GLChambered, GLAmmo))
	AnimDebounce = false
end

function ZeroAnim(OldZero, NewZero)
	if CheckForServerAnims() then
		Evt.Anims:FireServer("ZeroAnim", ArmaTool)
	end
	fallback(Anims,"ZeroAnim",fbAnims.IdleAnim)(Character, Speedo, {
		AnimBaseW,
		RAW,
		LAW,
		AnimBase.GripW,
		ArmaClone,
		Left_Arm,
		Right_Arm,
		OldZero,
		NewZero,
		RLAW,
		LLAW,
		RHW,
		LHW,
	})
end









Evt.Anims.OnClientEvent:Connect(function(Player, Anim, Tool, VarDict)
	if not debugtp.Value and Player == LocalPlayer or not Tool then
		return
	end
	
	local var = Tool.ACS_Modulo.Variaveis
	local anims = var.ServerAnimations
	if not anims then return end

	local func = require(anims)[Anim]
	if not func then return end

	local AnimBase = Player.Character.AnimBase

	local Arma = Player.Character:WaitForChild("S"..Tool.Name)
	local GripW = Arma.Grip.GripW
	local Settings = require(var.Settings)

	local Joints = {
		RS = AnimBase.RAW,
		LS = AnimBase.LAW,
		RE = AnimBase.RLAW,
		LE = AnimBase.LLAW,
		RW = AnimBase.RHW,
		LW = AnimBase.LHW,
		GripW = GripW,
	}

	local objs = {}

	if VarDict then
		for key, value in pairs(VarDict) do
			var[key].Value = value
			objs[key] = var[key]
		end
	else
		objs = {
			Ammo = var.Ammo,
			StoredAmmo = var.StoredAmmo,
			Chambered = var.Chambered,
			Emperrado = var.Emperrado,
		}
	end

	func(Player, Arma, Joints, objs, Settings)
end)



Evt.Stance.OnClientEvent:Connect(function(Player, Poses)
	if not debugtp.Value and Player == LocalPlayer or not Poses then
		return
	end

	local Character = Player.Character
	if not Character or Character.Humanoid.Health <= 0 then
		return
	end

	local AnimBase = Character:FindFirstChild("AnimBase")
	if not AnimBase then
		return
	end

	local Right_Weld = AnimBase:FindFirstChild("RAW")
	local Left_Weld = AnimBase:FindFirstChild("LAW")
	if not Right_Weld or not Left_Weld then
		return
	end

	local RightElbow = AnimBase.RLAW
	local RightWrist = AnimBase.RHW

	local LeftElbow = AnimBase.LLAW
	local LeftWrist = AnimBase.LHW

	local RECFrame =  CFrame.new(0,Character.RightUpperArm.Size.Y/2+.008,0)
	local RWCFrame =  CFrame.new(0,Character.RightLowerArm.Size.Y/2+.1,0)

	local LECFrame =  CFrame.new(0,Character.LeftUpperArm.Size.Y/2+.008,0)
	local LWCFrame =  CFrame.new(0,Character.LeftLowerArm.Size.Y/2+.1,0)

	local TInfo = TweenInfo.new(0.3)

	TweenService:Create(Right_Weld, TInfo, {C1 = Poses[1]}):Play()
	TweenService:Create(RightElbow, TInfo, {C1 = RECFrame * Poses[2]}):Play()
	TweenService:Create(RightWrist, TInfo, {C1 = RWCFrame * Poses[3]}):Play()

	TweenService:Create(Left_Weld, TInfo, {C1 = Poses[4]} ):Play()
	TweenService:Create(LeftElbow, TInfo, {C1 = LECFrame * Poses[5]}):Play()
	TweenService:Create(LeftWrist, TInfo, {C1 = LWCFrame * Poses[6]}):Play()
end)




























-- Mobile Support


if UIS.TouchEnabled then

	local StartedShooting
	local MModule = require(Mod.Mobile)
	local Buttons = {}

	Buttons.Aim = MModule.AddButton(LocalPlayer,"Aim","Aim",
		UDim2.new(0,100,.5,-50),
		UDim2.new(0,50,0,50))
	MModule.Tap(Buttons.Aim,OnMB2Down)

	Buttons.Reload = MModule.AddButton(LocalPlayer,"Reload","Reload",
		UDim2.new(1,-50,.5,-50),
		UDim2.new(0,50,0,50))
	MModule.Tap(Buttons.Reload,Reload)

	Buttons.Chamber = MModule.AddButton(LocalPlayer,"Chamber","Bolt",
		UDim2.new(1,-100,.5,-50),
		UDim2.new(0,50,0,50))
	MModule.Tap(Buttons.Chamber,Chamber)

	Buttons.FireMode = MModule.AddButton(LocalPlayer,"FireMode","Mode",
		UDim2.new(1, -150,.5, -50),
		UDim2.new(0,50,0,50))
	MModule.Tap(Buttons.FireMode,FireMode)

	Buttons.Shoot = MModule.AddButton(LocalPlayer,"Shoot","Shoot",
		UDim2.new(1,-100,.5,25),
		UDim2.new(0,80,0,80))
	MModule.Tap(Buttons.Shoot,function()
		StartedShooting = true
	end)
	MModule.Input(Buttons.Shoot,function()
		if StartedShooting then
			Shoot()
		end
	end,StopShooting)


	if ServerConfig.HideButtonsWhenUnequipped then
		local function ButtonCheck()
			if Equipped then
				Buttons.Aim.Visible = true
				Buttons.Reload.Visible = true
				Buttons.Chamber.Visible = true
				Buttons.FireMode.Visible = true
				Buttons.Shoot.Visible = true
			else
				Buttons.Aim.Visible = false
				Buttons.Reload.Visible = false
				Buttons.Chamber.Visible = false
				Buttons.FireMode.Visible = false
				Buttons.Shoot.Visible = false
			end
		end
		RunService.Heartbeat:Connect(ButtonCheck)
	end
end
Unset() -- reset viewmodel, etc if respawning/refreshing
while true do
	math.randomseed(tick())
	wait(math.random(40,80))
	ResetWorkspace()
end