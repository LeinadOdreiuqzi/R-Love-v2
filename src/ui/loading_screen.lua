-- src/ui/loading_screen.lua
local LoadingScreen = {}
local ShaderManager = require 'src.shaders.shader_manager'
-- Configuración
LoadingScreen.config = {
    -- Tiempos
    minLoadTime = 2.0,          -- Tiempo mínimo de carga (para que se vea la animación)
    fadeInTime = 0.3,           -- Tiempo de fade in
    fadeOutTime = 0.5,          -- Tiempo de fade out
    
    -- Colores del tema espacial
    colors = {
        background = {0.02, 0.02, 0.08, 1},
        primary = {0.3, 0.7, 1, 1},
        secondary = {0.8, 0.5, 1, 1},
        accent = {1, 0.8, 0.3, 1},
        text = {0.9, 0.9, 1, 1},
        textDim = {0.6, 0.6, 0.7, 1}
    },
    
    -- Animación
    animation = {
        starCount = 200,
        nebulaCount = 8,
        rotationSpeed = 0.5,
        pulseSpeed = 2,
        waveSpeed = 3
    }
}

-- Estado optimizado
LoadingScreen.state = {
    active = false,
    progress = 0,
    currentStep = "",
    subStep = "",
    startTime = 0,
    elapsedTime = 0,
    
    -- Estados de carga
    loadingSteps = {},
    currentStepIndex = 1,
    totalSteps = 0,
    stepsCompleted = 0,
    
    -- Animación
    fadeAlpha = 0,
    fadeState = "in", -- "in", "loading", "out", "done"
    animationTime = 0,
    
    -- Elementos visuales
    stars = {},
    nebulae = {},
    loadingRing = {
        rotation = 0,
        segments = {},
        pulseScale = 1
    },
    
    -- Callbacks
    onComplete = nil,
    loadFunction = nil,
    
    -- Optimizaciones de carga asíncrona
    asyncLoader = {
        enabled = true,
        maxTimePerFrame = 0.016, -- 16ms máximo por frame (60 FPS)
        currentTask = nil,
        taskQueue = {},
        lastFrameTime = 0
    },
    
    -- Cache de recursos
    resourceCache = {
        preloadedAssets = {},
        memoryUsage = 0,
        maxMemoryUsage = 50 * 1024 * 1024 -- 50MB
    }
}

-- Iterador de carga
LoadingScreen.loadIterator = nil

-- Pasos de carga del juego
LoadingScreen.gameLoadSteps = {
    {id = "init", name = "Initializing Systems", weight = 0.05},
    {id = "seed", name = "Processing Seed", weight = 0.05},
    {id = "perlin", name = "Generating Noise Maps", weight = 0.1},
    {id = "biomes", name = "Creating Biome Distribution", weight = 0.15},
    {id = "coordinates", name = "Setting Up Coordinate System", weight = 0.05},
    {id = "chunks", name = "Initializing Chunk Manager", weight = 0.1},
    {id = "renderer", name = "Preparing Renderer", weight = 0.05},
    {id = "initial_chunks", name = "Generating Initial Area", weight = 0.25},
    {id = "player", name = "Creating Player", weight = 0.05},
    {id = "hud", name = "Loading Interface", weight = 0.05},
    {id = "finalize", name = "Finalizing World", weight = 0.1}
}

-- Inicializar la pantalla de carga
function LoadingScreen.init()
    -- Generar estrellas de fondo
    LoadingScreen.generateStars()
    
    -- Generar nebulosas
    LoadingScreen.generateNebulae()
    -- Inicializar ShaderManager para usar shaders en la pantalla de carga (evita doble-init)
    if ShaderManager and (not ShaderManager.state or not ShaderManager.state.initialized) then
        ShaderManager.init()
    end
    -- Inicializar anillo de carga
    LoadingScreen.initLoadingRing()
    -- Crear fuentes
    LoadingScreen.fonts = {
        title = love.graphics.newFont(36),
        progress = love.graphics.newFont(24),
        step = love.graphics.newFont(18),
        small = love.graphics.newFont(14),
        tips = love.graphics.newFont(16)
    }
    
    -- Tips de carga
    LoadingScreen.tips = {
        "Deep Space acts as a natural ocean between biomes",
        "Ancient Ruins are extremely rare - explore far to find them",
        "Press F12 to toggle the Biome Scanner",
        "Radioactive Zones have unique green nebulae",
        "Your seed determines the entire universe layout",
        "Gravity Anomalies can distort space-time",
        "Press F1 to see system information",
        "Each biome has unique properties and dangers",
        "The universe extends 200,000 units in all directions",
        "Asteroid Belts are rich in resources but dangerous"
    }
    LoadingScreen.currentTip = LoadingScreen.tips[math.random(1, #LoadingScreen.tips)]
    LoadingScreen.tipChangeTime = 0
    
    print("LoadingScreen initialized")
end

-- Generar estrellas de fondo
function LoadingScreen.generateStars()
    LoadingScreen.state.stars = {}
    local starCount = LoadingScreen.config.animation.starCount
    
    for i = 1, starCount do
        local star = {
            x = math.random() * love.graphics.getWidth(),
            y = math.random() * love.graphics.getHeight(),
            size = math.random() * 2 + 0.5,
            brightness = math.random() * 0.5 + 0.5,
            twinkleSpeed = math.random() * 2 + 1,
            twinklePhase = math.random() * math.pi * 2,
            depth = math.random() -- Para efecto parallax
        }
        table.insert(LoadingScreen.state.stars, star)
    end
end

-- Generar nebulosas de fondo
function LoadingScreen.generateNebulae()
    LoadingScreen.state.nebulae = {}
    local nebulaCount = LoadingScreen.config.animation.nebulaCount
    
    for i = 1, nebulaCount do
        local nebula = {
            x = math.random() * love.graphics.getWidth(),
            y = math.random() * love.graphics.getHeight(),
            size = math.random() * 200 + 100,
            color = {
                math.random() * 0.5 + 0.3,
                math.random() * 0.5 + 0.2,
                math.random() * 0.5 + 0.5,
                0.3
            },
            rotation = math.random() * math.pi * 2,
            rotationSpeed = (math.random() - 0.5) * 0.2
        }
        table.insert(LoadingScreen.state.nebulae, nebula)
    end
end

-- Inicializar anillo de carga
function LoadingScreen.initLoadingRing()
    local segments = 32
    LoadingScreen.state.loadingRing.segments = {}
    
    for i = 1, segments do
        local segment = {
            angle = (i - 1) * (math.pi * 2 / segments),
            active = false,
            brightness = 0,
            size = 1
        }
        table.insert(LoadingScreen.state.loadingRing.segments, segment)
    end
end

-- Comenzar carga
function LoadingScreen.start(loadFunction, onComplete)
    LoadingScreen.state.active = true
    LoadingScreen.state.progress = 0
    LoadingScreen.state.currentStep = "Initializing..."
    LoadingScreen.state.subStep = ""
    LoadingScreen.state.startTime = love.timer.getTime()
    LoadingScreen.state.elapsedTime = 0
    LoadingScreen.state.fadeAlpha = 0
    LoadingScreen.state.fadeState = "in"
    LoadingScreen.state.animationTime = 0
    LoadingScreen.state.currentStepIndex = 1
    LoadingScreen.state.stepsCompleted = 0
    LoadingScreen.state.totalSteps = #LoadingScreen.gameLoadSteps
    
    -- Guardar callbacks
    LoadingScreen.state.onComplete = onComplete
    LoadingScreen.state.loadFunction = loadFunction
    
    -- Reiniciar elementos visuales
    LoadingScreen.generateStars()
    LoadingScreen.generateNebulae()
    LoadingScreen.initLoadingRing()
    
    -- Seleccionar tip aleatorio
    LoadingScreen.currentTip = LoadingScreen.tips[math.random(1, #LoadingScreen.tips)]
    
    print("Loading screen started")
end

-- Actualizar progreso
function LoadingScreen.updateProgress(stepId, subStep)
    -- Buscar el paso actual
    for i, step in ipairs(LoadingScreen.gameLoadSteps) do
        if step.id == stepId then
            LoadingScreen.state.currentStepIndex = i
            LoadingScreen.state.currentStep = step.name
            LoadingScreen.state.subStep = subStep or ""
            
            -- Calcular progreso ponderado
            local progressSoFar = 0
            for j = 1, i - 1 do
                progressSoFar = progressSoFar + LoadingScreen.gameLoadSteps[j].weight
            end
            
            -- Añadir progreso parcial del paso actual si hay substep
            if subStep then
                local subProgress = tonumber(string.match(subStep, "(%d+)%%")) or 0
                progressSoFar = progressSoFar + (LoadingScreen.gameLoadSteps[i].weight * subProgress / 100)
            end
            
            LoadingScreen.state.progress = math.min(1, progressSoFar)
            LoadingScreen.state.stepsCompleted = i - 1
            break
        end
    end
end

-- Actualizar
function LoadingScreen.update(dt)
    if not LoadingScreen.state.active then return false end
    
    -- Procesar tareas asíncronas
    LoadingScreen.processAsyncTasks(dt)
    
    -- Limpiar cache de recursos si es necesario
    LoadingScreen.cleanupResourceCache()
    
    LoadingScreen.state.elapsedTime = LoadingScreen.state.elapsedTime + dt
    LoadingScreen.state.animationTime = LoadingScreen.state.animationTime + dt
    
    -- Actualizar fade
    if LoadingScreen.state.fadeState == "in" then
        LoadingScreen.state.fadeAlpha = math.min(1, LoadingScreen.state.fadeAlpha + dt / LoadingScreen.config.fadeInTime)
        if LoadingScreen.state.fadeAlpha >= 1 then
            LoadingScreen.state.fadeState = "loading"
            -- Comenzar la carga real
            if LoadingScreen.state.loadFunction then
                LoadingScreen.executeLoadSteps()
            end
        end
    elseif LoadingScreen.state.fadeState == "loading" then
        -- Continuar ejecutando los pasos de carga
        -- Ejecutar múltiples pasos por frame para carga más fluida
        for i = 1, 2 do  -- Ejecutar 2 pasos por frame
            if LoadingScreen.loadIterator then
                LoadingScreen.resumeLoading()
            end
        end
    elseif LoadingScreen.state.fadeState == "out" then
        LoadingScreen.state.fadeAlpha = math.max(0, LoadingScreen.state.fadeAlpha - dt / LoadingScreen.config.fadeOutTime)
        if LoadingScreen.state.fadeAlpha <= 0 then
            LoadingScreen.state.fadeState = "done"
            LoadingScreen.state.active = false
            if LoadingScreen.state.onComplete then
                LoadingScreen.state.onComplete()
            end
            return false
        end
    end
    
    -- Actualizar animaciones
    LoadingScreen.updateAnimations(dt)
    
    -- Cambiar tip cada 3 segundos
    LoadingScreen.tipChangeTime = (LoadingScreen.tipChangeTime or 0) + dt
    if LoadingScreen.tipChangeTime > 3 then
        LoadingScreen.currentTip = LoadingScreen.tips[math.random(1, #LoadingScreen.tips)]
        LoadingScreen.tipChangeTime = 0
    end
    
    -- Verificar si la carga está completa
    if LoadingScreen.state.fadeState == "loading" and LoadingScreen.state.progress >= 1 then
        local minTimeElapsed = LoadingScreen.state.elapsedTime >= LoadingScreen.config.minLoadTime
        if minTimeElapsed then
            LoadingScreen.state.fadeState = "out"
        end
    end
    
    return true
end

-- Ejecutar pasos de carga (llamado una vez cuando comienza la carga real)
function LoadingScreen.executeLoadSteps()
    -- Crear el iterador de pasos de carga
    if LoadingScreen.state.loadFunction then
        LoadingScreen.loadIterator = LoadingScreen.state.loadFunction(LoadingScreen.updateProgress)
    end
end

-- Continuar la carga
function LoadingScreen.resumeLoading()
    if LoadingScreen.loadIterator then
        local completed = LoadingScreen.loadIterator()
        if completed then
            -- Carga completa
            LoadingScreen.state.progress = 1
            LoadingScreen.loadIterator = nil
        end
    end
end

-- Actualizar animaciones
function LoadingScreen.updateAnimations(dt)
    local time = LoadingScreen.state.animationTime
    
    -- Actualizar estrellas
    for _, star in ipairs(LoadingScreen.state.stars) do
        star.twinklePhase = star.twinklePhase + dt * star.twinkleSpeed
    end
    
    -- Actualizar nebulosas
    for _, nebula in ipairs(LoadingScreen.state.nebulae) do
        nebula.rotation = nebula.rotation + dt * nebula.rotationSpeed
        nebula.x = nebula.x + dt * 5 * nebula.rotationSpeed
        if nebula.x > love.graphics.getWidth() + nebula.size then
            nebula.x = -nebula.size
        end
    end
    
    -- Actualizar anillo de carga
    local ring = LoadingScreen.state.loadingRing
    ring.rotation = ring.rotation + dt * LoadingScreen.config.animation.rotationSpeed
    ring.pulseScale = 1 + math.sin(time * LoadingScreen.config.animation.pulseSpeed) * 0.1
    
    -- Activar segmentos según progreso
    local activeSegments = math.floor(LoadingScreen.state.progress * #ring.segments)
    for i, segment in ipairs(ring.segments) do
        if i <= activeSegments then
            segment.active = true
            segment.brightness = math.min(1, segment.brightness + dt * 3)
            segment.size = 1 + math.sin(time * LoadingScreen.config.animation.waveSpeed + segment.angle) * 0.2
        else
            segment.active = false
            segment.brightness = math.max(0.2, segment.brightness - dt * 2)
            segment.size = 1
        end
    end
end

-- Dibujar
function LoadingScreen.draw()
    if not LoadingScreen.state.active then return end
    
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local alpha = LoadingScreen.state.fadeAlpha
    
    -- Guardar estado
    love.graphics.push()
    love.graphics.reset() -- Reset transformations to ensure full screen coverage
    
    -- Fondo completo (asegurar que cubra toda la pantalla)
    love.graphics.setColor(LoadingScreen.config.colors.background[1],
                          LoadingScreen.config.colors.background[2],
                          LoadingScreen.config.colors.background[3],
                          1) -- Fondo siempre opaco
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Aplicar alpha para los elementos
    love.graphics.setColor(1, 1, 1, alpha)
    
    -- Dibujar estrellas
    LoadingScreen.drawStars(alpha)
    
    -- Dibujar nebulosas
    LoadingScreen.drawNebulae(alpha)
    
    -- Dibujar anillo de carga
    LoadingScreen.drawLoadingRing(width/2, height/2, alpha)
    
    -- Dibujar texto e información
    LoadingScreen.drawText(width/2, height/2, alpha)
    
    -- Dibujar barra de progreso
    LoadingScreen.drawProgressBar(width/2, height * 0.7, alpha)
    
    -- Dibujar tip
    LoadingScreen.drawTip(width/2, height * 0.85, alpha)
    
    -- Restaurar estado
    love.graphics.pop()
end

-- Dibujar estrellas
function LoadingScreen.drawStars(alpha)
    for _, star in ipairs(LoadingScreen.state.stars) do
        local twinkle = 0.5 + 0.5 * math.sin(star.twinklePhase)
        local brightness = star.brightness * twinkle
        
        love.graphics.setColor(1, 1, 1, brightness * alpha * 0.8)
        love.graphics.circle("fill", star.x, star.y, star.size)
    end
end

-- Dibujar nebulosas
function LoadingScreen.drawNebulae(alpha)
    for _, nebula in ipairs(LoadingScreen.state.nebulae) do
        love.graphics.push()
        love.graphics.translate(nebula.x, nebula.y)
        love.graphics.rotate(nebula.rotation)
        
        -- Intentar usar el shader actual de nebulosa
        local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("nebula") or nil
        local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
        
        if shader and img then
            -- Seed persistente por nebulosa
            nebula.seed = nebula.seed or (math.random() * 1000)
            
            love.graphics.setShader(shader)
            shader:send("u_time", love.timer.getTime())
            shader:send("u_seed", nebula.seed)
            shader:send("u_parallax", 0.0)
            shader:send("u_sparkleStrength", 0.0)
            -- Mantener intensidad/brillo en defaults (configurados en ShaderManager),
            -- el fade lo manejamos vía setColor
            
            -- Color + fade del loading
            love.graphics.setColor(nebula.color[1], nebula.color[2], nebula.color[3], nebula.color[4] * alpha)
            
            -- Dibujar textura base centrada y escalada
            local scale = (nebula.size * 2) / img:getWidth()
            love.graphics.draw(img, 0, 0, 0, scale, scale, img:getWidth() / 2, img:getHeight() / 2)
            
            love.graphics.setShader()
        else
            -- Fallback: gradiente de círculos (modo anterior)
            for i = 10, 1, -1 do
                local scale = i / 10
                local alphaScale = (1 - scale) * 0.5
                love.graphics.setColor(nebula.color[1], nebula.color[2], nebula.color[3],
                                       nebula.color[4] * alphaScale * alpha)
                love.graphics.circle("fill", 0, 0, nebula.size * scale)
            end
        end
        
        love.graphics.pop()
    end
end

-- Dibujar anillo de carga
function LoadingScreen.drawLoadingRing(x, y, alpha)
    local ring = LoadingScreen.state.loadingRing
    local radius = 80
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(ring.rotation)
    love.graphics.scale(ring.pulseScale, ring.pulseScale)
    
    -- Dibujar segmentos
    for i, segment in ipairs(ring.segments) do
        local angle = segment.angle
        local nextAngle = ring.segments[i % #ring.segments + 1].angle
        
        -- Color del segmento
        if segment.active then
            love.graphics.setColor(LoadingScreen.config.colors.primary[1],
                                  LoadingScreen.config.colors.primary[2],
                                  LoadingScreen.config.colors.primary[3],
                                  segment.brightness * alpha)
        else
            love.graphics.setColor(LoadingScreen.config.colors.textDim[1],
                                  LoadingScreen.config.colors.textDim[2],
                                  LoadingScreen.config.colors.textDim[3],
                                  segment.brightness * alpha * 0.3)
        end
        
        -- Dibujar segmento como línea gruesa
        local x1 = math.cos(angle) * radius
        local y1 = math.sin(angle) * radius
        local x2 = math.cos(angle) * (radius + 10 * segment.size)
        local y2 = math.sin(angle) * (radius + 10 * segment.size)
        
        love.graphics.setLineWidth(3)
        love.graphics.line(x1, y1, x2, y2)
        
        -- Punto brillante en segmentos activos
        if segment.active and segment.brightness > 0.8 then
            love.graphics.setColor(1, 1, 1, segment.brightness * alpha)
            love.graphics.circle("fill", x2, y2, 2)
        end
    end
    
    -- Círculo interior
    love.graphics.setColor(LoadingScreen.config.colors.primary[1],
                          LoadingScreen.config.colors.primary[2],
                          LoadingScreen.config.colors.primary[3],
                          0.3 * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, radius - 5)
    
    -- Círculo exterior
    love.graphics.circle("line", 0, 0, radius + 15)
    
    love.graphics.pop()
end

-- Dibujar texto
function LoadingScreen.drawText(x, y, alpha)
    -- Título
    love.graphics.setFont(LoadingScreen.fonts.title)
    love.graphics.setColor(LoadingScreen.config.colors.text[1],
                          LoadingScreen.config.colors.text[2],
                          LoadingScreen.config.colors.text[3],
                          alpha)
    love.graphics.printf("GENERATING UNIVERSE", 0, y - 200, love.graphics.getWidth(), "center")
    
    -- Paso actual
    love.graphics.setFont(LoadingScreen.fonts.step)
    love.graphics.setColor(LoadingScreen.config.colors.primary[1],
                          LoadingScreen.config.colors.primary[2],
                          LoadingScreen.config.colors.primary[3],
                          alpha)
    love.graphics.printf(LoadingScreen.state.currentStep, 0, y + 130, love.graphics.getWidth(), "center")
    
    -- Substep si existe
    if LoadingScreen.state.subStep and LoadingScreen.state.subStep ~= "" then
        love.graphics.setFont(LoadingScreen.fonts.small)
        love.graphics.setColor(LoadingScreen.config.colors.textDim[1],
                              LoadingScreen.config.colors.textDim[2],
                              LoadingScreen.config.colors.textDim[3],
                              alpha)
        love.graphics.printf(LoadingScreen.state.subStep, 0, y + 155, love.graphics.getWidth(), "center")
    end
    
    -- Porcentaje
    love.graphics.setFont(LoadingScreen.fonts.progress)
    love.graphics.setColor(LoadingScreen.config.colors.accent[1],
                          LoadingScreen.config.colors.accent[2],
                          LoadingScreen.config.colors.accent[3],
                          alpha)
    local percentage = math.floor(LoadingScreen.state.progress * 100)
    love.graphics.printf(percentage .. "%", x - 50, y - 10, 100, "center")
end

-- Dibujar barra de progreso
function LoadingScreen.drawProgressBar(x, y, alpha)
    local barWidth = 400
    local barHeight = 6
    local cornerRadius = 3
    
    -- Fondo de la barra
    love.graphics.setColor(LoadingScreen.config.colors.textDim[1],
                          LoadingScreen.config.colors.textDim[2],
                          LoadingScreen.config.colors.textDim[3],
                          0.3 * alpha)
    love.graphics.rectangle("fill", x - barWidth/2, y - barHeight/2, barWidth, barHeight, cornerRadius)
    
    -- Barra de progreso
    local progress = LoadingScreen.state.progress
    if progress > 0 then
        -- Gradiente de color
        local r = LoadingScreen.config.colors.secondary[1] * (1 - progress) + LoadingScreen.config.colors.accent[1] * progress
        local g = LoadingScreen.config.colors.secondary[2] * (1 - progress) + LoadingScreen.config.colors.accent[2] * progress
        local b = LoadingScreen.config.colors.secondary[3] * (1 - progress) + LoadingScreen.config.colors.accent[3] * progress
        
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.rectangle("fill", x - barWidth/2, y - barHeight/2, barWidth * progress, barHeight, cornerRadius)
        
        -- Brillo en el borde
        love.graphics.setColor(1, 1, 1, 0.5 * alpha)
        love.graphics.rectangle("fill", x - barWidth/2 + barWidth * progress - 2, y - barHeight/2, 2, barHeight)
    end
    
    -- Indicadores de pasos
    love.graphics.setColor(LoadingScreen.config.colors.text[1],
                          LoadingScreen.config.colors.text[2],
                          LoadingScreen.config.colors.text[3],
                          0.5 * alpha)
    for i, step in ipairs(LoadingScreen.gameLoadSteps) do
        local stepX = x - barWidth/2 + barWidth * step.weight * (i - 1) / LoadingScreen.state.totalSteps
        if i <= LoadingScreen.state.stepsCompleted then
            love.graphics.setColor(LoadingScreen.config.colors.accent[1],
                                  LoadingScreen.config.colors.accent[2],
                                  LoadingScreen.config.colors.accent[3],
                                  alpha)
        end
        love.graphics.circle("fill", stepX, y, 3)
    end
    
    -- Texto de progreso
    love.graphics.setFont(LoadingScreen.fonts.small)
    love.graphics.setColor(LoadingScreen.config.colors.textDim[1],
                          LoadingScreen.config.colors.textDim[2],
                          LoadingScreen.config.colors.textDim[3],
                          alpha)
    local stepText = string.format("Step %d of %d", LoadingScreen.state.currentStepIndex, LoadingScreen.state.totalSteps)
    love.graphics.printf(stepText, 0, y + 15, love.graphics.getWidth(), "center")
end

-- Dibujar tip
function LoadingScreen.drawTip(x, y, alpha)
    love.graphics.setFont(LoadingScreen.fonts.tips)
    love.graphics.setColor(LoadingScreen.config.colors.textDim[1],
                          LoadingScreen.config.colors.textDim[2],
                          LoadingScreen.config.colors.textDim[3],
                          alpha * 0.8)
    love.graphics.printf("TIP: " .. LoadingScreen.currentTip, 100, y, love.graphics.getWidth() - 200, "center")
end

-- Gestión de carga asíncrona
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
        local currentTime = love.timer.getTime()
        if currentTime - startTime > maxTime then
            break -- Evitar bloquear el frame
        end
        
        local task = table.remove(LoadingScreen.state.asyncLoader.taskQueue, 1)
        LoadingScreen.state.asyncLoader.currentTask = task
        
        -- Ejecutar tarea
        local success, result = pcall(task.func)
        if not success then
            print("Error in async task '" .. task.name .. "': " .. tostring(result))
        end
        
        LoadingScreen.state.asyncLoader.currentTask = nil
    end
    
    LoadingScreen.state.asyncLoader.lastFrameTime = love.timer.getTime() - startTime
end

-- Gestión de cache de recursos
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
        -- Estimar uso de memoria (aproximado)
        LoadingScreen.state.resourceCache.memoryUsage = LoadingScreen.state.resourceCache.memoryUsage + 1024
    end
    
    return asset
end

function LoadingScreen.cleanupResourceCache()
    local memoryUsage = LoadingScreen.state.resourceCache.memoryUsage
    local maxMemory = LoadingScreen.state.resourceCache.maxMemoryUsage
    
    if memoryUsage > maxMemory then
        -- Limpiar assets menos utilizados
        LoadingScreen.state.resourceCache.preloadedAssets = {}
        LoadingScreen.state.resourceCache.memoryUsage = 0
        print("LoadingScreen: Resource cache cleaned due to memory limit")
    end
end

-- Función para actualizar el progreso
function LoadingScreen.setProgress(progress)
    LoadingScreen.state.progress = math.max(0, math.min(1, progress))
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

-- Verificar si está activo
function LoadingScreen.isActive()
    return LoadingScreen.state.active
end

-- Forzar completado (para debug)
function LoadingScreen.forceComplete()
    LoadingScreen.state.progress = 1
    LoadingScreen.state.fadeState = "out"
end

-- Manejar redimensionamiento de ventana
function LoadingScreen.resize(w, h)
    if LoadingScreen.state.active then
        -- Regenerar elementos visuales para el nuevo tamaño
        LoadingScreen.generateStars()
        LoadingScreen.generateNebulae()
    end
end

return LoadingScreen