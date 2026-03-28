-- src/maps/map.lua (SIMPLIFICADO - COORDINADOR PRINCIPAL)

local Map = {}

-- Importar sistemas modulares
local PerlinNoise = require 'src.maps.perlin_noise'
local BiomeSystem = require 'src.maps.biome_system'
local CoordinateSystem = require 'src.maps.coordinate_system'
local ChunkManager = require 'src.maps.chunk_manager'
local OptimizedRenderer = require 'src.maps.optimized_renderer'

-- Importar módulos nuevos
local SeedConverter = require 'src.maps.systems.seed_converter'
local MapGenerator = require 'src.maps.systems.map_generator'
local MapRenderer = require 'src.maps.systems.map_renderer'
local MapStats = require 'src.maps.systems.map_stats'
local MapConfig = require 'src.maps.config.map_config'
local VisibilityUtils = require 'src.maps.visibility_utils'

-- Getter perezoso del World (evita require circular durante la carga inicial)
local function getWorld()
    return package.loaded['src.core.world']
end

-- Estado principal del mapa
Map.seed = "A1B2C3D4E5"  -- Semilla alfanumérica por defecto
Map.numericSeed = 12345   -- Semilla numérica equivalente
Map.initialized = false
Map.lastPlayerPosition = {x = 0, y = 0}

-- Configuración exportada para compatibilidad
Map.chunkSize = MapConfig.chunk.size
Map.tileSize = MapConfig.chunk.tileSize
Map.worldScale = MapConfig.chunk.worldScale
Map.viewDistance = MapConfig.chunk.viewDistance
Map.ObjectType = MapConfig.ObjectType
Map.colors = MapConfig.colors
Map.baseDensity = MapConfig.density

-- Stride unificado para posicionamiento de chunks (tamaño físico + espaciado)
Map.stride = (MapConfig.chunk.size * MapConfig.chunk.tileSize) + MapConfig.chunk.spacing

-- Configuración de estrellas exportada
Map.starConfig = MapConfig.stars

-- Chunks tradicionales (compatibilidad)
Map.chunks = {}
Map.loadedChunks = {}

-- Estadísticas exportadas para compatibilidad
Map.renderStats = MapStats.renderStats

-- Inicialización principal del mapa
function Map.init(seed)
    -- Procesar semilla de entrada
    Map.seed = seed or "A1B2C3D4E5"
    Map.numericSeed = SeedConverter.toNumeric(Map.seed)
    MapStats.setSeedType(SeedConverter.isAlphanumeric(Map.seed) and "alphanumeric" or "legacy")
    
    print("=== ENHANCED MAP SYSTEM INITIALIZING ===")
    print("Input Seed: " .. tostring(Map.seed))
    print("Seed Type: " .. MapStats.renderStats.seedType)
    print("Numeric Seed: " .. Map.numericSeed)
    
    -- Inicializar sistemas base
    PerlinNoise.init(Map.numericSeed)
    BiomeSystem.init(Map.seed)
    MapRenderer.init(Map.numericSeed)
    MapStats.init()
    
    -- Inicializar dimensiones de pantalla
    Map.updateScreenDimensions()
    
    -- Inicializar sistemas avanzados con manejo de errores
    local coordSuccess = pcall(function()
        CoordinateSystem.init(0, 0)
    end)
    if not coordSuccess then
        print("Warning: CoordinateSystem not available")
    end
    
    local chunkSuccess = pcall(function()
        ChunkManager.init(Map.numericSeed)
    end)
    if not chunkSuccess then
        print("Warning: ChunkManager not available")
    end
    
    -- Inicializar sistema de fases
    local phaseSuccess = pcall(function()
        local PhaseSystem = require 'src.gameplay.phase_system'
        PhaseSystem.init()
        -- Registrar callback para expansión de fases
        PhaseSystem.onPhaseExpanded = ChunkManager.onPhaseExpanded
    end)
    if not phaseSuccess then
        print("Warning: PhaseSystem not available")
    end
    
    local rendererSuccess, rendererErr = pcall(function()
        if not OptimizedRenderer or not OptimizedRenderer.init then
            error("OptimizedRenderer.init is missing")
        end
        OptimizedRenderer.init()
    end)
    if not rendererSuccess then
        print("Warning: OptimizedRenderer not available: " .. tostring(rendererErr))
    end
    
    -- Inicializar BackgroundManager
    local backgroundSuccess, backgroundErr = pcall(function()
        local BackgroundManager = require 'src.shaders.background_manager'
        BackgroundManager.init()
        BackgroundManager.setSeed(Map.numericSeed)
    end)
    if not backgroundSuccess then
        print("Warning: BackgroundManager not available:", backgroundErr)
    end
    
    -- Inicializar estructuras tradicionales
    Map.chunks = {}
    Map.loadedChunks = {}
    
    Map.initialized = true
    
    print("✓ Enhanced Map System Ready")
    print("✓ Modular Architecture Active")
    print("=== MAP SYSTEM READY ===")
end

-- Actualización principal del mapa con velocidad del jugador
-- src/maps/map.lua (SIMPLIFICADO - COORDINADOR PRINCIPAL)

function Map.update(dt, playerX, playerY, playerVelX, playerVelY)
    if not Map.initialized then return end
    
    local frameStart = love.timer.getTime()
    
    -- Actualizar sistema de coordenadas
    pcall(function()
        if CoordinateSystem and CoordinateSystem.update then
            local relocated = CoordinateSystem.update(playerX, playerY)
            if relocated then
                MapStats.incrementCoordinateRelocations()
                print("Coordinate system relocated - total: " .. MapStats.renderStats.coordinateRelocations)
            end
        end
    end)
    
    -- Actualizar gestor de chunks con velocidad para precarga direccional
    pcall(function()
        if ChunkManager and ChunkManager.update then
            ChunkManager.update(dt, playerX, playerY, playerVelX, playerVelY)
        end
    end)
    
    -- Actualizar sistema de fases
    pcall(function()
        local PhaseSystem = require 'src.gameplay.phase_system'
        if PhaseSystem and PhaseSystem.update then
            PhaseSystem.update(dt, playerX, playerY)
        end
    end)
    
    -- Actualizar estadísticas de biomas
    local lastPos = Map.lastPlayerPosition
    local movement = math.sqrt((playerX - lastPos.x)^2 + (playerY - lastPos.y)^2)
    
    if movement > 10 then
        if BiomeSystem and BiomeSystem.updatePlayerBiome then
            BiomeSystem.updatePlayerBiome(playerX, playerY)
        end
        Map.lastPlayerPosition = {x = playerX, y = playerY}
    end
    
    -- Actualizar sistema de anomalías gravitacionales
    pcall(function()
        local GravityAnomaly = require 'src.shaders.gravity_anomaly'
        -- Preferir World sobre _G.camera para evitar dependencia global
        local w = getWorld()
        local cam = (w and w.getCamera()) or _G.camera or {zoom = 1, x = playerX, y = playerY}
        local chunkInfo = Map.calculateVisibleChunksTraditional(cam)
        GravityAnomaly.update(dt, chunkInfo, Map.getChunkNonBlocking)
        
        -- Actualizar sistema continuo de anomalías basado en el bioma del jugador
        GravityAnomaly.updateContinuousSystem(dt, playerX, playerY)
    end)
    
    -- Asegurar actualización por frame del sistema de shaders (u_time, precarga incremental, etc.)
    pcall(function()
        if OptimizedRenderer and OptimizedRenderer.update then
            -- Si tienes _G.camera global (según tu main.lua), lo pasamos para precarga cercana
            OptimizedRenderer.update(dt, playerX, playerY, _G and _G.camera or nil)
        end
    end)
    
    -- Actualizar estadísticas del frame
    MapStats.updateFrameStats(frameStart)
end

-- Dibujo principal del mapa
function Map.draw(camera)
    if not Map.initialized or not camera then return end
    
    local frameStart = love.timer.getTime()
    MapStats.resetFrameStats()
    
    -- Calcular chunks visibles
    local chunkInfo = Map.calculateVisibleChunksTraditional(camera)

    -- Renderizar fondo galáctico procedural (capa más profunda)
    local BackgroundManager = require 'src.shaders.background_manager'
    BackgroundManager.render(camera)
    
    -- Dibujar fondo según bioma dominante
    local biomesActive = MapRenderer.drawBiomeBackground(chunkInfo, Map.getChunkNonBlocking)
    MapStats.setBiomesActive(biomesActive)
    
    -- NUEVO: microestrellas de fondo (spritebatch con culling por zoom)
    MapRenderer.drawMicroStars(camera)
    
    -- NUEVO: estrellas pequeñas (capa intermedia)
    MapRenderer.drawSmallStars(camera)
    
    -- Renderizar usando el sistema modular (incluye anomalías y overlays de lentes)
    Map.drawTraditionalImproved(camera, chunkInfo)
    
    -- Grid de debug si está habilitado
    if _G.showGrid then
        -- Overlay de grid de chunks (límites e índices)
        Map.drawChunkGridOverlay(chunkInfo, camera)
        -- Overlay anterior (grid relativo + estado de coordenadas)
        Map.drawEnhancedGrid(chunkInfo, camera)
    end
    
    -- Actualizar estadísticas del frame
    MapStats.updateFrameStats(frameStart)
end

-- Renderizado principal mejorado (versión optimizada)
function Map.drawTraditionalImproved(camera, chunkInfo)
    local MapRenderer = require 'src.maps.systems.map_renderer'
    
    -- 0. Renderizar estrellas (Fondo) primero para que queden DETRÁS de todo
    -- 1. Estrellas mejoradas (main stars) - Pasado a capa de fondo
    local starsRendered, starsTotal = MapRenderer.drawEnhancedStars(
        chunkInfo, camera, Map.getChunkNonBlocking, Map.starConfig
    )
    MapStats.addObjects(starsTotal, starsRendered, starsTotal - starsRendered)
    
    -- 2. Dibujar nebulosas (ahora tapan las estrellas)
    local nebulaeRendered = MapRenderer.drawNebulae(chunkInfo, camera, Map.getChunkNonBlocking)
    MapStats.addObjects(nebulaeRendered, nebulaeRendered, 0)
    
    -- 3. Dibujar asteroides
    local asteroidsRendered = MapRenderer.drawAsteroids(chunkInfo, camera, Map.getChunkNonBlocking)
    MapStats.addObjects(asteroidsRendered, asteroidsRendered, 0)
    
    -- 4. Dibujar objetos especiales
    local specialRendered = MapRenderer.drawSpecialObjects(chunkInfo, camera, Map.getChunkNonBlocking)
    MapStats.addObjects(specialRendered, specialRendered, 0)
    
    -- 4.5. Dibujar items del mundo
    local WorldItems = require 'src.item_systems.world_items'
    -- Preferir World sobre _G.player
    local w = getWorld()
    local _player = (w and w.getPlayer()) or _G.player
    local playerX, playerY = 0, 0
    if _player then
        playerX, playerY = _player.x or 0, _player.y or 0
    end
    local itemsRendered = WorldItems.draw(camera, playerX, playerY)
    MapStats.addObjects(itemsRendered or 0, itemsRendered or 0, 0)
    
    -- 5. Dibujar características de biomas
    local featuresRendered = MapRenderer.drawBiomeFeatures(chunkInfo, camera, Map.getChunkNonBlocking)
    MapStats.addObjects(featuresRendered, featuresRendered, 0)
    
    -- 6. Dibujar anomalías gravitacionales
    local GravityAnomaly = require 'src.shaders.gravity_anomaly'
    local anomaliesRendered = GravityAnomaly.drawAnomalies(chunkInfo, camera, Map.getChunkNonBlocking)
    MapStats.addObjects(anomaliesRendered, anomaliesRendered, 0)
    
    -- Actualizar y dibujar anomalías continuas
    GravityAnomaly.updateContinuousAnomalies(camera)
    GravityAnomaly.drawContinuousAnomalies(camera)
    GravityAnomaly.drawContinuousOverlays(camera)
    
    -- 7. Dibujar placeholders de ancient ruins
    local AncientRuinsRenderer = require 'src.maps.systems.ancient_ruins_renderer'
    local ruinsRendered = AncientRuinsRenderer.renderPlaceholders(chunkInfo, camera, Map.getChunkNonBlocking)
    MapStats.addObjects(ruinsRendered, ruinsRendered, 0)
end
-- Utilidad unificada: calcular bounds de chunks visibles con margen de pantalla (px)
function Map.getVisibleChunkBounds(camera, marginPx)
    -- Usar la utilidad compartida con anillo de precarga suave (+/-3)
    return VisibilityUtils.getVisibleChunkBounds(camera, marginPx or 800, 3)
end

-- Calcular chunks visibles (compatible)
function Map.calculateVisibleChunksTraditional(camera)
    -- Delegar a la utilidad sin anillo de precarga (lo maneja ChunkManager)
    return VisibilityUtils.getVisibleChunkBounds(camera, 300, 0)
end

-- Obtener chunk (híbrido: intenta ChunkManager, luego tradicional)
-- function Map.getChunkTraditional(chunkX, chunkY)
function Map.getChunkTraditional(chunkX, chunkY)
    -- Si hay ChunkManager y no se ha permitido explícitamente la generación sincrónica,
    -- redirigir a la ruta no bloqueante para evitar parones.
    if ChunkManager and ChunkManager.getChunk and not Map.debugAllowSyncGen then
        return Map.getChunkNonBlocking(chunkX, chunkY)
    end

    -- Fallback al sistema tradicional (permitido en herramientas/debug explícito)
    if not Map.chunks then Map.chunks = {} end
    if not Map.chunks[chunkX] then Map.chunks[chunkX] = {} end
    
    if not Map.chunks[chunkX][chunkY] then
        Map.chunks[chunkX][chunkY] = MapGenerator.generateChunk(chunkX, chunkY)
    end
    
    return Map.chunks[chunkX][chunkY]
end

-- Generación de chunk (delegada al MapGenerator)
function Map.generateChunk(chunkX, chunkY)
    return MapGenerator.generateChunk(chunkX, chunkY)
end

-- Grid mejorado con información de coordenadas
function Map.drawEnhancedGrid(chunkInfo, camera)
    local r, g, b, a = love.graphics.getColor()

    -- Grid básico en coordenadas de mundo (evitar doble transformación con camera:apply)
    love.graphics.setColor(0.1, 0.1, 0.2, 0.3)
    local gridSpacing = 100 * Map.worldScale

    -- Usar bounds de mundo provistos por chunkInfo
    local worldLeft, worldTop   = chunkInfo.worldLeft,  chunkInfo.worldTop
    local worldRight, worldBottom = chunkInfo.worldRight, chunkInfo.worldBottom

    local startX = math.floor(worldLeft / gridSpacing) * gridSpacing
    local startY = math.floor(worldTop  / gridSpacing) * gridSpacing
    local endX   = math.ceil(worldRight / gridSpacing) * gridSpacing
    local endY   = math.ceil(worldBottom/ gridSpacing) * gridSpacing

    -- Dibujar líneas de grid en coordenadas de mundo (la cámara ya está aplicada)
    for x = startX, endX, gridSpacing do
        love.graphics.line(x, worldTop, x, worldBottom)
    end
    for y = startY, endY, gridSpacing do
        love.graphics.line(worldLeft, y, worldRight, y)
    end

    -- Información del sistema de coordenadas (renderizada en mundo para aparecer en pantalla actual)
    if camera.zoom > 0.3 and CoordinateSystem and CoordinateSystem.getState then
        love.graphics.setColor(1, 1, 0, 0.8)
        local coordState = CoordinateSystem.getState()
        local infoText = string.format("Sector (%d,%d) | Relocations: %d",
            coordState.originSector.x,
            coordState.originSector.y,
            coordState.relocations)
        -- Posicionar el texto cerca de la esquina inferior izquierda de la vista actual
        local infoX, infoY = camera:screenToWorld(10, love.graphics.getHeight() - 40)
        love.graphics.print(infoText, infoX, infoY)
    end

    love.graphics.setColor(r, g, b, a)
end

-- Overlay de grid de chunks (líneas de límites e índices)
function Map.drawChunkGridOverlay(chunkInfo, camera)
    local r, g, b, a = love.graphics.getColor()
    local strideScaled = chunkInfo.strideScaled or (Map.stride * Map.worldScale)

    love.graphics.setColor(0.2, 0.8, 1.0, 0.25)

    -- Líneas verticales en límites de chunk (coordenadas de mundo)
    for cx = chunkInfo.startX, chunkInfo.endX + 1 do
        local xWorld = cx * strideScaled
        love.graphics.line(xWorld, chunkInfo.worldTop, xWorld, chunkInfo.worldBottom)
    end

    -- Líneas horizontales en límites de chunk (coordenadas de mundo)
    for cy = chunkInfo.startY, chunkInfo.endY + 1 do
        local yWorld = cy * strideScaled
        love.graphics.line(chunkInfo.worldLeft, yWorld, chunkInfo.worldRight, yWorld)
    end

    -- Índices de chunk en el centro de cada celda (dibujados en mundo)
    if (camera.zoom or 1) > 0.25 then
        love.graphics.setColor(1, 1, 0, 0.8)
        for cy = chunkInfo.startY, chunkInfo.endY do
            for cx = chunkInfo.startX, chunkInfo.endX do
                local centerX = (cx + 0.5) * strideScaled
                local centerY = (cy + 0.5) * strideScaled
                love.graphics.print(string.format("(%d,%d)", cx, cy), centerX + 4, centerY + 4)
            end
        end
    end

    -- Mostrar info de bounds y margen anclado a pantalla (convertir a mundo)
    love.graphics.setColor(0.9, 0.9, 0.9, 0.9)
    local info = string.format("Chunks: [%d..%d]x[%d..%d] | strideScaled=%.1f | marginPx=%d",
        chunkInfo.startX, chunkInfo.endX, chunkInfo.startY, chunkInfo.endY, strideScaled, chunkInfo.marginPx or 0)
    local infoX, infoY = camera:screenToWorld(10, love.graphics.getHeight() - 60)
    love.graphics.print(info, infoX, infoY)

    love.graphics.setColor(r, g, b, a)
end

-- Regenerar mapa
function Map.regenerate(newSeed)
    Map.seed = newSeed
    Map.numericSeed = SeedConverter.toNumeric(newSeed)
    
    -- Limpiar sistemas
    if ChunkManager.cleanup then
        ChunkManager.cleanup()
    end
    
    -- Reinicializar
    Map.init(newSeed)
    
    print("Enhanced map system regenerated")
    print("Alphanumeric seed: " .. tostring(newSeed))
    print("Numeric seed: " .. Map.numericSeed)
    print("Seed type: " .. (SeedConverter.isAlphanumeric(newSeed) and "alphanumeric" or "legacy"))
end

-- Funciones de acceso y compatibilidad
function Map.getPlayerBiome(playerX, playerY)
    local chunkX, chunkY = Map.getChunkInfo(playerX, playerY)
    -- Usar la ruta no bloqueante para evitar generación sincrónica en tiempo de juego
    local chunk = Map.getChunkNonBlocking(chunkX, chunkY)
    return chunk and chunk.biome or nil
end

function Map.getChunk(chunkX, chunkY, playerX, playerY)
    if ChunkManager and ChunkManager.getChunk then
        return ChunkManager.getChunk(chunkX, chunkY, playerX or 0, playerY or 0)
    end
    return Map.getChunkTraditional(chunkX, chunkY)
end

function Map.getChunkInfo(worldX, worldY)
    -- Usar stride escalado para estabilidad con worldScale
    local strideScaled = Map.stride * Map.worldScale
    local chunkX = math.floor(worldX / strideScaled)
    local chunkY = math.floor(worldY / strideScaled)
    return chunkX, chunkY
end

function Map.updateScreenDimensions()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    -- Actualizar en MapRenderer si es necesario
end

-- Estadísticas
function Map.getStats()
    return MapStats.getStats(
        Map.seed, Map.numericSeed, SeedConverter, Map.chunks, 
        BiomeSystem, ChunkManager, OptimizedRenderer, CoordinateSystem
    )
end

function Map.getBiomeStats()
    return MapStats.getBiomeStats(BiomeSystem, MapStats.renderStats)
end

function Map.resetStats()
    MapStats.resetStats()
end
-- NUEVO: obtener chunk sin bloquear (no genera si falta)
function Map.getChunkNonBlocking(chunkX, chunkY)
    if ChunkManager and ChunkManager.getChunk then
        local px = (Map.lastPlayerPosition and Map.lastPlayerPosition.x) or 0
        local py = (Map.lastPlayerPosition and Map.lastPlayerPosition.y) or 0
        return ChunkManager.getChunk(chunkX, chunkY, px, py)
    end
    -- Si no hay ChunkManager, devuelve el ya existente (si lo hay), pero no genera
    if Map.chunks and Map.chunks[chunkX] then
        return Map.chunks[chunkX][chunkY]
    end
    return nil
end
function Map.toggleAsyncLoading()
    print("Async loading is handled by ChunkManager")
    if ChunkManager and ChunkManager.getStats then
        local stats = ChunkManager.getStats()
        print("Current chunk loading status - Active: " .. stats.active .. ", Queue: " .. stats.loadQueue)
    end
end

function Map.getAsyncStats()
    return MapStats.getAsyncStats(ChunkManager)
end

-- Exportar funciones de generación para compatibilidad
Map.multiOctaveNoise = MapGenerator.multiOctaveNoise
Map.generateBalancedAsteroids = MapGenerator.generateBalancedAsteroids
Map.generateBalancedNebulae = MapGenerator.generateBalancedNebulae
Map.generateBalancedSpecialObjects = MapGenerator.generateBalancedSpecialObjects
Map.generateBalancedStars = MapGenerator.generateBalancedStars

-- Exportar funciones de renderizado para compatibilidad
Map.drawAdvancedStar = MapRenderer.drawAdvancedStar
Map.drawNebula = MapRenderer.drawNebula
Map.drawStation = MapRenderer.drawStation
Map.drawWormhole = MapRenderer.drawWormhole
Map.drawAsteroidLOD = MapRenderer.drawAsteroidLOD
Map.drawBiomeFeature = MapRenderer.drawBiomeFeature
Map.isObjectVisible = MapRenderer.isObjectVisible
Map.calculateLOD = MapRenderer.calculateLOD

return Map
