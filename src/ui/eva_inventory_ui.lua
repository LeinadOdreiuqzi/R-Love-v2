-- src/ui/eva_inventory_ui.lua
-- UI específica para el inventario EVA (3 slots)

local EVAInventoryUI = {}

-- Reutilizar paleta de colores del InventoryUI
local InventoryUI = require 'src.ui.inventory_ui'

-- Estado de la UI EVA
local evaUIState = {
    isOpen = false,
    selectedSlot = nil,
    
    -- Modal de opciones
    modal = {
        isOpen = false,
        slotIndex = nil,
        x = 0,
        y = 0,
        width = 120,
        height = 90
    },
    
    -- Configuración visual
    slotSize = 60,
    slotPadding = 10,
    panelPadding = 15,
    
    -- Colores (se inicializarán desde InventoryUI en init)
    colors = nil,
    
    -- Layout
    layout = {
        panelX = 0,
        panelY = 0,
        panelWidth = 0,
        panelHeight = 0
    }
}

-- Inicializar UI EVA
function EVAInventoryUI:init()
    -- Obtener paleta de colores compartida del InventoryUI
    evaUIState.colors = InventoryUI.getColors and InventoryUI:getColors() or {
        background = {0.05, 0.05, 0.1, 0.9},
        slotEmpty = {0.15, 0.15, 0.2, 1},
        slotFilled = {0.25, 0.25, 0.3, 1},
        slotSelected = {0.3, 0.5, 0.7, 1},
        border = {0.4, 0.4, 0.4, 1},
        text = {1, 1, 1, 1},
        textSecondary = {0.7, 0.7, 0.7, 1},
        rarity = {
            common = {0.6, 0.6, 0.6, 1},
            uncommon = {0.2, 0.8, 0.2, 1},
            rare = {0.2, 0.4, 1, 1},
            epic = {0.6, 0.2, 1, 1},
            legendary = {1, 0.6, 0.2, 1}
        },
        itemType = {
            tool = {0.4, 0.6, 0.8, 1},
            consumable = {0.6, 0.8, 0.4, 1},
            resource = {0.8, 0.6, 0.4, 1}
        }
    }
    
    self:calculateLayout()
end

-- Dibujar item EVA
function EVAInventoryUI:drawEVAItem(x, y, size, item)
    -- Delegar al método compartido del InventoryUI para unificar estilo y lógica
    if InventoryUI and InventoryUI.drawEVAItem then
        InventoryUI:drawEVAItem(x, y, size, item)
        return
    end
    
    -- Fallback (en caso de que InventoryUI no exponga drawEVAItem)
    local colors = evaUIState.colors
    local itemWrapper = { data = item.data, quantity = item.quantity }
    -- Mapear categoría a tipo EVA para obtener el color correcto
    local categoryToEVAType = {
        ["consumable"] = "consumable",
        ["equipable"] = "tool",
        ["material"] = "resource"
    }
    local evaType = categoryToEVAType[item.data.category] or "tool"
    
    local color = (InventoryUI and InventoryUI.getItemRarityColor and InventoryUI:getItemRarityColor(itemWrapper))
                  or (colors.itemType[evaType]) or colors.itemType.tool
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, size, size)
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, size, size)
end

-- Calcular layout de la UI EVA
function EVAInventoryUI:calculateLayout()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local slotSize = evaUIState.slotSize
    local padding = evaUIState.slotPadding
    local panelPadding = evaUIState.panelPadding
    
    -- Panel horizontal con 3 slots
    evaUIState.layout.panelWidth = 3 * slotSize + 2 * padding + panelPadding * 2
    evaUIState.layout.panelHeight = slotSize + panelPadding * 2 + 40 -- +40 para título y controles
    
    -- Posicionar en la parte inferior de la pantalla
    evaUIState.layout.panelX = (screenWidth - evaUIState.layout.panelWidth) / 2
    evaUIState.layout.panelY = screenHeight - evaUIState.layout.panelHeight - 50
end

-- Abrir/cerrar inventario EVA
function EVAInventoryUI:toggle()
    if evaUIState.isOpen then
        self:close()
    else
        evaUIState.isOpen = true
    end
end

-- Cerrar inventario EVA explícitamente
function EVAInventoryUI:close()
    if not evaUIState.isOpen then return end
    evaUIState.isOpen = false
    evaUIState.selectedSlot = nil
    evaUIState.modal.isOpen = false
    evaUIState.modal.slotIndex = nil
end

-- Verificar si está abierto
function EVAInventoryUI:isOpen()
    return evaUIState.isOpen
end

-- Actualizar UI EVA
function EVAInventoryUI:update(dt, evaPlayer)
    if not evaUIState.isOpen then return end
    
    -- Recalcular layout si cambió el tamaño de pantalla
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    if screenWidth ~= self.lastScreenWidth or screenHeight ~= self.lastScreenHeight then
        self:calculateLayout()
        self.lastScreenWidth = screenWidth
        self.lastScreenHeight = screenHeight
    end
end

-- Renderizar UI EVA
function EVAInventoryUI:draw(evaPlayer)
    if not evaUIState.isOpen or not evaPlayer or not evaPlayer.inventory then 
        return 
    end
    
    love.graphics.push()
    
    -- Obtener el compartimento EVA real del ship si existe
    local inventoryToDraw = evaPlayer.inventory
    if evaPlayer.ship and evaPlayer.ship.inventory and evaPlayer.ship.inventory.getCompartment then
        local comp = evaPlayer.ship.inventory:getCompartment('eva')
        if comp then
            inventoryToDraw = comp
        end
    end
    
    -- Dibujar panel de inventario EVA
    self:drawEVAInventoryPanel(inventoryToDraw)
    
    love.graphics.pop()
end

-- Dibujar panel de inventario EVA
function EVAInventoryUI:drawEVAInventoryPanel(inventory)
    local layout = evaUIState.layout
    local colors = evaUIState.colors
    local slotSize = evaUIState.slotSize
    local padding = evaUIState.slotPadding
    local panelPadding = evaUIState.panelPadding
    
    -- Fondo del panel
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", layout.panelX, layout.panelY, 
                           layout.panelWidth, layout.panelHeight)
    
    -- Borde del panel
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", layout.panelX, layout.panelY, 
                           layout.panelWidth, layout.panelHeight)
    
    -- Título
    love.graphics.setColor(colors.text)
    love.graphics.print("Inventario EVA (Tab para abrir/cerrar)", layout.panelX + panelPadding, layout.panelY + 5)
    
    -- Slots de inventario EVA (3 slots horizontales)
    local startX = layout.panelX + panelPadding
    local startY = layout.panelY + 25
    
    for i = 1, inventory.maxSlots do
        local x = startX + (i - 1) * (slotSize + padding)
        local y = startY
        
        self:drawEVASlot(x, y, i, inventory.items[i])
    end
    
    -- Instrucciones
    love.graphics.setColor(colors.textSecondary)
    love.graphics.print("1-3: Usar item | Clic derecho: Opciones", layout.panelX + panelPadding, layout.panelY + layout.panelHeight - 15)
    
    -- Dibujar modal si está abierto
    if evaUIState.modal.isOpen then
        self:drawModal()
    end
end

-- Dibujar modal de opciones
function EVAInventoryUI:drawModal()
    local modal = evaUIState.modal
    local colors = evaUIState.colors
    
    -- Fondo del modal
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", modal.x, modal.y, modal.width, modal.height)
    
    -- Borde del modal
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", modal.x, modal.y, modal.width, modal.height)
    
    -- Líneas divisorias
    local optionHeight = modal.height / 3
    local firstDividerY = modal.y + optionHeight
    local secondDividerY = modal.y + optionHeight * 2
    love.graphics.line(modal.x, firstDividerY, modal.x + modal.width, firstDividerY)
    love.graphics.line(modal.x, secondDividerY, modal.x + modal.width, secondDividerY)
    
    -- Texto de opciones
    love.graphics.setColor(colors.text)
    local font = love.graphics.getFont()
    
    -- Opción "Usar/Equipar"
    local useText = "Usar/Equipar"
    local useTextWidth = font:getWidth(useText)
    local useTextX = modal.x + (modal.width - useTextWidth) / 2
    local useTextY = modal.y + (optionHeight - font:getHeight()) / 2
    love.graphics.print(useText, useTextX, useTextY)
    
    -- Opción "Lanzar al mundo"
    local dropText = "Lanzar al mundo"
    local dropTextWidth = font:getWidth(dropText)
    local dropTextX = modal.x + (modal.width - dropTextWidth) / 2
    local dropTextY = modal.y + optionHeight + (optionHeight - font:getHeight()) / 2
    love.graphics.print(dropText, dropTextX, dropTextY)
    
    -- Opción "Eliminar"
    local deleteText = "Eliminar"
    local deleteTextWidth = font:getWidth(deleteText)
    local deleteTextX = modal.x + (modal.width - deleteTextWidth) / 2
    local deleteTextY = modal.y + optionHeight * 2 + (optionHeight - font:getHeight()) / 2
    love.graphics.print(deleteText, deleteTextX, deleteTextY)
end

-- Dibujar slot de inventario EVA
function EVAInventoryUI:drawEVASlot(x, y, slotIndex, item)
    local colors = evaUIState.colors
    local slotSize = evaUIState.slotSize
    
    -- Determinar color del slot
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    -- Verificar si está seleccionado
    if evaUIState.selectedSlot == slotIndex then
        slotColor = colors.slotSelected
    end
    
    -- Dibujar slot
    love.graphics.setColor(slotColor)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize)
    
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, slotSize, slotSize)
    
    -- Número del slot
    love.graphics.setColor(colors.text)
    love.graphics.print(tostring(slotIndex), x + 2, y + 2)
    
    -- Dibujar item si existe (usando el dibujado compartido del InventoryUI)
    if item then
        self:drawEVAItem(x, y, slotSize, item)
    end
end

-- Manejar input de teclado para EVA
function EVAInventoryUI:keypressed(key, evaPlayer)
    if not evaUIState.isOpen or not evaPlayer or not evaPlayer.inventory then return end
    
    -- Cerrar modal si está abierto
    if evaUIState.modal.isOpen and key == "escape" then
        evaUIState.modal.isOpen = false
        return
    end
    
    -- Usar items con teclas 1-3
    if key == "1" or key == "2" or key == "3" then
        local slotIndex = tonumber(key)
        self:useEVAItem(slotIndex, evaPlayer)
    end
end

-- Manejar clic del mouse
function EVAInventoryUI:mousepressed(x, y, button, evaPlayer)
    if not evaUIState.isOpen or not evaPlayer then return end
    
    -- Si hay modal abierto, verificar clics en él
    if evaUIState.modal.isOpen then
        self:handleModalClick(x, y, button, evaPlayer)
        return
    end
    
    -- Verificar clic en slots
    local layout = evaUIState.layout
    local slotSize = evaUIState.slotSize
    local padding = evaUIState.slotPadding
    local panelPadding = evaUIState.panelPadding
    
    local startX = layout.panelX + panelPadding
    local startY = layout.panelY + 25
    
    -- Obtener compartimento EVA desde el sistema de inventario del ship
    local evaComp = nil
    if evaPlayer and evaPlayer.ship and evaPlayer.ship.inventory and evaPlayer.ship.inventory.getCompartment then
        evaComp = evaPlayer.ship.inventory:getCompartment('eva')
    end
    -- Determinar fuente de inventario para inspección (compartimento real o wrapper EVA)
    local inv = evaComp or (evaPlayer and evaPlayer.inventory) or nil
    local maxSlots = (inv and inv.maxSlots) or 3
    
    for i = 1, maxSlots do
        local slotX = startX + (i - 1) * (slotSize + padding)
        local slotY = startY
        
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            if button == 1 then -- Clic izquierdo
                local hasItem = (inv and inv.items and inv.items[i])
                -- Si se presiona Shift y hay item, transferir a nave
                if (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and hasItem then
                    -- Verificar proximidad a la nave
                    if not evaPlayer:canEnterShip() then
                        print("[TRANSFER] Error: Debes estar cerca de la nave para transferir items")
                        return
                    end
                    self:transferItemToShip(evaPlayer, i)
                    return
                end
                evaUIState.selectedSlot = i
            elseif button == 2 then -- Clic derecho en slot con item
                local hasItem = (inv and inv.items and inv.items[i])
                if hasItem then
                    self:openModal(x, y, i)
                end
            end
            break
        end
    end
end

-- Abrir modal de opciones
function EVAInventoryUI:openModal(x, y, slotIndex)
    evaUIState.modal.isOpen = true
    evaUIState.modal.slotIndex = slotIndex
    evaUIState.modal.x = x
    evaUIState.modal.y = y
end

-- Manejar clics en el modal
function EVAInventoryUI:handleModalClick(x, y, button, evaPlayer)
    if button ~= 1 then return end -- Solo clic izquierdo
    
    local modal = evaUIState.modal
    
    -- Verificar si el clic está dentro del modal
    if x >= modal.x and x <= modal.x + modal.width and y >= modal.y and y <= modal.y + modal.height then
        local optionHeight = modal.height / 3
        
        if y <= modal.y + optionHeight then
            -- Opción "Usar/Equipar"
            self:useEVAItem(modal.slotIndex, evaPlayer)
        elseif y <= modal.y + optionHeight * 2 then
            -- Opción "Lanzar al mundo"
            self:dropItemFromModal(modal.slotIndex, evaPlayer)
        else
            -- Opción "Eliminar"
            self:deleteItem(modal.slotIndex, evaPlayer)
        end
    end
    
    -- Cerrar modal
    modal.isOpen = false
end

-- Usar item EVA
function EVAInventoryUI:useEVAItem(slotIndex, evaPlayer)
    if not evaPlayer or not evaPlayer.inventory then return end
    -- Usar directamente desde el inventario EVA
    local item = evaPlayer.inventory:useItem(slotIndex)
    if item then
        print("Usando: " .. (item.name or item.data and item.data.name or ""))
        if item.stats then
            if item.stats.heal and evaPlayer.stats then
                evaPlayer.stats:heal(item.stats.heal)
                print("Curado " .. item.stats.heal .. " puntos de vida")
            end
            if item.stats.oxygen then
                print("Oxígeno restaurado: " .. item.stats.oxygen)
            end
        end
    else
        print("No hay item en el slot " .. slotIndex)
    end
end

-- Descartar item EVA
function EVAInventoryUI:discardEVAItem(slotIndex, evaPlayer)
    if not evaPlayer or not evaPlayer.inventory then return end
    -- Eliminar directamente del inventario EVA
    local item = evaPlayer.inventory:removeItem(slotIndex)
    if item then
        print("Descartado: " .. (item.data and item.data.name or ""))
        evaUIState.selectedSlot = nil
    end
end

-- Seleccionar slot
function EVAInventoryUI:selectSlot(slotIndex)
    evaUIState.selectedSlot = slotIndex
end

-- Transferir item del compartimento EVA al compartimento ship
function EVAInventoryUI:transferItemToShip(evaPlayer, fromSlot)
    if not evaPlayer or not evaPlayer.ship or not evaPlayer.ship.inventory or not evaPlayer.ship.inventory.getCompartment then
        print("[TRANSFER] Error: No se puede acceder al sistema de inventario de la nave")
        return false
    end
    
    local shipComp = evaPlayer.ship.inventory:getCompartment('ship')
    local evaComp = evaPlayer.ship.inventory:getCompartment('eva')
    
    if not shipComp or not evaComp then
        print("[TRANSFER] Error: No se pueden encontrar los compartimentos")
        return false
    end
    
    local item = evaComp.items[fromSlot]
    if not item then
        print("[TRANSFER] Error: No hay item en el slot especificado")
        return false
    end
    
    -- Buscar slot vacío en la nave
    local targetSlot = nil
    for i = 1, shipComp.maxSlots do
        if not shipComp.items[i] then
            targetSlot = i
            break
        end
    end
    
    if not targetSlot then
        print("[TRANSFER] Error: Inventario de nave lleno")
        return false
    end
    
    -- Realizar transferencia
    if evaPlayer.ship.inventory:transferItemBetweenCompartments('eva', fromSlot, 'ship', targetSlot) then
        print("[TRANSFER] Item transferido de EVA a nave: " .. (item.data.name or "item desconocido"))
        return true
    else
        print("[TRANSFER] Error: Falló la transferencia")
        return false
    end
end

-- Lanzar item al mundo desde modal
function EVAInventoryUI:dropItemFromModal(slotIndex, evaPlayer)
    if not evaPlayer or not evaPlayer.ship or not evaPlayer.ship.inventory then return end
    
    -- Obtener item del compartimento EVA
    local evaComp = evaPlayer.ship.inventory:getCompartment('eva')
    if not evaComp or not evaComp.items[slotIndex] then
        print("[EVA DROP] Error: No hay item en el slot especificado")
        return
    end
    
    local item = evaComp.items[slotIndex]
    
    -- Usar el sistema WorldItems para crear el item en el mundo
    local WorldItems = require 'src.item_systems.world_items'
    local ItemSystem = require 'src.item_systems.items.init'
    
    local itemData = ItemSystem.getItem(item.data.id)
    if not itemData then
        print("[EVA DROP] Error: No se encontraron datos para el item", item.data.id)
        return
    end
    
    -- Obtener posición del jugador EVA
    local playerX = evaPlayer.x or 0
    local playerY = evaPlayer.y or 0
    
    -- Lanzar cerca del jugador con un offset aleatorio
    local offsetX = (math.random() - 0.5) * 100
    local offsetY = (math.random() - 0.5) * 100
    local targetX = playerX + offsetX
    local targetY = playerY + offsetY
    
    local quantity = item.quantity or 1
    local worldItem = WorldItems.drop(itemData, playerX, playerY, targetX, targetY, quantity)
    
    if worldItem then
        -- Eliminar item del inventario EVA
        evaComp.items[slotIndex] = nil
        print("[EVA DROP] Item lanzado:", itemData.name, "x" .. quantity)
        evaUIState.selectedSlot = nil
    else
        print("[EVA DROP] Error: No se pudo crear el item en el mundo")
    end
end

-- Eliminar item permanentemente
function EVAInventoryUI:deleteItem(slotIndex, evaPlayer)
    if not evaPlayer or not evaPlayer.inventory then return end
    
    local item = evaPlayer.inventory:removeItem(slotIndex)
    if item then
        print("Item eliminado permanentemente: " .. (item.data.name or "item desconocido"))
        evaUIState.selectedSlot = nil
    end
end

return EVAInventoryUI