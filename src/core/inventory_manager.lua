-- src/core/inventory_manager.lua
-- Lógica para la exclusividad de menús e integración de inventarios
-- Extraído de main.lua

local InventoryUI = require 'src.ui.inventory_ui'
local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
local GameState = require 'src.core.game_state'
local World = require 'src.core.world'

local InventoryManager = {}
local prevIsInEVA = false

-- Actualiza y sincroniza quién tiene el foco del inventario
function InventoryManager.processExclusivity()
    local player = World.get('player')
    if not player then return end

    -- Detectar transición de EVA
    if prevIsInEVA ~= player.isInEVA then
        if InventoryUI and InventoryUI.close then InventoryUI:close() end
        if EVAInventoryUI and EVAInventoryUI.close then EVAInventoryUI:close() end
        GameState.state.inventoryMode = "none"
        prevIsInEVA = player.isInEVA
    end

    -- Exclusividad forzada
    if player.isInEVA then
        if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then InventoryUI:close() end
    else
        if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then EVAInventoryUI:close() end
    end

    -- Sincronizar modo
    local computed = "none"
    if not player.isInEVA and InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then computed = "ship" end
    if player.isInEVA and EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then computed = "eva" end
    GameState.state.inventoryMode = computed
end

-- Llamado por main/game_loop en love.update
function InventoryManager.update(dt)
    local player = World.get('player')
    
    if InventoryUI and InventoryUI.update then
        InventoryUI:update(dt, player)
    end
    
    if EVAInventoryUI and EVAInventoryUI.update and player and player.isInEVA and player.evaPlayer then
        EVAInventoryUI:update(dt, player.evaPlayer)
    end
    
    InventoryManager.processExclusivity()
end

-- Interfaz auxiliar utilitaria 
function InventoryManager.isAnyInventoryOpen()
    return (InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen()) or 
           (EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen())
end

-- Fuerzo el cierre de inventarios si están abiertos
function InventoryManager.forceCloseAll()
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        if InventoryUI.close then InventoryUI:close() else InventoryUI:toggle() end
    end
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
        if EVAInventoryUI.close then EVAInventoryUI:close() else EVAInventoryUI:toggle() end
    end
    GameState.state.inventoryMode = "none"
end

return InventoryManager
