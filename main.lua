-- main.lua (SISTEMA COMPLETO DESACOPLADO)

local World = require 'src.core.world'
local InputManager = require 'src.core.input_manager'
local GameLoader = require 'src.core.game_loader'
local GameLoop = require 'src.core.game_loop'
local LoadingScreen = require 'src.ui.loading_screen'
local FullscreenManager = package.loaded['src.utils.fullscreen_manager']
local StateManager = require 'src.states.state_manager'
local ItemSystem = require 'src.item_systems.items.init'
local InventoryUI = require 'src.ui.inventory_ui'
local EVAInventoryUI = require 'src.ui.eva_inventory_ui'

-- State manager se instancia aquí y se inyecta
local stateManager = StateManager:new()
World.set('stateManager', stateManager)

-- Variables globales de interfaz (REMOVIDAS - usar módulos directamente)
print("[MAIN] Globals purged. Using World and specific modules.")

function love.load(args)
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    if FullscreenManager and FullscreenManager.init then
        FullscreenManager.init()
    end
    
    LoadingScreen.init()
    
    if ItemSystem and ItemSystem.initialize then
        ItemSystem.initialize()
        print("[MAIN] Sistema de items inicializado")
    end
    
    if InventoryUI and InventoryUI.init then InventoryUI:init() end
    if EVAInventoryUI and EVAInventoryUI.init then EVAInventoryUI:init() end
    
    -- Inicia carga asincrónica
    GameLoader.startLoading()
end

function love.update(dt)
    GameLoop.update(dt)
end

function love.draw()
    GameLoop.draw()
end

function love.keypressed(key)
    InputManager.keypressed(key)
end

function love.textinput(text)
    InputManager.textinput(text)
end

function love.wheelmoved(x, y)
    InputManager.wheelmoved(x, y)
end

function love.mousepressed(x, y, button)
    InputManager.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    InputManager.mousereleased(x, y, button)
end

function love.resize(w, h)
    if stateManager then stateManager:resize(w, h) end

    if FullscreenManager and FullscreenManager.handleResize then
        FullscreenManager.handleResize(w, h)
    end
    
    local camera = World.get('camera')
    if camera then camera:updateScreenDimensions() end

    local Map = require 'src.maps.map'
    if Map and Map.updateScreenDimensions then Map.updateScreenDimensions() end

    if LoadingScreen and LoadingScreen.resize then LoadingScreen.resize(w, h) end
end