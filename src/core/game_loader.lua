-- src/core/game_loader.lua
-- Encargado de cargar mundos (asíncrono), generar semillas y recursos
-- Desacoplado de main.lua

local GameLoader = {}
local DEBUG_STARTER_SPRITE = true

local World = require 'src.core.world'
local Camera = require 'src.utils.camera'
local Map = require 'src.maps.map'
local Naves = require 'src.entities.naves'
local HUD = require 'src.ui.hud'
local BiomeSystem = require 'src.maps.biome_system'
local ChunkManager = require 'src.maps.chunk_manager'
local SeedSystem = require 'src.utils.seed_system'
local LoadingScreen = require 'src.ui.loading_screen'
local GameState = require 'src.core.game_state'
local RunState = require 'src.gameplay.run_state'
local GameDirector = require 'src.gameplay.game_director'
local PhysicsManager = require 'src.physics.physics_manager'
local InventoryManager = require 'src.core.inventory_manager'
local PassiveManager = require 'src.item_systems.passive_manager'
local AudioManager = require 'src.audio.audio_manager'

local interfacesReady = false

local function loadWorld(updateProgress)
    local state = GameState.state
    local loadSteps = {}
    local currentStep = 1
    
    table.insert(loadSteps, function()
        updateProgress("init", "Setting up game systems...")
        return true
    end)
    
    if not interfacesReady then
        table.insert(loadSteps, function()
            updateProgress("init", "Preparing items...")
            require('src.item_systems.items.init').initialize()
        end)
        table.insert(loadSteps, function()
            require('src.ui.inventory_ui'):init()
            require('src.ui.eva_inventory_ui'):init()
            interfacesReady = true
        end)
    end

    table.insert(loadSteps, function()
        updateProgress("seed", "Generating universe seed...")
        if not state.currentSeed then
            math.randomseed(os.time())
            state.currentSeed = SeedSystem.generate()
        end
        love.window.setTitle("Space Roguelike - Enhanced Systems - Seed: " .. state.currentSeed)
        return true
    end)
    
    local function addPreload(stage, detail, fraction, preload)
        table.insert(loadSteps, coroutine.wrap(function()
            updateProgress(stage, detail, fraction)
            preload(function() coroutine.yield(false) end)
            return true
        end))
    end
    addPreload("seed", "Preparing rendering resources...", 0.5, require('src.shaders.shader_manager').init)

    table.insert(loadSteps, function()
        updateProgress("perlin", "Creating noise patterns...")
        Map.init(state.currentSeed)
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("biomes", "Locating the starting biome...")
        BiomeSystem.getBiomeForChunk(0, 0)
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("coordinates", "Setting up infinite coordinate system...")
        local cam = assert(Camera:new(), "Failed to initialize camera")
        
        World.set('camera', cam)
        cam:updateScreenDimensions()
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("chunks", "Initializing chunk management...")
        for y = -1, 1 do
            for x = -1, 1 do Map.getChunkNonBlocking(x, y) end
        end
    end)

    addPreload("renderer", "Preparing frontier ship art...", 0, require('src.rendering.ships.frontier_boss_art').preload)
    addPreload("renderer", "Preparing tactical ships...", 0.5, require('src.rendering.ships.tactical_pixel_art').preload)

    -- The player starts at a chunk boundary. Wait for its immediate neighbours.
    table.insert(loadSteps, coroutine.wrap(function()
        local ready = 0
        local deadline = love.timer.getTime() + 0.002
        local function checkpoint()
            if love.timer.getTime() >= deadline then
                coroutine.yield(false)
                deadline = love.timer.getTime() + 0.002
            end
        end
        repeat
            updateProgress("initial_chunks", string.format("Starting sectors ready: %d / 9", ready), ready / 9)
            ChunkManager.processLoadQueue(nil, 0.003, checkpoint)
            ready = 0
            for y = -1, 1 do
                for x = -1, 1 do
                    assert(ChunkManager.isChunkInCurrentPhase(x, y), "Starting sector outside active map")
                    local chunk = Map.getChunkNonBlocking(x, y)
                    if chunk and chunk.status == "complete" then ready = ready + 1 end
                end
            end
            checkpoint()
        until ready == 9
        updateProgress("initial_chunks", "Starting sectors ready: 9 / 9", 1)
        return true
    end))

    table.insert(loadSteps, function()
        updateProgress("player", "Creating player entity and test ships...")
        if Naves.clearAllShips then
            Naves.clearAllShips()
        end
        local playerX, playerY = 0, 0
        local player = Naves:new(playerX, playerY, "EXPLORER", {
            debugStarterSprite = DEBUG_STARTER_SPRITE
        })
        player.isPiloted = true
        player.isAbandoned = false
        local repairKit = require('src.item_systems.item_system'):getItem('repair_kit')
        if repairKit then player.inventory:addItemToCompartment('ship', repairKit, 1) end
        
        World.set('player', player)
        World.addEntity(player)
        
        local fighterShip = Naves:new(playerX + 500, playerY, "FIGHTER")
        fighterShip.isPiloted = false
        fighterShip.isAbandoned = true
        fighterShip.driftAngularSpeed = 0.04
        World.addEntity(fighterShip)
        
        local cargoShip = Naves:new(playerX - 500, playerY, "CARGO")
        cargoShip.isPiloted = false
        cargoShip.isAbandoned = true
        cargoShip.driftAngularSpeed = -0.025
        World.addEntity(cargoShip)
        
        print("[TESTING] Naves creadas para testing de persistencia y jugabilidad:")
        print("  Player (Explorer): ID", player.shipId, "en (0, 0)")
        print("  Fighter: ID", fighterShip.shipId, "en (500, 0)")
        print("  Cargo: ID", cargoShip.shipId, "en (-500, 0)")
        
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("game_systems", "Initializing game systems...")
        
        local runState = RunState:new({ seed = state.currentSeed })
        local gameDirector = GameDirector:new(runState)
        local physMgr = PhysicsManager:new()
        
        AudioManager.init()
        AudioManager.playMusic("track_8", { loop = true, volume = 0.45, restart = true, async = true })
        
        World.set('state', state)
        World.set('runState', runState)
        World.set('director', gameDirector)
        World.set('physics', physMgr)
        World.set('audio', AudioManager)
        World.set('map', Map)
        World.set('seed', state.currentSeed)
        World.set('biomeDebug', GameState.biomeDebug)
        
        print("[MAIN DEBUG] Sistemas inicializados")
        World.dump()
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("hud", "Loading user interface...")
        HUD.init(World)
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("finalize", "Finalizing universe generation...")
        print("=== SPACE ROGUELIKE ENHANCED LOADED ===")
        print("Alphanumeric Seed: " .. state.currentSeed)
        print("Numeric Seed: " .. SeedSystem.toNumeric(state.currentSeed))
        
        state.loaded = true
        state.isLoading = false
        World.set('seed', state.currentSeed)
        return true
    end)
    
    return function()
        if currentStep <= #loadSteps then
            if loadSteps[currentStep]() == false then return false end
            currentStep = currentStep + 1
            return currentStep > #loadSteps
        end
        return true
    end
end

function GameLoader.startLoading()
    GameState.state.isLoading = true
    LoadingScreen.start(loadWorld, function()
        print("=== LOADING COMPLETE ===")
        print("Welcome to the universe!")
    end)
end

function GameLoader.changeSeedWithLoading(newSeed)
    local state = GameState.state
    if not SeedSystem.validate(newSeed) then
        print("Invalid seed format. Using default seed.")
        newSeed = "A1B2C3D4E5"
    end
    
    state.currentSeed = newSeed
    state.loaded = false
    state.isLoading = true
    
    -- Limpieza total del sistema de audio al reiniciar
    AudioManager.reset()
    
    InventoryManager.forceCloseAll()
    
    PassiveManager.reset()
    local player = World.get('player')
    if player and player.inventory and player.inventory.compartments and player.inventory.compartments.passives then
        local passiveComp = player.inventory.compartments.passives
        if passiveComp and passiveComp.items then
            for i = 1, passiveComp.maxSlots do
                if passiveComp.items[i] then
                    if player.inventory.removeItemFromCompartment then
                        player.inventory:removeItemFromCompartment('passives', i)
                    else
                        passiveComp.items[i] = nil
                    end
                end
            end
        end
    end

    local frontier=World.get('frontierEncounter')
    if frontier then frontier:dispose() end
    local stateManager = World.get('stateManager')
    if stateManager and stateManager.clear then
        stateManager:clear()
    end
    
    if ChunkManager and ChunkManager.cleanup then
        ChunkManager.cleanup()
    end

    if Naves and Naves.clearAllShips then
        Naves.clearAllShips()
    end

    local WorldItems = package.loaded['src.item_systems.world_items']
    if WorldItems and WorldItems.clear then
        WorldItems.clear()
    end

    World.reset()
    
    print("Passive effects and items cleared for seed change")
    
    LoadingScreen.start(loadWorld, function()
        print("New world generated with seed: " .. newSeed)
        local runState = World.get('runState')
        local gameDirector = World.get('director')
        if runState and runState.reset then
            runState:reset(newSeed)
        else
            runState = RunState:new({ seed = newSeed })
            World.set('runState', runState)
        end
        if gameDirector and gameDirector.reset then
            gameDirector:reset()
            if gameDirector.setRunState then gameDirector:setRunState(runState) end
        else
            gameDirector = GameDirector:new(runState)
            World.set('director', gameDirector)
        end
    end)
end

function GameLoader.changeSeed(newSeed)
    GameLoader.changeSeedWithLoading(newSeed)
end

function GameLoader.regenerateMap(seed)
    GameLoader.changeSeedWithLoading(seed)
end

return GameLoader
