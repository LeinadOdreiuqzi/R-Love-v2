--[[
    PlasmaProjectile - Proyectil de Plasma
    
    Proyectil de energía de plasma con efectos visuales azules/verdes.
    Hereda de la clase base Projectile y añade características de plasma.
    
    Características:
    - Color azul/verde brillante
    - Efectos de ionización
    - Velocidad media-alta
    - Daño energético alto
    - Efectos de campo electromagnético
--]]

local Projectile = require('src.physics.projectiles.projectile')
local PlasmaProjectile = {}
PlasmaProjectile.__index = PlasmaProjectile
setmetatable(PlasmaProjectile, {__index = Projectile})

-- Configuración específica del proyectil de plasma
local PLASMA_PROJECTILE_CONFIG = {
    type = "plasma",
    damage = 35,
    speed = 1600, -- Velocidad alta pero menor que láser
    lifetime = 4.0,
    max_distance = 1200,
    size = 1.5, -- Más grande que láser
    color = {0.2, 0.8, 1, 1}, -- Azul cian brillante
    trail_color = {0.4, 1, 0.8, 0.9}, -- Verde azulado
    glow_color = {0.6, 0.9, 1, 0.8}, -- Resplandor azul
    particle_count = 8, -- Más partículas para efecto de plasma
    trail_length = 6, -- Estela más larga
    energy_cost = 15 -- Costo energético
}

--[[
    Constructor del proyectil de plasma
    @param world: mundo Box2D
    @param x, y: posición inicial
    @param angle: ángulo de disparo en radianes
    @param speed: velocidad inicial (opcional)
    @param custom_config: configuración personalizada (opcional)
    @return: nueva instancia de PlasmaProjectile
--]]
function PlasmaProjectile.new(world, x, y, angle, speed, custom_config)
    -- Combinar configuración por defecto con personalizada
    local config = {}
    for k, v in pairs(PLASMA_PROJECTILE_CONFIG) do
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
    setmetatable(self, PlasmaProjectile)
    
    -- Propiedades específicas del plasma
    self.plasma_intensity = 1.0
    self.ionization_timer = 0
    self.electromagnetic_field = 0
    self.plasma_particles = {}
    self.energy_fluctuation = 0
    self.core_temperature = 1.0
    
    -- Inicializar efectos específicos del plasma
    self:initializePlasmaEffects()
    
    return self
end

--[[
    Inicializa los efectos visuales específicos del plasma
--]]
function PlasmaProjectile:initializePlasmaEffects()
    -- Configurar sistema de partículas de plasma
    self.plasma_particles = {}
    
    -- Configurar efectos electromagnéticos
    self.field_radius = self.config.size * 4
    self.ionization_speed = 20.0
    self.energy_fluctuation_speed = 12.0
    
    -- Crear partículas iniciales de plasma
    for i = 1, self.config.particle_count do
        self:createPlasmaParticle()
    end
end

--[[
    Crea una partícula de plasma
--]]
function PlasmaProjectile:createPlasmaParticle()
    local particle = {
        x = (math.random() - 0.5) * self.config.size * 2,
        y = (math.random() - 0.5) * self.config.size * 2,
        vx = (math.random() - 0.5) * 50,
        vy = (math.random() - 0.5) * 50,
        life = math.random() * 0.8 + 0.4,
        max_life = 1.2,
        size = math.random() * 1.5 + 0.5,
        energy = math.random() * 0.5 + 0.5,
        phase = math.random() * math.pi * 2
    }
    
    table.insert(self.plasma_particles, particle)
end

--[[
    Actualiza el proyectil de plasma
    @param dt: tiempo delta
--]]
function PlasmaProjectile:update(dt)
    -- Llamar al update de la clase base
    Projectile.update(self, dt)
    
    if self.state == Projectile.State.DESTROYED then
        return
    end
    
    -- Actualizar efectos específicos del plasma
    self:updatePlasmaEffects(dt)
    
    -- Actualizar partículas de plasma
    self:updatePlasmaParticles(dt)
end

--[[
    Actualiza los efectos visuales específicos del plasma
    @param dt: tiempo delta
--]]
function PlasmaProjectile:updatePlasmaEffects(dt)
    -- Actualizar ionización
    self.ionization_timer = self.ionization_timer + dt * self.ionization_speed
    self.plasma_intensity = 0.7 + 0.3 * math.sin(self.ionization_timer)
    
    -- Actualizar campo electromagnético
    self.electromagnetic_field = self.electromagnetic_field + dt * 10
    
    -- Actualizar fluctuación energética
    self.energy_fluctuation = self.energy_fluctuation + dt * self.energy_fluctuation_speed
    self.core_temperature = 0.8 + 0.2 * math.sin(self.energy_fluctuation)
    
    -- Crear nuevas partículas de plasma ocasionalmente
    if math.random() < 0.4 then
        self:createPlasmaParticle()
    end
    
    -- Limitar número de partículas
    while #self.plasma_particles > self.config.particle_count * 2 do
        table.remove(self.plasma_particles, 1)
    end
end

--[[
    Actualiza las partículas de plasma
    @param dt: tiempo delta
--]]
function PlasmaProjectile:updatePlasmaParticles(dt)
    for i = #self.plasma_particles, 1, -1 do
        local particle = self.plasma_particles[i]
        
        -- Actualizar posición
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        
        -- Actualizar vida
        particle.life = particle.life - dt
        
        -- Actualizar fase para efectos ondulatorios
        particle.phase = particle.phase + dt * 15
        
        -- Aplicar fuerzas electromagnéticas (atracción hacia el centro)
        local distance = math.sqrt(particle.x * particle.x + particle.y * particle.y)
        if distance > 0 then
            local force = 30 / (distance + 1)
            particle.vx = particle.vx - (particle.x / distance) * force * dt
            particle.vy = particle.vy - (particle.y / distance) * force * dt
        end
        
        -- Remover partículas muertas
        if particle.life <= 0 then
            table.remove(self.plasma_particles, i)
        end
    end
end

--[[
    Dibuja el proyectil de plasma
--]]
function PlasmaProjectile:draw()
    if self.state == Projectile.State.DESTROYED then
        return
    end
    
    if not self.body then return end
    
    local x, y = self.body:getPosition()
    local angle = self.body:getAngle()
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Dibujar campo electromagnético
    self:drawElectromagneticField()
    
    -- Dibujar resplandor de plasma
    self:drawPlasmaGlow()
    
    -- Dibujar núcleo de plasma
    self:drawPlasmaCore()
    
    -- Dibujar partículas de plasma
    self:drawPlasmaParticles()
    
    -- Dibujar efectos de ionización
    self:drawIonizationEffects()
    
    love.graphics.pop()
end

--[[
    Dibuja el campo electromagnético
--]]
function PlasmaProjectile:drawElectromagneticField()
    local field_color = self.config.glow_color
    
    -- Dibujar ondas electromagnéticas
    for i = 1, 3 do
        local radius = self.field_radius * (0.5 + i * 0.3)
        local alpha = (field_color[4] * 0.3) / i
        local wave_offset = math.sin(self.electromagnetic_field + i) * 0.2
        
        love.graphics.setColor(field_color[1], field_color[2], field_color[3], alpha)
        love.graphics.circle("line", 0, 0, radius + wave_offset)
    end
end

--[[
    Dibuja el resplandor del plasma
--]]
function PlasmaProjectile:drawPlasmaGlow()
    local glow_color = self.config.glow_color
    
    -- Resplandor principal con múltiples capas
    for i = 1, 5 do
        local radius = self.config.size * (i * 0.8)
        local alpha = (glow_color[4] * self.plasma_intensity) / (i * 0.6)
        
        love.graphics.setColor(glow_color[1], glow_color[2], glow_color[3], alpha)
        love.graphics.circle("fill", 0, 0, radius)
    end
end

--[[
    Dibuja el núcleo del plasma
--]]
function PlasmaProjectile:drawPlasmaCore()
    local color = self.config.color
    
    -- Núcleo principal con temperatura variable
    love.graphics.setColor(color[1], color[2], color[3], color[4] * self.core_temperature)
    love.graphics.circle("fill", 0, 0, self.config.size * 1.2)
    
    -- Centro ultra caliente
    love.graphics.setColor(1, 1, 1, 0.9 * self.core_temperature)
    love.graphics.circle("fill", 0, 0, self.config.size * 0.8)
    
    -- Núcleo interno pulsante
    local pulse = 0.5 + 0.5 * math.sin(self.energy_fluctuation * 2)
    love.graphics.setColor(0.8, 1, 1, pulse)
    love.graphics.circle("fill", 0, 0, self.config.size * 0.4)
    
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Dibuja las partículas de plasma
--]]
function PlasmaProjectile:drawPlasmaParticles()
    local particle_color = self.config.trail_color
    
    for _, particle in ipairs(self.plasma_particles) do
        local alpha = (particle.life / particle.max_life) * particle_color[4]
        local size_factor = (particle.life / particle.max_life)
        local wave_effect = math.sin(particle.phase) * 0.3 + 0.7
        
        love.graphics.setColor(particle_color[1], particle_color[2], particle_color[3], alpha * wave_effect)
        love.graphics.circle("fill", particle.x, particle.y, particle.size * size_factor)
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Dibuja efectos de ionización
--]]
function PlasmaProjectile:drawIonizationEffects()
    -- Chispas eléctricas alrededor del proyectil
    local spark_color = {0.9, 1, 1, 0.8}
    
    for i = 1, 4 do
        local angle = (i / 4) * math.pi * 2 + self.ionization_timer
        local distance = self.config.size * 2 + math.sin(self.ionization_timer * 3 + i) * 5
        local spark_x = math.cos(angle) * distance
        local spark_y = math.sin(angle) * distance
        
        love.graphics.setColor(spark_color[1], spark_color[2], spark_color[3], spark_color[4] * self.plasma_intensity)
        love.graphics.circle("fill", spark_x, spark_y, 1)
        
        -- Líneas de conexión eléctrica
        love.graphics.setColor(spark_color[1], spark_color[2], spark_color[3], spark_color[4] * 0.5)
        love.graphics.line(0, 0, spark_x * 0.7, spark_y * 0.7)
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Crea efectos de impacto específicos del proyectil de plasma
    @param contact: información del contacto
--]]
function PlasmaProjectile:createImpactEffects(contact)
    -- Llamar al método base
    Projectile.createImpactEffects(self, contact)
    
    -- Añadir efectos específicos del plasma
    local x, y = contact:getPositions()
    
    -- Crear explosión de plasma con ionización
    for i = 1, 20 do
        local angle = (i / 20) * math.pi * 2
        local speed = math.random(80, 200)
        local particle = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = math.random() * 1.2 + 0.5,
            max_life = 1.5,
            size = math.random() * 4 + 2,
            color = {0.2 + math.random() * 0.3, 0.8 + math.random() * 0.2, 1, 1},
            energy = math.random()
        }
        
        table.insert(self.visual_effects, particle)
    end
    
    -- Crear ondas de choque electromagnéticas
    for i = 1, 3 do
        local shockwave = {
            x = x,
            y = y,
            radius = 0,
            max_radius = 50 + i * 20,
            life = 0.8,
            max_life = 0.8,
            intensity = 1.0 / i
        }
        
        table.insert(self.visual_effects, shockwave)
    end
end

return PlasmaProjectile