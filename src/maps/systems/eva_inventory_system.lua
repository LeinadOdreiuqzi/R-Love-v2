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

-- Constructor del inventario EVA (wrapper del compartimento 'eva')
function EVAInventorySystem:new(inventorySystem)
    local inventory = {}
    setmetatable(inventory, self)
    self.__index = self

    -- Guardar referencia al InventorySystem si se proporciona
    inventory._invSystem = inventorySystem
    inventory._compartmentName = 'eva'

    if inventorySystem and inventorySystem.getCompartment then
        local comp = inventorySystem:getCompartment('eva')
        if not comp and inventorySystem.addCompartment then
            comp = inventorySystem:addCompartment('eva', {
                maxSlots = 3,
                allowedTypes = { tool = true, consumable = true, resource = true }
            })
        end
        if comp then
            -- Exponer directamente las referencias del compartimento
            inventory.maxSlots = comp.maxSlots
            inventory.items = comp.items
        end
    end

    -- Fallback local si no hay InventorySystem disponible
    if not inventory.maxSlots or not inventory.items then
        inventory.maxSlots = 3  -- Solo 3 slots para EVA
        inventory.items = { nil, nil, nil }
        inventory._localAllowedTypes = { tool = true, consumable = true, resource = true }
    end

    -- Agregar items iniciales de EVA (se colocan en el compartimento si existe)
    inventory:addInitialItems()

    return inventory
end

-- Agregar items iniciales para EVA
function EVAInventorySystem:addInitialItems()
    -- Agregar kit de reparación EVA por defecto
    self:addItem(EVA_ITEMS[1]) -- Kit de reparación EVA
end

-- Agregar item al inventario EVA (delegado al compartimento si existe)
function EVAInventorySystem:addItem(itemData, quantity)
    quantity = quantity or 1

    if self._invSystem and self._invSystem.addItemToCompartment then
        return self._invSystem:addItemToCompartment(self._compartmentName, itemData, quantity)
    end

    -- Fallback local con validación de tipos
    if not self:isValidEVAItem(itemData) then
        return false
    end
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

-- Verificar si un item es válido para EVA (solo para fallback local)
function EVAInventorySystem:isValidEVAItem(itemData)
    -- Mapear categorías del sistema de items a tipos permitidos en EVA
    local categoryToEVAType = {
        ["consumable"] = "consumable",
        ["equipable"] = "tool",  -- Los equipables se consideran herramientas en EVA
        ["material"] = "resource"  -- Los materiales se consideran recursos en EVA
    }
    
    local itemCategory = itemData.category
    local evaType = categoryToEVAType[itemCategory]
    
    if evaType then
        for _, validType in pairs(EVA_ITEM_TYPES) do
            if evaType == validType then
                return true
            end
        end
    end
    return false
end

-- Remover item del inventario (delegado al compartimento si existe)
function EVAInventorySystem:removeItem(slotIndex)
    if self._invSystem and self._invSystem.removeItemFromCompartment then
        return self._invSystem:removeItemFromCompartment(self._compartmentName, slotIndex)
    end
    if slotIndex >= 1 and slotIndex <= self.maxSlots then
        local item = self.items[slotIndex]
        self.items[slotIndex] = nil
        return item
    end
    return nil
end

-- Mover item entre slots (delegado al compartimento si existe)
function EVAInventorySystem:moveItem(fromSlot, toSlot)
    if self._invSystem and self._invSystem.moveItemWithinCompartment then
        return self._invSystem:moveItemWithinCompartment(self._compartmentName, fromSlot, toSlot)
    end
    if fromSlot >= 1 and fromSlot <= self.maxSlots and 
       toSlot >= 1 and toSlot <= self.maxSlots then
        local item = self.items[fromSlot]
        self.items[fromSlot] = self.items[toSlot]
        self.items[toSlot] = item
        return true
    end
    return false
end

-- Usar item consumible (reduce cantidad y elimina si llega a 0)
function EVAInventorySystem:useItem(slotIndex)
    if slotIndex >= 1 and slotIndex <= self.maxSlots then
        local item = self.items[slotIndex]
        if item and item.data and item.data.category == "consumable" then
            item.quantity = (item.quantity or 1) - 1

            -- Si se agotó, remover del slot
            if item.quantity <= 0 then
                if self._invSystem and self._invSystem.removeItemFromCompartment then
                    self._invSystem:removeItemFromCompartment(self._compartmentName, slotIndex)
                else
                    self.items[slotIndex] = nil
                end
            end

            -- Devolver la data del item para aplicar efectos en la UI
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