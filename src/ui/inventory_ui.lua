-- src/ui/inventory_ui.lua
-- UI del inventario con drag and drop y modificación de naves

local InventoryUI = {}
local World = require 'src.core.world'
local InventoryModal = require 'src.ui.inventory.inventory_modal'
local InventoryEquipPanels = require 'src.ui.inventory.inventory_equip_panels'
local PilotPanel = require 'src.ui.inventory.pilot_panel'
local Theme = require 'src.ui.combat_theme'

-- Estado de la UI
local uiState = {
    isOpen = false,
    draggedItem = nil,
    draggedFromSlot = nil,
    draggedFromType = nil, -- "inventory", "eva", "weapons", "passives"
    mouseX = 0,
    mouseY = 0,
    
    -- Tooltip y Hover
    hoveredItem = nil,
    hoveredSlotPos = {x = 0, y = 0},
    hoveredSlotType = nil,
    tooltipWidth = 220,
    
    -- Selección de slots
    selectedPassiveSlot = nil,
    passiveSlotHighlightTimer = 0,
    selectedPassiveItemFromInventory = nil, -- Item pasivo seleccionado del inventario común
    
    -- Modal de opciones (estilo mejorado)
    modal = {
        isOpen = false,
        slotIndex = nil,
        slotType = nil,
        x = 0,
        y = 0,
        width = 160,
        height = 90
    },
    
    -- Configuración visual (Smarter & Smaller)
    slotSize = 40,
    slotPadding = 4,
    panelPadding = 15,
    borderRadius = 6,
    
    -- Colores Premium
    colors = {
        background = {0.05, 0.05, 0.08, 0.96}, -- Deep Space Blue-Black
        panelBackground = {0.1, 0.1, 0.14, 0.92},
        slotEmpty = {0.15, 0.15, 0.2, 0.6},
        slotFilled = {0.2, 0.2, 0.28, 0.8},
        slotHover = {0.3, 0.35, 0.5, 0.9},
        slotSelected = {0.4, 0.6, 0.9, 1},
        slotDragTarget = {0.1, 0.5, 0.2, 0.8},
        border = {0.3, 0.35, 0.45, 1},
        text = {0.95, 0.95, 1, 1},
        textSecondary = {0.6, 0.65, 0.75, 1},
        accent = {0.4, 0.7, 1, 1},
        
        -- Colores por rareza (HSL balanceados)
        rarity = {
            common = {0.7, 0.7, 0.75, 1},
            uncommon = {0.3, 0.85, 0.4, 1},
            rare = {0.3, 0.6, 1, 1},
            epic = {0.8, 0.3, 0.9, 1},
            legendary = {1, 0.65, 0.15, 1}
        }
    },
    
    -- Fuentes
    font = nil,
    smallFont = nil,
    titleFont = nil,
    
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
        
        weaponX = 0,
        weaponY = 0,
        weaponWidth = 0,
        weaponHeight = 0,
        
        passiveX = 0,
        passiveY = 0,
        passiveWidth = 0,
        passiveHeight = 0
    }
}

local function statsButton()
    local layout = uiState.layout
    return layout.inventoryX + layout.inventoryWidth - uiState.panelPadding - 104,
        layout.inventoryY + 5, 104, 20
end

-- Inicializar UI
function InventoryUI:init()
    -- Cargar fuentes
    uiState.font = love.graphics.getFont()
    uiState.smallFont = love.graphics.newFont(12)
    uiState.titleFont = love.graphics.newFont(18)
    
    -- Calcular layout
    self:calculateLayout()
end

-- Calcular layout de la UI
function InventoryUI:calculateLayout(player)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Configuración dinámica del inventario basada en los slots reales
    local maxSlots = 20 -- Default conservador
    if player and player.inventory then
        local shipComp = (player.inventory.getCompartment and player.inventory:getCompartment('ship')) or player.inventory
        maxSlots = shipComp.maxSlots or 20
    end

    local inventoryColumns = 8
    local inventoryRows = math.ceil(maxSlots / inventoryColumns)
    
    uiState.layout.inventoryWidth = inventoryColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.inventoryHeight = inventoryRows * (slotSize + padding) - padding + panelPadding * 2 + 40 -- +40 para título
    
    -- Configuración del panel EVA (3 slots horizontales)
    local evaColumns = 3
    local evaRows = 1
    uiState.layout.evaWidth = evaColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.evaHeight = evaRows * (slotSize + padding) - padding + panelPadding * 2 + 35
    
    -- Configuración del panel de armas (9 slots en grid 3x3 alineado con Pasivos)
    local weaponColumns = 3
    local weaponRows = 3
    uiState.layout.weaponWidth = weaponColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.weaponHeight = weaponRows * (slotSize + padding) - padding + panelPadding * 2 + 35
    
    -- Configuración del panel de pasivos (6 slots en grid 3x2)
    local passiveColumns = 3
    local passiveRows = 2
    uiState.layout.passiveWidth = passiveColumns * (slotSize + padding) - padding + panelPadding * 2
    uiState.layout.passiveHeight = passiveRows * (slotSize + padding) - padding + panelPadding * 2 + 35
    
    -- Posicionamiento: Inventario a la izquierda, equipo a la derecha
    local totalUIWidth = uiState.layout.inventoryWidth + math.max(uiState.layout.evaWidth, uiState.layout.weaponWidth) + panelPadding
    local startX = (screenWidth - totalUIWidth) / 2
    local startY = (screenHeight - uiState.layout.inventoryHeight) / 2
    
    uiState.layout.inventoryX = startX
    uiState.layout.inventoryY = startY
    
    local rightColumnX = startX + uiState.layout.inventoryWidth + panelPadding
    
    uiState.layout.evaX = rightColumnX
    uiState.layout.evaY = startY
    
    uiState.layout.weaponX = rightColumnX
    uiState.layout.weaponY = uiState.layout.evaY + uiState.layout.evaHeight + 10
    
    uiState.layout.passiveX = rightColumnX
    uiState.layout.passiveY = uiState.layout.weaponY + uiState.layout.weaponHeight + 10
end

-- Abrir/cerrar inventario
function InventoryUI:toggle(player)
    if uiState.isOpen then
        self:close()
    else
        uiState.isOpen = true
        -- Forzar recálculo de layout al abrir con los datos del jugador actual
        self:calculateLayout(player)
    end
    local audio = (World.getAudio and World.getAudio()) or World.get('audio')
    if audio and audio.play then
        audio.play("ui_click", { pitch = uiState.isOpen and 1.15 or 0.85, volume = 0.6 })
    end
end

-- Cerrar inventario explícitamente (usado al cambiar de estado)
function InventoryUI:close()
    if not uiState.isOpen then return end
    uiState.isOpen = false
    uiState.showPilotStats = false
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
        return "weapons"
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
    
    -- Resetear hover cada frame
    uiState.hoveredItem = nil
    uiState.hoveredSlotType = nil
    
    -- Solo detectar hover si no estamos arrastrando nada
    if not uiState.draggedItem then
        self:updateHoverDetection(player)
    end
    
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
        self:calculateLayout(player)
        self.lastScreenWidth = screenWidth
        self.lastScreenHeight = screenHeight
    end
end

-- Nueva función para detectar el slot bajo el mouse
function InventoryUI:updateHoverDetection(player)
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- 1. Verificar inventario principal
    local invStartX = layout.inventoryX + panelPadding
    local invStartY = layout.inventoryY + 40
    local invCols = 8
    local shipComp = (player.inventory.getCompartment and player.inventory:getCompartment('ship')) or player.inventory
    
    for i = 1, shipComp.maxSlots do
        local col = (i - 1) % invCols
        local row = math.floor((i - 1) / invCols)
        local x = invStartX + col * (slotSize + padding)
        local y = invStartY + row * (slotSize + padding)
        
        if self:isMouseOverSlot(x, y, slotSize) then
            uiState.hoveredItem = shipComp.items[i]
            uiState.hoveredSlotPos = {x = x, y = y}
            uiState.hoveredSlotType = "inventory"
            return
        end
    end
    
    -- 2. Verificar EVA
    local evaComp = player.inventory:getCompartment('eva')
    if evaComp then
        local evaSlot = self:getEVASlotAt(uiState.mouseX, uiState.mouseY, evaComp)
        if evaSlot then
            uiState.hoveredItem = evaComp.items[evaSlot]
            uiState.hoveredSlotPos = {x = uiState.mouseX, y = uiState.mouseY} -- Posición aproximada para tooltip
            uiState.hoveredSlotType = "eva"
            return
        end
    end
    
    -- 3. Verificar Armas
    local weaponComp = player.inventory:getCompartment('weapons')
    if weaponComp then
        local weaponSlot = self:getWeaponSlotAt(uiState.mouseX, uiState.mouseY, weaponComp)
        if weaponSlot then
            uiState.hoveredItem = weaponComp.items[weaponSlot]
            uiState.hoveredSlotPos = {x = uiState.mouseX, y = uiState.mouseY}
            uiState.hoveredSlotType = "weapons"
            return
        end
    end
    
    -- 4. Verificar Pasivos
    local passiveComp = player.inventory:getCompartment('passives')
    if passiveComp then
        local passiveSlot = self:getPassiveSlotAt(uiState.mouseX, uiState.mouseY, passiveComp)
        if passiveSlot then
            uiState.hoveredItem = passiveComp.items[passiveSlot]
            uiState.hoveredSlotPos = {x = uiState.mouseX, y = uiState.mouseY}
            uiState.hoveredSlotType = "passives"
            return
        end
    end
end

-- Renderizar UI
function InventoryUI:draw(player)
    if not uiState.isOpen or not player or not player.inventory then 
        return 
    end
    uiState.currentPlayer = player
    if uiState.showPilotStats then
        PilotPanel.draw(player)
        return
    end
    
    love.graphics.push()
    
    -- Dibujar panel de inventario
    local shipComp = (player.inventory.getCompartment and player.inventory:getCompartment('ship')) or player.inventory
    self:drawInventoryPanel(shipComp, player)
    
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

    -- Dibujar Tooltip al final (encima de todo)
    if uiState.hoveredItem and uiState.hoveredItem.data then
        self:drawTooltip(uiState.hoveredItem)
    end
    
    love.graphics.pop()
end

-- Función para dibujar el Tooltip Detallado
function InventoryUI:drawTooltip(item)
    if item and item.data then
        return require('src.ui.combat_theme').tooltip(uiState.currentPlayer or World.get('player'), item.data, uiState.mouseX, uiState.mouseY)
    end
end

-- Dibujar panel de inventario
function InventoryUI:drawInventoryPanel(compartment, player)
    local layout = uiState.layout
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Fondo del panel (Glassmorphism)
    love.graphics.setColor(colors.panelBackground)
    love.graphics.rectangle("fill", layout.inventoryX, layout.inventoryY, 
                           layout.inventoryWidth, layout.inventoryHeight, uiState.borderRadius, uiState.borderRadius)
    
    -- Borde sutil
    love.graphics.setColor(colors.border[1], colors.border[2], colors.border[3], 0.4)
    love.graphics.rectangle("line", layout.inventoryX, layout.inventoryY, 
                           layout.inventoryWidth, layout.inventoryHeight, uiState.borderRadius, uiState.borderRadius)
    
    -- Título con fuente más grande
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(uiState.titleFont)
    local shipName = player.shipConfig and player.shipConfig.name or player.inventory.shipType or "Carga"
    local headerX = layout.inventoryX + panelPadding
    love.graphics.print(shipName, headerX, layout.inventoryY + 5)

    if player.stats and player.shipConfig then
        local stats = player.stats
        love.graphics.setFont(uiState.smallFont)
        love.graphics.setColor(colors.textSecondary)
        love.graphics.print(string.format("Casco %d  |  Escudo %d  |  Comb. %d",
            stats.health.maxHealth, stats.shield.maxShield, stats.fuel.maxFuel),
            headerX, layout.inventoryY + 25)
        local x, y, w, h = statsButton()
        local mx, my = uiState.mouseX, uiState.mouseY
        Theme.panel(x, y, w, h, Theme.colors.active, mx >= x and mx < x + w and my >= y and my < y + h)
        love.graphics.setColor(colors.accent)
        love.graphics.printf("Estadísticas", x, y + 2, w, "center")
    end

    -- Slots del inventario (8 columnas)
    local startX = layout.inventoryX + panelPadding
    local startY = layout.inventoryY + 40
    local columns = 8
    
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
    
    -- Fondo (Glassmorphism)
    love.graphics.setColor(colors.panelBackground)
    love.graphics.rectangle("fill", layout.evaX, layout.evaY, 
                           layout.evaWidth, layout.evaHeight, uiState.borderRadius, uiState.borderRadius)
    
    -- Borde sutil
    love.graphics.setColor(colors.border[1], colors.border[2], colors.border[3], 0.4)
    love.graphics.rectangle("line", layout.evaX, layout.evaY, 
                           layout.evaWidth, layout.evaHeight, uiState.borderRadius, uiState.borderRadius)
    
    -- Título
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(uiState.font)
    love.graphics.print("EQUIPO EVA", layout.evaX + panelPadding, layout.evaY + 8)
    
    -- Slots (Horizontales)
    local startX = layout.evaX + panelPadding
    local startY = layout.evaY + 35
    
    for i = 1, evaCompartment.maxSlots do
        local x = startX + (i - 1) * (slotSize + padding)
        local y = startY
        self:drawEVASlot(x, y, i, evaCompartment.items[i])
    end
end

-- Dibujar panel de armas
function InventoryUI:drawWeaponPanel(weaponCompartment)
    return InventoryEquipPanels.drawWeaponPanel(self, uiState, weaponCompartment)
end

-- Dibujar slot de inventario
function InventoryUI:drawInventorySlot(x, y, slotIndex, item)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local borderRadius = uiState.borderRadius
    
    -- Determinar color del slot
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    -- Feedback visual para drag and drop
    if uiState.draggedItem then
        if self:isMouseOverSlot(x, y, slotSize) then
            if self:isValidDropTarget("inventory", slotIndex) then
                slotColor = colors.slotDragTarget
            else
                slotColor = {0.4, 0.1, 0.1, 0.8} -- Rojo para indicar que no es válido
            end
        elseif self:isValidDropTarget("inventory", slotIndex) then
            -- Resaltado suave para todos los slots válidos
            slotColor = {colors.slotDragTarget[1], colors.slotDragTarget[2], colors.slotDragTarget[3], 0.3}
        end
    elseif self:isMouseOverSlot(x, y, slotSize) then
        slotColor = colors.slotHover
    end
    
    -- Dibujar slot redondeado
    love.graphics.setColor(slotColor)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize, borderRadius, borderRadius)
    
    love.graphics.setColor(colors.border[1], colors.border[2], colors.border[3], 0.2)
    love.graphics.rectangle("line", x, y, slotSize, slotSize, borderRadius, borderRadius)
    
    -- Dibujar item si existe
    if item then
        self:drawItem(x + 4, y + 4, slotSize - 8, item)
    end
end

-- Dibujar slot EVA
function InventoryUI:drawEVASlot(x, y, slotIndex, item)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local borderRadius = uiState.borderRadius
    
    -- Determinar color del slot
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    -- Feedback visual para drag and drop
    if uiState.draggedItem then
        if self:isMouseOverSlot(x, y, slotSize) then
            if self:isValidDropTarget("eva", slotIndex) then
                slotColor = colors.slotDragTarget
            else
                slotColor = {0.4, 0.1, 0.1, 0.8} -- Rojo
            end
        elseif self:isValidDropTarget("eva", slotIndex) then
            slotColor = {colors.slotDragTarget[1], colors.slotDragTarget[2], colors.slotDragTarget[3], 0.3}
        end
    elseif self:isMouseOverSlot(x, y, slotSize) then
        slotColor = colors.slotHover
    end
    
    -- Dibujar slot
    love.graphics.setColor(slotColor)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize, borderRadius, borderRadius)
    
    love.graphics.setColor(colors.border[1], colors.border[2], colors.border[3], 0.2)
    love.graphics.rectangle("line", x, y, slotSize, slotSize, borderRadius, borderRadius)
    
    -- Dibujar item si existe
    if item then
        self:drawItem(x + 4, y + 4, slotSize - 8, item)
    end
end

-- Dibujar slot de arma
function InventoryUI:drawWeaponSlot(x, y, slotIndex, item)
    return InventoryEquipPanels.drawWeaponSlot(self, uiState, x, y, slotIndex, item)
end

-- Dibujar item
function InventoryUI:drawItem(x, y, size, item)
    local colors = uiState.colors
    if not item or not item.data then return end
    
    local rColor = self:getItemRarityColor(item)
    
    -- Fondo con brillo sutil de rareza
    love.graphics.setColor(rColor[1], rColor[2], rColor[3], 0.2)
    love.graphics.rectangle("fill", x, y, size, size, 4, 4)
    
    -- Icono (Placeholder mejorado)
    love.graphics.setColor(rColor)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x + 4, y + 4, size - 8, size - 8, 2, 2)
    
    -- Letra distintiva (segura para UTF-8 multibyte como ñ, á, ★)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(uiState.font)
    local itemName = tostring(item.data.name or "?"):gsub("^★%s*", "")
    local utf8 = require("utf8")
    local ok, nextByte = pcall(utf8.offset, itemName, 2)
    local firstChar = (ok and nextByte) and string.sub(itemName, 1, nextByte - 1) or string.sub(itemName, 1, 1)
    if #firstChar == 1 then
        firstChar = firstChar:upper()
    end
    local badgeText = firstChar
    local tw = uiState.font:getWidth(badgeText)
    local th = uiState.font:getHeight()
    love.graphics.print(badgeText, x + (size - tw)/2, y + (size - th)/2)
    
    if item.data.isEvolved then
        love.graphics.setColor(.78,.53,1)
        require('src.ui.combat_theme').star(x+size-7,y+7,5)
    end
    local status = require('src.ui.combat_presentation').item(uiState.currentPlayer or World.get('player'), item.data)
    local label, tint
    if #status.amplifications > 0 then
        label, tint = '+' .. #status.amplifications, {.25,.87,1}
    else
        for _, recipe in ipairs(status.recipes) do
            if recipe.available then label, tint = 'REC', {1,.73,.26}; break end
        end
    end
    if label then
        love.graphics.setFont(uiState.smallFont)
        love.graphics.setColor(tint)
        love.graphics.print(label, x + 3, y + 2)
    end
    -- Cantidad
    if item.quantity and item.quantity > 1 then
        love.graphics.setFont(uiState.smallFont)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print("x"..item.quantity, x + size - 18, y + size - 14)
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
    return InventoryModal.draw(uiState)
end

-- Verificar si el mouse está sobre un slot
function InventoryUI:isMouseOverSlot(x, y, size)
    return uiState.mouseX >= x and uiState.mouseX <= x + size and
           uiState.mouseY >= y and uiState.mouseY <= y + size
end

-- Verificar si es un target válido para drop
function InventoryUI:isValidDropTarget(targetType, targetSlot)
    if not uiState.draggedItem or not uiState.draggedItem.data then return false end
    
    local itemData = uiState.draggedItem.data
    
    if targetType == "inventory" then
        return true -- Siempre se puede mover a inventario
    elseif targetType == "eva" then
        return true -- Siempre se puede mover a EVA (las restricciones se manejan en la transferencia)
    elseif targetType == "weapons" then
        -- Solo armas pueden ir al panel de armas
        if itemData.category == "equipable" and itemData.equipType == "weapon" then
            -- Restricción del slot 1 (solo armas por defecto)
            if targetSlot == 1 then
                return itemData.isDefault == true
            end
            return true
        end
    elseif targetType == "passives" then
        -- Solo items con categoría PASSIVE pueden ir a pasivos
        return itemData.category == "passive"
    end
    
    return false
end

-- Verificar si un slot pasivo debería mostrar feedback visual
function InventoryUI:shouldShowPassiveSlotFeedback(slotIndex, player)
    return InventoryEquipPanels.shouldShowPassiveSlotFeedback(uiState, slotIndex, player)
end

-- Manejar click del mouse
function InventoryUI:mousepressed(x, y, button, player)
    if not uiState.isOpen or not player or not player.inventory then return end
    if uiState.showPilotStats then
        if button == 1 and PilotPanel.isBackButton(x, y) then
            uiState.showPilotStats = false
        end
        return
    end
    
    -- Si hay modal abierto, verificar clics en él
    if uiState.modal.isOpen then
        self:handleModalClick(x, y, button, player)
        return
    end
    
    -- Solo manejar drag con clic izquierdo
    if button == 1 then
        local bx, by, bw, bh = statsButton()
        if player.stats and player.shipConfig and not uiState.draggedItem
            and x >= bx and x < bx + bw and y >= by and y < by + bh then
            uiState.showPilotStats = true
            return
        end
        -- Verificar click en inventario (compartimento 'ship')
        local shipComp = (player.inventory.getCompartment and player.inventory:getCompartment('ship')) or player.inventory
        local inventorySlot = self:getInventorySlotAt(x, y, shipComp)
        
        if inventorySlot then
            local item = shipComp.items[inventorySlot]
            if item then
                -- Si se presiona Shift, transferencia inteligente
                if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
                    local data = item.data
                    if data then
                        -- 1. Si es Arma, intentar equipar
                        if data.category == "equipable" and data.equipType == "weapon" then
                            if self:transferInventoryToWeaponSlot(player, inventorySlot, nil) then return end
                        end
                        -- 2. Si es Pasivo, intentar equipar
                        if data.category == "passive" then
                            if self:equipPassiveItem(inventorySlot, "inventory", player) then return end
                        end
                    end
                    -- Fallback: Transferir al compartimento EVA si es posible
                    self:transferItemToEVA(player, inventorySlot)
                    return
                end
                
                -- Iniciar drag
                uiState.draggedItem = item
                uiState.draggedFromSlot = inventorySlot
                uiState.draggedFromType = "inventory"
            end
            return
        end
        
        -- Verificar click en panel EVA
        local evaComp = player.inventory:getCompartment('eva')
        if evaComp then
            local evaSlot = self:getEVASlotAt(x, y, evaComp)
            if evaSlot then
                local item = evaComp.items[evaSlot]
                if item then
                    if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
                        self:transferItemToShip(player, evaSlot)
                        return
                    end
                    uiState.draggedItem = item
                    uiState.draggedFromSlot = evaSlot
                    uiState.draggedFromType = "eva"
                end
                return
            end
        end
        
        -- Verificar click en panel de armas
        local weaponComp = player.inventory:getCompartment('weapons')
        if weaponComp then
            local weaponSlot = self:getWeaponSlotAt(x, y, weaponComp)
            if weaponSlot then
                local item = weaponComp.items[weaponSlot]
                if item then
                    if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
                        self:transferWeaponToInventory(player, weaponSlot)
                        return
                    end
                    -- No permitir arrastrar arma por defecto
                    if weaponSlot == 1 then return end
                    
                    uiState.draggedItem = item
                    uiState.draggedFromSlot = weaponSlot
                    uiState.draggedFromType = "weapons"
                end
                return
            end
        end
        
        -- Verificar click en panel de pasivos
        local passiveComp = (player.inventory.getCompartment and player.inventory:getCompartment('passives')) or nil
        if passiveComp then
            local passiveSlot = self:getPassiveSlotAt(x, y, passiveComp)
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
            local evaSlot = self:getEVASlotAt(x, y, evaComp)
            if evaSlot and evaComp.items[evaSlot] then
                self:openModal(x, y, evaSlot, "eva")
                return
            end
        end
        
        -- Verificar clic derecho en panel de armas
        local weaponComp = (player.inventory.getCompartment and player.inventory:getCompartment('weapons')) or nil
        if weaponComp then
            local weaponSlot = self:getWeaponSlotAt(x, y, weaponComp)
            if weaponSlot and weaponComp.items[weaponSlot] then
                self:openModal(x, y, weaponSlot, "weapons")
                return
            end
        end
        
        -- Verificar clic derecho en panel de pasivos
        local passiveComp = (player.inventory.getCompartment and player.inventory:getCompartment('passives')) or nil
        if passiveComp then
            local passiveSlot = self:getPassiveSlotAt(x, y, passiveComp)
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
        local evaSlot = self:getEVASlotAt(x, y, evaComp)
        if evaSlot then
            dropped = self:handleDrop(player, "eva", evaSlot)
        end
    end
    
    -- Verificar drop en panel de armas
    if not dropped and weaponComp then
        local weaponSlot = self:getWeaponSlotAt(x, y, weaponComp)
        if weaponSlot then
            -- Solo permitir drop de armas (la validación se hace en handleDrop -> isValidDropTarget)
            dropped = self:handleDrop(player, "weapons", weaponSlot)
        end
    end
    
    -- Verificar drop en panel de pasivos
    if not dropped and passiveComp then
        local passiveSlot = self:getPassiveSlotAt(x, y, passiveComp)
        if passiveSlot then
            -- Solo permitir drop de items pasivos (la validación se hace en handleDrop -> isValidDropTarget)
            dropped = self:handleDrop(player, "passives", passiveSlot)
        end
    end
    
    -- Si no se pudo hacer drop en el inventario, verificar drop al mundo
    if not dropped then
        -- Verificar si el mouse está fuera de todos los paneles usando los márgenes actuales
        local layout = uiState.layout
        local isOutsidePanel = true

        -- 1. Dentro de Inventario?
        if x >= layout.inventoryX and x <= layout.inventoryX + layout.inventoryWidth and
           y >= layout.inventoryY and y <= layout.inventoryY + layout.inventoryHeight then
            isOutsidePanel = false
        end

        -- 2. Dentro de EVA?
        if isOutsidePanel and evaComp then
            if x >= layout.evaX and x <= layout.evaX + layout.evaWidth and
               y >= layout.evaY and y <= layout.evaY + layout.evaHeight then
                isOutsidePanel = false
            end
        end

        -- 3. Dentro de Armas?
        if isOutsidePanel and weaponComp then
            if x >= layout.weaponX and x <= layout.weaponX + layout.weaponWidth and
               y >= layout.weaponY and y <= layout.weaponY + layout.weaponHeight then
                isOutsidePanel = false
            end
        end

        -- 4. Dentro de Pasivos?
        if isOutsidePanel and passiveComp then
            if x >= layout.passiveX and x <= layout.passiveX + layout.passiveWidth and
               y >= layout.passiveY and y <= layout.passiveY + layout.passiveHeight then
                isOutsidePanel = false
            end
        end
        
        if isOutsidePanel then
            self:dropItemToWorld(uiState.draggedItem, player, x, y)
            dropped = true
        else
            -- Devolver item a su lugar original directamente para evitar doble anidación
            local fromCompartmentName = self:getCompartmentName(uiState.draggedFromType)
            local comp = player.inventory:getCompartment(fromCompartmentName)
            if comp and uiState.draggedFromSlot then
                comp.items[uiState.draggedFromSlot] = uiState.draggedItem
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
    return InventoryModal.open(uiState, x, y, slotIndex, slotType)
end

-- Manejar clics en el modal
function InventoryUI:handleModalClick(x, y, button, player)
    return InventoryModal.handleClick(self, uiState, x, y, button, player)
end

-- Usar/equipar item
function InventoryUI:useItem(slotIndex, slotType, player)
    return InventoryModal.useItem(self, slotIndex, slotType, player)
end

-- Eliminar item
function InventoryUI:deleteItem(slotIndex, slotType, player)
    return InventoryModal.deleteItem(self, slotIndex, slotType, player)
end

-- Lanzar item al mundo desde modal
function InventoryUI:dropItemFromModal(slotIndex, slotType, player)
    if player and player.lootLabActive then return end
    return InventoryModal.dropItemFromModal(self, slotIndex, slotType, player)
end

-- Obtener slot de inventario en posición
function InventoryUI:getInventorySlotAt(x, y, inventory)
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    local startX = layout.inventoryX + panelPadding
    local startY = layout.inventoryY + 40 -- Consistente con drawInventoryPanel
    local columns = 8 -- Nuevo layout de 8 columnas
    
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
function InventoryUI:getEVASlotAt(x, y, evaComp)
    if not evaComp then return nil end
    
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    local startX = layout.evaX + panelPadding
    local startY = layout.evaY + 35 -- Consistente con drawEVAPanel
    
    for i = 1, evaComp.maxSlots do
        local slotX = startX + (i - 1) * (slotSize + padding)
        local slotY = startY
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            return i
        end
    end
    return nil
end

-- Obtener slot de arma en posición
function InventoryUI:getWeaponSlotAt(x, y, weaponComp)
    return InventoryEquipPanels.getWeaponSlotAt(uiState, x, y, weaponComp)
end

-- Obtener slot de pasivos en coordenadas específicas
function InventoryUI:getPassiveSlotAt(x, y, passiveComp)
    return InventoryEquipPanels.getPassiveSlotAt(uiState, x, y, passiveComp)
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
    player.inventory.items = shipComp.items
    
    -- Items de ejemplo - Armas y Pasivas del Catálogo Fase 3 para testear Sinergias (Reglas 1, 2 y 3)
    local testItems = {
        -- Armas listas para probar arquetipos y fusiones Regla 1
        "plasma_rifle",
        "energy_shotgun",
        "gauss_railgun",
        "phase_beam_lance",
        "arc_tesla_emitter",
        "swarm_micro_missiles",
        "ricochet_shard_gun",
        "industrial_rip_saw",
        "heavy_torpedo_launcher",
        "gravitic_wave_projector",
        "magma_slag_thrower",
        "cryo_shard_blaster",
        -- Pasivas listas para probar Regla 2 (Pasiva+Pasiva) y Regla 3 (Arma+Pasiva)
        "voltaic_coil",
        "prism_split_lens",
        "tungsten_sabot",
        "neural_homing_chip",
        "autoloader_magazine"
    }
    
    local autoEquipList = {
        "gauss_railgun",
        "swarm_micro_missiles",
        "ricochet_shard_gun",
        "heavy_torpedo_launcher"
    }
    for idx, wid in ipairs(autoEquipList) do
        local wData = ItemSystem.getItem(wid)
        if wData and player and player.weaponSystem and not player.inventory:getWeaponInSlot(idx + 1) then
            local equipCopy = {}
            for k, v in pairs(wData) do equipCopy[k] = v end
            player.weaponSystem:equipWeapon(equipCopy, idx + 1)
        end
    end

    local slotIndex = 1
    for _, itemId in ipairs(testItems) do
        if slotIndex <= (shipComp.maxSlots or 20) then
            local itemData = ItemSystem.getItem(itemId)
            if itemData then
                local fullData = {}
                for k, v in pairs(itemData) do
                    fullData[k] = v
                end
                fullData.id = itemId
                shipComp.items[slotIndex] = {
                    data = fullData,
                    quantity = itemData.category == "material" and 5 or 1
                }
                slotIndex = slotIndex + 1
            else
                print("[WARNING] Item no encontrado: " .. itemId)
            end
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
    if player and player.lootLabActive then return end
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
    return InventoryEquipPanels.transferWeaponToInventory(player, weaponSlot)
end

-- Transferir arma de inventario a slot específico
function InventoryUI:transferInventoryToWeaponSlot(player, invSlot, weaponSlot)
    return InventoryEquipPanels.transferInventoryToWeaponSlot(player, invSlot, weaponSlot)
end

-- Dibujar panel de pasivos
function InventoryUI:drawPassivePanel(passiveCompartment, player)
    return InventoryEquipPanels.drawPassivePanel(self, uiState, passiveCompartment, player)
end

-- Dibujar slot de pasivos
function InventoryUI:drawPassiveSlot(x, y, slotIndex, item, player)
    return InventoryEquipPanels.drawPassiveSlot(self, uiState, x, y, slotIndex, item, player)
end

-- Transferir item de pasivos a inventario principal
function InventoryUI:transferItemFromPassives(player, fromSlot)
    return InventoryEquipPanels.transferItemFromPassives(player, fromSlot)
end

-- Equipar item pasivo
function InventoryUI:equipPassiveItem(slotIndex, slotType, player)
    return InventoryEquipPanels.equipPassiveItem(uiState, slotIndex, slotType, player)
end

return InventoryUI
