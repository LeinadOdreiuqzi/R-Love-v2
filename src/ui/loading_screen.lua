-- src/ui/loading_screen.lua
-- Sistema de pantalla de carga inicial: Salto Hiperespacial / Túnel Cuántico (Warp-Drive & Stargate)
-- Proyección 3D de estrellas en trazas (star streaks), astrolabio holográfico giroscópico 3D y telemetría de sector.

local LoadingScreen = {}
local ShaderManager = require 'src.shaders.shader_manager'
local GameState = require 'src.core.game_state'

-- Configuración temática del Hiperespacio
LoadingScreen.config = {
    -- Tiempos de transición
    minLoadTime = 0.90,         -- Tiempo mínimo cinematográfico para disfrutar del túnel
    fadeInTime = 0.35,          -- Entrada suave
    fadeOutTime = 0.50,         -- Salida con destello warp hacia el juego

    -- Paleta de colores de alta energía cuántica (Hiperespacio)
    colors = {
        background  = {0.008, 0.010, 0.022, 1.0}, -- Vacío cósmico profundo
        warpCyan    = {0.20, 0.88, 1.00, 1.0},    -- Haz de hiperimpulso cian
        warpBlue    = {0.35, 0.58, 1.00, 1.0},    -- Azul interestelar
        warpPurple  = {0.72, 0.42, 0.98, 1.0},    -- Horizonte de eventos violeta
        warpAmber   = {1.00, 0.82, 0.38, 1.0},    -- Acento de advertencia y seed
        text        = {0.94, 0.97, 1.00, 1.0},    -- Blanco nítido
        textDim     = {0.52, 0.62, 0.78, 1.0},    -- Telemetría secundaria
        primary     = {0.20, 0.88, 1.00, 1.0},    -- Alias retrocompatible
        secondary   = {0.72, 0.42, 0.98, 1.0},
        accent      = {1.00, 0.82, 0.38, 1.0}
    },

    -- Parámetros del motor de salto warp 3D
    warp = {
        starCount     = 420,    -- Densidad óptima de partículas estelares 3D
        fov           = 360,    -- Distancia focal de proyección perspectiva
        maxDepth      = 1200,   -- Profundidad máxima Z
        baseSpeed     = 140,    -- Velocidad de aproximación inicial (px/s)
        maxSpeedBoost = 3800,   -- Aceleración a hipervelocidad al 100%
        coreRadius    = 88      -- Radio del astrolabio holográfico
    }
}

-- Estado de ejecución
LoadingScreen.state = {
    active = false,
    progress = 0,               -- Progreso real de CPU [0..1]
    smoothProgress = 0,         -- Progreso interpolado LERP a 60 FPS [0..1]
    currentStep = "",
    subStep = "",
    startTime = 0,
    elapsedTime = 0,
    animationTime = 0,

    -- Control de fases
    fadeAlpha = 0,
    fadeState = "in", -- "in", "loading", "out", "done"
    isWarpJump = false,
    warpDuration = 1.95,
    warpTitle = "",
    warpDestination = "",
    onMidpoint = nil,
    midpointExecuted = false,

    -- Pasos de carga
    currentStepIndex = 1,
    totalSteps = 12,
    stepsCompleted = 0,

    -- Decodificador de semilla cósmica
    targetSeed = "",
    displaySeed = "----------",
    seedLockIndex = 0,

    -- Entidades visuales
    stars = {},
    nebulae = {},
    astrolabe = {
        pitch = 0,
        yaw = 0,
        roll = 0,
        pulse = 1.0
    },

    -- Retrocompatibilidad para inspección externa
    loadingRing = {
        rotation = 0,
        segments = {},
        pulseScale = 1
    },

    -- Callbacks
    onComplete = nil,
    loadFunction = nil,

    -- Carga asíncrona y cache
    asyncLoader = {
        enabled = true,
        maxTimePerFrame = 0.016,
        currentTask = nil,
        taskQueue = {},
        lastFrameTime = 0
    },

    resourceCache = {
        preloadedAssets = {},
        memoryUsage = 0,
        maxMemoryUsage = 50 * 1024 * 1024
    }
}

LoadingScreen.loadIterator = nil

-- Pasos de carga sincronizados con game_loader.lua
LoadingScreen.gameLoadSteps = {
    {id = "init",           name = "Initializing Core Systems",           weight = 0.04},
    {id = "seed",           name = "Processing Seed & Universe Matrix",   weight = 0.04},
    {id = "perlin",         name = "Synthesizing Quantum Noise Fields",   weight = 0.08},
    {id = "biomes",         name = "Calculating Biome Distribution",      weight = 0.12},
    {id = "coordinates",    name = "Calibrating Coordinates & Astrometry", weight = 0.04},
    {id = "chunks",         name = "Initializing Sector Chunk Engine",    weight = 0.08},
    {id = "renderer",       name = "Compiling Stellar Shaders",           weight = 0.05},
    {id = "initial_chunks", name = "Materializing Spatial Sectors",       weight = 0.25},
    {id = "player",         name = "Engaging Vessel & Life Support",       weight = 0.08},
    {id = "game_systems",   name = "Synchronizing Sensors & Audio Engine", weight = 0.10},
    {id = "hud",            name = "Projecting Tactical HUD Interface",   weight = 0.05},
    {id = "finalize",       name = "Locking Hyperspace Exit Coordinates", weight = 0.07}
}

-- Inicializar fuentes, tips y recursos
function LoadingScreen.init()
    LoadingScreen.generateStars()
    LoadingScreen.generateNebulae()

    if ShaderManager and (not ShaderManager.state or not ShaderManager.state.initialized) then
        ShaderManager.init()
    end

    -- Inicializar fuentes nítidas y balanceadas
    LoadingScreen.fonts = {
        header    = love.graphics.newFont(26),
        subHeader = love.graphics.newFont(12),
        progress  = love.graphics.newFont(24),
        coreGlyph = love.graphics.newFont(10),
        stepTitle = love.graphics.newFont(17),
        stepSub   = love.graphics.newFont(13),
        telemetry = love.graphics.newFont(12),
        tip       = love.graphics.newFont(14),
        -- Alias retrocompatibles
        title     = love.graphics.newFont(26),
        step      = love.graphics.newFont(17),
        small     = love.graphics.newFont(12),
        tips      = love.graphics.newFont(14)
    }

    -- Consejos de exploración espacial y controles
    LoadingScreen.tips = {
        "Deep Space acts as an uncharted cosmic ocean between planetary biomes",
        "Ancient Ruins hold lost precursor technology - scan deep space to locate them",
        "Press [F12] to toggle the Long-Range Biome Scanner HUD",
        "Radioactive Zones harbor volatile green nebulae and dense gravitational anomalies",
        "Your unique sector seed determines the procedural placement of all star systems",
        "Gravity Anomalies bend starlight and warp local spacetime geometry",
        "Press [F1] to display flight telemetry, sector diagnostics, and system stats",
        "Asteroid Belts are abundant in rare minerals but require tactical navigation",
        "Hold [Shift] to engage emergency reverse thruster brakes",
        "Warp conduits reach peak stability when navigational event horizons synchronize"
    }
    LoadingScreen.currentTip = LoadingScreen.tips[math.random(1, #LoadingScreen.tips)]
    LoadingScreen.tipChangeTime = 0

    LoadingScreen.initLoadingRing()

    local HyperspaceTunnel = require 'src.shaders.hyperspace_tunnel'
    HyperspaceTunnel.init()

    print("✓ LoadingScreen: Hyperspace Warp Drive engine initialized")
end

-- Generar campo de estrellas 3D proyectivas para el túnel de velocidad (Star Streaks)
function LoadingScreen.generateStars()
    LoadingScreen.state.stars = {}
    local starCount = LoadingScreen.config.warp.starCount
    local maxZ = LoadingScreen.config.warp.maxDepth

    for _ = 1, starCount do
        -- Distribución radial homogénea alrededor del punto de fuga central
        local angle = math.random() * math.pi * 2
        local dist = (math.random() ^ 0.65) * 1100 + 35
        local x = math.cos(angle) * dist
        local y = math.sin(angle) * dist
        local z = math.random() * maxZ + 15

        -- Temperatura espectral variada
        local cRoll = math.random()
        local col
        if cRoll > 0.85 then
            col = {1.00, 0.88, 0.55} -- Ámbar / dorado estelar
        elseif cRoll > 0.55 then
            col = {0.45, 0.85, 1.00} -- Cian de plasma
        elseif cRoll > 0.25 then
            col = {0.65, 0.75, 1.00} -- Azul de hipervelocidad
        else
            col = {0.96, 0.98, 1.00} -- Blanco puro brillante
        end

        table.insert(LoadingScreen.state.stars, {
            x = x,
            y = y,
            z = z,
            speedMul = math.random() * 0.40 + 0.80,
            color = col,
            baseSize = math.random() * 1.6 + 1.0
        })
    end
end

-- Generar nebulosa cuántica de fondo en el punto focal
function LoadingScreen.generateNebulae()
    LoadingScreen.state.nebulae = {}
    table.insert(LoadingScreen.state.nebulae, {
        seed = 42.1337,
        size = 340,
        color = {0.18, 0.45, 0.95, 0.35},
        coreColor = {0.80, 0.35, 1.00},
        rotation = 0.0,
        rotationSpeed = 0.08
    })
end

-- Retrocompatibilidad: inicializador del anillo
function LoadingScreen.initLoadingRing()
    LoadingScreen.state.loadingRing.segments = {}
    for i = 1, 32 do
        table.insert(LoadingScreen.state.loadingRing.segments, {
            angle = (i - 1) * (math.pi * 2 / 32),
            active = false,
            brightness = 0,
            size = 1
        })
    end
end

-- Iniciar secuencia cinemática de salto hiperespacial para portales de submundos
function LoadingScreen.startWarpJump(options)
    options = options or {}
    local state = LoadingScreen.state
    state.active = true
    state.isWarpJump = true
    state.progress = 0
    state.smoothProgress = 0
    state.elapsedTime = 0
    state.animationTime = 0
    state.fadeAlpha = 0
    state.fadeState = "in"
    state.currentStepIndex = 1
    state.stepsCompleted = 0
    state.totalSteps = 4

    -- Semilla determinista del portal / submundo
    local seed = options.seed or "HYPERSPACE"
    state.targetSeed = seed
    state.displaySeed = "----------"
    state.seedLockIndex = 0

    state.warpDuration = options.duration or 1.95
    state.warpTitle = options.title or "CONDUIT HYPERSPACE JUMP"
    state.warpDestination = options.destination or "Submundo Cuántico"
    state.currentStep = state.warpTitle
    state.subStep = "Sincronizando Horizonte de Eventos..."

    state.onMidpoint = options.onMidpoint
    state.midpointExecuted = false
    state.onComplete = options.onComplete
    state.loadFunction = nil
    state.loadIterator = nil

    local HyperspaceTunnel = require 'src.shaders.hyperspace_tunnel'
    HyperspaceTunnel.setSeed(seed)

    LoadingScreen.generateStars()
    LoadingScreen.generateNebulae()

    print("★ LoadingScreen: Portal warp jump initiated to seed [" .. tostring(seed) .. "] destination: " .. tostring(state.warpDestination))
end

-- Iniciar secuencia de carga
function LoadingScreen.start(loadFunction, onComplete, seedOverride)
    local state = LoadingScreen.state
    state.active = true
    state.isWarpJump = false
    state.progress = 0
    state.smoothProgress = 0
    state.currentStep = "Initiating Hyperspace Drive..."
    state.subStep = "Synchronizing Event Horizon"
    state.startTime = love.timer.getTime()
    state.elapsedTime = 0
    state.animationTime = 0
    state.fadeAlpha = 0
    state.fadeState = "in"
    state.currentStepIndex = 1
    state.stepsCompleted = 0
    state.totalSteps = #LoadingScreen.gameLoadSteps

    -- Recuperar semilla cósmica activa
    local seed = seedOverride or (GameState and GameState.state and GameState.state.currentSeed) or "3HY6E8X36H"
    state.targetSeed = seed
    state.displaySeed = "----------"
    state.seedLockIndex = 0

    local HyperspaceTunnel = require 'src.shaders.hyperspace_tunnel'
    HyperspaceTunnel.setSeed(seed)

    state.onComplete = onComplete
    state.loadFunction = loadFunction

    LoadingScreen.generateStars()
    LoadingScreen.generateNebulae()

    if LoadingScreen.tips and #LoadingScreen.tips > 0 then
        LoadingScreen.currentTip = LoadingScreen.tips[math.random(1, #LoadingScreen.tips)]
    end

    print("★ LoadingScreen: Hyperspace jump started for seed: " .. tostring(seed))
end

-- Actualizar progreso de carga
function LoadingScreen.updateProgress(stepId, subStep)
    for i, step in ipairs(LoadingScreen.gameLoadSteps) do
        if step.id == stepId then
            LoadingScreen.state.currentStepIndex = i
            LoadingScreen.state.currentStep = step.name
            LoadingScreen.state.subStep = subStep or ""

            local progressSoFar = 0
            for j = 1, i - 1 do
                progressSoFar = progressSoFar + LoadingScreen.gameLoadSteps[j].weight
            end

            if subStep then
                local subProgress = tonumber(string.match(subStep, "(%d+)%%")) or 0
                progressSoFar = progressSoFar + (LoadingScreen.gameLoadSteps[i].weight * subProgress / 100)
            end

            LoadingScreen.state.progress = math.min(1.0, math.max(0.0, progressSoFar))
            LoadingScreen.state.stepsCompleted = i - 1
            break
        end
    end
end

-- Ciclo principal de actualización
function LoadingScreen.update(dt)
    local state = LoadingScreen.state
    if not state.active then return false end

    -- Actualizar subsistema de audio
    local AudioManager = require 'src.audio.audio_manager'
    if AudioManager and AudioManager.update then
        AudioManager.update(dt)
    end

    LoadingScreen.processAsyncTasks(dt)
    LoadingScreen.cleanupResourceCache()

    state.elapsedTime = state.elapsedTime + dt
    state.animationTime = state.animationTime + dt

    local HyperspaceTunnel = require 'src.shaders.hyperspace_tunnel'
    HyperspaceTunnel.update(dt, state.smoothProgress)

    -- Interpolación continua LERP a 60 FPS (cero tirones en el progreso visual)
    local targetP = state.progress
    local lerpRate = (state.fadeState == "out") and 16.0 or 8.5
    state.smoothProgress = state.smoothProgress + (targetP - state.smoothProgress) * math.min(1.0, dt * lerpRate)

    -- Decodificación procedural de la semilla (efecto de descifrado hexadecimal)
    local tgtSeed = state.targetSeed
    if tgtSeed and #tgtSeed > 0 then
        local hexChars = "0123456789ABCDEF"
        local chars = {}
        local numChars = #tgtSeed
        local lockP = math.min(numChars, math.floor(state.smoothProgress * (numChars + 1)))

        for i = 1, numChars do
            if i <= lockP or state.elapsedTime > (0.12 * i) then
                chars[i] = tgtSeed:sub(i, i)
            else
                local rIdx = math.random(1, #hexChars)
                chars[i] = hexChars:sub(rIdx, rIdx)
            end
        end
        state.displaySeed = table.concat(chars)
    end

    -- Dinámica del Astrolabio 3D
    local p = state.smoothProgress
    local warpFactor = 1.0 + p * 2.5
    state.astrolabe.yaw   = state.astrolabe.yaw + dt * (1.10 * warpFactor)
    state.astrolabe.roll  = state.astrolabe.roll - dt * (0.75 * warpFactor)
    state.astrolabe.pitch = math.sin(state.animationTime * 1.4) * 0.42
    state.astrolabe.pulse = 1.0 + 0.06 * math.sin(state.animationTime * 4.5 * warpFactor)

    -- Dinámica del campo estelar Warp 3D (Star Streaks con desaceleración relativista de llegada)
    local baseSpd = LoadingScreen.config.warp.baseSpeed
    local maxBoost = LoadingScreen.config.warp.maxSpeedBoost
    local currentSpeed = baseSpd + maxBoost * (p ^ 1.35)
    if p > 0.72 and state.fadeState ~= "out" then
        -- Desaceleración al aproximarse al horizonte de llegada
        local brakeT = (p - 0.72) / 0.28
        currentSpeed = baseSpd + maxBoost * (1.0 - 0.75 * (brakeT ^ 1.8))
    elseif state.fadeState == "out" then
        local exitT = 1.0 - state.fadeAlpha
        currentSpeed = baseSpd * (1.0 - exitT * 0.8)
    end

    local maxZ = LoadingScreen.config.warp.maxDepth
    for _, star in ipairs(state.stars) do
        star.z = star.z - currentSpeed * star.speedMul * dt
        if star.z <= 6 then
            star.z = maxZ
            local angle = math.random() * math.pi * 2
            local dist = (math.random() ^ 0.65) * 1100 + 35
            star.x = math.cos(angle) * dist
            star.y = math.sin(angle) * dist
        end
    end

    -- Rotación de nebulosa focal
    for _, neb in ipairs(state.nebulae) do
        neb.rotation = neb.rotation + dt * neb.rotationSpeed * (1.0 + p)
    end

    -- Máquina de estados de fade
    if state.fadeState == "in" then
        state.fadeAlpha = math.min(1.0, state.fadeAlpha + dt / LoadingScreen.config.fadeInTime)
        if state.fadeAlpha >= 1.0 then
            state.fadeState = "loading"
            if state.loadFunction then
                LoadingScreen.executeLoadSteps()
            end
        end
    elseif state.fadeState == "loading" then
        if state.isWarpJump then
            local dur = state.warpDuration or 1.95
            local p = math.min(1.0, state.elapsedTime / dur)
            state.progress = p

            if p < 0.25 then
                state.subStep = "Sincronizando Horizonte de Eventos..."
                state.stepsCompleted = 0
                state.currentStepIndex = 1
            elseif p < 0.55 then
                state.subStep = "Túnel cuántico activo — Aceleración a Hipervelocidad"
                state.stepsCompleted = 1
                state.currentStepIndex = 2
            elseif p < 0.85 then
                state.subStep = "Aproximación a destino: " .. tostring(state.warpDestination or "Submundo")
                state.stepsCompleted = 2
                state.currentStepIndex = 3
            else
                state.subStep = "Materialización inminente — Desacelerando salto"
                state.stepsCompleted = 3
                state.currentStepIndex = 4
            end

            -- Al alcanzar el 45% del salto (con pantalla 100% cubierta), ejecutamos el callback de escena si aún no se ejecutó
            if p >= 0.45 and not state.midpointExecuted then
                state.midpointExecuted = true
                if state.onMidpoint then
                    state.onMidpoint()
                end
            end

            -- Si se completó el tiempo del salto
            if p >= 1.0 and state.smoothProgress >= 0.98 then
                state.fadeState = "out"
            end
        else
            -- Presupuesto seguro de tiempo por frame (12ms) para 60 FPS estables (Carga inicial)
            local tStart = love.timer.getTime()
            while LoadingScreen.loadIterator and (love.timer.getTime() - tStart) < 0.012 do
                LoadingScreen.resumeLoading()
            end
        end
    elseif state.fadeState == "out" then
        state.fadeAlpha = math.max(0.0, state.fadeAlpha - dt / LoadingScreen.config.fadeOutTime)
        if state.fadeAlpha <= 0.0 then
            state.fadeState = "done"
            state.active = false
            state.isWarpJump = false
            if state.onComplete then
                state.onComplete()
            end
            return false
        end
    end

    -- Rotación de tips (solo en carga inicial de universo)
    if not state.isWarpJump then
        LoadingScreen.tipChangeTime = (LoadingScreen.tipChangeTime or 0) + dt
        if LoadingScreen.tipChangeTime > 3.5 then
            if LoadingScreen.tips and #LoadingScreen.tips > 0 then
                LoadingScreen.currentTip = LoadingScreen.tips[math.random(1, #LoadingScreen.tips)]
            end
            LoadingScreen.tipChangeTime = 0
        end
    end

    -- Condición de finalización para carga normal de mundo
    if not state.isWarpJump and state.fadeState == "loading" and state.progress >= 1.0 and state.smoothProgress >= 0.99 then
        if state.elapsedTime >= LoadingScreen.config.minLoadTime then
            state.fadeState = "out"
        end
    end

    return true
end

function LoadingScreen.executeLoadSteps()
    if LoadingScreen.state.loadFunction then
        LoadingScreen.loadIterator = LoadingScreen.state.loadFunction(LoadingScreen.updateProgress)
    end
end

function LoadingScreen.resumeLoading()
    if LoadingScreen.loadIterator then
        local ok, completed = pcall(LoadingScreen.loadIterator)
        if not ok or completed then
            LoadingScreen.state.progress = 1.0
            LoadingScreen.loadIterator = nil
        end
    end
end

-- ============================================================================
-- RENDERIZADO VISUAL: TÚNEL HIPERESPACIAL Y ASTROLABIO HOLOGRÁFICO
-- ============================================================================
function LoadingScreen.draw()
    local state = LoadingScreen.state
    if not state.active then return end

    local width, height
    local curCanvas = love.graphics.getCanvas()
    if curCanvas then
        width, height = curCanvas:getDimensions()
    else
        width, height = love.graphics.getDimensions()
    end

    local alpha = state.fadeAlpha
    local colors = LoadingScreen.config.colors

    love.graphics.push()
    love.graphics.origin()

    -- 1. Fondo de vacío cósmico profundo (opaco en carga inicial, modulado por fadeAlpha en salto de portal)
    local bgAlpha = state.isWarpJump and alpha or 1.0
    love.graphics.setColor(colors.background[1], colors.background[2], colors.background[3], bgAlpha)
    love.graphics.rectangle("fill", 0, 0, width, height)

    -- Centro focal del túnel hiperespacial
    local cx = math.floor(width * 0.50)
    local cy = math.floor(height * 0.46)
    local p = state.smoothProgress

    -- Micro-turbulencia cinemática en cabina al aproximarse al horizonte de llegada ("cuando se está por llegar")
    if p > 0.72 and state.fadeState ~= "out" then
        local surgeT = (p - 0.72) / 0.28
        local shakeAmp = (surgeT ^ 2.2) * 4.8
        local shakeFreq = state.animationTime * 48.0
        cx = cx + math.sin(shakeFreq) * shakeAmp
        cy = cy + math.cos(shakeFreq * 1.33) * shakeAmp * 0.7
    end

    local exitT = (state.fadeState == "out") and (1.0 - state.fadeAlpha) or 0.0

    -- 2. Túnel hiperespacial 3D (Shader procedural estilo Destiny 2 con llegada y rotura cuántica en GPU)
    local HyperspaceTunnel = require 'src.shaders.hyperspace_tunnel'
    local tunnelOk = HyperspaceTunnel.draw(cx, cy, width, height, alpha, p, exitT)

    if not tunnelOk then
        -- Fallback de seguridad si el shader no estuviese disponible
        LoadingScreen.drawFocalNebula(cx, cy, alpha)
        LoadingScreen.drawWarpStarfield(cx, cy, width, height, alpha)
    end

    -- 4. Interfaz HUD: Telemetría superior (solo la semilla) - OMITIR EN SALTOS DE SUBMUNDOS
    if not state.isWarpJump then
        LoadingScreen.drawTopTelemetry(width, alpha)
    end

    -- 5. Interfaz HUD: Paso de inicialización y barra cuántica - OMITIR EN SALTOS DE SUBMUNDOS
    if not state.isWarpJump then
        LoadingScreen.drawProgressSection(cx, cy, width, height, alpha)
    end

    -- 8. Destello culminante de llegada hiperespacial (Atmospheric Wash suplementario)
    if state.fadeState == "out" then
        LoadingScreen.drawArrivalBreakout(cx, cy, width, height, alpha)
    end

    love.graphics.pop()
end

-- ============================================================================
-- RENDERIZADO VISUAL: ROTURA DE HORIZONTE CUÁNTICO (ARRIVAL BREAKOUT FX)
-- ============================================================================
function LoadingScreen.drawArrivalBreakout(cx, cy, width, height, alpha)
    local state = LoadingScreen.state
    if state.fadeState ~= "out" then return end

    local HyperspaceTunnel = require 'src.shaders.hyperspace_tunnel'
    local themeCols = HyperspaceTunnel.getCurrentColors and HyperspaceTunnel.getCurrentColors()
    local flareCol = (themeCols and themeCols.flare) or {0.40, 0.85, 1.00}

    local exitT = 1.0 - state.fadeAlpha -- 0.0 al llegar hasta 1.0 al terminar la disipación

    local oldBlend, oldAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")

    -- Resplandor ambiental de descompresión cinemática (Full-Screen Atmospheric Wash)
    local washAlpha = (math.sin(exitT * math.pi) ^ 1.8) * 0.35 * alpha
    if washAlpha > 0.002 then
        local wr = flareCol[1] * 0.3 + 0.7
        local wg = flareCol[2] * 0.3 + 0.7
        local wb = flareCol[3] * 0.3 + 0.7
        love.graphics.setColor(wr, wg, wb, washAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)
    end

    love.graphics.setBlendMode(oldBlend, oldAlphaMode)
end

-- Render de nebulosa cuántica en el punto de fuga
function LoadingScreen.drawFocalNebula(cx, cy, alpha)
    local neb = LoadingScreen.state.nebulae[1]
    if not neb then return end

    local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("nebula")
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle")

    if shader and img then
        local NebulasShaders = require 'src.shaders.nebulas_shaders'
        love.graphics.setShader(shader)
        if NebulasShaders and NebulasShaders.configureForNebula then
            NebulasShaders.configureForNebula({
                seed = neb.seed,
                noiseScale = 2.4,
                warpAmp = 0.75,
                warpFreq = 1.35,
                softness = 0.35,
                intensity = 0.85,
                brightness = 1.25,
                parallax = 0.95,
                sparkleStrength = 0.0,
                coreColor = neb.coreColor,
                speed = 0.40
            }, love.timer.getTime())
        end

        local pulse = 1.0 + 0.08 * math.sin(LoadingScreen.state.animationTime * 1.8)
        local scale = (neb.size * pulse * 2.2) / img:getWidth()

        love.graphics.setColor(neb.color[1], neb.color[2], neb.color[3], neb.color[4] * alpha * 0.75)
        love.graphics.draw(img, cx, cy, neb.rotation, scale, scale, img:getWidth() * 0.5, img:getHeight() * 0.5)
        love.graphics.setShader()
    else
        -- Fallback suave
        love.graphics.setColor(neb.color[1], neb.color[2], neb.color[3], neb.color[4] * alpha * 0.30)
        love.graphics.circle("fill", cx, cy, neb.size * 0.70)
    end
end

-- Render del campo estelar 3D con Star Streaks
function LoadingScreen.drawWarpStarfield(cx, cy, width, height, alpha)
    local state = LoadingScreen.state
    local fov = LoadingScreen.config.warp.fov
    local p = state.smoothProgress
    local warpSpeed = LoadingScreen.config.warp.baseSpeed + LoadingScreen.config.warp.maxSpeedBoost * (p ^ 1.35)
    local streakScale = math.max(12.0, (warpSpeed / 75.0))

    local oldBlend, oldAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")

    for _, star in ipairs(state.stars) do
        local z = star.z
        if z > 8 then
            local k = fov / z
            local sx = cx + star.x * k
            local sy = cy + star.y * k

            -- Verificar si la estrella está dentro o cerca de la pantalla
            if sx >= -40 and sx <= width + 40 and sy >= -40 and sy <= height + 40 then
                -- Cola de la traza hiperespacial (proyectada en Z lejana)
                local tailLength = streakScale * star.speedMul
                local tailZ = z + tailLength
                local tailK = fov / tailZ
                local tx = cx + star.x * tailK
                local ty = cy + star.y * tailK

                -- Atenuación por profundidad y fade global
                local depthNorm = math.max(0.0, math.min(1.0, 1.0 - (z / LoadingScreen.config.warp.maxDepth)))
                local stAlpha = depthNorm * alpha * (0.45 + p * 0.55)
                local col = star.color

                -- Trazado del rayo de luz
                love.graphics.setColor(col[1], col[2], col[3], stAlpha * 0.85)
                love.graphics.setLineWidth(math.max(1.0, star.baseSize * depthNorm * (1.0 + p * 0.5)))
                love.graphics.line(tx, ty, sx, sy)

                -- Núcleo brillante en el punto delantero
                if depthNorm > 0.40 then
                    love.graphics.setColor(1.0, 1.0, 1.0, stAlpha * 0.95)
                    love.graphics.circle("fill", sx, sy, math.max(1.0, star.baseSize * depthNorm))
                end
            end
        end
    end

    love.graphics.setBlendMode(oldBlend, oldAlphaMode)
end

-- Render del Astrolabio / Giroscopio Holográfico 3D en el centro
function LoadingScreen.draw3DAstrolabe(cx, cy, alpha)
    local state = LoadingScreen.state
    local ast = state.astrolabe
    local colors = LoadingScreen.config.colors
    local baseR = LoadingScreen.config.warp.coreRadius * ast.pulse
    local p = state.smoothProgress

    love.graphics.push()
    love.graphics.translate(cx, cy)

    -- ------------------------------------------------------------------------
    -- 1. Anillo Exterior: Brújula Náutica Galáctica (Roll Axis)
    -- ------------------------------------------------------------------------
    local r1 = baseR * 1.25
    local roll = ast.roll

    -- Halo de fondo del anillo
    love.graphics.setColor(colors.warpCyan[1], colors.warpCyan[2], colors.warpCyan[3], 0.18 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, r1)

    -- Marcas angulares graduadas (cada 30 grados)
    for deg = 0, 330, 30 do
        local rad = math.rad(deg) + roll
        local len = (deg % 90 == 0) and 9 or 4
        local x1 = math.cos(rad) * (r1 - len)
        local y1 = math.sin(rad) * (r1 - len)
        local x2 = math.cos(rad) * (r1 + len)
        local y2 = math.sin(rad) * (r1 + len)

        local isCardinal = (deg % 90 == 0)
        local col = isCardinal and colors.warpAmber or colors.warpCyan
        love.graphics.setColor(col[1], col[2], col[3], (isCardinal and 0.85 or 0.40) * alpha)
        love.graphics.setLineWidth(isCardinal and 2 or 1)
        love.graphics.line(x1, y1, x2, y2)
    end

    -- Arco graduado de progreso exterior
    if p > 0.01 then
        love.graphics.setColor(colors.warpAmber[1], colors.warpAmber[2], colors.warpAmber[3], 0.90 * alpha)
        love.graphics.setLineWidth(3)
        local startAng = -math.pi * 0.5
        local endAng = startAng + (math.pi * 2 * p)
        love.graphics.arc("line", "open", 0, 0, r1 + 5, startAng, endAng, 48)
    end

    -- ------------------------------------------------------------------------
    -- 2. Anillo Intermedio: Bobina Cuántica 3D (Pitch / Yaw Gyroscope)
    -- ------------------------------------------------------------------------
    local r2 = baseR * 0.98
    local yaw = ast.yaw
    local pitch = ast.pitch

    local numPts = 36
    local pts = {}
    for i = 0, numPts do
        local ang = (i / numPts) * math.pi * 2
        -- Coordenadas 3D del anillo
        local x = math.cos(ang) * r2
        local y = math.sin(ang) * r2 * math.cos(pitch)
        local z = math.sin(ang) * r2 * math.sin(pitch)

        -- Rotación Yaw en Y
        local xRot = x * math.cos(yaw) - z * math.sin(yaw)
        local yRot = y
        table.insert(pts, xRot)
        table.insert(pts, yRot)
    end

    love.graphics.setColor(colors.warpPurple[1], colors.warpPurple[2], colors.warpPurple[3], 0.70 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", pts)

    -- Nodos luminosos en la bobina intermedia
    for i = 0, 7 do
        local ang = (i / 8) * math.pi * 2
        local x = math.cos(ang) * r2
        local y = math.sin(ang) * r2 * math.cos(pitch)
        local z = math.sin(ang) * r2 * math.sin(pitch)
        local nx = x * math.cos(yaw) - z * math.sin(yaw)
        local ny = y
        local nodeActive = (i / 8) <= p
        local ncol = nodeActive and colors.warpCyan or colors.warpPurple
        love.graphics.setColor(ncol[1], ncol[2], ncol[3], (nodeActive and 0.95 or 0.35) * alpha)
        love.graphics.circle("fill", nx, ny, nodeActive and 3.0 or 1.8)
    end

    -- ------------------------------------------------------------------------
    -- 3. Anillo Interior: Horizonte de Eventos (Contragiro 3D)
    -- ------------------------------------------------------------------------
    local r3 = baseR * 0.70
    local yawRev = -ast.yaw * 1.25
    local pitchRev = -ast.pitch * 0.85
    local pts3 = {}
    for i = 0, numPts do
        local ang = (i / numPts) * math.pi * 2
        local x = math.cos(ang) * r3
        local y = math.sin(ang) * r3 * math.cos(pitchRev)
        local z = math.sin(ang) * r3 * math.sin(pitchRev)
        local xRot = x * math.cos(yawRev) - z * math.sin(yawRev)
        local yRot = y
        table.insert(pts3, xRot)
        table.insert(pts3, yRot)
    end

    love.graphics.setColor(colors.warpCyan[1], colors.warpCyan[2], colors.warpCyan[3], 0.65 * alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", pts3)

    -- ------------------------------------------------------------------------
    -- 4. Núcleo Cuántico Central y Porcentaje
    -- ------------------------------------------------------------------------
    local rCore = baseR * 0.44
    -- Resplandor del núcleo
    local oldBlend, oldAlpha = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setColor(colors.warpCyan[1], colors.warpCyan[2], colors.warpCyan[3], 0.22 * alpha)
    love.graphics.circle("fill", 0, 0, rCore * 1.25)
    love.graphics.setColor(colors.warpPurple[1], colors.warpPurple[2], colors.warpPurple[3], 0.28 * alpha)
    love.graphics.circle("fill", 0, 0, rCore)
    love.graphics.setBlendMode(oldBlend, oldAlpha)

    -- Borde nítido del núcleo
    love.graphics.setColor(colors.warpCyan[1], colors.warpCyan[2], colors.warpCyan[3], 0.80 * alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 0, 0, rCore)

    -- Texto del porcentaje centrado matemáticamente
    local pctFont = LoadingScreen.fonts.progress
    love.graphics.setFont(pctFont)
    local pctVal = math.floor(p * 100)
    local pctText = pctVal .. "%"
    local pctH = pctFont:getHeight()
    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], alpha)
    love.graphics.printf(pctText, -60, -math.floor(pctH * 0.5) - 3, 120, "center")

    -- Glifo 'WARP' bajo el porcentaje
    local gFont = LoadingScreen.fonts.coreGlyph
    love.graphics.setFont(gFont)
    love.graphics.setColor(colors.warpAmber[1], colors.warpAmber[2], colors.warpAmber[3], 0.85 * alpha)
    love.graphics.printf("WARP CONDUIT", -60, math.floor(pctH * 0.5) - 1, 120, "center")

    love.graphics.pop()
end

-- Render de telemetría superior (solo la semilla)
function LoadingScreen.drawTopTelemetry(width, alpha)
    local colors = LoadingScreen.config.colors
    local state = LoadingScreen.state
    local padX = 36
    local topY = 28

    -- Mostrar exclusivamente la semilla del sector o submundo
    local prefix = state.isWarpJump and "CONDUIT SEED: [" or "SECTOR SEED: ["
    local seedText = prefix .. tostring(state.displaySeed) .. "]"
    local rightFont = LoadingScreen.fonts.telemetry
    love.graphics.setFont(rightFont)
    local seedW = rightFont:getWidth(seedText)
    local rightX = width - padX - seedW

    local isLocked = (state.displaySeed == state.targetSeed)
    local lockCol = isLocked and colors.warpAmber or colors.warpCyan
    love.graphics.setColor(lockCol[1], lockCol[2], lockCol[3], 0.90 * alpha)
    love.graphics.print(seedText, rightX, topY)
end

-- Render de la sección de progreso y barra cuántica
function LoadingScreen.drawProgressSection(cx, cy, width, height, alpha)
    local state = LoadingScreen.state
    local colors = LoadingScreen.config.colors
    local p = state.smoothProgress

    -- Posicionamiento armónico en el tercio inferior
    local barWidth = math.min(560, math.floor(width * 0.60))
    local barHeight = 6
    local barY = math.floor(height * 0.78)
    local barX = cx - math.floor(barWidth * 0.5)
    local corner = 3

    local stepH = LoadingScreen.fonts.stepTitle:getHeight()
    local subH = LoadingScreen.fonts.stepSub:getHeight()
    local textStartY = barY - (stepH + subH + 14)

    -- 1. Nombre del paso actual
    love.graphics.setFont(LoadingScreen.fonts.stepTitle)
    love.graphics.setColor(colors.warpCyan[1], colors.warpCyan[2], colors.warpCyan[3], 0.95 * alpha)
    love.graphics.printf(state.currentStep or "Synchronizing...", 0, textStartY, width, "center")

    -- 2. Substep o detalle
    local subY = textStartY + stepH + 4
    if state.subStep and state.subStep ~= "" then
        love.graphics.setFont(LoadingScreen.fonts.stepSub)
        love.graphics.setColor(colors.textDim[1], colors.textDim[2], colors.textDim[3], 0.85 * alpha)
        love.graphics.printf(state.subStep, 0, subY, width, "center")
    end

    -- Contenedor y marco biselado
    love.graphics.setColor(0.04, 0.08, 0.16, 0.65 * alpha)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, corner, corner)
    love.graphics.setColor(colors.warpCyan[1], colors.warpCyan[2], colors.warpCyan[3], 0.30 * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, corner, corner)

    -- Relleno de barra con gradiente cuántico
    if p > 0.005 then
        local fillW = math.max(corner * 2, barWidth * p)
        local r = colors.warpCyan[1] * (1.0 - p) + colors.warpAmber[1] * p
        local g = colors.warpCyan[2] * (1.0 - p) + colors.warpAmber[2] * p
        local b = colors.warpCyan[3] * (1.0 - p) + colors.warpAmber[3] * p

        love.graphics.setColor(r, g, b, 0.95 * alpha)
        love.graphics.rectangle("fill", barX, barY, fillW, barHeight, corner, corner)

        -- Cursor de avance de alta intensidad en el borde delantero
        local oldB, oldA = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")
        love.graphics.setColor(1.0, 1.0, 1.0, 0.90 * alpha)
        love.graphics.rectangle("fill", barX + fillW - 3, barY - 1, 3, barHeight + 2)
        love.graphics.setColor(colors.warpCyan[1], colors.warpCyan[2], colors.warpCyan[3], 0.60 * alpha)
        love.graphics.circle("fill", barX + fillW - 1, barY + barHeight * 0.5, 4.5)
        love.graphics.setBlendMode(oldB, oldA)
    end

    if state.isWarpJump then
        -- 4 hitos discretos para el salto cuántico del portal de submundo
        local conduitNodes = { 0.0, 0.33, 0.66, 1.0 }
        for _, nodeP in ipairs(conduitNodes) do
            local dotX = barX + barWidth * nodeP
            local isDone = (p >= nodeP)
            local isCurr = (p >= nodeP - 0.15 and p < nodeP + 0.15)
            local dotCol = isDone and colors.warpAmber or (isCurr and colors.warpCyan or colors.textDim)
            local dotAlpha = isDone and 0.95 or (isCurr and 0.85 or 0.35)

            love.graphics.setColor(dotCol[1], dotCol[2], dotCol[3], dotAlpha * alpha)
            love.graphics.circle("fill", dotX, barY + barHeight * 0.5, isCurr and 3.5 or 2.0)
        end
    else
        -- Hitos discretos de los 12 pasos de generación
        local cumWeight = 0
        for i, step in ipairs(LoadingScreen.gameLoadSteps) do
            local dotX = barX + barWidth * cumWeight
            local isDone = (i <= state.stepsCompleted)
            local isCurr = (i == state.currentStepIndex)
            local dotCol = isDone and colors.warpAmber or (isCurr and colors.warpCyan or colors.textDim)
            local dotAlpha = isDone and 0.95 or (isCurr and 0.85 or 0.35)

            love.graphics.setColor(dotCol[1], dotCol[2], dotCol[3], dotAlpha * alpha)
            love.graphics.circle("fill", dotX, barY + barHeight * 0.5, isCurr and 3.5 or 2.0)
            cumWeight = cumWeight + step.weight
        end
    end

    -- Sub-telemetría debajo de la barra
    local metaY = barY + barHeight + 10
    love.graphics.setFont(LoadingScreen.fonts.telemetry)
    love.graphics.setColor(colors.textDim[1], colors.textDim[2], colors.textDim[3], 0.75 * alpha)
    local stepStr
    if state.isWarpJump then
        stepStr = string.format("CONDUIT TRANSIT // STAGE %02d / %02d", state.currentStepIndex or 1, state.totalSteps or 4)
    else
        stepStr = string.format("PHASE %02d / %02d", state.currentStepIndex, state.totalSteps)
    end
    love.graphics.print(stepStr, barX, metaY)

    local warpFactorStr = string.format("WARP FACTOR: %.1f c", 1.0 + p * 8.9)
    local wfW = LoadingScreen.fonts.telemetry:getWidth(warpFactorStr)
    love.graphics.setColor(colors.warpAmber[1], colors.warpAmber[2], colors.warpAmber[3], 0.85 * alpha)
    love.graphics.print(warpFactorStr, barX + barWidth - wfW, metaY)
end

-- Render de la tarjeta de astrogación / Tip inferior glassmorphic
function LoadingScreen.drawTipCard(cx, cy, width, alpha)
    local colors = LoadingScreen.config.colors
    local tipText = "// ASTROGATION LOG: " .. tostring(LoadingScreen.currentTip)
    local font = LoadingScreen.fonts.tip
    local cardW = math.min(width - 64, math.max(480, math.floor(width * 0.70)))
    local _, wrappedLines = font:getWrap(tipText, cardW - 36)
    local lineCount = math.max(1, #wrappedLines)
    local cardH = math.max(34, lineCount * (font:getHeight() + 3) + 14)
    local cardX = cx - math.floor(cardW * 0.5)
    local cardY = cy - math.floor(cardH * 0.5)

    -- Fondo translúcido glassmorphic con gradiente sutil
    love.graphics.setColor(0.015, 0.035, 0.080, 0.72 * alpha)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6, 6)

    -- Borde holográfico biselado
    love.graphics.setColor(colors.warpCyan[1], colors.warpCyan[2], colors.warpCyan[3], 0.28 * alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 6, 6)

    -- Texto del Tip centrado
    love.graphics.setFont(font)
    love.graphics.setColor(colors.text[1], colors.text[2], colors.text[3], 0.90 * alpha)
    love.graphics.printf(tipText, cardX + 18, cardY + math.floor((cardH - lineCount * font:getHeight()) * 0.5), cardW - 36, "center")
end

-- ============================================================================
-- UTILIDADES, CARGA ASÍNCRONA Y RETROCOMPATIBILIDAD DE MÉTODOS
-- ============================================================================
function LoadingScreen.drawStars(alpha)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    LoadingScreen.drawWarpStarfield(math.floor(w * 0.5), math.floor(h * 0.40), w, h, alpha or 1.0)
end

function LoadingScreen.drawNebulae(alpha)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    LoadingScreen.drawFocalNebula(math.floor(w * 0.5), math.floor(h * 0.40), alpha or 1.0)
end

function LoadingScreen.drawLoadingRing(x, y, radius, alpha)
    LoadingScreen.draw3DAstrolabe(x or love.graphics.getWidth() * 0.5, y or love.graphics.getHeight() * 0.4, alpha or 1.0)
end

function LoadingScreen.drawProgressBar(x, y, barWidth, barHeight, alpha)
    -- Integrado en LoadingScreen.drawProgressSection
end

function LoadingScreen.drawText(x, y, alpha)
    -- Integrado en LoadingScreen.draw
end

function LoadingScreen.drawTip(cx, cy, alpha)
    LoadingScreen.drawTipCard(cx, cy, love.graphics.getWidth(), alpha)
end

function LoadingScreen.updateAnimations(dt)
    -- Administrado de forma integrada en LoadingScreen.update
end

function LoadingScreen.addAsyncTask(taskFunction, taskName)
    table.insert(LoadingScreen.state.asyncLoader.taskQueue, {
        func = taskFunction,
        name = taskName or "Unknown Task",
        startTime = love.timer.getTime()
    })
end

function LoadingScreen.processAsyncTasks(dt)
    if not LoadingScreen.state.asyncLoader.enabled then return end
    local startTime = love.timer.getTime()
    local maxTime = LoadingScreen.state.asyncLoader.maxTimePerFrame

    while #LoadingScreen.state.asyncLoader.taskQueue > 0 do
        if love.timer.getTime() - startTime > maxTime then break end
        local task = table.remove(LoadingScreen.state.asyncLoader.taskQueue, 1)
        LoadingScreen.state.asyncLoader.currentTask = task
        local success, result = pcall(task.func)
        if not success then
            print("Error in async task '" .. task.name .. "': " .. tostring(result))
        end
        LoadingScreen.state.asyncLoader.currentTask = nil
    end
    LoadingScreen.state.asyncLoader.lastFrameTime = love.timer.getTime() - startTime
end

function LoadingScreen.preloadAsset(assetPath, assetType)
    if LoadingScreen.state.resourceCache.preloadedAssets[assetPath] then
        return LoadingScreen.state.resourceCache.preloadedAssets[assetPath]
    end
    local asset = nil
    if assetType == "image" then
        asset = love.graphics.newImage(assetPath)
    elseif assetType == "sound" then
        asset = love.audio.newSource(assetPath, "static")
    elseif assetType == "font" then
        asset = love.graphics.newFont(assetPath)
    end
    if asset then
        LoadingScreen.state.resourceCache.preloadedAssets[assetPath] = asset
        LoadingScreen.state.resourceCache.memoryUsage = LoadingScreen.state.resourceCache.memoryUsage + 1024
    end
    return asset
end

function LoadingScreen.cleanupResourceCache()
    local memoryUsage = LoadingScreen.state.resourceCache.memoryUsage
    local maxMemory = LoadingScreen.state.resourceCache.maxMemoryUsage
    if memoryUsage > maxMemory then
        LoadingScreen.state.resourceCache.preloadedAssets = {}
        LoadingScreen.state.resourceCache.memoryUsage = 0
        print("LoadingScreen: Resource cache cleaned due to memory limit")
    end
end

function LoadingScreen.setProgress(progress)
    LoadingScreen.state.progress = math.max(0.0, math.min(1.0, progress))
end

function LoadingScreen.setStep(stepName)
    for i, step in ipairs(LoadingScreen.gameLoadSteps) do
        if step.name == stepName then
            LoadingScreen.state.currentStepIndex = i
            LoadingScreen.state.currentStep = step.name
            break
        end
    end
end

function LoadingScreen.isActive()
    return LoadingScreen.state.active
end

function LoadingScreen.forceComplete()
    LoadingScreen.state.progress = 1.0
    LoadingScreen.state.smoothProgress = 1.0
    LoadingScreen.state.fadeState = "out"
end

function LoadingScreen.resize(w, h)
    if LoadingScreen.state.active then
        LoadingScreen.generateStars()
        LoadingScreen.generateNebulae()
    end
end

return LoadingScreen