--[[
    Projectile - Clase Base para Proyectiles
    
    Esta clase define la estructura base para todos los proyectiles del juego.
    Maneja la física básica, ciclo de vida, y comportamientos comunes.
    
    Características:
    - Integración con Box2D para física realista
    - Sistema de vida útil y destrucción automática
    - Efectos visuales y de partículas
    - Detección y manejo de colisiones
    - Cálculo de trayectorias
--]]

local Projectile = {}
Projectile.__index = Projectile

-- Dependencias
local PhysicsConfig = require('src.physics.config.physics_config')

-- Enumeraciones de estado
local ProjectileState = {
    ACTIVE = "active",
    EXPLODING = "exploding",
    DESTROYED = "destroyed"
}

-- Tipos de proyectiles
local ProjectileType = {
    BASIC = "basic",
    LASER = "laser",
    MISSILE = "missile",
    PLASMA = "plasma",
    TORPEDO = "torpedo"
}

--[[
    Constructor de la clase Projectile
    @param world: mundo Box2D
    @param x, y: posición inicial
    @param angle: ángulo de disparo en radianes
    @param speed: velocidad inicial
    @param config: configuración específica del proyectil
    @return: nueva instancia de Projectile
--]]
function Projectile.new(world, x, y, angle, speed, config)
    local self = setmetatable({}, Projectile)
    
    -- Configuración básica
    self.world = world
    self.type = config.type or ProjectileType.BASIC
    self.state = ProjectileState.ACTIVE
    
    -- Propiedades físicas
    self.x = x
    self.y = y
    self.angle = angle
    self.speed = speed
    self.initial_velocity_x = math.cos(angle) * speed
    self.initial_velocity_y = math.sin(angle) * speed
    
    -- Configuración del proyectil
    self.config = self:mergeConfig(config)
    
    -- Propiedades de vida útil
    self.lifetime = self.config.lifetime or PhysicsConfig.PROJECTILE_LIFETIME.DEFAULT
    self.age = 0
    self.max_distance = self.config.max_distance or math.huge
    self.distance_traveled = 0
    
    -- Propiedades de daño y efectos
    self.damage = self.config.damage or 10
    self.explosion_radius = self.config.explosion_radius or 0
    self.penetration = self.config.penetration or false
    
    -- Referencias de Box2D
    self.body = nil
    self.fixture = nil
    self.shape = nil
    
    -- Efectos visuales
    self.trail_particles = {}
    self.visual_effects = {}
    
    -- Inicializar cuerpo físico
    self:createPhysicsBody()
    
    -- Configurar callbacks
    self:setupCallbacks()
    
    return self
end

--[[
    Combina configuración por defecto con configuración personalizada
    @param custom_config: configuración personalizada
    @return: configuración combinada
--]]
function Projectile:mergeConfig(custom_config)
    -- TODO: Implementar fusión inteligente de configuraciones
    local default_config = PhysicsConfig.getProjectileConfig(custom_config.type)
    local merged = {}
    
    -- Copiar configuración por defecto
    for key, value in pairs(default_config) do
        merged[key] = value
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
    Crea el cuerpo físico Box2D para el proyectil
--]]
function Projectile:createPhysicsBody()
    -- TODO: Implementar creación completa del cuerpo físico
    
    -- Crear cuerpo dinámico
    self.body = love.physics.newBody(self.world, self.x, self.y, "dynamic")
    
    -- Crear forma según el tipo de proyectil
    self.shape = self:createShape()
    
    -- Crear fixture con propiedades físicas
    self.fixture = love.physics.newFixture(self.body, self.shape)
    self:configureFixture()
    
    -- Establecer velocidad inicial
    self.body:setLinearVelocity(self.initial_velocity_x, self.initial_velocity_y)
    
    -- Configurar como proyectil (detección continua de colisiones)
    self.body:setBullet(true)
    
    -- Almacenar referencia al proyectil en el cuerpo
    self.body:setUserData(self)
end

--[[
    Crea la forma geométrica del proyectil según su tipo
    @return: forma Box2D
--]]
function Projectile:createShape()
    -- TODO: Implementar creación de formas específicas por tipo
    local shape_type = self.config.shape_type or "circle"
    
    if shape_type == "circle" then
        local radius = self.config.radius or 2
        return love.physics.newCircleShape(radius)
    elseif shape_type == "rectangle" then
        local width = self.config.width or 4
        local height = self.config.height or 2
        return love.physics.newRectangleShape(width, height)
    elseif shape_type == "polygon" then
        local vertices = self.config.vertices or {-2, -1, 2, -1, 2, 1, -2, 1}
        return love.physics.newPolygonShape(vertices)
    else
        -- Forma por defecto: círculo pequeño
        return love.physics.newCircleShape(2)
    end
end

--[[
    Configura las propiedades físicas del fixture
--]]
function Projectile:configureFixture()
    -- TODO: Implementar configuración completa del fixture
    
    -- Propiedades físicas básicas
    self.fixture:setDensity(self.config.density)
    self.fixture:setFriction(self.config.friction)
    self.fixture:setRestitution(self.config.restitution)
    
    -- Configurar categorías y máscaras de colisión
    self.fixture:setCategory(PhysicsConfig.COLLISION_CATEGORIES.PROJECTILE)
    self.fixture:setMask(PhysicsConfig.COLLISION_MASKS.PROJECTILE)
    
    -- Configurar como sensor si es necesario
    if self.config.sensor then
        self.fixture:setSensor(true)
    end
end

--[[
    Configura los callbacks de colisión y eventos
--]]
function Projectile:setupCallbacks()
    -- TODO: Implementar callbacks específicos del proyectil
    -- Los callbacks se manejarán a través del CollisionHandler
    -- pero aquí se pueden definir comportamientos específicos
end

--[[
    Actualiza el proyectil
    @param dt: tiempo delta
--]]
function Projectile:update(dt)
    if self.state == ProjectileState.DESTROYED then
        return
    end
    
    -- Actualizar edad
    self.age = self.age + dt
    
    -- Actualizar distancia recorrida
    self:updateDistanceTraveled(dt)
    
    -- Verificar condiciones de destrucción
    self:checkDestructionConditions()
    
    -- Actualizar efectos visuales
    self:updateVisualEffects(dt)
    
    -- Aplicar fuerzas especiales según el tipo
    self:applySpecialForces(dt)
end

--[[
    Actualiza la distancia recorrida por el proyectil
    @param dt: tiempo delta
--]]
function Projectile:updateDistanceTraveled(dt)
    -- TODO: Implementar cálculo preciso de distancia
    if self.body then
        local vx, vy = self.body:getLinearVelocity()
        local speed = math.sqrt(vx * vx + vy * vy)
        self.distance_traveled = self.distance_traveled + (speed * dt)
    end
end

--[[
    Verifica las condiciones para destruir el proyectil
--]]
function Projectile:checkDestructionConditions()
    -- TODO: Implementar verificaciones completas de destrucción
    
    -- Verificar tiempo de vida
    if self.age >= self.lifetime then
        self:destroy("lifetime_expired")
        return
    end
    
    -- Verificar distancia máxima
    if self.distance_traveled >= self.max_distance then
        self:destroy("max_distance_reached")
        return
    end
    
    -- Verificar si está fuera de los límites del mundo
    if self:isOutOfBounds() then
        self:destroy("out_of_bounds")
        return
    end
end

--[[
    Verifica si el proyectil está fuera de los límites del mundo
    @return: true si está fuera de límites
--]]
function Projectile:isOutOfBounds()
    -- TODO: Implementar verificación de límites del mundo
    if not self.body then
        return true
    end
    
    local x, y = self.body:getPosition()
    local world_bounds = self.config.world_bounds
    
    if world_bounds then
        return x < world_bounds.min_x or x > world_bounds.max_x or
               y < world_bounds.min_y or y > world_bounds.max_y
    end
    
    return false
end

--[[
    Actualiza los efectos visuales del proyectil
    @param dt: tiempo delta
--]]
function Projectile:updateVisualEffects(dt)
    -- TODO: Implementar actualización de efectos visuales
    
    -- Actualizar partículas de estela
    self:updateTrailParticles(dt)
    
    -- Actualizar otros efectos visuales
    for i = #self.visual_effects, 1, -1 do
        local effect = self.visual_effects[i]
        effect:update(dt)
        
        if effect:isFinished() then
            table.remove(self.visual_effects, i)
        end
    end
end

--[[
    Actualiza las partículas de estela del proyectil
    @param dt: tiempo delta
--]]
function Projectile:updateTrailParticles(dt)
    -- TODO: Implementar sistema de partículas de estela
    -- Crear nuevas partículas en la posición actual
    -- Actualizar partículas existentes
    -- Eliminar partículas expiradas
end

--[[
    Aplica fuerzas especiales según el tipo de proyectil
    @param dt: tiempo delta
--]]
function Projectile:applySpecialForces(dt)
    -- TODO: Implementar fuerzas específicas por tipo
    
    if self.type == ProjectileType.MISSILE then
        -- Aplicar propulsión continua
        self:applyThrust(dt)
    elseif self.type == ProjectileType.PLASMA then
        -- Aplicar efectos de plasma
        self:applyPlasmaEffects(dt)
    end
    
    -- Aplicar resistencia del aire si está habilitada
    if PhysicsConfig.AIR_RESISTANCE.ENABLED then
        self:applyAirResistance(dt)
    end
end

--[[
    Aplica propulsión para misiles
    @param dt: tiempo delta
--]]
function Projectile:applyThrust(dt)
    -- TODO: Implementar propulsión de misiles
    if self.body and self.config.thrust_force then
        local thrust_x = math.cos(self.angle) * self.config.thrust_force
        local thrust_y = math.sin(self.angle) * self.config.thrust_force
        self.body:applyForce(thrust_x, thrust_y)
    end
end

--[[
    Aplica efectos específicos de plasma
    @param dt: tiempo delta
--]]
function Projectile:applyPlasmaEffects(dt)
    -- TODO: Implementar efectos de plasma
    -- Efectos de ionización, campo electromagnético, etc.
end

--[[
    Aplica resistencia del aire al proyectil
    @param dt: tiempo delta
--]]
function Projectile:applyAirResistance(dt)
    -- TODO: Implementar resistencia del aire realista
    if self.body then
        local vx, vy = self.body:getLinearVelocity()
        local speed = math.sqrt(vx * vx + vy * vy)
        
        if speed > 0 then
            local drag_force = PhysicsConfig.AIR_RESISTANCE.COEFFICIENT * speed * speed
            local drag_x = -(vx / speed) * drag_force
            local drag_y = -(vy / speed) * drag_force
            
            self.body:applyForce(drag_x, drag_y)
        end
    end
end

--[[
    Maneja la colisión del proyectil
    @param other: el otro objeto que colisionó
    @param contact: información del contacto
--]]
function Projectile:onCollision(other, contact)
    -- TODO: Implementar manejo completo de colisiones
    
    if self.state == ProjectileState.DESTROYED then
        return
    end
    
    -- Determinar tipo de colisión
    local collision_type = self:determineCollisionType(other)
    
    -- Manejar según el tipo de colisión
    if collision_type == "target" then
        self:handleTargetHit(other, contact)
    elseif collision_type == "environment" then
        self:handleEnvironmentHit(other, contact)
    elseif collision_type == "shield" then
        self:handleShieldHit(other, contact)
    end
end

--[[
    Determina el tipo de colisión basado en el otro objeto
    @param other: el otro objeto
    @return: tipo de colisión
--]]
function Projectile:determineCollisionType(other)
    -- TODO: Implementar lógica de determinación de tipo de colisión
    -- Analizar las categorías de colisión del otro objeto
    return "target" -- Placeholder
end

--[[
    Maneja el impacto contra un objetivo
    @param target: el objetivo impactado
    @param contact: información del contacto
--]]
function Projectile:handleTargetHit(target, contact)
    -- TODO: Implementar manejo de impacto contra objetivo
    
    -- Aplicar daño
    if target.takeDamage then
        target:takeDamage(self.damage, self)
    end
    
    -- Crear efectos de impacto
    self:createImpactEffects(contact)
    
    -- Destruir proyectil si no tiene penetración
    if not self.penetration then
        self:destroy("target_hit")
    end
end

--[[
    Maneja el impacto contra el entorno
    @param environment: el objeto del entorno
    @param contact: información del contacto
--]]
function Projectile:handleEnvironmentHit(environment, contact)
    -- TODO: Implementar manejo de impacto contra entorno
    
    -- Crear efectos de impacto
    self:createImpactEffects(contact)
    
    -- Destruir proyectil
    self:destroy("environment_hit")
end

--[[
    Maneja el impacto contra un escudo
    @param shield: el escudo impactado
    @param contact: información del contacto
--]]
function Projectile:handleShieldHit(shield, contact)
    -- TODO: Implementar manejo de impacto contra escudo
    
    -- Reducir energía del escudo
    if shield.absorbDamage then
        local absorbed = shield:absorbDamage(self.damage)
        
        -- Si el escudo no absorbió todo el daño, continuar
        if absorbed < self.damage then
            self.damage = self.damage - absorbed
            return -- Continuar con el proyectil
        end
    end
    
    -- Crear efectos de escudo
    self:createShieldEffects(contact)
    
    -- Destruir proyectil
    self:destroy("shield_hit")
end

--[[
    Crea efectos visuales de impacto
    @param contact: información del contacto
--]]
function Projectile:createImpactEffects(contact)
    -- TODO: Implementar creación de efectos de impacto
    local x, y = contact:getPositions()
    
    -- Crear partículas de impacto
    -- Crear flash de impacto
    -- Crear ondas de choque si es necesario
end

--[[
    Crea efectos visuales de escudo
    @param contact: información del contacto
--]]
function Projectile:createShieldEffects(contact)
    -- TODO: Implementar efectos específicos de escudo
    local x, y = contact:getPositions()
    
    -- Crear efectos de energía
    -- Crear ondas de escudo
    -- Crear chispas eléctricas
end

--[[
    Destruye el proyectil
    @param reason: razón de la destrucción
--]]
function Projectile:destroy(reason)
    if self.state == ProjectileState.DESTROYED then
        return
    end
    
    self.state = ProjectileState.DESTROYED
    
    -- Crear efectos de destrucción si es necesario
    if self.explosion_radius > 0 then
        self:createExplosion()
    end
    
    -- Limpiar cuerpo físico
    if self.body then
        self.body:destroy()
        self.body = nil
        self.fixture = nil
        self.shape = nil
    end
    
    -- Limpiar efectos visuales
    self:cleanupVisualEffects()
    
    print("[Projectile] Destruido por: " .. (reason or "unknown"))
end

--[[
    Crea una explosión en la posición del proyectil
--]]
function Projectile:createExplosion()
    -- TODO: Implementar sistema de explosiones
    local x, y = self.body:getPosition()
    
    -- Crear efectos de explosión
    -- Aplicar daño en área
    -- Crear ondas de choque
end

--[[
    Limpia todos los efectos visuales
--]]
function Projectile:cleanupVisualEffects()
    -- TODO: Implementar limpieza de efectos
    self.trail_particles = {}
    self.visual_effects = {}
end

--[[
    Renderiza el proyectil
--]]
function Projectile:draw()
    if self.state == ProjectileState.DESTROYED or not self.body then
        return
    end
    
    -- TODO: Implementar renderizado completo
    
    -- Obtener posición y rotación
    local x, y = self.body:getPosition()
    local angle = self.body:getAngle()
    
    -- Dibujar el proyectil según su tipo
    self:drawProjectileBody(x, y, angle)
    
    -- Dibujar efectos visuales
    self:drawVisualEffects()
    
    -- Dibujar debug si está habilitado
    if PhysicsConfig.DEBUG_DRAW_ENABLED then
        self:drawDebug(x, y, angle)
    end
end

--[[
    Dibuja el cuerpo del proyectil
    @param x, y: posición
    @param angle: ángulo de rotación
--]]
function Projectile:drawProjectileBody(x, y, angle)
    -- TODO: Implementar renderizado específico por tipo
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Dibujar según el tipo
    if self.type == ProjectileType.LASER then
        self:drawLaser()
    elseif self.type == ProjectileType.MISSILE then
        self:drawMissile()
    elseif self.type == ProjectileType.PLASMA then
        self:drawPlasma()
    else
        self:drawBasicProjectile()
    end
    
    love.graphics.pop()
end

--[[
    Dibuja un proyectil básico
--]]
function Projectile:drawBasicProjectile()
    -- TODO: Implementar renderizado de proyectil básico
    love.graphics.setColor(1, 1, 0, 1) -- Amarillo
    love.graphics.circle("fill", 0, 0, 2)
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Dibuja un proyectil láser
--]]
function Projectile:drawLaser()
    -- TODO: Implementar renderizado de láser
    love.graphics.setColor(1, 0, 0, 1) -- Rojo
    love.graphics.rectangle("fill", -4, -1, 8, 2)
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Dibuja un misil
--]]
function Projectile:drawMissile()
    -- TODO: Implementar renderizado de misil
    love.graphics.setColor(0.8, 0.8, 0.8, 1) -- Gris
    love.graphics.rectangle("fill", -6, -2, 12, 4)
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Dibuja un proyectil de plasma
--]]
function Projectile:drawPlasma()
    -- TODO: Implementar renderizado de plasma
    love.graphics.setColor(0, 1, 1, 0.8) -- Cian transparente
    love.graphics.circle("fill", 0, 0, 3)
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Dibuja los efectos visuales del proyectil
--]]
function Projectile:drawVisualEffects()
    -- TODO: Implementar renderizado de efectos visuales
    
    -- Dibujar partículas de estela
    self:drawTrailParticles()
    
    -- Dibujar otros efectos
    for _, effect in ipairs(self.visual_effects) do
        effect:draw()
    end
end

--[[
    Dibuja las partículas de estela
--]]
function Projectile:drawTrailParticles()
    -- TODO: Implementar renderizado de estela
    for _, particle in ipairs(self.trail_particles) do
        particle:draw()
    end
end

--[[
    Dibuja información de debug
    @param x, y: posición
    @param angle: ángulo
--]]
function Projectile:drawDebug(x, y, angle)
    -- TODO: Implementar renderizado de debug
    
    -- Dibujar velocidad
    if PhysicsConfig.DEBUG_INFO.SHOW_VELOCITY and self.body then
        local vx, vy = self.body:getLinearVelocity()
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.line(x, y, x + vx * 0.1, y + vy * 0.1)
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Dibujar información de texto
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("Age: %.1f", self.age), x + 10, y - 20)
    love.graphics.print(string.format("Dist: %.1f", self.distance_traveled), x + 10, y - 5)
end

--[[
    Verifica si el proyectil está destruido
    @return: true si está destruido
--]]
function Projectile:isDestroyed()
    return self.state == ProjectileState.DESTROYED
end

--[[
    Obtiene la posición actual del proyectil
    @return: x, y
--]]
function Projectile:getPosition()
    if self.body then
        return self.body:getPosition()
    end
    return self.x, self.y
end

--[[
    Obtiene la velocidad actual del proyectil
    @return: vx, vy
--]]
function Projectile:getVelocity()
    if self.body then
        return self.body:getLinearVelocity()
    end
    return 0, 0
end

-- Exportar enumeraciones para uso externo
Projectile.State = ProjectileState
Projectile.Type = ProjectileType

return Projectile