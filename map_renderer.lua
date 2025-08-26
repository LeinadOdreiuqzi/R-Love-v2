-- Función unificada de parallax
function MapRenderer.calculateLayerParallax(camera_x, camera_y, layer_config, zoom)
    local parallax_x = camera_x * layer_config.parallax_factor * zoom
    local parallax_y = camera_y * layer_config.parallax_factor * zoom
    
    -- Aplicar límites para evitar desplazamientos excesivos
    local max_offset = 1000 / zoom
    parallax_x = math.max(-max_offset, math.min(max_offset, parallax_x))
    parallax_y = math.max(-max_offset, math.min(max_offset, parallax_y))
    
    return parallax_x, parallax_y
end

-- Renderizado por capas optimizado
function MapRenderer.drawLayeredSystem(camera, zoom)
    for layer_name, layer_config in pairs(MapConfig.layers) do
        -- Calcular parallax para esta capa
        local offset_x, offset_y = MapRenderer.calculateLayerParallax(
            camera.x, camera.y, layer_config, zoom
        )
        
        -- Aplicar LOD basado en zoom y configuración de capa
        local lod_level = math.min(1.0, zoom * layer_config.lod_threshold)
        
        -- Renderizar elementos de la capa
        MapRenderer.renderLayerElements(layer_config, offset_x, offset_y, lod_level)
    end
end

-- Optimización de microestrellas con transiciones suaves
function MapRenderer.drawOptimizedMicroStars(camera, zoom)
    local config = MapConfig._microStars
    
    -- Calcular densidad basada en zoom con transición suave
    local zoom_factor = math.max(0, math.min(1, 
        (config.showBelowZoom - zoom) / (config.showBelowZoom * 0.3)
    ))
    
    if zoom_factor <= 0 then return end
    
    -- Ajustar densidad dinámicamente
    local dynamic_density = config.densityPerPixel * zoom_factor
    local star_count = math.min(config.maxCount, 
        love.graphics.getWidth() * love.graphics.getHeight() * dynamic_density
    )
    
    -- Usar instanced rendering para mejor rendimiento
    if star_count > 100 then
        MapRenderer.drawInstancedMicroStars(camera, zoom_factor, star_count)
    else
        MapRenderer.drawBatchedMicroStars(camera, zoom_factor, star_count)
    end
end