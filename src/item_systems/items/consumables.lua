-- Items Consumibles para Space Roguelike
-- Items que se usan una vez y proporcionan efectos temporales o permanentes

local ItemSystem = require("src.item_systems.item_system")

local Consumables = {}

-- Efectos base para consumibles
local Effects = {
    -- Curación
    heal = function(player, amount)
        if not player then return "No se pudo curar" end
        if type(player.heal) == "function" then
            local oldHealth = (player.stats and type(player.stats.health) == "table" and player.stats.health.currentHealth) or 0
            player:heal(amount)
            local newHealth = (player.stats and type(player.stats.health) == "table" and player.stats.health.currentHealth) or (oldHealth + amount)
            return string.format("Curado %d puntos de vida", math.max(0, newHealth - oldHealth))
        elseif player.stats then
            if type(player.stats.heal) == "function" and type(player.stats.health) == "table" then
                local oldHealth = player.stats.health.currentHealth or 0
                player.stats:heal(amount)
                local healed = (player.stats.health.currentHealth or 0) - oldHealth
                return string.format("Curado %d puntos de vida", healed)
            elseif type(player.stats.health) == "table" then
                local oldHealth = player.stats.health.currentHealth or 0
                local maxHealth = player.stats.health.maxHealth or 100
                player.stats.health.currentHealth = math.min(oldHealth + amount, maxHealth)
                if player.stats.updateHeartDisplay then
                    player.stats:updateHeartDisplay()
                end
                local healed = player.stats.health.currentHealth - oldHealth
                return string.format("Curado %d puntos de vida", healed)
            elseif type(player.stats.health) == "number" then
                local oldHealth = player.stats.health
                player.stats.health = math.min(player.stats.health + amount, player.stats.maxHealth or 100)
                local healed = player.stats.health - oldHealth
                return string.format("Curado %d puntos de vida", healed)
            end
        end
        return "No se pudo curar"
    end,
    
    -- Restaurar escudo
    restoreShield = function(player, amount)
        if player and player.stats and type(player.stats.shield) == "table" then
            local oldShield = player.stats.shield.currentShield or 0
            local maxShield = player.stats.shield.maxShield or 100
            player.stats.shield.currentShield = math.min(maxShield, oldShield + amount)
            local restored = player.stats.shield.currentShield - oldShield
            return string.format("Restaurado %d puntos de escudo", restored)
        end
        return "No se pudo restaurar escudo"
    end,
    
    -- Restaurar energía (o escudo/combustible como respaldo)
    restoreEnergy = function(player, amount)
        if not player or not player.stats then
            return "No se pudo restaurar energía"
        end
        if type(player.stats.energy) == "table" then
            local oldEnergy = player.stats.energy.currentEnergy or 0
            local maxEnergy = player.stats.energy.maxEnergy or 100
            player.stats.energy.currentEnergy = math.min(oldEnergy + amount, maxEnergy)
            local restored = player.stats.energy.currentEnergy - oldEnergy
            return string.format("Restaurado %d puntos de energía", restored)
        elseif type(player.stats.energy) == "number" then
            local oldEnergy = player.stats.energy
            player.stats.energy = math.min(player.stats.energy + amount, player.stats.maxEnergy or 100)
            local restored = player.stats.energy - oldEnergy
            return string.format("Restaurado %d puntos de energía", restored)
        elseif type(player.stats.shield) == "table" then
            local oldShield = player.stats.shield.currentShield or 0
            local maxShield = player.stats.shield.maxShield or 100
            player.stats.shield.currentShield = math.min(maxShield, oldShield + amount)
            local restored = player.stats.shield.currentShield - oldShield
            return string.format("Restaurado %d puntos de energía de escudo", restored)
        end
        return "No se pudo restaurar energía"
    end,
    
    -- Aumentar estadística temporalmente
    tempBoost = function(player, stat, amount, duration)
        if not player.tempEffects then
            player.tempEffects = {}
        end
        
        local effect = {
            type = "stat_boost",
            stat = stat,
            amount = amount,
            duration = duration,
            timeLeft = duration
        }
        
        table.insert(player.tempEffects, effect)
        return string.format("%s aumentado en %d por %d segundos", stat, amount, duration)
    end,
    
    -- Curar completamente
    fullHeal = function(player)
        if player and player.stats and player.stats.health then
            if type(player.stats.health) == "table" then
                local maxH = player.stats.health.maxHealth or 100
                if type(player.heal) == "function" then
                    player:heal(maxH)
                elseif type(player.stats.heal) == "function" then
                    player.stats:heal(maxH)
                else
                    player.stats.health.currentHealth = maxH
                    if player.stats.updateHeartDisplay then
                        player.stats:updateHeartDisplay()
                    end
                end
            elseif type(player.stats.health) == "number" then
                player.stats.health = player.stats.maxHealth or 100
            end
            if type(player.stats.shield) == "table" then
                player.stats.shield.currentShield = player.stats.shield.maxShield or 100
            end
            if type(player.stats.energy) == "table" then
                player.stats.energy.currentEnergy = player.stats.energy.maxEnergy or 100
            elseif type(player.stats.energy) == "number" then
                player.stats.energy = player.stats.maxEnergy or 100
            end
            return "Completamente curado"
        end
        return "No se pudo curar"
    end,
    
    -- Aumentar máximo de vida permanentemente
    increaseMaxHealth = function(player, amount)
        if player and player.stats then
            if type(player.stats.health) == "table" then
                player.stats.health.maxHealth = (player.stats.health.maxHealth or 10) + amount
                player.stats.health.currentHealth = math.min(
                    player.stats.health.maxHealth,
                    (player.stats.health.currentHealth or 10) + amount
                )
                player.stats.health.maxHearts = math.ceil(player.stats.health.maxHealth / 2)
                if player.stats.updateHeartDisplay then
                    player.stats:updateHeartDisplay()
                end
            else
                player.stats.maxHealth = (player.stats.maxHealth or 100) + amount
                player.stats.health = (player.stats.health or 100) + amount
            end
            return string.format("Vida máxima aumentada en %d", amount)
        end
        return "No se pudo aumentar vida máxima"
    end
}

-- Función para registrar todos los consumibles
function Consumables.registerAll()
    -- Kit de Reparación EVA (ya existente)
    ItemSystem:registerItem({
        id = "eva_repair_kit",
        name = "Kit de Reparación EVA",
        description = "Un kit médico especializado para reparaciones de emergencia en el espacio. Cura 25 puntos de vida.",
        category = ItemSystem.CATEGORIES.CONSUMABLE,
        rarity = ItemSystem.RARITY.COMMON,
        stackable = true,
        maxStack = 5,
        value = 50,
        weight = 0.5,
        icon = "eva_repair_kit",
        tags = {"medical", "eva", "healing"},
        
        canUse = function(self, player)
            if player and player.stats and type(player.stats.health) == "table" then
                return player.stats.health.currentHealth < player.stats.health.maxHealth
            end
            return true
        end,
        use = function(self, player)
            return Effects.heal(player, 25)
        end
    })
    
    -- Estimulante de Energía
    ItemSystem:registerItem({
        id = "energy_stim",
        name = "Estimulante de Energía",
        description = "Un estimulante que restaura 40 puntos de energía instantáneamente.",
        category = ItemSystem.CATEGORIES.CONSUMABLE,
        rarity = ItemSystem.RARITY.COMMON,
        stackable = true,
        maxStack = 10,
        value = 30,
        weight = 0.2,
        icon = "energy_stim",
        tags = {"energy", "stimulant"},
        
        canUse = function(self, player)
            if player and player.stats and type(player.stats.shield) == "table" and not player.stats.energy then
                return player.stats.shield.currentShield < player.stats.shield.maxShield
            end
            return true
        end,
        use = function(self, player)
            return Effects.restoreEnergy(player, 40)
        end
    })
    
    -- Nanobots Médicos
    ItemSystem:registerItem({
        id = "medical_nanobots",
        name = "Nanobots Médicos",
        description = "Nanobots avanzados que curan completamente al usuario.",
        category = ItemSystem.CATEGORIES.CONSUMABLE,
        rarity = ItemSystem.RARITY.RARE,
        stackable = true,
        maxStack = 3,
        value = 200,
        weight = 0.1,
        icon = "medical_nanobots",
        tags = {"medical", "nanotech", "full_heal"},
        
        canUse = function(self, player)
            if player and player.stats and type(player.stats.health) == "table" then
                return player.stats.health.currentHealth < player.stats.health.maxHealth
            end
            return true
        end,
        use = function(self, player)
            return Effects.fullHeal(player)
        end
    })
    
    -- Suero de Mejora Genética
    ItemSystem:registerItem({
        id = "genetic_enhancement_serum",
        name = "Suero de Mejora Genética",
        description = "Un suero experimental que aumenta permanentemente la vida máxima en 10 puntos.",
        category = ItemSystem.CATEGORIES.CONSUMABLE,
        rarity = ItemSystem.RARITY.EPIC,
        stackable = true,
        maxStack = 2,
        value = 500,
        weight = 0.3,
        icon = "genetic_serum",
        tags = {"genetic", "permanent", "enhancement"},
        
        use = function(self, player)
            return Effects.increaseMaxHealth(player, 10)
        end
    })
    
    -- Estimulante de Combate
    ItemSystem:registerItem({
        id = "combat_stim",
        name = "Estimulante de Combate",
        description = "Aumenta temporalmente la velocidad de movimiento y precisión por 30 segundos.",
        category = ItemSystem.CATEGORIES.CONSUMABLE,
        rarity = ItemSystem.RARITY.UNCOMMON,
        stackable = true,
        maxStack = 5,
        value = 75,
        weight = 0.2,
        icon = "combat_stim",
        tags = {"combat", "temporary", "boost"},
        
        use = function(self, player)
            local result1 = Effects.tempBoost(player, "speed", 25, 30)
            local result2 = Effects.tempBoost(player, "accuracy", 15, 30)
            return result1 .. " y " .. result2
        end
    })
    
    -- Ración de Emergencia
    ItemSystem:registerItem({
        id = "emergency_ration",
        name = "Ración de Emergencia",
        description = "Una ración nutritiva que restaura 15 puntos de vida y 20 de energía.",
        category = ItemSystem.CATEGORIES.CONSUMABLE,
        rarity = ItemSystem.RARITY.COMMON,
        stackable = true,
        maxStack = 20,
        value = 25,
        weight = 0.3,
        icon = "emergency_ration",
        tags = {"food", "basic", "survival"},
        
        use = function(self, player)
            local heal_result = Effects.heal(player, 15)
            local energy_result = Effects.restoreEnergy(player, 20)
            return heal_result .. " y " .. energy_result
        end
    })
    
    -- Antídoto Universal
    ItemSystem:registerItem({
        id = "universal_antidote",
        name = "Antídoto Universal",
        description = "Cura todos los efectos negativos y restaura 20 puntos de vida.",
        category = ItemSystem.CATEGORIES.CONSUMABLE,
        rarity = ItemSystem.RARITY.UNCOMMON,
        stackable = true,
        maxStack = 5,
        value = 100,
        weight = 0.2,
        icon = "universal_antidote",
        tags = {"medical", "antidote", "cure"},
        
        use = function(self, player)
            -- Limpiar efectos negativos
            if player.tempEffects then
                for i = #player.tempEffects, 1, -1 do
                    local effect = player.tempEffects[i]
                    if effect.type == "debuff" or effect.negative then
                        table.remove(player.tempEffects, i)
                    end
                end
            end
            
            local heal_result = Effects.heal(player, 20)
            return "Efectos negativos eliminados. " .. heal_result
        end
    })
    
    -- Kit de Reparación
    ItemSystem:registerItem({
        id = "repair_kit",
        name = "Kit de Reparación",
        description = "Restaura 50 puntos de vida de la nave.",
        category = ItemSystem.CATEGORIES.CONSUMABLE,
        rarity = ItemSystem.RARITY.COMMON,
        stackable = true,
        maxStack = 10,
        value = 50,
        weight = 0.5,
        icon = "repair_kit",
        tags = {"repair", "healing", "ship"},
        
        canUse = function(self, player)
            if player and player.stats and type(player.stats.health) == "table" then
                return player.stats.health.currentHealth < player.stats.health.maxHealth
            end
            return true
        end,
        use = function(self, player)
            local heal_result = Effects.heal(player, 50)
            return "Nave reparada. " .. heal_result
        end
    })
    
    print("Items consumibles registrados: 8 items")
end

return Consumables