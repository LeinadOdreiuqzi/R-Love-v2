-- Nueva configuración de capas con parallax ajustado
MapConfig.layers = {
    -- Capa 1: Fondo fijo (microestrellas)
    background_fixed = {
        parallax_factor = 0.0,
        elements = {"microstars", "deep_space_gradient"},
        render_priority = 1,
        lod_threshold = 0.1,
        size_scale = 0.8 -- Nuevo: escala de tamaño específica
    },
    
    -- Capa 2: Parallax ultra lento (10%) - estrellas muy distantes
    parallax_ultra_slow = {
        parallax_factor = 0.10,
        elements = {"ultra_distant_stars"},
        render_priority = 2,
        lod_threshold = 0.2,
        size_scale = 0.3
    },
    
    -- Capa 3: Parallax muy lento (20%) - estrellas distantes
    parallax_very_slow = {
        parallax_factor = 0.20,
        elements = {"very_distant_stars", "far_nebulae"},
        render_priority = 3,
        lod_threshold = 0.3,
        size_scale = 0.5
    },
    
    -- Capa 4: Parallax lento (35%)
    parallax_slow = {
        parallax_factor = 0.35,
        elements = {"distant_stars", "background_nebulae"},
        render_priority = 4,
        lod_threshold = 0.4,
        size_scale = 0.7
    },
    
    -- Capa 5: Parallax medio (60%)
    parallax_medium = {
        parallax_factor = 0.60,
        elements = {"medium_stars", "background_asteroids"},
        render_priority = 5,
        lod_threshold = 0.6,
        size_scale = 0.9
    },
    
    -- Capa 6: Parallax rápido (85%)
    parallax_fast = {
        parallax_factor = 0.85,
        elements = {"close_stars", "near_nebulae"},
        render_priority = 6,
        lod_threshold = 0.8,
        size_scale = 1.1
    },
    
    -- Capa 7: Capa principal (100%)
    main_layer = {
        parallax_factor = 1.0,
        elements = {"player", "enemies", "interactive_objects", "stations"},
        render_priority = 7,
        lod_threshold = 1.0,
        size_scale = 1.0
    },
    
    -- Capa 8: Foreground (115%)
    foreground = {
        parallax_factor = 1.15,
        elements = {"particles", "light_effects", "distant_satellites", "ui_elements"},
        render_priority = 8,
        lod_threshold = 1.0,
        size_scale = 1.2
    }
}