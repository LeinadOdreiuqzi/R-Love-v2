-- src/maps/systems/renderers/asteroid_renderer.lua
-- Submódulo de renderizado procedural y LOD para asteroides optimizado
-- Arquitectura de estado consolidado (1 push/origin, 1 setShader para todo el lote, 0 GC churn)

local AsteroidRenderer = {}
local MapConfig = require 'src.maps.config.map_config'
local CapsuleLight = require 'src.rendering.capsule_light'
local Rock = require 'src.maps.systems.renderers.belt_rock_art'

local function currentInspection()
    local sites = package.loaded['src.gameplay.salvage_sites']
    return sites and sites.getInspection()
end

local SIZE_PIXELS = MapConfig.chunk.size * MapConfig.chunk.tileSize
local STRIDE = SIZE_PIXELS + (MapConfig.chunk.spacing or 0)

-- LCG determinista rápido
local function lcg(state)
    return (state * 1664525 + 1013904223) % 4294967296
end

local function drawRock(mapRenderer, kind, worldX, worldY, gx, gy, baseSize, lod, camera, inspection, draw)
    -- Keep the existing size roll independent of the art seed.
    local state = lcg((gx*1103515245 + gy*12345 + kind*2654435761) % 4294967296)
    local radius = baseSize * (0.8 + state/4294967296 * 0.4)
    local seed = (state + (mapRenderer.worldSeed or 0)) % 4294967296
    local colors = MapConfig.colors.asteroids
    local color = colors[(gx+gy) % #colors + 1]
    local sx, sy = camera:worldToScreen(worldX, worldY)
    local alpha = mapRenderer.calculateEdgeFade(sx, sy, radius, camera)
    local light = CapsuleLight.sample(inspection, worldX, worldY, 0)
    draw(kind, seed, sx, sy, radius, camera.zoom or 1, alpha, lod, color, light)
end

function AsteroidRenderer.drawAsteroids(mapRenderer, chunkInfo, camera, getChunkFunc)
    local rendered = 0

    local baseSizes = (MapConfig.asteroids and MapConfig.asteroids.baseSizes) or {8, 15, 25}
    local sizeScale = (MapConfig.asteroids and MapConfig.asteroids.sizeScale) or 1.0
    local ws = MapConfig.chunk.worldScale or 1.0
    local tileSizeScaled = MapConfig.chunk.tileSize * ws
    local strideScaled = STRIDE * ws

    local sizeScaled1 = (baseSizes[1] or 8) * sizeScale * ws * 1.3
    local sizeScaled2 = (baseSizes[2] or 15) * sizeScale * ws * 1.3
    local sizeScaled3 = (baseSizes[3] or 25) * sizeScale * ws * 1.3

    local baseSize1 = (baseSizes[1] or 8) * sizeScale * ws
    local baseSize2 = (baseSizes[2] or 15) * sizeScale * ws
    local baseSize3 = (baseSizes[3] or 25) * sizeScale * ws

    local inspection = currentInspection()
    love.graphics.push('all')
    love.graphics.origin()
    Rock.beginBatch()

    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.tiles then
                local chunkBaseTileX = chunkX * MapConfig.chunk.size
                local chunkBaseTileY = chunkY * MapConfig.chunk.size
                local chunkBaseWorldX = chunkX * strideScaled
                local chunkBaseWorldY = chunkY * strideScaled

                for y = 0, MapConfig.chunk.size - 1 do
                    local tileRow = chunk.tiles[y]
                    if tileRow then
                        local worldY = chunkBaseWorldY + y * tileSizeScaled
                        local globalTileY = chunkBaseTileY + y

                        for x = 0, MapConfig.chunk.size - 1 do
                            local tileType = tileRow[x]
                            if tileType and tileType >= MapConfig.ObjectType.ASTEROID_SMALL and tileType <= MapConfig.ObjectType.ASTEROID_LARGE then
                                local cullingSize = (tileType == 1 and sizeScaled1) or (tileType == 2 and sizeScaled2) or sizeScaled3
                                local worldX = chunkBaseWorldX + x * tileSizeScaled

                                if mapRenderer.isObjectVisible(worldX, worldY, cullingSize, camera) then
                                    local globalTileX = chunkBaseTileX + x
                                    local lod = mapRenderer.calculateLOD(worldX, worldY, camera)
                                    rendered = rendered + 1

                                    local baseSize = (tileType == 1 and baseSize1) or (tileType == 2 and baseSize2) or baseSize3
                                    drawRock(mapRenderer, tileType, worldX, worldY, globalTileX, globalTileY, baseSize, lod, camera, inspection, Rock.add)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    Rock.flush()
    love.graphics.pop()

    return rendered
end

--[[
    Dibuja un asteroide específico utilizando niveles de detalle (LOD) y shaders deterministas
    (Mantenido para compatibilidad e inspección individual)
--]]
function AsteroidRenderer.drawAsteroidLOD(mapRenderer, asteroidType, worldX, worldY, globalX, globalY, lod, camera)
    local baseSizes = (MapConfig.asteroids and MapConfig.asteroids.baseSizes) or {8, 15, 25}
    local sizeScale = (MapConfig.asteroids and MapConfig.asteroids.sizeScale) or 1.0
    local baseSize = (baseSizes[asteroidType] or 15) * sizeScale * (MapConfig.chunk.worldScale or 1.0)
    love.graphics.push('all')
    love.graphics.origin()
    Rock.begin()
    drawRock(mapRenderer, asteroidType, worldX, worldY, globalX, globalY, baseSize, lod, camera, currentInspection(), Rock.draw)
    love.graphics.pop()
end

function AsteroidRenderer.drawMega(worldSeed, feature, sx, sy, worldX, worldY, zoom, alpha)
    local seed = lcg((math.floor(worldX)*65537 + math.floor(worldY)*257 + (worldSeed or 0)) % 4294967296)
    local light = CapsuleLight.sample(currentInspection(), worldX, worldY, 0)
    love.graphics.push('all')
    Rock.begin()
    Rock.draw(MapConfig.ObjectType.ASTEROID_LARGE, seed, sx, sy, feature.size, zoom,
        alpha*(feature.color[4] or 1), 0, feature.color, light)
    love.graphics.pop()
end

return AsteroidRenderer
