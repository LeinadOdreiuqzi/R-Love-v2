-- src/entities/player_stats.lua

local PlayerStats = {}

function PlayerStats:new(shipConfig)
    local stats = {}
    setmetatable(stats, self)
    self.__index = self
    
    shipConfig = shipConfig or {}
    local maxHealth = shipConfig.maxHealth or 10
    local maxShield = shipConfig.maxShield or 100
    local maxFuel = shipConfig.maxFuel or 100

    -- Casco en puntos. La interfaz deriva los corazones del casco actual.
    stats.health = {
        maxHealth = maxHealth,
        currentHealth = maxHealth
    }

    -- Sistema de escudo
    stats.shield = {
        maxShield = maxShield,
        currentShield = maxShield,
        regenRate = 15,          -- Puntos de escudo por segundo
        regenDelay = 3,          -- Segundos antes de comenzar regeneración
        lastDamageTime = -math.huge,      -- Tiempo del último daño
        isRegenerating = false   -- Estado de regeneración
    }
    
    -- Sistema de combustible
    stats.fuel = {
        maxFuel = maxFuel,
        currentFuel = maxFuel,
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

function PlayerStats:update(dt, isMoving, fuelMultiplier)
    -- Actualizar escudo
    self:updateShield(dt)
    
    -- Consumir combustible si se está moviendo
    if isMoving and not self.debug.infiniteFuel then
        self:consumeFuel(dt, fuelMultiplier)
    end

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

function PlayerStats:consumeFuel(dt, fuelMultiplier)
    if self.fuel.currentFuel > 0 then
        local consumption = self.fuel.consumeRate * self.fuel.efficiency * dt * (fuelMultiplier or 1)
        self.fuel.currentFuel = math.max(0, self.fuel.currentFuel - consumption)
    end
end

function PlayerStats:takeDamage(damage)
    if self.debug.invulnerable or damage <= 0 then
        return false
    end
    if self.health.currentHealth <= 0 then return true end

    local now = love.timer.getTime()
    local shield = self.shield
    local shieldDamage = math.min(shield.currentShield, damage)
    shield.currentShield = shield.currentShield - shieldDamage
    shield.lastDamageTime = now
    shield.isRegenerating = false
    if shieldDamage > 0 then
        shield.lastImpactTime = now
    end

    local hullDamage = damage - shieldDamage
    if hullDamage > 0 then
        self.health.currentHealth = math.max(0, self.health.currentHealth - hullDamage)
        self.health.lastImpactTime = now
    end
    return self.health.currentHealth == 0
end

function PlayerStats:heal(amount)
    self.health.currentHealth = math.min(self.health.maxHealth, self.health.currentHealth + amount)
end

function PlayerStats:addFuel(amount)
    self.fuel.currentFuel = math.min(self.fuel.maxFuel, self.fuel.currentFuel + amount)
end

function PlayerStats:canMove()
    -- Verificar si tiene combustible para moverse
    return self.fuel.currentFuel > 0 or self.debug.infiniteFuel
end

local function percentage(current, maximum)
    if maximum <= 0 then return 0 end
    return math.max(0, math.min(100, current / maximum * 100))
end

function PlayerStats:getHealthPercentage()
    return percentage(self.health.currentHealth, self.health.maxHealth)
end

function PlayerStats:getShieldPercentage()
    return percentage(self.shield.currentShield, self.shield.maxShield)
end

function PlayerStats:getFuelPercentage()
    return percentage(self.fuel.currentFuel, self.fuel.maxFuel)
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
