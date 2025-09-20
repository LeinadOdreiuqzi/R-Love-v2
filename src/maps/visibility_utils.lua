-- src/maps/visibility_utils.lua
-- Utilidad compartida para calcular bounds de chunks visibles de forma consistente

local MapConfig = require 'src.maps.config.map_config'

local VisibilityUtils = {}

-- Configuración del margen dinámico (puede ser modificada externamente)
VisibilityUtils.dynamicMarginConfig = {
    baseMargin = 300,
    zoomThreshold = 0.3,
    nebulaMarginMultiplier = 1.5,
    maxZoomFactor = 3.0,
    maxMarginMultiplier = 8.0,
    lowZoomBonus = 200
}

-- Calcula el margen dinámico basado en el zoom y tamaño de nebulosas
local function calculateDynamicMargin(camera, baseMargingPx)
    local config = VisibilityUtils.dynamicMarginConfig
    local baseMargin = baseMargingPx or config.baseMargin
    
    -- Si no hay cámara, usar margen base
    if not camera or not camera.zoom then
        return baseMargin
    end
    
    local zoom = camera.zoom
    
    -- Obtener configuración de nebulosas desde MapConfig
    local nebulaConfig = MapConfig.nebulae
    if not nebulaConfig or not nebulaConfig.sizeTiers then
        return baseMargin -- Fallback si no hay configuración
    end
    
    -- Calcular el tamaño máximo de nebulosa
    local maxNebulaSize = nebulaConfig.sizeTiers.gigantic and nebulaConfig.sizeTiers.gigantic.max or 1200
    local baseSizeScale = nebulaConfig.baseSizeScale or 1.80
    local worldScale = MapConfig.chunk.worldScale or 2.0
    
    -- Calcular el tamaño máximo real de nebulosa en píxeles de pantalla
    local maxNebulaWorldSize = maxNebulaSize * baseSizeScale * worldScale
    local maxNebulaScreenSize = maxNebulaWorldSize * zoom
    
    -- Margen adaptativo basado en zoom y tamaño de nebulosas
    local adaptiveMargin
    
    if zoom >= config.zoomThreshold then
        -- En zooms altos, necesitamos margen suficiente para nebulosas grandes
        local nebulaMargin = maxNebulaScreenSize * config.nebulaMarginMultiplier
        adaptiveMargin = math.max(baseMargin, nebulaMargin)
        
        -- Escalar gradualmente el margen adicional según el zoom
        local zoomFactor = math.min(zoom / config.zoomThreshold, config.maxZoomFactor)
        adaptiveMargin = adaptiveMargin * zoomFactor
    else
        -- En zooms bajos, usar margen base con pequeño incremento
        local zoomBonus = zoom * config.lowZoomBonus
        adaptiveMargin = baseMargin + zoomBonus
    end
    
    -- Limitar el margen máximo para evitar cargar demasiados chunks
    local maxMargin = baseMargin * config.maxMarginMultiplier
    adaptiveMargin = math.min(adaptiveMargin, maxMargin)
    
    return math.floor(adaptiveMargin)
end

-- Calcula los índices de chunk visibles y el rectángulo del viewport en world-space.
-- marginPx: margen en píxeles alrededor de la pantalla (opcional, se calculará dinámicamente)
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
    
    -- Usar margen dinámico si no se especifica uno
    local margin = marginPx or calculateDynamicMargin(camera, 300)

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
        strideScaled = strideScaled,
        -- Información adicional para debug y optimización
        isDynamicMargin = marginPx == nil,
        zoom = camera.zoom or 0,
        baseMargin = 300
    }
end

-- Función de utilidad para obtener información detallada del margen dinámico
-- Útil para debug y monitoreo del sistema
function VisibilityUtils.getDynamicMarginInfo(camera, baseMargingPx)
    local config = VisibilityUtils.dynamicMarginConfig
    local baseMargin = baseMargingPx or config.baseMargin
    
    if not camera or not camera.zoom then
        return {
            margin = baseMargin,
            zoom = 0,
            isDynamic = false,
            reason = "no_camera"
        }
    end
    
    local zoom = camera.zoom
    local nebulaConfig = MapConfig.nebulae
    
    if not nebulaConfig or not nebulaConfig.sizeTiers then
        return {
            margin = baseMargin,
            zoom = zoom,
            isDynamic = false,
            reason = "no_nebula_config"
        }
    end
    
    local maxNebulaSize = nebulaConfig.sizeTiers.gigantic and nebulaConfig.sizeTiers.gigantic.max or 1200
    local baseSizeScale = nebulaConfig.baseSizeScale or 1.80
    local worldScale = MapConfig.chunk.worldScale or 2.0
    local maxNebulaWorldSize = maxNebulaSize * baseSizeScale * worldScale
    local maxNebulaScreenSize = maxNebulaWorldSize * zoom
    
    local calculatedMargin = calculateDynamicMargin(camera, baseMargingPx)
    
    return {
        margin = calculatedMargin,
        zoom = zoom,
        isDynamic = true,
        baseMargin = baseMargin,
        maxNebulaScreenSize = maxNebulaScreenSize,
        zoomThreshold = config.zoomThreshold,
        isAboveThreshold = zoom >= config.zoomThreshold,
        marginIncrease = calculatedMargin / baseMargin,
        config = config
    }
end

return VisibilityUtils