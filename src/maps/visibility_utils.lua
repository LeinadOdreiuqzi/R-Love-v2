-- src/maps/visibility_utils.lua
-- Utilidad compartida para calcular bounds de chunks visibles de forma consistente

local MapConfig = require 'src.maps.config.map_config'

local VisibilityUtils = {}

-- Calcula los índices de chunk visibles y el rectángulo del viewport en world-space.
-- marginPx: margen en píxeles alrededor de la pantalla
-- preloadRing: entero para expandir los índices (p.ej. +3/-3)
function VisibilityUtils.getVisibleChunkBounds(camera, marginPx, preloadRing)
    if not camera or type(camera.screenToWorld) ~= "function" then
        return {
            startX = 0, startY = 0, endX = -1, endY = -1,
            worldLeft = 0, worldTop = 0, worldRight = 0, worldBottom = 0,
            marginPx = 0, strideScaled = 1
        }
    end

    local screenWidth, screenHeight = love.graphics.getDimensions()
    local margin = marginPx or 300

    -- Viewport con margen a world-space
    local wl, wt = camera:screenToWorld(-margin, -margin)
    local wr, wb = camera:screenToWorld(screenWidth + margin, screenHeight + margin)

    local worldLeft   = math.min(wl, wr)
    local worldRight  = math.max(wl, wr)
    local worldTop    = math.min(wt, wb)
    local worldBottom = math.max(wt, wb)

    -- stride (tamaño físico del chunk + spacing) y worldScale
    local sizePixels = MapConfig.chunk.size * MapConfig.chunk.tileSize
    local stride = sizePixels + (MapConfig.chunk.spacing or 0)
    local strideScaled = stride * (MapConfig.chunk.worldScale or 1)

    -- Índices visibles de chunk
    local startX = math.floor(worldLeft  / strideScaled)
    local startY = math.floor(worldTop   / strideScaled)
    local endX   = math.ceil (worldRight / strideScaled)
    local endY   = math.ceil (worldBottom/ strideScaled)

    -- Anillo opcional de precarga
    local ring = preloadRing or 0
    if ring > 0 then
        startX = startX - ring
        startY = startY - ring
        endX   = endX   + ring
        endY   = endY   + ring
    end

    return {
        startX = startX, startY = startY,
        endX   = endX,   endY   = endY,
        worldLeft = worldLeft, worldTop = worldTop,
        worldRight = worldRight, worldBottom = worldBottom,
        marginPx = margin,
        strideScaled = strideScaled
    }
end

return VisibilityUtils