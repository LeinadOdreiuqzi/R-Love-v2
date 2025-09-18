-- src/ui/inventory_ui.lua
-- UI del inventario con drag and drop y modificación de naves

local InventoryUI = {}

-- Estado de la UI
local uiState = {
    isOpen = false,
    draggedItem = nil,
    draggedFromSlot = nil,
    draggedFromType = nil, -- "inventory" o "upgrade"
    draggedFromUpgradeType = nil,
    mouseX = 0,
    mouseY = 0,
    
    -- Modal de opciones
    modal = {
        isOpen = false,
        slotIndex = nil,
        slotType = nil, -- "inventory" o "upgrade"
        upgradeType = nil,
        x = 0,
        y = 0,
        width = 120,
        height = 60
    },
    
    -- Configuración visual
    slotSize = 50,
    slotPadding = 5,
    panelPadding = 20,
    
    -- Colores
    colors = {
        background = {0.1, 0.1, 0.15, 0.95},
        panelBackground = {0.15, 0.15, 0.2, 0.9},
        slotEmpty = {0.2, 0.2, 0.25, 1},
        slotFilled = {0.3, 0.3, 0.35, 1},
        slotHover = {0.4, 0.4, 0.45, 1},
        slotDragTarget = {0.2, 0.6, 0.2, 1},
        border = {0.5, 0.5, 0.5, 1},
        text = {1, 1, 1, 1},
        textSecondary = {0.8, 0.8, 0.8, 1},
        
        -- Colores por rareza
        rarity = {
            common = {0.6, 0.6, 0.6, 1},
            uncommon = {0.2, 0.8, 0.2, 1},
            rare = {0.2, 0.4, 1, 1},
            epic = {0.6, 0.2, 1, 1},
            legendary = {1, 0.6, 0.2, 1}
        },
        
        -- Colores por tipo de item EVA
        itemType = {
            tool = {0.4, 0.6, 0.8, 1},
            consumable = {0.6, 0.8, 0.4, 1},
            resource = {0.8, 0.6, 0.4, 1}
        }
    },
    
    -- Fuentes
    font = nil,
    smallFont = nil,
    
    -- Layout
    layout = {
        inventoryX = 0,
        inventoryY = 0,
        inventoryWidth = 0,
        inventoryHeight = 0,
        
        upgradeX = 0,
        upgradeY = 0,
        upgradeWidth = 0,
        upgradeHeight = 0,
        
        totalWidth = 0,
        totalHeight = 0
    }
}

-- Inicializar UI
function InventoryUI:init()
    -- Cargar fuentes
    uiState.font = love.graphics.getFont()
    uiState.smallFont = love.graphics.newFont(12)
    
    -- Calcular layout
    self:calculateLayout()
end

-- Calcular layout de la UI
function InventoryUI:calculateLayout()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Configuración del inventario (grid 5x8 para 40 slots máximo)
    local inventoryColumns = 5
    local inventoryRows = 8
    
    uiState.layout.inventoryWidth = inventoryColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.inventoryHeight = inventoryRows * (slotSize + padding) - padding + panelPadding * 2 + 30 -- +30 para título
    
    -- Configuración de mejoras (4 slots en 2x2)
    local upgradeColumns = 2
    local upgradeRows = 2
    
    uiState.layout.upgradeWidth = upgradeColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.upgradeHeight = upgradeRows * (slotSize + padding) - padding + panelPadding * 2 + 30 -- +30 para título
    
    -- Configuración del panel EVA (3 slots horizontales)
    local evaColumns = 3
    uiState.layout.evaWidth = evaColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.evaHeight = slotSize + panelPadding * 2 + 40 -- +40 para título
    
    -- Posicionamiento centrado (incluyendo panel EVA)
    uiState.layout.totalWidth = uiState.layout.inventoryWidth + uiState.layout.upgradeWidth + uiState.layout.evaWidth + panelPadding * 2
    uiState.layout.totalHeight = math.max(uiState.layout.inventoryHeight, uiState.layout.upgradeHeight, uiState.layout.evaHeight)
    
    uiState.layout.inventoryX = (screenWidth - uiState.layout.totalWidth) / 2
    uiState.layout.inventoryY = (screenHeight - uiState.layout.totalHeight) / 2
    
    uiState.layout.upgradeX = uiState.layout.inventoryX + uiState.layout.inventoryWidth + panelPadding
    uiState.layout.upgradeY = uiState.layout.inventoryY
    
    uiState.layout.evaX = uiState.layout.upgradeX + uiState.layout.upgradeWidth + panelPadding
    uiState.layout.evaY = uiState.layout.upgradeY
end

-- Abrir/cerrar inventario
function InventoryUI:toggle()
    if uiState.isOpen then
        self:close()
    else
        uiState.isOpen = true
    end
end

-- Cerrar inventario explícitamente (usado al cambiar de estado, p.ej. entrar en EVA)
function InventoryUI:close()
    if not uiState.isOpen then return end
    uiState.isOpen = false
    -- Limpiar estado de drag y modal al cerrar
    uiState.draggedItem = nil
    uiState.draggedFromSlot = nil
    uiState.draggedFromType = nil
    uiState.draggedFromUpgradeType = nil
    uiState.modal.isOpen = false
end

-- Verificar si está abierto
function InventoryUI:isOpen()
    return uiState.isOpen
end

-- Actualizar UI
function InventoryUI:update(dt, player, evaPlayer)
    if not uiState.isOpen then return end
    
    -- Actualizar posición del mouse
    uiState.mouseX = love.mouse.getX()
    uiState.mouseY = love.mouse.getY()
    
    -- Recalcular layout si cambió el tamaño de pantalla
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    if screenWidth ~= self.lastScreenWidth or screenHeight ~= self.lastScreenHeight then
        self:calculateLayout()
        self.lastScreenWidth = screenWidth
        self.lastScreenHeight = screenHeight
    end
end

-- Renderizar UI
function InventoryUI:draw(player, evaPlayer)
    if not uiState.isOpen or not player or not player.inventory then 
        return 
    end
    
    love.graphics.push()
    
    -- Dibujar panel de inventario
    self:drawInventoryPanel(player.inventory)
    
    -- Dibujar panel de mejoras
    self:drawUpgradePanel(player.inventory)
    
    -- Dibujar panel de inventario EVA si está disponible
    if evaPlayer and evaPlayer.inventory then
        self:drawEVAInventoryPanel(evaPlayer.inventory)
    end
    
    -- Dibujar item arrastrado
    if uiState.draggedItem then
        self:drawDraggedItem()
    end
    
    -- Dibujar modal si está abierto
    if uiState.modal.isOpen then
        self:drawModal()
    end
    
    love.graphics.pop()
end

-- Dibujar panel de inventario
function InventoryUI:drawInventoryPanel(inventory)
    local layout = uiState.layout
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Fondo del panel
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", layout.inventoryX, layout.inventoryY, 
                           layout.inventoryWidth, layout.inventoryHeight)
    
    -- Borde del panel
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", layout.inventoryX, layout.inventoryY, 
                           layout.inventoryWidth, layout.inventoryHeight)
    
    -- Título
    love.graphics.setColor(colors.text)
    love.graphics.setFont(uiState.font)
    love.graphics.print("Inventario (" .. inventory.shipType .. ")", 
                       layout.inventoryX + panelPadding, layout.inventoryY + 5)
    
    -- Slots del inventario
    local startX = layout.inventoryX + panelPadding
    local startY = layout.inventoryY + 30
    local columns = 5
    
    for i = 1, inventory.maxSlots do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local x = startX + col * (slotSize + padding)
        local y = startY + row * (slotSize + padding)
        
        self:drawInventorySlot(x, y, i, inventory.items[i])
    end
end

-- Dibujar panel de mejoras
function InventoryUI:drawUpgradePanel(inventory)
    local layout = uiState.layout
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Fondo del panel
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", layout.upgradeX, layout.upgradeY, 
                           layout.upgradeWidth, layout.upgradeHeight)
    
    -- Borde del panel
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", layout.upgradeX, layout.upgradeY, 
                           layout.upgradeWidth, layout.upgradeHeight)
    
    -- Título
    love.graphics.setColor(colors.text)
    love.graphics.setFont(uiState.font)
    love.graphics.print("Mejoras de Nave", layout.upgradeX + panelPadding, layout.upgradeY + 5)
    
    -- Slots de mejoras (4 slots fijos)
    local startX = layout.upgradeX + panelPadding
    local startY = layout.upgradeY + 30
    local upgradeTypes = {"weapon", "shield", "engine", "utility"}
    local upgradeLabels = {"Arma", "Escudo", "Motor", "Utilidad"}
    
    for i, upgradeType in ipairs(upgradeTypes) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = startX + col * (slotSize + padding + 20)
        local y = startY + row * (slotSize + padding + 20)
        
        -- Obtener primer item equipado de este tipo
        local equippedItem = nil
        if inventory.upgradeSlots[upgradeType] and inventory.upgradeSlots[upgradeType][1] then
            equippedItem = inventory.upgradeSlots[upgradeType][1]
        end
        
        self:drawUpgradeSlot(x, y, upgradeType, 1, equippedItem, upgradeLabels[i])
    end
end

-- Dibujar panel de inventario EVA
function InventoryUI:drawEVAInventoryPanel(evaInventory)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Usar coordenadas del layout calculado
    local evaStartX = uiState.layout.evaX
    local evaStartY = uiState.layout.evaY
    local evaWidth = uiState.layout.evaWidth
    local evaHeight = uiState.layout.evaHeight
    
    -- Fondo del panel EVA
    love.graphics.setColor(colors.panelBackground)
    love.graphics.rectangle("fill", evaStartX, evaStartY, evaWidth, evaHeight)
    
    -- Borde del panel EVA
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", evaStartX, evaStartY, evaWidth, evaHeight)
    
    -- Título del panel EVA
    love.graphics.setColor(colors.text)
    love.graphics.print("Inventario EVA", evaStartX + panelPadding, evaStartY + 5)
    
    -- Dibujar slots del EVA (3 slots horizontales)
    local slotStartX = evaStartX + panelPadding
    local slotStartY = evaStartY + 25
    
    for i = 1, evaInventory.maxSlots do
        local x = slotStartX + (i - 1) * (slotSize + padding)
        local y = slotStartY
        
        self:drawEVASlot(x, y, i, evaInventory.items[i])
    end
end

-- Dibujar slot de inventario EVA
function InventoryUI:drawEVASlot(x, y, slotIndex, item)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    
    -- Determinar color del slot
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    -- Verificar hover
    if self:isMouseOverSlot(x, y, slotSize) then
        slotColor = colors.slotHover
    end
    
    -- Verificar si es target válido para drag
    if uiState.draggedItem and self:isValidDropTarget("eva", slotIndex) then
        slotColor = colors.slotDragTarget
    end
    
    -- Dibujar fondo del slot
    love.graphics.setColor(slotColor)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize)
    
    -- Dibujar borde del slot
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, slotSize, slotSize)
    
    -- Dibujar item si existe
    if item then
        self:drawEVAItem(x, y, slotSize, item)
    end
    
    -- Dibujar número del slot
    love.graphics.setColor(colors.textSecondary)
    love.graphics.print(tostring(slotIndex), x + 2, y + 2)
end

-- Dibujar item del EVA
function InventoryUI:drawEVAItem(x, y, size, item)
    local colors = uiState.colors
    local itemPadding = 4
    local itemSize = size - itemPadding * 2
    local itemX = x + itemPadding
    local itemY = y + itemPadding
    
    -- Color basado en el tipo de item EVA
    local itemColor = colors.itemType.tool -- Color por defecto
    if item.data and item.data.type then
        if item.data.type == "consumable" then
            itemColor = colors.itemType.consumable
        elseif item.data.type == "resource" then
            itemColor = colors.itemType.resource
        end
    end
    
    -- Dibujar fondo del item
    love.graphics.setColor(itemColor)
    love.graphics.rectangle("fill", itemX, itemY, itemSize, itemSize)
    
    -- Dibujar borde del item
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", itemX, itemY, itemSize, itemSize)
    
    -- Dibujar texto del item (primera letra del nombre)
    if item.data and item.data.name then
        love.graphics.setColor(colors.text)
        local firstLetter = string.sub(item.data.name, 1, 1)
        love.graphics.print(firstLetter, itemX + itemSize/2 - 4, itemY + itemSize/2 - 6)
    end
    
    -- Dibujar cantidad si es mayor a 1
    if item.quantity and item.quantity > 1 then
        love.graphics.setColor(colors.text)
        love.graphics.print(tostring(item.quantity), itemX + itemSize - 10, itemY + itemSize - 12)
    end
end

-- Dibujar slot de inventario
function InventoryUI:drawInventorySlot(x, y, slotIndex, item)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    
    -- Determinar color del slot
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    -- Verificar hover
    if self:isMouseOverSlot(x, y, slotSize) then
        slotColor = colors.slotHover
    end
    
    -- Verificar si es target válido para drag
    if uiState.draggedItem and self:isValidDropTarget("inventory", slotIndex) then
        slotColor = colors.slotDragTarget
    end
    
    -- Dibujar slot
    love.graphics.setColor(slotColor)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize)
    
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, slotSize, slotSize)
    
    -- Dibujar item si existe
    if item then
        self:drawItem(x + 2, y + 2, slotSize - 4, item)
    end
end

-- Dibujar slot de mejora
function InventoryUI:drawUpgradeSlot(x, y, upgradeType, slotIndex, item, label)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    
    -- Determinar color del slot
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    -- Verificar hover
    if self:isMouseOverSlot(x, y, slotSize) then
        slotColor = colors.slotHover
    end
    
    -- Verificar si es target válido para drag
    if uiState.draggedItem and self:isValidDropTarget("upgrade", upgradeType, slotIndex) then
        slotColor = colors.slotDragTarget
    end
    
    -- Dibujar slot
    love.graphics.setColor(slotColor)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize)
    
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, slotSize, slotSize)
    
    -- Dibujar label
    love.graphics.setColor(colors.textSecondary)
    love.graphics.setFont(uiState.smallFont)
    love.graphics.print(label, x, y + slotSize + 2)
    
    -- Dibujar item si existe
    if item then
        self:drawItem(x + 2, y + 2, slotSize - 4, item)
    end
end

-- Dibujar item
function InventoryUI:drawItem(x, y, size, item)
    local colors = uiState.colors
    
    -- Verificar que el item y sus datos existan
    if not item or not item.data then
        return
    end
    
    -- Color por rareza
    local rarityColor = colors.rarity[item.data.rarity] or colors.rarity.common
    love.graphics.setColor(rarityColor)
    love.graphics.rectangle("fill", x, y, size, size)
    
    -- Texto del item (primera letra del nombre)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(uiState.font)
    local firstLetter = string.sub(item.data.name, 1, 1)
    local textWidth = uiState.font:getWidth(firstLetter)
    local textHeight = uiState.font:getHeight()
    love.graphics.print(firstLetter, 
                       x + (size - textWidth) / 2, 
                       y + (size - textHeight) / 2)
    
    -- Cantidad si es mayor a 1
    if item.quantity and item.quantity > 1 then
        love.graphics.setFont(uiState.smallFont)
        love.graphics.print(tostring(item.quantity), x + size - 15, y + size - 15)
    end
end

-- Dibujar item siendo arrastrado
function InventoryUI:drawDraggedItem()
    if not uiState.draggedItem then return end
    
    local size = uiState.slotSize * 0.8
    local x = uiState.mouseX - size / 2
    local y = uiState.mouseY - size / 2
    
    -- Fondo semi-transparente
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x - 2, y - 2, size + 4, size + 4)
    
    self:drawItem(x, y, size, uiState.draggedItem)
end

-- Dibujar modal de opciones
function InventoryUI:drawModal()
    local modal = uiState.modal
    local colors = uiState.colors
    
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

-- Verificar si el mouse está sobre un slot
function InventoryUI:isMouseOverSlot(x, y, size)
    return uiState.mouseX >= x and uiState.mouseX <= x + size and
           uiState.mouseY >= y and uiState.mouseY <= y + size
end

-- Verificar si es un target válido para drop
function InventoryUI:isValidDropTarget(targetType, targetSlot, targetUpgradeSlot)
    if not uiState.draggedItem or not uiState.draggedItem.data then return false end
    
    if targetType == "inventory" then
        return true -- Siempre se puede mover a inventario
    elseif targetType == "upgrade" then
        -- Solo se puede equipar si el tipo coincide
        return uiState.draggedItem.data.type == targetSlot
    elseif targetType == "eva" then
        return true -- Siempre se puede mover al inventario EVA
    end
    
    return false
end

-- Manejar click del mouse
function InventoryUI:mousepressed(x, y, button, player, evaPlayer)
    if not uiState.isOpen or not player or not player.inventory then return end
    
    -- Si hay modal abierto, verificar clics en él
    if uiState.modal.isOpen then
        self:handleModalClick(x, y, button, player)
        return
    end
    
    -- Solo manejar drag con clic izquierdo
    if button == 1 then
        -- Verificar click en inventario
        local inventorySlot = self:getInventorySlotAt(x, y, player.inventory)
        if inventorySlot then
            local item = player.inventory.items[inventorySlot]
            if item then
                uiState.draggedItem = item
                uiState.draggedFromSlot = inventorySlot
                uiState.draggedFromType = "inventory"
                player.inventory.items[inventorySlot] = nil
            end
            return
        end
        
        -- Verificar click en mejoras
        local upgradeType, upgradeSlot = self:getUpgradeSlotAt(x, y)
        if upgradeType and upgradeSlot then
            local item = player.inventory.upgradeSlots[upgradeType] and 
                        player.inventory.upgradeSlots[upgradeType][upgradeSlot]
            if item then
                uiState.draggedItem = item
                uiState.draggedFromSlot = upgradeSlot
                uiState.draggedFromType = "upgrade"
                uiState.draggedFromUpgradeType = upgradeType
                player.inventory.upgradeSlots[upgradeType][upgradeSlot] = nil
            end
            return
        end
        
        -- Verificar click en EVA
        if evaPlayer and evaPlayer.inventory then
            local evaSlot = self:getEVASlotAt(x, y, evaPlayer.inventory)
            if evaSlot then
                local item = evaPlayer.inventory.items[evaSlot]
                if item then
                    uiState.draggedItem = item
                    uiState.draggedFromSlot = evaSlot
                    uiState.draggedFromType = "eva"
                    evaPlayer.inventory.items[evaSlot] = nil
                end
                return
            end
        end
    elseif button == 2 then -- Clic derecho
        -- Verificar clic derecho en inventario
        local inventorySlot = self:getInventorySlotAt(x, y, player.inventory)
        if inventorySlot and player.inventory.items[inventorySlot] then
            self:openModal(x, y, inventorySlot, "inventory")
            return
        end
        
        -- Verificar clic derecho en mejoras
        local upgradeType, upgradeSlot = self:getUpgradeSlotAt(x, y)
        if upgradeType and upgradeSlot then
            local item = player.inventory.upgradeSlots[upgradeType] and 
                        player.inventory.upgradeSlots[upgradeType][upgradeSlot]
            if item then
                self:openModal(x, y, upgradeSlot, "upgrade", upgradeType)
            end
            return
        end
        
        -- Verificar clic derecho en EVA
        if evaPlayer and evaPlayer.inventory then
            local evaSlot = self:getEVASlotAt(x, y, evaPlayer.inventory)
            if evaSlot and evaPlayer.inventory.items[evaSlot] then
                self:openModal(x, y, evaSlot, "eva")
                return
            end
        end
    end
end

-- Manejar release del mouse
function InventoryUI:mousereleased(x, y, button, player, evaPlayer)
    if not uiState.isOpen or button ~= 1 or not uiState.draggedItem or not player or not player.inventory then 
        return 
    end
    
    local dropped = false
    
    -- Verificar drop en inventario
    local inventorySlot = self:getInventorySlotAt(x, y, player.inventory)
    if inventorySlot then
        local existingItem = player.inventory.items[inventorySlot]
        player.inventory.items[inventorySlot] = uiState.draggedItem
        
        -- Si había un item, intercambiar
        if existingItem then
            if uiState.draggedFromType == "inventory" then
                player.inventory.items[uiState.draggedFromSlot] = existingItem
            elseif uiState.draggedFromType == "upgrade" then
                if not player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] then
                    player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] = {}
                end
                player.inventory.upgradeSlots[uiState.draggedFromUpgradeType][uiState.draggedFromSlot] = existingItem
            elseif uiState.draggedFromType == "eva" then
                evaPlayer.inventory.items[uiState.draggedFromSlot] = existingItem
            end
        end
        dropped = true
    end
    
    -- Verificar drop en mejoras
    if not dropped then
        local upgradeType, upgradeSlot = self:getUpgradeSlotAt(x, y)
        if upgradeType and upgradeSlot and uiState.draggedItem.data.type == upgradeType then
            if not player.inventory.upgradeSlots[upgradeType] then
                player.inventory.upgradeSlots[upgradeType] = {}
            end
            
            local existingItem = player.inventory.upgradeSlots[upgradeType][upgradeSlot]
            player.inventory.upgradeSlots[upgradeType][upgradeSlot] = uiState.draggedItem
            
            -- Si había un item, intercambiar
            if existingItem then
                if uiState.draggedFromType == "inventory" then
                    player.inventory.items[uiState.draggedFromSlot] = existingItem
                elseif uiState.draggedFromType == "upgrade" then
                    if not player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] then
                        player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] = {}
                    end
                    player.inventory.upgradeSlots[uiState.draggedFromUpgradeType][uiState.draggedFromSlot] = existingItem
                elseif uiState.draggedFromType == "eva" then
                    evaPlayer.inventory.items[uiState.draggedFromSlot] = existingItem
                end
            end
            dropped = true
        end
    end
    
    -- Verificar drop en EVA
    if not dropped and evaPlayer and evaPlayer.inventory then
        local evaSlot = self:getEVASlotAt(x, y, evaPlayer.inventory)
        if evaSlot then
            local existingItem = evaPlayer.inventory.items[evaSlot]
            evaPlayer.inventory.items[evaSlot] = uiState.draggedItem
            
            -- Si había un item, intercambiar
            if existingItem then
                if uiState.draggedFromType == "inventory" then
                    player.inventory.items[uiState.draggedFromSlot] = existingItem
                elseif uiState.draggedFromType == "upgrade" then
                    if not player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] then
                        player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] = {}
                    end
                    player.inventory.upgradeSlots[uiState.draggedFromUpgradeType][uiState.draggedFromSlot] = existingItem
                elseif uiState.draggedFromType == "eva" then
                    evaPlayer.inventory.items[uiState.draggedFromSlot] = existingItem
                end
            end
            dropped = true
        end
    end
    
    -- Si no se pudo hacer drop en el inventario, verificar drop al mundo
    if not dropped then
        -- Verificar si el mouse está fuera de todos los paneles
        local layout = uiState.layout
        local mouseOutsideInventory = uiState.mouseX < layout.inventoryX or 
                                     uiState.mouseX > layout.inventoryX + layout.inventoryWidth or
                                     uiState.mouseY < layout.inventoryY or 
                                     uiState.mouseY > layout.inventoryY + layout.inventoryHeight
        
        local mouseOutsideUpgrade = uiState.mouseX < layout.upgradeX or 
                                   uiState.mouseX > layout.upgradeX + layout.upgradeWidth or
                                   uiState.mouseY < layout.upgradeY or 
                                   uiState.mouseY > layout.upgradeY + layout.upgradeHeight
        
        local mouseOutsideEVA = true
        if evaPlayer and evaPlayer.inventory then
            mouseOutsideEVA = uiState.mouseX < layout.evaX or 
                             uiState.mouseX > layout.evaX + layout.evaWidth or
                             uiState.mouseY < layout.evaY or 
                             uiState.mouseY > layout.evaY + layout.evaHeight
        end
        
        if mouseOutsideInventory and mouseOutsideUpgrade and mouseOutsideEVA then
            -- Drop al mundo
            self:dropItemToWorld(uiState.draggedItem, player, uiState.mouseX, uiState.mouseY)
            dropped = true
        else
            -- Devolver item a su lugar original
            if uiState.draggedFromType == "inventory" then
                player.inventory.items[uiState.draggedFromSlot] = uiState.draggedItem
            elseif uiState.draggedFromType == "upgrade" then
                if not player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] then
                    player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] = {}
                end
                player.inventory.upgradeSlots[uiState.draggedFromUpgradeType][uiState.draggedFromSlot] = uiState.draggedItem
            elseif uiState.draggedFromType == "eva" and evaPlayer then
                evaPlayer.inventory.items[uiState.draggedFromSlot] = uiState.draggedItem
            end
        end
    end
    
    -- Limpiar estado de drag
    uiState.draggedItem = nil
    uiState.draggedFromSlot = nil
    uiState.draggedFromType = nil
    uiState.draggedFromUpgradeType = nil
end

-- Manejar input de teclado
function InventoryUI:keypressed(key, player)
    if not uiState.isOpen then return end
    
    -- Cerrar modal si está abierto
    if uiState.modal.isOpen and key == "escape" then
        uiState.modal.isOpen = false
        return
    end
end

-- Abrir modal de opciones
function InventoryUI:openModal(x, y, slotIndex, slotType, upgradeType)
    uiState.modal.isOpen = true
    uiState.modal.slotIndex = slotIndex
    uiState.modal.slotType = slotType
    uiState.modal.upgradeType = upgradeType
    uiState.modal.x = x
    uiState.modal.y = y
end

-- Manejar clics en el modal
function InventoryUI:handleModalClick(x, y, button, player)
    if button ~= 1 then return end -- Solo clic izquierdo
    
    local modal = uiState.modal
    
    -- Verificar si el clic está dentro del modal
    if x >= modal.x and x <= modal.x + modal.width and y >= modal.y and y <= modal.y + modal.height then
        local optionHeight = modal.height / 3 -- Ahora hay 3 opciones
        
        if y <= modal.y + optionHeight then
            -- Opción "Usar/Equipar"
            self:useItem(modal.slotIndex, modal.slotType, modal.upgradeType, player)
        elseif y <= modal.y + optionHeight * 2 then
            -- Opción "Lanzar al mundo"
            self:dropItemFromModal(modal.slotIndex, modal.slotType, modal.upgradeType, player)
        else
            -- Opción "Eliminar"
            self:deleteItem(modal.slotIndex, modal.slotType, modal.upgradeType, player)
        end
    end
    
    -- Cerrar modal
    modal.isOpen = false
end

-- Usar/equipar item
function InventoryUI:useItem(slotIndex, slotType, upgradeType, player)
    local item = nil
    local evaPlayer = (player and player.evaPlayer) or nil
    
    if slotType == "inventory" then
        item = player.inventory.items[slotIndex]
    elseif slotType == "upgrade" and upgradeType then
        item = player.inventory.upgradeSlots[upgradeType] and player.inventory.upgradeSlots[upgradeType][slotIndex]
    elseif slotType == "eva" and evaPlayer then
        item = evaPlayer.inventory.items[slotIndex]
    end
    
    if item and item.data then
        -- Integración con el sistema de items
        local ItemSystem = require 'src.item_systems.items.init'
        local itemData = ItemSystem.getItem(item.data.id)
        
        if itemData then
            if itemData.category == "consumable" then
                -- Usar item consumible
                local success = ItemSystem.useItem(item.data.id, player)
                if success then
                    -- Remover item del inventario si se usó exitosamente
                    if slotType == "inventory" then
                        player.inventory.items[slotIndex] = nil
                    elseif slotType == "eva" and evaPlayer then
                        evaPlayer.inventory.items[slotIndex] = nil
                    end
                    print("Usado: " .. itemData.name)
                else
                    print("No se pudo usar: " .. itemData.name)
                end
            elseif itemData.category == "equipable" then
                -- Equipar item
                local success = ItemSystem.equipItem(item.data.id, player)
                if success then
                    print("Equipado: " .. itemData.name)
                else
                    print("No se pudo equipar: " .. itemData.name)
                end
            else
                print("Item: " .. itemData.name .. " (" .. itemData.category .. ")")
            end
        else
            print("Usando item: " .. (item.data.name or "Unknown"))
        end
    end
end

-- Eliminar item
function InventoryUI:deleteItem(slotIndex, slotType, upgradeType, player)
    local evaPlayer = (player and player.evaPlayer) or nil
    
    if slotType == "inventory" then
        player.inventory.items[slotIndex] = nil
        print("Item eliminado del inventario")
    elseif slotType == "upgrade" and upgradeType then
        if player.inventory.upgradeSlots[upgradeType] then
            player.inventory.upgradeSlots[upgradeType][slotIndex] = nil
            print("Item eliminado de mejoras")
        end
    elseif slotType == "eva" and evaPlayer then
        evaPlayer.inventory.items[slotIndex] = nil
        print("Item eliminado del inventario EVA")
    end
end

-- Lanzar item al mundo desde modal
function InventoryUI:dropItemFromModal(slotIndex, slotType, upgradeType, player)
    local item = nil
    local evaPlayer = (player and player.evaPlayer) or nil
    
    if slotType == "inventory" then
        item = player.inventory.items[slotIndex]
    elseif slotType == "upgrade" and upgradeType then
        item = player.inventory.upgradeSlots[upgradeType] and player.inventory.upgradeSlots[upgradeType][slotIndex]
    elseif slotType == "eva" and evaPlayer then
        item = evaPlayer.inventory.items[slotIndex]
    end
    
    if not item then
        print("[DROP MODAL] Error: No se encontró el item")
        return
    end
    
    -- Obtener posición del jugador para lanzar cerca
    local activeEntity = player:getActiveEntity()
    if not activeEntity then
        print("[DROP MODAL] Error: No se pudo obtener la entidad activa")
        return
    end
    
    -- Lanzar cerca del jugador con un offset aleatorio
    local offsetX = (math.random() - 0.5) * 100 -- Offset aleatorio de -50 a 50
    local offsetY = (math.random() - 0.5) * 100
    local targetX = activeEntity.x + offsetX
    local targetY = activeEntity.y + offsetY
    
    -- Usar la función dropItemToWorld con coordenadas del mundo
    local WorldItems = require 'src.item_systems.world_items'
    local ItemSystem = require 'src.item_systems.items.init'
    
    local itemData = ItemSystem.getItem(item.data.id)
    if not itemData then
        print("[DROP MODAL] Error: No se encontraron datos para el item", item.data.id)
        return
    end
    
    local quantity = item.data.quantity or 1
    local worldItem = WorldItems.drop(itemData, activeEntity.x, activeEntity.y, targetX, targetY, quantity)
    
    if worldItem then
        -- Eliminar item del inventario
        if slotType == "inventory" then
            player.inventory.items[slotIndex] = nil
        elseif slotType == "upgrade" and upgradeType then
            player.inventory.upgradeSlots[upgradeType][slotIndex] = nil
        elseif slotType == "eva" and evaPlayer then
            evaPlayer.inventory.items[slotIndex] = nil
        end
        
        print("[DROP MODAL] Item lanzado:", itemData.name, "x" .. quantity)
    else
        print("[DROP MODAL] Error: No se pudo crear el item en el mundo")
    end
end

-- Obtener slot de inventario en posición
function InventoryUI:getInventorySlotAt(x, y, inventory)
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    local startX = layout.inventoryX + panelPadding
    local startY = layout.inventoryY + 30
    local columns = 5
    
    for i = 1, inventory.maxSlots do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local slotX = startX + col * (slotSize + padding)
        local slotY = startY + row * (slotSize + padding)
        
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            return i
        end
    end
    
    return nil
end

-- Obtener slot de mejora en posición
function InventoryUI:getUpgradeSlotAt(x, y)
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    local startX = layout.upgradeX + panelPadding
    local startY = layout.upgradeY + 30
    local upgradeTypes = {"weapon", "shield", "engine", "utility"}
    
    for i, upgradeType in ipairs(upgradeTypes) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local slotX = startX + col * (slotSize + padding + 20)
        local slotY = startY + row * (slotSize + padding + 20)
        
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            return upgradeType, 1
        end
    end
    
    return nil, nil
end

-- Obtener slot de EVA en posición
function InventoryUI:getEVASlotAt(x, y, evaInventory)
    if not evaInventory then return nil end
    
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Usar coordenadas del layout calculado
    local evaStartX = layout.evaX
    local evaStartY = layout.evaY
    local slotStartX = evaStartX + panelPadding
    local slotStartY = evaStartY + 25
    
    for i = 1, evaInventory.maxSlots do
        local slotX = slotStartX + (i - 1) * (slotSize + padding)
        local slotY = slotStartY
        
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            return i
        end
    end
    
    return nil
end

-- Obtener color por rareza de item
function InventoryUI:getItemRarityColor(item)
    if not item or not item.data then
        return uiState.colors.rarity.common
    end
    
    local ItemSystem = require 'src.item_systems.items.init'
    local itemData = ItemSystem.getItem(item.data.id)
    
    if itemData and itemData.rarity then
        return uiState.colors.rarity[itemData.rarity] or uiState.colors.rarity.common
    end
    
    return uiState.colors.rarity.common
end

-- Obtener información detallada de item
function InventoryUI:getItemInfo(item)
    if not item or not item.data then
        return nil
    end
    
    local ItemSystem = require 'src.item_systems.items.init'
    local itemData = ItemSystem.getItem(item.data.id)
    
    if itemData then
        return {
            name = itemData.name,
            description = itemData.description,
            category = itemData.category,
            rarity = itemData.rarity,
            effects = itemData.effects
        }
    end
    
    return {
        name = item.data.name or "Unknown Item",
        description = "No description available",
        category = "unknown",
        rarity = "common",
        effects = {}
    }
end

-- Crear inventario de prueba con items del sistema
function InventoryUI:createTestInventory(player)
    local ItemSystem = require 'src.item_systems.items.init'
    
    -- Limpiar inventario actual
    player.inventory.items = {}
    
    -- Agregar algunos items de prueba
    local testItems = {
        "eva_repair_kit",
        "energy_cell",
        "neural_implant_basic",
        "laser_pistol_basic",
        "metal_scrap",
        "energy_crystal"
    }
    
    for i, itemId in ipairs(testItems) do
        local itemData = ItemSystem.getItem(itemId)
        if itemData then
            player.inventory.items[i] = {
                data = {
                    id = itemId,
                    name = itemData.name,
                    quantity = 1
                }
            }
        end
    end
    
    print("[INVENTORY] Inventario de prueba creado con " .. #testItems .. " items")
end

-- Lanzar item al mundo
function InventoryUI:dropItemToWorld(item, player, mouseX, mouseY)
    if not item or not item.data or not player or not _G.camera then return end
    
    local WorldItems = require 'src.item_systems.world_items'
    local ItemSystem = require 'src.item_systems.items.init'
    
    -- Obtener datos del item
    local itemData = ItemSystem.getItem(item.data.id)
    if not itemData then
        print("[DROP] Error: No se encontraron datos para el item", item.data.id)
        return
    end
    
    -- Obtener posición del jugador en el mundo
    local activeEntity = player:getActiveEntity()
    if not activeEntity then
        print("[DROP] Error: No se pudo obtener la entidad activa")
        return
    end
    
    local playerWorldX = activeEntity.x
    local playerWorldY = activeEntity.y
    
    -- Convertir posición del mouse a coordenadas del mundo usando la función de la cámara
    local targetWorldX, targetWorldY = _G.camera:screenToWorld(mouseX, mouseY)
    
    -- Limitar la distancia máxima de drop para mantener items cerca del jugador
    local maxDropDistance = 100
    local dx = targetWorldX - playerWorldX
    local dy = targetWorldY - playerWorldY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if distance > maxDropDistance then
        local factor = maxDropDistance / distance
        targetWorldX = playerWorldX + dx * factor
        targetWorldY = playerWorldY + dy * factor
    end
    
    -- Crear item en el mundo
    local quantity = item.data.quantity or 1
    local worldItem = WorldItems.drop(itemData, playerWorldX, playerWorldY, targetWorldX, targetWorldY, quantity)
    
    if worldItem then
        print("[DROP] Item lanzado:", itemData.name, "x" .. quantity, "desde", 
              string.format("(%.1f, %.1f)", playerWorldX, playerWorldY), 
              "hacia", string.format("(%.1f, %.1f)", targetWorldX, targetWorldY))
    else
        print("[DROP] Error: No se pudo crear el item en el mundo")
    end
end

return InventoryUI