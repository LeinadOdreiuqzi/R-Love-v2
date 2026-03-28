-- src/utils/debug_renderer.lua
-- Encargado de los overlays y estadísticas de depuración visual.
-- Desacoplado de main.lua

local DebugRenderer = {}

local World = require 'src.core.world'
local Map = require 'src.maps.map'
local ChunkManager = require 'src.maps.chunk_manager'
local OptimizedRenderer = require 'src.maps.optimized_renderer'
local CoordinateSystem = require 'src.maps.coordinate_system'
local BiomeSystem = require 'src.maps.biome_system'
local SeedSystem = require 'src.utils.seed_system'
local HUD = require 'src.ui.hud'
local GameState = require 'src.core.game_state'

function DebugRenderer.updateAdvancedStats(dt)
    local state = GameState.state
    local advStats = GameState.advancedStats
    local cache = GameState.advancedStatsCache
    
    local currentTime = love.timer.getTime()
    
    -- Agregar tiempo de frame actual al historial
    if currentTime - cache.lastFPSUpdate >= cache.fpsUpdateInterval then
        table.insert(advStats.frameTimeHistory, dt)
        if #advStats.frameTimeHistory > advStats.maxHistorySize then
            table.remove(advStats.frameTimeHistory, 1)
        end
        
        -- Calcular FPS promedio y cachear
        local avgFrameTime = 0
        for _, frameTime in ipairs(advStats.frameTimeHistory) do
            avgFrameTime = avgFrameTime + frameTime
        end
        cache.cachedFrameTime = avgFrameTime / #advStats.frameTimeHistory
        cache.cachedAvgFPS = math.floor(1 / cache.cachedFrameTime)
        cache.lastFPSUpdate = currentTime
    end
    
    -- Actualizar memoria menos frecuentemente
    if currentTime - cache.lastMemoryUpdate >= cache.memoryUpdateInterval then
        cache.cachedMemory = collectgarbage("count")
        cache.lastMemoryUpdate = currentTime
    end
    
    -- Actualizar estadísticas cada intervalo
    if currentTime - advStats.lastUpdate >= advStats.updateInterval then
        advStats.lastUpdate = currentTime
        
        if advStats.enabled then
            print("=== ADVANCED STATS UPDATE ===")
            print("Avg FPS: " .. cache.cachedAvgFPS)
            print("Frame Time: " .. string.format("%.2f", cache.cachedFrameTime * 1000) .. "ms")
            print("Current Seed: " .. state.currentSeed)
            print("Memory: " .. string.format("%.1f", cache.cachedMemory / 1024) .. "MB")
        end
    end
end

function DebugRenderer.drawPerformanceOverlay()
    if not GameState.state.loaded then return end
    
    local currentTime = love.timer.getTime()
    local r, g, b, a = love.graphics.getColor()
    
    local perfCache = GameState.performanceCache
    local state = GameState.state
    
    local panelWidth = 300
    local panelHeight = 180
    local x = 10
    local y = love.graphics.getHeight() - panelHeight - 10
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(0, 1, 1, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(0, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("PERFORMANCE MONITOR", x + 10, y + 8)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(10))
    
    local infoY = y + 25
    
    love.graphics.setColor(1, 1, 0.5, 1)
    love.graphics.print("Seed: " .. state.currentSeed, x + 10, infoY)
    infoY = infoY + 12
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Numeric: " .. SeedSystem.toNumeric(state.currentSeed), x + 10, infoY)
    infoY = infoY + 15
    
    local currentFPS = love.timer.getFPS()
    local fpsColor = currentFPS >= 55 and {0, 1, 0, 1} or currentFPS >= 30 and {1, 1, 0, 1} or {1, 0, 0, 1}
    love.graphics.setColor(fpsColor)
    love.graphics.print("FPS: " .. currentFPS, x + 10, infoY)
    infoY = infoY + 12
    
    local rendererStats
    if currentTime - perfCache.lastUpdate >= perfCache.updateInterval then
        rendererStats = OptimizedRenderer.getStats()
        perfCache.cachedStats = rendererStats
        perfCache.lastUpdate = currentTime
        
        perfCache.stringCache.frameTime = "Frame Time: " .. string.format("%.1f", rendererStats.performance.frameTime) .. "ms"
        perfCache.stringCache.drawCalls = "Draw Calls: " .. rendererStats.performance.drawCalls
        perfCache.stringCache.objectsRendered = "Objects Rendered: " .. rendererStats.rendering.objectsRendered
        perfCache.stringCache.cullingEff = "Culling Efficiency: " .. string.format("%.1f%%", rendererStats.rendering.cullingEfficiency)
        perfCache.stringCache.qualityLevel = "Quality Level: " .. string.format("%.1f%%", rendererStats.quality.current * 100)
    else
        rendererStats = perfCache.cachedStats or OptimizedRenderer.getStats()
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(perfCache.stringCache.frameTime or "Frame Time: N/A", x + 10, infoY)
    infoY = infoY + 12
    love.graphics.print(perfCache.stringCache.drawCalls or "Draw Calls: N/A", x + 10, infoY)
    infoY = infoY + 12
    love.graphics.print(perfCache.stringCache.objectsRendered or "Objects Rendered: N/A", x + 10, infoY)
    infoY = infoY + 12
    
    local cullingEff = rendererStats.rendering.cullingEfficiency
    local cullingColor = cullingEff >= 80 and {0, 1, 0, 1} or cullingEff >= 60 and {1, 1, 0, 1} or {1, 0, 0, 1}
    love.graphics.setColor(cullingColor)
    love.graphics.print(perfCache.stringCache.cullingEff or "Culling Efficiency: N/A", x + 10, infoY)
    infoY = infoY + 12
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(perfCache.stringCache.qualityLevel or "Quality Level: N/A", x + 10, infoY)
    infoY = infoY + 12
    
    local memoryMB = collectgarbage("count") / 1024
    local memoryColor = memoryMB < 100 and {0, 1, 0, 1} or memoryMB < 200 and {1, 1, 0, 1} or {1, 0, 0, 1}
    love.graphics.setColor(memoryColor)
    love.graphics.print("Memory: " .. string.format("%.1f", memoryMB) .. "MB", x + 10, infoY)
    
    love.graphics.setColor(r, g, b, a)
end

function DebugRenderer.drawBiomeDebugOverlay()
    local player = World.get('player')
    local state = GameState.state
    local biomeDebug = GameState.biomeDebug
    
    if not player or not state.loaded then return end
    
    local r, g, b, a = love.graphics.getColor()
    
    local panelWidth = 420
    local panelHeight = 320
    local x = love.graphics.getWidth() - panelWidth - 10
    local y = HUD.isBiomeInfoVisible() and 220 or 10
    
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("ENHANCED SYSTEM DEBUG", x + 10, y + 8)
    
    local infoY = y + 25
    
    love.graphics.setColor(1, 0.8, 0.5, 1)
    love.graphics.setFont(love.graphics.newFont(10))
    love.graphics.print("SEED SYSTEM", x + 10, infoY)
    infoY = infoY + 12
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Alpha: " .. state.currentSeed, x + 10, infoY)
    infoY = infoY + 12
    love.graphics.print("Numeric: " .. SeedSystem.toNumeric(state.currentSeed), x + 10, infoY)
    infoY = infoY + 15
    
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
        
        local chunkStats = ChunkManager.getStats()
        love.graphics.setColor(1, 0.8, 1, 1)
        love.graphics.print("CHUNK MANAGER", x + 10, infoY)
        infoY = infoY + 12
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Active: " .. chunkStats.active .. " | Cached: " .. chunkStats.cached .. " | Pool: " .. chunkStats.pooled, x + 10, infoY)
        infoY = infoY + 12
        love.graphics.print("Load Queue: " .. chunkStats.loadQueue .. " | Hit Ratio: " .. string.format("%.1f%%", chunkStats.cacheHitRatio * 100), x + 10, infoY)
        infoY = infoY + 15
        
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
        
        if biomeDebug.testDistribution then
            love.graphics.setColor(1, 0.5, 1, 1)
            love.graphics.print("AUTO-TESTING ENABLED", x + 10, y + panelHeight - 15)
        end
        
        love.graphics.setColor(0.5, 1, 0.5, 1)
        love.graphics.print("Enhanced: ✓ Seeds ✓ Biomes ✓ Coords ✓ Chunks ✓ Render", x + 10, y + panelHeight - 28)
    end
    
    love.graphics.setColor(r, g, b, a)
end

function DebugRenderer.drawBiomeRegionDebug()
    local camera = World.get('camera')
    local player = World.get('player')
    local state = GameState.state
    
    if not camera or not player or not state.loaded then return end
    
    local r, g, b, a = love.graphics.getColor()
    
    local visibleChunks = ChunkManager.getVisibleChunks(camera)
    love.graphics.setColor(1, 1, 0, 0.5)
    
    local chunkSize = Map.chunkSize * Map.tileSize
    
    if visibleChunks then
        for _, chunk in ipairs(visibleChunks) do
            if chunk.biome then
                local worldX = chunk.x * chunkSize
                local worldY = chunk.y * chunkSize
                
                local relX, relY = CoordinateSystem.worldToRelative(worldX, worldY)
                local camRelX, camRelY = CoordinateSystem.worldToRelative(camera.x, camera.y)
                
                local screenX = (relX - camRelX) * camera.zoom + love.graphics.getWidth() / 2
                local screenY = (relY - camRelY) * camera.zoom + love.graphics.getHeight() / 2
                local screenSize = chunkSize * camera.zoom
                
                love.graphics.rectangle("line", screenX, screenY, screenSize, screenSize)
                
                local config = chunk.biome.config
                love.graphics.setColor(config.color[1] + 0.3, config.color[2] + 0.3, config.color[3] + 0.3, 0.7)
                love.graphics.circle("fill", screenX + screenSize/2, screenY + screenSize/2, 10)
                
                if camera.zoom > 0.5 then
                    love.graphics.setColor(1, 1, 1, 0.8)
                    love.graphics.printf(config.name:sub(1, 8), screenX + 5, screenY + 5, screenSize - 10, "center")
                end
            end
        end
    end
    
    love.graphics.setColor(r, g, b, a)
end

return DebugRenderer
