local HUD = require('src.ui.hud.core')

-- Referencia privada al World context
local _world = nil

-- Inicialización del HUD
-- Acepta el World context (nuevo) O los argumentos sueltos antiguos (compat)
function HUD.init(worldOrGameState, playerRef, mapRef, gameDirectorRef, runStateRef)
    hudState.font = love.graphics.newFont(13)
    hudState.smallFont = love.graphics.newFont(11)
    hudState.tinyFont = love.graphics.newFont(9)

    -- Detectar si se llama con World o con refs sueltas (compatibilidad)
    if worldOrGameState and type(worldOrGameState.get) == 'function' then
        -- Nueva API: HUD.init(World)
        _world = worldOrGameState
        gameState    = _world.get('state')
        player       = _world.getPlayer()
        Map          = _world.getMap()
        gameDirector = _world.getDirector()
        runState     = _world.getRunState()
    else
        -- API legada: HUD.init(gameState, player, Map, gameDirector, runState)
        gameState    = worldOrGameState
        player       = playerRef
        Map          = mapRef
        gameDirector = gameDirectorRef
        runState     = runStateRef
    end

    print("[HUD DEBUG] Referencias recibidas:")
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
        print("HUD: BiomeSystem loaded successfully")
    else
        print("HUD: BiomeSystem not available")
    end

    for i, preset in ipairs(presetSeeds) do
        if preset.name == "Random" then
            preset.seed = SeedSystem.generate()
        end
    end

    WeaponHUD:init()

    print("Enhanced HUD system initialized with alphanumeric seed support")
end

-- Nota: HUD.updateReferences está definido en util.lua (cargado después, toma precedencia)

-- Actualización principal del HUD (idéntico al original)
function HUD.update(dt)
    local currentTime = love.timer.getTime()

    if hudState.performance.enableCaching then
        if currentTime - hudState.renderCache.lastUpdate >= hudState.renderCache.updateInterval then
            HUD.updateCachedData()
            hudState.renderCache.lastUpdate = currentTime
        end
    end

    HUD.updateBiomeInfo(dt)

    WeaponHUD:update(dt)

    if hudState.stationHint and hudState.stationHint.enabled then
        HUD.updateStationHint(dt)
    end
end

-- Actualizar datos en cache (idéntico al original)
function HUD.updateCachedData()
    hudState.renderCache.dirtyFlags.stats = true
    hudState.renderCache.dirtyFlags.biome = true
    hudState.renderCache.dirtyFlags.player = true
end

-- Actualizar información de bioma del jugador (idéntico al original)
function HUD.updateBiomeInfo(dt)
    local currentTime = love.timer.getTime()

    if currentTime - biomeCache.lastUpdate >= biomeCache.updateInterval then
        biomeCache.debugInfo = {
            playerExists = player ~= nil,
            playerHasCoords = player and player.x and player.y,
            biomeSystemExists = BiomeSystem ~= nil,
            updatePlayerBiomeExists = BiomeSystem and BiomeSystem.updatePlayerBiome ~= nil,
            getPlayerBiomeInfoExists = BiomeSystem and BiomeSystem.getPlayerBiomeInfo ~= nil,
            playerCoords = player and {x = player.x, y = player.y} or nil
        }

        if player and player.x and player.y and BiomeSystem then
            local success, biomeInfo = pcall(function()
                if BiomeSystem.getPlayerBiomeInfo then
                    return BiomeSystem.getPlayerBiomeInfo(player.x, player.y)
                end
                return nil
            end)

            if success and biomeInfo then
                biomeCache.currentBiomeInfo = biomeInfo
                biomeCache.currentBiome = biomeInfo.type
                biomeCache.lastSuccessfulUpdate = currentTime

                if #biomeCache.biomeHistory == 0 or biomeCache.biomeHistory[1].biome ~= biomeInfo.type then
                    table.insert(biomeCache.biomeHistory, 1, {
                        biome = biomeInfo.type,
                        name = biomeInfo.name,
                        time = currentTime,
                        config = biomeInfo.config
                    })

                    if #biomeCache.biomeHistory > biomeCache.maxHistory then
                        table.remove(biomeCache.biomeHistory)
                    end
                end
            else
                biomeCache.lastError = "Failed to get biome info"
            end
        else
            biomeCache.lastError = "Missing dependencies"
        end

        biomeCache.lastUpdate = currentTime
    end
end

return HUD