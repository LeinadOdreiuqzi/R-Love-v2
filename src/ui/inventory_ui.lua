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
    
    -- Posicionamiento centrado
    uiState.layout.totalWidth = uiState.layout.inventoryWidth + uiState.layout.upgradeWidth + panelPadding
    uiState.layout.totalHeight = math.max(uiState.layout.inventoryHeight, uiState.layout.upgradeHeight)
    
    uiState.layout.inventoryX = (screenWidth - uiState.layout.totalWidth) / 2
    uiState.layout.inventoryY = (screenHeight - uiState.layout.totalHeight) / 2
    
    uiState.layout.upgradeX = uiState.layout.inventoryX + uiState.layout.inventoryWidth + panelPadding
    uiState.layout.upgradeY = uiState.layout.inventoryY
end

-- Abrir/cerrar inventario
function InventoryUI:toggle()
    uiState.isOpen = not uiState.isOpen
    if not uiState.isOpen then
        -- Limpiar estado de drag al cerrar
        uiState.draggedItem = nil
        uiState.draggedFromSlot = nil
        uiState.draggedFromType = nil
    end
end

-- Verificar si está abierto
function InventoryUI:isOpen()
    return uiState.isOpen
end

-- Actualizar UI
function InventoryUI:update(dt, player)
    if not uiState.isOpen then return end
    
    -- Actualizar posición del mouse
    uiState.mouseX, uiState.mouseY = love.mouse.getPosition()
    
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
function InventoryUI:draw(player)
    if not uiState.isOpen or not player or not player.inventory then 
        return 
    end
    
    love.graphics.push()
    
    -- Dibujar panel de inventario
    self:drawInventoryPanel(player.inventory)
    
    -- Dibujar panel de mejoras
    self:drawUpgradePanel(player.inventory)
    
    -- Dibujar item siendo arrastrado
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
    
    -- Línea divisoria
    local midY = modal.y + modal.height / 2
    love.graphics.line(modal.x, midY, modal.x + modal.width, midY)
    
    -- Texto de opciones
    love.graphics.setColor(colors.text)
    local font = love.graphics.getFont()
    local optionHeight = modal.height / 2
    
    -- Opción "Usar/Equipar"
    local useText = "Usar/Equipar"
    local useTextWidth = font:getWidth(useText)
    local useTextX = modal.x + (modal.width - useTextWidth) / 2
    local useTextY = modal.y + (optionHeight - font:getHeight()) / 2
    love.graphics.print(useText, useTextX, useTextY)
    
    -- Opción "Eliminar"
    local deleteText = "Eliminar"
    local deleteTextWidth = font:getWidth(deleteText)
    local deleteTextX = modal.x + (modal.width - deleteTextWidth) / 2
    local deleteTextY = modal.y + optionHeight + (optionHeight - font:getHeight()) / 2
    love.graphics.print(deleteText, deleteTextX, deleteTextY)
end

-- Verificar si el mouse está sobre un slot
function InventoryUI:isMouseOverSlot(x, y, size)
    return uiState.mouseX >= x and uiState.mouseX <= x + size and
           uiState.mouseY >= y and uiState.mouseY <= y + size
end

-- Verificar si es un target válido para drop
function InventoryUI:isValidDropTarget(targetType, targetSlot, targetUpgradeSlot)
    if not uiState.draggedItem then return false end
    
    if targetType == "inventory" then
        return true -- Siempre se puede mover a inventario
    elseif targetType == "upgrade" then
        -- Solo se puede equipar si el tipo coincide
        return uiState.draggedItem.data.type == targetSlot
    end
    
    return false
end

-- Manejar click del mouse
function InventoryUI:mousepressed(x, y, button, player)
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
    end
end

-- Manejar release del mouse
function InventoryUI:mousereleased(x, y, button, player)
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
                end
            end
            dropped = true
        end
    end
    
    -- Si no se pudo hacer drop, devolver item a su lugar original
    if not dropped then
        if uiState.draggedFromType == "inventory" then
            player.inventory.items[uiState.draggedFromSlot] = uiState.draggedItem
        elseif uiState.draggedFromType == "upgrade" then
            if not player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] then
                player.inventory.upgradeSlots[uiState.draggedFromUpgradeType] = {}
            end
            player.inventory.upgradeSlots[uiState.draggedFromUpgradeType][uiState.draggedFromSlot] = uiState.draggedItem
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
        local optionHeight = modal.height / 2
        
        if y <= modal.y + optionHeight then
            -- Opción "Usar/Equipar"
            self:useItem(modal.slotIndex, modal.slotType, modal.upgradeType, player)
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
    
    if slotType == "inventory" then
        item = player.inventory.items[slotIndex]
    elseif slotType == "upgrade" and upgradeType then
        item = player.inventory.upgradeSlots[upgradeType] and player.inventory.upgradeSlots[upgradeType][slotIndex]
    end
    
    if item then
        -- Aquí puedes agregar lógica específica para usar/equipar items
        print("Usando item: " .. (item.data.name or "Unknown"))
        -- Por ahora solo mostramos un mensaje
    end
end

-- Eliminar item
function InventoryUI:deleteItem(slotIndex, slotType, upgradeType, player)
    if slotType == "inventory" then
        player.inventory.items[slotIndex] = nil
        print("Item eliminado del inventario")
    elseif slotType == "upgrade" and upgradeType then
        if player.inventory.upgradeSlots[upgradeType] then
            player.inventory.upgradeSlots[upgradeType][slotIndex] = nil
            print("Item eliminado de mejoras")
        end
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

return InventoryUI