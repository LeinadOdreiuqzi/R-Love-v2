-- src/states/station/engine/door.lua
-- Puerta estilo Metroid: closed -> opening -> open -> closing.
-- Laterales (left/right): 1x3 tiles. Escotillas (up/down): 3x1 tiles.

local Config = require 'src.states.station.engine.config'

local Door = {}
Door.__index = Door

Door.KINDS = {
    normal = { color = { 0.35, 0.78, 1.00 }, locked = false },
    locked = { color = { 0.95, 0.32, 0.30 }, locked = true },
}

local VALID_SIDES = { left = true, right = true, up = true, down = true }

function Door.new(room, def, index)
    local side = def.side
    if not VALID_SIDES[side] then
        error(string.format("[Door] Sala '%s': lado de puerta inválido '%s'", room.id, tostring(side)))
    end
    local kind = def.kind or 'normal'
    if not Door.KINDS[kind] then
        error(string.format("[Door] Sala '%s': tipo de puerta desconocido '%s'", room.id, tostring(kind)))
    end

    local L = Config.door.length
    local tx, ty, tw, th
    if side == 'left' or side == 'right' then
        if not def.row then error(string.format("[Door] Sala '%s': puerta %s requiere 'row'", room.id, side)) end
        tx = (side == 'left') and 1 or room.tw
        ty, tw, th = def.row, 1, L
    else
        if not def.col then error(string.format("[Door] Sala '%s': escotilla %s requiere 'col'", room.id, side)) end
        ty = (side == 'up') and 1 or room.th
        tx, tw, th = def.col, L, 1
    end
    if tx < 1 or ty < 1 or tx + tw - 1 > room.tw or ty + th - 1 > room.th then
        error(string.format("[Door] Sala '%s': puerta %s fuera de los límites de la sala", room.id, side))
    end

    local T = Config.TILE
    local d = setmetatable({}, Door)
    d.room = room
    d.index = index
    d.id = string.format("%s:%s:%d", room.id, side, index)
    d.side = side
    d.kind = kind
    d.locked = Door.KINDS[kind].locked
    d.color = Door.KINDS[kind].color
    d.isHatch = (side == 'up' or side == 'down')
    d.tx, d.ty, d.tw, d.th = tx, ty, tw, th
    d.x = room.x + (tx - 1) * T
    d.y = room.y + (ty - 1) * T
    d.w = tw * T
    d.h = th * T
    d.state = 'closed'
    d.open = 0          -- 0 cerrada .. 1 abierta
    d.idle = 0          -- tiempo abierta sin el jugador cerca
    d.link = nil        -- { room = Room, door = Door }
    d.time = 0
    return d
end

function Door:isSolid()
    return self.state ~= 'open'
end

-- Rectángulo de proximidad ampliado (24 px hacia el interior de la sala)
function Door:getTriggerRect()
    local side = self.side
    local margin = 24
    if side == 'left' then
        return self.x - 2, self.y - 4, self.w + margin + 2, self.h + 8
    elseif side == 'right' then
        return self.x - margin, self.y - 4, self.w + margin + 2, self.h + 8
    elseif side == 'up' then
        return self.x - 4, self.y - 2, self.w + 8, self.h + margin + 2
    else -- 'down'
        return self.x - 4, self.y - 12, self.w + 8, self.h + 16
    end
end

-- Detecta si el jugador está en la zona frontal de proximidad
function Door:isPlayerNear(px, py, pw, ph)
    local tx, ty, tw, th = self:getTriggerRect()
    return px < tx + tw and px + pw > tx and py < ty + th and py + ph > ty
end

-- Detecta si el jugador ha cruzado el umbral medio de la compuerta
function Door:isPlayerCrossing(px, py, pw, ph)
    local side = self.side
    if side == 'right' then
        return (px + pw > self.x + self.w * 0.5)
    elseif side == 'left' then
        return (px < self.x + self.w * 0.5)
    elseif side == 'up' then
        return (py < self.y + self.h * 0.5)
    elseif side == 'down' then
        return (py + ph > self.y + self.h * 0.5)
    end
    return false
end

function Door:requestOpen()
    if self.locked then return false end
    if self.state == 'closed' or self.state == 'closing' then
        self.state = 'opening'
        self.idle = 0
    end
    return true
end

function Door:keepOpen()
    self.idle = 0
    if not self.locked and (self.state == 'closed' or self.state == 'closing') then
        self.state = 'opening'
    end
end

function Door:requestClose()
    if self.state == 'open' or self.state == 'opening' then
        self.state = 'closing'
    end
end

function Door:forceOpen()
    self.state, self.open, self.idle = 'open', 1, 0
end

function Door:forceClose()
    self.state, self.open, self.idle = 'closed', 0, 0
end

function Door:update(dt)
    self.time = self.time + dt
    local cfg = Config.door
    if self.state == 'opening' then
        self.open = self.open + dt / cfg.openTime
        if self.open >= 1 then self.open = 1; self.state = 'open' end
    elseif self.state == 'closing' then
        self.open = self.open - dt / cfg.closeTime
        if self.open <= 0 then self.open = 0; self.state = 'closed' end
    end
end

-- Dibujo (coordenadas de mundo) -------------------------------------------

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

function Door:draw()
    local P = Config.palette
    local x, y, w, h = self.x, self.y, self.w, self.h
    local c = self.color
    local closedness = 1 - self.open
    local pulse = 0.65 + 0.35 * math.sin(self.time * 4)

    if not self.isHatch then
        -- Marco: remates arriba y abajo
        setc(P.doorFrame)
        love.graphics.rectangle('fill', x - 2, y - 4, w + 4, 4)
        love.graphics.rectangle('fill', x - 2, y + h, w + 4, 4)
        setc(c, 0.9)
        love.graphics.rectangle('fill', x + 2, y - 3, w - 4, 1)
        love.graphics.rectangle('fill', x + 2, y + h + 2, w - 4, 1)

        -- Hojas que se separan verticalmente
        local half = (h * 0.5) * closedness
        if half > 0.5 then
            setc(P.doorShut)
            love.graphics.rectangle('fill', x + 2, y, w - 4, half)
            love.graphics.rectangle('fill', x + 2, y + h - half, w - 4, half)
            setc(c, pulse)
            love.graphics.rectangle('fill', x + 6, y, 4, half)
            love.graphics.rectangle('fill', x + 6, y + h - half, 4, half)
            setc(P.solidDark)
            love.graphics.rectangle('fill', x + 2, y + half - 1, w - 4, 1)
        end
    else
        -- Marco: remates a izquierda y derecha
        setc(P.doorFrame)
        love.graphics.rectangle('fill', x - 4, y - 2, 4, h + 4)
        love.graphics.rectangle('fill', x + w, y - 2, 4, h + 4)
        setc(c, 0.9)
        love.graphics.rectangle('fill', x - 3, y + 2, 1, h - 4)
        love.graphics.rectangle('fill', x + w + 2, y + 2, 1, h - 4)

        -- Hojas que se separan horizontalmente
        local half = (w * 0.5) * closedness
        if half > 0.5 then
            setc(P.doorShut)
            love.graphics.rectangle('fill', x, y + 2, half, h - 4)
            love.graphics.rectangle('fill', x + w - half, y + 2, half, h - 4)
            setc(c, pulse)
            love.graphics.rectangle('fill', x, y + 6, half, 4)
            love.graphics.rectangle('fill', x + w - half, y + 6, half, 4)
            setc(P.solidDark)
            love.graphics.rectangle('fill', x + half - 1, y + 2, 1, h - 4)
        end
    end
end

return Door
