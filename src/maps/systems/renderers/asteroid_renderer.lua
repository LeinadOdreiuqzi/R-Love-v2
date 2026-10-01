-- src/maps/systems/renderers/asteroid_renderer.lua
-- Submódulo de renderizado procedural y LOD para asteroides
-- Desacoplado de src/maps/systems/map_renderer.lua

local AsteroidRenderer = {}
local MapConfig = require 'src.maps.config.map_config'
local ShaderManager = require 'src.shaders.shader_manager'

local SIZE_PIXELS = MapConfig.chunk.size * MapConfig.chunk.tileSize
local STRIDE = SIZE_PIXELS + (MapConfig.chunk.spacing or 0)

--[[
    Dibuja todos los asteroides visibles en los chunks cargados
--]]
function AsteroidRenderer.drawAsteroids(mapRenderer, chunkInfo, camera, getChunkFunc)
    local rendered = 0
    local maxAsteroidsPerFrame = (MapConfig.performance and MapConfig.performance.maxAsteroidsPerFrame) or 3000

    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            if rendered >= maxAsteroidsPerFrame then return rendered end
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.tiles then
                local chunkBaseTileX = chunkX * MapConfig.chunk.size
                local chunkBaseTileY = chunkY * MapConfig.chunk.size
                local chunkBaseWorldX = chunkX * STRIDE * MapConfig.chunk.worldScale
                local chunkBaseWorldY = chunkY * STRIDE * MapConfig.chunk.worldScale

                for y = 0, MapConfig.chunk.size - 1 do
                    if rendered >= maxAsteroidsPerFrame then return rendered end
                    for x = 0, MapConfig.chunk.size - 1 do
                        if rendered >= maxAsteroidsPerFrame then return rendered end
                        local tileType = chunk.tiles[y][x]
                        if tileType >= MapConfig.ObjectType.ASTEROID_SMALL and tileType <= MapConfig.ObjectType.ASTEROID_LARGE then
                            local globalTileX = chunkBaseTileX + x
                            local globalTileY = chunkBaseTileY + y
                            local worldX = chunkBaseWorldX + x * MapConfig.chunk.tileSize * MapConfig.chunk.worldScale
                            local worldY = chunkBaseWorldY + y * MapConfig.chunk.tileSize * MapConfig.chunk.worldScale
                            
                            local baseSizes = (MapConfig.asteroids and MapConfig.asteroids.baseSizes) or {8, 15, 25}
                            local sizeScale = (MapConfig.asteroids and MapConfig.asteroids.sizeScale) or 1.0
                            local size = baseSizes[tileType] * sizeScale * MapConfig.chunk.worldScale * 1.3
                            
                            if mapRenderer.isObjectVisible(worldX, worldY, size, camera) then
                                local lod = mapRenderer.calculateLOD(worldX, worldY, camera)
                                AsteroidRenderer.drawAsteroidLOD(mapRenderer, tileType, worldX, worldY, globalTileX, globalTileY, lod, camera)
                                rendered = rendered + 1
                                if rendered >= maxAsteroidsPerFrame then return rendered end
                            end
                        end
                    end
                end
            end
        end
    end
    return rendered
end

--[[
    Dibuja un asteroide específico utilizando niveles de detalle (LOD) y shaders deterministas
--]]
function AsteroidRenderer.drawAsteroidLOD(mapRenderer, asteroidType, worldX, worldY, globalX, globalY, lod, camera)
    local function lcg(state) return (state * 1664525 + 1013904223) % 4294967296 end
    local function next01(state)
        state = lcg(state)
        return state, (state / 4294967296)
    end
    
    local state = (globalX * 1103515245 + globalY * 12345 + asteroidType * 2654435761) % 4294967296

    local baseSizes = (MapConfig.asteroids and MapConfig.asteroids.baseSizes) or {8, 15, 25}
    local sizeScale = (MapConfig.asteroids and MapConfig.asteroids.sizeScale) or 1.0
    local baseSize = baseSizes[asteroidType] * sizeScale * MapConfig.chunk.worldScale
    local colorIndex = (globalX + globalY) % #MapConfig.colors.asteroids + 1
    local color = MapConfig.colors.asteroids[colorIndex]
    
    local r1
    state, r1 = next01(state)
    local sizeVariation = 0.8 + r1 * 0.4
    local finalSize = baseSize * sizeVariation

    local sx, sy = camera:worldToScreen(worldX, worldY)
    local alpha = mapRenderer.calculateEdgeFade(sx, sy, finalSize, camera)
    local segments = lod >= 2 and 6 or (lod >= 1 and 8 or 12)
    local pxSize = finalSize * (camera.zoom or 1)
    
    love.graphics.push()
    love.graphics.origin()

    local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("asteroid") or nil
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
    if shader and img then
        local function next01Local(st)
            st = (st * 1664525 + 1013904223) % 4294967296
            return st, (st / 4294967296)
        end
        local rSx, rSy, rAmp, rFreq, rRot
        state, rSx = next01Local(state)
        state, rSy = next01Local(state)
        state, rAmp = next01Local(state)
        state, rFreq = next01Local(state)
        state, rRot = next01Local(state)

        local squashMin, squashMax = 0.8, 1.3
        local squashX = squashMin + (squashMax - squashMin) * rSx
        local squashY = squashMin + (squashMax - squashMin) * rSy

        local ampBase = (asteroidType == MapConfig.ObjectType.ASTEROID_LARGE) and 0.16 or 0.10
        local freqBase = (asteroidType == MapConfig.ObjectType.ASTEROID_LARGE) and 16.0 or 12.0
        local noiseAmp = ampBase * (0.7 + 0.6 * rAmp)
        local noiseFreq = freqBase * (0.7 + 0.6 * rFreq)
        local rotation = (rRot * 2.0 - 1.0) * math.pi
        local seedUniform = (globalX * 0.123 + globalY * 0.789 + asteroidType * 1.37) % 1.0

        pcall(function()
            shader:send("u_squashX", squashX)
            shader:send("u_squashY", squashY)
            shader:send("u_noiseAmp", noiseAmp)
            shader:send("u_noiseFreq", noiseFreq)
            shader:send("u_rotation", rotation)
            shader:send("u_seed", seedUniform)
        end)

        love.graphics.setShader(shader)
        local iw, ih = img:getWidth(), img:getHeight()
        local scale = (pxSize * 2) / math.max(1, iw)
        
        if lod >= 2 then
            love.graphics.setColor(color[1], color[2], color[3], 0.8 * alpha)
            love.graphics.draw(img, sx, sy, 0, scale, scale, iw * 0.5, ih * 0.5)
            love.graphics.setShader()
            love.graphics.pop()
            return
        end
        
        if lod >= 1 then
            love.graphics.setColor(0.1, 0.1, 0.1, 0.3 * alpha)
            love.graphics.draw(img, sx + 2, sy + 2, 0, (pxSize + 1) * 2 / iw, (pxSize + 1) * 2 / ih, iw * 0.5, ih * 0.5)
            love.graphics.setColor(color[1], color[2], color[3], 1 * alpha)
            love.graphics.draw(img, sx, sy, 0, scale, scale, iw * 0.5, ih * 0.5)
            love.graphics.setShader()
            love.graphics.pop()
            return
        end
        
        -- LOD 0: detalle + highlights
        love.graphics.setColor(0.1, 0.1, 0.1, 0.5 * alpha)
        love.graphics.draw(img, sx + 2, sy + 2, 0, (pxSize + 1) * 2 / iw, (pxSize + 1) * 2 / ih, iw * 0.5, ih * 0.5)
        love.graphics.setColor(color[1], color[2], color[3], 1 * alpha)
        love.graphics.draw(img, sx, sy, 0, scale, scale, iw * 0.5, ih * 0.5)
        
        if asteroidType >= MapConfig.ObjectType.ASTEROID_MEDIUM then
            love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 1 * alpha)
            local r2
            state, r2 = next01(state)
            local numDetails = math.min(2 + math.floor(r2 * 3), math.floor(pxSize / 5))
            for i = 1, numDetails do
                local rA, rB, rC
                state, rA = next01(state)
                state, rB = next01(state)
                state, rC = next01(state)
                local angle = (i / numDetails) * 2 * math.pi + rA * 0.5
                local detailDistancePx = (finalSize * 0.3 * rB) * (camera.zoom or 1)
                local detailX = sx + math.cos(angle) * detailDistancePx
                local detailY = sy + math.sin(angle) * detailDistancePx
                local detailSizePx = (finalSize * 0.2 * rC) * (camera.zoom or 1)
                love.graphics.draw(img, detailX, detailY, 0, (detailSizePx * 2) / iw, (detailSizePx * 2) / ih, iw * 0.5, ih * 0.5)
            end
        end
        
        if asteroidType == MapConfig.ObjectType.ASTEROID_LARGE then
            love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.7 * alpha)
            love.graphics.draw(img, sx - pxSize * 0.3, sy - pxSize * 0.3, 0, (pxSize * 0.4 * 2) / iw, (pxSize * 0.4 * 2) / ih, iw * 0.5, ih * 0.5)
        end
        
        love.graphics.setShader()
    else
        -- Fallback sin shader (círculos)
        if lod >= 2 then
            love.graphics.setColor(color[1], color[2], color[3], 0.8 * alpha)
            love.graphics.circle("fill", sx, sy, pxSize, segments)
            love.graphics.pop()
            return
        end
        if lod >= 1 then
            love.graphics.setColor(0.1, 0.1, 0.1, 0.3 * alpha)
            love.graphics.circle("fill", sx + 2, sy + 2, pxSize + 1, segments)
            love.graphics.setColor(color[1], color[2], color[3], 1 * alpha)
            love.graphics.circle("fill", sx, sy, pxSize, segments)
            love.graphics.pop()
            return
        end
        love.graphics.setColor(0.1, 0.1, 0.1, 0.5 * alpha)
        love.graphics.circle("fill", sx + 2, sy + 2, pxSize + 1, segments)
        love.graphics.setColor(color[1], color[2], color[3], 1 * alpha)
        love.graphics.circle("fill", sx, sy, pxSize, segments)
    end

    love.graphics.pop()
end

return AsteroidRenderer
