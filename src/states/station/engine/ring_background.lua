-- src/states/station/engine/ring_background.lua
-- Sistema de fondo y parallax continuo para la Estación de Tipo Anillo (Ring Station).
-- Gestiona el shader GPU especializado (curvatura toroidal opuesta, hub central, radios giratorios)
-- y renderizado procedural continuo conectado globalmente a través de todas las salas.

local RingBackground = {}
RingBackground.__index = RingBackground

function RingBackground.new()
    local self = setmetatable({}, RingBackground)
    self.time = 0
    self.spin = 0
    self.shader = nil
    self.shaderLoaded = false

    -- Intentar compilar el shader GLSL especializado
    self:initShader()

    -- Estrellas procedurales para fallback y capas auxiliares
    self:initStars()

    return self
end

function RingBackground:initShader()
    local shaderPath = 'src/shaders/ring_station_bg.glsl'
    local code = nil
    if love.filesystem.getInfo and love.filesystem.getInfo(shaderPath) then
        code = love.filesystem.read(shaderPath)
    end
    if not code then
        local paths = {
            shaderPath,
            'c:/Users/sherd/OneDrive/Desktop/JuegoProyectoLove/R-Love-v2/' .. shaderPath,
        }
        for _, p in ipairs(paths) do
            local f = io.open(p, 'r')
            if f then
                code = f:read('*all')
                f:close()
                break
            end
        end
    end

    if code then
        local ok, s = pcall(love.graphics.newShader, code)
        if ok and s then
            self.shader = s
            self.shaderLoaded = true
        else
            print("[RingBackground] Error compilando shader:", tostring(s))
            self.shaderError = tostring(s)
        end
    end
end

function RingBackground:initStars()
    self.stars = {}
    -- Generar 160 estrellas deterministas con diferentes profundidades
    local rng = love.math.newRandomGenerator(1337)
    for i = 1, 160 do
        local depth = rng:random()
        local factor = 0.02 + depth * 0.06
        table.insert(self.stars, {
            x = rng:random(0, 1600),
            y = rng:random(0, 600),
            depth = factor,
            size = (depth > 0.7) and 2 or 1,
            phase = rng:random() * 6.28,
            color = (depth > 0.8) and { 1.0, 0.85, 0.6 } or (depth > 0.4 and { 0.8, 0.95, 1.0 } or { 0.6, 0.75, 0.9 }),
        })
    end
end

function RingBackground:update(dt)
    self.time = self.time + dt
    -- Rotación centrífuga constante (aprox. 1 vuelta cada 120 segundos)
    self.spin = (self.spin + dt * 0.05) % (math.pi * 2)
end

function RingBackground:draw(camX, camY, viewW, viewH, currentRoom)
    viewW = viewW or 480
    viewH = viewH or 270

    if self.shaderLoaded and self.shader then
        self:drawShader(camX, camY, viewW, viewH, currentRoom)
    else
        self:drawProceduralFallback(camX, camY, viewW, viewH, currentRoom)
    end
end

function RingBackground:drawShader(camX, camY, viewW, viewH, currentRoom)
    local s = self.shader
    love.graphics.setShader(s)

    local okSend = pcall(function()
        s:send("u_time", self.time)
        s:send("u_camera", { camX, camY })
        s:send("u_resolution", { viewW, viewH })
        s:send("u_spin", self.spin)
        local a = (currentRoom and currentRoom.accent) or { 0.35, 0.78, 1.00 }
        s:send("u_accent", { a[1], a[2], a[3] })
    end)

    if okSend then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('fill', 0, 0, viewW, viewH)
    else
        -- Si falló el envío de uniforms, recurrir al render procedural
        love.graphics.setShader()
        self:drawProceduralFallback(camX, camY, viewW, viewH, currentRoom)
        return
    end

    love.graphics.setShader()
end

-- Render procedural puro para hardware sin soporte de shader
function RingBackground:drawProceduralFallback(camX, camY, viewW, viewH, currentRoom)
    -- 1. Fondo cósmico base
    love.graphics.setColor(0.015, 0.018, 0.030, 1)
    love.graphics.rectangle('fill', 0, 0, viewW, viewH)

    -- Nebulosa sutil en segundo plano
    love.graphics.setColor(0.04, 0.12, 0.18, 0.45)
    local nebX = -(camX * 0.02) % viewW
    love.graphics.circle('fill', nebX + viewW * 0.4, viewH * 0.3, 140)
    love.graphics.setColor(0.07, 0.04, 0.14, 0.35)
    love.graphics.circle('fill', nebX + viewW * 0.7, viewH * 0.5, 120)

    -- 2. Campo de estrellas con parallax continuo
    for _, st in ipairs(self.stars) do
        local sx = (st.x - camX * st.depth) % (viewW + 20) - 10
        local sy = (st.y - camY * st.depth) % (viewH + 20) - 10
        local tw = 0.7 + 0.3 * math.sin(self.time * 2.5 + st.phase)
        local c = st.color
        love.graphics.setColor(c[1], c[2], c[3], tw)
        love.graphics.rectangle('fill', math.floor(sx), math.floor(sy), st.size, st.size)
    end

    -- 3. Eje central (Hub) y radios giratorios (Spokes)
    local hubX = viewW * 0.5 - (camX - 2400) * 0.09
    local hubY = viewH * 0.38 - (camY - 272) * 0.06

    -- Radios giratorios
    love.graphics.setLineWidth(2)
    for i = 0, 3 do
        local a = self.spin + i * (math.pi * 0.5)
        local rx1 = hubX + math.cos(a) * 20
        local ry1 = hubY + math.sin(a) * 20
        local rx2 = hubX + math.cos(a) * 240
        local ry2 = hubY + math.sin(a) * 240
        love.graphics.setColor(0.18, 0.22, 0.28, 0.85)
        love.graphics.line(rx1, ry1, rx2, ry2)

        -- Vainas de transporte iluminadas
        local podDist = 30 + ((self.time * 20 + i * 50) % 180)
        local px = hubX + math.cos(a) * podDist
        local py = hubY + math.sin(a) * podDist
        love.graphics.setColor(0.35, 0.85, 1.0, 0.9)
        love.graphics.rectangle('fill', px - 1, py - 1, 2, 2)
    end
    love.graphics.setLineWidth(1)

    -- Módulo del Hub Central
    love.graphics.setColor(0.24, 0.28, 0.36, 1)
    love.graphics.circle('fill', hubX, hubY, 18)
    love.graphics.setColor(0.14, 0.17, 0.22, 1)
    love.graphics.circle('fill', hubX, hubY, 7)
    -- Luz estroboscópica del eje
    local hubFlash = (math.sin(self.time * 3) > 0)
    love.graphics.setColor(hubFlash and 1 or 0.3, 0.2, 0.2, 1)
    love.graphics.rectangle('fill', hubX - 1, hubY - 14, 2, 2)
    love.graphics.rectangle('fill', hubX - 1, hubY + 12, 2, 2)

    -- 4. El colosal arco opuesto del anillo
    local ringCamX = camX * 0.18
    local segments = 32
    local stepX = viewW / segments
    for i = 0, segments do
        local x1 = i * stepX
        local x2 = (i + 1) * stepX
        local nx1 = (x1 / viewW) - 0.5
        local nx2 = (x2 / viewW) - 0.5
        local y1 = viewH * 0.30 + (nx1 * nx1) * 90 - (camY - 272) * 0.10
        local y2 = viewH * 0.30 + (nx2 * nx2) * 90 - (camY - 272) * 0.10

        -- Casco del anillo opuesto
        love.graphics.setColor(0.15, 0.18, 0.24, 0.95)
        love.graphics.polygon('fill', x1, y1 - 12, x2, y2 - 12, x2, y2 + 12, x1, y1 + 12)

        -- Borde superior reflectante
        love.graphics.setColor(0.30, 0.36, 0.46, 0.9)
        love.graphics.line(x1, y1 - 12, x2, y2 - 12)
        love.graphics.line(x1, y1 + 12, x2, y2 + 12)

        -- Ventanitas iluminadas en el arco opuesto
        local worldX = x1 + ringCamX
        if math.floor(worldX * 0.08) % 3 ~= 0 then
            love.graphics.setColor(1.0, 0.88, 0.55, 0.75)
            love.graphics.rectangle('fill', x1 + 2, y1 - 3, 2, 2)
            love.graphics.setColor(0.40, 0.85, 1.00, 0.75)
            love.graphics.rectangle('fill', x1 + 6, y1 + 1, 2, 2)
        end
    end
end

function RingBackground:release()
    if self.shader and self.shader.release then
        self.shader:release()
        self.shader = nil
    end
end

return RingBackground
