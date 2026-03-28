local HUD = require('src.ui.hud.core')
local World = require('src.core.world')
local GameState = require('src.core.game_state')

-- Panel de información principal (ACTUALIZADO PARA SEMILLAS ALFANUMÉRICAS)
function HUD.drawUnifiedInfoPanel()
    local panelWidth = 360
    local panelHeight = 500
    local x = 10
    local y = 10
    
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", x, y, panelWidth, panelHeight)
    love.graphics.setColor(0.3, 0.5, 0.7, 1)
    love.graphics.rectangle("line", x, y, panelWidth, panelHeight)
    
    love.graphics.setColor(0.7, 0.9, 1, 1)
    love.graphics.setFont(HUD.hudState.font)
    love.graphics.print("ENHANCED SPACE EXPLORER", x + 10, y + 8)
    
    love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
    love.graphics.line(x + 10, y + 28, x + panelWidth - 10, y + 28)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(HUD.hudState.smallFont)
    
    local posX = math.floor(HUD.player and HUD.player.x or 0)
    local posY = math.floor(HUD.player and HUD.player.y or 0)
    local speed = 0
    if HUD.player then
        speed = math.sqrt((HUD.player.dx or 0)^2 + (HUD.player.dy or 0)^2)
    end
    
    local chunkX, chunkY = HUD.getSafeChunkCoords(posX, posY)
    local stats = HUD.getSafeStats()
    
    local infoY = y + 35
    local lineHeight = 12
    
    love.graphics.setColor(1, 1, 0.6, 1)
    love.graphics.print("GALAXY SEED", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Current: " .. (stats.seed or "UNKNOWN00"), x + 15, infoY)
    infoY = infoY + lineHeight
    
    local seedStatus = HUD.SeedSystem.validate(stats.seed) and "Valid" or "Legacy"
    local seedColor = HUD.SeedSystem.validate(stats.seed) and {0.6, 1, 0.6, 1} or {1, 0.8, 0.4, 1}
    love.graphics.setColor(seedColor[1], seedColor[2], seedColor[3], seedColor[4])
    love.graphics.print("Status: " .. seedStatus, x + 15, infoY)
    infoY = infoY + lineHeight + 5
    
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
    
    if HUD.BiomeSystem then
        love.graphics.setColor(1, 0.9, 0.6, 1)
        love.graphics.print("BIOME EXPLORATION", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        
        local success, biomeStats = pcall(function()
            if HUD.BiomeSystem.getAdvancedStats then
                return HUD.BiomeSystem.getAdvancedStats()
            end
            return nil
        end)
        
        if success and biomeStats and biomeStats.playerStats then
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.print("Biome Changes: " .. (biomeStats.playerStats.biomeChanges or 0), x + 15, infoY)
            infoY = infoY + lineHeight
            love.graphics.print("Chunks Generated: " .. (biomeStats.totalChunksGenerated or 0), x + 15, infoY)
            infoY = infoY + lineHeight
            
            if biomeStats.playerStats.currentBiome and HUD.BiomeSystem.getBiomeConfig then
                local configSuccess, currentConfig = pcall(function()
                    return HUD.BiomeSystem.getBiomeConfig(biomeStats.playerStats.currentBiome)
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
    
    love.graphics.setColor(0.9, 1, 0.9, 1)
    love.graphics.print("SYSTEM INFO", x + 10, infoY)
    infoY = infoY + lineHeight + 3
    
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("FPS: " .. (stats.fps or 0), x + 15, infoY)
    infoY = infoY + lineHeight
    local camera = World.get('camera')
    love.graphics.print("Zoom: " .. string.format("%.1f", camera and camera.zoom or 1), x + 15, infoY)
    infoY = infoY + lineHeight
    local budgetMs = ((stats.chunks and stats.chunks.generationBudget) or 0) * 1000
    local loadQueueLen = (stats.chunks and stats.chunks.loadQueue) or 0
    love.graphics.print(string.format("Chunk Budget: %.2f ms | Load Queue: %d", budgetMs, loadQueueLen), x + 15, infoY)
    infoY = infoY + lineHeight
    
    local chunkInfo = "N/A"
    if stats.chunks and stats.chunks.active and stats.chunks.cached then
        chunkInfo = stats.chunks.active .. "/" .. stats.chunks.cached
    elseif stats.loadedChunks then
        chunkInfo = tostring(stats.loadedChunks)
    end
    love.graphics.print("Chunks: " .. chunkInfo, x + 15, infoY)
    infoY = infoY + lineHeight
    
    if GameState.state.showGrid then
        love.graphics.setColor(0.8, 1, 0.8, 1)
        love.graphics.print("Grid: ON", x + 15, infoY)
    else
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("Grid: OFF", x + 15, infoY)
    end
    infoY = infoY + lineHeight
    
    pcall(function()
        local PhaseSystem = require 'src.gameplay.phase_system'
        if PhaseSystem and PhaseSystem.getHUDInfo then
            local phaseInfo = PhaseSystem.getHUDInfo()
            if phaseInfo then
                love.graphics.setColor(0.8, 1, 1, 1)
                love.graphics.print("Phase: " .. phaseInfo.currentPhase .. "/" .. phaseInfo.totalPhases, x + 15, infoY)
                infoY = infoY + lineHeight
                if phaseInfo.status == "Can expand (Press E)" then
                    love.graphics.setColor(0.2, 1, 0.2, 1)
                elseif phaseInfo.status == "At boundary" then
                    love.graphics.setColor(1, 0.3, 0.3, 1)
                elseif phaseInfo.status == "Near boundary" then
                    love.graphics.setColor(1, 1, 0.3, 1)
                else
                    love.graphics.setColor(0.8, 0.8, 0.8, 1)
                end
                love.graphics.print("Status: " .. phaseInfo.status, x + 15, infoY)
                infoY = infoY + lineHeight
                if phaseInfo.distanceToBoundary then
                    love.graphics.setColor(0.7, 0.9, 1, 1)
                    love.graphics.print("Distance to boundary: " .. phaseInfo.distanceToBoundary, x + 15, infoY)
                    infoY = infoY + lineHeight
                end
                if phaseInfo.worldPosition then
                    love.graphics.setColor(0.6, 0.8, 0.9, 1)
                    love.graphics.print("World: (" .. phaseInfo.worldPosition.x .. ", " .. phaseInfo.worldPosition.y .. ")", x + 15, infoY)
                    infoY = infoY + lineHeight
                end
                love.graphics.setColor(0.8, 0.8, 0.8, 1)
                love.graphics.print("Bounds: " .. phaseInfo.boundsString, x + 15, infoY)
                infoY = infoY + lineHeight
            end
        end
    end)
    
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
        if stats.chunks and stats.chunks.fullscreenOptimizations then
            local fsStats = stats.chunks.fullscreenOptimizations
            local modeText = fsStats.isFullscreen and "Fullscreen" or "Windowed"
            local optimizationColor = fsStats.isFullscreen and {0.8, 1, 0.8, 1} or {0.8, 0.8, 0.8, 1}
            love.graphics.setColor(optimizationColor[1], optimizationColor[2], optimizationColor[3], optimizationColor[4])
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
    
    if HUD.player and HUD.player.stats and HUD.player.stats.debug and HUD.player.stats.debug.enabled then
        infoY = infoY + 5
        love.graphics.setColor(1, 1, 0.4, 1)
        love.graphics.print("DEBUG MODE", x + 10, infoY)
        infoY = infoY + lineHeight + 3
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        local invulnStatus = HUD.player.stats.debug.invulnerable and "ON" or "OFF"
        love.graphics.print("Invulnerability: " .. invulnStatus, x + 15, infoY)
        infoY = infoY + lineHeight
        local fuelStatus = HUD.player.stats.debug.infiniteFuel and "ON" or "OFF"
        love.graphics.print("Infinite Fuel: " .. fuelStatus, x + 15, infoY)
        infoY = infoY + lineHeight
        local regenStatus = HUD.player.stats.debug.fastRegen and "ON" or "OFF"
        love.graphics.print("Fast Regen: " .. regenStatus, x + 15, infoY)
        infoY = infoY + lineHeight + 10
    end
    
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

return HUD