-- src/states/station/engine/debug_draw.lua
-- Overlays de depuración: F1 colisiones, F2 cámara, F3 info de sala.

local Config = require 'src.states.station.engine.config'
local Tilemap = require 'src.states.station.engine.tilemap'

local DebugDraw = {}

-- Dentro del espacio de mundo (ya trasladado por la cámara)
function DebugDraw.collision(room, player, camX, camY, viewW, viewH)
    local T = Config.TILE
    viewW = viewW or Config.VIEW_W or 480
    viewH = viewH or Config.VIEW_H or 270
    local tx1 = math.max(1, math.floor((camX - room.x) / T) + 1)
    local ty1 = math.max(1, math.floor((camY - room.y) / T) + 1)
    local tx2 = math.min(room.tw, math.ceil((camX + viewW - room.x) / T))
    local ty2 = math.min(room.th, math.ceil((camY + viewH - room.y) / T))

    love.graphics.setLineWidth(1)
    for ty = ty1, ty2 do
        for tx = tx1, tx2 do
            local x, y = room.x + (tx - 1) * T, room.y + (ty - 1) * T
            if room:isSolidTile(tx, ty) then
                love.graphics.setColor(1, 0.25, 0.25, 0.35)
                love.graphics.rectangle('line', x + 0.5, y + 0.5, T - 1, T - 1)
            elseif room:tileAt(tx, ty) == Tilemap.ONEWAY then
                love.graphics.setColor(1, 0.9, 0.2, 0.6)
                love.graphics.line(x, y + 0.5, x + T, y + 0.5)
            end
        end
    end

    for _, d in ipairs(room.doors) do
        if d.state == 'open' then love.graphics.setColor(0.3, 1, 0.4, 0.8)
        else love.graphics.setColor(1, 0.5, 0.1, 0.8) end
        love.graphics.rectangle('line', d.x + 0.5, d.y + 0.5, d.w - 1, d.h - 1)
    end

    love.graphics.setColor(0.2, 1, 1, 0.9)
    love.graphics.rectangle('line', math.floor(player.x) + 0.5, math.floor(player.y) + 0.5, player.w - 1, player.h - 1)
end

-- Espacio de pantalla virtual (sin traslación)
function DebugDraw.camera(camera)
    local cfg = Config.camera
    local W = camera.viewW or Config.VIEW_W or 480
    local H = camera.viewH or Config.VIEW_H or 270
    local cx, cy = W * 0.5, H * 0.5
    love.graphics.setColor(1, 0.4, 1, 0.6)
    love.graphics.rectangle('line', cx - cfg.deadzoneW * 0.5 + 0.5, cy - cfg.deadzoneUp + 0.5,
        cfg.deadzoneW, cfg.deadzoneUp + cfg.deadzoneDown)
    love.graphics.line(cx - 3, cy + 0.5, cx + 4, cy + 0.5)
    love.graphics.line(cx + 0.5, cy - 3, cx + 0.5, cy + 4)
    love.graphics.setColor(1, 1, 0.3, 0.8)
    local lx = cx + camera.lookX
    love.graphics.line(lx + 0.5, cy - 6, lx + 0.5, cy + 6)
end

return DebugDraw
