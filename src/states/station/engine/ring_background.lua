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
    -- Imagen base: círculo suave con caída radial cuadrática (8x8 px)
    local id = love.image.newImageData(8, 8)
    for y = 0, 7 do
        for x = 0, 7 do
            local dx = (x - 3.5) / 3.5
            local dy = (y - 3.5) / 3.5
            local d = math.sqrt(dx * dx + dy * dy)
            local a = math.max(0.0, math.min(1.0, 1.0 - d))
            id:setPixel(x, y, 1, 1, 1, a * a)
        end
    end
    self.starImg = love.graphics.newImage(id)
    self.starImg:setFilter("linear", "linear")

    local rng = love.math.newRandomGenerator(1337)

    -- Capa 1: Micro-polvo estelar cósmico (profundidad infinita, parallax 0.005)
    self.microStars = {}
    for i = 1, 180 do
        local rColor = rng:random()
        local col = { 0.88, 0.94, 1.00 } -- blanco-azulado frío estándar
        if rColor > 0.85 then
            col = { 1.00, 0.88, 0.65 }   -- gigante ámbar/amarillo
        elseif rColor > 0.68 then
            col = { 0.72, 0.86, 1.00 }   -- tipo B azul tenue
        end

        table.insert(self.microStars, {
            x = rng:random() * 480,
            y = rng:random() * 270,
            baseAlpha = 0.38 + rng:random() * 0.48,
            size = 1.1 + rng:random() * 0.8, -- 1.1 a 1.9 px
            phase = rng:random() * 6.28,
            freq = 1.4 + rng:random() * 1.6,
            color = col,
        })
    end

    -- Capa 2: Estrellas de referencia con halo suave aditivo (parallax 0.010)
    self.glowStars = {}
    for i = 1, 32 do
        local rColor = rng:random()
        local col = { 0.92, 0.96, 1.00 }
        if rColor > 0.82 then
            col = { 1.00, 0.86, 0.60 }
        elseif rColor > 0.60 then
            col = { 0.68, 0.88, 1.00 }
        end

        table.insert(self.glowStars, {
            x = rng:random() * 480,
            y = rng:random() * 270,
            baseAlpha = 0.80 + rng:random() * 0.20,
            coreSize = 1.8 + rng:random() * 0.8, -- 1.8 a 2.6 px
            glowSize = 5.0 + rng:random() * 4.0, -- 5.0 a 9.0 px
            glowAlpha = 0.22 + rng:random() * 0.16,
            phase = rng:random() * 6.28,
            freq = 1.0 + rng:random() * 1.2,
            color = col,
        })
    end

    -- Nebulosa y tenue polvo galáctico en el infinito (adaptable a cualquier resolución)
    self.dustBands = {
        { relX = 0.18, relY = 0.40, scaleX = 1.0, scaleY = 1.0, color = { 0.012, 0.016, 0.032, 0.45 } },
        { relX = 0.54, relY = 0.52, scaleX = 1.25, scaleY = 1.15, color = { 0.010, 0.018, 0.028, 0.40 } },
        { relX = 0.84, relY = 0.44, scaleX = 0.95, scaleY = 0.90, color = { 0.014, 0.012, 0.026, 0.35 } },
    }
end

function RingBackground:update(dt)
    self.time = self.time + dt
    -- Rotación centrífuga constante (aprox. 1 vuelta cada 120 segundos)
    self.spin = (self.spin + dt * 0.05) % (math.pi * 2)
end

function RingBackground:draw(camX, camY, viewW, viewH, currentRoom)
    viewW = viewW or 480
    viewH = viewH or 270

    -- Renderizado procedural continuo nativo (diseño canónico y pixel-art puro de la estación)
    self:drawProceduralFallback(camX, camY, viewW, viewH, currentRoom)
end

function RingBackground:drawShader(camX, camY, viewW, viewH, currentRoom)
    local s = self.shader
    love.graphics.setShader(s)

    local okSend = pcall(function()
        if s:hasUniform("u_time") then s:send("u_time", self.time) end
        if s:hasUniform("u_camera") then s:send("u_camera", { camX, camY }) end
        if s:hasUniform("u_resolution") then s:send("u_resolution", { viewW, viewH }) end
        if s:hasUniform("u_spin") then s:send("u_spin", self.spin) end
        if s:hasUniform("u_accent") then
            local a = (currentRoom and currentRoom.accent) or { 0.35, 0.78, 1.00 }
            s:send("u_accent", { a[1], a[2], a[3] })
        end
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
    -- 1. Vacío cósmico profundo puro
    love.graphics.setColor(0.005, 0.007, 0.012, 1)
    love.graphics.rectangle('fill', 0, 0, viewW, viewH)

    -- Tenue banda de polvo estelar galáctico en el infinito (Parallax ultra-lento 0.003)
    if self.dustBands then
        local dustCellW = math.max(480, viewW * 0.85)
        local dustX = (-camX * 0.003)
        local oxDust = ((dustX % dustCellW) + dustCellW) % dustCellW
        local minDustCol = math.floor((-oxDust) / dustCellW) - 1
        local maxDustCol = math.ceil((viewW - oxDust) / dustCellW) + 1

        local baseRx = math.max(180, viewW * 0.32)
        local baseRy = math.max(55, viewH * 0.20)

        for col = minDustCol, maxDustCol do
            local bx = oxDust + col * dustCellW
            for _, d in ipairs(self.dustBands) do
                local cx = bx + d.relX * dustCellW
                local cy = viewH * d.relY - (camY - 272) * 0.002
                local rx = baseRx * d.scaleX
                local ry = baseRy * d.scaleY
                love.graphics.setColor(d.color[1], d.color[2], d.color[3], d.color[4])
                love.graphics.ellipse('fill', cx, cy, rx, ry)
            end
        end
    end

    -- 2. CAMPO ESTELAR MULTICAPA CON TILING CONTINUO ADAPTATIVO A TODO EL VIEWPORT (ZERO-POPPING)
    local cellW = 480
    local cellH = 270

    -- 2.1 Capa A: Micro-polvo estelar cósmico (Parallax ultra-lento 0.005)
    if self.microStars and self.starImg then
        local p1x = -camX * 0.005
        local p1y = -(camY - 272) * 0.003
        local ox1 = ((p1x % cellW) + cellW) % cellW
        local oy1 = ((p1y % cellH) + cellH) % cellH

        local minCol1 = math.floor((-ox1) / cellW) - 1
        local maxCol1 = math.ceil((viewW - ox1) / cellW) + 1
        local minRow1 = math.floor((-oy1) / cellH) - 1
        local maxRow1 = math.ceil((viewH - oy1) / cellH) + 1

        for col = minCol1, maxCol1 do
            local bx = ox1 + col * cellW
            for row = minRow1, maxRow1 do
                local by = oy1 + row * cellH
                for _, st in ipairs(self.microStars) do
                    local sx = bx + st.x
                    local sy = by + st.y
                    if sx >= -4 and sx <= viewW + 4 and sy >= -4 and sy <= viewH + 4 then
                        local tw = 0.78 + 0.22 * math.sin(self.time * st.freq + st.phase)
                        local a = st.baseAlpha * tw
                        love.graphics.setColor(st.color[1], st.color[2], st.color[3], a)
                        local s = st.size / 8.0
                        love.graphics.draw(self.starImg, sx, sy, 0, s, s, 4, 4)
                    end
                end
            end
        end
    end

    -- 2.2 Capa B: Estrellas de referencia con halo suave aditivo (Parallax 0.010)
    if self.glowStars and self.starImg then
        local p2x = -camX * 0.010
        local p2y = -(camY - 272) * 0.006
        local ox2 = ((p2x % cellW) + cellW) % cellW
        local oy2 = ((p2y % cellH) + cellH) % cellH

        local minCol2 = math.floor((-ox2) / cellW) - 1
        local maxCol2 = math.ceil((viewW - ox2) / cellW) + 1
        local minRow2 = math.floor((-oy2) / cellH) - 1
        local maxRow2 = math.ceil((viewH - oy2) / cellH) + 1

        -- Pase 1: Halos suaves difuminados en modo aditivo
        local oldBlend, oldAlpha = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add", "alphamultiply")
        for col = minCol2, maxCol2 do
            local bx = ox2 + col * cellW
            for row = minRow2, maxRow2 do
                local by = oy2 + row * cellH
                for _, st in ipairs(self.glowStars) do
                    local sx = bx + st.x
                    local sy = by + st.y
                    if sx >= -12 and sx <= viewW + 12 and sy >= -12 and sy <= viewH + 12 then
                        local tw = 0.70 + 0.30 * math.sin(self.time * st.freq + st.phase)
                        local a = st.glowAlpha * tw
                        love.graphics.setColor(st.color[1], st.color[2], st.color[3], a)
                        local s = st.glowSize / 8.0
                        love.graphics.draw(self.starImg, sx, sy, 0, s, s, 4, 4)
                    end
                end
            end
        end
        love.graphics.setBlendMode(oldBlend or "alpha", oldAlpha)

        -- Pase 2: Núcleos centrales nítidos en modo alpha
        for col = minCol2, maxCol2 do
            local bx = ox2 + col * cellW
            for row = minRow2, maxRow2 do
                local by = oy2 + row * cellH
                for _, st in ipairs(self.glowStars) do
                    local sx = bx + st.x
                    local sy = by + st.y
                    if sx >= -4 and sx <= viewW + 4 and sy >= -4 and sy <= viewH + 4 then
                        local tw = 0.80 + 0.20 * math.sin(self.time * st.freq + st.phase)
                        local a = st.baseAlpha * tw
                        love.graphics.setColor(1.0, 1.0, 1.0, a)
                        local s = st.coreSize / 8.0
                        love.graphics.draw(self.starImg, sx, sy, 0, s, s, 4, 4)
                    end
                end
            end
        end
    end

    -- 3. Sistema geométrico unificado del Toroide (Unified Torus Frame)
    local hubX = viewW * 0.50 - (camX - 2400) * 0.038
    local hubY = viewH * 0.58 - (camY - 272) * 0.020
    local Rx = math.max(viewW * 0.75 + math.abs(hubX - viewW * 0.50) * 1.2, 440)
    local Ry = math.max(viewH * 0.52 + math.abs(hubY - viewH * 0.58) * 0.8, 220)
    local tiltRatio = Ry / Rx

    -- 4. Puentes radiales de celosía (Radial Elevator Spokes) en perspectiva 3D
    -- Por la lógica física de la estación de anillo (el jugador habita en el arco frontal inferior),
    -- los radios elevadores conectan el Eje Central exclusivamente hacia el Arco Opuesto visible en el cielo (sy <= 0).
    -- En la parte baja de la estación (sy > 0), no deben observarse líneas giratorias adentrándose en el vacío inferior.
    love.graphics.setLineWidth(3)
    for i = 0, 3 do
        local a = self.spin + i * (math.pi * 0.5)
        local sx = math.sin(a) * Rx
        local sy = -math.cos(a) * Ry

        -- Sólo visibles en el hemisferio superior (conectando hacia el arco opuesto)
        if sy <= 0 then
            local horizonFade = math.min(1.0, math.abs(sy) / (Ry * 0.15))
            local alphaSpoke = 0.92 * horizonFade

            local rx1 = hubX + sx * 0.12
            local ry1 = hubY + sy * 0.12
            local rx2 = hubX + sx * 0.98
            local ry2 = hubY + sy * 0.98

            love.graphics.setColor(0.13, 0.16, 0.22, alphaSpoke)
            love.graphics.line(rx1, ry1, rx2, ry2)

            -- Balizas / borde de celosía
            love.graphics.setColor(0.24, 0.30, 0.42, alphaSpoke * 0.85)
            love.graphics.setLineWidth(1)
            love.graphics.line(rx1, ry1, rx2, ry2)
            love.graphics.setLineWidth(3)

            -- Vainas de transporte magnético de alta velocidad (Transit Pods)
            local podT1 = ((self.time * 0.18 + i * 0.25) % 0.82) + 0.10
            local px1 = hubX + sx * podT1
            local py1 = hubY + sy * podT1
            love.graphics.setColor(1.0, 0.92, 0.60, 0.95 * alphaSpoke)
            love.graphics.rectangle('fill', px1 - 1, py1 - 1, 3, 3)

            local podT2 = 0.92 - ((self.time * 0.14 + i * 0.31) % 0.82)
            local px2 = hubX + sx * podT2
            local py2 = hubY + sy * podT2
            love.graphics.setColor(1.0, 0.92, 0.60, 0.95 * alphaSpoke)
            love.graphics.rectangle('fill', px2 - 1, py2 - 1, 3, 3)
        end
    end
    love.graphics.setLineWidth(1)

    -- 4. EJE CENTRAL DE GRAVEDAD CERO (DISEÑO CANÓNICO DE LA ESTACIÓN)
    -- 100% idéntico a station_ring_renderer.lua y al sobre-mundo
    local hubR = 54
    local hubRy = hubR * 0.58
    local hubH = 34
    local topCenterY = hubY - hubH * 0.40
    local botCenterY = hubY + hubH * 0.60

    -- 4.1 PUENTE HORIZONTAL PRINCIPAL EN CELOSÍA 'X' (Main Gantry)
    -- Se extiende de este a oeste a lo largo de todo el horizonte visible
    local gantryH = 8
    local gantryExtent = math.max(viewW, Rx) + math.abs(hubX - viewW * 0.50) + 400
    local gantryLeftX = hubX - gantryExtent
    local gantryRightX = hubX + gantryExtent

    love.graphics.setLineWidth(1.5)
    -- Vigas horizontales superior e inferior
    love.graphics.setColor(0.16, 0.19, 0.26, 0.95)
    love.graphics.line(gantryLeftX, hubY - gantryH, gantryRightX, hubY - gantryH)
    love.graphics.line(gantryLeftX, hubY + gantryH, gantryRightX, hubY + gantryH)

    -- Celosía interna con cruces en 'X' cada 15 px (visible fuera del tambor)
    love.graphics.setColor(0.28, 0.34, 0.46, 0.92)
    local cellW = 15
    local minGx = math.floor(-gantryExtent / cellW) * cellW
    local maxGx = math.ceil(gantryExtent / cellW) * cellW
    for gx = minGx, maxGx, cellW do
        if math.abs(gx) > hubR * 0.82 then
            local xL = hubX + gx
            local xR = xL + cellW
            if xL >= -30 and xR <= viewW + 30 then
                love.graphics.line(xL, hubY - gantryH, xR, hubY + gantryH)
                love.graphics.line(xL, hubY + gantryH, xR, hubY - gantryH)
                love.graphics.line(xL, hubY - gantryH, xL, hubY + gantryH)
            end
        end
    end

    -- Pasillo interior iluminado con luz constante
    love.graphics.setColor(0.40, 0.62, 0.88, 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.line(gantryLeftX, hubY, hubX - hubR * 0.85, hubY)
    love.graphics.line(hubX + hubR * 0.85, hubY, gantryRightX, hubY)

    -- 4.2 RADIOS ESTRUCTURALES DEL EJE (Structural Radial Spokes)
    -- Spoke posterior hacia el ápice del arco opuesto (270° / arriba)
    love.graphics.setColor(0.16, 0.19, 0.26, 0.92)
    love.graphics.setLineWidth(2.5)
    love.graphics.line(hubX, topCenterY - hubRy * 0.95, hubX, hubY - Ry * 0.96)
    love.graphics.setColor(0.42, 0.50, 0.64, 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.line(hubX, topCenterY - hubRy * 0.95, hubX, hubY - Ry * 0.96)

    -- Spokes diagonales posteriores (225° y 315°)
    love.graphics.setColor(0.16, 0.19, 0.26, 0.88)
    love.graphics.setLineWidth(2)
    love.graphics.line(hubX - hubR * 0.67, hubY - hubRy * 0.67, hubX - Rx * 0.71, hubY - Ry * 0.71)
    love.graphics.line(hubX + hubR * 0.67, hubY - hubRy * 0.67, hubX + Rx * 0.71, hubY - Ry * 0.71)
    love.graphics.setLineWidth(1)

    -- 4.3 MÓDULO AUXILIAR / SENSOR POD (Cuadrante frontal izquierdo a 142°)
    local podX = hubX - hubR * 1.72
    local podY = hubY + hubRy * 1.34
    -- Brazo diagonal de anclaje de celosía
    love.graphics.setColor(0.28, 0.34, 0.46, 0.92)
    love.graphics.setLineWidth(1.8)
    love.graphics.line(hubX - hubR * 0.82, botCenterY * 0.40 + hubY * 0.60, podX, podY)

    -- Pod esférico presurizado con elipse inclinada (14 px)
    local podR = 14
    local podRy = podR * 0.58
    love.graphics.setColor(0.16, 0.19, 0.26, 1)
    love.graphics.ellipse('fill', podX, podY, podR, podRy)
    love.graphics.setColor(0.36, 0.43, 0.55, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.ellipse('line', podX, podY, podR, podRy)
    -- Núcleo de energía / sensor óptico cian
    love.graphics.setColor(0.45, 0.70, 0.94, 0.95)
    love.graphics.ellipse('fill', podX, podY, podR * 0.45, podRy * 0.45)
    love.graphics.setColor(0.75, 0.90, 1.00, 1)
    love.graphics.ellipse('fill', podX, podY, podR * 0.22, podRy * 0.22)
    -- Retículo óptico en cruz
    love.graphics.setColor(0.85, 0.92, 1.00, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.line(podX - podR * 0.35, podY, podX + podR * 0.35, podY)
    love.graphics.line(podX, podY - podRy * 0.35, podX, podY + podRy * 0.35)

    -- 4.4 PARED CILÍNDRICA VERTICAL DEL TAMBOR CENTRAL (Drum Cylindrical Body)
    local drumSegs = 28
    for i = 1, drumSegs do
        local a1 = (i - 1) / drumSegs * math.pi * 2
        local a2 = i / drumSegs * math.pi * 2
        local sin1, sin2 = math.sin(a1), math.sin(a2)
        if sin1 > 0 or sin2 > 0 then
            local x1 = hubX + math.cos(a1) * hubR
            local yT1 = topCenterY + math.sin(a1) * hubRy
            local yB1 = botCenterY + math.sin(a1) * hubRy
            local x2 = hubX + math.cos(a2) * hubR
            local yT2 = topCenterY + math.sin(a2) * hubRy
            local yB2 = botCenterY + math.sin(a2) * hubRy

            local midA = (a1 + a2) * 0.5
            local shade = 0.68 + 0.32 * math.cos(midA - 0.45)
            love.graphics.setColor(0.12 * shade, 0.15 * shade, 0.21 * shade, 1)
            love.graphics.polygon('fill', x1, yT1, x2, yT2, x2, yB2, x1, yB1)

            -- Juntas verticales de placas
            if i % 3 == 0 then
                love.graphics.setColor(0.08, 0.10, 0.14, 0.9)
                love.graphics.line(x1, yT1, x1, yB1)
            end
        end
    end

    -- 4.5 TAPA / CÚPULA SUPERIOR DEL HUB DE MANDO (Top Cap Face)
    -- Base oscura
    love.graphics.setColor(0.16, 0.19, 0.26, 1)
    love.graphics.ellipse('fill', hubX, topCenterY, hubR * 0.98, hubRy * 0.98)
    -- Bisel exterior de titanio
    love.graphics.setColor(0.52, 0.60, 0.74, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse('line', hubX, topCenterY, hubR * 0.98, hubRy * 0.98)

    -- Anillo intermedio de acople
    love.graphics.setColor(0.25, 0.30, 0.40, 1)
    love.graphics.ellipse('fill', hubX, topCenterY, hubR * 0.65, hubRy * 0.65)
    love.graphics.setColor(0.36, 0.43, 0.55, 1)
    love.graphics.setLineWidth(1.2)
    love.graphics.ellipse('line', hubX, topCenterY, hubR * 0.65, hubRy * 0.65)

    -- Iris polar central de observación (8 sectores angulares)
    local irisR = hubR * 0.45
    local irisRy = hubRy * 0.45
    love.graphics.setColor(0.10, 0.12, 0.17, 1)
    love.graphics.ellipse('fill', hubX, topCenterY, irisR, irisRy)
    love.graphics.setColor(0.52, 0.60, 0.74, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.ellipse('line', hubX, topCenterY, irisR, irisRy)
    for k = 0, 7 do
        local radA = math.rad(k * 45)
        local ix = hubX + math.cos(radA) * irisR
        local iy = topCenterY + math.sin(radA) * irisRy
        love.graphics.line(hubX, topCenterY, ix, iy)
    end

    -- Túnel axial Zero-G con anillo cian resplandeciente
    local tunR = hubR * 0.20
    local tunRy = hubRy * 0.20
    love.graphics.setColor(0.08, 0.10, 0.14, 1)
    love.graphics.ellipse('fill', hubX, topCenterY, tunR, tunRy)
    love.graphics.setColor(0.45, 0.70, 0.94, 0.95)
    love.graphics.setLineWidth(1.5)
    love.graphics.ellipse('line', hubX, topCenterY, tunR, tunRy)

    -- 6. La Colosal Superestructura del Arco Opuesto (curvatura toroidal monumental)
    local arcSegments = 64
    local angleMin = -1.85
    local angleMax = 1.85
    local angleStep = (angleMax - angleMin) / arcSegments

    for i = 0, arcSegments - 1 do
        local a1 = angleMin + i * angleStep
        local a2 = angleMin + (i + 1) * angleStep

        local x1 = hubX + math.sin(a1) * Rx
        local y1 = hubY - math.cos(a1) * Ry
        local x2 = hubX + math.sin(a2) * Rx
        local y2 = hubY - math.cos(a2) * Ry

        local halfThick = 16
        local arcWorldX = a1 * 1100 + camX * 0.06

        -- Aletas radiadoras térmicas exteriores y paneles solares
        if math.floor(arcWorldX / 56) % 2 == 0 and (arcWorldX % 56) < 18 then
            love.graphics.setColor(0.10, 0.12, 0.16, 0.90)
            love.graphics.polygon('fill', x1, y1 - halfThick - 12, x2, y2 - halfThick - 12, x2, y2 - halfThick, x1, y1 - halfThick)
            -- Núcleo de calor
            love.graphics.setColor(0.45, 0.08, 0.04, 0.70)
            love.graphics.line(x1, y1 - halfThick - 6, x2, y2 - halfThick - 6)
        elseif (arcWorldX % 56) > 28 and (arcWorldX % 56) < 48 then
            -- Paneles solares fotovoltaicos
            love.graphics.setColor(0.06, 0.12, 0.24, 0.85)
            love.graphics.polygon('fill', x1, y1 - halfThick - 8, x2, y2 - halfThick - 8, x2, y2 - halfThick, x1, y1 - halfThick)
        end

        -- Blindaje flotante de titanio exterior
        if (arcWorldX % 36) > 4 and (arcWorldX % 36) < 32 then
            love.graphics.setColor(0.16, 0.20, 0.27, 0.92)
            love.graphics.polygon('fill', x1, y1 - halfThick - 4, x2, y2 - halfThick - 4, x2, y2 - halfThick - 1, x1, y1 - halfThick - 1)
        end

        -- Casco presurizado principal de titanio (Espesor monumental de 28 px)
        love.graphics.setColor(0.13, 0.16, 0.22, 0.98)
        love.graphics.polygon('fill', x1, y1 - halfThick, x2, y2 - halfThick, x2, y2 + halfThick, x1, y1 + halfThick)

        -- Refuerzos de quilla superior e inferior
        love.graphics.setColor(0.16, 0.22, 0.30, 0.95)
        love.graphics.line(x1, y1 - halfThick, x2, y2 - halfThick)
        love.graphics.line(x1, y1 + halfThick, x2, y2 + halfThick)

        -- Costillas maestras cada 32 px
        if (arcWorldX % 32) < 3.0 then
            love.graphics.setColor(0.09, 0.11, 0.15, 0.90)
            love.graphics.line(x1, y1 - halfThick, x1, y1 + halfThick)
        end

        -- Bahías de atraque y hangares activos
        if (arcWorldX % 160) < 24 then
            love.graphics.setColor(0.26, 0.19, 0.09, 0.90)
            love.graphics.polygon('fill', x1, y1 - 6, x2, y2 - 6, x2, y2 + 6, x1, y1 + 6)
            love.graphics.setColor(0.15, 0.95, 0.55, 0.85)
            love.graphics.line(x1, y1 + 4, x2, y2 + 4)
        end

        -- Franja de servicio y conductos técnicos
        love.graphics.setColor(0.08, 0.10, 0.14, 0.90)
        love.graphics.polygon('fill', x1, y1 - 2, x2, y2 - 2, x2, y2 + 2, x1, y1 + 2)

        -- Cubiertas habitacionales iluminadas (City Lights in Space)
        if (arcWorldX % 160) >= 24 then
            local winSeed = math.floor(arcWorldX * 0.25)
            if winSeed % 3 ~= 0 then
                love.graphics.setColor(1.0, 0.88, 0.55, 0.88)
                love.graphics.rectangle('fill', x1 + 1, y1 - 8, 2, 2)
                love.graphics.rectangle('fill', x1 + 3, y1 + 6, 2, 2)
                love.graphics.setColor(0.40, 0.85, 1.00, 0.88)
                love.graphics.rectangle('fill', x1 + 2, y1 - 5, 2, 2)
            end
        end

        -- Tubo de tránsito secundario interior
        love.graphics.setColor(0.14, 0.17, 0.22, 0.70)
        love.graphics.line(x1, y1 + halfThick, x1, y1 + halfThick + 7)
        love.graphics.setColor(0.16, 0.20, 0.28, 0.90)
        love.graphics.line(x1, y1 + halfThick + 7, x2, y2 + halfThick + 7)

        -- Balizas estroboscópicas aeronáuticas
        if (arcWorldX % 96) < 4 then
            local bFlash = (math.sin(self.time * 4.5 + arcWorldX * 0.1) > 0.7)
            love.graphics.setColor(bFlash and 1 or 0.2, 0.15, 0.15, 1)
            love.graphics.rectangle('fill', x1, y1 - halfThick - 1, 2, 2)
        end
    end
end

function RingBackground:release()
    if self.starImg and self.starImg.release then
        self.starImg:release()
        self.starImg = nil
    end
    if self.shader and self.shader.release then
        self.shader:release()
        self.shader = nil
    end
end

return RingBackground
