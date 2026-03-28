local HUD = require('src.ui.hud.core')

-- Referencia privada al World context
local _world = nil

-- Inicialización del HUD
function HUD.init(worldOrGameState, playerRef, mapRef, gameDirectorRef, runStateRef)
    HUD.hudState.font = love.graphics.newFont(13)
    HUD.hudState.smallFont = love.graphics.newFont(11)
    HUD.hudState.tinyFont = love.graphics.newFont(9)

    -- Detectar si se llama con World o con refs sueltas (compatibilidad)
    if worldOrGameState and type(worldOrGameState.get) == 'function' then
        -- Nueva API: HUD.init(World)
        _world = worldOrGameState
        HUD.gameState    = _world.get('state')
        HUD.player       = _world.getPlayer()
        HUD.Map          = _world.getMap()
        HUD.gameDirector = _world.getDirector()
        HUD.runState     = _world.getRunState()
    else
        -- API legada: HUD.init(gameState, player, Map, gameDirector, runState)
        HUD.gameState    = worldOrGameState
        HUD.player       = playerRef
        HUD.Map          = mapRef
        HUD.gameDirector = gameDirectorRef
        HUD.runState     = runStateRef
    end

    print("[HUD DEBUG] Referencias recibidas:")
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
        print("HUD: BiomeSystem loaded successfully")
    else
        print("HUD: BiomeSystem not available")
    end

    for i, preset in ipairs(HUD.presetSeeds) do
        if preset.name == "Random" then
            preset.seed = HUD.SeedSystem.generate()
        end
    end

    local WeaponHUD = require 'src.ui.weapon_hud'
    WeaponHUD:init()

    print("Enhanced HUD system initialized with alphanumeric seed support")
end

-- Actualización principal del HUD
function HUD.update(dt)
    local currentTime = love.timer.getTime()

    if HUD.hudState.performance.enableCaching then
        if currentTime - HUD.hudState.renderCache.lastUpdate >= HUD.hudState.renderCache.updateInterval then
            HUD.updateCachedData()
            HUD.hudState.renderCache.lastUpdate = currentTime
        end
    end

    HUD.updateBiomeInfo(dt)

    local WeaponHUD = require 'src.ui.weapon_hud'
    WeaponHUD:update(dt)

    if HUD.hudState.stationHint and HUD.hudState.stationHint.enabled then
        HUD.updateStationHint(dt)
    end
end

-- Actualizar datos en cache
function HUD.updateCachedData()
    HUD.hudState.renderCache.dirtyFlags.stats = true
    HUD.hudState.renderCache.dirtyFlags.biome = true
    HUD.hudState.renderCache.dirtyFlags.player = true
end

-- Actualizar información de bioma del jugador
function HUD.updateBiomeInfo(dt)
    local currentTime = love.timer.getTime()

    if currentTime - HUD.biomeCache.lastUpdate >= HUD.biomeCache.updateInterval then
        HUD.biomeCache.debugInfo = {
            playerExists = HUD.player ~= nil,
            playerHasCoords = HUD.player and HUD.player.x and HUD.player.y,
            biomeSystemExists = HUD.BiomeSystem ~= nil,
            updatePlayerBiomeExists = HUD.BiomeSystem and HUD.BiomeSystem.updatePlayerBiome ~= nil,
            getPlayerBiomeInfoExists = HUD.BiomeSystem and HUD.BiomeSystem.getPlayerBiomeInfo ~= nil,
            playerCoords = HUD.player and {x = HUD.player.x, y = HUD.player.y} or nil
        }

        if HUD.player and HUD.player.x and HUD.player.y and HUD.BiomeSystem then
            local success, biomeInfo = pcall(function()
                if HUD.BiomeSystem.getPlayerBiomeInfo then
                    return HUD.BiomeSystem.getPlayerBiomeInfo(HUD.player.x, HUD.player.y)
                end
                return nil
            end)

            if success and biomeInfo then
                HUD.biomeCache.currentBiomeInfo = biomeInfo
                HUD.biomeCache.currentBiome = biomeInfo.type
                HUD.biomeCache.lastSuccessfulUpdate = currentTime

                if #HUD.biomeCache.biomeHistory == 0 or HUD.biomeCache.biomeHistory[1].biome ~= biomeInfo.type then
                    table.insert(HUD.biomeCache.biomeHistory, 1, {
                        biome = biomeInfo.type,
                        name = biomeInfo.name,
                        time = currentTime,
                        config = biomeInfo.config
                    })

                    if #HUD.biomeCache.biomeHistory > HUD.biomeCache.maxHistory then
                        table.remove(HUD.biomeCache.biomeHistory)
                    end
                end
            else
                HUD.biomeCache.lastError = "Failed to get biome info"
            end
        else
            HUD.biomeCache.lastError = "Missing dependencies"
        end

        HUD.biomeCache.lastUpdate = currentTime
    end
end

return HUD