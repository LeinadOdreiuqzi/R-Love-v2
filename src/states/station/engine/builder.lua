-- src/states/station/engine/builder.lua
-- DSL (Domain-Specific Language) para construir salas Metroidvania masivas (hasta 256x256 tiles).
-- Permite estructurar sectores gigantescos mediante primitivas geométricas limpias
-- y estampar bloques ASCII detallados en cualquier coordenada.

local Tilemap = require 'src.states.station.engine.tilemap'

local Builder = {}
Builder.__index = Builder

function Builder.new(id, tw, th, opts)
    opts = opts or {}
    local b = setmetatable({}, Builder)
    b.id = id
    b.name = opts.name or id
    b.tw = tw or 256
    b.th = th or 256
    b.accent = opts.accent or { 0.35, 0.78, 1.00 }
    b.legend = opts.legend or Tilemap.DEFAULT_LEGEND
    b.doors = {}
    b.spawns = {}
    b.windows = {}
    b.windowMap = {}

    -- Inicializar matriz de tiles llena de Tilemap.EMPTY
    b.tiles = {}
    for ty = 1, b.th do
        local row = {}
        for tx = 1, b.tw do
            row[tx] = Tilemap.EMPTY
        end
        b.tiles[ty] = row
    end

    return b
end

-- Resuelve un carácter o código a su valor numérico de Tilemap
function Builder:_resolve(tile)
    if type(tile) == 'number' then return tile end
    return self.legend[tile] or Tilemap.SOLID
end

-- Rellena un área rectangular [tx, ty] hasta [tx+w-1, ty+h-1]
function Builder:fill(tx, ty, w, h, tile)
    local code = self:_resolve(tile)
    local x1 = math.max(1, tx)
    local y1 = math.max(1, ty)
    local x2 = math.min(self.tw, tx + (w or 1) - 1)
    local y2 = math.min(self.th, ty + (h or 1) - 1)
    for y = y1, y2 do
        local row = self.tiles[y]
        for x = x1, x2 do
            row[x] = code
        end
    end
    return self
end

-- Dibuja un marco rectangular hueco con grosor especificado
function Builder:box(tx, ty, w, h, tile, thickness)
    thickness = thickness or 1
    local code = self:_resolve(tile or '#')
    -- Techo y suelo
    self:fill(tx, ty, w, thickness, code)
    self:fill(tx, ty + h - thickness, w, thickness, code)
    -- Muros laterales
    self:fill(tx, ty, thickness, h, code)
    self:fill(tx + w - thickness, ty, thickness, h, code)
    return self
end

-- Muro o piso horizontal
function Builder:hwall(tx, ty, len, thickness, tile)
    return self:fill(tx, ty, len, thickness or 1, tile or '#')
end

-- Muro o mampara vertical
function Builder:vwall(tx, ty, len, thickness, tile)
    return self:fill(tx, ty, thickness or 1, len, tile or '#')
end

-- Plataforma one-way atravesable
function Builder:platform(tx, ty, len)
    return self:fill(tx, ty, len, 1, '=')
end

-- Pasarela suspendida
function Builder:catwalk(tx, ty, len)
    return self:fill(tx, ty, len, 1, '=')
end

-- Plataforma soportada físicamente (sin flotar en el aire)
function Builder:supportedPlatform(tx, ty, len, style)
    style = style or 'pillars'
    self:platform(tx, ty, len)

    if style == 'pillars' then
        -- Desciende pilares de soporte hasta encontrar sólido
        local cols = { tx + 1, tx + len - 2 }
        if len >= 16 then table.insert(cols, tx + math.floor(len * 0.5)) end
        for _, col in ipairs(cols) do
            if col >= 1 and col <= self.tw then
                for y = ty + 1, self.th do
                    if self.tiles[y] and self.tiles[y][col] == Tilemap.SOLID then break end
                    if self.tiles[y] then self.tiles[y][col] = Tilemap.BG end
                end
            end
        end
    elseif style == 'suspended' then
        -- Asciende tirantes de sujeción hasta el techo
        local cols = { tx + 1, tx + len - 2 }
        for _, col in ipairs(cols) do
            if col >= 1 and col <= self.tw then
                for y = ty - 1, 1, -1 do
                    if self.tiles[y] and self.tiles[y][col] == Tilemap.SOLID then break end
                    if self.tiles[y] then self.tiles[y][col] = Tilemap.BG end
                end
            end
        end
    elseif style == 'brackets' then
        -- Ménsulas diagonales/cortas en los extremos
        if ty + 1 <= self.th then
            if tx >= 1 then self.tiles[ty + 1][tx] = Tilemap.BG end
            if tx + len - 1 <= self.tw then self.tiles[ty + 1][tx + len - 1] = Tilemap.BG end
        end
    end
    return self
end

-- Ventanal de observación al espacio exterior tipo pantalla panorámica wide
-- Apertura de fondo arquitectónica limpia sin recortes escalonados.
-- No modifica self.tiles para evitar colisiones con plataformas, pilares u objetos en primer plano.
function Builder:window(tx, ty, w, h, opts)
    opts = opts or {}
    local Config = require 'src.states.station.engine.config'
    local T = Config.TILE
    local winW = math.max(1, w or 1)
    local winH = math.max(1, h or 1)

    local win = {
        tx = tx,
        ty = ty,
        tw = winW,
        th = winH,
        x = (tx - 1) * T,
        y = (ty - 1) * T,
        w = winW * T,
        h = winH * T,
        tint = opts.tint,
        style = opts.style or 'widescreen',
    }
    table.insert(self.windows, win)

    -- Marcar mapa bidimensional para consulta O(1) rectangular limpia
    local y1 = math.max(1, ty)
    local y2 = math.min(self.th, ty + winH - 1)
    local x1 = math.max(1, tx)
    local x2 = math.min(self.tw, tx + winW - 1)

    for y = y1, y2 do
        self.windowMap[y] = self.windowMap[y] or {}
        for x = x1, x2 do
            self.windowMap[y][x] = win
        end
    end

    return self
end

-- Ventanal panorámico ultra-wide sin bordes (apertura limpia al espacio exterior)
function Builder:wideScreen(tx, ty, w, h, opts)
    opts = opts or {}
    opts.style = 'widescreen'
    return self:window(tx, ty, w, h, opts)
end

-- Compatibilidad: redirige al formato ultra-wide limpio sin bordes
function Builder:seamlessWindow(tx, ty, w, h, opts)
    return self:wideScreen(tx, ty, w, h, opts)
end

function Builder:vaultedWindow(tx, ty, w, h, chamfer, opts)
    return self:wideScreen(tx, ty, w, h, opts)
end

-- Pilar estructural de fondo
function Builder:pillar(tx, ty, len)
    return self:fill(tx, ty, 1, len, ':')
end

-- Conducto o tubería de fondo (horizontal o vertical)
function Builder:conduit(tx, ty, len, isVertical)
    if isVertical then
        return self:fill(tx, ty, 1, len, ':')
    else
        return self:fill(tx, ty, len, 1, ':')
    end
end

-- Estampa un bloque ASCII hecho a mano en las coordenadas (tx, ty)
function Builder:stamp(tx, ty, asciiRows, customLegend)
    local leg = customLegend or self.legend
    for rIdx, line in ipairs(asciiRows) do
        local targetY = ty + rIdx - 1
        if targetY >= 1 and targetY <= self.th then
            local row = self.tiles[targetY]
            for cIdx = 1, #line do
                local targetX = tx + cIdx - 1
                if targetX >= 1 and targetX <= self.tw then
                    local ch = line:sub(cIdx, cIdx)
                    if ch ~= ' ' then -- espacio = transparente (no sobreescribe)
                        local code = leg[ch] or Tilemap.EMPTY
                        row[targetX] = code
                    end
                end
            end
        end
    end
    return self
end

-- Registra una puerta Metroid y despeja automáticamente el paso frontal y suelo
function Builder:door(side, pos, kind)
    local Config = require 'src.states.station.engine.config'
    local doorLen = (Config and Config.door and Config.door.length) or 3
    local d = { side = side, kind = kind or 'normal' }
    if side == 'left' or side == 'right' then
        d.row = pos
        local row = pos
        -- Despejar el hueco de la puerta y los 5 tiles de aproximación
        for y = row, row + doorLen - 1 do
            if y >= 1 and y <= self.th then
                if side == 'left' then
                    for x = 1, math.min(self.tw, 5) do self.tiles[y][x] = Tilemap.EMPTY end
                else
                    for x = math.max(1, self.tw - 4), self.tw do self.tiles[y][x] = Tilemap.EMPTY end
                end
            end
        end
        -- Asegurar suelo sólido bajo la puerta
        local fy = row + doorLen
        if fy >= 1 and fy <= self.th then
            if side == 'left' then
                for x = 1, math.min(self.tw, 5) do self.tiles[fy][x] = Tilemap.SOLID end
            else
                for x = math.max(1, self.tw - 4), self.tw do self.tiles[fy][x] = Tilemap.SOLID end
            end
        end
    else
        d.col = pos
        local col = pos
        if side == 'down' then
            for y = math.max(1, self.th - 4), self.th do
                for x = col, math.min(self.tw, col + doorLen - 1) do self.tiles[y][x] = Tilemap.EMPTY end
            end
        else -- up
            for y = 1, math.min(self.th, 5) do
                for x = col, math.min(self.tw, col + doorLen - 1) do self.tiles[y][x] = Tilemap.EMPTY end
            end
        end
    end
    table.insert(self.doors, d)
    return self
end

-- Registra un punto de aparición
function Builder:spawn(name, col, row)
    self.spawns[name or 'default'] = { col = col, row = row }
    return self
end

-- Construye la definición final de la sala para el motor
function Builder:build()
    return {
        id = self.id,
        name = self.name,
        size = { tw = self.tw, th = self.th },
        accent = self.accent,
        tiles = self.tiles,
        doors = self.doors,
        spawns = self.spawns,
        windows = self.windows,
        windowMap = self.windowMap,
    }
end

return Builder
