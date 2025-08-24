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
    maxStarsPerFrame = 6550,
    parallaxStrength = 0.15,
    twinkleEnabled = true,
    enhancedEffects = true,
    -- NUEVO: escala global de tamaño para todas las estrellas
    sizeScaleGlobal = 1.35,
    -- Capas profundas para paralaje: estrellas más pequeñas y movimiento más lento
    deepLayers = {
        { threshold = 0.90,  parallaxScale = 0.25, sizeScale = 0.60 }, -- subido de 0.55
        { threshold = 0.94,  parallaxScale = 0.20, sizeScale = 0.45 }  -- subido de 0.40
    }
}

-- Densidades base balanceadas
MapConfig.density = {
    asteroids = 8,
    nebulae = 4,
    stations = 4,
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
        {1.0, 1.0, 1.0, 0.9},   -- Blanco brillante
        {0.8, 0.8, 1.0, 0.8},   -- Azul claro
        {1.0, 0.9, 0.7, 0.7},   -- Amarillo
        {1.0, 0.7, 0.7, 0.6},   -- Rojizo
        {0.7, 1.0, 0.9, 0.8},   -- Verde azulado
        {0.9, 0.6, 1.0, 0.7},   -- Púrpura
        {0.6, 0.8, 1.0, 0.8}    -- Azul celeste
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
    maxStarsPerFrame = 6550,
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
return MapConfig