-- main.lua (SISTEMA COMPLETO CON PANTALLA DE CARGA)

local Camera = require 'src.utils.camera'
local Map = require 'src.maps.map'
local Naves = require 'src.entities.naves'
local HUD = require 'src.ui.hud'
local InventoryUI = require 'src.ui.inventory_ui'
local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
local BiomeSystem = require 'src.maps.biome_system'
local CoordinateSystem = require 'src.maps.coordinate_system'
local ChunkManager = require 'src.maps.chunk_manager'
local OptimizedRenderer = require 'src.maps.optimized_renderer'
local SeedSystem = require 'src.utils.seed_system'
local LoadingScreen = require 'src.ui.loading_screen'
local FullscreenManager = require 'src.utils.fullscreen_manager'
local StateManager = require 'src.states.state_manager'
local StationScene = require 'src.states.station_scene'
local SubLevelScene = require 'src.sublevels.sublevel_scene'
local SubLevelManager = require 'src.maps.systems.sublevel_manager'
local stateManager = StateManager:new()

-- Sistema de items
local ItemSystem = require 'src.item_systems.items.init'
local WorldItems = require 'src.item_systems.world_items'

-- Nuevos módulos de gameplay (esqueleto, sin efectos en comportamiento)
local RunState = require 'src.gameplay.run_state'
local GameDirector = require 'src.gameplay.game_director'
local PhaseSystem = require 'src.gameplay.phase_system'

-- Sistema de física Box2D
local PhysicsManager = require 'src.physics.physics_manager'

-- Estado del juego con semilla alfanumérica
local gameState = {
    currentSeed = SeedSystem.generate(),
    paused = false,
    loaded = false,  -- Nueva bandera para saber si el mundo está cargado
    isLoading = false,  -- Nueva bandera para estado de carga
    inventoryMode = "none",  -- none | ship | eva
    inventoryDebug = false
}

-- Sistema de luz eliminado (no se usaba)

-- Variables globales
_G.camera = nil
_G.showGrid = false
_G.physicsManager = nil
local player
local runState, gameDirector
local prevIsInEVA = false

-- Sistema de debug para biomas y sistemas avanzados
local biomeDebug = {
    enabled = false,
    showRegions = false,
    showInfluences = false,
    lastDebugUpdate = 0,
    testDistribution = false,
    showSystemStats = false,
    showPerformanceOverlay = false
}

-- Sistema de estadísticas avanzadas
local advancedStats = {
    enabled = false,
    updateInterval = 1.0,
    lastUpdate = 0,
    frameTimeHistory = {},
    maxHistorySize = 60
}

-- NUEVA FUNCIÓN: Cargar el mundo de forma asíncrona
local function loadWorld(updateProgress)
    local loadSteps = {}
    local currentStep = 1
    
    -- Definir todos los pasos de carga como funciones
    table.insert(loadSteps, function()
        -- Paso 1: Inicializar
        updateProgress("init", "Setting up game systems...")
        
        -- Configuración inicial de la ventana
        -- (Mover setTitle al Paso 2, para que use la seed final)
        love.window.setMode(1200, 800, {resizable = true})
        return true
    end)
    
    table.insert(loadSteps, function()
        -- Paso 2: Procesamiento de semilla
        updateProgress("seed", "Generating universe seed...")
        
        -- Inicializar semilla aleatoria real
        math.randomseed(os.time())
        gameState.currentSeed = SeedSystem.generate()
        love.window.setTitle("Space Roguelike - Enhanced Systems - Seed: " .. gameState.currentSeed)
        return true
    end)
    
    table.insert(loadSteps, function()
        -- Paso 3: Generar mapas de ruido
        updateProgress("perlin", "Creating noise patterns...")
        
        -- Este paso puede ser pesado, así que lo dividimos
        local mapInitSuccess = pcall(function() 
            Map.init(gameState.currentSeed)
        end)
        
        if not mapInitSuccess then
            print("Warning: Enhanced Map initialization had issues")
        end
        return true
    end)
    
    table.insert(loadSteps, function()
        -- Paso 4: Crear distribución de biomas
        updateProgress("biomes", "Distributing biomes across space...")
        
        -- El sistema de biomas ya se inicializa en Map.init, pero podemos hacer verificaciones adicionales
        if BiomeSystem then
            -- Precalcular algunas distribuciones
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
        -- Paso 5: Sistema de coordenadas
        updateProgress("coordinates", "Setting up infinite coordinate system...")
        
        -- Inicializar cámara con manejo de errores
        local success, cam = pcall(function() return Camera:new() end)
        if not success or not cam then
            error("Failed to initialize camera: " .. tostring(cam))
        end
        _G.camera = cam
        _G.camera:updateScreenDimensions()
        return true
    end)
    
    table.insert(loadSteps, function()
        -- Paso 6: Gestor de chunks
        updateProgress("chunks", "Initializing chunk management...")
        
        -- ChunkManager ya se inicializa en Map.init, pero podemos preparar el pool
        if ChunkManager and ChunkManager.state then
            updateProgress("chunks", "Creating chunk pool... 50%")
        end
        return true
    end)
    
    table.insert(loadSteps, function()
        -- Paso 7: Preparar renderizador
        updateProgress("renderer", "Preparing renderer and shaders...")
        
        -- Inicializar OptimizedRenderer (que inicializa ShaderManager)
        local rendererSuccess, rendererErr = pcall(function()
            OptimizedRenderer.init()
        end)
        
        if not rendererSuccess then
            print("Warning: OptimizedRenderer not available: " .. tostring(rendererErr))
        end
        
        -- Shader de anomalía gravitacional removido
        
        return true
    end)
    
    -- Pasos para generar chunks iniciales (dividido en múltiples pasos)
    local initialRadius = 3
    local chunkCount = 0
    local totalChunks = (initialRadius * 2 + 1) ^ 2
    
    for chunkY = -initialRadius, initialRadius do
        for chunkX = -initialRadius, initialRadius do
            local cx, cy = chunkX, chunkY  -- Capturar valores en closure
            table.insert(loadSteps, function()
                -- Paso 8+: Generar área inicial
                if Map.getChunk then
                    Map.getChunk(cx, cy, 0, 0)
                end
                chunkCount = chunkCount + 1
                local percent = math.floor((chunkCount / totalChunks) * 100)
                updateProgress("initial_chunks", string.format("Generating chunks... %d%%", percent))
                return true
            end)
        end
    end
    
    table.insert(loadSteps, function()
        -- Paso 9: Crear jugador y naves adicionales para testing
        updateProgress("player", "Creating player entity and test ships...")
        
        -- Crear jugador principal (Explorer) en el centro
        local playerX, playerY = 0, 0
        player = Naves:new(playerX, playerY, "EXPLORER")
        
        -- Crear naves adicionales de diferentes tipos para testing de persistencia
        -- Fighter a 500 unidades al este
        local fighterShip = Naves:new(playerX + 500, playerY, "FIGHTER")
        
        -- Cargo a 500 unidades al oeste
        local cargoShip = Naves:new(playerX - 500, playerY, "CARGO")
        
        -- Las naves se crean con inventarios vacíos para testing de persistencia
        -- Los items se pueden agregar manualmente durante el juego para probar la persistencia
        
        print("[TESTING] Naves creadas para testing de persistencia:")
        print("  Player (Explorer): ID", player.shipId, "en posición (0, 0)")
        print("  Fighter: ID", fighterShip.shipId, "en posición (500, 0)")
        print("  Cargo: ID", cargoShip.shipId, "en posición (-500, 0)")
        
        -- Configurar iluminación inicial
        if lighting then
            lighting.playerLight.x = playerX
            lighting.playerLight.y = playerY
        end
        return true
    end)
    
    table.insert(loadSteps, function()
        -- Paso 10: Inicializar sistemas de juego
        updateProgress("game_systems", "Initializing game systems...")
        
        -- Inicializar RunState y GameDirector
        runState = RunState:new({ seed = gameState.currentSeed })
        gameDirector = GameDirector:new(runState)
        
        -- Inicializar sistema de física Box2D
        _G.physicsManager = PhysicsManager:new()
        
        print("[MAIN DEBUG] Sistemas inicializados:")
        print("  runState:", runState and "CREADO" or "NIL")
        print("  gameDirector:", gameDirector and "CREADO" or "NIL")
        print("  physicsManager:", _G.physicsManager and "CREADO" or "NIL")
        
        return true
    end)
    
    table.insert(loadSteps, function()
        -- Paso 11: Cargar interfaz
        updateProgress("hud", "Loading user interface...")
        
        -- Inicializar HUD
        HUD.init(gameState, player, Map, gameDirector, runState)
        return true
    end)
    
    table.insert(loadSteps, function()
        -- Paso 12: Finalizar
        updateProgress("finalize", "Finalizing universe generation...")
        
        -- Últimas verificaciones y configuraciones
        print("=== SPACE ROGUELIKE ENHANCED LOADED ===")
        print("Alphanumeric Seed: " .. gameState.currentSeed)
        print("Numeric Seed: " .. SeedSystem.toNumeric(gameState.currentSeed))
        
        print("=== ENHANCED SYSTEMS ACTIVE ===")
        print("✓ Alphanumeric Seed System: 5 letters + 5 digits mixed")
        print("✓ Natural Biome Distribution: Improved Perlin noise mapping")
        print("✓ Coordinate System: Relative coordinates for infinite exploration")
        print("✓ Chunk Manager: Dynamic loading with pooling and prioritization")
        print("✓ Optimized Renderer: LOD, frustum culling, adaptive quality")
        print("✓ Enhanced Performance: Batch rendering and memory optimization")
        
        -- Marcar como cargado
        gameState.loaded = true
        gameState.isLoading = false
        return true
    end)
    
    -- Ejecutar pasos uno por uno
    return function()
        if currentStep <= #loadSteps then
            loadSteps[currentStep]()
            currentStep = currentStep + 1
            return currentStep > #loadSteps
        end
        return true
    end
end

function love.load(args)

    
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Inicializar FullscreenManager después de configurar los filtros
    if FullscreenManager and FullscreenManager.init then
        FullscreenManager.init()
    end
    
    -- Inicializar pantalla de carga
    LoadingScreen.init()
    
    -- Inicializar sistema de items
    if ItemSystem and ItemSystem.initialize then
        ItemSystem.initialize()
        print("[MAIN] Sistema de items inicializado")
    end
    
    -- Inicializar InventoryUI
    if InventoryUI and InventoryUI.init then
        InventoryUI:init()
    end
    
    if EVAInventoryUI and EVAInventoryUI.init then
        EVAInventoryUI:init()
    end
    
    -- Comenzar proceso de carga con la función creadora de iterador
    gameState.isLoading = true
    LoadingScreen.start(loadWorld, function()
        -- Callback cuando termina la carga
        print("=== LOADING COMPLETE ===")
        print("Welcome to the universe!")
        
        -- Los sistemas ya fueron inicializados durante la carga
        print("[MAIN DEBUG] Sistemas ya disponibles:")
        print("  runState:", runState and "DISPONIBLE" or "NIL")
        print("  gameDirector:", gameDirector and "DISPONIBLE" or "NIL")
    end)
end

function love.update(dt)
    -- Si está cargando, actualizar pantalla de carga
    if gameState.isLoading then
        LoadingScreen.update(dt)
        return
    end
    
    -- Si no está cargado, no actualizar nada más
    if not gameState.loaded then
        return
    end
    
    -- Pausar el juego si es necesario
    if gameState.paused then return end
    
    -- Limitar delta time para evitar saltos grandes
    dt = math.min(dt or 1/60, 1/30)

    -- Actualizar gestor de estados; si hay estado bloqueante, detener gameplay
    if stateManager then
        stateManager:update(dt)
        if stateManager:blocksUnderlying() then
            return
        end
    end

    -- Actualizar RunState y GameDirector (no-op por ahora)
    if runState then runState:update(dt) end
    if gameDirector then gameDirector:update(dt) end

    -- Actualizar sistema de física Box2D
    if _G.physicsManager then
        _G.physicsManager:update(dt)
    end

    -- Actualizar estadísticas avanzadas
    updateAdvancedStats(dt)
    
    -- Actualizar cámara (necesario para zoom y optimizaciones)
    if _G.camera and _G.camera.update then
        _G.camera:update(dt)
    end
    
    -- Actualizar HUD (incluye tracking de biomas)
    if HUD and HUD.update then
        HUD.update(dt)
    end
    
    -- Actualizar InventoryUI
    if InventoryUI and InventoryUI.update then
        InventoryUI:update(dt, player)
    end
    
    -- Actualizar EVAInventoryUI
    if EVAInventoryUI and EVAInventoryUI.update and player and player.isInEVA and player.evaPlayer then
        EVAInventoryUI:update(dt, player.evaPlayer)
    end

    -- Forzar exclusividad de inventarios según modo EVA (cierre automático)
    if player then
        -- Detectar transición de EVA y cerrar inventarios + resetear modo
        if prevIsInEVA ~= player.isInEVA then
            if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
                if InventoryUI.close then InventoryUI:close() else InventoryUI:toggle() end
            end
            if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
                if EVAInventoryUI.close then EVAInventoryUI:close() else EVAInventoryUI:toggle() end
            end
            gameState.inventoryMode = "none"
            if gameState.inventoryDebug then print("[INV] EVA transition -> mode=none, inventories closed") end
            prevIsInEVA = player.isInEVA
        end

        -- Exclusividad según estado EVA
        if player.isInEVA then
            if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
                if InventoryUI.close then InventoryUI:close() else InventoryUI:toggle() end
            end
        else
            if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
                if EVAInventoryUI.close then EVAInventoryUI:close() else EVAInventoryUI:toggle() end
            end
        end

        -- Sincronizar modo en base a estado real de las UIs
        local computed = "none"
        if not player.isInEVA and InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
            computed = "ship"
        end
        if player.isInEVA and EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
            computed = "eva"
        end
        if computed ~= gameState.inventoryMode then
            gameState.inventoryMode = computed
            if gameState.inventoryDebug then print("[INV] Sync mode -> mode=" .. gameState.inventoryMode) end
        end
    end

    -- Actualizar jugador
        if player and type(player.update) == "function" then
            local success, err = pcall(function() player:update(dt) end)
            if not success then
                print("Error updating player:", err)
            end
            
            -- Conectar estado de boost del jugador con GameDirector
            if gameDirector and player.isBoostActive ~= nil then
                gameDirector:setPlayerBoosting(player.isBoostActive)
            end
        end
    
    -- Obtener velocidad del jugador para precarga direccional
    local playerVelX, playerVelY = 0, 0
    if player then
        playerVelX = player.dx or 0
        playerVelY = player.dy or 0
    end
    
    -- Actualizar sistema de mapas mejorado con velocidad
    if player and player.x and player.y then
        Map.update(dt, player.x, player.y, playerVelX, playerVelY)
    end
    
    -- Actualizar optimizaciones de pantalla completa en ChunkManager
    if ChunkManager and ChunkManager.updateFullscreenOptimizations then
        local isFullscreen = false
        if FullscreenManager and FullscreenManager.isFullscreen then
            isFullscreen = FullscreenManager.isFullscreen()
        end
        ChunkManager.updateFullscreenOptimizations(isFullscreen, _G.camera)
    end
    
    -- Actualizar OptimizedRenderer con precarga incremental
    if type(OptimizedRenderer) == "table" and OptimizedRenderer.update then
        OptimizedRenderer.update(dt, player and player.x or 0, player and player.y or 0, _G.camera)
    end
    
    -- Actualizar cámara para seguir la entidad activa (nave o EVA player)
    if _G.camera and type(_G.camera.follow) == "function" then
        local success, err = pcall(function()
            local activeEntity = player:getActiveEntity()
            _G.camera:follow(activeEntity, dt)
        end)
        if not success then
            print("Error updating camera:", err)
        end
    end
    
    -- Sistema de luz eliminado
    
    -- Actualizar debug de biomas y sistemas
    if biomeDebug.enabled and player then
        local currentTime = love.timer.getTime()
        if currentTime - biomeDebug.lastDebugUpdate >= 1.0 then  -- Cada segundo
            local biomeInfo = BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
            if biomeInfo then
                print("=== ENHANCED BIOME DEBUG ===")
                print("Current Biome: " .. biomeInfo.name .. " (" .. biomeInfo.rarity .. ")")
                print("Chunk: (" .. biomeInfo.coordinates.chunk.x .. ", " .. biomeInfo.coordinates.chunk.y .. ")")
                print("Weight: " .. string.format("%.1f%%", biomeInfo.config.spawnWeight * 100))
                
                -- Mostrar estadísticas del sistema de coordenadas
                local coordStats = CoordinateSystem.getStats()
                print("Coordinate Sector: (" .. coordStats.currentSector.x .. ", " .. coordStats.currentSector.y .. ")")
                print("Relocations: " .. coordStats.relocations)
                
                -- Mostrar estadísticas de chunks
                local chunkStats = ChunkManager.getStats()
                print("Chunks - Active: " .. chunkStats.active .. ", Cached: " .. chunkStats.cached .. ", Pool: " .. chunkStats.pooled)
                
                -- Mostrar estadísticas de renderizado
                if biomeDebug.showSystemStats then
                    local rendererStats = OptimizedRenderer.getStats()
                    print("Renderer - FPS: " .. rendererStats.performance.fps .. 
                          ", Objects: " .. rendererStats.rendering.objectsRendered ..
                          ", Culled: " .. string.format("%.1f%%", rendererStats.rendering.cullingEfficiency))
                end
                
                -- Debug específico de semillas
                print("Seed Debug - Alpha: " .. gameState.currentSeed .. 
                      ", Numeric: " .. SeedSystem.toNumeric(gameState.currentSeed))
            end
            biomeDebug.lastDebugUpdate = currentTime
        end
    end
    
    -- Test automático de distribución de biomas
    if biomeDebug.testDistribution then
        local currentTime = love.timer.getTime()
        if currentTime - biomeDebug.lastDebugUpdate >= 10.0 then  -- Cada 10 segundos
            print("=== AUTOMATIC DISTRIBUTION TEST ===")
            BiomeSystem.debugDistribution(1000)
            biomeDebug.lastDebugUpdate = currentTime
        end
    end
    
    -- Actualizar dimensiones de la cámara en caso de redimensionamiento
    if _G.camera then
        _G.camera:updateScreenDimensions()
    end
    
    -- Actualizar items en el mundo
    WorldItems.update(dt)
end

function love.draw()
    -- Si está mostrando la pantalla de carga, solo dibujar eso
    if gameState.isLoading or not gameState.loaded then
        LoadingScreen.draw()
        return
    end
    
    -- Si hay un estado bloqueante activo, solo dibujar estados
    if stateManager and stateManager:blocksUnderlying() then
        love.graphics.clear(0, 0, 0, 1)
        stateManager:draw()
        return
    end

    -- Aplicar transformación de cámara
    if _G.camera then
        _G.camera:apply()
    end
    
    -- Dibujar el mapa usando el sistema mejorado
    Map.draw(_G.camera)
    
    -- Dibujar debug de biomas si está activado
    if biomeDebug.enabled and biomeDebug.showRegions then
        drawBiomeRegionDebug()
    end
    
    -- Dibujar el jugador
    if player then
        player:draw()
    end
    
    -- Dibujar items en el mundo
    local playerX, playerY = 0, 0
    if player then
        local activeEntity = player:getActiveEntity()
        if activeEntity then
            playerX, playerY = activeEntity.x or 0, activeEntity.y or 0
        end
    end
    WorldItems.draw(_G.camera, playerX, playerY)
    
    -- Dibujar sistema de física Box2D (proyectiles, efectos, debug)
    if physicsManager then
        physicsManager:drawDebug()
    end
    
    -- Efectos de iluminación eliminados
    
    -- Restaurar transformación de cámara
    if _G.camera then
        _G.camera:unapply()
    end
    
    -- Verificar si algún inventario está abierto
    local inventoryOpen = (InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen()) or 
                         (EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen())
    
    -- Dibujar HUD (no afectado por la cámara)
    -- Pasar información de estado del inventario al HUD
    HUD.draw(inventoryOpen)
    
    -- Dibujar InventoryUI (no afectado por la cámara) - se dibuja después del HUD para estar encima
    if InventoryUI and InventoryUI.draw then
        InventoryUI:draw(player)
    end
    
    -- Dibujar EVAInventoryUI (no afectado por la cámara)
    if EVAInventoryUI and EVAInventoryUI.draw and player and player.isInEVA and player.evaPlayer then
        EVAInventoryUI:draw(player.evaPlayer)
    end
    
    -- Dibujar información de debug de biomas y sistemas en pantalla
    if biomeDebug.enabled then
        drawBiomeDebugOverlay()
    end
    
    -- Dibujar overlay de performance si está activado
    if biomeDebug.showPerformanceOverlay or advancedStats.enabled then
        drawPerformanceOverlay()
    end

    -- Dibujar estados superpuestos (overlays)
    if stateManager then
        stateManager:draw()
    end
end

-- Cache para estadísticas avanzadas
local advancedStatsCache = {
    lastFPSUpdate = 0,
    lastMemoryUpdate = 0,
    fpsUpdateInterval = 0.5, -- Actualizar FPS cada 500ms
    memoryUpdateInterval = 2.0, -- Actualizar memoria cada 2s
    cachedAvgFPS = 0,
    cachedMemory = 0,
    cachedFrameTime = 0
}

-- Actualizar estadísticas avanzadas optimizado
function updateAdvancedStats(dt)
    local currentTime = love.timer.getTime()
    
    -- Agregar tiempo de frame actual al historial (solo si es necesario)
    if currentTime - advancedStatsCache.lastFPSUpdate >= advancedStatsCache.fpsUpdateInterval then
        table.insert(advancedStats.frameTimeHistory, dt)
        if #advancedStats.frameTimeHistory > advancedStats.maxHistorySize then
            table.remove(advancedStats.frameTimeHistory, 1)
        end
        
        -- Calcular FPS promedio y cachear
        local avgFrameTime = 0
        for _, frameTime in ipairs(advancedStats.frameTimeHistory) do
            avgFrameTime = avgFrameTime + frameTime
        end
        advancedStatsCache.cachedFrameTime = avgFrameTime / #advancedStats.frameTimeHistory
        advancedStatsCache.cachedAvgFPS = math.floor(1 / advancedStatsCache.cachedFrameTime)
        advancedStatsCache.lastFPSUpdate = currentTime
    end
    
    -- Actualizar memoria menos frecuentemente
    if currentTime - advancedStatsCache.lastMemoryUpdate >= advancedStatsCache.memoryUpdateInterval then
        advancedStatsCache.cachedMemory = collectgarbage("count")
        advancedStatsCache.lastMemoryUpdate = currentTime
    end
    
    -- Actualizar estadísticas cada intervalo (usando valores cacheados)
    if currentTime - advancedStats.lastUpdate >= advancedStats.updateInterval then
        advancedStats.lastUpdate = currentTime
        
        if advancedStats.enabled then
            print("=== ADVANCED STATS UPDATE ===")
            print("Avg FPS: " .. advancedStatsCache.cachedAvgFPS)
            print("Frame Time: " .. string.format("%.2f", advancedStatsCache.cachedFrameTime * 1000) .. "ms")
            print("Current Seed: " .. gameState.currentSeed)
            print("Memory: " .. string.format("%.1f", advancedStatsCache.cachedMemory / 1024) .. "MB")
        end
    end
end

-- Cache para el overlay de performance
local performanceCache = {
    lastUpdate = 0,
    updateInterval = 0.1, -- Actualizar cada 100ms
    cachedStats = nil,
    stringCache = {}
}

-- Dibujar overlay de performance optimizado
function drawPerformanceOverlay()
    if not gameState.loaded then return end
    
    local currentTime = love.timer.getTime()
    local r, g, b, a = love.graphics.getColor()
    
    -- Panel de performance en la esquina inferior izquierda
    local panelWidth = 300
    local panelHeight = 180  -- Más alto para información de semilla
    local x = 10
    local y = love.graphics.getHeight() - panelHeight - 10
    
    -- Fondo semi-transparente
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(0, 1, 1, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Título
    love.graphics.setColor(0, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("PERFORMANCE MONITOR", x + 10, y + 8)
    
    -- Información en tiempo real
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(10))
    
    local infoY = y + 25
    
    -- Información de semilla
    love.graphics.setColor(1, 1, 0.5, 1)
    love.graphics.print("Seed: " .. gameState.currentSeed, x + 10, infoY)
    infoY = infoY + 12
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Numeric: " .. SeedSystem.toNumeric(gameState.currentSeed), x + 10, infoY)
    infoY = infoY + 15
    
    -- FPS actual
    local currentFPS = love.timer.getFPS()
    local fpsColor = currentFPS >= 55 and {0, 1, 0, 1} or currentFPS >= 30 and {1, 1, 0, 1} or {1, 0, 0, 1}
    love.graphics.setColor(fpsColor)
    love.graphics.print("FPS: " .. currentFPS, x + 10, infoY)
    infoY = infoY + 12
    
    -- Estadísticas del renderizador (con cache)
    local rendererStats
    if currentTime - performanceCache.lastUpdate >= performanceCache.updateInterval then
        rendererStats = OptimizedRenderer.getStats()
        performanceCache.cachedStats = rendererStats
        performanceCache.lastUpdate = currentTime
        
        -- Cache de strings formateados
        performanceCache.stringCache.frameTime = "Frame Time: " .. string.format("%.1f", rendererStats.performance.frameTime) .. "ms"
        performanceCache.stringCache.drawCalls = "Draw Calls: " .. rendererStats.performance.drawCalls
        performanceCache.stringCache.objectsRendered = "Objects Rendered: " .. rendererStats.rendering.objectsRendered
        performanceCache.stringCache.cullingEff = "Culling Efficiency: " .. string.format("%.1f%%", rendererStats.rendering.cullingEfficiency)
        performanceCache.stringCache.qualityLevel = "Quality Level: " .. string.format("%.1f%%", rendererStats.quality.current * 100)
    else
        rendererStats = performanceCache.cachedStats or OptimizedRenderer.getStats()
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(performanceCache.stringCache.frameTime or "Frame Time: N/A", x + 10, infoY)
    infoY = infoY + 12
    love.graphics.print(performanceCache.stringCache.drawCalls or "Draw Calls: N/A", x + 10, infoY)
    infoY = infoY + 12
    love.graphics.print(performanceCache.stringCache.objectsRendered or "Objects Rendered: N/A", x + 10, infoY)
    infoY = infoY + 12
    
    -- Eficiencia de culling con color (optimizado)
    local cullingEff = rendererStats.rendering.cullingEfficiency
    local cullingColor = cullingEff >= 80 and {0, 1, 0, 1} or cullingEff >= 60 and {1, 1, 0, 1} or {1, 0, 0, 1}
    love.graphics.setColor(cullingColor)
    love.graphics.print(performanceCache.stringCache.cullingEff or "Culling Efficiency: N/A", x + 10, infoY)
    infoY = infoY + 12
    
    -- Calidad adaptativa
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(performanceCache.stringCache.qualityLevel or "Quality Level: N/A", x + 10, infoY)
    infoY = infoY + 12
    
    -- Memoria
    local memoryMB = collectgarbage("count") / 1024
    local memoryColor = memoryMB < 100 and {0, 1, 0, 1} or memoryMB < 200 and {1, 1, 0, 1} or {1, 0, 0, 1}
    love.graphics.setColor(memoryColor)
    love.graphics.print("Memory: " .. string.format("%.1f", memoryMB) .. "MB", x + 10, infoY)
    
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar overlay de debug de biomas (MEJORADO CON INFORMACIÓN DE SEMILLA)
function drawBiomeDebugOverlay()
    if not player or not gameState.loaded then return end
    
    local r, g, b, a = love.graphics.getColor()
    
    -- Panel de debug en la esquina superior derecha (expandido)
    local panelWidth = 420
    local panelHeight = 320  -- Más alto para información de semilla
    local x = love.graphics.getWidth() - panelWidth - 10
    local y = HUD.isBiomeInfoVisible() and 220 or 10
    
    -- Fondo
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Título
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("ENHANCED SYSTEM DEBUG", x + 10, y + 8)
    
    local infoY = y + 25
    
    -- Información de semilla
    love.graphics.setColor(1, 0.8, 0.5, 1)
    love.graphics.setFont(love.graphics.newFont(10))
    love.graphics.print("SEED SYSTEM", x + 10, infoY)
    infoY = infoY + 12
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Alpha: " .. gameState.currentSeed, x + 10, infoY)
    infoY = infoY + 12
    love.graphics.print("Numeric: " .. SeedSystem.toNumeric(gameState.currentSeed), x + 10, infoY)
    infoY = infoY + 15
    
    -- Información detallada de biomas
    local biomeInfo = BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
    if biomeInfo then
        love.graphics.setColor(0.8, 1, 0.8, 1)
        love.graphics.print("CURRENT BIOME", x + 10, infoY)
        infoY = infoY + 12
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Name: " .. biomeInfo.name, x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Rarity: " .. biomeInfo.rarity, x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Target Weight: " .. string.format("%.1f%%", biomeInfo.config.spawnWeight * 100), x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Threshold: " .. string.format("%.3f", biomeInfo.config.noiseThreshold), x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Position: (" .. math.floor(player.x) .. ", " .. math.floor(player.y) .. ")", x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Chunk: (" .. biomeInfo.coordinates.chunk.x .. ", " .. biomeInfo.coordinates.chunk.y .. ")", x + 10, infoY)
        infoY = infoY + 15
        
        -- NUEVO: Información del sistema de coordenadas
        local coordStats = CoordinateSystem.getStats()
        love.graphics.setColor(0.8, 1, 1, 1)
        love.graphics.print("COORDINATE SYSTEM", x + 10, infoY)
        infoY = infoY + 12
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Sector: (" .. coordStats.currentSector.x .. ", " .. coordStats.currentSector.y .. ")", x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Relocations: " .. coordStats.relocations, x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Since Last: " .. string.format("%.1f", coordStats.timeSinceLastRelocation) .. "s", x + 10, infoY)
        infoY = infoY + 15
        
        -- NUEVO: Información del gestor de chunks
        local chunkStats = ChunkManager.getStats()
        love.graphics.setColor(1, 0.8, 1, 1)
        love.graphics.print("CHUNK MANAGER", x + 10, infoY)
        infoY = infoY + 12
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Active: " .. chunkStats.active .. " | Cached: " .. chunkStats.cached .. " | Pool: " .. chunkStats.pooled, x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Load Queue: " .. chunkStats.loadQueue .. " | Hit Ratio: " .. string.format("%.1f%%", chunkStats.cacheHitRatio * 100), x + 10, infoY)
        infoY = infoY + 15
        
        -- Estadísticas de cambios de bioma
        local biomeAdvancedStats = BiomeSystem.getAdvancedStats()
        if biomeAdvancedStats and biomeAdvancedStats.playerStats then
            love.graphics.setColor(0.8, 1, 0.8, 1)
            love.graphics.print("EXPLORATION STATS", x + 10, infoY)
            infoY = infoY + 12
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("Biome Changes: " .. biomeAdvancedStats.playerStats.biomeChanges, x + 10, infoY)
            infoY = infoY + 12
            love.graphics.print("Chunks Generated: " .. biomeAdvancedStats.totalChunksGenerated, x + 10, infoY)
        end
        
        -- Indicador de test automático
        if biomeDebug.testDistribution then
            love.graphics.setColor(1, 0.5, 1, 1)
            love.graphics.print("AUTO-TESTING ENABLED", x + 10, y + panelHeight - 15)
        end
        
        -- NUEVO: Indicadores de sistemas avanzados activos
        love.graphics.setColor(0.5, 1, 0.5, 1)
        love.graphics.print("Enhanced: ✓ Seeds ✓ Biomes ✓ Coords ✓ Chunks ✓ Render", x + 10, y + panelHeight - 28)
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar debug de regiones de biomas (actualizado)
function drawBiomeRegionDebug()
    if not _G.camera or not player or not gameState.loaded then return end
    
    local r, g, b, a = love.graphics.getColor()
    
    -- Usar el sistema mejorado para obtener chunks visibles
    local visibleChunks, chunkInfo = ChunkManager.getVisibleChunks(_G.camera)
    
    -- Dibujar bordes de chunks con información de bioma
    love.graphics.setColor(1, 1, 0, 0.5)
    
    local chunkSize = Map.chunkSize * Map.tileSize
    
    for _, chunk in ipairs(visibleChunks) do
        if chunk.biome then
            local worldX = chunk.x * chunkSize
            local worldY = chunk.y * chunkSize
            
            -- Convertir a coordenadas relativas para renderizado
            local relX, relY = CoordinateSystem.worldToRelative(worldX, worldY)
            local camRelX, camRelY = CoordinateSystem.worldToRelative(_G.camera.x, _G.camera.y)
            
            local screenX = (relX - camRelX) * _G.camera.zoom + love.graphics.getWidth() / 2
            local screenY = (relY - camRelY) * _G.camera.zoom + love.graphics.getHeight() / 2
            local screenSize = chunkSize * _G.camera.zoom
            
            -- Dibujar borde del chunk
            love.graphics.rectangle("line", screenX, screenY, screenSize, screenSize)
            
            -- Color del bioma
            local config = chunk.biome.config
            love.graphics.setColor(config.color[1] + 0.3, config.color[2] + 0.3, config.color[3] + 0.3, 0.7)
            love.graphics.circle("fill", screenX + screenSize/2, screenY + screenSize/2, 10)
            
            -- Texto del bioma (solo si zoom permite legibilidad)
            if _G.camera.zoom > 0.5 then
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.printf(config.name:sub(1, 8), screenX + 5, screenY + 5, screenSize - 10, "center")
            end
        end
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Función de efectos de iluminación eliminada

function love.keypressed(key)
    -- No procesar teclas durante la carga
    if gameState.isLoading or not gameState.loaded then
        -- Solo permitir salir durante la carga
        if key == "escape" then
            love.event.quit()
        end
        -- Permitir también toggle de pantalla completa durante la carga
        if key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) then
            if FullscreenManager and FullscreenManager.toggle then
                FullscreenManager.toggle()
            end
        elseif key == "f11" then
            if FullscreenManager and FullscreenManager.toggle then
                FullscreenManager.toggle()
            end
        end
        return
    end

    -- Delegar primero al gestor de estados
    if stateManager and stateManager:keypressed(key) then
        return
    end

    -- Atajos globales para pantalla completa
    if key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) then
        if FullscreenManager and FullscreenManager.toggle then
            FullscreenManager.toggle()
            return
        end
    elseif key == "f11" then
        -- Reasignamos F11 al toggle de pantalla completa; movemos la función previa a F10+Shift
        if FullscreenManager and FullscreenManager.toggle then
            FullscreenManager.toggle()
            return
        end
    end

    -- Manejar input de semilla si el HUD lo está mostrando
    if HUD.isSeedInputVisible() then
        local newSeed, seedType = HUD.handleSeedInput(key)
        if newSeed then
            -- Asegurar cierre del panel antes de regenerar
            HUD.hideSeedInput()
            changeSeed(newSeed)
        end
        return
    end
    
    -- Controles generales
    if key == "escape" then
        love.event.quit()
    elseif key == "f1" then
        HUD.toggleInfo()
    elseif key == "f2" then
        HUD.showSeedInput()
    elseif key == "f3" then
        if player and player.stats then
            local enabled = player.stats:toggleDebugMode()
            print("Debug mode: " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "f4" then
        _G.showGrid = not _G.showGrid
        print("Enhanced grid display: " .. (_G.showGrid and "ON" or "OFF"))
    elseif key == "f5" then
        HUD.toggleDebugMenu()
    elseif key == "1" then
        -- Crear inventario de prueba con items del sistema
        if player and InventoryUI then
            InventoryUI:createTestInventory(player)
            -- Inventario de prueba creado
        end
    elseif key == "f6" then
        -- Toggle del overlay de performance (antes: daño de prueba)
        biomeDebug.showPerformanceOverlay = not biomeDebug.showPerformanceOverlay
        print("Performance overlay: " .. (biomeDebug.showPerformanceOverlay and "ON" or "OFF"))
    elseif key == "f7" then
        if Map.starConfig then
            Map.starConfig.enhancedEffects = not Map.starConfig.enhancedEffects
            local status = Map.starConfig.enhancedEffects and "ON" or "OFF"
            print("Enhanced star effects: " .. status)
        end
    elseif key == "f8" then
        if Map.starConfig then
            local currentMax = Map.starConfig.maxStarsPerFrame
            if currentMax <= 1500 then
                Map.starConfig.maxStarsPerFrame = 3000
                print("Star quality: MEDIUM (3000 stars/frame)")
            elseif currentMax <= 3000 then
                Map.starConfig.maxStarsPerFrame = 5000
                print("Star quality: HIGH (5000 stars/frame)")
            else
                Map.starConfig.maxStarsPerFrame = 1500
                print("Star quality: LOW (1500 stars/frame)")
            end
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
    -- NOTE: F11 ahora se usa para alternar pantalla completa. Si se requiere el antiguo 'Fast shield regen', reasignarlo a otra tecla.
    -- elseif key == "f11" then
    --     if player and player.stats then
    --         local enabled = player.stats:toggleFastRegen()
    --         print("Fast shield regen: " .. (enabled and "ON" or "OFF"))
    --     end
    elseif key == "m" then
        -- Debug del PassiveManager
        local PassiveManager = require 'src.item_systems.passive_manager'
        PassiveManager.printDebugInfo()
    elseif key == "f12" then
        HUD.toggleBiomeInfo()
    elseif key == "f" then
        -- Regenerar con semilla completamente nueva
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            -- Ctrl+F: Force garbage collection
            if biomeDebug.enabled then
                print("=== MANUAL MEMORY CLEANUP ===")
                local beforeMB = collectgarbage("count") / 1024
                collectgarbage("collect")
                local afterMB = collectgarbage("count") / 1024
                print("Memory before: " .. string.format("%.1f", beforeMB) .. "MB")
                print("Memory after: " .. string.format("%.1f", afterMB) .. "MB")
                print("Freed: " .. string.format("%.1f", beforeMB - afterMB) .. "MB")
            end
        else
            -- Regenerar mundo con nueva semilla
            local newSeed = SeedSystem.generate()
            changeSeedWithLoading(newSeed)
        end
    elseif key == "r" then
        -- Reload weapon
        if player and player.weaponSystem then
            player.weaponSystem:reload()
        end
    elseif key == "p" then
        gameState.paused = not gameState.paused
        print("Game " .. (gameState.paused and "PAUSED" or "RESUMED"))
    elseif key == "h" then
        if player and player.stats then
            player:heal(2)
            print("Player healed")
        end
    elseif key == "u" then
        if player and player.stats then
            player:addFuel(25)
            print("Fuel added")
        end
    elseif key == "e" then
        -- Manejo de expansión de fases
        pcall(function()
            if PhaseSystem and PhaseSystem.handleInput then
                PhaseSystem.handleInput(key)
            end
        end)
    elseif key == "tab" then
        -- Control centralizado de inventarios basado en inventoryMode y estado EVA
        if not player then return end
        local desired = player.isInEVA and "eva" or "ship"
        if gameState.inventoryMode == desired then
            -- Cerrar el inventario actual
            if desired == "ship" then
                if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
                    if InventoryUI.close then InventoryUI:close() else InventoryUI:toggle() end
                end
            else
                if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
                    if EVAInventoryUI.close then EVAInventoryUI:close() else EVAInventoryUI:toggle() end
                end
            end
            gameState.inventoryMode = "none"
            if gameState.inventoryDebug then print("[INV] Close via Tab -> mode=none") end
        else
            -- Cerrar el contrario y abrir el deseado
            if desired == "ship" then
                if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
                    if EVAInventoryUI.close then EVAInventoryUI:close() else EVAInventoryUI:toggle() end
                end
                if InventoryUI then InventoryUI:toggle() end
                gameState.inventoryMode = "ship"
            else
                if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
                    if InventoryUI.close then InventoryUI:close() else InventoryUI:toggle() end
                end
                if EVAInventoryUI then EVAInventoryUI:toggle() end
                gameState.inventoryMode = "eva"
            end
            if gameState.inventoryDebug then print("[INV] Open via Tab -> mode=" .. gameState.inventoryMode) end
        end
    end
    
    -- Manejar teclas específicas del inventario EVA cuando está abierto
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() and player and player.isInEVA and player.evaPlayer then
        EVAInventoryUI:keypressed(key, player.evaPlayer)
    end
    
    -- Manejar teclas específicas del inventario de la nave cuando está abierto
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() and player and not player.isInEVA then
        InventoryUI:keypressed(key, player)
    end
    -- Para testear en grandes distancias
    if key == "0" then
        if player and player.toggleHyperTravel then
            local enabled = player:toggleHyperTravel(100000)
            print("Hyper travel (100k): " .. (enabled and "ON" or "OFF"))
        end
    elseif key == "k" then
        -- Toggle entre shaders de estrellas: Legacy (StarShader) vs Instanced (StarfieldInstanced)
        if Map and Map.starConfig then
            Map.starConfig.useInstancedShader = not Map.starConfig.useInstancedShader
            local modeName = Map.starConfig.useInstancedShader and "INSTANCED" or "LEGACY"
            print("Star rendering mode: " .. modeName)
            if Map.starConfig.useInstancedShader then
                -- Asegurar que el shader instanced esté inicializado
                local StarfieldInstanced = require 'src.shaders.starfield_instanced'
                if StarfieldInstanced and StarfieldInstanced.init then
                    StarfieldInstanced.init()
                end
            end
        end
    elseif key == "e" and (not stateManager or not stateManager:blocksUnderlying()) then
        -- Intentar recolectar item manualmente
        local WorldItems = require 'src.item_systems.world_items'
        local collected = WorldItems.tryManualCollection()
        
        -- Si no se recolectó ningún item, intentar entrar a estación
        if not collected then
            -- Entrar a estación si existe una cercana en Ancient Ruins
        if player and player.x and player.y then
            local biomeInfo = BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
            if biomeInfo and biomeInfo.type == BiomeSystem.BiomeType.ANCIENT_RUINS then
                -- Buscar estación cercana en los chunks visibles
                local bounds = Map.getVisibleChunkBounds(_G.camera, 800)
                local closest, minDist
                for cy = bounds.startY, bounds.endY do
                    for cx = bounds.startX, bounds.endX do
                        local chunk = Map.getChunkNonBlocking(cx, cy)
                        if chunk and chunk.ancientRuinsPlaceholders then
                            for _, ph in ipairs(chunk.ancientRuinsPlaceholders) do
                                local dx, dy = ph.x - player.x, ph.y - player.y
                                local dist = math.sqrt(dx*dx + dy*dy)
                                if not minDist or dist < minDist then
                                    closest, minDist = ph, dist
                                end
                            end
                        end
                    end
                end
                local factor = HUD.getEnterRadiusFactor()
                local allowed = HUD.computeEnterRadius(closest, factor)
                if closest and (not minDist or minDist <= allowed) then
                    local scene = StationScene:new(closest)
                    stateManager:push(scene, { suspendUnderlying = true, fadeDuration = 0.25 })
                else
                    print("No hay estación cercana para entrar.")
                end
            end
        end
        end -- Cerrar el bloque if not collected

    elseif key == "u" then
        -- Entrar a escena de subnivel (mapa limitado) de prueba
        local SeedSystem = require 'src.utils.seed_system'
        local currentSeed = gameState.currentSeed
        local px, py = 0, 0
        if player and player.x and player.y then px, py = player.x, player.y end
        local cfg = SubLevelManager.createConfig({
            parentSeed = currentSeed,
            type = SubLevelManager.Types.Generic,
            cx = math.floor(px / (Map.stride or 1)),
            cy = math.floor(py / (Map.stride or 1)),
            width = 8, height = 8,
            entryX = 0, entryY = 0,
        })
        local scene = SubLevelScene:new(cfg)
        stateManager:push(scene, { suspendUnderlying = true, fadeDuration = 0.25 })
    end
end

function love.textinput(text)
    if not gameState.loaded then return end
    if stateManager and stateManager:textinput(text) then return end
    HUD.textinput(text)
end

function love.wheelmoved(x, y)
    if not gameState.loaded then return end
    if stateManager and stateManager:wheelmoved(x, y) then return end
    if _G.camera and _G.camera.wheelmoved then
        _G.camera:wheelmoved(x, y)
    end
end

-- NUEVA FUNCIÓN: Cambiar semilla con pantalla de carga
function changeSeedWithLoading(newSeed)
    -- Validar la nueva semilla
    if not SeedSystem.validate(newSeed) then
        print("Invalid seed format. Using default seed.")
        newSeed = "A1B2C3D4E5"  -- Default seed
    end
    
    gameState.currentSeed = newSeed
    gameState.loaded = false
    gameState.isLoading = true
    
    -- Cerrar inventarios si están abiertos
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        if InventoryUI.close then InventoryUI:close() else InventoryUI:toggle() end
    end
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
        if EVAInventoryUI.close then EVAInventoryUI:close() else EVAInventoryUI:toggle() end
    end
    gameState.inventoryMode = "none"
    
    -- Limpiar todos los estados (salir de estaciones, etc.)
    if stateManager and stateManager.clear then
        stateManager:clear()
        -- Estados limpiados - jugador fuera de estaciones
    end
    
    -- Limpiar recursos existentes
    if ChunkManager and ChunkManager.cleanup then
        ChunkManager.cleanup()
    end
    
    -- Limpiar efectos pasivos y items pasivos
    local PassiveManager = require 'src.item_systems.passive_manager'
    PassiveManager.reset()
    
    -- También limpiar items pasivos del inventario para evitar que se vuelvan a aplicar
    if player and player.inventory and player.inventory.compartments and player.inventory.compartments.passives then
        local passiveComp = player.inventory.compartments.passives
        if passiveComp and passiveComp.items then
            for i = 1, passiveComp.maxSlots do
                if passiveComp.items[i] then
                    -- Usar el método apropiado para remover items pasivos (aunque ya se hizo reset)
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
    
    -- Comenzar nueva carga usando la función creadora de iterador
    LoadingScreen.start(loadWorld, function()
        print("New world generated with seed: " .. newSeed)
        -- Sincronizar estado de la run y director con la nueva semilla (no-op visual)
        if runState and runState.reset then
            runState:reset(newSeed)
        else
            runState = RunState:new({ seed = newSeed })
        end
        if gameDirector and gameDirector.reset then
            gameDirector:reset()
            if gameDirector.setRunState then gameDirector:setRunState(runState) end
        else
            gameDirector = GameDirector:new(runState)
        end
    end)
end

function changeSeed(newSeed)
    -- Validar la nueva semilla
    if not SeedSystem.validate(newSeed) then
        print("Invalid seed format. Using default seed.")
        newSeed = "A1B2C3D4E5"  -- Default seed
    end
    
    gameState.currentSeed = newSeed
    
    love.window.setTitle("Space Roguelike - Enhanced Systems - Seed: " .. newSeed)
    regenerateMap(newSeed)
    print("New enhanced galaxy generated with seed: " .. newSeed)
    print("Numeric equivalent: " .. SeedSystem.toNumeric(newSeed))
end

function regenerateMap(seed)
    -- Cerrar inventarios si están abiertos
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        if InventoryUI.close then InventoryUI:close() else InventoryUI:toggle() end
    end
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
        if EVAInventoryUI.close then EVAInventoryUI:close() else EVAInventoryUI:toggle() end
    end
    gameState.inventoryMode = "none"
    
    -- Limpiar efectos pasivos y items pasivos antes de regenerar
    local PassiveManager = require 'src.item_systems.passive_manager'
    PassiveManager.reset()
    
    -- También limpiar items pasivos del inventario para evitar que se vuelvan a aplicar
    if player and player.inventory and player.inventory.compartments and player.inventory.compartments.passives then
        local passiveComp = player.inventory.compartments.passives
        if passiveComp and passiveComp.items then
            for i = 1, passiveComp.maxSlots do
                if passiveComp.items[i] then
                    -- Usar el método apropiado para remover items pasivos (aunque ya se hizo reset)
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
    
    -- Regenerar mapa con nueva semilla usando el sistema mejorado
    Map.regenerate(seed)
    
    -- Reposicionar jugador al centro
    if player then
        -- Forzar salida del modo EVA si está activo
        if player.isInEVA and player.exitEVA then
            player:exitEVA()
            -- Forced exit from EVA mode during world regeneration
        end
        
        player.x = 0
        player.y = 0
        player.dx = 0
        player.dy = 0
        
        -- Reset player stats
        if player.stats then
            player.stats.health.currentHealth = player.stats.health.maxHealth
            player.stats.shield.currentShield = player.stats.shield.maxShield
            player.stats.fuel.currentFuel = player.stats.fuel.maxFuel
            player.stats:updateHeartDisplay()
        end
    end
    
    -- Recentrar cámara
    if _G.camera then
        _G.camera:setPosition(0, 0)
    end
    
    -- Reinicializar sistema de coordenadas desde el origen
    CoordinateSystem.init(0, 0)
    
    -- Actualizar referencias del HUD
    HUD.updateReferences(gameState, player, Map, gameDirector, runState)
    
    print("=== NEW ENHANCED GALAXY GENERATED ===")
    print("Alphanumeric Seed: " .. seed)
    print("Numeric Seed: " .. SeedSystem.toNumeric(seed))
end

function love.mousepressed(x, y, button)
    if not gameState.loaded then return end
    
    -- Delegar primero al gestor de estados
    if stateManager and stateManager.mousepressed and stateManager:mousepressed(x, y, button) then
        return
    end
    
    -- Manejar input del inventario EVA
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() and player and player.isInEVA and player.evaPlayer then
        EVAInventoryUI:mousepressed(x, y, button, player.evaPlayer)
        return
    end
    
    -- Manejar input del inventario de la nave
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        InventoryUI:mousepressed(x, y, button, player)
        return
    end
    
    -- Manejar disparo con clic izquierdo (solo si no hay inventarios abiertos)
    if button == 1 and player and not player.isInEVA then -- Clic izquierdo y no en EVA
        player:shoot(x, y)
    end
end

function love.mousereleased(x, y, button)
    if not gameState.loaded then return end
    
    -- Delegar primero al gestor de estados
    if stateManager and stateManager.mousereleased and stateManager:mousereleased(x, y, button) then
        return
    end
    
    -- Manejar input del inventario
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        InventoryUI:mousereleased(x, y, button, player)
    end
end

function love.resize(w, h)
    -- Delegar primero al gestor de estados
    if stateManager then stateManager:resize(w, h) end

    -- Notificar al FullscreenManager sobre el redimensionamiento
    if FullscreenManager and FullscreenManager.handleResize then
        FullscreenManager.handleResize(w, h)
    end
    
    if _G.camera then
        _G.camera:updateScreenDimensions()
    end

    -- Actualizar dimensiones de pantalla para el culling optimizado
    if Map and Map.updateScreenDimensions then
        Map.updateScreenDimensions()
    end

    -- Actualizar pantalla de carga si está activa
    if LoadingScreen then
        LoadingScreen.resize(w, h)
    end
end