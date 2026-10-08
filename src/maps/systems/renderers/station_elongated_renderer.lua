-- src/maps/systems/renderers/station_elongated_renderer.lua
-- Renderizador Especializado de Megaestructura Espacial: Estación Orbital Final Weapon (Mega Man X4 Class)
-- Estética Anime Mecha / Super-Arma Espacial Colosal:
-- - Perspectiva oblicua 3/4 frontal con la apertura de flor hacia el frente y el fuste cónico hacia atrás (arriba-derecha).
-- - Floración mecha abierta con cuchillas que curvan hacia adentro en la punta (con la punta casi hacia adentro).
-- - Jerarquía de capas de profundidad estricta:
--   1. El cono posterior es la parte más trasera (fondo inferior de la escena).
--   2. Los pétalos traseros opacos se dibujan POR ENCIMA del cono, enmarcando la aguja desde el frente.
--   3. Collar dorado central y mamparo concéntrico del iris del súper-cañón.
--   4. Núcleo de plasma central con destello en cruz (4-point star lens flare).
--   5. Pétalos frontales en primer plano, con paneles térmicos (pink radiator slats) perfectamente
--      integrados a las nervaduras de su respectivo pétalo, rematados en puntas afiladas de cuchilla.
-- - Variantes de daño: Operacional prístina, Dañada con fallos térmicos y arcos voltaicos, y Ruinas catastróficas.

local StationElongatedRenderer = {}

-- ============================================================================
-- PALETA DE MATERIALES AUTÉNTICA FINAL WEAPON (MEGA MAN X4)
-- ============================================================================
local PALETTE = {
    -- Blindaje exterior carmesí oscuro / vino tinto mecha (Armored Hull)
    armorDeepShadow  = { 0.12, 0.03, 0.08 }, -- Sombras profundas y uniones de placas
    armorWineBase    = { 0.22, 0.05, 0.15 }, -- Púrpura vino oscuro base (pétalos traseros opacos)
    armorCrimsonDark = { 0.36, 0.08, 0.22 }, -- Cara exterior sombreada
    armorCrimsonMid  = { 0.54, 0.12, 0.28 }, -- Rojo carmesí mecha base de placas frontales
    armorCrimsonHot  = { 0.78, 0.16, 0.38 }, -- Aristas iluminadas y biseles dorsales
    armorHighlight   = { 0.96, 0.35, 0.58 }, -- Reflejo especular en bordes
    armorRimWhite    = { 1.00, 0.90, 0.96 }, -- Destello blanco-rosado en vértices

    -- Rejillas de disipación de calor / paneles térmicos (Pink/Magenta Radiator Slats)
    heatBedTrough    = { 0.14, 0.02, 0.08 }, -- Fondo del surco cóncavo del radiador
    heatDarkMagenta  = { 0.58, 0.10, 0.32 }, -- Base de láminas disipadoras
    heatGlowPink     = { 1.00, 0.20, 0.56 }, -- Rosa neón brillante de emisión térmica
    heatCoreWhite    = { 1.00, 0.96, 0.98 }, -- Filamento central ultrabrillante
    heatSlatRib      = { 0.09, 0.02, 0.05 }, -- Divisiones mecánicas transversales

    -- Núcleo del Cañón Super-Arma (Central Plasma Cannon Core)
    cannonPlasmaCore = { 1.00, 0.98, 1.00 }, -- Foco central de plasma blanco puro
    cannonPlasmaPink = { 1.00, 0.16, 0.52 }, -- Corona de energía magenta vibrante
    cannonGlowHalo   = { 0.90, 0.08, 0.36, 0.38 }, -- Halo exterior radiante
    cannonIrisMetal  = { 0.13, 0.12, 0.17 }, -- Anillo concéntrico de grafito/titanio
    cannonIrisRing   = { 0.25, 0.22, 0.32 }, -- Ranuras y conductos mecánicos del iris

    -- Collar Mecánico Central Acampanado (Golden / Brass Collar)
    collarGoldLight  = { 0.98, 0.86, 0.42 }, -- Aleación dorada iluminada
    collarGoldMid    = { 0.78, 0.60, 0.20 }, -- Bronce/oro base de contención
    collarGoldDark   = { 0.40, 0.28, 0.09 }, -- Sombra profunda del collar
    collarWindowWarm = { 1.00, 0.92, 0.58 }, -- Micro-ventanas habitacionales

    -- Fuste Cónico / Aguja Tecnológica Posterior (Rear Spindle / Drive Cone)
    spindleLight     = { 0.30, 0.34, 0.44 }, -- Paneles superiores iluminados
    spindleMid       = { 0.18, 0.21, 0.30 }, -- Casco metálico base índigo/acero
    spindleDark      = { 0.11, 0.13, 0.18 }, -- Hendiduras y costillas en sombra
    spindleDeep      = { 0.06, 0.07, 0.10 }, -- Popa y toberas posteriores
    spindleTruss     = { 0.42, 0.48, 0.60 }, -- Antenas estabilizadoras de popa

    -- Luces de Señalización y Sistemas
    beaconAmber      = { 1.00, 0.75, 0.20 }, -- Luces de advertencia y collar
    beaconCyan       = { 0.25, 0.88, 1.00 }, -- Telemetría del fuste
    thrusterCyan     = { 0.28, 0.82, 1.00 }, -- Propulsión sub-luz de popa
    thrusterCore     = { 0.88, 0.96, 1.00 },

    -- Daños y Ruinas
    charredMetal     = { 0.08, 0.07, 0.09 }, -- Casco carbonizado
    emberGlow        = { 1.00, 0.42, 0.12 }, -- Rescoldos térmicos
    electricArc      = { 0.35, 0.88, 1.00 }, -- Arcos voltaicos de fallo
    trussSteel       = { 0.42, 0.48, 0.58 }  -- Vigas estructurales expuestas
}

local function setColor(c, alphaMul)
    alphaMul = alphaMul or 1.0
    local a = (c[4] or 1.0) * alphaMul
    love.graphics.setColor(c[1], c[2], c[3], a)
end

-- ============================================================================
-- 1. TRANSFORMADA GEOMÉTRICA 3D Y PROYECCIÓN OBLICUA FINAL WEAPON
-- ============================================================================
local BASE_PITCH   = math.rad(46.0)  -- Inclinación 3/4 hacia la cámara (revela interior y núcleo)
local BASE_AZIMUTH = math.rad(-42.0) -- Orientación en pantalla (popa apunta a arriba-derecha)

local function getProjectionBasis(placeholder, camera, rotation)
    local camX = (camera and camera.x) or placeholder.x
    local camY = (camera and camera.y) or placeholder.y

    local relX = placeholder.x - camX
    local relY = placeholder.y - camY

    -- Parallax volumétrico según posición de cámara
    local normX = math.max(-1.0, math.min(1.0, relX / 3200))
    local normY = math.max(-1.0, math.min(1.0, relY / 3200))
    local skewX = normX * 0.16
    local skewY = normY * 0.10

    local pitch = BASE_PITCH
    local azim  = BASE_AZIMUTH

    -- Dirección unitaria del eje en pantalla (desde popa hacia proa, hacia abajo-izquierda)
    local dirFrontX = -math.cos(azim)
    local dirFrontY = -math.sin(azim)

    -- Dirección transversal unitaria perpendicular en pantalla
    local dirTransX = -dirFrontY
    local dirTransY =  dirFrontX

    -- Rotación orbital propia (roll alrededor del eje longitudinal)
    local roll = (rotation or 0) + math.rad(28.0)

    return {
        pitch     = pitch,
        azim      = azim,
        cosP      = math.cos(pitch),
        sinP      = math.sin(pitch),
        dirFrontX = dirFrontX,
        dirFrontY = dirFrontY,
        dirTransX = dirTransX,
        dirTransY = dirTransY,
        skewX     = skewX,
        skewY     = skewY,
        roll      = roll
    }
end

-- Proyectar punto 3D local (xLong, yRad, zRad) a coordenadas de pantalla (sx, sy, zCam)
-- zCam es la profundidad hacia la cámara: valores más altos = más cerca del espectador
local function projectPoint3D(cx, cy, xLong, yRad, zRad, basis)
    local cosR, sinR = math.cos(basis.roll), math.sin(basis.roll)
    local yr = yRad * cosR - zRad * sinR
    local zr = yRad * sinR + zRad * cosR
    local xr = xLong

    -- Inclinación pitch hacia la cámara:
    -- xr > 0 (proa/frente) se acerca a la cámara (+xr * sinP)
    -- zr < 0 (lado inferior-frontal) se acerca a la cámara (-zr * cosP > 0)
    -- zr > 0 (lado superior-trasero) se aleja en el fondo (-zr * cosP < 0)
    local xProj = xr * basis.cosP - zr * basis.sinP
    local zCam  = xr * basis.sinP - zr * basis.cosP
    local yProj = yr

    local sx = cx + xProj * basis.dirFrontX + yProj * basis.dirTransX + zCam * basis.skewX
    local sy = cy + xProj * basis.dirFrontY + yProj * basis.dirTransY + zCam * basis.skewY

    return sx, sy, zCam
end

-- ============================================================================
-- 2. DIBUJO DE DESTELLO EN CRUZ / ANIME 4-POINT LENS FLARE
-- ============================================================================
local function drawCrossFlare(px, py, rayLen, coreRadius, coreColor, rayColor, alpha, rotOffset)
    rotOffset = rotOffset or 0
    love.graphics.push()
    love.graphics.translate(px, py)
    love.graphics.rotate(rotOffset)

    local rL = rayLen
    local rW = math.max(1.5, coreRadius * 0.40)

    setColor(rayColor, alpha * 0.85)
    love.graphics.polygon("fill", -rL, 0, 0, -rW, rL, 0, 0, rW)
    love.graphics.polygon("fill", 0, -rL, -rW, 0, 0, rL, rW, 0)

    local sL = rL * 0.38
    local sW = rW * 0.45
    love.graphics.polygon("fill", -sL, -sL, sW, -sW, sL, sL, -sW, sW)
    love.graphics.polygon("fill", sL, -sL, sW, sW, -sL, sL, -sW, -sW)

    setColor(coreColor, alpha * 0.98)
    love.graphics.circle("fill", 0, 0, coreRadius)

    love.graphics.pop()
end

-- ============================================================================
-- 3. FUSTE CÓNICO POSTERIOR (REAR DRIVE SPINDLE / AGUJA DE POPA)
-- ============================================================================
-- Se dibuja en el PASO 1 (la parte más trasera de la escena, x < 0).
-- Esto garantiza que todos los pétalos se dibujen por encima de él.
local function drawRearSpindle(cx, cy, L, basis, alpha, damageState, isBroken)
    local xStart = -L * 0.05
    local xEnd   = isBroken and (-L * 0.45) or (-L * 0.72)
    local rStart = L * 0.22
    local rEnd   = isBroken and (L * 0.14) or (L * 0.06)

    local segs = 8
    local rings = {}

    for i = 0, segs do
        local frac = i / segs
        local curX = xStart + frac * (xEnd - xStart)
        local curR = rStart + frac * (rEnd - rStart)

        local pTopX, pTopY, pTopZ = projectPoint3D(cx, cy, curX, 0,  curR, basis)
        local pBotX, pBotY, pBotZ = projectPoint3D(cx, cy, curX, 0, -curR, basis)
        local pLftX, pLftY, pLftZ = projectPoint3D(cx, cy, curX, -curR, 0, basis)
        local pRgtX, pRgtY, pRgtZ = projectPoint3D(cx, cy, curX,  curR, 0, basis)
        local pDiaX, pDiaY, pDiaZ = projectPoint3D(cx, cy, curX, -curR * 0.7, curR * 0.7, basis)

        table.insert(rings, {
            top = { pTopX, pTopY, pTopZ },
            bot = { pBotX, pBotY, pBotZ },
            lft = { pLftX, pLftY, pLftZ },
            rgt = { pRgtX, pRgtY, pRgtZ },
            dia = { pDiaX, pDiaY, pDiaZ },
            x = curX, r = curR
        })
    end

    -- Superficie superior facetada iluminada
    local polyTop = {}
    for i = 1, segs + 1 do
        table.insert(polyTop, rings[i].lft[1])
        table.insert(polyTop, rings[i].lft[2])
    end
    for i = segs + 1, 1, -1 do
        table.insert(polyTop, rings[i].rgt[1])
        table.insert(polyTop, rings[i].rgt[2])
    end
    setColor(PALETTE.spindleLight, alpha * 0.98)
    love.graphics.polygon("fill", polyTop)

    -- Superficie inferior en penumbra
    local polyBot = {}
    for i = 1, segs + 1 do
        table.insert(polyBot, rings[i].lft[1])
        table.insert(polyBot, rings[i].lft[2])
    end
    for i = segs + 1, 1, -1 do
        table.insert(polyBot, rings[i].bot[1])
        table.insert(polyBot, rings[i].bot[2])
    end
    setColor(PALETTE.spindleDark, alpha * 0.98)
    love.graphics.polygon("fill", polyBot)

    -- Aleta estabilizadora dorsal
    if not isBroken then
        local finX1 = xStart - L * 0.10
        local finX2 = xEnd + L * 0.15
        local finH  = L * 0.12
        local f1X, f1Y = projectPoint3D(cx, cy, finX1, 0, rStart * 0.8, basis)
        local f2X, f2Y = projectPoint3D(cx, cy, finX1 - L * 0.08, 0, rStart * 0.8 + finH, basis)
        local f3X, f3Y = projectPoint3D(cx, cy, finX2, 0, rEnd + finH * 0.4, basis)
        local f4X, f4Y = projectPoint3D(cx, cy, finX2, 0, rEnd, basis)

        setColor(PALETTE.spindleMid, alpha * 0.95)
        love.graphics.polygon("fill", f1X, f1Y, f2X, f2Y, f3X, f3Y, f4X, f4Y)
        setColor(PALETTE.spindleLight, alpha * 0.90)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", f1X, f1Y, f2X, f2Y, f3X, f3Y, f4X, f4Y)
    end

    -- Nervaduras longitudinales de blindaje de popa
    setColor(PALETTE.spindleDeep, alpha * 0.90)
    love.graphics.setLineWidth(math.max(1.4, L * 0.006))
    for i = 1, segs do
        love.graphics.line(rings[i].top[1], rings[i].top[2], rings[i+1].top[1], rings[i+1].top[2])
        love.graphics.line(rings[i].lft[1], rings[i].lft[2], rings[i+1].lft[1], rings[i+1].lft[2])
        love.graphics.line(rings[i].dia[1], rings[i].dia[2], rings[i+1].dia[1], rings[i+1].dia[2])
    end

    -- Anillos de refuerzo estructural dorados/metálicos
    for i = 2, segs, 2 do
        local r = rings[i]
        local ringCol = (i == 2) and PALETTE.collarGoldMid or PALETTE.spindleTruss
        setColor(ringCol, alpha * 0.85)
        love.graphics.setLineWidth(math.max(1.2, L * 0.005))
        love.graphics.line(r.top[1], r.top[2], r.lft[1], r.lft[2])
        love.graphics.line(r.lft[1], r.lft[2], r.bot[1], r.bot[2])
    end

    -- Luces de hábitat y telemetría a lo largo del fuste
    if damageState ~= "ruins" then
        for i = 2, segs - 1 do
            local r = rings[i]
            local wCol = (i % 2 == 0) and PALETTE.collarWindowWarm or PALETTE.beaconCyan
            setColor(wCol, alpha * 0.92)
            love.graphics.circle("fill", r.dia[1], r.dia[2], math.max(1.4, L * 0.005))
            if i % 3 == 0 then
                setColor(PALETTE.beaconAmber, alpha * 0.88)
                love.graphics.circle("fill", r.top[1], r.top[2], math.max(1.6, L * 0.006))
            end
        end
    end

    -- Extremo de popa: antenas y tobera de propulsión
    if not isBroken then
        local tipX = xEnd
        local prongLen = L * 0.14
        local prongSpread = L * 0.055

        local prongs = {
            { y = 0, z = prongSpread },
            { y = 0, z = -prongSpread },
            { y = -prongSpread, z = 0 },
            { y =  prongSpread, z = 0 }
        }

        local tCx, tCy = projectPoint3D(cx, cy, tipX, 0, 0, basis)
        setColor(PALETTE.spindleTruss, alpha * 0.90)
        love.graphics.setLineWidth(math.max(1.4, L * 0.005))
        for _, pr in ipairs(prongs) do
            local pEx, pEy = projectPoint3D(cx, cy, tipX - prongLen, pr.y, pr.z, basis)
            love.graphics.line(tCx, tCy, pEx, pEy)
            if damageState == "operational" then
                setColor(PALETTE.beaconAmber, alpha * 0.85)
                love.graphics.circle("fill", pEx, pEy, 1.5)
                setColor(PALETTE.spindleTruss, alpha * 0.90)
            end
        end

        if damageState == "operational" then
            setColor(PALETTE.thrusterCyan, alpha * 0.90)
            love.graphics.circle("fill", tCx, tCy, math.max(3.2, L * 0.015))
            setColor(PALETTE.thrusterCore, alpha * 0.95)
            love.graphics.circle("fill", tCx, tCy, math.max(1.5, L * 0.007))
        end
    else
        local fTx, fTy = projectPoint3D(cx, cy, xEnd, -rEnd * 0.6, rEnd * 0.8, basis)
        local fBx, fBy = projectPoint3D(cx, cy, xEnd + L * 0.03, -rEnd * 0.7, -rEnd * 0.7, basis)
        local fMx, fMy = projectPoint3D(cx, cy, xEnd - L * 0.02, 0, 0, basis)

        setColor(PALETTE.charredMetal, alpha * 0.95)
        love.graphics.polygon("fill", fTx, fTy, fMx, fMy, fBx, fBy)
        setColor(PALETTE.emberGlow, alpha * 0.85)
        love.graphics.line(fTx, fTy, fBx, fBy)
    end
end

-- ============================================================================
-- 4. COLLAR MECÁNICO ACAMPANADO CENTRAL (GOLDEN / BRASS COLLAR)
-- ============================================================================
local function drawGoldenCollar(cx, cy, L, basis, alpha, damageState, isBroken)
    local colXFront = L * 0.06
    local colXBack  = -L * 0.05
    local colRFront = L * 0.27
    local colRBack  = L * 0.22

    local steps = 24
    local frontPts = {}
    local backPts  = {}

    for i = 0, steps do
        local angle = (i / steps) * math.pi * 2
        local sinA  = math.sin(angle)
        local cosA  = math.cos(angle)

        local fx, fy, fz = projectPoint3D(cx, cy, colXFront, -colRFront * sinA, colRFront * cosA, basis)
        local bx, by, bz = projectPoint3D(cx, cy, colXBack,  -colRBack * sinA,  colRBack * cosA,  basis)
        table.insert(frontPts, { fx, fy, fz })
        table.insert(backPts,  { bx, by, bz })
    end

    -- Mamparo interior de cierre mecánico con Triangle Fan sólido
    local cBx, cBy = projectPoint3D(cx, cy, colXBack, 0, 0, basis)
    setColor(PALETTE.armorDeepShadow, 1.0)
    for i = 1, steps do
        local b1 = backPts[i]
        local b2 = backPts[i+1] or backPts[1]
        love.graphics.polygon("fill", cBx, cBy, b1[1], b1[2], b2[1], b2[2])
    end

    -- Caras poligonales del collar dorado sombreadas por ángulo
    for i = 1, steps do
        local f1, f2 = frontPts[i], frontPts[i+1] or frontPts[1]
        local b1, b2 = backPts[i],  backPts[i+1] or backPts[1]
        local angle  = ((i - 0.5) / steps) * math.pi * 2

        local shade = 0.65 + 0.35 * math.cos(angle - 0.7)
        love.graphics.setColor(
            PALETTE.collarGoldMid[1] * shade,
            PALETTE.collarGoldMid[2] * shade,
            PALETTE.collarGoldMid[3] * shade,
            1.0
        )
        love.graphics.polygon("fill", f1[1], f1[2], f2[1], f2[2], b2[1], b2[2])
        love.graphics.polygon("fill", f1[1], f1[2], b2[1], b2[2], b1[1], b1[2])

        -- Bisel dorado reflectante en el labio frontal
        setColor(PALETTE.collarGoldLight, alpha * 0.90)
        love.graphics.setLineWidth(1)
        love.graphics.line(f1[1], f1[2], f2[1], f2[2])

        -- Corona de balizas e iluminación de hábitat
        if damageState ~= "ruins" and (i % 2 == 0) then
            local mx, my = (f1[1] + b1[1]) * 0.5, (f1[2] + b1[2]) * 0.5
            local wCol = (i % 4 == 0) and PALETTE.collarWindowWarm or PALETTE.beaconAmber
            setColor(wCol, alpha * 0.95)
            love.graphics.circle("fill", mx, my, math.max(1.5, L * 0.006))
        end
    end

    -- Arcos voltaicos de fallo si está dañado
    if damageState == "damaged" then
        local crackX, crackY = projectPoint3D(cx, cy, colXFront, -colRFront * 0.5, colRFront * 0.5, basis)
        setColor(PALETTE.charredMetal, alpha * 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.line(crackX - 5, crackY - 4, crackX + 5, crackY + 5)
        local flicker = 0.4 + 0.6 * math.sin(love.timer.getTime() * 22.0)
        setColor(PALETTE.electricArc, alpha * flicker)
        love.graphics.circle("fill", crackX, crackY, 2.5)
    end
end

-- ============================================================================
-- 5. NÚCLEO DEL SÚPER-CAÑÓN CENTRAL (PLASMA CORE & STAR FLARE)
-- ============================================================================
local function drawCannonCore(cx, cy, L, basis, alpha, damageState)
    local coreX = L * 0.08
    local irisOuterR = L * 0.27
    local coreR = L * 0.13

    local cX, cY, cZ = projectPoint3D(cx, cy, coreX, 0, 0, basis)

    -- Placa base del iris de titanio/grafito (Triangle fan)
    local steps = 24
    local irisPts = {}
    for i = 0, steps do
        local angle = (i / steps) * math.pi * 2
        local ipX, ipY = projectPoint3D(cx, cy, coreX, -irisOuterR * math.sin(angle), irisOuterR * math.cos(angle), basis)
        table.insert(irisPts, { ipX, ipY })
    end

    setColor(PALETTE.cannonIrisMetal, 1.0)
    for i = 1, steps do
        local p1 = irisPts[i]
        local p2 = irisPts[i+1] or irisPts[1]
        love.graphics.polygon("fill", cX, cY, p1[1], p1[2], p2[1], p2[2])
    end

    -- Ranuras y aros concéntricos mecánicos del iris
    local ringRadii = { irisOuterR * 0.85, irisOuterR * 0.68, irisOuterR * 0.52 }
    for _, rRad in ipairs(ringRadii) do
        local rPoly = {}
        for i = 0, steps do
            local angle = (i / steps) * math.pi * 2
            local rx, ry = projectPoint3D(cx, cy, coreX, -rRad * math.sin(angle), rRad * math.cos(angle), basis)
            table.insert(rPoly, rx)
            table.insert(rPoly, ry)
        end
        setColor(PALETTE.cannonIrisRing, alpha * 0.85)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", rPoly)
    end

    -- Radios mecánicos de partición del iris
    setColor(PALETTE.armorDeepShadow, alpha * 0.80)
    love.graphics.setLineWidth(1)
    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2
        local rx, ry = projectPoint3D(cx, cy, coreX, -irisOuterR * math.sin(angle), irisOuterR * math.cos(angle), basis)
        love.graphics.line(cX, cY, rx, ry)
    end

    -- Foco emisor de plasma central y destello en cruz
    local t = love.timer.getTime()

    if damageState == "operational" then
        local pulse = 0.88 + 0.12 * math.sin(t * 3.8)

        -- Halo de energía exterior difuso
        setColor(PALETTE.cannonGlowHalo, alpha * pulse)
        love.graphics.circle("fill", cX, cY, coreR * 1.8 * pulse)

        -- Corona de energía plasma rosa
        setColor(PALETTE.cannonPlasmaPink, alpha * 0.95)
        love.graphics.circle("fill", cX, cY, coreR * 0.90)

        -- Núcleo blanco caliente
        setColor(PALETTE.cannonPlasmaCore, alpha * 0.98)
        love.graphics.circle("fill", cX, cY, coreR * 0.48)

        -- Destello de Estrella en Cruz (4-Point Star Lens Flare) idéntico a X4
        local flareLen = coreR * 2.8 * pulse
        drawCrossFlare(cX, cY, flareLen, coreR * 0.32, PALETTE.cannonPlasmaCore, PALETTE.cannonPlasmaPink, alpha * pulse, math.rad(15.0))
    elseif damageState == "damaged" then
        local flicker = 0.35 + 0.65 * math.sin(t * 15.0)
        setColor(PALETTE.cannonPlasmaPink, alpha * flicker)
        love.graphics.circle("fill", cX, cY, coreR * 0.72)
        setColor(PALETTE.emberGlow, alpha * 0.85)
        love.graphics.circle("fill", cX, cY, coreR * 0.38)
        drawCrossFlare(cX, cY, coreR * 1.4, coreR * 0.22, PALETTE.cannonPlasmaCore, PALETTE.heatGlowPink, alpha * flicker, math.rad(15.0))
    else
        setColor(PALETTE.charredMetal, alpha * 0.95)
        love.graphics.circle("fill", cX, cY, coreR * 0.82)
        setColor(PALETTE.emberGlow, alpha * 0.60)
        love.graphics.circle("fill", cX, cY, coreR * 0.28)
    end
end

-- ============================================================================
-- 6. PÉTALO RADIAL INDIVIDUAL MECHA (CUCHILLA MECHA AFILADA CON PUNTA HACIA ADENTRO)
-- ============================================================================
-- 1. Curvatura estilizada de flor abierta con punta hacia adentro:
--    - Raíz en el collar (t = 0.0): r = 0.24L, x = 0.05L.
--    - Envergadura máxima abierta en el vientre (t = 0.70): r alcanza ~1.18L.
--    - Punta afilada como aguja que curva hacia adentro (t = 1.0): r se reduce a ~1.02L
--      mientras x avanza a 0.53L, rematando en un vértice afilado único (w = 0).
-- 2. Paneles radiadores térmicos (slats) 100% integrados y organizados:
--    - Construidos a partir de las secciones transversales exactas del pétalo (t = 0.10 a 0.70),
--      manteniendo perfecta alineación con la columna vertebral y bordes de blindaje.
--    - Remate de cuchilla sólida acorazada y afilada en el tercio final (t = 0.70 a 1.0).
-- 3. Pétalos traseros opacos: muestran su blindaje exterior oscuro dorsal y se dibujan
--    POR ENCIMA del cono posterior.
local function drawPetalBlade(cx, cy, L, basis, alpha, damageState, angle, petalLen, rMidMul, wMul, isDamagedPetal, hasSparkle, isBackFacing)
    local numSegs = 10

    local sc = {} -- Centros proyectados
    local sl = {} -- Borde izquierdo proyectado
    local sr = {} -- Borde derecho proyectado

    for k = 0, numSegs do
        local t = k / numSegs

        -- Longitudinal: avanza hacia proa (+X) continuamente
        local curX = L * (0.05 + 0.38 * t + 0.10 * (t * t)) * (petalLen / L)

        -- Radial: Bezier cúbico que se abre a rMaxFlare y curva HACIA ADENTRO a rTip
        local u = 1.0 - t
        local rBase     = L * 0.24
        local r1        = L * 0.85 * rMidMul * (petalLen / L)
        local rMaxFlare = L * 1.20 * rMidMul * (petalLen / L)
        local rTip      = L * 1.02 * rMidMul * (petalLen / L) -- Curvada hacia adentro respecto a rMaxFlare

        local curR = u*u*u * rBase + 3*u*u*t * r1 + 3*u*t*t * rMaxFlare + t*t*t * rTip

        -- Anchura: cuchilla afilada mecha que converge exactamente a 0 en la punta (t = 1.0)
        local curW = L * 0.075 * wMul * math.sin(t * math.pi * 0.75) * ((1.0 - t) ^ 0.70)
        if t < 0.15 then
            curW = math.max(L * 0.035 * wMul, curW)
        end
        if k == numSegs then
            curW = 0.0 -- Convergencia en vértice afilado
        end

        -- Leve curvatura tangencial de garra mecha hacia el interior
        local curAngle = angle - 0.06 * (t * t)

        local cosA = math.cos(curAngle)
        local sinA = math.sin(curAngle)

        local radY, radZ =  cosA,  sinA
        local tanY, tanZ = -sinA,  cosA

        -- Puntos 3D proyectados
        local cX, cY, cZ = projectPoint3D(cx, cy, curX, radY * curR, radZ * curR, basis)
        local lX, lY, lZ = projectPoint3D(cx, cy, curX, radY * curR - tanY * curW, radZ * curR - tanZ * curW, basis)
        local rX, rY, rZ = projectPoint3D(cx, cy, curX, radY * curR + tanY * curW, radZ * curR + tanZ * curW, basis)

        table.insert(sc, { cX, cY, cZ })
        table.insert(sl, { lX, lY, lZ })
        table.insert(sr, { rX, rY, rZ })
    end

    -- ========================================================================
    -- CONTORNO COMPLETO Y BASE DE BLINDAJE DEL PÉTALO (CUCHILLA MECHA AFILADA)
    -- ========================================================================
    local petalOutline = {}
    for k = 1, numSegs do
        table.insert(petalOutline, sl[k][1])
        table.insert(petalOutline, sl[k][2])
    end
    -- Vértice de punta afilada única
    table.insert(petalOutline, sc[numSegs + 1][1])
    table.insert(petalOutline, sc[numSegs + 1][2])
    for k = numSegs, 1, -1 do
        table.insert(petalOutline, sr[k][1])
        table.insert(petalOutline, sr[k][2])
    end

    if isBackFacing then
        -- ====================================================================
        -- CARA EXTERIOR DORSAL (Pétalos traseros opacos sobre el cono)
        -- ====================================================================
        local backColor = isDamagedPetal and PALETTE.armorDeepShadow or PALETTE.armorWineBase
        setColor(backColor, alpha * 0.98)
        love.graphics.polygon("fill", petalOutline)

        -- Borde perimetral acorazado
        setColor(PALETTE.armorCrimsonDark, alpha * 0.95)
        love.graphics.setLineWidth(math.max(1.4, L * 0.007))
        love.graphics.polygon("line", petalOutline)

        -- Quilla dorsal reflectante exterior que recorre la espina central del pétalo
        setColor(PALETTE.armorCrimsonHot, alpha * 0.85)
        love.graphics.setLineWidth(math.max(1.2, L * 0.005))
        for k = 1, numSegs do
            love.graphics.line(sc[k][1], sc[k][2], sc[k+1][1], sc[k+1][2])
        end
    else
        -- ====================================================================
        -- CARA INTERIOR CÓNCAVA (Pétalos frontales abiertos con paneles organizados)
        -- ====================================================================
        local baseColor = isDamagedPetal and PALETTE.armorDeepShadow or PALETTE.armorCrimsonMid
        setColor(baseColor, alpha * 0.98)
        love.graphics.polygon("fill", petalOutline)

        -- Bisel exterior iluminado
        setColor(PALETTE.armorCrimsonHot, alpha * 0.95)
        love.graphics.setLineWidth(math.max(1.6, L * 0.008))
        love.graphics.polygon("line", petalOutline)

        -- Reflejo especular en el borde
        setColor(PALETTE.armorHighlight, alpha * 0.65)
        love.graphics.setLineWidth(1)
        for k = 1, numSegs do
            love.graphics.line(sr[k][1], sr[k][2], sr[k+1][1], sr[k+1][2])
        end

        -- ====================================================================
        -- PANELES RADIADORES TÉRMICOS (SLATS) 100% INTEGRADOS Y ORGANIZADOS
        -- ====================================================================
        -- Ocupan desde k = 1 (t = 0.10) hasta k = 7 (t = 0.70),
        -- dejando el tramo final (k = 8 a 10) como cuchilla de blindaje sólida y afilada.
        if not isDamagedPetal then
            local slatStart = 1
            local slatEnd   = 7

            for k = slatStart, slatEnd do
                local widthFrac = 0.50 -- 50% de la anchura central, 25% de margen a cada lado

                local s1L = {
                    sc[k][1] + (sl[k][1] - sc[k][1]) * widthFrac,
                    sc[k][2] + (sl[k][2] - sc[k][2]) * widthFrac
                }
                local s1R = {
                    sc[k][1] + (sr[k][1] - sc[k][1]) * widthFrac,
                    sc[k][2] + (sr[k][2] - sc[k][2]) * widthFrac
                }
                local s2L = {
                    sc[k+1][1] + (sl[k+1][1] - sc[k+1][1]) * widthFrac,
                    sc[k+1][2] + (sl[k+1][2] - sc[k+1][2]) * widthFrac
                }
                local s2R = {
                    sc[k+1][1] + (sr[k+1][1] - sc[k+1][1]) * widthFrac,
                    sc[k+1][2] + (sr[k+1][2] - sc[k+1][2]) * widthFrac
                }

                -- Fondo del lecho térmico
                setColor(PALETTE.heatBedTrough, alpha * 0.95)
                love.graphics.polygon("fill", s1L[1], s1L[2], s1R[1], s1R[2], s2R[1], s2R[2], s2L[1], s2L[2])

                -- Lámina radiadora rosa neón de alta energía
                local heatColor = (damageState == "operational") and PALETTE.heatGlowPink or PALETTE.heatDarkMagenta
                setColor(heatColor, alpha * 0.95)
                love.graphics.polygon("fill", s1L[1], s1L[2], s1R[1], s1R[2], s2R[1], s2R[2], s2L[1], s2L[2])

                -- Filamento central blanco ardiente a lo largo de la columna vertebral
                if damageState == "operational" then
                    setColor(PALETTE.heatCoreWhite, alpha * 0.92)
                    love.graphics.setLineWidth(math.max(1, L * 0.005))
                    love.graphics.line(sc[k][1], sc[k][2], sc[k+1][1], sc[k+1][2])
                end

                -- División mecánica transversal entre paneles
                setColor(PALETTE.heatSlatRib, alpha * 0.95)
                love.graphics.setLineWidth(1)
                love.graphics.line(s1L[1], s1L[2], s1R[1], s1R[2])
            end
        else
            -- Pétalo averiado: marcas de impacto y arcos voltaicos
            local midIdx = math.floor(numSegs * 0.5)
            local midX, midY = sc[midIdx][1], sc[midIdx][2]
            setColor(PALETTE.charredMetal, alpha * 0.95)
            love.graphics.circle("fill", midX, midY, math.max(6, L * 0.030))
            local flicker = 0.3 + 0.7 * math.sin(love.timer.getTime() * 24.0)
            setColor(PALETTE.emberGlow, alpha * flicker)
            love.graphics.circle("fill", midX, midY, math.max(3, L * 0.015))
            setColor(PALETTE.electricArc, alpha * flicker)
            love.graphics.line(midX - 5, midY - 4, midX + 5, midY + 5)
        end

        -- Destello de Estrella en arista/punta (Sparkle Anime Glint como en X4)
        if hasSparkle and damageState == "operational" then
            local t = love.timer.getTime()
            local glintPulse = 0.85 + 0.15 * math.sin(t * 4.5)
            local tipPt = sc[numSegs + 1]
            drawCrossFlare(tipPt[1], tipPt[2], L * 0.10 * glintPulse, math.max(1.5, L * 0.006), PALETTE.armorRimWhite, PALETTE.heatGlowPink, alpha * glintPulse, math.rad(22.0))
        end
    end
end

-- ============================================================================
-- 7. RECREACIÓN EN RUINAS: PÉTALOS DESGAJADOS A LA DERIVA Y ESCOMBROS
-- ============================================================================
local function drawRuinsCatastrophe(cx, cy, L, basis, alpha, seed)
    local driftedPetals = {
        { dx =  L * 0.55, dy = -L * 0.40, dz =  L * 0.25, rot = math.rad(42),  scale = 0.95, angle = 0.5 },
        { dx =  L * 0.70, dy =  L * 0.32, dz = -L * 0.22, rot = math.rad(-32), scale = 0.85, angle = 2.4 },
        { dx = -L * 0.40, dy = -L * 0.45, dz =  L * 0.30, rot = math.rad(58),  scale = 0.78, angle = 4.1 }
    }

    for _, dp in ipairs(driftedPetals) do
        local dBasis = {
            pitch     = basis.pitch,
            azim      = basis.azim,
            cosP      = basis.cosP,
            sinP      = basis.sinP,
            dirFrontX = basis.dirFrontX,
            dirFrontY = basis.dirFrontY,
            dirTransX = basis.dirTransX,
            dirTransY = basis.dirTransY,
            skewX     = basis.skewX,
            skewY     = basis.skewY,
            roll      = basis.roll + dp.rot
        }

        local dCx = cx + dp.dx * basis.dirFrontX + dp.dy * basis.dirTransX
        local dCy = cy + dp.dx * basis.dirFrontY + dp.dy * basis.dirTransY

        drawPetalBlade(dCx, dCy, L * dp.scale, dBasis, alpha * 0.90, "ruins", dp.angle, L * 0.95 * dp.scale, 1.0, 1.0, true, false, false)

        local stumpX, stumpY = projectPoint3D(dCx, dCy, 0, 0, 0, dBasis)
        setColor(PALETTE.trussSteel, alpha * 0.85)
        love.graphics.line(stumpX, stumpY, stumpX - 8, stumpY + 6)
        love.graphics.line(stumpX, stumpY, stumpX + 6, stumpY - 7)
    end

    love.math.setRandomSeed(seed + 40404)
    for d = 1, 14 do
        local debX = -L * 0.45 + love.math.random() * (L * 1.5)
        local debY = (-0.5 + love.math.random()) * (L * 1.0)
        local debZ = (-0.5 + love.math.random()) * (L * 0.8)

        local dx, dy = projectPoint3D(cx, cy, debX, debY, debZ, basis)
        local debRot = (love.math.random() * math.pi * 2)

        love.graphics.push()
        love.graphics.translate(dx, dy)
        love.graphics.rotate(debRot)

        local pw = 8 + (d % 3) * 4
        local ph = 4 + (d % 2) * 3
        local dPts = {
            -pw * 0.5, -ph * 0.4,
             pw * 0.4, -ph * 0.5,
             pw * 0.5,  ph * 0.4,
            -pw * 0.35, ph * 0.5
        }
        setColor(PALETTE.armorCrimsonMid, alpha * 0.85)
        love.graphics.polygon("fill", dPts)
        setColor(PALETTE.armorCrimsonHot, alpha * 0.70)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", dPts)

        love.graphics.pop()
    end
end

-- ============================================================================
-- 8. FUNCIÓN PRINCIPAL DE RENDERIZADO DE LA FINAL WEAPON
-- ============================================================================
function StationElongatedRenderer.render(placeholder, camera, screenX, screenY, finalSize, alpha, rotation, damageState, lod)
    local seed = placeholder.seed or 70707
    damageState = damageState or "operational"
    lod = lod or 1

    -- Escala masiva y presencia colosal
    local L = finalSize * 1.95

    local basis = getProjectionBasis(placeholder, camera, rotation)
    local isBroken = (damageState == "ruins")

    -- ========================================================================
    -- PREPARACIÓN DE ENTIDADES PARA ORDENACIÓN POR PROFUNDIDAD (Z-SORTING)
    -- ========================================================================
    -- 12 pétalos radiales en 2 capas escalonadas:
    -- Capa 1: 6 pétalos principales largos
    -- Capa 2: 6 pétalos secundarios medianos en los intersticios
    local petals = {}

    local numOuter = 6
    local outerLen = L * 1.00
    for i = 1, numOuter do
        local angle = ((i - 1) / numOuter) * math.pi * 2 + math.pi * 0.10
        local isDamaged = (damageState == "damaged" and i == 2)
        local hasSparkle = (i == 4 or i == 5) -- Destello en arista lateral izquierda como en X4
        if not (isBroken and (i == 1 or i == 4)) then
            table.insert(petals, {
                layer = "outer",
                angle = angle,
                len = outerLen,
                rMid = 1.0,
                wMul = 1.0,
                isDamaged = isDamaged,
                hasSparkle = hasSparkle
            })
        end
    end

    local numInner = 6
    local innerLen = L * 0.78
    for i = 1, numInner do
        local angle = ((i - 1) / numInner) * math.pi * 2 + math.pi * (0.10 + 1.0 / numInner)
        local isDamaged = (damageState == "damaged" and i == 5)
        local hasSparkle = false
        if not (isBroken and (i == 2 or i == 5)) then
            table.insert(petals, {
                layer = "inner",
                angle = angle,
                len = innerLen,
                rMid = 0.82,
                wMul = 0.85,
                isDamaged = isDamaged,
                hasSparkle = hasSparkle
            })
        end
    end

    -- Calcular profundidad aproximada zCam del punto medio de cada pétalo
    for _, p in ipairs(petals) do
        local midR = L * 0.80 * p.rMid
        local radY = math.cos(p.angle)
        local radZ = math.sin(p.angle)
        local _, _, pZ = projectPoint3D(screenX, screenY, L * 0.25, radY * midR, radZ * midR, basis)
        p.zCam = pZ

        -- Un pétalo se clasifica como vista trasera (exterior de la flor)
        -- si su punto medio apunta hacia el fondo (zCam negativo)
        p.isBackFacing = (pZ < -L * 0.05)
    end

    -- Ordenar pétalos de atrás hacia adelante (zCam menor a mayor)
    table.sort(petals, function(a, b) return a.zCam < b.zCam end)

    -- Profundidad de referencia del collar central
    local _, _, zCollar = projectPoint3D(screenX, screenY, 0, 0, 0, basis)

    -- ========================================================================
    -- PIPELINE DE RENDERIZADO 2.5D CON JERARQUÍA DE PROFUNDIDAD CORREGIDA:
    --
    -- 1. FUSTE CÓNICO POSTERIOR:
    --    Se dibuja PRIMERO, como la base más trasera en la perspectiva del espacio.
    --
    -- 2. PÉTALOS TRASEROS OPACOS (zCam < zCollar):
    --    Se dibujan POR ENCIMA del cono, mostrando su blindaje exterior oscuro dorsal
    --    y abrazando la raíz del cono desde el frente.
    --
    -- 3. COLLAR MECÁNICO ACAMPANADO CENTRAL (Dorado):
    --    Sella la conexión entre el cono y las raíces de los pétalos.
    --
    -- 4. NÚCLEO DEL SÚPER-CAÑÓN CENTRAL (Iris de Titanio y Plasma Core con Destello en Cruz):
    --    Situado en el fondo cóncavo de la flor abierta.
    --
    -- 5. PÉTALOS FRONTALES (zCam >= zCollar):
    --    Se dibujan en primer plano, con sus puntas curvadas hacia adentro y sus
    --    paneles radiadores rosa neón 100% integrados a las nervaduras de cada pétalo.
    --
    -- 6. RECREACIÓN DE RUINAS CATASTRÓFICAS (si aplica).
    -- ========================================================================

    -- 1. Fuste cónico posterior (fondo inferior de la perspectiva)
    drawRearSpindle(screenX, screenY, L, basis, alpha, damageState, isBroken)

    -- 2. Pétalos traseros opacos (por encima del cono)
    local nextPetalIdx = 1
    while nextPetalIdx <= #petals and petals[nextPetalIdx].zCam < zCollar do
        local p = petals[nextPetalIdx]
        drawPetalBlade(screenX, screenY, L, basis, alpha, damageState, p.angle, p.len, p.rMid, p.wMul, p.isDamaged, p.hasSparkle, p.isBackFacing)
        nextPetalIdx = nextPetalIdx + 1
    end

    -- 3. Collar mecánico acampanado
    drawGoldenCollar(screenX, screenY, L, basis, alpha, damageState, isBroken)

    -- 4. Núcleo del súper-cañón central
    drawCannonCore(screenX, screenY, L, basis, alpha, damageState)

    -- 5. Pétalos frontales restantes (primer plano, por delante del collar y núcleo)
    while nextPetalIdx <= #petals do
        local p = petals[nextPetalIdx]
        drawPetalBlade(screenX, screenY, L, basis, alpha, damageState, p.angle, p.len, p.rMid, p.wMul, p.isDamaged, p.hasSparkle, p.isBackFacing)
        nextPetalIdx = nextPetalIdx + 1
    end

    -- 6. Recreación de ruinas catastróficas
    if isBroken then
        drawRuinsCatastrophe(screenX, screenY, L, basis, alpha, seed)
    end

    love.graphics.setLineWidth(1)
end

return StationElongatedRenderer
