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
        transitionSmoothing = true
    },
    
    -- Frustum culling
    culling = {
        enabled = true,
        margin = 200,           -- Aumentado de 150 a 200 para mejor precarga
        hierarchical = true,    -- Culling jerárquico
        temporal = true         -- Culling temporal (basado en movimiento)
    },
    
    -- Batch rendering
    batching = {
        enabled = true,
        maxBatchSize = 10000,   -- Máximo objetos por batch
        autoSort = true,        -- Ordenamiento automático por textura/tipo
        dynamicBatching = true, -- Batching dinámico basado en visibilidad
        
        -- Configuración de lotes por tipo
        batchConfigs = {
            stars = {maxSize = 10000, priority = 1},
            asteroids = {maxSize = 8000, priority = 2},
            nebulae = {maxSize = 5000, priority = 3},
            stations = {maxSize = 2000, priority = 4},
            effects = {maxSize = 3000, priority = 5}
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
function OptimizedRenderer.renderObjects(objects, objectType, camera, chunkX, chunkY)
    if not objects or not camera then return 0 end
    
    local renderedCount = 0
    local culledCount = 0
    
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
        
        -- Frustum culling (usar tamaño escalado)
        local objSize = ((obj.size or 10)) * ws
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

-- Renderizar estrella con batching mejorado
function OptimizedRenderer.renderStarBatched(star, x, y, size, lodLevel)
    if lodLevel >= 3 then
        -- LOD mínimo - saltear para performance
        return
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

-- Renderizar asteroide con batching
function OptimizedRenderer.renderAsteroidBatched(asteroid, x, y, size, lodLevel)
    if lodLevel >= 3 then return end -- Saltear LOD muy bajo
    
    local batch = OptimizedRenderer.state.batches.asteroids
    if not batch then
        OptimizedRenderer.renderAsteroid(asteroid, x, y, size, lodLevel)
        return
    end
    
    -- Configurar color del asteroide
    local color = {0.4, 0.3, 0.2, 1}
    local brightness = 1.0 - (lodLevel * 0.2) -- Reducir brillo con LOD
    
    -- Flush preventivo si el batch está lleno
    local maxCount = OptimizedRenderer.config.batching.batchConfigs.asteroids.maxSize
    if batch:getCount() >= (maxCount - 100) then
        OptimizedRenderer.flushAsteroidBatch()
    end
    
    batch:setColor(color[1] * brightness, color[2] * brightness, color[3] * brightness, color[4])
    batch:add(x, y, 0, size * 2, size * 2, 0.5, 0.5)
end

-- Renderizar nebulosa con batching
function OptimizedRenderer.renderNebulaBatched(nebula, x, y, size, lodLevel)
    if lodLevel >= 3 then return end
    
    local batch = OptimizedRenderer.state.batches.nebulae
    if not batch then
        OptimizedRenderer.renderNebula(nebula, x, y, size, lodLevel)
        return
    end
    
    local color = nebula.color or {0.5, 0.3, 0.8, 0.5}
    local intensity = (nebula.intensity or 0.5) * (1.0 - lodLevel * 0.15)
    
    -- Efecto de pulso para nebulosas
    local time = love.timer.getTime()
    local pulse = 0.9 + 0.1 * math.sin(time * 0.8)
    
    -- Flush preventivo
    local maxCount = OptimizedRenderer.config.batching.batchConfigs.nebulae.maxSize
    if batch:getCount() >= (maxCount - 100) then
        OptimizedRenderer.flushNebulaBatch()
    end
    
    batch:setColor(color[1], color[2], color[3], color[4] * intensity * pulse)
    batch:add(x, y, 0, size * pulse * 2, size * pulse * 2, 0.5, 0.5)
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

return OptimizedRenderer