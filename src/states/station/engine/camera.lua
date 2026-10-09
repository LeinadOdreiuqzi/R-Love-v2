-- src/states/station/engine/camera.lua
-- Cámara estilo Hollow Knight: deadzone, look-ahead, re-centrado al pisar
-- suelo, "mirar abajo" al caer y clamp estricto a los límites de la sala.

local Config = require 'src.states.station.engine.config'

local Camera = {}
Camera.__index = Camera

local function damp(rate, dt) return 1 - math.exp(-rate * dt) end

function Camera.new(viewW, viewH)
    return setmetatable({
        x = 0, y = 0,
        viewW = viewW or Config.VIEW_W or 480,
        viewH = viewH or Config.VIEW_H or 270,
        lookX = 0,
        shakeTime = 0, shakeDuration = 0, shakeIntensity = 0,
        ox = 0, oy = 0,
    }, Camera)
end

function Camera:setViewDimensions(w, h)
    self.viewW = w or self.viewW
    self.viewH = h or self.viewH
end

function Camera:clamp(room, x, y)
    local W, H = self.viewW, self.viewH
    if room.w <= W then x = room.x + (room.w - W) * 0.5
    else x = math.max(room.x, math.min(x, room.x + room.w - W)) end
    if room.h <= H then y = room.y + (room.h - H) * 0.5
    else y = math.max(room.y, math.min(y, room.y + room.h - H)) end
    return x, y
end

function Camera:focusPoint(player)
    local cfg = Config.camera
    return player.x + player.w * 0.5 + self.lookX,
           player.y + player.h * 0.5 - cfg.verticalOffset
end

-- Posición en reposo (sin suavizado) para un jugador en una sala
function Camera:restingFor(player, room)
    local fx, fy = self:focusPoint(player)
    return self:clamp(room, fx - self.viewW * 0.5, fy - self.viewH * 0.5)
end

function Camera:snap(player, room)
    self.lookX = player.facing * Config.camera.lookAhead
    self.x, self.y = self:restingFor(player, room)
end

function Camera:update(dt, player, room)
    local cfg = Config.camera
    local W, H = self.viewW, self.viewH

    -- Look-ahead en la dirección de la mirada (se mantiene al parar)
    if math.abs(player.vx) > 20 then
        local target = player.facing * cfg.lookAhead
        self.lookX = self.lookX + (target - self.lookX) * damp(cfg.lookAheadSpeed, dt)
    end

    local fx, fy = self:focusPoint(player)
    local cx, cy = self.x + W * 0.5, self.y + H * 0.5

    -- Horizontal: deadzone
    local hdz = cfg.deadzoneW * 0.5
    local desiredX = cx
    if fx > cx + hdz then desiredX = fx - hdz
    elseif fx < cx - hdz then desiredX = fx + hdz end

    -- Vertical: re-centrar en suelo, deadzone en el aire
    local desiredY, rateY = cy, cfg.followYAir
    if player.onGround then
        desiredY, rateY = fy, cfg.followYGround
    else
        if fy < cy - cfg.deadzoneUp then desiredY = fy + cfg.deadzoneUp
        elseif fy > cy + cfg.deadzoneDown then desiredY = fy - cfg.deadzoneDown end
        if player.vy > cfg.fallLookThreshold then desiredY = desiredY + cfg.fallLookAhead end
    end

    cx = cx + (desiredX - cx) * damp(cfg.followX, dt)
    cy = cy + (desiredY - cy) * damp(rateY, dt)
    self.x, self.y = self:clamp(room, cx - W * 0.5, cy - H * 0.5)

    self:updateShake(dt)
end

function Camera:shake(intensity, duration)
    self.shakeIntensity = intensity
    self.shakeDuration = duration
    self.shakeTime = duration
end

function Camera:updateShake(dt)
    if self.shakeTime > 0 then
        self.shakeTime = math.max(0, self.shakeTime - dt)
        local k = self.shakeTime / self.shakeDuration
        local a = self.shakeIntensity * k
        self.ox = (love.math.random() * 2 - 1) * a
        self.oy = (love.math.random() * 2 - 1) * a
    else
        self.ox, self.oy = 0, 0
    end
end

-- Offset entero para dibujar (sin jitter sub-píxel)
function Camera:drawOffset()
    return math.floor(self.x + self.ox + 0.5), math.floor(self.y + self.oy + 0.5)
end

return Camera
