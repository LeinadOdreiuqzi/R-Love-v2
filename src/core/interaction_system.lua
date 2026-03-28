-- src/core/interaction_system.lua
-- Sistema de interacciones desacoplado de main.lua
-- Gestiona la entrada a estaciones o subniveles.

local InteractionSystem = {}

local World = require 'src.core.world'
local Map = require 'src.maps.map'
local HUD = require 'src.ui.hud'
local BiomeSystem = require 'src.maps.biome_system'
local SubLevelManager = require 'src.maps.systems.sublevel_manager'
local SubLevelScene = require 'src.sublevels.sublevel_scene'
local StationScene = require 'src.states.station_scene'
local GameState = require 'src.core.game_state'

function InteractionSystem.tryEnterStationOrSublevel()
    local player = World.get('player')
    if not player then return end

    -- Determinar la entidad activa (nave o astronauta en EVA)
    local activeEntity = (player.getActiveEntity and player:getActiveEntity()) or player
    local camera = World.get('camera')
    local stateManager = World.get('stateManager')
    
    if not camera or not stateManager then return end

    -- Intentar entrar a Subnivel si existe una entrada cercana
    do
        local MapConfig = require 'src.maps.config.map_config'
        local bounds = Map.getVisibleChunkBounds(camera, 800)
        local closest, minDist
        local closestWorldX, closestWorldY
        local sizePixels = MapConfig.chunk.size * MapConfig.chunk.tileSize
        local spacing = MapConfig.chunk.spacing or 0
        local ws = MapConfig.chunk.worldScale or 1
        local strideScaled = (sizePixels + spacing) * ws

        for cy = bounds.startY, bounds.endY do
            for cx = bounds.startX, bounds.endX do
                local chunk = Map.getChunkNonBlocking(cx, cy)
                if chunk and chunk.specialObjects then
                    for _, obj in ipairs(chunk.specialObjects) do
                        if obj and (obj.type == MapConfig.ObjectType.SUBLEVEL_ENTRANCE or obj.type == "SUBLEVEL_ENTRANCE") then
                            local worldX = cx * strideScaled + (obj.x or 0) * ws
                            local worldY = cy * strideScaled + (obj.y or 0) * ws
                            local dx, dy = worldX - activeEntity.x, worldY - activeEntity.y
                            local dist = math.sqrt(dx*dx + dy*dy)
                            if not minDist or dist < minDist then
                                closest, minDist = obj, dist
                                closestWorldX, closestWorldY = worldX, worldY
                            end
                        end
                    end
                end
            end
        end

        local factor = HUD.getEnterRadiusFactor and HUD.getEnterRadiusFactor() or 1.0
        local allowed = HUD.computeEnterRadius and HUD.computeEnterRadius(closest, factor) or 48
        
        if closest and (not minDist or minDist <= allowed) then
            local scx, scy = Map.getChunkInfo(closestWorldX or activeEntity.x, closestWorldY or activeEntity.y)
            local cfg = SubLevelManager.createConfig({
                parentSeed = GameState.state.currentSeed,
                type = SubLevelManager.Types.Generic,
                cx = closest.cx or scx,
                cy = closest.cy or scy,
                width = 8,
                height = 8,
                entryX = 0,
                entryY = 0,
                context = "entrance|" .. tostring(closest.entranceKey or ((closest.cx or scx) .. ":" .. (closest.cy or scy)))
            })
            local scene = SubLevelScene:new(cfg)
            stateManager:push(scene, { suspendUnderlying = true, fadeDuration = 0.25 })
            return
        end
    end

    -- Segundo: Entrar a estación si existe una cercana en Ancient Ruins
    if activeEntity.x and activeEntity.y then
        local biomeInfo = BiomeSystem.getPlayerBiomeInfo(activeEntity.x, activeEntity.y)
        if biomeInfo and biomeInfo.type == BiomeSystem.BiomeType.ANCIENT_RUINS then
            local bounds = Map.getVisibleChunkBounds(camera, 800)
            local closest, minDist
            for cy = bounds.startY, bounds.endY do
                for cx = bounds.startX, bounds.endX do
                    local chunk = Map.getChunkNonBlocking(cx, cy)
                    if chunk and chunk.ancientRuinsPlaceholders then
                        for _, ph in ipairs(chunk.ancientRuinsPlaceholders) do
                            local dx, dy = ph.x - activeEntity.x, ph.y - activeEntity.y
                            local dist = math.sqrt(dx*dx + dy*dy)
                            if not minDist or dist < minDist then
                                closest, minDist = ph, dist
                            end
                        end
                    end
                end
            end
            
            local factor = HUD.getEnterRadiusFactor and HUD.getEnterRadiusFactor() or 1.0
            local allowed = HUD.computeEnterRadius and HUD.computeEnterRadius(closest, factor) or 48
            
            if closest and (not minDist or minDist <= allowed) then
                local scene = StationScene:new(closest)
                stateManager:push(scene, { suspendUnderlying = true, fadeDuration = 0.25 })
            else
                print("No hay estación cercana para entrar.")
            end
        end
    end
end

return InteractionSystem
