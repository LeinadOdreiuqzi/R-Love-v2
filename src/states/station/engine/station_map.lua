-- src/states/station/engine/station_map.lua
-- Carga una estación: coloca salas en la cuadrícula global de pantallas,
-- valida solapamientos y enlaza puertas automáticamente por vecindad.

local Config = require 'src.states.station.engine.config'
local Room = require 'src.states.station.engine.room'

local StationMap = {}
StationMap.__index = StationMap

local OPPOSITE = { left = 'right', right = 'left', up = 'down', down = 'up' }

local function cellKey(gx, gy) return gx .. ',' .. gy end

function StationMap.load(stationId)
    local base = 'src.states.station.rooms.' .. stationId
    local mapDef = require(base .. '.map')

    local self = setmetatable({}, StationMap)
    self.id = stationId
    self.name = mapDef.name or stationId
    self.rooms = {}
    self.list = {}
    self.cells = {}
    self.start = mapDef.start or {}

    for _, entry in ipairs(mapDef.rooms or {}) do
        local def = require(base .. '.' .. entry.id)
        if def.id ~= entry.id then
            error(string.format("[StationMap] '%s': el archivo '%s' declara id '%s'",
                stationId, entry.id, tostring(def.id)))
        end
        if self.rooms[entry.id] then
            error(string.format("[StationMap] '%s': sala duplicada '%s'", stationId, entry.id))
        end
        local room = Room.new(def, entry.gx or 0, entry.gy or 0, entry.tx, entry.ty)
        for _, existing in ipairs(self.list) do
            if room.tx < existing.tx + existing.tw and room.tx + room.tw > existing.tx and
               room.ty < existing.ty + existing.th and room.ty + room.th > existing.ty then
                error(string.format("[StationMap] '%s': las salas '%s' y '%s' se solapan",
                    stationId, existing.id, room.id))
            end
        end
        self.rooms[room.id] = room
        table.insert(self.list, room)
    end

    self:linkDoors()

    if not self.rooms[self.start.room] then
        error(string.format("[StationMap] '%s': sala inicial '%s' no existe", stationId, tostring(self.start.room)))
    end
    return self
end

-- Coordenadas globales de tile (0-based)
function StationMap:roomAtTile(gtx, gty)
    for _, room in ipairs(self.list) do
        if gtx >= room.tx and gtx < room.tx + room.tw and
           gty >= room.ty and gty < room.ty + room.th then
            return room
        end
    end
    return nil
end

function StationMap:linkDoors()
    for _, room in ipairs(self.list) do
        for _, door in ipairs(room.doors) do
            local gtx, gty
            local side = door.side
            if side == 'right' then
                gtx, gty = room.tx + room.tw, room.ty + door.ty - 1
            elseif side == 'left' then
                gtx, gty = room.tx - 1, room.ty + door.ty - 1
            elseif side == 'down' then
                gtx, gty = room.tx + door.tx - 1, room.ty + room.th
            else -- up
                gtx, gty = room.tx + door.tx - 1, room.ty - 1
            end

            local other = self:roomAtTile(gtx, gty)
            if not other then
                error(string.format("[StationMap] Puerta '%s' no da a ninguna sala (tile global %d,%d)",
                    door.id, gtx, gty))
            end

            local want = OPPOSITE[side]
            local match = nil
            for _, od in ipairs(other.doors) do
                if od.side == want then
                    if door.isHatch then
                        if other.tx + od.tx - 1 == gtx then match = od; break end
                    else
                        if other.ty + od.ty - 1 == gty then match = od; break end
                    end
                end
            end
            if not match then
                error(string.format("[StationMap] Puerta '%s' no tiene pareja '%s' alineada en la sala '%s'",
                    door.id, want, other.id))
            end
            door.link = { room = other, door = match }
            match.link = { room = room, door = door }
        end
    end
end

function StationMap:getRoom(id)
    return self.rooms[id]
end

function StationMap:bakeAll()
    for _, r in ipairs(self.list) do r:bake() end
end

function StationMap:update(dt)
    for _, r in ipairs(self.list) do r:update(dt) end
end

-- Dibuja las salas visibles en el rectángulo de cámara
function StationMap:drawVisible(cx, cy, cw, ch)
    for _, r in ipairs(self.list) do
        if r:intersectsRect(cx, cy, cw, ch) then
            r:draw(cx, cy, cw, ch)
        end
    end
end

function StationMap:release()
    for _, r in ipairs(self.list) do r:release() end
end

return StationMap
