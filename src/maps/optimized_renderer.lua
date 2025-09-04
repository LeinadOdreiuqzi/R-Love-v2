-- src/maps/optimized_renderer.lua
-- Sistema de renderizado optimizado con LOD, culling y batching

local OptimizedRenderer = {}
local CoordinateSystem = require 'src.maps.coordinate_system'
local StarShader = require 'src.shaders.star_shader'
local ShaderManager = require 'src.shaders.shader_manager'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'

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
        transitionSmoothing = true,
        
        -- Configuración específica para zoom alto
        highZoomMode = {
            enabled = false,  -- Se activa dinámicamente
            levels = {
                [0] = {distance = 0,    detail = 0.7},  -- Reducido
                [1] = {distance = 400,  detail = 0.5},  -- Reducido
                [2] = {distance = 800,  detail = 0.3},  -- Reducido
                [3] = {distance = 1600, detail = 0.1}   -- Muy reducido
            }
        },
        
        -- NUEVO: LOD inteligente basado en propiedades de estrella
        intelligentLOD = {
            enabled = true,
            -- Factores de importancia visual
            sizeImportance = 2.0,      -- Estrellas grandes mantienen calidad
            typeImportance = {
                [1] = 1.0,  -- Estrella básica
                [2] = 1.2,  -- Estrella media
                [3] = 1.4,  -- Estrella grande
                [4] = 2.0   -- Estrella super brillante
            },
            brightnessImportance = 1.5, -- Factor de brillo
            -- Multiplicadores de distancia por importancia
            distanceMultipliers = {
                veryHigh = 2.5,  -- Estrellas muy importantes
                high = 2.0,      -- Estrellas importantes
                medium = 1.5,    -- Estrellas medianas
                low = 1.0        -- Estrellas normales
            }
        }
    },
    
    -- Frustum culling
    culling = {
        enabled = true,
        margin = 200,           -- Aumentado de 150 a 200 para mejor precarga
        hierarchical = true,    -- Culling jerárquico
        temporal = true         -- Culling temporal (basado en movimiento)
    },
    
    -- Batch rendering optimizado para zoom alto
    batching = {
        enabled = true,
        maxBatchSize = 8000,    -- Reducido para mejor rendimiento en zoom alto
        autoSort = true,        -- Ordenamiento automático por textura/tipo
        dynamicBatching = true, -- Batching dinámico basado en visibilidad
        
        -- OPTIMIZACIÓN: Umbral mínimo para flush automático (aumentado)
        minFlushThreshold = 100,
        -- OPTIMIZACIÓN: Contador de objetos en batch actual
        currentBatchCount = 0,
        
        -- Configuración de lotes por tipo (optimizado para zoom alto)
        batchConfigs = {
            stars = {maxSize = 8000, priority = 1},
            asteroids = {maxSize = 6000, priority = 2},
            nebulae = {maxSize = 4000, priority = 3},
            stations = {maxSize = 1500, priority = 4},
            effects = {maxSize = 2000, priority = 5}
        },
        
        -- Optimización para zoom alto
        zoomOptimization = {
            enabled = true,
            highZoomThreshold = 1.2,  -- Umbral para considerar zoom alto
            batchSizeMultiplier = 0.7 -- Reducir tamaño de batch en zoom alto
        }
    },
    
    -- Optimizaciones de performance
    performance = {
        maxDrawCalls = 500,     -- Máximo draw calls por frame
        targetFrameTime = 0.016, -- Target 60 FPS (16.6ms)
        adaptiveQuality = true,  -- Calidad adaptativa basada en performance
        earlyZReject = true,    -- Rechazo temprano de objetos no visibles
        
        -- Precarga de shaders y objetos
        preloadShaders = true,
        preloadObjects = true,
        incrementalPreload = true,
        maxPreloadTimePerFrame = 0.003 -- 3ms para precarga por frame
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
    
    -- Cache de visuales por bioma
    biomeVisuals = {},
    
    -- Estado de precarga
    preloadState = {
        shadersPrecached = false,
        objectsPrecached = false,
        lastPreloadFrame = 0,
        incrementalProgress = 0
    },
    
    -- Estadísticas de performance
    stats = {
        frameTime = 0,
        frameCount = 0,  -- NUEVO: Contador de frames para optimizaciones
        drawCalls = 0,
        objectsRendered = 0,
        objectsCulled = 0,
        batchesUsed = 0,
        lodDistribution = {[0] = 0, [1] = 0, [2] = 0, [3] = 0},
        cullingEfficiency = 0,
        lastFrameStats = {},
        
        -- Estadísticas de precarga
        preloadStats = {
            shadersLoaded = 0,
            totalShaders = 4,
            objectsPreloaded = 0,
            preloadTime = 0
        }
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
    print("=== OPTIMIZED RENDERER INITIALIZING ===")
    
    -- Inicializar ShaderManager primero
    ShaderManager.init()
    
    -- Inicializar shader de estrellas (retrocompatibilidad)
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
        -- Crear SpriteBatches para todos los tipos
        OptimizedRenderer.createSpriteBatches()

        -- Cachear visuales por bioma para tint y brillo (sin costos por frame)
        OptimizedRenderer.state.biomeVisuals = {}
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

    print("✓ OptimizedRenderer initialized")
    print("✓ Batching: " .. (OptimizedRenderer.config.batching.enabled and "ON" or "OFF"))
    print("✓ LOD Levels: " .. #OptimizedRenderer.config.lod.levels)
    print("✓ Frustum Culling: " .. (OptimizedRenderer.config.culling.enabled and "ON" or "OFF"))
    print("✓ Shader Preloading: " .. (OptimizedRenderer.config.performance.preloadShaders and "ON" or "OFF"))
end

-- Crear sprite batches para diferentes tipos de objetos
function OptimizedRenderer.createSpriteBatches()
    if not love.graphics then return end
    
    local batchConfigs = OptimizedRenderer.config.batching.batchConfigs
    
    -- Crear batch para estrellas
    local starImage = ShaderManager.getBaseImage("white")
    if starImage then
        OptimizedRenderer.state.batches.stars = love.graphics.newSpriteBatch(
            starImage, batchConfigs.stars.maxSize
        )
        print("✓ SpriteBatch for stars created")
    end
    
    -- Crear batch para asteroides
    local asteroidImage = ShaderManager.getBaseImage("circle")
    if asteroidImage then
        OptimizedRenderer.state.batches.asteroids = love.graphics.newSpriteBatch(
            asteroidImage, batchConfigs.asteroids.maxSize
        )
        print("✓ SpriteBatch for asteroids created")
    end
    
    -- Crear batch para nebulosas
    local nebulaImage = ShaderManager.getBaseImage("circle")
    if nebulaImage then
        OptimizedRenderer.state.batches.nebulae = love.graphics.newSpriteBatch(
            nebulaImage, batchConfigs.nebulae.maxSize
        )
        print("✓ SpriteBatch for nebulae created")
    end
    
    -- Crear batch para estaciones
    local stationImage = ShaderManager.getBaseImage("white")
    if stationImage then
        OptimizedRenderer.state.batches.stations = love.graphics.newSpriteBatch(
            stationImage, batchConfigs.stations.maxSize
        )
        print("✓ SpriteBatch for stations created")
    end
end

-- Activar optimizaciones para zoom alto
function OptimizedRenderer.enableHighZoomOptimizations()
    -- Activar modo de zoom alto
    OptimizedRenderer.config.lod.highZoomMode.enabled = true
    
    -- Reducir tamaños de batch
    local zoomConfig = OptimizedRenderer.config.batching.zoomOptimization
    if zoomConfig and zoomConfig.enabled then
        -- Guardar configuración original si no existe
        if not OptimizedRenderer.originalBatchSizes then
            OptimizedRenderer.originalBatchSizes = {}
            for type, config in pairs(OptimizedRenderer.config.batching.batchConfigs) do
                OptimizedRenderer.originalBatchSizes[type] = config.maxSize
            end
        end
        
        -- Aplicar multiplicador a todos los batches
        for type, config in pairs(OptimizedRenderer.config.batching.batchConfigs) do
            config.maxSize = math.floor(OptimizedRenderer.originalBatchSizes[type] * zoomConfig.batchSizeMultiplier)
        end
    end
    
    -- Forzar limpieza de caché de visibilidad
    OptimizedRenderer.invalidateVisibilityCache()
    
    -- Vaciar todos los batches para aplicar nuevos tamaños
    OptimizedRenderer.flushAllBatches()
    
    print(" HIGH ZOOM OPTIMIZATIONS ENABLED - Performance mode activated")
    print(string.format("Batch size multiplier: %.1f%% (reduction: %.1f%%)", 
        zoomConfig.batchSizeMultiplier * 100, (1 - zoomConfig.batchSizeMultiplier) * 100))
    print("  ✓ Visibility cache invalidated and batches flushed")
end

-- Desactivar optimizaciones para zoom alto
function OptimizedRenderer.disableHighZoomOptimizations()
    -- Desactivar modo de zoom alto
    OptimizedRenderer.config.lod.highZoomMode.enabled = false
    
    -- Restaurar tamaños de batch originales
    if OptimizedRenderer.originalBatchSizes then
        for type, size in pairs(OptimizedRenderer.originalBatchSizes) do
            if OptimizedRenderer.config.batching.batchConfigs[type] then
                OptimizedRenderer.config.batching.batchConfigs[type].maxSize = size
            end
        end
    end
    
    -- Forzar limpieza de caché de visibilidad
    OptimizedRenderer.invalidateVisibilityCache()
    
    -- Vaciar todos los batches para aplicar nuevos tamaños
    OptimizedRenderer.flushAllBatches()
    
    print("HIGH ZOOM OPTIMIZATIONS DISABLED - Normal performance mode restored")
    print("  ✓ Original batch sizes restored and caches cleared")
end

-- Calcular nivel de LOD basado en distancia y zoom
function OptimizedRenderer.calculateLOD(objectX, objectY, camera, obj)
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
    
    -- LOD específico para estrellas intermedias con optimización para zoom alto
    if obj and obj.isIntermediateStar then
        local zoom = camera.zoom or 1.0
        
        -- Culling agresivo por zoom (optimizado)
        if zoom > 1.5 then return 3 end  -- No renderizar en zoom muy alto
        if zoom > 1.0 then return 3 end  -- Calidad mínima en zoom alto
        if zoom > 0.7 then return 2 end  -- Calidad reducida
        if zoom > 0.4 then return 1 end  -- Calidad media
        return 0  -- Calidad completa solo en zoom muy bajo
    end
    
    -- NUEVO: Ajustar distancia por importancia de la estrella
    if obj and OptimizedRenderer.config.lod.intelligentLOD.enabled then
        local importance = OptimizedRenderer.calculateStarImportance(obj)
        local config = OptimizedRenderer.config.lod.intelligentLOD
        
        -- Determinar multiplicador de distancia
        local distanceMultiplier = 1.0
        if importance >= 3.0 then
            distanceMultiplier = config.distanceMultipliers.veryHigh
        elseif importance >= 2.5 then
            distanceMultiplier = config.distanceMultipliers.high
        elseif importance >= 2.0 then
            distanceMultiplier = config.distanceMultipliers.medium
        else
            distanceMultiplier = config.distanceMultipliers.low
        end
        
        -- Aplicar multiplicador (estrellas importantes "parecen" más cerca)
        adjustedDistance = adjustedDistance / distanceMultiplier
    end
    
    -- Determinar nivel de LOD (con soporte para modo zoom alto)
    local lodLevels = OptimizedRenderer.config.lod.levels
    
    -- Usar configuración específica para zoom alto si está activada
    if OptimizedRenderer.config.lod.highZoomMode and OptimizedRenderer.config.lod.highZoomMode.enabled then
        lodLevels = OptimizedRenderer.config.lod.highZoomMode.levels
    end
    
    for level = #lodLevels - 1, 0, -1 do
        if adjustedDistance >= lodLevels[level].distance then
            return level
        end
    end
    
    return 0
end

-- Invalidar caché de visibilidad
function OptimizedRenderer.invalidateVisibilityCache()
    -- Limpiar caché de visibilidad
    OptimizedRenderer.state = OptimizedRenderer.state or {}
    OptimizedRenderer.state.visibilityCache = {}
    OptimizedRenderer.state.lastCameraPosition = nil
    OptimizedRenderer.state.lastCameraZoom = nil
    
    -- Actualizar estadísticas
    if OptimizedRenderer.state.stats then
        OptimizedRenderer.state.stats.cacheInvalidations = (OptimizedRenderer.state.stats.cacheInvalidations or 0) + 1
    end
end

-- Verificar si un objeto está visible (frustum culling optimizado para zoom alto)
function OptimizedRenderer.isObjectVisible(objectX, objectY, objectSize, camera)
    if not camera or not OptimizedRenderer.config.culling.enabled then
        return true
    end
    
    -- Optimización para zoom alto: culling más agresivo
    local zoom = camera.zoom or 1.0
    if zoom > 1.5 and objectSize < 20 then
        -- En zoom muy alto, objetos pequeños se descartan rápidamente
        return false
    end
    
    -- Convertir a coordenadas relativas
    local relX, relY = CoordinateSystem.worldToRelative(objectX, objectY)
    local camRelX, camRelY = CoordinateSystem.worldToRelative(camera.x, camera.y)
    
    -- Calcular posición en pantalla
    local screenX = (relX - camRelX) * camera.zoom + love.graphics.getWidth() / 2
    local screenY = (relY - camRelY) * camera.zoom + love.graphics.getHeight() / 2
    
    -- Calcular tamaño en pantalla
    local screenSize = objectSize * camera.zoom
    
    -- NUEVO: Calcular margen dinámico basado en importancia
    local margin = OptimizedRenderer.config.culling.margin
    if star and OptimizedRenderer.config.intelligentCulling.enabled then
        local importance = OptimizedRenderer.calculateStarImportance(star)
        local config = OptimizedRenderer.config.intelligentCulling
        
        -- Determinar multiplicador de margen
        local marginMultiplier = 1.0
        if importance >= 3.0 then
            marginMultiplier = config.dynamicMargin.multipliers.critical
        elseif importance >= 2.5 then
            marginMultiplier = config.dynamicMargin.multipliers.high
        elseif importance >= 2.0 then
            marginMultiplier = config.dynamicMargin.multipliers.medium
        else
            marginMultiplier = config.dynamicMargin.multipliers.low
        end
        
        margin = config.dynamicMargin.base * marginMultiplier
    end
    
    -- Verificar bounds con margen dinámico
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
    
    -- Calcular esquinas del chunk en coordenadas relativas (escaladas por worldScale)
    local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1
    local relLeft, relTop = CoordinateSystem.worldToRelative(bounds.left * ws, bounds.top * ws)
    local relRight, relBottom = CoordinateSystem.worldToRelative(bounds.right * ws, bounds.bottom * ws)
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
-- MEJORADO: Renderizar objetos con LOD y culling inteligente
function OptimizedRenderer.renderObjects(objects, objectType, camera, chunkX, chunkY, playerVelocity)
    if not objects or not camera then return 0 end
    
    local renderedCount = 0
    local culledCount = 0
    playerVelocity = playerVelocity or {x = 0, y = 0}
    
    for _, obj in ipairs(objects) do
        -- Calcular posición mundial del objeto (unidades de mundo escaladas)
        local sizePixels = (MapConfig and MapConfig.chunk and MapConfig.chunk.size or 48) * (MapConfig and MapConfig.chunk and MapConfig.chunk.tileSize or 32)
        local spacing = (MapConfig and MapConfig.chunk and MapConfig.chunk.spacing) or 0
        local stride = sizePixels + spacing
        local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1
        local baseX = chunkX * stride * ws
        local baseY = chunkY * stride * ws
        local worldX = baseX + (obj.x or 0) * ws
        local worldY = baseY + (obj.y or 0) * ws
        
        -- NUEVO: Calcular prioridad direccional
        local directionalPriority = 1.0
        if objectType == "stars" then
            directionalPriority = OptimizedRenderer.calculateDirectionalPriority(worldX, worldY, camera, playerVelocity)
        end
        
        -- Frustum culling inteligente (usar tamaño escalado)
        local objSize = ((obj.size or 10)) * ws
        if OptimizedRenderer.isObjectVisible(worldX, worldY, objSize, camera, obj) then
            -- Calcular LOD inteligente
            local lodLevel = OptimizedRenderer.calculateLOD(worldX, worldY, camera, obj)
            obj.lodLevel = lodLevel  -- Guardar para estadísticas
            obj.directionalPriority = directionalPriority -- Guardar prioridad
            
            -- MEJORADO: No saltear estrellas importantes en LOD 3
            local shouldRender = true
            if lodLevel >= 3 and objectType == "stars" then
                local importance = OptimizedRenderer.calculateStarImportance(obj)
                -- Solo saltear si la importancia es muy baja
                if importance < 2.0 then
                    shouldRender = false
                end
            end
            
            if shouldRender then
                -- Renderizar según el tipo y LOD
                OptimizedRenderer.renderSingleObject(obj, objectType, worldX, worldY, lodLevel, camera)
                renderedCount = renderedCount + 1
            else
                culledCount = culledCount + 1
            end
            
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

-- Renderizar objeto individual con LOD (optimizado para zoom alto)
function OptimizedRenderer.renderSingleObject(obj, objectType, worldX, worldY, lodLevel, camera)
    local lodConfig = OptimizedRenderer.config.lod.levels[lodLevel]
    local detailLevel = lodConfig.detail
    
    -- Optimización para zoom alto
    local zoom = camera.zoom or 1.0
    if zoom > 1.5 then
        -- En zoom muy alto, reducir aún más el detalle
        detailLevel = detailLevel * 0.7
        
        -- Para objetos pequeños o de baja prioridad, aumentar LOD
        if (obj.size or 10) < 30 and lodLevel < 3 then
            lodLevel = lodLevel + 1
        end
    end
    
    -- Convertir a coordenadas relativas para renderizado
    local relX, relY = CoordinateSystem.worldToRelative(worldX, worldY)
    local camRelX, camRelY = CoordinateSystem.worldToRelative(camera.x, camera.y)
    
    -- Calcular posición de renderizado
    local renderX = (relX - camRelX) * camera.zoom + love.graphics.getWidth() / 2
    local renderY = (relY - camRelY) * camera.zoom + love.graphics.getHeight() / 2
    
    -- Ajustar tamaño según LOD (escalar por worldScale)
    local ws = (MapConfig and MapConfig.chunk and MapConfig.chunk.worldScale) or 1
    local renderSize = (obj.size or 10) * ws * camera.zoom * detailLevel
    
    -- Renderizar según tipo usando batching mejorado
    if objectType == "stars" then
        OptimizedRenderer.renderStarBatched(obj, renderX, renderY, renderSize, lodLevel)
    elseif objectType == "nebulae" then
        OptimizedRenderer.renderNebulaBatched(obj, renderX, renderY, renderSize, lodLevel)
    elseif objectType == "asteroids" then
        OptimizedRenderer.renderAsteroidBatched(obj, renderX, renderY, renderSize, lodLevel)
    elseif objectType == "stations" then
        OptimizedRenderer.renderStationBatched(obj, renderX, renderY, renderSize, lodLevel)
    end
    
    OptimizedRenderer.state.stats.drawCalls = OptimizedRenderer.state.stats.drawCalls + 1
end

-- Renderizar estrella con batching mejorado y optimizado para zoom alto
function OptimizedRenderer.renderStarBatched(star, x, y, size, lodLevel)
    -- Optimización para zoom alto
    local camera = OptimizedRenderer.state.camera
    local zoom = camera and camera.zoom or 1.0
    
    -- NUEVA OPTIMIZACIÓN: Culling agresivo para zoom alto
    if not OptimizedRenderer.isStarVisibleHighZoom(star, x, y, size, camera) then
        return -- Saltear estrellas no visibles
    end
    
    -- NUEVA OPTIMIZACIÓN: Cache de twinkle para zoom alto (reduce parpadeo)
    if zoom > 1.2 then
        -- Reducir frecuencia de actualización del twinkle en zoom alto
        local frameCount = OptimizedRenderer.state.stats.frameCount or 0
        if not star._twinkleCache or frameCount % 4 == 0 then
            local time = love.timer.getTime()
            local twinklePhase = time * (star.twinkleSpeed or 1) + (star.twinkle or 0)
            local angleIndex = math.floor(twinklePhase * 57.29) % 360
            star._twinkleCache = 0.6 + 0.4 * (MapRenderer.sinTable and MapRenderer.sinTable[angleIndex] or math.sin(math.rad(angleIndex)))
            star._lastTwinkleUpdate = frameCount
        end
    end
    
    -- Ajuste de LOD más agresivo en zoom alto
    if zoom > 1.5 and lodLevel < 3 then
        lodLevel = lodLevel + 1
    end
    
    -- Filtrado mejorado para zoom alto con preservación visual
    if lodLevel >= 3 then
        local importance = OptimizedRenderer.calculateStarImportance(star)
        -- En zoom alto, ser más selectivo pero mantener estrellas brillantes
        local importanceThreshold = zoom > 1.8 and 3.0 or (zoom > 1.5 and 2.5 or 2.0)
        if importance < importanceThreshold then
            return -- Saltear estrellas menos importantes en zoom alto
        end
        -- Estrellas importantes mantienen tamaño mínimo visible
        size = math.max(size * 0.5, 1.5) -- Tamaño mínimo de 1.5 píxeles para visibilidad
    end
    
    -- OPTIMIZACIÓN: Incrementar contador de batch
    OptimizedRenderer.config.batching.currentBatchCount = OptimizedRenderer.config.batching.currentBatchCount + 1
    
    -- Aplicar optimización de tamaño de batch para zoom alto
    if OptimizedRenderer.config.batching.zoomOptimization.enabled and 
       zoom > OptimizedRenderer.config.batching.zoomOptimization.highZoomThreshold then
        -- Forzar flush más frecuente en zoom alto para mantener batches pequeños
        local currentCount = OptimizedRenderer.config.batching.currentBatchCount
        local maxBatchSize = OptimizedRenderer.config.batching.maxBatchSize * 
                            OptimizedRenderer.config.batching.zoomOptimization.batchSizeMultiplier
        
        if currentCount > maxBatchSize then
            OptimizedRenderer.flushAllBatches()
        end
    end
    
    local batch = OptimizedRenderer.state.batches.stars
    if not batch then
        -- Fallback a renderizado individual
        OptimizedRenderer.renderStar(star, x, y, size, lodLevel)
        return
    end
    
    -- Usar lógica existente de StarShader con batching
    OptimizedRenderer.renderStarHighDetail(star, x, y, size)
end

-- Renderizar asteroide con batching (optimizado para zoom alto)
function OptimizedRenderer.renderAsteroidBatched(asteroid, x, y, size, lodLevel)
    -- Optimización para zoom alto
    local camera = OptimizedRenderer.state.camera
    local zoom = camera and camera.zoom or 1.0
    
    -- En zoom alto, filtrar más agresivamente
    if zoom > 1.5 then
        -- En zoom muy alto, solo renderizar asteroides grandes o importantes
        local asteroidSize = asteroid.size or 10
        if asteroidSize < 25 then
            return -- No renderizar asteroides pequeños en zoom alto
        end
        
        -- Aumentar LOD para reducir detalle
        if lodLevel < 3 then
            lodLevel = lodLevel + 1
        end
    end
    
    -- Saltear LOD muy bajo
    if lodLevel >= 3 then 
        -- En LOD 3, solo renderizar asteroides muy grandes
        local asteroidSize = asteroid.size or 10
        if asteroidSize < 50 then
            return
        end
        -- Reducir tamaño para asteroides grandes en LOD bajo
        size = size * 0.5
    end
    
    local batch = OptimizedRenderer.state.batches.asteroids
    if not batch then
        OptimizedRenderer.renderAsteroid(asteroid, x, y, size, lodLevel)
        return
    end
    
    -- OPTIMIZACIÓN: Flush preventivo más inteligente
    local maxCount = OptimizedRenderer.config.batching.batchConfigs.asteroids.maxSize
    local threshold = maxCount - 100
    if batch:getCount() >= threshold then
        OptimizedRenderer.flushAsteroidBatch()
    end
    
    -- OPTIMIZACIÓN: Incrementar contador de batch
    OptimizedRenderer.config.batching.currentBatchCount = OptimizedRenderer.config.batching.currentBatchCount + 1
    
    -- Aplicar optimización de tamaño de batch para zoom alto
    if OptimizedRenderer.config.batching.zoomOptimization.enabled and 
       zoom > OptimizedRenderer.config.batching.zoomOptimization.highZoomThreshold then
        -- Forzar flush más frecuente en zoom alto para mantener batches pequeños
        local currentCount = OptimizedRenderer.config.batching.currentBatchCount
        local maxBatchSize = OptimizedRenderer.config.batching.maxBatchSize * 
                            OptimizedRenderer.config.batching.zoomOptimization.batchSizeMultiplier
        
        if currentCount > maxBatchSize then
            OptimizedRenderer.flushAllBatches()
        end
    end
    
    -- Configurar color del asteroide
    local color = {0.4, 0.3, 0.2, 1}
    local brightness = 1.0 - (lodLevel * 0.2) -- Reducir brillo con LOD
    
    batch:setColor(color[1] * brightness, color[2] * brightness, color[3] * brightness, color[4])
    batch:add(x, y, 0, size * 2, size * 2, 0.5, 0.5)
end

-- Función para vaciar todos los batches (optimización para zoom alto)
function OptimizedRenderer.flushAllBatches()
    -- Vaciar todos los batches para evitar sobrecarga de memoria
    if OptimizedRenderer.state.batches.stars then
        love.graphics.draw(OptimizedRenderer.state.batches.stars)
        OptimizedRenderer.state.batches.stars:clear()
    end
    
    if OptimizedRenderer.state.batches.asteroids then
        love.graphics.draw(OptimizedRenderer.state.batches.asteroids)
        OptimizedRenderer.state.batches.asteroids:clear()
    end
    
    if OptimizedRenderer.state.batches.nebulae then
        love.graphics.draw(OptimizedRenderer.state.batches.nebulae)
        OptimizedRenderer.state.batches.nebulae:clear()
    end
    
    if OptimizedRenderer.state.batches.stations then
        love.graphics.draw(OptimizedRenderer.state.batches.stations)
        OptimizedRenderer.state.batches.stations:clear()
    end
    
    -- Reiniciar contador de batch
    OptimizedRenderer.config.batching.currentBatchCount = 0
    
    -- Actualizar estadísticas
    OptimizedRenderer.state.stats.batchFlushes = (OptimizedRenderer.state.stats.batchFlushes or 0) + 1
end

-- Renderizar nebulosa con batching (optimizado para zoom alto)
function OptimizedRenderer.renderNebulaBatched(nebula, x, y, size, lodLevel)
    -- Optimización para zoom alto
    local camera = OptimizedRenderer.state.camera
    local zoom = camera and camera.zoom or 1.0
    
    -- En zoom alto, ser más selectivo con nebulosas
    if zoom > 1.5 and lodLevel >= 2 then
        return -- No renderizar nebulosas en zoom alto con LOD bajo
    end
    
    if lodLevel >= 3 then
        -- Para nebulosas grandes, renderizar con calidad reducida en lugar de eliminar
        local nebulaSize = nebula.size or 140
        if nebulaSize < 300 then
            return -- Solo eliminar nebulosas pequeñas en LOD 3
        end
        -- Nebulosas grandes se renderizan con menor detalle pero siguen visibles
        size = size * 0.6
    end
    
    local batch = OptimizedRenderer.state.batches.nebulae
    if not batch then
        OptimizedRenderer.renderNebula(nebula, x, y, size, lodLevel)
        -- No-op: Rendering inmediato para nebulosas (uniforms por-nebulosa). El batch no se usa.
        return
    end
    
    -- Dibujar nebulosa inmediatamente con shader y uniforms por-nebulosa (no usar SpriteBatch)
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle")
    local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("nebula")
    if not img or not shader then
        return
    end

    -- Color base
    local color = nebula.color or {1, 1, 1, 0.7}
    local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 0.7

    -- UNIFICADO: Usar función centralizada de brillo
    local brightness = OptimizedRenderer.calculateNebulaBrightness(nebula, love.timer.getTime())
    local par = math.max(0.0, math.min(1.0, nebula.parallax or 0.85))

    -- Enviar uniforms por nebulosa (incluye u_parallax y sparkle)
    shader:send("u_seed", (nebula.seed or 0) * 0.001)
    shader:send("u_noiseScale", nebula.noiseScale or 2.5)
    shader:send("u_warpAmp", nebula.warpAmp or 0.65)
    shader:send("u_warpFreq", nebula.warpFreq or 1.25)
    shader:send("u_softness", nebula.softness or 0.28)
    shader:send("u_brightness", brightness)
    shader:send("u_intensity", (nebula.intensity or 0.6) * 1.3) -- Aumentar intensidad
    shader:send("u_parallax", par)
    shader:send("u_sparkleStrength", 1.3)
    shader:send("u_time", love.timer.getTime())

    -- Dibujar
    love.graphics.setShader(shader)
    love.graphics.setColor(r, g, b, a)
    local iw = img:getWidth()
    local ih = img:getHeight()
    local s = size / math.max(1, iw)
    love.graphics.draw(img, x, y, 0, s, s, iw * 0.5, ih * 0.5)
    love.graphics.setShader()
    -- Nota: no agregamos nada al SpriteBatch de nebulosas a propósito.
    batch:clear()
    
end
-- Culling jerárquico por capas
function OptimizedRenderer.hierarchicalLayerCulling(camera, zoom, layer_config)
    local frustum = {
        left = camera.x - (love.graphics.getWidth() / (2 * zoom)),
        right = camera.x + (love.graphics.getWidth() / (2 * zoom)),
        top = camera.y - (love.graphics.getHeight() / (2 * zoom)),
        bottom = camera.y + (love.graphics.getHeight() / (2 * zoom))
    }
    
    -- Expandir frustum basado en factor de parallax
    local parallax_expansion = 1.0 + (1.0 - layer_config.parallax_factor)
    frustum.left = frustum.left - (frustum.right - frustum.left) * parallax_expansion * 0.1
    frustum.right = frustum.right + (frustum.right - frustum.left) * parallax_expansion * 0.1
    frustum.top = frustum.top - (frustum.bottom - frustum.top) * parallax_expansion * 0.1
    frustum.bottom = frustum.bottom + (frustum.bottom - frustum.top) * parallax_expansion * 0.1
    
    return frustum
end
-- Renderizar estación con batching
function OptimizedRenderer.renderStationBatched(station, x, y, size, lodLevel)
    if lodLevel >= 2 then return end
    
    local batch = OptimizedRenderer.state.batches.stations
    if not batch then
        OptimizedRenderer.renderStation(station, x, y, size, lodLevel)
        return
    end
    
    local color = {0.6, 0.6, 0.8, 1}
    
    -- Flush preventivo
    local maxCount = OptimizedRenderer.config.batching.batchConfigs.stations.maxSize
    if batch:getCount() >= (maxCount - 50) then
        OptimizedRenderer.flushStationBatch()
    end
    
    batch:setColor(color[1], color[2], color[3], color[4])
    batch:add(x, y, station.rotation or 0, size, size, 0.5, 0.5)
end

-- Actualización con precarga incremental
function OptimizedRenderer.update(dt, playerX, playerY, camera)
    -- Incrementar contador de frames para optimizaciones
    OptimizedRenderer.incrementFrameCount()
    
    -- Actualizar ShaderManager
    if ShaderManager and ShaderManager.update then
        ShaderManager.update(dt)
    end
    
    -- Precarga incremental de shaders y objetos
    if OptimizedRenderer.config.performance.incrementalPreload then
        OptimizedRenderer.performIncrementalPreload(dt, playerX, playerY, camera)
    end
    
    -- Actualizar calidad adaptativa
    if OptimizedRenderer.updateAdaptiveQuality then
        OptimizedRenderer.updateAdaptiveQuality(OptimizedRenderer.state.stats.frameTime)
    end
end

-- Realizar precarga incremental
function OptimizedRenderer.performIncrementalPreload(dt, playerX, playerY, camera)
    local startTime = love.timer.getTime()
    local maxTime = OptimizedRenderer.config.performance.maxPreloadTimePerFrame
    
    -- Precarga de shaders
    if not OptimizedRenderer.state.preloadState.shadersPrecached then
        ShaderManager.preloadAll()
        local stats = ShaderManager.getStats()
        OptimizedRenderer.state.stats.preloadStats.shadersLoaded = stats.loaded
        if stats.loaded >= stats.total then
            OptimizedRenderer.state.preloadState.shadersPrecached = true
            print("✓ All shaders precached (" .. stats.loaded .. "/" .. stats.total .. ")")
        end
    end
    
    -- Precarga de objetos cercanos (chunks fuera de pantalla)
    if OptimizedRenderer.state.preloadState.shadersPrecached and 
       OptimizedRenderer.config.performance.preloadObjects and
       love.timer.getTime() - startTime < maxTime then
        
        OptimizedRenderer.preloadNearbyObjects(playerX, playerY, camera, maxTime - (love.timer.getTime() - startTime))
    end
    
    OptimizedRenderer.state.stats.preloadStats.preloadTime = love.timer.getTime() - startTime
end

-- Precarga de objetos cercanos
function OptimizedRenderer.preloadNearbyObjects(playerX, playerY, camera, remainingTime)
    if not camera then return end
    
    local ChunkManager = require 'src.maps.chunk_manager'
    if not ChunkManager or not ChunkManager.getVisibleChunks then return end
    
    local startTime = love.timer.getTime()
    
    -- Calcular chunks en un área ampliada para precarga
    local extendedCamera = {
        x = camera.x,
        y = camera.y,
        zoom = camera.zoom * 0.7, -- Zoom out para área más amplia
        screenToWorld = camera.screenToWorld,
        worldToScreen = camera.worldToScreen
    }
    
    local nearbyChunks = ChunkManager.getVisibleChunks(extendedCamera)
    local preloadedCount = 0
    
    for _, chunk in ipairs(nearbyChunks) do
        if love.timer.getTime() - startTime >= remainingTime then break end
        
        -- Precalentar objetos del chunk sin renderizar
        if chunk.objects then
            if chunk.objects.stars then
                for _, star in ipairs(chunk.objects.stars) do
                    -- Aplicar efectos de estrella en background
                    if ShaderManager.getShader("star") and preloadedCount < 50 then
                        preloadedCount = preloadedCount + 1
                    end
                end
            end
        end
    end
    
    OptimizedRenderer.state.stats.preloadStats.objectsPreloaded = preloadedCount
end

-- Finalizar batches con shaders
function OptimizedRenderer.flushBatches()
    OptimizedRenderer.flushStarBatch()
    OptimizedRenderer.flushAsteroidBatch()
    OptimizedRenderer.flushNebulaBatch()
    OptimizedRenderer.flushStationBatch()
    
    OptimizedRenderer.state.stats.batchesUsed = 4
end

-- Flush individual de cada tipo de batch
function OptimizedRenderer.flushStarBatch()
    local batch = OptimizedRenderer.state.batches.stars
    if batch and batch:getCount() > 0 then
        local shader = ShaderManager.getShader("star")
        if shader then love.graphics.setShader(shader) end
        love.graphics.draw(batch)
        if shader then love.graphics.setShader() end
        batch:clear()
    end
end

function OptimizedRenderer.flushAsteroidBatch()
    local batch = OptimizedRenderer.state.batches.asteroids
    if batch and batch:getCount() > 0 then
        local shader = ShaderManager.getShader("asteroid")
        if shader then love.graphics.setShader(shader) end
        love.graphics.draw(batch)
        if shader then love.graphics.setShader() end
        batch:clear()
    end
end

function OptimizedRenderer.flushNebulaBatch()
    local batch = OptimizedRenderer.state.batches.nebulae
    if batch and batch:getCount() > 0 then
        local shader = ShaderManager.getShader("nebula")
        if shader then love.graphics.setShader(shader) end
        love.graphics.draw(batch)
        if shader then love.graphics.setShader() end
        batch:clear()
    end
end

function OptimizedRenderer.flushStationBatch()
    local batch = OptimizedRenderer.state.batches.stations
    if batch and batch:getCount() > 0 then
        local shader = ShaderManager.getShader("station")
        if shader then love.graphics.setShader(shader) end
        love.graphics.draw(batch)
        if shader then love.graphics.setShader() end
        batch:clear()
    end
end

-- Reiniciar estadísticas del renderizador
function OptimizedRenderer.resetStats()
    if not OptimizedRenderer.state then return end

    -- Intentar preservar el total de shaders si ya fue establecido
    local totalShaders = 4
    if OptimizedRenderer.state.stats
        and OptimizedRenderer.state.stats.preloadStats
        and OptimizedRenderer.state.stats.preloadStats.totalShaders then
        totalShaders = OptimizedRenderer.state.stats.preloadStats.totalShaders
    end

    OptimizedRenderer.state.stats = {
        frameTime = 0,
        frameCount = (OptimizedRenderer.state.stats and OptimizedRenderer.state.stats.frameCount or 0), -- Preservar contador
        drawCalls = 0,
        objectsRendered = 0,
        objectsCulled = 0,
        batchesUsed = 0,
        lodDistribution = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 },
        cullingEfficiency = 0,
        lastFrameStats = {},
        preloadStats = {
            shadersLoaded = 0,
            totalShaders = totalShaders,
            objectsPreloaded = 0,
            preloadTime = 0
        }
    }
end

-- Culling agresivo para estrellas en zoom máximo
function OptimizedRenderer.isStarVisibleHighZoom(star, x, y, size, camera)
    if not camera or camera.zoom <= 1.5 then
        return true -- Usar culling normal para zoom bajo/medio
    end
    
    -- Culling más agresivo para zoom alto
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local margin = size * 2 -- Margen reducido para zoom alto
    
    -- Convertir a coordenadas de pantalla
    local screenX = (x - camera.x) * camera.zoom + screenWidth / 2
    local screenY = (y - camera.y) * camera.zoom + screenHeight / 2
    
    -- Verificar si está dentro del viewport con margen reducido
    local visible = screenX >= -margin and screenX <= screenWidth + margin and
                   screenY >= -margin and screenY <= screenHeight + margin
    
    -- Culling adicional por importancia en zoom muy alto
    if visible and camera.zoom > 2.0 then
        local importance = OptimizedRenderer.calculateStarImportance(star)
        local distanceFromCenter = math.sqrt((screenX - screenWidth/2)^2 + (screenY - screenHeight/2)^2)
        local maxDistance = math.min(screenWidth, screenHeight) * 0.6 -- Solo centro de pantalla
        
        -- Filtrar estrellas menos importantes en los bordes
        if distanceFromCenter > maxDistance and importance < 2.5 then
            visible = false
        end
    end
    
    return visible
end

-- Incrementar contador de frames (llamar desde el bucle principal)
function OptimizedRenderer.incrementFrameCount()
    if OptimizedRenderer.state and OptimizedRenderer.state.stats then
        OptimizedRenderer.state.stats.frameCount = OptimizedRenderer.state.stats.frameCount + 1
    end
end

-- Módulo: OptimizedRenderer

function OptimizedRenderer.getStats()
    -- FPS actual vía LÖVE
    local fps = (love and love.timer and love.timer.getFPS) and love.timer.getFPS() or 0

    -- Intentar usar frameTime del estado si existe (segundos -> ms), si no, estimar desde FPS
    local frameTimeMs
    if OptimizedRenderer.state and OptimizedRenderer.state.stats and OptimizedRenderer.state.stats.frameTime then
        frameTimeMs = (OptimizedRenderer.state.stats.frameTime or 0) * 1000
    else
        frameTimeMs = (fps > 0) and (1000 / fps) or 0
    end

    local stats = OptimizedRenderer.state and OptimizedRenderer.state.stats or {}
    local quality = OptimizedRenderer.state and OptimizedRenderer.state.adaptiveQuality or {}

    return {
        performance = {
            fps = fps or 0,
            frameTime = frameTimeMs or 0,
            drawCalls = stats.drawCalls or 0,
        },
        rendering = {
            objectsRendered = stats.objectsRendered or 0,
            cullingEfficiency = stats.cullingEfficiency or 0,
        },
        quality = {
            current = quality.currentLevel or 1.0,
        }
    }
end
-- NUEVO: Calcular importancia visual de una estrella
function OptimizedRenderer.calculateStarImportance(star)
    if not star then return 1.0 end
    
    local config = OptimizedRenderer.config.lod.intelligentLOD
    if not config.enabled then return 1.0 end
    
    local importance = 1.0
    
    -- Factor de tamaño
    local size = star.size or 10
    local sizeNormalized = math.min(size / 20, 2.0) -- Normalizar a 0-2
    importance = importance + (sizeNormalized * config.sizeImportance)
    
    -- Factor de tipo
    local starType = star.type or 1
    local typeMultiplier = config.typeImportance[starType] or 1.0
    importance = importance * typeMultiplier
    
    -- Factor de brillo
    local brightness = star.brightness or 1.0
    importance = importance + (brightness * config.brightnessImportance)
    
    return math.max(importance, 0.1) -- Mínimo 0.1
end

-- MEJORADO: Calcular nivel de LOD basado en distancia, zoom y propiedades de estrella
function OptimizedRenderer.calculateLOD(objectX, objectY, camera, star)
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
    
    -- NUEVO: Ajustar distancia por importancia de la estrella
    if star and OptimizedRenderer.config.lod.intelligentLOD.enabled then
        local importance = OptimizedRenderer.calculateStarImportance(star)
        local config = OptimizedRenderer.config.lod.intelligentLOD
        
        -- Determinar multiplicador de distancia
        local distanceMultiplier = 1.0
        if importance >= 3.0 then
            distanceMultiplier = config.distanceMultipliers.veryHigh
        elseif importance >= 2.5 then
            distanceMultiplier = config.distanceMultipliers.high
        elseif importance >= 2.0 then
            distanceMultiplier = config.distanceMultipliers.medium
        else
            distanceMultiplier = config.distanceMultipliers.low
        end
        
        -- Aplicar multiplicador (estrellas importantes "parecen" más cerca)
        adjustedDistance = adjustedDistance / distanceMultiplier
    end
    
    -- Determinar nivel de LOD
    for level = #OptimizedRenderer.config.lod.levels - 1, 0, -1 do
        if adjustedDistance >= OptimizedRenderer.config.lod.levels[level].distance then
            return level
        end
    end
    
    return 0
end

-- MEJORADO: Verificar si un objeto está visible con culling inteligente
function OptimizedRenderer.isObjectVisible(objectX, objectY, objectSize, camera, star)
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
    
    -- NUEVO: Calcular margen dinámico basado en importancia
    local margin = OptimizedRenderer.config.culling.margin
    if star and OptimizedRenderer.config.intelligentCulling.enabled then
        local importance = OptimizedRenderer.calculateStarImportance(star)
        local config = OptimizedRenderer.config.intelligentCulling
        
        -- Determinar multiplicador de margen
        local marginMultiplier = 1.0
        if importance >= 3.0 then
            marginMultiplier = config.dynamicMargin.multipliers.critical
        elseif importance >= 2.5 then
            marginMultiplier = config.dynamicMargin.multipliers.high
        elseif importance >= 2.0 then
            marginMultiplier = config.dynamicMargin.multipliers.medium
        else
            marginMultiplier = config.dynamicMargin.multipliers.low
        end
        
        margin = config.dynamicMargin.base * marginMultiplier
    end
    
    -- Verificar bounds con margen dinámico
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    return screenX + screenSize >= -margin and
           screenX - screenSize <= screenWidth + margin and
           screenY + screenSize >= -margin and
           screenY - screenSize <= screenHeight + margin
end

-- NUEVO: Calcular prioridad de precarga direccional
function OptimizedRenderer.calculateDirectionalPriority(objectX, objectY, camera, playerVelocity)
    if not OptimizedRenderer.config.directionalPreload.enabled then
        return 1.0
    end
    
    local config = OptimizedRenderer.config.directionalPreload
    
    -- Verificar si hay suficiente velocidad
    local velocityMagnitude = math.sqrt(playerVelocity.x^2 + playerVelocity.y^2)
    if velocityMagnitude < config.velocityThreshold then
        return 1.0
    end
    
    -- Calcular vector hacia el objeto
    local dx = objectX - camera.x
    local dy = objectY - camera.y
    local distance = math.sqrt(dx^2 + dy^2)
    
    if distance == 0 then return 1.0 end
    
    -- Normalizar vectores
    local objDirX = dx / distance
    local objDirY = dy / distance
    local velDirX = playerVelocity.x / velocityMagnitude
    local velDirY = playerVelocity.y / velocityMagnitude
    
    -- Calcular ángulo entre dirección de movimiento y objeto
    local dotProduct = objDirX * velDirX + objDirY * velDirY
    local angle = math.acos(math.max(-1, math.min(1, dotProduct)))
    local angleDegrees = math.deg(angle)
    
    -- Verificar si está dentro del cono de precarga
    if angleDegrees <= config.angleSpread then
        -- Calcular boost de prioridad basado en alineación
        local alignment = 1.0 - (angleDegrees / config.angleSpread)
        local priorityBoost = 1.0 + (config.priorityBoost * alignment)
        
        -- Ajustar por distancia si está habilitado
        if config.adaptiveDistance then
            local distanceFactor = math.min(distance / config.lookAheadDistance, 1.0)
            priorityBoost = priorityBoost * (1.0 + distanceFactor)
        end
        
        return priorityBoost
    end
    
    return 1.0
end

-- NUEVO: Sistema unificado de brillo de nebulosas
function OptimizedRenderer.calculateNebulaBrightness(nebula, timeNow)
    if not nebula then return 1.0 end
    
    -- Parallax normalizado
    local par = math.max(0.0, math.min(1.0, nebula.parallax or 0.85))
    
    -- Brillo base según propiedades de la nebulosa
    local baseBrightness
    if nebula.brightness then
        baseBrightness = nebula.brightness
    else
        -- Brillo por bioma y parallax
        if nebula.biomeType == BiomeSystem.BiomeType.NEBULA_FIELD then
            baseBrightness = 1.60  -- Nebulosas en campos de nebulosa más brillantes
        elseif par > 0.85 then
            baseBrightness = 1.45  -- Nebulosas de fondo brillantes
        elseif par > 0.7 then
            baseBrightness = 1.30  -- Nebulosas medias
        else
            baseBrightness = 1.15  -- Nebulosas de primer plano
        end
    end
    
    -- Pulso senoidal suave basado en tiempo y seed
    local freq = 0.15 + 0.25 * par  -- Frecuencia dependiente de parallax
    local phase = (nebula.seed or 0) * 0.15
    local pulse = 1.0 + 0.04 * math.sin((timeNow or love.timer.getTime()) * freq + phase)
    
    -- Multiplicador global de brillo unificado
    local globalBrightnessMultiplier = 1.4
    
    return baseBrightness * pulse * globalBrightnessMultiplier
end
return OptimizedRenderer