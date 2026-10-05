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
local TauCetiDef = require 'src.sublevels.definitions.tau_ceti'

function CelestialRenderer.init()
    if CelestialRenderer.initialized then return end

    PlanetSphereShader.init()
    StarCoronaShader.init()
    EclipticPlaneShader.init()

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

    -- 3. Inicializar partículas de viento solar (Tier 2)
    local wind = TauCetiDef.tiers[2].solarWind
    for i = 1, (wind.particleCount or 180) do
        local angle = math.random() * math.pi * 2
        local dist = 1800 + math.random() * 3800
        table.insert(CelestialRenderer.particles.solarWind, {
            angle = angle,
            dist = dist,
            speed = (wind.baseSpeed or 320) * (0.7 + math.random() * 0.6),
            length = 15 + math.random() * 35,
            alpha = 0.3 + math.random() * 0.5
        })
    end

    -- 4. Inicializar escombros y satélites orbitales (Tier 3)
    local debrisConfig = TauCetiDef.tiers[3].orbitalDebris
    for i = 1, (debrisConfig.count or 60) do
        local angle = math.random() * math.pi * 2
        local dist = 1250 + math.random() * 1800
        table.insert(CelestialRenderer.particles.debris, {
            angle = angle,
            dist = dist,
            speed = 0.02 + math.random() * 0.025,
            size = 2.0 + math.random() * 4.0,
            blinkPhase = math.random() * math.pi * 2,
            isSatellite = (i % 8 == 0)
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

    -- Actualizar viento solar
    for _, p in ipairs(CelestialRenderer.particles.solarWind) do
        p.dist = p.dist + p.speed * dt
        if p.dist > 5800 then
            p.dist = 1800 + math.random() * 200
            p.angle = math.random() * math.pi * 2
        end
    end

    -- Actualizar escombros orbitales
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
    if tier ~= 1 then return end

    local def = TauCetiDef.tiers[1]
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local t = love.timer.getTime()
    local camX = (camera and camera.x) or 0
    local camY = (camera and camera.y) or 0
    local camZoom = (camera and camera.zoom) or 1.0

    -- Factor de escala suave para el escenario según el zoom de la cámara
    local scenicScale = math.max(0.70, math.min(1.40, 1.0 + (camZoom - 0.35) * 0.50))
    local whiteImg = CelestialRenderer.whiteImage
    local yComp = 0.12 -- Inclinación de canto rasante a ~7 grados (horizonte estelar realista)
    local spreadMul = (sw / 1920) * 0.25 * scenicScale

    -- ─── CAPA 1: DISCO ZODIACAL DE CANTO (Parallax profundo: 0.020) ───────────
    local psSun = 0.022
    local sunScreenX = sw * 0.5 - (camX * psSun)
    local sunScreenY = sh * 0.44 - (camY * psSun)

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

    -- ─── CAPA 2: CINTURÓN DE ASTEROIDES POSTERIOR (sin < -0.05, Parallax: 0.032) ───
    local psBeltBack = 0.032
    local bBackX = sw * 0.5 - (camX * psBeltBack)
    local bBackY = sh * 0.44 - (camY * psBeltBack)

    for _, ast in ipairs(CelestialRenderer.particles.asteroids) do
        local sinA = math.sin(ast.angle)
        if sinA < -0.05 then
            local dist = ast.dist * spreadMul
            local ax = bBackX + math.cos(ast.angle) * dist
            local ay = bBackY + sinA * dist * yComp
            local depth = 0.45 + 0.20 * (sinA * 0.5 + 0.5)
            love.graphics.setColor(ast.shade * depth, ast.shade * 0.92 * depth, ast.shade * 0.88 * depth, 0.45)
            love.graphics.circle("fill", ax, ay, ast.size * 0.68 * scenicScale, 4)
        end
    end

    -- ─── CAPA 3: PLANETAS POSTERIORES (sin < 0, Parallax: 0.038) ─────────────
    for _, p in ipairs(def.planets) do
        local curAngle = (p.phase or 0) + t * p.speed
        local sinA = math.sin(curAngle)
        if sinA < 0 then
            local psPlanet = 0.038
            local pCenterX = sw * 0.5 - (camX * psPlanet)
            local pCenterY = sh * 0.44 - (camY * psPlanet)
            local orbitR = p.orbitRadius * spreadMul
            local px = pCenterX + math.cos(curAngle) * orbitR
            local py = pCenterY + sinA * orbitR * yComp

            local depth = 0.65
            local pSize = p.size * 0.42 * scenicScale
            love.graphics.setColor(p.color[1] * depth, p.color[2] * depth, p.color[3] * depth, 0.75)
            love.graphics.circle("fill", px, py, pSize)

            if p.atmosphere then
                love.graphics.setColor(p.atmosphere[1], p.atmosphere[2], p.atmosphere[3], 0.30)
                love.graphics.circle("line", px, py, pSize + 1.2)
            end

            -- Etiqueta suave y elegante
            love.graphics.setColor(0.70, 0.80, 0.92, 0.55)
            love.graphics.printf(p.name, px - 60, py + pSize + 3, 120, "center")
        end
    end

    -- ─── CAPA 4: ESTRELLA CENTRAL TAU CETI (Parallax: 0.024) ──────────────────
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

    -- ─── CAPA 5: CINTURÓN DE ASTEROIDES ANTERIOR (sin >= -0.05, Parallax: 0.052) ─
    local psBeltFront = 0.052
    local bFrontX = sw * 0.5 - (camX * psBeltFront)
    local bFrontY = sh * 0.44 - (camY * psBeltFront)

    for _, ast in ipairs(CelestialRenderer.particles.asteroids) do
        local sinA = math.sin(ast.angle)
        if sinA >= -0.05 then
            local dist = ast.dist * spreadMul
            local ax = bFrontX + math.cos(ast.angle) * dist
            local ay = bFrontY + sinA * dist * yComp
            local depth = 0.75 + 0.25 * (sinA * 0.5 + 0.5)
            love.graphics.setColor(ast.shade * depth, ast.shade * 0.96 * depth, ast.shade * 0.90 * depth, 0.82)
            love.graphics.circle("fill", ax, ay, ast.size * 0.92 * scenicScale, 5)
        end
    end

    -- ─── CAPA 6: PLANETAS ANTERIORES Y TAU CETI IV (Parallax: 0.065 - 0.082) ───
    for _, p in ipairs(def.planets) do
        local curAngle = (p.phase or 0) + t * p.speed
        local sinA = math.sin(curAngle)
        if sinA >= 0 then
            local psPlanet = p.isTarget and 0.082 or 0.065
            local pCenterX = sw * 0.5 - (camX * psPlanet)
            local pCenterY = sh * 0.44 - (camY * psPlanet)
            local orbitR = p.orbitRadius * spreadMul
            local px = pCenterX + math.cos(curAngle) * orbitR
            local py = pCenterY + sinA * orbitR * yComp

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

                -- Anillo planetario fino de hielo
                love.graphics.setColor(0.45, 0.80, 1.0, 0.65)
                love.graphics.setLineWidth(1.8)
                love.graphics.ellipse("line", px, py, pRadius * 2.3, pRadius * 0.42)

                -- Indicador HUD sutil de objetivo
                love.graphics.setColor(0.35, 0.85, 1.0, 0.90)
                love.graphics.printf(p.name, px - 80, py + pRadius + 6, 160, "center")
            else
                local pRadius = p.size * 0.52 * scenicScale
                love.graphics.setColor(p.color[1], p.color[2], p.color[3], 1.0)
                love.graphics.circle("fill", px, py, pRadius)

                if p.atmosphere then
                    love.graphics.setColor(p.atmosphere[1], p.atmosphere[2], p.atmosphere[3], 0.55)
                    love.graphics.circle("line", px, py, pRadius + 2)
                end

                -- Sombra del terminador orientada opuesta a la estrella
                local shadowAngle = math.atan2(py - sunScreenY, px - sunScreenX)
                love.graphics.setColor(0.010, 0.015, 0.025, 0.80)
                love.graphics.arc("fill", px, py, pRadius + 0.5, shadowAngle - math.pi * 0.5, shadowAngle + math.pi * 0.5)

                love.graphics.setColor(0.85, 0.92, 1.0, 0.80)
                love.graphics.printf(p.name, px - 60, py + pRadius + 4, 120, "center")
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

    if shader and whiteImg then
        love.graphics.setShader(shader)
        shader:send("u_time", t)
        shader:send("u_surfaceColor", sun.surfaceColor)
        shader:send("u_coronaColor", sun.coronaColor)
        shader:send("u_deepCoronaColor", sun.deepCoronaColor)
        shader:send("u_flareIntensity", 1.4)

        local pad = sun.radius * 2.6
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(whiteImg, sun.x - pad, sun.y - pad, 0, pad * 2, pad * 2)
        love.graphics.setShader()
    else
        love.graphics.setColor(sun.surfaceColor[1], sun.surfaceColor[2], sun.surfaceColor[3], 0.9)
        love.graphics.circle("fill", sun.x, sun.y, sun.radius, 64)
    end

    -- Viento solar de alta energía
    love.graphics.setLineWidth(1.8)
    for _, p in ipairs(CelestialRenderer.particles.solarWind) do
        local startX = sun.x + math.cos(p.angle) * p.dist
        local startY = sun.y + math.sin(p.angle) * p.dist
        local endX = sun.x + math.cos(p.angle) * (p.dist + p.length)
        local endY = sun.y + math.sin(p.angle) * (p.dist + p.length)

        love.graphics.setColor(def.solarWind.color[1], def.solarWind.color[2], def.solarWind.color[3], p.alpha)
        love.graphics.line(startX, startY, endX, endY)
    end

    -- Advertencia de proximidad térmica
    if player then
        local px, py = player.x or 0, player.y or 0
        local distToSun = math.sqrt((px - sun.x)^2 + (py - sun.y)^2)
        if distToSun < sun.heatDamageDistance then
            local dangerFactor = 1.0 - (distToSun / sun.heatDamageDistance)
            local warnAlpha = (0.2 + 0.25 * math.sin(t * 8.0)) * dangerFactor
            love.graphics.setColor(1.0, 0.25, 0.1, warnAlpha)
            love.graphics.circle("line", px, py, 140)
        end
    end

    -- Balizas de navegación
    CelestialRenderer.drawBeacons(def.beacons, player, t)
end

-- ─── TIER 3: ÓRBITA BAJA DE TAU CETI IV (PSEUDO-ESFERA RAYMARCHED) ──────────

function CelestialRenderer.drawTier3(def, camera, player, t)
    local planet = def.planet
    local shader = PlanetSphereShader.getShader()
    local whiteImg = CelestialRenderer.whiteImage

    if shader and whiteImg then
        love.graphics.setShader(shader)

        local px = (player and player.x) or 0
        local py = (player and player.y) or 0
        local uvX = (px - planet.x) / (planet.radius * 7.5) + t * planet.rotationSpeed
        local uvY = (py - planet.y) / (planet.radius * 7.5)

        shader:send("u_time", t)
        shader:send("u_lightDir", planet.lightDir)
        shader:send("u_uvOffset", { uvX, uvY })
        shader:send("u_atmosphereThickness", planet.atmosphereThickness)
        shader:send("u_atmosphereColor", planet.atmosphere.dayColor)
        shader:send("u_oceanColor", planet.surface.oceanColor)
        shader:send("u_landColor", planet.surface.landColor)
        shader:send("u_specular", planet.surface.specularIntensity)

        local pad = planet.radius * (1.0 + planet.atmosphereThickness) * 1.05
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(whiteImg, planet.x - pad, planet.y - pad, 0, pad * 2, pad * 2)
        love.graphics.setShader()
    else
        love.graphics.setColor(0.2, 0.5, 0.85, 0.9)
        love.graphics.circle("fill", planet.x, planet.y, planet.radius, 64)
    end

    -- Escombros orbitales y satélites
    for _, d in ipairs(CelestialRenderer.particles.debris) do
        local dx = planet.x + math.cos(d.angle) * d.dist
        local dy = planet.y + math.sin(d.angle) * d.dist

        if d.isSatellite then
            love.graphics.setColor(0.85, 0.88, 0.92, 0.9)
            love.graphics.rectangle("fill", dx - 3, dy - 2, 6, 4)
            love.graphics.setColor(0.25, 0.55, 0.85, 0.75)
            love.graphics.rectangle("fill", dx - 8, dy - 1, 4, 2)
            love.graphics.rectangle("fill", dx + 4, dy - 1, 4, 2)
            local blink = math.sin(t * 5.0 + d.blinkPhase) > 0.5
            if blink then
                love.graphics.setColor(0.3, 1.0, 0.4, 0.95)
                love.graphics.circle("fill", dx, dy, 1.8)
            end
        else
            love.graphics.setColor(0.55, 0.60, 0.68, 0.6)
            love.graphics.circle("fill", dx, dy, d.size, 5)
        end
    end

    -- Balizas de navegación
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
