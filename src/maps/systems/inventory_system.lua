-- src/maps/systems/inventory_system.lua
-- Bodega cuadriculada y compartimentos de equipo por nave.

local InventorySystem = {}
InventorySystem.__index = InventorySystem

-- Importar el sistema de items principal para usar tipos estándar
local ItemSystem = require 'src.item_systems.item_system'
local Passives = require 'src.item_systems.items.passives'
local PassiveManager = require 'src.item_systems.passive_manager'
local SynergyEngine = require 'src.item_systems.synergy_engine'
local Grid = require 'src.item_systems.cargo_grid'
InventorySystem.gridVersion = Grid.version

-- Usar los tipos del sistema principal
local CATEGORIES = ItemSystem.CATEGORIES
local EQUIPABLE_TYPES = ItemSystem.EQUIPABLE_TYPES
local ITEM_TYPES = ItemSystem.CATEGORIES

-- Función para mapear categorías del sistema de items a tipos de inventario
local function _mapCategoryToType(itemData)
    if not itemData or not itemData.category then return nil end
    
    -- Mapeo de categorías extendido
    local mapping = {
        ["consumable"] = "consumable",
        ["equipable"] = "tool",      -- Por defecto los equipables son herramientas en EVA
        ["material"] = "resource",
        ["passive"] = "passive",
        ["quest"] = "quest",
        ["currency"] = "currency"
    }
    
    -- Si es equipable, podemos ser más específicos basándonos en equipType
    if itemData.category == CATEGORIES.EQUIPABLE then
        if itemData.equipType == EQUIPABLE_TYPES.WEAPON then return "weapon" end
        if itemData.equipType == EQUIPABLE_TYPES.SHIELD then return "shield" end
        if itemData.equipType == EQUIPABLE_TYPES.ARMOR then return "armor" end
        if itemData.equipType == EQUIPABLE_TYPES.UTILITY then return "utility" end
    end
    
    return mapping[itemData.category] or itemData.category
end

local function allowedIn(comp, data)
    if not comp.allowedTypes then return true end
    if comp.name == 'eva' and data.category == CATEGORIES.EQUIPABLE then return comp.allowedTypes.tool end
    return comp.allowedTypes[_mapCategoryToType(data)]
end

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
    EXPLORER = {columns = 4, inventorySlots = 24},
    FIGHTER = {columns = 4, inventorySlots = 16},
    CARGO = {columns = 4, inventorySlots = 32},
    INTERCEPTOR = {columns = 4, inventorySlots = 16},
    GUNSHIP = {columns = 4, inventorySlots = 24},
    SALVAGER = {columns = 4, inventorySlots = 32},
    SENTINEL = {columns = 4, inventorySlots = 16},
    TITAN_EXCAVATOR = {columns = 4, inventorySlots = 32},
    ECLIPSE = {columns = 4, inventorySlots = 24},
    DREADNOUGHT = {columns = 4, inventorySlots = 24},
    ARK_MONOLITH = {columns = 4, inventorySlots = 24}
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
    inventory.columns = config.columns
    
    -- Inicializar slots de inventario
    inventory.items = {}
    inventory.recoveryCargo = {}
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
        columns = inventory.columns,
        items = inventory.items
    }
    
    -- Compartimento EVA: inventario independiente con 3 slots por defecto
    inventory.compartments.eva = {
        name = "eva",
        maxSlots = 3,
        items = { nil, nil, nil },
        allowedTypes = { tool = true, consumable = true, resource = true }
    }
    
    -- Compartimento de armas: 9 slots para armas equipadas (estilo Enter the Gungeon: teclas 1 a 9)
    inventory.compartments.weapons = {
        name = "weapons",
        maxSlots = 9,
        items = { nil, nil, nil, nil, nil, nil, nil, nil, nil },
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
    return self:addItemToCompartment('ship', itemData, quantity)
end

function InventorySystem:removeItem(slotIndex)
    return self:removeItemFromCompartment('ship', slotIndex)
end

function InventorySystem:moveItem(fromSlot, toSlot)
    return self:moveItemWithinCompartment('ship', fromSlot, toSlot)
end

function InventorySystem:findCargoSlot(item)
    return Grid.find(Grid.occupancy(self.items, nil, nil, self.columns), self.maxSlots, item, self.columns)
end

function InventorySystem:cargoAnchor(cell)
    return Grid.occupancy(self.items, nil, nil, self.columns)[cell]
end

local function applyPacking(items, capacity, packed)
    for slot = 1, capacity do items[slot] = nil end
    for anchor, entry in pairs(packed) do
        entry.item.rotated = entry.rotated
        items[anchor] = entry.item
    end
end

function InventorySystem:restoreCargo(items, recovery, preserveLayout, previousColumns)
    previousColumns = previousColumns or self.columns
    local config = self:getShipConfig()
    self.maxSlots, self.columns = config.inventorySlots, config.columns
    self.items, self.recoveryCargo = {}, {}
    local comp = self:getCompartment('ship')
    comp.maxSlots = self.maxSlots
    comp.columns = self.columns
    local cells, pending, order = {}, {}, {}
    for anchor, item in pairs(items or {}) do
        if type(item) == 'table' and item.data and tonumber(anchor) then order[#order + 1] = tonumber(anchor) end
    end
    table.sort(order)
    for _, anchor in ipairs(order) do
        local item = items[anchor] or items[tostring(anchor)]
        local column, row = (anchor - 1) % previousColumns, math.floor((anchor - 1) / previousColumns)
        local target = row * self.columns + column + 1
        if preserveLayout and column < self.columns and Grid.fits(cells, self.maxSlots, target, item, nil, self.columns) then
            item.rotated = Grid.canRotate(item) and item.rotated == true
            self.items[target] = item
            Grid.claim(cells, target, item, nil, self.columns)
        else
            pending[#pending + 1] = item
        end
    end
    for _, item in ipairs(recovery or {}) do pending[#pending + 1] = item end
    for _, item in ipairs(pending) do
        local anchor, rotated = Grid.find(cells, self.maxSlots, item, self.columns)
        if anchor then
            item.rotated = rotated
            self.items[anchor] = item
            Grid.claim(cells, anchor, item, nil, self.columns)
        else
            self.recoveryCargo[#self.recoveryCargo + 1] = item
        end
    end
    if #self.recoveryCargo > 0 and (not recovery or #recovery == 0) then
        local all = {}
        for _, anchor in ipairs(order) do all[#all + 1] = items[anchor] or items[tostring(anchor)] end
        local packed = Grid.pack(self.maxSlots, all, self.columns)
        if packed then
            applyPacking(self.items, self.maxSlots, packed)
            self.recoveryCargo = {}
        end
    end
end

function InventorySystem:recoverCargo()
    for index, item in ipairs(self.recoveryCargo) do
        local anchor, rotated = self:findCargoSlot(item)
        if anchor then
            item.rotated = rotated
            self.items[anchor] = table.remove(self.recoveryCargo, index)
            self:evaluateSynergies()
            return true
        end
    end
    return false
end

function InventorySystem:rotateCargo(anchor)
    local item = self.items[anchor]
    if not item or not Grid.canRotate(item) then return false end
    return self:moveItemWithinCompartment('ship', anchor, anchor, not item.rotated)
end

local function copyStack(itemData, quantity)
    local entry, data = {}, {}
    if itemData.data then
        for k, v in pairs(itemData) do entry[k] = v end
    end
    for k, v in pairs(itemData.data or itemData) do data[k] = v end
    data.quantity, entry.data, entry.quantity = quantity, data, quantity
    return entry
end

-- Manual drops respect the chosen cell. Only quick transfers may repack cargo.
function InventorySystem:placeCargo(entry, anchor, rotated)
    local existing = self.items[self:cargoAnchor(anchor)]
    local data = entry.data or entry
    local amount = entry.quantity or 1
    if existing then
        local total = (existing.quantity or 1) + amount
        if not data.stackable or existing.data.id ~= data.id or total > (data.maxStack or 99) then return false end
        existing.quantity, existing.data.quantity = total, total
    else
        if not Grid.fits(Grid.occupancy(self.items), self.maxSlots, anchor, entry, rotated) then return false end
        local stack = copyStack(entry, amount)
        stack.rotated = rotated
        self.items[anchor] = stack
    end
    self:evaluateSynergies()
    return true
end

function InventorySystem:equipLoot(entry, name, slot)
    local comp = self:getCompartment(name)
    local data = entry.data or entry
    if not comp or slot < 1 or slot > comp.maxSlots or comp.items[slot] then return false end
    if name == 'weapons' then
        if slot == 1 or data.category ~= 'equipable' or data.equipType ~= 'weapon' then return false end
        comp.items[slot] = copyStack(entry, entry.quantity or 1)
        self:evaluateSynergies()
        return true
    end
    if name ~= 'eva' and name ~= 'passives' then return false end
    if not allowedIn(comp, data) or (name == 'passives' and data.category ~= 'passive') then return false end
    local item = copyStack(entry, entry.quantity or 1)
    comp.items[slot] = item
    if name == 'passives' then handlePassiveEffects(item, self.player, 'apply') end
    self:evaluateSynergies()
    return true
end

local function copyEntries(items)
    local result = {}
    for slot, item in pairs(items or {}) do
        if type(item) == 'table' and item.data and tonumber(slot) then
            local entry = copyStack(item, item.quantity or item.data.quantity or 1)
            entry.passiveId = nil
            result[tonumber(slot)] = entry
        end
    end
    return result
end

function InventorySystem:saveState()
    local compartments = {}
    for _, name in ipairs({'eva', 'weapons', 'passives'}) do
        local comp = self:getCompartment(name)
        compartments[name] = {maxSlots = comp.maxSlots, items = copyEntries(comp.items)}
    end
    return {gridVersion = Grid.version, shipType = self.shipType, columns = self.columns, items = copyEntries(self.items),
        recoveryCargo = copyEntries(self.recoveryCargo), compartments = compartments}
end

function InventorySystem:loadState(state)
    self.shipType = state.shipType or self.shipType
    self:restoreCargo(copyEntries(state.items), copyEntries(state.recoveryCargo),
        (state.gridVersion or 0) >= 1, state.columns or Grid.columns)
    for _, name in ipairs({'eva', 'weapons', 'passives'}) do
        local saved = state.compartments and state.compartments[name]
        local comp = self:getCompartment(name)
        if saved then
            if name == 'passives' then
                for _, item in pairs(comp.items) do handlePassiveEffects(item, self.player, 'remove') end
            elseif name == 'eva' then comp.maxSlots = saved.maxSlots or comp.maxSlots end
            comp.items = copyEntries(saved.items)
            if name == 'passives' then
                for _, item in pairs(comp.items) do handlePassiveEffects(item, self.player, 'apply') end
            end
        end
    end
    self:evaluateSynergies()
end

local function addToStorage(self, comp, itemData, quantity, autoPack)
    if type(quantity) ~= 'number' or quantity < 1 or quantity % 1 ~= 0 then return false end
    local data = itemData.data or itemData
    local maximum = data.stackable and (data.maxStack or 99) or 1
    local topUps, placements = {}, {}
    if data.stackable then
        for slot = 1, comp.maxSlots do
            local item = comp.items[slot]
            if quantity > 0 and item and item.data.id == data.id then
                local current = item.quantity or item.data.quantity or 1
                local add = math.min(quantity, math.max(0, maximum - current))
                topUps[item] = current + add
                quantity = quantity - add
            end
        end
    end
    local isCargo = comp.name == 'ship'
    local cells = isCargo and Grid.occupancy(comp.items, nil, nil, comp.columns)
    local incoming = {}
    if math.ceil(quantity / maximum) > comp.maxSlots then return false end
    while quantity > 0 do
        local amount = math.min(maximum, quantity)
        incoming[#incoming + 1] = copyStack(itemData, amount)
        quantity = quantity - amount
    end
    local packed
    for _, item in ipairs(incoming) do
        local anchor, rotated
        if isCargo then anchor, rotated = Grid.find(cells, comp.maxSlots, item, comp.columns)
        else
            for slot = 1, comp.maxSlots do
                if not comp.items[slot] and not placements[slot] then anchor = slot; break end
            end
        end
        if not anchor then
            if not isCargo or not autoPack then return false end
            local all = {}
            for slot = 1, comp.maxSlots do
                if comp.items[slot] then all[#all + 1] = comp.items[slot] end
            end
            for _, entry in ipairs(incoming) do all[#all + 1] = entry end
            packed = Grid.pack(comp.maxSlots, all, comp.columns)
            if not packed then return false end
            break
        end
        placements[anchor] = item
        if isCargo then
            item.rotated = rotated
            Grid.claim(cells, anchor, item, nil, comp.columns)
        end
    end
    for item, total in pairs(topUps) do item.quantity, item.data.quantity = total, total end
    if packed then
        applyPacking(comp.items, comp.maxSlots, packed)
    else
        for anchor, item in pairs(placements) do
            comp.items[anchor] = item
            if comp.name == 'passives' then handlePassiveEffects(item, self.player, 'apply') end
        end
    end
    self:evaluateSynergies()
    return true
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
    if name == "ship" and self.compartments.ship then
        self.compartments.ship.items = self.items
    end
    return self.compartments[name]
end

function InventorySystem:addItemToCompartment(name, itemData, quantity, autoPack)
    local c = self:getCompartment(name)
    if not c or not c.items or not itemData then return false end
    
    local rawData = (type(itemData) == "table" and itemData.data) or itemData
    quantity = quantity or (type(itemData) == "table" and (itemData.quantity or (itemData.data and itemData.data.quantity))) or 1

    -- Validaciones específicas para compartimento de armas
    if name == "weapons" then
        return self:addWeaponToSlot(rawData, nil, quantity)
    end
    
    -- Validaciones específicas para compartimento de pasivos
    if name == "passives" then
        if not rawData or rawData.category ~= ItemSystem.CATEGORIES.PASSIVE then
            return false
        end
    end

    -- Validación opcional de tipos permitidos en el compartimento
    if not allowedIn(c, rawData) then return false end
    
    return addToStorage(self, c, itemData, quantity, autoPack)
end

function InventorySystem:removeItemFromCompartment(name, slotIndex)
    local c = self:getCompartment(name)
    if not c or not c.items or not slotIndex then return nil end
    if name == 'ship' then slotIndex = self:cargoAnchor(slotIndex) or slotIndex end
    if slotIndex >= 1 and slotIndex <= c.maxSlots then
        local item = c.items[slotIndex]
        
        -- Remover efectos pasivos si se está removiendo del compartimento de pasivos
        if name == "passives" then
            handlePassiveEffects(item, self.player, "remove")
        end
        
        c.items[slotIndex] = nil
        self:evaluateSynergies()
        return item
    end
    return nil
end

local function placementsNear(cells, occupied, capacity, columns, destination, item)
    local choices = {}
    local preferred = item.rotated == true
    local column, row = (destination - 1) % columns, math.floor((destination - 1) / columns)
    for turn = 1, Grid.canRotate(item) and 2 or 1 do
        local rotated = (turn == 1 and preferred) or (turn == 2 and not preferred)
        local w, h = Grid.dimensions(item, rotated)
        for anchor = 1, capacity do
            if Grid.fits(cells, capacity, anchor, item, rotated, columns) then
                local touchesDestination = false
                for y = 0, h - 1 do
                    for x = 0, w - 1 do
                        if occupied[anchor + y * columns + x] == destination then touchesDestination = true end
                    end
                end
                if touchesDestination then
                    local distance = math.abs((anchor - 1) % columns - column)
                        + math.abs(math.floor((anchor - 1) / columns) - row)
                    choices[#choices + 1] = {anchor = anchor, rotated = rotated, cost = distance * 3 + turn - 1}
                end
            end
        end
    end
    return choices
end

local function planCargoSwap(self, occupied, origin, swapAnchor, destinations)
    local columns = self.columns
    local item, swap = self.items[origin], self.items[swapAnchor]
    local cells = Grid.occupancy(self.items, origin, swapAnchor, columns)
    destinations = destinations or placementsNear(cells, occupied, self.maxSlots, columns, swapAnchor, item)
    local returns = placementsNear(cells, occupied, self.maxSlots, columns, origin, swap)
    local best, bestCost
    for _, destination in ipairs(destinations) do
        local placed = Grid.occupancy(self.items, origin, swapAnchor, columns)
        Grid.claim(placed, destination.anchor, item, destination.rotated, columns)
        for _, returning in ipairs(returns) do
            local cost = destination.cost + returning.cost
            if (not bestCost or cost < bestCost)
                and Grid.fits(placed, self.maxSlots, returning.anchor, swap, returning.rotated, columns) then
                bestCost = cost
                best = {origin = origin, target = destination.anchor, rotated = destination.rotated,
                    swap = swap, swapOrigin = swapAnchor, swapTarget = returning.anchor, swapRotated = returning.rotated}
            end
        end
    end
    return best
end

local function footprintBlocker(occupied, columns, anchor, w, h, origin)
    local blocker
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local other = occupied[anchor + y * columns + x]
            if other and other ~= origin then
                if blocker and blocker ~= other then return false end
                blocker = other
            end
        end
    end
    return blocker
end

local function planCargoLanding(self, occupied, origin, hovered, offsetX, offsetY)
    local item, columns = self.items[origin], self.columns
    local preferred = item.rotated == true
    local column, row = (hovered - 1) % columns, math.floor((hovered - 1) / columns)
    local empty, overlaps = {}, {}
    local best, bestCost
    -- Consider every legal anchor under which the released cell belongs to the item.
    for turn = 1, Grid.canRotate(item) and 2 or 1 do
        local rotated = (turn == 1 and preferred) or (turn == 2 and not preferred)
        local w, h = Grid.dimensions(item, rotated)
        for y = 0, math.min(h - 1, row) do
            for x = 0, math.min(w - 1, column) do
                local anchor = hovered - x - y * columns
                if Grid.fits(empty, self.maxSlots, anchor, item, rotated, columns) then
                    local cost = (turn - 1) * (columns + self.maxSlots) + math.abs(x - offsetX) + math.abs(y - offsetY)
                    local blocker = footprintBlocker(occupied, columns, anchor, w, h, origin)
                    if blocker then
                        overlaps[#overlaps + 1] = {anchor = anchor, rotated = rotated, cost = cost, blocker = blocker}
                    elseif blocker == nil and (not bestCost or cost < bestCost) then
                        bestCost = cost
                        best = {origin = origin, target = anchor, rotated = rotated}
                    end
                end
            end
        end
    end
    if best then return best end

    for _, placement in ipairs(overlaps) do
        local swap = planCargoSwap(self, occupied, origin, placement.blocker, {placement})
        if swap and (not bestCost or placement.cost < bestCost) then
            best, bestCost = swap, placement.cost
        end
    end
    return best
end

function InventorySystem:previewCargoMove(fromSlot, hovered, rotated, offsetX, offsetY)
    if not hovered or hovered < 1 or hovered > self.maxSlots then return end
    local columns = self.columns
    local occupied = Grid.occupancy(self.items, nil, nil, columns)
    local origin = occupied[fromSlot]
    if not origin then return end
    local swapAnchor = occupied[hovered]
    if swapAnchor and swapAnchor ~= origin then
        return planCargoSwap(self, occupied, origin, swapAnchor)
    end
    if offsetX ~= nil then
        return planCargoLanding(self, occupied, origin, hovered, offsetX, offsetY or 0)
    end

    local item = self.items[origin]
    local current = item.rotated == true
    if rotated ~= nil then current = rotated end
    local cells = Grid.occupancy(self.items, origin, nil, columns)
    if Grid.fits(cells, self.maxSlots, hovered, item, current, columns) then
        return {origin = origin, target = hovered, rotated = current}
    end
end

function InventorySystem:moveItemWithinCompartment(name, fromSlot, toSlot, rotated, offsetX, offsetY)
    local c = self:getCompartment(name)
    if not c or not c.items or not fromSlot or not toSlot then return false end
    if name == 'weapons' and (fromSlot == 1 or toSlot == 1) then return false end
    if name == 'ship' then
        local move = self:previewCargoMove(fromSlot, toSlot, rotated, offsetX, offsetY)
        if not move then return false end
        local item = c.items[move.origin]
        c.items[move.origin] = nil
        item.rotated = move.rotated
        if move.swap then
            c.items[move.swapOrigin] = nil
            move.swap.rotated = move.swapRotated
            c.items[move.swapTarget] = move.swap
        end
        c.items[move.target] = item
        self:evaluateSynergies()
        return true
    end
    if fromSlot >= 1 and fromSlot <= c.maxSlots and toSlot >= 1 and toSlot <= c.maxSlots then
        local item = c.items[fromSlot]
        c.items[fromSlot] = c.items[toSlot]
        c.items[toSlot] = item
        self:evaluateSynergies()
        return true
    end
    return false
end

function InventorySystem:transferItemBetweenCompartments(fromName, fromSlot, toName, toSlot)
    local fromC = self:getCompartment(fromName)
    local toC = self:getCompartment(toName)
    if not fromC or not toC or not fromC.items or not toC.items then return false end
    if fromName == toName then return self:moveItemWithinCompartment(fromName, fromSlot, toSlot) end
    if fromName == 'ship' then fromSlot = self:cargoAnchor(fromSlot) end
    if not fromSlot or not fromC.items[fromSlot] then return false end
    local itemFrom = fromC.items[fromSlot]
    local cargoRotation
    if toName == 'ship' then
        if toSlot then toSlot = self:cargoAnchor(toSlot) or toSlot
        else toSlot, cargoRotation = self:findCargoSlot(itemFrom) end
    end
    
    -- Validar que los slots sean válidos (no nil y dentro de rango)
    if not fromSlot or not toSlot then return false end
    if fromSlot < 1 or fromSlot > fromC.maxSlots or toSlot < 1 or toSlot > toC.maxSlots then return false end

    local itemTo = toC.items[toSlot]
    if fromName == 'ship' and itemTo
        and not Grid.fits(Grid.occupancy(self.items, fromSlot, nil, self.columns),
            self.maxSlots, fromSlot, itemTo, nil, self.columns) then return false end
    if toName == 'ship' and not Grid.fits(Grid.occupancy(self.items, toSlot, nil, self.columns),
        self.maxSlots, toSlot, itemFrom, cargoRotation, self.columns) then return false end

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

    -- Validar tipos permitidos en destino (validación general) usando el mapeo centralizado
    if not allowedIn(toC, itemFrom.data) or (itemTo and not allowedIn(fromC, itemTo.data)) then return false end

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
    if cargoRotation ~= nil then itemFrom.rotated = cargoRotation end
    toC.items[toSlot] = itemFrom

    self:evaluateSynergies()

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
    
    -- Equipar arma (con robustez contra doble anidación y clonación de instancia para modificadores de sinergia)
    if type(weaponData) == "table" and weaponData.data then
        weaponsComp.items[slot] = weaponData
        if quantity and quantity > 1 then
            weaponsComp.items[slot].quantity = quantity
        end
    else
        local clonedWeapon = {}
        for k, v in pairs(weaponData) do clonedWeapon[k] = v end
        weaponsComp.items[slot] = {
            data = clonedWeapon,
            quantity = quantity
        }
    end
    
    self:evaluateSynergies()
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
    self:evaluateSynergies()
    return weapon
end

function InventorySystem:evaluateSynergies()
    if self.player and SynergyEngine and SynergyEngine.evaluate then
        return SynergyEngine.evaluate(self.player)
    end
    return nil
end

function InventorySystem:getWeaponInSlot(slot)
    local weaponsComp = self:getCompartment('weapons')
    if not weaponsComp or not slot or slot < 1 or slot > weaponsComp.maxSlots then
        return nil
    end
    return weaponsComp.items[slot]
end

function InventorySystem:isDefaultWeapon(weaponId)
    -- Lista de armas por defecto (coincide con DEFAULT_WEAPONS en weapon_system.lua)
    local defaultWeapons = {
        "basic_laser_pistol",
        "kinetic_assault_rifle",
        "heavy_plasma_cannon",
        "energy_shotgun",
        "plasma_rifle",
        "laser_basic"
    }
    
    for _, defaultId in ipairs(defaultWeapons) do
        if weaponId == defaultId then
            return true
        end
    end
    -- Permitir también armas evolucionadas si el arma inicial evolucionó en el Slot 1
    local tpl = ItemSystem:getItem(weaponId)
    if tpl and tpl.isEvolved then
        return true
    end
    return false
end

-- Transferir arma al inventario principal
function InventorySystem:transferWeaponToInventory(slot)
    local weaponsComp = self:getCompartment('weapons')
    local maxWeaponSlots = (weaponsComp and weaponsComp.maxSlots) or 9
    if not slot or slot < 1 or slot > maxWeaponSlots then return false end
    
    -- No se puede remover el arma del slot 1 (arma por defecto)
    if slot == 1 then
        return false
    end
    
    local weaponItem = self:getWeaponInSlot(slot)
    if not weaponItem then return false end
    
    return self:transferItemBetweenCompartments('weapons', slot, 'ship')
end

-- Transferir item desde inventario principal a slot de arma
function InventorySystem:transferItemToWeaponSlot(inventorySlot, weaponSlot)
    return self:transferItemBetweenCompartments("ship", inventorySlot, "weapons", weaponSlot)
end

-- Intercambiar items entre compartimentos
function InventorySystem:swapItemsBetweenCompartments(fromName, fromSlot, toName, toSlot)
    return self:transferItemBetweenCompartments(fromName, fromSlot, toName, toSlot)
end

return InventorySystem
