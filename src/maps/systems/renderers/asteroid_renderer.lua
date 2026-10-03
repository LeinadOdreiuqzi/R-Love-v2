-- src/maps/systems/renderers/asteroid_renderer.lua
-- Submódulo de renderizado procedural y LOD para asteroides optimizado
-- Arquitectura de estado consolidado (1 push/origin, 1 setShader para todo el lote, 0 GC churn)

local AsteroidRenderer = {}
local MapConfig = require 'src.maps.config.map_config'
local ShaderManager = require 'src.shaders.shader_manager'

local SIZE_PIXELS = MapConfig.chunk.size * MapConfig.chunk.tileSize
local STRIDE = SIZE_PIXELS + (MapConfig.chunk.spacing or 0)

-- LCG determinista rápido
local function lcg(state)
    return (state * 1664525 + 1013904223) % 4294967296
end

-- Envío directo de uniforms sin generar closures temporales (0 allocations)
local function sendUniformsDirect(shader, sx, sy, na, nf, rot, s)
    shader:send("u_squashX", sx)
    shader:send("u_squashY", sy)
    shader:send("u_noiseAmp", na)
    shader:send("u_noiseFreq", nf)
    shader:send("u_rotation", rot)
    shader:send("u_seed", s)
end

--[[
    Dibuja todos los asteroides visibles en los chunks cargados.
    Optimizado: Consolidación de matrices y vinculación de shader una sola vez por frame.
--]]
function AsteroidRenderer.drawAsteroids(mapRenderer, chunkInfo, camera, getChunkFunc)
    local rendered = 0
    local maxAsteroidsPerFrame = (MapConfig.performance and MapConfig.performance.maxAsteroidsPerFrame) or 3000

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

    local colors = MapConfig.colors.asteroids
    local numColors = #colors

    local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("asteroid") or nil
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil
    local useShader = (shader ~= nil) and (img ~= nil)

    local iw, ih, ox, oy = 512, 512, 256, 256
    if img then
        iw = img:getWidth()
        ih = img:getHeight()
        ox = iw * 0.5
        oy = ih * 0.5
    end

    local zoom = camera.zoom or 1.0

    -- Conmutar a coordenadas de pantalla UNA SOLA VEZ para todo el subsistema de asteroides
    love.graphics.push()
    love.graphics.origin()

    if useShader then
        love.graphics.setShader(shader)
    end

    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            if rendered >= maxAsteroidsPerFrame then break end
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.tiles then
                local chunkBaseTileX = chunkX * MapConfig.chunk.size
                local chunkBaseTileY = chunkY * MapConfig.chunk.size
                local chunkBaseWorldX = chunkX * strideScaled
                local chunkBaseWorldY = chunkY * strideScaled

                for y = 0, MapConfig.chunk.size - 1 do
                    if rendered >= maxAsteroidsPerFrame then break end
                    local tileRow = chunk.tiles[y]
                    if tileRow then
                        local worldY = chunkBaseWorldY + y * tileSizeScaled
                        local globalTileY = chunkBaseTileY + y

                        for x = 0, MapConfig.chunk.size - 1 do
                            if rendered >= maxAsteroidsPerFrame then break end
                            local tileType = tileRow[x]
                            if tileType and tileType >= MapConfig.ObjectType.ASTEROID_SMALL and tileType <= MapConfig.ObjectType.ASTEROID_LARGE then
                                local cullingSize = (tileType == 1 and sizeScaled1) or (tileType == 2 and sizeScaled2) or sizeScaled3
                                local worldX = chunkBaseWorldX + x * tileSizeScaled

                                if mapRenderer.isObjectVisible(worldX, worldY, cullingSize, camera) then
                                    local globalTileX = chunkBaseTileX + x
                                    local lod = mapRenderer.calculateLOD(worldX, worldY, camera)
                                    rendered = rendered + 1

                                    local baseSize = (tileType == 1 and baseSize1) or (tileType == 2 and baseSize2) or baseSize3
                                    local colorIndex = (globalTileX + globalTileY) % numColors + 1
                                    local color = colors[colorIndex]

                                    -- Generador LCG determinista
                                    local state = (globalTileX * 1103515245 + globalTileY * 12345 + tileType * 2654435761) % 4294967296
                                    state = lcg(state)
                                    local r1 = state / 4294967296
                                    local finalSize = baseSize * (0.8 + r1 * 0.4)

                                    local sx, sy = camera:worldToScreen(worldX, worldY)
                                    local alpha = mapRenderer.calculateEdgeFade(sx, sy, finalSize, camera)
                                    local pxSize = finalSize * zoom

                                    if useShader then
                                        state = lcg(state)
                                        local rSx = state / 4294967296
                                        state = lcg(state)
                                        local rSy = state / 4294967296
                                        state = lcg(state)
                                        local rAmp = state / 4294967296
                                        state = lcg(state)
                                        local rFreq = state / 4294967296
                                        state = lcg(state)
                                        local rRot = state / 4294967296

                                        local squashX = 0.8 + 0.5 * rSx
                                        local squashY = 0.8 + 0.5 * rSy
                                        local isLarge = (tileType == MapConfig.ObjectType.ASTEROID_LARGE)
                                        local ampBase = isLarge and 0.16 or 0.10
                                        local freqBase = isLarge and 16.0 or 12.0
                                        local noiseAmp = ampBase * (0.7 + 0.6 * rAmp)
                                        local noiseFreq = freqBase * (0.7 + 0.6 * rFreq)
                                        local rotation = (rRot * 2.0 - 1.0) * math.pi
                                        local seedUniform = (globalTileX * 0.123 + globalTileY * 0.789 + tileType * 1.37) % 1.0

                                        sendUniformsDirect(shader, squashX, squashY, noiseAmp, noiseFreq, rotation, seedUniform)

                                        local scale = (pxSize * 2) / iw

                                        if lod >= 2 then
                                            -- LOD 2: Solo cuerpo rocoso principal
                                            love.graphics.setColor(color[1], color[2], color[3], 0.8 * alpha)
                                            love.graphics.draw(img, sx, sy, 0, scale, scale, ox, oy)
                                        elseif lod >= 1 then
                                            -- LOD 1: Sombra + Cuerpo
                                            local shadowScale = ((pxSize + 1) * 2) / iw
                                            love.graphics.setColor(0.1, 0.1, 0.1, 0.3 * alpha)
                                            love.graphics.draw(img, sx + 2, sy + 2, 0, shadowScale, shadowScale, ox, oy)
                                            love.graphics.setColor(color[1], color[2], color[3], alpha)
                                            love.graphics.draw(img, sx, sy, 0, scale, scale, ox, oy)
                                        else
                                            -- LOD 0: Sombra + Cuerpo + Cráteres + Especular
                                            local shadowScale = ((pxSize + 1) * 2) / iw
                                            love.graphics.setColor(0.1, 0.1, 0.1, 0.5 * alpha)
                                            love.graphics.draw(img, sx + 2, sy + 2, 0, shadowScale, shadowScale, ox, oy)
                                            love.graphics.setColor(color[1], color[2], color[3], alpha)
                                            love.graphics.draw(img, sx, sy, 0, scale, scale, ox, oy)

                                            if tileType >= MapConfig.ObjectType.ASTEROID_MEDIUM then
                                                love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, alpha)
                                                state = lcg(state)
                                                local r2 = state / 4294967296
                                                local numDetails = math.min(2 + math.floor(r2 * 3), math.floor(pxSize / 5))
                                                for i = 1, numDetails do
                                                    state = lcg(state)
                                                    local rA = state / 4294967296
                                                    state = lcg(state)
                                                    local rB = state / 4294967296
                                                    state = lcg(state)
                                                    local rC = state / 4294967296

                                                    local angle = (i / numDetails) * 2 * math.pi + rA * 0.5
                                                    local detailDist = (finalSize * 0.3 * rB) * zoom
                                                    local dX = sx + math.cos(angle) * detailDist
                                                    local dY = sy + math.sin(angle) * detailDist
                                                    local dSize = (finalSize * 0.2 * rC) * zoom
                                                    love.graphics.draw(img, dX, dY, 0, (dSize * 2) / iw, (dSize * 2) / ih, ox, oy)
                                                end
                                            end

                                            if isLarge then
                                                love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.7 * alpha)
                                                love.graphics.draw(img, sx - pxSize * 0.3, sy - pxSize * 0.3, 0, (pxSize * 0.4 * 2) / iw, (pxSize * 0.4 * 2) / ih, ox, oy)
                                            end
                                        end
                                    else
                                        -- Fallback sin shader (círculos vectoriales puros)
                                        local segments = lod >= 2 and 6 or (lod >= 1 and 8 or 12)
                                        if lod >= 2 then
                                            love.graphics.setColor(color[1], color[2], color[3], 0.8 * alpha)
                                            love.graphics.circle("fill", sx, sy, pxSize, segments)
                                        elseif lod >= 1 then
                                            love.graphics.setColor(0.1, 0.1, 0.1, 0.3 * alpha)
                                            love.graphics.circle("fill", sx + 2, sy + 2, pxSize + 1, segments)
                                            love.graphics.setColor(color[1], color[2], color[3], alpha)
                                            love.graphics.circle("fill", sx, sy, pxSize, segments)
                                        else
                                            love.graphics.setColor(0.1, 0.1, 0.1, 0.5 * alpha)
                                            love.graphics.circle("fill", sx + 2, sy + 2, pxSize + 1, segments)
                                            love.graphics.setColor(color[1], color[2], color[3], alpha)
                                            love.graphics.circle("fill", sx, sy, pxSize, segments)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if useShader then
        love.graphics.setShader()
    end
    love.graphics.pop()

    return rendered
end

--[[
    Dibuja un asteroide específico utilizando niveles de detalle (LOD) y shaders deterministas
    (Mantenido para compatibilidad e inspección individual)
--]]
function AsteroidRenderer.drawAsteroidLOD(mapRenderer, asteroidType, worldX, worldY, globalX, globalY, lod, camera)
    local state = (globalX * 1103515245 + globalY * 12345 + asteroidType * 2654435761) % 4294967296

    local baseSizes = (MapConfig.asteroids and MapConfig.asteroids.baseSizes) or {8, 15, 25}
    local sizeScale = (MapConfig.asteroids and MapConfig.asteroids.sizeScale) or 1.0
    local baseSize = (baseSizes[asteroidType] or 15) * sizeScale * (MapConfig.chunk.worldScale or 1.0)
    local colorIndex = (globalX + globalY) % #MapConfig.colors.asteroids + 1
    local color = MapConfig.colors.asteroids[colorIndex]

    state = lcg(state)
    local r1 = state / 4294967296
    local finalSize = baseSize * (0.8 + r1 * 0.4)

    local sx, sy = camera:worldToScreen(worldX, worldY)
    local alpha = mapRenderer.calculateEdgeFade(sx, sy, finalSize, camera)
    local pxSize = finalSize * (camera.zoom or 1)

    love.graphics.push()
    love.graphics.origin()

    local shader = ShaderManager and ShaderManager.getShader and ShaderManager.getShader("asteroid") or nil
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle") or nil

    if shader and img then
        state = lcg(state)
        local rSx = state / 4294967296
        state = lcg(state)
        local rSy = state / 4294967296
        state = lcg(state)
        local rAmp = state / 4294967296
        state = lcg(state)
        local rFreq = state / 4294967296
        state = lcg(state)
        local rRot = state / 4294967296

        local squashX = 0.8 + 0.5 * rSx
        local squashY = 0.8 + 0.5 * rSy
        local isLarge = (asteroidType == MapConfig.ObjectType.ASTEROID_LARGE)
        local ampBase = isLarge and 0.16 or 0.10
        local freqBase = isLarge and 16.0 or 12.0
        local noiseAmp = ampBase * (0.7 + 0.6 * rAmp)
        local noiseFreq = freqBase * (0.7 + 0.6 * rFreq)
        local rotation = (rRot * 2.0 - 1.0) * math.pi
        local seedUniform = (globalX * 0.123 + globalY * 0.789 + asteroidType * 1.37) % 1.0

        sendUniformsDirect(shader, squashX, squashY, noiseAmp, noiseFreq, rotation, seedUniform)

        love.graphics.setShader(shader)
        local iw, ih = img:getWidth(), img:getHeight()
        local scale = (pxSize * 2) / iw
        local ox, oy = iw * 0.5, ih * 0.5

        if lod >= 2 then
            love.graphics.setColor(color[1], color[2], color[3], 0.8 * alpha)
            love.graphics.draw(img, sx, sy, 0, scale, scale, ox, oy)
        elseif lod >= 1 then
            local shadowScale = ((pxSize + 1) * 2) / iw
            love.graphics.setColor(0.1, 0.1, 0.1, 0.3 * alpha)
            love.graphics.draw(img, sx + 2, sy + 2, 0, shadowScale, shadowScale, ox, oy)
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.draw(img, sx, sy, 0, scale, scale, ox, oy)
        else
            local shadowScale = ((pxSize + 1) * 2) / iw
            love.graphics.setColor(0.1, 0.1, 0.1, 0.5 * alpha)
            love.graphics.draw(img, sx + 2, sy + 2, 0, shadowScale, shadowScale, ox, oy)
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.draw(img, sx, sy, 0, scale, scale, ox, oy)

            if asteroidType >= MapConfig.ObjectType.ASTEROID_MEDIUM then
                love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, alpha)
                state = lcg(state)
                local r2 = state / 4294967296
                local numDetails = math.min(2 + math.floor(r2 * 3), math.floor(pxSize / 5))
                for i = 1, numDetails do
                    state = lcg(state)
                    local rA = state / 4294967296
                    state = lcg(state)
                    local rB = state / 4294967296
                    state = lcg(state)
                    local rC = state / 4294967296

                    local angle = (i / numDetails) * 2 * math.pi + rA * 0.5
                    local detailDist = (finalSize * 0.3 * rB) * (camera.zoom or 1)
                    local dX = sx + math.cos(angle) * detailDist
                    local dY = sy + math.sin(angle) * detailDist
                    local dSize = (finalSize * 0.2 * rC) * (camera.zoom or 1)
                    love.graphics.draw(img, dX, dY, 0, (dSize * 2) / iw, (dSize * 2) / ih, ox, oy)
                end
            end

            if isLarge then
                love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.7 * alpha)
                love.graphics.draw(img, sx - pxSize * 0.3, sy - pxSize * 0.3, 0, (pxSize * 0.4 * 2) / iw, (pxSize * 0.4 * 2) / ih, ox, oy)
            end
        end

        love.graphics.setShader()
    else
        local segments = lod >= 2 and 6 or (lod >= 1 and 8 or 12)
        if lod >= 2 then
            love.graphics.setColor(color[1], color[2], color[3], 0.8 * alpha)
            love.graphics.circle("fill", sx, sy, pxSize, segments)
        elseif lod >= 1 then
            love.graphics.setColor(0.1, 0.1, 0.1, 0.3 * alpha)
            love.graphics.circle("fill", sx + 2, sy + 2, pxSize + 1, segments)
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.circle("fill", sx, sy, pxSize, segments)
        else
            love.graphics.setColor(0.1, 0.1, 0.1, 0.5 * alpha)
            love.graphics.circle("fill", sx + 2, sy + 2, pxSize + 1, segments)
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.circle("fill", sx, sy, pxSize, segments)
        end
    end

    love.graphics.pop()
end

return AsteroidRenderer
