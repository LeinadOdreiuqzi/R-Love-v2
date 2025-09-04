-- src/ui/hud.lua (VERSIÓN CON SOPORTE ALFANUMÉRICO)

local HUD = {}
local SeedSystem = require 'src.utils.seed_system'
local ChunkManager = require 'src.maps.chunk_manager'

-- Estado del HUD unificado con optimizaciones
local hudState = {
    showInfo = true,
    showSeedInput = false,
    showBiomeInfo = true,
    seedInputText = "",
    font = nil,
    smallFont = nil,
    tinyFont = nil,
    
    -- Cache de renderizado para optimización
    renderCache = {
        lastUpdate = 0,
        updateInterval = 0.1, -- Actualizar cada 100ms
        cachedStats = nil,
        cachedBiomeInfo = nil,
        dirtyFlags = {
            stats = true,
            biome = true,
            player = true
        }
    },
    
    -- Pool de strings para evitar concatenaciones frecuentes
    stringPool = {},
    
    -- Configuración de performance
    performance = {
        enableCaching = true,
        maxStringPoolSize = 50,
        reducedUpdateMode = false
    }
}

-- Sistema de semillas alfanuméricas integrado
local SeedSystem = {
    -- Caracteres permitidos
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    digits = "0123456789",
    
    -- Generar semilla alfanumérica (5 letras + 5 dígitos mezclados)
    generate = function()
        local chars = {}
        local letters = SeedSystem.letters
        local digits = SeedSystem.digits
        
        -- Agregar 5 letras aleatorias
        for i = 1, 5 do
            local randomIndex = math.random(1, #letters)
            table.insert(chars, letters:sub(randomIndex, randomIndex))
        end
        
        -- Agregar 5 dígitos aleatorios
        for i = 1, 5 do
            local randomIndex = math.random(1, #digits)
            table.insert(chars, digits:sub(randomIndex, randomIndex))
        end
        
        -- Mezclar los caracteres
        for i = #chars, 2, -1 do
            local j = math.random(i)
            chars[i], chars[j] = chars[j], chars[i]
        end
        
        return table.concat(chars)
    end,
    
    -- Validar semilla alfanumérica
    validate = function(seed)
        if type(seed) ~= "string" then
            return false
        end
        
        if #seed ~= 10 then
            return false
        end
        
        local letterCount = 0
        local digitCount = 0
        
        for i = 1, #seed do
            local char = seed:sub(i, i):upper()
            if char:match("[A-Z]") then
                letterCount = letterCount + 1
            elseif char:match("[0-9]") then
                digitCount = digitCount + 1
            else
                return false  -- Carácter inválido
            end
        end
        
        return letterCount == 5 and digitCount == 5
    end,
    
    -- Normalizar entrada de semilla
    normalize = function(input)
        if not input or input == "" then
            return SeedSystem.generate()
        end
        
        local normalized = tostring(input):upper()
        
        -- Si es una semilla alfanumérica válida, devolverla
        if SeedSystem.validate(normalized) then
            return normalized
        end
        
        -- Si es demasiado corta, completar
        if #normalized < 10 then
            -- Rellenar con caracteres aleatorios
            local remaining = 10 - #normalized
            for i = 1, remaining do
                if math.random() < 0.5 then
                    normalized = normalized .. SeedSystem.letters:sub(math.random(1, 26), math.random(1, 26))
                else
                    normalized = normalized .. SeedSystem.digits:sub(math.random(1, 10), math.random(1, 10))
                end
            end
        elseif #normalized > 10 then
            -- Truncar a 10 caracteres
            normalized = normalized:sub(1, 10)
        end
        
        -- Filtrar caracteres inválidos y reemplazar
        local cleanSeed = ""
        for i = 1, #normalized do
            local char = normalized:sub(i, i)
            if char:match("[A-Z0-9]") then
                cleanSeed = cleanSeed .. char
            else
                -- Reemplazar caracteres inválidos
                if math.random() < 0.5 then
                    cleanSeed = cleanSeed .. SeedSystem.letters:sub(math.random(1, 26), math.random(1, 26))
                else
                    cleanSeed = cleanSeed .. SeedSystem.digits:sub(math.random(1, 10), math.random(1, 10))
                end
            end
        end
        
        -- Asegurar balance de letras y números
        local letterCount = 0
        local digitCount = 0
        for i = 1, #cleanSeed do
            local char = cleanSeed:sub(i, i)
            if char:match("[A-Z]") then
                letterCount = letterCount + 1
            else
                digitCount = digitCount + 1
            end
        end
        
        -- Si está desbalanceado, regenerar
        if math.abs(letterCount - digitCount) > 2 then
            return SeedSystem.generate()
        end
        
        return cleanSeed
    end
}

-- Lista de semillas predefinidas alfanuméricas optimizadas
local presetSeeds = {
    {name = "Random", seed = SeedSystem.generate()},
    {name = "Dense Nebula", seed = "A5N9E3B7U1"},
    {name = "Open Void", seed = "S2P4A6C8E0"},
    {name = "Asteroid Fields", seed = "R3O7C9K2S6"},
    {name = "Ancient Mysteries", seed = "M1Y8S4T6I3"},
    {name = "Radiation Storm", seed = "H2A5Z9R3D7"},
    {name = "Crystal Caverns", seed = "C4R8Y1S5T9"},
    {name = "Quantum Rifts", seed = "Q3U6A7N2T4"},
    {name = "Lost Worlds", seed = "L6O1S4T9W3"},
    {name = "Deep Explorer", seed = "E2X8P5L7O9"}
}
local currentPresetIndex = 1

-- Referencias externas
local gameState = nil
local player = nil
local Map = nil
local BiomeSystem = nil

-- Cache de información de bioma del jugador
local biomeCache = {
    lastUpdate = 0,
    updateInterval = 0.5,
    currentBiome = nil,
    currentBiomeInfo = nil,
    biomeHistory = {},
    maxHistory = 10,
    debugInfo = nil,
    lastError = nil,
    lastSuccessfulUpdate = 0
}

-- Inicialización del HUD
function HUD.init(gameStateRef, playerRef, mapRef)
    -- Cargar fuentes de forma segura
    hudState.font = love.graphics.newFont(13)
    hudState.smallFont = love.graphics.newFont(11)
    hudState.tinyFont = love.graphics.newFont(9)
    
    -- Asignar referencias
    gameState = gameStateRef
    player = playerRef
    Map = mapRef
    
    -- Obtener referencia al sistema de biomas de forma segura
    local success, biomeSystemModule = pcall(function()
        return require 'src.maps.biome_system'
    end)
    
    if success then
        BiomeSystem = biomeSystemModule
        print("HUD: BiomeSystem loaded successfully")
    else
        print("HUD: BiomeSystem not available")
    end
    
    -- Regenerar semillas aleatorias en presets
    for i, preset in ipairs(presetSeeds) do
        if preset.name == "Random" then
            preset.seed = SeedSystem.generate()
        end
    end
    
    print("Enhanced HUD system initialized with alphanumeric seed support")
end

-- Función de actualización principal del HUD optimizada
function HUD.update(dt)
    local currentTime = love.timer.getTime()
    
    -- Actualizar cache solo cuando sea necesario
    if hudState.performance.enableCaching then
        if currentTime - hudState.renderCache.lastUpdate >= hudState.renderCache.updateInterval then
            HUD.updateCachedData()
            hudState.renderCache.lastUpdate = currentTime
        end
    end
    
    HUD.updateBiomeInfo(dt)
end

-- Nueva función para actualizar datos en cache
function HUD.updateCachedData()
    -- Marcar flags como dirty para forzar actualización
    hudState.renderCache.dirtyFlags.stats = true
    hudState.renderCache.dirtyFlags.biome = true
    hudState.renderCache.dirtyFlags.player = true
end

-- Actualizar información de bioma del jugador (SUPER SEGURO)
function HUD.updateBiomeInfo(dt)
    local currentTime = love.timer.getTime()
    
    if currentTime - biomeCache.lastUpdate >= biomeCache.updateInterval then
        -- Debug: verificar estado del sistema
        biomeCache.debugInfo = {
            playerExists = player ~= nil,
            playerHasCoords = player and player.x and player.y,
            biomeSystemExists = BiomeSystem ~= nil,
            updatePlayerBiomeExists = BiomeSystem and BiomeSystem.updatePlayerBiome ~= nil,
            getPlayerBiomeInfoExists = BiomeSystem and BiomeSystem.getPlayerBiomeInfo ~= nil,
            playerCoords = player and {x = player.x, y = player.y} or nil
        }
        
        -- Verificar que todo esté disponible antes de proceder
        if player and player.x and player.y and BiomeSystem then
            -- Intentar obtener información del bioma directamente
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
                
                -- Actualizar historial
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

-- Función de compatibilidad para estadísticas optimizada con cache
function HUD.getSafeStats()
    -- Usar cache si está disponible y no está dirty
    if hudState.performance.enableCaching and 
       hudState.renderCache.cachedStats and 
       not hudState.renderCache.dirtyFlags.stats then
        -- Actualizar solo FPS en tiempo real
        hudState.renderCache.cachedStats.fps = love.timer.getFPS()
        return hudState.renderCache.cachedStats
    end
    
    local stats = {
        loadedChunks = 0,
        cachedChunks = 0,
        seed = "UNKNOWN00",
        worldScale = 1,
        frameTime = 0,
        biomesActive = 0,
        fps = love.timer.getFPS(),
        renderStats = {
            totalObjects = 0,
            renderedObjects = 0,
            culledObjects = 0
        }
    }
    
    -- Obtener semilla actual de forma segura
    if gameState and gameState.currentSeed then
        stats.seed = gameState.currentSeed
    end
    
    -- Obtener información básica del Map de forma segura
    if Map then
        if Map.seed then stats.seed = Map.seed end
        if Map.worldScale then stats.worldScale = Map.worldScale end
        
        -- Intentar obtener estadísticas mejoradas
        local success, mapStats = pcall(function() 
            if Map.getStats then
                return Map.getStats() 
            end
            return nil
        end)
        
        if success and mapStats then
            -- Copiar estadísticas disponibles de forma segura
            if mapStats.chunks then
                stats.chunks = mapStats.chunks
                
                -- Agregar estadísticas de optimizaciones de pantalla completa
                local fsSuccess, fsStats = pcall(function()
                    if ChunkManager and ChunkManager.getFullscreenStats then
                        return ChunkManager.getFullscreenStats()
                    end
                    return nil
                end)
                
                if fsSuccess and fsStats then
                    stats.chunks.fullscreenOptimizations = fsStats
                end
            elseif mapStats.loadedChunks then
                stats.loadedChunks = mapStats.loadedChunks
            end
            
            if mapStats.rendering then
                stats.rendering = mapStats.rendering
            elseif mapStats.renderStats then
                stats.renderStats = mapStats.renderStats
            end
            
            if mapStats.coordinates then
                stats.coordinates = mapStats.coordinates
            end
            
            if mapStats.frameTime then stats.frameTime = mapStats.frameTime end
            if mapStats.biomesActive then stats.biomesActive = mapStats.biomesActive end
        else
            -- Fallback básico
            if Map.renderStats then 
                stats.renderStats = Map.renderStats
                stats.biomesActive = Map.renderStats.biomesActive or 0
            end
            
            -- Contar chunks de forma segura
            if Map.chunks then
                pcall(function()
                    for x, row in pairs(Map.chunks) do
                        for y, chunk in pairs(row) do
                            if chunk then stats.loadedChunks = stats.loadedChunks + 1 end
                        end
                    end
                end)
            end
        end
    end
    
    -- Guardar en cache si está habilitado
    if hudState.performance.enableCaching then
        hudState.renderCache.cachedStats = stats
        hudState.renderCache.dirtyFlags.stats = false
    end
    
    return stats
end

-- Calcular coordenadas de chunk de forma segura
function HUD.getSafeChunkCoords(worldX, worldY)
    local chunkX, chunkY = 0, 0
    
    if Map then
        -- Intentar usar la función del Map
        local success, cx, cy = pcall(function()
            if Map.getChunkInfo then
                return Map.getChunkInfo(worldX, worldY)
            end
            return nil, nil
        end)
        
        if success and cx and cy then
            return cx, cy
        end
        
        -- Calcular manualmente si es posible
        if Map.chunkSize and Map.tileSize then
            local chunkSize = Map.chunkSize * Map.tileSize
            chunkX = math.floor(worldX / chunkSize)
            chunkY = math.floor(worldY / chunkSize)
        end
    end
    
    return chunkX, chunkY
end

-- Dibujar todo el HUD
function HUD.draw()
    local r, g, b, a = love.graphics.getColor()
    
    -- Panel de información unificado
    if hudState.showInfo then
        HUD.drawUnifiedInfoPanel()
    end
    
    -- Panel de información de biomas
    if hudState.showBiomeInfo then
        HUD.drawBiomeInfoPanel()
    end
    
    -- Input de semilla alfanumérica
    if hudState.showSeedInput then
        HUD.drawSeedInput()
    end
    
    -- Información de la semilla actual (siempre visible)
    HUD.drawCurrentSeedInfo()
    
    -- HUD del jugador (barras de vida, escudo, combustible)
    if player and player.stats then
        HUD.drawPlayerHUD()
    end
    
    love.graphics.setColor(r, g, b, a)
end

-- Panel de información de biomas optimizado
function HUD.drawBiomeInfoPanel()
    if not player or not BiomeSystem then return end
    
    -- Cache optimizado de biomas cercanos
    local currentTime = love.timer.getTime()
    local scanInterval = hudState.performance.reducedUpdateMode and 2.0 or 1.0
    
    if not HUD.lastBiomeScan or currentTime - HUD.lastBiomeScan > scanInterval then
        -- Siempre actualizar con la posición actual del jugador
        HUD.nearbyBiomes = BiomeSystem.findNearbyBiomes(player.x, player.y, 10000)
        HUD.lastBiomeScan = currentTime
        
        -- Actualizar cache con la nueva información
        if hudState.performance.enableCaching then
            hudState.renderCache.cachedBiomeInfo = HUD.nearbyBiomes
        end
    end
    
    local panelWidth = 300
    local panelHeight = 200
    local x = love.graphics.getWidth() - panelWidth - 10
    local y = 10
    
    -- Fondo del panel
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(0.2, 0.6, 0.8, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Panel title with scan radius
    love.graphics.setColor(0.6, 0.9, 1, 1)
    love.graphics.setFont(hudState.font)
    love.graphics.print("BIOME SCANNER", x + 10, y + 8)
    
    -- Scan radius info
    love.graphics.setColor(0.7, 0.8, 1, 0.8)
    love.graphics.setFont(hudState.tinyFont)
    love.graphics.print("10km Radius", x + panelWidth - 60, y + 12)
    
    -- Separator line
    love.graphics.setColor(0.2, 0.6, 0.8, 0.8)
    love.graphics.line(x + 10, y + 28, x + panelWidth - 10, y + 28)
    
    -- Usar información del bioma desde el cache actualizado
    local biomeInfo = biomeCache.currentBiomeInfo
    
    -- Mostrar información de debug si hay problemas
    if biomeCache.debugInfo and not biomeInfo then
        love.graphics.setColor(1, 0.8, 0.2, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("DEBUG INFO:", x + 10, y + 35)
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(hudState.tinyFont)
        local debugY = y + 50
        
        love.graphics.print("Player exists: " .. tostring(biomeCache.debugInfo.playerExists), x + 15, debugY)
        debugY = debugY + 12
        love.graphics.print("Player coords: " .. tostring(biomeCache.debugInfo.playerHasCoords), x + 15, debugY)
        debugY = debugY + 12
        love.graphics.print("BiomeSystem: " .. tostring(biomeCache.debugInfo.biomeSystemExists), x + 15, debugY)
        debugY = debugY + 12
        love.graphics.print("getPlayerBiomeInfo: " .. tostring(biomeCache.debugInfo.getPlayerBiomeInfoExists), x + 15, debugY)
        debugY = debugY + 12
        
        if biomeCache.debugInfo.playerCoords then
            love.graphics.print(string.format("Coords: (%.1f, %.1f)", 
                biomeCache.debugInfo.playerCoords.x, biomeCache.debugInfo.playerCoords.y), x + 15, debugY)
            debugY = debugY + 12
        end
        
        if biomeCache.lastError then
            love.graphics.setColor(1, 0.5, 0.5, 1)
            love.graphics.print("Error: " .. biomeCache.lastError, x + 15, debugY)
        end
    end
    
    if biomeInfo then
        local infoY = y + 35
        local lineHeight = 12
        
        -- Nombre del bioma actual
        local biomeColor = biomeInfo.config.color or {0.5, 0.5, 0.5, 1}
        love.graphics.setColor(biomeColor[1] + 0.3, biomeColor[2] + 0.3, biomeColor[3] + 0.3, 1)
        love.graphics.setFont(hudState.font)
        love.graphics.print("▶ " .. (biomeInfo.name or "Unknown"), x + 10, infoY)
        infoY = infoY + lineHeight + 2
        
        -- Rareza del bioma
        local rarityColors = {
            ["Very Common"] = {0.7, 0.7, 0.7, 1},
            ["Common"] = {0.8, 0.8, 0.8, 1},
            ["Uncommon"] = {0.6, 0.9, 0.6, 1},
            ["Rare"] = {0.6, 0.6, 1, 1},
            ["Very Rare"] = {0.9, 0.6, 1, 1},
            ["Legendary"] = {1, 0.8, 0.2, 1}
        }
        
        local rarityColor = rarityColors[biomeInfo.rarity] or {1, 1, 1, 1}
        love.graphics.setColor(rarityColor)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("Rarity: " .. (biomeInfo.rarity or "Unknown"), x + 15, infoY)
        infoY = infoY + lineHeight
        
        -- Propiedades del bioma si están disponibles
        if biomeInfo.config and biomeInfo.config.properties then
            love.graphics.setColor(0.9, 0.9, 1, 1)
            love.graphics.print("PROPERTIES", x + 10, infoY)
            infoY = infoY + lineHeight + 2
            
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.setFont(hudState.tinyFont)
            
            local props = biomeInfo.config.properties
            love.graphics.print("Visibility: " .. string.format("%.1f", props.visibility or 1), x + 15, infoY)
            infoY = infoY + 10
            love.graphics.print("Mobility: " .. string.format("%.1f", props.mobility or 1), x + 15, infoY)
            infoY = infoY + 10
            love.graphics.print("Radiation: " .. string.format("%.1f", props.radiation or 0), x + 15, infoY)
            infoY = infoY + 10
            love.graphics.print("Gravity: " .. string.format("%.1f", props.gravity or 1), x + 15, infoY)
        end
        
        -- Coordenadas
        love.graphics.setColor(0.9, 1, 0.9, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("LOCATION", x + 10, y + panelHeight - 30)
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(hudState.tinyFont)
        if biomeInfo.coordinates and biomeInfo.coordinates.chunk then
            love.graphics.print("Chunk: (" .. biomeInfo.coordinates.chunk.x .. ", " .. biomeInfo.coordinates.chunk.y .. ")", x + 15, y + panelHeight - 15)
        end
        
        -- Nearby biomes list
        local listY = infoY + 5
        local maxListHeight = y + panelHeight - listY - 30
        local maxVisibleItems = math.floor(maxListHeight / 12)
        
        love.graphics.setColor(0.6, 0.9, 1, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("NEARBY BIOMES:", x + 10, listY)
        listY = listY + 15
        
        love.graphics.setFont(hudState.tinyFont)
        
        -- Show nearby biomes with distance (optimizado)
        local itemsToShow = math.min(#HUD.nearbyBiomes, maxVisibleItems)
        for i = 1, itemsToShow do
            local biome = HUD.nearbyBiomes[i]
            local distance = math.floor(biome.distance / 100) * 100
            
            -- Cache de strings para evitar concatenaciones frecuentes
            local stringKey = biome.name .. "_" .. distance
            local displayText = hudState.stringPool[stringKey]
            if not displayText then
                displayText = string.format("%s (%d m)", biome.name, distance)
                -- Limitar tamaño del pool
                if #hudState.stringPool < hudState.performance.maxStringPoolSize then
                    hudState.stringPool[stringKey] = displayText
                end
            end
            
            -- Optimizar cálculo de color
            local alpha = 1.0
            if distance > 8000 then
                alpha = 0.3 + 0.7 * (1 - math.min(1, (distance - 8000) / 2000))
            end
            
            love.graphics.setColor(0.8, 0.9, 1, alpha)
            love.graphics.print(displayText, x + 15, listY)
            listY = listY + 12
        end
        
        -- Show current chunk coordinates if available
        if biomeInfo.coordinates and biomeInfo.coordinates.chunk then
            love.graphics.setColor(0.6, 0.8, 0.6, 0.7)
            love.graphics.setFont(hudState.tinyFont)
            love.graphics.print(string.format("Chunk: (%d, %d)", 
                biomeInfo.coordinates.chunk.x, 
                biomeInfo.coordinates.chunk.y), 
                x + 10, y + panelHeight - 15)
        end
    else
        -- Error fallback
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.setFont(hudState.smallFont)
        love.graphics.print("Biome scanner offline", x + 10, y + 40)
        
        -- Still show nearby biomes if available
        if HUD.nearbyBiomes then
            love.graphics.setColor(0.8, 0.4, 0.4, 1)
            love.graphics.setFont(hudState.tinyFont)
            love.graphics.print("Last known biomes:", x + 10, y + 60)
            
            for i = 1, math.min(#HUD.nearbyBiomes, 3) do
                local biome = HUD.nearbyBiomes[i]
                local distance = math.floor(biome.distance / 100) * 100
                love.graphics.print(string.format("%s (%d m)", biome.name, distance), 
                                  x + 20, y + 75 + (i-1)*12)
            end
        end
    end
end

-- Panel de información principal (ACTUALIZADO PARA SEMILLAS ALFANUMÉRICAS)
function HUD.drawUnifiedInfoPanel()
    local panelWidth = 360
    local panelHeight = 500
    local x = 10
    local y = 10
    
    -- Fondo del panel
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(0.3, 0.5, 0.7, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    -- Título del panel
    love.graphics.setColor(0.7, 0.9, 1, 1)
    love.graphics.setFont(hudState.font)
    love.graphics.print("ENHANCED SPACE EXPLORER", x + 10, y + 8)
    
    -- Línea separadora
    love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
    love.graphics.line(x + 10, y + 28, x + panelWidth - 10, y + 28)
    
    -- Información del jugador
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.smallFont)
    
    local posX = math.floor(player.x or 0)
    local posY = math.floor(player.y or 0)
    local speed = math.sqrt((player.dx or 0)^2 + (player.dy or 0)^2)
    
    -- CORREGIDO: Calcular chunk de forma segura
    local chunkX, chunkY = HUD.getSafeChunkCoords(posX, posY)
    
    -- CORREGIDO: Usar función de compatibilidad para estadísticas
    local stats = HUD.getSafeStats()
    
    local infoY = y + 35
    local lineHeight = 12
    
    -- Información de semilla alfanumérica
    love.graphics.setColor(1, 1, 0.6, 1)
    love.graphics.print("GALAXY SEED", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Current: " .. (stats.seed or "UNKNOWN00"), x + 15, infoY)
    infoY = infoY + lineHeight
    
    -- Validación de semilla
    local seedStatus = SeedSystem.validate(stats.seed) and "Valid" or "Legacy"
    local seedColor = SeedSystem.validate(stats.seed) and {0.6, 1, 0.6, 1} or {1, 0.8, 0.4, 1}
    love.graphics.setColor(seedColor)
    love.graphics.print("Status: " .. seedStatus, x + 15, infoY)
    infoY = infoY + lineHeight + 5
    
    -- Información del jugador
    love.graphics.setColor(0.9, 0.9, 1, 1)
    love.graphics.print("PLAYER STATUS", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Position: (" .. posX .. ", " .. posY .. ")", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("Speed: " .. math.floor(speed) .. " u/s", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("Chunk: (" .. chunkX .. ", " .. chunkY .. ")", x + 15, infoY)
    infoY = infoY + lineHeight + 5
    
    -- Estadísticas de biomas si están disponibles
    if BiomeSystem then
        love.graphics.setColor(1, 0.9, 0.6, 1)
        love.graphics.print("BIOME EXPLORATION", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        local success, biomeStats = pcall(function()
            if BiomeSystem.getAdvancedStats then
                return BiomeSystem.getAdvancedStats()
            end
            return nil
        end)
        
        if success and biomeStats and biomeStats.playerStats then
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.print("Biome Changes: " .. (biomeStats.playerStats.biomeChanges or 0), x + 15, infoY)
            infoY = infoY + lineHeight
            love.graphics.print("Chunks Generated: " .. (biomeStats.totalChunksGenerated or 0), x + 15, infoY)
            infoY = infoY + lineHeight
            
            if biomeStats.playerStats.currentBiome and BiomeSystem.getBiomeConfig then
                local configSuccess, currentConfig = pcall(function()
                    return BiomeSystem.getBiomeConfig(biomeStats.playerStats.currentBiome)
                end)
                if configSuccess and currentConfig then
                    love.graphics.print("Current: " .. currentConfig.name, x + 15, infoY)
                else
                    love.graphics.print("Current: Unknown Biome", x + 15, infoY)
                end
            else
                love.graphics.print("Current: Scanning...", x + 15, infoY)
            end
            infoY = infoY + lineHeight + 5
        else
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.print("Biome data loading...", x + 15, infoY)
            infoY = infoY + lineHeight + 5
        end
    end
    
    -- Información del sistema
    love.graphics.setColor(0.9, 1, 0.9, 1)
    love.graphics.print("SYSTEM INFO", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("FPS: " .. stats.fps, x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("Zoom: " .. string.format("%.1f", _G.camera and _G.camera.zoom or 1), x + 15, infoY)
    infoY = infoY + lineHeight
    local budgetMs = ((stats.chunks and stats.chunks.generationBudget) or 0) * 1000
    local loadQueueLen = (stats.chunks and stats.chunks.loadQueue) or 0
    love.graphics.print(string.format("Chunk Budget: %.2f ms | Load Queue: %d", budgetMs, loadQueueLen), x + 15, infoY)
    infoY = infoY + lineHeight
    
    -- Información de chunks
    local chunkInfo = "N/A"
    if stats.chunks and stats.chunks.active and stats.chunks.cached then
        chunkInfo = stats.chunks.active .. "/" .. stats.chunks.cached
    elseif stats.loadedChunks then
        chunkInfo = tostring(stats.loadedChunks)
    end
    love.graphics.print("Chunks: " .. chunkInfo, x + 15, infoY)
    infoY = infoY + lineHeight
    
    -- Grid status
    if _G.showGrid then
        love.graphics.setColor(0.8, 1, 0.8, 1)
        love.graphics.print("Grid: ON", x + 15, infoY)
    else
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("Grid: OFF", x + 15, infoY)
    end
    infoY = infoY + lineHeight
    
    -- Estadísticas de renderizado si están disponibles
    local renderStats = stats.rendering or stats.renderStats
    if renderStats and renderStats.totalObjects and renderStats.totalObjects > 0 then
        local efficiency = 0
        if renderStats.culledObjects and renderStats.totalObjects > 0 then
            efficiency = (renderStats.culledObjects / renderStats.totalObjects * 100)
        end
        
        love.graphics.print("Objects: " .. (renderStats.renderedObjects or 0) .. "/" .. renderStats.totalObjects, x + 15, infoY)
        infoY = infoY + lineHeight
        
        if efficiency > 0 then
            love.graphics.print("Culling: " .. string.format("%.1f%%", efficiency), x + 15, infoY)
            infoY = infoY + lineHeight
        end
        
        if renderStats.biomesActive and renderStats.biomesActive > 0 then
            love.graphics.print("Active Biomes: " .. renderStats.biomesActive, x + 15, infoY)
            infoY = infoY + lineHeight
        end
    end
    
    -- Información de sistemas mejorados si están disponibles
    if stats.chunks or stats.coordinates then
        love.graphics.setColor(0.8, 1, 0.8, 1)
        love.graphics.print("ENHANCED SYSTEMS", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        
        if stats.chunks and stats.chunks.pooled then
            love.graphics.print("Pool: " .. stats.chunks.pooled .. " available", x + 15, infoY)
            infoY = infoY + lineHeight
        end
        
        if stats.chunks and stats.chunks.cacheHitRatio then
            love.graphics.print("Cache Hit: " .. string.format("%.1f%%", stats.chunks.cacheHitRatio * 100), x + 15, infoY)
            infoY = infoY + lineHeight
        end
        
        if stats.coordinates and stats.coordinates.relocations then
            love.graphics.print("Coord Relocations: " .. stats.coordinates.relocations, x + 15, infoY)
            infoY = infoY + lineHeight
        end
        
        -- Información de optimizaciones de pantalla completa
        if stats.chunks and stats.chunks.fullscreenOptimizations then
            local fsStats = stats.chunks.fullscreenOptimizations
            local modeText = fsStats.isFullscreen and "Fullscreen" or "Windowed"
            local optimizationColor = fsStats.isFullscreen and {0.8, 1, 0.8, 1} or {0.8, 0.8, 0.8, 1}
            
            love.graphics.setColor(optimizationColor)
            love.graphics.print("Mode: " .. modeText, x + 15, infoY)
            infoY = infoY + lineHeight
            
            if fsStats.isFullscreen then
                love.graphics.print("FS Optimizations: " .. fsStats.optimizationsApplied, x + 15, infoY)
                infoY = infoY + lineHeight
                
                if fsStats.aggressiveUnloads and fsStats.aggressiveUnloads > 0 then
                    love.graphics.print("Chunks Unloaded: " .. fsStats.aggressiveUnloads, x + 15, infoY)
                    infoY = infoY + lineHeight
                end
                
                if fsStats.maxActiveReduced then
                    love.graphics.print("Active Limit: Reduced", x + 15, infoY)
                    infoY = infoY + lineHeight
                end
            end
        end
        
        infoY = infoY + 5
    end
    
    -- SECCIÓN DE DEBUG
    if player and player.stats and player.stats.debug and player.stats.debug.enabled then
        infoY = infoY + 5
        love.graphics.setColor(1, 1, 0.4, 1)
        love.graphics.print("DEBUG MODE", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        local invulnStatus = player.stats.debug.invulnerable and "ON" or "OFF"
        love.graphics.print("Invulnerability: " .. invulnStatus, x + 15, infoY)
        infoY = infoY + lineHeight
        
        local fuelStatus = player.stats.debug.infiniteFuel and "ON" or "OFF"
        love.graphics.print("Infinite Fuel: " .. fuelStatus, x + 15, infoY)
        infoY = infoY + lineHeight
        
        local regenStatus = player.stats.debug.fastRegen and "ON" or "OFF"
        love.graphics.print("Fast Regen: " .. regenStatus, x + 15, infoY)
        infoY = infoY + lineHeight + 10
    end
    
    -- Controles básicos
    love.graphics.setColor(1, 1, 0.8, 1)
    love.graphics.print("CONTROLS", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("WASD + Mouse: Move & Aim", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("Shift: Brake | Wheel: Zoom", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("F1: Info | F2: Seed | F12: Biomes", x + 15, infoY)
    infoY = infoY + lineHeight
    love.graphics.print("F6: Performance | R: New Galaxy", x + 15, infoY)
end

-- Input de semilla alfanumérica (COMPLETAMENTE NUEVO)
function HUD.drawSeedInput()
    local panelWidth = 500
    local panelHeight = 400
    local x = (love.graphics.getWidth() - panelWidth) / 2
    local y = (love.graphics.getHeight() - panelHeight) / 2
    
    -- Fondo
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    -- Borde
    love.graphics.setColor(0.5, 0.7, 0.9, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.font)
    
    -- Título
    love.graphics.print("NEW ENHANCED GALAXY SEED", x + 20, y + 20)
    
    -- Información sobre semillas alfanuméricas
    love.graphics.setFont(hudState.smallFont)
    love.graphics.setColor(0.8, 0.8, 1, 1)
    love.graphics.print("Alphanumeric Seeds: 5 letters + 5 digits mixed (e.g., A5B9C2D7E1)", x + 20, y + 45)
    love.graphics.print("36^10 = 3.6 trillion possible galaxies!", x + 20, y + 60)
    
    -- Semillas predefinidas
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Quick Select (Arrow Keys + Enter):", x + 20, y + 85)
    
    for i, preset in ipairs(presetSeeds) do
        local color = (i == currentPresetIndex) and {1, 1, 0.3, 1} or {0.8, 0.8, 0.8, 1}
        local prefix = (i == currentPresetIndex) and "> " or "  "
        
        love.graphics.setColor(color)
        love.graphics.print(prefix .. preset.name .. " (" .. preset.seed .. ")", x + 30, y + 100 + i * 15)
    end
    
    -- Input manual
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Custom Seed (10 characters: 5 letters + 5 digits):", x + 20, y + 280)
    
    -- Campo de input
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x + 20, y + 300, 460, 25)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.rectangle("line", x + 20, y + 300, 460, 25)
    
    -- Mostrar texto de entrada
    love.graphics.setColor(1, 1, 1, 1)
    local displayText = hudState.seedInputText:upper()
    love.graphics.print(displayText, x + 25, y + 305)
    
    -- Cursor parpadeante
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        local textWidth = hudState.font:getWidth(displayText)
        love.graphics.line(x + 25 + textWidth, y + 305, x + 25 + textWidth, y + 320)
    end
    
    -- Indicador de validez
    local isValid = SeedSystem.validate(displayText)
    local validColor = isValid and {0.6, 1, 0.6, 1} or {1, 0.6, 0.6, 1}
    local validText = isValid and "✓ Valid Format" or "✗ Need 5 letters + 5 digits"
    love.graphics.setColor(validColor)
    love.graphics.print(validText, x + 25, y + 330)
    
    -- Contador de caracteres
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print(#displayText .. "/10 characters", x + 300, y + 330)
    
    -- Instrucciones
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Letters A-Z and digits 0-9 only • Enter to confirm • Escape to cancel", x + 20, y + 355)
    
    -- Ejemplo
    love.graphics.setColor(0.6, 0.8, 1, 1)
    love.graphics.print("Examples: A5B2C9D1E7, X3Y8Z2K6M4, F9R1T5G3H8", x + 20, y + 375)
end

function HUD.drawCurrentSeedInfo()
    if not gameState then return end
    
    local currentSeed = gameState.currentSeed or "UNKNOWN00"
    local text = "Seed: " .. currentSeed
    local textWidth = hudState.smallFont:getWidth(text)
    local x = love.graphics.getWidth() - textWidth - 15
    local y = love.graphics.getHeight() - 45
    
    -- Fondo semi-transparente expandido
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x - 8, y - 3, textWidth + 16, 42)
    
    -- Borde sutil
    love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
    love.graphics.rectangle("line", x - 8, y - 3, textWidth + 16, 42)
    
    -- Texto de semilla
    love.graphics.setColor(0.7, 1, 0.7, 1)
    love.graphics.setFont(hudState.smallFont)
    love.graphics.print(text, x, y)
    
    -- Estado de validez
    local isValid = SeedSystem.validate(currentSeed)
    local validColor = isValid and {0.6, 1, 0.6, 1} or {1, 0.8, 0.4, 1}
    local validText = isValid and "Alpha" or "Legacy"
    love.graphics.setColor(validColor)
    love.graphics.setFont(hudState.tinyFont)
    love.graphics.print("Type: " .. validText, x, y + 15)
end

-- HUD del jugador (barras de vida, escudo, combustible) - SIN CAMBIOS
function HUD.drawPlayerHUD()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Posiciones para el HUD
    local hudY = screenHeight - 80
    local heartStartX = 20
    local barWidth = 200
    local barHeight = 12
    
    -- Guardar color actual
    local r, g, b, a = love.graphics.getColor()
    
    -- Dibujar corazones
    HUD.drawHearts(heartStartX, hudY - 30)
    
    -- Dibujar barra de escudo
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.smallFont)
    love.graphics.print("SHIELD", heartStartX, hudY)
    HUD.drawBar(heartStartX + 60, hudY + 2, barWidth, barHeight, 
                 player.stats:getShieldPercentage(), {0.2, 0.6, 1, 1}, {0.1, 0.3, 0.5, 0.8})
    
    -- Dibujar barra de combustible
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FUEL", heartStartX, hudY + 20)
    HUD.drawBar(heartStartX + 60, hudY + 22, barWidth, barHeight, 
                 player.stats:getFuelPercentage(), {1, 0.8, 0.2, 1}, {0.5, 0.4, 0.1, 0.8})
    
    -- Restaurar color
    love.graphics.setColor(r, g, b, a)
end

-- Dibujar corazones de vida - SIN CAMBIOS
function HUD.drawHearts(x, y)
    local heartSize = 16
    local heartSpacing = 20
    
    for i = 1, player.stats.health.maxHearts do
        local heartX = x + (i - 1) * heartSpacing
        
        if i <= player.stats.health.currentHearts then
            -- Corazón completo
            love.graphics.setColor(1, 0.2, 0.2, 1)
            HUD.drawHeart(heartX, y, heartSize, true)
        elseif i == player.stats.health.currentHearts + 1 and player.stats.health.heartHalves > 0 then
            -- Medio corazón
            love.graphics.setColor(1, 0.2, 0.2, 1)
            HUD.drawHeart(heartX, y, heartSize, false)
        else
            -- Corazón vacío
            love.graphics.setColor(0.3, 0.1, 0.1, 1)
            HUD.drawHeartOutline(heartX, y, heartSize)
        end
    end
end

function HUD.drawHeart(x, y, size, full)
    local halfSize = size / 2
    
    if full then
        -- Corazón completo
        love.graphics.circle("fill", x + halfSize * 0.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.circle("fill", x + halfSize * 1.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.polygon("fill", 
            x, y + halfSize,
            x + halfSize, y + size,
            x + size, y + halfSize
        )
    else
        -- Medio corazón (solo lado izquierdo)
        love.graphics.circle("fill", x + halfSize * 0.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.polygon("fill", 
            x, y + halfSize,
            x + halfSize, y + size,
            x + halfSize, y + halfSize
        )
        
        -- Lado derecho vacío
        love.graphics.setColor(0.3, 0.1, 0.1, 1)
        love.graphics.circle("line", x + halfSize * 1.5, y + halfSize * 0.5, halfSize * 0.5)
        love.graphics.polygon("line", 
            x + halfSize, y + halfSize,
            x + size, y + halfSize,
            x + halfSize, y + size
        )
    end
end

function HUD.drawHeartOutline(x, y, size)
    local halfSize = size / 2
    
    -- Contorno del corazón vacío
    love.graphics.circle("line", x + halfSize * 0.5, y + halfSize * 0.5, halfSize * 0.5)
    love.graphics.circle("line", x + halfSize * 1.5, y + halfSize * 0.5, halfSize * 0.5)
    love.graphics.polygon("line", 
        x, y + halfSize,
        x + halfSize, y + size,
        x + size, y + halfSize
    )
end

function HUD.drawBar(x, y, width, height, percentage, color, backgroundColor)
    -- Fondo de la barra
    love.graphics.setColor(backgroundColor)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Borde
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Relleno de la barra
    if percentage > 0 then
        love.graphics.setColor(color)
        local fillWidth = (width - 2) * (percentage / 100)
        love.graphics.rectangle("fill", x + 1, y + 1, fillWidth, height - 2)
    end
    
    -- Texto del porcentaje
    love.graphics.setColor(1, 1, 1, 1)
    local text = string.format("%.0f%%", percentage)
    local textWidth = hudState.smallFont:getWidth(text)
    love.graphics.setFont(hudState.smallFont)
    love.graphics.print(text, x + width/2 - textWidth/2, y - 1)
end

-- Manejo de entrada para el HUD alfanumérico (COMPLETAMENTE NUEVO)
function HUD.handleSeedInput(key)
    if key == "escape" then
        hudState.showSeedInput = false
        hudState.seedInputText = ""
    elseif key == "return" or key == "enter" then
        if hudState.seedInputText ~= "" then
            local normalizedSeed = SeedSystem.normalize(hudState.seedInputText)
            if SeedSystem.validate(normalizedSeed) then
                -- Cerrar panel ANTES de devolver la semilla
                hudState.showSeedInput = false
                hudState.seedInputText = ""
                return normalizedSeed, "custom"
            else
                -- Si no es válido, intentar normalizar
                -- Cerrar panel ANTES de devolver la semilla
                hudState.showSeedInput = false
                hudState.seedInputText = ""
                return normalizedSeed, "normalized"
            end
        else
            -- Usar semilla predefinida
            local selectedPreset = presetSeeds[currentPresetIndex]
            local selectedSeed = selectedPreset.seed
            
            -- Regenerar semilla aleatoria si es necesario
            if selectedPreset.name == "Random" then
                selectedSeed = SeedSystem.generate()
                selectedPreset.seed = selectedSeed  -- Actualizar para mostrar
            end
            
            -- Cerrar panel ANTES de devolver la semilla
            hudState.showSeedInput = false
            hudState.seedInputText = ""
            return selectedSeed, "preset"
        end
    elseif key == "backspace" then
        hudState.seedInputText = string.sub(hudState.seedInputText, 1, -2)
    elseif key == "up" then
        currentPresetIndex = math.max(1, currentPresetIndex - 1)
    elseif key == "down" then
        currentPresetIndex = math.min(#presetSeeds, currentPresetIndex + 1)
    end
    return nil, nil
end

-- Input de texto mejorado para alfanumérico
function HUD.textinput(text)
    if hudState.showSeedInput then
        -- Solo permitir letras A-Z y dígitos 0-9
        local upperText = text:upper()
        if upperText:match("[A-Z0-9]") and #hudState.seedInputText < 10 then
            hudState.seedInputText = hudState.seedInputText .. upperText
        end
    end
end

-- Funciones de control del HUD - SIN CAMBIOS
function HUD.toggleInfo()
    hudState.showInfo = not hudState.showInfo
end

function HUD.toggleBiomeInfo()
    hudState.showBiomeInfo = not hudState.showBiomeInfo
    local status = hudState.showBiomeInfo and "ON" or "OFF"
    print("Biome info panel: " .. status)
end

function HUD.showSeedInput()
    hudState.showSeedInput = true
    hudState.seedInputText = ""
    -- Regenerar semilla aleatoria en preset
    presetSeeds[1].seed = SeedSystem.generate()
end

function HUD.hideSeedInput()
    hudState.showSeedInput = false
    hudState.seedInputText = ""
end

function HUD.isSeedInputVisible()
    return hudState.showSeedInput
end

function HUD.isInfoVisible()
    return hudState.showInfo
end

function HUD.isBiomeInfoVisible()
    return hudState.showBiomeInfo
end

function HUD.updateReferences(gameStateRef, playerRef, mapRef)
    gameState = gameStateRef
    player = playerRef
    Map = mapRef
    
    -- Recargar sistema de biomas de forma segura
    local success, biomeSystemModule = pcall(function()
        return require 'src.maps.biome_system'
    end)
    
    if success then
        BiomeSystem = biomeSystemModule
    end
    
    -- Limpiar cache de biomas
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

-- Función utilitaria para obtener el sistema de semillas
function HUD.getSeedSystem()
    return SeedSystem
end

return HUD