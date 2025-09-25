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

-- NOTA: Las funciones applyPassiveEffect y removePassiveEffect han sido movidas
-- al PassiveManager para centralizar el manejo de efectos pasivos y evitar duplicaciones

-- Función para registrar todos los items pasivos
function Passives.registerAll()
    -- 1. Propulsores Mejorados - Aumenta velocidad base 5%
    ItemSystem:registerItem({
        id = "enhanced_thrusters",
        name = "Propulsores Mejorados",
        description = "Propulsores de alta eficiencia que aumentan la velocidad base en un 5%.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        stackable = false,
        value = 500,
        weight = 0.8,
        icon = "enhanced_thrusters",
        tags = {"propulsion", "speed", "movement"},
        
        passiveEffects = {
            { type = "stat", stat = "speed", amount = 5, modifierType = "percent" }
        },
        
        onAcquire = function(self, player)
            applyPassiveEffect(player, self)
            return "Propulsores mejorados activados"
        end,
        
        onRemove = function(self, player)
            removePassiveEffect(player, self)
            return "Propulsores mejorados desactivados"
        end
    })
    
    -- 2. Sistema de Disparo Rápido - Aumenta velocidad de disparo 2%
    ItemSystem:registerItem({
        id = "rapid_fire_system",
        name = "Sistema de Disparo Rápido",
        description = "Sistema automatizado que permite disparar un 2% más rápido.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        stackable = false,
        value = 400,
        weight = 0.5,
        icon = "rapid_fire_system",
        tags = {"weapons", "fire_rate", "automation"},
        
        passiveEffects = {
            { type = "stat", stat = "fire_rate", amount = 2, modifierType = "percent" }
        },
        
        onAcquire = function(self, player)
            applyPassiveEffect(player, self)
            return "Sistema de disparo rápido activado"
        end,
        
        onRemove = function(self, player)
            removePassiveEffect(player, self)
            return "Sistema de disparo rápido desactivado"
        end
    })
    
    -- 3. Corazón Auxiliar - Aumenta 1 corazón de vida
    ItemSystem:registerItem({
        id = "auxiliary_heart",
        name = "Corazón Auxiliar",
        description = "Un corazón artificial que aumenta tu capacidad vital en 1 corazón.",
        category = ItemSystem.CATEGORIES.PASSIVE,
        stackable = false,
        value = 800,
        weight = 0.3,
        icon = "auxiliary_heart",
        tags = {"health", "life", "medical"},
        
        passiveEffects = {
            { type = "stat", stat = "max_health", amount = 1, modifierType = "flat" }
        }
    })
    
    print("Items pasivos registrados: 3 items")
end

-- NOTA: Las funciones applyPassiveEffect y removePassiveEffect han sido
-- centralizadas en PassiveManager para evitar duplicaciones

return Passives