-- src/states/station/engine/lighting.lua
-- Sistema de iluminación dinámica para interiores de estaciones espaciales.
-- Renderiza el lightmap virtual en espacio de pantalla con texturas de caída suave
-- (linterna direccional del astronauta, luminarias de techo, consolas, LEDs de puertas)
-- y compone la arquitectura interior sobre el vacío cósmico exterior mediante shader.

local Config = require 'src.states.station.engine.config'

local StationLighting = {}
StationLighting.__index = StationLighting

function StationLighting.new()
    local self = setmetatable({}, StationLighting)
    self.time = 0
    self.lightCanvas = nil
    self.interiorCanvas = nil
    self.w, self.h = 0, 0
    self.shader = nil
    self.shaderLoaded = false
    self.flashlightEnabled = true
    self.ambient = { 0.34, 0.38, 0.46 } -- Penumbra base azul titanio legible y cinematográfica

    -- Luces dinámicas transitorias (chispas, partículas, explosiones)
    self.dynamicLights = {}

    -- Inicializar texturas de luz de alta suavidad matemática
    self:initLightTextures()

    -- Compilar el shader de composición
    self:initShader()

    return self
end

function StationLighting:initLightTextures()
    -- 1. Luz radial esférica suave (64x64 px) con caída cuadrática
    local size = 64
    local radius = size * 0.5
    local radData = love.image.newImageData(size, size)
    for y = 0, size - 1 do
        for x = 0, size - 1 do
            local dx = (x - radius + 0.5) / radius
            local dy = (y - radius + 0.5) / radius
            local d = math.sqrt(dx * dx + dy * dy)
            if d < 1.0 then
                local a = (1.0 - d * d)
                radData:setPixel(x, y, 1, 1, 1, a * a)
            else
                radData:setPixel(x, y, 1, 1, 1, 0)
            end
        end
    end
    self.radialLightImg = love.graphics.newImage(radData)
    self.radialLightImg:setFilter('linear', 'linear')

    -- 2. Haz cónico direccional de linterna suave (128x64 px)
    local coneW, coneH = 128, 64
    local coneData = love.image.newImageData(coneW, coneH)
    for y = 0, coneH - 1 do
        local dy = (y - (coneH * 0.5 - 0.5)) / (coneH * 0.5)
        for x = 0, coneW - 1 do
            local dx = x / (coneW - 1)
            -- Apertura cónica angular que se ensancha hacia adelante
            local spread = math.max(0.12, dx * 0.92)
            if math.abs(dy) <= spread and dx <= 1.0 then
                -- Caída longitudinal suave hacia la punta del haz
                local fallX = (1.0 - dx)
                fallX = fallX * fallX
                -- Caída angular suave hacia los bordes del cono
                local normAngle = (dy / spread) * (math.pi * 0.5)
                local fallY = math.cos(normAngle)
                local a = fallX * fallY * fallY
                coneData:setPixel(x, y, 1, 1, 1, math.min(1.0, a * 1.2))
            else
                coneData:setPixel(x, y, 1, 1, 1, 0)
            end
        end
    end
    self.coneLightImg = love.graphics.newImage(coneData)
    self.coneLightImg:setFilter('linear', 'linear')

    -- 3. Luminaria cenital de techo (64x64 px): caída vertical con dispersión suave
    local stripData = love.image.newImageData(64, 64)
    for y = 0, 63 do
        local dy = y / 63.0
        local fallY = (1.0 - dy)
        fallY = fallY * fallY
        local spread = math.max(0.20, dy * 0.85)
        for x = 0, 63 do
            local dx = (x - 31.5) / 31.5
            if math.abs(dx) <= spread then
                local fallX = math.cos((dx / spread) * (math.pi * 0.5))
                local a = fallY * fallX * fallX
                stripData:setPixel(x, y, 1, 1, 1, a)
            else
                stripData:setPixel(x, y, 1, 1, 1, 0)
            end
        end
    end
    self.stripLightImg = love.graphics.newImage(stripData)
    self.stripLightImg:setFilter('linear', 'linear')
end

function StationLighting:initShader()
    local path = 'src/shaders/station_interior_light.glsl'
    local code = nil
    if love.filesystem.getInfo and love.filesystem.getInfo(path) then
        code = love.filesystem.read(path)
    end
    if not code then
        local altPath = 'c:/Users/sherd/OneDrive/Desktop/JuegoProyectoLove/R-Love-v2/' .. path
        local f = io.open(altPath, 'r')
        if f then
            code = f:read('*all')
            f:close()
        end
    end

    if code then
        local ok, s = pcall(love.graphics.newShader, code)
        if ok and s then
            self.shader = s
            self.shaderLoaded = true
        else
            print("[StationLighting] Error compilando shader:", tostring(s))
            self.shaderLoaded = false
        end
    end
end

function StationLighting:update(dt)
    self.time = self.time + dt

    -- Limpieza de luces dinámicas temporales
    for i = #self.dynamicLights, 1, -1 do
        local l = self.dynamicLights[i]
        if l.duration then
            l.timer = (l.timer or 0) + dt
            if l.timer >= l.duration then
                table.remove(self.dynamicLights, i)
            end
        end
    end
end

function StationLighting:toggleFlashlight()
    self.flashlightEnabled = not self.flashlightEnabled
    return self.flashlightEnabled
end

function StationLighting:addLight(light)
    table.insert(self.dynamicLights, light)
end

function StationLighting:ensureCanvases(vw, vh)
    if not self.lightCanvas or self.w ~= vw or self.h ~= vh then
        if self.lightCanvas then self.lightCanvas:release() end
        if self.interiorCanvas then self.interiorCanvas:release() end
        self.w, self.h = vw, vh
        self.lightCanvas = love.graphics.newCanvas(vw, vh)
        self.lightCanvas:setFilter('linear', 'linear')
        self.interiorCanvas = love.graphics.newCanvas(vw, vh)
        self.interiorCanvas:setFilter('nearest', 'nearest')
    end
end

-- Inicia la captura exclusiva de la arquitectura interior (mamparos, plataformas, jugador)
function StationLighting:beginInterior(vw, vh)
    self:ensureCanvases(vw, vh)
    love.graphics.push('all')
    love.graphics.setCanvas(self.interiorCanvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
end

function StationLighting:endInterior()
    love.graphics.pop()
end

-- Genera el lightmap en lightCanvas
function StationLighting:renderLightmap(scene, camX, camY, vw, vh)
    local room = scene.room
    local player = scene.player
    local T = Config.TILE

    love.graphics.push('all')
    love.graphics.setCanvas(self.lightCanvas)
    love.graphics.origin()

    -- 1. Luz ambiental base de la sala
    local amb = (room and room.def and room.def.ambientLight) or self.ambient
    love.graphics.clear(amb[1], amb[2], amb[3], 1.0)

    -- Modo de dibujo aditivo para sumar intensidades lumínicas
    love.graphics.setBlendMode("add", "alphamultiply")

    -- 2. Luminarias cenitales de techo (Tiras LED / fluorescentes)
    if room then
        local fixtureSpacing = 8
        for tx = 3, room.tw - 2, fixtureSpacing do
            local lx = (room.x + (tx - 1) * T + T * 0.5) - camX
            local ly = (room.y + T * 1.0) - camY

            if lx > -80 and lx < vw + 80 and ly > -150 and ly < vh + 150 then
                local fPulse = 0.94 + 0.06 * math.sin(self.time * 2.5 + tx * 1.3)
                local isFlicker = (room.id == "ring_sector_omega") and (math.sin(self.time * 18.0 + tx * 9.0) > 0.88)
                if not isFlicker then
                    local r = 0.85 * fPulse
                    local g = 0.94 * fPulse
                    local b = 1.00 * fPulse

                    -- Haz descendente suave
                    local beamH = math.min(180, room.th * T * 0.70)
                    local scaleX = 1.8 * fPulse
                    local scaleY = beamH / 64.0
                    love.graphics.setColor(r * 0.40, g * 0.42, b * 0.45, 0.50)
                    love.graphics.draw(self.stripLightImg, lx, ly, 0, scaleX, scaleY, 32, 0)

                    -- Halo puntual en la lámpara
                    love.graphics.setColor(r * 0.75, g * 0.75, b * 0.75, 0.65)
                    local sHalo = (48 / 64) * fPulse
                    love.graphics.draw(self.radialLightImg, lx, ly + 2, 0, sHalo, sHalo, 32, 32)
                end
            end
        end
    end

    -- 3. LEDs y balizas de estado de puertas / escotillas
    if room and room.doors then
        for _, d in ipairs(room.doors) do
            local dx = (d.x + d.w * 0.5) - camX
            local dy = (d.y + d.h * 0.5) - camY
            if dx > -40 and dx < vw + 40 and dy > -40 and dy < vh + 40 then
                local isOpen = (d.state == 'open' or d.state == 'opening')
                if isOpen then
                    -- Verde de presurización segura
                    love.graphics.setColor(0.20, 1.00, 0.55, 0.80)
                else
                    -- Ámbar / rojo de advertencia
                    local blink = 0.75 + 0.25 * math.sin(self.time * 4.0)
                    love.graphics.setColor(1.00, 0.35 * blink, 0.20, 0.75 * blink)
                end
                local s = 32 / 64
                love.graphics.draw(self.radialLightImg, dx, dy, 0, s, s, 32, 32)
            end
        end
    end

    -- 4. Consolas holográficas y terminales
    if room and room.id == "ring_airlock" then
        local conX = (room.x + 8 * T) - camX
        local conY = (room.y + 17 * T) - camY
        if conX > -50 and conX < vw + 50 and conY > -50 and conY < vh + 50 then
            local pulse = 0.85 + 0.15 * math.sin(self.time * 3.5)
            love.graphics.setColor(0.35 * pulse, 0.85 * pulse, 1.00 * pulse, 0.85)
            local s = 46 / 64
            love.graphics.draw(self.radialLightImg, conX, conY, 0, s, s, 32, 32)
        end
    end

    -- 5. Linterna direccional del traje del astronauta (Player Flashlight)
    if player and self.flashlightEnabled then
        local px = (player.x + player.w * 0.5) - camX
        local py = (player.y + 6) - camY
        local f = player.facing or 1

        -- 5.1 Halo ambiental personal 360° suave (radio ~45 px)
        love.graphics.setColor(0.90, 0.96, 1.00, 0.85)
        local sHalo = 90 / 64
        love.graphics.draw(self.radialLightImg, px, py, 0, sHalo, sHalo, 32, 32)

        -- 5.2 Haz cónico frontal suave de largo alcance (165 px de alcance, 76 px de alto)
        local beamLen = 165
        local beamScaleX = (beamLen / 128.0) * f
        local beamScaleY = 76 / 64.0

        -- Aporte de luz xenon blanca-azulada
        love.graphics.setColor(0.92, 0.98, 1.00, 0.95)
        love.graphics.draw(self.coneLightImg, px + f * 4, py + 2, 0, beamScaleX, beamScaleY, 0, 32)

        -- Núcleo brillante concentrado
        love.graphics.setColor(1.00, 1.00, 1.00, 0.65)
        love.graphics.draw(self.coneLightImg, px + f * 4, py + 2, 0, beamScaleX * 0.75, beamScaleY * 0.60, 0, 32)
    end

    -- 6. Visor del casco del astronauta (Emisivo cian)
    if player then
        local vx = (player.facing > 0) and (player.x + player.w - 4) or (player.x + 4)
        local vy = player.y + 3.5
        local svx = vx - camX
        local svy = vy - camY
        love.graphics.setColor(0.35, 0.90, 1.00, 0.95)
        local sVisor = 18 / 64
        love.graphics.draw(self.radialLightImg, svx, svy, 0, sVisor, sVisor, 32, 32)
    end

    -- 7. Luces dinámicas transitorias
    for _, l in ipairs(self.dynamicLights) do
        local lx = l.x - camX
        local ly = l.y - camY
        local rad = l.radius or 32
        if lx > -rad and lx < vw + rad and ly > -rad and ly < vh + rad then
            local col = l.color or { 1, 1, 1 }
            local intens = l.intensity or 1.0
            love.graphics.setColor(col[1] * intens, col[2] * intens, col[3] * intens, 0.85 * intens)
            local s = (rad * 2) / 64
            love.graphics.draw(self.radialLightImg, lx, ly, 0, s, s, 32, 32)
        end
    end

    -- Restaurar blend mode estándar
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

-- Compone la arquitectura interior iluminada sobre el canvas activo
function StationLighting:present(scene, vw, vh)
    if self.shaderLoaded and self.shader then
        love.graphics.setShader(self.shader)
        local okSend = pcall(function()
            self.shader:send("u_lightCanvas", self.lightCanvas)
            self.shader:send("u_bloomIntensity", 0.75)
        end)

        if okSend then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.interiorCanvas, 0, 0)
            love.graphics.setShader()
        else
            love.graphics.setShader()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.interiorCanvas, 0, 0)
        end
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.interiorCanvas, 0, 0)
    end

    -- Sutil halo volumétrico de partículas en el aire para la linterna (dust haze)
    if scene and scene.player and self.flashlightEnabled then
        local camX, camY = scene.camera:drawOffset()
        local px = (scene.player.x + scene.player.w * 0.5) - camX
        local py = (scene.player.y + 6) - camY
        local f = scene.player.facing or 1

        local oldBlend, oldAlpha = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")
        local beamLen = 165
        local beamScaleX = (beamLen / 128.0) * f
        local beamScaleY = 76 / 64.0
        love.graphics.setColor(0.35, 0.60, 0.90, 0.14)
        love.graphics.draw(self.coneLightImg, px + f * 4, py + 2, 0, beamScaleX, beamScaleY, 0, 32)
        love.graphics.setBlendMode(oldBlend, oldAlpha)
    end
end

function StationLighting:release()
    if self.lightCanvas then self.lightCanvas:release(); self.lightCanvas = nil end
    if self.interiorCanvas then self.interiorCanvas:release(); self.interiorCanvas = nil end
    if self.radialLightImg then self.radialLightImg:release(); self.radialLightImg = nil end
    if self.coneLightImg then self.coneLightImg:release(); self.coneLightImg = nil end
    if self.stripLightImg then self.stripLightImg:release(); self.stripLightImg = nil end
    if self.shader and self.shader.release then self.shader:release(); self.shader = nil end
end

return StationLighting
