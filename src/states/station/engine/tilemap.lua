-- src/states/station/engine/tilemap.lua
-- Parser de tilemaps ASCII y horneado (bake) de la capa estática de una sala.

local Config = require 'src.states.station.engine.config'

local Tilemap = {}

Tilemap.EMPTY  = 0
Tilemap.SOLID  = 1
Tilemap.ONEWAY = 2
Tilemap.BG     = 3   -- estructura de fondo, no colisiona
Tilemap.WINDOW = 4   -- ventanal acristalado al espacio / fondo

Tilemap.DEFAULT_LEGEND = {
    ['.'] = Tilemap.EMPTY,
    ['#'] = Tilemap.SOLID,
    ['='] = Tilemap.ONEWAY,
    [':'] = Tilemap.BG,
    ['W'] = Tilemap.WINDOW,
    ['@'] = Tilemap.WINDOW,
    ['D'] = Tilemap.EMPTY,   -- marcador visual opcional de puerta
}

-- rows: array de strings; devuelve tiles[ty][tx] (1-based)
function Tilemap.parse(rows, tw, th, legend, roomId)
    legend = legend or Tilemap.DEFAULT_LEGEND
    if type(rows) ~= 'table' then
        error(string.format("[Tilemap] Sala '%s': falta layers.collision", tostring(roomId)))
    end
    if #rows ~= th then
        error(string.format("[Tilemap] Sala '%s': se esperaban %d filas, hay %d", roomId, th, #rows))
    end
    local tiles = {}
    for ty = 1, th do
        local line = rows[ty]
        if #line ~= tw then
            error(string.format("[Tilemap] Sala '%s': la fila %d tiene %d columnas, se esperaban %d",
                roomId, ty, #line, tw))
        end
        local row = {}
        for tx = 1, tw do
            local ch = line:sub(tx, tx)
            local code = legend[ch]
            if code == nil then
                error(string.format("[Tilemap] Sala '%s': carácter desconocido '%s' en fila %d, columna %d",
                    roomId, ch, ty, tx))
            end
            row[tx] = code
        end
        tiles[ty] = row
    end
    return tiles
end

-- Render procedural -------------------------------------------------------

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local function isWindowAt(tiles, tx, ty, tw, th)
    if tx < 1 or ty < 1 or tx > tw or ty > th then return false end
    local row = tiles[ty]
    return row and row[tx] == Tilemap.WINDOW
end

local function drawLegacyWindowTile(room, tiles, tx, ty, x, y)
    local P, T = Config.palette, Config.TILE
    local tw, th = room.tw, room.th

    love.graphics.setColor(P.windowGlass[1], P.windowGlass[2], P.windowGlass[3], P.windowGlass[4] or 0.35)
    love.graphics.rectangle('fill', x, y, T, T)

    local openU = not isWindowAt(tiles, tx, ty - 1, tw, th)
    local openD = not isWindowAt(tiles, tx, ty + 1, tw, th)
    local openL = not isWindowAt(tiles, tx - 1, ty, tw, th)
    local openR = not isWindowAt(tiles, tx + 1, ty, tw, th)

    love.graphics.setColor(P.windowFrame[1], P.windowFrame[2], P.windowFrame[3], 0.95)
    if openU then love.graphics.rectangle('fill', x, y, T, 2) end
    if openD then love.graphics.rectangle('fill', x, y + T - 2, T, 2) end
    if openL then love.graphics.rectangle('fill', x, y, 2, T) end
    if openR then love.graphics.rectangle('fill', x + T - 2, y, 2, T) end
end

-- Renderiza una apertura arquitectónica de ventanal completa
local function drawWindowAperture(room, win, rx1, ry1, rx2, ry2)
    local P, T = Config.palette, Config.TILE
    local wx = room.x + (win.tx - 1) * T
    local wy = room.y + (win.ty - 1) * T
    local ww = win.tw * T
    local wh = win.th * T

    -- Culling con el rectángulo de cámara
    if wx + ww < rx1 or wx > rx2 or wy + wh < ry1 or wy > ry2 then
        return
    end

    -- 1. Cristal de alta transparencia espacial (sin bordes, biseles ni marcos de ventanal)
    -- El espacio cósmico y el anillo giran libremente en el fondo
    local glassColor = win.tint or P.windowGlass
    love.graphics.setColor(glassColor[1], glassColor[2], glassColor[3], glassColor[4] or 0.12)
    love.graphics.rectangle('fill', wx, wy, ww, wh)

    -- 2. Sombra de profundidad arquitectónica natural (grosor de la pared del casco, sin marco)
    -- Sombra superior proyectada por el techo
    love.graphics.setColor(0.01, 0.02, 0.04, 0.40)
    love.graphics.rectangle('fill', wx, wy, ww, 2)
    love.graphics.setColor(0.01, 0.02, 0.04, 0.18)
    love.graphics.rectangle('fill', wx, wy + 2, ww, 2)
    -- Sombras laterales sutiles donde la mampara corta al vacío
    love.graphics.setColor(0.01, 0.02, 0.04, 0.25)
    love.graphics.rectangle('fill', wx, wy, 2, wh)
    love.graphics.rectangle('fill', wx + ww - 2, wy, 2, wh)

    -- 3. Reflejo especular diagonal cinemático ultra-suave (sin líneas divisorias ni clips)
    local stepReflect = 240
    local startRef = math.floor(wx / stepReflect) * stepReflect
    for rx = startRef - wh, wx + ww + wh, stepReflect do
        local rx1 = math.max(wx, rx)
        local rx2 = math.min(wx + ww, rx + 24)
        local rx3 = math.min(wx + ww, rx + wh * 0.70 + 24)
        local rx4 = math.max(wx, rx + wh * 0.70)
        if rx2 > rx1 and rx3 > rx4 then
            love.graphics.setColor(0.75, 0.90, 1.00, 0.025)
            love.graphics.polygon('fill', rx1, wy, rx2, wy, rx3, wy + wh, rx4, wy + wh)
        end
    end
end

local function drawBackWall(room, rx1, ry1, rx2, ry2, tx1, ty1, tx2, ty2)
    local P, T = Config.palette, Config.TILE
    local tiles = room.tiles

    -- Paneles arquitectónicos ultra-wide (bandas horizontales continuas de 4 tiles = 64px)
    -- y módulos longitudinales de 16 tiles (256px), eliminando cualquier cuadrícula 16x16
    for ty = ty1, ty2 do
        local row = tiles[ty]
        if row then
            local bandIdx = math.floor((ty - 1) / 4)
            local isBandSeam = (ty % 4 == 0) -- junta horizontal entre paneles ultra-wide

            for tx = tx1, tx2 do
                local isWin = (room.isWindowTile and room:isWindowTile(tx, ty)) or (row[tx] == Tilemap.WINDOW)
                if not isWin then
                    local x = room.x + (tx - 1) * T
                    local y = room.y + (ty - 1) * T

                    -- 1. Capa base sólida y limpia del panel de casco
                    setc(P.backWall)
                    love.graphics.rectangle('fill', x, y, T, T)

                    -- 2. Tono suave uniforme por franja ultra-wide (NO celda por celda)
                    if bandIdx % 2 == 1 then
                        setc(P.backPanel, 0.35)
                        love.graphics.rectangle('fill', x, y, T, T)
                    end

                    -- 3. Ranura horizontal de unión entre paneles ultra-wide
                    if isBandSeam then
                        setc(P.backSeam, 0.85)
                        love.graphics.rectangle('fill', x, y + T - 1, T, 1)
                        setc(P.bgStructHi, 0.22)
                        love.graphics.rectangle('fill', x, y + T - 2, T, 1)
                    end

                    -- 4. Junta vertical longitudinal cada 16 tiles (256px de ancho)
                    if (tx - 1) % 16 == 0 then
                        setc(P.backSeam, 0.55)
                        love.graphics.rectangle('fill', x, y, 1, T)
                        if isBandSeam then
                            setc(P.rivet, 0.65)
                            love.graphics.rectangle('fill', x + 1, y + T - 3, 2, 2)
                        end
                    end
                end
            end
        end
    end

    -- Franja sutil de iluminación continua de la cubierta (respetando aperturas de ventanal)
    local a = room.accent
    local screenH = Config.SCREEN_H
    local sy1 = math.floor((ry1 - room.y) / screenH)
    local sy2 = math.ceil((ry2 - room.y) / screenH)
    for sy = sy1, sy2 do
        local y = room.y + sy * screenH + T * 3
        if y >= ry1 and y <= ry2 then
            local tyLight = math.floor((y - room.y) / T) + 1
            for tx = tx1, tx2 do
                local isWin = (room.isWindowTile and room:isWindowTile(tx, tyLight))
                if not isWin then
                    local x = room.x + (tx - 1) * T
                    love.graphics.setColor(a[1], a[2], a[3], 0.10)
                    love.graphics.rectangle('fill', x, y, T, 2)
                end
            end
        end
    end
end

local function drawBgStruct(room, tiles, tx, ty, x, y)
    local P, T = Config.palette, Config.TILE
    setc(P.bgStruct)
    love.graphics.rectangle('fill', x + 3, y, T - 6, T)
    setc(P.bgStructHi)
    love.graphics.rectangle('fill', x + 3, y, 1, T)
    setc(P.backSeam)
    love.graphics.rectangle('fill', x + T - 4, y, 1, T)
    -- Remate superior/inferior cuando termina el pilar
    local up = tiles[ty - 1] and tiles[ty - 1][tx]
    local dn = tiles[ty + 1] and tiles[ty + 1][tx]
    if up ~= Tilemap.BG then
        setc(P.bgStructHi)
        love.graphics.rectangle('fill', x + 1, y, T - 2, 2)
    end
    if dn ~= Tilemap.BG then
        setc(P.bgStructHi)
        love.graphics.rectangle('fill', x + 1, y + T - 2, T - 2, 2)
    end
end

local function isSolidAt(tiles, tx, ty, tw, th)
    if tx < 1 or ty < 1 or tx > tw or ty > th then return true end
    local row = tiles[ty]
    return row and row[tx] == Tilemap.SOLID
end

local function drawSolid(room, tiles, tx, ty, x, y)
    local P, T = Config.palette, Config.TILE
    local tw, th = room.tw, room.th
    local openU = not isSolidAt(tiles, tx, ty - 1, tw, th)
    local openD = not isSolidAt(tiles, tx, ty + 1, tw, th)
    local openL = not isSolidAt(tiles, tx - 1, ty, tw, th)
    local openR = not isSolidAt(tiles, tx + 1, ty, tw, th)
    local exposed = openU or openD or openL or openR

    setc(exposed and P.solid or P.solidInner)
    love.graphics.rectangle('fill', x, y, T, T)

    if not exposed then
        -- Interior: patrón sutil
        if (tx + ty) % 2 == 0 then
            setc(P.solidDark)
            love.graphics.rectangle('fill', x + 7, y + 7, 2, 2)
        end
        return
    end

    if openU then
        setc(P.solidLight)
        love.graphics.rectangle('fill', x, y, T, 2)
        setc(P.rivet)
        love.graphics.rectangle('fill', x + 3, y + 5, 1, 1)
        love.graphics.rectangle('fill', x + 12, y + 5, 1, 1)
    end
    if openD then
        setc(P.solidDark)
        love.graphics.rectangle('fill', x, y + T - 2, T, 2)
    end
    if openL then
        setc(P.solidLight, 0.7)
        love.graphics.rectangle('fill', x, y, 1, T)
    end
    if openR then
        setc(P.solidDark)
        love.graphics.rectangle('fill', x + T - 1, y, 1, T)
    end
end

local function drawOneWay(room, tiles, tx, ty, x, y)
    local P, T = Config.palette, Config.TILE
    setc(P.oneway)
    love.graphics.rectangle('fill', x, y, T, 4)
    setc(P.solidLight)
    love.graphics.rectangle('fill', x, y, T, 1)
    setc(P.onewayDark)
    love.graphics.rectangle('fill', x, y + 4, T, 1)
    -- Soportes en los extremos de la plataforma
    local row = tiles[ty]
    local left = row and row[tx - 1]
    local right = row and row[tx + 1]
    if left ~= Tilemap.ONEWAY then
        setc(P.onewayDark)
        love.graphics.polygon('fill', x, y + 5, x + 6, y + 5, x, y + 11)
    end
    if right ~= Tilemap.ONEWAY then
        setc(P.onewayDark)
        love.graphics.polygon('fill', x + T, y + 5, x + T - 6, y + 5, x + T, y + 11)
    end
end

-- Dibuja en tiempo real con frustum culling sobre el viewport visible (sin límite de tamaño de sala)
function Tilemap.drawVisible(room, camX, camY, viewW, viewH)
    local rx1 = math.max(room.x, camX)
    local ry1 = math.max(room.y, camY)
    local rx2 = math.min(room.x + room.w, camX + viewW)
    local ry2 = math.min(room.y + room.h, camY + viewH)
    if rx2 <= rx1 or ry2 <= ry1 then return end

    local T = Config.TILE
    local tiles = room.tiles
    local tx1 = math.max(1, math.floor((rx1 - room.x) / T) + 1)
    local ty1 = math.max(1, math.floor((ry1 - room.y) / T) + 1)
    local tx2 = math.min(room.tw, math.ceil((rx2 - room.x) / T))
    local ty2 = math.min(room.th, math.ceil((ry2 - room.y) / T))

    -- Pasada 0: fondo metálico de sala (respeta aperturas de ventanas)
    drawBackWall(room, rx1, ry1, rx2, ry2, tx1, ty1, tx2, ty2)

    -- Pasada 1: aperturas de ventanales arquitectónicos al exterior (capa de fondo independiente)
    if room.windows and #room.windows > 0 then
        for _, win in ipairs(room.windows) do
            drawWindowAperture(room, win, rx1, ry1, rx2, ry2)
        end
    end

    -- Fallback para tiles WINDOW legados no registrados en room.windows
    for ty = ty1, ty2 do
        local row = tiles[ty]
        if row then
            for tx = tx1, tx2 do
                if row[tx] == Tilemap.WINDOW and not (room.isWindowTile and room:isWindowTile(tx, ty)) then
                    local x = room.x + (tx - 1) * T
                    local y = room.y + (ty - 1) * T
                    drawLegacyWindowTile(room, tiles, tx, ty, x, y)
                end
            end
        end
    end

    -- Pasada 2: estructuras de fondo
    for ty = ty1, ty2 do
        local row = tiles[ty]
        if row then
            for tx = tx1, tx2 do
                if row[tx] == Tilemap.BG then
                    local x = room.x + (tx - 1) * T
                    local y = room.y + (ty - 1) * T
                    drawBgStruct(room, tiles, tx, ty, x, y)
                end
            end
        end
    end

    -- Pasada 2: sólidos y one-way
    for ty = ty1, ty2 do
        local row = tiles[ty]
        if row then
            for tx = tx1, tx2 do
                local code = row[tx]
                if code == Tilemap.SOLID then
                    local x = room.x + (tx - 1) * T
                    local y = room.y + (ty - 1) * T
                    drawSolid(room, tiles, tx, ty, x, y)
                elseif code == Tilemap.ONEWAY then
                    local x = room.x + (tx - 1) * T
                    local y = room.y + (ty - 1) * T
                    drawOneWay(room, tiles, tx, ty, x, y)
                end
            end
        end
    end
end

-- Bake compatible para salas que aún llamen a room:bake()
function Tilemap.bake(room)
    return nil
end

return Tilemap
