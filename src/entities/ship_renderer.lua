-- src/entities/ship_renderer.lua
-- Renderizado geométrico puro de naves (cascos, propulsores y siluetas por clase).
-- Separado de naves.lua para desacoplar estado/física de la presentación visual.
-- Todas las funciones reciben la nave como primer argumento (self) y no mutan estado de simulación.

local ShipRenderer = {}

function ShipRenderer.drawThrusterFlame(self, offsetX, offsetY, width, color)
    local intensity = self.engineGlow or 1.0
    local time = love.timer.getTime()
    local pulse = 0.85 + 0.15 * math.sin(time * 16)
    local wiggle = math.sin(time * 24) * 0.08
    local length = width * 2.2 * pulse * intensity

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.rotate(wiggle)

    -- Capa exterior de fuego
    love.graphics.setColor(color[1], color[2], color[3], 0.45 * intensity * pulse)
    love.graphics.polygon("fill",
        -width * 0.6, 0,
        0, length,
        width * 0.6, 0
    )

    -- Capa media brillante
    love.graphics.setColor(math.min(1, color[1] * 1.2), math.min(1, color[2] * 1.2), math.min(1, color[3] * 1.2), 0.75 * intensity * pulse)
    love.graphics.polygon("fill",
        -width * 0.35, 0,
        0, length * 0.65,
        width * 0.35, 0
    )

    -- N├║cleo blanco caliente
    love.graphics.setColor(1.0, 1.0, 1.0, 0.9 * intensity * pulse)
    love.graphics.polygon("fill",
        -width * 0.18, 0,
        0, length * 0.35,
        width * 0.18, 0
    )

    love.graphics.pop()
end

function ShipRenderer.drawFighterShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0

    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.push()
    love.graphics.translate(3, 3)
    love.graphics.polygon("fill",
        0, -size * 1.8,
        -size * 1.4, size * 0.6,
        -size * 0.5, size * 1.0,
        0, size * 0.4,
        size * 0.5, size * 1.0,
        size * 1.4, size * 0.6
    )
    love.graphics.pop()

    -- Paleta (Grafito militar + carmes├¡ de asalto)
    local cBody = isAbandoned and {0.14, 0.16, 0.19, alpha} or {0.18, 0.21, 0.26, alpha}
    local cAccent = isAbandoned and {0.55, 0.18, 0.20, alpha} or {0.92, 0.16, 0.22, alpha}
    local cMetal = isAbandoned and {0.25, 0.27, 0.30, alpha} or {0.40, 0.44, 0.50, alpha}
    local cGlass = isAbandoned and {0.35, 0.25, 0.10, alpha * 0.7} or {1.0, 0.68, 0.12, 0.95}

    -- 1. Alas principales (Forma en flecha agresiva)
    love.graphics.setColor(cBody[1], cBody[2], cBody[3], cBody[4])
    love.graphics.polygon("fill",
        0, -size * 1.2,
        -size * 1.45, size * 0.55,
        -size * 0.9, size * 0.85,
        0, size * 0.3,
        size * 0.9, size * 0.85,
        size * 1.45, size * 0.55
    )

    -- 2. Paneles de acento carmes├¡ en los bordes de ataque de las alas
    love.graphics.setColor(cAccent[1], cAccent[2], cAccent[3], cAccent[4])
    -- Borde ala izquierda
    love.graphics.polygon("fill",
        -size * 0.3, -size * 0.4,
        -size * 1.45, size * 0.55,
        -size * 1.25, size * 0.55,
        -size * 0.2, -size * 0.2
    )
    -- Borde ala derecha
    love.graphics.polygon("fill",
        size * 0.3, -size * 0.4,
        size * 1.45, size * 0.55,
        size * 1.25, size * 0.55,
        size * 0.2, -size * 0.2
    )

    -- 3. Fuselaje central y morro afilado
    love.graphics.setColor(cMetal[1], cMetal[2], cMetal[3], cMetal[4])
    love.graphics.polygon("fill",
        0, -size * 1.8,
        -size * 0.45, -size * 0.2,
        -size * 0.45, size * 0.9,
        0, size * 0.6,
        size * 0.45, size * 0.9,
        size * 0.45, -size * 0.2
    )

    -- 4. Toberas gemelas reforzadas (Twin Engines)
    love.graphics.setColor(0.10, 0.11, 0.13, alpha)
    love.graphics.rectangle("fill", -size * 0.6, size * 0.8, size * 0.35, size * 0.35, 1, 1)
    love.graphics.rectangle("fill", size * 0.25, size * 0.8, size * 0.35, size * 0.35, 1, 1)

    -- 5. Cockpit angular ├ímbar de combate
    love.graphics.setColor(cGlass[1], cGlass[2], cGlass[3], cGlass[4])
    love.graphics.polygon("fill",
        0, -size * 1.3,
        -size * 0.22, -size * 0.45,
        0, -size * 0.25,
        size * 0.22, -size * 0.45
    )

    -- 6. Luces / Balizas t├ícticas
    if isAbandoned then
        local blink = 0.3 + 0.7 * math.abs(math.sin(time * 3.0))
        love.graphics.setColor(1.0, 0.15, 0.2, blink)
        love.graphics.circle("fill", -size * 1.4, size * 0.55, 2.0)
        love.graphics.circle("fill", size * 1.4, size * 0.55, 2.0)
    else
        love.graphics.setColor(1.0, 0.1, 0.1, 0.9)
        love.graphics.circle("fill", -size * 1.4, size * 0.55, 1.8)
        love.graphics.setColor(0.1, 1.0, 0.2, 0.9)
        love.graphics.circle("fill", size * 1.4, size * 0.55, 1.8)

        if self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
            self:drawThrusterFlame(-size * 0.42, size * 1.15, size * 0.45, {1.0, 0.35, 0.1})
            self:drawThrusterFlame(size * 0.42, size * 1.15, size * 0.45, {1.0, 0.35, 0.1})
        end
    end
end

function ShipRenderer.drawCargoShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0

    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.push()
    love.graphics.translate(4, 4)
    love.graphics.rectangle("fill", -size * 1.3, -size * 1.2, size * 2.6, size * 2.3, 4, 4)
    love.graphics.pop()

    -- Paleta (Titanio industrial + amarillo de maquinaria + visor esmeralda)
    local cHull = isAbandoned and {0.20, 0.22, 0.26, alpha} or {0.28, 0.32, 0.38, alpha}
    local cArmor = isAbandoned and {0.30, 0.33, 0.38, alpha} or {0.42, 0.46, 0.54, alpha}
    local cYellow = isAbandoned and {0.55, 0.42, 0.15, alpha} or {0.94, 0.72, 0.14, alpha}
    local cGlass = isAbandoned and {0.15, 0.30, 0.25, alpha * 0.7} or {0.18, 0.90, 0.65, 0.95}

    -- 1. Casco principal blindado (Octogonal ancho)
    love.graphics.setColor(cHull[1], cHull[2], cHull[3], cHull[4])
    love.graphics.polygon("fill",
        -size * 0.8, -size * 1.3,
        size * 0.8, -size * 1.3,
        size * 1.35, -size * 0.6,
        size * 1.35, size * 0.8,
        size * 0.9, size * 1.15,
        -size * 0.9, size * 1.15,
        -size * 1.35, size * 0.8,
        -size * 1.35, -size * 0.6
    )

    -- 2. Contenedores de carga laterales reforzados
    love.graphics.setColor(cArmor[1], cArmor[2], cArmor[3], cArmor[4])
    love.graphics.rectangle("fill", -size * 1.25, -size * 0.5, size * 0.55, size * 1.2, 2, 2)
    love.graphics.rectangle("fill", size * 0.70, -size * 0.5, size * 0.55, size * 1.2, 2, 2)

    -- 3. Bandas industriales en bah├¡as de carga
    love.graphics.setColor(cYellow[1], cYellow[2], cYellow[3], cYellow[4])
    love.graphics.rectangle("fill", -size * 1.2, -size * 0.4, size * 0.45, size * 0.2)
    love.graphics.rectangle("fill", -size * 1.2, size * 0.3, size * 0.45, size * 0.2)
    love.graphics.rectangle("fill", size * 0.75, -size * 0.4, size * 0.45, size * 0.2)
    love.graphics.rectangle("fill", size * 0.75, size * 0.3, size * 0.45, size * 0.2)

    -- 4. Proa blindada reforzada (Ariete pesado)
    love.graphics.setColor(cYellow[1], cYellow[2], cYellow[3], cYellow[4])
    love.graphics.polygon("fill",
        -size * 0.65, -size * 1.25,
        size * 0.65, -size * 1.25,
        size * 0.45, -size * 0.95,
        -size * 0.45, -size * 0.95
    )

    -- 5. Puente de mando blindado (Visor verde esmeralda)
    love.graphics.setColor(cGlass[1], cGlass[2], cGlass[3], cGlass[4])
    love.graphics.rectangle("fill", -size * 0.35, -size * 0.9, size * 0.7, size * 0.25, 2, 2)

    -- 6. Bloque de 3 propulsores pesados
    love.graphics.setColor(0.12, 0.13, 0.16, alpha)
    love.graphics.rectangle("fill", -size * 0.85, size * 1.1, size * 0.4, size * 0.25, 1, 1)
    love.graphics.rectangle("fill", -size * 0.2, size * 1.15, size * 0.4, size * 0.30, 1, 1)
    love.graphics.rectangle("fill", size * 0.45, size * 1.1, size * 0.4, size * 0.25, 1, 1)

    -- 7. Balizas / Luces
    if isAbandoned then
        local blink = 0.3 + 0.7 * math.abs(math.sin(time * 2.0))
        love.graphics.setColor(1.0, 0.75, 0.1, blink)
        love.graphics.circle("fill", -size * 1.25, -size * 0.5, 2.5)
        love.graphics.circle("fill", size * 1.25, -size * 0.5, 2.5)
        love.graphics.circle("fill", -size * 1.25, size * 0.7, 2.5)
        love.graphics.circle("fill", size * 1.25, size * 0.7, 2.5)
    else
        if self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
            self:drawThrusterFlame(-size * 0.65, size * 1.35, size * 0.45, {0.2, 0.7, 1.0})
            self:drawThrusterFlame(0, size * 1.45, size * 0.55, {0.2, 0.85, 1.0})
            self:drawThrusterFlame(size * 0.65, size * 1.35, size * 0.45, {0.2, 0.7, 1.0})
        end
    end
end

function ShipRenderer.drawExplorerShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0

    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.push()
    love.graphics.translate(3, 3)
    love.graphics.polygon("fill",
        0, -size * 1.6,
        -size * 1.1, size * 0.9,
        0, size * 0.5,
        size * 1.1, size * 0.9
    )
    love.graphics.pop()

    -- Paleta (Cobalto espacial + detalles plateados + visor cian)
    local cBody = isAbandoned and {0.12, 0.22, 0.38, alpha} or {0.14, 0.36, 0.72, alpha}
    local cWing = isAbandoned and {0.22, 0.28, 0.36, alpha} or {0.32, 0.52, 0.85, alpha}
    local cAccent = isAbandoned and {0.40, 0.55, 0.65, alpha} or {0.80, 0.90, 1.0, alpha}
    local cGlass = isAbandoned and {0.15, 0.35, 0.45, alpha * 0.7} or {0.30, 0.85, 1.0, 0.95}

    -- 1. Alas delta
    love.graphics.setColor(cWing[1], cWing[2], cWing[3], cWing[4])
    love.graphics.polygon("fill",
        0, -size * 1.0,
        -size * 1.15, size * 0.85,
        0, size * 0.45,
        size * 1.15, size * 0.85
    )

    -- 2. Fuselaje principal
    love.graphics.setColor(cBody[1], cBody[2], cBody[3], cBody[4])
    love.graphics.polygon("fill",
        0, -size * 1.6,
        -size * 0.4, size * 0.8,
        0, size * 0.6,
        size * 0.4, size * 0.8
    )

    -- 3. Detalles de contorno
    love.graphics.setColor(cAccent[1], cAccent[2], cAccent[3], cAccent[4])
    love.graphics.polygon("line",
        0, -size * 1.6,
        -size * 0.4, size * 0.8,
        0, size * 0.6,
        size * 0.4, size * 0.8
    )

    -- 4. Cockpit cian
    love.graphics.setColor(cGlass[1], cGlass[2], cGlass[3], cGlass[4])
    love.graphics.polygon("fill",
        0, -size * 1.1,
        -size * 0.2, -size * 0.2,
        0, -size * 0.05,
        size * 0.2, -size * 0.2
    )

    -- 5. Propulsor central
    love.graphics.setColor(0.12, 0.14, 0.18, alpha)
    love.graphics.rectangle("fill", -size * 0.25, size * 0.75, size * 0.5, size * 0.3, 1, 1)

    -- 6. Balizas / Luces
    if isAbandoned then
        local blink = 0.3 + 0.7 * math.abs(math.sin(time * 2.2))
        love.graphics.setColor(0.2, 0.7, 1.0, blink)
        love.graphics.circle("fill", 0, -size * 0.1, 2.5)
    else
        if self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
            self:drawThrusterFlame(0, size * 1.05, size * 0.6, {0.3, 0.75, 1.0})
        end
    end
end

function ShipRenderer.drawInterceptorShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0

    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.push()
    love.graphics.translate(3, 3)
    love.graphics.polygon("fill",
        0, -size * 2.1,
        -size * 1.35, -size * 0.3,
        -size * 0.55, size * 1.1,
        0, size * 0.5,
        size * 0.55, size * 1.1,
        size * 1.35, -size * 0.3
    )
    love.graphics.pop()

    -- Paleta (Obsidiana sigilosa + violeta plasma + visor magenta)
    local cBody = isAbandoned and {0.12, 0.11, 0.18, alpha} or {0.16, 0.14, 0.25, alpha}
    local cAccent = isAbandoned and {0.42, 0.18, 0.52, alpha} or {0.82, 0.24, 0.96, alpha}
    local cBlade = isAbandoned and {0.26, 0.25, 0.32, alpha} or {0.48, 0.45, 0.62, alpha}
    local cGlass = isAbandoned and {0.32, 0.14, 0.35, alpha * 0.7} or {1.0, 0.32, 0.82, 0.95}

    -- 1. Alas invertidas hacia adelante (Forward-swept interceptor blades)
    love.graphics.setColor(cBody[1], cBody[2], cBody[3], cBody[4])
    love.graphics.polygon("fill",
        -size * 0.25, size * 0.3,
        -size * 1.35, -size * 0.45,
        -size * 1.05, -size * 0.95,
        -size * 0.70, size * 0.85
    )
    love.graphics.polygon("fill",
        size * 0.25, size * 0.3,
        size * 1.35, -size * 0.45,
        size * 1.05, -size * 0.95,
        size * 0.70, size * 0.85
    )

    -- 2. Filos de plasma en las puntas de ala
    love.graphics.setColor(cAccent[1], cAccent[2], cAccent[3], cAccent[4])
    love.graphics.polygon("fill",
        -size * 1.35, -size * 0.45,
        -size * 1.05, -size * 0.95,
        -size * 0.90, -size * 0.20
    )
    love.graphics.polygon("fill",
        size * 1.35, -size * 0.45,
        size * 1.05, -size * 0.95,
        size * 0.90, -size * 0.20
    )

    -- 3. Aguja central hipersónica
    love.graphics.setColor(cBlade[1], cBlade[2], cBlade[3], cBlade[4])
    love.graphics.polygon("fill",
        0, -size * 2.15,
        -size * 0.34, size * 0.2,
        -size * 0.22, size * 1.05,
        0, size * 0.80,
        size * 0.22, size * 1.05,
        size * 0.34, size * 0.2
    )

    -- 4. Visor longitudinal
    love.graphics.setColor(cGlass[1], cGlass[2], cGlass[3], cGlass[4])
    love.graphics.polygon("fill",
        0, -size * 1.45,
        -size * 0.15, -size * 0.35,
        0, -size * 0.05,
        size * 0.15, -size * 0.35
    )

    -- 5. Propulsor vectorial central
    if not isAbandoned and self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
        self:drawThrusterFlame(0, size * 1.0, size * 0.52, {0.88, 0.25, 1.0})
    end
end

function ShipRenderer.drawGunshipShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0

    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.28)
    love.graphics.push()
    love.graphics.translate(4, 4)
    love.graphics.polygon("fill",
        -size * 0.65, -size * 1.5,
        size * 0.65, -size * 1.5,
        size * 1.55, -size * 0.3,
        size * 1.35, size * 1.1,
        -size * 1.35, size * 1.1,
        -size * 1.55, -size * 0.3
    )
    love.graphics.pop()

    -- Paleta (Acero pesado + naranja artillería + bronce oscuro)
    local cHull = isAbandoned and {0.18, 0.17, 0.16, alpha} or {0.26, 0.24, 0.23, alpha}
    local cPlate = isAbandoned and {0.28, 0.25, 0.22, alpha} or {0.44, 0.38, 0.34, alpha}
    local cAccent = isAbandoned and {0.52, 0.24, 0.12, alpha} or {0.96, 0.42, 0.12, alpha}
    local cGlass = isAbandoned and {0.35, 0.18, 0.12, alpha * 0.7} or {1.0, 0.35, 0.18, 0.95}

    -- 1. Bastiones laterales portacañones (Sponsons)
    love.graphics.setColor(cHull[1], cHull[2], cHull[3], cHull[4])
    love.graphics.polygon("fill",
        -size * 0.6, -size * 1.3,
        size * 0.6, -size * 1.3,
        size * 1.55, -size * 0.25,
        size * 1.35, size * 1.05,
        -size * 1.35, size * 1.05,
        -size * 1.55, -size * 0.25
    )

    -- 2. Cañones gemelos pesados sobresaliendo al frente
    love.graphics.setColor(0.12, 0.12, 0.14, alpha)
    love.graphics.rectangle("fill", -size * 1.15, -size * 1.65, size * 0.28, size * 0.95, 1, 1)
    love.graphics.rectangle("fill", size * 0.87, -size * 1.65, size * 0.28, size * 0.95, 1, 1)

    -- 3. Placa de blindaje frontal y franjas de artillería
    love.graphics.setColor(cPlate[1], cPlate[2], cPlate[3], cPlate[4])
    love.graphics.polygon("fill",
        -size * 0.75, -size * 1.25,
        size * 0.75, -size * 1.25,
        size * 0.95, size * 0.85,
        -size * 0.95, size * 0.85
    )
    love.graphics.setColor(cAccent[1], cAccent[2], cAccent[3], cAccent[4])
    love.graphics.rectangle("fill", -size * 0.85, -size * 0.95, size * 1.7, size * 0.22)

    -- 4. Torreta / Puente acorazado
    love.graphics.setColor(cGlass[1], cGlass[2], cGlass[3], cGlass[4])
    love.graphics.polygon("fill",
        -size * 0.45, -size * 0.55,
        size * 0.45, -size * 0.55,
        size * 0.30, -size * 0.15,
        -size * 0.30, -size * 0.15
    )

    -- 5. Propulsores dobles de alto empuje
    if not isAbandoned and self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
        self:drawThrusterFlame(-size * 0.65, size * 1.10, size * 0.55, {1.0, 0.42, 0.12})
        self:drawThrusterFlame(size * 0.65, size * 1.10, size * 0.55, {1.0, 0.42, 0.12})
    elseif isAbandoned then
        local blink = 0.3 + 0.7 * math.abs(math.sin(time * 2.4))
        love.graphics.setColor(1.0, 0.4, 0.1, blink)
        love.graphics.circle("fill", -size * 1.0, -size * 1.65, 2.2)
        love.graphics.circle("fill", size * 1.0, -size * 1.65, 2.2)
    end
end

function ShipRenderer.drawSalvagerShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0

    -- Paleta (Verde oliva industrial + ámbar de excavación)
    local cBody = isAbandoned and {0.18, 0.22, 0.19, alpha} or {0.25, 0.33, 0.28, alpha}
    local cClaw = isAbandoned and {0.35, 0.32, 0.22, alpha} or {0.78, 0.64, 0.18, alpha}
    local cGlass = isAbandoned and {0.20, 0.32, 0.22, alpha * 0.7} or {0.45, 1.0, 0.55, 0.95}

    -- 1. Pinzas frontales de desmantelamiento (Mandíbulas industriales)
    love.graphics.setColor(cClaw[1], cClaw[2], cClaw[3], cClaw[4])
    love.graphics.polygon("fill",
        -size * 0.95, -size * 0.6,
        -size * 0.55, -size * 1.75,
        -size * 0.30, -size * 1.55,
        -size * 0.55, -size * 0.6
    )
    love.graphics.polygon("fill",
        size * 0.95, -size * 0.6,
        size * 0.55, -size * 1.75,
        size * 0.30, -size * 1.55,
        size * 0.55, -size * 0.6
    )

    -- 2. Chasis compacto de remolcador
    love.graphics.setColor(cBody[1], cBody[2], cBody[3], cBody[4])
    love.graphics.polygon("fill",
        -size * 0.85, -size * 0.85,
        size * 0.85, -size * 0.85,
        size * 1.10, size * 0.85,
        -size * 1.10, size * 0.85
    )

    -- 3. Cabina panorámica industrial
    love.graphics.setColor(cGlass[1], cGlass[2], cGlass[3], cGlass[4])
    love.graphics.rectangle("fill", -size * 0.42, -size * 0.65, size * 0.84, size * 0.32, 2, 2)

    if not isAbandoned and self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
        self:drawThrusterFlame(-size * 0.45, size * 0.90, size * 0.42, {0.4, 0.95, 0.55})
        self:drawThrusterFlame(size * 0.45, size * 0.90, size * 0.42, {0.4, 0.95, 0.55})
    end
end

function ShipRenderer.drawSentinelShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0
    local pulse = 0.7 + 0.3 * math.sin(time * 6.0)

    -- Paleta (Marfil monolítico antiguo + cian de contención)
    local cMonolith = isAbandoned and {0.22, 0.26, 0.30, alpha} or {0.72, 0.80, 0.88, alpha}
    local cDark = isAbandoned and {0.10, 0.14, 0.18, alpha} or {0.14, 0.22, 0.32, alpha}
    local cCore = isAbandoned and {0.15, 0.40, 0.45, alpha} or {0.15, 0.92, 1.0, alpha * pulse}

    -- 1. Rombo exterior segmentado (Geometría ancestral)
    love.graphics.setColor(cMonolith[1], cMonolith[2], cMonolith[3], cMonolith[4])
    love.graphics.polygon("fill",
        0, -size * 1.85,
        -size * 1.35, 0,
        0, size * 1.45,
        size * 1.35, 0
    )

    -- 2. Cavidad interior oscura
    love.graphics.setColor(cDark[1], cDark[2], cDark[3], cDark[4])
    love.graphics.polygon("fill",
        0, -size * 1.15,
        -size * 0.75, 0,
        0, size * 0.85,
        size * 0.75, 0
    )

    -- 3. Anillo y Ojo de Contención Cian
    love.graphics.setColor(cCore[1], cCore[2], cCore[3], cCore[4])
    love.graphics.circle("fill", 0, -size * 0.1, size * 0.38)
    love.graphics.circle("line", 0, -size * 0.1, size * 0.62, 16)

    if not isAbandoned and self.engineGlow > 0 then
        self:drawThrusterFlame(0, size * 1.45, size * 0.50, {0.15, 0.95, 1.0})
    end
end

function ShipRenderer.drawTitanExcavatorShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0
    local pulse = 0.7 + 0.3 * math.sin(time * 4.5)

    -- Sombra pesada
    love.graphics.setColor(0, 0, 0, 0.32)
    love.graphics.push()
    love.graphics.translate(5, 5)
    love.graphics.rectangle("fill", -size * 1.4, -size * 1.6, size * 2.8, size * 3.1, 6, 6)
    love.graphics.pop()

    local cHull = isAbandoned and {0.19, 0.22, 0.20, alpha} or {0.26, 0.32, 0.29, alpha}
    local cPlate = isAbandoned and {0.28, 0.31, 0.29, alpha} or {0.38, 0.45, 0.41, alpha}
    local cAmber = isAbandoned and {0.48, 0.36, 0.14, alpha} or {0.95, 0.72, 0.18, alpha}
    local cCore = isAbandoned and {0.20, 0.35, 0.25, alpha * 0.7} or {0.35, 1.0, 0.60, alpha * pulse}

    -- 1. Brazos de excavación y molienda frontales masivos
    love.graphics.setColor(cAmber[1], cAmber[2], cAmber[3], cAmber[4])
    love.graphics.polygon("fill",
        -size * 1.35, -size * 0.75,
        -size * 0.85, -size * 1.95,
        -size * 0.45, -size * 1.70,
        -size * 0.75, -size * 0.75
    )
    love.graphics.polygon("fill",
        size * 1.35, -size * 0.75,
        size * 0.85, -size * 1.95,
        size * 0.45, -size * 1.70,
        size * 0.75, -size * 0.75
    )

    -- 2. Casco central de Barcaza Madre (Plataforma octogonal pesada)
    love.graphics.setColor(cHull[1], cHull[2], cHull[3], cHull[4])
    love.graphics.polygon("fill",
        -size * 0.95, -size * 1.45,
        size * 0.95, -size * 1.45,
        size * 1.45, -size * 0.70,
        size * 1.45, size * 1.05,
        size * 1.00, size * 1.45,
        -size * 1.00, size * 1.45,
        -size * 1.45, size * 1.05,
        -size * 1.45, -size * 0.70
    )

    -- 3. Bahías laterales de atraque de recolectores y silos de mineral
    love.graphics.setColor(cPlate[1], cPlate[2], cPlate[3], cPlate[4])
    love.graphics.rectangle("fill", -size * 1.32, -size * 0.55, size * 0.52, size * 1.45, 3, 3)
    love.graphics.rectangle("fill", size * 0.80, -size * 0.55, size * 0.52, size * 1.45, 3, 3)

    -- 4. Horno / Reactor central de refinado (Esmeralda industrial)
    love.graphics.setColor(0.10, 0.14, 0.12, alpha)
    love.graphics.circle("fill", 0, -size * 0.15, size * 0.48)
    love.graphics.setColor(cCore[1], cCore[2], cCore[3], cCore[4])
    love.graphics.circle("fill", 0, -size * 0.15, size * 0.30)
    love.graphics.circle("line", 0, -size * 0.15, size * 0.42, 20)

    -- 5. Puente de comando superior
    love.graphics.setColor(cAmber[1], cAmber[2], cAmber[3], cAmber[4])
    love.graphics.rectangle("fill", -size * 0.55, -size * 1.15, size * 1.10, size * 0.26, 2, 2)

    -- 6. Cuatro propulsores pesados de crucero
    if not isAbandoned and self.engineGlow > 0 then
        self:drawThrusterFlame(-size * 0.85, size * 1.48, size * 0.45, {0.3, 0.95, 0.55})
        self:drawThrusterFlame(-size * 0.30, size * 1.52, size * 0.55, {0.3, 0.95, 0.55})
        self:drawThrusterFlame(size * 0.30, size * 1.52, size * 0.55, {0.3, 0.95, 0.55})
        self:drawThrusterFlame(size * 0.85, size * 1.48, size * 0.45, {0.3, 0.95, 0.55})
    end
end

function ShipRenderer.drawDreadnoughtShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0
    local pulse = 0.72 + 0.28 * math.sin(time * 6.0)

    -- Sombra de acorazado
    love.graphics.setColor(0, 0, 0, 0.34)
    love.graphics.push()
    love.graphics.translate(5, 5)
    love.graphics.polygon("fill",
        0, -size * 2.1,
        -size * 1.55, -size * 0.2,
        -size * 1.15, size * 1.5,
        size * 1.15, size * 1.5,
        size * 1.55, -size * 0.2
    )
    love.graphics.pop()

    -- Paleta (Obsidiana imperial + púrpura plasma + carmesí corsario)
    local cBody = isAbandoned and {0.11, 0.10, 0.16, alpha} or {0.15, 0.12, 0.24, alpha}
    local cArmor = isAbandoned and {0.20, 0.18, 0.28, alpha} or {0.28, 0.23, 0.42, alpha}
    local cPurple = isAbandoned and {0.42, 0.16, 0.52, alpha} or {0.84, 0.22, 0.98, alpha}
    local cCrimson = isAbandoned and {0.50, 0.14, 0.18, alpha} or {0.96, 0.18, 0.28, alpha}

    -- 1. Alas acorazadas en punta de lanza con espolones hacia adelante
    love.graphics.setColor(cBody[1], cBody[2], cBody[3], cBody[4])
    love.graphics.polygon("fill",
        -size * 0.35, -size * 1.25,
        -size * 1.55, -size * 0.25,
        -size * 1.25, size * 1.35,
        0, size * 1.05,
        size * 1.25, size * 1.35,
        size * 1.55, -size * 0.25,
        size * 0.35, -size * 1.25
    )

    -- 2. Espolón bifurcado de proa (Prow Prongs con pista de lanzamiento de cazas en el medio)
    love.graphics.setColor(cArmor[1], cArmor[2], cArmor[3], cArmor[4])
    love.graphics.polygon("fill",
        -size * 0.68, -size * 0.85,
        -size * 0.32, -size * 2.15,
        -size * 0.16, -size * 1.85,
        -size * 0.22, size * 1.15,
        -size * 0.72, size * 1.15
    )
    love.graphics.polygon("fill",
        size * 0.68, -size * 0.85,
        size * 0.32, -size * 2.15,
        size * 0.16, -size * 1.85,
        size * 0.22, size * 1.15,
        size * 0.72, size * 1.15
    )

    -- 3. Pista magnética de lanzamiento del Hangar Central (Brillo magenta/violeta)
    love.graphics.setColor(0.06, 0.04, 0.10, alpha)
    love.graphics.rectangle("fill", -size * 0.18, -size * 1.65, size * 0.36, size * 2.25)
    love.graphics.setColor(cPurple[1], cPurple[2], cPurple[3], alpha * pulse)
    love.graphics.rectangle("fill", -size * 0.08, -size * 1.55, size * 0.16, size * 1.95)

    -- 4. Filos de energía púrpura y baterías carmesí en los bastiones laterales
    love.graphics.setColor(cCrimson[1], cCrimson[2], cCrimson[3], cCrimson[4])
    love.graphics.polygon("fill",
        -size * 1.55, -size * 0.25,
        -size * 1.15, -size * 0.85,
        -size * 0.95, size * 0.45
    )
    love.graphics.polygon("fill",
        size * 1.55, -size * 0.25,
        size * 1.15, -size * 0.85,
        size * 0.95, size * 0.45
    )

    -- 5. Puente de mando imperial
    love.graphics.setColor(1.0, 0.32, 0.85, 0.95 * alpha)
    love.graphics.polygon("fill",
        0, size * 0.05,
        -size * 0.38, size * 0.55,
        0, size * 0.78,
        size * 0.38, size * 0.55
    )

    if not isAbandoned and self.engineGlow > 0 then
        self:drawThrusterFlame(-size * 0.75, size * 1.35, size * 0.55, {0.88, 0.22, 1.0})
        self:drawThrusterFlame(0, size * 1.25, size * 0.70, {0.98, 0.25, 0.55})
        self:drawThrusterFlame(size * 0.75, size * 1.35, size * 0.55, {0.88, 0.22, 1.0})
    end
end

function ShipRenderer.drawArkMonolithShape(self, size, isAbandoned)
    local time = love.timer.getTime()
    local alpha = isAbandoned and 0.85 or 1.0
    local pulse = 0.7 + 0.3 * math.sin(time * 5.0)

    local cIvory = isAbandoned and {0.25, 0.28, 0.32, alpha} or {0.78, 0.85, 0.92, alpha}
    local cGold = isAbandoned and {0.35, 0.32, 0.22, alpha} or {0.92, 0.78, 0.38, alpha}
    local cCyan = isAbandoned and {0.15, 0.42, 0.48, alpha} or {0.18, 0.94, 1.0, alpha * pulse}

    -- 1. Anillo exterior sagrado y arcos flotantes
    love.graphics.setColor(cGold[1], cGold[2], cGold[3], cGold[4] * 0.85)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, size * 1.35, 32)
    love.graphics.setLineWidth(1)

    -- 2. Cuatro pilares monolíticos en cruz/estrella
    love.graphics.setColor(cIvory[1], cIvory[2], cIvory[3], cIvory[4])
    love.graphics.polygon("fill",
        0, -size * 2.05,
        -size * 0.55, -size * 0.45,
        0, size * 1.65,
        size * 0.55, -size * 0.45
    )
    love.graphics.polygon("fill",
        -size * 1.65, -size * 0.15,
        -size * 0.45, -size * 0.65,
        size * 1.65, -size * 0.15,
        size * 0.45, size * 0.45
    )

    -- 3. Esfera de Singularidad Cian en el corazón del Arca
    love.graphics.setColor(0.06, 0.12, 0.18, alpha)
    love.graphics.circle("fill", 0, -size * 0.1, size * 0.58)
    love.graphics.setColor(cCyan[1], cCyan[2], cCyan[3], cCyan[4])
    love.graphics.circle("fill", 0, -size * 0.1, size * 0.38)
    love.graphics.circle("line", 0, -size * 0.1, size * 0.78, 24)

    if not isAbandoned and self.engineGlow > 0 then
        self:drawThrusterFlame(0, size * 1.65, size * 0.65, {0.18, 0.95, 1.0})
    end
end

function ShipRenderer.drawGeometricShip(self, isAbandoned)
    local size = self.size * (self.worldScale or 1)
    local shipType = self.shipType or "EXPLORER"
    
    if shipType == "FIGHTER" then
        self:drawFighterShape(size, isAbandoned)
    elseif shipType == "CARGO" then
        self:drawCargoShape(size, isAbandoned)
    elseif shipType == "INTERCEPTOR" then
        self:drawInterceptorShape(size, isAbandoned)
    elseif shipType == "GUNSHIP" then
        self:drawGunshipShape(size, isAbandoned)
    elseif shipType == "SALVAGER" then
        self:drawSalvagerShape(size, isAbandoned)
    elseif shipType == "SENTINEL" then
        self:drawSentinelShape(size, isAbandoned)
    elseif shipType == "TITAN_EXCAVATOR" then
        self:drawTitanExcavatorShape(size, isAbandoned)
    elseif shipType == "ECLIPSE" or shipType == "DREADNOUGHT" then
        self:drawDreadnoughtShape(size, isAbandoned)
    elseif shipType == "ARK_MONOLITH" then
        self:drawArkMonolithShape(size, isAbandoned)
    else
        self:drawExplorerShape(size, isAbandoned)
    end
end

function ShipRenderer.drawShieldEffect(self)
    local shieldPercentage = self.stats and self.stats:getShieldPercentage() or 0
    if shieldPercentage > 0 then
        local shieldAlpha = 0.25 + (shieldPercentage / 100) * 0.45
        local shieldRadius = (self.size * (self.worldScale or 1)) * 1.9
        
        love.graphics.setColor(0.2, 0.6, 1.0, shieldAlpha)
        love.graphics.circle("line", 0, 0, shieldRadius, 24)
        
        if self.stats.shield and self.stats.shield.isRegenerating then
            local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 8)
            love.graphics.setColor(0.2, 0.8, 1.0, pulse * 0.3)
            love.graphics.circle("line", 0, 0, shieldRadius * 1.08, 24)
        end
    end
end

function ShipRenderer.drawAbandonedShip(self)
    local World = package.loaded['src.core.world']
    local alpha = World and World.get('interpolationAlpha') or 1.0
    local MathUtil = require 'src.utils.math_util'

    -- Interpolación de posición y rotación para naves a la deriva / abandonadas
    local renderX = MathUtil.lerp(self.prevX or self.x, self.x, alpha)
    local renderY = MathUtil.lerp(self.prevY or self.y, self.y, alpha)
    local renderRot = MathUtil.lerpAngle(self.prevRotation or self.rotation, self.rotation, alpha)

    love.graphics.push()
    love.graphics.translate(renderX, renderY)
    love.graphics.rotate(renderRot)
    
    local r, g, b, a = love.graphics.getColor()
    
    -- Si tiene sprite de nave inicial del jugador (useStarterSprite) y es EXPLORER:
    if self.sprite and self.useStarterSprite and self.shipType == "EXPLORER" then
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.push()
        love.graphics.translate(3, 3)
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
        love.graphics.pop()

        love.graphics.setColor(0.5, 0.55, 0.65, 0.85)
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)

        local blink = 0.3 + 0.7 * math.abs(math.sin(love.timer.getTime() * 2.5))
        love.graphics.setColor(0.2, 0.6, 1.0, blink)
        love.graphics.circle("fill", 0, -self.spriteOffsetY * 0.3, 2.5)
    else
        -- Dibujado geométrico dedicado según clase (FIGHTER, CARGO, EXPLORER) en modo abandonado
        self:drawGeometricShip(true)
    end
    
    love.graphics.setColor(r, g, b, a)
    love.graphics.pop()

    -- Dibujar proyectiles remanentes o chispas de impacto aunque la nave esté abandonada
    if self.drawProjectiles then
        love.graphics.push("all")
        self:drawProjectiles()
        love.graphics.pop()
    end
end

function ShipRenderer.drawAIShip(self)
    local World = package.loaded['src.core.world']
    local alpha = World and World.get('interpolationAlpha') or 1.0
    local MathUtil = require 'src.utils.math_util'

    local renderX = MathUtil.lerp(self.prevX or self.x, self.x, alpha)
    local renderY = MathUtil.lerp(self.prevY or self.y, self.y, alpha)
    local renderRot = MathUtil.lerpAngle(self.prevRotation or self.rotation, self.rotation, alpha)

    local r, g, b, a = love.graphics.getColor()
    local ai = self.aiController

    -- 1. Si el agente está extrayendo recursos o desmantelando un pecio, dibujar haz industrial diegético
    if ai and ai.worldGoal and ai.worldGoal.isWorking and ai.worldGoal.targetX and ai.worldGoal.targetY then
        local pulse = 0.55 + 0.45 * math.sin(love.timer.getTime() * 18)
        local prowX = renderX + math.sin(renderRot) * (self.size or 14) * 1.1
        local prowY = renderY - math.cos(renderRot) * (self.size or 14) * 1.1
        love.graphics.setColor(1.0, 0.78, 0.22, 0.35 * pulse)
        love.graphics.setLineWidth(4)
        love.graphics.line(prowX, prowY, ai.worldGoal.targetX, ai.worldGoal.targetY)
        love.graphics.setColor(1.0, 0.95, 0.65, 0.85 * pulse)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(prowX, prowY, ai.worldGoal.targetX, ai.worldGoal.targetY)
        love.graphics.circle("fill", ai.worldGoal.targetX, ai.worldGoal.targetY, 3.5 * pulse)
        love.graphics.setLineWidth(1)
    end

    -- 2. Si es un Centinela (WARDEN) o está en modo ADVERTENCIA (ALERT: WARN), dibujar anillo/arco diegético
    if ai and (ai.role == "WARDEN" or (ai.state == "ALERT" and ai.alertMode == "WARN")) then
        local isWarn = (ai.state == "ALERT" and ai.alertMode == "WARN")
        local freq = isWarn and 9.5 or 3.5
        local scanPulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * freq)
        local bCol = isWarn and {1.0, 0.72, 0.15} or ((ai.config and ai.config.beaconColor) or {0.25, 0.88, 1.0})
        love.graphics.setColor(bCol[1], bCol[2], bCol[3], (isWarn and 0.28 or 0.14) + 0.12 * scanPulse)
        love.graphics.circle("line", renderX, renderY, (self.size or 14) * (isWarn and 2.3 or 2.8), 28)
    end

    -- 2.5. Telegrafía de Ataque Pesado (Laser Lock / Carga antes de disparar en GUNSHIP o SENTINEL)
    if ai and ai.telegraphTimer and ai.telegraphTimer > 0 and ai.telegraphAimX and ai.telegraphAimY then
        local chargeRatio = 1.0 - math.min(1.0, ai.telegraphTimer / (ai.telegraphDuration or 0.55))
        local prowX = renderX + math.sin(renderRot) * (self.size or 14) * 1.25
        local prowY = renderY - math.cos(renderRot) * (self.size or 14) * 1.25
        love.graphics.setColor(1.0, 0.25, 0.15, 0.25 + 0.60 * chargeRatio)
        love.graphics.setLineWidth(1.5 + 2.0 * chargeRatio)
        love.graphics.line(prowX, prowY, ai.telegraphAimX, ai.telegraphAimY)
        love.graphics.setColor(1.0, 0.85, 0.35, 0.90)
        love.graphics.circle("fill", prowX, prowY, 2.5 + 4.5 * chargeRatio)
        love.graphics.setLineWidth(1)
    end

    -- 2.6. Enlace de Recarga de Escudo desde Nodriza (Carrier Shield Tether)
    if ai and ai.isReceivingCarrierShield and ai.wingmanOf and not ai.wingmanOf.isDestroyed and not ai.wingmanOf.isAbandoned then
        local mx = MathUtil.lerp(ai.wingmanOf.prevX or ai.wingmanOf.x, ai.wingmanOf.x, alpha)
        local my = MathUtil.lerp(ai.wingmanOf.prevY or ai.wingmanOf.y, ai.wingmanOf.y, alpha)
        local tPulse = 0.55 + 0.45 * math.sin(love.timer.getTime() * 14.0)
        local isEclipse = (ai.wingmanOf.shipType == "ECLIPSE" or ai.wingmanOf.shipType == "DREADNOUGHT")
        local tetherCol = isEclipse and {0.85, 0.25, 1.0} or {0.20, 0.90, 1.0}
        love.graphics.setColor(tetherCol[1], tetherCol[2], tetherCol[3], 0.38 * tPulse)
        love.graphics.setLineWidth(4.5)
        love.graphics.line(mx, my, renderX, renderY)
        love.graphics.setColor(0.85, 0.98, 1.0, 0.85 * tPulse)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(mx, my, renderX, renderY)
        love.graphics.circle("line", renderX, renderY, (self.size or 14) * 1.75, 20)
        love.graphics.setLineWidth(1)
    end

    -- 2.7. Destello de Despliegue de Hangar (cuando una Nodriza lanza escoltas de refuerzo)
    if ai and ai.hangarFlashTimer and ai.hangarFlashTimer > 0 then
        local fRatio = math.max(0, math.min(1, ai.hangarFlashTimer / 0.85))
        local isEclipse = (self.shipType == "ECLIPSE" or self.shipType == "DREADNOUGHT")
        local fCol = isEclipse and {0.92, 0.20, 1.0}
            or ((self.shipType == "TITAN_EXCAVATOR") and {1.0, 0.78, 0.22} or {0.20, 0.95, 1.0})
        love.graphics.setColor(fCol[1], fCol[2], fCol[3], 0.55 * fRatio)
        love.graphics.circle("line", renderX, renderY, (self.size or 36) * (1.2 + (1.0 - fRatio) * 1.1), 28)
        love.graphics.setColor(1.0, 1.0, 1.0, 0.45 * fRatio)
        love.graphics.circle("fill", renderX, renderY, (self.size or 36) * 0.40 * fRatio)
    end

    -- 2.8. Estela de Entrada por Impulso Sub-Warp (evita que las naves parezcan aparecer de la nada)
    if ai and ai.warpInTimer and ai.warpInTimer > 0 then
        local wRatio = math.max(0, math.min(1, ai.warpInTimer / 0.90))
        local bCol = (ai.config and ai.config.beaconColor) or {0.35, 0.85, 1.0}
        local tailLen = (self.size or 16) * 12.0 * wRatio
        local tailX = renderX - math.sin(renderRot) * tailLen
        local tailY = renderY + math.cos(renderRot) * tailLen
        love.graphics.setColor(bCol[1], bCol[2], bCol[3], 0.55 * wRatio)
        love.graphics.setLineWidth(4.5 * wRatio + 1.0)
        love.graphics.line(tailX, tailY, renderX, renderY)
        love.graphics.setColor(1.0, 1.0, 1.0, 0.85 * wRatio)
        love.graphics.circle("line", renderX, renderY, (self.size or 16) * (1.2 + wRatio * 1.8), 24)
        love.graphics.setLineWidth(1)
    end

    -- 2.9. Haz Tractor / Rayo de Chatarrería Industrial (Salvager Tractor Beam)
    if ai and ai.isTractorBeaming and ai.tractorTargetX and ai.tractorTargetY then
        local tTime = love.timer and love.timer.getTime and love.timer.getTime() or 0
        local tx = ai.tractorTargetX
        local ty = ai.tractorTargetY
        local prowX = renderX + math.sin(renderRot) * (self.size or 14) * 1.15
        local prowY = renderY - math.cos(renderRot) * (self.size or 14) * 1.15

        local pulse = 0.65 + 0.35 * math.sin(tTime * 16.0)

        -- Haz exterior: cono / línea dorada-ámbar gruesa pulsante
        love.graphics.setColor(1.0, 0.72, 0.18, 0.38 * pulse)
        love.graphics.setLineWidth(5.0 + pulse * 2.0)
        love.graphics.line(prowX, prowY, tx, ty)

        -- Haz medio: amarillo intenso concentrado
        love.graphics.setColor(1.0, 0.88, 0.35, 0.75 * pulse)
        love.graphics.setLineWidth(2.2)
        love.graphics.line(prowX, prowY, tx, ty)

        -- Núcleo central blanco caliente
        love.graphics.setColor(1.0, 1.0, 0.9, 0.90 * pulse)
        love.graphics.setLineWidth(1.0)
        love.graphics.line(prowX, prowY, tx, ty)

        -- Emisor de proa
        love.graphics.setColor(1.0, 0.90, 0.40, 0.95)
        love.graphics.circle("fill", prowX, prowY, 2.8)

        -- Anillo gravítico de captura en el objetivo
        local ringR = 9.0 + 4.0 * math.sin(tTime * 12.0)
        love.graphics.setColor(1.0, 0.75, 0.15, 0.65 * pulse)
        love.graphics.circle("line", tx, ty, ringR, 16)
        love.graphics.setColor(1.0, 0.95, 0.60, 0.45 * pulse)
        love.graphics.circle("fill", tx, ty, 3.5)

        love.graphics.setLineWidth(1)
    end

    -- 3. Dibujar cuerpo activo de la nave, propulsores laterales RCS (Drift/Juke) y escudo
    love.graphics.push()
    love.graphics.translate(renderX, renderY)
    love.graphics.rotate(renderRot)

    -- Propulsores laterales RCS visibles cuando hace Derrape Inercial (isDrifting) o Esquiva Reactiva (jukeTimer > 0)
    if ai and (self.isDrifting or (ai.jukeTimer and ai.jukeTimer > 0) or (ai.rcsThrustDir and ai.rcsThrustDir ~= 0)) then
        local sz = (self.size or 14) * (self.worldScale or 1)
        local rcsSide = (ai.rcsThrustDir and ai.rcsThrustDir ~= 0) and ai.rcsThrustDir or 1
        local rcsAlpha = (ai.jukeTimer and ai.jukeTimer > 0) and 0.85 or 0.45
        love.graphics.setColor(0.65, 0.90, 1.0, rcsAlpha)
        -- El chorro sale del flanco opuesto al empuje lateral
        local nozzleX = -rcsSide * sz * 0.85
        love.graphics.polygon("fill",
            nozzleX, -sz * 0.25,
            nozzleX - rcsSide * sz * 0.75, 0,
            nozzleX, sz * 0.25
        )
    end

    self:drawShieldEffect()
    self:drawGeometricShip(false)
    ShipRenderer.drawHardpointsAndMuzzleFlashes(self)

    -- Baliza de rol / estado diegético sobre el fuselaje
    if ai and ai.config and ai.config.beaconColor then
        local bc = ai.config.beaconColor
        local blinkSpeed = (ai.state == "COMBAT") and 10.0 or 3.0
        local blink = 0.45 + 0.55 * math.abs(math.sin(love.timer.getTime() * blinkSpeed))
        love.graphics.setColor(bc[1], bc[2], bc[3], blink)
        love.graphics.circle("fill", 0, 0, 2.4)
    end

    love.graphics.pop()

    -- 4. Micro-indicador diegético de casco/escudo cuando la nave está dañada o en combate
    local hpPct = (self.stats and self.stats:getHealthPercentage()) or 100
    local isMothership = (self.shipConfig and self.shipConfig.isMothership)
    if hpPct < 99 or (ai and ai.state == "COMBAT") or isMothership then
        local barW = isMothership and 56 or 28
        local barH = isMothership and 4.5 or 3
        local bx = renderX - barW * 0.5
        local by = renderY - (self.size or 14) * (isMothership and 1.55 or 1.9)
        love.graphics.setColor(0.05, 0.07, 0.10, 0.82)
        love.graphics.rectangle("fill", bx - 1, by - 1, barW + 2, barH + 2, 1, 1)
        local bCol = (ai and ai.config and ai.config.beaconColor) or {0.9, 0.3, 0.2}
        love.graphics.setColor(bCol[1], bCol[2], bCol[3], 0.92)
        love.graphics.rectangle("fill", bx, by, barW * math.max(0, math.min(1, hpPct / 100)), barH, 1, 1)
    end

    love.graphics.setColor(r, g, b, a)

    -- 5. Dibujar proyectiles disparados por esta nave IA
    if self.drawProjectiles then
        love.graphics.push("all")
        self:drawProjectiles()
        love.graphics.pop()
    end
end

function ShipRenderer.drawShip(self)
    local World = package.loaded['src.core.world']
    local isPlayer = (self.isPiloted or (World and World.getPlayer and World.getPlayer() == self))

    -- Si no es la nave controlada actualmente por el jugador:
    if not isPlayer then
        if self.isAI and not self.isAbandoned and self.aiController and self.aiController.active then
            ShipRenderer.drawAIShip(self)
        else
            self:drawAbandonedShip()
        end
        return
    end

    -- Si está en modo EVA, dibujar la nave nodriza abandonada y al astronauta
    if self.isInEVA then
        self:drawAbandonedShip()
        self:drawEVA()
        return
    end
    
    local alpha = World and World.get('interpolationAlpha') or 1.0
    local MathUtil = require 'src.utils.math_util'
    
    -- Calcular posición y rotación interpolada
    local renderX = MathUtil.lerp(self.prevX or self.x, self.x, alpha)
    local renderY = MathUtil.lerp(self.prevY or self.y, self.y, alpha)
    local renderRot = MathUtil.lerpAngle(self.prevRotation or self.rotation, self.rotation, alpha)

    love.graphics.push()
    love.graphics.translate(renderX, renderY)
    love.graphics.rotate(renderRot)
    
    local r, g, b, a = love.graphics.getColor()
    
    -- Escudo visual activo
    self:drawShieldEffect()
    
    -- Dibujar la nave según sprite inicial (si useStarterSprite) o geometría especializada de su clase
    if self.sprite and self.useStarterSprite and self.shipType == "EXPLORER" then
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.push()
        love.graphics.translate(3, 3)
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
        love.graphics.pop()

        local fuelPercentage = self.stats and self.stats:getFuelPercentage() or 100
        if fuelPercentage < 25 then
            love.graphics.setColor(1.0, 0.6, 0.4, 1.0)
        elseif fuelPercentage < 50 then
            love.graphics.setColor(1.0, 1.0, 0.6, 1.0)
        else
            love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
        end
        
        love.graphics.draw(self.sprite, 
                          -self.spriteOffsetX * self.spriteScale, 
                          -self.spriteOffsetY * self.spriteScale, 
                          0, 
                          self.spriteScale, 
                          self.spriteScale)
                          
        if self.engineGlow > 0 and (not self.stats or self.stats:canMove()) then
            self:drawThrusterFlame(0, self.spriteOffsetY * self.spriteScale * 0.85, self.size * 0.8, {1.0, 0.55, 0.1})
        end

        local blinkPhase = love.timer.getTime() * 3
        if math.sin(blinkPhase) > 0 then
            local lightOffset = self.spriteOffsetX * self.spriteScale * 0.6
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.circle("fill", -lightOffset, 0, 2)
            love.graphics.setColor(0, 1, 0, 1)
            love.graphics.circle("fill", lightOffset, 0, 2)
        end
    else
        self:drawGeometricShip(false)
    end
    ShipRenderer.drawHardpointsAndMuzzleFlashes(self)
    
    -- Aviso de combustible crítico
    local fuelPercentage = self.stats and self.stats:getFuelPercentage() or 100
    if fuelPercentage < 15 and math.sin(love.timer.getTime() * 6) > 0 then
        love.graphics.setColor(1, 0, 0, 0.8)
        local warningRadius = (self.size * (self.worldScale or 1)) * 2.2
        love.graphics.circle("line", 0, 0, warningRadius, 16)
    end
    
    love.graphics.setColor(r, g, b, a)
    love.graphics.pop()
    
    -- Dibujar proyectiles de la nave
    love.graphics.push("all")
    self:drawProjectiles()
    love.graphics.pop()
end


-- Renderiza los montajes de hardpoints activos (Niveles 1-4 estilo Heavy Weapon) y sus fogonazos localizados
function ShipRenderer.drawHardpointsAndMuzzleFlashes(self)
    if not self or not self.weaponSystem or self.isAbandoned then return end

    -- 1. Indicadores diegéticos de torretas/emisores activos en el chasis cuando el arma está en Nivel >= 2
    if self.weaponSystem.currentWeapon and self.weaponSystem.getActiveHardpointEmitters and self.getHardpointLocalPosition then
        local emitters, hpLevel = self.weaponSystem:getActiveHardpointEmitters(self.weaponSystem.currentWeapon)
        if emitters and hpLevel and hpLevel >= 2 then
            for _, em in ipairs(emitters) do
                local lx, ly = self:getHardpointLocalPosition(em.name)
                if lx and ly then
                    love.graphics.setColor(0.14, 0.18, 0.24, 0.90)
                    love.graphics.rectangle("fill", lx - 1.6, ly - 3.6, 3.2, 5.2, 1, 1)
                    if hpLevel >= 4 then
                        love.graphics.setColor(1.0, 0.82, 0.22, 0.85)
                    else
                        love.graphics.setColor(0.35, 0.85, 1.0, 0.75)
                    end
                    love.graphics.circle("fill", lx, ly - 2.2, 1.3)
                end
            end
        end
    end

    -- 2. Fogonazos localizados (Muzzle Flashes) en la coordenada exacta del hardpoint que disparó
    local flashes = self.weaponSystem.activeMuzzleFlashes
    if flashes and #flashes > 0 then
        for i = 1, #flashes do
            local mf = flashes[i]
            if mf and mf.lx and mf.ly then
                local progress = math.min(1.0, (mf.timer or 0) / math.max(0.01, mf.duration or 0.09))
                local fade = 1.0 - progress
                local radius = (mf.overcharged and 6.2 or 4.2) * (0.7 + 0.5 * fade)

                if mf.overcharged then
                    love.graphics.setColor(1.0, 0.85, 0.25, 0.55 * fade)
                else
                    love.graphics.setColor(0.35, 0.88, 1.0, 0.50 * fade)
                end
                love.graphics.circle("fill", mf.lx, mf.ly - 2.0, radius)

                love.graphics.setColor(1.0, 1.0, 1.0, 0.92 * fade)
                love.graphics.circle("fill", mf.lx, mf.ly - 2.5, radius * 0.48)
            end
        end
    end
end

-- Instala los métodos de renderizado en la clase de naves para mantener la API existente (self:drawX(...))
function ShipRenderer.install(Naves)
    Naves.drawThrusterFlame = ShipRenderer.drawThrusterFlame
    Naves.drawHardpointsAndMuzzleFlashes = ShipRenderer.drawHardpointsAndMuzzleFlashes
    Naves.drawFighterShape = ShipRenderer.drawFighterShape
    Naves.drawCargoShape = ShipRenderer.drawCargoShape
    Naves.drawExplorerShape = ShipRenderer.drawExplorerShape
    Naves.drawInterceptorShape = ShipRenderer.drawInterceptorShape
    Naves.drawGunshipShape = ShipRenderer.drawGunshipShape
    Naves.drawSalvagerShape = ShipRenderer.drawSalvagerShape
    Naves.drawSentinelShape = ShipRenderer.drawSentinelShape
    Naves.drawTitanExcavatorShape = ShipRenderer.drawTitanExcavatorShape
    Naves.drawDreadnoughtShape = ShipRenderer.drawDreadnoughtShape
    Naves.drawArkMonolithShape = ShipRenderer.drawArkMonolithShape
    Naves.drawGeometricShip = ShipRenderer.drawGeometricShip
    Naves.drawShieldEffect = ShipRenderer.drawShieldEffect
    Naves.drawAbandonedShip = ShipRenderer.drawAbandonedShip
    Naves.draw = ShipRenderer.drawShip
end

return ShipRenderer