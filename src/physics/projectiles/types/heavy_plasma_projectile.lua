--[[
    HeavyPlasmaProjectile - Proyectil de Plasma Pesado
    
    Proyectil de plasma de alta potencia con efectos visuales intensos.
    Hereda de la clase base Projectile y añade características de plasma pesado.
    
    Características:
    - Color plasma intenso púrpura/azul
    - Velocidad moderada pero alto daño
    - Efectos de ionización y campo electromagnético
    - Área de daño en impacto
    - Efectos de distorsión espacial
--]]

local Projectile = require('src.physics.projectiles.projectile')
local HeavyPlasmaProjectile = {}
HeavyPlasmaProjectile.__index = HeavyPlasmaProjectile
setmetatable(HeavyPlasmaProjectile, {__index = Projectile})

-- Configuración específica del proyectil de plasma pesado
local HEAVY_PLASMA_CONFIG = {
    type = "heavy_plasma",
    damage = 45, -- Daño muy alto
    speed = 1400, -- Velocidad moderada
    lifetime = 4.0, -- Mayor tiempo de vida
    max_distance = 2000,
    size = 1.8, -- Más grande que el plasma normal
    color = {0.6, 0.2, 1, 1}, -- Púrpura intenso
    core_color = {0.9, 0.4, 1, 1}, -- Núcleo púrpura brillante
    trail_color = {0.4, 0.1, 0.8, 0.9}, -- Estela púrpura
    glow_color = {0.7, 0.3, 1, 0.7}, -- Resplandor púrpura
    particle_count = 12, -- Muchas partículas
    trail_length = 15, -- Estela muy larga
    explosion_radius = 25, -- Radio de explosión
    electromagnetic_range = 35, -- Rango de efectos electromagnéticos
    energy_intensity = 1.5 -- Intensidad de energía
}

--[[
    Constructor del proyectil de plasma pesado
    @param world: mundo Box2D
    @param x, y: posición inicial
    @param angle: ángulo de disparo en radianes
    @param speed: velocidad inicial (opcional)
    @param custom_config: configuración personalizada (opcional)
    @return: nueva instancia de HeavyPlasmaProjectile
--]]
function HeavyPlasmaProjectile.new(world, x, y, angle, speed, custom_config)
    -- Combinar configuración por defecto con personalizada
    local config = {}
    for k, v in pairs(HEAVY_PLASMA_CONFIG) do
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
    setmetatable(self, HeavyPlasmaProjectile)
    
    -- Propiedades específicas del proyectil de plasma pesado
    self.plasma_field = {}
    self.electromagnetic_pulses = {}
    self.energy_distortion = 0
    self.plasma_intensity = 1.0
    self.field_oscillation = 0
    self.core_pulsation = 0
    self.ionization_particles = {}
    self.energy_arcs = {}
    self.spatial_distortion = {}
    
    -- Inicializar trail points para efectos de estela
    self.trail_points = {}
    self.max_trail_points = config.trail_length
    
    -- Inicializar efectos específicos del plasma pesado
    self:initializeHeavyPlasmaEffects()
    
    return self
end

--[[
    Inicializa los efectos visuales específicos del plasma pesado
--]]
function HeavyPlasmaProjectile:initializeHeavyPlasmaEffects()
    -- Configurar campo de plasma
    self.plasma_field = {
        inner_radius = self.config.size * 1.5,
        outer_radius = self.config.size * 3.0,
        intensity = self.config.energy_intensity,
        fluctuation = 0
    }
    
    -- Configurar pulsos electromagnéticos
    self.electromagnetic_pulses = {}
    
    -- Configurar partículas de ionización
    self.ionization_particles = {}
    for i = 1, 8 do
        table.insert(self.ionization_particles, {
            angle = (i / 8) * math.pi * 2,
            distance = self.config.size * 2,
            speed = math.random() * 50 + 25,
            phase = math.random() * math.pi * 2,
            intensity = math.random() * 0.5 + 0.5
        })
    end
    
    -- Configurar arcos de energía
    self.energy_arcs = {}
    
    -- Configurar distorsión espacial
    self.spatial_distortion = {
        strength = 0,
        frequency = 0,
        phase = 0
    }
end

--[[
    Actualiza el proyectil de plasma pesado
    @param dt: tiempo delta
--]]
function HeavyPlasmaProjectile:update(dt)
    -- Llamar al update de la clase base
    Projectile.update(self, dt)
    
    if self.state == Projectile.State.DESTROYED then
        return
    end
    
    -- Actualizar estela del proyectil
    self:updateTrail(dt)
    
    -- Actualizar efectos específicos del plasma pesado
    self:updateHeavyPlasmaEffects(dt)
    
    -- Actualizar campo electromagnético
    self:updateElectromagneticField(dt)
    
    -- Actualizar partículas de ionización
    self:updateIonizationParticles(dt)
    
    -- Actualizar arcos de energía
    self:updateEnergyArcs(dt)
    
    -- Actualizar distorsión espacial
    self:updateSpatialDistortion(dt)
end

--[[
    Actualiza los efectos visuales específicos del plasma pesado
    @param dt: tiempo delta
--]]
function HeavyPlasmaProjectile:updateHeavyPlasmaEffects(dt)
    -- Actualizar oscilación del campo
    self.field_oscillation = self.field_oscillation + dt * 8.0
    
    -- Actualizar pulsación del núcleo
    self.core_pulsation = self.core_pulsation + dt * 12.0
    
    -- Actualizar distorsión de energía
    self.energy_distortion = self.energy_distortion + dt * 15.0
    
    -- Fluctuación del campo de plasma
    self.plasma_field.fluctuation = math.sin(self.field_oscillation) * 0.3
    
    -- Intensidad variable del plasma
    self.plasma_intensity = 0.8 + math.sin(self.core_pulsation) * 0.2
    
    -- Crear pulsos electromagnéticos ocasionalmente
    if math.random() < 0.15 then -- 15% de probabilidad
        self:createElectromagneticPulse()
    end
    
    -- Crear arcos de energía
    if math.random() < 0.25 then -- 25% de probabilidad
        self:createEnergyArc()
    end
    
    -- Limitar número de efectos
    while #self.electromagnetic_pulses > 4 do
        table.remove(self.electromagnetic_pulses, 1)
    end
    
    while #self.energy_arcs > 6 do
        table.remove(self.energy_arcs, 1)
    end
end

--[[
    Actualiza el campo electromagnético
    @param dt: tiempo delta
--]]
function HeavyPlasmaProjectile:updateElectromagneticField(dt)
    -- Actualizar pulsos electromagnéticos
    for i = #self.electromagnetic_pulses, 1, -1 do
        local pulse = self.electromagnetic_pulses[i]
        
        pulse.radius = pulse.radius + pulse.expansion_speed * dt
        pulse.intensity = pulse.intensity - dt * 2.0
        
        if pulse.intensity <= 0 or pulse.radius > self.config.electromagnetic_range then
            table.remove(self.electromagnetic_pulses, i)
        end
    end
end

--[[
    Actualiza las partículas de ionización
    @param dt: tiempo delta
--]]
function HeavyPlasmaProjectile:updateIonizationParticles(dt)
    for _, particle in ipairs(self.ionization_particles) do
        -- Actualizar fase para movimiento orbital
        particle.phase = particle.phase + dt * particle.speed
        
        -- Calcular nueva posición orbital
        local orbit_radius = particle.distance + math.sin(particle.phase * 2) * 5
        particle.current_x = math.cos(particle.angle + particle.phase * 0.5) * orbit_radius
        particle.current_y = math.sin(particle.angle + particle.phase * 0.5) * orbit_radius
        
        -- Actualizar intensidad con pulsación
        particle.current_intensity = particle.intensity * (0.7 + math.sin(particle.phase * 3) * 0.3)
    end
end

--[[
    Actualiza los arcos de energía
    @param dt: tiempo delta
--]]
function HeavyPlasmaProjectile:updateEnergyArcs(dt)
    for i = #self.energy_arcs, 1, -1 do
        local arc = self.energy_arcs[i]
        
        -- Actualizar vida del arco
        arc.life = arc.life - dt
        
        -- Actualizar puntos del arco
        for j, point in ipairs(arc.points) do
            point.offset_x = point.offset_x + (math.random() - 0.5) * 20 * dt
            point.offset_y = point.offset_y + (math.random() - 0.5) * 20 * dt
            
            -- Limitar desplazamiento
            point.offset_x = math.max(-10, math.min(10, point.offset_x))
            point.offset_y = math.max(-10, math.min(10, point.offset_y))
        end
        
        if arc.life <= 0 then
            table.remove(self.energy_arcs, i)
        end
    end
end

--[[
    Actualiza la distorsión espacial
    @param dt: tiempo delta
--]]
function HeavyPlasmaProjectile:updateSpatialDistortion(dt)
    self.spatial_distortion.phase = self.spatial_distortion.phase + dt * 10.0
    self.spatial_distortion.strength = 0.5 + math.sin(self.spatial_distortion.phase) * 0.3
    self.spatial_distortion.frequency = 3.0 + math.cos(self.spatial_distortion.phase * 0.7) * 1.0
end

--[[
    Crea un pulso electromagnético
--]]
function HeavyPlasmaProjectile:createElectromagneticPulse()
    local pulse = {
        radius = self.config.size,
        max_radius = self.config.electromagnetic_range,
        intensity = 1.0,
        expansion_speed = 80,
        color = {0.8, 0.4, 1, 0.6}
    }
    
    table.insert(self.electromagnetic_pulses, pulse)
end

--[[
    Crea un arco de energía
--]]
function HeavyPlasmaProjectile:createEnergyArc()
    local arc = {
        life = math.random() * 0.3 + 0.2,
        max_life = 0.5,
        intensity = math.random() * 0.5 + 0.5,
        points = {}
    }
    
    -- Crear puntos del arco
    local num_points = math.random(4, 8)
    for i = 1, num_points do
        local angle = math.random() * math.pi * 2
        local distance = math.random() * self.config.size * 3
        
        table.insert(arc.points, {
            x = math.cos(angle) * distance,
            y = math.sin(angle) * distance,
            offset_x = 0,
            offset_y = 0
        })
    end
    
    table.insert(self.energy_arcs, arc)
end

--[[
    Dibuja el proyectil de plasma pesado
--]]
function HeavyPlasmaProjectile:draw()
    if self.state == Projectile.State.DESTROYED then
        return
    end
    
    if not self.body then return end
    
    local x, y = self.body:getPosition()
    local angle = self.body:getAngle()
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Dibujar distorsión espacial
    self:drawSpatialDistortion()
    
    -- Dibujar campo electromagnético
    self:drawElectromagneticField()
    
    -- Dibujar estela de plasma
    self:drawPlasmaTrail()
    
    -- Dibujar campo de plasma
    self:drawPlasmaField()
    
    -- Dibujar arcos de energía
    self:drawEnergyArcs()
    
    -- Dibujar partículas de ionización
    self:drawIonizationParticles()
    
    -- Dibujar núcleo del proyectil
    self:drawHeavyPlasmaCore()
    
    love.graphics.pop()
end

--[[
    Dibuja la distorsión espacial
--]]
function HeavyPlasmaProjectile:drawSpatialDistortion()
    local distortion = self.spatial_distortion
    
    -- Efecto de ondas de distorsión
    for i = 1, 3 do
        local radius = self.config.size * (2 + i) * distortion.strength
        local wave_offset = math.sin(distortion.phase * distortion.frequency + i * 2) * 3
        local alpha = 0.2 / i
        
        love.graphics.setColor(0.6, 0.2, 1, alpha)
        love.graphics.circle("line", 0, 0, radius + wave_offset)
    end
end

--[[
    Dibuja el campo electromagnético
--]]
function HeavyPlasmaProjectile:drawElectromagneticField()
    -- Dibujar pulsos electromagnéticos
    for _, pulse in ipairs(self.electromagnetic_pulses) do
        local alpha = pulse.intensity * 0.4
        love.graphics.setColor(pulse.color[1], pulse.color[2], pulse.color[3], alpha)
        
        -- Anillo de pulso
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", 0, 0, pulse.radius)
        
        -- Efecto de resplandor
        love.graphics.setColor(pulse.color[1], pulse.color[2], pulse.color[3], alpha * 0.3)
        love.graphics.circle("line", 0, 0, pulse.radius * 1.1)
    end
    
    love.graphics.setLineWidth(1) -- Resetear grosor
end

--[[
    Dibuja la estela de plasma
--]]
function HeavyPlasmaProjectile:drawPlasmaTrail()
    if #self.trail_points < 2 then return end
    
    local trail_color = self.config.trail_color
    
    for i = 1, #self.trail_points - 1 do
        local point1 = self.trail_points[i]
        local point2 = self.trail_points[i + 1]
        
        local alpha = math.min(point1.alpha, point2.alpha) * trail_color[4] * self.plasma_intensity
        love.graphics.setColor(trail_color[1], trail_color[2], trail_color[3], alpha)
        
        -- Grosor variable de la estela
        local thickness = 4 + math.sin(self.field_oscillation + i * 0.5) * 2
        love.graphics.setLineWidth(thickness)
        
        -- Convertir a coordenadas locales
        local current_x, current_y = self.body:getPosition()
        local local_x1 = point1.x - current_x
        local local_y1 = point1.y - current_y
        local local_x2 = point2.x - current_x
        local local_y2 = point2.y - current_y
        
        love.graphics.line(local_x1, local_y1, local_x2, local_y2)
        
        -- Estela de resplandor
        love.graphics.setColor(trail_color[1], trail_color[2], trail_color[3], alpha * 0.3)
        love.graphics.setLineWidth(thickness * 2)
        love.graphics.line(local_x1, local_y1, local_x2, local_y2)
    end
    
    love.graphics.setLineWidth(1) -- Resetear grosor
end

--[[
    Dibuja el campo de plasma
--]]
function HeavyPlasmaProjectile:drawPlasmaField()
    local field = self.plasma_field
    local glow_color = self.config.glow_color
    
    -- Campo exterior
    local outer_alpha = (field.intensity + field.fluctuation) * glow_color[4] * 0.3
    love.graphics.setColor(glow_color[1], glow_color[2], glow_color[3], outer_alpha)
    love.graphics.circle("fill", 0, 0, field.outer_radius)
    
    -- Campo intermedio
    local mid_alpha = (field.intensity + field.fluctuation) * glow_color[4] * 0.5
    love.graphics.setColor(glow_color[1] * 1.2, glow_color[2] * 1.2, glow_color[3], mid_alpha)
    love.graphics.circle("fill", 0, 0, field.inner_radius * 1.5)
    
    -- Campo interior
    local inner_alpha = (field.intensity + field.fluctuation) * glow_color[4] * 0.7
    love.graphics.setColor(glow_color[1] * 1.5, glow_color[2] * 1.5, glow_color[3], inner_alpha)
    love.graphics.circle("fill", 0, 0, field.inner_radius)
end

--[[
    Dibuja los arcos de energía
--]]
function HeavyPlasmaProjectile:drawEnergyArcs()
    for _, arc in ipairs(self.energy_arcs) do
        local alpha = (arc.life / arc.max_life) * arc.intensity
        
        love.graphics.setColor(0.9, 0.5, 1, alpha)
        love.graphics.setLineWidth(2)
        
        -- Dibujar líneas del arco
        for i = 1, #arc.points - 1 do
            local p1 = arc.points[i]
            local p2 = arc.points[i + 1]
            
            local x1 = p1.x + p1.offset_x
            local y1 = p1.y + p1.offset_y
            local x2 = p2.x + p2.offset_x
            local y2 = p2.y + p2.offset_y
            
            love.graphics.line(x1, y1, x2, y2)
        end
        
        -- Efecto de resplandor del arco
        love.graphics.setColor(1, 0.8, 1, alpha * 0.5)
        love.graphics.setLineWidth(4)
        
        for i = 1, #arc.points - 1 do
            local p1 = arc.points[i]
            local p2 = arc.points[i + 1]
            
            local x1 = p1.x + p1.offset_x
            local y1 = p1.y + p1.offset_y
            local x2 = p2.x + p2.offset_x
            local y2 = p2.y + p2.offset_y
            
            love.graphics.line(x1, y1, x2, y2)
        end
    end
    
    love.graphics.setLineWidth(1) -- Resetear grosor
end

--[[
    Dibuja las partículas de ionización
--]]
function HeavyPlasmaProjectile:drawIonizationParticles()
    for _, particle in ipairs(self.ionization_particles) do
        local alpha = particle.current_intensity * 0.8
        
        love.graphics.setColor(0.7, 0.3, 1, alpha)
        love.graphics.circle("fill", particle.current_x, particle.current_y, 2)
        
        -- Efecto de resplandor
        love.graphics.setColor(1, 0.6, 1, alpha * 0.5)
        love.graphics.circle("fill", particle.current_x, particle.current_y, 4)
        
        -- Estela de la partícula
        love.graphics.setColor(0.5, 0.2, 0.8, alpha * 0.3)
        love.graphics.circle("fill", particle.current_x, particle.current_y, 6)
    end
end

--[[
    Dibuja el núcleo del proyectil de plasma pesado
--]]
function HeavyPlasmaProjectile:drawHeavyPlasmaCore()
    local color = self.config.color
    local core_color = self.config.core_color
    
    -- Núcleo exterior pulsante
    local outer_size = self.config.size * (1.2 + math.sin(self.core_pulsation) * 0.3)
    love.graphics.setColor(color[1], color[2], color[3], color[4] * self.plasma_intensity)
    love.graphics.circle("fill", 0, 0, outer_size)
    
    -- Núcleo intermedio
    local mid_size = self.config.size * (0.8 + math.sin(self.core_pulsation * 1.5) * 0.2)
    love.graphics.setColor(core_color[1], core_color[2], core_color[3], core_color[4])
    love.graphics.circle("fill", 0, 0, mid_size)
    
    -- Núcleo interior ultra brillante
    local inner_size = self.config.size * (0.4 + math.sin(self.core_pulsation * 2) * 0.1)
    love.graphics.setColor(1, 0.8, 1, 0.9)
    love.graphics.circle("fill", 0, 0, inner_size)
    
    -- Centro de energía pura
    local center_size = self.config.size * 0.2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 0, 0, center_size)
    
    -- Anillos de energía
    for i = 1, 2 do
        local ring_radius = self.config.size * (1.5 + i * 0.5)
        local ring_alpha = 0.4 / i * self.plasma_intensity
        
        love.graphics.setColor(core_color[1], core_color[2], core_color[3], ring_alpha)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, ring_radius)
    end
    
    love.graphics.setLineWidth(1) -- Resetear grosor
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Crea efectos de impacto específicos del plasma pesado
    @param contact: información del contacto
--]]
function HeavyPlasmaProjectile:createImpactEffects(contact)
    -- Llamar al método base
    Projectile.createImpactEffects(self, contact)
    
    -- Añadir efectos específicos del plasma pesado
    local x, y = contact:getPositions()
    
    -- Crear explosión de plasma
    for i = 1, 25 do
        local angle = (i / 25) * math.pi * 2
        local speed = math.random(80, 200)
        local plasma_fragment = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = math.random() * 1.5 + 0.8,
            max_life = 2.3,
            size = math.random() * 4 + 2,
            color = {0.6 + math.random() * 0.3, 0.2, 1, 1},
            intensity = math.random() * 0.5 + 0.5
        }
        
        table.insert(self.visual_effects, plasma_fragment)
    end
    
    -- Crear ondas de choque electromagnéticas
    for i = 1, 3 do
        local shockwave = {
            x = x,
            y = y,
            radius = 0,
            max_radius = self.config.explosion_radius + i * 20,
            life = 1.0 + i * 0.3,
            max_life = 1.3 + i * 0.3,
            intensity = 1.0 / i,
            color = {0.7, 0.3, 1, 0.6 / i}
        }
        
        table.insert(self.visual_effects, shockwave)
    end
    
    -- Crear arcos de energía residuales
    for i = 1, 8 do
        local residual_arc = {
            x = x,
            y = y,
            life = math.random() * 2.0 + 1.0,
            max_life = 3.0,
            length = math.random() * 30 + 20,
            angle = math.random() * math.pi * 2,
            intensity = math.random() * 0.7 + 0.3
        }
        
        table.insert(self.visual_effects, residual_arc)
    end
end

--[[
    Actualiza la estela del proyectil
    @param dt: tiempo delta
--]]
function HeavyPlasmaProjectile:updateTrail(dt)
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

return HeavyPlasmaProjectile