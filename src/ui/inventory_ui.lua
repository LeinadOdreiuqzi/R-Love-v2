-- src/ui/inventory_ui.lua
-- UI del inventario con drag and drop y modificación de naves

local InventoryUI = {}
local World = require 'src.core.world'

-- Estado de la UI
local uiState = {
    isOpen = false,
    draggedItem = nil,
    draggedFromSlot = nil,
    draggedFromType = nil, -- "inventory" o "eva"
    mouseX = 0,
    mouseY = 0,
    
    -- Selección de slots
    selectedPassiveSlot = nil,
    passiveSlotHighlightTimer = 0,
    selectedPassiveItemFromInventory = nil, -- Item pasivo seleccionado del inventario común
    
    -- Modal de opciones
    modal = {
        isOpen = false,
        slotIndex = nil,
        slotType = nil, -- "inventory" o "eva"
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
        slotSelected = {0.3, 0.5, 0.7, 1},
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
        
        -- Colores por tipo de item
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
        

        
        evaX = 0,
        evaY = 0,
        evaWidth = 0,
        evaHeight = 0,
        
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
    

    
    -- Configuración del panel EVA (3 slots horizontales)
    local evaColumns = 3
    local evaRows = 1
    
    uiState.layout.evaWidth = evaColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.evaHeight = evaRows * (slotSize + padding) - padding + panelPadding * 2 + 30 -- +30 para título
    
    -- Configuración del panel de armas (4 slots horizontales)
    local weaponColumns = 4
    local weaponRows = 1
    
    uiState.layout.weaponWidth = weaponColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.weaponHeight = weaponRows * (slotSize + padding) - padding + panelPadding * 2 + 30 -- +30 para título
    
    -- Configuración del panel de pasivos (6 slots en grid 3x2)
    local passiveColumns = 3
    local passiveRows = 2
    
    uiState.layout.passiveWidth = passiveColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.passiveHeight = passiveRows * (slotSize + padding) - padding + panelPadding * 2 + 30 -- +30 para título
    
    -- Posicionamiento mejorado: inventario centrado, paneles a los lados
    local maxRightPanelWidth = math.max(uiState.layout.evaWidth, uiState.layout.weaponWidth, uiState.layout.passiveWidth)
    uiState.layout.totalWidth = uiState.layout.inventoryWidth + maxRightPanelWidth + panelPadding * 3
    uiState.layout.totalHeight = uiState.layout.inventoryHeight
    
    -- Inventario principal centrado
    uiState.layout.inventoryX = (screenWidth - uiState.layout.inventoryWidth) / 2
    uiState.layout.inventoryY = (screenHeight - uiState.layout.inventoryHeight) / 2
    
    -- Panel EVA a la derecha del inventario, en la parte superior
    uiState.layout.evaX = uiState.layout.inventoryX + uiState.layout.inventoryWidth + panelPadding
    uiState.layout.evaY = uiState.layout.inventoryY
    
    -- Panel de armas a la derecha del inventario, debajo del panel EVA
    uiState.layout.weaponX = uiState.layout.inventoryX + uiState.layout.inventoryWidth + panelPadding
    uiState.layout.weaponY = uiState.layout.evaY + uiState.layout.evaHeight + panelPadding
    
    -- Panel de pasivos a la derecha del inventario, debajo del panel de armas
    uiState.layout.passiveX = uiState.layout.inventoryX + uiState.layout.inventoryWidth + panelPadding
    uiState.layout.passiveY = uiState.layout.weaponY + uiState.layout.weaponHeight + panelPadding
end

-- Abrir/cerrar inventario
function InventoryUI:toggle()
    if uiState.isOpen then
        self:close()
    else
        uiState.isOpen = true
    end
end

-- Cerrar inventario explícitamente (usado al cambiar de estado)
function InventoryUI:close()
    if not uiState.isOpen then return end
    uiState.isOpen = false
    -- Limpiar estado de drag y modal al cerrar
    uiState.draggedItem = nil
    uiState.draggedFromSlot = nil
    uiState.draggedFromType = nil
    uiState.modal.isOpen = false
end

-- Verificar si está abierto
function InventoryUI:isOpen()
    return uiState.isOpen
end

-- Función helper para manejar drops de manera centralizada
-- Helper function para convertir tipos de UI a nombres de compartimentos
function InventoryUI:getCompartmentName(uiType)
    if uiType == "inventory" then
        return "ship"
    elseif uiType == "eva" then
        return "eva"
    elseif uiType == "weapons" then
        return "equipable"
    elseif uiType == "passives" then
        return "passives"
    end
    return nil
end

function InventoryUI:handleDrop(player, targetCompartment, targetSlot)
    if not uiState.draggedItem or not uiState.draggedFromType or not uiState.draggedFromSlot then
        return false
    end
    
    -- Convertir tipos de UI a nombres de compartimentos
    local fromCompartment = self:getCompartmentName(uiState.draggedFromType)
    
    -- Realizar transferencia usando el sistema centralizado
    local success = player.inventory:transferItemBetweenCompartments(
        fromCompartment, 
        uiState.draggedFromSlot, 
        targetCompartment, 
        targetSlot
    )
    
    return success
end

-- Exponer paleta de colores para otras UIs
function InventoryUI:getColors()
    return uiState.colors
end

-- Actualizar UI
function InventoryUI:update(dt, player)
    if not uiState.isOpen then return end
    
    -- Actualizar posición del mouse
    uiState.mouseX = love.mouse.getX()
    uiState.mouseY = love.mouse.getY()
    
    -- Actualizar timer de highlight para items pasivos
    if uiState.passiveSlotHighlightTimer > 0 then
        uiState.passiveSlotHighlightTimer = uiState.passiveSlotHighlightTimer - dt
        if uiState.passiveSlotHighlightTimer <= 0 then
            uiState.selectedPassiveSlot = nil
        end
    end
    
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
    local shipComp = (player.inventory.getCompartment and player.inventory:getCompartment('ship')) or player.inventory
    self:drawInventoryPanel(shipComp, player.inventory)
    
    -- Dibujar panel EVA integrado
    local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
    if evaComp then
        self:drawEVAPanel(evaComp)
    end
    
    -- Dibujar panel de armas
    local weaponComp = (player.inventory.getCompartment and player.inventory:getCompartment('weapons')) or nil
    if weaponComp then
        self:drawWeaponPanel(weaponComp)
    end
    
    -- Dibujar panel de pasivos
    local passiveComp = (player.inventory.getCompartment and player.inventory:getCompartment('passives')) or nil
    if passiveComp then
        self:drawPassivePanel(passiveComp, player)
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
function InventoryUI:drawInventoryPanel(compartment, mainInventory)
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
    local shipType = (mainInventory and mainInventory.shipType) or "Desconocido"
    love.graphics.print("Inventario (" .. shipType .. ")", 
                       layout.inventoryX + panelPadding, layout.inventoryY + 5)
    
    -- Slots del inventario
    local startX = layout.inventoryX + panelPadding
    local startY = layout.inventoryY + 30
    local columns = 5
    
    for i = 1, compartment.maxSlots do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local x = startX + col * (slotSize + padding)
        local y = startY + row * (slotSize + padding)
        
        self:drawInventorySlot(x, y, i, compartment.items[i])
    end
end



-- Dibujar panel EVA
function InventoryUI:drawEVAPanel(evaCompartment)
    local layout = uiState.layout
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Fondo del panel
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", layout.evaX, layout.evaY, 
                           layout.evaWidth, layout.evaHeight)
    
    -- Borde del panel
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", layout.evaX, layout.evaY, 
                           layout.evaWidth, layout.evaHeight)
    
    -- Título
    love.graphics.setColor(colors.text)
    love.graphics.setFont(uiState.font)
    love.graphics.print("Inventario EVA", layout.evaX + panelPadding, layout.evaY + 5)
    
    -- Slots del inventario EVA (3 slots horizontales)
    local startX = layout.evaX + panelPadding
    local startY = layout.evaY + 30
    
    for i = 1, evaCompartment.maxSlots do
        local x = startX + (i - 1) * (slotSize + padding)
        local y = startY
        
        self:drawEVASlot(x, y, i, evaCompartment.items[i])
    end
end

-- Dibujar panel de armas
function InventoryUI:drawWeaponPanel(weaponCompartment)
    local layout = uiState.layout
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Fondo del panel
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", layout.weaponX, layout.weaponY, 
                           layout.weaponWidth, layout.weaponHeight)
    
    -- Borde del panel
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", layout.weaponX, layout.weaponY, 
                           layout.weaponWidth, layout.weaponHeight)
    
    -- Título
    love.graphics.setColor(colors.text)
    love.graphics.setFont(uiState.font)
    love.graphics.print("Armas Equipadas", layout.weaponX + panelPadding, layout.weaponY + 5)
    
    -- Slots de armas (4 slots horizontales)
    local startX = layout.weaponX + panelPadding
    local startY = layout.weaponY + 30
    
    for i = 1, weaponCompartment.maxSlots do
        local x = startX + (i - 1) * (slotSize + padding)
        local y = startY
        
        self:drawWeaponSlot(x, y, i, weaponCompartment.items[i])
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
    
    -- Verificar si es target válido para drop
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

-- Dibujar slot EVA
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
    
    -- Verificar si es target válido para drop
    if uiState.draggedItem and self:isValidDropTarget("eva", slotIndex) then
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

-- Dibujar slot de arma
function InventoryUI:drawWeaponSlot(x, y, slotIndex, item)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    
    -- Determinar color del slot
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    -- Slot 1 tiene color especial (arma por defecto)
    if slotIndex == 1 then
        slotColor = {0.3, 0.2, 0.1, 1} -- Color dorado/marrón para slot por defecto
        if item then
            slotColor = {0.4, 0.3, 0.2, 1}
        end
    end
    
    -- Verificar hover
    if self:isMouseOverSlot(x, y, slotSize) then
        slotColor = colors.slotHover
    end
    
    -- Verificar si es target de drag
    if uiState.draggedItem and self:isMouseOverSlot(x, y, slotSize) then
        -- Solo permitir drop de armas
        if uiState.draggedItem.data and uiState.draggedItem.data.category == "equipable" and 
           uiState.draggedItem.data.equipType == "weapon" then
            slotColor = colors.slotDragTarget
        else
            slotColor = {0.6, 0.2, 0.2, 1} -- Rojo para indicar que no se puede hacer drop
        end
    end
    
    -- Dibujar slot
    love.graphics.setColor(slotColor)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize)
    
    -- Borde del slot
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", x, y, slotSize, slotSize)
    
    -- Indicador de slot número
    love.graphics.setColor(colors.textSecondary)
    love.graphics.setFont(uiState.smallFont)
    love.graphics.print(tostring(slotIndex), x + 2, y + 2)
    
    -- Dibujar item si existe
    if item then
        -- Color por rareza
        local rarityColor = self:getItemRarityColor(item)
        love.graphics.setColor(rarityColor)
        love.graphics.rectangle("fill", x + 2, y + 12, slotSize - 4, slotSize - 14)
        
        -- Nombre del item
        love.graphics.setColor(colors.text)
        love.graphics.setFont(uiState.smallFont)
        local itemName = item.data and item.data.name or "Unknown"
        local textWidth = uiState.smallFont:getWidth(itemName)
        if textWidth > slotSize - 4 then
            itemName = string.sub(itemName, 1, 6) .. "..."
        end
        love.graphics.print(itemName, x + 2, y + slotSize - 15)
    end
end

-- Dibujar item
function InventoryUI:drawItem(x, y, size, item)
    local colors = uiState.colors
    
    -- Verificar que el item y sus datos existan
    if not item or not item.data then
        return
    end
    
    -- Usar el color de rareza obtenido desde el sistema de items por ID
    local rarityColor = self:getItemRarityColor(item)
    love.graphics.setColor(rarityColor)
    love.graphics.rectangle("fill", x, y, size, size)
    
    -- Texto del item (primera letra del nombre)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(uiState.font)
    local itemName = item.data and item.data.name or "Unknown"
    local firstLetter = string.sub(itemName, 1, 1)
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
    
    -- Texto de opciones
    love.graphics.setColor(colors.text)
    local font = love.graphics.getFont()
    
    if modal.slotType == "weapons" then
        -- Modal para armas equipadas - solo 2 opciones
        local optionHeight = modal.height / 2
        
        -- Línea divisoria
        local dividerY = modal.y + optionHeight
        love.graphics.line(modal.x, dividerY, modal.x + modal.width, dividerY)
        
        -- Verificar si es slot 1 (arma por defecto)
        local isDefaultWeapon = (modal.slotIndex == 1)
        
        if isDefaultWeapon then
            -- Para arma por defecto, mostrar mensaje informativo
            local infoText = "Arma por defecto"
            local infoTextWidth = font:getWidth(infoText)
            local infoTextX = modal.x + (modal.width - infoTextWidth) / 2
            local infoTextY = modal.y + (optionHeight - font:getHeight()) / 2
            love.graphics.setColor(0.7, 0.7, 0.7) -- Color gris
            love.graphics.print(infoText, infoTextX, infoTextY)
            
            local disabledText = "(No se puede modificar)"
            local disabledTextWidth = font:getWidth(disabledText)
            local disabledTextX = modal.x + (modal.width - disabledTextWidth) / 2
            local disabledTextY = modal.y + optionHeight + (optionHeight - font:getHeight()) / 2
            love.graphics.print(disabledText, disabledTextX, disabledTextY)
        else
            -- Para otras armas, mostrar opciones normales
            love.graphics.setColor(colors.text)
            
            -- Opción "Mover a inventario"
            local moveText = "Mover a inventario"
            local moveTextWidth = font:getWidth(moveText)
            local moveTextX = modal.x + (modal.width - moveTextWidth) / 2
            local moveTextY = modal.y + (optionHeight - font:getHeight()) / 2
            love.graphics.print(moveText, moveTextX, moveTextY)
            
            -- Opción "Eliminar"
            local deleteText = "Eliminar"
            local deleteTextWidth = font:getWidth(deleteText)
            local deleteTextX = modal.x + (modal.width - deleteTextWidth) / 2
            local deleteTextY = modal.y + optionHeight + (optionHeight - font:getHeight()) / 2
            love.graphics.print(deleteText, deleteTextX, deleteTextY)
        end
    elseif modal.slotType == "passives" then
        -- Modal para items pasivos - solo 2 opciones (sin usar/equipar)
        local optionHeight = modal.height / 2
        
        -- Línea divisoria
        local dividerY = modal.y + optionHeight
        love.graphics.line(modal.x, dividerY, modal.x + modal.width, dividerY)
        
        love.graphics.setColor(colors.text)
        
        -- Opción "Expulsar de la nave"
        local ejectText = "Expulsar de la nave"
        local ejectTextWidth = font:getWidth(ejectText)
        local ejectTextX = modal.x + (modal.width - ejectTextWidth) / 2
        local ejectTextY = modal.y + (optionHeight - font:getHeight()) / 2
        love.graphics.print(ejectText, ejectTextX, ejectTextY)
        
        -- Opción "Eliminar"
        local deleteText = "Eliminar"
        local deleteTextWidth = font:getWidth(deleteText)
        local deleteTextX = modal.x + (modal.width - deleteTextWidth) / 2
        local deleteTextY = modal.y + optionHeight + (optionHeight - font:getHeight()) / 2
        love.graphics.print(deleteText, deleteTextX, deleteTextY)
    else
        -- Modal para inventario normal - 3 opciones
        local optionHeight = modal.height / 3
        local firstDividerY = modal.y + optionHeight
        local secondDividerY = modal.y + optionHeight * 2
        love.graphics.line(modal.x, firstDividerY, modal.x + modal.width, firstDividerY)
        love.graphics.line(modal.x, secondDividerY, modal.x + modal.width, secondDividerY)
        
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
end

-- Verificar si el mouse está sobre un slot
function InventoryUI:isMouseOverSlot(x, y, size)
    return uiState.mouseX >= x and uiState.mouseX <= x + size and
           uiState.mouseY >= y and uiState.mouseY <= y + size
end

-- Verificar si es un target válido para drop
function InventoryUI:isValidDropTarget(targetType, targetSlot)
    if not uiState.draggedItem or not uiState.draggedItem.data then return false end
    
    if targetType == "inventory" then
        return true -- Siempre se puede mover a inventario
    elseif targetType == "eva" then
        return true -- Siempre se puede mover a EVA (las restricciones se manejan en la transferencia)
    elseif targetType == "passives" then
        -- Solo items con categoría PASSIVE pueden ir a pasivos
        return uiState.draggedItem.data.category == "passive"
    end
    
    return false
end

-- Verificar si un slot pasivo debería mostrar feedback visual
function InventoryUI:shouldShowPassiveSlotFeedback(slotIndex, player)
    -- Si hay un item pasivo seleccionado del inventario común
    if uiState.selectedPassiveItemFromInventory then
        -- Verificar que el slot esté vacío (disponible para equipar)
        local passiveComp = player.inventory:getCompartment('passives')
        if passiveComp and not passiveComp.items[slotIndex] then
            return true
        end
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
        -- Verificar click en inventario (compartimento 'ship')
        local shipComp = (player.inventory.getCompartment and player.inventory:getCompartment('ship')) or player.inventory
        local inventorySlot = self:getInventorySlotAt(x, y, shipComp)
        if inventorySlot then
            local item = shipComp.items[inventorySlot]
            if item then
                -- Si se presiona Shift, transferir al compartimento EVA
                if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
                    -- Verificar proximidad a la nave si está en modo EVA
                    if player.isInEVA and player.evaPlayer and not player.evaPlayer:canEnterShip() then
                        print("[TRANSFER] Error: Debes estar cerca de la nave para transferir items")
                        return
                    end
                    self:transferItemToEVA(player, inventorySlot)
                    return
                end
                
                -- Verificar si es un item pasivo para mostrar feedback visual
                if item.data and item.data.category == "passive" then
                    uiState.selectedPassiveItemFromInventory = item
                else
                    uiState.selectedPassiveItemFromInventory = nil
                end
                
                uiState.draggedItem = item
                uiState.draggedFromSlot = inventorySlot
                uiState.draggedFromType = "inventory"
                -- No manipular directamente el array, el sistema centralizado lo manejará al hacer drop
            else
                -- Si se hace clic en un slot vacío, limpiar selección
                uiState.selectedPassiveItemFromInventory = nil
            end
            return
        end
        
        -- Verificar click en panel EVA
        local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
        if evaComp then
            local evaSlot = self:getEVASlotAt(x, y)
            if evaSlot then
                local item = evaComp.items[evaSlot]
                if item then
                    -- Si se presiona Shift, transferir al compartimento ship
                    if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
                        -- Verificar proximidad a la nave si está en modo EVA
                        if player.isInEVA and player.evaPlayer and not player.evaPlayer:canEnterShip() then
                            print("[TRANSFER] Error: Debes estar cerca de la nave para transferir items")
                            return
                        end
                        self:transferItemToShip(player, evaSlot)
                        return
                    end
                    
                    -- Verificar si es un item pasivo para mostrar feedback visual
                    if item.data and item.data.category == "passive" then
                        uiState.selectedPassiveItemFromInventory = item
                    else
                        uiState.selectedPassiveItemFromInventory = nil
                    end
                    
                    uiState.draggedItem = item
                    uiState.draggedFromSlot = evaSlot
                    uiState.draggedFromType = "eva"
                    -- No manipular directamente el array, el sistema centralizado lo manejará al hacer drop
                else
                    -- Si se hace clic en un slot vacío, limpiar selección
                    uiState.selectedPassiveItemFromInventory = nil
                end
                return
            end
        end
        
        -- Verificar click en panel de armas
        local weaponComp = (player.inventory.getCompartment and player.inventory:getCompartment('weapons')) or nil
        if weaponComp then
            local weaponSlot = self:getWeaponSlotAt(x, y)
            if weaponSlot then
                local item = weaponComp.items[weaponSlot]
                if item then
                    -- No permitir arrastrar el arma por defecto del slot 1
                    if weaponSlot == 1 then
                        print("[DRAG] Error: No se puede mover el arma por defecto")
                        return
                    end
                    
                    uiState.draggedItem = item
                    uiState.draggedFromSlot = weaponSlot
                    uiState.draggedFromType = "weapons"
                    -- No manipular directamente el array, el sistema centralizado lo manejará al hacer drop
                end
                return
            end
        end
        
        -- Verificar click en panel de pasivos
        local passiveComp = (player.inventory.getCompartment and player.inventory:getCompartment('passives')) or nil
        if passiveComp then
            local passiveSlot = self:getPassiveSlotAt(x, y)
            if passiveSlot then
                local item = passiveComp.items[passiveSlot]
                if item then
                    -- Si se presiona Shift, transferir al inventario principal
                    if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
                        -- Verificar proximidad a la nave si está en modo EVA
                        if player.isInEVA and player.evaPlayer and not player.evaPlayer:canEnterShip() then
                            print("[TRANSFER] Error: Debes estar cerca de la nave para transferir items")
                            return
                        end
                        self:transferItemFromPassives(player, passiveSlot)
                        return
                    end
                    
                    uiState.draggedItem = item
                    uiState.draggedFromSlot = passiveSlot
                    uiState.draggedFromType = "passives"
                    -- No manipular directamente el array, el sistema centralizado lo manejará al hacer drop
                end
                return
            end
        end

    elseif button == 2 then -- Clic derecho
        -- Verificar clic derecho en inventario (compartimento 'ship')
        local shipComp = (player.inventory.getCompartment and player.inventory:getCompartment('ship')) or player.inventory
        local inventorySlot = self:getInventorySlotAt(x, y, shipComp)
        if inventorySlot and shipComp.items[inventorySlot] then
            self:openModal(x, y, inventorySlot, "inventory")
            return
        end
        
        -- Verificar clic derecho en panel EVA
        local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
        if evaComp then
            local evaSlot = self:getEVASlotAt(x, y)
            if evaSlot and evaComp.items[evaSlot] then
                self:openModal(x, y, evaSlot, "eva")
                return
            end
        end
        
        -- Verificar clic derecho en panel de armas
        local weaponComp = (player.inventory.getCompartment and player.inventory:getCompartment('weapons')) or nil
        if weaponComp then
            local weaponSlot = self:getWeaponSlotAt(x, y)
            if weaponSlot and weaponComp.items[weaponSlot] then
                self:openModal(x, y, weaponSlot, "weapons")
                return
            end
        end
        
        -- Verificar clic derecho en panel de pasivos
        local passiveComp = (player.inventory.getCompartment and player.inventory:getCompartment('passives')) or nil
        if passiveComp then
            local passiveSlot = self:getPassiveSlotAt(x, y)
            if passiveSlot and passiveComp.items[passiveSlot] then
                self:openModal(x, y, passiveSlot, "passives")
                return
            end
        end

    end
end

-- Manejar release del mouse
function InventoryUI:mousereleased(x, y, button, player)
    if not uiState.isOpen or button ~= 1 or not uiState.draggedItem or not player or not player.inventory then 
        return 
    end
    
    local dropped = false
    local shipComp = (player.inventory.getCompartment and player.inventory:getCompartment('ship')) or player.inventory
    local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
    local weaponComp = (player.inventory.getCompartment and player.inventory:getCompartment('weapons')) or nil
    local passiveComp = (player.inventory.getCompartment and player.inventory:getCompartment('passives')) or nil
    
    -- Verificar drop en inventario (compartimento 'ship')
    local inventorySlot = self:getInventorySlotAt(x, y, shipComp)
    if inventorySlot then
        dropped = self:handleDrop(player, "ship", inventorySlot)
    end
    
    -- Verificar drop en panel EVA
    if not dropped and evaComp then
        local evaSlot = self:getEVASlotAt(x, y)
        if evaSlot then
            dropped = self:handleDrop(player, "eva", evaSlot)
        end
    end
    
    -- Verificar drop en panel de armas
    if not dropped and weaponComp then
        local weaponSlot = self:getWeaponSlotAt(x, y)
        if weaponSlot then
            -- Solo permitir drop de armas
            if uiState.draggedItem.data and uiState.draggedItem.data.category == "equipable" and 
               uiState.draggedItem.data.equipType == "weapon" then
                dropped = self:handleDrop(player, "weapons", weaponSlot)
            end
        end
    end
    
    -- Verificar drop en panel de pasivos
    if not dropped and passiveComp then
        local passiveSlot = self:getPassiveSlotAt(x, y)
        if passiveSlot then
            -- Solo permitir drop de items pasivos
            if uiState.draggedItem.data and uiState.draggedItem.data.category == "passive" then
                dropped = self:handleDrop(player, "passives", passiveSlot)
            end
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
        
        local mouseOutsideEVA = true
        if evaComp then
            mouseOutsideEVA = uiState.mouseX < layout.evaX or 
                             uiState.mouseX > layout.evaX + layout.evaWidth or
                             uiState.mouseY < layout.evaY or 
                             uiState.mouseY > layout.evaY + layout.evaHeight
        end
        
        local mouseOutsideWeapons = true
        if weaponComp then
            mouseOutsideWeapons = uiState.mouseX < layout.weaponX or 
                                 uiState.mouseX > layout.weaponX + layout.weaponWidth or
                                 uiState.mouseY < layout.weaponY or 
                                 uiState.mouseY > layout.weaponY + layout.weaponHeight
        end
        
        local mouseOutsidePassives = true
        if passiveComp then
            mouseOutsidePassives = uiState.mouseX < layout.passiveX or 
                                  uiState.mouseX > layout.passiveX + layout.passiveWidth or
                                  uiState.mouseY < layout.passiveY or 
                                  uiState.mouseY > layout.passiveY + layout.passiveHeight
        end
        
        if mouseOutsideInventory and mouseOutsideEVA and mouseOutsideWeapons and mouseOutsidePassives then
            -- Drop al mundo
            self:dropItemToWorld(uiState.draggedItem, player, uiState.mouseX, uiState.mouseY)
            dropped = true
        else
            -- Devolver item a su lugar original usando el sistema centralizado
            local fromCompartment = self:getCompartmentName(uiState.draggedFromType)
            if fromCompartment then
                -- Usar el sistema centralizado para devolver el item
                player.inventory:addItemToCompartment(fromCompartment, uiState.draggedItem, uiState.draggedFromSlot)
            end
        end
    end
    
    -- Limpiar estado de drag
    uiState.draggedItem = nil
    uiState.draggedFromSlot = nil
    uiState.draggedFromType = nil
    uiState.selectedPassiveItemFromInventory = nil

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
function InventoryUI:openModal(x, y, slotIndex, slotType)
    uiState.modal.isOpen = true
    uiState.modal.slotIndex = slotIndex
    uiState.modal.slotType = slotType
    uiState.modal.x = x
    uiState.modal.y = y
end

-- Manejar clics en el modal
function InventoryUI:handleModalClick(x, y, button, player)
    if button ~= 1 then return end -- Solo clic izquierdo
    
    local modal = uiState.modal
    
    -- Verificar si el clic está dentro del modal
    if x >= modal.x and x <= modal.x + modal.width and y >= modal.y and y <= modal.y + modal.height then
        
        if modal.slotType == "weapons" then
            -- Modal para armas equipadas
            local isDefaultWeapon = (modal.slotIndex == 1)
            
            if isDefaultWeapon then
                -- No hacer nada para el arma por defecto
                modal.isOpen = false
                return
            end
            
            -- Para otras armas, solo 2 opciones
            local optionHeight = modal.height / 2
            
            if y <= modal.y + optionHeight then
                 -- Mover a inventario
                 self:transferWeaponToInventory(player, modal.slotIndex)
            else
                -- Eliminar
                self:deleteItem(modal.slotIndex, modal.slotType, player)
            end
        elseif modal.slotType == "passives" then
            -- Modal para items pasivos - solo 2 opciones
            local optionHeight = modal.height / 2
            
            if y <= modal.y + optionHeight then
                -- Opción "Expulsar de la nave"
                self:dropItemFromModal(modal.slotIndex, modal.slotType, player)
            else
                -- Opción "Eliminar"
                self:deleteItem(modal.slotIndex, modal.slotType, player)
            end
        else
            -- Modal para inventario normal - 3 opciones
            local optionHeight = modal.height / 3
            
            if y <= modal.y + optionHeight then
                -- Opción "Usar/Equipar"
                self:useItem(modal.slotIndex, modal.slotType, player)
            elseif y <= modal.y + optionHeight * 2 then
                -- Opción "Lanzar al mundo"
                self:dropItemFromModal(modal.slotIndex, modal.slotType, player)
            else
                -- Opción "Eliminar"
                self:deleteItem(modal.slotIndex, modal.slotType, player)
            end
        end
    end
    
    -- Cerrar modal
    modal.isOpen = false
end

-- Usar/equipar item
function InventoryUI:useItem(slotIndex, slotType, player)
    local item = nil
    local shipComp = (player and player.inventory and player.inventory.getCompartment) and player.inventory:getCompartment('ship') or player.inventory
    
    if slotType == "inventory" then
        item = shipComp.items[slotIndex]
    elseif slotType == "eva" then
        local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
        if evaComp then
            item = evaComp.items[slotIndex]
        end
    elseif slotType == "weapons" then
        -- No permitir usar/equipar desde armas equipadas - no tiene sentido
        print("[USE] Error: No se puede usar/equipar un arma ya equipada")
        return
    end
    
    if item and item.data then
        local ItemSystem = require 'src.item_systems.item_system'
        local itemData = ItemSystem:getItem(item.data.id)
        
        if itemData then
            if itemData.category == "consumable" then
                local success = ItemSystem.useItem(item.data.id, player)
                if success then
                    if slotType == "inventory" then
                        shipComp.items[slotIndex] = nil
                    elseif slotType == "eva" then
                        local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
                        if evaComp then
                            evaComp.items[slotIndex] = nil
                        end
                    end
                    print("Usado: " .. itemData.name)
                else
                    print("No se pudo usar: " .. itemData.name)
                end
            elseif itemData.category == "equipable" then
                -- Manejar armas específicamente
                if itemData.equipType == "weapon" and player.weaponSystem then
                    -- Buscar slot libre para arma (empezar desde slot 2)
                    local weaponSlot = nil
                    for slot = 2, 4 do
                        if not player.inventory:getWeaponInSlot(slot) then
                            weaponSlot = slot
                            break
                        end
                    end
                    
                    if weaponSlot then
                        local success = player.weaponSystem:equipWeapon(itemData, weaponSlot)
                        if success then
                            -- Remover item del inventario después de equipar exitosamente
                            if slotType == "inventory" then
                                shipComp.items[slotIndex] = nil
                            elseif slotType == "eva" then
                                local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
                                if evaComp then
                                    evaComp.items[slotIndex] = nil
                                end
                            end
                            print("Arma equipada: " .. itemData.name .. " en slot " .. weaponSlot)
                        else
                            print("No se pudo equipar arma: " .. itemData.name)
                        end
                    else
                        print("No hay slots de arma disponibles")
                    end
                else
                    -- Otros equipables (armaduras, etc.)
                    local success = ItemSystem:equipItem(itemData, player)
                    if success then
                        -- Remover item del inventario después de equipar exitosamente
                        if slotType == "inventory" then
                            shipComp.items[slotIndex] = nil
                        elseif slotType == "eva" then
                            local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
                            if evaComp then
                                evaComp.items[slotIndex] = nil
                            end
                        end
                        print("Equipado: " .. itemData.name)
                    else
                        print("No se pudo equipar: " .. itemData.name)
                    end
                end
            elseif itemData.category == "passive" then
                -- Manejar items pasivos - transferir al compartimento de pasivos
                self:equipPassiveItem(slotIndex, slotType, player)
            else
                print("Item: " .. itemData.name .. " (" .. itemData.category .. ")")
            end
        else
            print("Usando item: " .. (item.data.name or "Unknown"))
        end
    end
end

-- Eliminar item
function InventoryUI:deleteItem(slotIndex, slotType, player)
    local shipComp = (player and player.inventory and player.inventory.getCompartment) and player.inventory:getCompartment('ship') or player.inventory
    
    if slotType == "inventory" then
        shipComp.items[slotIndex] = nil
        print("Item eliminado del inventario")
    elseif slotType == "eva" then
        local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
        if evaComp then
            evaComp.items[slotIndex] = nil
            print("Item eliminado del inventario EVA")
        end
    elseif slotType == "weapons" then
        -- No permitir eliminar arma del slot 1 (arma por defecto)
        if slotIndex == 1 then
            print("[DELETE] Error: No se puede eliminar el arma por defecto")
            return
        end
        
        local weaponComp = (player.inventory.getCompartment and player.inventory:getCompartment('weapons')) or nil
        if weaponComp then
            -- Si era el arma actual, cambiar a la siguiente disponible
            if player.weaponSystem and player.weaponSystem.currentSlot == slotIndex then
                player.weaponSystem:switchToNextAvailableWeapon()
            end
            
            weaponComp.items[slotIndex] = nil
            print("Arma eliminada del slot " .. slotIndex)
        end
    elseif slotType == "passives" then
        local passiveComp = (player.inventory.getCompartment and player.inventory:getCompartment('passives')) or nil
        if passiveComp and passiveComp.items[slotIndex] then
            -- Usar el método del inventario que maneja automáticamente los efectos pasivos
            if player.inventory and player.inventory.removeItemFromCompartment then
                player.inventory:removeItemFromCompartment('passives', slotIndex)
                print("Item pasivo eliminado del slot " .. slotIndex)
            else
                print("[DELETE] Error: No se pudo acceder al sistema de inventario")
            end
        else
            print("[DELETE] Error: No hay item pasivo en el slot " .. slotIndex)
        end
    end
end

-- Lanzar item al mundo desde modal
function InventoryUI:dropItemFromModal(slotIndex, slotType, player)
    local item = nil
    local shipComp = (player and player.inventory and player.inventory.getCompartment) and player.inventory:getCompartment('ship') or player.inventory
    
    if slotType == "inventory" then
        item = shipComp.items[slotIndex]
    elseif slotType == "eva" then
        local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
        if evaComp then
            item = evaComp.items[slotIndex]
        end
    elseif slotType == "weapons" then
        -- No permitir lanzar arma del slot 1 (arma por defecto)
        if slotIndex == 1 then
            print("[DROP MODAL] Error: No se puede lanzar el arma por defecto")
            return
        end
        
        local weaponComp = (player.inventory.getCompartment and player.inventory:getCompartment('weapons')) or nil
        if weaponComp then
            item = weaponComp.items[slotIndex]
        end
    elseif slotType == "passives" then
        local passiveComp = (player.inventory.getCompartment and player.inventory:getCompartment('passives')) or nil
        if passiveComp then
            item = passiveComp.items[slotIndex]
        end
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
            shipComp.items[slotIndex] = nil
        elseif slotType == "eva" then
            local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
            if evaComp then
                evaComp.items[slotIndex] = nil
            end
        elseif slotType == "weapons" then
            local weaponComp = (player.inventory.getCompartment and player.inventory:getCompartment('weapons')) or nil
            if weaponComp then
                -- Si era el arma actual, cambiar a la siguiente disponible
                if player.weaponSystem and player.weaponSystem.currentSlot == slotIndex then
                    player.weaponSystem:switchToNextAvailableWeapon()
                end
                
                weaponComp.items[slotIndex] = nil
            end
        elseif slotType == "passives" then
            -- Usar el método del inventario del jugador para remover correctamente el item pasivo y sus efectos
            if player.inventory and player.inventory.removeItemFromCompartment then
                player.inventory:removeItemFromCompartment('passives', slotIndex)
            else
                -- Fallback: remover manualmente del compartimento
                local passiveComp = (player.inventory.getCompartment and player.inventory:getCompartment('passives')) or nil
                if passiveComp then
                    passiveComp.items[slotIndex] = nil
                end
            end
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



-- Obtener slot EVA en posición
function InventoryUI:getEVASlotAt(x, y)
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    local startX = layout.evaX + panelPadding
    local startY = layout.evaY + 30
    
    -- 3 slots horizontales
    for i = 1, 3 do
        local slotX = startX + (i - 1) * (slotSize + padding)
        local slotY = startY
        
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            return i
        end
    end
    
    return nil
end

-- Obtener slot de arma en posición
function InventoryUI:getWeaponSlotAt(x, y)
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    local startX = layout.weaponX + panelPadding
    local startY = layout.weaponY + 30
    
    -- 4 slots horizontales
    for i = 1, 4 do
        local slotX = startX + (i - 1) * (slotSize + padding)
        local slotY = startY
        
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            return i
        end
    end
    
    return nil
end

-- Obtener slot de pasivos en coordenadas específicas
function InventoryUI:getPassiveSlotAt(x, y)
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    local startX = layout.passiveX + panelPadding
    local startY = layout.passiveY + 30
    local columns = 3
    
    -- 6 slots en grid 3x2
    for i = 1, 6 do
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

-- Obtener color por rareza de item
function InventoryUI:getItemRarityColor(item)
    if not item or not item.data then
        return uiState.colors.rarity.common
    end
    
    -- 1) Preferir rareza directamente en el item si está presente
    if item.data.rarity then
        if type(item.data.rarity) == "table" and item.data.rarity.color then
            local c = item.data.rarity.color
            return {c[1], c[2], c[3], 1}
        elseif type(item.data.rarity) == "string" then
            return uiState.colors.rarity[item.data.rarity] or uiState.colors.rarity.common
        end
    end
    
    -- 2) Si no está en el item, intentar obtenerla desde el sistema por ID
    if item.data.id then
        local ItemSystem = require 'src.item_systems.items.init'
        local itemData = ItemSystem.getItem(item.data.id)
        if itemData and itemData.rarity then
            if type(itemData.rarity) == "table" and itemData.rarity.color then
                local c = itemData.rarity.color
                return {c[1], c[2], c[3], 1}
            elseif type(itemData.rarity) == "string" then
                return uiState.colors.rarity[itemData.rarity] or uiState.colors.rarity.common
            end
        end
    end
    
    -- 3) Fallback
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
    
    -- Limpiar inventario actual del compartimento 'ship'
    local shipComp = (player and player.inventory and player.inventory.getCompartment) and player.inventory:getCompartment('ship') or player.inventory
    shipComp.items = {}
    
    -- Items de ejemplo - Armas para testear integración con weapon_system
    local testItems = {
        -- Armas principales
        "basic_laser_pistol",
        "plasma_rifle",
        "kinetic_assault_rifle",
        "heavy_plasma_cannon",
        "energy_shotgun"
    }
    
    local slotIndex = 1
    for _, itemId in ipairs(testItems) do
        local itemData = ItemSystem.getItem(itemId)
        if itemData then
            shipComp.items[slotIndex] = {
                data = {
                    id = itemId,
                    name = itemData.name,
                    category = itemData.category,
                    rarity = itemData.rarity,
                    equipType = itemData.equipType,
                },
                quantity = itemData.category == "material" and 5 or 1
            }
            slotIndex = slotIndex + 1
        else
            print("[WARNING] Item no encontrado: " .. itemId)
        end
    end
    
    -- Agregar items pasivos de prueba al compartimento de pasivos
    local passiveTestItems = {
        "enhanced_thrusters",       -- +5% velocidad base
        "rapid_fire_system",        -- +2% velocidad de disparo
        "auxiliary_heart"           -- +1 corazón de vida
    }
    
    local passiveSlotIndex = 1
    for _, itemId in ipairs(passiveTestItems) do
        local itemData = ItemSystem.getItem(itemId)
        if itemData then
            -- Usar el método correcto del inventario para agregar al compartimento de pasivos
            local success = player.inventory:addItemToCompartment('passives', itemData, 1)
            if success then
                passiveSlotIndex = passiveSlotIndex + 1
                print("[INVENTORY] Item pasivo agregado y aplicado: " .. itemId)
            else
                print("[WARNING] No se pudo agregar item pasivo: " .. itemId)
            end
        else
            print("[WARNING] Item pasivo no encontrado: " .. itemId)
        end
    end
    
    print("[INVENTORY] Items pasivos de prueba procesados: " .. (passiveSlotIndex - 1) .. " items")
    
    print("[INVENTORY] Inventario de prueba creado con " .. (slotIndex - 1) .. " armas para testear weapon_system")
end

-- Lanzar item al mundo
function InventoryUI:dropItemToWorld(item, player, mouseX, mouseY)
    local cam = World.get('camera')
    if not item or not item.data or not player or not cam then return end
    
    -- Validación adicional: No permitir lanzar arma por defecto del slot 1
    if uiState.draggedFromType == "weapons" and uiState.draggedFromSlot == 1 then
        print("[DROP] Error: No se puede lanzar el arma por defecto al mundo")
        return
    end
    
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
    local targetWorldX, targetWorldY = cam:screenToWorld(mouseX, mouseY)
    
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
        -- Remover el item del inventario original solo si se creó exitosamente en el mundo
        local fromCompartment = self:getCompartmentName(uiState.draggedFromType)
        if fromCompartment and player.inventory and player.inventory.removeItemFromCompartment then
            player.inventory:removeItemFromCompartment(fromCompartment, uiState.draggedFromSlot)
        end
        
        print("[DROP] Item lanzado:", itemData.name, "x" .. quantity, "desde", 
              string.format("(%.1f, %.1f)", playerWorldX, playerWorldY), 
              "hacia", string.format("(%.1f, %.1f)", targetWorldX, targetWorldY))
    else
        print("[DROP] Error: No se pudo crear el item en el mundo")
    end
end

-- Transferir item del compartimento ship al compartimento EVA
function InventoryUI:transferItemToEVA(player, fromSlot)
    if not player or not player.inventory or not player.inventory.getCompartment then
        print("[TRANSFER] Error: No se puede acceder al sistema de inventario")
        return false
    end
    
    local shipComp = player.inventory:getCompartment('ship')
    local evaComp = player.inventory:getCompartment('eva')
    
    if not shipComp or not evaComp then
        print("[TRANSFER] Error: No se pueden encontrar los compartimentos")
        return false
    end
    
    local item = shipComp.items[fromSlot]
    if not item then
        print("[TRANSFER] Error: No hay item en el slot especificado")
        return false
    end
    
    -- Verificar si el item es permitido en el compartimento EVA
    if evaComp.allowedTypes and item.data and item.data.category then
        -- Mapear categoría a tipo EVA
        local categoryToEVAType = {
            ["consumable"] = "consumable",
            ["equipable"] = "tool",
            ["material"] = "resource"
        }
        local evaType = categoryToEVAType[item.data.category]
        if not evaType or not evaComp.allowedTypes[evaType] then
            print("[TRANSFER] Error: Tipo de item '" .. (evaType or item.data.category) .. "' no permitido en EVA")
            return false
        end
    end
    
    -- Buscar slot vacío en EVA
    local targetSlot = nil
    for i = 1, evaComp.maxSlots do
        if not evaComp.items[i] then
            targetSlot = i
            break
        end
    end
    
    if not targetSlot then
        print("[TRANSFER] Error: Inventario EVA lleno")
        return false
    end
    
    -- Realizar transferencia
    if player.inventory:transferItemBetweenCompartments('ship', fromSlot, 'eva', targetSlot) then
        print("[TRANSFER] Item transferido de nave a EVA: " .. (item.data.name or "item desconocido"))
        return true
    else
        print("[TRANSFER] Error: Falló la transferencia")
        return false
    end
end

-- Transferir item de EVA a nave
function InventoryUI:transferItemToShip(player, fromSlot)
    if not player or not player.inventory or not player.inventory.getCompartment then
        print("[TRANSFER] Error: No se puede acceder al sistema de inventario")
        return false
    end
    
    local shipComp = player.inventory:getCompartment('ship')
    local evaComp = player.inventory:getCompartment('eva')
    
    if not shipComp or not evaComp then
        print("[TRANSFER] Error: No se pueden encontrar los compartimentos")
        return false
    end
    
    local item = evaComp.items[fromSlot]
    if not item then
        print("[TRANSFER] Error: No hay item en el slot especificado")
        return false
    end
    
    -- Buscar slot vacío en nave
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
    if player.inventory:transferItemBetweenCompartments('eva', fromSlot, 'ship', targetSlot) then
        print("[TRANSFER] Item transferido de EVA a nave: " .. (item.data.name or "item desconocido"))
        return true
    else
        print("[TRANSFER] Error: Falló la transferencia")
        return false
    end
end

-- Transferir arma de slot a inventario
function InventoryUI:transferWeaponToInventory(player, weaponSlot)
    if not player or not player.inventory or not player.inventory.getCompartment then
        print("[TRANSFER] Error: No se puede acceder al sistema de inventario")
        return false
    end
    
    -- No permitir remover arma del slot 1 (arma por defecto)
    if weaponSlot == 1 then
        print("[TRANSFER] Error: No se puede remover el arma por defecto")
        return false
    end
    
    local weaponComp = player.inventory:getCompartment('weapons')
    local shipComp = player.inventory:getCompartment('ship')
    
    if not weaponComp or not shipComp then
        print("[TRANSFER] Error: No se pueden encontrar los compartimentos")
        return false
    end
    
    local weaponItem = weaponComp.items[weaponSlot]
    if not weaponItem then
        print("[TRANSFER] Error: No hay arma en el slot especificado")
        return false
    end
    
    -- Buscar slot libre en inventario
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
    if player.inventory:transferItemBetweenCompartments('weapons', weaponSlot, 'ship', targetSlot) then
        -- Si era el arma actual, cambiar a la siguiente disponible
        if player.weaponSystem and player.weaponSystem.currentSlot == weaponSlot then
            player.weaponSystem:switchToNextAvailableWeapon()
        end
        
        print("[TRANSFER] Arma transferida de slot a inventario: " .. (weaponItem.data.name or "arma desconocida"))
        return true
    else
        print("[TRANSFER] Error: Falló la transferencia")
        return false
    end
end

-- Transferir arma de inventario a slot específico
function InventoryUI:transferInventoryToWeaponSlot(player, invSlot, weaponSlot)
    if not player or not player.inventory or not player.inventory.getCompartment then
        print("[TRANSFER] Error: No se puede acceder al sistema de inventario")
        return false
    end
    
    local shipComp = player.inventory:getCompartment('ship')
    local weaponComp = player.inventory:getCompartment('weapons')
    
    if not shipComp or not weaponComp then
        print("[TRANSFER] Error: No se pueden encontrar los compartimentos")
        return false
    end
    
    local item = shipComp.items[invSlot]
    if not item or not item.data then
        print("[TRANSFER] Error: No hay item en el slot especificado")
        return false
    end
    
    -- Verificar que sea un arma
    if item.data.category ~= "equipable" or item.data.equipType ~= "weapon" then
        print("[TRANSFER] Error: El item no es un arma")
        return false
    end
    
    -- Verificar restricciones del slot 1
    if weaponSlot == 1 and not item.data.isDefault then
        print("[TRANSFER] Error: Solo armas por defecto pueden ir en el slot 1")
        return false
    end
    
    -- Realizar transferencia (si hay arma en destino, se intercambia automáticamente)
    if player.inventory:transferItemBetweenCompartments('ship', invSlot, 'weapons', weaponSlot) then
        print("[TRANSFER] Arma transferida de inventario a slot " .. weaponSlot .. ": " .. (item.data.name or "arma desconocida"))
        return true
    else
        print("[TRANSFER] Error: Falló la transferencia")
        return false
    end
end

-- Dibujar panel de pasivos
function InventoryUI:drawPassivePanel(passiveCompartment, player)
    local layout = uiState.layout
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Fondo del panel
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", layout.passiveX, layout.passiveY, 
                           layout.passiveWidth, layout.passiveHeight)
    
    -- Borde del panel
    love.graphics.setColor(colors.border)
    love.graphics.rectangle("line", layout.passiveX, layout.passiveY, 
                           layout.passiveWidth, layout.passiveHeight)
    
    -- Título
    love.graphics.setColor(colors.text)
    love.graphics.setFont(uiState.font)
    love.graphics.print("Items Pasivos", layout.passiveX + panelPadding, layout.passiveY + 5)
    
    -- Slots de pasivos (6 slots en grid 3x2)
    local startX = layout.passiveX + panelPadding
    local startY = layout.passiveY + 30
    local columns = 3
    
    for i = 1, passiveCompartment.maxSlots do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local x = startX + col * (slotSize + padding)
        local y = startY + row * (slotSize + padding)
        
        self:drawPassiveSlot(x, y, i, passiveCompartment.items[i], player)
    end
end

-- Dibujar slot de pasivos
function InventoryUI:drawPassiveSlot(x, y, slotIndex, item, player)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    
    -- Determinar color del slot
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    -- Verificar si está seleccionado (feedback visual)
    if uiState.selectedPassiveSlot == slotIndex then
        slotColor = colors.slotSelected
    end
    
    -- Verificar si debería mostrar feedback visual para item pasivo seleccionado
    if self:shouldShowPassiveSlotFeedback(slotIndex, player) then
        slotColor = colors.slotDragTarget
    end
    
    -- Verificar hover
    if self:isMouseOverSlot(x, y, slotSize) then
        slotColor = colors.slotHover
    end
    
    -- Verificar si es target válido para drop
    if uiState.draggedItem and self:isValidDropTarget("passives", slotIndex) then
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

-- Transferir item de pasivos a inventario principal
function InventoryUI:transferItemFromPassives(player, fromSlot)
    if not player or not player.inventory or not player.inventory.getCompartment then
        print("[TRANSFER] Error: No se puede acceder al sistema de inventario")
        return false
    end
    
    local shipComp = player.inventory:getCompartment('ship')
    local passiveComp = player.inventory:getCompartment('passives')
    
    if not shipComp or not passiveComp then
        print("[TRANSFER] Error: No se pueden encontrar los compartimentos")
        return false
    end
    
    local item = passiveComp.items[fromSlot]
    if not item then
        print("[TRANSFER] Error: No hay item en el slot especificado")
        return false
    end
    
    -- Buscar slot vacío en inventario principal
    local targetSlot = nil
    for i = 1, shipComp.maxSlots do
        if not shipComp.items[i] then
            targetSlot = i
            break
        end
    end
    
    if not targetSlot then
        print("[TRANSFER] Error: Inventario principal lleno")
        return false
    end
    
    -- Realizar transferencia (los efectos pasivos se manejan automáticamente en inventory_system.lua)
    if player.inventory:transferItemBetweenCompartments('passives', fromSlot, 'ship', targetSlot) then
        print("[TRANSFER] Item pasivo transferido al inventario: " .. (item.data.name or "item desconocido"))
        return true
    else
        print("[TRANSFER] Error: Falló la transferencia")
        return false
    end
end

-- Equipar item pasivo (transferir del inventario común al compartimento de pasivos)
function InventoryUI:equipPassiveItem(slotIndex, slotType, player)
    if not player or not player.inventory or not player.inventory.getCompartment then
        print("[EQUIP PASSIVE] Error: No se puede acceder al sistema de inventario")
        return false
    end
    
    local shipComp = player.inventory:getCompartment('ship')
    local passiveComp = player.inventory:getCompartment('passives')
    
    if not shipComp or not passiveComp then
        print("[EQUIP PASSIVE] Error: No se pueden encontrar los compartimentos")
        return false
    end
    
    local item = nil
    if slotType == "inventory" then
        item = shipComp.items[slotIndex]
    elseif slotType == "eva" then
        local evaComp = player.inventory:getCompartment('eva')
        if evaComp then
            item = evaComp.items[slotIndex]
        end
    end
    
    if not item then
        print("[EQUIP PASSIVE] Error: No hay item en el slot especificado")
        return false
    end
    
    -- Verificar que sea un item pasivo
    if not item.data or item.data.category ~= "passive" then
        print("[EQUIP PASSIVE] Error: El item no es un item pasivo")
        return false
    end
    
    -- Buscar slot vacío en compartimento de pasivos
    local targetSlot = nil
    for i = 1, passiveComp.maxSlots do
        if not passiveComp.items[i] then
            targetSlot = i
            break
        end
    end
    
    if not targetSlot then
        print("[EQUIP PASSIVE] Error: Compartimento de pasivos lleno")
        return false
    end
    
    -- Realizar transferencia (los efectos pasivos se aplican automáticamente en inventory_system.lua)
    local fromCompartment = (slotType == "inventory") and 'ship' or 'eva'
    if player.inventory:transferItemBetweenCompartments(fromCompartment, slotIndex, 'passives', targetSlot) then
        -- Activar feedback visual en el slot de destino
        uiState.selectedPassiveSlot = targetSlot
        uiState.passiveSlotHighlightTimer = 2.0 -- Highlight por 2 segundos
        
        print("[EQUIP PASSIVE] Item pasivo equipado: " .. (item.data.name or "item desconocido"))
        return true
    else
        print("[EQUIP PASSIVE] Error: Falló la transferencia")
        return false
    end
end

return InventoryUI