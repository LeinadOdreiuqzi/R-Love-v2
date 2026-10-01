-- src/ui/inventory/inventory_modal.lua
-- Submódulo para gestión y renderizado del menú contextual / modal de opciones en inventario
-- Desacoplado de src/ui/inventory_ui.lua para modularidad limpia

local InventoryModal = {}
local World = require 'src.core.world'

local function getAudio()
    return (World.getAudio and World.getAudio()) or World.get('audio')
end

--[[
    Abre el modal contextual en las coordenadas dadas
--]]
function InventoryModal.open(uiState, x, y, slotIndex, slotType)
    uiState.modal.isOpen = true
    uiState.modal.slotIndex = slotIndex
    uiState.modal.slotType = slotType
    uiState.modal.x = x
    uiState.modal.y = y
    
    local audio = getAudio()
    if audio and audio.play then
        audio.play("ui_click", { pitch = 1.15, volume = 0.6 })
    end
end

--[[
    Dibuja el modal contextual con opciones según el tipo de slot
--]]
function InventoryModal.draw(uiState)
    local modal = uiState.modal
    if not modal.isOpen then return end
    
    local colors = uiState.colors
    local br = uiState.borderRadius
    
    -- Fondo con sombra/glow sutil
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", modal.x + 4, modal.y + 4, modal.width, modal.height, br, br)
    
    love.graphics.setColor(colors.panelBackground)
    love.graphics.rectangle("fill", modal.x, modal.y, modal.width, modal.height, br, br)
    
    -- Borde de acento
    love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", modal.x, modal.y, modal.width, modal.height, br, br)
    
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
            love.graphics.setColor(0.7, 0.7, 0.7)
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

--[[
    Maneja clics dentro del modal contextual
--]]
function InventoryModal.handleClick(parentUI, uiState, x, y, button, player)
    if button ~= 1 then return end
    
    local modal = uiState.modal
    
    if x >= modal.x and x <= modal.x + modal.width and y >= modal.y and y <= modal.y + modal.height then
        local audio = getAudio()
        if audio and audio.play then
            audio.play("ui_click", { pitch = 1.0, volume = 0.55 })
        end
        
        if modal.slotType == "weapons" then
            local isDefaultWeapon = (modal.slotIndex == 1)
            if isDefaultWeapon then
                modal.isOpen = false
                return
            end
            
            local optionHeight = modal.height / 2
            if y <= modal.y + optionHeight then
                parentUI:transferWeaponToInventory(player, modal.slotIndex)
            else
                InventoryModal.deleteItem(parentUI, modal.slotIndex, modal.slotType, player)
            end
        elseif modal.slotType == "passives" then
            local optionHeight = modal.height / 2
            if y <= modal.y + optionHeight then
                InventoryModal.dropItemFromModal(parentUI, modal.slotIndex, modal.slotType, player)
            else
                InventoryModal.deleteItem(parentUI, modal.slotIndex, modal.slotType, player)
            end
        else
            local optionHeight = modal.height / 3
            if y <= modal.y + optionHeight then
                InventoryModal.useItem(parentUI, modal.slotIndex, modal.slotType, player)
            elseif y <= modal.y + optionHeight * 2 then
                InventoryModal.dropItemFromModal(parentUI, modal.slotIndex, modal.slotType, player)
            else
                InventoryModal.deleteItem(parentUI, modal.slotIndex, modal.slotType, player)
            end
        end
    end
    
    modal.isOpen = false
end

--[[
    Usa o equipa un item según su categoría
--]]
function InventoryModal.useItem(parentUI, slotIndex, slotType, player)
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
                    local compName = parentUI:getCompartmentName(slotType)
                    if compName and player.inventory and player.inventory.removeItemFromCompartment then
                        player.inventory:removeItemFromCompartment(compName, slotIndex)
                    else
                        if slotType == "inventory" then shipComp.items[slotIndex] = nil
                        elseif slotType == "eva" then
                            local evaComp = player.inventory:getCompartment('eva')
                            if evaComp then evaComp.items[slotIndex] = nil end
                        end
                    end
                    local audio = getAudio()
                    if audio and audio.play then
                        audio.play("item_equip", { pitch = 1.3, volume = 0.7 })
                    end
                    print("Usado: " .. itemData.name)
                else
                    print("No se pudo usar: " .. itemData.name)
                end
            elseif itemData.category == "equipable" then
                if itemData.equipType == "weapon" and player.weaponSystem then
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
                            if slotType == "inventory" then
                                shipComp.items[slotIndex] = nil
                            elseif slotType == "eva" then
                                local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
                                if evaComp then
                                    evaComp.items[slotIndex] = nil
                                end
                            end
                            local audio = getAudio()
                            if audio and audio.play then
                                audio.play("item_equip", { pitch = 1.0, volume = 0.75 })
                            end
                            print("Arma equipada: " .. itemData.name .. " en slot " .. weaponSlot)
                        else
                            print("No se pudo equipar arma: " .. itemData.name)
                        end
                    else
                        print("No hay slots de arma disponibles")
                    end
                else
                    local success = ItemSystem:equipItem(itemData, player)
                    if success then
                        if slotType == "inventory" then
                            shipComp.items[slotIndex] = nil
                        elseif slotType == "eva" then
                            local evaComp = (player.inventory.getCompartment and player.inventory:getCompartment('eva')) or nil
                            if evaComp then
                                evaComp.items[slotIndex] = nil
                            end
                        end
                        local audio = getAudio()
                        if audio and audio.play then
                            audio.play("item_equip", { pitch = 1.0, volume = 0.75 })
                        end
                        print("Equipado: " .. itemData.name)
                    else
                        print("No se pudo equipar: " .. itemData.name)
                    end
                end
            elseif itemData.category == "passive" then
                parentUI:equipPassiveItem(slotIndex, slotType, player)
            else
                print("Item: " .. itemData.name .. " (" .. itemData.category .. ")")
            end
        else
            print("Usando item: " .. (item.data.name or "Unknown"))
        end
    end
end

--[[
    Elimina un item del inventario o slot
--]]
function InventoryModal.deleteItem(parentUI, slotIndex, slotType, player)
    if not player or not player.inventory then return end
    
    if slotType == "weapons" and slotIndex == 1 then
        print("[DELETE] Error: No se puede eliminar el arma por defecto")
        return
    end

    local compName = parentUI:getCompartmentName(slotType)
    if compName and player.inventory.removeItemFromCompartment then
        if slotType == "weapons" and player.weaponSystem and player.weaponSystem.currentSlot == slotIndex then
            player.weaponSystem:switchToNextAvailableWeapon()
        end
        
        local removedItem = player.inventory:removeItemFromCompartment(compName, slotIndex)
        if removedItem then
            local audio = getAudio()
            if audio and audio.play then
                audio.play("ui_click", { pitch = 0.75, volume = 0.5 })
            end
            print("Item eliminado de " .. slotType .. ": " .. (removedItem.data and removedItem.data.name or "Unknown"))
        end
    else
        print("[DELETE] Advertencia: Usando fallback manual para eliminación")
        if slotType == "inventory" then
            local shipComp = player.inventory:getCompartment('ship') or player.inventory
            shipComp.items[slotIndex] = nil
        elseif slotType == "eva" then
            local evaComp = player.inventory:getCompartment('eva')
            if evaComp then evaComp.items[slotIndex] = nil end
        elseif slotType == "weapons" then
            local weaponComp = player.inventory:getCompartment('weapons')
            if weaponComp then weaponComp.items[slotIndex] = nil end
        end
    end
end

--[[
    Lanza un item del inventario al mundo exterior
--]]
function InventoryModal.dropItemFromModal(parentUI, slotIndex, slotType, player)
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
    
    local activeEntity = player:getActiveEntity()
    if not activeEntity then
        print("[DROP MODAL] Error: No se pudo obtener la entidad activa")
        return
    end
    
    local offsetX = (math.random() - 0.5) * 100
    local offsetY = (math.random() - 0.5) * 100
    local targetX = activeEntity.x + offsetX
    local targetY = activeEntity.y + offsetY
    
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
        local compName = parentUI:getCompartmentName(slotType)
        if compName and player.inventory and player.inventory.removeItemFromCompartment then
            if slotType == "weapons" and player.weaponSystem and player.weaponSystem.currentSlot == slotIndex then
                player.weaponSystem:switchToNextAvailableWeapon()
            end
            player.inventory:removeItemFromCompartment(compName, slotIndex)
        end
        
        local audio = getAudio()
        if audio and audio.play then
            audio.play("ui_click", { pitch = 0.85, volume = 0.55 })
        end
        print("[DROP MODAL] Item lanzado:", itemData.name, "x" .. quantity)
    else
        print("[DROP MODAL] Error: No se pudo crear el item en el mundo")
    end
end

return InventoryModal
