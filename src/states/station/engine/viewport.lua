-- src/states/station/engine/viewport.lua
-- Canvas de resolución virtual con escalado (entero por defecto) y letterbox.

local Config = require 'src.states.station.engine.config'

local Viewport = {}
Viewport.__index = Viewport

function Viewport.new()
    local v = setmetatable({}, Viewport)
    v.w = Config.VIEW_W or 480
    v.h = Config.VIEW_H or 270
    v.scale, v.ox, v.oy = 1, 0, 0
    v.canvas = nil
    v:updateLayout()
    return v
end

function Viewport:computeScale(sw, sh)
    if type(Config.PIXEL_SCALE) == 'number' then
        return math.max(1, math.floor(Config.PIXEL_SCALE))
    end
    local targetH = Config.TARGET_VIEW_H or 320
    return math.max(1, math.floor(sh / targetH))
end

function Viewport:updateLayout()
    local sw, sh = love.graphics.getDimensions()
    if Config.ADAPTIVE_VIEWPORT then
        local s = self:computeScale(sw, sh)
        self.scale = s
        local vw = math.max(1, math.ceil(sw / s))
        local vh = math.max(1, math.ceil(sh / s))

        if not self.canvas or self.w ~= vw or self.h ~= vh then
            if self.canvas then self.canvas:release() end
            self.w, self.h = vw, vh
            self.canvas = love.graphics.newCanvas(self.w, self.h)
            self.canvas:setFilter('nearest', 'nearest')
        end

        self.ox = 0
        self.oy = 0
    else
        self.w, self.h = Config.VIEW_W, Config.VIEW_H
        local s = math.min(sw / self.w, sh / self.h)
        if Config.INTEGER_SCALE then s = math.max(1, math.floor(s)) end
        self.scale = s
        self.ox = math.floor((sw - self.w * s) * 0.5)
        self.oy = math.floor((sh - self.h * s) * 0.5)
        if not self.canvas or self.canvas:getWidth() ~= self.w or self.canvas:getHeight() ~= self.h then
            if self.canvas then self.canvas:release() end
            self.canvas = love.graphics.newCanvas(self.w, self.h)
            self.canvas:setFilter('nearest', 'nearest')
        end
    end
end

-- Comienza a dibujar en el canvas virtual (coordenadas 0..VIEW_W, 0..VIEW_H)
function Viewport:beginDraw()
    love.graphics.push('all')
    love.graphics.setCanvas(self.canvas)
    love.graphics.origin()
    local c = Config.palette.clear
    love.graphics.clear(c[1], c[2], c[3], 1)
end

function Viewport:endDraw()
    love.graphics.pop() -- restaura canvas y estado previos
end

-- Presenta el canvas escalado en pantalla
function Viewport:present()
    local lb = Config.palette.letterbox
    love.graphics.clear(lb[1], lb[2], lb[3], 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, self.ox, self.oy, 0, self.scale, self.scale)
end

-- Rectángulo en pantalla ocupado por el juego (útil para HUD en letterbox)
function Viewport:getScreenRect()
    return self.ox, self.oy, self.w * self.scale, self.h * self.scale
end

function Viewport:release()
    if self.canvas then self.canvas:release(); self.canvas = nil end
end

return Viewport
