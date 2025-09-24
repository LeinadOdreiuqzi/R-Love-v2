--[[
    BasicRedProjectile - Proyectil Básico con Efecto Rojo
    
    Proyectil simple con efectos visuales rojos para disparos básicos.
    Hereda de la clase base Projectile y añade características específicas.
    
    Características:
    - Color rojo brillante
    - Efectos de partículas rojas
    - Velocidad media
    - Daño básico
    - Estela roja
--]]

local Projectile = require('src.physics.projectiles.projectile')
local BasicRedProjectile = {}
BasicRedProjectile.__index = BasicRedProjectile
setmetatable(BasicRedProjectile, {__index = Projectile})

-- Configuración específica del proyectil láser rojo 
local RED_PROJECTILE_CONFIG = {
    type = "laser_red",
    damage = 20,
    speed = 1900, -- Velocidad de láser muy alta
    lifetime = 5.0, -- Menor tiempo de vida por la alta velocidad
    max_distance = 1500, -- Mayor alcance
    size = 1.0, -- Más pequeño y delgado como un láser
    color = {1, 0.1, 0.1, 1}, -- Rojo más intenso
    trail_color = {1, 0.3, 0.3, 0.9}, -- Estela más brillante
    glow_color = {1, 0.8, 0.8, 0.8}, -- Resplandor más intenso
    particle_count = 4, -- Menos partículas para efecto más limpio
    trail_length = 4 -- Estela más corta pero intensa
}

--[[
    Constructor del proyectil rojo
    @param world: mundo Box2D
    @param x, y: posición inicial
    @param angle: ángulo de disparo en radianes
    @param speed: velocidad inicial (opcional, usa la por defecto si no se especifica)
    @param custom_config: configuración personalizada (opcional)
    @return: nueva instancia de BasicRedProjectile
--]]
function BasicRedProjectile.new(world, x, y, angle, speed, custom_config)
    -- Combinar configuración por defecto con personalizada
    local config = {}
    for k, v in pairs(RED_PROJECTILE_CONFIG) do
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
    setmetatable(self, BasicRedProjectile)
    
    -- Propiedades específicas del proyectil láser
    self.glow_intensity = 1.0
    self.pulse_timer = 0
    self.trail_points = {}
    self.max_trail_points = config.trail_length
    self.laser_flicker = 0
    self.core_brightness = 1.0
    
    -- Inicializar efectos específicos del láser
    self:initializeLaserEffects()
    
    return self
end

--[[
    Inicializa los efectos visuales específicos del láser rojo
--]]
function BasicRedProjectile:initializeLaserEffects()
    -- Inicializar sistema de partículas para la estela
    self.trail_particles = {}
    
    -- Configurar efectos de resplandor láser
    self.glow_radius = self.config.size * 3 -- Resplandor más amplio
    self.pulse_speed = 15.0 -- Pulsación más rápida
    self.flicker_speed = 25.0 -- Parpadeo rápido del láser
end

--[[
    Actualiza el proyectil rojo
    @param dt: tiempo delta
--]]
function BasicRedProjectile:update(dt)
    -- Llamar al update de la clase base
    Projectile.update(self, dt)
    
    if self.state == Projectile.State.DESTROYED then
        return
    end
    
    -- Actualizar efectos específicos del láser rojo
    self:updateLaserEffects(dt)
    
    -- Actualizar estela
    self:updateTrail(dt)
end

--[[
    Actualiza los efectos visuales específicos del láser rojo
    @param dt: tiempo delta
--]]
function BasicRedProjectile:updateLaserEffects(dt)
    -- Actualizar pulsación del resplandor láser
    self.pulse_timer = self.pulse_timer + dt * self.pulse_speed
    self.glow_intensity = 0.8 + 0.2 * math.sin(self.pulse_timer)
    
    -- Actualizar parpadeo del núcleo del láser
    self.laser_flicker = self.laser_flicker + dt * self.flicker_speed
    self.core_brightness = 0.9 + 0.1 * math.sin(self.laser_flicker)
    
    -- Crear menos partículas para efecto más limpio
    if self.body and math.random() < 0.3 then -- Solo 30% de probabilidad
        local x, y = self.body:getPosition()
        self:addTrailParticle(x, y)
    end
end

--[[
    Actualiza la estela del proyectil
    @param dt: tiempo delta
--]]
function BasicRedProjectile:updateTrail(dt)
    if not self.body then return end
    
    local x, y = self.body:getPosition()
    
    -- Añadir punto actual a la estela
    table.insert(self.trail_points, 1, {x = x, y = y, alpha = 1.0})
    
    -- Limitar número de puntos de estela
    while #self.trail_points > self.max_trail_points do
        table.remove(self.trail_points)
    end
    
    -- Actualizar alpha de los puntos de estela
    for i, point in ipairs(self.trail_points) do
        point.alpha = point.alpha - dt * 2.0
        if point.alpha <= 0 then
            table.remove(self.trail_points, i)
        end
    end
end

--[[
    Añade una partícula a la estela
    @param x, y: posición de la partícula
--]]
function BasicRedProjectile:addTrailParticle(x, y)
    local particle = {
        x = x + (math.random() - 0.5) * 2,
        y = y + (math.random() - 0.5) * 2,
        life = 0.5,
        max_life = 0.5,
        size = math.random() * 2 + 1
    }
    
    table.insert(self.trail_particles, particle)
    
    -- Limitar número de partículas
    while #self.trail_particles > self.config.particle_count do
        table.remove(self.trail_particles, 1)
    end
end

--[[
    Dibuja el proyectil rojo
--]]
function BasicRedProjectile:draw()
    if self.state == Projectile.State.DESTROYED then
        return
    end
    
    if not self.body then return end
    
    local x, y = self.body:getPosition()
    local angle = self.body:getAngle()
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Dibujar efectos de resplandor
    self:drawGlow()
    
    -- Dibujar estela
    self:drawTrail()
    
    -- Dibujar el proyectil principal
    self:drawMainProjectile()
    
    -- Dibujar partículas
    self:drawTrailParticles()
    
    love.graphics.pop()
end

--[[
    Dibuja el resplandor del láser
--]]
function BasicRedProjectile:drawGlow()
    local glow_color = self.config.glow_color
    
    -- Dibujar resplandor láser más intenso y alargado
    for i = 1, 4 do
        local radius = self.glow_radius * (i * 0.3)
        local alpha = (glow_color[4] * self.glow_intensity) / (i * 0.8)
        love.graphics.setColor(glow_color[1], glow_color[2], glow_color[3], alpha)
        
        -- Crear forma alargada para simular rayo láser
        love.graphics.ellipse("fill", 0, 0, radius * 2, radius * 0.5)
    end
end

--[[
    Dibuja la estela del proyectil
--]]
function BasicRedProjectile:drawTrail()
    if #self.trail_points < 2 then return end
    
    local trail_color = self.config.trail_color
    
    for i = 1, #self.trail_points - 1 do
        local point1 = self.trail_points[i]
        local point2 = self.trail_points[i + 1]
        
        local alpha = math.min(point1.alpha, point2.alpha) * trail_color[4]
        love.graphics.setColor(trail_color[1], trail_color[2], trail_color[3], alpha)
        
        -- Calcular grosor de línea basado en la posición en la estela
        local thickness = (alpha / trail_color[4]) * 2
        love.graphics.setLineWidth(thickness)
        
        -- Convertir coordenadas del mundo a coordenadas locales
        local current_x, current_y = self.body:getPosition()
        local local_x1 = point1.x - current_x
        local local_y1 = point1.y - current_y
        local local_x2 = point2.x - current_x
        local local_y2 = point2.y - current_y
        
        love.graphics.line(local_x1, local_y1, local_x2, local_y2)
    end
    
    love.graphics.setLineWidth(1) -- Resetear grosor de línea
end

--[[
    Dibuja el núcleo del láser
--]]
function BasicRedProjectile:drawMainProjectile()
    local color = self.config.color
    
    -- Dibujar núcleo del láser con brillo variable
    love.graphics.setColor(color[1], color[2], color[3], color[4] * self.core_brightness)
    
    -- Núcleo alargado del láser
    love.graphics.ellipse("fill", 0, 0, self.config.size * 3, self.config.size * 0.8)
    
    -- Centro ultra brillante
    love.graphics.setColor(1, 1, 1, 0.9 * self.core_brightness)
    love.graphics.ellipse("fill", 0, 0, self.config.size * 2, self.config.size * 0.4)
    
    -- Línea central del láser
    love.graphics.setColor(1, 0.9, 0.9, 1)
    love.graphics.ellipse("fill", 0, 0, self.config.size * 1.5, self.config.size * 0.2)
    
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Dibuja las partículas de estela
--]]
function BasicRedProjectile:drawTrailParticles()
    local trail_color = self.config.trail_color
    
    for i = #self.trail_particles, 1, -1 do
        local particle = self.trail_particles[i]
        
        -- Actualizar vida de la partícula
        particle.life = particle.life - love.timer.getDelta()
        
        if particle.life <= 0 then
            table.remove(self.trail_particles, i)
        else
            local alpha = (particle.life / particle.max_life) * trail_color[4]
            love.graphics.setColor(trail_color[1], trail_color[2], trail_color[3], alpha)
            
            -- Convertir a coordenadas locales
            local current_x, current_y = self.body:getPosition()
            local local_x = particle.x - current_x
            local local_y = particle.y - current_y
            
            love.graphics.circle("fill", local_x, local_y, particle.size * (particle.life / particle.max_life))
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Crea efectos de impacto específicos del proyectil rojo
    @param contact: información del contacto
--]]
function BasicRedProjectile:createImpactEffects(contact)
    -- Llamar al método base
    Projectile.createImpactEffects(self, contact)
    
    -- Añadir efectos específicos del proyectil rojo
    local x, y = contact:getPositions()
    
    -- Crear explosión de partículas rojas
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2
        local speed = math.random(50, 150)
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = math.random() * 0.8 + 0.2,
            max_life = 1.0,
            size = math.random() * 3 + 1,
            color = {1, math.random() * 0.5, math.random() * 0.3, 1}
        }
        
        table.insert(self.visual_effects, particle)
    end
end

return BasicRedProjectile