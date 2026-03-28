-- src/maps/systems/inventory_system.lua
-- Sistema de inventario básico con slots predeterminados por tipo de nave

local InventorySystem = {}
InventorySystem.__index = InventorySystem

-- Importar el sistema de items principal para usar tipos estándar
local ItemSystem = require 'src.item_systems.item_system'
local Passives = require 'src.item_systems.items.passives'
local PassiveManager = require 'src.item_systems.passive_manager'

-- Usar los tipos del sistema principal
local CATEGORIES = ItemSystem.CATEGORIES
local EQUIPABLE_TYPES = ItemSystem.EQUIPABLE_TYPES
local ITEM_TYPES = ItemSystem.CATEGORIES

-- Función centralizada para manejar efectos pasivos usando PassiveManager
local function handlePassiveEffects(item, player, action)
    if not item or not item.data or item.data.category ~= CATEGORIES.PASSIVE then
        return
    end
    
    if action == "apply" then
        -- Generar un ID único para el item si no lo tiene
        if not item.passiveId then
            item.passiveId = PassiveManager.applyPassiveEffect(player, item.data)
        else
            -- Si ya tiene ID, intentar aplicar con ese ID (previene duplicaciones)
            PassiveManager.applyPassiveEffect(player, item.data, item.passiveId)
        end
    elseif action == "remove" then
        if item.passiveId then
            PassiveManager.removePassiveEffect(item.passiveId)
            item.passiveId = nil -- Limpiar el ID después de remover
        end
    end
end

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

-- Items de ejemplo usando el formato estándar del ItemSystem
local SAMPLE_ITEMS = {
    -- Armas
    {
        id = "laser_basic",
        name = "Láser Básico",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.WEAPON,
        description = "Arma láser estándar",
        damage = { min = 8, max = 12 },
        damageType = "energy",
        fireRate = 2.0,
        energyCost = 5,
        rarity = ItemSystem.RARITY.COMMON,
        value = 150,
        weight = 1.0
    },
    {
        id = "plasma_cannon",
        name = "Cañón de Plasma",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.WEAPON,
        description = "Arma de plasma avanzada",
        damage = { min = 20, max = 30 },
        damageType = "plasma",
        fireRate = 1.0,
        energyCost = 12,
        rarity = ItemSystem.RARITY.RARE,
        value = 600,
        weight = 2.2
    },
    -- Escudos
    {
        id = "shield_basic",
        name = "Escudo Básico",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.SHIELD,
        description = "Protección estándar",
        shieldCapacity = 50,
        regenRate = 2,
        rarity = ItemSystem.RARITY.COMMON,
        value = 200,
        weight = 1.5
    },
    {
        id = "shield_advanced",
        name = "Escudo Avanzado",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.SHIELD,
        description = "Protección mejorada",
        shieldCapacity = 100,
        regenRate = 5,
        rarity = ItemSystem.RARITY.UNCOMMON,
        value = 450,
        weight = 2.0
    },
    -- Utilidades
    {
        id = "scanner_basic",
        name = "Escáner Básico",
        category = ItemSystem.CATEGORIES.EQUIPABLE,
        equipType = ItemSystem.EQUIPABLE_TYPES.UTILITY,
        description = "Detecta recursos cercanos",
        scanRange = 100,
        rarity = ItemSystem.RARITY.COMMON,
        value = 100,
        weight = 0.5
    },
    {
        id = "repair_kit",
        name = "Kit de Reparación",
        category = ItemSystem.CATEGORIES.CONSUMABLE,
        description = "Restaura 50 puntos de vida",
        healAmount = 50,
        rarity = ItemSystem.RARITY.COMMON,
        value = 75,
        weight = 0.3,
        stackable = true,
        maxStack = 10
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
    
    -- Compartimento de armas: 4 slots para armas equipadas
    inventory.compartments.weapons = {
        name = "weapons",
        maxSlots = 4,
        items = { nil, nil, nil, nil },
        allowedTypes = { weapon = true },
        slotRestrictions = {
            [1] = "default_weapon_only"  -- Slot 1 reservado para arma por defecto
        }
    }
    
    -- Compartimento de items pasivos: 6 slots para items que otorgan efectos permanentes
    inventory.compartments.passives = {
        name = "passives",
        maxSlots = 6,
        items = { nil, nil, nil, nil, nil, nil },
        allowedTypes = { passive = true },
        description = "Items que otorgan efectos permanentes mientras están equipados"
    }
    
    -- Inicializar PassiveManager
    PassiveManager.initialize()
    
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
            -- contra doble anidación
            if type(itemData) == "table" and itemData.data then
                self.items[i] = itemData
                if quantity and quantity > 1 then
                    self.items[i].quantity = quantity
                end
            else
                self.items[i] = {
                    data = itemData,
                    quantity = quantity
                }
            end
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
    
    -- Validaciones específicas para compartimento de armas
    if name == "weapons" then
        return self:addWeaponToSlot(itemData, nil, quantity)
    end
    
    -- Validaciones específicas para compartimento de pasivos
    if name == "passives" then
        if not itemData or itemData.category ~= ItemSystem.CATEGORIES.PASSIVE then
            return false
        end
    end

    -- Validación opcional de tipos permitidos en el compartimento
    if c.allowedTypes and itemData and itemData.category then
        -- Mapear categoría a tipo EVA si es necesario
        local categoryToEVAType = {
            ["consumable"] = "consumable",
            ["equipable"] = "tool",
            ["material"] = "resource",
            ["passive"] = "passive"
        }
        local itemType = categoryToEVAType[itemData.category] or itemData.category
        if not c.allowedTypes[itemType] then
            return false
        end
    end

    quantity = quantity or 1
    for i = 1, c.maxSlots do
        if not c.items[i] then
            local newItem
            -- Si itemData ya es una instancia (tiene campo 'data'), usarla directamente o extraer sus datos
            if type(itemData) == "table" and itemData.data then
                newItem = itemData
                -- Asegurar que la cantidad esté sincronizada si se pasó una diferente
                if quantity and quantity > 1 then
                    newItem.quantity = quantity
                end
            else
                newItem = { data = itemData, quantity = quantity }
            end
            
            c.items[i] = newItem
            
            -- Aplicar efectos pasivos si se está agregando al compartimento de pasivos
            if name == "passives" then
                handlePassiveEffects(newItem, self.player, "apply")
            end
            
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
        
        -- Remover efectos pasivos si se está removiendo del compartimento de pasivos
        if name == "passives" then
            handlePassiveEffects(item, self.player, "remove")
        end
        
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

    -- Validaciones especiales para el compartimento weapons
    if toName == "weapons" then
        if itemFrom then
            -- Validar que es un arma
            if not itemFrom.data or itemFrom.data.category ~= ItemSystem.CATEGORIES.EQUIPABLE or 
               itemFrom.data.equipType ~= ItemSystem.EQUIPABLE_TYPES.WEAPON then
                return false
            end
            
            -- Validar restricciones del slot 1 (solo armas por defecto)
            if toSlot == 1 and toC.slotRestrictions and toC.slotRestrictions[1] == "default_weapon_only" then
                local isDefaultWeapon = self:isDefaultWeapon(itemFrom.data.id)
                if not isDefaultWeapon then
                    return false
                end
            end
        end
    end
    
    -- Validaciones especiales para el compartimento passives
    if toName == "passives" then
        if itemFrom then
            -- Validar que es un item pasivo
            if not itemFrom.data or itemFrom.data.category ~= ItemSystem.CATEGORIES.PASSIVE then
                return false
            end
        end
    end
    
    if fromName == "weapons" then
        -- El slot 1 está reservado para arma por defecto y no se puede remover
        if fromSlot == 1 then
            return false
        end
    end

    -- Validar tipos permitidos en destino (validación general)
    if toC.allowedTypes and itemFrom and itemFrom.data and itemFrom.data.type and not toC.allowedTypes[itemFrom.data.type] then
        return false
    end
    if fromC.allowedTypes and itemTo and itemTo.data and itemTo.data.type and not fromC.allowedTypes[itemTo.data.type] then
        return false
    end

    -- Manejar efectos pasivos antes de la transferencia
    
    -- Remover efectos de items que salen del compartimento de pasivos
    if fromName == "passives" then
        handlePassiveEffects(itemFrom, self.player, "remove")
    end
    if toName == "passives" and itemTo then
        handlePassiveEffects(itemTo, self.player, "remove")
    end
    
    -- Aplicar efectos de items que entran al compartimento de pasivos
    if toName == "passives" then
        handlePassiveEffects(itemFrom, self.player, "apply")
    end
    if fromName == "passives" and itemTo then
        handlePassiveEffects(itemTo, self.player, "apply")
    end

    fromC.items[fromSlot] = itemTo
    toC.items[toSlot] = itemFrom
    return true
end

-- Funciones específicas para el compartimento de armas
function InventorySystem:addWeaponToSlot(weaponData, slot, quantity)
    local weaponsComp = self:getCompartment('weapons')
    if not weaponsComp then return false end
    
    quantity = quantity or 1
    
    -- Validar que es un arma
    if not weaponData or weaponData.category ~= ItemSystem.CATEGORIES.EQUIPABLE or 
       weaponData.equipType ~= ItemSystem.EQUIPABLE_TYPES.WEAPON then
        return false
    end
    
    -- Si no se especifica slot, buscar uno libre (empezando desde slot 2)
    if not slot then
        for i = 2, weaponsComp.maxSlots do
            if not weaponsComp.items[i] then
                slot = i
                break
            end
        end
        if not slot then return false end -- No hay slots libres
    end
    
    -- Validar slot
    if slot < 1 or slot > weaponsComp.maxSlots then return false end
    
    -- Validar restricciones del slot 1 (solo armas por defecto)
    if slot == 1 and weaponsComp.slotRestrictions and weaponsComp.slotRestrictions[1] == "default_weapon_only" then
        local isDefaultWeapon = self:isDefaultWeapon(weaponData.id)
        if not isDefaultWeapon then
            return false -- No se puede equipar arma no-por-defecto en slot 1
        end
    end
    
    -- Equipar arma
    weaponsComp.items[slot] = {
        data = weaponData,
        quantity = quantity
    }
    
    return true
end

function InventorySystem:removeWeaponFromSlot(slot)
    local weaponsComp = self:getCompartment('weapons')
    if not weaponsComp or not slot or slot < 1 or slot > weaponsComp.maxSlots then
        return nil
    end
    
    -- El slot 1 está reservado para arma por defecto y no se puede remover
    if slot == 1 then
        return nil
    end
    
    local weapon = weaponsComp.items[slot]
    weaponsComp.items[slot] = nil
    return weapon
end

function InventorySystem:getWeaponInSlot(slot)
    local weaponsComp = self:getCompartment('weapons')
    if not weaponsComp or not slot or slot < 1 or slot > weaponsComp.maxSlots then
        return nil
    end
    return weaponsComp.items[slot]
end

function InventorySystem:isDefaultWeapon(weaponId)
    -- Lista de armas por defecto (debería coincidir con DEFAULT_WEAPONS en weapon_system.lua)
    local defaultWeapons = {
        "basic_laser_pistol",
        "kinetic_assault_rifle"
    }
    
    for _, defaultId in ipairs(defaultWeapons) do
        if weaponId == defaultId then
            return true
        end
    end
    return false
end

-- Transferir arma al inventario principal
function InventorySystem:transferWeaponToInventory(slot)
    if slot < 1 or slot > 4 then return false end
    
    -- No se puede remover el arma del slot 1 (arma por defecto)
    if slot == 1 then
        return false
    end
    
    local weaponItem = self:getWeaponInSlot(slot)
    if not weaponItem then return false end
    
    -- Buscar espacio libre en el inventario principal
    local shipComp = self:getCompartment('ship')
    if not shipComp then return false end
    
    for i = 1, shipComp.maxSlots do
        if not shipComp.items[i] then
            shipComp.items[i] = weaponItem
            self:removeWeaponFromSlot(slot)
            return true
        end
    end
    
    return false -- No hay espacio en el inventario
end

-- Transferir item desde inventario principal a slot de arma
function InventorySystem:transferItemToWeaponSlot(inventorySlot, weaponSlot)
    if inventorySlot < 1 or weaponSlot < 1 or weaponSlot > 4 then return false end
    
    local shipComp = self:getCompartment('ship')
    if not shipComp or inventorySlot > shipComp.maxSlots then return false end
    
    local item = shipComp.items[inventorySlot]
    if not item then return false end
    
    -- Intentar agregar al slot de arma
    if self:addWeaponToSlot(item.data, weaponSlot) then
        shipComp.items[inventorySlot] = nil
        return true
    end
    
    return false
end

-- Intercambiar items entre compartimentos
function InventorySystem:swapItemsBetweenCompartments(fromName, fromSlot, toName, toSlot)
    return self:transferItemBetweenCompartments(fromName, fromSlot, toName, toSlot)
end

return InventorySystem