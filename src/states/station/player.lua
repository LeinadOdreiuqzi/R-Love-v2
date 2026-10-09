-- src/states/station/player.lua
-- Jugador de plataformas sobre colisión por tiles.
-- Física con aceleración/deceleración, coyote time, jump buffer,
-- salto variable, caída pesada y descenso por plataformas one-way.

local Config = require 'src.states.station.engine.config'
local Collision = require 'src.states.station.engine.collision'

local Player = {}
Player.__index = Player

local function approach(v, target, delta)
    if v < target then return math.min(v + delta, target) end
    return math.max(v - delta, target)
end

function Player.new(x, y)
    local cfg = Config.player
    local p = setmetatable({}, Player)
    p.x, p.y = x or 0, y or 0
    p.w, p.h = cfg.w, cfg.h
    p.vx, p.vy = 0, 0
    p.facing = 1
    p.onGround = false
    p.coyote = 0
    p.jumpBuffer = 0
    p.jumpCutAvailable = false
    p.dropThrough = false
    p.dropTimer = 0
    p.fuel = cfg.jetpack.fuelMax
    p.isJetpacking = false
    p.animTime = 0
    return p
end

function Player:pressJump()
    self.jumpBuffer = Config.player.jumpBufferTime
end

function Player:resetMotion()
    self.vx, self.vy = 0, 0
    self.coyote, self.jumpBuffer = 0, 0
    self.jumpCutAvailable = false
end

-- input: { left, right, down, jumpHeld, jetpack, speedMult }
function Player:update(dt, room, input)
    local cfg = Config.player
    input = input or {}
    self.animTime = self.animTime + dt

    -- Timers
    if self.coyote > 0 then self.coyote = self.coyote - dt end
    if self.jumpBuffer > 0 then self.jumpBuffer = self.jumpBuffer - dt end
    if self.dropTimer > 0 then
        self.dropTimer = self.dropTimer - dt
        if self.dropTimer <= 0 then self.dropThrough = false end
    end

    -- Horizontal
    local dir = (input.right and 1 or 0) - (input.left and 1 or 0)
    local maxSpeed = cfg.runSpeed * (input.speedMult or 1)
    local accel, decel
    if self.onGround then accel, decel = cfg.groundAccel, cfg.groundDecel
    else accel, decel = cfg.airAccel, cfg.airDecel end
    if dir ~= 0 then
        self.facing = dir
        local rate = (self.vx ~= 0 and (self.vx > 0) ~= (dir > 0)) and (accel + decel) or accel
        self.vx = approach(self.vx, dir * maxSpeed, rate * dt)
    else
        self.vx = approach(self.vx, 0, decel * dt)
    end

    -- Salto / descenso por one-way
    if self.jumpBuffer > 0 and (self.onGround or self.coyote > 0) then
        self.jumpBuffer = 0
        if input.down and self.onGround and Collision.isOnOneWayOnly(self, room) then
            self.dropThrough = true
            self.dropTimer = cfg.dropThroughTime
            self.onGround = false
        else
            self.vy = -cfg.jumpVelocity
            self.onGround = false
            self.coyote = 0
            self.jumpCutAvailable = true
        end
    end

    -- Salto variable
    if self.jumpCutAvailable and self.vy < 0 and not input.jumpHeld then
        self.vy = self.vy * cfg.jumpCutMult
        self.jumpCutAvailable = false
    end
    if self.vy >= 0 then self.jumpCutAvailable = false end

    -- Gravedad
    local g = cfg.gravity
    if self.vy > 0 then g = g * cfg.fallGravityMult end
    self.vy = math.min(self.vy + g * dt, cfg.maxFallSpeed)

    -- Jetpack (desactivado por defecto en config)
    local jp = cfg.jetpack
    self.isJetpacking = false
    if jp.enabled then
        if input.jetpack and self.fuel > 0 then
            self.vy = math.max(self.vy - jp.thrust * dt, -jp.maxAscendSpeed)
            self.fuel = math.max(0, self.fuel - dt)
            self.isJetpacking = true
        else
            local rate = self.onGround and jp.rechargeGround or jp.rechargeAir
            self.fuel = math.min(jp.fuelMax, self.fuel + rate * dt)
        end
    end

    -- Movimiento con colisión
    if Collision.moveX(self, room, self.vx * dt) then self.vx = 0 end
    local hit, landed = Collision.moveY(self, room, self.vy * dt)
    if hit then self.vy = 0 end
    self.onGround = landed

    if self.onGround then
        self.coyote = cfg.coyoteTime
        self.jumpCutAvailable = false
    end
end

-- Dibujo pixel-art procedural (coordenadas de mundo, ya en espacio virtual)
function Player:draw()
    local P = Config.palette
    local x, y = math.floor(self.x + 0.5), math.floor(self.y + 0.5)
    local w, h = self.w, self.h
    local f = self.facing

    -- Piernas (animación simple al correr)
    local step = 0
    if self.onGround and math.abs(self.vx) > 10 then
        step = (math.floor(self.animTime * 10) % 2 == 0) and 1 or -1
    end
    love.graphics.setColor(P.playerDark[1], P.playerDark[2], P.playerDark[3], 1)
    love.graphics.rectangle('fill', x + 1, y + h - 6 + math.max(0, step), 3, 6 - math.max(0, step))
    love.graphics.rectangle('fill', x + w - 4, y + h - 6 + math.max(0, -step), 3, 6 - math.max(0, -step))

    -- Torso
    love.graphics.setColor(P.player[1], P.player[2], P.player[3], 1)
    love.graphics.rectangle('fill', x, y + 7, w, h - 13)
    -- Mochila
    love.graphics.setColor(P.playerDark[1], P.playerDark[2], P.playerDark[3], 1)
    local packX = (f > 0) and (x - 2) or (x + w)
    love.graphics.rectangle('fill', packX, y + 8, 2, 7)

    -- Casco
    love.graphics.setColor(P.player[1], P.player[2], P.player[3], 1)
    love.graphics.rectangle('fill', x + 1, y, w - 2, 7)
    -- Visor
    love.graphics.setColor(P.visor[1], P.visor[2], P.visor[3], 1)
    local vx = (f > 0) and (x + w - 6) or (x + 2)
    love.graphics.rectangle('fill', vx, y + 2, 4, 3)
end

return Player
