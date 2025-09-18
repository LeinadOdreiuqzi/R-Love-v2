-- src/ui/eva_inventory_ui.lua
-- UI específica para el inventario EVA (3 slots)

local EVAInventoryUI = {}

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
        height = 60
    },
    
    -- Configuración visual
    slotSize = 60,
    slotPadding = 10,
    panelPadding = 15,
    
    -- Colores
    colors = {
        background = {0.05, 0.05, 0.1, 0.9},
        slotEmpty = {0.15, 0.15, 0.2, 1},
        slotFilled = {0.25, 0.25, 0.3, 1},
        slotSelected = {0.3, 0.5, 0.7, 1},
        border = {0.4, 0.4, 0.4, 1},
        text = {1, 1, 1, 1},
        textSecondary = {0.7, 0.7, 0.7, 1},
        
        -- Colores por tipo de item EVA
        itemType = {
            tool = {0.4, 0.6, 0.8, 1},
            consumable = {0.6, 0.8, 0.4, 1},
            resource = {0.8, 0.6, 0.4, 1}
        }
    },
    
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
    self:calculateLayout()
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
    evaUIState.isOpen = not evaUIState.isOpen
    if not evaUIState.isOpen then
        evaUIState.selectedSlot = nil
    end
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
    
    -- Dibujar panel de inventario EVA
    self:drawEVAInventoryPanel(evaPlayer.inventory)
    
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
    
    -- Slots de inventario (3 slots horizontales)
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
    
    -- Dibujar item si existe
    if item then
        self:drawEVAItem(x + 2, y + 15, slotSize - 4, item)
    end
end

-- Dibujar item EVA
function EVAInventoryUI:drawEVAItem(x, y, size, item)
    local colors = evaUIState.colors
    
    -- Color por tipo de item
    local typeColor = colors.itemType[item.data.type] or colors.itemType.tool
    love.graphics.setColor(typeColor)
    love.graphics.rectangle("fill", x, y, size, size - 15)
    
    -- Nombre del item (abreviado)
    love.graphics.setColor(colors.text)
    local itemName = item.data.name
    if string.len(itemName) > 8 then
        itemName = string.sub(itemName, 1, 6) .. ".."
    end
    love.graphics.print(itemName, x + 2, y + 2)
    
    -- Cantidad si es mayor a 1
    if item.quantity and item.quantity > 1 then
        love.graphics.print("x" .. tostring(item.quantity), x + 2, y + size - 25)
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
    
    for i = 1, evaPlayer.inventory.maxSlots do
        local slotX = startX + (i - 1) * (slotSize + padding)
        local slotY = startY
        
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            if button == 1 then -- Clic izquierdo
                evaUIState.selectedSlot = i
            elseif button == 2 and evaPlayer.inventory.items[i] then -- Clic derecho en slot con item
                self:openModal(x, y, i)
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
        local optionHeight = modal.height / 2
        
        if y <= modal.y + optionHeight then
            -- Opción "Usar/Equipar"
            self:useEVAItem(modal.slotIndex, evaPlayer)
        else
            -- Opción "Eliminar"
            self:discardEVAItem(modal.slotIndex, evaPlayer)
        end
    end
    
    -- Cerrar modal
    modal.isOpen = false
end

-- Usar item EVA
function EVAInventoryUI:useEVAItem(slotIndex, evaPlayer)
    local item = evaPlayer.inventory:useItem(slotIndex)
    if item then
        print("Usando: " .. item.name)
        
        -- Aplicar efectos del item
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
    local item = evaPlayer.inventory:removeItem(slotIndex)
    if item then
        print("Descartado: " .. item.data.name)
        evaUIState.selectedSlot = nil
    end
end

-- Seleccionar slot
function EVAInventoryUI:selectSlot(slotIndex)
    evaUIState.selectedSlot = slotIndex
end

return EVAInventoryUI