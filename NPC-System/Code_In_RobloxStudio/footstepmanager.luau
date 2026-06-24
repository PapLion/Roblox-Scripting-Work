--[[
================================================================================
  FootstepManager.lua  —  NPC Footstep Audio Module (v1)
================================================================================

  OVERVIEW
  --------
  Reproduce sonidos de pasos sincronizados con la velocidad real del NPC
  leyendo HRP.Velocity.Magnitude en un loop de Heartbeat.

  No modifica ningún archivo existente. NpcScript solo necesita agregar
  al final (después de los otros requires):

      local FootstepManager = require(NPC:WaitForChild("FootstepManager"))
      FootstepManager:Start()

  DISEÑO
  ------
  • Lee Velocity.Magnitude (no WalkSpeed) — refleja el movimiento real,
    incluyendo frames de aceleración/desaceleración y empujes externos.

  • Cooldown dinámico: más rápido = pasos más frecuentes.
    El rango 0.28–0.50s cubre walk hasta sprint sin sonar robótico.

  • Volumen escalado con velocidad: arranca en 0.25 al umbral mínimo y
    sube a 1.0 en velocidad máxima. Evita el click abrupto al partir.

  • Sound se crea en HRP (no en Head) para que la atenuación de distancia
    corresponda a donde están físicamente los pies del NPC.

  • Múltiples surface types listos para expandir: agrega IDs en
    SURFACE_SOUNDS y llama detectSurface() si lo necesitas después.

  PARA COMPLETAR
  --------------
  Reemplaza los rbxassetid://0 con los IDs reales de audio de pasos.
  Cada lista puede tener N IDs — se elige uno al azar para variedad.

================================================================================
]]

local FootstepManager = {}

local NPC             = script.Parent
local Humanoid        = NPC:WaitForChild("Humanoid")
local HRP             = NPC:WaitForChild("HumanoidRootPart")
local RS              = game:GetService("RunService")
local Debris          = game:GetService("Debris")

-- ── THRESHOLDS DE VELOCIDAD ───────────────────────────────────────────────────
--[[
  MIN_SPEED: velocidad mínima (studs/s) para reproducir pasos.
  Roblox tiene jitter de ~0.1–0.8 incluso parado — 1.5 evita falsos positivos.
]]
local MIN_SPEED = 1.5

--[[
  Tabla de velocidad → cooldown entre pasos (segundos).
  Se interpola linealmente entre los dos puntos más cercanos.
  Ajusta los valores si las animaciones de walk/run van a ritmos distintos.
]]
local SPEED_STEPS = {
    { speed = MIN_SPEED, cooldown = 0.50 }, -- borde mínimo (casi parado)
    { speed = 10,        cooldown = 0.48 }, -- walk lento
    { speed = 16,        cooldown = 0.40 }, -- walk normal / GunWalk
    { speed = 18,        cooldown = 0.32 }, -- run
    { speed = 24,        cooldown = 0.26 }, -- run rápido (Rusher con multiplier)
}

-- ── VOLUMEN ───────────────────────────────────────────────────────────────────
local VOL_MIN     = 0.25 -- volumen al arrancar (en MIN_SPEED)
local VOL_MAX     = 1.00 -- volumen a velocidad máxima
local VOL_SPEED   = 20   -- velocidad de referencia para VOL_MAX

-- ── ROLLOFF ───────────────────────────────────────────────────────────────────
local ROLLOFF_MIN = 3
local ROLLOFF_MAX = 35 -- se escuchan pasos hasta 35 studs — más que voces (60) porque pasos son sutiles

-- ── IDs DE AUDIO POR SUPERFICIE ──────────────────────────────────────────────
--[[
  Agrega más entradas (Wood, Grass, Metal) cuando tengas los IDs.
  detectSurface() devuelve la clave a usar; por ahora siempre "Default".
  Cada lista puede tener varios IDs — se elige uno al azar por paso.
]]
local SURFACE_SOUNDS = {
    Default = {
        -- TODO: reemplaza con IDs reales de pasos
        "rbxassetid://0",
        "rbxassetid://0",
        "rbxassetid://0",
        "rbxassetid://0",
    },
    -- Wood    = { "rbxassetid://0" },
    -- Grass   = { "rbxassetid://0" },
    -- Metal   = { "rbxassetid://0" },
}

-- ── HELPERS PRIVADOS ──────────────────────────────────────────────────────────

--[[
  getCooldown(speed)
  ------------------
  Interpola linealmente el cooldown entre los puntos de SPEED_STEPS.
  Por debajo del primer punto devuelve el cooldown máximo.
  Por encima del último punto fija el cooldown mínimo.
]]
local function getCooldown(speed)
    local steps = SPEED_STEPS
    if speed <= steps[1].speed then return steps[1].cooldown end
    if speed >= steps[#steps].speed then return steps[#steps].cooldown end
    for i = 1, #steps - 1 do
        local a, b = steps[i], steps[i + 1]
        if speed >= a.speed and speed <= b.speed then
            local t = (speed - a.speed) / (b.speed - a.speed)
            return a.cooldown + (b.cooldown - a.cooldown) * t
        end
    end
    return steps[#steps].cooldown
end

--[[
  getVolume(speed)
  ----------------
  Escala el volumen entre VOL_MIN y VOL_MAX según la velocidad actual.
  Evita el salto abrupto de silencio → volumen completo al empezar a moverse.
]]
local function getVolume(speed)
    local t = math.clamp((speed - MIN_SPEED) / (VOL_SPEED - MIN_SPEED), 0, 1)
    return VOL_MIN + (VOL_MAX - VOL_MIN) * t
end

--[[
  detectSurface()
  ---------------
  Lanza un raycast corto hacia abajo desde HRP para detectar el material
  del suelo y devolver la clave de SURFACE_SOUNDS correspondiente.
  Por ahora siempre devuelve "Default" — expande el match cuando tengas
  materiales definidos en tu mapa.
]]
local function detectSurface()
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { NPC }
    params.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(HRP.Position, Vector3.new(0, -4, 0), params)
    if hit then
        -- Ejemplo de expansión futura:
        -- local mat = hit.Material
        -- if mat == Enum.Material.Wood or mat == Enum.Material.WoodPlanks then return "Wood" end
        -- if mat == Enum.Material.Grass then return "Grass" end
        -- if mat == Enum.Material.Metal then return "Metal" end
        _ = hit -- referencia silenciosa para evitar warning de variable no usada
    end
    return "Default"
end

--[[
  pickSound(surface)
  ------------------
  Elige un ID al azar de la lista de la superficie dada.
  Si la superficie no existe en la tabla, cae a "Default".
  Si el ID es vacío o "rbxassetid://0", no reproduce nada (silencioso).
]]
local function pickSound(surface)
    local list = SURFACE_SOUNDS[surface] or SURFACE_SOUNDS["Default"]
    if not list or #list == 0 then return nil end
    local id = list[math.random(1, #list)]
    if id == "" or id == "rbxassetid://0" then return nil end
    return id
end

--[[
  playStep(volume)
  ----------------
  Crea un Sound temporal en HRP, lo reproduce y lo destruye automáticamente.
  Un Sound por paso — no hay risk de solaparse con el anterior porque el
  cooldown garantiza que el anterior ya terminó para velocidades normales.
]]
local function playStep(volume)
    local surface = detectSurface()
    local id      = pickSound(surface)
    if not id then return end -- IDs no configurados todavía, silencio

    local s              = Instance.new("Sound")
    s.SoundId            = id
    s.Volume             = volume
    s.RollOffMaxDistance = ROLLOFF_MAX
    s.RollOffMinDistance = ROLLOFF_MIN
    s.RollOffMode        = Enum.RollOffMode.InverseTapered
    s.Parent             = HRP
    s:Play()

    -- Debris limpia el Sound en 2s — más que suficiente para cualquier paso
    Debris:AddItem(s, 2)
end

-- ── API PÚBLICA ───────────────────────────────────────────────────────────────

--[[
  Start()
  -------
  Arranca el loop de pasos. Llamar una sola vez desde NpcScript.
  Se detiene automáticamente cuando el NPC muere.
]]
function FootstepManager:Start()
    local running  = true
    local lastStep = 0

    -- Detener al morir — sin depender de NpcScript
    Humanoid.Died:Once(function()
        running = false
    end)

    RS.Heartbeat:Connect(function()
        if not running then return end

        -- Estados que bloquean pasos (muerto, arrestado, rendido, stun)
        -- Leemos los atributos del NPC que NpcScript ya actualiza
        if NPC:GetAttribute("Arrested") then return end
        if NPC:GetAttribute("Surrendered") then return end
        if NPC:GetAttribute("Flashbanged") then return end

        local speed = HRP.Velocity.Magnitude
        if speed < MIN_SPEED then
            -- Parado: reset del timer para que el primer paso al arrancar
            -- no espere el cooldown completo del paso anterior
            lastStep = tick() - 0.1
            return
        end

        local cooldown = getCooldown(speed)
        local now      = tick()
        if now - lastStep < cooldown then return end

        lastStep = now
        local vol = getVolume(speed)
        playStep(vol)
    end)
end

return FootstepManager
