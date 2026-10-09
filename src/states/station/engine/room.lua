-- src/states/station/engine/room.lua
-- Instancia de una sala: tiles, puertas, spawns y posición en el mundo.

local Config = require 'src.states.station.engine.config'
local Tilemap = require 'src.states.station.engine.tilemap'
local Door = require 'src.states.station.engine.door'

local Room = {}
Room.__index = Room

-- def: tabla de la sala (archivo en rooms/<estación>/<id>.lua)
-- gx, gy: posición en la cuadrícula global de pantallas
function Room.new(def, gx, gy, tx, ty)
    if type(def) ~= 'table' or not def.id then
        error("[Room] Definición de sala inválida (falta 'id')")
    end
    local size = def.size or { w = 1, h = 1 }
    local T = Config.TILE

    local r = setmetatable({}, Room)
    r.id = def.id
    r.name = def.name or def.id
    r.def = def

    -- Soporte para dimensiones directas en tiles (ej. 256x256) o en pantallas (ej. 1x1, 2x1)
    if size.tw and size.th then
        r.tw, r.th = size.tw, size.th
        r.sw = math.ceil(r.tw / Config.SCREEN_TW)
        r.sh = math.ceil(r.th / Config.SCREEN_TH)
    else
        r.sw, r.sh = size.w or 1, size.h or 1
        r.tw, r.th = r.sw * Config.SCREEN_TW, r.sh * Config.SCREEN_TH
    end

    if tx and ty then
        r.tx, r.ty = tx, ty
        r.gx = math.floor(tx / Config.SCREEN_TW)
        r.gy = math.floor(ty / Config.SCREEN_TH)
    else
        r.gx, r.gy = gx or 0, gy or 0
        r.tx, r.ty = r.gx * Config.SCREEN_TW, r.gy * Config.SCREEN_TH   -- origen global en tiles (0-based)
    end
    r.x, r.y = r.tx * T, r.ty * T                               -- origen en mundo (px)
    r.w, r.h = r.tw * T, r.th * T
    r.accent = def.accent or { 0.35, 0.78, 1.00 }
    r.spawns = def.spawns or {}
    r.windows = def.windows or {}
    r.windowMap = def.windowMap or {}

    -- Reconstruir mapa rápido si la sala viene con array de ventanas sin mapa previo
    if (not def.windowMap or not next(r.windowMap)) and #r.windows > 0 then
        r.windowMap = {}
        for _, win in ipairs(r.windows) do
            for y = win.ty, win.ty + win.th - 1 do
                r.windowMap[y] = r.windowMap[y] or {}
                for x = win.tx, win.tx + win.tw - 1 do
                    r.windowMap[y][x] = win
                end
            end
        end
    end

    -- Usar tiles ya construidos por el Builder o parsear capas ASCII
    if def.tiles then
        r.tiles = def.tiles
    else
        r.tiles = Tilemap.parse(def.layers and def.layers.collision, r.tw, r.th, def.legend, r.id)
    end

    -- Puertas: se abre el hueco en el tilemap y se registran por tile
    r.doors = {}
    r.doorAt = {}
    for i, dd in ipairs(def.doors or {}) do
        local d = Door.new(r, dd, i)
        for ty = d.ty, d.ty + d.th - 1 do
            r.doorAt[ty] = r.doorAt[ty] or {}
            for tx = d.tx, d.tx + d.tw - 1 do
                r.tiles[ty][tx] = Tilemap.EMPTY
                r.doorAt[ty][tx] = d
            end
            -- Despejar el paso frontal (evita que muros perimetrales de grosor >= 2 tapen la puerta)
            if d.side == 'left' then
                for x = 1, math.min(r.tw, 3) do
                    r.tiles[ty][x] = Tilemap.EMPTY
                end
            elseif d.side == 'right' then
                for x = math.max(1, r.tw - 2), r.tw do
                    r.tiles[ty][x] = Tilemap.EMPTY
                end
            end
        end

        -- Garantizar suelo sólido firme bajo la puerta lateral
        if d.side == 'left' or d.side == 'right' then
            local floorY = d.ty + d.th
            if floorY <= r.th then
                if d.side == 'left' then
                    for x = 1, math.min(r.tw, 3) do
                        r.tiles[floorY][x] = Tilemap.SOLID
                    end
                else
                    for x = math.max(1, r.tw - 2), r.tw do
                        r.tiles[floorY][x] = Tilemap.SOLID
                    end
                end
            end
        elseif d.side == 'down' then
            -- Para escotilla en el suelo: despejar los tiles verticales hacia arriba para poder pisarla
            for y = math.max(1, d.ty - 3), d.ty - 1 do
                for x = d.tx, d.tx + d.tw - 1 do
                    r.tiles[y][x] = Tilemap.EMPTY
                end
            end
        elseif d.side == 'up' then
            -- Para escotilla en el techo: despejar los tiles verticales hacia abajo para poder caer
            for y = d.ty + 1, math.min(r.th, d.ty + 3) do
                for x = d.tx, d.tx + d.tw - 1 do
                    r.tiles[y][x] = Tilemap.EMPTY
                end
            end
        end

        table.insert(r.doors, d)
    end

    r.canvas = nil
    return r
end

-- Tiles (coordenadas locales 1-based). Fuera de la sala = sólido.
function Room:tileAt(tx, ty)
    if tx < 1 or ty < 1 or tx > self.tw or ty > self.th then return Tilemap.SOLID end
    return self.tiles[ty][tx]
end

function Room:isSolidTile(tx, ty)
    local row = self.doorAt[ty]
    local d = row and row[tx]
    if d then return d:isSolid() end
    return self:tileAt(tx, ty) == Tilemap.SOLID
end

function Room:isOneWayTile(tx, ty)
    return self:tileAt(tx, ty) == Tilemap.ONEWAY
end

function Room:isWindowTile(tx, ty)
    local row = self.windowMap[ty]
    return (row and row[tx]) ~= nil
end

function Room:windowAt(tx, ty)
    local row = self.windowMap[ty]
    return row and row[tx]
end

-- Conversión mundo -> tile local
function Room:worldToTile(px, py)
    local T = Config.TILE
    return math.floor((px - self.x) / T) + 1, math.floor((py - self.y) / T) + 1
end

-- Posición de mundo para un spawn (pies apoyados en la base del tile indicado)
function Room:spawnPosition(name, pw, ph)
    local s = self.spawns[name or 'default']
    if not s then
        error(string.format("[Room] Sala '%s': spawn '%s' no existe", self.id, tostring(name)))
    end
    local T = Config.TILE
    local x = self.x + (s.col - 1) * T + (T - pw) * 0.5
    local y = self.y + s.row * T - ph
    return x, y
end

function Room:intersectsRect(x, y, w, h)
    return x < self.x + self.w and x + w > self.x and y < self.y + self.h and y + h > self.y
end

function Room:bake()
    if self.canvas then self.canvas:release() end
    self.canvas = Tilemap.bake(self)
end

function Room:update(dt)
    for _, d in ipairs(self.doors) do d:update(dt) end
end

function Room:draw(camX, camY, viewW, viewH)
    camX = camX or self.x
    camY = camY or self.y
    viewW = viewW or Config.VIEW_W
    viewH = viewH or Config.VIEW_H

    Tilemap.drawVisible(self, camX, camY, viewW, viewH)
    for _, d in ipairs(self.doors) do
        d:draw()
    end
end

function Room:release()
end

return Room
