local HUD = require('src.ui.hud.core')

-- Función de compatibilidad para estadísticas optimizada con cache
function HUD.getSafeStats()
    if hudState.performance.enableCaching and 
       hudState.renderCache.cachedStats and 
       not hudState.renderCache.dirtyFlags.stats then
        hudState.renderCache.cachedStats.fps = love.timer.getFPS()
        return hudState.renderCache.cachedStats
    end
    
    local stats = {
        loadedChunks = 0,
        cachedChunks = 0,
        seed = "UNKNOWN00",
        worldScale = 1,
        frameTime = 0,
        biomesActive = 0,
        fps = love.timer.getFPS(),
        renderStats = {
            totalObjects = 0,
            renderedObjects = 0,
            culledObjects = 0
        }
    }
    
    if gameState and gameState.currentSeed then
        stats.seed = gameState.currentSeed
    end
    
    if Map then
        if Map.seed then stats.seed = Map.seed end
        if Map.worldScale then stats.worldScale = Map.worldScale end
        
        local success, mapStats = pcall(function() 
            if Map.getStats then
                return Map.getStats() 
            end
            return nil
        end)
        
        if success and mapStats then
            if mapStats.chunks then
                stats.chunks = mapStats.chunks
                
                local fsSuccess, fsStats = pcall(function()
                    if ChunkManager and ChunkManager.getFullscreenStats then
                        return ChunkManager.getFullscreenStats()
                    end
                    return nil
                end)
                
                if fsSuccess and fsStats then
                    stats.chunks.fullscreenOptimizations = fsStats
                end
            elseif mapStats.loadedChunks then
                stats.loadedChunks = mapStats.loadedChunks
            end
            
            if mapStats.rendering then
                stats.rendering = mapStats.rendering
            elseif mapStats.renderStats then
                stats.renderStats = mapStats.renderStats
            end
            
            if mapStats.coordinates then
                stats.coordinates = mapStats.coordinates
            end
            
            if mapStats.frameTime then stats.frameTime = mapStats.frameTime end
            if mapStats.biomesActive then stats.biomesActive = mapStats.biomesActive end
        else
            if Map.renderStats then 
                stats.renderStats = Map.renderStats
                stats.biomesActive = Map.renderStats.biomesActive or 0
            end
            
            if Map.chunks then
                pcall(function()
                    for x, row in pairs(Map.chunks) do
                        for y, chunk in pairs(row) do
                            if chunk then stats.loadedChunks = stats.loadedChunks + 1 end
                        end
                    end
                end)
            end
        end
    end
    
    if hudState.performance.enableCaching then
        hudState.renderCache.cachedStats = stats
        hudState.renderCache.dirtyFlags.stats = false
    end
    
    return stats
end

-- Calcular coordenadas de chunk de forma segura
function HUD.getSafeChunkCoords(worldX, worldY)
    local chunkX, chunkY = 0, 0
    
    if Map then
        local success, cx, cy = pcall(function()
            if Map.getChunkInfo then
                return Map.getChunkInfo(worldX, worldY)
            end
            return nil, nil
        end)
        
        if success and cx and cy then
            return cx, cy
        end
        
        if Map.chunkSize and Map.tileSize then
            local chunkSize = Map.chunkSize * Map.tileSize
            chunkX = math.floor(worldX / chunkSize)
            chunkY = math.floor(worldY / chunkSize)
        end
    end
    
    return chunkX, chunkY
end

return HUD