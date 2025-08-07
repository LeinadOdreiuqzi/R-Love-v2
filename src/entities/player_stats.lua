-- src/entities/player_stats.lua

local PlayerStats = {}

function PlayerStats:new()
    local stats = {}
    setmetatable(stats, self)
    self.__index = self
    
    -- Sistema de vida (corazones)
    stats.health = {
        maxHearts = 5,           -- Máximo de corazones
        currentHearts = 5,       -- Corazones actuales (enteros)
        heartHalves = 0,         -- Medios corazones (0 o 1)
        maxHealth = 10,          -- Vida total (5 corazones * 2 = 10)
        currentHealth = 10       -- Vida actual
    }
    
    -- Sistema de escudo
    stats.shield = {
        maxShield = 100,         -- Escudo máximo
        currentShield = 100,     -- Escudo actual
        regenRate = 15,          -- Puntos de escudo por segundo
        regenDelay = 3,          -- Segundos antes de comenzar regeneración
        lastDamageTime = 0,      -- Tiempo del último daño
        isRegenerating = false   -- Estado de regeneración
    }
    
    -- Sistema de combustible
    stats.fuel = {
        maxFuel = 100,           -- Combustible máximo
        currentFuel = 100,       -- Combustible actual
        consumeRate = 0.5,       -- Consumo por segundo al moverse
        efficiency = 1.0         -- Multiplicador de eficiencia (puede mejorar)
    }
    
    -- Estados de debug
    stats.debug = {
        enabled = false,         -- Debug general activado
        invulnerable = false,    -- Invulnerabilidad
        infiniteFuel = false,    -- Combustible infinito
        fastRegen = false        -- Regeneración rápida de escudo
    }
    
    return stats
end

function PlayerStats:update(dt, isMoving)
    -- Actualizar escudo
    self:updateShield(dt)
    
    -- Consumir combustible si se está moviendo
    if isMoving and not self.debug.infiniteFuel then
        self:consumeFuel(dt)
    end
    
    -- Actualizar corazones basado en vida actual
    self:updateHeartDisplay()
end

function PlayerStats:updateShield(dt)
    local currentTime = love.timer.getTime()
    
    -- Verificar si puede comenzar la regeneración
    if self.shield.currentShield < self.shield.maxShield then
        if currentTime - self.shield.lastDamageTime >= self.shield.regenDelay then
            self.shield.isRegenerating = true
        end
    end
    
    -- Regenerar escudo
    if self.shield.isRegenerating then
        local regenRate = self.shield.regenRate
        
        -- Debug: regeneración rápida
        if self.debug.fastRegen then
            regenRate = regenRate * 5
        end
        
        self.shield.currentShield = math.min(
            self.shield.maxShield, 
            self.shield.currentShield + regenRate * dt
        )
        
        -- Detener regeneración si está lleno
        if self.shield.currentShield >= self.shield.maxShield then
            self.shield.isRegenerating = false
        end
    end
end

function PlayerStats:consumeFuel(dt)
    if self.fuel.currentFuel > 0 then
        local consumption = self.fuel.consumeRate * self.fuel.efficiency * dt
        self.fuel.currentFuel = math.max(0, self.fuel.currentFuel - consumption)
    end
end

function PlayerStats:updateHeartDisplay()
    -- Calcular corazones basado en vida actual
    self.health.currentHearts = math.floor(self.health.currentHealth / 2)
    self.health.heartHalves = self.health.currentHealth % 2
end

function PlayerStats:takeDamage(damage)
    -- Debug: invulnerabilidad
    if self.debug.invulnerable then
        return false
    end
    
    local actualDamage = damage
    
    -- El escudo absorbe el daño primero
    if self.shield.currentShield > 0 then
        local shieldDamage = math.min(self.shield.currentShield, actualDamage)
        self.shield.currentShield = self.shield.currentShield - shieldDamage
        actualDamage = actualDamage - shieldDamage
        
        -- Registrar tiempo de daño para regeneración
        self.shield.lastDamageTime = love.timer.getTime()
        self.shield.isRegenerating = false
    end
    
    -- Si queda daño, afecta la vida
    if actualDamage > 0 then
        self.health.currentHealth = math.max(0, self.health.currentHealth - actualDamage)
        self:updateHeartDisplay()
        
        -- Verificar muerte
        if self.health.currentHealth <= 0 then
            return true -- Jugador murió
        end
    end
    
    return false
end

function PlayerStats:heal(amount)
    self.health.currentHealth = math.min(self.health.maxHealth, self.health.currentHealth + amount)
    self:updateHeartDisplay()
end

function PlayerStats:addFuel(amount)
    self.fuel.currentFuel = math.min(self.fuel.maxFuel, self.fuel.currentFuel + amount)
end

function PlayerStats:canMove()
    -- Verificar si tiene combustible para moverse
    return self.fuel.currentFuel > 0 or self.debug.infiniteFuel
end

function PlayerStats:getHealthPercentage()
    return (self.health.currentHealth / self.health.maxHealth) * 100
end

function PlayerStats:getShieldPercentage()
    return (self.shield.currentShield / self.shield.maxShield) * 100
end

function PlayerStats:getFuelPercentage()
    return (self.fuel.currentFuel / self.fuel.maxFuel) * 100
end

-- Funciones de debug
function PlayerStats:toggleDebugMode()
    self.debug.enabled = not self.debug.enabled
    return self.debug.enabled
end

function PlayerStats:toggleInvulnerability()
    self.debug.invulnerable = not self.debug.invulnerable
    return self.debug.invulnerable
end

function PlayerStats:toggleInfiniteFuel()
    self.debug.infiniteFuel = not self.debug.infiniteFuel
    return self.debug.infiniteFuel
end

function PlayerStats:toggleFastRegen()
    self.debug.fastRegen = not self.debug.fastRegen
    return self.debug.fastRegen
end

return PlayerStats