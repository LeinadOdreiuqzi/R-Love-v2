-- Materiales y Sistema de Crafting para Space Roguelike
-- Materiales básicos y recursos para crear otros items

local ItemSystem = require("src.item_systems.item_system")

local Materials = {}

-- Tipos de materiales
Materials.TYPES = {
    METAL = "metal",
    CRYSTAL = "crystal",
    ORGANIC = "organic",
    ENERGY = "energy",
    RARE_EARTH = "rare_earth",
    ALIEN = "alien",
    SYNTHETIC = "synthetic"
}

-- Recetas de crafting
Materials.recipes = {}

-- Función para registrar una receta
function Materials.registerRecipe(outputId, ingredients, craftingTime, requiredTool)
    Materials.recipes[outputId] = {
        output = outputId,
        ingredients = ingredients, -- { {id = "material_id", quantity = 2}, ... }
        craftingTime = craftingTime or 5,
        requiredTool = requiredTool,
        category = "crafting"
    }
end

-- Función para verificar si se pueden craftear items
function Materials.canCraft(recipeId, inventory)
    local recipe = Materials.recipes[recipeId]
    if not recipe then return false, "Receta no encontrada" end
    
    -- Verificar ingredientes
    for _, ingredient in ipairs(recipe.ingredients) do
        local found = false
        local totalQuantity = 0
        
        for _, item in ipairs(inventory) do
            if item.id == ingredient.id then
                totalQuantity = totalQuantity + (item.quantity or 1)
            end
        end
        
        if totalQuantity < ingredient.quantity then
            return false, "Materiales insuficientes: " .. ingredient.id
        end
    end
    
    return true
end

-- Función para craftear un item
function Materials.craftItem(recipeId, inventory, player)
    local canCraft, error = Materials.canCraft(recipeId, inventory)
    if not canCraft then
        return false, error
    end
    
    local recipe = Materials.recipes[recipeId]
    
    -- Verificar herramienta requerida
    if recipe.requiredTool then
        local hasTool = false
        if player.equipment and player.equipment[recipe.requiredTool] then
            hasTool = true
        end
        
        if not hasTool then
            return false, "Herramienta requerida: " .. recipe.requiredTool
        end
    end
    
    -- Consumir ingredientes
    for _, ingredient in ipairs(recipe.ingredients) do
        local remaining = ingredient.quantity
        
        for i = #inventory, 1, -1 do
            local item = inventory[i]
            if item.id == ingredient.id and remaining > 0 then
                local toConsume = math.min(remaining, item.quantity or 1)
                remaining = remaining - toConsume
                
                if item.quantity then
                    item.quantity = item.quantity - toConsume
                    if item.quantity <= 0 then
                        table.remove(inventory, i)
                    end
                else
                    table.remove(inventory, i)
                end
            end
        end
    end
    
    -- Crear item resultante
    local outputItem = ItemSystem:createItemInstance(recipe.output, 1)
    table.insert(inventory, outputItem)
    
    return true, "Item crafteado exitosamente: " .. outputItem.name
end

-- Función para registrar todos los materiales
function Materials.registerAll()
    -- === METALES ===
    
    -- Hierro
    ItemSystem:registerItem({
        id = "iron_ore",
        name = "Mineral de Hierro",
        description = "Un mineral común usado en la construcción básica.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.COMMON,
        stackable = true,
        maxStack = 100,
        value = 5,
        weight = 0.5,
        icon = "iron_ore",
        tags = {"metal", "common", "construction"},
        materialType = Materials.TYPES.METAL
    })
    
    -- Titanio
    ItemSystem:registerItem({
        id = "titanium_ingot",
        name = "Lingote de Titanio",
        description = "Un metal ligero y resistente, ideal para equipos avanzados.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.UNCOMMON,
        stackable = true,
        maxStack = 50,
        value = 25,
        weight = 0.3,
        icon = "titanium_ingot",
        tags = {"metal", "lightweight", "advanced"},
        materialType = Materials.TYPES.METAL
    })
    
    -- === CRISTALES ===
    
    -- Cristal de Energía
    ItemSystem:registerItem({
        id = "energy_crystal",
        name = "Cristal de Energía",
        description = "Un cristal que almacena energía pura. Usado en tecnología avanzada.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.RARE,
        stackable = true,
        maxStack = 20,
        value = 100,
        weight = 0.2,
        icon = "energy_crystal",
        tags = {"crystal", "energy", "power"},
        materialType = Materials.TYPES.CRYSTAL
    })
    
    -- Cuarzo Espacial
    ItemSystem:registerItem({
        id = "space_quartz",
        name = "Cuarzo Espacial",
        description = "Un cristal formado en el vacío del espacio con propiedades únicas.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.UNCOMMON,
        stackable = true,
        maxStack = 30,
        value = 40,
        weight = 0.1,
        icon = "space_quartz",
        tags = {"crystal", "space", "unique"},
        materialType = Materials.TYPES.CRYSTAL
    })
    
    -- === ORGÁNICOS ===
    
    -- Biomasa Alienígena
    ItemSystem:registerItem({
        id = "alien_biomass",
        name = "Biomasa Alienígena",
        description = "Material orgánico de origen desconocido. Útil para investigación.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.RARE,
        stackable = true,
        maxStack = 10,
        value = 150,
        weight = 0.8,
        icon = "alien_biomass",
        tags = {"organic", "alien", "research"},
        materialType = Materials.TYPES.ORGANIC
    })
    
    -- === SINTÉTICOS ===
    
    -- Polímero Avanzado
    ItemSystem:registerItem({
        id = "advanced_polymer",
        name = "Polímero Avanzado",
        description = "Un material sintético con propiedades excepcionales.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.UNCOMMON,
        stackable = true,
        maxStack = 40,
        value = 30,
        weight = 0.2,
        icon = "advanced_polymer",
        tags = {"synthetic", "advanced", "versatile"},
        materialType = Materials.TYPES.SYNTHETIC
    })
    
    -- Nanofibra
    ItemSystem:registerItem({
        id = "nanofiber",
        name = "Nanofibra",
        description = "Fibras microscópicas extremadamente resistentes.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.RARE,
        stackable = true,
        maxStack = 25,
        value = 80,
        weight = 0.05,
        icon = "nanofiber",
        tags = {"synthetic", "nano", "strong"},
        materialType = Materials.TYPES.SYNTHETIC
    })
    
    -- === ELEMENTOS RAROS ===
    
    -- Elemento Zero
    ItemSystem:registerItem({
        id = "element_zero",
        name = "Elemento Zero",
        description = "Un elemento extremadamente raro que desafía las leyes de la física.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.LEGENDARY,
        stackable = true,
        maxStack = 5,
        value = 1000,
        weight = 0.1,
        icon = "element_zero",
        tags = {"rare_earth", "legendary", "physics"},
        materialType = Materials.TYPES.RARE_EARTH
    })
    
    -- === COMPONENTES BÁSICOS ===
    
    -- Circuito Básico
    ItemSystem:registerItem({
        id = "basic_circuit",
        name = "Circuito Básico",
        description = "Un circuito electrónico simple usado en muchos dispositivos.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.COMMON,
        stackable = true,
        maxStack = 50,
        value = 15,
        weight = 0.1,
        icon = "basic_circuit",
        tags = {"electronic", "component", "basic"},
        materialType = Materials.TYPES.SYNTHETIC
    })
    
    -- Batería de Energía
    ItemSystem:registerItem({
        id = "energy_cell",
        name = "Celda de Energía",
        description = "Una batería compacta que almacena energía eléctrica.",
        category = ItemSystem.CATEGORIES.MATERIAL,
        rarity = ItemSystem.RARITY.COMMON,
        stackable = true,
        maxStack = 30,
        value = 20,
        weight = 0.3,
        icon = "energy_cell",
        tags = {"energy", "battery", "power"},
        materialType = Materials.TYPES.ENERGY
    })
    
    print("Materiales registrados: 10 items")
end

-- Función para registrar recetas básicas
function Materials.registerBasicRecipes()
    -- Receta: Kit de Reparación EVA
    Materials.registerRecipe("eva_repair_kit", {
        { id = "advanced_polymer", quantity = 2 },
        { id = "basic_circuit", quantity = 1 },
        { id = "energy_cell", quantity = 1 }
    }, 10)
    
    -- Receta: Estimulante de Energía
    Materials.registerRecipe("energy_stim", {
        { id = "alien_biomass", quantity = 1 },
        { id = "energy_crystal", quantity = 1 }
    }, 5)
    
    -- Receta: Circuito Básico
    Materials.registerRecipe("basic_circuit", {
        { id = "iron_ore", quantity = 3 },
        { id = "space_quartz", quantity = 1 }
    }, 8, "tool_repair")
    
    -- Receta: Polímero Avanzado
    Materials.registerRecipe("advanced_polymer", {
        { id = "iron_ore", quantity = 2 },
        { id = "energy_cell", quantity = 1 }
    }, 12)
    
    -- Receta: Pistola Láser Básica
    Materials.registerRecipe("basic_laser_pistol", {
        { id = "titanium_ingot", quantity = 3 },
        { id = "energy_crystal", quantity = 2 },
        { id = "basic_circuit", quantity = 2 }
    }, 30, "tool_repair")
    
    print("Recetas básicas registradas: 5 recetas")
end

-- Función para obtener todas las recetas disponibles
function Materials.getAvailableRecipes(inventory)
    local available = {}
    
    for recipeId, recipe in pairs(Materials.recipes) do
        local canCraft = Materials.canCraft(recipeId, inventory)
        if canCraft then
            table.insert(available, recipe)
        end
    end
    
    return available
end

-- Función para obtener información de una receta
function Materials.getRecipeInfo(recipeId)
    local recipe = Materials.recipes[recipeId]
    if not recipe then return nil end
    
    local outputItem = ItemSystem:getItem(recipe.output)
    if not outputItem then return nil end
    
    local info = {
        name = outputItem.name,
        description = outputItem.description,
        ingredients = {},
        craftingTime = recipe.craftingTime,
        requiredTool = recipe.requiredTool
    }
    
    for _, ingredient in ipairs(recipe.ingredients) do
        local item = ItemSystem:getItem(ingredient.id)
        if item then
            table.insert(info.ingredients, {
                name = item.name,
                quantity = ingredient.quantity
            })
        end
    end
    
    return info
end

return Materials