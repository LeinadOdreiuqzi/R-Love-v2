-- src/sublevels/celestial_renderer.lua
-- Motor de Renderizado 2.5D para Submundos: Escenario Multi-Capa con Parallax Estelar y Shaders GPU

local CelestialRenderer = {
    initialized = false,
    whiteImage = nil,
    particles = {
        solarWind = {},
        asteroids = {},
        debris = {},
        foregroundDust = {}
    }
}

local PlanetSphereShader = require 'src.shaders.planet_sphere'
local StarCoronaShader = require 'src.shaders.star_corona'
local EclipticPlaneShader = require 'src.shaders.ecliptic_plane'
local GasGiantShader = require 'src.shaders.gas_giant'
local PlanetaryRingShader = require 'src.shaders.planetary_ring'
local TauCetiDef = require 'src.sublevels.definitions.tau_ceti'

function CelestialRenderer.init()
    if CelestialRenderer.initialized then return end

    PlanetSphereShader.init()
    StarCoronaShader.init()
    EclipticPlaneShader.init()
    GasGiantShader.init()
    PlanetaryRingShader.init()

    -- Imagen blanca 1x1 para transmitir UVs (0..1) completas a los shaders GLSL en quads
    if not CelestialRenderer.whiteImage then
        local id = love.image.newImageData(1, 1)
        id:setPixel(0, 0, 1, 1, 1, 1)
        CelestialRenderer.whiteImage = love.graphics.newImage(id)
    end

    -- 1. Inicializar partículas del cinturón de asteroides (Tier 1)
    local belt = TauCetiDef.tiers[1].asteroidBelt
    for i = 1, (belt.particleCount or 220) do
        local angle = (i / (belt.particleCount or 220)) * math.pi * 2 + math.random() * 0.15
        local r = belt.innerRadius + math.random() * (belt.outerRadius - belt.innerRadius)
        table.insert(CelestialRenderer.particles.asteroids, {
            angle = angle,
            dist = r,
            speed = (0.022 / (r / 1000)) * (0.85 + math.random() * 0.3),
            size = 1.8 + math.random() * 3.2,
            shade = 0.55 + math.random() * 0.4
        })
    end

    -- 2. Inicializar motes de polvo cósmico en primer plano (Foreground space dust) para Parallax dinámico
    for i = 1, 110 do
        table.insert(CelestialRenderer.particles.foregroundDust, {
            x = math.random() * 3000 - 1500,
            y = math.random() * 2000 - 1000,
            vx = (math.random() - 0.5) * 12,
            vy = (math.random() - 0.5) * 8,
            size = 1.0 + math.random() * 2.2,
            alpha = 0.20 + math.random() * 0.50,
            twinklePhase = math.random() * math.pi * 2,
            twinkleSpeed = 1.2 + math.random() * 2.0
        })
    end

    -- 3. Inicializar partículas de viento solar de alta energía (Tier 2)
    local wind = TauCetiDef.tiers[2].solarWind
    for i = 1, (wind.particleCount or 260) do
        local angle = math.random() * math.pi * 2
        local dist = (wind.minDist or 3300) + math.random() * ((wind.maxDist or 8000) - (wind.minDist or 3300))
        table.insert(CelestialRenderer.particles.solarWind, {
            angle = angle,
            dist = dist,
            speed = (wind.baseSpeed or 620) * (0.80 + math.random() * 0.40),
            length = 30 + math.random() * 55,
            width = 1.4 + math.random() * 1.6,
            alpha = 0.35 + math.random() * 0.55
        })
    end

    -- 4. Inicializar escombros y satélites orbitales (Tier 3)
    local debrisConfig = TauCetiDef.tiers[3].orbitalDebris
    for i = 1, (debrisConfig.count or 75) do
        local angle = math.random() * math.pi * 2
        local dist = (debrisConfig.minDist or 2800) + math.random() * ((debrisConfig.maxDist or 5800) - (debrisConfig.minDist or 2800))
        table.insert(CelestialRenderer.particles.debris, {
            angle = angle,
            dist = dist,
            speed = (0.018 / (dist / 3000)) * (0.85 + math.random() * 0.3),
            size = 2.0 + math.random() * 4.5,
            blinkPhase = math.random() * math.pi * 2,
            isSatellite = (i % 6 == 0)
        })
    end

    CelestialRenderer.initialized = true
end

function CelestialRenderer.update(dt)
    if not CelestialRenderer.initialized then
        CelestialRenderer.init()
    end

    -- Actualizar asteroides
    for _, ast in ipairs(CelestialRenderer.particles.asteroids) do
        ast.angle = (ast.angle + ast.speed * dt) % (math.pi * 2)
    end

    -- Actualizar motes de polvo cósmico en primer plano
    for _, mote in ipairs(CelestialRenderer.particles.foregroundDust) do
        mote.x = mote.x + mote.vx * dt
        mote.y = mote.y + mote.vy * dt
        if mote.x > 1800 then mote.x = -1800
        elseif mote.x < -1800 then mote.x = 1800 end
        if mote.y > 1200 then mote.y = -1200
        elseif mote.y < -1200 then mote.y = 1200 end
    end

    -- Actualizar viento solar radial
    for _, p in ipairs(CelestialRenderer.particles.solarWind) do
        p.dist = p.dist + p.speed * dt
        if p.dist > 8200 then
            p.dist = 3300 + math.random() * 200
            p.angle = math.random() * math.pi * 2
        end
    end

    -- Actualizar escombros y satélites orbitales
    for _, d in ipairs(CelestialRenderer.particles.debris) do
        d.angle = (d.angle + d.speed * dt) % (math.pi * 2)
    end
end

-- ============================================================================
-- ESCENARIO DE FONDO CON PARALLAX MULTI-CAPA ESTELAR (ANTES DE camera:apply())
-- ============================================================================

function CelestialRenderer.drawScenicBackground(sublevelConfig, camera, player)
    if not CelestialRenderer.initialized then
        CelestialRenderer.init()
    end

    local meta = sublevelConfig and sublevelConfig.meta
    local tier = (meta and meta.tier) or 1
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local t = love.timer.getTime()

    if tier == 1 then
        CelestialRenderer.drawTier1ScenicBackground(TauCetiDef.tiers[1], camera, player, sw, sh, t)
    elseif tier == 3 then
        CelestialRenderer.drawTier3ScenicBackground(TauCetiDef.tiers[3], camera, player, sw, sh, t)
    end
end

-- ─── ESCENARIO DE FONDO TIER 1: VISTA DE CANTO DEL SISTEMA SOLAR ────────────

function CelestialRenderer.drawTier1ScenicBackground(def, camera, player, sw, sh, t)
    local camX = (camera and camera.x) or 0
    local camY = (camera and camera.y) or 0
    local camZoom = (camera and camera.zoom) or 1.0

    -- Factor de escala suave para el escenario según el zoom de la cámara
    local scenicScale = math.max(0.70, math.min(1.40, 1.0 + (camZoom - 0.35) * 0.50))
    local whiteImg = CelestialRenderer.whiteImage
    local yComp = 0.12 -- Inclinación de canto rasante a ~7 grados (horizonte estelar realista)
    local spreadMul = (sw / 1920) * 0.25 * scenicScale

    -- ─── CENTRO UNIFICADO DEL SISTEMA SOLAR (Parallax único: todos los cuerpos orbitan al Sol) ─
    local psSystem = 0.024
    local sunScreenX = sw * 0.5 - (camX * psSystem)
    local sunScreenY = sh * 0.44 - (camY * psSystem)

    -- ─── CAPA 1: DISCO ZODIACAL DE CANTO ──────────────────────────────────────
    local eclipticShader = EclipticPlaneShader.getShader()
    if eclipticShader and whiteImg then
        love.graphics.setShader(eclipticShader)
        eclipticShader:send("u_time", t)
        eclipticShader:send("u_color", { 0.32, 0.68, 0.95 })

        local diskW = sw * 3.2 * scenicScale
        local diskH = diskW * yComp * 1.45
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(whiteImg, sunScreenX - diskW * 0.5, sunScreenY - diskH * 0.5, 0, diskW, diskH)
        love.graphics.setShader()
    end

    -- ─── CAPA 2: CINTURÓN DE ASTEROIDES POSTERIOR (sin < -0.05) ────────────────
    for _, ast in ipairs(CelestialRenderer.particles.asteroids) do
        local sinA = math.sin(ast.angle)
        if sinA < -0.05 then
            local dist = ast.dist * spreadMul
            local ax = sunScreenX + math.cos(ast.angle) * dist
            local ay = sunScreenY + sinA * dist * yComp
            local depth = 0.45 + 0.20 * (sinA * 0.5 + 0.5)
            love.graphics.setColor(ast.shade * depth, ast.shade * 0.92 * depth, ast.shade * 0.88 * depth, 0.45)
            love.graphics.circle("fill", ax, ay, ast.size * 0.68 * scenicScale, 4)
        end
    end

    -- ─── CAPA 3: PLANETAS POSTERIORES (sin < 0) ────────────────────────────────
    for _, p in ipairs(def.planets) do
        local curAngle = (p.phase or 0) + t * p.speed
        local sinA = math.sin(curAngle)
        if sinA < 0 then
            local orbitR = p.orbitRadius * spreadMul
            local px = sunScreenX + math.cos(curAngle) * orbitR
            local py = sunScreenY + sinA * orbitR * yComp

            local depth = 0.65
            local pSize = p.size * 0.42 * scenicScale
            love.graphics.setColor(p.color[1] * depth, p.color[2] * depth, p.color[3] * depth, 0.75)
            love.graphics.circle("fill", px, py, pSize)
        end
    end

    -- ─── CAPA 4: ESTRELLA CENTRAL TAU CETI ─────────────────────────────────────
    local sunShader = StarCoronaShader.getShader()
    local sunR = 46 * scenicScale
    local sunPad = sunR * 2.6
    if sunShader and whiteImg then
        love.graphics.setShader(sunShader)
        sunShader:send("u_time", t)
        sunShader:send("u_surfaceColor", def.sun.color)
        sunShader:send("u_coronaColor", def.sun.glowColor)
        sunShader:send("u_deepCoronaColor", { 0.95, 0.42, 0.10 })
        sunShader:send("u_flareIntensity", 1.25)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(whiteImg, sunScreenX - sunPad, sunScreenY - sunPad, 0, sunPad * 2, sunPad * 2)
        love.graphics.setShader()
    else
        love.graphics.setColor(def.sun.color[1], def.sun.color[2], def.sun.color[3], 0.95)
        love.graphics.circle("fill", sunScreenX, sunScreenY, sunR, 48)
    end

    -- ─── CAPA 5: CINTURÓN DE ASTEROIDES ANTERIOR (sin >= -0.05) ────────────────
    for _, ast in ipairs(CelestialRenderer.particles.asteroids) do
        local sinA = math.sin(ast.angle)
        if sinA >= -0.05 then
            local dist = ast.dist * spreadMul
            local ax = sunScreenX + math.cos(ast.angle) * dist
            local ay = sunScreenY + sinA * dist * yComp
            local depth = 0.75 + 0.25 * (sinA * 0.5 + 0.5)
            love.graphics.setColor(ast.shade * depth, ast.shade * 0.96 * depth, ast.shade * 0.90 * depth, 0.82)
            love.graphics.circle("fill", ax, ay, ast.size * 0.92 * scenicScale, 5)
        end
    end

    -- ─── CAPA 6: PLANETAS ANTERIORES Y TAU CETI IV (sin >= 0) ──────────────────
    for _, p in ipairs(def.planets) do
        local curAngle = (p.phase or 0) + t * p.speed
        local sinA = math.sin(curAngle)
        if sinA >= 0 then
            local orbitR = p.orbitRadius * spreadMul
            local px = sunScreenX + math.cos(curAngle) * orbitR
            local py = sunScreenY + sinA * orbitR * yComp

            if p.isTarget then
                -- Tau Ceti IV con PlanetSphereShader en primer plano escénico
                local pShader = PlanetSphereShader.getShader()
                local pRadius = p.size * 0.72 * scenicScale
                local pPad = pRadius * 1.28
                if pShader and whiteImg then
                    love.graphics.setShader(pShader)
                    
                    -- Dirección de luz dinámica apuntando a la estrella central
                    local ldx = (sunScreenX - px)
                    local ldy = (sunScreenY - py)
                    local ldist = math.max(1.0, math.sqrt(ldx*ldx + ldy*ldy))
                    
                    pShader:send("u_time", t)
                    pShader:send("u_lightDir", { ldx / ldist, ldy / ldist, 0.55 })
                    pShader:send("u_uvOffset", { t * 0.015, 0.0 })
                    pShader:send("u_atmosphereThickness", 0.26)
                    pShader:send("u_atmosphereColor", p.atmosphere or { 0.40, 0.85, 1.00 })
                    pShader:send("u_oceanColor", { 0.08, 0.28, 0.62 })
                    pShader:send("u_landColor", { 0.20, 0.62, 0.38 })
                    pShader:send("u_specular", 1.4)

                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(whiteImg, px - pPad, py - pPad, 0, pPad * 2, pPad * 2)
                    love.graphics.setShader()
                else
                    love.graphics.setColor(p.color[1], p.color[2], p.color[3], 1.0)
                    love.graphics.circle("fill", px, py, pRadius)
                end
            else
                local pRadius = p.size * 0.52 * scenicScale
                love.graphics.setColor(p.color[1], p.color[2], p.color[3], 1.0)
                love.graphics.circle("fill", px, py, pRadius)

                -- Sombra del terminador orientada opuesta a la estrella
                local shadowAngle = math.atan2(py - sunScreenY, px - sunScreenX)
                love.graphics.setColor(0.010, 0.015, 0.025, 0.80)
                love.graphics.arc("fill", px, py, pRadius + 0.5, shadowAngle - math.pi * 0.5, shadowAngle + math.pi * 0.5)
            end
        end
    end

    -- ─── CAPA 7: MOTES DE POLVO CÓSMICO EN PRIMER PLANO (Parallax dinámico: 0.22) ─
    do
        local psDust = 0.22
        local dustOffX = - (camX * psDust)
        local dustOffY = - (camY * psDust)
        local wrapW = sw + 300
        local wrapH = sh + 300

        for _, mote in ipairs(CelestialRenderer.particles.foregroundDust) do
            local sx = ((mote.x + dustOffX) % wrapW) - 150
            local sy = ((mote.y + dustOffY) % wrapH) - 150
            local tw = 0.70 + 0.30 * math.sin(t * mote.twinkleSpeed + mote.twinklePhase)
            love.graphics.setColor(0.68, 0.85, 1.00, mote.alpha * tw * 0.65)
            love.graphics.circle("fill", sx, sy, mote.size)
        end
    end
end

-- ─── ESCENARIO DE FONDO TIER 3: GIGANTE GASEOSO CELESTE, LUNAS Y NAVE MARATHON ─

function CelestialRenderer.drawRing(gasX, gasY, tilt, inR, outR, rCol, yFlatten, drawSide, scenicScale, t)
    local ringShader = PlanetaryRingShader.getShader()
    local whiteImg = CelestialRenderer.whiteImage
    if not ringShader or not whiteImg then return end

    local outW = outR * 2
    local oldBlend, oldAlpha = love.graphics.getBlendMode()
    love.graphics.push()
    love.graphics.translate(gasX, gasY)
    love.graphics.rotate(tilt)

    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setShader(ringShader)

    ringShader:send("u_time", t)
    ringShader:send("u_innerRatio", inR / outR)
    ringShader:send("u_yFlatten", yFlatten)
    ringShader:send("u_drawSide", drawSide)
    ringShader:send("u_ringColor", { rCol[1], rCol[2], rCol[3] })
    ringShader:send("u_ringHighlight", { 0.95, 0.98, 1.00 })
    ringShader:send("u_baseAlpha", rCol[4] or 0.65)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(whiteImg, -outR, -outR, 0, outW, outW)

    love.graphics.setShader()
    love.graphics.setBlendMode(oldBlend, oldAlpha)
    love.graphics.pop()
end

function CelestialRenderer.drawTier3ScenicBackground(def, camera, player, sw, sh, t)
    local whiteImg = CelestialRenderer.whiteImage
    local camX = (camera and camera.x) or 0
    local camY = (camera and camera.y) or 0
    local camZoom = (camera and camera.zoom) or 1.0
    local scenicScale = math.max(0.70, math.min(1.40, 1.0 + (camZoom - 0.45) * 0.45))

    -- ─── 1. EL GIGANTE GASEOSO CELESTE COLOSAL (Parallax profundo: 0.008) ────────
    local gasGiant = def.gasGiant
    local gasX, gasY, gasR = 0, 0, 0
    if gasGiant then
        local psGas = gasGiant.parallax or 0.008
        local sp = gasGiant.screenPos or { xRatio = 0.68, yRatio = 0.82 }
        gasX = sw * sp.xRatio - (camX * psGas)
        gasY = sh * sp.yRatio - ((camY - 2900) * psGas)
        gasR = (gasGiant.radius or 580) * scenicScale
        local yFlatten = (gasGiant.rings and gasGiant.rings.yFlatten) or 0.25

        -- 1.1 Anillos planetarios helados (MITAD POSTERIOR - Detrás del gigante gaseoso)
        if gasGiant.rings then
            local rCol = gasGiant.rings.color or { 0.75, 0.90, 1.00, 0.55 }
            local tilt = gasGiant.rings.tilt or -0.38
            local inR = (gasGiant.rings.innerRadius or 700) * scenicScale
            local outR = (gasGiant.rings.outerRadius or 1420) * scenicScale

            CelestialRenderer.drawRing(gasX, gasY, tilt, inR, outR, rCol, yFlatten, -1.0, scenicScale, t)
        end

        -- 1.2 Globo del Gigante Gaseoso con Shader GLSL
        local gasShader = GasGiantShader.getShader()
        local pad = gasR * (1.0 + gasGiant.atmosphereThickness) * 1.05
        if gasShader and whiteImg then
            love.graphics.setShader(gasShader)
            gasShader:send("u_time", t)
            gasShader:send("u_lightDir", gasGiant.lightDir or { 0.65, 0.45, 0.60 })
            gasShader:send("u_atmosphereThickness", gasGiant.atmosphereThickness)
            gasShader:send("u_atmosphereColor", gasGiant.colors.atmosphere)
            gasShader:send("u_colorDeep", gasGiant.colors.deep)
            gasShader:send("u_colorMid", gasGiant.colors.mid)
            gasShader:send("u_colorLight", gasGiant.colors.light)
            gasShader:send("u_colorWhite", gasGiant.colors.white)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(whiteImg, gasX - pad, gasY - pad, 0, pad * 2, pad * 2)
            love.graphics.setShader()
        else
            love.graphics.setColor(gasGiant.colors.mid[1], gasGiant.colors.mid[2], gasGiant.colors.mid[3], 0.95)
            love.graphics.circle("fill", gasX, gasY, gasR, 120)
        end

        -- 1.3 Anillos planetarios helados (MITAD FRONTAL - Pasa sobre el gigante gaseoso)
        if gasGiant.rings then
            local rCol = gasGiant.rings.color or { 0.75, 0.90, 1.00, 0.55 }
            local tilt = gasGiant.rings.tilt or -0.38
            local inR = (gasGiant.rings.innerRadius or 700) * scenicScale
            local outR = (gasGiant.rings.outerRadius or 1420) * scenicScale

            CelestialRenderer.drawRing(gasX, gasY, tilt, inR, outR, rCol, yFlatten, 1.0, scenicScale, t)
        end
    end

    -- ─── 2. LUNAS SECUNDARIAS DE FONDO Y LUNA MAGENTA ─────────────────────────
    if def.backgroundMoons then
        local pShader = PlanetSphereShader.getShader()
        for _, moon in ipairs(def.backgroundMoons) do
            local psMoon = moon.parallax or 0.015
            local mX = gasX + (moon.screenOffset.x or 0) * scenicScale - (camX * (psMoon - 0.008))
            local mY = gasY + (moon.screenOffset.y or 0) * scenicScale - ((camY - 2900) * (psMoon - 0.008))
            local mR = moon.radius * scenicScale
            local mPad = mR * 1.25

            if pShader and whiteImg then
                love.graphics.setShader(pShader)
                pShader:send("u_time", t)
                pShader:send("u_lightDir", { 0.65, 0.45, 0.60 })
                pShader:send("u_uvOffset", { 0.22, 0.38 })
                pShader:send("u_atmosphereThickness", 0.16)
                pShader:send("u_atmosphereColor", moon.color.atmosphere)
                pShader:send("u_oceanColor", moon.color.ocean)
                pShader:send("u_landColor", moon.color.land)
                pShader:send("u_specular", 0.0)

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(whiteImg, mX - mPad, mY - mPad, 0, mPad * 2, mPad * 2)
                love.graphics.setShader()
            else
                love.graphics.setColor(moon.color.land[1], moon.color.land[2], moon.color.land[3], 1.0)
                love.graphics.circle("fill", mX, mY, mR, 64)
            end

            -- ─── 3. TRIBUTO A MARATHON: NAVE "MARATHON" INCRUSTADA EN DEIMOS ───────
            if moon.hasMarathon and def.marathonShip then
                CelestialRenderer.drawMarathonShip(def.marathonShip, mX, mY, mR, scenicScale, t)
            end
        end
    end

    -- ─── 4. MOTES DE POLVO CÓSMICO EN PRIMER PLANO (Parallax: 0.22) ───────────
    do
        local psDust = 0.22
        local dustOffX = - (camX * psDust)
        local dustOffY = - ((camY - 2900) * psDust)
        local wrapW = sw + 300
        local wrapH = sh + 300

        for _, mote in ipairs(CelestialRenderer.particles.foregroundDust) do
            local sx = ((mote.x + dustOffX) % wrapW) - 150
            local sy = ((mote.y + dustOffY) % wrapH) - 150
            local tw = 0.70 + 0.30 * math.sin(t * mote.twinkleSpeed + mote.twinklePhase)
            love.graphics.setColor(0.68, 0.85, 1.00, mote.alpha * tw * 0.65)
            love.graphics.circle("fill", sx, sy, mote.size)
        end
    end
end

-- ─── TRIBUTO UESC MARATHON (NAVE INCRUSTADA EN LA LUNA DE DEIMOS) ───────────

function CelestialRenderer.drawMarathonShip(shipDef, moonX, moonY, moonR, scale, t)
    local orbSpeed = (shipDef and shipDef.orbitSpeed) or 0.03
    -- Posicionada en el limbo izquierdo de la luna, con la aguja apuntando al centro (idéntica a Marathon referencia)
    local orbAngle = math.pi + 0.12 + math.sin(t * orbSpeed) * 0.08
    local orbRadX = moonR * 0.94
    local orbRadY = moonR * 0.16
    local sx = moonX + math.cos(orbAngle) * orbRadX
    local sy = moonY + math.sin(orbAngle) * orbRadY
    local shipScale = scale * 1.08
    local shipAngle = -0.06 + math.sin(orbAngle) * 0.02

    love.graphics.push()
    love.graphics.translate(sx, sy)
    love.graphics.rotate(shipAngle)
    love.graphics.scale(shipScale, shipScale)

    local deimosX = -16
    local deimosY = 0
    local deimosR = 20.0

    -- ========================================================================
    -- 1. EL ESPINAZO CONTINUO DE LA NAVE (PASA POR DENTRO DE DEIMOS)
    --    Se dibuja primero la nave entera de punta a punta, limpia y rectilínea.
    --    Luego Deimos se dibuja encima, cubriendo y ocultando la sección interna.
    -- ========================================================================

    -- 1.1 Popa / cola rectangular trasera (sale por la parte izquierda de Deimos)
    -- De x = -48 a x = -16 (donde entra a Deimos)
    love.graphics.setColor(0.16, 0.38, 0.80, 1.0) -- Azul UESC
    love.graphics.rectangle("fill", -48, -2.2, 34, 4.4)
    -- Extremo plano de la popa (tapa de motores oscura, SIN CONO NI RESPLANDOR)
    love.graphics.setColor(0.12, 0.14, 0.18, 1.0)
    love.graphics.rectangle("fill", -51, -2.6, 3.2, 5.2)

    -- 1.2 Aguja delantera principal (sale por la parte derecha de Deimos)
    -- De x = 0 a x = 74
    -- Quilla ventral oscura
    love.graphics.setColor(0.10, 0.12, 0.16, 1.0)
    love.graphics.polygon("fill", 0, 2.0, 74, 1.0, 74, 2.5, 0, 3.5)

    -- Viga inferior (haz azul cobalto)
    love.graphics.setColor(0.18, 0.42, 0.84, 1.0)
    love.graphics.polygon("fill", 0, 0.3, 74, 0.2, 74, 2.0, 0, 2.0)

    -- Canal central longitudinal oscuro (ranura divisoria de vigas paralelas)
    love.graphics.setColor(0.08, 0.10, 0.14, 1.0)
    love.graphics.polygon("fill", 0, -0.3, 74, -0.2, 74, 0.3, 0, 0.3)

    -- Viga superior (haz azul cobalto con reflejo dorsal)
    love.graphics.setColor(0.24, 0.50, 0.92, 1.0)
    love.graphics.polygon("fill", 0, -2.0, 74, -2.0, 74, -0.3, 0, -0.3)

    -- Placas celestes modulares en la superficie dorsal
    love.graphics.setColor(0.38, 0.70, 0.95, 0.95)
    love.graphics.rectangle("fill", 48, -2.0, 18, 0.8)
    love.graphics.rectangle("fill", 14, -2.0, 12, 0.8)

    -- Tapa frontal de la proa (punta recta/biselada de grafito, SIN LÍNEAS QUE SOBRESALGAN)
    love.graphics.setColor(0.12, 0.14, 0.18, 1.0)
    love.graphics.polygon("fill", 74, -2.0, 77, -1.4, 77, 1.4, 74, 2.0)

    -- Franja de seguridad naranja/amarilla en la unión con la roca
    love.graphics.setColor(0.98, 0.65, 0.12, 1.0)
    love.graphics.rectangle("fill", 3.0, -2.2, 2.2, 4.4)

    -- Letrero auténtico "UESC" en blanco sobre la aguja azul
    love.graphics.setColor(0.98, 0.98, 1.0, 0.98)
    love.graphics.setLineWidth(1.3)
    -- 'U' (x = 26 a 29)
    love.graphics.line(26.0, -1.5, 26.0, 0.2)
    love.graphics.line(26.0, 0.2, 29.0, 0.2)
    love.graphics.line(29.0, 0.2, 29.0, -1.5)
    -- 'E' (x = 31 a 34)
    love.graphics.line(31.0, -1.5, 31.0, 0.2)
    love.graphics.line(31.0, -1.5, 34.0, -1.5)
    love.graphics.line(31.0, -0.65, 33.2, -0.65)
    love.graphics.line(31.0, 0.2, 34.0, 0.2)
    -- 'S' (x = 36 a 39)
    love.graphics.line(39.0, -1.5, 36.0, -1.5)
    love.graphics.line(36.0, -1.5, 36.0, -0.65)
    love.graphics.line(36.0, -0.65, 39.0, -0.65)
    love.graphics.line(39.0, -0.65, 39.0, 0.2)
    love.graphics.line(39.0, 0.2, 36.0, 0.2)
    -- 'C' (x = 41 a 44)
    love.graphics.line(44.0, -1.5, 41.0, -1.5)
    love.graphics.line(41.0, -1.5, 41.0, 0.2)
    love.graphics.line(41.0, 0.2, 44.0, 0.2)
    love.graphics.setLineWidth(1.0)

    -- ========================================================================
    -- 2. LUNA DE DEIMOS (CUBRE Y OCULTA COMPLETAMENTE LA PARTE INTERIOR DE LA NAVE)
    -- ========================================================================

    -- 2.1 Fragmentos de roca / escombros desprendidos orbitando alrededor de Deimos
    local rockFragments = {
        { x = -10, y = -26, w = 3.8, h = 2.8, rot = 0.4 },
        { x = 7,   y = -20, w = 3.2, h = 2.2, rot = -0.3 },
        { x = -32, y = -18, w = 3.5, h = 2.5, rot = 0.8 },
        { x = -40, y = 16,  w = 3.6, h = 2.8, rot = -0.6 },
        { x = -8,  y = 25,  w = 4.0, h = 3.0, rot = 0.2 },
        { x = 9,   y = 17,  w = 3.0, h = 2.0, rot = 0.5 },
        { x = -26, y = 26,  w = 3.2, h = 2.4, rot = -0.4 },
        { x = -18, y = -29, w = 2.8, h = 2.2, rot = 0.1 }
    }

    for _, rf in ipairs(rockFragments) do
        love.graphics.push()
        love.graphics.translate(rf.x, rf.y)
        love.graphics.rotate(rf.rot)
        -- Cara iluminada
        love.graphics.setColor(0.74, 0.70, 0.62, 0.95)
        love.graphics.polygon("fill", -rf.w * 0.5, 0, 0, -rf.h * 0.5, rf.w * 0.5, 0, 0, rf.h * 0.5)
        -- Cara en sombra
        love.graphics.setColor(0.34, 0.32, 0.28, 0.95)
        love.graphics.polygon("fill", -rf.w * 0.5, 0, 0, rf.h * 0.5, rf.w * 0.5, 0)
        love.graphics.pop()
    end

    -- 2.2 Cuerpo esférico sólido de Deimos (tapa completamente el interior de la nave)
    love.graphics.setColor(0.60, 0.56, 0.50, 1.0)
    love.graphics.circle("fill", deimosX, deimosY, deimosR, 64)

    -- Sombra volumétrica esférica (fase lunar natural)
    love.graphics.setColor(0.24, 0.22, 0.20, 0.88)
    love.graphics.arc("fill", deimosX, deimosY, deimosR, math.pi * 0.12, math.pi * 1.18)

    -- Borde y relieve iluminado superior exterior
    love.graphics.setColor(0.82, 0.78, 0.70, 0.95)
    love.graphics.setLineWidth(2.0)
    love.graphics.arc("line", deimosX, deimosY, deimosR - 0.6, -math.pi * 0.88, -math.pi * 0.12)

    -- Cráteres y textura geológica en la superficie sólida de la luna
    love.graphics.setColor(0.38, 0.35, 0.30, 0.80)
    love.graphics.circle("fill", deimosX - 8, deimosY - 8, 3.6)
    love.graphics.setColor(0.72, 0.68, 0.60, 0.85)
    love.graphics.arc("line", deimosX - 8, deimosY - 8, 3.6, -math.pi * 0.85, -math.pi * 0.10)

    love.graphics.setColor(0.34, 0.31, 0.28, 0.80)
    love.graphics.circle("fill", deimosX - 10, deimosY + 7, 3.0)
    love.graphics.setColor(0.70, 0.66, 0.58, 0.85)
    love.graphics.arc("line", deimosX - 10, deimosY + 7, 3.0, -math.pi * 0.85, -math.pi * 0.10)

    -- 2.3 Cráteres de impacto/perforación en los puntos de entrada y salida de la aguja
    -- Punto de entrada (lado derecho de Deimos, de donde emerge la aguja hacia la derecha)
    love.graphics.setColor(0.36, 0.33, 0.29, 0.95)
    love.graphics.ellipse("fill", deimosX + deimosR - 1.5, 0, 3.2, 5.0)
    love.graphics.setColor(0.78, 0.74, 0.66, 0.90)
    love.graphics.ellipse("line", deimosX + deimosR - 1.5, 0, 3.2, 5.0)

    -- Punto de salida (lado izquierdo de Deimos, de donde emerge la popa hacia la izquierda)
    love.graphics.setColor(0.28, 0.26, 0.23, 0.95)
    love.graphics.ellipse("fill", deimosX - deimosR + 1.5, 0, 2.8, 4.4)
    love.graphics.setColor(0.68, 0.64, 0.56, 0.85)
    love.graphics.ellipse("line", deimosX - deimosR + 1.5, 0, 2.8, 4.4)

    love.graphics.setLineWidth(1.0)
    love.graphics.pop()
end

-- ============================================================================
-- RENDERIZADO EN ESPACIO DE MUNDO LOCAL (DENTRO DE camera:apply())
-- ============================================================================

function CelestialRenderer.drawWorldBeacons(sublevelConfig, player)
    local meta = sublevelConfig and sublevelConfig.meta
    local tier = (meta and meta.tier) or 1
    local tierDef = TauCetiDef.tiers[tier]
    if not tierDef or not tierDef.beacons then return end

    local t = love.timer.getTime()
    CelestialRenderer.drawBeacons(tierDef.beacons, player, t)
end

function CelestialRenderer.draw(sublevelConfig, camera, player, dt)
    if not CelestialRenderer.initialized then
        CelestialRenderer.init()
    end

    local meta = sublevelConfig and sublevelConfig.meta
    local tier = (meta and meta.tier) or 1
    local t = love.timer.getTime()

    if tier == 1 then
        CelestialRenderer.drawWorldBeacons(sublevelConfig, player)
    elseif tier == 2 then
        CelestialRenderer.drawTier2(TauCetiDef.tiers[2], camera, player, t)
    elseif tier == 3 then
        CelestialRenderer.drawTier3(TauCetiDef.tiers[3], camera, player, t)
    end
end

-- ─── TIER 2: CORONA SOLAR CERCANA (ZONA DE CALOR CRÍTICO) ───────────────────

function CelestialRenderer.drawTier2(def, camera, player, t)
    local sun = def.sun
    local shader = StarCoronaShader.getShader()
    local whiteImg = CelestialRenderer.whiteImage
    local oldBlend, oldAlpha = love.graphics.getBlendMode()

    -- 1. Estrella Colosal Tau Ceti (Fotosfera de Proximidad y Arcos Magnéticos)
    if shader and whiteImg then
        love.graphics.setShader(shader)
        shader:send("u_time", t)
        shader:send("u_surfaceColor", sun.surfaceColor)
        shader:send("u_coronaColor", sun.coronaColor)
        shader:send("u_deepCoronaColor", sun.deepCoronaColor)
        shader:send("u_flareIntensity", 1.8)
        local pad = sun.radius * 2.35
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(whiteImg, sun.x - pad, sun.y - pad, 0, pad * 2, pad * 2)
        love.graphics.setShader()
    else
        love.graphics.setColor(sun.surfaceColor[1], sun.surfaceColor[2], sun.surfaceColor[3], 0.95)
        love.graphics.circle("fill", sun.x, sun.y, sun.radius, 120)
    end

    -- 2. Viento solar de alta energía (Rayos y plasma acelerado radialmente)
    love.graphics.setBlendMode("add", "alphamultiply")
    for _, p in ipairs(CelestialRenderer.particles.solarWind) do
        local cosA = math.cos(p.angle)
        local sinA = math.sin(p.angle)
        local startX = sun.x + cosA * p.dist
        local startY = sun.y + sinA * p.dist
        local endX = sun.x + cosA * (p.dist + p.length)
        local endY = sun.y + sinA * (p.dist + p.length)

        love.graphics.setLineWidth(p.width or 1.8)
        love.graphics.setColor(def.solarWind.color[1], def.solarWind.color[2], def.solarWind.color[3], p.alpha * 0.85)
        love.graphics.line(startX, startY, endX, endY)

        -- Chispa incandescente en el frente de onda
        love.graphics.setColor(1.0, 0.95, 0.85, p.alpha)
        love.graphics.circle("fill", endX, endY, (p.width or 1.8) * 0.8)
    end
    love.graphics.setBlendMode(oldBlend, oldAlpha)

    -- 3. Balizas de navegación y salto
    CelestialRenderer.drawBeacons(def.beacons, player, t)

    -- 4. Advertencia y efecto térmico si la nave se adentra en la zona de peligro
    if player then
        local px, py = player.x or 0, player.y or 0
        local distToSun = math.sqrt((px - sun.x)^2 + (py - sun.y)^2)
        if distToSun < sun.heatDamageDistance then
            local dangerFactor = math.max(0.0, math.min(1.0, 1.0 - (distToSun - sun.radius) / (sun.heatDamageDistance - sun.radius)))
            local warnAlpha = (0.35 + 0.35 * math.sin(t * 8.0)) * dangerFactor

            -- Anillo de calor alrededor de la nave
            love.graphics.setColor(1.0, 0.30, 0.08, warnAlpha)
            love.graphics.setLineWidth(2.5)
            love.graphics.circle("line", px, py, 110 + math.sin(t * 12.0) * 12)

            -- HUD badge en espacio de mundo junto a la nave
            love.graphics.setColor(0.12, 0.02, 0.02, 0.85)
            love.graphics.rectangle("fill", px - 140, py - 160, 280, 36, 4)
            love.graphics.setColor(1.0, 0.35, 0.10, 0.95)
            love.graphics.rectangle("line", px - 140, py - 160, 280, 36, 4)
            love.graphics.setColor(1.0, 0.90, 0.80, 0.95)
            love.graphics.printf("ALERTA: RADIACION CORONAL", px - 138, py - 152, 276, "center")
        end
    end
end

-- ─── TIER 3: ÓRBITA BAJA DE TAU CETI IV (PSEUDO-ESFERA RAYMARCHED) ──────────

function CelestialRenderer.drawTier3(def, camera, player, t)
    local planet = def.planet
    local shader = PlanetSphereShader.getShader()
    local whiteImg = CelestialRenderer.whiteImage

    -- 1. Globo Gigante de Tau Ceti IV en Órbita Baja
    if shader and whiteImg then
        love.graphics.setShader(shader)

        local px = (player and player.x) or 0
        local py = (player and player.y) or 0
        -- Mapeo UV rotatorio dinámico al navegar alrededor del planeta
        local uvX = (px - planet.x) / (planet.radius * 6.5) + t * planet.rotationSpeed
        local uvY = (py - planet.y) / (planet.radius * 6.5)

        shader:send("u_time", t)
        shader:send("u_lightDir", planet.lightDir)
        shader:send("u_uvOffset", { uvX, uvY })
        shader:send("u_atmosphereThickness", planet.atmosphereThickness)
        shader:send("u_atmosphereColor", planet.atmosphere.dayColor)
        shader:send("u_oceanColor", planet.surface.oceanColor)
        shader:send("u_landColor", planet.surface.landColor)
        shader:send("u_specular", planet.surface.specularIntensity)

        local pad = planet.radius * (1.0 + planet.atmosphereThickness) * 1.08
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(whiteImg, planet.x - pad, planet.y - pad, 0, pad * 2, pad * 2)
        love.graphics.setShader()
    else
        love.graphics.setColor(0.18, 0.45, 0.85, 0.95)
        love.graphics.circle("fill", planet.x, planet.y, planet.radius, 120)
    end

    -- 2. Escombros orbitales y satélites de investigación
    for _, d in ipairs(CelestialRenderer.particles.debris) do
        local dx = planet.x + math.cos(d.angle) * d.dist
        local dy = planet.y + math.sin(d.angle) * d.dist

        if d.isSatellite then
            -- Cuerpo del satélite con paneles solares
            love.graphics.setColor(0.85, 0.88, 0.92, 0.95)
            love.graphics.rectangle("fill", dx - 4, dy - 3, 8, 6)
            love.graphics.setColor(0.20, 0.55, 0.90, 0.85)
            love.graphics.rectangle("fill", dx - 12, dy - 2, 7, 4)
            love.graphics.rectangle("fill", dx + 5, dy - 2, 7, 4)
            
            -- Baliza de telemetría intermitente
            local blink = math.sin(t * 6.0 + d.blinkPhase) > 0.4
            if blink then
                love.graphics.setColor(0.3, 1.0, 0.5, 0.95)
                love.graphics.circle("fill", dx, dy, 2.2)
            end
        else
            love.graphics.setColor(0.55, 0.62, 0.70, 0.70)
            love.graphics.circle("fill", dx, dy, d.size, 5)
        end
    end

    -- 4. Balizas de navegación y salto
    CelestialRenderer.drawBeacons(def.beacons, player, t)
end

-- ─── BALIZAS DE NAVEGACIÓN Y SALTO ──────────────────────────────────────────

function CelestialRenderer.drawBeacons(beacons, player, t)
    if not beacons then return end

    local px = (player and player.x) or 0
    local py = (player and player.y) or 0

    for _, b in ipairs(beacons) do
        local col = b.color or { 0.4, 0.8, 1.0 }
        local pulse = 0.7 + 0.3 * math.sin(t * 3.0)
        local radarR = (t * 40) % b.radius

        -- 1. Anillo exterior de la baliza
        love.graphics.setColor(col[1], col[2], col[3], 0.35 * pulse)
        love.graphics.setLineWidth(1.8)
        love.graphics.circle("line", b.x, b.y, b.radius, 36)

        -- 2. Pulso de radar expansivo
        love.graphics.setColor(col[1], col[2], col[3], (1.0 - radarR / b.radius) * 0.4)
        love.graphics.circle("line", b.x, b.y, radarR, 36)

        -- 3. Estructura de la boya de navegación (rombo holográfico rotatorio)
        love.graphics.push()
        love.graphics.translate(b.x, b.y)
        love.graphics.rotate(t * 0.8)
        love.graphics.setColor(col[1], col[2], col[3], 0.85)
        love.graphics.polygon("line", 0, -10, 10, 0, 0, 10, -10, 0)
        love.graphics.pop()

        -- Núcleo de la baliza
        love.graphics.setColor(col[1], col[2], col[3], 0.95)
        love.graphics.circle("fill", b.x, b.y, 4, 12)

        -- Texto interactivo si el jugador está en rango
        local dist = math.sqrt((px - b.x)^2 + (py - b.y)^2)
        if dist <= b.radius * 1.6 then
            love.graphics.setColor(0.08, 0.12, 0.18, 0.85)
            love.graphics.rectangle("fill", b.x - 120, b.y - b.radius - 38, 240, 30, 4)
            love.graphics.setColor(col[1], col[2], col[3], 0.90)
            love.graphics.rectangle("line", b.x - 120, b.y - b.radius - 38, 240, 30, 4)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf("[E] " .. b.name, b.x - 118, b.y - b.radius - 30, 236, "center")
        end
    end
end

-- Comprobar si el jugador está interactuando con una baliza de salto
function CelestialRenderer.checkBeaconInteraction(sublevelConfig, player)
    local meta = sublevelConfig and sublevelConfig.meta
    local tier = (meta and meta.tier) or 1
    local tierDef = TauCetiDef.tiers[tier]
    if not tierDef or not tierDef.beacons or not player then return nil end

    local px, py = player.x or 0, player.y or 0
    for _, b in ipairs(tierDef.beacons) do
        local dist = math.sqrt((px - b.x)^2 + (py - b.y)^2)
        if dist <= b.radius * 1.6 then
            return b
        end
    end
    return nil
end

return CelestialRenderer
