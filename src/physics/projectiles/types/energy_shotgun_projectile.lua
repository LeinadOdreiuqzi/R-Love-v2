--[[
    EnergyShotgunProjectile - Proyectil de Escopeta de Energía
    
    Proyectil de energía que se dispersa en múltiples fragmentos.
    Hereda de la clase base Projectile y añade características de dispersión.
    
    Características:
    - Color energía azul/blanco brillante
    - Se fragmenta en múltiples proyectiles menores
    - Patrón de dispersión tipo escopeta
    - Efectos de energía eléctrica
    - Menor daño individual pero mayor cobertura
--]]

local Projectile = require('src.physics.projectiles.projectile')
local EnergyShotgunProjectile = {}
EnergyShotgunProjectile.__index = EnergyShotgunProjectile
setmetatable(EnergyShotgunProjectile, {__index = Projectile})

-- Configuración específica del proyectil de escopeta de energía
local ENERGY_SHOTGUN_CONFIG = {
    type = "energy_shotgun",
    damage = 15, -- Daño moderado por fragmento
    speed = 1600, -- Velocidad alta inicial
    lifetime = 2.5, -- Tiempo de vida antes de fragmentación
    max_distance = 1200,
    size = 1.2, -- Tamaño moderado
    color = {0.3, 0.7, 1, 1}, -- Azul energético
    core_color = {0.8, 0.9, 1, 1}, -- Núcleo azul claro
    trail_color = {0.2, 0.5, 0.9, 0.8}, -- Estela azul
    glow_color = {0.4, 0.8, 1, 0.6}, -- Resplandor azul
    particle_count = 8, -- Partículas moderadas
    trail_length = 10, -- Estela media
    fragment_count = 6, -- Número de fragmentos
    spread_angle = math.pi / 4, -- Ángulo de dispersión (45 grados)
    fragment_speed_factor = 0.7, -- Factor de velocidad de fragmentos
    fragmentation_distance = 800 -- Distancia antes de fragmentar
}

--[[
    Constructor del proyectil de escopeta de energía
    @param world: mundo Box2D
    @param x, y: posición inicial
    @param angle: ángulo de disparo en radianes
    @param speed: velocidad inicial (opcional)
    @param custom_config: configuración personalizada (opcional)
    @return: nueva instancia de EnergyShotgunProjectile
--]]
function EnergyShotgunProjectile.new(world, x, y, angle, speed, custom_config)
    -- Combinar configuración por defecto con personalizada
    local config = {}
    for k, v in pairs(ENERGY_SHOTGUN_CONFIG) do
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
    setmetatable(self, EnergyShotgunProjectile)
    
    -- Propiedades específicas del proyectil de escopeta de energía
    self.energy_charge = 1.0
    self.electrical_arcs = {}
    self.charge_buildup = 0
    self.fragmentation_timer = 0
    self.has_fragmented = false
    self.fragments = {}
    self.energy_field = {}
    self.discharge_particles = {}
    self.instability_factor = 0
    self.travel_distance = 0
    
    -- Inicializar trail points para efectos de estela
    self.trail_points = {}
    self.max_trail_points = config.trail_length
    
    -- Inicializar efectos específicos del proyectil de escopeta de energía
    self:initializeEnergyShotgunEffects()
    
    return self
end

--[[
    Inicializa los efectos visuales específicos del proyectil de escopeta de energía
--]]
function EnergyShotgunProjectile:initializeEnergyShotgunEffects()
    -- Configurar campo de energía
    self.energy_field = {
        intensity = 1.0,
        fluctuation = 0,
        radius = self.config.size * 2
    }
    
    -- Configurar arcos eléctricos
    self.electrical_arcs = {}
    
    -- Configurar partículas de descarga
    self.discharge_particles = {}
    
    -- Inicializar carga de energía
    self.energy_charge = 1.0
end

--[[
    Actualiza el proyectil de escopeta de energía
    @param dt: tiempo delta
--]]
function EnergyShotgunProjectile:update(dt)
    -- Llamar al update de la clase base
    Projectile.update(self, dt)
    
    if self.state == Projectile.State.DESTROYED then
        return
    end
    
    -- Actualizar distancia recorrida
    if self.body then
        local vx, vy = self.body:getLinearVelocity()
        local speed = math.sqrt(vx * vx + vy * vy)
        self.travel_distance = self.travel_distance + speed * dt
    end
    
    -- Verificar si debe fragmentarse
    if not self.has_fragmented and self.travel_distance >= self.config.fragmentation_distance then
        self:fragmentProjectile()
    end
    
    -- Actualizar estela del proyectil
    self:updateTrail(dt)
    
    -- Actualizar efectos específicos del proyectil de escopeta de energía
    self:updateEnergyShotgunEffects(dt)
    
    -- Actualizar arcos eléctricos
    self:updateElectricalArcs(dt)
    
    -- Actualizar partículas de descarga
    self:updateDischargeParticles(dt)
    
    -- Actualizar fragmentos si existen
    self:updateFragments(dt)
end

--[[
    Actualiza los efectos visuales específicos del proyectil de escopeta de energía
    @param dt: tiempo delta
--]]
function EnergyShotgunProjectile:updateEnergyShotgunEffects(dt)
    -- Actualizar acumulación de carga
    self.charge_buildup = self.charge_buildup + dt * 10.0
    
    -- Actualizar factor de inestabilidad (aumenta con el tiempo)
    self.instability_factor = math.min(1.0, self.travel_distance / self.config.fragmentation_distance)
    
    -- Fluctuación del campo de energía
    self.energy_field.fluctuation = math.sin(self.charge_buildup) * 0.4 * self.instability_factor
    self.energy_field.intensity = 1.0 + self.instability_factor * 0.5
    
    -- Crear arcos eléctricos con mayor frecuencia cerca de la fragmentación
    local arc_probability = 0.1 + self.instability_factor * 0.3
    if math.random() < arc_probability then
        self:createElectricalArc()
    end
    
    -- Crear partículas de descarga
    if math.random() < 0.2 then
        self:createDischargeParticle()
    end
    
    -- Limitar número de efectos
    while #self.electrical_arcs > 8 do
        table.remove(self.electrical_arcs, 1)
    end
    
    while #self.discharge_particles > 12 do
        table.remove(self.discharge_particles, 1)
    end
end

--[[
    Actualiza los arcos eléctricos
    @param dt: tiempo delta
--]]
function EnergyShotgunProjectile:updateElectricalArcs(dt)
    for i = #self.electrical_arcs, 1, -1 do
        local arc = self.electrical_arcs[i]
        
        arc.life = arc.life - dt
        
        -- Actualizar puntos del arco para efecto de chisporroteo
        for _, point in ipairs(arc.points) do
            point.offset_x = point.offset_x + (math.random() - 0.5) * 30 * dt
            point.offset_y = point.offset_y + (math.random() - 0.5) * 30 * dt
            
            -- Limitar desplazamiento
            point.offset_x = math.max(-8, math.min(8, point.offset_x))
            point.offset_y = math.max(-8, math.min(8, point.offset_y))
        end
        
        if arc.life <= 0 then
            table.remove(self.electrical_arcs, i)
        end
    end
end

--[[
    Actualiza las partículas de descarga
    @param dt: tiempo delta
--]]
function EnergyShotgunProjectile:updateDischargeParticles(dt)
    for i = #self.discharge_particles, 1, -1 do
        local particle = self.discharge_particles[i]
        
        -- Actualizar posición
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        
        -- Aplicar resistencia
        particle.vx = particle.vx * 0.95
        particle.vy = particle.vy * 0.95
        
        -- Actualizar vida
        particle.life = particle.life - dt
        
        if particle.life <= 0 then
            table.remove(self.discharge_particles, i)
        end
    end
end

--[[
    Actualiza los fragmentos
    @param dt: tiempo delta
--]]
function EnergyShotgunProjectile:updateFragments(dt)
    for i = #self.fragments, 1, -1 do
        local fragment = self.fragments[i]
        
        -- Actualizar posición
        fragment.x = fragment.x + fragment.vx * dt
        fragment.y = fragment.y + fragment.vy * dt
        
        -- Actualizar vida
        fragment.life = fragment.life - dt
        
        -- Actualizar efectos visuales del fragmento
        fragment.trail_alpha = fragment.trail_alpha - dt * 2.0
        fragment.glow_intensity = 0.8 + math.sin(fragment.phase) * 0.2
        fragment.phase = fragment.phase + dt * 15.0
        
        if fragment.life <= 0 or fragment.trail_alpha <= 0 then
            table.remove(self.fragments, i)
        end
    end
end

--[[
    Fragmenta el proyectil en múltiples proyectiles menores
--]]
function EnergyShotgunProjectile:fragmentProjectile()
    if self.has_fragmented or not self.body then
        return
    end
    
    self.has_fragmented = true
    local x, y = self.body:getPosition()
    local base_angle = self.body:getAngle()
    local base_speed = self.config.speed * self.config.fragment_speed_factor
    
    -- Crear fragmentos
    for i = 1, self.config.fragment_count do
        -- Calcular ángulo de dispersión
        local spread_offset = (i - (self.config.fragment_count + 1) / 2) / self.config.fragment_count
        local fragment_angle = base_angle + spread_offset * self.config.spread_angle
        
        -- Añadir variación aleatoria
        fragment_angle = fragment_angle + (math.random() - 0.5) * 0.2
        
        -- Calcular velocidad del fragmento
        local speed_variation = 0.8 + math.random() * 0.4 -- 80% - 120% de velocidad base
        local fragment_speed = base_speed * speed_variation
        
        local fragment = {
            x = x,
            y = y,
            vx = math.cos(fragment_angle) * fragment_speed,
            vy = math.sin(fragment_angle) * fragment_speed,
            angle = fragment_angle,
            life = 1.5 + math.random() * 0.5, -- 1.5 - 2.0 segundos
            max_life = 2.0,
            size = self.config.size * 0.6, -- Fragmentos más pequeños
            damage = self.config.damage * 0.8, -- Daño reducido por fragmento
            trail_alpha = 1.0,
            glow_intensity = 1.0,
            phase = math.random() * math.pi * 2,
            color = {
                self.config.color[1] + math.random() * 0.2 - 0.1,
                self.config.color[2] + math.random() * 0.2 - 0.1,
                self.config.color[3],
                self.config.color[4]
            }
        }
        
        table.insert(self.fragments, fragment)
    end
    
    -- Crear efectos de fragmentación
    self:createFragmentationEffects(x, y)
    
    -- Destruir el proyectil principal
    self:destroy()
end

--[[
    Crea efectos de fragmentación
    @param x, y: posición de la fragmentación
--]]
function EnergyShotgunProjectile:createFragmentationEffects(x, y)
    -- Crear explosión de energía
    for i = 1, 20 do
        local angle = (i / 20) * math.pi * 2
        local speed = math.random(50, 150)
        local energy_burst = {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = math.random() * 0.8 + 0.4,
            max_life = 1.2,
            size = math.random() * 3 + 1,
            color = {0.3, 0.7, 1, 1},
            intensity = math.random() * 0.5 + 0.5
        }
        
        table.insert(self.visual_effects, energy_burst)
    end
    
    -- Crear ondas de choque eléctrico
    for i = 1, 3 do
        local shockwave = {
            x = x,
            y = y,
            radius = 0,
            max_radius = 40 + i * 15,
            life = 0.8,
            max_life = 0.8,
            intensity = 1.0 / i,
            color = {0.4, 0.8, 1, 0.5 / i}
        }
        
        table.insert(self.visual_effects, shockwave)
    end
end

--[[
    Crea un arco eléctrico
--]]
function EnergyShotgunProjectile:createElectricalArc()
    local arc = {
        life = math.random() * 0.2 + 0.1,
        max_life = 0.3,
        intensity = math.random() * 0.5 + 0.5,
        points = {}
    }
    
    -- Crear puntos del arco
    local num_points = math.random(3, 6)
    for i = 1, num_points do
        local angle = math.random() * math.pi * 2
        local distance = math.random() * self.config.size * 2.5
        
        table.insert(arc.points, {
            x = math.cos(angle) * distance,
            y = math.sin(angle) * distance,
            offset_x = 0,
            offset_y = 0
        })
    end
    
    table.insert(self.electrical_arcs, arc)
end

--[[
    Crea una partícula de descarga
--]]
function EnergyShotgunProjectile:createDischargeParticle()
    if not self.body then return end
    
    local x, y = self.body:getPosition()
    local particle = {
        x = x + (math.random() - 0.5) * 6,
        y = y + (math.random() - 0.5) * 6,
        vx = (math.random() - 0.5) * 80,
        vy = (math.random() - 0.5) * 80,
        life = math.random() * 0.4 + 0.2,
        max_life = 0.6,
        size = math.random() * 1.5 + 0.5,
        brightness = math.random() * 0.5 + 0.5
    }
    
    table.insert(self.discharge_particles, particle)
end

--[[
    Dibuja el proyectil de escopeta de energía
--]]
function EnergyShotgunProjectile:draw()
    if self.state == Projectile.State.DESTROYED then
        -- Dibujar fragmentos si existen
        self:drawFragments()
        return
    end
    
    if not self.body then return end
    
    local x, y = self.body:getPosition()
    local angle = self.body:getAngle()
    
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Dibujar campo de energía
    self:drawEnergyField()
    
    -- Dibujar arcos eléctricos
    self:drawElectricalArcs()
    
    -- Dibujar estela de energía
    self:drawEnergyTrail()
    
    -- Dibujar partículas de descarga
    self:drawDischargeParticles()
    
    -- Dibujar núcleo del proyectil
    self:drawEnergyShotgunCore()
    
    love.graphics.pop()
    
    -- Dibujar fragmentos si existen
    self:drawFragments()
end

--[[
    Dibuja el campo de energía
--]]
function EnergyShotgunProjectile:drawEnergyField()
    local field = self.energy_field
    local glow_color = self.config.glow_color
    
    -- Campo de energía con fluctuación
    local field_radius = field.radius * (field.intensity + field.fluctuation)
    local alpha = glow_color[4] * (0.3 + self.instability_factor * 0.4)
    
    love.graphics.setColor(glow_color[1], glow_color[2], glow_color[3], alpha)
    love.graphics.circle("fill", 0, 0, field_radius)
    
    -- Anillos de inestabilidad
    if self.instability_factor > 0.3 then
        for i = 1, 2 do
            local ring_radius = field_radius * (1 + i * 0.3)
            local ring_alpha = alpha * 0.5 / i
            
            love.graphics.setColor(glow_color[1], glow_color[2], glow_color[3], ring_alpha)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", 0, 0, ring_radius)
        end
        
        love.graphics.setLineWidth(1) -- Resetear grosor
    end
end

--[[
    Dibuja los arcos eléctricos
--]]
function EnergyShotgunProjectile:drawElectricalArcs()
    for _, arc in ipairs(self.electrical_arcs) do
        local alpha = (arc.life / arc.max_life) * arc.intensity
        
        love.graphics.setColor(0.8, 0.9, 1, alpha)
        love.graphics.setLineWidth(1.5)
        
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
        love.graphics.setColor(1, 1, 1, alpha * 0.6)
        love.graphics.setLineWidth(3)
        
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
    Dibuja la estela de energía
--]]
function EnergyShotgunProjectile:drawEnergyTrail()
    if #self.trail_points < 2 then return end
    
    local trail_color = self.config.trail_color
    
    for i = 1, #self.trail_points - 1 do
        local point1 = self.trail_points[i]
        local point2 = self.trail_points[i + 1]
        
        local alpha = math.min(point1.alpha, point2.alpha) * trail_color[4]
        love.graphics.setColor(trail_color[1], trail_color[2], trail_color[3], alpha)
        
        -- Grosor variable basado en inestabilidad
        local thickness = 2 + self.instability_factor * 3
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
    Dibuja las partículas de descarga
--]]
function EnergyShotgunProjectile:drawDischargeParticles()
    for _, particle in ipairs(self.discharge_particles) do
        local alpha = (particle.life / particle.max_life)
        local brightness = particle.brightness * alpha
        
        love.graphics.setColor(0.6, 0.8, 1, alpha)
        
        -- Convertir a coordenadas locales
        local current_x, current_y = self.body:getPosition()
        local local_x = particle.x - current_x
        local local_y = particle.y - current_y
        
        love.graphics.circle("fill", local_x, local_y, particle.size * alpha)
        
        -- Efecto de brillo adicional
        love.graphics.setColor(1, 1, 1, alpha * 0.7)
        love.graphics.circle("fill", local_x, local_y, particle.size * alpha * 0.5)
    end
end

--[[
    Dibuja el núcleo del proyectil de escopeta de energía
--]]
function EnergyShotgunProjectile:drawEnergyShotgunCore()
    local color = self.config.color
    local core_color = self.config.core_color
    
    -- Núcleo exterior con inestabilidad
    local outer_size = self.config.size * (1.0 + self.instability_factor * 0.5)
    love.graphics.setColor(color[1], color[2], color[3], color[4])
    love.graphics.circle("fill", 0, 0, outer_size)
    
    -- Núcleo intermedio
    local mid_size = self.config.size * 0.7
    love.graphics.setColor(core_color[1], core_color[2], core_color[3], core_color[4])
    love.graphics.circle("fill", 0, 0, mid_size)
    
    -- Núcleo interior brillante
    local inner_size = self.config.size * 0.4
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", 0, 0, inner_size)
    
    -- Indicadores de inestabilidad
    if self.instability_factor > 0.5 then
        love.graphics.setColor(1, 0.8, 0.8, self.instability_factor * 0.6)
        love.graphics.setLineWidth(2)
        
        for i = 1, 4 do
            local line_angle = (i / 4) * math.pi * 2 + self.charge_buildup
            local line_length = self.config.size * 1.5
            local x1 = math.cos(line_angle) * line_length * 0.5
            local y1 = math.sin(line_angle) * line_length * 0.5
            local x2 = math.cos(line_angle) * line_length
            local y2 = math.sin(line_angle) * line_length
            love.graphics.line(x1, y1, x2, y2)
        end
        
        love.graphics.setLineWidth(1) -- Resetear grosor
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Dibuja los fragmentos
--]]
function EnergyShotgunProjectile:drawFragments()
    for _, fragment in ipairs(self.fragments) do
        love.graphics.push()
        love.graphics.translate(fragment.x, fragment.y)
        love.graphics.rotate(fragment.angle)
        
        -- Resplandor del fragmento
        local glow_alpha = fragment.trail_alpha * fragment.glow_intensity * 0.4
        love.graphics.setColor(fragment.color[1], fragment.color[2], fragment.color[3], glow_alpha)
        love.graphics.circle("fill", 0, 0, fragment.size * 2)
        
        -- Núcleo del fragmento
        love.graphics.setColor(fragment.color[1], fragment.color[2], fragment.color[3], fragment.trail_alpha)
        love.graphics.circle("fill", 0, 0, fragment.size)
        
        -- Centro brillante
        love.graphics.setColor(1, 1, 1, fragment.trail_alpha * 0.8)
        love.graphics.circle("fill", 0, 0, fragment.size * 0.5)
        
        love.graphics.pop()
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Actualiza la estela del proyectil
    @param dt: tiempo delta
--]]
function EnergyShotgunProjectile:updateTrail(dt)
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

return EnergyShotgunProjectile