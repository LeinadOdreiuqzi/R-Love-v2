-- src/maps/systems/map_stats.lua
-- Sistema de estadísticas del mapa

local MapStats = {}

-- Estado de las estadísticas
MapStats.renderStats = {
    totalObjects = 0,
    renderedObjects = 0,
    culledObjects = 0,
    chunksLoaded = 0,
    chunksGenerated = 0,
    biomesActive = 0,
    coordinateRelocations = 0,
    frameTime = 0,
    memoryUsage = 0,
    seedType = "alphanumeric"
}

-- Inicializar estadísticas
function MapStats.init()
    MapStats.resetStats()
end

-- Reset de estadísticas completas
function MapStats.resetStats()
    MapStats.renderStats = {
        totalObjects = 0,
        renderedObjects = 0,
        culledObjects = 0,
        chunksLoaded = 0,
        chunksGenerated = 0,
        biomesActive = 0,
        coordinateRelocations = 0,
        frameTime = 0,
        memoryUsage = 0,
        seedType = "alphanumeric"
    }
end

-- Reset de estadísticas por frame
function MapStats.resetFrameStats()
    MapStats.renderStats.totalObjects = 0
    MapStats.renderStats.renderedObjects = 0
    MapStats.renderStats.culledObjects = 0
end

-- Actualizar estadísticas del frame
function MapStats.updateFrameStats(frameStart)
    MapStats.renderStats.frameTime = love.timer.getTime() - frameStart
end

-- Incrementar contador de objetos
function MapStats.addObjects(total, rendered, culled)
    MapStats.renderStats.totalObjects = MapStats.renderStats.totalObjects + (total or 0)
    MapStats.renderStats.renderedObjects = MapStats.renderStats.renderedObjects + (rendered or 0)
    MapStats.renderStats.culledObjects = MapStats.renderStats.culledObjects + (culled or 0)
end

-- Establecer biomas activos
function MapStats.setBiomesActive(count)
    MapStats.renderStats.biomesActive = count or 0
end

-- Incrementar relocalizaciones de coordenadas
function MapStats.incrementCoordinateRelocations()
    MapStats.renderStats.coordinateRelocations = MapStats.renderStats.coordinateRelocations + 1
end

-- Obtener estadísticas completas del mapa
function MapStats.getStats(seed, numericSeed, SeedConverter, chunks, BiomeSystem, ChunkManager, OptimizedRenderer, CoordinateSystem)
    local stats = {
        -- Información de semilla
        seed = seed,
        numericSeed = numericSeed,
        seedType = MapStats.renderStats.seedType,
        isAlphanumeric = SeedConverter and SeedConverter.isAlphanumeric(seed) or false,
        
        -- Estadísticas básicas del mapa
        worldScale = 0.8,
        frameTime = MapStats.renderStats.frameTime,
        biomesActive = MapStats.renderStats.biomesActive,
        totalObjects = MapStats.renderStats.totalObjects,
        renderedObjects = MapStats.renderStats.renderedObjects,
        culledObjects = MapStats.renderStats.culledObjects,
        coordinateRelocations = MapStats.renderStats.coordinateRelocations,
        
        -- Estadísticas tradicionales de chunks
        loadedChunks = 0,
        cachedChunks = 0
    }
    
    -- Intentar obtener estadísticas del sistema de chunks mejorado
    if ChunkManager and ChunkManager.getStats then
        local success, chunkStats = pcall(function()
            return ChunkManager.getStats()
        end)
        
        if success and chunkStats then
            stats.chunks = chunkStats
        end
    end
    
    -- Intentar obtener estadísticas del renderizador
    if OptimizedRenderer and OptimizedRenderer.getStats then
        local success, rendererStats = pcall(function()
            return OptimizedRenderer.getStats()
        end)
        
        if success and rendererStats then
            stats.rendering = rendererStats
        else
            stats.renderStats = MapStats.renderStats
        end
    else
        stats.renderStats = MapStats.renderStats
    end
    
    -- Intentar obtener estadísticas de coordenadas
    if CoordinateSystem and CoordinateSystem.getStats then
        local success, coordStats = pcall(function()
            return CoordinateSystem.getStats()
        end)
        
        if success and coordStats then
            stats.coordinates = coordStats
        end
    end
    
    -- Contar chunks tradicionales si no hay sistema mejorado
    if not stats.chunks and chunks then
        pcall(function()
            for x, row in pairs(chunks) do
                for y, chunk in pairs(row) do
                    if chunk then 
                        stats.loadedChunks = stats.loadedChunks + 1 
                    end
                end
            end
        end)
    end
    
    return stats
end

-- Obtener estadísticas de biomas
function MapStats.getBiomeStats(BiomeSystem, renderStats)
    if BiomeSystem and BiomeSystem.getAdvancedStats then
        local success, stats = pcall(function()
            return BiomeSystem.getAdvancedStats()
        end)
        
        if success and stats then
            stats.renderStats = renderStats or MapStats.renderStats
            return stats
        end
    end
    
    return {
        totalChunksGenerated = 0,
        biomeDistribution = {},
        renderStats = renderStats or MapStats.renderStats
    }
end

-- Obtener estadísticas de async loading
function MapStats.getAsyncStats(ChunkManager)
    if ChunkManager and ChunkManager.getStats then
        return ChunkManager.getStats()
    end
    
    return {
        active = 0,
        cached = 0,
        pooled = 0,
        loadQueue = 0,
        cacheHitRatio = 0
    }
end

-- Actualizar tipo de semilla
function MapStats.setSeedType(seedType)
    MapStats.renderStats.seedType = seedType or "unknown"
end

-- Obtener estadísticas de renderizado básicas
function MapStats.getRenderStats()
    return MapStats.renderStats
end

return MapStats