-- src/maps/optimized_renderer.lua
-- Sistema de renderizado optimizado con LOD, culling y batching

local OptimizedRenderer = {}
local CoordinateSystem = require 'src.maps.coordinate_system'
local StarShader = require 'src.shaders.star_shader'
local BiomeSystem = require 'src.maps.biome_system'

-- Configuración del renderizador
OptimizedRenderer.config = {
    -- Niveles de detalle (LOD)
    lod = {
        levels = {
            [0] = {distance = 0,    name = "High",   detail = 1.0},   -- Alto detalle
            [1] = {distance = 800,  name = "Medium", detail = 0.7},   -- Detalle medio
            [2] = {distance = 1600, name = "Low",    detail = 0.4},   -- Bajo detalle
            [3] = {distance = 3200, name = "Minimal", detail = 0.2}   -- Detalle mínimo
        },
        transitionSmoothing = true
    },
    
    -- Frustum culling
    culling = {
        enabled = true,
        margin = 150,           -- Margen extra para culling
        hierarchical = true,    -- Culling jerárquico
        temporal = true         -- Culling temporal (basado en movimiento)
    },
    
    -- Batch rendering
    batching = {
        enabled = true,
        maxBatchSize = 10000,   -- Máximo objetos por batch
        autoSort = true,        -- Ordenamiento automático por textura/tipo
        dynamicBatching = true  -- Batching dinámico basado en visibilidad
    },
    
    -- Optimizaciones de performance
    performance = {
        maxDrawCalls = 500,     -- Máximo draw calls por frame
        targetFrameTime = 0.016, -- Target 60 FPS (16.6ms)
        adaptiveQuality = true,  -- Calidad adaptativa basada en performance
        earlyZReject = true     -- Rechazo temprano de objetos no visibles
    },
    
    -- Controles visuales del shader de estrellas
    starVisuals = {
        haloMultiplier = 1.0,
        flareMultiplier = 1.0,
        coreMultiplier = 1.0
    },
    
    -- Debug y estadísticas
    debug = {
        showLODLevels = false,
        showCullingBounds = false,
        showBatches = false,
        enableStats = true
    }
}

-- Estado del renderizador
OptimizedRenderer.state = {
    -- Batches de renderizado
    batches = {
        stars = nil,
        asteroids = nil,
        nebulae = nil,
        stations = nil,
        effects = nil
    },
    
    -- Cache de objetos visibles
    visibilityCache = {},
    lastCameraPosition = {x = 0, y = 0, zoom = 1},
    cacheValidFrames = 0,
    
    -- Estadísticas de performance
    stats = {
        frameTime = 0,
        drawCalls = 0,
        objectsRendered = 0,
        objectsCulled = 0,
        batchesUsed = 0,
        lodDistribution = {[0] = 0, [1] = 0, [2] = 0, [3] = 0},
        cullingEfficiency = 0,
        lastFrameStats = {}
    },
    
    -- Sistema de calidad adaptativa
    adaptiveQuality = {
        currentLevel = 1.0,
        targetFrameTime = 0.016,
        adjustmentCooldown = 0,
        -- Acumuladores sin asignaciones por frame
        sampleAccumTime = 0,
        sampleAccumFrames = 0,
        sampleWindow = 0.5, -- segundos
        timeSinceLastAdjust = 0
    }
}

-- Inicializar el renderizador
function OptimizedRenderer.init()
    -- Inicializar shader de estrellas primero (para que whiteImage exista)
    if StarShader and StarShader.init then
        StarShader.init()
        if StarShader.setVisualConfig then
            StarShader.setVisualConfig({
                haloMultiplier = OptimizedRenderer.config.starVisuals.haloMultiplier,
                flareMultiplier = OptimizedRenderer.config.starVisuals.flareMultiplier,
                coreMultiplier  = OptimizedRenderer.config.starVisuals.coreMultiplier
            })
        end
    end

    -- Crear batches si el batching está habilitado
    if OptimizedRenderer.config.batching.enabled then
        -- Crear SpriteBatches
        OptimizedRenderer.createSpriteBatches()

        -- Cachear visuales por bioma para tint y brillo (sin costos por frame)
        local BT = BiomeSystem.BiomeType
        local function cfg(typeId, brightnessMul)
            local c = BiomeSystem.getBiomeConfig(typeId).color or {1,1,1,1}
            OptimizedRenderer.state.biomeVisuals[typeId] = {
                color = {c[1], c[2], c[3]},
                brightness = brightnessMul or 1.0
            }
        end
        cfg(BT.DEEP_SPACE,       0.97)
        cfg(BT.NEBULA_FIELD,     1.07)
        cfg(BT.ASTEROID_BELT,    0.93)
        cfg(BT.GRAVITY_ANOMALY,  1.08)
        cfg(BT.RADIOACTIVE_ZONE, 1.12)
        cfg(BT.ANCIENT_RUINS,    0.95)
    end
    
    -- Inicializar cache de visibilidad
    OptimizedRenderer.state.visibilityCache = {}
    
    -- Reset estadísticas
    OptimizedRenderer.resetStats()

    print("OptimizedRenderer initialized")
    print("Batching: " .. (OptimizedRenderer.config.batching.enabled and "ON" or "OFF"))
    print("LOD Levels: " .. #OptimizedRenderer.config.lod.levels)
    print("Frustum Culling: " .. (OptimizedRenderer.config.culling.enabled and "ON" or "OFF"))
end

-- Crear sprite batches para diferentes tipos de objetos
function OptimizedRenderer.createSpriteBatches()
    if not love.graphics then return end
    
    -- Usar imagen blanca 1x1 del shader si está disponible; fallback a un canvas 1x1
    local baseImage = StarShader and StarShader.getWhiteImage and StarShader.getWhiteImage() or nil
    if not baseImage then
        local data = love.image.newImageData(1, 1)
        data:setPixel(0, 0, 1, 1, 1, 1)
        baseImage = love.graphics.newImage(data)
    end
    
    OptimizedRenderer.state.batches.stars = love.graphics.newSpriteBatch(
        baseImage, OptimizedRenderer.config.batching.maxBatchSize
    )
    
    print("SpriteBatch for stars created successfully")
end

-- Calcular nivel de LOD basado en distancia y zoom
function OptimizedRenderer.calculateLOD(objectX, objectY, camera)
    if not camera then return 0 end
    
    -- Convertir coordenadas del mundo a relativas para precisión
    local relX, relY = CoordinateSystem.worldToRelative(objectX, objectY)
    local camRelX, camRelY = CoordinateSystem.worldToRelative(camera.x, camera.y)
    
    -- Calcular distancia relativa
    local dx = relX - camRelX
    local dy = relY - camRelY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Ajustar por zoom
    local adjustedDistance = distance / (camera.zoom or 1)
    
    -- Determinar nivel de LOD
    for level = #OptimizedRenderer.config.lod.levels - 1, 0, -1 do
        if adjustedDistance >= OptimizedRenderer.config.lod.levels[level].distance then
            return level
        end
    end
    
    return 0
end

-- Verificar si un objeto está visible (frustum culling optimizado)
function OptimizedRenderer.isObjectVisible(objectX, objectY, objectSize, camera)
    if not camera or not OptimizedRenderer.config.culling.enabled then
        return true
    end
    
    -- Convertir a coordenadas relativas
    local relX, relY = CoordinateSystem.worldToRelative(objectX, objectY)
    local camRelX, camRelY = CoordinateSystem.worldToRelative(camera.x, camera.y)
    
    -- Calcular posición en pantalla
    local screenX = (relX - camRelX) * camera.zoom + love.graphics.getWidth() / 2
    local screenY = (relY - camRelY) * camera.zoom + love.graphics.getHeight() / 2
    
    -- Calcular tamaño en pantalla
    local screenSize = objectSize * camera.zoom
    
    -- Verificar bounds con margen
    local margin = OptimizedRenderer.config.culling.margin
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    return screenX + screenSize >= -margin and
           screenX - screenSize <= screenWidth + margin and
           screenY + screenSize >= -margin and
           screenY - screenSize <= screenHeight + margin
end

-- Frustum culling jerárquico para chunks
function OptimizedRenderer.isChunkVisible(chunk, camera)
    if not camera or not OptimizedRenderer.config.culling.enabled then
        return true
    end
    
    -- Verificar bounds del chunk
    local bounds = chunk.bounds
    if not bounds then return true end
    
    -- Calcular esquinas del chunk en coordenadas relativas
    local relLeft, relTop = CoordinateSystem.worldToRelative(bounds.left, bounds.top)
    local relRight, relBottom = CoordinateSystem.worldToRelative(bounds.right, bounds.bottom)
    local camRelX, camRelY = CoordinateSystem.worldToRelative(camera.x, camera.y)
    
    -- Convertir a coordenadas de pantalla
    local screenLeft = (relLeft - camRelX) * camera.zoom + love.graphics.getWidth() / 2
    local screenRight = (relRight - camRelX) * camera.zoom + love.graphics.getWidth() / 2
    local screenTop = (relTop - camRelY) * camera.zoom + love.graphics.getHeight() / 2
    local screenBottom = (relBottom - camRelY) * camera.zoom + love.graphics.getHeight() / 2
    
    -- Verificar intersección con viewport
    local margin = OptimizedRenderer.config.culling.margin
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    return not (screenRight < -margin or screenLeft > screenWidth + margin or
                screenBottom < -margin or screenTop > screenHeight + margin)
end

-- Actualizar cache de visibilidad
function OptimizedRenderer.updateVisibilityCache(camera)
    if not camera then return end
    
    local currentPos = {x = camera.x, y = camera.y, zoom = camera.zoom}
    local lastPos = OptimizedRenderer.state.lastCameraPosition
    
    -- Verificar si la cámara se movió significativamente
    local dx = currentPos.x - lastPos.x
    local dy = currentPos.y - lastPos.y
    local dzoom = math.abs(currentPos.zoom - lastPos.zoom)
    
    local cameraMovement = math.sqrt(dx * dx + dy * dy)
    local significantMovement = cameraMovement > 50 or dzoom > 0.1
    
    -- Invalidar cache si hay movimiento significativo
    if significantMovement then
        OptimizedRenderer.state.visibilityCache = {}
        OptimizedRenderer.state.lastCameraPosition = currentPos
        OptimizedRenderer.state.cacheValidFrames = 0
    else
        OptimizedRenderer.state.cacheValidFrames = OptimizedRenderer.state.cacheValidFrames + 1
    end
end

-- Renderizar objetos con LOD y culling
function OptimizedRenderer.renderObjects(objects, objectType, camera, chunkX, chunkY)
    if not objects or not camera then return 0 end
    
    local renderedCount = 0
    local culledCount = 0
    
    for _, obj in ipairs(objects) do
        -- Calcular posición mundial del objeto
        local worldX = chunkX * 48 * 32 + (obj.x or 0)  -- Usar configuración del chunk
        local worldY = chunkY * 48 * 32 + (obj.y or 0)
        
        -- Frustum culling
        local objSize = obj.size or 10
        if OptimizedRenderer.isObjectVisible(worldX, worldY, objSize, camera) then
            -- Calcular LOD
            local lodLevel = OptimizedRenderer.calculateLOD(worldX, worldY, camera)
            obj.lodLevel = lodLevel  -- Guardar para estadísticas
            
            -- Renderizar según el tipo y LOD
            OptimizedRenderer.renderSingleObject(obj, objectType, worldX, worldY, lodLevel, camera)
            renderedCount = renderedCount + 1
            
            -- Actualizar estadísticas de LOD
            OptimizedRenderer.state.stats.lodDistribution[lodLevel] = 
                (OptimizedRenderer.state.stats.lodDistribution[lodLevel] or 0) + 1
        else
            culledCount = culledCount + 1
        end
    end
    
    -- Actualizar estadísticas
    OptimizedRenderer.state.stats.objectsRendered = OptimizedRenderer.state.stats.objectsRendered + renderedCount
    OptimizedRenderer.state.stats.objectsCulled = OptimizedRenderer.state.stats.objectsCulled + culledCount
    
    return renderedCount
end

-- Renderizar objeto individual con LOD
function OptimizedRenderer.renderSingleObject(obj, objectType, worldX, worldY, lodLevel, camera)
    local lodConfig = OptimizedRenderer.config.lod.levels[lodLevel]
    local detailLevel = lodConfig.detail
    
    -- Convertir a coordenadas relativas para renderizado
    local relX, relY = CoordinateSystem.worldToRelative(worldX, worldY)
    local camRelX, camRelY = CoordinateSystem.worldToRelative(camera.x, camera.y)
    
    -- Calcular posición de renderizado
    local renderX = (relX - camRelX) * camera.zoom + love.graphics.getWidth() / 2
    local renderY = (relY - camRelY) * camera.zoom + love.graphics.getHeight() / 2
    
    -- Ajustar tamaño según LOD
    local renderSize = (obj.size or 10) * camera.zoom * detailLevel
    
    -- Renderizar según tipo
    if objectType == "stars" then
        OptimizedRenderer.renderStar(obj, renderX, renderY, renderSize, lodLevel)
    elseif objectType == "nebulae" then
        OptimizedRenderer.renderNebula(obj, renderX, renderY, renderSize, lodLevel)
    elseif objectType == "asteroids" then
        OptimizedRenderer.renderAsteroid(obj, renderX, renderY, renderSize, lodLevel)
    elseif objectType == "stations" then
        OptimizedRenderer.renderStation(obj, renderX, renderY, renderSize, lodLevel)
    end
    
    OptimizedRenderer.state.stats.drawCalls = OptimizedRenderer.state.stats.drawCalls + 1
end

-- Renderizar estrella con LOD
function OptimizedRenderer.renderStar(star, x, y, size, lodLevel)
    local r, g, b, a = love.graphics.getColor()
    
    -- Ajustar propiedades según LOD
    local alpha = star.color and star.color[4] or 1
    local brightness = star.brightness or 1
    
    if lodLevel >= 3 then
        -- LOD mínimo - solo puntos
        love.graphics.setColor(star.color[1], star.color[2], star.color[3], alpha * 0.8)
        love.graphics.points(x, y)
    elseif lodLevel >= 2 then
        -- LOD bajo - círculos simples
        love.graphics.setColor(star.color[1], star.color[2], star.color[3], alpha * 0.9)
        love.graphics.circle("fill", x, y, math.max(1, size * 0.5), 6)
    elseif lodLevel >= 1 then
        -- LOD medio - círculos con brillo
        love.graphics.setColor(star.color[1], star.color[2], star.color[3], alpha * 0.3)
        love.graphics.circle("fill", x, y, size * 1.5, 8)
        love.graphics.setColor(star.color[1], star.color[2], star.color[3], alpha)
        love.graphics.circle("fill", x, y, size, 8)
    else
        -- LOD alto - efectos completos
        OptimizedRenderer.renderStarHighDetail(star, x, y, size)
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Renderizar estrella con alto detalle
function OptimizedRenderer.renderStarHighDetail(star, x, y, size)
    local time = OptimizedRenderer.state.frameNow or love.timer.getTime()
    local color = star.color or {1, 1, 1, 1}
    local brightness = star.brightness or 1

    -- Calcular parpadeo (twinkle)
    local twinklePhase = time * (star.twinkleSpeed or 1) + (star.twinkle or 0)
    local twinkle = 0.8 + 0.2 * math.sin(twinklePhase * 2)

    -- Si hay shader y batching está habilitado, agregar al SpriteBatch
    if StarShader and StarShader.getShader and StarShader.getShader() and OptimizedRenderer.config.batching.enabled and OptimizedRenderer.state.batches.stars then
        -- Sizing del quad según tipo (aprox)
        local starType = star.type or 1
        local quadMul = (starType == 4) and 4.0 or (starType == 1 and 2.6 or 3.0)
        local s = math.max(2, size * quadMul)

        -- Color final modulado por brillo, twinkle y tinte por bioma (batch-friendly)
        local baseR, baseG, baseB = (color[1] or 1), (color[2] or 1), (color[3] or 1)
        local biomeVis = OptimizedRenderer.state.biomeVisuals and OptimizedRenderer.state.biomeVisuals[star.biomeType or 0]
        if biomeVis then
            -- Mezcla suave hacia el color del bioma (15%) y aplicar multiplicador de brillo del bioma
            local tint = biomeVis.color
            baseR = baseR * 0.85 + tint[1] * 0.15
            baseG = baseG * 0.85 + tint[2] * 0.15
            baseB = baseB * 0.85 + tint[3] * 0.15
            brightness = brightness * biomeVis.brightness
        end

        local r = baseR * brightness * twinkle
        local g = baseG * brightness * twinkle
        local b = baseB * brightness * twinkle
        local a = color[4] or 1

        local batch = OptimizedRenderer.state.batches.stars
        -- Flush preventivo si nos acercamos al límite del batch
        local maxCount = OptimizedRenderer.config.batching.maxBatchSize or 10000
        if batch:getCount() >= (maxCount - 512) then
            local sh = StarShader and StarShader.getShader and StarShader.getShader() or nil
            if sh then love.graphics.setShader(sh) end
            love.graphics.draw(batch)
            if sh then love.graphics.setShader() end
            batch:clear()
        end
        batch:setColor(r, g, b, a)
        -- Origen 0.5,0.5 para escalar desde el centro
        batch:add(x, y, 0, s, s, 0.5, 0.5)
        return
    end

    -- Fallback CPU si no hay shader o no hay batching
    love.graphics.setColor(color[1], color[2], color[3], color[4] * 0.2 * twinkle)
    love.graphics.circle("fill", x, y, size * 2, 12)
    love.graphics.setColor(color[1], color[2], color[3], color[4] * twinkle)
    love.graphics.circle("fill", x, y, size, 8)
    love.graphics.setColor(1, 1, 1, twinkle)
    love.graphics.circle("fill", x, y, size * 0.3, 4)
end

-- Renderizar nebulosa con LOD
function OptimizedRenderer.renderNebula(nebula, x, y, size, lodLevel)
    local r, g, b, a = love.graphics.getColor()
    local color = nebula.color or {0.5, 0.3, 0.8, 0.5}
    local intensity = nebula.intensity or 0.5
    
    if lodLevel >= 2 then
        -- LOD bajo - círculo simple
        love.graphics.setColor(color[1], color[2], color[3], color[4] * intensity * 0.8)
        love.graphics.circle("fill", x, y, size * 0.8, 8)
    else
        -- LOD alto - efecto de pulso
        local time = love.timer.getTime()
        local pulse = 0.9 + 0.1 * math.sin(time * 0.8)
        
        love.graphics.setColor(color[1], color[2], color[3], color[4] * intensity * pulse)
        love.graphics.circle("fill", x, y, size * pulse, 16)
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Renderizar asteroide con LOD
function OptimizedRenderer.renderAsteroid(asteroid, x, y, size, lodLevel)
    local r, g, b, a = love.graphics.getColor()
    local color = {0.4, 0.3, 0.2}  -- Color base del asteroide
    
    if lodLevel >= 3 then
        -- LOD mínimo - punto
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.points(x, y)
    elseif lodLevel >= 2 then
        -- LOD bajo - círculo simple
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.circle("fill", x, y, size, 6)
    elseif lodLevel >= 1 then
        -- LOD medio - círculo con sombra
        love.graphics.setColor(0.1, 0.1, 0.1, 0.3)
        love.graphics.circle("fill", x + 1, y + 1, size)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.circle("fill", x, y, size, 8)
    else
        -- LOD alto - detalles completos
        love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
        love.graphics.circle("fill", x + 2, y + 2, size + 1)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.circle("fill", x, y, size)
        
        -- Detalles de superficie
        love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 1)
        for i = 1, 3 do
            local angle = (i / 3) * math.pi * 2
            local detailX = x + math.cos(angle) * size * 0.3
            local detailY = y + math.sin(angle) * size * 0.3
            love.graphics.circle("fill", detailX, detailY, size * 0.15)
        end
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Renderizar estación con LOD
function OptimizedRenderer.renderStation(station, x, y, size, lodLevel)
    local r, g, b, a = love.graphics.getColor()
    
    if lodLevel >= 2 then
        -- LOD bajo - cuadrado simple
        love.graphics.setColor(0.6, 0.6, 0.8, 1)
        love.graphics.rectangle("fill", x - size/2, y - size/2, size, size)
    else
        -- LOD alto - detalles completos
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate((station.rotation or 0) + love.timer.getTime() * 0.1)
        
        -- Sombra
        love.graphics.setColor(0.1, 0.1, 0.1, 0.3)
        love.graphics.circle("fill", 2, 2, size * 1.1)
        
        -- Cuerpo principal
        love.graphics.setColor(0.6, 0.6, 0.8, 1)
        love.graphics.circle("fill", 0, 0, size)
        
        -- Detalles
        love.graphics.setColor(0.3, 0.5, 0.8, 1)
        love.graphics.circle("line", 0, 0, size * 0.8)
        
        -- Luces parpadeantes
        if math.sin(love.timer.getTime() * 3) > 0 then
            love.graphics.setColor(0, 1, 0, 1)
            love.graphics.circle("fill", size * 0.7, 0, 2)
            love.graphics.circle("fill", -size * 0.7, 0, 2)
        end
        
        love.graphics.pop()
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Sistema de calidad adaptativa
function OptimizedRenderer.updateAdaptiveQuality(dt)
    if not OptimizedRenderer.config.performance.adaptiveQuality then return end
    
    local adaptive = OptimizedRenderer.state.adaptiveQuality
    local frameTime = OptimizedRenderer.state.stats.frameTime
    
    -- Acumular sin asignaciones
    adaptive.sampleAccumTime = adaptive.sampleAccumTime + frameTime
    adaptive.sampleAccumFrames = adaptive.sampleAccumFrames + 1
    adaptive.timeSinceLastAdjust = adaptive.timeSinceLastAdjust + dt

    if adaptive.timeSinceLastAdjust >= adaptive.sampleWindow then
        local avgFrameTime = adaptive.sampleAccumTime / math.max(1, adaptive.sampleAccumFrames)
        adaptive.adjustmentCooldown = adaptive.adjustmentCooldown - adaptive.timeSinceLastAdjust

        if adaptive.adjustmentCooldown <= 0 then
            if avgFrameTime > adaptive.targetFrameTime * 1.2 then
                adaptive.currentLevel = math.max(0.5, adaptive.currentLevel - 0.1)
                adaptive.adjustmentCooldown = 1.0
            elseif avgFrameTime < adaptive.targetFrameTime * 0.8 then
                adaptive.currentLevel = math.min(1.0, adaptive.currentLevel + 0.05)
                adaptive.adjustmentCooldown = 2.0
            end
            OptimizedRenderer.applyQualitySettings(adaptive.currentLevel)
        end

        -- Reset acumuladores de la ventana
        adaptive.sampleAccumTime = 0
        adaptive.sampleAccumFrames = 0
        adaptive.timeSinceLastAdjust = 0
    end
end

-- Aplicar configuración de calidad
function OptimizedRenderer.applyQualitySettings(qualityLevel)
    -- Ajustar distancias de LOD
    for level, config in pairs(OptimizedRenderer.config.lod.levels) do
        config.distance = config.distance * (2 - qualityLevel)
    end
    
    -- Ajustar tamaño de batches
    local batchMultiplier = 0.5 + qualityLevel * 0.5
    OptimizedRenderer.config.batching.maxBatchSize = 
        math.floor(10000 * batchMultiplier)
end

-- Reset contadores del frame sin reasignaciones
function OptimizedRenderer.resetFrameStats()
    local stats = OptimizedRenderer.state.stats
    if not stats then return end
    stats.drawCalls = 0
    stats.objectsRendered = 0
    stats.objectsCulled = 0
    stats.batchesUsed = 0
    if stats.lodDistribution then
        stats.lodDistribution[0] = 0
        stats.lodDistribution[1] = 0
        stats.lodDistribution[2] = 0
        stats.lodDistribution[3] = 0
    end
end

-- Renderizado principal
function OptimizedRenderer.render(visibleChunks, camera)
    local startTime = love.timer.getTime()
    OptimizedRenderer.state.frameNow = startTime
    
    -- Reset estadísticas del frame
    OptimizedRenderer.resetFrameStats()
    
    -- Actualizar cache de visibilidad
    OptimizedRenderer.updateVisibilityCache(camera)
    
    -- Renderizar chunks visibles
    for _, chunk in ipairs(visibleChunks) do
        if OptimizedRenderer.isChunkVisible(chunk, camera) then
            OptimizedRenderer.renderChunk(chunk, camera)
        end
    end
    
    -- Finalizar batches si están habilitados
    if OptimizedRenderer.config.batching.enabled then
        OptimizedRenderer.flushBatches()
    end
    
    -- Actualizar estadísticas
    OptimizedRenderer.state.stats.frameTime = love.timer.getTime() - startTime
    OptimizedRenderer.updateAdaptiveQuality(OptimizedRenderer.state.stats.frameTime)
    
    -- Calcular eficiencia de culling
    local totalObjects = OptimizedRenderer.state.stats.objectsRendered + OptimizedRenderer.state.stats.objectsCulled
    if totalObjects > 0 then
        OptimizedRenderer.state.stats.cullingEfficiency = 
            OptimizedRenderer.state.stats.objectsCulled / totalObjects
    end
end

-- Renderizar chunk individual
function OptimizedRenderer.renderChunk(chunk, camera)
    -- Renderizar estrellas
    if chunk.objects and chunk.objects.stars then
        OptimizedRenderer.renderObjects(chunk.objects.stars, "stars", camera, chunk.x, chunk.y)
    end
    
    -- Renderizar nebulosas
    if chunk.objects and chunk.objects.nebulae then
        OptimizedRenderer.renderObjects(chunk.objects.nebulae, "nebulae", camera, chunk.x, chunk.y)
    end
    
    -- Renderizar asteroides (desde tiles)
    if chunk.tiles then
        OptimizedRenderer.renderAsteroids(chunk, camera)
    end
    
    -- Renderizar objetos especiales
    if chunk.specialObjects then
        OptimizedRenderer.renderObjects(chunk.specialObjects, "stations", camera, chunk.x, chunk.y)
    end
end

-- Renderizar asteroides desde tiles
function OptimizedRenderer.renderAsteroids(chunk, camera)
    local chunkSize = 48  -- Configuración del chunk
    local tileSize = 32
    
    for y = 0, chunkSize - 1 do
        for x = 0, chunkSize - 1 do
            local tileType = chunk.tiles[y] and chunk.tiles[y][x]
            if tileType and tileType >= 1 and tileType <= 3 then  -- Tipos de asteroides
                local worldX = chunk.x * chunkSize * tileSize + x * tileSize
                local worldY = chunk.y * chunkSize * tileSize + y * tileSize
                
                local asteroidSize = ({8, 15, 25})[tileType] or 8
                
                if OptimizedRenderer.isObjectVisible(worldX, worldY, asteroidSize, camera) then
                    local lodLevel = OptimizedRenderer.calculateLOD(worldX, worldY, camera)
                    
                    -- Crear objeto asteroide temporal
                    local asteroid = {
                        type = tileType,
                        size = asteroidSize,
                        x = x * tileSize,
                        y = y * tileSize
                    }
                    
                    OptimizedRenderer.renderSingleObject(asteroid, "asteroids", worldX, worldY, lodLevel, camera)
                end
            end
        end
    end
end

function OptimizedRenderer.flushBatches()
    if OptimizedRenderer.state.batches.stars then
        local batch = OptimizedRenderer.state.batches.stars
        if batch:getCount() > 0 then
            -- Aplicar shader de estrellas y dibujar todo el batch en un solo draw call
            local sh = StarShader and StarShader.getShader and StarShader.getShader() or nil
            if sh then love.graphics.setShader(sh) end
            love.graphics.draw(batch)
            if sh then love.graphics.setShader() end
            batch:clear()
        end
    end
    
    OptimizedRenderer.state.stats.batchesUsed = OptimizedRenderer.state.stats.batchesUsed + 1
end

-- Obtener estadísticas
function OptimizedRenderer.getStats()
    return {
        performance = {
            frameTime = OptimizedRenderer.state.stats.frameTime * 1000,  -- En milisegundos
            drawCalls = OptimizedRenderer.state.stats.drawCalls,
            fps = math.floor(1 / math.max(0.001, OptimizedRenderer.state.stats.frameTime))
        },
        rendering = {
            objectsRendered = OptimizedRenderer.state.stats.objectsRendered,
            objectsCulled = OptimizedRenderer.state.stats.objectsCulled,
            cullingEfficiency = OptimizedRenderer.state.stats.cullingEfficiency * 100,
            batchesUsed = OptimizedRenderer.state.stats.batchesUsed
        },
        lod = OptimizedRenderer.state.stats.lodDistribution,
        quality = {
            current = OptimizedRenderer.state.adaptiveQuality.currentLevel,
            target = OptimizedRenderer.state.adaptiveQuality.targetFrameTime * 1000
        }
    }
end

-- Configuración de debug
function OptimizedRenderer.toggleDebug(feature)
    if feature == "lod" then
        OptimizedRenderer.config.debug.showLODLevels = not OptimizedRenderer.config.debug.showLODLevels
    elseif feature == "culling" then
        OptimizedRenderer.config.debug.showCullingBounds = not OptimizedRenderer.config.debug.showCullingBounds
    elseif feature == "batches" then
        OptimizedRenderer.config.debug.showBatches = not OptimizedRenderer.config.debug.showBatches
    end
end

return OptimizedRenderer