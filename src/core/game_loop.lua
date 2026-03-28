-- src/core/game_loop.lua
-- Bucle principal del juego extraído de main.lua
-- Encapsula update y draw logrando un main.lua limpio

local GameLoop = {}

local World = require 'src.core.world'
local GameState = require 'src.core.game_state'
local LoadingScreen = require 'src.ui.loading_screen'
local HUD = require 'src.ui.hud'
local InventoryManager = require 'src.core.inventory_manager'
local InventoryUI = require 'src.ui.inventory_ui'
local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
local Map = require 'src.maps.map'
local OptimizedRenderer = require 'src.maps.optimized_renderer'
local ChunkManager = require 'src.maps.chunk_manager'
local FullscreenManager = package.loaded['src.utils.fullscreen_manager']
local DebugRenderer = require 'src.utils.debug_renderer'
local WorldItems = require 'src.item_systems.world_items'

function GameLoop.update(dt)
    local state = GameState.state
    local physics = GameState.physics
    
    -- 1. Pantalla de carga
    if state.isLoading then
        LoadingScreen.update(dt)
        return
    end
    
    if not state.loaded then return end
    if state.paused then return end

    local stateManager = World.get('stateManager')
    
    -- 2. Actualizar StateManager con Tasa Variable (UI y Escenas superpuestas)
    local isBlocked = false
    if stateManager then
        stateManager:update(dt)
        if stateManager:blocksUnderlying() then
            isBlocked = true
            physics.accumulator = 0
            World.set('interpolationAlpha', 1.0)
            -- Como el estado cubre todo, no actualizamos lógica principal
            return 
        end
    end

    local player = World.get('player')
    local runState = World.get('runState')
    local gameDirector = World.get('director')
    local physMgr = World.get('physics')
    local camera = _G.camera or World.get('camera')

    -- 3. Acumular tiempo (Fixed Timestep)
    physics.accumulator = physics.accumulator + math.min(dt, 0.25)

    -- 4. CICLO DE LÓGICA FIJA (60 Hz)
    while physics.accumulator >= physics.fixed_dt do

        if runState then
            local pSpeed = 0
            if player and player.dx and player.dy then
                pSpeed = math.sqrt(player.dx * player.dx + player.dy * player.dy)
            end
            runState:update(physics.fixed_dt, pSpeed)
        end
        
        if gameDirector then gameDirector:update(physics.fixed_dt) end

        if physMgr then physMgr:update(physics.fixed_dt) end

        if player and type(player.update) == "function" then
            if player.savePreviousState then player:savePreviousState() end
            pcall(function() player:update(physics.fixed_dt) end)
            
            if gameDirector and player.isBoostActive ~= nil then
                gameDirector:setPlayerBoosting(player.isBoostActive)
            end
        end

        if WorldItems and WorldItems.update then
            WorldItems.update(physics.fixed_dt)
        end

        physics.accumulator = physics.accumulator - physics.fixed_dt
    end

    -- 4. ACTUALIZACIONES VISUALES (Tasa Variable)
    local interpolationAlpha = physics.accumulator / physics.fixed_dt
    World.set('interpolationAlpha', interpolationAlpha)

    DebugRenderer.updateAdvancedStats(dt)
    
    if camera and camera.update then camera:update(dt) end
    
    if HUD and HUD.update then HUD.update(dt) end
    
    -- Manejar UI e Inventarios
    InventoryManager.update(dt)
    
    -- Culling y Mapas
    if player and player.x and player.y then
        local px, py = player.x, player.y
        local vx, vy = player.dx or 0, player.dy or 0
        
        Map.update(dt, px, py, vx, vy)
        
        if type(OptimizedRenderer) == "table" and OptimizedRenderer.update then
            OptimizedRenderer.update(dt, px, py, camera)
        end
    end
    
    if ChunkManager and ChunkManager.updateFullscreenOptimizations then
        local fsManager = package.loaded['src.utils.fullscreen_manager']
        local isFullscreen = (fsManager and fsManager.isFullscreen and fsManager:isFullscreen()) or false
        ChunkManager.updateFullscreenOptimizations(isFullscreen, camera)
    end

    -- 5. SEGUIMIENTO
    if camera and type(camera.follow) == "function" then
        local success, err = pcall(function()
            local activeEntity = (player and player.getActiveEntity) and player:getActiveEntity() or player
            if activeEntity then camera:follow(activeEntity, dt) end
        end)
        if not success then print("Error updating camera:", err) end
    end
    
    if camera then camera:updateScreenDimensions() end
end

function GameLoop.draw()
    local state = GameState.state
    
    if state.isLoading or not state.loaded then
        LoadingScreen.draw()
        return
    end

    local stateManager = World.get('stateManager')
    if stateManager and stateManager:blocksUnderlying() then
        love.graphics.clear(0, 0, 0, 1)
        stateManager:draw()
        return
    end

    local camera = _G.camera or World.get('camera')
    
    if camera then camera:apply() end
    
    Map.draw(camera)
    
    if GameState.biomeDebug.enabled and GameState.biomeDebug.showRegions then
        DebugRenderer.drawBiomeRegionDebug()
    end
    
    local player = World.get('player')
    if player then player:draw() end
    
    local playerX, playerY = 0, 0
    if player then
        local activeEntity = player:getActiveEntity()
        if activeEntity then
            playerX, playerY = activeEntity.x or 0, activeEntity.y or 0
        end
    end
    
    if WorldItems and WorldItems.draw then
        WorldItems.draw(camera, playerX, playerY)
    end
    
    local physMgr = World.get('physics')
    if physMgr then physMgr:drawDebug() end
    
    if camera then camera:unapply() end
    
    local inventoryOpen = InventoryManager.isAnyInventoryOpen()
    
    if state.showHUD then HUD.draw(inventoryOpen) end
    
    if InventoryUI and InventoryUI.draw and InventoryUI.isOpen and InventoryUI:isOpen() then
        InventoryUI:draw(player)
    end
    
    if EVAInventoryUI and EVAInventoryUI.draw and player and player.isInEVA and player.evaPlayer then
        if EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
            EVAInventoryUI:draw(player.evaPlayer)
        end
    end
    
    if GameState.biomeDebug.enabled then
        DebugRenderer.drawBiomeDebugOverlay()
    end
    
    if GameState.biomeDebug.showPerformanceOverlay or GameState.advancedStats.enabled then
        DebugRenderer.drawPerformanceOverlay()
    end

    if stateManager then stateManager:draw() end
end

return GameLoop
