--[[
    Physics Configuration - Configuración del Sistema de Física Box2D
    
    Este archivo contiene todas las constantes, configuraciones y parámetros
    del sistema de física. Centraliza la configuración para facilitar
    el ajuste y mantenimiento del sistema.
--]]

local PhysicsConfig = {}

-- ============================================================================
-- CONFIGURACIÓN GENERAL DEL MUNDO
-- ============================================================================

-- Gravedad por defecto (en metros/segundo²)
PhysicsConfig.DEFAULT_GRAVITY_X = 0
PhysicsConfig.DEFAULT_GRAVITY_Y = 0  -- Sin gravedad para juego espacial

-- Escala de conversión píxeles/metros
PhysicsConfig.DEFAULT_METER = 64  -- 64 píxeles = 1 metro

-- Configuración de pasos de simulación
PhysicsConfig.TIME_STEP = 1/60  -- 60 FPS
PhysicsConfig.VELOCITY_ITERATIONS = 8
PhysicsConfig.POSITION_ITERATIONS = 3

-- ============================================================================
-- CONFIGURACIÓN DE PROYECTILES
-- ============================================================================

-- Propiedades físicas por defecto de proyectiles
PhysicsConfig.PROJECTILE_DEFAULTS = {
    density = 1.0,
    friction = 0.1,
    restitution = 0.2,  -- Rebote
    bullet = true,      -- Detección continua de colisiones
    sensor = false
}

-- Velocidades típicas de proyectiles (en metros/segundo)
PhysicsConfig.PROJECTILE_SPEEDS = {
    SLOW = 10,      -- Proyectiles lentos
    NORMAL = 25,    -- Velocidad estándar
    FAST = 50,      -- Proyectiles rápidos
    ULTRA_FAST = 100 -- Proyectiles muy rápidos
}

-- Configuración de vida útil de proyectiles
PhysicsConfig.PROJECTILE_LIFETIME = {
    DEFAULT = 5.0,  -- 5 segundos por defecto
    SHORT = 2.0,    -- Proyectiles de corto alcance
    LONG = 10.0     -- Proyectiles de largo alcance
}

-- ============================================================================
-- CONFIGURACIÓN DE COLISIONES
-- ============================================================================

-- Categorías de colisión (usando bits)
PhysicsConfig.COLLISION_CATEGORIES = {
    PLAYER = 1,         -- 0001
    ENEMY = 2,          -- 0010
    PROJECTILE = 4,     -- 0100
    ENVIRONMENT = 8,    -- 1000
    PICKUP = 16,        -- 10000
    SENSOR = 32         -- 100000
}

-- Máscaras de colisión (qué puede colisionar con qué)
PhysicsConfig.COLLISION_MASKS = {
    PLAYER = PhysicsConfig.COLLISION_CATEGORIES.ENEMY + 
             PhysicsConfig.COLLISION_CATEGORIES.ENVIRONMENT + 
             PhysicsConfig.COLLISION_CATEGORIES.PICKUP,
             
    ENEMY = PhysicsConfig.COLLISION_CATEGORIES.PLAYER + 
            PhysicsConfig.COLLISION_CATEGORIES.ENVIRONMENT,
            
    PROJECTILE = PhysicsConfig.COLLISION_CATEGORIES.PLAYER + 
                 PhysicsConfig.COLLISION_CATEGORIES.ENEMY + 
                 PhysicsConfig.COLLISION_CATEGORIES.ENVIRONMENT,
                 
    ENVIRONMENT = PhysicsConfig.COLLISION_CATEGORIES.PLAYER + 
                  PhysicsConfig.COLLISION_CATEGORIES.ENEMY + 
                  PhysicsConfig.COLLISION_CATEGORIES.PROJECTILE,
                  
    PICKUP = PhysicsConfig.COLLISION_CATEGORIES.PLAYER,
    
    SENSOR = 0  -- Los sensores no colisionan físicamente
}

-- ============================================================================
-- CONFIGURACIÓN DE TRAYECTORIAS
-- ============================================================================

-- Configuración para cálculo de trayectorias
PhysicsConfig.TRAJECTORY = {
    PREDICTION_STEPS = 50,      -- Número de puntos para predicción
    PREDICTION_TIME_STEP = 0.1, -- Tiempo entre puntos de predicción
    MAX_PREDICTION_TIME = 5.0,  -- Tiempo máximo de predicción
    DRAW_PREDICTION = true      -- Dibujar trayectoria predicha
}

-- Configuración de resistencia del aire
PhysicsConfig.AIR_RESISTANCE = {
    ENABLED = false,    -- Habilitar resistencia del aire
    COEFFICIENT = 0.01, -- Coeficiente de resistencia
    DENSITY = 1.225     -- Densidad del aire (kg/m³)
}

-- ============================================================================
-- CONFIGURACIÓN DE EFECTOS
-- ============================================================================

-- Configuración de efectos de partículas
PhysicsConfig.PARTICLE_EFFECTS = {
    EXPLOSION_PARTICLES = 20,
    TRAIL_PARTICLES = 10,
    SPARK_PARTICLES = 15,
    PARTICLE_LIFETIME = 2.0
}

-- Configuración de efectos visuales
PhysicsConfig.VISUAL_EFFECTS = {
    MUZZLE_FLASH_DURATION = 0.1,
    IMPACT_FLASH_DURATION = 0.2,
    SCREEN_SHAKE_INTENSITY = 5.0,
    SCREEN_SHAKE_DURATION = 0.3
}

-- ============================================================================
-- CONFIGURACIÓN DE DEBUG
-- ============================================================================

-- Configuración de debug y visualización
PhysicsConfig.DEBUG_DRAW_ENABLED = false
PhysicsConfig.DEBUG_COLORS = {
    STATIC_BODY = {0.5, 0.5, 0.5, 0.8},     -- Gris
    DYNAMIC_BODY = {1.0, 0.0, 0.0, 0.8},    -- Rojo
    KINEMATIC_BODY = {0.0, 1.0, 0.0, 0.8},  -- Verde
    SENSOR = {0.0, 0.0, 1.0, 0.5},          -- Azul transparente
    JOINT = {1.0, 1.0, 0.0, 1.0}            -- Amarillo
}

-- Configuración de información de debug
PhysicsConfig.DEBUG_INFO = {
    SHOW_VELOCITY = false,
    SHOW_FORCES = false,
    SHOW_CONTACTS = false,
    SHOW_AABB = false,
    SHOW_CENTER_OF_MASS = false
}

-- ============================================================================
-- CONFIGURACIÓN DE RENDIMIENTO
-- ============================================================================

-- Límites de rendimiento
PhysicsConfig.PERFORMANCE = {
    MAX_PROJECTILES = 100,      -- Máximo número de proyectiles simultáneos
    MAX_PARTICLES = 500,        -- Máximo número de partículas
    CLEANUP_INTERVAL = 1.0,     -- Intervalo de limpieza (segundos)
    SLEEP_THRESHOLD = 0.1       -- Umbral para dormir cuerpos inactivos
}

-- Configuración de optimización
PhysicsConfig.OPTIMIZATION = {
    USE_SPATIAL_HASH = true,    -- Usar hash espacial para colisiones
    BROAD_PHASE_ALGORITHM = "dynamic_tree", -- Algoritmo de fase amplia
    CONTINUOUS_PHYSICS = true,  -- Física continua para proyectiles rápidos
    WARM_STARTING = true        -- Precalentamiento de solver
}

-- ============================================================================
-- FUNCIONES DE UTILIDAD
-- ============================================================================

--[[
    Valida la configuración proporcionada
    @param config: tabla de configuración a validar
    @return: true si es válida, false en caso contrario
--]]
function PhysicsConfig.validateConfig(config)
    -- TODO: Implementar validación completa de configuración
    if not config then
        return false
    end
    
    -- Validar valores críticos
    if config.meter and config.meter <= 0 then
        print("[PhysicsConfig] Error: meter debe ser mayor que 0")
        return false
    end
    
    return true
end

--[[
    Combina configuración por defecto con configuración personalizada
    @param custom_config: configuración personalizada
    @return: configuración combinada
--]]
function PhysicsConfig.mergeConfig(custom_config)
    -- TODO: Implementar fusión inteligente de configuraciones
    local merged = {}
    
    -- Copiar valores por defecto
    for key, value in pairs(PhysicsConfig) do
        if type(value) ~= "function" then
            merged[key] = value
        end
    end
    
    -- Sobrescribir con configuración personalizada
    if custom_config then
        for key, value in pairs(custom_config) do
            merged[key] = value
        end
    end
    
    return merged
end

--[[
    Obtiene configuración específica para un tipo de proyectil
    @param projectile_type: tipo de proyectil
    @return: configuración específica
--]]
function PhysicsConfig.getProjectileConfig(projectile_type)
    -- TODO: Implementar configuraciones específicas por tipo
    local base_config = PhysicsConfig.PROJECTILE_DEFAULTS
    
    -- Aplicar modificaciones según el tipo
    if projectile_type == "laser" then
        -- Configuración para láser
    elseif projectile_type == "missile" then
        -- Configuración para misil
    elseif projectile_type == "plasma" then
        -- Configuración para plasma
    end
    
    return base_config
end

return PhysicsConfig