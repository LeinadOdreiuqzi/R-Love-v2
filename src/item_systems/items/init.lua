-- Inicializador del Sistema de Items
-- Registra todos los items y recetas del juego

local ItemSystem = require("src.item_systems.item_system")
local Consumables = require("src.item_systems.items.consumables")
local Passives = require("src.item_systems.items.passives")
local Equipables = require("src.item_systems.items.equipables")
local Materials = require("src.item_systems.items.materials")

local ItemInit = {}

-- Función para inicializar todo el sistema de items
function ItemInit.initialize()
    print("=== INICIALIZANDO SISTEMA DE ITEMS ===")
    
    -- Inicializar el sistema base
    ItemSystem:init()
    
    -- Registrar todas las categorías de items
    print("Registrando items...")
    
    -- Registrar materiales primero (pueden ser requeridos por recetas)
    Materials.registerAll()
    
    -- Registrar consumibles
    Consumables.registerAll()
    
    -- Registrar items pasivos
    Passives.registerAll()
    
    -- Registrar equipables
    Equipables.registerAll()
    
    -- Registrar recetas de crafting
    print("Registrando recetas de crafting...")
    Materials.registerBasicRecipes()
    
    -- Mostrar estadísticas
    local totalItems = 0
    for category, items in pairs(ItemSystem.itemsByCategory) do
        local count = #items
        totalItems = totalItems + count
        print(string.format("  %s: %d items", category, count))
    end
    
    local totalRecipes = 0
    for _ in pairs(Materials.recipes) do
        totalRecipes = totalRecipes + 1
    end
    
    print(string.format("Total de items registrados: %d", totalItems))
    print(string.format("Total de recetas registradas: %d", totalRecipes))
    print("=== SISTEMA DE ITEMS INICIALIZADO ===")
    
    return ItemSystem
end

-- Función para obtener un item por ID (wrapper conveniente)
function ItemInit.getItem(id)
    return ItemSystem:getItem(id)
end

-- Función para crear una instancia de item (wrapper conveniente)
function ItemInit.createItem(id, quantity)
    return ItemSystem:createItemInstance(id, quantity)
end

-- Función para obtener items por categoría (wrapper conveniente)
function ItemInit.getItemsByCategory(category)
    return ItemSystem:getItemsByCategory(category)
end

-- Función para usar un item (wrapper conveniente)
function ItemInit.useItem(item, player)
    return ItemSystem:useItem(item, player)
end

-- Función para equipar un item (wrapper conveniente)
function ItemInit.equipItem(item, player)
    return ItemSystem:equipItem(item, player)
end

-- Función para desequipar un item (wrapper conveniente)
function ItemInit.unequipItem(item, player)
    return ItemSystem:unequipItem(item, player)
end

-- Función para craftear un item (wrapper conveniente)
function ItemInit.craftItem(recipeId, inventory, player)
    return Materials.craftItem(recipeId, inventory, player)
end

-- Función para obtener recetas disponibles (wrapper conveniente)
function ItemInit.getAvailableRecipes(inventory)
    return Materials.getAvailableRecipes(inventory)
end

-- NOTA: Las funciones de efectos pasivos ahora se manejan directamente
-- a través del PassiveManager para evitar duplicaciones y centralizar la lógica

-- Función para obtener el daño de un arma
function ItemInit.getWeaponDamage(weapon)
    return Equipables.getWeaponDamage(weapon)
end

-- Función para obtener la defensa total del equipamiento
function ItemInit.getTotalDefense(equipment)
    return Equipables.getTotalDefense(equipment)
end

-- Función para verificar si se puede craftear algo
function ItemInit.canCraft(recipeId, inventory)
    return Materials.canCraft(recipeId, inventory)
end

-- Función para obtener información de una receta
function ItemInit.getRecipeInfo(recipeId)
    return Materials.getRecipeInfo(recipeId)
end

-- Función de utilidad para crear un inventario de prueba
function ItemInit.createTestInventory()
    local inventory = {
        ItemInit.createItem("eva_repair_kit", 3),
        ItemInit.createItem("energy_stim", 5),
        ItemInit.createItem("iron_ore", 20),
        ItemInit.createItem("titanium_ingot", 5),
        ItemInit.createItem("energy_crystal", 3),
        ItemInit.createItem("basic_circuit", 2),
        ItemInit.createItem("basic_laser_pistol", 1),
        ItemInit.createItem("eva_helmet", 1),
        ItemInit.createItem("basic_neural_implant", 1)
    }
    
    print("Inventario de prueba creado con 9 items")
    return inventory
end

-- Exportar referencias útiles
ItemInit.ItemSystem = ItemSystem
ItemInit.Consumables = Consumables
ItemInit.Passives = Passives
ItemInit.Equipables = Equipables
ItemInit.Materials = Materials

-- Exportar constantes útiles
ItemInit.CATEGORIES = ItemSystem.CATEGORIES
ItemInit.RARITY = ItemSystem.RARITY
ItemInit.EQUIPABLE_TYPES = ItemSystem.EQUIPABLE_TYPES
ItemInit.SLOTS = Equipables.SLOTS
ItemInit.MATERIAL_TYPES = Materials.TYPES

return ItemInit