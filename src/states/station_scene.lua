-- src/states/station_scene.lua
-- Escena de Estación (Ancient Ruins) independiente del gameplay principal

local StateBase = require 'src.states.state_base'

local StationScene = setmetatable({}, { __index = StateBase })
StationScene.__index = StationScene

function StationScene:new(placeholder)
    local o = StateBase.new(self, {
        name = "StationScene",
        suspendUnderlying = true, -- Bloquea update/draw del gameplay mientras está activa
        isOverlay = false
    })
    o.placeholder = placeholder
    o.time = 0
    -- Configuración de físicas y control del modo plataformero
    o.physics = {
        gravity = 1600,     -- px/s^2
        moveAccel = 6000,   -- aceleración lateral
        maxSpeed = 260,     -- velocidad máxima lateral
        friction = 4200,    -- fricción cuando no hay input
        jumpVelocity = 560, -- impulso de salto
    }
    o.level = nil
    o.player = nil
    o.camera = { x = 0, y = 0 }
    return o
end

function StationScene:enter(params)
    self.time = 0
    -- Inicializar nivel y jugador plataformero
    self:setupLevel()
end

function StationScene:update(dt)
    self.time = self.time + dt
    -- Actualizar jugador y cámara del modo plataformero
    self:updatePlayer(dt)
    self:updateCamera()
end

function StationScene:draw()
    -- Fondo
    love.graphics.clear(0.03, 0.03, 0.05, 1)

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    -- Visual base de la estación (marco)
    local lr, lg, lb, la = love.graphics.getColor()
    love.graphics.setColor(0.12, 0.14, 0.18, 1)
    love.graphics.rectangle('fill', w*0.08, h*0.08, w*0.84, h*0.84, 12, 12)

    -- Mundo 2D con cámara
    love.graphics.push()
    love.graphics.translate(-math.floor(self.camera.x), -math.floor(self.camera.y))

    -- Dibujar nivel (suelo y plataformas)
    if self.level then
        -- Fondo del nivel
        love.graphics.setColor(0.08, 0.09, 0.12, 1)
        love.graphics.rectangle('fill', 0, 0, self.level.width, self.level.height)
        -- Suelo/plataformas
        love.graphics.setColor(0.22, 0.65, 0.85, 0.9)
        for _, p in ipairs(self.level.platforms) do
            love.graphics.rectangle('fill', p.x, p.y, p.w, p.h, 4, 4)
        end
    end

    -- Dibujar jugador
    if self.player then
        love.graphics.setColor(0.95, 0.95, 1.0, 1)
        love.graphics.rectangle('fill', self.player.x, self.player.y, self.player.w, self.player.h, 4, 4)
        -- Sombra simple
        love.graphics.setColor(0,0,0,0.2)
        love.graphics.ellipse('fill', self.player.x + self.player.w*0.5, self.player.y + self.player.h, self.player.w*0.45, 6)
    end

    love.graphics.pop()

    -- Header
    love.graphics.setColor(0.75, 0.9, 1.0, 1)
    love.graphics.printf("Estación Antigua - Modo Interno", w*0.1, h*0.1, w*0.8, 'left')

    -- Información contextual de la estación
    love.graphics.setColor(0.85, 0.9, 1.0, 0.9)
    local info = {
        "Estado: En órbita estable (ruinas)",
        "Tipo: " .. (self.placeholder and (self.placeholder.complexType or self.placeholder.stationSize) or "desconocido"),
        string.format("Coordenadas: x=%.0f  y=%.0f", self.placeholder and self.placeholder.x or 0, self.placeholder and self.placeholder.y or 0),
    }
    local y = h*0.1 + 30
    for _, line in ipairs(info) do
        love.graphics.print(line, w*0.1, y)
        y = y + 22
    end

    -- Acciones simples
    love.graphics.setColor(0.9, 0.95, 1.0, 0.9)
    love.graphics.printf("[A/D o ←/→] Mover   [W/↑/ESP/Z] Saltar   [Q / ESC] Salir", w*0.1, h*0.84, w*0.8, 'right')

    love.graphics.setColor(lr, lg, lb, la)
end

function StationScene:keypressed(key)
    if key == 'escape' or key == 'q' then
        if self.manager then self.manager:pop({ fadeDuration = 0.2 }) end
        return true
    end
    -- Salto
    if key == 'space' or key == 'w' or key == 'up' or key == 'z' then
        if self.player and self.player.onGround then
            self.player.vy = -self.physics.jumpVelocity
            self.player.onGround = false
            return true
        end
    end
    return false
end

-- Inicializa nivel (plataformas) y jugador
function StationScene:setupLevel()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    -- Dimensión del nivel (más grande que la pantalla para poder desplazarse)
    local lvlW, lvlH = math.max(2400, sw*2.5), math.max(1200, sh*1.6)

    -- Crear plataformas simples: suelo y algunas elevaciones
    local groundHeight = 56
    local platforms = {
        { x = 0, y = lvlH - groundHeight, w = lvlW, h = groundHeight }, -- suelo
        { x = 220, y = lvlH - 220, w = 220, h = 24 },
        { x = 560, y = lvlH - 340, w = 280, h = 24 },
        { x = 980, y = lvlH - 420, w = 220, h = 24 },
        { x = 1340, y = lvlH - 520, w = 260, h = 24 },
        { x = 1780, y = lvlH - 300, w = 300, h = 24 },
    }

    self.level = {
        width = lvlW,
        height = lvlH,
        platforms = platforms,
    }

    -- Jugador: caja simple
    local startX, startY = 80, lvlH - groundHeight - 64
    self.player = {
        x = startX,
        y = startY,
        w = 32,
        h = 48,
        vx = 0,
        vy = 0,
        onGround = false,
        facing = 1,
    }

    self.camera.x, self.camera.y = 0, math.max(0, self.player.y - sh*0.5)
end

function StationScene:updateCamera()
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    if not self.player or not self.level then return end
    -- Centrar cámara en el jugador, con márgenes
    local targetX = (self.player.x + self.player.w*0.5) - sw*0.5
    local targetY = (self.player.y + self.player.h*0.5) - sh*0.5
    -- Clamp a límites del nivel
    self.camera.x = math.max(0, math.min(self.level.width - sw, targetX))
    self.camera.y = math.max(0, math.min(self.level.height - sh, targetY))
end

function StationScene:updatePlayer(dt)
    if not self.player or not self.level then return end
    local p = self.player
    local phys = self.physics

    -- Input lateral
    local left = love.keyboard.isDown('a') or love.keyboard.isDown('left')
    local right = love.keyboard.isDown('d') or love.keyboard.isDown('right')

    if left == right then
        -- Fricción cuando no hay input o inputs opuestos
        if p.vx > 0 then
            p.vx = math.max(0, p.vx - phys.friction*dt)
        elseif p.vx < 0 then
            p.vx = math.min(0, p.vx + phys.friction*dt)
        end
    else
        local dir = right and 1 or -1
        p.vx = p.vx + dir * phys.moveAccel * dt
        p.facing = dir
    end

    -- Clamp velocidad lateral
    if p.vx > phys.maxSpeed then p.vx = phys.maxSpeed end
    if p.vx < -phys.maxSpeed then p.vx = -phys.maxSpeed end

    -- Gravedad
    p.vy = p.vy + phys.gravity * dt

    -- Integración y colisiones separadas por eje (AABB)
    p.onGround = false

    -- Movimiento horizontal
    local newX = p.x + p.vx * dt
    local px, py, pw, ph = newX, p.y, p.w, p.h
    for _, plat in ipairs(self.level.platforms) do
        if self:rectsIntersect(px, py, pw, ph, plat.x, plat.y, plat.w, plat.h) then
            if p.vx > 0 then
                newX = plat.x - pw
            elseif p.vx < 0 then
                newX = plat.x + plat.w
            end
            p.vx = 0
            px = newX
        end
    end
    p.x = newX

    -- Movimiento vertical
    local newY = p.y + p.vy * dt
    px, py = p.x, newY
    for _, plat in ipairs(self.level.platforms) do
        if self:rectsIntersect(px, py, pw, ph, plat.x, plat.y, plat.w, plat.h) then
            if p.vy > 0 then
                newY = plat.y - ph
                p.onGround = true
            elseif p.vy < 0 then
                newY = plat.y + plat.h
            end
            p.vy = 0
            py = newY
        end
    end
    p.y = newY

    -- Evitar salir de los límites del nivel
    if p.x < 0 then p.x = 0; p.vx = 0 end
    if p.y < 0 then p.y = 0; p.vy = 0 end
    if p.x + p.w > self.level.width then p.x = self.level.width - p.w; p.vx = 0 end
    if p.y + p.h > self.level.height then p.y = self.level.height - p.h; p.vy = 0; p.onGround = true end
end

function StationScene:rectsIntersect(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

return StationScene