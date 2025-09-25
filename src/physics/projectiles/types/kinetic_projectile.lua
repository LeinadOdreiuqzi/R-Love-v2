--[[
    KineticProjectile - Proyectil Cinético
    
    Proyectil físico de alta velocidad con efectos metálicos.
    Hereda de la clase base Projectile y añade características cinéticas.
    
    Características:
    - Color metálico plateado/dorado
    - Velocidad muy alta
    - Daño físico penetrante
    - Efectos de estela metálica
    - Capacidad de penetración
--]]

local Projectile = require('src.physics.projectiles.projectile')
local KineticProjectile = {}
KineticProjectile.__index = KineticProjectile
setmetatable(KineticProjectile, {__index = Projectile})

-- Configuración específica del proyectil cinético
local KINETIC_PROJECTILE_CONFIG = {
    type = "kinetic",
    damage = 25,
    speed = 2200, -- Velocidad muy alta
    lifetime = 3.0, -- Menor tiempo por la alta velocidad
    max_distance = 1800,
    size = 0.8, -- Más pequeño y aerodinámico
    color = {0.9, 0.9, 0.7, 1}, -- Dorado metálico
    trail_color = {0.8, 0.8, 0.6, 0.8}, -- Estela dorada
    glow_color = {1, 0.9, 0.5, 0.6}, -- Resplandor dorado
    particle_count = 3, -- Pocas partículas para efecto limpio
    trail_length = 8, -- Estela larga por la velocidad
    penetration = true, -- Puede penetrar objetivos
    armor_piercing = 0.3 -- 30% de penetración de armadura
}

--[[
    Constructor del proyectil cinético
    @param world: mundo Box2D
    @param x, y: posición inicial
    @param angle: ángulo de disparo en radianes
    @param speed: velocidad inicial (opcional)
    @param custom_config: configuración personalizada (opcional)
    @return: nueva instancia de KineticProjectile
--]]
function KineticProjectile.new(world, x, y, angle, speed, custom_config)
    -- Combinar configuración por defecto con personalizada
    local config = {}
    for k, v in pairs(KINETIC_PROJECTILE_CONFIG) do
        config[k] = v
    end
    
    if custom_config then
        for k, v in pairs(custom_config) do
            config[k] = v
        end
    end
    
    -- Usar velocidad por defecto si no se especifica
    local final_speed = speed or config.speed
    
    -- Crear instancia base
    local self = Projectile.new(world, x, y, angle, final_speed, config)
    setmetatable(self, KineticProjectile)
    
    -- Propiedades específicas del proyectil cinético
    self.velocity_trail = {}
    self.max_trail_points = config.trail_length
    self.spin_rotation = 0
    self.spin_speed = 25.0 -- Rotación rápida
    self.sonic_boom_timer = 0
    self.metal_sparks = {}
    self.penetration_count = 0
    self.max_penetrations = 2
    
    -- Inicializar efectos específicos del proyectil cinético
    self:initializeKineticEffects()
    
    return self
end

--[[
    Inicializa los efectos visuales específicos del proyectil cinético
--]]
function KineticProjectile:initializeKineticEffects()
    -- Configurar sistema de chispas metálicas
    self.metal_sparks = {}
    
    -- Configurar efectos de velocidad
    self.velocity_lines = {}
    self.sonic_effect_radius = self.config.size * 2
    
    -- Inicializar estela de velocidad
    self.velocity_trail = {}
end

--[[
    Actualiza el proyectil cinético
    @param dt: tiempo delta
--]]
function KineticProjectile:update(dt)
    -- Llamar al update de la clase base
    Projectile.update(self, dt)
    
    if self.state == Projectile.State.DESTROYED then
        return
    end
    
    -- Actualizar efectos específicos del proyectil cinético
    self:updateKineticEffects(dt)
    
    -- Actualizar estela de velocidad
    self:updateVelocityTrail(dt)
    
    -- Actualizar chispas metálicas
    self:updateMetalSparks(dt)
end

--[[
    Actualiza los efectos visuales específicos del proyectil cinético
    @param dt: tiempo delta
--]]
function KineticProjectile:updateKineticEffects(dt)
    -- Actualizar rotación del proyectil
    self.spin_rotation = self.spin_rotation + dt * self.spin_speed
    
    -- Actualizar efectos sónicos
    self.sonic_boom_timer = self.sonic_boom_timer + dt * 30
    
    -- Crear chispas metálicas ocasionalmente
    if math.random() < 0.2 then -- 20% de probabilidad
        self:createMetalSpark()
    end
    
    -- Limitar número de chispas
    while #self.metal_sparks > 6 do
        table.remove(self.metal_sparks, 1)
    end
end

--[[
    Actualiza la estela de velocidad
    @param dt: tiempo delta
--]]
function KineticProjectile:updateVelocityTrail(dt)
    if not self.body then return end
    
    local x, y = self.body:getPosition()
    local vx, vy = self.body:getLinearVelocity()
    local speed = math.sqrt(vx * vx + vy * vy)
    
    -- Añadir punto actual a la estela
    table.insert(self.velocity_trail, 1, {
        x = x,
        y = y,
        alpha = 1.0,
        speed = speed
    })
    
    -- Limitar número de puntos de estela
    while #self.velocity_trail > self.max_trail_points do
        table.remove(self.velocity_trail)
    end
    
    -- Actualizar alpha de los puntos de estela
    for i, point in ipairs(self.velocity_trail) do
        point.alpha = point.alpha - dt * 3.0
        if point.alpha <= 0 then
            table.remove(self.velocity_trail, i)
        end
    end
end

--[[
    Crea una chispa metálica
--]]
function KineticProjectile:createMetalSpark()
    if not self.body then return end
    
    local x, y = self.body:getPosition()
    local spark = {
        x = x + (math.random() - 0.5) * 4,
        y = y + (math.random() - 0.5) * 4,
        vx = (math.random() - 0.5) * 100,
        vy = (math.random() - 0.5) * 100,
        life = math.random() * 0.3 + 0.1,
        max_life = 0.4,
        size = math.random() * 1.5 + 0.5,
        brightness = math.random() * 0.5 + 0.5
    }
    
    table.insert(self.metal_sparks, spark)
end

--[[
    Actualiza las chispas metálicas
    @param dt: tiempo delta
--]]
function KineticProjectile:updateMetalSparks(dt)
    for i = #self.metal_sparks, 1, -1 do
        local spark = self.metal_sparks[i]
        
        -- Actualizar posición
        spark.x = spark.x + spark.vx * dt
        spark.y = spark.y + spark.vy * dt
        
        -- Aplicar gravedad y resistencia
        spark.vy = spark.vy + 50 * dt -- Gravedad ligera
        spark.vx = spark.vx * 0.98 -- Resistencia
        spark.vy = spark.vy * 0.98
        
        -- Actualizar vida
        spark.life = spark.life - dt
        
        if spark.life <= 0 then
            table.remove(self.metal_sparks, i)
        end
    end
end

--[[
    Dibuja el proyectil cinético
--]]
function KineticProjectile:draw()
    if self.state == Projectile.State.DESTROYED then
        return
    end
    
    if not self.body then return end
    
    local x, y = self.body:getPosition()
    local angle = self.body:getAngle()
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Dibujar efectos sónicos
    self:drawSonicEffects()
    
    -- Dibujar estela de velocidad
    self:drawVelocityTrail()
    
    -- Dibujar resplandor metálico
    self:drawMetallicGlow()
    
    -- Dibujar el proyectil principal
    self:drawKineticCore()
    
    -- Dibujar chispas metálicas
    self:drawMetalSparks()
    
    love.graphics.pop()
end

--[[
    Dibuja efectos sónicos del proyectil
--]]
function KineticProjectile:drawSonicEffects()
    -- Ondas de choque por la alta velocidad
    local sonic_color = {0.9, 0.9, 1, 0.3}
    
    for i = 1, 2 do
        local radius = self.sonic_effect_radius * (1 + i * 0.5)
        local wave_offset = math.sin(self.sonic_boom_timer + i * 2) * 2
        local alpha = sonic_color[4] / (i + 1)
        
        love.graphics.setColor(sonic_color[1], sonic_color[2], sonic_color[3], alpha)
        love.graphics.circle("line", -radius, 0, radius + wave_offset)
    end
end

--[[
    Dibuja la estela de velocidad
--]]
function KineticProjectile:drawVelocityTrail()
    if #self.velocity_trail < 2 then return end
    
    local trail_color = self.config.trail_color
    
    for i = 1, #self.velocity_trail - 1 do
        local point1 = self.velocity_trail[i]
        local point2 = self.velocity_trail[i + 1]
        
        local alpha = math.min(point1.alpha, point2.alpha) * trail_color[4]
        love.graphics.setColor(trail_color[1], trail_color[2], trail_color[3], alpha)
        
        -- Grosor de línea basado en velocidad
        local speed_factor = (point1.speed or 1000) / 2000
        local thickness = math.max(0.5, speed_factor * 3)
        love.graphics.setLineWidth(thickness)
        
        -- Convertir a coordenadas locales
        local current_x, current_y = self.body:getPosition()
        local local_x1 = point1.x - current_x
        local local_y1 = point1.y - current_y
        local local_x2 = point2.x - current_x
        local local_y2 = point2.y - current_y
        
        love.graphics.line(local_x1, local_y1, local_x2, local_y2)
    end
    
    love.graphics.setLineWidth(1) -- Resetear grosor
end

--[[
    Dibuja el resplandor metálico
--]]
function KineticProjectile:drawMetallicGlow()
    local glow_color = self.config.glow_color
    
    -- Resplandor metálico con múltiples capas
    for i = 1, 3 do
        local radius = self.config.size * (i * 1.2)
        local alpha = glow_color[4] / (i * 0.8)
        
        love.graphics.setColor(glow_color[1], glow_color[2], glow_color[3], alpha)
        love.graphics.ellipse("fill", 0, 0, radius * 2.5, radius * 0.8)
    end
end

--[[
    Dibuja el núcleo del proyectil cinético
--]]
function KineticProjectile:drawKineticCore()
    local color = self.config.color
    
    love.graphics.push()
    love.graphics.rotate(self.spin_rotation)
    
    -- Cuerpo principal del proyectil (forma de bala)
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    
    -- Forma aerodinámica
    local vertices = {
        -self.config.size * 2, -self.config.size * 0.5,
        self.config.size * 2, 0,
        -self.config.size * 2, self.config.size * 0.5
    }
    love.graphics.polygon("fill", vertices)
    
    -- Núcleo metálico brillante
    love.graphics.setColor(1, 1, 0.8, 0.9)
    love.graphics.ellipse("fill", 0, 0, self.config.size * 1.5, self.config.size * 0.6)
    
    -- Centro ultra brillante
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.ellipse("fill", 0, 0, self.config.size * 0.8, self.config.size * 0.3)
    
    -- Líneas de rotación para mostrar el giro
    love.graphics.setColor(0.7, 0.7, 0.5, 0.8)
    for i = 1, 3 do
        local line_angle = (i / 3) * math.pi * 2
        local line_length = self.config.size * 1.2
        local x1 = math.cos(line_angle) * line_length * 0.3
        local y1 = math.sin(line_angle) * line_length * 0.3
        local x2 = math.cos(line_angle) * line_length
        local y2 = math.sin(line_angle) * line_length
        love.graphics.line(x1, y1, x2, y2)
    end
    
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Dibuja las chispas metálicas
--]]
function KineticProjectile:drawMetalSparks()
    for _, spark in ipairs(self.metal_sparks) do
        local alpha = (spark.life / spark.max_life)
        local brightness = spark.brightness * alpha
        
        love.graphics.setColor(1, 0.9, 0.6, alpha)
        
        -- Convertir a coordenadas locales
        local current_x, current_y = self.body:getPosition()
        local local_x = spark.x - current_x
        local local_y = spark.y - current_y
        
        love.graphics.circle("fill", local_x, local_y, spark.size * alpha)
        
        -- Efecto de brillo adicional
        love.graphics.setColor(1, 1, 1, alpha * 0.5)
        love.graphics.circle("fill", local_x, local_y, spark.size * alpha * 0.5)
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Maneja el impacto del proyectil cinético
    @param other: el otro objeto que colisionó
    @param contact: información del contacto
--]]
function KineticProjectile:onCollision(other, contact)
    -- Si tiene penetración y no ha alcanzado el máximo
    if self.config.penetration and self.penetration_count < self.max_penetrations then
        self.penetration_count = self.penetration_count + 1
        
        -- Reducir daño por penetración
        self.damage = self.damage * 0.7
        
        -- Crear efectos de penetración
        self:createPenetrationEffects(contact)
        
        -- Continuar sin destruir el proyectil
        return
    end
    
    -- Llamar al método base para destrucción normal
    Projectile.onCollision(self, other, contact)
end

--[[
    Crea efectos de penetración
    @param contact: información del contacto
--]]
function KineticProjectile:createPenetrationEffects(contact)
    local x, y = contact:getPositions()
    
    -- Crear chispas de penetración
    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2
        local speed = math.random(60, 120)
        local spark = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = math.random() * 0.5 + 0.2,
            max_life = 0.7,
            size = math.random() * 2 + 1,
            color = {0.9, 0.8, 0.5, 1}
        }
        
        table.insert(self.visual_effects, spark)
    end
end

--[[
    Crea efectos de impacto específicos del proyectil cinético
    @param contact: información del contacto
--]]
function KineticProjectile:createImpactEffects(contact)
    -- Llamar al método base
    Projectile.createImpactEffects(self, contact)
    
    -- Añadir efectos específicos del proyectil cinético
    local x, y = contact:getPositions()
    
    -- Crear explosión de fragmentos metálicos
    for i = 1, 15 do
        local angle = (i / 15) * math.pi * 2
        local speed = math.random(100, 250)
        local fragment = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = math.random() * 1.0 + 0.5,
            max_life = 1.5,
            size = math.random() * 3 + 1,
            color = {0.9, 0.8, 0.6, 1},
            spin = math.random() * 10 - 5
        }
        
        table.insert(self.visual_effects, fragment)
    end
    
    -- Crear ondas de impacto
    for i = 1, 2 do
        local shockwave = {
            x = x,
            y = y,
            radius = 0,
            max_radius = 30 + i * 15,
            life = 0.6,
            max_life = 0.6,
            intensity = 1.0 / i
        }
        
        table.insert(self.visual_effects, shockwave)
    end
end

return KineticProjectile