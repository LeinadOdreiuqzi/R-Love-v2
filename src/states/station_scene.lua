-- src/states/station_scene.lua
-- Escena de interiores de estación (motor Metroidvania).
-- Orquesta: StationMap (salas hechas a mano), Viewport (480x270), Camera,
-- Transition (puertas Metroid) y Player. Toda la lógica vive en src/states/station/.

local StateBase = require 'src.states.state_base'
local Config = require 'src.states.station.engine.config'
local Viewport = require 'src.states.station.engine.viewport'
local Camera = require 'src.states.station.engine.camera'
local StationMap = require 'src.states.station.engine.station_map'
local Transition = require 'src.states.station.engine.transition'
local Collision = require 'src.states.station.engine.collision'
local DebugDraw = require 'src.states.station.engine.debug_draw'
local Player = require 'src.states.station.player'
local BackgroundManager = require 'src.shaders.background_manager'
local World = require 'src.core.world'

local StationScene = setmetatable({}, { __index = StateBase })
StationScene.__index = StationScene

local DEFAULT_STATION = 'ring_station'

local function keyDown(...)
    for i = 1, select('#', ...) do
        if love.keyboard.isDown((select(i, ...))) then return true end
    end
    return false
end

local JUMP_KEYS = { space = true, z = true, w = true, up = true }

function StationScene:new(placeholder)
    local o = StateBase.new(self, {
        name = "StationScene",
        suspendUnderlying = true,
        isOverlay = false
    })
    o.placeholder = placeholder
    o.stationId = (placeholder and placeholder.stationId) or DEFAULT_STATION
    o.map = nil
    o.room = nil
    o.player = nil
    o.camera = nil
    o.viewport = nil
    o.transition = nil
    o.debug = { collision = false, camera = false, info = false }
    o.toast = nil
    o._prevBgEnabled = nil
    return o
end

function StationScene:enter(params)
    self.map = StationMap.load(self.stationId)
    self.map:bakeAll()

    self.room = self.map:getRoom(self.map.start.room)
    local cfg = Config.player
    local x, y = self.room:spawnPosition(self.map.start.spawn, cfg.w, cfg.h)
    self.player = Player.new(x, y)

    self.viewport = Viewport.new()
    self.camera = Camera.new(self.viewport.w, self.viewport.h)
    self.camera:snap(self.player, self.room)
    self.transition = Transition.new()

    -- Fondo conectado por shader y parallax para estaciones (ej. ring_station)
    if self.stationId == 'ring_station' then
        local RingBackground = require 'src.states.station.engine.ring_background'
        self.stationBackground = RingBackground.new()
    end

    -- Sistema de iluminación dinámica interior (Lightmap virtual + linterna + LEDs)
    local StationLighting = require 'src.states.station.engine.lighting'
    self.lighting = StationLighting.new()

    -- El fondo galáctico exterior no se usa en interiores
    if BackgroundManager and BackgroundManager.isEnabled and BackgroundManager.setEnabled then
        self._prevBgEnabled = BackgroundManager.isEnabled()
        BackgroundManager.setEnabled(false)
    end
end

function StationScene:readInput()
    return {
        left = keyDown('a', 'left'),
        right = keyDown('d', 'right'),
        down = keyDown('s', 'down'),
        jumpHeld = keyDown('space', 'z', 'w', 'up'),
        jetpack = keyDown('lshift', 'rshift'),
    }
end

function StationScene:showToast(text)
    self.toast = { text = text, t = 1.6 }
end

-- Apertura por proximidad inteligente, auto-cierre y disparo de transición anti-bloqueo
function StationScene:updateDoors(dt, input)
    local p = self.player
    for _, d in ipairs(self.room.doors) do
        local near = d:isPlayerNear(p.x, p.y, p.w, p.h)
        local otherDoor = d.link and d.link.door

        if d.state == 'closed' or d.state == 'closing' then
            local wantsOpen = near and (d.side ~= 'down' or input.down)
            if wantsOpen then
                if not d:requestOpen() and not self.toast then
                    self:showToast("Puerta bloqueada")
                else
                    if otherDoor then otherDoor:requestOpen() end
                end
            end
        elseif d.state == 'open' or d.state == 'opening' then
            if near then
                d:keepOpen()
                if otherDoor then otherDoor:keepOpen() end
                if d.state == 'open' and d:isPlayerCrossing(p.x, p.y, p.w, p.h) then
                    if self.transition:start(self, d) then return end
                end
            else
                d.idle = d.idle + dt
                if d.idle >= Config.door.autoCloseDelay then
                    d:requestClose()
                    if otherDoor then otherDoor:requestClose() end
                end
            end
        end
    end
end

function StationScene:update(dt)
    dt = dt or (1 / 60)
    dt = math.min(dt, 1 / 30)
    if not self.map then return end

    self.map:update(dt)

    if self.transition:isActive() then
        self.transition:update(dt, self)
    else
        local input = self:readInput()
        self.player:update(dt, self.room, input)
        self:updateDoors(dt, input)
        if not self.transition:isActive() then
            self.camera:update(dt, self.player, self.room)
        end
    end

    if self.toast then
        self.toast.t = self.toast.t - dt
        if self.toast.t <= 0 then self.toast = nil end
    end

    if self.stationBackground then
        self.stationBackground:update(dt)
    end

    if self.lighting then
        self.lighting:update(dt)
    end

    -- Mantener actualizadas las UIs de inventario si están abiertas
    local UIManager = require 'src.ui.ui_manager'
    UIManager.updateAll(dt, World.get('player'))
end

function StationScene:draw()
    if not self.map then return end

    self.viewport:updateLayout()
    self.camera:setViewDimensions(self.viewport.w, self.viewport.h)

    local W, H = self.viewport.w, self.viewport.h
    local camX, camY = self.camera:drawOffset()

    if self.lighting then
        -- 1. Capturar la arquitectura interior de la sala en interiorCanvas
        self.lighting:beginInterior(W, H)

        love.graphics.push()
        love.graphics.translate(-camX, -camY)
        self.map:drawVisible(camX, camY, W, H)
        self.player:draw()
        if self.debug.collision then
            DebugDraw.collision(self.room, self.player, camX, camY, W, H)
        end
        love.graphics.pop()

        self.lighting:endInterior()

        -- 2. Renderizar el Lightmap virtual (linterna suave, luminarias LED, LEDs de puertas)
        self.lighting:renderLightmap(self, camX, camY, W, H)

        -- 3. Componer la escena en el canvas virtual final:
        self.viewport:beginDraw()

        -- Paso A: Fondo cósmico exterior prístino (estrellas, anillo, arco)
        if self.stationBackground then
            self.stationBackground:draw(camX, camY, W, H, self.room)
        end

        -- Paso B: Componer la arquitectura interior iluminada por shader
        self.lighting:present(self, W, H)

        if self.debug.camera then DebugDraw.camera(self.camera) end
        self.viewport:endDraw()
    else
        self.viewport:beginDraw()
        if self.stationBackground then
            self.stationBackground:draw(camX, camY, W, H, self.room)
        end
        love.graphics.push()
        love.graphics.translate(-camX, -camY)
        self.map:drawVisible(camX, camY, W, H)
        self.player:draw()
        if self.debug.collision then
            DebugDraw.collision(self.room, self.player, camX, camY, W, H)
        end
        love.graphics.pop()
        if self.debug.camera then DebugDraw.camera(self.camera) end
        self.viewport:endDraw()
    end

    self.viewport:present()
    self:drawHUD()
end

function StationScene:drawHUD()
    local sw, sh = love.graphics.getDimensions()

    -- Título de la estación y sala en la esquina superior izquierda
    love.graphics.setColor(0.82, 0.92, 1.0, 0.95)
    love.graphics.print(string.format("%s  ·  %s", self.map.name, self.room.name), 16, 12)

    if self.debug.info then
        local p = self.player
        local lines = {
            string.format("sala=%s  grid=(%d,%d)  tiles=%dx%d", self.room.id, self.room.gx, self.room.gy, self.room.tw, self.room.th),
            string.format("jugador x=%.1f y=%.1f  vx=%.1f vy=%.1f  suelo=%s", p.x, p.y, p.vx, p.vy, tostring(p.onGround)),
            string.format("cámara x=%.1f y=%.1f  vista=%dx%d  escala=%sx (%s)", self.camera.x, self.camera.y, self.viewport.w, self.viewport.h, tostring(self.viewport.scale), tostring(self.transition.state)),
            string.format("FPS %d  [+/-] Zoom  [0] Auto-zoom", love.timer.getFPS()),
        }
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle('fill', 12, 32, 520, #lines * 16 + 8, 4, 4)
        love.graphics.setColor(0.6, 1.0, 0.8, 1)
        for i, l in ipairs(lines) do love.graphics.print(l, 18, 36 + (i - 1) * 16) end
    end

    if self.toast then
        local a = math.min(1, self.toast.t * 2)
        love.graphics.setColor(1, 0.85, 0.4, a)
        love.graphics.printf(self.toast.text, 0, 50, sw, 'center')
    end

    love.graphics.setColor(0.70, 0.80, 0.92, 0.85)
    love.graphics.printf("[A/D] Mover   [ESP/Z/W] Saltar   [S+Salto] Bajar plataforma   [S] Abrir escotilla   [F] Linterna   [+/-] Zoom   [F1/F2/F3] Debug   [Q/ESC] Salir",
        8, sh - 22, sw - 16, 'center')
end

function StationScene:keypressed(key)
    if key == 'escape' or key == 'q' then
        if self.manager then self.manager:pop({ fadeDuration = 0.2 }) end
        return true
    end
    if key == 'f' then
        if self.lighting then
            local on = self.lighting:toggleFlashlight()
            self:showToast(on and "Linterna del traje: ACTIVADA" or "Linterna del traje: DESACTIVADA")
            return true
        end
    end
    if key == 'f1' then self.debug.collision = not self.debug.collision; return true end
    if key == 'f2' then self.debug.camera = not self.debug.camera; return true end
    if key == 'f3' then self.debug.info = not self.debug.info; return true end

    -- Ajuste dinámico de escala / zoom
    if key == '=' or key == 'kp+' or key == '+' then
        local current = self.viewport.scale
        Config.PIXEL_SCALE = math.min(6, current + 1)
        self.viewport:updateLayout()
        self.camera:setViewDimensions(self.viewport.w, self.viewport.h)
        self:showToast(string.format("Zoom: escala %dx (vista %dx%d)", self.viewport.scale, self.viewport.w, self.viewport.h))
        return true
    elseif key == '-' or key == 'kp-' then
        local current = self.viewport.scale
        Config.PIXEL_SCALE = math.max(1, current - 1)
        self.viewport:updateLayout()
        self.camera:setViewDimensions(self.viewport.w, self.viewport.h)
        self:showToast(string.format("Zoom: escala %dx (vista %dx%d)", self.viewport.scale, self.viewport.w, self.viewport.h))
        return true
    elseif key == '0' then
        Config.PIXEL_SCALE = nil
        self.viewport:updateLayout()
        self.camera:setViewDimensions(self.viewport.w, self.viewport.h)
        self:showToast(string.format("Zoom: automático (escala %dx)", self.viewport.scale))
        return true
    end

    if JUMP_KEYS[key] then
        if self.player and self.transition and not self.transition:isActive() then
            self.player:pressJump()
        end
        return true
    end
    return false
end

function StationScene:resize(w, h)
    if self.viewport then
        self.viewport:updateLayout()
        if self.camera then
            self.camera:setViewDimensions(self.viewport.w, self.viewport.h)
        end
    end
end

function StationScene:exit()
    if self.lighting and self.lighting.release then
        self.lighting:release()
        self.lighting = nil
    end
    if self.stationBackground and self.stationBackground.release then
        self.stationBackground:release()
        self.stationBackground = nil
    end
    if self.map then self.map:release() end
    if self.viewport then self.viewport:release() end
    if BackgroundManager and BackgroundManager.setEnabled then
        if self._prevBgEnabled == nil then
            BackgroundManager.setEnabled(true)
        else
            BackgroundManager.setEnabled(self._prevBgEnabled)
        end
    end
end

return StationScene