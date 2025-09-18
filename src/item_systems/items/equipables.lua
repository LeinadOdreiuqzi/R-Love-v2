-- Items Equipables para Space Roguelike
-- Armas, armaduras, herramientas y accesorios que se pueden equipar

local ItemSystem = require("src.item_systems.item_system")

local Equipables = {}

-- Slots de equipamiento
Equipables.SLOTS = {
    WEAPON_PRIMARY = "weapon_primary",
    WEAPON_SECONDARY = "weapon_secondary",
    ARMOR_HEAD = "armor_head",
    ARMOR_CHEST = "armor_chest",
    ARMOR_LEGS = "armor_legs",
    TOOL_MINING = "tool_mining",
    TOOL_REPAIR = "tool_repair",
    ACCESSORY_1 = "accessory_1",
    ACCESSORY_2 = "accessory_2",
    UTILITY = "utility",
    SHIELD = "shield"
}

-- Tipos de daño para armas
local DAMAGE_TYPES = {
    KINETIC = "kinetic",
    ENERGY = "energy",
    PLASMA = "plasma",
    EXPLOSIVE = "explosive"
}

-- Función para registrar todos los equipables
function Equipables.registerAll()
    -- === ARMAS ===
    
    -- Pistola Láser Básica
    ItemSystem:registerItem({
        id = "basic_laser_pistol",
        name = "Pistola Láser Básica",
        description = "Una pistola láser estándar. Daño: 15-25 energía. Alcance: medio.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.WEAPON,
        slot = Equipables.SLOTS.WEAPON_PRIMARY,
        rarity = ItemSystem.RARITY.COMMON,
        value = 200,
        weight = 1.2,
        icon = "laser_pistol",
        tags = {"weapon", "energy", "ranged"},
        
        -- Estadísticas de arma
        damage = { min = 15, max = 25 },
        damageType = DAMAGE_TYPES.ENERGY,
        range = 150,
        fireRate = 2.0, -- disparos por segundo
        energyCost = 5,
        accuracy = 85,
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Pistola láser equipada"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Pistola láser desequipada"
        end
    })
    
    -- Rifle de Plasma
    ItemSystem:registerItem({
        id = "plasma_rifle",
        name = "Rifle de Plasma",
        description = "Un rifle de plasma de alta potencia. Daño: 30-45 plasma. Alcance: largo.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.WEAPON,
        slot = Equipables.SLOTS.WEAPON_PRIMARY,
        rarity = ItemSystem.RARITY.RARE,
        value = 800,
        weight = 2.5,
        icon = "plasma_rifle",
        tags = {"weapon", "plasma", "ranged", "heavy"},
        
        damage = { min = 30, max = 45 },
        damageType = DAMAGE_TYPES.PLASMA,
        range = 250,
        fireRate = 1.2,
        energyCost = 12,
        accuracy = 75,
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Rifle de plasma equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Rifle de plasma desequipado"
        end
    })
    
    -- Cuchillo de Combate
    ItemSystem:registerItem({
        id = "combat_knife",
        name = "Cuchillo de Combate",
        description = "Un cuchillo táctico para combate cuerpo a cuerpo. Daño: 8-15 cinético.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.WEAPON,
        slot = Equipables.SLOTS.WEAPON_SECONDARY,
        rarity = ItemSystem.RARITY.COMMON,
        value = 50,
        weight = 0.3,
        icon = "combat_knife",
        tags = {"weapon", "melee", "kinetic"},
        
        damage = { min = 8, max = 15 },
        damageType = DAMAGE_TYPES.KINETIC,
        range = 5,
        fireRate = 3.0,
        energyCost = 0,
        accuracy = 95,
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Cuchillo de combate equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Cuchillo de combate desequipado"
        end
    })
    
    -- === ARMADURAS ===
    
    -- Casco EVA
    ItemSystem:registerItem({
        id = "eva_helmet",
        name = "Casco EVA",
        description = "Un casco espacial que proporciona protección y soporte vital. +10 Defensa, +20 Resistencia al vacío.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.ARMOR,
        slot = Equipables.SLOTS.ARMOR_HEAD,
        rarity = ItemSystem.RARITY.UNCOMMON,
        value = 300,
        weight = 1.5,
        icon = "eva_helmet",
        tags = {"armor", "head", "eva", "life_support"},
        
        defense = 10,
        resistances = {
            vacuum = 20,
            radiation = 15
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            if player.stats then
                player.stats.defense = (player.stats.defense or 0) + self.defense
            end
            return "Casco EVA equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            if player.stats then
                player.stats.defense = (player.stats.defense or 0) - self.defense
            end
            return "Casco EVA desequipado"
        end
    })
    
    -- Traje Espacial Reforzado
    ItemSystem:registerItem({
        id = "reinforced_spacesuit",
        name = "Traje Espacial Reforzado",
        description = "Un traje espacial con blindaje adicional. +25 Defensa, +30 Resistencia al vacío.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.ARMOR,
        slot = Equipables.SLOTS.ARMOR_CHEST,
        rarity = ItemSystem.RARITY.RARE,
        value = 600,
        weight = 3.0,
        icon = "reinforced_suit",
        tags = {"armor", "chest", "eva", "heavy"},
        
        defense = 25,
        resistances = {
            vacuum = 30,
            kinetic = 20,
            energy = 10
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            if player.stats then
                player.stats.defense = (player.stats.defense or 0) + self.defense
            end
            return "Traje espacial reforzado equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            if player.stats then
                player.stats.defense = (player.stats.defense or 0) - self.defense
            end
            return "Traje espacial reforzado desequipado"
        end
    })
    
    -- === HERRAMIENTAS ===
    
    -- Taladro Minero
    ItemSystem:registerItem({
        id = "mining_drill",
        name = "Taladro Minero",
        description = "Una herramienta especializada para extraer minerales. Eficiencia de minería +50%.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.TOOL,
        slot = Equipables.SLOTS.TOOL_MINING,
        rarity = ItemSystem.RARITY.UNCOMMON,
        value = 400,
        weight = 2.0,
        icon = "mining_drill",
        tags = {"tool", "mining", "extraction"},
        
        miningEfficiency = 1.5,
        energyCost = 8,
        durability = 100,
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Taladro minero equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Taladro minero desequipado"
        end,
        
        use = function(self, player, target)
            if self.durability <= 0 then
                return "El taladro está dañado y necesita reparación"
            end
            
            self.durability = self.durability - 1
            return "Extrayendo minerales..."
        end
    })
    
    -- Kit de Reparación Avanzado
    ItemSystem:registerItem({
        id = "advanced_repair_kit",
        name = "Kit de Reparación Avanzado",
        description = "Herramientas avanzadas para reparar equipos. Eficiencia de reparación +75%.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.TOOL,
        slot = Equipables.SLOTS.TOOL_REPAIR,
        rarity = ItemSystem.RARITY.RARE,
        value = 500,
        weight = 1.5,
        icon = "repair_kit_adv",
        tags = {"tool", "repair", "maintenance"},
        
        repairEfficiency = 1.75,
        energyCost = 5,
        durability = 150,
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Kit de reparación avanzado equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Kit de reparación avanzado desequipado"
        end,
        
        use = function(self, player, target)
            if self.durability <= 0 then
                return "El kit de reparación está agotado"
            end
            
            self.durability = self.durability - 1
            return "Reparando equipo..."
        end
    })
    
    -- === ACCESORIOS ===
    
    -- Anillo de Traducción Universal
    ItemSystem:registerItem({
        id = "universal_translator",
        name = "Anillo de Traducción Universal",
        description = "Un dispositivo que permite comunicarse con especies alienígenas.",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.ACCESSORY,
        slot = Equipables.SLOTS.ACCESSORY_1,
        rarity = ItemSystem.RARITY.EPIC,
        value = 1000,
        weight = 0.1,
        icon = "translator",
        tags = {"accessory", "communication", "alien"},
        
        abilities = {
            universal_translation = true
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            if not player.abilities then
                player.abilities = {}
            end
            player.abilities.universal_translation = true
            return "Traductor universal activado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            if player.abilities then
                player.abilities.universal_translation = nil
            end
            return "Traductor universal desactivado"
        end
    })
    
    -- === UTILIDADES ===
    
    -- Escáner Básico
    ItemSystem:registerItem({
        id = "scanner_basic",
        name = "Escáner Básico",
        description = "Detecta recursos cercanos",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.UTILITY,
        slot = Equipables.SLOTS.UTILITY,
        rarity = ItemSystem.RARITY.COMMON,
        value = 150,
        weight = 0.5,
        icon = "scanner",
        tags = {"utility", "scanner", "detection"},
        
        stats = {
            range = 100
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Escáner básico equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Escáner básico desequipado"
        end
    })
    
    -- Escudo Básico
    ItemSystem:registerItem({
        id = "shield_basic",
        name = "Escudo Básico",
        description = "Protección estándar",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.SHIELD,
        slot = Equipables.SLOTS.SHIELD,
        rarity = ItemSystem.RARITY.COMMON,
        value = 200,
        weight = 2.0,
        icon = "shield",
        tags = {"shield", "defense", "protection"},
        
        stats = {
            shield = 50,
            regen = 2
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Escudo básico equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Escudo básico desequipado"
        end
    })
    
    -- Láser Básico
    ItemSystem:registerItem({
        id = "laser_basic",
        name = "Láser Básico",
        description = "Arma láser estándar",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.WEAPON,
        slot = Equipables.SLOTS.WEAPON_PRIMARY,
        rarity = ItemSystem.RARITY.COMMON,
        value = 100,
        weight = 1.0,
        icon = "laser",
        tags = {"weapon", "laser", "energy"},
        
        stats = {
            damage = 10,
            energy = 5
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Láser básico equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Láser básico desequipado"
        end
    })
    
    -- Motor Básico
    ItemSystem:registerItem({
        id = "engine_basic",
        name = "Motor Básico",
        description = "Propulsión estándar",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.TOOL,
        slot = Equipables.SLOTS.TOOL_REPAIR,
        rarity = ItemSystem.RARITY.COMMON,
        value = 250,
        weight = 5.0,
        icon = "engine",
        tags = {"engine", "propulsion", "speed"},
        
        stats = {
            speed = 10,
            acceleration = 5
        },
        
        onEquip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = self
            end
            return "Motor básico equipado"
        end,
        
        onUnequip = function(self, player)
            if player.equipment then
                player.equipment[self.slot] = nil
            end
            return "Motor básico desequipado"
        end
    })
    
    print("Items equipables registrados: 12 items")
end

-- Función para obtener el daño total de un arma
function Equipables.getWeaponDamage(weapon)
    if not weapon.damage then return 0 end
    return math.random(weapon.damage.min, weapon.damage.max)
end

-- Función para verificar si un item puede ser equipado en un slot
function Equipables.canEquipInSlot(item, slot)
    return item.slot == slot
end

-- Función para obtener la defensa total del equipamiento
function Equipables.getTotalDefense(equipment)
    local totalDefense = 0
    for slot, item in pairs(equipment) do
        if item.defense then
            totalDefense = totalDefense + item.defense
        end
    end
    return totalDefense
end

return Equipables