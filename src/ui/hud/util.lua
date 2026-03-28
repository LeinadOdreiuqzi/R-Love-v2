local HUD = require('src.ui.hud.core')

function HUD.updateReferences(worldOrGameState, playerRef, mapRef, gameDirectorRef, runStateRef)
    -- Acepta el World context (nueva API) o refs sueltas (API legada)
    if worldOrGameState and type(worldOrGameState.get) == 'function' then
        local w = worldOrGameState
        HUD.gameState    = w.get('state')
        HUD.player       = w.getPlayer()
        HUD.Map          = w.getMap()
        HUD.gameDirector = w.getDirector()
        HUD.runState     = w.getRunState()
    else
        HUD.gameState    = worldOrGameState or HUD.gameState
        HUD.player       = playerRef       or HUD.player
        HUD.Map          = mapRef          or HUD.Map
        HUD.gameDirector = gameDirectorRef or HUD.gameDirector
        HUD.runState     = runStateRef     or HUD.runState
    end

    print("[HUD DEBUG] updateReferences llamado:")
    print("  gameState:", HUD.gameState and "OK" or "NIL")
    print("  player:", HUD.player and "OK" or "NIL")
    print("  Map:", HUD.Map and "OK" or "NIL")
    print("  gameDirector:", HUD.gameDirector and "OK" or "NIL")
    print("  runState:", HUD.runState and "OK" or "NIL")

    local success, biomeSystemModule = pcall(function()
        return require 'src.maps.biome_system'
    end)

    if success then
        HUD.BiomeSystem = biomeSystemModule
    end

    HUD.biomeCache = {
        lastUpdate = 0,
        updateInterval = 0.5,
        currentBiome = nil,
        biomeHistory = {},
        maxHistory = 10
    }
end

function HUD.getBiomeHistory()
    return HUD.biomeCache.biomeHistory
end

function HUD.getSeedSystem()
    return HUD.SeedSystem
end

return HUD