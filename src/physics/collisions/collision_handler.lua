--[[
    Collision Handler - Sistema de Manejo de Colisiones
    
    Este módulo centraliza el manejo de todas las colisiones en el sistema de física.
    Coordina las interacciones entre diferentes tipos de objetos y ejecuta
    las respuestas apropiadas para cada tipo de colisión.
    
    Responsabilidades:
    - Procesar callbacks de colisión de Box2D
    - Clasificar tipos de colisiones
    - Ejecutar respuestas específicas por tipo
    - Manejar efectos de colisión
    - Optimizar detección de colisiones
--]]

local CollisionHandler = {}

-- Dependencias
local PhysicsConfig = require('src.physics.config.physics_config')

-- Estado del sistema de colisiones
local world = nil
local collision_listeners = {}
local collision_filters = {}
local collision_stats = {
    total_collisions = 0,
    collisions_per_second = 0,
    last_second_collisions = 0,
    last_stats_update = 0
}

-- Tipos de colisión
local CollisionType = {
    PROJECTILE_TARGET = "projectile_target",
    PROJECTILE_ENVIRONMENT = "projectile_environment",
    PROJECTILE_SHIELD = "projectile_shield",
    PLAYER_ENEMY = "player_enemy",
    PLAYER_PICKUP = "player_pickup",
    EXPLOSION_DAMAGE = "explosion_damage",
    SENSOR_TRIGGER = "sensor_trigger"
}

-- Prioridades de colisión
local CollisionPriority = {
    CRITICAL = 1,   -- Colisiones que requieren procesamiento inmediato
    HIGH = 2,       -- Colisiones importantes
    NORMAL = 3,     -- Colisiones estándar
    LOW = 4         -- Colisiones de baja prioridad
}

--[[
    Inicializa el sistema de manejo de colisiones
    @param physics_world: mundo Box2D
--]]
function CollisionHandler.initialize(physics_world)
    world = physics_world
    
    -- Inicializar estructuras de datos
    collision_listeners = {}
    collision_filters = {}
    
    -- Configurar filtros por defecto
    CollisionHandler.setupDefaultFilters()
    
    -- Inicializar estadísticas
    collision_stats = {
        total_collisions = 0,
        collisions_per_second = 0,
        last_second_collisions = 0,
        last_stats_update = love.timer.getTime()
    }
    
    print("[CollisionHandler] Sistema de colisiones inicializado")
end

--[[
    Configura los filtros de colisión por defecto
--]]
function CollisionHandler.setupDefaultFilters()
    -- TODO: Implementar filtros de colisión específicos
    
    -- Filtro para proyectiles vs objetivos
    CollisionHandler.addCollisionFilter(
        PhysicsConfig.COLLISION_CATEGORIES.PROJECTILE,
        PhysicsConfig.COLLISION_CATEGORIES.PLAYER,
        function(fixtureA, fixtureB)
            return CollisionHandler.filterProjectileTarget(fixtureA, fixtureB)
        end
    )
    
    -- Filtro para sensores
    CollisionHandler.addCollisionFilter(
        PhysicsConfig.COLLISION_CATEGORIES.SENSOR,
        nil, -- Cualquier categoría
        function(fixtureA, fixtureB)
            return CollisionHandler.filterSensorCollision(fixtureA, fixtureB)
        end
    )
end

--[[
    Añade un filtro de colisión personalizado
    @param categoryA: categoría del primer objeto
    @param categoryB: categoría del segundo objeto (nil para cualquiera)
    @param filter_function: función de filtrado
--]]
function CollisionHandler.addCollisionFilter(categoryA, categoryB, filter_function)
    -- TODO: Implementar sistema de filtros personalizado
    local filter_key = categoryA .. "_" .. (categoryB or "any")
    collision_filters[filter_key] = filter_function
end

--[[
    Filtra colisiones entre proyectiles y objetivos
    @param fixtureA, fixtureB: fixtures involucrados
    @return: true si la colisión debe procesarse
--]]
function CollisionHandler.filterProjectileTarget(fixtureA, fixtureB)
    -- TODO: Implementar lógica de filtrado específica
    
    -- Obtener objetos de usuario
    local objectA = fixtureA:getBody():getUserData()
    local objectB = fixtureB:getBody():getUserData()
    
    -- Verificar que los objetos existan
    if not objectA or not objectB then
        return false
    end
    
    -- Evitar que los proyectiles colisionen con su creador
    if objectA.owner and objectA.owner == objectB then
        return false
    end
    
    if objectB.owner and objectB.owner == objectA then
        return false
    end
    
    return true
end

--[[
    Filtra colisiones de sensores
    @param fixtureA, fixtureB: fixtures involucrados
    @return: true si la colisión debe procesarse
--]]
function CollisionHandler.filterSensorCollision(fixtureA, fixtureB)
    -- TODO: Implementar filtrado de sensores
    
    -- Los sensores siempre procesan colisiones pero no generan respuesta física
    return true
end

--[[
    Registra un listener para un tipo específico de colisión
    @param collision_type: tipo de colisión
    @param listener_function: función a ejecutar
    @param priority: prioridad del listener
--]]
function CollisionHandler.addCollisionListener(collision_type, listener_function, priority)
    priority = priority or CollisionPriority.NORMAL
    
    if not collision_listeners[collision_type] then
        collision_listeners[collision_type] = {}
    end
    
    table.insert(collision_listeners[collision_type], {
        func = listener_function,
        priority = priority
    })
    
    -- Ordenar por prioridad
    table.sort(collision_listeners[collision_type], function(a, b)
        return a.priority < b.priority
    end)
end

--[[
    Callback de inicio de contacto (Box2D beginContact)
    @param fixtureA, fixtureB: fixtures que colisionan
    @param contact: información del contacto
--]]
function CollisionHandler.handleBeginContact(fixtureA, fixtureB, contact)
    -- TODO: Implementar manejo completo de inicio de contacto
    
    -- Actualizar estadísticas
    collision_stats.total_collisions = collision_stats.total_collisions + 1
    collision_stats.last_second_collisions = collision_stats.last_second_collisions + 1
    
    -- Aplicar filtros de colisión
    if not CollisionHandler.shouldProcessCollision(fixtureA, fixtureB) then
        contact:setEnabled(false)
        return
    end
    
    -- Determinar tipo de colisión
    local collision_type = CollisionHandler.determineCollisionType(fixtureA, fixtureB)
    
    -- Obtener objetos involucrados
    local objectA = fixtureA:getBody():getUserData()
    local objectB = fixtureB:getBody():getUserData()
    
    -- Crear datos de colisión
    local collision_data = {
        type = collision_type,
        fixtureA = fixtureA,
        fixtureB = fixtureB,
        objectA = objectA,
        objectB = objectB,
        contact = contact,
        phase = "begin"
    }
    
    -- Procesar colisión
    CollisionHandler.processCollision(collision_data)
end

--[[
    Callback de fin de contacto (Box2D endContact)
    @param fixtureA, fixtureB: fixtures que terminan de colisionar
    @param contact: información del contacto
--]]
function CollisionHandler.handleEndContact(fixtureA, fixtureB, contact)
    -- TODO: Implementar manejo de fin de contacto
    
    -- Determinar tipo de colisión
    local collision_type = CollisionHandler.determineCollisionType(fixtureA, fixtureB)
    
    -- Obtener objetos involucrados
    local objectA = fixtureA:getBody():getUserData()
    local objectB = fixtureB:getBody():getUserData()
    
    -- Crear datos de colisión
    local collision_data = {
        type = collision_type,
        fixtureA = fixtureA,
        fixtureB = fixtureB,
        objectA = objectA,
        objectB = objectB,
        contact = contact,
        phase = "end"
    }
    
    -- Procesar fin de colisión
    CollisionHandler.processCollisionEnd(collision_data)
end

--[[
    Callback de pre-resolución (Box2D preSolve)
    @param fixtureA, fixtureB: fixtures involucrados
    @param contact: información del contacto
--]]
function CollisionHandler.handlePreSolve(fixtureA, fixtureB, contact)
    -- TODO: Implementar pre-resolución de colisiones
    
    -- Aquí se pueden modificar las propiedades del contacto antes de la resolución
    -- Por ejemplo, cambiar fricción, restitución, o deshabilitar el contacto
    
    local objectA = fixtureA:getBody():getUserData()
    local objectB = fixtureB:getBody():getUserData()
    
    -- Aplicar modificaciones específicas según los objetos
    if objectA and objectA.modifyContact then
        objectA:modifyContact(contact, fixtureB)
    end
    
    if objectB and objectB.modifyContact then
        objectB:modifyContact(contact, fixtureA)
    end
end

--[[
    Callback de post-resolución (Box2D postSolve)
    @param fixtureA, fixtureB: fixtures involucrados
    @param contact: información del contacto
    @param normalImpulse, tangentImpulse: impulsos aplicados
--]]
function CollisionHandler.handlePostSolve(fixtureA, fixtureB, contact, normalImpulse, tangentImpulse)
    -- TODO: Implementar post-resolución de colisiones
    
    -- Aquí se pueden procesar los resultados de la colisión
    -- Por ejemplo, crear efectos basados en la fuerza del impacto
    
    local impact_force = math.abs(normalImpulse)
    
    -- Crear efectos si el impacto es suficientemente fuerte
    if impact_force > PhysicsConfig.PERFORMANCE.SLEEP_THRESHOLD then
        CollisionHandler.createImpactEffects(fixtureA, fixtureB, contact, impact_force)
    end
end

--[[
    Determina si una colisión debe ser procesada
    @param fixtureA, fixtureB: fixtures involucrados
    @return: true si debe procesarse
--]]
function CollisionHandler.shouldProcessCollision(fixtureA, fixtureB)
    -- TODO: Implementar lógica de filtrado completa
    
    -- Verificar filtros personalizados
    local categoryA = fixtureA:getCategory()
    local categoryB = fixtureB:getCategory()
    
    -- Buscar filtro específico
    local filter_key = categoryA .. "_" .. categoryB
    local filter = collision_filters[filter_key]
    
    if filter then
        return filter(fixtureA, fixtureB)
    end
    
    -- Buscar filtro genérico
    filter_key = categoryA .. "_any"
    filter = collision_filters[filter_key]
    
    if filter then
        return filter(fixtureA, fixtureB)
    end
    
    -- Por defecto, procesar la colisión
    return true
end

--[[
    Determina el tipo de colisión basado en los fixtures
    @param fixtureA, fixtureB: fixtures involucrados
    @return: tipo de colisión
--]]
function CollisionHandler.determineCollisionType(fixtureA, fixtureB)
    -- TODO: Implementar determinación completa de tipos
    
    local categoryA = fixtureA:getCategory()
    local categoryB = fixtureB:getCategory()
    
    -- Determinar tipo basado en categorías
    if (categoryA == PhysicsConfig.COLLISION_CATEGORIES.PROJECTILE and 
        categoryB == PhysicsConfig.COLLISION_CATEGORIES.PLAYER) or
       (categoryA == PhysicsConfig.COLLISION_CATEGORIES.PLAYER and 
        categoryB == PhysicsConfig.COLLISION_CATEGORIES.PROJECTILE) then
        return CollisionType.PROJECTILE_TARGET
    end
    
    if (categoryA == PhysicsConfig.COLLISION_CATEGORIES.PROJECTILE and 
        categoryB == PhysicsConfig.COLLISION_CATEGORIES.ENVIRONMENT) or
       (categoryA == PhysicsConfig.COLLISION_CATEGORIES.ENVIRONMENT and 
        categoryB == PhysicsConfig.COLLISION_CATEGORIES.PROJECTILE) then
        return CollisionType.PROJECTILE_ENVIRONMENT
    end
    
    if categoryA == PhysicsConfig.COLLISION_CATEGORIES.SENSOR or 
       categoryB == PhysicsConfig.COLLISION_CATEGORIES.SENSOR then
        return CollisionType.SENSOR_TRIGGER
    end
    
    -- Tipo por defecto
    return "unknown"
end

--[[
    Procesa una colisión según su tipo
    @param collision_data: datos de la colisión
--]]
function CollisionHandler.processCollision(collision_data)
    -- TODO: Implementar procesamiento completo de colisiones
    
    local collision_type = collision_data.type
    
    -- Ejecutar listeners específicos
    if collision_listeners[collision_type] then
        for _, listener in ipairs(collision_listeners[collision_type]) do
            listener.func(collision_data)
        end
    end
    
    -- Procesamiento específico por tipo
    if collision_type == CollisionType.PROJECTILE_TARGET then
        CollisionHandler.handleProjectileTargetCollision(collision_data)
    elseif collision_type == CollisionType.PROJECTILE_ENVIRONMENT then
        CollisionHandler.handleProjectileEnvironmentCollision(collision_data)
    elseif collision_type == CollisionType.SENSOR_TRIGGER then
        CollisionHandler.handleSensorTrigger(collision_data)
    end
end

--[[
    Procesa el fin de una colisión
    @param collision_data: datos de la colisión
--]]
function CollisionHandler.processCollisionEnd(collision_data)
    -- TODO: Implementar procesamiento de fin de colisión
    
    local collision_type = collision_data.type
    
    -- Procesamiento específico para fin de colisión
    if collision_type == CollisionType.SENSOR_TRIGGER then
        CollisionHandler.handleSensorTriggerEnd(collision_data)
    end
end

--[[
    Maneja colisión entre proyectil y objetivo
    @param collision_data: datos de la colisión
--]]
function CollisionHandler.handleProjectileTargetCollision(collision_data)
    -- TODO: Implementar manejo específico proyectil-objetivo
    
    local projectile = nil
    local target = nil
    
    -- Identificar cuál es el proyectil y cuál el objetivo
    if collision_data.objectA and collision_data.objectA.type == "projectile" then
        projectile = collision_data.objectA
        target = collision_data.objectB
    elseif collision_data.objectB and collision_data.objectB.type == "projectile" then
        projectile = collision_data.objectB
        target = collision_data.objectA
    end
    
    if projectile and target then
        -- Delegar al proyectil el manejo de la colisión
        if projectile.onCollision then
            projectile:onCollision(target, collision_data.contact)
        end
        
        -- Notificar al objetivo si tiene método de daño
        if target.takeDamage and projectile.damage then
            target:takeDamage(projectile.damage, projectile)
        end
    end
end

--[[
    Maneja colisión entre proyectil y entorno
    @param collision_data: datos de la colisión
--]]
function CollisionHandler.handleProjectileEnvironmentCollision(collision_data)
    -- TODO: Implementar manejo específico proyectil-entorno
    
    local projectile = nil
    local environment = nil
    
    -- Identificar proyectil y entorno
    if collision_data.objectA and collision_data.objectA.type == "projectile" then
        projectile = collision_data.objectA
        environment = collision_data.objectB
    elseif collision_data.objectB and collision_data.objectB.type == "projectile" then
        projectile = collision_data.objectB
        environment = collision_data.objectA
    end
    
    if projectile then
        -- Delegar al proyectil
        if projectile.onCollision then
            projectile:onCollision(environment, collision_data.contact)
        end
    end
end

--[[
    Maneja activación de sensor
    @param collision_data: datos de la colisión
--]]
function CollisionHandler.handleSensorTrigger(collision_data)
    -- TODO: Implementar manejo de sensores
    
    local sensor = nil
    local trigger_object = nil
    
    -- Identificar sensor y objeto activador
    if collision_data.fixtureA:isSensor() then
        sensor = collision_data.objectA
        trigger_object = collision_data.objectB
    elseif collision_data.fixtureB:isSensor() then
        sensor = collision_data.objectB
        trigger_object = collision_data.objectA
    end
    
    if sensor and sensor.onTriggerEnter then
        sensor:onTriggerEnter(trigger_object)
    end
end

--[[
    Maneja desactivación de sensor
    @param collision_data: datos de la colisión
--]]
function CollisionHandler.handleSensorTriggerEnd(collision_data)
    -- TODO: Implementar manejo de fin de sensor
    
    local sensor = nil
    local trigger_object = nil
    
    -- Identificar sensor y objeto
    if collision_data.fixtureA:isSensor() then
        sensor = collision_data.objectA
        trigger_object = collision_data.objectB
    elseif collision_data.fixtureB:isSensor() then
        sensor = collision_data.objectB
        trigger_object = collision_data.objectA
    end
    
    if sensor and sensor.onTriggerExit then
        sensor:onTriggerExit(trigger_object)
    end
end

--[[
    Crea efectos de impacto basados en la fuerza
    @param fixtureA, fixtureB: fixtures involucrados
    @param contact: información del contacto
    @param impact_force: fuerza del impacto
--]]
function CollisionHandler.createImpactEffects(fixtureA, fixtureB, contact, impact_force)
    -- TODO: Implementar creación de efectos de impacto
    
    local x, y = contact:getPositions()
    
    -- Crear efectos proporcionales a la fuerza del impacto
    if impact_force > 50 then
        -- Crear partículas de impacto fuerte
        -- Crear ondas de choque
        -- Aplicar screen shake
    elseif impact_force > 20 then
        -- Crear partículas de impacto medio
        -- Crear chispas
    else
        -- Crear partículas menores
    end
end

--[[
    Actualiza el sistema de colisiones
    @param dt: tiempo delta
--]]
function CollisionHandler.update(dt)
    -- TODO: Implementar actualización del sistema
    
    -- Actualizar estadísticas
    CollisionHandler.updateStatistics(dt)
    
    -- Limpiar colisiones antiguas si es necesario
    CollisionHandler.cleanupOldCollisions(dt)
end

--[[
    Actualiza las estadísticas de colisiones
    @param dt: tiempo delta
--]]
function CollisionHandler.updateStatistics(dt)
    local current_time = love.timer.getTime()
    
    if current_time - collision_stats.last_stats_update >= 1.0 then
        collision_stats.collisions_per_second = collision_stats.last_second_collisions
        collision_stats.last_second_collisions = 0
        collision_stats.last_stats_update = current_time
    end
end

--[[
    Limpia colisiones antiguas para optimizar rendimiento
    @param dt: tiempo delta
--]]
function CollisionHandler.cleanupOldCollisions(dt)
    -- TODO: Implementar limpieza de colisiones antiguas
    -- Remover listeners inactivos
    -- Limpiar datos de colisión expirados
end

--[[
    Obtiene estadísticas del sistema de colisiones
    @return: tabla con estadísticas
--]]
function CollisionHandler.getStatistics()
    return {
        total_collisions = collision_stats.total_collisions,
        collisions_per_second = collision_stats.collisions_per_second,
        active_listeners = CollisionHandler.countActiveListeners()
    }
end

--[[
    Cuenta el número de listeners activos
    @return: número de listeners
--]]
function CollisionHandler.countActiveListeners()
    local count = 0
    for collision_type, listeners in pairs(collision_listeners) do
        count = count + #listeners
    end
    return count
end

--[[
    Limpia el sistema de colisiones
--]]
function CollisionHandler.cleanup()
    -- TODO: Implementar limpieza completa
    
    collision_listeners = {}
    collision_filters = {}
    collision_stats = {
        total_collisions = 0,
        collisions_per_second = 0,
        last_second_collisions = 0,
        last_stats_update = 0
    }
    
    world = nil
    
    print("[CollisionHandler] Sistema de colisiones limpiado")
end

--[[
    Renderiza información de debug de colisiones
--]]
function CollisionHandler.drawDebug()
    if not PhysicsConfig.DEBUG_DRAW_ENABLED then
        return
    end
    
    -- TODO: Implementar renderizado de debug
    
    -- Mostrar estadísticas
    local stats = CollisionHandler.getStatistics()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Colisiones/seg: " .. stats.collisions_per_second, 10, 10)
    love.graphics.print("Total colisiones: " .. stats.total_collisions, 10, 25)
    love.graphics.print("Listeners activos: " .. stats.active_listeners, 10, 40)
end

-- Exportar tipos para uso externo
CollisionHandler.Type = CollisionType
CollisionHandler.Priority = CollisionPriority

return CollisionHandler