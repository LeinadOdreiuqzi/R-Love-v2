-- main.lua (SISTEMA COMPLETO DESACOPLADO)
local bootStarted = love.timer.getTime()

local CombatDebug = require 'src.ui.combat_debug_menu'
local World = require 'src.core.world'
local InputManager = require 'src.core.input_manager'
local GameLoader = require 'src.core.game_loader'
local GameLoop = require 'src.core.game_loop'
local LoadingScreen = require 'src.ui.loading_screen'
local FullscreenManager = require 'src.utils.fullscreen_manager'
local StateManager = require 'src.states.state_manager'
local HUD = require 'src.ui.hud'

-- State manager se instancia aquí y se inyecta
local stateManager = StateManager:new()
World.set('stateManager', stateManager)

-- Variables globales de interfaz (REMOVIDAS - usar módulos directamente)
print("[MAIN] Globals purged. Using World and specific modules.")

function love.load(args)
    if args and args[1] == '--combat-vfx-test' then
        require('tests.combat_vfx.runner').install(args[2])
    end
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    if FullscreenManager and FullscreenManager.init then
        FullscreenManager.init()
    end
    
    LoadingScreen.init()
    
    GameLoader.startLoading()
    LoadingScreen.state.startTime = bootStarted
end

function love.update(dt)
    if CombatDebug.opened then return end
    GameLoop.update(dt)
end

function love.draw()
    GameLoop.draw()
    local run = World.get('runState')
    if run and run.defeat then
        HUD.drawDefeat(run.defeat)
        return
    end
    CombatDebug.draw()
end

function love.keypressed(key)
    if LoadingScreen.state.failure and (key == 'return' or key == 'kpenter') then
        love.event.quit('restart')
        return
    end
    local run = World.get('runState')
    if run and run.defeat then
        if key == 'return' or key == 'kpenter' then
            if CombatDebug.opened then CombatDebug.close() end
            GameLoader.changeSeedWithLoading(run.seed)
        end
        return
    end
    if CombatDebug.opened then CombatDebug.keypressed(key); return end
    InputManager.keypressed(key)
end

local function runDefeated()
    local run = World.get('runState')
    return run and run.defeat ~= nil
end

function love.textinput(text)
    if runDefeated() then return end
    if CombatDebug.opened then CombatDebug.textinput(text); return end
    InputManager.textinput(text)
end

function love.wheelmoved(x, y)
    if runDefeated() then return end
    if CombatDebug.opened then CombatDebug.wheelmoved(x, y); return end
    InputManager.wheelmoved(x, y)
end

function love.mousepressed(x, y, button)
    if runDefeated() then return end
    if CombatDebug.opened then CombatDebug.mousepressed(x, y, button); return end
    InputManager.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    if runDefeated() then return end
    if CombatDebug.opened then
        CombatDebug.mousereleased(x, y, button)
        return
    end
    InputManager.mousereleased(x, y, button)
end

function love.mousemoved(x, y)
    if runDefeated() then return end
    if CombatDebug.opened then CombatDebug.mousemoved(x, y) end
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
