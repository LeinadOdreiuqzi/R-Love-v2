local HUD = require('src.ui.hud.core')

function HUD.updateReferences(gameStateRef, playerRef, mapRef, gameDirectorRef, runStateRef)
    gameState = gameStateRef
    player = playerRef
    Map = mapRef
    gameDirector = gameDirectorRef
    runState = runStateRef

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