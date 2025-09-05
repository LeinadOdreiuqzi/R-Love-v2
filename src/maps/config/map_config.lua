-- src/maps/config/map_config.lua
-- Configuración centralizada del sistema de mapas

local MapConfig = {}

MapConfig.chunk = {
    size = 64,
    tileSize = 32,
    worldScale = 2.0,
    viewDistance = 3,
    spacing = 0
}

-- Configuración de estrellas
MapConfig.stars = {
    maxStarsPerFrame = 6000,
    parallaxStrength = 0.15,
    twinkleEnabled = true,
    enhancedEffects = true,
    sizeScaleGlobal = 0.9,
    useInstancedShader = true,
    instancedSizeScale = 5.0,
    -- Capas profundas ajustadas (removiendo niveles menos profundos para la nueva capa intermedia)
    deepLayers = {
        -- Solo mantener las capas más profundas
        { threshold = 0.92,  parallaxScale = 0.04, sizeScale = 0.35 }, -- Ajustado
        { threshold = 0.96,  parallaxScale = 0.06, sizeScale = 0.45 }, -- Ajustado
        { threshold = 0.98,  parallaxScale = 0.08, sizeScale = 0.60 }  -- Ajustado
    },
    -- Configuración para estrellas intermedias (reemplazando capa cercana)
    smallStars = {
        -- Capa 1: Estrellas intermedias pequeñas (reemplaza estrellas cercanas pequeñas)
        layer1 = {
            showBelowZoom = 2.0,        -- Aumentado para mayor visibilidad
            showAboveZoom = 0.2,        -- Límite inferior más bajo
            densityPerPixel = 0.00008,  -- Aumentada la densidad
            maxCount = 500,             -- Aumentado de 300 a 500
            sizeMin = 3.0,              -- Aumentado de 2.0 a 3.0 (más visibles)
            sizeMax = 5.0,              -- Aumentado de 3.5 a 5.0
            alphaMin = 0.4,             -- Aumentado para mejor visibilidad
            alphaMax = 0.8,             -- Aumentado para mejor visibilidad
            parallaxScale = 0.015,      -- Ligeramente aumentado
            depthRange = { min = 0.60, max = 0.80 },  -- Ajustado para capa cercana
            useShaders = true,
            -- Escalado inverso por zoom optimizado
            inverseZoomScaling = {
                enabled = true,
                baseZoom = 1.0,
                minScale = 0.4,         -- Aumentado de 0.3 a 0.4
                maxScale = 2.5          -- Aumentado de 2.0 a 2.5
            }
        },
        -- Capa 2: Estrellas intermedias medianas (reemplaza estrellas cercanas medianas)
        layer2 = {
            showBelowZoom = 1.8,        -- Aumentado para mayor visibilidad
            showAboveZoom = 0.3,        -- Límite inferior ajustado
            densityPerPixel = 0.00006,  -- Aumentada la densidad
            maxCount = 350,             -- Aumentado de 200 a 350
            sizeMin = 4.0,              -- Aumentado de 2.5 a 4.0 (más visibles)
            sizeMax = 6.5,              -- Aumentado de 4.0 a 6.5
            alphaMin = 0.6,             -- Aumentado para mejor visibilidad
            alphaMax = 0.9,             -- Aumentado para mejor visibilidad
            parallaxScale = 0.025,      -- Aumentado para efecto parallax más notorio
            depthRange = { min = 0.75, max = 0.90 },  -- Ajustado para capa cercana
            useShaders = true,
            -- Escalado inverso por zoom optimizado
            inverseZoomScaling = {
                enabled = true,
                baseZoom = 1.0,
                minScale = 0.5,         -- Aumentado de 0.4 a 0.5
                maxScale = 2.2          -- Aumentado de 1.8 a 2.2
            }
        }
    },
    -- Configuración específica para microestrellas
    microStars = {
        showBelowZoom = 0.95,
        densityPerPixel = 0.00018,
        maxCount = 1000,
        sizeMin = 0.5,
        sizeMax = 1.2,
        alphaMin = 0.20,
        alphaMax = 0.55,
        parallaxScale = 0.005
    }
}

-- Densidades base balanceadas
MapConfig.density = {
    asteroids = 8,
    nebulae = 5,
    stations = 3,
    wormholes = 3,
    stars = 0.50
}

-- Tipos de objetos
MapConfig.ObjectType = {
    EMPTY = 0,
    ASTEROID_SMALL = 1,
    ASTEROID_MEDIUM = 2,
    ASTEROID_LARGE = 3,
    NEBULA = 4,
    STATION = 5,
    WORMHOLE = 6,
    STAR = 7,
    SPECIAL_FEATURE = 8,
    BIOME_TRANSITION = 9
}

-- Paleta de colores
MapConfig.colors = {
    asteroids = {
        {0.4, 0.3, 0.2}, {0.3, 0.3, 0.4}, 
        {0.5, 0.4, 0.3}, {0.2, 0.2, 0.3}
    },
    nebulae = {
        {0.8, 0.2, 0.8, 0.3}, {0.2, 0.8, 0.8, 0.3}, 
        {0.8, 0.6, 0.2, 0.3}, {0.2, 0.8, 0.2, 0.3}
    },
    stars = {
        {1.0, 0.9, 0.8, 0.9},   -- Blanco cálido
        {0.8, 0.9, 1.0, 0.9},   -- Azul claro
        {1.0, 0.8, 0.6, 0.9},   -- Naranja
        {0.9, 0.7, 1.0, 0.9},   -- Púrpura claro
        {0.7, 1.0, 0.8, 0.9},   -- Verde claro
        {1.0, 0.7, 0.7, 0.9}    -- Rojo claro
    },
    biomeFeatures = {
        ancient = {0.3, 0.7, 0.5, 0.8},
        radioactive = {0.8, 0.6, 0.2, 0.9},
        gravity = {0.4, 0.2, 0.8, 0.4},
        mega = {0.5, 0.4, 0.3, 1.0}
    }
}

-- NUEVO: configuración de nebulosas (categorías de tamaño)
MapConfig.nebulae = {
    -- Rangos en píxeles base (antes de aplicar worldScale)
    sizeTiers = {
        small     = { min = 80,   max = 220,  weight = 0.58 },
        medium    = { min = 220,  max = 420,  weight = 0.32 },
        large     = { min = 420,  max = 720,  weight = 0.09 },
        gigantic  = { min = 720,  max = 1200, weight = 0.01 }
    },
    -- Factor global para mantener coherencia con lo que tenías (x1.25)
    baseSizeScale = 1.80
}

-- Configuración de renderizado
MapConfig.rendering = {
    maxStarsPerFrame = 6000,
    enhancedEffects = true,
    lodEnabled = true,
    cullingEnabled = true
}

-- Ajuste de densidad por escala + caps (para no perder rendimiento)
MapConfig.spawn = {
    -- Compensación de densidad por píxel (si duplicas worldScale, el área crece 4x)
    densityScale = (MapConfig.chunk.worldScale or 1) ^ 2,

    -- Límites máximos por chunk (ajusta a tu presupuesto)
    caps = {
        asteroids_per_chunk_max = 900,
        debris_per_chunk_max = 1200,
        microstars_per_chunk_max = 3000,
        stars_per_chunk_max = 1600   -- subido desde 1200
    },

    -- LOD simple (opcional): radios de influencia para spawns pesados
    lod = {
        nearRadius = 800 * (MapConfig.chunk.worldScale or 1),
        farCull   = 3000 * (MapConfig.chunk.worldScale or 1)
    }
}
-- Agregar configuración de culling inteligente
MapConfig.stars.smartCulling = {
    enabled = true,
    -- Distancias de culling por zoom
    zoomThresholds = {
        { zoom = 2.0, cullDistance = 200 },
        { zoom = 1.5, cullDistance = 400 },
        { zoom = 1.0, cullDistance = 800 },
        { zoom = 0.5, cullDistance = 1600 }
    },
    -- Culling por importancia visual
    importanceCulling = {
        enabled = true,
        minImportance = 1.5,  -- Solo renderizar estrellas con importancia >= 1.5
        distanceMultiplier = 2.0
    }
}

-- Configuración del fondo galáctico procedural
MapConfig.galacticBackground = {
    -- Configuración de renderizado
    rendering = {
        enabled = true,
        renderBehindStars = true,  -- Renderizar en la capa más profunda
        fadeWithZoom = false,  -- DESHABILITADO: No aplicar fade a nebulosas durante zoom
        minZoomVisibility = 0.1,
        maxZoomVisibility = 3.0
    },
    
    -- Configuración de performance
    performance = {
        adaptiveQuality = true,
        targetFrameTime = 0.016,  -- 60 FPS
        currentQuality = "medium",
        qualityLevels = {
            low = {
                intensity = 0.3,
                detailLevel = 0.6,
                updateFrequency = 0.1
            },
            medium = {
                intensity = 0.5,
                detailLevel = 0.8,
                updateFrequency = 0.05
            },
            high = {
                intensity = 0.7,
                detailLevel = 1.0,
                updateFrequency = 0.02
            }
        }
    },
    
    -- Configuración visual
    visual = {
        baseIntensity = 0.6,
        detailLevel = 1.0,
        movementSpeed = 0.1,
        colorVariation = 0.3,
        
        -- Paletas de colores predefinidas
        colorPalettes = {
            default = {
                base = {0.05, 0.08, 0.15},
                dust = {0.12, 0.15, 0.25},
                gas = {0.08, 0.12, 0.20},
                nebula = {0.15, 0.10, 0.25}
            },
            warm = {
                base = {0.08, 0.06, 0.12},
                dust = {0.18, 0.12, 0.20},
                gas = {0.15, 0.10, 0.15},
                nebula = {0.20, 0.08, 0.18}
            },
            cold = {
                base = {0.03, 0.06, 0.18},
                dust = {0.08, 0.12, 0.28},
                gas = {0.05, 0.10, 0.25},
                nebula = {0.10, 0.08, 0.30}
            },
            alien = {
                base = {0.06, 0.12, 0.08},
                dust = {0.12, 0.25, 0.15},
                gas = {0.08, 0.20, 0.12},
                nebula = {0.15, 0.25, 0.10}
            }
        },
        
        -- Paleta activa (se puede cambiar dinámicamente)
        activePalette = "default"
    },
    
    -- Configuración de variaciones por semilla
    seedVariation = {
        enabled = true,
        intensityRange = {0.4, 0.8},
        detailRange = {0.8, 1.2},
        speedRange = {0.05, 0.15},
        colorVariationRange = {0.1, 0.5}
    }
}

return MapConfig