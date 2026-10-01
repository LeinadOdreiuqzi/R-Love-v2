-- src/ui/inventory/inventory_equip_panels.lua
-- Submódulo para gestión y renderizado de paneles de equipamiento (Armas y Pasivos)
-- Desacoplado de src/ui/inventory_ui.lua para modularidad limpia

local InventoryEquipPanels = {}
local World = require 'src.core.world'

local function getAudio()
    return (World.getAudio and World.getAudio()) or World.get('audio')
end

--[[
    Dibujar panel de armas
--]]
function InventoryEquipPanels.drawWeaponPanel(parentUI, uiState, weaponCompartment)
    local layout = uiState.layout
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Fondo (Glassmorphism)
    love.graphics.setColor(colors.panelBackground)
    love.graphics.rectangle("fill", layout.weaponX, layout.weaponY, 
                           layout.weaponWidth, layout.weaponHeight, uiState.borderRadius, uiState.borderRadius)
    
    love.graphics.setColor(colors.border[1], colors.border[2], colors.border[3], 0.4)
    love.graphics.rectangle("line", layout.weaponX, layout.weaponY, 
                           layout.weaponWidth, layout.weaponHeight, uiState.borderRadius, uiState.borderRadius)
    
    -- Título
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(uiState.font)
    love.graphics.print("ARMAS", layout.weaponX + panelPadding, layout.weaponY + 8)
    
    -- Slots (Horizontales)
    local startX = layout.weaponX + panelPadding
    local startY = layout.weaponY + 35
    
    for i = 1, weaponCompartment.maxSlots do
        local x = startX + (i - 1) * (slotSize + padding)
        local y = startY
        InventoryEquipPanels.drawWeaponSlot(parentUI, uiState, x, y, i, weaponCompartment.items[i])
    end
end

--[[
    Dibujar slot de arma
--]]
function InventoryEquipPanels.drawWeaponSlot(parentUI, uiState, x, y, slotIndex, item)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local borderRadius = uiState.borderRadius
    
    -- Determinar color del slot
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    -- Slot 1 tiene color especial (arma por defecto)
    if slotIndex == 1 then
        slotColor = {0.2, 0.15, 0.1, 0.7}
    end
    
    -- Feedback visual para drag and drop
    if uiState.draggedItem then
        if parentUI:isMouseOverSlot(x, y, slotSize) then
            if parentUI:isValidDropTarget("weapons", slotIndex) then
                slotColor = colors.slotDragTarget
            else
                slotColor = {0.4, 0.1, 0.1, 0.8}
            end
        elseif parentUI:isValidDropTarget("weapons", slotIndex) then
            slotColor = {colors.slotDragTarget[1], colors.slotDragTarget[2], colors.slotDragTarget[3], 0.3}
        end
    elseif parentUI:isMouseOverSlot(x, y, slotSize) then
        slotColor = colors.slotHover
    end
    
    -- Dibujar slot
    love.graphics.setColor(slotColor)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize, borderRadius, borderRadius)
    
    love.graphics.setColor(colors.border[1], colors.border[2], colors.border[3], 0.2)
    love.graphics.rectangle("line", x, y, slotSize, slotSize, borderRadius, borderRadius)
    
    -- Indicador de slot número
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setFont(uiState.smallFont)
    love.graphics.print(tostring(slotIndex), x + 4, y + 2)
    
    -- Dibujar item si existe
    if item then
        parentUI:drawItem(x + 4, y + 4, slotSize - 8, item)
    end
end

--[[
    Obtener slot de arma en coordenadas de pantalla
--]]
function InventoryEquipPanels.getWeaponSlotAt(uiState, x, y, weaponComp)
    if not weaponComp then return nil end
    
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    local startX = layout.weaponX + panelPadding
    local startY = layout.weaponY + 35
    
    for i = 1, weaponComp.maxSlots do
        local slotX = startX + (i - 1) * (slotSize + padding)
        local slotY = startY
        if x >= slotX and x <= slotX + slotSize and y >= slotY and y <= slotY + slotSize then
            return i
        end
    end
    return nil
end

--[[
    Transferir arma de slot a inventario
--]]
function InventoryEquipPanels.transferWeaponToInventory(player, weaponSlot)
    if not player or not player.inventory or not player.inventory.getCompartment then
        print("[TRANSFER] Error: No se puede acceder al sistema de inventario")
        return false
    end
    
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
    
    if player.inventory:transferItemBetweenCompartments('weapons', weaponSlot, 'ship', targetSlot) then
        if player.weaponSystem and player.weaponSystem.currentSlot == weaponSlot then
            player.weaponSystem:switchToNextAvailableWeapon()
        end
        
        local audio = getAudio()
        if audio and audio.play then
            audio.play("item_equip", { pitch = 0.9, volume = 0.65 })
        end
        print("[TRANSFER] Arma transferida de slot a inventario: " .. (weaponItem.data.name or "arma desconocida"))
        return true
    else
        print("[TRANSFER] Error: Falló la transferencia")
        return false
    end
end

--[[
    Transferir arma de inventario a slot específico
--]]
function InventoryEquipPanels.transferInventoryToWeaponSlot(player, invSlot, weaponSlot)
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
    
    if item.data.category ~= "equipable" or item.data.equipType ~= "weapon" then
        print("[TRANSFER] Error: El item no es un arma")
        return false
    end
    
    if not weaponSlot then
        for i = 1, weaponComp.maxSlots do
            if i == 1 and not item.data.isDefault then
                -- skip default weapon slot
            elseif not weaponComp.items[i] then
                weaponSlot = i
                break
            end
        end
        
        if not weaponSlot then
            weaponSlot = 2
        end
    end
    
    if weaponSlot == 1 and not item.data.isDefault then
        print("[TRANSFER] Error: Solo armas por defecto pueden ir en el slot 1")
        return false
    end
    
    if player.inventory:transferItemBetweenCompartments('ship', invSlot, 'weapons', weaponSlot) then
        local audio = getAudio()
        if audio and audio.play then
            audio.play("item_equip", { pitch = 1.05, volume = 0.7 })
        end
        print("[TRANSFER] Arma transferida de inventario a slot " .. weaponSlot .. ": " .. (item.data.name or "arma desconocida"))
        return true
    else
        print("[TRANSFER] Error: Falló la transferencia")
        return false
    end
end

--[[
    Dibujar panel de pasivos
--]]
function InventoryEquipPanels.drawPassivePanel(parentUI, uiState, passiveCompartment, player)
    local layout = uiState.layout
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    -- Fondo
    love.graphics.setColor(colors.panelBackground)
    love.graphics.rectangle("fill", layout.passiveX, layout.passiveY, 
                           layout.passiveWidth, layout.passiveHeight, uiState.borderRadius, uiState.borderRadius)
    
    love.graphics.setColor(colors.border[1], colors.border[2], colors.border[3], 0.4)
    love.graphics.rectangle("line", layout.passiveX, layout.passiveY, 
                           layout.passiveWidth, layout.passiveHeight, uiState.borderRadius, uiState.borderRadius)
    
    -- Título
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(uiState.font)
    love.graphics.print("PASIVOS", layout.passiveX + panelPadding, layout.passiveY + 8)
    
    -- Slots (3x2 grid)
    local startX = layout.passiveX + panelPadding
    local startY = layout.passiveY + 35
    local columns = 3
    
    for i = 1, passiveCompartment.maxSlots do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local x = startX + col * (slotSize + padding)
        local y = startY + row * (slotSize + padding)
        InventoryEquipPanels.drawPassiveSlot(parentUI, uiState, x, y, i, passiveCompartment.items[i], player)
    end
end

--[[
    Dibujar slot de pasivo
--]]
function InventoryEquipPanels.drawPassiveSlot(parentUI, uiState, x, y, slotIndex, item, player)
    local colors = uiState.colors
    local slotSize = uiState.slotSize
    local borderRadius = uiState.borderRadius
    
    local slotColor = colors.slotEmpty
    if item then
        slotColor = colors.slotFilled
    end
    
    if uiState.selectedPassiveSlot == slotIndex then
        slotColor = colors.slotSelected
    end
    
    if uiState.draggedItem then
        if parentUI:isMouseOverSlot(x, y, slotSize) then
            if parentUI:isValidDropTarget("passives", slotIndex) then
                slotColor = colors.slotDragTarget
            else
                slotColor = {0.4, 0.1, 0.1, 0.8}
            end
        elseif parentUI:isValidDropTarget("passives", slotIndex) then
            slotColor = {colors.slotDragTarget[1], colors.slotDragTarget[2], colors.slotDragTarget[3], 0.3}
        end
    elseif parentUI:isMouseOverSlot(x, y, slotSize) then
        slotColor = colors.slotHover
    end
    
    love.graphics.setColor(slotColor)
    love.graphics.rectangle("fill", x, y, slotSize, slotSize, borderRadius, borderRadius)
    
    love.graphics.setColor(colors.border[1], colors.border[2], colors.border[3], 0.2)
    love.graphics.rectangle("line", x, y, slotSize, slotSize, borderRadius, borderRadius)
    
    if item then
        parentUI:drawItem(x + 4, y + 4, slotSize - 8, item)
    end
end

--[[
    Obtener slot de pasivo en coordenadas de pantalla
--]]
function InventoryEquipPanels.getPassiveSlotAt(uiState, x, y, passiveComp)
    if not passiveComp then return nil end
    
    local layout = uiState.layout
    local slotSize = uiState.slotSize
    local padding = uiState.slotPadding
    local panelPadding = uiState.panelPadding
    
    local startX = layout.passiveX + panelPadding
    local startY = layout.passiveY + 35
    local columns = 3
    
    for i = 1, passiveComp.maxSlots do
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

--[[
    Verificar si un slot pasivo debería mostrar feedback visual
--]]
function InventoryEquipPanels.shouldShowPassiveSlotFeedback(uiState, slotIndex, player)
    if uiState.selectedPassiveItemFromInventory then
        local passiveComp = player.inventory and player.inventory:getCompartment('passives')
        if passiveComp and not passiveComp.items[slotIndex] then
            return true
        end
    end
    return false
end

--[[
    Transferir item de pasivos a inventario principal
--]]
function InventoryEquipPanels.transferItemFromPassives(player, fromSlot)
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
    
    if player.inventory:transferItemBetweenCompartments('passives', fromSlot, 'ship', targetSlot) then
        local audio = getAudio()
        if audio and audio.play then
            audio.play("item_equip", { pitch = 0.9, volume = 0.65 })
        end
        print("[TRANSFER] Item pasivo transferido al inventario: " .. (item.data.name or "item desconocido"))
        return true
    else
        print("[TRANSFER] Error: Falló la transferencia")
        return false
    end
end

--[[
    Equipar item pasivo (transferir del inventario común al compartimento de pasivos)
--]]
function InventoryEquipPanels.equipPassiveItem(uiState, slotIndex, slotType, player)
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
    
    if not item.data or item.data.category ~= "passive" then
        print("[EQUIP PASSIVE] Error: El item no es un item pasivo")
        return false
    end
    
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
    
    local fromCompartment = (slotType == "inventory") and 'ship' or 'eva'
    if player.inventory:transferItemBetweenCompartments(fromCompartment, slotIndex, 'passives', targetSlot) then
        uiState.selectedPassiveSlot = targetSlot
        uiState.passiveSlotHighlightTimer = 2.0
        
        local audio = getAudio()
        if audio and audio.play then
            audio.play("item_equip", { pitch = 1.15, volume = 0.75 })
        end
        print("[EQUIP PASSIVE] Item pasivo equipado: " .. (item.data.name or "item desconocido"))
        return true
    else
        print("[EQUIP PASSIVE] Error: Falló la transferencia")
        return false
    end
end

return InventoryEquipPanels
