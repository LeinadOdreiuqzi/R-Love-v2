-- src/maps/systems/eva_inventory_system.lua
-- Sistema de inventario específico para EVA (Extra-Vehicular Activity)
-- Inventario reducido con solo 3 slots para items esenciales

local EVAInventorySystem = {}

-- Tipos de items permitidos en EVA (solo esenciales)
local EVA_ITEM_TYPES = {
    TOOL = "tool",
    CONSUMABLE = "consumable",
    RESOURCE = "resource"
}

-- Items específicos para EVA
local EVA_ITEMS = {
    {
        id = "eva_repair_kit",
        name = "Kit de Reparación EVA",
        type = EVA_ITEM_TYPES.CONSUMABLE,
        description = "Kit de reparación portátil para EVA",
        stats = { heal = 25 },
        rarity = "common"
    },
    {
        id = "eva_scanner",
        name = "Escáner Portátil",
        type = EVA_ITEM_TYPES.TOOL,
        description = "Escáner de corto alcance para EVA",
        stats = { range = 50 },
        rarity = "common"
    },
    {
        id = "oxygen_tank",
        name = "Tanque de Oxígeno",
        type = EVA_ITEM_TYPES.CONSUMABLE,
        description = "Tanque de oxígeno de emergencia",
        stats = { oxygen = 100 },
        rarity = "common"
    },
    {
        id = "metal_scrap",
        name = "Chatarra Metálica",
        type = EVA_ITEM_TYPES.RESOURCE,
        description = "Material recuperado del espacio",
        stats = { value = 10 },
        rarity = "common"
    }
}

-- Constructor del inventario EVA
function EVAInventorySystem:new()
    local inventory = {}
    setmetatable(inventory, self)
    self.__index = self
    
    -- Configuración específica de EVA
    inventory.maxSlots = 3  -- Solo 3 slots para EVA
    inventory.items = {}
    
    -- Inicializar slots vacíos
    for i = 1, inventory.maxSlots do
        inventory.items[i] = nil
    end
    
    -- Agregar items iniciales de EVA
    inventory:addInitialItems()
    
    return inventory
end

-- Agregar items iniciales para EVA
function EVAInventorySystem:addInitialItems()
    -- Agregar kit de reparación EVA por defecto
    self:addItem(EVA_ITEMS[1]) -- Kit de reparación EVA
end

-- Agregar item al inventario EVA
function EVAInventorySystem:addItem(itemData, quantity)
    quantity = quantity or 1
    
    -- Verificar si el item es válido para EVA
    if not self:isValidEVAItem(itemData) then
        return false
    end
    
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

-- Verificar si un item es válido para EVA
function EVAInventorySystem:isValidEVAItem(itemData)
    for _, validType in pairs(EVA_ITEM_TYPES) do
        if itemData.type == validType then
            return true
        end
    end
    return false
end

-- Remover item del inventario
function EVAInventorySystem:removeItem(slotIndex)
    if slotIndex >= 1 and slotIndex <= self.maxSlots then
        local item = self.items[slotIndex]
        self.items[slotIndex] = nil
        return item
    end
    return nil
end

-- Mover item entre slots
function EVAInventorySystem:moveItem(fromSlot, toSlot)
    if fromSlot >= 1 and fromSlot <= self.maxSlots and 
       toSlot >= 1 and toSlot <= self.maxSlots then
        local item = self.items[fromSlot]
        self.items[fromSlot] = self.items[toSlot]
        self.items[toSlot] = item
        return true
    end
    return false
end

-- Usar item consumible
function EVAInventorySystem:useItem(slotIndex)
    if slotIndex >= 1 and slotIndex <= self.maxSlots then
        local item = self.items[slotIndex]
        if item and item.data.type == EVA_ITEM_TYPES.CONSUMABLE then
            -- Reducir cantidad
            item.quantity = item.quantity - 1
            
            -- Si se agotó, remover del slot
            if item.quantity <= 0 then
                self.items[slotIndex] = nil
            end
            
            return item.data
        end
    end
    return nil
end

-- Obtener item por ID de la lista de EVA
function EVAInventorySystem:getEVAItemById(itemId)
    for _, item in pairs(EVA_ITEMS) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

-- Obtener tipos de items válidos para EVA
function EVAInventorySystem:getEVAItemTypes()
    return EVA_ITEM_TYPES
end

-- Obtener todos los items disponibles para EVA
function EVAInventorySystem:getAvailableEVAItems()
    return EVA_ITEMS
end

-- Verificar si el inventario está lleno
function EVAInventorySystem:isFull()
    for i = 1, self.maxSlots do
        if not self.items[i] then
            return false
        end
    end
    return true
end

-- Obtener número de slots libres
function EVAInventorySystem:getFreeSlots()
    local freeSlots = 0
    for i = 1, self.maxSlots do
        if not self.items[i] then
            freeSlots = freeSlots + 1
        end
    end
    return freeSlots
end

return EVAInventorySystem