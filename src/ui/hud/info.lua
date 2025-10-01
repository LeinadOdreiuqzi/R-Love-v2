local HUD = require('src.ui.hud.core')

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
    love.graphics.setFont(hudState.font)
    love.graphics.print("ENHANCED SPACE EXPLORER", x + 10, y + 8)
    
    love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
    love.graphics.line(x + 10, y + 28, x + panelWidth - 10, y + 28)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(hudState.smallFont)
    
    local posX = math.floor(player.x or 0)
    local posY = math.floor(player.y or 0)
    local speed = math.sqrt((player.dx or 0)^2 + (player.dy or 0)^2)
    
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
    
    local seedStatus = SeedSystem.validate(stats.seed) and "Valid" or "Legacy"
    local seedColor = SeedSystem.validate(stats.seed) and {0.6, 1, 0.6, 1} or {1, 0.8, 0.4, 1}
    love.graphics.setColor(seedColor)
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
    
    local chunkInfo = "N/A"
    if stats.chunks and stats.chunks.active and stats.chunks.cached then
        chunkInfo = stats.chunks.active .. "/" .. stats.chunks.cached
    elseif stats.loadedChunks then
        chunkInfo = tostring(stats.loadedChunks)
    end
    love.graphics.print("Chunks: " .. chunkInfo, x + 15, infoY)
    infoY = infoY + lineHeight
    
    if _G.showGrid then
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