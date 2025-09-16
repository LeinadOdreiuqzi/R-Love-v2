-- src/states/station/platformer_player.lua

local Player = {}
Player.__index = Player

function Player.new(opts)
    opts = opts or {}
    local p = setmetatable({}, Player)
    p.x = opts.x or 0
    p.y = opts.y or 0
    p.w = opts.w or 12
    p.h = opts.h or 22
    p.vx = 0
    p.vy = 0
    p.onGround = false
    p.facing = 1

    local phys = opts.physics or {}
    p.physics = {
        gravity = phys.gravity or 1700,
        moveAccel = phys.moveAccel or 7200,
        maxSpeed = phys.maxSpeed or 280,
        friction = phys.friction or 5200,
        jumpVelocity = phys.jumpVelocity or 600,
        airControl = phys.airControl or 0.85,
    }

    -- Timers para control de salto
    p.coyoteMax = 0.10
    p.coyote = 0
    p.jumpBufferMax = 0.12
    p.jumpBuffer = 0

    -- Jetpack
    p.jetpack = {
        fuelMax = 1.6,
        fuel = 1.6,
        rechargeGround = 0.8,   -- por segundo
        rechargeAir = 0.35,     -- por segundo
        thrust = 2000,          -- aceleración hacia arriba
        maxAscendSpeed = 360,   -- velocidad vertical máxima al ascender
    }
    p.isJetpacking = false

    return p
end

function Player:keypressed(key)
    if key == 'space' or key == 'w' or key == 'up' or key == 'z' then
        -- Buffer de salto
        self.jumpBuffer = self.jumpBufferMax
        return true
    end
    return false
end

function Player:keyreleased(key)
    if key == 'space' or key == 'w' or key == 'up' or key == 'z' then
        -- Salto variable: si vamos hacia arriba, recortar impulso
        if self.vy < 0 then
            self.vy = self.vy * 0.45
        end
        return true
    end
    return false
end

local function rectsIntersect(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function Player:update(dt, level)
    local phys = self.physics

    -- Timers de salto
    if self.coyote > 0 then self.coyote = self.coyote - dt end
    if self.jumpBuffer > 0 then self.jumpBuffer = self.jumpBuffer - dt end

    -- Input lateral
    local left = love.keyboard.isDown('a') or love.keyboard.isDown('left')
    local right = love.keyboard.isDown('d') or love.keyboard.isDown('right')

    local accel = phys.moveAccel
    if not self.onGround then
        accel = accel * (phys.airControl or 1)
    end

    if left == right then
        -- Fricción cuando no hay input o inputs opuestos
        if self.vx > 0 then
            self.vx = math.max(0, self.vx - phys.friction*dt)
        elseif self.vx < 0 then
            self.vx = math.min(0, self.vx + phys.friction*dt)
        end
    else
        local dir = right and 1 or -1
        self.vx = self.vx + dir * accel * dt
        self.facing = dir
    end

    -- Clamp velocidad lateral
    if self.vx > phys.maxSpeed then self.vx = phys.maxSpeed end
    if self.vx < -phys.maxSpeed then self.vx = -phys.maxSpeed end

    -- Gravedad base
    self.vy = self.vy + phys.gravity * dt

    -- Jetpack (mantener Shift para ascender)
    local jp = self.jetpack
    local jpActive = (love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')) and jp.fuel > 0
    if jpActive then
        self.vy = self.vy - jp.thrust * dt
        if self.vy < -jp.maxAscendSpeed then self.vy = -jp.maxAscendSpeed end
        jp.fuel = math.max(0, jp.fuel - dt)
        self.isJetpacking = true
    else
        self.isJetpacking = false
        local recharge = self.onGround and jp.rechargeGround or jp.rechargeAir
        jp.fuel = math.min(jp.fuelMax, jp.fuel + recharge * dt)
    end

    -- Integración y colisiones separadas por eje (AABB)
    local wasOnGround = self.onGround
    self.onGround = false

    -- Movimiento horizontal
    local newX = self.x + self.vx * dt
    local px, py, pw, ph = newX, self.y, self.w, self.h
    for _, plat in ipairs(level.platforms or {}) do
        if rectsIntersect(px, py, pw, ph, plat.x, plat.y, plat.w, plat.h) then
            if self.vx > 0 then
                newX = plat.x - pw
            elseif self.vx < 0 then
                newX = plat.x + plat.w
            end
            self.vx = 0
            px = newX
        end
    end
    self.x = newX

    -- Movimiento vertical
    local newY = self.y + self.vy * dt
    px, py = self.x, newY
    for _, plat in ipairs(level.platforms or {}) do
        if rectsIntersect(px, py, pw, ph, plat.x, plat.y, plat.w, plat.h) then
            if self.vy > 0 then
                newY = plat.y - ph
                self.onGround = true
            elseif self.vy < 0 then
                newY = plat.y + plat.h
            end
            self.vy = 0
            py = newY
        end
    end
    self.y = newY

    -- Coyote time: si acabamos de tocar suelo
    if self.onGround then
        self.coyote = self.coyoteMax
    end

    -- Consumir buffer de salto si procede
    if self.jumpBuffer > 0 and (self.onGround or self.coyote > 0) then
        self.vy = -phys.jumpVelocity
        self.onGround = false
        self.coyote = 0
        self.jumpBuffer = 0
    end

    -- Límites de la sala (usar offset de sala en mundo)
    local lx, ly = level.x or 0, level.y or 0
    local lw, lh = level.width or 99999, level.height or 99999
    if self.x < lx then self.x = lx; self.vx = 0 end
    if self.y < ly then self.y = ly; self.vy = 0 end
    if self.x + self.w > lx + lw then self.x = lx + lw - self.w; self.vx = 0 end
    if self.y + self.h > ly + lh then self.y = ly + lh - self.h; self.vy = 0; self.onGround = true end
end

function Player:setPosition(x, y)
    self.x, self.y = x, y
end

return Player