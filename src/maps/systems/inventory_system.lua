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
        inventorySlots = 20
    },
    FIGHTER = {
        inventorySlots = 12
    },
    CARGO = {
        inventorySlots = 35
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
    
    -- Inicializar slots de inventario
    inventory.items = {}
    for i = 1, inventory.maxSlots do
        inventory.items[i] = nil
    end
    
    -- No agregar items por defecto; el usuario los añadirá con el toggle "1"
    -- inventory:addSampleItems()
    
    -- Definición inicial de compartimentos unificados (Ship + EVA)
    inventory.compartments = {}
    
    -- Compartimento principal de la nave: referencia a los mismos datos existentes
    inventory.compartments.ship = {
        name = "ship",
        maxSlots = inventory.maxSlots,
        items = inventory.items
    }
    
    -- Compartimento EVA: inventario independiente con 3 slots por defecto
    inventory.compartments.eva = {
        name = "eva",
        maxSlots = 3,
        items = { nil, nil, nil },
        allowedTypes = { tool = true, consumable = true, resource = true }
    }
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
-- API de compartimentos: creación y operaciones básicas
function InventorySystem:addCompartment(name, opts)
    if not self.compartments then self.compartments = {} end
    if not name or self.compartments[name] then return self.compartments[name] end

    local maxSlots = (opts and opts.maxSlots) or 10
    local items = {}
    for i = 1, maxSlots do items[i] = nil end

    local compartment = {
        name = name,
        maxSlots = maxSlots,
        items = items,
        allowedTypes = opts and opts.allowedTypes or nil
    }

    self.compartments[name] = compartment
    return compartment
end

function InventorySystem:getCompartment(name)
    if not self.compartments then return nil end
    return self.compartments[name]
end

function InventorySystem:addItemToCompartment(name, itemData, quantity)
    local c = self:getCompartment(name)
    if not c or not c.items then return false end

    -- Validación opcional de tipos permitidos en el compartimento
    if c.allowedTypes and itemData and itemData.category then
        -- Mapear categoría a tipo EVA si es necesario
        local categoryToEVAType = {
            ["consumable"] = "consumable",
            ["equipable"] = "tool",
            ["material"] = "resource"
        }
        local itemType = categoryToEVAType[itemData.category] or itemData.category
        if not c.allowedTypes[itemType] then
            return false
        end
    end

    quantity = quantity or 1
    for i = 1, c.maxSlots do
        if not c.items[i] then
            c.items[i] = { data = itemData, quantity = quantity }
            return true
        end
    end
    return false
end

function InventorySystem:removeItemFromCompartment(name, slotIndex)
    local c = self:getCompartment(name)
    if not c or not c.items then return nil end
    if slotIndex >= 1 and slotIndex <= c.maxSlots then
        local item = c.items[slotIndex]
        c.items[slotIndex] = nil
        return item
    end
    return nil
end

function InventorySystem:moveItemWithinCompartment(name, fromSlot, toSlot)
    local c = self:getCompartment(name)
    if not c or not c.items then return false end
    if fromSlot >= 1 and fromSlot <= c.maxSlots and toSlot >= 1 and toSlot <= c.maxSlots then
        local item = c.items[fromSlot]
        c.items[fromSlot] = c.items[toSlot]
        c.items[toSlot] = item
        return true
    end
    return false
end

function InventorySystem:transferItemBetweenCompartments(fromName, fromSlot, toName, toSlot)
    local fromC = self:getCompartment(fromName)
    local toC = self:getCompartment(toName)
    if not fromC or not toC or not fromC.items or not toC.items then return false end
    if fromSlot < 1 or fromSlot > fromC.maxSlots or toSlot < 1 or toSlot > toC.maxSlots then return false end

    local itemFrom = fromC.items[fromSlot]
    local itemTo = toC.items[toSlot]

    -- Validar tipos permitidos en destino
    if toC.allowedTypes and itemFrom and itemFrom.data and itemFrom.data.type and not toC.allowedTypes[itemFrom.data.type] then
        return false
    end
    if fromC.allowedTypes and itemTo and itemTo.data and itemTo.data.type and not fromC.allowedTypes[itemTo.data.type] then
        return false
    end

    fromC.items[fromSlot] = itemTo
    toC.items[toSlot] = itemFrom
    return true
end
return InventorySystem