-- src/sublevels/debug_grid.lua
-- Grilla de debug para subniveles, reutilizando las utilidades del Map

local DebugGrid = {}

function DebugGrid.draw(camera)
    if not _G.showGrid then return end
    local Map = require 'src.maps.map'
    if not Map or not camera then return end

    local ok, chunkInfo = pcall(function()
        return Map.calculateVisibleChunksTraditional(camera)
    end)
    if not ok or not chunkInfo then return end

    if Map.drawChunkGridOverlay then
        Map.drawChunkGridOverlay(chunkInfo, camera)
    end
    if Map.drawEnhancedGrid then
        Map.drawEnhancedGrid(chunkInfo, camera)
    end
end

return DebugGrid