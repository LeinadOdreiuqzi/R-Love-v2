-- src/states/station/engine/transition.lua
-- Cambio de sala a través de una puerta Metroid:
-- idle -> panning (cámara desliza a la sala nueva) -> walkin (solo laterales) -> idle

local Config = require 'src.states.station.engine.config'

local Transition = {}
Transition.__index = Transition

local function smoothstep(t) return t * t * (3 - 2 * t) end

function Transition.new()
    return setmetatable({ state = 'idle', t = 0 }, Transition)
end

function Transition:isActive()
    return self.state ~= 'idle'
end

-- Coloca al jugador junto a la puerta de destino según el lado de entrada
local function placePlayer(player, toDoor)
    local side = toDoor.side
    if side == 'left' then
        player.x = toDoor.x + toDoor.w + 2
        player.y = toDoor.y + toDoor.h - player.h
        player.onGround = true
        return 1
    elseif side == 'right' then
        player.x = toDoor.x - player.w - 2
        player.y = toDoor.y + toDoor.h - player.h
        player.onGround = true
        return -1
    elseif side == 'down' then
        -- Sube desde abajo: aparece sobre la escotilla del suelo
        player.x = toDoor.x + (toDoor.w - player.w) * 0.5
        player.y = toDoor.y - player.h - 1
        player.onGround = true
        return 0
    else -- 'up': cae desde arriba, aparece bajo la escotilla del techo
        player.x = toDoor.x + (toDoor.w - player.w) * 0.5
        player.y = toDoor.y + toDoor.h + 2
        player.onGround = false
        return 0
    end
end

-- scene: { player, camera, room }
function Transition:start(scene, door)
    local link = door.link
    if not link then return false end

    local player, camera = scene.player, scene.camera
    self.fromRoom, self.fromDoor = scene.room, door
    self.toRoom, self.toDoor = link.room, link.door
    self.fromX, self.fromY = camera.x, camera.y

    local vy = player.vy
    self.walkDir = placePlayer(player, self.toDoor)
    player.vx = 0
    if self.toDoor.side == 'down' then
        player.vy = -Config.transition.upwardPop
        self.toDoor:forceClose()        -- el jugador aterriza sobre ella
    elseif self.toDoor.side == 'up' then
        player.vy = math.max(vy, 60)
        self.toDoor:forceClose()
    else
        player.vy = 0
        self.toDoor:forceOpen()
    end
    if self.walkDir ~= 0 then player.facing = self.walkDir end

    scene.room = self.toRoom
    camera:snap(player, self.toRoom)
    self.toX, self.toY = camera.x, camera.y
    camera.x, camera.y = self.fromX, self.fromY

    self.t = 0
    self.state = 'panning'
    return true
end

function Transition:update(dt, scene)
    local cfg = Config.transition
    if self.state == 'panning' then
        self.t = math.min(1, self.t + dt / cfg.panTime)
        local k = smoothstep(self.t)
        scene.camera.x = self.fromX + (self.toX - self.fromX) * k
        scene.camera.y = self.fromY + (self.toY - self.fromY) * k
        if self.t >= 1 then
            self.fromDoor:forceClose()
            if self.walkDir ~= 0 then
                self.state, self.t = 'walkin', 0
            else
                self.state = 'idle'
            end
        end
    elseif self.state == 'walkin' then
        self.t = self.t + dt
        local input = { left = self.walkDir < 0, right = self.walkDir > 0, speedMult = cfg.walkInSpeedMult }
        scene.player:update(dt, scene.room, input)
        scene.camera:update(dt, scene.player, scene.room)
        if self.t >= cfg.walkInTime then
            self.state = 'idle'
        end
    end
end

return Transition
