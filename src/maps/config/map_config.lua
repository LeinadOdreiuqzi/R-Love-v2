-- src/maps/config/map_config.lua
-- Configuración centralizada del sistema de mapas

local MapConfig = {}

-- Configuración básica del mapa
MapConfig.chunk = {
    size = 48,
    tileSize = 32,
    worldScale = 0.8,
    viewDistance = 3
}

-- Configuración de estrellas
MapConfig.stars = {
    maxStarsPerFrame = 6550,
    parallaxStrength = 0.15,
    twinkleEnabled = true,
    enhancedEffects = true
}

-- Densidades base balanceadas
MapConfig.density = {
    asteroids = 8,
    nebulae = 4,
    stations = 4,
    wormholes = 3,
    stars = 0.35
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

-- Configuración de renderizado
MapConfig.rendering = {
    maxStarsPerFrame = 6550,
    enhancedEffects = true,
    lodEnabled = true,
    cullingEnabled = true
}

return MapConfig