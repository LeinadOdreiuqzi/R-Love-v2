-- Sistema de Items en el Mundo para Space Roguelike
-- Maneja items que se encuentran en el mapa y pueden ser recolectados

local WorldItems = {}
WorldItems.__index = WorldItems

-- Lista global de items en el mundo
local worldItems = {}
local nextItemId = 1

-- Configuración
local CONFIG = {
    PICKUP_DISTANCE = 80,        -- Distancia para recoger items
    EVA_PICKUP_DISTANCE = 30,    -- Distancia para recoger en EVA
    ITEM_SIZE = 16,              -- Tamaño visual del item
    BOUNCE_HEIGHT = 8,           -- Altura del rebote
    BOUNCE_SPEED = 2,            -- Velocidad del rebote
    FADE_TIME = 0.5,             -- Tiempo antes de que aparezca el item (segundos)
    DESPAWN_TIME = 300,          -- Tiempo antes de que desaparezca (segundos)
    DROP_VELOCITY = 30,          -- Velocidad inicial al lanzar (reducida)
    DROP_SPREAD = 20,            -- Dispersión al lanzar múltiples items (reducida)
    -- Configuración de recolección
    COLLECTION = {
        AUTO_PICKUP = false, -- Recolección automática deshabilitada
        RANGE = 80, -- Rango de recolección
        SHIP_RANGE = 80, -- Rango para naves
        EVA_RANGE = 60 -- Rango para EVA (menor que naves)
    }
}

-- Crear un nuevo item en el mundo
function WorldItems.create(itemData, x, y, quantity)
    quantity = quantity or 1
    
    local worldItem = {
        id = nextItemId,
        itemData = itemData,
        quantity = quantity,
        x = x,
        y = y,
        
        -- Propiedades visuales
        bounceOffset = 0,
        bounceTime = 0,
        alpha = 0,
        
        -- Propiedades de tiempo
        spawnTime = love.timer.getTime(),
        fadeInComplete = false,
        
        -- Propiedades físicas
        velocityX = 0,
        velocityY = 0,
        friction = 0.95
    }
    
    nextItemId = nextItemId + 1
    table.insert(worldItems, worldItem)
    
    return worldItem
end

-- Lanzar item desde una posición con velocidad
function WorldItems.drop(itemData, fromX, fromY, targetX, targetY, quantity)
    local worldItem = WorldItems.create(itemData, fromX, fromY, quantity)
    
    -- Calcular velocidad hacia el objetivo
    local dx = targetX - fromX
    local dy = targetY - fromY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > 0 then
        local speed = CONFIG.DROP_VELOCITY
        worldItem.velocityX = (dx / distance) * speed
        worldItem.velocityY = (dy / distance) * speed
    end
    
    -- Agregar algo de dispersión aleatoria
    worldItem.velocityX = worldItem.velocityX + (math.random() - 0.5) * CONFIG.DROP_SPREAD
    worldItem.velocityY = worldItem.velocityY + (math.random() - 0.5) * CONFIG.DROP_SPREAD
    
    return worldItem
end

-- Actualizar todos los items en el mundo
function WorldItems.update(dt)
    local currentTime = love.timer.getTime()
    
    for i = #worldItems, 1, -1 do
        local item = worldItems[i]
        
        -- Actualizar física
        item.x = item.x + item.velocityX * dt
        item.y = item.y + item.velocityY * dt
        item.velocityX = item.velocityX * item.friction
        item.velocityY = item.velocityY * item.friction
        
        -- Actualizar animación de rebote
        item.bounceTime = item.bounceTime + dt * CONFIG.BOUNCE_SPEED
        item.bounceOffset = math.sin(item.bounceTime) * CONFIG.BOUNCE_HEIGHT
        
        -- Actualizar fade in
        local timeSinceSpawn = currentTime - item.spawnTime
        if not item.fadeInComplete then
            if timeSinceSpawn >= CONFIG.FADE_TIME then
                item.alpha = 1
                item.fadeInComplete = true
            else
                item.alpha = math.min(1, timeSinceSpawn / CONFIG.FADE_TIME)
            end
        end
        
        -- Verificar despawn
        if timeSinceSpawn >= CONFIG.DESPAWN_TIME then
            table.remove(worldItems, i)
        end
    end
end

-- Renderizar todos los items en el mundo
function WorldItems.draw(camera, playerX, playerY)
    if not camera then return 0 end
    
    local itemsRendered = 0
    local currentTime = love.timer.getTime()
    playerX = playerX or 0
    playerY = playerY or 0
    
    for _, item in ipairs(worldItems) do
        if item.alpha > 0 then
            -- Convertir coordenadas del mundo a pantalla
            local screenX, screenY = camera:worldToScreen(item.x, item.y) -- solo para culling
            screenY = screenY + item.bounceOffset
            local worldX, worldY = item.x, item.y + item.bounceOffset
            
            if screenX > -CONFIG.ITEM_SIZE and screenX < love.graphics.getWidth() + CONFIG.ITEM_SIZE and
               screenY > -CONFIG.ITEM_SIZE and screenY < love.graphics.getHeight() + CONFIG.ITEM_SIZE then
                
                -- Guardar color actual
                local r, g, b, a = love.graphics.getColor()
                
                -- Aplicar alpha y color de rareza
                local rarity = item.itemData.rarity
                local rarityColor = {1, 1, 1} -- Color por defecto (blanco)
                
                -- Obtener color de rareza de forma segura
                if rarity then
                    if type(rarity) == "table" and rarity.color then
                        rarityColor = rarity.color
                    elseif type(rarity) == "string" then
                        -- Si es string, usar colores por defecto del sistema
                        local ItemSystem = require("src.item_systems.item_system")
                        local rarityData = ItemSystem.RARITY[rarity:upper()]
                        if rarityData and rarityData.color then
                            rarityColor = rarityData.color
                        end
                    end
                end
                
                local baseAlpha = item.alpha
                
                -- Efecto de brillo pulsante
                local pulseAlpha = baseAlpha + math.sin(currentTime * 3) * 0.2
                pulseAlpha = math.max(0.3, math.min(1, pulseAlpha))
                
                love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], pulseAlpha)
                
                -- Dibujar item (rectángulo con esquinas redondeadas)
                local itemSize = CONFIG.ITEM_SIZE
                love.graphics.rectangle("fill", worldX - itemSize/2, worldY - itemSize/2, 
                                      itemSize, itemSize, 3, 3)
                
                -- Dibujar borde brillante
                love.graphics.setColor(1, 1, 1, pulseAlpha * 0.9)
                love.graphics.rectangle("line", worldX - itemSize/2, worldY - itemSize/2, 
                                      itemSize, itemSize, 3, 3)
                
                -- Efecto de aura para items raros
                local hasAura = false
                if rarity then
                    if type(rarity) == "table" and rarity.name and rarity.name ~= "Común" then
                        hasAura = true
                    elseif type(rarity) == "string" and rarity:upper() ~= "COMMON" then
                        hasAura = true
                    end
                end
                
                if hasAura then
                    local auraSize = itemSize + 8 + math.sin(currentTime * 4) * 3
                    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], pulseAlpha * 0.3)
                    love.graphics.rectangle("line", worldX - auraSize/2, worldY - auraSize/2, 
                                          auraSize, auraSize, 5, 5)
                end
                
                -- Indicador de proximidad para recolección
                local distanceToPlayer = math.sqrt((item.x - playerX)^2 + (item.y - playerY)^2)
                if distanceToPlayer <= CONFIG.PICKUP_DISTANCE then
                    -- Círculo de proximidad pulsante
                    local proximityAlpha = 0.4 + math.sin(currentTime * 6) * 0.3
                    love.graphics.setColor(0, 1, 0, proximityAlpha)
                    love.graphics.circle("line", worldX, worldY, CONFIG.PICKUP_DISTANCE * 0.3)
                    
                    -- Texto indicativo
                    love.graphics.setColor(1, 1, 1, proximityAlpha)
                    love.graphics.print("[E]", worldX - 8, worldY - itemSize - 15)
                end
                
                -- Dibujar cantidad si es mayor a 1
                if item.quantity > 1 then
                    love.graphics.setColor(1, 1, 1, baseAlpha)
                    love.graphics.print(tostring(item.quantity), worldX + itemSize/2 - 8, 
                                      worldY - itemSize/2 - 2)
                end
                
                -- Restaurar color
                love.graphics.setColor(r, g, b, a)
                
                itemsRendered = itemsRendered + 1
            end
        end
    end
    
    return itemsRendered
end

-- Intentar recoger items cerca de una posición
function WorldItems.tryPickup(x, y, inventory, isEVA)
    local pickupDistance = isEVA and CONFIG.EVA_PICKUP_DISTANCE or CONFIG.PICKUP_DISTANCE
    local pickedItems = {}
    
    for i = #worldItems, 1, -1 do
        local item = worldItems[i]
        
        -- Verificar distancia
        local dx = item.x - x
        local dy = item.y - y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance <= pickupDistance and item.fadeInComplete then
            -- Intentar agregar al inventario
            local success = false
            
            if inventory and inventory.addItem then
                success = inventory:addItem(item.itemData, item.quantity)
            elseif inventory and inventory.items then
                -- Buscar slot vacío
                for slot = 1, (inventory.maxSlots or 12) do
                    if not inventory.items[slot] then
                        inventory.items[slot] = {
                            data = item.itemData,
                            quantity = item.quantity
                        }
                        success = true
                        break
                    end
                end
            end
            
            if success then
                table.insert(pickedItems, {
                    name = item.itemData.name,
                    quantity = item.quantity
                })
                table.remove(worldItems, i)
            end
        end
    end
    
    return pickedItems
end

-- Obtener items cerca de una posición (para mostrar en UI)
function WorldItems.getNearbyItems(x, y, distance)
    distance = distance or CONFIG.PICKUP_DISTANCE
    local nearbyItems = {}
    
    for _, item in ipairs(worldItems) do
        local dx = item.x - x
        local dy = item.y - y
        local itemDistance = math.sqrt(dx * dx + dy * dy)
        
        if itemDistance <= distance and item.fadeInComplete then
            table.insert(nearbyItems, {
                item = item,
                distance = itemDistance
            })
        end
    end
    
    -- Ordenar por distancia
    table.sort(nearbyItems, function(a, b) return a.distance < b.distance end)
    
    return nearbyItems
end

-- Limpiar todos los items del mundo
function WorldItems.clear()
    worldItems = {}
    nextItemId = 1
end

-- Verificar recolección por proximidad
function WorldItems.checkCollection(item)
    if not CONFIG.COLLECTION.AUTO_PICKUP then
        return false
    end
    
    -- Obtener todas las naves del sistema
    local Naves = require 'src.entities.naves'
    local allShips = Naves.getAllShips()
    
    if not allShips then return false end
    
    for _, ship in ipairs(allShips) do
        if ship then
            -- Obtener entidad activa (nave o EVA player)
            local activeEntity = ship:getActiveEntity()
            if activeEntity then
                local distance = math.sqrt((activeEntity.x - item.x)^2 + (activeEntity.y - item.y)^2)
                
                -- Determinar rango de recolección según el tipo de entidad
                local collectionRange
                if ship.isInEVA and ship.evaPlayer then
                    collectionRange = CONFIG.COLLECTION.EVA_RANGE
                else
                    collectionRange = CONFIG.COLLECTION.SHIP_RANGE
                end
                
                if distance <= collectionRange then
                    -- Intentar agregar item al inventario
                    local success = WorldItems.collectItem(item, ship)
                    if success then
                        local entityType = ship.isInEVA and "EVA" or "NAVE"
                        print("[COLLECTION] Item recolectado por", entityType .. ":", item.itemData.name, "x" .. item.quantity)
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Función para recolección manual (tecla E)
function WorldItems.tryManualCollection()
    -- Obtener todas las naves del sistema
    local Naves = require 'src.entities.naves'
    local allShips = Naves.getAllShips()
    
    if not allShips then return false end
    
    for _, ship in ipairs(allShips) do
        if ship then
            -- Obtener entidad activa (nave o EVA player)
            local activeEntity = ship:getActiveEntity()
            if activeEntity then
                -- Determinar rango de recolección según el tipo de entidad
                local collectionRange
                if ship.isInEVA and ship.evaPlayer then
                    collectionRange = CONFIG.COLLECTION.EVA_RANGE
                else
                    collectionRange = CONFIG.COLLECTION.SHIP_RANGE
                end
                
                -- Buscar el item más cercano dentro del rango
                local closestItem = nil
                local closestDistance = math.huge
                
                for _, item in ipairs(worldItems) do
                    local distance = math.sqrt((activeEntity.x - item.x)^2 + (activeEntity.y - item.y)^2)
                    if distance <= collectionRange and distance < closestDistance then
                        closestItem = item
                        closestDistance = distance
                    end
                end
                
                -- Recolectar el item más cercano
                if closestItem then
                    local success = WorldItems.collectItem(closestItem, ship)
                    if success then
                        -- Remover item de la lista
                        for i, item in ipairs(worldItems) do
                            if item == closestItem then
                                table.remove(worldItems, i)
                                break
                            end
                        end
                        
                        local entityType = ship.isInEVA and "EVA" or "NAVE"
                        print("[MANUAL COLLECTION] Item recolectado por", entityType .. ":", closestItem.itemData.name, "x" .. closestItem.quantity)
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Recolectar item y agregarlo al inventario correcto según el estado del jugador
function WorldItems.collectItem(item, ship)
    if not item or not ship or not ship.inventory then
        return false
    end
    
    local ItemSystem = require 'src.item_systems.items.init'
    
    -- Crear instancia del item para el inventario
    local itemInstance = ItemSystem.createItem(item.itemData.id, item.quantity)
    if not itemInstance then
        print("[COLLECTION] Error: No se pudo crear instancia del item", item.itemData.id)
        return false
    end
    
    -- Determinar el inventario de destino según el estado del jugador
    local targetInventory
    local maxSlots
    local inventoryType
    
    if ship.isInEVA then
        -- Jugador en EVA: usar inventario EVA
        if ship.inventory.compartments and ship.inventory.compartments.eva then
            targetInventory = ship.inventory.compartments.eva.items
            maxSlots = ship.inventory.compartments.eva.maxSlots or 3
            inventoryType = "EVA"
            
            -- Verificar si el item es permitido en EVA
            -- Mapear categorías del sistema de items a tipos permitidos en EVA
            local categoryToEVAType = {
                ["consumable"] = "consumable",
                ["equipable"] = "tool",  -- Los equipables se consideran herramientas en EVA
                ["material"] = "resource"  -- Los materiales se consideran recursos en EVA
            }
            
            local allowedTypes = {"tool", "consumable", "resource"}
            local itemCategory = item.itemData.category
            local evaType = categoryToEVAType[itemCategory]
            
            local isAllowed = false
            if evaType then
                for _, allowedType in ipairs(allowedTypes) do
                    if evaType == allowedType then
                        isAllowed = true
                        break
                    end
                end
            end
            
            if not isAllowed then
                print("[COLLECTION] Item categoría '" .. (itemCategory or "unknown") .. "' no permitido en inventario EVA")
                return false
            end
        else
            print("[COLLECTION] Error: Inventario EVA no disponible")
            return false
        end
    else
        -- Jugador en nave: usar inventario principal
        if ship.inventory.compartments and ship.inventory.compartments.ship then
            targetInventory = ship.inventory.compartments.ship.items
            maxSlots = ship.inventory.compartments.ship.maxSlots
            inventoryType = "NAVE"
        else
            -- Fallback al inventario legacy
            targetInventory = ship.inventory.items
            maxSlots = ship.inventory.maxSlots
            inventoryType = "NAVE"
        end
    end
    
    if not targetInventory then
        print("[COLLECTION] Error: No se pudo determinar inventario de destino")
        return false
    end
    
    print("[MANUAL COLLECTION] Recolectando en inventario:", inventoryType)
    
    -- Buscar slot vacío en el inventario de destino
    for slot = 1, maxSlots do
        if not targetInventory[slot] then
            targetInventory[slot] = itemInstance
            return true
        end
    end
    
    -- Si no hay espacio, intentar stackear con items existentes
    for slot = 1, maxSlots do
        local existingItem = targetInventory[slot]
        if existingItem and existingItem.data.id == item.itemData.id then
            -- Verificar si el item es stackeable
            if item.itemData.stackable then
                local maxStack = item.itemData.maxStack or 99
                local currentStack = existingItem.data.quantity or 1
                local spaceAvailable = maxStack - currentStack
                
                if spaceAvailable > 0 then
                    local amountToAdd = math.min(spaceAvailable, item.quantity)
                    existingItem.data.quantity = currentStack + amountToAdd
                    
                    -- Si no se pudo agregar todo, crear nuevo item con el resto
                    if amountToAdd < item.quantity then
                        item.quantity = item.quantity - amountToAdd
                        return false -- No se recolectó completamente
                    end
                    
                    return true
                end
            end
        end
    end
    
    print("[COLLECTION] Inventario " .. inventoryType .. " lleno, no se puede recolectar:", item.itemData.name)
    return false
end

-- Obtener estadísticas
function WorldItems.getStats()
    return {
        totalItems = #worldItems,
        nextId = nextItemId
    }
end

-- Obtener configuración
function WorldItems.getConfig()
    return CONFIG
end

-- Modificar configuración
function WorldItems.setConfig(newConfig)
    for key, value in pairs(newConfig) do
        if CONFIG[key] ~= nil then
            CONFIG[key] = value
        end
    end
end

return WorldItems