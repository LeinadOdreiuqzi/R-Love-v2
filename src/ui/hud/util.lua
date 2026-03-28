local HUD = require('src.ui.hud.core')

function HUD.updateReferences(worldOrGameState, playerRef, mapRef, gameDirectorRef, runStateRef)
    -- Acepta el World context (nueva API) o refs sueltas (API legada)
    if worldOrGameState and type(worldOrGameState.get) == 'function' then
        local w = worldOrGameState
        gameState    = w.get('state')
        player       = w.getPlayer()
        Map          = w.getMap()
        gameDirector = w.getDirector()
        runState     = w.getRunState()
    else
        gameState    = worldOrGameState or gameState
        player       = playerRef       or player
        Map          = mapRef          or Map
        gameDirector = gameDirectorRef or gameDirector
        runState     = runStateRef     or runState
    end

    print("[HUD DEBUG] updateReferences llamado:")
    print("  gameState:", gameState and "OK" or "NIL")
    print("  player:", player and "OK" or "NIL")
    print("  Map:", Map and "OK" or "NIL")
    print("  gameDirector:", gameDirector and "OK" or "NIL")
    print("  runState:", runState and "OK" or "NIL")

    local success, biomeSystemModule = pcall(function()
        return require 'src.maps.biome_system'
    end)

    if success then
        BiomeSystem = biomeSystemModule
    end

    biomeCache = {
        lastUpdate = 0,
        updateInterval = 0.5,
        currentBiome = nil,
        biomeHistory = {},
        maxHistory = 10
    }
end

function HUD.getBiomeHistory()
    return biomeCache.biomeHistory
end

function HUD.getSeedSystem()
    return SeedSystem
end

return HUD