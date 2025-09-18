-- src/maps/systems/inventory_system.lua
-- Sistema de inventario básico con slots predeterminados por tipo de nave

local InventorySystem = {}

-- Tipos de items disponibles
local ITEM_TYPES = {
    WEAPON = "weapon",
    SHIELD = "shield", 
    ENGINE = "engine",
    UTILITY = "utility",
    CONSUMABLE = "consumable",
    RESOURCE = "resource"
}

-- Configuración de slots por tipo de nave
local SHIP_INVENTORY_CONFIG = {
    EXPLORER = {
        inventorySlots = 20,
        upgradeSlots = {
            weapon = 2,
            shield = 1,
            engine = 1,
            utility = 2
        }
    },
    FIGHTER = {
        inventorySlots = 12,
        upgradeSlots = {
            weapon = 3,
            shield = 1,
            engine = 1,
            utility = 1
        }
    },
    CARGO = {
        inventorySlots = 35,
        upgradeSlots = {
            weapon = 1,
            shield = 2,
            engine = 1,
            utility = 2
        }
    }
}

-- Items de ejemplo para el sistema
local SAMPLE_ITEMS = {
    -- Armas
    {
        id = "laser_basic",
        name = "Láser Básico",
        type = ITEM_TYPES.WEAPON,
        description = "Arma láser estándar",
        stats = { damage = 10, energy = 5 },
        rarity = "common"
    },
    {
        id = "plasma_cannon",
        name = "Cañón de Plasma",
        type = ITEM_TYPES.WEAPON,
        description = "Arma de plasma avanzada",
        stats = { damage = 25, energy = 12 },
        rarity = "rare"
    },
    -- Escudos
    {
        id = "shield_basic",
        name = "Escudo Básico",
        type = ITEM_TYPES.SHIELD,
        description = "Protección estándar",
        stats = { shield = 50, regen = 2 },
        rarity = "common"
    },
    {
        id = "shield_advanced",
        name = "Escudo Avanzado",
        type = ITEM_TYPES.SHIELD,
        description = "Protección mejorada",
        stats = { shield = 100, regen = 5 },
        rarity = "uncommon"
    },
    -- Motores
    {
        id = "engine_basic",
        name = "Motor Básico",
        type = ITEM_TYPES.ENGINE,
        description = "Propulsión estándar",
        stats = { speed = 10, acceleration = 5 },
        rarity = "common"
    },
    {
        id = "engine_turbo",
        name = "Motor Turbo",
        type = ITEM_TYPES.ENGINE,
        description = "Propulsión mejorada",
        stats = { speed = 20, acceleration = 12 },
        rarity = "rare"
    },
    -- Utilidades
    {
        id = "scanner_basic",
        name = "Escáner Básico",
        type = ITEM_TYPES.UTILITY,
        description = "Detecta recursos cercanos",
        stats = { range = 100 },
        rarity = "common"
    },
    {
        id = "repair_kit",
        name = "Kit de Reparación",
        type = ITEM_TYPES.CONSUMABLE,
        description = "Restaura 50 puntos de vida",
        stats = { heal = 50 },
        rarity = "common"
    }
}

-- Constructor del inventario
function InventorySystem:new(shipType)
    local inventory = {}
    setmetatable(inventory, self)
    self.__index = self
    
    shipType = shipType or "EXPLORER"
    local config = SHIP_INVENTORY_CONFIG[shipType] or SHIP_INVENTORY_CONFIG.EXPLORER
    
    -- Configuración básica
    inventory.shipType = shipType
    inventory.maxSlots = config.inventorySlots
    inventory.upgradeSlots = {}
    
    -- Inicializar slots de inventario
    inventory.items = {}
    for i = 1, inventory.maxSlots do
        inventory.items[i] = nil
    end
    
    -- Inicializar slots de mejoras
    for upgradeType, maxSlots in pairs(config.upgradeSlots) do
        inventory.upgradeSlots[upgradeType] = {}
        for i = 1, maxSlots do
            inventory.upgradeSlots[upgradeType][i] = nil
        end
    end
    
    -- Agregar algunos items de ejemplo
    inventory:addSampleItems()
    
    return inventory
end

-- Agregar items de ejemplo al inventario
function InventorySystem:addSampleItems()
    -- Agregar algunos items básicos
    self:addItem(SAMPLE_ITEMS[1]) -- Láser básico
    self:addItem(SAMPLE_ITEMS[3]) -- Escudo básico
    self:addItem(SAMPLE_ITEMS[5]) -- Motor básico
    self:addItem(SAMPLE_ITEMS[7]) -- Escáner básico
    self:addItem(SAMPLE_ITEMS[8]) -- Kit de reparación
    self:addItem(SAMPLE_ITEMS[8]) -- Otro kit de reparación
end

-- Agregar item al inventario
function InventorySystem:addItem(itemData, quantity)
    quantity = quantity or 1
    
    -- Buscar slot vacío
    for i = 1, self.maxSlots do
        if not self.items[i] then
            self.items[i] = {
                data = itemData,
                quantity = quantity
            }
            return true
        end
    end
    
    return false -- Inventario lleno
end

-- Remover item del inventario
function InventorySystem:removeItem(slotIndex)
    if slotIndex >= 1 and slotIndex <= self.maxSlots then
        local item = self.items[slotIndex]
        self.items[slotIndex] = nil
        return item
    end
    return nil
end

-- Mover item entre slots
function InventorySystem:moveItem(fromSlot, toSlot)
    if fromSlot >= 1 and fromSlot <= self.maxSlots and 
       toSlot >= 1 and toSlot <= self.maxSlots then
        local item = self.items[fromSlot]
        self.items[fromSlot] = self.items[toSlot]
        self.items[toSlot] = item
        return true
    end
    return false
end

-- Equipar item en slot de mejora
function InventorySystem:equipItem(inventorySlot, upgradeType, upgradeSlot)
    local item = self.items[inventorySlot]
    if not item or item.data.type ~= upgradeType then
        return false
    end
    
    if not self.upgradeSlots[upgradeType] or 
       upgradeSlot < 1 or upgradeSlot > #self.upgradeSlots[upgradeType] then
        return false
    end
    
    -- Intercambiar items
    local oldUpgrade = self.upgradeSlots[upgradeType][upgradeSlot]
    self.upgradeSlots[upgradeType][upgradeSlot] = item
    self.items[inventorySlot] = oldUpgrade
    
    return true
end

-- Desequipar item de slot de mejora
function InventorySystem:unequipItem(upgradeType, upgradeSlot)
    if not self.upgradeSlots[upgradeType] or 
       upgradeSlot < 1 or upgradeSlot > #self.upgradeSlots[upgradeType] then
        return false
    end
    
    local item = self.upgradeSlots[upgradeType][upgradeSlot]
    if not item then
        return false
    end
    
    -- Buscar slot vacío en inventario
    for i = 1, self.maxSlots do
        if not self.items[i] then
            self.items[i] = item
            self.upgradeSlots[upgradeType][upgradeSlot] = nil
            return true
        end
    end
    
    return false -- Inventario lleno
end

-- Obtener estadísticas totales de mejoras equipadas
function InventorySystem:getTotalStats()
    local totalStats = {
        damage = 0,
        shield = 0,
        speed = 0,
        acceleration = 0,
        energy = 0,
        regen = 0,
        range = 0,
        heal = 0
    }
    
    for upgradeType, slots in pairs(self.upgradeSlots) do
        for _, item in pairs(slots) do
            if item and item.data.stats then
                for stat, value in pairs(item.data.stats) do
                    if totalStats[stat] then
                        totalStats[stat] = totalStats[stat] + value
                    end
                end
            end
        end
    end
    
    return totalStats
end

-- Obtener información del item por ID
function InventorySystem:getItemById(itemId)
    for _, item in pairs(SAMPLE_ITEMS) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

-- Obtener todos los tipos de items disponibles
function InventorySystem:getItemTypes()
    return ITEM_TYPES
end

-- Obtener configuración de slots para el tipo de nave
function InventorySystem:getShipConfig()
    return SHIP_INVENTORY_CONFIG[self.shipType] or SHIP_INVENTORY_CONFIG.EXPLORER
end

return InventorySystem