--[[
    Trajectory Calculator - Calculadora de Trayectorias
    
    Este módulo proporciona funciones para calcular y predecir trayectorias
    de proyectiles en el sistema de física. Incluye cálculos para diferentes
    tipos de proyectiles, efectos ambientales y predicción de rutas.
    
    Responsabilidades:
    - Calcular trayectorias balísticas
    - Predecir puntos de impacto
    - Simular efectos ambientales
    - Optimizar cálculos de trayectoria
    - Proporcionar datos para renderizado de predicción
--]]

local TrajectoryCalculator = {}

-- Dependencias
local PhysicsConfig = require('src.physics.config.physics_config')

-- Constantes matemáticas
local GRAVITY_CONSTANT = 9.81 -- m/s² (ajustable según el juego)
local AIR_DENSITY = 1.225 -- kg/m³ (densidad del aire a nivel del mar)
local PREDICTION_STEP = 0.016 -- Paso de predicción en segundos (60 FPS)

-- Cache para optimización
local trajectory_cache = {}
local cache_max_size = 100
local cache_cleanup_timer = 0
local cache_cleanup_interval = 5.0

-- Tipos de trayectoria
local TrajectoryType = {
    BALLISTIC = "ballistic",           -- Trayectoria balística simple
    GUIDED = "guided",                 -- Proyectil guiado
    STRAIGHT = "straight",             -- Línea recta (láser, rayos)
    PARABOLIC = "parabolic",           -- Parábola con gravedad
    CURVED = "curved",                 -- Curva personalizada
    HOMING = "homing"                  -- Proyectil que busca objetivo
}

-- Factores ambientales
local EnvironmentalFactors = {
    wind_x = 0,
    wind_y = 0,
    air_resistance = 0.1,
    gravity_modifier = 1.0,
    magnetic_fields = {}
}

--[[
    Inicializa el calculador de trayectorias
--]]
function TrajectoryCalculator.initialize()
    -- Inicializar cache
    trajectory_cache = {}
    cache_cleanup_timer = 0
    
    -- Configurar factores ambientales por defecto
    EnvironmentalFactors = {
        wind_x = 0,
        wind_y = 0,
        air_resistance = PhysicsConfig.AIR_RESISTANCE.DEFAULT_COEFFICIENT,
        gravity_modifier = 1.0,
        magnetic_fields = {}
    }
    
    print("[TrajectoryCalculator] Calculadora de trayectorias inicializada")
end

--[[
    Calcula una trayectoria balística simple
    @param start_x, start_y: posición inicial
    @param velocity_x, velocity_y: velocidad inicial
    @param gravity: fuerza de gravedad (opcional)
    @param max_time: tiempo máximo de simulación
    @return: tabla con puntos de la trayectoria
--]]
function TrajectoryCalculator.calculateBallisticTrajectory(start_x, start_y, velocity_x, velocity_y, gravity, max_time)
    gravity = gravity or (GRAVITY_CONSTANT * EnvironmentalFactors.gravity_modifier)
    max_time = max_time or PhysicsConfig.TRAJECTORY_PREDICTION.MAX_TIME
    
    -- TODO: Implementar cálculo balístico completo
    
    local trajectory_points = {}
    local time = 0
    local step = PhysicsConfig.TRAJECTORY_PREDICTION.STEP_SIZE
    
    while time <= max_time do
        -- Calcular posición en el tiempo t
        local x = start_x + velocity_x * time
        local y = start_y + velocity_y * time + 0.5 * gravity * time * time
        
        -- Aplicar resistencia del aire (simplificada)
        local air_factor = 1 - (EnvironmentalFactors.air_resistance * time)
        air_factor = math.max(0.1, air_factor) -- Mínimo 10% de velocidad
        
        x = start_x + (velocity_x * air_factor) * time
        
        -- Aplicar viento
        x = x + EnvironmentalFactors.wind_x * time * time * 0.5
        y = y + EnvironmentalFactors.wind_y * time * time * 0.5
        
        table.insert(trajectory_points, {
            x = x,
            y = y,
            time = time,
            velocity_x = velocity_x * air_factor + EnvironmentalFactors.wind_x * time,
            velocity_y = velocity_y + gravity * time + EnvironmentalFactors.wind_y * time
        })
        
        time = time + step
        
        -- Verificar si el proyectil ha salido de los límites
        if TrajectoryCalculator.isOutOfBounds(x, y) then
            break
        end
    end
    
    return trajectory_points
end

--[[
    Calcula una trayectoria en línea recta
    @param start_x, start_y: posición inicial
    @param end_x, end_y: posición final
    @param speed: velocidad del proyectil
    @return: tabla con puntos de la trayectoria
--]]
function TrajectoryCalculator.calculateStraightTrajectory(start_x, start_y, end_x, end_y, speed)
    speed = speed or PhysicsConfig.PROJECTILE_DEFAULTS.SPEED
    
    -- TODO: Implementar trayectoria recta completa
    
    local trajectory_points = {}
    local distance = math.sqrt((end_x - start_x)^2 + (end_y - start_y)^2)
    local total_time = distance / speed
    
    local direction_x = (end_x - start_x) / distance
    local direction_y = (end_y - start_y) / distance
    
    local time = 0
    local step = PhysicsConfig.TRAJECTORY_PREDICTION.STEP_SIZE
    
    while time <= total_time do
        local progress = time / total_time
        local x = start_x + direction_x * speed * time
        local y = start_y + direction_y * speed * time
        
        table.insert(trajectory_points, {
            x = x,
            y = y,
            time = time,
            velocity_x = direction_x * speed,
            velocity_y = direction_y * speed,
            progress = progress
        })
        
        time = time + step
    end
    
    return trajectory_points
end

--[[
    Calcula una trayectoria guiada hacia un objetivo
    @param start_x, start_y: posición inicial
    @param target_x, target_y: posición del objetivo
    @param speed: velocidad del proyectil
    @param turn_rate: velocidad de giro (radianes por segundo)
    @param max_time: tiempo máximo de simulación
    @return: tabla con puntos de la trayectoria
--]]
function TrajectoryCalculator.calculateGuidedTrajectory(start_x, start_y, target_x, target_y, speed, turn_rate, max_time)
    speed = speed or PhysicsConfig.PROJECTILE_DEFAULTS.SPEED
    turn_rate = turn_rate or math.pi -- 180 grados por segundo
    max_time = max_time or PhysicsConfig.TRAJECTORY_PREDICTION.MAX_TIME
    
    -- TODO: Implementar trayectoria guiada completa
    
    local trajectory_points = {}
    local time = 0
    local step = PhysicsConfig.TRAJECTORY_PREDICTION.STEP_SIZE
    
    local current_x = start_x
    local current_y = start_y
    local current_angle = math.atan2(target_y - start_y, target_x - start_x)
    
    while time <= max_time do
        -- Calcular dirección hacia el objetivo
        local target_angle = math.atan2(target_y - current_y, target_x - current_x)
        
        -- Ajustar ángulo gradualmente
        local angle_diff = target_angle - current_angle
        
        -- Normalizar diferencia de ángulo
        while angle_diff > math.pi do
            angle_diff = angle_diff - 2 * math.pi
        end
        while angle_diff < -math.pi do
            angle_diff = angle_diff + 2 * math.pi
        end
        
        -- Aplicar velocidad de giro
        local max_turn = turn_rate * step
        if math.abs(angle_diff) > max_turn then
            current_angle = current_angle + max_turn * (angle_diff > 0 and 1 or -1)
        else
            current_angle = target_angle
        end
        
        -- Calcular nueva posición
        local velocity_x = math.cos(current_angle) * speed
        local velocity_y = math.sin(current_angle) * speed
        
        current_x = current_x + velocity_x * step
        current_y = current_y + velocity_y * step
        
        table.insert(trajectory_points, {
            x = current_x,
            y = current_y,
            time = time,
            velocity_x = velocity_x,
            velocity_y = velocity_y,
            angle = current_angle
        })
        
        time = time + step
        
        -- Verificar si llegó al objetivo
        local distance_to_target = math.sqrt((target_x - current_x)^2 + (target_y - current_y)^2)
        if distance_to_target < speed * step then
            break
        end
        
        -- Verificar límites
        if TrajectoryCalculator.isOutOfBounds(current_x, current_y) then
            break
        end
    end
    
    return trajectory_points
end

--[[
    Predice el punto de impacto de un proyectil
    @param start_x, start_y: posición inicial
    @param velocity_x, velocity_y: velocidad inicial
    @param trajectory_type: tipo de trayectoria
    @param obstacles: lista de obstáculos (opcional)
    @return: punto de impacto {x, y, time} o nil si no hay impacto
--]]
function TrajectoryCalculator.predictImpactPoint(start_x, start_y, velocity_x, velocity_y, trajectory_type, obstacles)
    trajectory_type = trajectory_type or TrajectoryType.BALLISTIC
    obstacles = obstacles or {}
    
    -- TODO: Implementar predicción de impacto completa
    
    -- Generar clave de cache
    local cache_key = string.format("%.2f_%.2f_%.2f_%.2f_%s", 
        start_x, start_y, velocity_x, velocity_y, trajectory_type)
    
    -- Verificar cache
    if trajectory_cache[cache_key] then
        return trajectory_cache[cache_key]
    end
    
    local trajectory_points
    
    -- Calcular trayectoria según el tipo
    if trajectory_type == TrajectoryType.BALLISTIC then
        trajectory_points = TrajectoryCalculator.calculateBallisticTrajectory(
            start_x, start_y, velocity_x, velocity_y)
    elseif trajectory_type == TrajectoryType.STRAIGHT then
        local end_x = start_x + velocity_x * 10 -- Proyectar 10 segundos
        local end_y = start_y + velocity_y * 10
        trajectory_points = TrajectoryCalculator.calculateStraightTrajectory(
            start_x, start_y, end_x, end_y, math.sqrt(velocity_x^2 + velocity_y^2))
    end
    
    if not trajectory_points or #trajectory_points == 0 then
        return nil
    end
    
    -- Buscar primer punto de impacto
    local impact_point = nil
    
    for i, point in ipairs(trajectory_points) do
        -- Verificar colisión con obstáculos
        for _, obstacle in ipairs(obstacles) do
            if TrajectoryCalculator.checkPointInObstacle(point.x, point.y, obstacle) then
                impact_point = {
                    x = point.x,
                    y = point.y,
                    time = point.time,
                    obstacle = obstacle
                }
                break
            end
        end
        
        if impact_point then
            break
        end
        
        -- Verificar límites del mundo
        if TrajectoryCalculator.isOutOfBounds(point.x, point.y) then
            impact_point = {
                x = point.x,
                y = point.y,
                time = point.time,
                out_of_bounds = true
            }
            break
        end
    end
    
    -- Si no hay impacto, usar el último punto
    if not impact_point and #trajectory_points > 0 then
        local last_point = trajectory_points[#trajectory_points]
        impact_point = {
            x = last_point.x,
            y = last_point.y,
            time = last_point.time,
            max_range = true
        }
    end
    
    -- Guardar en cache
    TrajectoryCalculator.addToCache(cache_key, impact_point)
    
    return impact_point
end

--[[
    Calcula el ángulo y velocidad necesarios para alcanzar un objetivo
    @param start_x, start_y: posición inicial
    @param target_x, target_y: posición objetivo
    @param speed: velocidad del proyectil (opcional)
    @param gravity: gravedad (opcional)
    @return: {angle, speed, time_to_target} o nil si es imposible
--]]
function TrajectoryCalculator.calculateFiringSolution(start_x, start_y, target_x, target_y, speed, gravity)
    gravity = gravity or (GRAVITY_CONSTANT * EnvironmentalFactors.gravity_modifier)
    
    -- TODO: Implementar solución de disparo completa
    
    local dx = target_x - start_x
    local dy = target_y - start_y
    local distance = math.sqrt(dx^2 + dy^2)
    
    -- Si no se especifica velocidad, calcular una apropiada
    if not speed then
        speed = PhysicsConfig.PROJECTILE_DEFAULTS.SPEED
    end
    
    -- Para trayectoria balística, resolver ecuación cuadrática
    local g = math.abs(gravity)
    local v2 = speed * speed
    local discriminant = v2^2 - g * (g * dx^2 + 2 * dy * v2)
    
    if discriminant < 0 then
        -- No hay solución (objetivo fuera de alcance)
        return nil
    end
    
    -- Calcular dos ángulos posibles
    local sqrt_discriminant = math.sqrt(discriminant)
    local angle1 = math.atan((v2 + sqrt_discriminant) / (g * dx))
    local angle2 = math.atan((v2 - sqrt_discriminant) / (g * dx))
    
    -- Ajustar para dirección
    if dx < 0 then
        angle1 = angle1 + math.pi
        angle2 = angle2 + math.pi
    end
    
    -- Calcular tiempo de vuelo para cada ángulo
    local time1 = dx / (speed * math.cos(angle1))
    local time2 = dx / (speed * math.cos(angle2))
    
    -- Retornar la solución de menor ángulo (trayectoria más directa)
    local chosen_angle = math.abs(angle1) < math.abs(angle2) and angle1 or angle2
    local chosen_time = math.abs(angle1) < math.abs(angle2) and time1 or time2
    
    return {
        angle = chosen_angle,
        speed = speed,
        time_to_target = math.abs(chosen_time),
        high_arc = angle1,
        low_arc = angle2
    }
end

--[[
    Verifica si un punto está fuera de los límites del mundo
    @param x, y: coordenadas del punto
    @return: true si está fuera de límites
--]]
function TrajectoryCalculator.isOutOfBounds(x, y)
    -- TODO: Implementar verificación de límites configurable
    
    local bounds = PhysicsConfig.WORLD_BOUNDS or {
        min_x = -1000,
        max_x = 1000,
        min_y = -1000,
        max_y = 1000
    }
    
    return x < bounds.min_x or x > bounds.max_x or 
           y < bounds.min_y or y > bounds.max_y
end

--[[
    Verifica si un punto está dentro de un obstáculo
    @param x, y: coordenadas del punto
    @param obstacle: datos del obstáculo
    @return: true si hay colisión
--]]
function TrajectoryCalculator.checkPointInObstacle(x, y, obstacle)
    -- TODO: Implementar verificación de colisión con diferentes formas
    
    if obstacle.type == "rectangle" then
        return x >= obstacle.x and x <= obstacle.x + obstacle.width and
               y >= obstacle.y and y <= obstacle.y + obstacle.height
    elseif obstacle.type == "circle" then
        local dx = x - obstacle.x
        local dy = y - obstacle.y
        return (dx^2 + dy^2) <= obstacle.radius^2
    end
    
    return false
end

--[[
    Configura factores ambientales
    @param factors: tabla con factores ambientales
--]]
function TrajectoryCalculator.setEnvironmentalFactors(factors)
    if factors.wind_x then
        EnvironmentalFactors.wind_x = factors.wind_x
    end
    if factors.wind_y then
        EnvironmentalFactors.wind_y = factors.wind_y
    end
    if factors.air_resistance then
        EnvironmentalFactors.air_resistance = factors.air_resistance
    end
    if factors.gravity_modifier then
        EnvironmentalFactors.gravity_modifier = factors.gravity_modifier
    end
end

--[[
    Obtiene los factores ambientales actuales
    @return: tabla con factores ambientales
--]]
function TrajectoryCalculator.getEnvironmentalFactors()
    return {
        wind_x = EnvironmentalFactors.wind_x,
        wind_y = EnvironmentalFactors.wind_y,
        air_resistance = EnvironmentalFactors.air_resistance,
        gravity_modifier = EnvironmentalFactors.gravity_modifier
    }
end

--[[
    Añade un campo magnético que afecta las trayectorias
    @param field: datos del campo magnético
--]]
function TrajectoryCalculator.addMagneticField(field)
    -- TODO: Implementar campos magnéticos
    table.insert(EnvironmentalFactors.magnetic_fields, field)
end

--[[
    Remueve todos los campos magnéticos
--]]
function TrajectoryCalculator.clearMagneticFields()
    EnvironmentalFactors.magnetic_fields = {}
end

--[[
    Añade un resultado al cache
    @param key: clave del cache
    @param value: valor a guardar
--]]
function TrajectoryCalculator.addToCache(key, value)
    -- Limpiar cache si está lleno
    if #trajectory_cache >= cache_max_size then
        TrajectoryCalculator.clearOldestCacheEntries()
    end
    
    trajectory_cache[key] = {
        value = value,
        timestamp = love.timer.getTime()
    }
end

--[[
    Limpia las entradas más antiguas del cache
--]]
function TrajectoryCalculator.clearOldestCacheEntries()
    local entries = {}
    
    for key, entry in pairs(trajectory_cache) do
        table.insert(entries, {key = key, timestamp = entry.timestamp})
    end
    
    table.sort(entries, function(a, b) return a.timestamp < b.timestamp end)
    
    -- Remover la mitad más antigua
    local to_remove = math.floor(#entries / 2)
    for i = 1, to_remove do
        trajectory_cache[entries[i].key] = nil
    end
end

--[[
    Actualiza el sistema de trayectorias
    @param dt: tiempo delta
--]]
function TrajectoryCalculator.update(dt)
    -- TODO: Implementar actualización del sistema
    
    -- Limpiar cache periódicamente
    cache_cleanup_timer = cache_cleanup_timer + dt
    if cache_cleanup_timer >= cache_cleanup_interval then
        TrajectoryCalculator.cleanupCache()
        cache_cleanup_timer = 0
    end
end

--[[
    Limpia entradas expiradas del cache
--]]
function TrajectoryCalculator.cleanupCache()
    local current_time = love.timer.getTime()
    local max_age = 30.0 -- 30 segundos
    
    for key, entry in pairs(trajectory_cache) do
        if current_time - entry.timestamp > max_age then
            trajectory_cache[key] = nil
        end
    end
end

--[[
    Obtiene estadísticas del sistema
    @return: tabla con estadísticas
--]]
function TrajectoryCalculator.getStatistics()
    local cache_count = 0
    for _ in pairs(trajectory_cache) do
        cache_count = cache_count + 1
    end
    
    return {
        cache_entries = cache_count,
        cache_max_size = cache_max_size,
        environmental_factors = EnvironmentalFactors
    }
end

--[[
    Renderiza información de debug
--]]
function TrajectoryCalculator.drawDebug()
    if not PhysicsConfig.DEBUG_DRAW_ENABLED then
        return
    end
    
    -- TODO: Implementar renderizado de debug
    
    local stats = TrajectoryCalculator.getStatistics()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Cache trayectorias: " .. stats.cache_entries, 10, 70)
    love.graphics.print("Viento: (" .. stats.environmental_factors.wind_x .. ", " .. 
                       stats.environmental_factors.wind_y .. ")", 10, 85)
end

--[[
    Limpia el sistema de trayectorias
--]]
function TrajectoryCalculator.cleanup()
    trajectory_cache = {}
    EnvironmentalFactors = {
        wind_x = 0,
        wind_y = 0,
        air_resistance = 0.1,
        gravity_modifier = 1.0,
        magnetic_fields = {}
    }
    
    print("[TrajectoryCalculator] Calculadora de trayectorias limpiada")
end

-- Exportar tipos para uso externo
TrajectoryCalculator.Type = TrajectoryType

return TrajectoryCalculator