-- src/maps/systems/renderers/station_ring_renderer.lua
-- Renderizador Modular de Megaestructura Espacial: Estación Tipo Anillo (Toroide Sci-Fi Brutalista)
-- Implementa la técnica de visualización 2.5D por capas y proyección oblicua de los subniveles
-- con inclinación en determinados grados (tilt angle), extrusión Z volumétrica y parallax dinámico.
-- Garantiza cierre circunferencial perfecto (360° continuo) sin fracturas ni discontinuidades.

local StationRingRenderer = {}

-- Paleta de Materiales Brutalistas Sci-Fi
local PALETTE = {
    -- Metales estructurales y blindaje (Graphite / Industrial Slate / Titanium)
    hullDeep        = { 0.10, 0.12, 0.17 }, -- Grafito espacial profundo / sombras de juntas
    hullDark        = { 0.16, 0.19, 0.26 }, -- Acero estructural base
    hullMid         = { 0.25, 0.30, 0.40 }, -- Placas de blindaje principales
    hullLight       = { 0.36, 0.43, 0.55 }, -- Paneles biselados y resaltes de aleación
    hullHighlight   = { 0.52, 0.60, 0.74 }, -- Borde reflectante de titanio
    wallShade       = { 0.12, 0.15, 0.21 }, -- Pared cilíndrica exterior en sombra
    wallLight       = { 0.28, 0.34, 0.45 }, -- Pared cilíndrica iluminada por estrellas

    -- Estructuras de celosía y andamiaje (Truss & Girders)
    trussDark       = { 0.13, 0.16, 0.22 }, -- Vigas interiores de sombra
    trussSteel      = { 0.28, 0.34, 0.46 }, -- Acero de vigas de soporte cruzadas (X)
    trussLight      = { 0.42, 0.50, 0.64 }, -- Borde iluminado de celosía

    -- Acentos sobrios de instrumentación e iluminación (Sin estrobos epilépticos)
    accentCyanDark  = { 0.24, 0.42, 0.62 }, -- Ranuras de energía y conductos secundarios
    accentCyan      = { 0.45, 0.70, 0.94 }, -- Líneas de acento del anillo y núcleo auxiliar
    accentCyanBright= { 0.75, 0.90, 1.00 }, -- Núcleo de reactor y sensores astronómicos
    corridorLight   = { 0.40, 0.62, 0.88, 0.60 }, -- Luz constante de pasillos interiores
    windowColdWhite = { 0.85, 0.92, 1.00 }, -- Ventanas de observación y habitáculos (fijas)
    beaconRed       = { 0.88, 0.22, 0.22 }, -- Señalizador estático de navegación babor
    beaconGreen     = { 0.22, 0.85, 0.45 }, -- Señalizador estático de navegación estribor

    -- Estados de ruina y daño
    charredMetal    = { 0.08, 0.09, 0.12 }, -- Metal fundido / rotura catastrófica
    sparkOrange     = { 0.95, 0.55, 0.20 }  -- Conducto expuesto despresurizado
}

local function setColor(c, alphaMul)
    alphaMul = alphaMul or 1.0
    local a = (c[4] or 1.0) * alphaMul
    love.graphics.setColor(c[1], c[2], c[3], a)
end

-- ============================================================================
-- 1. TRANSFORMADA GEOMÉTRICA 2.5D UNIFICADA (TÉCNICA DE LOS SUBNIVELES)
-- ============================================================================
-- Proyecta un punto en coordenadas polares orbitales (r, angle, z) al espacio de pantalla.
-- Todos los hemisferios y el hub central comparten el mismo origen unificado (cx, cy).
-- El parallax 2.5D se aplica mediante perspectiva de altura Z (camSkewX, camSkewY),
-- garantizando que la circunferencia permanezca 100% matemática y visualmente continua
-- en todo el recorrido de 360°, sin fracturas en ningún ángulo ni posición de cámara.
local function projectPoint(cx, cy, r, angle, z, yFlatten, zScale, camSkewX, camSkewY)
    local cosA = math.cos(angle)
    local sinA = math.sin(angle)

    local rx = r * cosA
    local ry = r * sinA

    -- Desplazamiento perspectivo tridimensional según altura Z (Parallax volumétrico de subniveles)
    local zSkewX = z * (camSkewX or 0)
    local zSkewY = z * (camSkewY or 0)

    local sx = cx + rx + zSkewX
    local sy = cy + (ry * yFlatten) - (z * zScale) + zSkewY

    return sx, sy, ry
end

-- ============================================================================
-- 2. CÁLCULO DE PARALLAX Y PARÁMETROS ORBITALES 2.5D
-- ============================================================================
local function getProjectionParams(placeholder, camera, screenX, screenY, finalSize)
    local camX = (camera and camera.x) or placeholder.x
    local camY = (camera and camera.y) or placeholder.y

    local relX = (placeholder.x - camX)
    local relY = (placeholder.y - camY)

    -- Ángulo de visualización oblicuo en determinados grados (inspirado en Tau Ceti θ ≈ 38°-46°)
    local seed = placeholder.seed or 12345
    local tiltDeg = 38.0 + (seed % 5) * 2.0
    local tiltRad = math.rad(tiltDeg)
    local yFlatten = math.sin(tiltRad)      -- Factor de aplanamiento elíptico (0.62 a 0.72)
    local zScale = math.cos(tiltRad) * 0.95 -- Factor de proyección vertical de la altura Z

    -- Parallax dinámico según sobrevuelo de la cámara (Técnica de Subniveles)
    -- Se aplica proporcionalmente a la altura Z para mantener el sólido rígido unificado
    local normX = math.max(-1.0, math.min(1.0, relX / 3000))
    local normY = math.max(-1.0, math.min(1.0, relY / 3000))

    local camSkewX = normX * 0.22
    local camSkewY = normY * 0.12 * yFlatten

    return {
        yFlatten = yFlatten,
        zScale   = zScale,
        tiltDeg  = tiltDeg,
        camSkewX = camSkewX,
        camSkewY = camSkewY,
        rot      = placeholder.rotation or 0
    }
end

-- ============================================================================
-- 3. CAPA POSTERIOR (BACK HEMISPHERE: ry <= 0) - DETRÁS DEL HUB CENTRAL
-- ============================================================================
-- Cubre el arco dorsal del toroide: a ∈ [π, 2π]
-- Coincide exactamente en a = π y a = 2π (0) con el hemisferio frontal.
local function drawBackHemisphere(cx, cy, R, pParams, alpha, damageState, seed, lod)
    local yF = pParams.yFlatten
    local zS = pParams.zScale
    local skX = pParams.camSkewX
    local skY = pParams.camSkewY

    local rInner = R * 0.76
    local rOuter = R * 0.92
    local ringH  = R * 0.16
    local zTop   = ringH * 0.5
    local zBot   = -ringH * 0.5
    local hubR   = R * 0.22

    -- ─── 3.1 VIGAS Y CELOSÍAS DEL HEMISFERIO POSTERIOR (Spokes hacia el fondo) ─
    -- Vigas radiales que apuntan hacia el cuadrante dorsal (ry < 0)
    local spokeAngles = { math.rad(225), math.rad(270), math.rad(315) }
    for _, a in ipairs(spokeAngles) do
        local sx1, sy1 = projectPoint(cx, cy, hubR * 0.95, a, 0, yF, zS, skX, skY)
        local sx2, sy2 = projectPoint(cx, cy, rInner,      a, 0, yF, zS, skX, skY)

        -- Viga estructural en sombra de profundidad
        setColor(PALETTE.trussDark, alpha * 0.85)
        love.graphics.setLineWidth(math.max(2, R * 0.016))
        love.graphics.line(sx1, sy1, sx2, sy2)

        -- Borde de celosía interna
        setColor(PALETTE.trussSteel, alpha * 0.70)
        love.graphics.setLineWidth(math.max(1, R * 0.007))
        love.graphics.line(sx1, sy1 - 1, sx2, sy2 - 1)
    end

    -- ─── 3.2 PARED CILÍNDRICA INTERIOR POSTERIOR (Inner Wall de π a 2π) ──────
    -- La pared interior del arco dorsal mira hacia el observador (+Y en pantalla local)
    local segments = 32
    local rearArcPtsBottom = {}
    local rearArcPtsTop    = {}
    local rearDeckOuter    = {}

    for i = 0, segments do
        local a = math.pi + (i / segments) * math.pi
        local pBotX, pBotY = projectPoint(cx, cy, rInner, a, zBot, yF, zS, skX, skY)
        local pTopX, pTopY = projectPoint(cx, cy, rInner, a, zTop, yF, zS, skX, skY)
        local pOutX, pOutY = projectPoint(cx, cy, rOuter, a, zTop, yF, zS, skX, skY)

        table.insert(rearArcPtsBottom, { pBotX, pBotY })
        table.insert(rearArcPtsTop,    { pTopX, pTopY })
        table.insert(rearDeckOuter,    { pOutX, pOutY })
    end

    -- Sombra profunda del interior del anillo (Oclusión ambiental cósmica)
    setColor(PALETTE.hullDeep, alpha * 0.90)
    for i = 1, segments do
        local b1, b2 = rearArcPtsBottom[i], rearArcPtsBottom[i+1]
        local t1, t2 = rearArcPtsTop[i],    rearArcPtsTop[i+1]
        love.graphics.polygon("fill", b1[1], b1[2], b2[1], b2[2], t2[1], t2[2], t1[1], t1[2])
    end

    -- ─── 3.3 CARA SUPERIOR DORSAL (Habitat Roof de π a 2π) ───────────────────
    -- Visible desde el ángulo oblicuo cenital. Se sombrea gradualmente hacia el fondo
    for i = 1, segments do
        local in1, in2   = rearArcPtsTop[i], rearArcPtsTop[i+1]
        local out1, out2 = rearDeckOuter[i],  rearDeckOuter[i+1]

        local midA = math.pi + ((i - 0.5) / segments) * math.pi
        -- Sombreado suave de profundidad: en π y 2π coincide exactamente con 0.85
        local shade = 0.85 + 0.15 * math.sin(midA) -- varía entre 0.70 (fondo norte) y 0.85 (laterales)
        love.graphics.setColor(PALETTE.hullMid[1] * shade, PALETTE.hullMid[2] * shade, PALETTE.hullMid[3] * shade, alpha)
        love.graphics.polygon("fill", in1[1], in1[2], in2[1], in2[2], out2[1], out2[2], out1[1], out1[2])
    end

    -- Línea de borde biselada exterior de titanio (Dorsal)
    setColor(PALETTE.hullHighlight, alpha * 0.90)
    love.graphics.setLineWidth(math.max(1.8, R * 0.010))
    for i = 1, segments do
        love.graphics.line(rearDeckOuter[i][1], rearDeckOuter[i][2], rearDeckOuter[i+1][1], rearDeckOuter[i+1][2])
    end

    -- Línea de borde interior de titanio (Dorsal)
    setColor(PALETTE.hullLight, alpha * 0.70)
    love.graphics.setLineWidth(1.2)
    for i = 1, segments do
        love.graphics.line(rearArcPtsTop[i][1], rearArcPtsTop[i][2], rearArcPtsTop[i+1][1], rearArcPtsTop[i+1][2])
    end

    -- ─── 3.4 ARCO DE BLINDAJE EXTERIOR TRASERO (Floating Shield dorsal curvo) ──
    local rArmor = R * 1.02
    local sA1 = math.rad(235)
    local sA2 = math.rad(305)
    local segCount = 14
    local rearShieldTop = {}
    local rearShieldBot = {}

    for j = 0, segCount do
        local a = sA1 + (j / segCount) * (sA2 - sA1)
        local ptx, pty = projectPoint(cx, cy, rArmor, a, zTop + R * 0.015, yF, zS, skX, skY)
        local pbx, pby = projectPoint(cx, cy, rArmor, a, zBot - R * 0.010, yF, zS, skX, skY)
        table.insert(rearShieldTop, { ptx, pty })
        table.insert(rearShieldBot, { pbx, pby })
    end

    -- Soportes radiales dorsales (Brackets anclados al toroide)
    setColor(PALETTE.hullDark, alpha * 0.80)
    love.graphics.setLineWidth(math.max(1.8, R * 0.012))
    for _, bA in ipairs({ sA1 + math.rad(6), (sA1+sA2)*0.5, sA2 - math.rad(6) }) do
        local bk1x, bk1y = projectPoint(cx, cy, rOuter, bA, zTop, yF, zS, skX, skY)
        local bk2x, bk2y = projectPoint(cx, cy, rArmor, bA, zTop, yF, zS, skX, skY)
        love.graphics.line(bk1x, bk1y, bk2x, bk2y)
    end

    -- Placa exterior dorsal del blindaje
    setColor(PALETTE.hullDark, alpha * 0.75)
    for j = 1, segCount do
        local b1, b2 = rearShieldBot[j], rearShieldBot[j+1]
        local t1, t2 = rearShieldTop[j], rearShieldTop[j+1]
        love.graphics.polygon("fill", b1[1], b1[2], b2[1], b2[2], t2[1], t2[2], t1[1], t1[2])
    end

    -- Bisel exterior dorsal
    setColor(PALETTE.hullHighlight, alpha * 0.75)
    love.graphics.setLineWidth(math.max(1.5, R * 0.008))
    for j = 1, segCount do
        love.graphics.line(rearShieldTop[j][1], rearShieldTop[j][2], rearShieldTop[j+1][1], rearShieldTop[j+1][2])
    end
end

-- ============================================================================
-- 4. CUERPO CENTRAL (3D HUB & CYLINDRICAL CORE) - EJE PRINCIPAL
-- ============================================================================
-- Ocluye geométricamente el hemisferio posterior y se sitúa detrás del hemisferio frontal
local function drawCentralHub3D(cx, cy, R, pParams, alpha, damageState, seed, lod)
    local yF = pParams.yFlatten
    local zS = pParams.zScale
    local skX = pParams.camSkewX
    local skY = pParams.camSkewY

    local hubR = R * 0.22
    local hubH = R * 0.26
    local zBot = -hubH * 0.4
    local zTop =  hubH * 0.6

    -- 4.1 Pared cilíndrica exterior del cubo central (Extrusión Z volumétrica)
    local drumSegs = 28
    local drumBottom = {}
    local drumTop    = {}
    for i = 0, drumSegs do
        local a = (i / drumSegs) * math.pi * 2
        local bx, by = projectPoint(cx, cy, hubR, a, zBot, yF, zS, skX, skY)
        local tx, ty = projectPoint(cx, cy, hubR, a, zTop, yF, zS, skX, skY)
        table.insert(drumBottom, { bx, by })
        table.insert(drumTop,    { tx, ty })
    end

    -- Dibujar pared lateral del cilindro (sólo la mitad frontal visible: sinA > 0)
    for i = 1, drumSegs do
        local midAngle = ((i - 0.5) / drumSegs) * math.pi * 2
        local sinA = math.sin(midAngle)
        if sinA > 0 then
            local b1, b2 = drumBottom[i], drumBottom[i+1]
            local t1, t2 = drumTop[i],    drumTop[i+1]
            local shade = 0.70 + 0.30 * math.cos(midAngle - 0.4)
            love.graphics.setColor(PALETTE.wallShade[1] * shade, PALETTE.wallShade[2] * shade, PALETTE.wallShade[3] * shade, alpha)
            love.graphics.polygon("fill", b1[1], b1[2], b2[1], b2[2], t2[1], t2[2], t1[1], t1[2])

            -- Juntas verticales de placas en el cilindro
            if i % 3 == 0 then
                setColor(PALETTE.hullDeep, alpha * 0.90)
                love.graphics.setLineWidth(1)
                love.graphics.line(b1[1], b1[2], t1[1], t1[2])
            end
        end
    end

    -- 4.2 Tapa / Cúpula superior del Hub de mando (z = zTop)
    local capSegs = 28
    local capPoints = {}
    for i = 0, capSegs do
        local a = (i / capSegs) * math.pi * 2
        local x, y = projectPoint(cx, cy, hubR * 0.98, a, zTop, yF, zS, skX, skY)
        table.insert(capPoints, x)
        table.insert(capPoints, y)
    end

    setColor(PALETTE.hullDark, alpha)
    love.graphics.polygon("fill", capPoints)

    -- Bisel exterior de titanio en la cima del Hub
    setColor(PALETTE.hullHighlight, alpha * 0.92)
    love.graphics.setLineWidth(math.max(1.8, R * 0.010))
    love.graphics.polygon("line", capPoints)

    -- Anillo intermedio de acople
    local midCapPoints = {}
    for i = 0, capSegs do
        local a = (i / capSegs) * math.pi * 2
        local x, y = projectPoint(cx, cy, hubR * 0.65, a, zTop + R * 0.015, yF, zS, skX, skY)
        table.insert(midCapPoints, x)
        table.insert(midCapPoints, y)
    end
    setColor(PALETTE.hullMid, alpha)
    love.graphics.polygon("fill", midCapPoints)
    setColor(PALETTE.hullLight, alpha)
    love.graphics.setLineWidth(1.2)
    love.graphics.polygon("line", midCapPoints)

    -- Iris polar central de observación (dividido en 8 sectores angulares)
    local irisR = hubR * 0.45
    local irisPoints = {}
    for i = 0, capSegs do
        local a = (i / capSegs) * math.pi * 2
        local x, y = projectPoint(cx, cy, irisR, a, zTop + R * 0.02, yF, zS, skX, skY)
        table.insert(irisPoints, x)
        table.insert(irisPoints, y)
    end
    setColor(PALETTE.hullDeep, alpha)
    love.graphics.polygon("fill", irisPoints)

    setColor(PALETTE.hullHighlight, alpha * 0.85)
    love.graphics.setLineWidth(1)
    local cx0, cy0 = projectPoint(cx, cy, 0, 0, zTop + R * 0.02, yF, zS, skX, skY)
    for k = 0, 7 do
        local a = math.rad(k * 45)
        local ix, iy = projectPoint(cx, cy, irisR, a, zTop + R * 0.02, yF, zS, skX, skY)
        love.graphics.line(cx0, cy0, ix, iy)
    end

    -- Túnel axial zero-g en el centro
    local tunnelR = hubR * 0.20
    local tunPoints = {}
    for i = 0, capSegs do
        local a = (i / capSegs) * math.pi * 2
        local x, y = projectPoint(cx, cy, tunnelR, a, zTop + R * 0.02, yF, zS, skX, skY)
        table.insert(tunPoints, x)
        table.insert(tunPoints, y)
    end
    setColor(PALETTE.hullDark, alpha)
    love.graphics.polygon("fill", tunPoints)
    setColor(PALETTE.accentCyan, alpha * (damageState == "ruins" and 0.25 or 0.95))
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", tunPoints)
end

-- ============================================================================
-- 5. CAPA FRONTAL (FRONT HEMISPHERE: ry >= 0) - PUENTE EN 'X', ANILLO Y SHIELDS
-- ============================================================================
-- Cubre el arco frontal del toroide: a ∈ [0, π]
-- Coincide exactamente en a = 0 y a = π con el hemisferio posterior.
local function drawFrontHemisphere(cx, cy, R, pParams, alpha, damageState, seed, lod)
    local yF = pParams.yFlatten
    local zS = pParams.zScale
    local skX = pParams.camSkewX
    local skY = pParams.camSkewY

    local rInner = R * 0.76
    local rOuter = R * 0.92
    local ringH  = R * 0.16
    local zTop   = ringH * 0.5
    local zBot   = -ringH * 0.5
    local hubR   = R * 0.22

    -- ─── 5.1 PUENTE HORIZONTAL PRINCIPAL EN CELOSÍA 'X' (Main Gantry) ───────
    -- Une el Hub central con los extremos laterales este (0) y oeste (π) del anillo
    local gantryAngles = { 0, math.pi }
    for _, bridgeA in ipairs(gantryAngles) do
        local gLen = (damageState == "ruins" and bridgeA == 0) and (R * 0.44) or rInner
        local steps = 7
        local lastXTop, lastYTop, lastXBot, lastYBot

        for s = 0, steps do
            local curR = hubR + (s / steps) * (gLen - hubR)
            local xt, yt = projectPoint(cx, cy, curR, bridgeA, zTop * 0.45, yF, zS, skX, skY)
            local xb, yb = projectPoint(cx, cy, curR, bridgeA, zBot * 0.45, yF, zS, skX, skY)

            if s > 0 then
                -- Viga superior
                setColor(PALETTE.hullDark, alpha)
                love.graphics.setLineWidth(math.max(1.8, R * 0.010))
                love.graphics.line(lastXTop, lastYTop, xt, yt)
                -- Viga inferior
                love.graphics.line(lastXBot, lastYBot, xb, yb)

                -- Celosía cruzada en 'X' uniendo alturas Z
                setColor(PALETTE.trussSteel, alpha * 0.95)
                love.graphics.setLineWidth(math.max(1.2, R * 0.005))
                love.graphics.line(lastXTop, lastYTop, xb, yb)
                love.graphics.line(lastXBot, lastYBot, xt, yt)
                love.graphics.line(xt, yt, xb, yb) -- puntal vertical
            end

            lastXTop, lastYTop = xt, yt
            lastXBot, lastYBot = xb, yb
        end

        -- Pasillo interior con iluminación continua sobria
        if damageState ~= "ruins" then
            local p1x, p1y = projectPoint(cx, cy, hubR, bridgeA, 0, yF, zS, skX, skY)
            local p2x, p2y = projectPoint(cx, cy, gLen, bridgeA, 0, yF, zS, skX, skY)
            setColor(PALETTE.corridorLight, alpha)
            love.graphics.setLineWidth(math.max(1.5, R * 0.006))
            love.graphics.line(p1x, p1y, p2x, p2y)
        end
    end

    -- Columna vertical frontal hacia el primer plano (ángulo 90° = π/2)
    do
        local colA = math.pi * 0.5
        local colLen = rInner
        local c1x, c1y = projectPoint(cx, cy, hubR,   colA, zTop * 0.40, yF, zS, skX, skY)
        local c2x, c2y = projectPoint(cx, cy, colLen, colA, zTop * 0.40, yF, zS, skX, skY)
        setColor(PALETTE.hullDark, alpha)
        love.graphics.setLineWidth(math.max(2, R * 0.016))
        love.graphics.line(c1x, c1y, c2x, c2y)
        setColor(PALETTE.trussLight, alpha * 0.85)
        love.graphics.setLineWidth(1.2)
        love.graphics.line(c1x + 1, c1y, c2x + 1, c2y)
    end

    -- ─── 5.2 MÓDULO AUXILIAR / SENSOR POD EN 2.5D (Cuadrante frontal izq) ───
    do
        local podA = math.rad(142) -- Frontal inferior izquierdo en vista isométrica
        local podDist = R * 0.48
        local podRadius = R * 0.075

        -- Anclaje diagonal que lo sostiene desde el Hub
        local kx, ky = projectPoint(cx, cy, hubR * 1.05, podA, 0, yF, zS, skX, skY)
        local px, py = projectPoint(cx, cy, podDist,     podA, 0, yF, zS, skX, skY)
        setColor(PALETTE.trussSteel, alpha)
        love.graphics.setLineWidth(math.max(1.5, R * 0.007))
        love.graphics.line(kx, ky, px, py)

        -- Pod esférico presurizado con elipse inclinada
        setColor(PALETTE.hullDark, alpha)
        love.graphics.ellipse("fill", px, py, podRadius, podRadius * yF, 24)
        setColor(PALETTE.hullLight, alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.ellipse("line", px, py, podRadius, podRadius * yF, 24)

        -- Núcleo de energía / sensor óptico
        if damageState == "operational" then
            setColor(PALETTE.accentCyan, alpha * 0.90)
            love.graphics.ellipse("fill", px, py, podRadius * 0.45, podRadius * 0.45 * yF, 16)
            setColor(PALETTE.accentCyanBright, alpha * 0.95)
            love.graphics.ellipse("fill", px, py, podRadius * 0.22, podRadius * 0.22 * yF, 12)
            -- Retículo óptico
            setColor(PALETTE.windowColdWhite, alpha * 0.9)
            love.graphics.setLineWidth(1)
            love.graphics.line(px - podRadius * 0.35, py, px + podRadius * 0.35, py)
            love.graphics.line(px, py - podRadius * 0.35 * yF, px, py + podRadius * 0.35 * yF)
        else
            setColor(PALETTE.charredMetal, alpha)
            love.graphics.ellipse("fill", px, py, podRadius * 0.35, podRadius * 0.35 * yF, 12)
        end
    end

    -- ─── 5.3 ANILLO DE HÁBITAT FRONTAL: PARED VERTICAL Y CUBIERTA SUPERIOR ──
    -- Arco de 0 a π (180° frontales).
    -- En a = 0 coincide con a = 2π del arco trasero; en a = π coincide con a = π.
    local segments = 32
    local frontWallBottom = {}
    local frontWallTop    = {}
    local frontHabInner   = {}

    for i = 0, segments do
        local a = (i / segments) * math.pi
        local pbx, pby = projectPoint(cx, cy, rOuter, a, zBot, yF, zS, skX, skY)
        local ptx, pty = projectPoint(cx, cy, rOuter, a, zTop, yF, zS, skX, skY)
        local pix, piy = projectPoint(cx, cy, rInner, a, zTop, yF, zS, skX, skY)
        table.insert(frontWallBottom, { pbx, pby })
        table.insert(frontWallTop,    { ptx, pty })
        table.insert(frontHabInner,   { pix, piy })
    end

    if damageState ~= "ruins" then
        -- A. PARED CILÍNDRICA EXTERIOR VERTICAL (Front Wall)
        for i = 1, segments do
            local midA = ((i - 0.5) / segments) * math.pi
            local sinA = math.sin(midA)
            local b1, b2 = frontWallBottom[i], frontWallBottom[i+1]
            local t1, t2 = frontWallTop[i],    frontWallTop[i+1]

            -- Iluminación direccional estelar sobre la pared vertical
            local lightFactor = 0.70 + 0.30 * math.cos(midA - 0.4)
            love.graphics.setColor(PALETTE.wallLight[1] * lightFactor, PALETTE.wallLight[2] * lightFactor, PALETTE.wallLight[3] * lightFactor, alpha)
            love.graphics.polygon("fill", b1[1], b1[2], b2[1], b2[2], t2[1], t2[2], t1[1], t1[2])

            -- Juntas de paneles de blindaje modular
            if i % 2 == 0 then
                setColor(PALETTE.hullDeep, alpha * 0.85)
                love.graphics.setLineWidth(1)
                love.graphics.line(b1[1], b1[2], t1[1], t1[2])
            end
        end

        -- B. CARA SUPERIOR DEL TOROIDE (Habitat Roof)
        for i = 1, segments do
            local in1, in2   = frontHabInner[i], frontHabInner[i+1]
            local out1, out2 = frontWallTop[i],   frontWallTop[i+1]

            local midA = ((i - 0.5) / segments) * math.pi
            -- En a = 0 y a = π coincide exactamente con 0.85 del arco dorsal
            local shade = 0.85 + 0.15 * math.sin(midA) -- varía entre 0.85 (laterales) y 1.00 (frente sur)
            love.graphics.setColor(PALETTE.hullMid[1] * shade, PALETTE.hullMid[2] * shade, PALETTE.hullMid[3] * shade, alpha)
            love.graphics.polygon("fill", in1[1], in1[2], in2[1], in2[2], out2[1], out2[2], out1[1], out1[2])
        end

        -- C. BISEL DE TITANIO EN LOS BORDES (Unión continua 100% cerrada con el arco dorsal)
        setColor(PALETTE.hullHighlight, alpha * 0.95)
        love.graphics.setLineWidth(math.max(1.8, R * 0.010))
        for i = 1, segments do
            love.graphics.line(frontWallTop[i][1], frontWallTop[i][2], frontWallTop[i+1][1], frontWallTop[i+1][2])
        end
        setColor(PALETTE.hullLight, alpha * 0.70)
        love.graphics.setLineWidth(1.2)
        for i = 1, segments do
            love.graphics.line(frontHabInner[i][1], frontHabInner[i][2], frontHabInner[i+1][1], frontHabInner[i+1][2])
        end

        -- D. TIRAS DE VENTANAS DE TRIPULACIÓN EN LA CUBIERTA SUPERIOR
        local winAlpha = (damageState == "damaged") and 0.45 or 0.90
        setColor(PALETTE.windowColdWhite, alpha * winAlpha)
        love.graphics.setLineWidth(math.max(1, R * 0.005))
        for i = 1, segments - 1 do
            if i % 3 ~= 0 then
                local p1In, p1Out = frontHabInner[i],   frontWallTop[i]
                local p2In, p2Out = frontHabInner[i+1], frontWallTop[i+1]
                local wx1 = (p1In[1] + p1Out[1]) * 0.5
                local wy1 = (p1In[2] + p1Out[2]) * 0.5
                local wx2 = (p2In[1] + p2Out[1]) * 0.5
                local wy2 = (p2In[2] + p2Out[2]) * 0.5
                love.graphics.line(wx1, wy1, wx2, wy2)
            end
        end

    else
        -- ─── EN RUINAS: CASCO FRACTURADO CON ARISTAS METÁLICAS EXPUESTAS ────
        setColor(PALETTE.charredMetal, alpha)
        for i = 1, math.floor(segments * 0.42) do
            local in1, in2   = frontHabInner[i], frontHabInner[i+1]
            local out1, out2 = frontWallTop[i],   frontWallTop[i+1]
            love.graphics.polygon("fill", in1[1], in1[2], in2[1], in2[2], out2[1], out2[2], out1[1], out1[2])
        end
        for i = math.floor(segments * 0.58), segments do
            local in1, in2   = frontHabInner[i], frontHabInner[i+1]
            local out1, out2 = frontWallTop[i],   frontWallTop[i+1]
            love.graphics.polygon("fill", in1[1], in1[2], in2[1], in2[2], out2[1], out2[2], out1[1], out1[2])
        end
        -- Línea de rotura y conducto despresurizado
        setColor(PALETTE.sparkOrange, alpha * 0.85)
        love.graphics.setLineWidth(2)
        local cutI = math.floor(segments * 0.42)
        love.graphics.line(frontHabInner[cutI][1], frontHabInner[cutI][2], frontWallTop[cutI][1], frontWallTop[cutI][2])
    end

    -- ─── 5.4 ARCOS EXTERIORES DE BLINDAJE MODULAR FLOTANTES (Front Shields) ─
    local rArmor = R * 1.02
    local frontShieldArcs = {
        { startDeg = 12,  endDeg = 65,  damaged = false },
        { startDeg = 78,  endDeg = 138, damaged = false },
        { startDeg = 150, endDeg = 175, damaged = (damageState == "damaged") }
    }

    if damageState == "ruins" then
        frontShieldArcs[2].missing = true
    end

    for idx, sArc in ipairs(frontShieldArcs) do
        if not sArc.missing then
            local sA1 = math.rad(sArc.startDeg)
            local sA2 = math.rad(sArc.endDeg)
            local segCount = 12
            local sPtsTop = {}
            local sPtsBot = {}

            local curArmorR = rArmor * (sArc.damaged and 1.04 or 1.0)
            for j = 0, segCount do
                local a = sA1 + (j / segCount) * (sA2 - sA1)
                local ptx, pty = projectPoint(cx, cy, curArmorR, a, zTop + R * 0.02, yF, zS, skX, skY)
                local pbx, pby = projectPoint(cx, cy, curArmorR, a, zBot - R * 0.01, yF, zS, skX, skY)
                table.insert(sPtsTop, { ptx, pty })
                table.insert(sPtsBot, { pbx, pby })
            end

            -- Soportes radiales anclados al toroide
            setColor(PALETTE.hullDark, alpha)
            love.graphics.setLineWidth(math.max(2, R * 0.015))
            for _, bA in ipairs({ sA1 + math.rad(6), (sA1+sA2)*0.5, sA2 - math.rad(6) }) do
                local bk1x, bk1y = projectPoint(cx, cy, rOuter,    bA, zTop, yF, zS, skX, skY)
                local bk2x, bk2y = projectPoint(cx, cy, curArmorR, bA, zTop, yF, zS, skX, skY)
                love.graphics.line(bk1x, bk1y, bk2x, bk2y)
            end

            -- Pared exterior del arco de blindaje
            setColor(PALETTE.hullDark, alpha)
            for j = 1, segCount do
                local b1, b2 = sPtsBot[j], sPtsBot[j+1]
                local t1, t2 = sPtsTop[j], sPtsTop[j+1]
                love.graphics.polygon("fill", b1[1], b1[2], b2[1], b2[2], t2[1], t2[2], t1[1], t1[2])
            end

            -- Borde biselado superior de titanio
            setColor(PALETTE.hullHighlight, alpha * 0.95)
            love.graphics.setLineWidth(math.max(1.8, R * 0.010))
            for j = 1, segCount do
                love.graphics.line(sPtsTop[j][1], sPtsTop[j][2], sPtsTop[j+1][1], sPtsTop[j+1][2])
            end

            -- Ranura decorativa y señalizadores estáticos de navegación
            if not sArc.damaged and damageState ~= "ruins" then
                setColor(PALETTE.accentCyan, alpha * 0.90)
                love.graphics.setLineWidth(math.max(1, R * 0.005))
                for j = 2, segCount - 1 do
                    local m1x = (sPtsTop[j][1] + sPtsBot[j][1]) * 0.5
                    local m1y = (sPtsTop[j][2] + sPtsBot[j][2]) * 0.5
                    local m2x = (sPtsTop[j+1][1] + sPtsBot[j+1][1]) * 0.5
                    local m2y = (sPtsTop[j+1][2] + sPtsBot[j+1][2]) * 0.5
                    love.graphics.line(m1x, m1y, m2x, m2y)
                end

                local beaconColor = (idx % 2 == 0) and PALETTE.beaconGreen or PALETTE.beaconRed
                setColor(beaconColor, alpha * 0.95)
                local bRad = math.max(2, R * 0.014)
                love.graphics.circle("fill", sPtsTop[1][1], sPtsTop[1][2], bRad)
                love.graphics.circle("fill", sPtsTop[#sPtsTop][1], sPtsTop[#sPtsTop][2], bRad)
            end
        end
    end
end

-- ============================================================================
-- 6. FUNCIÓN PRINCIPAL DE RENDERIZADO
-- ============================================================================
function StationRingRenderer.render(placeholder, camera, screenX, screenY, finalSize, alpha, rotation, damageState, lod)
    local seed = placeholder.seed or 12345
    damageState = damageState or "operational"
    lod = lod or 1

    -- Calcular proyección 2.5D unificada y vectores de parallax de altura
    local pParams = getProjectionParams(placeholder, camera, screenX, screenY, finalSize)

    -- Paso 1: Hemisferio Posterior (Dorsal / Fondo: a ∈ [π, 2π], pasa detrás del Hub central)
    drawBackHemisphere(screenX, screenY, finalSize, pParams, alpha, damageState, seed, lod)

    -- Paso 2: Cubo Central 3D con Extrusión Vertical Z (Ocluye el fondo)
    drawCentralHub3D(screenX, screenY, finalSize, pParams, alpha, damageState, seed, lod)

    -- Paso 3: Hemisferio Frontal (a ∈ [0, π]: Paredes cilíndricas, puente 'X' y blindajes)
    drawFrontHemisphere(screenX, screenY, finalSize, pParams, alpha, damageState, seed, lod)

    -- Restaurar estado gráfico de grosor de línea de Love2D
    love.graphics.setLineWidth(1)
end

return StationRingRenderer
