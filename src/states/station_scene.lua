-- src/states/station_scene.lua
-- Escena de Estación (Rooms Grid estilo Metal Warriors) - usa módulos: generador, plantillas, jugador, decoración y fondo

local StateBase = require 'src.states.state_base'
local Generator = require 'src.states.station.generator'
local Player = require 'src.states.station.platformer_player'
local Decor = require 'src.states.station.decor'
local BackgroundManager = require 'src.shaders.background_manager'

local StationScene = setmetatable({}, { __index = StateBase })
StationScene.__index = StationScene

function StationScene:new(placeholder)
    local o = StateBase.new(self, {
        name = "StationScene",
        suspendUnderlying = true,
        isOverlay = false
    })
    o.placeholder = placeholder
    o.time = 0
    o.player = nil
    o.camera = { x = 0, y = 0, zoom = 1 }
    o.seed = (placeholder and placeholder.seed) or 0
    o.graph = nil
    o.currentRoomId = nil
    o._doorCooldown = 0
    return o
end

function StationScene:enter(params)
    self.time = 0

    -- Generar grafo 2D estilo Metal Warriors (permite verticalidad y grandes salas)
    local rows, cols = 3, 4
    self.graph = Generator.generateGrid({ seed = self.seed, rows = rows, cols = cols, separation = 120 })
    if not self.graph or not self.graph.rooms or #self.graph.rooms == 0 then return end

    -- Decor por sala
    for _, room in ipairs(self.graph.rooms) do
        room.decor = Decor.decorateRoom(room, self.seed + room.id)
    end

    -- Definir sala inicial y jugador
    self.currentRoomId = self.graph.startRoomId or 1
    local startRoom = self.graph.rooms[self.currentRoomId]
    self.player = Player.new({ x = startRoom.spawn.x, y = startRoom.spawn.y })

    -- Inicializar cámara
    self.camera = { x = startRoom.x, y = startRoom.y, zoom = 1 }
    self:updateCamera(0)

    -- Inicializar fondo
    if BackgroundManager and BackgroundManager.init then
        BackgroundManager.init()
    end
end

function StationScene:update(dt)
    self.time = self.time + dt
    if self._doorCooldown > 0 then self._doorCooldown = self._doorCooldown - dt end

    local room = self:getCurrentRoom()
    if not room then return end

    -- Actualizar fondo (feedback visual de fondo, no debe quedar obstruido por plataformas)
    if BackgroundManager and BackgroundManager.update then
        BackgroundManager.update(dt, self.camera, { currentSeed = self.seed })
    end

    -- Construir level efímero para el jugador basado en la sala actual
    local level = { x = room.x, y = room.y, width = room.width, height = room.height, platforms = room.platforms }
    if self.player then
        self.player:update(dt, level)
    end

    -- Ya no hacemos transición automática al tocar puertas; se hace con tecla 'E'

    self:updateCamera(dt)
end

function StationScene:getCurrentRoom()
    if not self.graph or not self.currentRoomId then return nil end
    return self.graph.rooms[self.currentRoomId]
end

function StationScene:switchRoom(door)
    local targetId = door.to and door.to.roomId
    if not targetId then return end
    local target = self.graph.rooms[targetId]
    if not target then return end

    -- Reposicionar jugador cercano a la puerta opuesta
    local destSide = door.to.door -- 'left'|'right'|'up'|'down'
    local td = target.doors and target.doors[destSide]
    if td then
        if destSide == 'left' then
            self.player.x = td.x + td.w + 4
            self.player.y = td.y - self.player.h * 0.5 + td.h * 0.5
        elseif destSide == 'right' then
            self.player.x = td.x - self.player.w - 4
            self.player.y = td.y - self.player.h * 0.5 + td.h * 0.5
        elseif destSide == 'up' then
            self.player.x = td.x - self.player.w * 0.5 + td.w * 0.5
            self.player.y = td.y + td.h + 4
        elseif destSide == 'down' then
            self.player.x = td.x - self.player.w * 0.5 + td.w * 0.5
            self.player.y = td.y - self.player.h - 4
        end
    else
        -- Fallback al spawn de la sala
        self.player.x, self.player.y = target.spawn.x, target.spawn.y
    end

    -- Resetear velocidades y timers de salto
    self.player.vx, self.player.vy = 0, 0
    self.player.onGround = false
    if self.player.coyote then self.player.coyote = 0 end
    if self.player.jumpBuffer then self.player.jumpBuffer = 0 end

    -- Cambiar sala
    self.currentRoomId = targetId
end

function StationScene:draw()
    -- Limpiar fondo base
    love.graphics.clear(0.02, 0.02, 0.04, 1)

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Renderizar fondo procedural (feedback), por detrás de todo lo demás
    if BackgroundManager and BackgroundManager.render then
        BackgroundManager.render(self.camera, { currentSeed = self.seed })
    end

    -- Mundo 2D
    love.graphics.push()
    love.graphics.translate(-math.floor(self.camera.x), -math.floor(self.camera.y))

    local room = self:getCurrentRoom()
    if room then
        -- Fondo de sala semitransparente para no ocultar el feedback
        love.graphics.setColor(0.07, 0.09, 0.12, 0.35)
        love.graphics.rectangle('fill', room.x, room.y, room.width, room.height)

        -- Textura simple: franjas para suelos metálicos
        love.graphics.setColor(0.12, 0.15, 0.20, 0.55)
        for _, plat in ipairs(room.platforms or {}) do
            love.graphics.rectangle('fill', plat.x, plat.y, plat.w, plat.h, 2, 2)
            love.graphics.setColor(0.20, 0.25, 0.32, 0.55)
            for ix = plat.x, plat.x + plat.w, 14 do
                love.graphics.rectangle('fill', ix, plat.y, 8, math.min(plat.h, 4))
            end
            love.graphics.setColor(0.12, 0.15, 0.20, 0.55)
        end

        -- Puertas
        local overlappingDoor = nil
        for side, d in pairs(room.doors or {}) do
            if d then
                if side == 'left' or side == 'right' then
                    love.graphics.setColor(0.70, 0.85, 1.0, 0.55)
                else
                    love.graphics.setColor(0.70, 1.0, 0.85, 0.55)
                end
                love.graphics.rectangle('line', d.x, d.y, d.w, d.h)

                -- Chequeo de overlap para UI (solo mostrar si la puerta tiene destino)
                if d.to and self.player and self:rectsIntersect(self.player.x, self.player.y, self.player.w, self.player.h, d.x, d.y, d.w, d.h) then
                    overlappingDoor = d
                end
            end
        end

        -- Decoraciones
        if room.decor then
            for _, d in ipairs(room.decor) do
                if d.kind == 'panel' then
                    love.graphics.setColor(0.55, 0.65, 0.80, 0.55)
                elseif d.kind == 'rubble' then
                    love.graphics.setColor(0.40, 0.45, 0.50, 0.55)
                else -- 'crate' u otros
                    love.graphics.setColor(0.55, 0.50, 0.40, 0.65)
                end
                -- d.x, d.y ya están en coordenadas de mundo
                love.graphics.rectangle('fill', d.x, d.y, d.w, d.h, 2, 2)
                love.graphics.setColor(0, 0, 0, 0.25)
                love.graphics.rectangle('line', d.x, d.y, d.w, d.h)
            end
        end

        -- Jugador
        if self.player then
            love.graphics.setColor(0.9, 0.95, 1.0, 1)
            love.graphics.rectangle('fill', self.player.x, self.player.y, self.player.w, self.player.h, 3, 3)
            love.graphics.setColor(0,0,0,0.20)
            love.graphics.ellipse('fill', self.player.x + self.player.w*0.5, self.player.y + self.player.h, self.player.w*0.45, 5)
        end

        -- Prompt de interacción con puerta (solo si tiene destino)
        if overlappingDoor then
            love.graphics.setColor(1,1,1,0.9)
            love.graphics.print("Pulsa E para entrar", overlappingDoor.x, overlappingDoor.y - 18)
        end
    end

    love.graphics.pop()

    -- UI
    love.graphics.setColor(0.82, 0.92, 1.0, 1)
    love.graphics.printf("Estación - Grafo 2D (usa puertas ←→↑↓)", 16, 14, sw - 32, 'left')
    love.graphics.setColor(0.90, 0.96, 1.0, 0.95)
    love.graphics.printf("[A/D o ←/→] Mover   [W/↑/ESP/Z] Saltar   [Shift] Jetpack   [E] Usar puerta   [Q/ESC] Salir", 16, sh - 28, sw - 32, 'right')
end

function StationScene:updateCamera(dt)
    if not self.player then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local room = self:getCurrentRoom()
    if not room then return end

    local targetX = (self.player.x + self.player.w*0.5) - sw*0.5
    local targetY = (self.player.y + self.player.h*0.5) - sh*0.5

    -- Clamping sin márgenes: aprovechar toda la pantalla
    local minX = room.x
    local minY = room.y
    local maxX = room.x + room.width - sw
    local maxY = room.y + room.height - sh

    -- Si la sala es más pequeña que la pantalla, centrar
    if maxX < minX then
        targetX = room.x + room.width*0.5 - sw*0.5
    else
        targetX = math.max(minX, math.min(targetX, maxX))
    end
    if maxY < minY then
        targetY = room.y + room.height*0.5 - sh*0.5
    else
        targetY = math.max(minY, math.min(targetY, maxY))
    end

    -- Suavizado dt-invariante: alpha = 1 - exp(-lambda*dt)
    local lambda = 10.0
    local alpha = 1 - math.exp(-lambda * (dt or 0.016))
    self.camera.x = self.camera.x + (targetX - self.camera.x) * alpha
    self.camera.y = self.camera.y + (targetY - self.camera.y) * alpha
end

function StationScene:keypressed(key)
    if key == 'escape' or key == 'q' then
        if self.manager then self.manager:pop({ fadeDuration = 0.2 }) end
        return true
    end
    if key == 'e' and self.player and self._doorCooldown <= 0 then
        local room = self:getCurrentRoom()
        if room then
            for _, door in pairs(room.doors or {}) do
                if door and door.to and self:rectsIntersect(self.player.x, self.player.y, self.player.w, self.player.h, door.x, door.y, door.w, door.h) then
                    self:switchRoom(door)
                    self._doorCooldown = 0.15
                    return true
                end
            end
        end
    end
    if self.player and self.player:keypressed(key) then
        return true
    end
    return false
end

function StationScene:keyreleased(key)
    if self.player and self.player.keyreleased then
        return self.player:keyreleased(key)
    end
    return false
end

function StationScene:rectsIntersect(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

return StationScene