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
    MapRenderer.init()
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
    
    local rendererSuccess = pcall(function()
        OptimizedRenderer.init()
    end)
    if not rendererSuccess then
        print("Warning: OptimizedRenderer not available")
    end
    
    -- Inicializar estructuras tradicionales
    Map.chunks = {}
    Map.loadedChunks = {}
    
    Map.initialized = true
    
    print("✓ Enhanced Map System Ready")
    print("✓ Modular Architecture Active")
    print("=== MAP SYSTEM READY ===")
end

-- Actualización principal del mapa
function Map.update(dt, playerX, playerY)
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
    
    -- Actualizar gestor de chunks
    pcall(function()
        if ChunkManager and ChunkManager.update then
            ChunkManager.update(dt, playerX, playerY)
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
    
    -- Dibujar fondo según bioma dominante
    local biomesActive = MapRenderer.drawBiomeBackground(chunkInfo, Map.getChunkTraditional)
    MapStats.setBiomesActive(biomesActive)
    
    -- Renderizar usando el sistema modular
    Map.drawTraditionalImproved(camera, chunkInfo)
    
    -- Grid de debug si está habilitado
    if _G.showGrid then
        Map.drawEnhancedGrid(chunkInfo, camera)
    end
    
    -- Actualizar estadísticas del frame
    MapStats.updateFrameStats(frameStart)
end

-- Renderizado principal mejorado
function Map.drawTraditionalImproved(camera, chunkInfo)
    -- 1. Dibujar estrellas con efectos mejorados
    local starsRendered, starsTotal = MapRenderer.drawEnhancedStars(
        chunkInfo, camera, Map.getChunkTraditional, Map.starConfig
    )
    MapStats.addObjects(starsTotal, starsRendered, starsTotal - starsRendered)
    
    -- 2. Dibujar nebulosas
    local nebulaeRendered = MapRenderer.drawNebulae(chunkInfo, camera, Map.getChunkTraditional)
    MapStats.addObjects(nebulaeRendered, nebulaeRendered, 0)
    
    -- 3. Dibujar asteroides
    local asteroidsRendered = MapRenderer.drawAsteroids(chunkInfo, camera, Map.getChunkTraditional)
    MapStats.addObjects(asteroidsRendered, asteroidsRendered, 0)
    
    -- 4. Dibujar objetos especiales
    local specialRendered = MapRenderer.drawSpecialObjects(chunkInfo, camera, Map.getChunkTraditional)
    MapStats.addObjects(specialRendered, specialRendered, 0)
    
    -- 5. Dibujar características de biomas
    local featuresRendered = MapRenderer.drawBiomeFeatures(chunkInfo, camera, Map.getChunkTraditional)
    MapStats.addObjects(featuresRendered, featuresRendered, 0)
end

-- Calcular chunks visibles (compatible)
function Map.calculateVisibleChunksTraditional(camera)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Add a margin around the screen to ensure objects don't pop in at the edges
    local margin = 200
    
    -- Convert screen corners to world coordinates with margin
    local worldLeft, worldTop = camera:screenToWorld(-margin, -margin)
    local worldRight, worldBottom = camera:screenToWorld(screenWidth + margin, screenHeight + margin)
    
    -- Calculate chunk coordinates based on visible area
    local chunkSize = Map.chunkSize * Map.tileSize
    local chunkStartX = math.floor(worldLeft / chunkSize)
    local chunkStartY = math.floor(worldTop / chunkSize)
    local chunkEndX = math.ceil(worldRight / chunkSize)
    local chunkEndY = math.ceil(worldBottom / chunkSize)
    
    -- Add an extra chunk in each direction to ensure smooth transitions
    chunkStartX = chunkStartX - 1
    chunkStartY = chunkStartY - 1
    chunkEndX = chunkEndX + 1
    chunkEndY = chunkEndY + 1
    
    return {
        startX = chunkStartX, startY = chunkStartY,
        endX = chunkEndX, endY = chunkEndY,
        worldLeft = worldLeft, worldTop = worldTop,
        worldRight = worldRight, worldBottom = worldBottom
    }
end

-- Obtener chunk (híbrido: intenta ChunkManager, luego tradicional)
function Map.getChunkTraditional(chunkX, chunkY)
    -- Intentar usar ChunkManager si está disponible
    if ChunkManager and ChunkManager.getChunk then
        local chunk = ChunkManager.getChunk(chunkX, chunkY, 0, 0)
        if chunk then return chunk end
    end
    
    -- Fallback al sistema tradicional
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
    
    -- Grid básico
    love.graphics.setColor(0.1, 0.1, 0.2, 0.3)
    local gridSpacing = 100 * Map.worldScale
    
    -- Usar coordenadas relativas si está disponible
    local relLeft, relTop, relRight, relBottom
    local camRelX, camRelY
    
    if CoordinateSystem and CoordinateSystem.worldToRelative then
        relLeft, relTop = CoordinateSystem.worldToRelative(chunkInfo.worldLeft, chunkInfo.worldTop)
        relRight, relBottom = CoordinateSystem.worldToRelative(chunkInfo.worldRight, chunkInfo.worldBottom)
        camRelX, camRelY = CoordinateSystem.worldToRelative(camera.x, camera.y)
    else
        relLeft, relTop = chunkInfo.worldLeft, chunkInfo.worldTop
        relRight, relBottom = chunkInfo.worldRight, chunkInfo.worldBottom
        camRelX, camRelY = camera.x, camera.y
    end
    
    local startX = math.floor(relLeft / gridSpacing) * gridSpacing
    local startY = math.floor(relTop / gridSpacing) * gridSpacing
    local endX = math.ceil(relRight / gridSpacing) * gridSpacing
    local endY = math.ceil(relBottom / gridSpacing) * gridSpacing
    
    -- Dibujar líneas de grid
    for x = startX, endX, gridSpacing do
        local screenX = (x - camRelX) * camera.zoom + love.graphics.getWidth() / 2
        local screenY1 = (startY - camRelY) * camera.zoom + love.graphics.getHeight() / 2
        local screenY2 = (endY - camRelY) * camera.zoom + love.graphics.getHeight() / 2
        love.graphics.line(screenX, screenY1, screenX, screenY2)
    end
    
    for y = startY, endY, gridSpacing do
        local screenY = (y - camRelY) * camera.zoom + love.graphics.getHeight() / 2
        local screenX1 = (startX - camRelX) * camera.zoom + love.graphics.getWidth() / 2
        local screenX2 = (endX - camRelX) * camera.zoom + love.graphics.getWidth() / 2
        love.graphics.line(screenX1, screenY, screenX2, screenY)
    end
    
    -- Información del sistema de coordenadas
    if camera.zoom > 0.3 and CoordinateSystem and CoordinateSystem.getState then
        love.graphics.setColor(1, 1, 0, 0.8)
        local coordState = CoordinateSystem.getState()
        local infoText = string.format("Sector (%d,%d) | Relocations: %d", 
                                     coordState.originSector.x, 
                                     coordState.originSector.y,
                                     coordState.relocations)
        love.graphics.print(infoText, 10, love.graphics.getHeight() - 40)
    end
    
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
    local chunk = Map.getChunkTraditional(chunkX, chunkY)
    return chunk and chunk.biome or nil
end

function Map.getChunk(chunkX, chunkY, playerX, playerY)
    if ChunkManager and ChunkManager.getChunk then
        return ChunkManager.getChunk(chunkX, chunkY, playerX or 0, playerY or 0)
    end
    return Map.getChunkTraditional(chunkX, chunkY)
end

function Map.getChunkInfo(worldX, worldY)
    local chunkX = math.floor(worldX / Map.stride)
    local chunkY = math.floor(worldY / Map.stride)
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