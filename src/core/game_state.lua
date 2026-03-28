-- src/core/game_state.lua
-- Almacena el estado global estático y banderas de configuración
-- Desacoplado de main.lua

local SeedSystem = require 'src.utils.seed_system'

local GameState = {
    -- Estado principal
    state = {
        currentSeed = SeedSystem.generate(),
        paused = false,
        loaded = false,
        isLoading = false,
        inventoryMode = "none",  -- "none" | "ship" | "eva"
        inventoryDebug = false,
        showHUD = true,
        showGrid = false
    },
    
    -- Configuración física (Fixed Timestep)
    physics = {
        fixed_dt = 1/60,
        accumulator = 0
    },

    -- Sistema de depuración de biomas / sistema
    biomeDebug = {
        enabled = false,
        showRegions = false,
        showInfluences = false,
        lastDebugUpdate = 0,
        testDistribution = false,
        showSystemStats = false,
        showPerformanceOverlay = false
    },

    -- Estadísticas avanzadas generales
    advancedStats = {
        enabled = false,
        updateInterval = 1.0,
        lastUpdate = 0,
        frameTimeHistory = {},
        maxHistorySize = 60
    },

    -- Cache para estadísticas de rendimiento visual
    performanceCache = {
        lastUpdate = 0,
        updateInterval = 0.1,
        cachedStats = nil,
        stringCache = {}
    },
    
    -- Cache para cálculo de stats avanzados
    advancedStatsCache = {
        lastFPSUpdate = 0,
        lastMemoryUpdate = 0,
        fpsUpdateInterval = 0.5,
        memoryUpdateInterval = 2.0,
        cachedAvgFPS = 0,
        cachedMemory = 0,
        cachedFrameTime = 0
    }
}

return GameState
