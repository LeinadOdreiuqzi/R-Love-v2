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

function ShipRenderer.drawGeometricShip(self, isAbandoned)
    local size = self.size * (self.worldScale or 1)
    local shipType = self.shipType or "EXPLORER"
    
    if shipType == "FIGHTER" then
        self:drawFighterShape(size, isAbandoned)
    elseif shipType == "CARGO" then
        self:drawCargoShape(size, isAbandoned)
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
    
    -- Si tiene sprite y es EXPLORER:
    if self.sprite and self.shipType == "EXPLORER" then
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

    -- 2. Si es un Centinela (WARDEN), dibujar anillo tenue de perímetro de escaneo
    if ai and ai.role == "WARDEN" then
        local scanPulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 3.5)
        local bCol = (ai.config and ai.config.beaconColor) or {0.25, 0.88, 1.0}
        love.graphics.setColor(bCol[1], bCol[2], bCol[3], 0.14 + 0.08 * scanPulse)
        love.graphics.circle("line", renderX, renderY, (self.size or 14) * 2.8, 28)
    end

    -- 3. Dibujar cuerpo activo de la nave y escudo
    love.graphics.push()
    love.graphics.translate(renderX, renderY)
    love.graphics.rotate(renderRot)

    self:drawShieldEffect()
    self:drawGeometricShip(false)

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
    if hpPct < 99 or (ai and ai.state == "COMBAT") then
        local barW = 28
        local barH = 3
        local bx = renderX - barW * 0.5
        local by = renderY - (self.size or 14) * 1.9
        love.graphics.setColor(0.05, 0.07, 0.10, 0.75)
        love.graphics.rectangle("fill", bx - 1, by - 1, barW + 2, barH + 2, 1, 1)
        local bCol = (ai and ai.config and ai.config.beaconColor) or {0.9, 0.3, 0.2}
        love.graphics.setColor(bCol[1], bCol[2], bCol[3], 0.90)
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
    
    -- Dibujar la nave según sprite (Explorer) o geometría especializada (Fighter, Cargo, Explorer fallback)
    if self.sprite and self.shipType == "EXPLORER" then
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


-- Instala los métodos de renderizado en la clase de naves para mantener la API existente (self:drawX(...))
function ShipRenderer.install(Naves)
    Naves.drawThrusterFlame = ShipRenderer.drawThrusterFlame
    Naves.drawFighterShape = ShipRenderer.drawFighterShape
    Naves.drawCargoShape = ShipRenderer.drawCargoShape
    Naves.drawExplorerShape = ShipRenderer.drawExplorerShape
    Naves.drawGeometricShip = ShipRenderer.drawGeometricShip
    Naves.drawShieldEffect = ShipRenderer.drawShieldEffect
    Naves.drawAbandonedShip = ShipRenderer.drawAbandonedShip
    Naves.draw = ShipRenderer.drawShip
end

return ShipRenderer