-- src/maps/systems/renderers/station_modular_renderer.lua
-- Renderizador Modular de Megaestructura Espacial: Estación Tipo Modular (Ciudadela / El Arca)
-- Estética Brutalista Sci-Fi a escala colosal:
-- - 5 brazos radiales masivos convergentes en un único núcleo central monumental.
-- - Quilla ventral profunda (-Z) con 5 contrafuertes de titanio alineados simétricamente con los brazos.
-- - Parallax 2.5D volumétrico acentuado con diferencial de altura Z (deltaZ ~ 0.85R).
-- - Macro-ciudadelas satélites en las puntas con espolones Forerunner y micro-ventanas de habitáculo.
-- - Daño y ruina realistas: mamparos estructurales seccionados, vigas de celosía retorcidas expuestas,
--   blackout total en módulos a la deriva y fragmentos poligonales de blindaje auténticos.

local StationModularRenderer = {}

-- Paleta de Materiales Brutalistas Sci-Fi
local PALETTE = {
    -- Metales estructurales y blindaje (Graphite / Industrial Slate / Titanium)
    hullDeep        = { 0.08, 0.10, 0.14 }, -- Grafito espacial profundo / sombra de trincheras
    hullDark        = { 0.14, 0.17, 0.23 }, -- Acero estructural base / quilla
    hullMid         = { 0.23, 0.28, 0.37 }, -- Placas de blindaje principales
    hullLight       = { 0.35, 0.42, 0.53 }, -- Paneles biselados y resaltes de aleación
    hullHighlight   = { 0.52, 0.60, 0.73 }, -- Borde reflectante de titanio pulido
    wallShade       = { 0.10, 0.13, 0.18 }, -- Pared vertical en sombra de profundidad
    wallLight       = { 0.28, 0.35, 0.46 }, -- Pared vertical iluminada por luz estelar

    -- Estructuras de soporte y andamiaje interno (Truss)
    trussDark       = { 0.11, 0.14, 0.19 },
    trussSteel      = { 0.28, 0.35, 0.47 },
    trussLight      = { 0.44, 0.52, 0.65 },

    -- Energía del Reactor y Acentos (Halo del Arca / Energía de la Ciudadela)
    reactorHalo     = { 0.42, 0.74, 0.96 }, -- Anillo de energía del núcleo
    reactorHaloGlow = { 0.70, 0.88, 1.00, 0.35 }, -- Resplandor del halo
    conduitCyan     = { 0.38, 0.68, 0.94 }, -- Conductos de plasma en las trincheras
    conduitBright   = { 0.75, 0.92, 1.00 }, -- Núcleos de alta densidad
    windowFleetCold = { 0.88, 0.94, 1.00 }, -- Hileras microscópicas de ventanas
    beaconRed       = { 0.88, 0.22, 0.22 }, -- Baliza de babor
    beaconGreen     = { 0.22, 0.85, 0.45 }, -- Baliza de estribor
    beaconAmber     = { 0.95, 0.65, 0.20 }, -- Alerta de atraque

    -- Estados de ruina y fractura realista (Metal carbonizado, mamparos desgarrados)
    charredMetal    = { 0.05, 0.06, 0.08 }, -- Metal fundido / borde de fractura
    emberGlow       = { 0.88, 0.40, 0.12 }  -- Rescoldo térmico sutil en conductos rotos
}

local function setColor(c, alphaMul)
    alphaMul = alphaMul or 1.0
    local a = (c[4] or 1.0) * alphaMul
    love.graphics.setColor(c[1], c[2], c[3], a)
end

-- ============================================================================
-- 1. TRANSFORMADA GEOMÉTRICA 2.5D UNIFICADA CON PARALLAX DE ALTURA Z
-- ============================================================================
local function projectPoint(cx, cy, r, angle, z, yFlatten, zScale, camSkewX, camSkewY)
    local cosA = math.cos(angle)
    local sinA = math.sin(angle)

    local rx = r * cosA
    local ry = r * sinA

    local zSkewX = z * (camSkewX or 0)
    local zSkewY = z * (camSkewY or 0)

    local sx = cx + rx + zSkewX
    local sy = cy + (ry * yFlatten) - (z * zScale) + zSkewY

    return sx, sy, ry
end

-- ============================================================================
-- 2. CÁLCULO DE PARÁMETROS ORBITALES Y PERSPECTIVA 2.5D
-- ============================================================================
local function getProjectionParams(placeholder, camera, screenX, screenY, finalSize)
    local camX = (camera and camera.x) or placeholder.x
    local camY = (camera and camera.y) or placeholder.y

    local relX = (placeholder.x - camX)
    local relY = (placeholder.y - camY)

    local seed = placeholder.seed or 54321
    local tiltDeg = 38.0 + (seed % 5) * 2.0 -- 38° a 46° de vista isométrica
    local tiltRad = math.rad(tiltDeg)
    local yFlatten = math.sin(tiltRad)      -- Compresión elíptica vertical (~0.62 - 0.72)
    local zScale = math.cos(tiltRad) * 0.95 -- Factor de proyección vertical de la altura Z

    -- Parallax volumétrico acentuado para apreciar la monumentalidad de la quilla ventral
    local normX = math.max(-1.0, math.min(1.0, relX / 3000))
    local normY = math.max(-1.0, math.min(1.0, relY / 3000))

    local camSkewX = normX * 0.28
    local camSkewY = normY * 0.16 * yFlatten

    local armCount = 5

    return {
        yFlatten = yFlatten,
        zScale   = zScale,
        tiltDeg  = tiltDeg,
        camSkewX = camSkewX,
        camSkewY = camSkewY,
        armCount = armCount,
        rot      = placeholder.rotation or 0
    }
end

-- ============================================================================
-- 3. COMPLEJO ESCALONADO VENTRAL: SUBCUBIERTA DE HANGAR Y POZO RADIADOR TÉRMICO
-- ============================================================================
-- Sustituye el cono por una estructura monumental brutalista en capas descendentes (z < 0):
-- 1. Tambor de Subcubierta de Hangares (z: -0.08R a -0.26R, r: 0.28R): prismático, con
--    contrafuertes de soporte estructural hacia los brazos y compuertas de servicio.
-- 2. Pozo de Confinamiento del Reactor (z: -0.26R a -0.54R, r: 0.15R): cilíndrico profundo.
-- 3. Tres Anillos Radiadores Térmicos Horizontales (z = -0.34R, -0.43R, -0.51R): bridas
--    anulares concéntricas con parallax multicapa y ranuras de refrigeración.
-- 4. Plataforma Inferior Plana de Servicio (z = -0.54R): base masiva plana que se pierde
--    en la oscuridad espacial sin converger a ningún vértice o aguja.
local function drawLowerStructure(cx, cy, R, pParams, alpha, damageState, seed)
    local yF  = pParams.yFlatten
    local zS  = pParams.zScale
    local skX = pParams.camSkewX
    local skY = pParams.camSkewY

    local baseRot   = pParams.rot
    local armCount  = pParams.armCount or 5

    -- Alturas de cotas Z
    local zTop1     = -R * 0.08 -- Unión con la base del núcleo central
    local zBot1     = -R * 0.26 -- Base del tambor de subcubierta
    local rDrum1    = R * 0.28  -- Radio del tambor de subcubierta

    local zWellBot  = -R * 0.54 -- Fondo del pozo del reactor
    local rWell     = R * 0.15  -- Radio del pozo central cilíndrico

    -- ────────────────────────────────────────────────────────────────────────
    -- 3.1 POZO CENTRAL PROFUNDO DEL REACTOR (Fondo cilíndrico más distante)
    -- ────────────────────────────────────────────────────────────────────────
    local wellSegs = 14
    local wellTopPts = {}
    local wellBotPts = {}
    for i = 0, wellSegs do
        local a = baseRot + (i / wellSegs) * math.pi * 2
        local tx, ty = projectPoint(cx, cy, rWell, a, zBot1, yF, zS, skX, skY)
        local bx, by = projectPoint(cx, cy, rWell, a, zWellBot, yF, zS, skX, skY)
        table.insert(wellTopPts, { tx, ty })
        table.insert(wellBotPts, { bx, by })
    end

    for i = 1, wellSegs do
        local midA = baseRot + ((i - 0.5) / wellSegs) * math.pi * 2
        local sinA = math.sin(midA)
        if sinA > -0.20 then
            local t1, t2 = wellTopPts[i], wellTopPts[i+1]
            local b1, b2 = wellBotPts[i], wellBotPts[i+1]
            local light = 0.40 + 0.30 * math.cos(midA - 0.4)
            love.graphics.setColor(PALETTE.hullDeep[1] * light, PALETTE.hullDeep[2] * light, PALETTE.hullDeep[3] * light, alpha * 0.95)
            love.graphics.polygon("fill", t1[1], t1[2], t2[1], t2[2], b2[1], b2[2], b1[1], b1[2])
        end
    end

    -- ────────────────────────────────────────────────────────────────────────
    -- 3.2 ANILLOS RADIADORES TÉRMICOS HORIZONTALES (COOLING RADIATOR FLANGES)
    -- Tres aletas anulares concéntricas escalonadas a diferentes cotas Z.
    -- ────────────────────────────────────────────────────────────────────────
    local finConfigs = {
        { z = -R * 0.34, rOut = R * 0.24, th = R * 0.016 },
        { z = -R * 0.43, rOut = R * 0.21, th = R * 0.014 },
        { z = -R * 0.51, rOut = R * 0.18, th = R * 0.012 },
    }

    local glowAlpha = (damageState == "ruins") and 0.0 or ((damageState == "damaged") and 0.25 or 0.65)

    for fIdx, fin in ipairs(finConfigs) do
        local fZ    = fin.z
        local fTh   = fin.th
        local fROut = fin.rOut
        local segs  = 16

        local fTop = {}
        local fBot = {}
        for i = 0, segs do
            local a = baseRot + (i / segs) * math.pi * 2
            local tx, ty = projectPoint(cx, cy, fROut, a, fZ, yF, zS, skX, skY)
            local bx, by = projectPoint(cx, cy, fROut, a, fZ - fTh, yF, zS, skX, skY)
            table.insert(fTop, { tx, ty })
            table.insert(fBot, { bx, by })
        end

        -- Borde vertical cilíndrico de la aleta
        for i = 1, segs do
            local midA = baseRot + ((i - 0.5) / segs) * math.pi * 2
            local sinA = math.sin(midA)
            if sinA > -0.22 then
                local t1, t2 = fTop[i], fTop[i+1]
                local b1, b2 = fBot[i], fBot[i+1]
                local light = 0.50 + 0.35 * math.cos(midA - 0.4)
                love.graphics.setColor(PALETTE.hullDark[1] * light, PALETTE.hullDark[2] * light, PALETTE.hullDark[3] * light, alpha * 0.95)
                love.graphics.polygon("fill", t1[1], t1[2], t2[1], t2[2], b2[1], b2[2], b1[1], b1[2])
            end
        end

        -- Superficie anular de la aleta radiadora
        local diskPts = {}
        for i = 1, segs + 1 do
            table.insert(diskPts, fTop[i][1])
            table.insert(diskPts, fTop[i][2])
        end
        setColor(PALETTE.hullDark, alpha * 0.90)
        love.graphics.polygon("fill", diskPts)

        setColor(PALETTE.hullHighlight, alpha * 0.70)
        love.graphics.setLineWidth(1.2)
        love.graphics.polygon("line", diskPts)

        -- Ranura interior de resplandor térmico de refrigeración
        if glowAlpha > 0.05 then
            local glowPts = {}
            local rGlow = (fROut + rWell) * 0.5
            for i = 0, segs do
                local a = baseRot + (i / segs) * math.pi * 2
                local gx, gy = projectPoint(cx, cy, rGlow, a, fZ + R * 0.004, yF, zS, skX, skY)
                table.insert(glowPts, gx)
                table.insert(glowPts, gy)
            end
            setColor(PALETTE.reactorHaloGlow, alpha * glowAlpha * 0.5)
            love.graphics.setLineWidth(math.max(2, R * 0.008))
            love.graphics.polygon("line", glowPts)
        end
    end

    -- ────────────────────────────────────────────────────────────────────────
    -- 3.3 PLATAFORMA PLANA INFERIOR DE SERVICIO (BASE PLANA DEL POZO - CERO PUNTAS)
    -- ────────────────────────────────────────────────────────────────────────
    local basePts = {}
    for i = 1, wellSegs + 1 do
        table.insert(basePts, wellBotPts[i][1])
        table.insert(basePts, wellBotPts[i][2])
    end
    setColor(PALETTE.hullDeep, alpha * 0.95)
    love.graphics.polygon("fill", basePts)
    setColor(PALETTE.hullDark, alpha * 0.80)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", basePts)

    -- ────────────────────────────────────────────────────────────────────────
    -- 3.4 TAMBOR DE SUBCUBIERTA DE HANGAR Y BASTIÓN (NIVEL INMEDIATO: zTop1 a zBot1)
    -- ────────────────────────────────────────────────────────────────────────
    local drumSegs = 10 -- 10 facetas continuas (2 por brazo, alineadas con baseRot)
    local dTopPts = {}
    local dBotPts = {}

    for i = 0, drumSegs do
        local a = baseRot + (i / drumSegs) * math.pi * 2
        local tx, ty = projectPoint(cx, cy, rDrum1, a, zTop1, yF, zS, skX, skY)
        local bx, by = projectPoint(cx, cy, rDrum1, a, zBot1, yF, zS, skX, skY)
        table.insert(dTopPts, { tx, ty })
        table.insert(dBotPts, { bx, by })
    end

    for i = 1, drumSegs do
        local midA = baseRot + ((i - 0.5) / drumSegs) * math.pi * 2
        local sinMid = math.sin(midA)

        if sinMid > -0.25 then
            local t1, t2 = dTopPts[i], dTopPts[i+1]
            local b1, b2 = dBotPts[i], dBotPts[i+1]

            -- Iluminación direccional consistente sobre las caras prismáticas
            local light = 0.58 + 0.38 * math.cos(midA - 0.4)
            love.graphics.setColor(PALETTE.hullDark[1] * light, PALETTE.hullDark[2] * light, PALETTE.hullDark[3] * light, alpha * 0.98)
            love.graphics.polygon("fill", t1[1], t1[2], t2[1], t2[2], b2[1], b2[2], b1[1], b1[2])

            -- Aristas verticales biseladas de titanio
            setColor(PALETTE.hullHighlight, alpha * 0.85)
            love.graphics.setLineWidth(1.4)
            love.graphics.line(t1[1], t1[2], b1[1], b1[2])
            love.graphics.line(t2[1], t2[2], b2[1], b2[2])

            -- Juntas de blindaje horizontales intermedias
            local m1x = t1[1] * 0.5 + b1[1] * 0.5
            local m1y = t1[2] * 0.5 + b1[2] * 0.5
            local m2x = t2[1] * 0.5 + b2[1] * 0.5
            local m2y = t2[2] * 0.5 + b2[2] * 0.5
            setColor(PALETTE.hullDeep, alpha * 0.9)
            love.graphics.setLineWidth(1)
            love.graphics.line(m1x, m1y, m2x, m2y)

            -- Compuerta de hangar de servicio ventral en las facetas impares
            if i % 2 == 1 then
                local hTop1x = t1[1] * 0.75 + b1[1] * 0.25
                local hTop1y = t1[2] * 0.75 + b1[2] * 0.25
                local hTop2x = t2[1] * 0.75 + b2[1] * 0.25
                local hTop2y = t2[2] * 0.75 + b2[2] * 0.25

                local hBot1x = t1[1] * 0.35 + b1[1] * 0.65
                local hBot1y = t1[2] * 0.35 + b1[2] * 0.65
                local hBot2x = t2[1] * 0.35 + b2[1] * 0.65
                local hBot2y = t2[2] * 0.35 + b2[2] * 0.65

                local in1x = hTop1x * 0.8 + hTop2x * 0.2
                local in1y = hTop1y * 0.8 + hTop2y * 0.2
                local in2x = hTop1x * 0.2 + hTop2x * 0.8
                local in2y = hTop1y * 0.2 + hTop2y * 0.8

                local ib1x = hBot1x * 0.8 + hBot2x * 0.2
                local ib1y = hBot1y * 0.8 + hBot2y * 0.2
                local ib2x = hBot1x * 0.2 + hBot2x * 0.8
                local ib2y = hBot1y * 0.2 + hBot2y * 0.8

                -- Hueco del hangar en bajo relieve oscuro
                setColor(PALETTE.hullDeep, alpha * 0.95)
                love.graphics.polygon("fill", in1x, in1y, in2x, in2y, ib2x, ib2y, ib1x, ib1y)

                -- Balizas de atraque estáticas en los lados de la compuerta
                if damageState ~= "ruins" then
                    local beaconA = (damageState == "damaged") and 0.45 or 0.85
                    setColor(PALETTE.beaconAmber, alpha * beaconA)
                    love.graphics.circle("fill", in1x, in1y, math.max(1.2, R * 0.005))
                    love.graphics.circle("fill", in2x, in2y, math.max(1.2, R * 0.005))
                end
            end
        end
    end

    -- ────────────────────────────────────────────────────────────────────────
    -- 3.5 CONTRAFUERTES ESTRUCTURALES DIAGONALES (VENTRAL BUTTRESS STRUTS)
    -- Conectan la quilla de cada brazo (r = 0.42R, z = -0.06R) con la base de
    -- la subcubierta (r = 0.28R, z = -0.22R).
    -- ────────────────────────────────────────────────────────────────────────
    for i = 1, armCount do
        local armAngle = baseRot + ((i - 1) / armCount) * math.pi * 2
        local sinA = math.sin(armAngle)

        -- Dibujar los contrafuertes visibles hacia la cámara
        if sinA > -0.15 then
            local rArmK  = R * 0.42
            local zArmK  = -R * 0.06
            local rDrumK = R * 0.28
            local zDrumK = -R * 0.22

            local pArmX,  pArmY  = projectPoint(cx, cy, rArmK,  armAngle, zArmK,  yF, zS, skX, skY)
            local pDrumX, pDrumY = projectPoint(cx, cy, rDrumK, armAngle, zDrumK, yF, zS, skX, skY)

            -- Ancho transversal de la viga
            local perpA = armAngle + math.pi * 0.5
            local halfW = R * 0.022
            local cosP, sinP = math.cos(perpA) * halfW, math.sin(perpA) * halfW

            local s1x, s1y = pArmX - cosP,  pArmY - sinP * yF
            local s2x, s2y = pArmX + cosP,  pArmY + sinP * yF
            local s3x, s3y = pDrumX + cosP, pDrumY + sinP * yF
            local s4x, s4y = pDrumX - cosP, pDrumY - sinP * yF

            -- Cuerpo sólido del contrafuerte
            local strutLight = 0.65 + 0.30 * math.cos(armAngle - 0.4)
            love.graphics.setColor(PALETTE.trussSteel[1] * strutLight, PALETTE.trussSteel[2] * strutLight, PALETTE.trussSteel[3] * strutLight, alpha * 0.95)
            love.graphics.polygon("fill", s1x, s1y, s2x, s2y, s3x, s3y, s4x, s4y)

            -- Borde biselado
            setColor(PALETTE.trussLight, alpha * 0.85)
            love.graphics.setLineWidth(1.2)
            love.graphics.line(s1x, s1y, s4x, s4y)
            love.graphics.line(s2x, s2y, s3x, s3y)
        end
    end
end

-- ============================================================================
-- 4. BRAZO RADIAL INDIVIDUAL (CANTILEVER SPINE & OUTPOST CITADEL)
-- ============================================================================
local function drawModularArm(cx, cy, R, armAngle, pParams, alpha, isSevered, damageState, seed, armIdx)
    local yF  = pParams.yFlatten
    local zS  = pParams.zScale
    local skX = pParams.camSkewX
    local skY = pParams.camSkewY

    local rCoreStart = R * 0.30
    local rArmEnd    = R * 0.84
    local zTop       = R * 0.11
    local zBot       = -R * 0.07

    local halfWStart = R * 0.080
    local halfWEnd   = R * 0.135

    -- Si está cercenado en ruinas, se fractura en R * 0.52
    local currentEndR = isSevered and (R * 0.52) or rArmEnd

    local perpA = armAngle + math.pi * 0.5
    local cosP, sinP = math.cos(perpA), math.sin(perpA)

    local function getArmPylonPoint(rad, halfW, z, sideSign)
        local cosA, sinA = math.cos(armAngle), math.sin(armAngle)
        local px = rad * cosA + (halfW * sideSign) * cosP
        local py = rad * sinA + (halfW * sideSign) * sinP
        local actualR = math.sqrt(px * px + py * py)
        local actualA = math.atan2(py, px)
        return projectPoint(cx, cy, actualR, actualA, z, yF, zS, skX, skY)
    end

    local lTopStart = { getArmPylonPoint(rCoreStart, halfWStart, zTop, -1) }
    local rTopStart = { getArmPylonPoint(rCoreStart, halfWStart, zTop,  1) }
    local lTopEnd   = { getArmPylonPoint(currentEndR, halfWEnd,   zTop, -1) }
    local rTopEnd   = { getArmPylonPoint(currentEndR, halfWEnd,   zTop,  1) }

    local lBotStart = { getArmPylonPoint(rCoreStart, halfWStart, zBot, -1) }
    local rBotStart = { getArmPylonPoint(rCoreStart, halfWStart, zBot,  1) }
    local lBotEnd   = { getArmPylonPoint(currentEndR, halfWEnd,   zBot, -1) }
    local rBotEnd   = { getArmPylonPoint(currentEndR, halfWEnd,   zBot,  1) }

    -- ─── 4.1 PAREDES LATERALES VERTICALES DEL BRAZO (Extrusión Z) ───────────
    local normalLeftY = -math.cos(armAngle)
    if normalLeftY > -0.25 then
        local lightLeft = 0.70 + 0.30 * math.cos(perpA - math.pi)
        love.graphics.setColor(PALETTE.wallLight[1] * lightLeft, PALETTE.wallLight[2] * lightLeft, PALETTE.wallLight[3] * lightLeft, alpha)
        love.graphics.polygon("fill", lBotStart[1], lBotStart[2], lBotEnd[1], lBotEnd[2], lTopEnd[1], lTopEnd[2], lTopStart[1], lTopStart[2])
    end

    local normalRightY = math.cos(armAngle)
    if normalRightY > -0.25 then
        local lightRight = 0.70 + 0.30 * math.cos(perpA)
        love.graphics.setColor(PALETTE.wallShade[1] * lightRight, PALETTE.wallShade[2] * lightRight, PALETTE.wallShade[3] * lightRight, alpha)
        love.graphics.polygon("fill", rBotStart[1], rBotStart[2], rBotEnd[1], rBotEnd[2], rTopEnd[1], rTopEnd[2], rTopStart[1], rTopStart[2])
    end

    -- ─── 4.2 CUBIERTA SUPERIOR DEL BRAZO (Blindaje Escalonado y Trinchera) ──
    setColor(PALETTE.hullMid, alpha)
    love.graphics.polygon("fill", lTopStart[1], lTopStart[2], rTopStart[1], rTopStart[2], rTopEnd[1], rTopEnd[2], lTopEnd[1], lTopEnd[2])

    setColor(PALETTE.hullHighlight, alpha * 0.92)
    love.graphics.setLineWidth(math.max(1.8, R * 0.010))
    love.graphics.line(lTopStart[1], lTopStart[2], lTopEnd[1], lTopEnd[2])
    love.graphics.line(rTopStart[1], rTopStart[2], rTopEnd[1], rTopEnd[2])

    -- Trinchera central profunda de servicio
    local trenchWStart = halfWStart * 0.36
    local trenchWEnd   = halfWEnd * 0.36
    local tL1 = { getArmPylonPoint(rCoreStart, trenchWStart, zTop, -1) }
    local tR1 = { getArmPylonPoint(rCoreStart, trenchWStart, zTop,  1) }
    local tL2 = { getArmPylonPoint(currentEndR, trenchWEnd,   zTop, -1) }
    local tR2 = { getArmPylonPoint(currentEndR, trenchWEnd,   zTop,  1) }

    setColor(PALETTE.hullDeep, alpha * 0.95)
    love.graphics.polygon("fill", tL1[1], tL1[2], tR1[1], tR1[2], tR2[1], tR2[2], tL2[1], tL2[2])

    -- Conductos de energía en la trinchera
    local c1x, c1y = (tL1[1] + tR1[1]) * 0.5, (tL1[2] + tR1[2]) * 0.5
    local c2x, c2y = (tL2[1] + tR2[1]) * 0.5, (tL2[2] + tR2[2]) * 0.5
    if not isSevered and damageState ~= "ruins" then
        setColor(PALETTE.conduitCyan, alpha * 0.90)
        love.graphics.setLineWidth(math.max(1.6, R * 0.007))
        love.graphics.line(c1x, c1y, c2x, c2y)
        setColor(PALETTE.conduitBright, alpha * 0.70)
        love.graphics.setLineWidth(1)
        love.graphics.line(c1x, c1y, c2x, c2y)
    elseif isSevered then
        -- ─── BRAZO CERCENADO EN RUINAS: MAMPARO ESTRUCTURAL DE CORTE REALISTA
        -- 1. Cara transversal del mamparo sellado de titanio (sin líneas naranjas toscas)
        setColor(PALETTE.charredMetal, alpha)
        love.graphics.polygon("fill", lTopEnd[1], lTopEnd[2], rTopEnd[1], rTopEnd[2], rBotEnd[1], rBotEnd[2], lBotEnd[1], lBotEnd[2])

        -- Marco exterior de blindaje roto con rebabas de acero
        setColor(PALETTE.hullDark, alpha * 0.95)
        love.graphics.setLineWidth(math.max(1.8, R * 0.010))
        love.graphics.polygon("line", lTopEnd[1], lTopEnd[2], rTopEnd[1], rTopEnd[2], rBotEnd[1], rBotEnd[2], lBotEnd[1], lBotEnd[2])

        -- 2. Vigas internas de celosía 'X' retorcidas que sobresalen hacia el vacío
        setColor(PALETTE.trussSteel, alpha * 0.95)
        love.graphics.setLineWidth(math.max(1.6, R * 0.008))
        local jag1X, jag1Y = projectPoint(cx, cy, currentEndR + R * 0.040, armAngle - 0.045, zTop * 0.45, yF, zS, skX, skY)
        local jag2X, jag2Y = projectPoint(cx, cy, currentEndR + R * 0.055, armAngle + 0.035, zTop * 0.15, yF, zS, skX, skY)
        local jag3X, jag3Y = projectPoint(cx, cy, currentEndR + R * 0.025, armAngle,          0,           yF, zS, skX, skY)

        love.graphics.line(lTopEnd[1], lTopEnd[2], jag1X, jag1Y)
        love.graphics.line(rTopEnd[1], rTopEnd[2], jag2X, jag2Y)
        love.graphics.line(jag1X, jag1Y, jag3X, jag3Y)
        love.graphics.line(jag3X, jag3Y, jag2X, jag2Y)

        -- 3. Rescoldos térmicos sutiles en los conductos seccionados (1 px de enfriamiento)
        setColor(PALETTE.emberGlow, alpha * 0.85)
        love.graphics.circle("fill", jag3X, jag3Y, 1.5)
        love.graphics.circle("fill", (lTopEnd[1] + rTopEnd[1]) * 0.5, (lTopEnd[2] + rTopEnd[2]) * 0.5, 1.2)
    end

    -- Costillas transversales y hangares intermedios a lo largo del brazo
    local steps = 5
    for s = 1, steps - 1 do
        local frac = s / steps
        local curR = rCoreStart + frac * (currentEndR - rCoreStart)
        local curW = halfWStart + frac * (halfWEnd - halfWStart)
        local kL = { getArmPylonPoint(curR, curW, zTop, -1) }
        local kR = { getArmPylonPoint(curR, curW, zTop,  1) }

        setColor(PALETTE.hullDark, alpha * 0.85)
        love.graphics.setLineWidth(1)
        love.graphics.line(kL[1], kL[2], kR[1], kR[2])

        if s == 3 and not isSevered and damageState ~= "ruins" then
            local midX = (kL[1] + kR[1]) * 0.5
            local midY = (kL[2] + kR[2]) * 0.5
            setColor(PALETTE.beaconAmber, alpha * 0.85)
            love.graphics.circle("fill", midX - 6, midY, 1.5)
            love.graphics.circle("fill", midX + 6, midY, 1.5)
        end
    end

    -- ─── 4.3 MACRO-MÓDULO SUBSIDIARIO TERMINAL (OUTPOST CITADEL) ────────────
    local function drawTerminalModule(modCx, modCy, modRot, modScale, modAlpha, isDrifting)
        local podRadius = R * 0.185 * modScale
        local podZ      = zTop + R * 0.02

        -- Cuello de acoplamiento de tránsito presurizado
        local neckW = podRadius * 0.45
        local nL = { modCx - math.cos(modRot) * podRadius * 0.6 + cosP * neckW, modCy - math.sin(modRot) * podRadius * 0.6 * yF + sinP * neckW * yF }
        local nR = { modCx - math.cos(modRot) * podRadius * 0.6 - cosP * neckW, modCy - math.sin(modRot) * podRadius * 0.6 * yF - sinP * neckW * yF }
        setColor(PALETTE.hullDark, modAlpha)
        love.graphics.setLineWidth(math.max(2, R * 0.012))
        love.graphics.line(nL[1], nL[2], nR[1], nR[2])

        -- Plataforma base facetada
        local segs = 8
        local basePts = {}
        for k = 0, segs - 1 do
            local ba = modRot + (k / segs) * math.pi * 2
            local bx = modCx + math.cos(ba) * podRadius
            local by = modCy + math.sin(ba) * podRadius * yF
            table.insert(basePts, bx)
            table.insert(basePts, by)
        end

        setColor(isDrifting and PALETTE.charredMetal or PALETTE.hullDark, modAlpha)
        love.graphics.polygon("fill", basePts)
        setColor(PALETTE.hullHighlight, modAlpha * 0.95)
        love.graphics.setLineWidth(math.max(1.8, R * 0.010))
        love.graphics.polygon("line", basePts)

        -- Espolones de blindaje bífidos Forerunner
        local prongLen = podRadius * 1.60
        for _, side in ipairs({ -1, 1 }) do
            local prongA = modRot + side * math.rad(26)
            local p1x = modCx + math.cos(modRot + side * math.rad(52)) * podRadius * 0.92
            local p1y = modCy + math.sin(modRot + side * math.rad(52)) * podRadius * 0.92 * yF
            local p2x = modCx + math.cos(prongA) * prongLen
            local p2y = modCy + math.sin(prongA) * prongLen * yF
            local p3x = modCx + math.cos(prongA + side * math.rad(7)) * (prongLen * 0.88)
            local p3y = modCy + math.sin(prongA + side * math.rad(7)) * (prongLen * 0.88) * yF

            setColor(isDrifting and PALETTE.charredMetal or PALETTE.hullMid, modAlpha)
            love.graphics.polygon("fill", p1x, p1y, p2x, p2y, p3x, p3y)
            setColor(PALETTE.hullHighlight, modAlpha * 0.88)
            love.graphics.setLineWidth(1.2)
            love.graphics.line(p1x, p1y, p2x, p2y, p3x, p3y)

            if not isDrifting and damageState ~= "ruins" then
                local bColor = (side == -1) and PALETTE.beaconRed or PALETTE.beaconGreen
                setColor(bColor, modAlpha * 0.95)
                love.graphics.circle("fill", p2x, p2y, math.max(2.2, R * 0.013))
            end
        end

        -- Anillo interior de habitáculos
        local innerHabR = podRadius * 0.68
        local habPts = {}
        for k = 0, segs - 1 do
            local ba = modRot + (k / segs) * math.pi * 2
            local bx = modCx + math.cos(ba) * innerHabR
            local by = modCy + math.sin(ba) * innerHabR * yF
            table.insert(habPts, bx)
            table.insert(habPts, by)
        end
        setColor(PALETTE.hullDeep, modAlpha)
        love.graphics.polygon("fill", habPts)
        setColor(PALETTE.hullLight, modAlpha * 0.80)
        love.graphics.setLineWidth(1.2)
        love.graphics.polygon("line", habPts)

        -- Micro-ventanas: encendidas solo en estado operativo
        if not isDrifting and damageState == "operational" then
            setColor(PALETTE.windowFleetCold, modAlpha * 0.88)
            for w = 0, 11 do
                local wa = modRot + (w / 12) * math.pi * 2
                local wx = modCx + math.cos(wa) * (innerHabR * 0.82)
                local wy = modCy + math.sin(wa) * (innerHabR * 0.82) * yF
                love.graphics.circle("fill", wx, wy, 1.2)
            end
        elseif isDrifting then
            -- Módulo a la deriva: Blackout total (ventanas apagadas en grafito frío)
            setColor(PALETTE.hullDeep, modAlpha * 0.9)
            for w = 0, 11 do
                local wa = modRot + (w / 12) * math.pi * 2
                local wx = modCx + math.cos(wa) * (innerHabR * 0.82)
                local wy = modCy + math.sin(wa) * (innerHabR * 0.82) * yF
                love.graphics.circle("fill", wx, wy, 0.8)
            end
        end

        -- Cúpula central
        local domeR = innerHabR * 0.44
        setColor(isDrifting and PALETTE.hullDark or PALETTE.hullMid, modAlpha)
        love.graphics.ellipse("fill", modCx, modCy, domeR, domeR * yF, 16)
        if not isDrifting then
            setColor(PALETTE.reactorHalo, modAlpha * 0.85)
            love.graphics.setLineWidth(1.4)
            love.graphics.ellipse("line", modCx, modCy, domeR, domeR * yF, 16)
        else
            -- Cúpula apagada con cicatriz de impacto
            setColor(PALETTE.hullLight, modAlpha * 0.45)
            love.graphics.setLineWidth(1)
            love.graphics.ellipse("line", modCx, modCy, domeR, domeR * yF, 16)
        end

        -- Cicatriz del cuello de fractura desgarrado (coincide con el muñón del brazo)
        if isDrifting then
            local neckX = modCx - math.cos(modRot) * podRadius * 0.92
            local neckY = modCy - math.sin(modRot) * podRadius * 0.92 * yF
            -- Mamparo rasgado en titanio carbonizado
            setColor(PALETTE.charredMetal, modAlpha)
            love.graphics.circle("fill", neckX, neckY, podRadius * 0.32)
            setColor(PALETTE.trussSteel, modAlpha * 0.9)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(neckX - 7, neckY - 3, neckX + 2, neckY + 4)
            love.graphics.line(neckX - 2, neckY - 4, neckX + 6, neckY + 2)
        end
    end

    if not isSevered then
        local tipCx, tipCy = projectPoint(cx, cy, rArmEnd + R * 0.05, armAngle, zTop, yF, zS, skX, skY)
        drawTerminalModule(tipCx, tipCy, armAngle, 1.0, alpha, false)
    else
        -- ─── EN RUINAS: MACRO-MÓDULO COLOSAL SEPARADO A LA DERIVA ───────────
        local driftDist = rArmEnd + R * 0.28
        local driftAngle = armAngle + math.rad(14)
        local driftCx, driftCy = projectPoint(cx, cy, driftDist, driftAngle, zTop - R * 0.05, yF, zS, skX, skY)
        drawTerminalModule(driftCx, driftCy, armAngle + math.rad(28), 0.95, alpha * 0.92, true)

        -- Escombros de blindaje poligonales auténticos flotando entre el muñón y la ciudadela
        love.math.setRandomSeed(seed + armIdx * 123)
        for d = 1, 5 do
            local frac = 0.18 + d * 0.15
            local debR = currentEndR + frac * (driftDist - currentEndR)
            local debA = armAngle + (love.math.random() - 0.5) * 0.14
            local dx, dy = projectPoint(cx, cy, debR, debA, zTop - R * 0.02, yF, zS, skX, skY)
            local debRot = (love.math.random() * math.pi * 2)

            -- Fragmento trapezoidal de placa de blindaje biselada
            love.graphics.push()
            love.graphics.translate(dx, dy)
            love.graphics.rotate(debRot)

            local pw, ph = 6 + (d % 3) * 3, 4 + (d % 2) * 2
            local dPts = {
                -pw * 0.5, -ph * 0.4,
                 pw * 0.4, -ph * 0.5,
                 pw * 0.5,  ph * 0.4,
                -pw * 0.35, ph * 0.5
            }
            setColor(PALETTE.hullDark, alpha * 0.90)
            love.graphics.polygon("fill", dPts)
            setColor(PALETTE.hullHighlight, alpha * 0.75)
            love.graphics.setLineWidth(1)
            love.graphics.polygon("line", dPts)

            love.graphics.pop()
        end
    end
end

-- ============================================================================
-- 5. NÚCLEO CENTRAL MASIVO (CENTRAL CITADEL CORE & REACTOR HALO)
-- ============================================================================
local function drawCentralCitadelCore(cx, cy, R, pParams, alpha, damageState, seed, lod)
    local yF  = pParams.yFlatten
    local zS  = pParams.zScale
    local skX = pParams.camSkewX
    local skY = pParams.camSkewY

    local coreR = R * 0.30
    local zTop  = R * 0.13
    local zBot  = -R * 0.08

    -- 5.1 Pared cilíndrica exterior del núcleo (Extrusión Z volumétrica)
    local segs = 20 -- 20 segmentos: coincide exactamente con los 5 sectores y el cono inferior
    local drumBottom = {}
    local drumTop    = {}
    for i = 0, segs do
        local a = (i / segs) * math.pi * 2
        local bx, by = projectPoint(cx, cy, coreR, a, zBot, yF, zS, skX, skY)
        local tx, ty = projectPoint(cx, cy, coreR, a, zTop, yF, zS, skX, skY)
        table.insert(drumBottom, { bx, by })
        table.insert(drumTop,    { tx, ty })
    end

    for i = 1, segs do
        local midA = ((i - 0.5) / segs) * math.pi * 2
        local sinA = math.sin(midA)
        if sinA > -0.15 then
            local b1, b2 = drumBottom[i], drumBottom[i+1]
            local t1, t2 = drumTop[i],    drumTop[i+1]
            local shade = 0.70 + 0.30 * math.cos(midA - 0.4)
            love.graphics.setColor(PALETTE.wallShade[1] * shade, PALETTE.wallShade[2] * shade, PALETTE.wallShade[3] * shade, alpha)
            love.graphics.polygon("fill", b1[1], b1[2], b2[1], b2[2], t2[1], t2[2], t1[1], t1[2])

            -- Juntas de blindaje vertical del tambor alineadas con los contrafuertes
            setColor(PALETTE.hullDeep, alpha * 0.90)
            love.graphics.setLineWidth(1)
            love.graphics.line(b1[1], b1[2], t1[1], t1[2])
        end
    end

    -- 5.2 Plataforma superior monumental del Núcleo (z = zTop)
    local deckPts = {}
    for i = 0, segs do
        local a = (i / segs) * math.pi * 2
        local x, y = projectPoint(cx, cy, coreR, a, zTop, yF, zS, skX, skY)
        table.insert(deckPts, x)
        table.insert(deckPts, y)
    end
    setColor(PALETTE.hullDark, alpha)
    love.graphics.polygon("fill", deckPts)

    setColor(PALETTE.hullHighlight, alpha * 0.95)
    love.graphics.setLineWidth(math.max(2, R * 0.012))
    love.graphics.polygon("line", deckPts)

    -- 5.3 Anillo de energía / Halo de reactor (Inspirado en el Arca de Halo)
    local haloR = coreR * 0.76
    local haloPts = {}
    for i = 0, segs do
        local a = (i / segs) * math.pi * 2
        local x, y = projectPoint(cx, cy, haloR, a, zTop + R * 0.015, yF, zS, skX, skY)
        table.insert(haloPts, x)
        table.insert(haloPts, y)
    end
    setColor(PALETTE.hullDeep, alpha)
    love.graphics.polygon("fill", haloPts)

    local haloAlpha = (damageState == "ruins") and 0.25 or ((damageState == "damaged") and 0.60 or 0.95)
    setColor(PALETTE.reactorHaloGlow, alpha * haloAlpha)
    love.graphics.setLineWidth(math.max(4, R * 0.022))
    love.graphics.polygon("line", haloPts)

    setColor(PALETTE.reactorHalo, alpha * haloAlpha)
    love.graphics.setLineWidth(math.max(1.8, R * 0.010))
    love.graphics.polygon("line", haloPts)

    -- 5.4 Cúpula polar monumental de la Ciudadela (Inspirada en Rick & Morty)
    local domeR = coreR * 0.44
    local domeZ = zTop + R * 0.05
    local domePts = {}
    for i = 0, segs do
        local a = (i / segs) * math.pi * 2
        local x, y = projectPoint(cx, cy, domeR, a, domeZ, yF, zS, skX, skY)
        table.insert(domePts, x)
        table.insert(domePts, y)
    end
    setColor(PALETTE.hullMid, alpha)
    love.graphics.polygon("fill", domePts)

    setColor(PALETTE.hullHighlight, alpha * 0.92)
    love.graphics.setLineWidth(1.6)
    love.graphics.polygon("line", domePts)

    -- División radial en 8 sectores de la cúpula central
    local cx0, cy0 = projectPoint(cx, cy, 0, 0, domeZ, yF, zS, skX, skY)
    setColor(PALETTE.hullDeep, alpha * 0.85)
    love.graphics.setLineWidth(1)
    for k = 0, 7 do
        local a = math.rad(k * 45)
        local ix, iy = projectPoint(cx, cy, domeR, a, domeZ, yF, zS, skX, skY)
        love.graphics.line(cx0, cy0, ix, iy)
    end

    -- Linterna polar cenital y espina astronómica
    local spireX, spireY = projectPoint(cx, cy, 0, 0, domeZ + R * 0.04, yF, zS, skX, skY)
    setColor(PALETTE.reactorHalo, alpha * haloAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx0, cy0, spireX, spireY)
    love.graphics.circle("fill", spireX, spireY, math.max(2.5, R * 0.014))
end

-- ============================================================================
-- 6. FUNCIÓN PRINCIPAL DE RENDERIZADO MODULAR
-- ============================================================================
function StationModularRenderer.render(placeholder, camera, screenX, screenY, finalSize, alpha, rotation, damageState, lod)
    local seed = placeholder.seed or 54321
    damageState = damageState or "operational"
    lod = lod or 1

    local pParams = getProjectionParams(placeholder, camera, screenX, screenY, finalSize)
    if rotation and rotation ~= 0 then
        pParams.rot = rotation
    end

    local armCount = pParams.armCount
    local baseRot = pParams.rot

    local severedArms = {}
    if damageState == "ruins" then
        severedArms[2] = true
        severedArms[4] = true
    elseif damageState == "damaged" then
        severedArms[3] = "damaged"
    end

    -- Paso 1: Complejo escalonado ventral (subcubierta, pozo del reactor y radiadores térmicos sin convergencia a un punto)
    drawLowerStructure(screenX, screenY, finalSize, pParams, alpha, damageState, seed)

    -- Paso 2: Brazos y Módulos Posteriores (ry < -0.15, pasan detrás del núcleo central)
    for i = 1, armCount do
        local armAngle = baseRot + ((i - 1) / armCount) * math.pi * 2
        local sinA = math.sin(armAngle)
        if sinA < -0.15 then
            local isSevered = (severedArms[i] == true)
            drawModularArm(screenX, screenY, finalSize, armAngle, pParams, alpha, isSevered, damageState, seed, i)
        end
    end

    -- Paso 3: Núcleo Central Masivo (Cilindro 3D, Halo y Cúpula, ocluye la parte posterior)
    drawCentralCitadelCore(screenX, screenY, finalSize, pParams, alpha, damageState, seed, lod)

    -- Paso 4: Brazos y Módulos Frontales (ry >= -0.15, se dibujan en primer plano)
    for i = 1, armCount do
        local armAngle = baseRot + ((i - 1) / armCount) * math.pi * 2
        local sinA = math.sin(armAngle)
        if sinA >= -0.15 then
            local isSevered = (severedArms[i] == true)
            drawModularArm(screenX, screenY, finalSize, armAngle, pParams, alpha, isSevered, damageState, seed, i)
        end
    end

    -- Restaurar estado gráfico de grosor de línea de Love2D
    love.graphics.setLineWidth(1)
end

return StationModularRenderer
