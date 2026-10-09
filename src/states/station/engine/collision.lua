-- src/states/station/engine/collision.lua
-- Colisión AABB contra tiles, separada por eje y con sub-pasos (sin tunneling).
-- body: { x, y, w, h, dropThrough? }

local Config = require 'src.states.station.engine.config'

local Collision = {}

local EPS = 1e-4

local function rowRange(room, y, h)
    local T = Config.TILE
    local t1 = math.floor((y - room.y) / T) + 1
    local t2 = math.floor((y + h - EPS - room.y) / T) + 1
    return t1, t2
end

local function colRange(room, x, w)
    local T = Config.TILE
    local t1 = math.floor((x - room.x) / T) + 1
    local t2 = math.floor((x + w - EPS - room.x) / T) + 1
    return t1, t2
end

local function substeps(d)
    local maxStep = Config.TILE * 0.5
    return math.max(1, math.ceil(math.abs(d) / maxStep))
end

-- Devuelve true si chocó
function Collision.moveX(body, room, dx)
    if dx == 0 then return false end
    local T = Config.TILE
    local n = substeps(dx)
    local step = dx / n
    for _ = 1, n do
        local nx = body.x + step
        local ty1, ty2 = rowRange(room, body.y, body.h)
        if step > 0 then
            local tx = math.floor((nx + body.w - EPS - room.x) / T) + 1
            for ty = ty1, ty2 do
                if room:isSolidTile(tx, ty) then
                    body.x = room.x + (tx - 1) * T - body.w
                    return true
                end
            end
        else
            local tx = math.floor((nx - room.x) / T) + 1
            for ty = ty1, ty2 do
                if room:isSolidTile(tx, ty) then
                    body.x = room.x + tx * T
                    return true
                end
            end
        end
        body.x = nx
    end
    return false
end

-- Devuelve hit, landed
function Collision.moveY(body, room, dy)
    if dy == 0 then return false, false end
    local T = Config.TILE
    local n = substeps(dy)
    local step = dy / n
    for _ = 1, n do
        local ny = body.y + step
        local tx1, tx2 = colRange(room, body.x, body.w)
        if step > 0 then
            local prevBottom = body.y + body.h
            local ty = math.floor((ny + body.h - EPS - room.y) / T) + 1
            local top = room.y + (ty - 1) * T
            for tx = tx1, tx2 do
                local solid = room:isSolidTile(tx, ty)
                local oneway = (not solid) and (not body.dropThrough)
                    and room:isOneWayTile(tx, ty) and prevBottom <= top + EPS
                if solid or oneway then
                    body.y = top - body.h
                    return true, true
                end
            end
        else
            local ty = math.floor((ny - room.y) / T) + 1
            for tx = tx1, tx2 do
                if room:isSolidTile(tx, ty) then
                    body.y = room.y + ty * T
                    return true, false
                end
            end
        end
        body.y = ny
    end
    return false, false
end

-- ¿Está el cuerpo apoyado únicamente sobre plataformas one-way?
function Collision.isOnOneWayOnly(body, room)
    local T = Config.TILE
    local ty = math.floor((body.y + body.h + 0.5 - room.y) / T) + 1
    local tx1, tx2 = colRange(room, body.x, body.w)
    local any = false
    for tx = tx1, tx2 do
        if room:isSolidTile(tx, ty) then return false end
        if room:isOneWayTile(tx, ty) then any = true end
    end
    return any
end

function Collision.rectsIntersect(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

return Collision
