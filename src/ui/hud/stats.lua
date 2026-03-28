local HUD = require('src.ui.hud.core')

-- Función de compatibilidad para estadísticas optimizada con cache
function HUD.getSafeStats()
    if HUD.hudState.performance.enableCaching and 
       HUD.hudState.renderCache.cachedStats and 
       not HUD.hudState.renderCache.dirtyFlags.stats then
        HUD.hudState.renderCache.cachedStats.fps = love.timer.getFPS()
        return HUD.hudState.renderCache.cachedStats
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
    
    if HUD.gameState and HUD.gameState.currentSeed then
        stats.seed = HUD.gameState.currentSeed
    end
    
    if HUD.Map then
        if HUD.Map.seed then stats.seed = HUD.Map.seed end
        if HUD.Map.worldScale then stats.worldScale = HUD.Map.worldScale end
        
        local success, mapStats = pcall(function() 
            if HUD.Map.getStats then
                return HUD.Map.getStats() 
            end
            return nil
        end)
        
        if success and mapStats then
            if mapStats.chunks then
                stats.chunks = mapStats.chunks
                
                local fsSuccess, fsStats = pcall(function()
                    local ChunkManager = require('src.maps.chunk_manager')
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
            if HUD.Map.renderStats then 
                stats.renderStats = HUD.Map.renderStats
                stats.biomesActive = HUD.Map.renderStats.biomesActive or 0
            end
            
            if HUD.Map.chunks then
                pcall(function()
                    for x, row in pairs(HUD.Map.chunks) do
                        for y, chunk in pairs(row) do
                            if chunk then stats.loadedChunks = stats.loadedChunks + 1 end
                        end
                    end
                end)
            end
        end
    end
    
    if HUD.hudState.performance.enableCaching then
        HUD.hudState.renderCache.cachedStats = stats
        HUD.hudState.renderCache.dirtyFlags.stats = false
    end
    
    return stats
end

-- Calcular coordenadas de chunk de forma segura
function HUD.getSafeChunkCoords(worldX, worldY)
    local chunkX, chunkY = 0, 0
    
    if HUD.Map then
        local success, cx, cy = pcall(function()
            if HUD.Map.getChunkInfo then
                return HUD.Map.getChunkInfo(worldX, worldY)
            end
            return nil, nil
        end)
        
        if success and cx and cy then
            return cx, cy
        end
        
        if HUD.Map.chunkSize and HUD.Map.tileSize then
            local chunkSize = HUD.Map.chunkSize * HUD.Map.tileSize
            chunkX = math.floor(worldX / chunkSize)
            chunkY = math.floor(worldY / chunkSize)
        end
    end
    
    return chunkX, chunkY
end

return HUD