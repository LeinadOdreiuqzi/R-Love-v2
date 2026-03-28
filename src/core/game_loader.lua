-- src/core/game_loader.lua
-- Encargado de cargar mundos (asíncrono), generar semillas y recursos
-- Desacoplado de main.lua

local GameLoader = {}

local World = require 'src.core.world'
local Camera = require 'src.utils.camera'
local Map = require 'src.maps.map'
local Naves = require 'src.entities.naves'
local HUD = require 'src.ui.hud'
local BiomeSystem = require 'src.maps.biome_system'
local CoordinateSystem = require 'src.maps.coordinate_system'
local ChunkManager = require 'src.maps.chunk_manager'
local OptimizedRenderer = require 'src.maps.optimized_renderer'
local SeedSystem = require 'src.utils.seed_system'
local LoadingScreen = require 'src.ui.loading_screen'
local GameState = require 'src.core.game_state'
local RunState = require 'src.gameplay.run_state'
local GameDirector = require 'src.gameplay.game_director'
local PhysicsManager = require 'src.physics.physics_manager'
local InventoryManager = require 'src.core.inventory_manager'
local PassiveManager = require 'src.item_systems.passive_manager'

local function loadWorld(updateProgress)
    local state = GameState.state
    local loadSteps = {}
    local currentStep = 1
    
    table.insert(loadSteps, function()
        updateProgress("init", "Setting up game systems...")
        love.window.setMode(1200, 800, {resizable = true})
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("seed", "Generating universe seed...")
        math.randomseed(os.time())
        state.currentSeed = SeedSystem.generate()
        love.window.setTitle("Space Roguelike - Enhanced Systems - Seed: " .. state.currentSeed)
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("perlin", "Creating noise patterns...")
        local mapInitSuccess = pcall(function() Map.init(state.currentSeed) end)
        if not mapInitSuccess then print("Warning: Enhanced Map initialization had issues") end
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("biomes", "Distributing biomes across space...")
        if BiomeSystem then
            for i = 1, 10 do
                local testX = math.random(-100, 100)
                local testY = math.random(-100, 100)
                BiomeSystem.getBiomeForChunk(testX, testY)
                updateProgress("biomes", string.format("Calculating biome distribution... %d%%", i * 10))
            end
        end
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("coordinates", "Setting up infinite coordinate system...")
        local success, cam = pcall(function() return Camera:new() end)
        if not success or not cam then error("Failed to initialize camera") end
        
        World.set('camera', cam)
        _G.camera = cam -- Global por compatibilidad por ahora
        _G.camera:updateScreenDimensions()
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("chunks", "Initializing chunk management...")
        if ChunkManager and ChunkManager.state then
            updateProgress("chunks", "Creating chunk pool... 50%")
        end
        return true
    end)
    
    table.insert(loadSteps, function()
        updateProgress("renderer", "Preparing renderer and shaders...")
        local rendererSuccess, rendererErr = pcall(function() OptimizedRenderer.init() end)
        if not rendererSuccess then print("Warning: OptimizedRenderer not available: " .. tostring(rendererErr)) end
        return true
    end)
    
    local initialRadius = 3
    local chunkCount = 0
    local totalChunks = (initialRadius * 2 + 1) ^ 2
    
    for chunkY = -initialRadius, initialRadius do
        for chunkX = -initialRadius, initialRadius do
            local cx, cy = chunkX, chunkY
            table.insert(loadSteps, function()
                if Map.getChunk then Map.getChunk(cx, cy, 0, 0) end
                chunkCount = chunkCount + 1
                local percent = math.floor((chunkCount / totalChunks) * 100)
                updateProgress("initial_chunks", string.format("Generating chunks... %d%%", percent))
                return true
            end)
        end
    end
    
    table.insert(loadSteps, function()
        updateProgress("player", "Creating player entity and test ships...")
        local playerX, playerY = 0, 0
        local player = Naves:new(playerX, playerY, "EXPLORER")
        
        World.set('player', player)
        World.addEntity(player)
        
        local fighterShip = Naves:new(playerX + 500, playerY, "FIGHTER")
        World.addEntity(fighterShip)
        
        local cargoShip = Naves:new(playerX - 500, playerY, "CARGO")
        World.addEntity(cargoShip)
        
        print("[TESTING] Naves creadas para testing de persistencia:")
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
        _G.physicsManager = physMgr
        
        World.set('state', state)
        World.set('runState', runState)
        World.set('director', gameDirector)
        World.set('physics', physMgr)
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
            loadSteps[currentStep]()
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
    
    InventoryManager.forceCloseAll()
    World.reset()
    
    local stateManager = World.get('stateManager')
    if stateManager and stateManager.clear then
        stateManager:clear()
    end
    
    if ChunkManager and ChunkManager.cleanup then
        ChunkManager.cleanup()
    end
    
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
    local state = GameState.state
    if not SeedSystem.validate(newSeed) then
        print("Invalid seed format. Using default seed.")
        newSeed = "A1B2C3D4E5"
    end
    
    state.currentSeed = newSeed
    love.window.setTitle("Space Roguelike - Enhanced Systems - Seed: " .. newSeed)
    GameLoader.regenerateMap(newSeed)
    print("New enhanced galaxy generated with seed: " .. newSeed)
    print("Numeric equivalent: " .. SeedSystem.toNumeric(newSeed))
end

function GameLoader.regenerateMap(seed)
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
    
    print("Passive effects and items cleared for map regeneration")
    
    Map.regenerate(seed)
    
    if player then
        if player.isInEVA and player.exitEVA then
            player:exitEVA()
        end
        
        player.x, player.y = 0, 0
        player.dx, player.dy = 0, 0
        
        if player.stats then
            player.stats.health.currentHealth = player.stats.health.maxHealth
            player.stats.shield.currentShield = player.stats.shield.maxShield
            player.stats.fuel.currentFuel = player.stats.fuel.maxFuel
            player.stats:updateHeartDisplay()
        end
    end
    
    local camera = _G.camera or World.get('camera')
    if camera then camera:setPosition(0, 0) end
    
    CoordinateSystem.init(0, 0)
    
    World.set('player', player)
    World.set('seed', seed)
    HUD.updateReferences(World)
    
    print("=== NEW ENHANCED GALAXY GENERATED ===")
    print("Alphanumeric Seed: " .. seed)
    print("Numeric Seed: " .. SeedSystem.toNumeric(seed))
end

return GameLoader
