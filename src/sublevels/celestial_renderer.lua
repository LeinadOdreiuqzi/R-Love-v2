-- src/sublevels/celestial_renderer.lua
-- Motor de Renderizado 2.5D para Submundos: Escenario Multi-Capa con Parallax Estelar y Shaders GPU

local CelestialRenderer = {
    initialized = false,
    whiteImage = nil,
    particles = {
        solarWind = {},
        asteroids = {},
        debris = {}
    }
}

local PlanetSphereShader = require 'src.shaders.planet_sphere'
local StarCoronaShader = require 'src.shaders.star_corona'
local EclipticPlaneShader = require 'src.shaders.ecliptic_plane'
local GasGiantShader = require 'src.shaders.gas_giant'
local PlanetaryRingShader = require 'src.shaders.planetary_ring'
local DeimosMoonShader = require 'src.shaders.deimos_moon'
local RockyPlanetShader = require 'src.shaders.rocky_planet'
local LunaEosShader = require 'src.shaders.luna_eos'
local MarsMoonShader = require 'src.shaders.mars_moon'
local TauCetiDef = require 'src.sublevels.definitions.tau_ceti'

function CelestialRenderer.init()
    if CelestialRenderer.initialized then return end

    PlanetSphereShader.init()
    StarCoronaShader.init()
    EclipticPlaneShader.init()
    GasGiantShader.init()
    PlanetaryRingShader.init()
    DeimosMoonShader.init()
    RockyPlanetShader.init()
    LunaEosShader.init()
    MarsMoonShader.init()

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

    -- 2. Inicializar partículas de viento solar de alta energía (Tier 2)
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

    -- 3. Inicializar escombros y satélites orbitales (Tier 3)
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
    local tier = (meta and meta.tier) or (sublevelConfig and sublevelConfig.tier) or 1
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local t = love.timer.getTime()

    if tier == 1 then
        CelestialRenderer.drawTier1ScenicBackground(TauCetiDef.tiers[1], camera, player, sw, sh, t)
    elseif tier == 3 then
        CelestialRenderer.drawTier3ScenicBackground(TauCetiDef.tiers[3], camera, player, sw, sh, t)
    end
end

-- ─── PROCEDURAL SHADER RENDERER PARA PLANETAS TELÚRICOS (TIER 1) ───────────

function CelestialRenderer.drawProceduralTerrestrialPlanet(p, px, py, radius, scenicScale, t, sunScreenX, sunScreenY, depth)
    local whiteImg = CelestialRenderer.whiteImage
    local pShader = PlanetSphereShader.getShader()
    local atmThick = p.atmThickness or 0.15
    local pPad = radius * (1.0 + atmThick) * 1.08

    local ldx = (sunScreenX - px)
    local ldy = (sunScreenY - py)
    local ldist = math.max(1.0, math.sqrt(ldx * ldx + ldy * ldy))
    local lightDir = { ldx / ldist, ldy / ldist, 0.55 }

    local colors = p.colors or {}
    local oceanCol = colors.ocean or { 0.22, 0.20, 0.22 }
    local landCol = colors.land or { 0.58, 0.52, 0.44 }
    local atmCol = colors.atmosphere or { 0.50, 0.75, 1.00 }

    -- 1. Calcular órbitas si el planeta telúrico posee lunas (ej. Tau Ceti d con Eos y Célere)
    local moonData = {}
    if p.moons then
        local tilt = -0.32
        local rotCos = math.cos(tilt)
        local rotSin = math.sin(tilt)
        local yFlatten = 0.28
        for _, m in ipairs(p.moons) do
            local mAngle = (m.phase or 0) + t * (m.speed or 0.25)
            local mCos = math.cos(mAngle)
            local mSin = math.sin(mAngle)
            local mDist = m.orbitRadius * scenicScale

            local unrotX = mCos * mDist
            local unrotY = mSin * mDist * yFlatten
            local mx = px + (unrotX * rotCos - unrotY * rotSin)
            local my = py + (unrotX * rotSin + unrotY * rotCos)
            local mRadius = math.max(2.0, m.size * scenicScale * 0.70)

            table.insert(moonData, {
                moon = m,
                x = mx,
                y = my,
                sinA = mSin,
                radius = mRadius
            })
        end

        -- Lunas en la mitad posterior (sinA < 0)
        for _, md in ipairs(moonData) do
            if md.sinA < 0 then
                local distCenter = math.sqrt((md.x - px)^2 + (md.y - py)^2)
                if distCenter > radius * 0.90 then
                    CelestialRenderer.drawProceduralTerrestrialPlanet(md.moon, md.x, md.y, md.radius, scenicScale, t, sunScreenX, sunScreenY, depth * 0.85)
                end
            end
        end
    end

    -- 2. Globo planetario
    if pShader and whiteImg then
        love.graphics.setShader(pShader)
        pShader:send("u_time", t)
        pShader:send("u_lightDir", lightDir)
        pShader:send("u_uvOffset", { t * (p.rotSpeed or 0.015), 0.0 })
        pShader:send("u_atmosphereThickness", atmThick)
        pShader:send("u_atmosphereColor", atmCol)
        pShader:send("u_oceanColor", oceanCol)
        pShader:send("u_landColor", landCol)
        pShader:send("u_specular", p.specular or 1.0)

        love.graphics.setColor(depth, depth, depth, 1.0)
        love.graphics.draw(whiteImg, px - pPad, py - pPad, 0, pPad * 2, pPad * 2)
        love.graphics.setShader()
    else
        love.graphics.setColor(landCol[1] * depth, landCol[2] * depth, landCol[3] * depth, 1.0)
        love.graphics.circle("fill", px, py, radius, 36)

        local shadowAngle = math.atan2(py - sunScreenY, px - sunScreenX)
        love.graphics.setColor(0.010, 0.015, 0.025, 0.85)
        love.graphics.arc("fill", px, py, radius + 0.5, shadowAngle - math.pi * 0.5, shadowAngle + math.pi * 0.5)
    end

    -- 3. Lunas en la mitad frontal (sinA >= 0)
    if p.moons and #moonData > 0 then
        for _, md in ipairs(moonData) do
            if md.sinA >= 0 then
                CelestialRenderer.drawProceduralTerrestrialPlanet(md.moon, md.x, md.y, md.radius, scenicScale, t, sunScreenX, sunScreenY, depth)
            end
        end
    end

    -- 4. Si el planeta es objetivo de salto (isTarget), dibujar retículo indicador sutil
    if p.isTarget then
        local retPulse = 0.65 + 0.35 * math.sin(t * 3.5)
        love.graphics.setColor(0.30, 0.90, 0.65, 0.60 * retPulse)
        love.graphics.setLineWidth(1.4)
        local rPad = radius + 9 * scenicScale
        love.graphics.circle("line", px, py, rPad, 32)
        local cLen = 6 * scenicScale
        love.graphics.line(px - rPad - cLen, py, px - rPad + cLen * 0.3, py)
        love.graphics.line(px + rPad - cLen * 0.3, py, px + rPad + cLen, py)
        love.graphics.line(px, py - rPad - cLen, px, py - rPad + cLen * 0.3)
        love.graphics.line(px, py + rPad - cLen * 0.3, px, py + rPad + cLen)
    end
end

-- ─── RENDERER DE SUPER-TIERRA ROCOSA (TIER 1 - TAU CETI d Y LUNAS EOS / CÉLERE) ─

function CelestialRenderer.drawRockyPlanetSystem(p, px, py, radius, scenicScale, t, sunScreenX, sunScreenY, depth)
    local whiteImg = CelestialRenderer.whiteImage
    local rockyShader = RockyPlanetShader.getShader()
    local eosShader = LunaEosShader.getShader()
    local atmThick = p.atmThickness or (p.atmosphereThickness or 0.22)
    local pPad = radius * (1.0 + atmThick) * 1.08

    -- Dirección solar dinámica 3D relativa a la estrella central Tau Ceti
    local ldx = (sunScreenX - px)
    local ldy = (sunScreenY - py)
    local ldist = math.max(1.0, math.sqrt(ldx * ldx + ldy * ldy))
    local lightDir = { ldx / ldist, ldy / ldist, 0.55 }

    local colors = p.colors or {}
    local atmCol = colors.atmosphere or { 0.98, 0.86, 0.38 }
    local landTerracotta = colors.terracotta or colors.land or { 0.58, 0.25, 0.13 }
    local landPlains = colors.plains or { 0.76, 0.62, 0.36 }
    local basinCol = colors.basin or colors.ocean or { 0.68, 0.84, 0.80 }
    local cloudWhite = colors.cloudWhite or { 0.94, 0.98, 0.95 }
    local cloudGreen = colors.cloudGreen or { 0.74, 0.86, 0.78 }

    -- 1. Calcular órbitas e inclinación 3D para cada luna (Luna Eos y Luna Célere)
    local moonData = {}
    if p.moons then
        local tilt = -0.32
        local rotCos = math.cos(tilt)
        local rotSin = math.sin(tilt)
        local yFlatten = 0.28
        for _, m in ipairs(p.moons) do
            local mAngle = (m.phase or 0) + t * (m.speed or 0.25)
            local mCos = math.cos(mAngle)
            local mSin = math.sin(mAngle)
            local mDist = m.orbitRadius * scenicScale

            local unrotX = mCos * mDist
            local unrotY = mSin * mDist * yFlatten
            local mx = px + (unrotX * rotCos - unrotY * rotSin)
            local my = py + (unrotX * rotSin + unrotY * rotCos)
            local mRadius = math.max(2.2, (m.size or 5.0) * scenicScale * 0.75)

            table.insert(moonData, {
                moon = m,
                x = mx,
                y = my,
                sinA = mSin,
                radius = mRadius
            })
        end
    end

    local function drawRockyMoon(md, mDepth)
        local m = md.moon
        local isEos = (m.id == "eos" or m.id == "moon_magenta" or m.shader == "luna_eos")
        if isEos and eosShader and whiteImg then
            local mAtm = m.atmThickness or 0.18
            local mPad = md.radius * (1.0 + mAtm) * 1.10
            local mColors = m.colors or {}
            love.graphics.setShader(eosShader)
            eosShader:send("u_time", t)
            eosShader:send("u_lightDir", lightDir)
            eosShader:send("u_uvOffset", { 0.22 + t * (m.rotSpeed or 0.015), 0.38 })
            eosShader:send("u_atmosphereThickness", mAtm)
            eosShader:send("u_atmosphereColor", mColors.atmosphere or { 0.98, 0.55, 0.80 })
            eosShader:send("u_landColor", mColors.land or { 0.85, 0.42, 0.62 })
            eosShader:send("u_oceanColor", mColors.ocean or { 0.35, 0.10, 0.25 })
            if eosShader:hasUniform("u_specular") then
                eosShader:send("u_specular", 0.0)
            end

            love.graphics.setColor(mDepth, mDepth, mDepth, 1.0)
            love.graphics.draw(whiteImg, md.x - mPad, md.y - mPad, 0, mPad * 2, mPad * 2)
            love.graphics.setShader()
        else
            CelestialRenderer.drawProceduralTerrestrialPlanet(m, md.x, md.y, md.radius, scenicScale, t, sunScreenX, sunScreenY, mDepth)
        end
    end

    -- 2. Lunas en la mitad posterior (sinA < 0)
    for _, md in ipairs(moonData) do
        if md.sinA < 0 then
            local distCenter = math.sqrt((md.x - px)^2 + (md.y - py)^2)
            if distCenter > radius * 0.90 then
                drawRockyMoon(md, depth * 0.85)
            end
        end
    end

    -- 3. Globo de la Super-Tierra Rocosa con RockyPlanetShader
    if rockyShader and whiteImg then
        love.graphics.setShader(rockyShader)
        rockyShader:send("u_time", t)
        rockyShader:send("u_lightDir", lightDir)
        rockyShader:send("u_uvOffset", { 0.18 + t * (p.rotSpeed or 0.008), 0.22 })
        rockyShader:send("u_atmosphereThickness", atmThick)
        rockyShader:send("u_atmosphereColor", atmCol)
        rockyShader:send("u_landTerracotta", landTerracotta)
        rockyShader:send("u_landPlains", landPlains)
        rockyShader:send("u_basinColor", basinCol)
        rockyShader:send("u_cloudWhite", cloudWhite)
        rockyShader:send("u_cloudGreen", cloudGreen)

        love.graphics.setColor(depth, depth, depth, 1.0)
        love.graphics.draw(whiteImg, px - pPad, py - pPad, 0, pPad * 2, pPad * 2)
        love.graphics.setShader()
    else
        love.graphics.setColor(landTerracotta[1] * depth, landTerracotta[2] * depth, landTerracotta[3] * depth, 1.0)
        love.graphics.circle("fill", px, py, radius, 48)
    end

    -- 4. Lunas en la mitad frontal (sinA >= 0)
    for _, md in ipairs(moonData) do
        if md.sinA >= 0 then
            drawRockyMoon(md, depth)
        end
    end

    -- 5. Retículo holográfico indicador de objetivo hacia Tier 3 (isTarget)
    if p.isTarget then
        local retPulse = 0.65 + 0.35 * math.sin(t * 3.5)
        love.graphics.setColor(0.30, 0.90, 0.65, 0.65 * retPulse * depth)
        love.graphics.setLineWidth(1.4)
        local rPad = radius + 9 * scenicScale
        love.graphics.circle("line", px, py, rPad, 32)
        local cLen = 6 * scenicScale
        love.graphics.line(px - rPad - cLen, py, px - rPad + cLen * 0.3, py)
        love.graphics.line(px + rPad - cLen * 0.3, py, px + rPad + cLen, py)
        love.graphics.line(px, py - rPad - cLen, px, py - rPad + cLen * 0.3)
        love.graphics.line(px, py + rPad - cLen * 0.3, px, py + rPad + cLen)
        love.graphics.setLineWidth(1.0)
    end
end

-- ─── RENDERER DEL SISTEMA JOVIANO: GIGANTE GASEOSO, ANILLOS Y LUNAS (TIER 1) ─

function CelestialRenderer.drawGasGiantSystem(p, px, py, radius, scenicScale, t, sunScreenX, sunScreenY, depth)
    local whiteImg = CelestialRenderer.whiteImage
    local gasShader = GasGiantShader.getShader()
    local gasR = radius
    local gasPad = gasR * (1.0 + (p.atmosphereThickness or 0.22)) * 1.08

    local ldx = (sunScreenX - px)
    local ldy = (sunScreenY - py)
    local ldist = math.max(1.0, math.sqrt(ldx * ldx + ldy * ldy))
    local lightDir = { ldx / ldist, ldy / ldist, 0.55 }

    local rings = p.rings
    local tilt = (rings and rings.tilt) or -0.38
    local yFlatten = (rings and rings.yFlatten) or 0.25
    local inR = gasR * ((rings and rings.innerRatio) or 1.25)
    local outR = gasR * ((rings and rings.outerRatio) or 2.30)
    local rCol = (rings and rings.color) or { 0.80, 0.94, 1.00, 0.65 }

    -- 1. Calcular órbitas e inclinación 3D para cada luna alrededor del gigante gaseoso
    local moonData = {}
    if p.moons then
        local rotCos = math.cos(tilt)
        local rotSin = math.sin(tilt)
        for _, m in ipairs(p.moons) do
            local mAngle = (m.phase or 0) + t * (m.speed or 0.25)
            local mCos = math.cos(mAngle)
            local mSin = math.sin(mAngle)
            local mDist = m.orbitRadius * scenicScale

            -- Proyección elíptica inclinada alineada con el plano de los anillos
            local unrotX = mCos * mDist
            local unrotY = mSin * mDist * yFlatten
            local mx = px + (unrotX * rotCos - unrotY * rotSin)
            local my = py + (unrotX * rotSin + unrotY * rotCos)
            local mRadius = math.max(2.2, m.size * scenicScale * 0.75)

            table.insert(moonData, {
                moon = m,
                x = mx,
                y = my,
                sinA = mSin,
                radius = mRadius
            })
        end
    end

    -- 2. Anillos planetarios helados (Mitad posterior: detrás del gigante gaseoso)
    if rings then
        CelestialRenderer.drawRing(px, py, tilt, inR, outR, rCol, yFlatten, -1.0, scenicScale, t)
    end

    -- 3. Lunas en la mitad posterior (sinA < 0)
    for _, md in ipairs(moonData) do
        if md.sinA < 0 then
            local distCenter = math.sqrt((md.x - px)^2 + (md.y - py)^2)
            -- Dibujar sólo si no está ocultada por el disco sólido del gigante
            if distCenter > gasR * 0.90 then
                CelestialRenderer.drawProceduralTerrestrialPlanet(md.moon, md.x, md.y, md.radius, scenicScale, t, sunScreenX, sunScreenY, depth * 0.85)
            end
        end
    end

    -- 4. Globo esférico del gigante gaseoso
    if gasShader and whiteImg then
        love.graphics.setShader(gasShader)
        gasShader:send("u_time", t)
        gasShader:send("u_lightDir", lightDir)
        gasShader:send("u_atmosphereThickness", p.atmosphereThickness or 0.22)
        gasShader:send("u_atmosphereColor", p.colors.atmosphere)
        gasShader:send("u_colorDeep", p.colors.deep)
        gasShader:send("u_colorMid", p.colors.mid)
        gasShader:send("u_colorLight", p.colors.light)
        gasShader:send("u_colorWhite", p.colors.white)

        love.graphics.setColor(depth, depth, depth, 1.0)
        love.graphics.draw(whiteImg, px - gasPad, py - gasPad, 0, gasPad * 2, gasPad * 2)
        love.graphics.setShader()
    else
        love.graphics.setColor(p.colors.mid[1] * depth, p.colors.mid[2] * depth, p.colors.mid[3] * depth, 1.0)
        love.graphics.circle("fill", px, py, gasR, 48)
    end

    -- 5. Anillos planetarios helados (Mitad frontal: pasando sobre el gigante gaseoso)
    if rings then
        CelestialRenderer.drawRing(px, py, tilt, inR, outR, rCol, yFlatten, 1.0, scenicScale, t)
    end

    -- 6. Lunas en la mitad frontal (sinA >= 0)
    for _, md in ipairs(moonData) do
        if md.sinA >= 0 then
            CelestialRenderer.drawProceduralTerrestrialPlanet(md.moon, md.x, md.y, md.radius, scenicScale, t, sunScreenX, sunScreenY, depth)

            -- Si es Tau Ceti IV (luna objetivo hacia Tier 3), dibujar retículo indicador sutil
            if md.moon.isTarget then
                local ping = 0.4 + 0.35 * math.sin(t * 4.5)
                love.graphics.setColor(0.30, 0.85, 1.00, ping * depth)
                love.graphics.setLineWidth(1.4)
                love.graphics.circle("line", md.x, md.y, md.radius + 3.5 + math.sin(t * 6.0) * 0.8)
                love.graphics.setLineWidth(1.0)
            end
        end
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

            local depth = 0.62 + 0.18 * (sinA * 0.5 + 0.5)
            local pRadius = p.size * 0.55 * scenicScale
            if p.type == "super_earth" or p.id == "tau_ceti_d" or p.shader == "rocky_planet" then
                CelestialRenderer.drawRockyPlanetSystem(p, px, py, pRadius, scenicScale, t, sunScreenX, sunScreenY, depth)
            elseif p.isGasGiant then
                CelestialRenderer.drawGasGiantSystem(p, px, py, pRadius, scenicScale, t, sunScreenX, sunScreenY, depth)
            else
                CelestialRenderer.drawProceduralTerrestrialPlanet(p, px, py, pRadius, scenicScale, t, sunScreenX, sunScreenY, depth)
            end
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

    -- ─── CAPA 6: PLANETAS ANTERIORES Y SUPER-TIERRA ROCOSA (sin >= 0) ──────────
    for _, p in ipairs(def.planets) do
        local curAngle = (p.phase or 0) + t * p.speed
        local sinA = math.sin(curAngle)
        if sinA >= 0 then
            local orbitR = p.orbitRadius * spreadMul
            local px = sunScreenX + math.cos(curAngle) * orbitR
            local py = sunScreenY + sinA * orbitR * yComp

            local depth = 0.85 + 0.15 * (sinA * 0.5 + 0.5)
            local pRadius = p.size * 0.68 * scenicScale
            if p.type == "super_earth" or p.id == "tau_ceti_d" or p.shader == "rocky_planet" then
                CelestialRenderer.drawRockyPlanetSystem(p, px, py, pRadius, scenicScale, t, sunScreenX, sunScreenY, depth)
            elseif p.isGasGiant then
                CelestialRenderer.drawGasGiantSystem(p, px, py, pRadius, scenicScale, t, sunScreenX, sunScreenY, depth)
            else
                CelestialRenderer.drawProceduralTerrestrialPlanet(p, px, py, pRadius, scenicScale, t, sunScreenX, sunScreenY, depth)
            end
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

    -- ─── 1. CÁLCULO DE POSICIÓN DEL PLANETA CENTRAL ROCOSO (Tau Ceti d) ───────
    local centralPlanet = def.centralPlanet or def.gasGiant
    local gasX, gasY, gasR = 0, 0, 0
    if centralPlanet then
        local psPlanet = centralPlanet.parallax or 0.008
        local sp = centralPlanet.screenPos or { xRatio = 0.68, yRatio = 0.82 }
        gasX = sw * sp.xRatio - (camX * psPlanet)
        gasY = sh * sp.yRatio - ((camY - 2900) * psPlanet)
        gasR = (centralPlanet.radius or 580) * scenicScale
    end

    -- Shaders para lunas
    local pShader = PlanetSphereShader.getShader()
    local eosShader = LunaEosShader.getShader()
    local marsShader = MarsMoonShader.getShader()

    -- Función auxiliar unificada para renderizado de cada luna
    local function drawSingleMoon(moon)
        local psMoon = moon.parallax or 0.015
        local mX = gasX + (moon.screenOffset.x or 0) * scenicScale - (camX * (psMoon - 0.008))
        local mY = gasY + (moon.screenOffset.y or 0) * scenicScale - ((camY - 2900) * (psMoon - 0.008))
        local mR = moon.radius * scenicScale

        local isMars = (moon.shader == "mars_moon") or (moon.isMars == true)
        local isEos = (moon.id == "moon_magenta") or (moon.shader == "luna_eos")
        local activeShader = isMars and marsShader or (isEos and eosShader or pShader)

        local atmThick = moon.atmosphereThickness or (isEos and 0.18 or (isMars and 0.15 or 0.16))
        local mPad = mR * (1.0 + atmThick) * 1.06

        if activeShader and whiteImg then
            love.graphics.setShader(activeShader)
            if activeShader:hasUniform("u_time") then
                activeShader:send("u_time", t)
            end
            if activeShader:hasUniform("u_lightDir") then
                activeShader:send("u_lightDir", (centralPlanet and centralPlanet.lightDir) or { 0.65, 0.45, 0.60 })
            end
            if activeShader:hasUniform("u_uvOffset") then
                activeShader:send("u_uvOffset", moon.uvOffset or (isMars and { 0.18, 0.25 } or { 0.22, 0.38 }))
            end
            if activeShader:hasUniform("u_atmosphereThickness") then
                activeShader:send("u_atmosphereThickness", atmThick)
            end

            if activeShader:hasUniform("u_atmosphereColor") and moon.color and moon.color.atmosphere then
                activeShader:send("u_atmosphereColor", moon.color.atmosphere)
            end
            if activeShader:hasUniform("u_oceanColor") and moon.color and moon.color.ocean then
                activeShader:send("u_oceanColor", moon.color.ocean)
            end
            if activeShader:hasUniform("u_basinColor") and moon.color then
                activeShader:send("u_basinColor", moon.color.basin or moon.color.ocean or { 0.30, 0.11, 0.08 })
            end
            if activeShader:hasUniform("u_landColor") and moon.color and moon.color.land then
                activeShader:send("u_landColor", moon.color.land)
            end
            if activeShader:hasUniform("u_ambientColor") and moon.color then
                activeShader:send("u_ambientColor", moon.color.ambient or { 0.24, 0.12, 0.08 })
            end
            if activeShader:hasUniform("u_specular") then
                activeShader:send("u_specular", moon.specular or 0.0)
            end

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(whiteImg, mX - mPad, mY - mPad, 0, mPad * 2, mPad * 2)
            love.graphics.setShader()
        else
            if moon.color and moon.color.land then
                love.graphics.setColor(moon.color.land[1], moon.color.land[2], moon.color.land[3], 1.0)
            else
                love.graphics.setColor(0.8, 0.4, 0.2, 1.0)
            end
            love.graphics.circle("fill", mX, mY, mR, 64)
        end

        -- Tributo a Marathon (si la luna tiene la nave incrustada)
        if moon.hasMarathon and def.marathonShip then
            CelestialRenderer.drawMarathonShip(def.marathonShip, mX, mY, mR, scenicScale, t)
        end
    end

    -- ─── 2. FASE A: LUNAS DE FONDO PROFUNDO (Detrás del planeta, en la zona de sombra) ───
    if def.backgroundMoons then
        for _, moon in ipairs(def.backgroundMoons) do
            if moon.renderBehind then
                drawSingleMoon(moon)
            end
        end
    end

    -- ─── 3. FASE B: EL PLANETA CENTRAL ROCOSO (Super-Tierra Tau Ceti d) ────────
    if centralPlanet then
        local rockyShader = RockyPlanetShader.getShader()
        local pad = gasR * (1.0 + (centralPlanet.atmosphereThickness or 0.22)) * 1.05
        if rockyShader and whiteImg then
            love.graphics.setShader(rockyShader)
            rockyShader:send("u_time", t)
            rockyShader:send("u_lightDir", centralPlanet.lightDir or { 0.65, 0.45, 0.60 })
            rockyShader:send("u_uvOffset", { 0.18 + t * 0.001, 0.22 })
            rockyShader:send("u_atmosphereThickness", centralPlanet.atmosphereThickness or 0.22)
            rockyShader:send("u_atmosphereColor", (centralPlanet.colors and centralPlanet.colors.atmosphere) or { 0.98, 0.86, 0.38 })
            rockyShader:send("u_landTerracotta", (centralPlanet.colors and centralPlanet.colors.terracotta) or { 0.58, 0.25, 0.13 })
            rockyShader:send("u_landPlains", (centralPlanet.colors and centralPlanet.colors.plains) or { 0.76, 0.62, 0.36 })
            rockyShader:send("u_basinColor", (centralPlanet.colors and centralPlanet.colors.basin) or { 0.68, 0.84, 0.80 })
            rockyShader:send("u_cloudWhite", (centralPlanet.colors and centralPlanet.colors.cloudWhite) or { 0.94, 0.98, 0.95 })
            rockyShader:send("u_cloudGreen", (centralPlanet.colors and centralPlanet.colors.cloudGreen) or { 0.74, 0.86, 0.78 })

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(whiteImg, gasX - pad, gasY - pad, 0, pad * 2, pad * 2)
            love.graphics.setShader()
        else
            love.graphics.setColor(0.68, 0.45, 0.20, 0.95)
            love.graphics.circle("fill", gasX, gasY, gasR, 120)
        end
    end

    -- ─── 4. FASE C: LUNAS EN PRIMER PLANO (Luna Eos con Marathon, Luna Célere) ───
    if def.backgroundMoons then
        for _, moon in ipairs(def.backgroundMoons) do
            if not moon.renderBehind then
                drawSingleMoon(moon)
            end
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

    local deimosX = -16.0
    local deimosY = 0.0
    local deimosW = 58.0
    local deimosH = 52.0

    local dShader = DeimosMoonShader.getShader()
    local whiteImg = CelestialRenderer.whiteImage

    local function sendDeimosUniforms(pass)
        local function safeSend(name, val)
            if dShader:hasUniform(name) then dShader:send(name, val) end
        end
        safeSend("u_lightDir", { 0.65, 0.45, 0.60 })
        safeSend("u_bounceColor", { 0.24, 0.15, 0.22 })
        safeSend("u_sunColor", { 1.00, 0.96, 0.90 })
        safeSend("u_rockLight", { 0.46, 0.46, 0.52 })
        safeSend("u_rockMid", { 0.24, 0.24, 0.28 })
        safeSend("u_rockDark", { 0.09, 0.09, 0.12 })
        safeSend("u_seed", 42.1)
        safeSend("u_pass", pass)
    end

    -- ========================================================================
    -- 1. FONDO INTERIOR CÓNCAVO DE LA CAVERNA (DETRÁS DE LA NAVE)
    -- ========================================================================
    if dShader and whiteImg then
        love.graphics.setShader(dShader)
        sendDeimosUniforms(1.0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(whiteImg, deimosX - deimosW * 0.5, deimosY - deimosH * 0.5, 0, deimosW, deimosH)
        love.graphics.setShader()
    end

    -- ========================================================================
    -- 2. EL ESPINAZO CONTINUO DE LA NAVE MARATHON (PRESERVADO INTACTO)
    -- ========================================================================

    -- 2.1 Popa / cola rectangular trasera (sale por la parte izquierda de Deimos)
    love.graphics.setColor(0.16, 0.38, 0.80, 1.0) -- Azul UESC
    love.graphics.rectangle("fill", -48, -2.2, 34, 4.4)
    -- Extremo plano de la popa (tapa de motores oscura)
    love.graphics.setColor(0.12, 0.14, 0.18, 1.0)
    love.graphics.rectangle("fill", -51, -2.6, 3.2, 5.2)

    -- 2.2 Aguja delantera principal (sale por la parte derecha de Deimos)
    -- Quilla ventral oscura
    love.graphics.setColor(0.10, 0.12, 0.16, 1.0)
    love.graphics.polygon("fill", 0, 2.0, 74, 1.0, 74, 2.5, 0, 3.5)

    -- Viga inferior (haz azul cobalto)
    love.graphics.setColor(0.18, 0.42, 0.84, 1.0)
    love.graphics.polygon("fill", 0, 0.3, 74, 0.2, 74, 2.0, 0, 2.0)

    -- Canal central longitudinal oscuro
    love.graphics.setColor(0.08, 0.10, 0.14, 1.0)
    love.graphics.polygon("fill", 0, -0.3, 74, -0.2, 74, 0.3, 0, 0.3)

    -- Viga superior (haz azul cobalto con reflejo dorsal)
    love.graphics.setColor(0.24, 0.50, 0.92, 1.0)
    love.graphics.polygon("fill", 0, -2.0, 74, -2.0, 74, -0.3, 0, -0.3)

    -- Placas celestes modulares en la superficie dorsal
    love.graphics.setColor(0.38, 0.70, 0.95, 0.95)
    love.graphics.rectangle("fill", 48, -2.0, 18, 0.8)
    love.graphics.rectangle("fill", 14, -2.0, 12, 0.8)

    -- Tapa frontal de la proa (punta biselada de grafito)
    love.graphics.setColor(0.12, 0.14, 0.18, 1.0)
    love.graphics.polygon("fill", 74, -2.0, 77, -1.4, 77, 1.4, 74, 2.0)

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
    -- 3. CAPARAZÓN EXTERIOR DE DEIMOS (PRIMER PLANO)
    -- ========================================================================
    if dShader and whiteImg then
        love.graphics.setShader(dShader)
        sendDeimosUniforms(2.0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(whiteImg, deimosX - deimosW * 0.5, deimosY - deimosH * 0.5, 0, deimosW, deimosH)
        love.graphics.setShader()
    end

    -- ========================================================================
    -- 5. INCRUSTACIÓN SENCILLA Y ELEGANTE (SIN CAJAS TOLETERAS)
    -- ========================================================================

    -- Franja de seguridad naranja en la salida de la aguja hacia el espacio
    love.graphics.setColor(0.98, 0.65, 0.12, 1.0)
    love.graphics.rectangle("fill", 1.8, -2.2, 2.0, 4.4)

    -- Sombra de contacto natural en la boca derecha
    love.graphics.setColor(0.06, 0.07, 0.09, 0.85)
    love.graphics.rectangle("fill", 0.6, -2.0, 1.2, 4.0)

    -- Sutil resalte de roca solar en el brocal superior derecho
    love.graphics.setColor(0.85, 0.82, 0.75, 0.80)
    love.graphics.line(0.4, -2.4, 1.8, -2.2)

    -- Sombra de contacto en la entrada de la popa izquierda
    love.graphics.setColor(0.05, 0.05, 0.07, 0.90)
    love.graphics.rectangle("fill", -35.2, -2.2, 1.4, 4.4)

    -- ========================================================================
    -- 6. ESCOMBROS ROCOSOS Y PARTÍCULAS FLOTANTES (REFERENCIA 3D)
    -- ========================================================================
    local debris = {
        { x = 5,   y = 11,  w = 2.4, h = 1.7, rot = 0.4 },
        { x = 12,  y = 15,  w = 2.8, h = 2.1, rot = -0.3 },
        { x = 20,  y = 13,  w = 2.0, h = 1.5, rot = 0.8 },
        { x = 28,  y = 17,  w = 2.5, h = 1.9, rot = -0.2 },
        { x = 36,  y = 14,  w = 1.8, h = 1.4, rot = 0.5 },
        { x = 46,  y = 18,  w = 2.2, h = 1.6, rot = -0.6 },
        { x = -4,  y = 23,  w = 2.7, h = 2.0, rot = 0.2 },
        { x = -15, y = 26,  w = 2.3, h = 1.7, rot = -0.5 },
        { x = -29, y = 22,  w = 2.5, h = 1.9, rot = 0.6 },
        { x = -11, y = -27, w = 3.0, h = 2.2, rot = 0.3 },
        { x = 6,   y = -23, w = 2.4, h = 1.8, rot = -0.4 },
        { x = -34, y = -17, w = 2.6, h = 2.0, rot = 0.7 }
    }

    for _, rf in ipairs(debris) do
        love.graphics.push()
        love.graphics.translate(rf.x, rf.y)
        love.graphics.rotate(rf.rot)
        love.graphics.setColor(0.46, 0.46, 0.52, 0.95)
        love.graphics.polygon("fill", -rf.w * 0.4, -rf.h * 0.5, rf.w * 0.5, -rf.h * 0.3, rf.w * 0.3, rf.h * 0.2, 0, 0)
        love.graphics.setColor(0.24, 0.24, 0.28, 0.95)
        love.graphics.polygon("fill", -rf.w * 0.5, 0, -rf.w * 0.4, -rf.h * 0.5, 0, 0, -rf.w * 0.3, rf.h * 0.4)
        love.graphics.setColor(0.10, 0.10, 0.13, 0.95)
        love.graphics.polygon("fill", -rf.w * 0.3, rf.h * 0.4, 0, 0, rf.w * 0.3, rf.h * 0.2, rf.w * 0.1, rf.h * 0.5)
        love.graphics.pop()
    end

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

-- ─── TIER 3: ÓRBITA BAJA DE TAU CETI d (ESPACIO ORBITAL JUGABLE) ───────────

function CelestialRenderer.drawTier3(def, camera, player, t)
    -- 1. Escombros orbitales y satélites de investigación en el espacio jugable
    for _, d in ipairs(CelestialRenderer.particles.debris) do
        local dx = math.cos(d.angle) * d.dist
        local dy = math.sin(d.angle) * d.dist

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

    -- 2. Balizas de navegación y salto
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

        -- 3. Estructura de la baliza / portal de salida
        if b.isExit then
            -- Portal Hiperespacial rotatorio con vórtice cuántico
            love.graphics.push()
            love.graphics.translate(b.x, b.y)
            love.graphics.rotate(t * 1.2)
            love.graphics.setColor(col[1], col[2], col[3], 0.75 * pulse)
            love.graphics.circle("line", 0, 0, 22, 6)
            love.graphics.rotate(-t * 2.4)
            love.graphics.setColor(0.95, 0.85, 1.0, 0.90)
            love.graphics.circle("line", 0, 0, 14, 6)
            love.graphics.pop()
        else
            -- Estructura de la boya de navegación (rombo holográfico rotatorio)
            love.graphics.push()
            love.graphics.translate(b.x, b.y)
            love.graphics.rotate(t * 0.8)
            love.graphics.setColor(col[1], col[2], col[3], 0.85)
            love.graphics.polygon("line", 0, -10, 10, 0, 0, 10, -10, 0)
            love.graphics.pop()
        end

        -- Núcleo de la baliza
        love.graphics.setColor(col[1], col[2], col[3], 0.95)
        love.graphics.circle("fill", b.x, b.y, b.isExit and 6 or 4, 16)

        -- Texto interactivo si el jugador está en rango
        local dist = math.sqrt((px - b.x)^2 + (py - b.y)^2)
        if dist <= b.radius * 1.6 then
            local bannerW = b.isExit and 320 or 250
            love.graphics.setColor(0.08, 0.12, 0.18, 0.85)
            love.graphics.rectangle("fill", b.x - bannerW * 0.5, b.y - b.radius - 38, bannerW, 30, 4)
            love.graphics.setColor(col[1], col[2], col[3], 0.90)
            love.graphics.rectangle("line", b.x - bannerW * 0.5, b.y - b.radius - 38, bannerW, 30, 4)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf("[E] " .. b.name, b.x - bannerW * 0.5 + 4, b.y - b.radius - 30, bannerW - 8, "center")
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
