-- Items Pasivos para Space Roguelike
-- Items que otorgan efectos permanentes mientras están en el inventario

local ItemSystem = require("src.item_systems.item_system")

local Passives = {}

-- Modificadores base para items pasivos
local Modifiers = {
    -- Modificadores de estadísticas
    statModifier = function(player, stat, amount, type)
        if not player.passiveModifiers then
            player.passiveModifiers = {}
        end
        
        if not player.passiveModifiers[stat] then
            player.passiveModifiers[stat] = { flat = 0, percent = 0 }
        end
        
        if type == "flat" then
            player.passiveModifiers[stat].flat = player.passiveModifiers[stat].flat + amount
        elseif type == "percent" then
            player.passiveModifiers[stat].percent = player.passiveModifiers[stat].percent + amount
        end
    end,
    
    -- Resistencias
    resistanceModifier = function(player, damageType, amount)
        if not player.resistances then
            player.resistances = {}
        end
        
        player.resistances[damageType] = (player.resistances[damageType] or 0) + amount
    end,
    
    -- Habilidades especiales
    abilityModifier = function(player, ability, value)
        if not player.abilities then
            player.abilities = {}
        end
        
        player.abilities[ability] = value
    end
}

-- Función para aplicar efectos pasivos
local function applyPassiveEffect(player, item)
    if item.passiveEffects then
        for _, effect in ipairs(item.passiveEffects) do
            if effect.type == "stat" then
                Modifiers.statModifier(player, effect.stat, effect.amount, effect.modifierType or "flat")
            elseif effect.type == "resistance" then
                Modifiers.resistanceModifier(player, effect.damageType, effect.amount)
            elseif effect.type == "ability" then
                Modifiers.abilityModifier(player, effect.ability, effect.value)
            end
        end
    end
end

-- Función para remover efectos pasivos
local function removePassiveEffect(player, item)
    if item.passiveEffects then
        for _, effect in ipairs(item.passiveEffects) do
            if effect.type == "stat" and player.passiveModifiers and player.passiveModifiers[effect.stat] then
                if effect.modifierType == "flat" then
                    player.passiveModifiers[effect.stat].flat = player.passiveModifiers[effect.stat].flat - effect.amount
                elseif effect.modifierType == "percent" then
                    player.passiveModifiers[effect.stat].percent = player.passiveModifiers[effect.stat].percent - effect.amount
                end
            elseif effect.type == "resistance" and player.resistances then
                player.resistances[effect.damageType] = (player.resistances[effect.damageType] or 0) - effect.amount
            elseif effect.type == "ability" and player.abilities then
                player.abilities[effect.ability] = nil
            end
        end
    end
end

-- Función para registrar todos los items pasivos
function Passives.registerAll()
    -- Implante Neural Básico
    ItemSystem:registerItem({
        id = "basic_neural_implant",
        name = "Implante Neural Básico",
        description = "Un implante que mejora la capacidad de procesamiento mental. +10 Inteligencia.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        rarity = ItemSystem.RARITY.UNCOMMON,
        stackable = false,
        value = 300,
        weight = 0.1,
        icon = "neural_implant",
        tags = {"cybernetic", "intelligence", "mental"},
        
        passiveEffects = {
            { type = "stat", stat = "intelligence", amount = 10, modifierType = "flat" }
        },
        
        onAcquire = function(self, player)
            applyPassiveEffect(player, self)
            return "Implante neural activado"
        end,
        
        onRemove = function(self, player)
            removePassiveEffect(player, self)
            return "Implante neural desactivado"
        end
    })
    
    -- Exoesqueleto de Soporte
    ItemSystem:registerItem({
        id = "support_exoskeleton",
        name = "Exoesqueleto de Soporte",
        description = "Un exoesqueleto ligero que aumenta la fuerza y resistencia. +15 Fuerza, +10 Resistencia.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        rarity = ItemSystem.RARITY.RARE,
        stackable = false,
        value = 800,
        weight = 2.0,
        icon = "exoskeleton",
        tags = {"mechanical", "strength", "endurance"},
        
        passiveEffects = {
            { type = "stat", stat = "strength", amount = 15, modifierType = "flat" },
            { type = "stat", stat = "endurance", amount = 10, modifierType = "flat" }
        },
        
        onAcquire = function(self, player)
            applyPassiveEffect(player, self)
            return "Exoesqueleto activado"
        end,
        
        onRemove = function(self, player)
            removePassiveEffect(player, self)
            return "Exoesqueleto desactivado"
        end
    })
    
    -- Escudo Personal
    ItemSystem:registerItem({
        id = "personal_shield",
        name = "Escudo Personal",
        description = "Un generador de escudo personal que reduce el daño recibido en un 15%.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        rarity = ItemSystem.RARITY.EPIC,
        stackable = false,
        value = 1200,
        weight = 0.8,
        icon = "personal_shield",
        tags = {"shield", "defense", "energy"},
        
        passiveEffects = {
            { type = "resistance", damageType = "all", amount = 0.15 }
        },
        
        onAcquire = function(self, player)
            applyPassiveEffect(player, self)
            return "Escudo personal activado"
        end,
        
        onRemove = function(self, player)
            removePassiveEffect(player, self)
            return "Escudo personal desactivado"
        end
    })
    
    -- Metabolismo Mejorado
    ItemSystem:registerItem({
        id = "enhanced_metabolism",
        name = "Metabolismo Mejorado",
        description = "Modificación genética que mejora la regeneración natural. +50% velocidad de curación.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        rarity = ItemSystem.RARITY.RARE,
        stackable = false,
        value = 600,
        weight = 0.0,
        icon = "metabolism",
        tags = {"genetic", "healing", "regeneration"},
        
        passiveEffects = {
            { type = "stat", stat = "healing_rate", amount = 50, modifierType = "percent" }
        },
        
        onAcquire = function(self, player)
            applyPassiveEffect(player, self)
            return "Metabolismo mejorado activado"
        end,
        
        onRemove = function(self, player)
            removePassiveEffect(player, self)
            return "Metabolismo mejorado desactivado"
        end
    })
    
    -- Sintetizador de Oxígeno
    ItemSystem:registerItem({
        id = "oxygen_synthesizer",
        name = "Sintetizador de Oxígeno",
        description = "Un dispositivo que reduce el consumo de oxígeno en un 30%.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        rarity = ItemSystem.RARITY.UNCOMMON,
        stackable = false,
        value = 400,
        weight = 0.5,
        icon = "oxygen_synth",
        tags = {"life_support", "efficiency", "oxygen"},
        
        passiveEffects = {
            { type = "stat", stat = "oxygen_consumption", amount = -30, modifierType = "percent" }
        },
        
        onAcquire = function(self, player)
            applyPassiveEffect(player, self)
            return "Sintetizador de oxígeno activado"
        end,
        
        onRemove = function(self, player)
            removePassiveEffect(player, self)
            return "Sintetizador de oxígeno desactivado"
        end
    })
    
    -- Amplificador de Señal
    ItemSystem:registerItem({
        id = "signal_amplifier",
        name = "Amplificador de Señal",
        description = "Mejora el alcance de comunicaciones y sensores en un 100%.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        rarity = ItemSystem.RARITY.UNCOMMON,
        stackable = false,
        value = 250,
        weight = 0.3,
        icon = "signal_amp",
        tags = {"communication", "sensors", "range"},
        
        passiveEffects = {
            { type = "stat", stat = "sensor_range", amount = 100, modifierType = "percent" },
            { type = "stat", stat = "comm_range", amount = 100, modifierType = "percent" }
        },
        
        onAcquire = function(self, player)
            applyPassiveEffect(player, self)
            return "Amplificador de señal activado"
        end,
        
        onRemove = function(self, player)
            removePassiveEffect(player, self)
            return "Amplificador de señal desactivado"
        end
    })
    
    -- Núcleo de Energía Auxiliar
    ItemSystem:registerItem({
        id = "auxiliary_power_core",
        name = "Núcleo de Energía Auxiliar",
        description = "Aumenta la capacidad máxima de energía en 25 puntos.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        rarity = ItemSystem.RARITY.RARE,
        stackable = false,
        value = 700,
        weight = 1.0,
        icon = "power_core",
        tags = {"energy", "capacity", "power"},
        
        passiveEffects = {
            { type = "stat", stat = "maxEnergy", amount = 25, modifierType = "flat" }
        },
        
        onAcquire = function(self, player)
            applyPassiveEffect(player, self)
            if player.stats then
                player.stats.energy = (player.stats.energy or 0) + 25
            end
            return "Núcleo de energía auxiliar conectado"
        end,
        
        onRemove = function(self, player)
            removePassiveEffect(player, self)
            if player.stats and player.stats.energy then
                player.stats.energy = math.max(0, player.stats.energy - 25)
            end
            return "Núcleo de energía auxiliar desconectado"
        end
    })
    
    print("Items pasivos registrados: 7 items")
end

-- Función para aplicar todos los efectos pasivos del inventario
function Passives.applyInventoryPassives(player, inventory)
    -- Limpiar modificadores existentes
    player.passiveModifiers = {}
    player.resistances = {}
    player.abilities = {}
    
    -- Aplicar efectos de todos los items pasivos en el inventario
    for _, item in ipairs(inventory) do
        if ItemSystem:isCategory(item, ItemSystem.CATEGORIES.PASSIVE) then
            applyPassiveEffect(player, item)
        end
    end
end

return Passives