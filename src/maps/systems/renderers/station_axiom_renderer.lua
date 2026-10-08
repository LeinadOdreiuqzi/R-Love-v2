-- src/maps/systems/renderers/station_axiom_renderer.lua
-- Renderizador Especializado de Megaestructura Espacial: Crucero Estelar Clase Axiom
-- Inspirado en la nave Axiom (WALL-E):
-- - Proa clíper aerodinámica súper-alargada con visera superior afilada, lounge panorámico y curvatura náutica hacia la quilla.
-- - Superestructura superior en cúpula escalonada abombada con múltiples cintas de ventanales habitacionales.
-- - Alerón dorsal masivo en arco envolvente que cruza el domo hacia la torre del puente de mando.
-- - Quilla ventral monumental profunda en Z negativo (-0.56L) con muelle de atraque en voladizo en forma de T.
-- - Góndolas de propulsores iónicos laterales (sponson pods) redondeadas con resplandor de plasma cian.
-- - Emblema circular rojo BNL y rotulación estilizada AXIOM en el flanco de proa.
-- - Parallax 2.5D volumétrico acentuado mediante diferencial de altura Z (+0.32L a -0.56L).
-- - Ruina realista: Casco colosal partido con sección de proa a la deriva, blackout total,
--   mamparos de titanio expuestos, celosías retorcidas y escombros de blindaje blanco en gravedad cero.

local StationAxiomRenderer = {}

-- Paleta de Materiales Axiom Sci-Fi
local PALETTE = {
    -- Blindaje exterior cerámico/titanio pulido (Axiom White / Pearl / Titanium Slate)
    hullPureWhite   = { 0.96, 0.98, 1.00 }, -- Brillo de titanio en cubiertas iluminadas
    hullWhite       = { 0.88, 0.91, 0.96 }, -- Blindaje blanco principal
    hullMid         = { 0.70, 0.76, 0.84 }, -- Paneles biselados y transiciones de luz
    hullDark        = { 0.44, 0.50, 0.60 }, -- Costados en ángulo y sombras de casco
    hullDeep        = { 0.20, 0.24, 0.33 }, -- Trincheras de servicio y hendiduras
    hullHighlight   = { 1.00, 1.00, 1.00 }, -- Aristas afiladas reflectantes

    -- Quilla ventral e infraestructura industrial (Heavy Graphite / Dark Slate)
    keelLight       = { 0.35, 0.42, 0.52 },
    keelDark        = { 0.20, 0.24, 0.32 },
    keelDeep        = { 0.10, 0.13, 0.19 }, -- Sombra profunda del vientre
    trussSteel      = { 0.38, 0.46, 0.58 }, -- Celosías internas de soporte

    -- Ventanales panorámicos y micro-luces
    windowBandDark  = { 0.06, 0.08, 0.13 }, -- Banda oscura de cristal tintado
    windowFleetCold = { 0.92, 0.96, 1.00 }, -- Micro-ventanas encendidas
    windowWarmGold  = { 1.00, 0.92, 0.70 }, -- Salones de lujo iluminados

    -- Propulsión de Plasma / Iones y Acentos de Energía
    plasmaCore      = { 0.88, 0.98, 1.00 }, -- Núcleo de tobera ultrabrillante
    plasmaCyan      = { 0.35, 0.82, 1.00 }, -- Resplandor del chorro de iones
    plasmaGlow      = { 0.20, 0.65, 0.98, 0.35 },
    beaconRed       = { 0.92, 0.20, 0.22 }, -- Baliza de babor / logo BNL
    beaconGreen     = { 0.20, 0.90, 0.48 }, -- Baliza de estribor
    beaconAmber     = { 0.98, 0.68, 0.20 }, -- Alerta de daño
    badgeWhite      = { 0.98, 0.99, 1.00 }, -- Letras / logo interior

    -- Estados de ruina y fractura (Metal quemado, bordes de impacto)
    charredMetal    = { 0.08, 0.09, 0.12 }, -- Borde de fractura seccionada
    emberGlow       = { 0.95, 0.42, 0.15 }, -- Rescoldos en conductos rotos
    scorchMark      = { 0.12, 0.14, 0.18, 0.75 }
}

local function setColor(c, alphaMul)
    alphaMul = alphaMul or 1.0
    local a = (c[4] or 1.0) * alphaMul
    love.graphics.setColor(c[1], c[2], c[3], a)
end

-- ============================================================================
-- 1. TRANSFORMADA GEOMÉTRICA 2.5D CON PROYECCIÓN ISOMÉTRICA Y PARALLAX
-- ============================================================================
local function projectPoint(cx, cy, xLocal, yLocal, zLocal, pParams)
    -- Orientación en el plano XY (rumbo de crucero de popa -X a proa +X)
    local cosR, sinR = math.cos(pParams.rot), math.sin(pParams.rot)
    local rx = xLocal * cosR - yLocal * sinR
    local ry = xLocal * sinR + yLocal * cosR

    -- Parallax de altura Z según la posición relativa de la cámara
    local zSkewX = zLocal * pParams.camSkewX
    local zSkewY = zLocal * pParams.camSkewY

    -- En perspectiva 2.5D de vista superior-lateral náutica:
    local sx = cx + rx + zSkewX
    local sy = cy - (ry * pParams.yFlatten) - (zLocal * pParams.zScale) + zSkewY

    return sx, sy
end

-- ============================================================================
-- 2. CÁLCULO DE PARÁMETROS DE CÁMARA Y PERSPECTIVA
-- ============================================================================
local function getProjectionParams(placeholder, camera, screenX, screenY, finalSize)
    local camX = (camera and camera.x) or placeholder.x
    local camY = (camera and camera.y) or placeholder.y

    local relX = (placeholder.x - camX)
    local relY = (placeholder.y - camY)

    -- Inclinación isométrica náutica semi-oblicua (~24° de elevación vertical)
    local tiltDeg = 24.0
    local tiltRad = math.rad(tiltDeg)
    local yFlatten = math.sin(tiltRad)       -- Compresión elíptica transversal (~0.40)
    local zScale = math.cos(tiltRad) * 0.95  -- Factor de proyección de altura Z (~0.87)

    -- Parallax volumétrico según distancia a la cámara
    local normX = math.max(-1.0, math.min(1.0, relX / 3000))
    local normY = math.max(-1.0, math.min(1.0, relY / 3000))

    local camSkewX = normX * 0.24
    local camSkewY = normY * 0.14 * yFlatten

    -- Rumbo náutico majestuoso horizontal: navega hacia la derecha con ligera inclinación (-5°)
    local rot = math.rad(-5.0)

    return {
        yFlatten = yFlatten,
        zScale   = zScale,
        tiltDeg  = tiltDeg,
        camSkewX = camSkewX,
        camSkewY = camSkewY,
        rot      = rot
    }
end

-- ============================================================================
-- 3. GÓNDOLAS DE PROPULSIÓN AUXILIAR (SPONSON PODS / WARP NACELLES)
-- ============================================================================
local function drawSponsonPod(cx, cy, L, pParams, alpha, damageState, isPortSide)
    local pP = pParams
    local sideSign = isPortSide and -1 or 1

    local podX    = -L * 0.25
    local podY    = sideSign * (L * 0.22)
    local podZ    = -L * 0.05
    local podLen  = L * 0.34
    local podW    = L * 0.055
    local podH    = L * 0.045

    local noseX   = podX + podLen * 0.50
    local tailX   = podX - podLen * 0.50

    local steps = 8
    local pts = {}
    for i = 0, steps do
        local angle = math.pi * 0.5 - (i / steps) * math.pi
        local lx = podX + math.cos(angle) * (podLen * 0.50)
        local ly = podY - math.sin(angle) * (podW * 0.6)
        local lz = podZ - math.sin(angle) * (podH * 0.7)
        local px, py = projectPoint(cx, cy, lx, ly, lz, pP)
        table.insert(pts, px)
        table.insert(pts, py)
    end

    local pBotTail = { projectPoint(cx, cy, tailX, podY, podZ - podH * 0.8, pP) }
    local pBotNose = { projectPoint(cx, cy, noseX * 0.9, podY, podZ - podH * 0.8, pP) }
    table.insert(pts, pBotNose[1])
    table.insert(pts, pBotNose[2])
    table.insert(pts, pBotTail[1])
    table.insert(pts, pBotTail[2])

    local fillCol = isPortSide and PALETTE.hullWhite or PALETTE.hullDark
    setColor(fillCol, alpha * 0.95)
    love.graphics.polygon("fill", pts)

    setColor(PALETTE.hullHighlight, alpha * 0.80)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", pts)

    local s1 = { projectPoint(cx, cy, noseX * 0.8, podY - podW * 0.35, podZ, pP) }
    local s2 = { projectPoint(cx, cy, tailX * 0.9, podY - podW * 0.35, podZ, pP) }
    setColor(PALETTE.hullDeep, alpha * 0.90)
    love.graphics.setLineWidth(math.max(1.5, L * 0.007))
    love.graphics.line(s1[1], s1[2], s2[1], s2[2])

    local nozPt = { projectPoint(cx, cy, tailX, podY, podZ - podH * 0.2, pP) }
    if damageState == "operational" then
        setColor(PALETTE.plasmaGlow, alpha * 0.85)
        love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(4, L * 0.024))
        setColor(PALETTE.plasmaCyan, alpha * 0.95)
        love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(2.2, L * 0.012))
        setColor(PALETTE.plasmaCore, alpha * 0.98)
        love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(1.2, L * 0.006))
    elseif damageState == "damaged" and isPortSide then
        local flicker = 0.3 + 0.5 * math.sin(love.timer.getTime() * 14.0)
        setColor(PALETTE.plasmaCyan, alpha * flicker)
        love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(2, L * 0.010))
    else
        setColor(PALETTE.keelDeep, alpha * 0.90)
        love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(2, L * 0.010))
    end
end

-- ============================================================================
-- 4. QUILLA VENTRAL MONUMENTAL Y MUELLE EN T (VENTRAL PYLON & DOCKING BOOM)
-- ============================================================================
local function drawVentralKeel(cx, cy, L, pParams, alpha, damageState, isBroken)
    local pP = pParams

    local kxFront = L * 0.12
    local kxBack  = -L * 0.26
    local halfW1  = L * 0.040
    local halfW2  = L * 0.022

    local zTop = -L * 0.09
    local zMid = -L * 0.26
    local zBot = isBroken and (-L * 0.38) or (-L * 0.56)

    local pTL = { projectPoint(cx, cy, kxFront, -halfW1, zTop, pP) }
    local pTR = { projectPoint(cx, cy, kxBack,  -halfW1, zTop, pP) }
    local pML = { projectPoint(cx, cy, kxFront * 0.7, -halfW2, zMid, pP) }
    local pMR = { projectPoint(cx, cy, kxBack * 0.7,  -halfW2, zMid, pP) }
    local pBL = { projectPoint(cx, cy, kxFront * 0.2, -halfW2 * 0.5, zBot, pP) }
    local pBR = { projectPoint(cx, cy, kxBack * 0.2,  -halfW2 * 0.5, zBot, pP) }

    setColor(PALETTE.keelDark, alpha * 0.95)
    love.graphics.polygon("fill", pTL[1], pTL[2], pTR[1], pTR[2], pMR[1], pMR[2], pML[1], pML[2])
    setColor(PALETTE.hullDark, alpha * 0.85)
    love.graphics.setLineWidth(1)
    love.graphics.line(pTL[1], pTL[2], pML[1], pML[2])
    love.graphics.line(pTR[1], pTR[2], pMR[1], pMR[2])

    setColor(PALETTE.keelDeep, alpha * 0.98)
    love.graphics.polygon("fill", pML[1], pML[2], pMR[1], pMR[2], pBR[1], pBR[2], pBL[1], pBL[2])
    setColor(PALETTE.keelLight, alpha * 0.80)
    love.graphics.line(pML[1], pML[2], pBL[1], pBL[2])
    love.graphics.line(pMR[1], pMR[2], pBR[1], pBR[2])

    -- Muelle de atraque en voladizo en forma de T
    local boomFront = L * 0.36
    local boomBack  = -L * 0.42
    local boomW     = L * 0.080
    local boomTh    = L * 0.038

    local b1 = { projectPoint(cx, cy, boomFront, -boomW, zMid, pP) }
    local b2 = { projectPoint(cx, cy, boomBack,  -boomW, zMid, pP) }
    local b3 = { projectPoint(cx, cy, boomBack,   boomW, zMid, pP) }
    local b4 = { projectPoint(cx, cy, boomFront,  boomW, zMid, pP) }

    local b1b = { projectPoint(cx, cy, boomFront, -boomW, zMid - boomTh, pP) }
    local b2b = { projectPoint(cx, cy, boomBack,  -boomW, zMid - boomTh, pP) }

    setColor(PALETTE.keelLight, alpha * 0.95)
    love.graphics.polygon("fill", b1[1], b1[2], b2[1], b2[2], b2b[1], b2b[2], b1b[1], b1b[2])

    setColor(PALETTE.keelDark, alpha * 0.90)
    love.graphics.polygon("fill", b1[1], b1[2], b2[1], b2[2], b3[1], b3[2], b4[1], b4[2])

    setColor(PALETTE.hullHighlight, alpha * 0.75)
    love.graphics.setLineWidth(1)
    love.graphics.line(b1[1], b1[2], b2[1], b2[2])
    love.graphics.line(b1b[1], b1b[2], b2b[1], b2b[2])

    for k = -2, 1 do
        local hx = k * (L * 0.13) + L * 0.02
        local hL = { projectPoint(cx, cy, hx + L * 0.035, -boomW * 0.95, zMid - boomTh * 0.5, pP) }
        local hR = { projectPoint(cx, cy, hx - L * 0.035, -boomW * 0.95, zMid - boomTh * 0.5, pP) }
        setColor(PALETTE.hullDeep, alpha * 0.95)
        love.graphics.setLineWidth(math.max(2, L * 0.008))
        love.graphics.line(hL[1], hL[2], hR[1], hR[2])
    end

    if damageState ~= "ruins" then
        local bPulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 4.0)
        local bCol = (damageState == "damaged") and PALETTE.beaconAmber or PALETTE.beaconRed
        setColor(bCol, alpha * bPulse)
        love.graphics.circle("fill", b1[1], b1[2], math.max(1.8, L * 0.006))
        love.graphics.circle("fill", b2[1], b2[2], math.max(1.8, L * 0.006))
    end

    if damageState ~= "ruins" then
        setColor(PALETTE.beaconGreen, alpha * 0.85)
        love.graphics.circle("fill", pBL[1], pBL[2], math.max(1.6, L * 0.005))
    end
end

-- ============================================================================
-- 5. PROPULSORES PRINCIPALES DE POPA (STERN ION THRUSTERS)
-- ============================================================================
local function drawSternEngines(cx, cy, L, pParams, alpha, damageState)
    local pP = pParams
    local sternX = -L * 0.90

    local engines = {
        { y = -L * 0.08, z = -L * 0.02, r = L * 0.032 },
        { y =  0,        z =  L * 0.02, r = L * 0.038 },
        { y =  L * 0.08, z = -L * 0.02, r = L * 0.032 }
    }

    for _, eng in ipairs(engines) do
        local nozPt = { projectPoint(cx, cy, sternX, eng.y, eng.z, pP) }

        if damageState == "operational" then
            setColor(PALETTE.plasmaGlow, alpha * 0.90)
            love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(6, eng.r * 1.5))
            setColor(PALETTE.plasmaCyan, alpha * 0.95)
            love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(3, eng.r * 0.7))
            setColor(PALETTE.plasmaCore, alpha * 0.98)
            love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(1.5, eng.r * 0.35))
        elseif damageState == "damaged" then
            local pA = (eng.y <= 0) and 0.80 or 0.25
            setColor(PALETTE.plasmaCyan, alpha * pA)
            love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(3, eng.r * 0.7))
        else
            setColor(PALETTE.keelDeep, alpha * 0.90)
            love.graphics.circle("fill", nozPt[1], nozPt[2], math.max(3, eng.r * 0.7))
        end
    end
end

-- ============================================================================
-- 6. CASCO PRINCIPAL Y PROA CLÍPER AXIOM
-- ============================================================================
local function drawMainHull(cx, cy, L, pParams, alpha, damageState, isSevered)
    local pP = pParams

    local sternX    = -L * 0.90
    local midX      = -L * 0.10
    local bowBaseX  = isSevered and (L * 0.08) or (L * 0.55)
    local bowChinX  = isSevered and (L * 0.08) or (L * 0.80)
    local bowVisorX = isSevered and (L * 0.08) or (L * 1.02)
    local bowProwX  = isSevered and (L * 0.08) or (L * 1.15)

    local halfWStern= L * 0.16
    local halfWMid  = L * 0.24
    local halfWBow  = L * 0.08

    local zKeel     = -L * 0.12
    local zMainDeck = L * 0.03
    local zVisor    = L * 0.06

    -- Vientre inferior
    local bellyPts = {}
    local bSteps = 6
    for i = 0, bSteps do
        local frac = i / bSteps
        local bx = bowChinX + (sternX - bowChinX) * frac
        local bw = (halfWBow + (halfWMid - halfWBow) * math.sin(frac * math.pi * 0.85)) * 0.80
        local bz = zKeel + math.sin(frac * math.pi) * 0.02 * L
        local px, py = projectPoint(cx, cy, bx, -bw, bz, pP)
        table.insert(bellyPts, px)
        table.insert(bellyPts, py)
    end
    local pStnCenter = { projectPoint(cx, cy, sternX, 0, zKeel, pP) }
    local pChinCenter = { projectPoint(cx, cy, bowChinX, 0, zKeel * 0.7, pP) }
    table.insert(bellyPts, pStnCenter[1])
    table.insert(bellyPts, pStnCenter[2])
    table.insert(bellyPts, pChinCenter[1])
    table.insert(bellyPts, pChinCenter[2])

    setColor(PALETTE.hullDark, alpha * 0.95)
    love.graphics.polygon("fill", bellyPts)

    -- Flanco lateral de babor con proa clíper
    local pProw      = { projectPoint(cx, cy, bowProwX,  0,                 zVisor, pP) }
    local pVisorPort = { projectPoint(cx, cy, bowVisorX, -halfWBow * 0.85,  zVisor * 0.85, pP) }
    local pDeckBow   = { projectPoint(cx, cy, bowBaseX,  -halfWMid * 0.90,  zMainDeck, pP) }
    local pDeckMid   = { projectPoint(cx, cy, midX,      -halfWMid,         zMainDeck, pP) }
    local pDeckStern = { projectPoint(cx, cy, sternX,    -halfWStern,       zMainDeck, pP) }
    local pBotStern  = { projectPoint(cx, cy, sternX,    -halfWStern * 0.75,zKeel, pP) }
    local pBotMid    = { projectPoint(cx, cy, midX,      -halfWMid * 0.80,  zKeel, pP) }
    local pBotBow    = { projectPoint(cx, cy, bowBaseX,  -halfWMid * 0.70,  zKeel * 0.9, pP) }
    local pChinPort  = { projectPoint(cx, cy, bowChinX,  -halfWBow * 0.65,  zKeel * 0.6, pP) }
    local pNoseCurve = { projectPoint(cx, cy, (bowProwX + bowChinX) * 0.5, -halfWBow * 0.35, -L * 0.01, pP) }

    local flankPts = {
        pProw[1], pProw[2],
        pVisorPort[1], pVisorPort[2],
        pDeckBow[1], pDeckBow[2],
        pDeckMid[1], pDeckMid[2],
        pDeckStern[1], pDeckStern[2],
        pBotStern[1], pBotStern[2],
        pBotMid[1], pBotMid[2],
        pBotBow[1], pBotBow[2],
        pChinPort[1], pChinPort[2],
        pNoseCurve[1], pNoseCurve[2]
    }

    setColor(PALETTE.hullWhite, alpha * 0.98)
    love.graphics.polygon("fill", flankPts)

    setColor(PALETTE.hullHighlight, alpha * 0.95)
    love.graphics.setLineWidth(math.max(1.8, L * 0.008))
    love.graphics.line(pProw[1], pProw[2], pVisorPort[1], pVisorPort[2])
    love.graphics.line(pVisorPort[1], pVisorPort[2], pDeckBow[1], pDeckBow[2])
    love.graphics.line(pDeckBow[1], pDeckBow[2], pDeckMid[1], pDeckMid[2])
    love.graphics.line(pDeckMid[1], pDeckMid[2], pDeckStern[1], pDeckStern[2])

    setColor(PALETTE.hullDark, alpha * 0.85)
    love.graphics.setLineWidth(1.2)
    love.graphics.line(pProw[1], pProw[2], pNoseCurve[1], pNoseCurve[2])
    love.graphics.line(pNoseCurve[1], pNoseCurve[2], pChinPort[1], pChinPort[2])
    love.graphics.line(pChinPort[1], pChinPort[2], pBotBow[1], pBotBow[2])

    -- Lounge panorámico de proa
    if not isSevered then
        local g1 = { projectPoint(cx, cy, bowProwX * 0.97, -halfWBow * 0.30, zVisor * 0.70, pP) }
        local g2 = { projectPoint(cx, cy, bowVisorX * 0.98, -halfWBow * 0.75, zMainDeck * 1.10, pP) }
        local g3 = { projectPoint(cx, cy, bowVisorX * 0.92, -halfWBow * 0.75, zMainDeck * 0.50, pP) }
        local g4 = { projectPoint(cx, cy, bowProwX * 0.93, -halfWBow * 0.30, zVisor * 0.25, pP) }

        setColor(PALETTE.windowBandDark, alpha * 0.98)
        love.graphics.polygon("fill", g1[1], g1[2], g2[1], g2[2], g3[1], g3[2], g4[1], g4[2])

        if damageState == "operational" then
            setColor(PALETTE.windowFleetCold, alpha * 0.92)
            love.graphics.setLineWidth(1)
            love.graphics.line((g1[1] + g4[1]) * 0.5, (g1[2] + g4[2]) * 0.5, (g2[1] + g3[1]) * 0.5, (g2[2] + g3[2]) * 0.5)
        end
    end

    -- Franja oscura horizontal
    local str1 = { projectPoint(cx, cy, bowVisorX * 0.90, -halfWBow * 0.75, zMainDeck * 0.65, pP) }
    local str2 = { projectPoint(cx, cy, bowChinX * 0.92,  -halfWMid * 0.78, zMainDeck * 0.45, pP) }
    local str3 = { projectPoint(cx, cy, midX * 0.8,       -halfWMid * 0.95, zMainDeck * 0.35, pP) }

    setColor(PALETTE.hullDeep, alpha * 0.95)
    love.graphics.setLineWidth(math.max(2, L * 0.009))
    love.graphics.line(str1[1], str1[2], str2[1], str2[2])
    love.graphics.line(str2[1], str2[2], str3[1], str3[2])

    -- Emblema BNL y rótulo AXIOM
    if not isSevered then
        local badgeP = { projectPoint(cx, cy, bowChinX * 0.92, -halfWMid * 0.76, zMainDeck * 0.75, pP) }
        local badgeR = math.max(4.2, L * 0.016)

        setColor(PALETTE.beaconRed, alpha * 0.95)
        love.graphics.circle("fill", badgeP[1], badgeP[2], badgeR)
        setColor(PALETTE.badgeWhite, alpha * 0.95)
        love.graphics.circle("fill", badgeP[1], badgeP[2], badgeR * 0.55)
        setColor(PALETTE.beaconRed, alpha * 0.95)
        love.graphics.circle("fill", badgeP[1], badgeP[2], badgeR * 0.30)

        local textP = { projectPoint(cx, cy, bowVisorX * 0.85, -halfWBow * 0.80, zMainDeck * 1.15, pP) }
        setColor(PALETTE.hullDeep, alpha * 0.85)
        love.graphics.setLineWidth(1.2)
        love.graphics.line(textP[1] - 8, textP[2], textP[1] + 10, textP[2])

        if damageState ~= "ruins" then
            setColor(PALETTE.beaconRed, alpha * 0.95)
            love.graphics.circle("fill", pProw[1], pProw[2], math.max(2, L * 0.007))
        end
    end

    if damageState == "damaged" then
        local scorchP = { projectPoint(cx, cy, midX * 0.4, -halfWMid * 0.85, zMainDeck * 0.2, pP) }
        setColor(PALETTE.scorchMark, alpha * 0.90)
        love.graphics.circle("fill", scorchP[1], scorchP[2], math.max(9, L * 0.040))
        setColor(PALETTE.charredMetal, alpha * 0.85)
        love.graphics.circle("fill", scorchP[1], scorchP[2], math.max(4, L * 0.016))
        local flicker = 0.5 + 0.5 * math.sin(love.timer.getTime() * 20.0)
        setColor(PALETTE.emberGlow, alpha * flicker)
        love.graphics.circle("fill", scorchP[1] - 2, scorchP[2] + 1, 1.8)
    end
end

-- ============================================================================
-- 7. SUPERESTRUCTURA ESCALONADA EN CÚPULA (TIERED HABITAT DECKS & DORSAL ARCH)
-- ============================================================================
local function drawTieredSuperstructure(cx, cy, L, pParams, alpha, damageState, isSevered)
    local pP = pParams

    local terraces = {
        { xStart = -L * 0.78, xEnd = L * 0.62, halfW = L * 0.17, z = L * 0.04, h = L * 0.045, tierIdx = 1 },
        { xStart = -L * 0.64, xEnd = L * 0.46, halfW = L * 0.13, z = L * 0.09, h = L * 0.045, tierIdx = 2 },
        { xStart = -L * 0.50, xEnd = L * 0.30, halfW = L * 0.09, z = L * 0.14, h = L * 0.040, tierIdx = 3 }
    }

    if isSevered then
        for _, t in ipairs(terraces) do
            t.xEnd = math.min(t.xEnd, L * 0.06)
        end
    end

    for _, t in ipairs(terraces) do
        local tLen = t.xEnd - t.xStart
        local zBase = t.z
        local zRoof = t.z + t.h

        local segs = 14
        local portPts = {}
        local starPts = {}

        for s = 0, segs do
            local frac = s / segs
            local curX = t.xStart + frac * tLen
            local wFactor = math.sin(frac * math.pi * 0.86)
            local curW = t.halfW * wFactor

            local ptPortTop = { projectPoint(cx, cy, curX, -curW, zRoof, pP) }
            local ptPortBot = { projectPoint(cx, cy, curX, -curW, zBase, pP) }
            local ptStarTop = { projectPoint(cx, cy, curX,  curW * 0.4, zRoof, pP) }

            table.insert(portPts, { top = ptPortTop, bot = ptPortBot })
            table.insert(starPts, ptStarTop)
        end

        for s = 1, segs do
            local p1 = portPts[s]
            local p2 = portPts[s+1]

            setColor(PALETTE.windowBandDark, alpha * 0.98)
            love.graphics.polygon("fill",
                p1.top[1], p1.top[2],
                p2.top[1], p2.top[2],
                p2.bot[1], p2.bot[2],
                p1.bot[1], p1.bot[2]
            )

            if damageState == "operational" then
                local winCol = (s % 4 == 0) and PALETTE.windowWarmGold or PALETTE.windowFleetCold
                setColor(winCol, alpha * 0.92)
                local mx1, my1 = (p1.top[1] + p1.bot[1]) * 0.5, (p1.top[2] + p1.bot[2]) * 0.5
                local mx2, my2 = (p2.top[1] + p2.bot[1]) * 0.5, (p2.top[2] + p2.bot[2]) * 0.5
                love.graphics.setLineWidth(1)
                love.graphics.line(mx1, my1, mx2, my2)
            elseif damageState == "damaged" and (s <= segs * 0.55) then
                local winCol = (s % 3 == 0) and PALETTE.beaconAmber or PALETTE.windowFleetCold
                setColor(winCol, alpha * 0.75)
                local mx1, my1 = (p1.top[1] + p1.bot[1]) * 0.5, (p1.top[2] + p1.bot[2]) * 0.5
                local mx2, my2 = (p2.top[1] + p2.bot[1]) * 0.5, (p2.top[2] + p2.bot[2]) * 0.5
                love.graphics.setLineWidth(1)
                love.graphics.line(mx1, my1, mx2, my2)
            end
        end

        local roofPoly = {}
        for s = 1, segs + 1 do
            table.insert(roofPoly, portPts[s].top[1])
            table.insert(roofPoly, portPts[s].top[2])
        end
        for s = segs + 1, 1, -1 do
            table.insert(roofPoly, starPts[s][1])
            table.insert(roofPoly, starPts[s][2])
        end

        local roofCol = (t.tierIdx == 3) and PALETTE.hullPureWhite or PALETTE.hullWhite
        setColor(roofCol, alpha * 0.96)
        love.graphics.polygon("fill", roofPoly)

        setColor(PALETTE.hullHighlight, alpha * 0.85)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", roofPoly)
    end

    -- Alerón dorsal en arco envolvente
    if not isSevered or damageState ~= "ruins" then
        local archSteps = 8
        local archFront = {}
        local archBack  = {}

        for i = 0, archSteps do
            local frac = i / archSteps
            local ax = -L * 0.12 - frac * (L * 0.24)
            local ay = -L * 0.20 + frac * (L * 0.15)
            local az = L * 0.04 + math.sin(frac * math.pi * 0.5) * (L * 0.18)

            local pF = { projectPoint(cx, cy, ax,              ay, az, pP) }
            local pB = { projectPoint(cx, cy, ax - L * 0.040, ay, az, pP) }
            table.insert(archFront, pF)
            table.insert(archBack, pB)
        end

        local archPoly = {}
        for _, pt in ipairs(archFront) do
            table.insert(archPoly, pt[1])
            table.insert(archPoly, pt[2])
        end
        for k = #archBack, 1, -1 do
            table.insert(archPoly, archBack[k][1])
            table.insert(archPoly, archBack[k][2])
        end

        setColor(PALETTE.hullPureWhite, alpha * 0.98)
        love.graphics.polygon("fill", archPoly)
        setColor(PALETTE.hullHighlight, alpha * 0.95)
        love.graphics.setLineWidth(1.2)
        love.graphics.polygon("line", archPoly)
    end

    -- Puente de mando y mástil de telecomunicaciones
    local brX = -L * 0.44
    local brZ = L * 0.18
    local brTopZ = L * 0.27

    local bBL = { projectPoint(cx, cy, brX + L * 0.04, -L * 0.035, brZ, pP) }
    local bBR = { projectPoint(cx, cy, brX - L * 0.04, -L * 0.035, brZ, pP) }
    local bTL = { projectPoint(cx, cy, brX + L * 0.02, -L * 0.025, brTopZ, pP) }
    local bTR = { projectPoint(cx, cy, brX - L * 0.05, -L * 0.025, brTopZ, pP) }

    setColor(PALETTE.hullDark, alpha * 0.98)
    love.graphics.polygon("fill", bBL[1], bBL[2], bBR[1], bBR[2], bTR[1], bTR[2], bTL[1], bTL[2])

    if damageState ~= "ruins" then
        setColor(PALETTE.plasmaCore, alpha * 0.95)
        love.graphics.setLineWidth(math.max(1.5, L * 0.007))
        love.graphics.line(bTL[1], bTL[2], bTR[1], bTR[2])
    end

    local mastTop = { projectPoint(cx, cy, brX - L * 0.035, -L * 0.02, brTopZ + L * 0.055, pP) }
    setColor(PALETTE.trussSteel, alpha * 0.92)
    love.graphics.setLineWidth(1.2)
    love.graphics.line(bTL[1], bTL[2], mastTop[1], mastTop[2])

    local tLeft  = { projectPoint(cx, cy, brX - L * 0.035, -L * 0.050, brTopZ + L * 0.055, pP) }
    local tRight = { projectPoint(cx, cy, brX - L * 0.035,  L * 0.015, brTopZ + L * 0.055, pP) }
    love.graphics.line(tLeft[1], tLeft[2], tRight[1], tRight[2])

    if damageState ~= "ruins" then
        setColor(PALETTE.beaconRed, alpha * 0.90)
        love.graphics.circle("fill", mastTop[1], mastTop[2], math.max(1.6, L * 0.006))
    end
end

-- ============================================================================
-- 8. RECREACIÓN EN RUINAS: PROA A LA DERIVA Y MAMPAROS SECCIONADOS
-- ============================================================================
local function drawRuinsCatastrophe(cx, cy, L, pParams, alpha, seed)
    local pP = pParams
    local cutX = L * 0.08

    local mTopL = { projectPoint(cx, cy, cutX, -L * 0.20, L * 0.06, pP) }
    local mTopR = { projectPoint(cx, cy, cutX,  L * 0.20, L * 0.06, pP) }
    local mBotL = { projectPoint(cx, cy, cutX, -L * 0.15, -L * 0.11, pP) }
    local mBotR = { projectPoint(cx, cy, cutX,  L * 0.15, -L * 0.11, pP) }

    setColor(PALETTE.charredMetal, alpha * 0.98)
    love.graphics.polygon("fill", mTopL[1], mTopL[2], mTopR[1], mTopR[2], mBotR[1], mBotR[2], mBotL[1], mBotL[2])

    setColor(PALETTE.hullDark, alpha * 0.95)
    love.graphics.setLineWidth(math.max(1.8, L * 0.009))
    love.graphics.polygon("line", mTopL[1], mTopL[2], mTopR[1], mTopR[2], mBotR[1], mBotR[2], mBotL[1], mBotL[2])

    setColor(PALETTE.trussSteel, alpha * 0.92)
    love.graphics.setLineWidth(math.max(1.6, L * 0.008))
    local j1 = { projectPoint(cx, cy, cutX + L * 0.045, -L * 0.06, 0, pP) }
    local j2 = { projectPoint(cx, cy, cutX + L * 0.065,  L * 0.03, -L * 0.02, pP) }
    local j3 = { projectPoint(cx, cy, cutX + L * 0.030, -L * 0.02, L * 0.02, pP) }

    love.graphics.line(mTopL[1], mTopL[2], j1[1], j1[2])
    love.graphics.line(mBotL[1], mBotL[2], j2[1], j2[2])
    love.graphics.line(j1[1], j1[2], j3[1], j3[2])
    love.graphics.line(j3[1], j3[2], j2[1], j2[2])

    setColor(PALETTE.emberGlow, alpha * 0.85)
    love.graphics.circle("fill", j1[1], j1[2], 1.5)
    love.graphics.circle("fill", j2[1], j2[2], 1.2)

    -- Proa clíper desprendida a la deriva en gravedad cero
    local driftDistX = L * 0.52
    local driftDistY = L * 0.12
    local driftRot   = math.rad(18)

    local driftParams = {
        yFlatten = pP.yFlatten,
        zScale   = pP.zScale,
        tiltDeg  = pP.tiltDeg,
        camSkewX = pP.camSkewX,
        camSkewY = pP.camSkewY,
        rot      = pP.rot + driftRot
    }

    local driftCx = cx + math.cos(pP.rot) * driftDistX - math.sin(pP.rot) * driftDistY
    local driftCy = cy + math.sin(pP.rot) * driftDistX + math.cos(pP.rot) * driftDistY

    local bowLen   = L * 0.70
    local dBowTip  = { projectPoint(driftCx, driftCy, bowLen,              0, L * 0.06, driftParams) }
    local dBowVsr  = { projectPoint(driftCx, driftCy, bowLen * 0.88, -L * 0.07, L * 0.05, driftParams) }
    local dBowChin = { projectPoint(driftCx, driftCy, bowLen * 0.55, -L * 0.08, -L * 0.06, driftParams) }
    local dBowCutT = { projectPoint(driftCx, driftCy, 0,             -L * 0.16, L * 0.04, driftParams) }
    local dBowCutB = { projectPoint(driftCx, driftCy, 0,             -L * 0.13, -L * 0.08, driftParams) }

    setColor(PALETTE.hullMid, alpha * 0.92)
    love.graphics.polygon("fill",
        dBowTip[1], dBowTip[2],
        dBowVsr[1], dBowVsr[2],
        dBowCutT[1], dBowCutT[2],
        dBowCutB[1], dBowCutB[2],
        dBowChin[1], dBowChin[2]
    )

    setColor(PALETTE.charredMetal, alpha * 0.95)
    love.graphics.setLineWidth(math.max(1.8, L * 0.009))
    love.graphics.line(dBowCutT[1], dBowCutT[2], dBowCutB[1], dBowCutB[2])

    setColor(PALETTE.hullHighlight, alpha * 0.75)
    love.graphics.setLineWidth(1)
    love.graphics.line(dBowTip[1], dBowTip[2], dBowVsr[1], dBowVsr[2])
    love.graphics.line(dBowVsr[1], dBowVsr[2], dBowCutT[1], dBowCutT[2])

    setColor(PALETTE.hullDark, alpha * 0.85)
    love.graphics.line(dBowTip[1], dBowTip[2], dBowChin[1], dBowChin[2])

    local bBadge = { projectPoint(driftCx, driftCy, bowLen * 0.60, -L * 0.09, L * 0.02, driftParams) }
    setColor(PALETTE.beaconRed, alpha * 0.70)
    love.graphics.circle("fill", bBadge[1], bBadge[2], math.max(3.5, L * 0.013))
    setColor(PALETTE.badgeWhite, alpha * 0.70)
    love.graphics.circle("fill", bBadge[1], bBadge[2], math.max(1.8, L * 0.007))

    setColor(PALETTE.trussSteel, alpha * 0.85)
    love.graphics.line(dBowCutT[1], dBowCutT[2], dBowCutT[1] - 8, dBowCutT[2] + 4)
    love.graphics.line(dBowCutB[1], dBowCutB[2], dBowCutB[1] - 6, dBowCutB[2] - 5)

    -- Escombros poligonales
    love.math.setRandomSeed(seed + 9876)
    for d = 1, 7 do
        local frac = 0.12 + d * 0.13
        local debX = cutX + frac * (driftDistX - cutX)
        local debY = -L * 0.06 + (love.math.random() - 0.5) * (L * 0.18)
        local debZ = (love.math.random() - 0.5) * (L * 0.10)

        local dx, dy = projectPoint(cx, cy, debX, debY, debZ, pP)
        local debRot = (love.math.random() * math.pi * 2)

        love.graphics.push()
        love.graphics.translate(dx, dy)
        love.graphics.rotate(debRot)

        local pw = 6 + (d % 3) * 3
        local ph = 4 + (d % 2) * 2
        local dPts = {
            -pw * 0.5, -ph * 0.4,
             pw * 0.4, -ph * 0.5,
             pw * 0.5,  ph * 0.4,
            -pw * 0.35, ph * 0.5
        }
        setColor(PALETTE.hullWhite, alpha * 0.90)
        love.graphics.polygon("fill", dPts)
        setColor(PALETTE.hullHighlight, alpha * 0.70)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", dPts)

        love.graphics.pop()
    end
end

-- ============================================================================
-- 9. FUNCIÓN PRINCIPAL DE RENDERIZADO DEL CRUCERO ESTELAR CLASE AXIOM
-- ============================================================================
function StationAxiomRenderer.render(placeholder, camera, screenX, screenY, finalSize, alpha, rotation, damageState, lod)
    local seed = placeholder.seed or 65432
    damageState = damageState or "operational"
    lod = lod or 1

    -- Eslora base del crucero (proporción súper-alargada de gran escala)
    local L = finalSize * 1.55

    local pParams = getProjectionParams(placeholder, camera, screenX, screenY, L)
    if rotation and rotation ~= 0 then
        pParams.rot = pParams.rot + rotation
    end

    local isBroken = (damageState == "ruins")

    -- ORDEN DE PROFUNDIDAD (PAINTER'S ALGORITHM):
    -- 1. Góndola de estribor (detrás del casco)
    drawSponsonPod(screenX, screenY, L, pParams, alpha, damageState, false)

    -- 2. Quilla ventral monumental en Z negativo profundo (-0.56L)
    drawVentralKeel(screenX, screenY, L, pParams, alpha, damageState, isBroken)

    -- 3. Propulsores principales de popa
    drawSternEngines(screenX, screenY, L, pParams, alpha, damageState)

    -- 4. Casco principal y proa aerodinámica clíper Axiom
    drawMainHull(screenX, screenY, L, pParams, alpha, damageState, isBroken)

    -- 5. Superestructura escalonada en terrazas, alerón en arco y puente
    drawTieredSuperstructure(screenX, screenY, L, pParams, alpha, damageState, isBroken)

    -- 6. Góndola de babor (en primer plano frente al flanco inferior)
    drawSponsonPod(screenX, screenY, L, pParams, alpha, damageState, true)

    -- 7. Catástrofe de ruinas (proa desprendida a la deriva y escombros)
    if isBroken then
        drawRuinsCatastrophe(screenX, screenY, L, pParams, alpha, seed)
    end

    love.graphics.setLineWidth(1)
end

return StationAxiomRenderer
