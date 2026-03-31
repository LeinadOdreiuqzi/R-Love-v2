-- src/core/input_manager.lua
-- Gestor de entrada centralizado para R-Love-v2.
-- Maneja teclado, ratón y rueda del ratón de forma contextual.
-- Desacopla la lógica de entrada de main.lua.

local InputManager = {}

-- Referencias locales para optimización
local World = nil
local GameState = require 'src.core.game_state'

-- Estados internos
local _isInitialized = false

-- Acción especial: Toggle Fullscreen
local function toggleFullscreen()
    local FullscreenManager = package.loaded['src.utils.fullscreen_manager']
    if FullscreenManager and FullscreenManager.toggle then
        FullscreenManager.toggle()
    end
end

-- ─── LÓGICA DE TECLADO ─────────────────────────────────────────────────────

function InputManager.keypressed(key)
    World = package.loaded['src.core.world']
    if not World then return end

    local gameState = World.getState()
    local player = World.getPlayer()
    local stateManager = World.get('stateManager') -- Debería estar en World (se agregará en la integración)
    local HUD = package.loaded['src.ui.hud']
    local InventoryUI = package.loaded['src.ui.inventory_ui']
    local EVAInventoryUI = package.loaded['src.ui.eva_inventory_ui']
    local Map = World.getMap()
    local SeedSystem = package.loaded['src.utils.seed_system']

    -- 1. CASO: CARGANDO (Prioridad máxima)
    if gameState and (gameState.isLoading or not gameState.loaded) then
        if key == "escape" then
            love.event.quit()
        elseif (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) or key == "f11" then
            toggleFullscreen()
        end
        return
    end

    -- 2. CASO: SEED INPUT VISIBLE (Intercepción de HUD)
    if HUD and HUD.isSeedInputVisible and HUD.isSeedInputVisible() then
        local newSeed = HUD.handleSeedInput(key)
        if newSeed then
            HUD.hideSeedInput()
            local GameLoader = require 'src.core.game_loader'
            GameLoader.changeSeed(newSeed)
        end
        return
    end

    -- 3. DELEGAR AL STATE MANAGER (Escenas activas: estaciones, subniveles)
    if stateManager and stateManager.keypressed and stateManager:keypressed(key) then
        return
    end

    -- 4. ATAJOS GLOBALES (SIEMPRE ACTIVOS)
    if key == "escape" then
        love.event.quit()
        return
    elseif (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) or key == "f11" then
        toggleFullscreen()
        return
    elseif key == "p" then
        if gameState then
            gameState.paused = not gameState.paused
            print("Game " .. (gameState.paused and "PAUSED" or "RESUMED"))
        end
        return
    end

    -- 5. DELEGAR A INVENTARIOS ABIERTOS (Si están visibles)
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() and player and player.isInEVA then
        EVAInventoryUI:keypressed(key, player.evaPlayer)
    end
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() and player and not player.isInEVA then
        InventoryUI:keypressed(key, player)
    end

    -- 6. CONTROLES DE DEBUG / HUD (F1 - F12)
    if key == "f1" then HUD.toggleInfo()
    elseif key == "f2" then HUD.showSeedInput()
    elseif key == "f3" then
        if player and player.stats then
            local enabled = player.stats:toggleDebugMode()
            print("Debug mode: " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "f4" then
        GameState.state.showGrid = not GameState.state.showGrid
        print("Enhanced grid display: " .. (GameState.state.showGrid and "ON" or "OFF"))
    elseif key == "f5" then HUD.toggleDebugMenu()
    elseif key == "f6" then
        local biomeDebug = World.get('biomeDebug')
        if biomeDebug then
            biomeDebug.showPerformanceOverlay = not biomeDebug.showPerformanceOverlay
            print("Performance overlay: " .. (biomeDebug.showPerformanceOverlay and "ON" or "OFF"))
        end
    elseif key == "f7" then
        if Map and Map.starConfig then
            Map.starConfig.enhancedEffects = not Map.starConfig.enhancedEffects
            print("Enhanced star effects: " .. (Map.starConfig.enhancedEffects and "ON" or "OFF"))
        end
    elseif key == "f8" then
        if Map and Map.starConfig then
            local currentMax = Map.starConfig.maxStarsPerFrame
            if currentMax <= 1500 then Map.starConfig.maxStarsPerFrame = 3000
            elseif currentMax <= 3000 then Map.starConfig.maxStarsPerFrame = 5000
            else Map.starConfig.maxStarsPerFrame = 1500 end
            print("Star quality updated: " .. Map.starConfig.maxStarsPerFrame)
        end
    elseif key == "f9" then
        if player and player.stats then
            local enabled = player.stats:toggleInvulnerability()
            print("Invulnerability: " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "f10" then
        if player and player.stats then
            local enabled = player.stats:toggleInfiniteFuel()
            print("Infinite fuel: " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "f12" then HUD.toggleBiomeInfo()
    end

    -- 7. LÓGICA DE JUEGO / ACCIONES
    if key == "tab" then
        InputManager.toggleInventory(gameState, player, InventoryUI, EVAInventoryUI)
    elseif key == "r" then
        if player and player.weaponSystem then player.weaponSystem:reload() end
    elseif key == "e" then
        InputManager.handleInteraction(World, HUD, Map)
    elseif key == "h" then -- Debug Heal
        if player and player.heal then player:heal(2); print("Healed") end
    elseif key == "u" then -- Debug Fuel / Pruebas
        if player and player.addFuel then player:addFuel(25); print("Fuel added") end
    elseif key == "1" then -- Test Inventory
        if player and InventoryUI then InventoryUI:createTestInventory(player) end
    elseif key == "m" then -- Passive debug
        local PassiveManager = package.loaded['src.item_systems.passive_manager']
        if PassiveManager then PassiveManager.printDebugInfo() end
    elseif key == "l" then
        if gameState then
            gameState.showHUD = not gameState.showHUD
            print("HUD: " .. (gameState.showHUD and "VISIBLE" or "HIDDEN"))
        end
    elseif key == "0" then -- Hyper travel
        if player and player.toggleHyperTravel then
            local enabled = player:toggleHyperTravel(100000)
            print("Hyper travel (100k): " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "k" then -- Star shader toggle
        if Map and Map.starConfig then
            Map.starConfig.useInstancedShader = not Map.starConfig.useInstancedShader
            print("Star mode: " .. (Map.starConfig.useInstancedShader and "INSTANCED" or "LEGACY"))
        end
    elseif key == "f" then
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            collectgarbage("collect")
            print("Garbage collected manually")
        else
            if SeedSystem then
                local GameLoader = require 'src.core.game_loader'
                GameLoader.changeSeedWithLoading(SeedSystem.generate())
            end
        end
    end
end

-- ─── ACCIONES AUXILIARES ───────────────────────────────────────────────────

function InputManager.toggleInventory(gameState, player, InventoryUI, EVAInventoryUI)
    if not player or not gameState then return end
    
    local desired = player.isInEVA and "eva" or "ship"
    if gameState.inventoryMode == desired then
        -- Cerrar el actual
        if desired == "ship" then
            if InventoryUI and InventoryUI.close then InventoryUI:close() end
        else
            if EVAInventoryUI and EVAInventoryUI.close then EVAInventoryUI:close() end
        end
        gameState.inventoryMode = "none"
    else
        -- Abrir el deseado (y cerrar el otro)
        if desired == "ship" then
            if EVAInventoryUI and EVAInventoryUI.close then EVAInventoryUI:close() end
            if InventoryUI then InventoryUI:toggle(player) end
            gameState.inventoryMode = "ship"
        else
            if InventoryUI and InventoryUI.close then InventoryUI:close() end
            if EVAInventoryUI then EVAInventoryUI:toggle(player) end
            gameState.inventoryMode = "eva"
        end
    end
end

function InputManager.handleInteraction(World, HUD, Map)
    local player = World.getPlayer()
    if not player then 
        print("[InputManager] Error: No player found in World")
        return 
    end

    -- 1. Manejo de expansión de fases (PhaseSystem)
    local PhaseSystem = package.loaded['src.gameplay.phase_system']
    if PhaseSystem and PhaseSystem.handleInput then
        pcall(function() PhaseSystem.handleInput("e") end)
    end

    -- 2. Recolección de items
    local WorldItems = package.loaded['src.item_systems.world_items']
    local collected = false
    if WorldItems and WorldItems.tryManualCollection then
        collected = WorldItems.tryManualCollection()
    end

    -- 3. Entrar a Estaciones / Subniveles (si no se recolectó nada)
    if not collected then
        local stateManager = World.get('stateManager')
        if not stateManager then 
            print("[InputManager] Warning: stateManager not found in World")
            return 
        end
        
        -- Verificar si el estado actual bloquea la interacción subyacente
        if stateManager.blocksUnderlying and stateManager:blocksUnderlying() then
            return
        end

        -- Llamar a la función de interacción compleja en InteractionSystem
        local InteractionSystem = require 'src.core.interaction_system'
        InteractionSystem.tryEnterStationOrSublevel()
    end
end

-- ─── LÓGICA DE RATÓN ───────────────────────────────────────────────────────

function InputManager.mousepressed(x, y, button)
    World = package.loaded['src.core.world']
    if not World then return end
    
    local gameState = World.getState()
    if not gameState or not gameState.loaded then return end

    local stateManager = World.get('stateManager')
    local player = World.getPlayer()
    local InventoryUI = package.loaded['src.ui.inventory_ui']
    local EVAInventoryUI = package.loaded['src.ui.eva_inventory_ui']

    -- 1. Delegar al StateManager
    if stateManager and stateManager.mousepressed and stateManager:mousepressed(x, y, button) then
        return
    end

    -- 2. Delegar a inventarios
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() and player and player.isInEVA then
        EVAInventoryUI:mousepressed(x, y, button, player.evaPlayer)
        return
    end
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        InventoryUI:mousepressed(x, y, button, player)
        return
    end

    -- 3. Gameplay: Disparo
    if button == 1 and player and not player.isInEVA then
        player:shoot(x, y)
    end
end

function InputManager.mousereleased(x, y, button)
    World = package.loaded['src.core.world']
    if not World then return end
    
    local gameState = World.getState()
    if not gameState or not gameState.loaded then return end

    local stateManager = World.get('stateManager')
    local InventoryUI = package.loaded['src.ui.inventory_ui']

    if stateManager and stateManager.mousereleased and stateManager:mousereleased(x, y, button) then
        return
    end

    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        InventoryUI:mousereleased(x, y, button, World.getPlayer())
    end
end

-- ─── LÓGICA DE TEXTO Y RUEDA ───────────────────────────────────────────────

function InputManager.textinput(text)
    World = package.loaded['src.core.world']
    if not World or not World.getState() or not World.getState().loaded then return end

    local stateManager = World.get('stateManager')
    local HUD = package.loaded['src.ui.hud']

    if stateManager and stateManager.textinput and stateManager:textinput(text) then
        return
    end

    if HUD and HUD.textinput then
        HUD.textinput(text)
    end
end

function InputManager.wheelmoved(x, y)
    World = package.loaded['src.core.world']
    if not World or not World.getState() or not World.getState().loaded then return end

    local stateManager = World.get('stateManager')
    local camera = World.getCamera()

    if stateManager and stateManager.wheelmoved and stateManager:wheelmoved(x, y) then
        return
    end

    if camera and camera.wheelmoved then
        camera:wheelmoved(x, y)
    end
end

return InputManager