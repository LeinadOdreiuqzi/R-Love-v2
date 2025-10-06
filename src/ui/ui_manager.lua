-- src/ui/ui_manager.lua
-- Orquestador simple para actualizar UIs (inventario nave/EVA, HUD si aplica)

local UIManager = {}

function UIManager.updateAll(dt, player)
    -- Inventario de la nave
    local InventoryUI = require 'src.ui.inventory_ui'
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        InventoryUI:update(dt, player)
    end

    -- Inventario EVA (solo si el jugador está en EVA y existe evaPlayer)
    local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() and player and player.isInEVA and player.evaPlayer then
        EVAInventoryUI:update(dt, player.evaPlayer)
    end

    -- HUD podría requerir actualización separada; mantener fuera para no duplicar
    return true
end

return UIManager