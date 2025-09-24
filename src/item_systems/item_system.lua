-- Sistema de Items para Space Roguelike
-- Maneja diferentes categorías de items: consumibles, pasivos, equipables, materiales

local ItemSystem = {}

-- Categorías de items
ItemSystem.CATEGORIES = {
    CONSUMABLE = "consumable",     -- Items que se usan y desaparecen
    PASSIVE = "passive",           -- Items que otorgan efectos permanentes
    EQUIPABLE = "equipable",       -- Armas, armaduras, herramientas
    MATERIAL = "material",         -- Materiales para crafting
    QUEST = "quest",               -- Items de misión
    CURRENCY = "currency"          -- Monedas, créditos, etc.
}

-- Tipos de items equipables
ItemSystem.EQUIPABLE_TYPES = {
    WEAPON = "weapon",
    ARMOR = "armor",
    TOOL = "tool",
    ACCESSORY = "accessory",
    UTILITY = "utility",
    SHIELD = "shield"
}

-- Rareza de items
ItemSystem.RARITY = {
    COMMON = { name = "Común", color = {0.8, 0.8, 0.8}, value_multiplier = 1.0 },
    UNCOMMON = { name = "Poco Común", color = {0.3, 0.8, 0.3}, value_multiplier = 1.5 },
    RARE = { name = "Raro", color = {0.3, 0.3, 0.8}, value_multiplier = 2.5 },
    EPIC = { name = "Épico", color = {0.8, 0.3, 0.8}, value_multiplier = 4.0 },
    LEGENDARY = { name = "Legendario", color = {1.0, 0.6, 0.0}, value_multiplier = 6.0 }
}

-- Estructura base de un item
local function createBaseItem(id, name, description, category, rarity)
    return {
        id = id,
        name = name,
        description = description,
        category = category,
        rarity = rarity or ItemSystem.RARITY.COMMON,
        stackable = false,
        maxStack = 1,
        value = 0,
        weight = 0,
        icon = nil,
        tags = {},
        
        -- Métodos base
        canUse = function(self, player) return true end,
        use = function(self, player) end,
        onEquip = function(self, player) end,
        onUnequip = function(self, player) end,
        getTooltip = function(self) return self.description end
    }
end

-- Registro de items
ItemSystem.items = {}
ItemSystem.itemsByCategory = {}

-- Inicializar categorías
for _, category in pairs(ItemSystem.CATEGORIES) do
    ItemSystem.itemsByCategory[category] = {}
end

-- Registrar un nuevo item
function ItemSystem:registerItem(itemData)
    if not itemData.id then
        error("Item debe tener un ID único")
    end
    
    if self.items[itemData.id] then
        error("Item con ID '" .. itemData.id .. "' ya existe")
    end
    
    -- Crear item base y fusionar con datos proporcionados
    local item = createBaseItem(
        itemData.id,
        itemData.name,
        itemData.description,
        itemData.category,
        itemData.rarity
    )
    
    -- Fusionar propiedades adicionales
    for key, value in pairs(itemData) do
        if key ~= "id" and key ~= "name" and key ~= "description" and key ~= "category" and key ~= "rarity" then
            item[key] = value
        end
    end
    
    -- Registrar item
    self.items[itemData.id] = item
    table.insert(self.itemsByCategory[itemData.category], item)
    
    return item
end

-- Obtener item por ID
function ItemSystem:getItem(id)
    return self.items[id]
end

-- Crear una instancia de un item
function ItemSystem:createItem(id, quantity)
    local template = self.items[id]
    if not template then
        print("Error: Item con ID '" .. id .. "' no encontrado")
        return nil
    end
    
    -- Crear una copia del template
    local item = {}
    for key, value in pairs(template) do
        if type(value) == "table" then
            -- Copia profunda para tablas
            item[key] = {}
            for k, v in pairs(value) do
                item[key][k] = v
            end
        else
            item[key] = value
        end
    end
    
    -- Establecer cantidad si es stackable
    if item.stackable and quantity then
        item.quantity = math.min(quantity, item.maxStack or 1)
    else
        item.quantity = 1
    end
    
    return item
end

-- Crear instancia de item
function ItemSystem:createItemInstance(id, quantity)
    local template = self:getItem(id)
    if not template then
        error("Item con ID '" .. id .. "' no encontrado")
    end
    
    local instanceData = {}
    for key, value in pairs(template) do
        if type(value) ~= "function" then
            instanceData[key] = value
        else
            instanceData[key] = value
        end
    end
    
    instanceData.quantity = quantity or 1
    instanceData.isInstance = true
    
    -- Crear estructura compatible con el inventario
    local instance = {
        data = instanceData
    }
    
    return instance
end

-- Obtener items por categoría
function ItemSystem:getItemsByCategory(category)
    return self.itemsByCategory[category] or {}
end

-- Verificar si un item es de cierta categoría
function ItemSystem:isCategory(item, category)
    return item.category == category
end

-- Verificar si un item es stackable
function ItemSystem:isStackable(item)
    return item.stackable and item.maxStack > 1
end

-- Obtener valor total de un stack de items
function ItemSystem:getTotalValue(item)
    local baseValue = item.value * (item.rarity.value_multiplier or 1)
    return baseValue * (item.quantity or 1)
end

-- Usar un item
function ItemSystem:useItem(item, player)
    -- Verificar que el item tenga una función use
    if not item.use or type(item.use) ~= "function" then
        return false, "Este item no se puede usar"
    end
    
    local success, result = pcall(item.use, item, player)
    if not success then
        return false, "Error al usar el item: " .. tostring(result)
    end
    
    -- Si es consumible, reducir cantidad
    if self:isCategory(item, self.CATEGORIES.CONSUMABLE) then
        item.quantity = (item.quantity or 1) - 1
        if item.quantity <= 0 then
            return true, "Item consumido completamente"
        end
    end
    
    return true, result or "Item usado exitosamente"
end

-- Equipar un item
function ItemSystem:equipItem(item, player)
    if not self:isCategory(item, self.CATEGORIES.EQUIPABLE) then
        return false, "Este item no se puede equipar"
    end
    
    local success, result = pcall(item.onEquip, item, player)
    if not success then
        return false, "Error al equipar: " .. tostring(result)
    end
    
    return true, result or "Item equipado"
end

-- Desequipar un item
function ItemSystem:unequipItem(item, player)
    if not self:isCategory(item, self.CATEGORIES.EQUIPABLE) then
        return false, "Este item no se puede desequipar"
    end
    
    local success, result = pcall(item.onUnequip, item, player)
    if not success then
        return false, "Error al desequipar: " .. tostring(result)
    end
    
    return true, result or "Item desequipado"
end

-- Inicializar sistema
function ItemSystem:init()
    print("Sistema de Items inicializado")
    
    -- Obtener valores de categorías
    local categories = {}
    for _, category in pairs(self.CATEGORIES) do
        table.insert(categories, category)
    end
    
    print("Categorías disponibles:", table.concat(categories, ", "))
end

return ItemSystem