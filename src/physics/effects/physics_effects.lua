--[[
    Physics Effects - Sistema de Efectos Físicos
    
    Este módulo maneja todos los efectos visuales y físicos relacionados
    con las interacciones en el sistema de física. Incluye partículas,
    explosiones, ondas de choque y otros efectos especiales.
    
    Responsabilidades:
    - Crear y gestionar sistemas de partículas
    - Manejar explosiones y ondas de choque
    - Efectos de impacto y colisión
    - Efectos ambientales (viento, campos magnéticos)
    - Optimización de rendimiento de efectos
--]]

local PhysicsEffects = {}

-- Dependencias
local PhysicsConfig = require('src.physics.config.physics_config')

-- Sistemas de partículas activos
local active_particle_systems = {}
local particle_pools = {}
local effect_queue = {}

-- Contadores y estadísticas
local effect_stats = {
    total_effects_created = 0,
    active_particle_systems = 0,
    particles_per_second = 0,
    last_particle_count = 0,
    last_stats_update = 0
}

-- Tipos de efectos
local EffectType = {
    IMPACT_SPARKS = "impact_sparks",
    EXPLOSION = "explosion",
    SMOKE_TRAIL = "smoke_trail",
    ENERGY_BURST = "energy_burst",
    DEBRIS = "debris",
    SHOCKWAVE = "shockwave",
    MUZZLE_FLASH = "muzzle_flash",
    SHIELD_HIT = "shield_hit",
    DESTRUCTION = "destruction",
    AMBIENT_PARTICLES = "ambient_particles"
}

-- Configuraciones de efectos por defecto
local DefaultEffectConfigs = {
    [EffectType.IMPACT_SPARKS] = {
        particle_count = 15,
        lifetime = 0.8,
        speed_min = 50,
        speed_max = 150,
        size_min = 1,
        size_max = 3,
        colors = {{1, 1, 0.5, 1}, {1, 0.8, 0.2, 1}, {1, 0.5, 0, 1}}
    },
    [EffectType.EXPLOSION] = {
        particle_count = 50,
        lifetime = 2.0,
        speed_min = 100,
        speed_max = 300,
        size_min = 2,
        size_max = 8,
        colors = {{1, 1, 1, 1}, {1, 0.8, 0.4, 1}, {1, 0.4, 0, 1}, {0.5, 0.2, 0, 1}}
    },
    [EffectType.SMOKE_TRAIL] = {
        particle_count = 5,
        lifetime = 1.5,
        speed_min = 10,
        speed_max = 30,
        size_min = 3,
        size_max = 6,
        colors = {{0.8, 0.8, 0.8, 0.8}, {0.6, 0.6, 0.6, 0.6}, {0.4, 0.4, 0.4, 0.4}}
    }
}

--[[
    Inicializa el sistema de efectos físicos
--]]
function PhysicsEffects.initialize()
    -- Inicializar estructuras de datos
    active_particle_systems = {}
    particle_pools = {}
    effect_queue = {}
    
    -- Inicializar pools de partículas para optimización
    PhysicsEffects.initializeParticlePools()
    
    -- Inicializar estadísticas
    effect_stats = {
        total_effects_created = 0,
        active_particle_systems = 0,
        particles_per_second = 0,
        last_particle_count = 0,
        last_stats_update = love.timer.getTime()
    }
    
    print("[PhysicsEffects] Sistema de efectos físicos inicializado")
end

--[[
    Inicializa pools de partículas para optimización
--]]
function PhysicsEffects.initializeParticlePools()
    -- TODO: Implementar pools de partículas para reutilización
    
    for effect_type, config in pairs(DefaultEffectConfigs) do
        particle_pools[effect_type] = {
            available = {},
            in_use = {},
            max_size = config.particle_count * 10 -- Pool 10x más grande que el uso típico
        }
        
        -- Pre-crear partículas en el pool
        for i = 1, particle_pools[effect_type].max_size do
            local particle = PhysicsEffects.createParticle()
            table.insert(particle_pools[effect_type].available, particle)
        end
    end
end

--[[
    Crea una partícula básica
    @return: nueva partícula
--]]
function PhysicsEffects.createParticle()
    -- TODO: Implementar creación de partícula completa
    
    return {
        x = 0,
        y = 0,
        velocity_x = 0,
        velocity_y = 0,
        acceleration_x = 0,
        acceleration_y = 0,
        size = 1,
        size_velocity = 0,
        rotation = 0,
        rotation_velocity = 0,
        color = {1, 1, 1, 1},
        color_velocity = {0, 0, 0, 0},
        lifetime = 1.0,
        age = 0,
        active = false,
        physics_body = nil
    }
end

--[[
    Obtiene una partícula del pool
    @param effect_type: tipo de efecto
    @return: partícula del pool o nueva partícula
--]]
function PhysicsEffects.getParticleFromPool(effect_type)
    local pool = particle_pools[effect_type]
    if not pool then
        return PhysicsEffects.createParticle()
    end
    
    if #pool.available > 0 then
        local particle = table.remove(pool.available)
        table.insert(pool.in_use, particle)
        return particle
    else
        -- Pool vacío, crear nueva partícula
        return PhysicsEffects.createParticle()
    end
end

--[[
    Devuelve una partícula al pool
    @param particle: partícula a devolver
    @param effect_type: tipo de efecto
--]]
function PhysicsEffects.returnParticleToPool(particle, effect_type)
    local pool = particle_pools[effect_type]
    if not pool then
        return
    end
    
    -- Remover de la lista en uso
    for i, p in ipairs(pool.in_use) do
        if p == particle then
            table.remove(pool.in_use, i)
            break
        end
    end
    
    -- Resetear partícula
    particle.active = false
    particle.age = 0
    
    -- Devolver al pool si hay espacio
    if #pool.available < pool.max_size then
        table.insert(pool.available, particle)
    end
end

--[[
    Crea un efecto de impacto
    @param x, y: posición del impacto
    @param velocity_x, velocity_y: velocidad del impacto
    @param intensity: intensidad del efecto (0-1)
    @param effect_type: tipo de efecto (opcional)
--]]
function PhysicsEffects.createImpactEffect(x, y, velocity_x, velocity_y, intensity, effect_type)
    effect_type = effect_type or EffectType.IMPACT_SPARKS
    intensity = intensity or 1.0
    
    -- TODO: Implementar creación de efecto de impacto completo
    
    local config = DefaultEffectConfigs[effect_type]
    if not config then
        print("[PhysicsEffects] Configuración no encontrada para efecto: " .. effect_type)
        return
    end
    
    local particle_system = {
        type = effect_type,
        x = x,
        y = y,
        particles = {},
        lifetime = config.lifetime,
        age = 0,
        active = true
    }
    
    -- Crear partículas
    local particle_count = math.floor(config.particle_count * intensity)
    for i = 1, particle_count do
        local particle = PhysicsEffects.getParticleFromPool(effect_type)
        
        -- Configurar partícula
        particle.x = x + love.math.random(-5, 5)
        particle.y = y + love.math.random(-5, 5)
        
        -- Velocidad basada en el impacto
        local angle = love.math.random() * 2 * math.pi
        local speed = love.math.random(config.speed_min, config.speed_max) * intensity
        particle.velocity_x = math.cos(angle) * speed + velocity_x * 0.3
        particle.velocity_y = math.sin(angle) * speed + velocity_y * 0.3
        
        -- Propiedades visuales
        particle.size = love.math.random(config.size_min, config.size_max)
        particle.size_velocity = -particle.size / config.lifetime
        particle.rotation = love.math.random() * 2 * math.pi
        particle.rotation_velocity = love.math.random(-5, 5)
        
        -- Color aleatorio de la paleta
        local color_index = love.math.random(1, #config.colors)
        particle.color = {unpack(config.colors[color_index])}
        particle.color_velocity = {0, 0, 0, -particle.color[4] / config.lifetime}
        
        particle.lifetime = config.lifetime + love.math.random(-0.2, 0.2)
        particle.age = 0
        particle.active = true
        
        table.insert(particle_system.particles, particle)
    end
    
    table.insert(active_particle_systems, particle_system)
    effect_stats.total_effects_created = effect_stats.total_effects_created + 1
    
    return particle_system
end

--[[
    Crea un efecto de explosión
    @param x, y: posición de la explosión
    @param radius: radio de la explosión
    @param intensity: intensidad de la explosión
--]]
function PhysicsEffects.createExplosionEffect(x, y, radius, intensity)
    intensity = intensity or 1.0
    
    -- TODO: Implementar efecto de explosión completo
    
    -- Crear efecto principal de explosión
    local explosion_effect = PhysicsEffects.createImpactEffect(
        x, y, 0, 0, intensity, EffectType.EXPLOSION)
    
    -- Crear onda de choque
    PhysicsEffects.createShockwaveEffect(x, y, radius, intensity)
    
    -- Crear humo secundario
    love.timer.sleep(0.1) -- Pequeño delay para el humo
    PhysicsEffects.createSmokeEffect(x, y, radius * 0.5, intensity * 0.7)
    
    return explosion_effect
end

--[[
    Crea un efecto de onda de choque
    @param x, y: posición del centro
    @param radius: radio máximo
    @param intensity: intensidad del efecto
--]]
function PhysicsEffects.createShockwaveEffect(x, y, radius, intensity)
    -- TODO: Implementar onda de choque completa
    
    local shockwave = {
        type = EffectType.SHOCKWAVE,
        x = x,
        y = y,
        radius = 0,
        max_radius = radius,
        expansion_speed = radius * 2, -- Se expande en 0.5 segundos
        intensity = intensity,
        lifetime = 1.0,
        age = 0,
        active = true,
        alpha = 1.0
    }
    
    table.insert(active_particle_systems, shockwave)
    
    return shockwave
end

--[[
    Crea un efecto de humo
    @param x, y: posición inicial
    @param radius: área de dispersión
    @param intensity: intensidad del humo
--]]
function PhysicsEffects.createSmokeEffect(x, y, radius, intensity)
    intensity = intensity or 1.0
    
    -- TODO: Implementar efecto de humo completo
    
    return PhysicsEffects.createImpactEffect(
        x, y, 0, -20, intensity, EffectType.SMOKE_TRAIL)
end

--[[
    Crea un rastro de humo para proyectiles
    @param x, y: posición actual
    @param velocity_x, velocity_y: velocidad del proyectil
--]]
function PhysicsEffects.createSmokeTrail(x, y, velocity_x, velocity_y)
    -- TODO: Implementar rastro de humo para proyectiles
    
    local config = DefaultEffectConfigs[EffectType.SMOKE_TRAIL]
    
    -- Crear solo unas pocas partículas para el rastro
    local particle_count = 2
    
    for i = 1, particle_count do
        local particle = PhysicsEffects.getParticleFromPool(EffectType.SMOKE_TRAIL)
        
        -- Posición ligeramente detrás del proyectil
        local offset_x = -velocity_x * 0.01
        local offset_y = -velocity_y * 0.01
        
        particle.x = x + offset_x + love.math.random(-2, 2)
        particle.y = y + offset_y + love.math.random(-2, 2)
        
        -- Velocidad opuesta al movimiento del proyectil
        particle.velocity_x = -velocity_x * 0.1 + love.math.random(-10, 10)
        particle.velocity_y = -velocity_y * 0.1 + love.math.random(-10, 10)
        
        particle.size = love.math.random(config.size_min, config.size_max)
        particle.size_velocity = particle.size / config.lifetime
        
        particle.color = {0.7, 0.7, 0.7, 0.6}
        particle.color_velocity = {0, 0, 0, -0.6 / config.lifetime}
        
        particle.lifetime = config.lifetime
        particle.age = 0
        particle.active = true
        
        -- Crear sistema temporal para esta partícula
        local trail_system = {
            type = EffectType.SMOKE_TRAIL,
            particles = {particle},
            lifetime = config.lifetime,
            age = 0,
            active = true
        }
        
        table.insert(active_particle_systems, trail_system)
    end
end

--[[
    Crea un efecto de destello de boca de cañón
    @param x, y: posición del disparo
    @param angle: ángulo del disparo
    @param intensity: intensidad del destello
--]]
function PhysicsEffects.createMuzzleFlash(x, y, angle, intensity)
    intensity = intensity or 1.0
    
    -- TODO: Implementar destello de boca de cañón completo
    
    local flash_length = 20 * intensity
    local flash_width = 10 * intensity
    
    local muzzle_flash = {
        type = EffectType.MUZZLE_FLASH,
        x = x,
        y = y,
        angle = angle,
        length = flash_length,
        width = flash_width,
        intensity = intensity,
        lifetime = 0.1, -- Muy corto
        age = 0,
        active = true,
        alpha = 1.0
    }
    
    table.insert(active_particle_systems, muzzle_flash)
    
    return muzzle_flash
end

--[[
    Actualiza todos los sistemas de efectos
    @param dt: tiempo delta
--]]
function PhysicsEffects.update(dt)
    -- TODO: Implementar actualización completa de efectos
    
    -- Actualizar sistemas de partículas
    for i = #active_particle_systems, 1, -1 do
        local system = active_particle_systems[i]
        
        if system.active then
            PhysicsEffects.updateParticleSystem(system, dt)
            
            -- Remover sistemas inactivos
            if not system.active then
                PhysicsEffects.cleanupParticleSystem(system)
                table.remove(active_particle_systems, i)
            end
        else
            table.remove(active_particle_systems, i)
        end
    end
    
    -- Actualizar estadísticas
    PhysicsEffects.updateStatistics(dt)
end

--[[
    Actualiza un sistema de partículas específico
    @param system: sistema de partículas
    @param dt: tiempo delta
--]]
function PhysicsEffects.updateParticleSystem(system, dt)
    system.age = system.age + dt
    
    if system.type == EffectType.SHOCKWAVE then
        PhysicsEffects.updateShockwave(system, dt)
    elseif system.type == EffectType.MUZZLE_FLASH then
        PhysicsEffects.updateMuzzleFlash(system, dt)
    else
        PhysicsEffects.updateStandardParticleSystem(system, dt)
    end
    
    -- Verificar si el sistema debe desactivarse
    if system.age >= system.lifetime then
        system.active = false
    end
end

--[[
    Actualiza un sistema de partículas estándar
    @param system: sistema de partículas
    @param dt: tiempo delta
--]]
function PhysicsEffects.updateStandardParticleSystem(system, dt)
    -- TODO: Implementar actualización de partículas completa
    
    for i = #system.particles, 1, -1 do
        local particle = system.particles[i]
        
        if particle.active then
            -- Actualizar edad
            particle.age = particle.age + dt
            
            -- Actualizar posición
            particle.x = particle.x + particle.velocity_x * dt
            particle.y = particle.y + particle.velocity_y * dt
            
            -- Actualizar velocidad (gravedad, resistencia del aire)
            particle.velocity_y = particle.velocity_y + PhysicsConfig.GRAVITY_Y * dt
            particle.velocity_x = particle.velocity_x * 0.98 -- Resistencia del aire
            particle.velocity_y = particle.velocity_y * 0.98
            
            -- Actualizar tamaño
            particle.size = particle.size + particle.size_velocity * dt
            particle.size = math.max(0, particle.size)
            
            -- Actualizar rotación
            particle.rotation = particle.rotation + particle.rotation_velocity * dt
            
            -- Actualizar color
            for j = 1, 4 do
                particle.color[j] = particle.color[j] + particle.color_velocity[j] * dt
                particle.color[j] = math.max(0, math.min(1, particle.color[j]))
            end
            
            -- Verificar si la partícula debe morir
            if particle.age >= particle.lifetime or particle.size <= 0 or particle.color[4] <= 0 then
                particle.active = false
                PhysicsEffects.returnParticleToPool(particle, system.type)
                table.remove(system.particles, i)
            end
        else
            table.remove(system.particles, i)
        end
    end
    
    -- Desactivar sistema si no quedan partículas
    if #system.particles == 0 then
        system.active = false
    end
end

--[[
    Actualiza una onda de choque
    @param shockwave: sistema de onda de choque
    @param dt: tiempo delta
--]]
function PhysicsEffects.updateShockwave(shockwave, dt)
    -- TODO: Implementar actualización de onda de choque
    
    shockwave.radius = shockwave.radius + shockwave.expansion_speed * dt
    shockwave.alpha = 1.0 - (shockwave.age / shockwave.lifetime)
    
    if shockwave.radius >= shockwave.max_radius then
        shockwave.active = false
    end
end

--[[
    Actualiza un destello de boca de cañón
    @param flash: sistema de destello
    @param dt: tiempo delta
--]]
function PhysicsEffects.updateMuzzleFlash(flash, dt)
    flash.alpha = 1.0 - (flash.age / flash.lifetime)
    flash.length = flash.length * (1.0 - dt * 5) -- Se reduce rápidamente
end

--[[
    Limpia un sistema de partículas
    @param system: sistema a limpiar
--]]
function PhysicsEffects.cleanupParticleSystem(system)
    if system.particles then
        for _, particle in ipairs(system.particles) do
            PhysicsEffects.returnParticleToPool(particle, system.type)
        end
    end
end

--[[
    Renderiza todos los efectos activos
--]]
function PhysicsEffects.draw()
    -- TODO: Implementar renderizado completo de efectos
    
    for _, system in ipairs(active_particle_systems) do
        if system.active then
            if system.type == EffectType.SHOCKWAVE then
                PhysicsEffects.drawShockwave(system)
            elseif system.type == EffectType.MUZZLE_FLASH then
                PhysicsEffects.drawMuzzleFlash(system)
            else
                PhysicsEffects.drawParticleSystem(system)
            end
        end
    end
end

--[[
    Renderiza un sistema de partículas estándar
    @param system: sistema de partículas
--]]
function PhysicsEffects.drawParticleSystem(system)
    for _, particle in ipairs(system.particles) do
        if particle.active and particle.size > 0 and particle.color[4] > 0 then
            love.graphics.setColor(particle.color)
            
            love.graphics.push()
            love.graphics.translate(particle.x, particle.y)
            love.graphics.rotate(particle.rotation)
            
            -- Dibujar partícula como círculo
            love.graphics.circle("fill", 0, 0, particle.size)
            
            love.graphics.pop()
        end
    end
end

--[[
    Renderiza una onda de choque
    @param shockwave: sistema de onda de choque
--]]
function PhysicsEffects.drawShockwave(shockwave)
    if shockwave.radius > 0 and shockwave.alpha > 0 then
        love.graphics.setColor(1, 1, 1, shockwave.alpha * 0.5)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", shockwave.x, shockwave.y, shockwave.radius)
        love.graphics.setLineWidth(1)
    end
end

--[[
    Renderiza un destello de boca de cañón
    @param flash: sistema de destello
--]]
function PhysicsEffects.drawMuzzleFlash(flash)
    if flash.alpha > 0 and flash.length > 0 then
        love.graphics.setColor(1, 1, 0.8, flash.alpha)
        
        love.graphics.push()
        love.graphics.translate(flash.x, flash.y)
        love.graphics.rotate(flash.angle)
        
        -- Dibujar forma de destello
        love.graphics.polygon("fill", 
            0, 0,
            flash.length, -flash.width/2,
            flash.length * 0.8, 0,
            flash.length, flash.width/2
        )
        
        love.graphics.pop()
    end
end

--[[
    Actualiza las estadísticas del sistema
    @param dt: tiempo delta
--]]
function PhysicsEffects.updateStatistics(dt)
    local current_time = love.timer.getTime()
    
    if current_time - effect_stats.last_stats_update >= 1.0 then
        local current_particle_count = PhysicsEffects.getTotalParticleCount()
        effect_stats.particles_per_second = current_particle_count - effect_stats.last_particle_count
        effect_stats.last_particle_count = current_particle_count
        effect_stats.last_stats_update = current_time
    end
    
    effect_stats.active_particle_systems = #active_particle_systems
end

--[[
    Obtiene el número total de partículas activas
    @return: número de partículas
--]]
function PhysicsEffects.getTotalParticleCount()
    local count = 0
    for _, system in ipairs(active_particle_systems) do
        if system.particles then
            count = count + #system.particles
        end
    end
    return count
end

--[[
    Obtiene estadísticas del sistema de efectos
    @return: tabla con estadísticas
--]]
function PhysicsEffects.getStatistics()
    return {
        total_effects_created = effect_stats.total_effects_created,
        active_particle_systems = effect_stats.active_particle_systems,
        total_particles = PhysicsEffects.getTotalParticleCount(),
        particles_per_second = effect_stats.particles_per_second
    }
end

--[[
    Renderiza información de debug
--]]
function PhysicsEffects.drawDebug()
    if not PhysicsConfig.DEBUG_DRAW_ENABLED then
        return
    end
    
    local stats = PhysicsEffects.getStatistics()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Sistemas de efectos: " .. stats.active_particle_systems, 10, 100)
    love.graphics.print("Partículas totales: " .. stats.total_particles, 10, 115)
    love.graphics.print("Efectos creados: " .. stats.total_effects_created, 10, 130)
end

--[[
    Limpia todos los efectos activos
--]]
function PhysicsEffects.clearAllEffects()
    for _, system in ipairs(active_particle_systems) do
        PhysicsEffects.cleanupParticleSystem(system)
    end
    
    active_particle_systems = {}
end

--[[
    Limpia el sistema de efectos
--]]
function PhysicsEffects.cleanup()
    PhysicsEffects.clearAllEffects()
    
    particle_pools = {}
    effect_queue = {}
    
    effect_stats = {
        total_effects_created = 0,
        active_particle_systems = 0,
        particles_per_second = 0,
        last_particle_count = 0,
        last_stats_update = 0
    }
    
    print("[PhysicsEffects] Sistema de efectos físicos limpiado")
end

-- Exportar tipos para uso externo
PhysicsEffects.Type = EffectType

return PhysicsEffects