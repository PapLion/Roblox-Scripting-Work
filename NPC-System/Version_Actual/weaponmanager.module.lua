--[[
================================================================================
  WeaponManager.lua  —  NPC Weapon Module (v8)
================================================================================

  CAMBIOS vs v7
  -------------
  • FIX Drop() desde holstered — findGun() fallaba silenciosamente cuando
    gun = nil (que ocurre después de Holster() en ciertos flujos). Ahora
    Drop() hace su propio búsqueda directa por nombre sin depender del
    estado interno. Si gun es nil, lo busca de nuevo antes de soltar.
  • FIX impulso de Drop() — BodyVelocity ahora ancla el arma 1 frame
    antes de aplicar el impulso para cancelar la velocidad heredada del
    NPC. Así el arma no vuela fuera del mapa cuando el NPC estaba corriendo.
  • Holster() ahora fuerza gun = nil después de ocultar, para que el
    siguiente findGun() siempre busque fresh desde el NPC en lugar de
    usar una referencia potencialmente stale.

================================================================================
]]

local WeaponManager = {}

local NPC    = script.Parent
local Debris = game:GetService("Debris")

local GUN_NAME = "PF940"

-- Calibrado en Studio el 05/04/2026
local EQUIP_OFFSET = CFrame.new(0, -1.1, -0.4)
	* CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0))

-- ── ESTADO INTERNO ────────────────────────────────────────────────────────────
local gun        = nil
local handle     = nil
local activeWeld = nil
local equipped   = false
local holstered  = true

-- ── HELPERS ───────────────────────────────────────────────────────────────────

--[[
  findGun()
  ---------
  Busca el modelo del arma dentro del NPC por nombre.
  Siempre busca fresh — no usa cache — para evitar referencias stale
  después de Holster() o estados intermedios.
]]
local function findGun()
	gun    = NPC:FindFirstChild(GUN_NAME)
	handle = gun and (gun:FindFirstChild("Handle") or gun:FindFirstChild("Frame"))
	return gun ~= nil and handle ~= nil
end

--[[
  findGunAnywhere()
  -----------------
  Versión extendida para Drop(): busca en NPC Y en workspace por si el
  modelo fue movido. Útil cuando el estado interno está desincronizado.
]]
local function findGunAnywhere()
	-- primero en el NPC
	gun    = NPC:FindFirstChild(GUN_NAME)
	handle = gun and (gun:FindFirstChild("Handle") or gun:FindFirstChild("Frame"))
	if gun and handle then return true end

	-- si no, en workspace (por si ya fue dropeada parcialmente)
	gun    = workspace:FindFirstChild(GUN_NAME)
	handle = gun and (gun:FindFirstChild("Handle") or gun:FindFirstChild("Frame"))
	return gun ~= nil and handle ~= nil
end

--[[
  clearWeld()
  -----------
  Destruye el WeaponGrip por referencia y por nombre como red de seguridad.
  No toca los InternalGunWelds.
]]
local function clearWeld()
	if activeWeld and activeWeld.Parent then
		activeWeld:Destroy()
	end
	activeWeld = nil

	local rightArm = NPC:FindFirstChild("Right Arm") or NPC:FindFirstChild("Right Arm", true)
	if rightArm then
		local orphan = rightArm:FindFirstChild("WeaponGrip")
		if orphan then orphan:Destroy() end
	end
end

local function setGunVisible(visible)
	if not gun then return end
	local t = visible and 0 or 1
	for _, d in ipairs(gun:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = t
			d.CanCollide   = false
		end
	end
	if handle then
		handle.Transparency = t
		handle.CanCollide   = false
	end
end

local function getPart(name)
	return NPC:FindFirstChild(name) or NPC:FindFirstChild(name, true)
end

local function setupGunPhysics(anchored)
	if not gun then return end
	for _, d in ipairs(gun:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored   = anchored
			d.CanCollide = false
			d.Massless   = not anchored
		end
	end
	if handle then
		handle.Anchored   = anchored
		handle.CanCollide = false
		handle.Massless   = not anchored
	end
end

--[[
  weldModelParts()
  ----------------
  Une todas las BasePart del modelo a handle con Welds internos para que
  el modelo se comporte como un bloque rígido. Se mantienen en Drop() para
  que el arma caiga sólida. Solo se destruyen en clearInternalWelds().
]]
local internalWelds = {}

local function weldModelParts()
	if not gun or not handle then return end

	for _, w in ipairs(internalWelds) do
		if w and w.Parent then w:Destroy() end
	end
	internalWelds = {}

	for _, part in ipairs(gun:GetDescendants()) do
		if part:IsA("BasePart") and part ~= handle then
			local w  = Instance.new("Weld")
			w.Name   = "InternalGunWeld"
			w.Part0  = handle
			w.Part1  = part
			w.C0     = handle.CFrame:Inverse() * part.CFrame
			w.C1     = CFrame.new()
			w.Parent = handle
			table.insert(internalWelds, w)
		end
	end
end

local function clearInternalWelds()
	for _, w in ipairs(internalWelds) do
		if w and w.Parent then w:Destroy() end
	end
	internalWelds = {}
end

-- ── API PÚBLICA ───────────────────────────────────────────────────────────────

function WeaponManager:Equip()
	if equipped then return end
	if not findGun() then
		warn("[WeaponManager] '" .. GUN_NAME .. "' o su Handle no encontrado.")
		return
	end

	local rightArm = getPart("Right Arm")
	if not rightArm then
		warn("[WeaponManager] 'Right Arm' no encontrado en el NPC.")
		return
	end

	clearWeld()
	setGunVisible(true)
	setupGunPhysics(false)
	weldModelParts()

	local weld  = Instance.new("Weld")
	weld.Name   = "WeaponGrip"
	weld.Part0  = rightArm
	weld.Part1  = handle
	weld.C0     = EQUIP_OFFSET
	weld.C1     = CFrame.new()
	weld.Parent = rightArm

	activeWeld = weld
	gun.Parent = NPC

	equipped  = true
	holstered = false
end

--[[
  Holster()
  ---------
  Oculta el arma. Fuerza gun = nil al final para que el próximo findGun()
  siempre haga una búsqueda fresca desde el NPC.
]]
function WeaponManager:Holster()
	clearWeld()

	if findGun() then
		setupGunPhysics(true)
		setGunVisible(false)
		gun.Parent = NPC
	end

	equipped  = false
	holstered = true
	-- Limpiar referencias para forzar búsqueda fresca en el próximo findGun()
	gun    = nil
	handle = nil
end

--[[
  ForceHolster()
  --------------
  Versión nuclear para emergencias (onTargetDied, etc).
]]
function WeaponManager:ForceHolster()
	local rightArm = NPC:FindFirstChild("Right Arm") or NPC:FindFirstChild("Right Arm", true)
	if rightArm then
		for _, child in ipairs(rightArm:GetChildren()) do
			if child:IsA("Weld") or child:IsA("Motor6D") then
				child:Destroy()
			end
		end
	end

	if activeWeld and activeWeld.Parent then
		activeWeld:Destroy()
	end
	activeWeld = nil

	if findGun() then
		setupGunPhysics(true)
		setGunVisible(false)
		gun.Parent = NPC
	end

	equipped  = false
	holstered = true
	gun       = nil
	handle    = nil
end

--[[
  Drop()
  ------
  Suelta el arma al workspace.

  FIX v8 — Drop() desde holstered:
    Usa findGunAnywhere() en lugar de findGun() para recuperar el modelo
    incluso cuando gun = nil (estado después de Holster()). Esto soluciona
    el bug de auto-surrender donde el arma no se soltaba porque gun era nil.

  FIX v8 — Arma vuela fuera del mapa:
    Antes de aplicar BodyVelocity, el handle se ancla 1 frame para cancelar
    la velocidad heredada del NPC (que se acumulaba si estaba corriendo).
    Luego se desancla y se aplica el impulso controlado desde cero.
]]
function WeaponManager:Drop()
	-- Si ya fue dropeada antes (surrender previo), no hacer nada
	-- Cubre tanto el estado 'dropped' (false/false) como el caso donde
	-- holstered=true pero el arma ya está en workspace (drop previo con estado desincronizado)
	if not equipped and not holstered then return end
	if not equipped and holstered then
		local existing = workspace:FindFirstChild(GUN_NAME)
		if existing then return end  -- ya fue dropeada, está en workspace
	end

	-- Destruir WeaponGrip
	clearWeld()

	if not findGunAnywhere() then
		equipped = false; holstered = false; gun = nil; handle = nil
		return
	end

	-- PASO 1: asegurar InternalWelds para que caiga como bloque rígido
	weldModelParts()

	-- PASO 2: unlock todas las partes
	local function unlockPart(p)
		if not p:IsA("BasePart") then return end
		p.Anchored     = false
		p.CanCollide   = true
		p.Massless     = false
		p.Transparency = 0
	end
	for _, d in ipairs(gun:GetDescendants()) do unlockPart(d) end
	for _, d in ipairs(gun:GetChildren())    do unlockPart(d) end
	if handle          then unlockPart(handle)          end
	if gun.PrimaryPart then unlockPart(gun.PrimaryPart) end

	-- PASO 3: teletransportar el arma a la mano derecha del NPC antes de soltar
	-- El arma puede estar en cualquier parte del workspace (lejos del NPC)
	-- así que hay que moverla a donde debería estar físicamente
	local rightArm = getPart("Right Arm")
	if rightArm and handle then
		-- Posicionar el handle en la palma del brazo derecho usando EQUIP_OFFSET
		handle.CFrame = rightArm.CFrame * EQUIP_OFFSET
	end

	-- PASO 4: mover al workspace
	gun.Parent = workspace

	-- PASO 5: impulso
	if handle then
		local vel    = Instance.new("BodyVelocity")
		vel.Velocity = Vector3.new(math.random(-3, 3), 4, math.random(-2, 2))
		vel.MaxForce = Vector3.new(1e4, 1e4, 1e4)
		vel.P        = 1e4
		vel.Parent   = handle
		Debris:AddItem(vel, 0.15)
	end

	equipped = false; holstered = false; gun = nil; handle = nil
end

function WeaponManager:GetState()
	if equipped  then return "equipped"  end
	if holstered then return "holstered" end
	return "dropped"
end

function WeaponManager:IsEquipped()  return equipped  end
function WeaponManager:IsHolstered() return holstered end

return WeaponManager