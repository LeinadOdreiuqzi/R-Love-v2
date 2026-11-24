-- src/sublevels/nebulae_debug_world.lua
-- Sistema de visualización, banco de pruebas y laboratorio interactivo de nebulosas
-- Permite testear la generación procedural aleatoria o parametrizada (Forma A / Forma B / Biomas / Armonías)

local NebulaeDebugDef = require 'src.sublevels.definitions.nebulae_debug'
local ColorHarmony = require 'src.utils.color_harmony'
local NebulasShaders = require 'src.shaders.nebulas_shaders'
local Volume = require 'src.shaders.nebula_volume'
local Material = require 'src.maps.nebula_material'
local Shape = require 'src.maps.nebula_shape'
local OptimizedRenderer = require 'src.maps.optimized_renderer'
local ShaderManager = require 'src.shaders.shader_manager'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'
local SeedSystem = require 'src.utils.seed_system'

local NebulaeDebugWorld = {
    nebulae = {},
    viewMode = "focus",     -- "focus" (1 nebulosa central) o "gallery" (6 nebulosas comparativas)
    showHUD = true,
    closestNebula = nil,
    volumetric = true,
    materialView = 0,
    
    -- Opciones configurables para generación específica
    options = {
        colorModeIndex = 1,     -- 1: "RANDOM", 2: "A" (Mono-Tono), 3: "B" (Bi-Tonal)
        biomeIndex = 1,         -- 1: "ALL", 2..7: Biomas específicos
        harmonyIndex = 1,       -- 1: "ALL", 2..6: Armonías específicas
        tierIndex = 2,          -- 1: small, 2: medium, 3: large, 4: gigantic
        hueIndex = 1,           -- 1: Libre 360°, 2..9: Matices fijos
        morphologyIndex = 1,    -- Aleatoria, difusa, anular, bipolar, filamentosa o abanico
        aspectRatioIndex = 1,   -- 1: Libre/Orgánico, 2: Circular 1:1, 3: Elíptica Horiz, 4: Elíptica Vert
        seed = 10101
    }
}

-- Listas de opciones
local COLOR_MODES = Material.colorModes

local MATERIAL_VIEWS = {"Composición", "Gas difuso", "Frente iluminado", "Absorción por polvo", "Luz dispersada por polvo"}
local EMISSION_MODES = {"Balance regional", "Gas dominante", "Frente intenso"}

local MORPHOLOGIES = {
    { id = nil, name = "Aleatoria / Mixta" },
    { id = 0,   name = "Difusa Clásica" },
    { id = 1,   name = "Anular / Bubble" },
    { id = 2,   name = "Bipolar / Alas" },
    { id = 3,   name = "Filamentosa / Velo" },
    { id = Shape.FAN, name = "Abanico de emisión" }
}

local function morphologyName(cloud)
    local id = (NebulaeDebugWorld.volumetric and cloud.visualMorphology) or cloud.morphology or 0
    return (MORPHOLOGIES[id+2] or MORPHOLOGIES[2]).name
end

local ASPECT_RATIOS = {
    { id = nil,  name = "Orgánico Libre (0.75-1.35x)" },
    { id = 1.00, name = "Circular Puro (1.0x)" },
    { id = 1.35, name = "Elíptica Horiz (1.35x)" },
    { id = 0.74, name = "Elíptica Vert (0.74x)" }
}

local BIOMES = {
    { id = nil, name = "Aleatorio (Todos los biomas)" },
    { id = BiomeSystem.BiomeType.NEBULA_FIELD, name = "NEBULA FIELD (Cuna Estelar)" },
    { id = BiomeSystem.BiomeType.RADIOACTIVE_ZONE, name = "RADIOACTIVE ZONE (Plasma Ionizado)" },
    { id = BiomeSystem.BiomeType.GRAVITY_ANOMALY, name = "GRAVITY ANOMALY (Lente Gravitacional)" },
    { id = BiomeSystem.BiomeType.ASTEROID_BELT, name = "ASTEROID BELT (Polvo de Silicato)" },
    { id = BiomeSystem.BiomeType.ANCIENT_RUINS, name = "ANCIENT RUINS (Resonancia Arcana)" },
    { id = BiomeSystem.BiomeType.DEEP_SPACE, name = "DEEP SPACE (Éter Frío Sereno)" }
}

local HARMONIES = Material.harmonies

local TIERS = {
    { name = "small",    label = "Pequeña",   radius = 280,  scale = 1.0 },
    { name = "medium",   label = "Mediana",    radius = 420,  scale = 1.3 },
    { name = "large",    label = "Grande",     radius = 650,  scale = 1.8 },
    { name = "gigantic", label = "Gigantesca", radius = 950,  scale = 2.4 }
}

local HUES = Material.hues

-- Función para construir una nebulosa con parámetros específicos o procedurales
local function buildNebula(params)
    local seed = params.seed or math.random(1, 999999)
    local rng = SeedSystem.makeRNG(seed)

    local bType = params.biomeType or BiomeSystem.BiomeType.NEBULA_FIELD
    local mode = params.colorMode

    -- El generador de la silueta conserva el recorrido original de la semilla.
    -- Los ajustes de color del laboratorio usan un RNG aparte.
    local colorObj, harmony = ColorHarmony.generateNebulaColor(rng, bType, seed, params.layoutMode)
    local colorRng = SeedSystem.makeRNG(seed)
    if mode ~= params.layoutMode then
        colorObj, harmony = ColorHarmony.generateNebulaColor(colorRng, bType, seed, mode)
    end
    
    -- Si se forzó un matiz específico
    if params.fixedHue then
        local baseH = params.fixedHue
        local profile = ColorHarmony.ENERGY_PROFILES.NEBULA_FIELD
        if type(bType) == "number" then
            local pNames = {[1]="DEEP_SPACE",[2]="NEBULA_FIELD",[3]="ASTEROID_BELT",[4]="GRAVITY_ANOMALY",[5]="RADIOACTIVE_ZONE",[6]="ANCIENT_RUINS"}
            profile = ColorHarmony.ENERGY_PROFILES[pNames[bType]] or profile
        end
        local palCount = (colorObj.mode == "B") and 2 or 1
        local r, g, b = ColorHarmony.hsv2rgb(baseH, (profile.satRange and profile.satRange[2]) or 0.95, (profile.valRange and profile.valRange[2]) or 0.90)
        local pal = ColorHarmony.generateHarmonicPalette(colorRng, params.harmony or harmony, {r, g, b}, palCount, profile.satRange, profile.valRange)
        colorObj[1], colorObj[2], colorObj[3] = pal[1][1], pal[1][2], pal[1][3]
        if pal[2] then
            colorObj.core = { pal[2][1], pal[2][2], pal[2][3], profile.coreAlpha or 0.60 }
        else
            colorObj.core = { pal[1][1], pal[1][2], pal[1][3], profile.coreAlpha or 0.60 }
        end
    end

    local tier = params.tier or TIERS[2]
    local radius = tier.radius

    local morph = params.morphology
    if morph == nil then
        local mRoll = rng:random()
        morph = (mRoll < 0.25 and 1) or (mRoll < 0.50 and 2) or (mRoll < 0.75 and 3) or 0
    elseif morph == Shape.FAN then
        morph = 0
    end

    local aspect = params.aspectRatio
    if aspect == nil then
        aspect = rng:randomRange(0.74, 1.35)
    end

    local neb = {
        x = params.x or 0,
        y = params.y or 0,
        size = radius,
        radius = radius,
        seed = seed,
        color = colorObj,
        coreColor = colorObj.core or colorObj,
        colorMode = colorObj.mode or (mode or "A"),
        harmony = harmony or colorObj.harmony or "cosmic",
        energyStyle = colorObj.energyStyle or "Standard",
        sparkleStrength = colorObj.sparkle or 0.0,
        biomeType = bType,
        tierName = tier.name,
        noiseScale = rng:randomRange(1.8, 3.2),
        warpAmp = rng:randomRange(0.40, 0.90),
        warpFreq = rng:randomRange(0.8, 1.8),
        softness = rng:randomRange(0.20, 0.38),
        brightness = rng:randomRange(1.15, 1.35),
        parallax = 1.0,
        rotation = params.rotation or rng:randomRange(0, math.pi * 2),
        aspectRatio = aspect,
        morphology = morph,
        visualMorphology = params.morphology or Shape.visualMorphology(seed,morph),
        irregularity = rng:randomRange(0.25, 0.55)
    }

    -- Aplicar modulaciones por bioma
    if bType == BiomeSystem.BiomeType.RADIOACTIVE_ZONE then
        neb.warpAmp = neb.warpAmp * 1.3
        neb.sparkleStrength = rng:randomRange(0.25, 0.50)
        neb.brightness = neb.brightness * 1.15
    elseif bType == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        neb.warpAmp = neb.warpAmp * 1.4
        neb.warpFreq = neb.warpFreq * 0.75
        neb.softness = math.max(0.14, neb.softness - 0.06)
    elseif bType == BiomeSystem.BiomeType.DEEP_SPACE then
        neb.softness = math.min(0.48, neb.softness + 0.08)
        neb.sparkleStrength = 0.0
    elseif bType == BiomeSystem.BiomeType.ANCIENT_RUINS then
        neb.sparkleStrength = rng:randomRange(0.18, 0.35)
    end

    return neb
end

-- ============================================================================
-- GENERACIÓN DE ESCENARIOS EN EL MUNDO
-- ============================================================================

local function buildOrion(frame)
    local r = frame.radius
    local x, y = frame.x-.26*r, frame.y-.09*r
    -- El encuadre de la primera foto usa los mismos parámetros de corriente
    -- que una nube del mapa. La fuente se expresa en unidades del mundo.
    local neb = buildNebula({seed = 424210, x = x, y = y, rotation = 0, aspectRatio = 1, morphology = 0})
    neb.radius, neb.size = r, r
    -- El grano usa un radio fijo para reproducir la referencia en cualquier encuadre.
    neb.dustRadius = TIERS[3].radius
    neb.noiseScale, neb.warpAmp, neb.warpFreq = 2.65, .48, .93
    neb.intensity, neb.brightness, neb.color[4] = .88, 1.48, .75
    neb.structure = Shape.orionFan
    local region = {
        gas = {.28,.019,.49,.85}, front = {.97,.068,.41,1.30},
        outerGas = {.05962,.104843,.86038},
        lightX = x-.08*r, lightY = y+.27*r, reach = 1.10*r
    }
    -- El nudo al otro lado del frente oscuro tiene su propia fuente local.
    local knotFraction = .205
    local sx, sy, sr = x-.43*r, y+.45*r, knotFraction*r
    local knot = buildNebula({seed = 431042, x = sx, y = sy, rotation = 0, aspectRatio = 1, morphology = 0})
    knot.size, knot.radius = sr, sr
    knot.dustRadius = neb.dustRadius * knotFraction
    knot.intensity, knot.brightness, knot.color[4] = .83, 1.35, .72
    knot.structure = {
        {0,.05,.08,-.997}, {.84,.69,-.10,.27},
        {-.79,.613,.78,.36}, {-.28,.58,.54,.19},
        {.20,-.16,.19,.13}, {.32,3.1,.15,.91}
    }
    knot.emissionRegion = {
        gas = {.26,.045,.49,.89}, front = {.89,.17,.51,1.15},
        outerGas = {.05910,.107365,.86090},
        lightX = sx, lightY = sy, reach = sr
    }
    return {neb, knot}, region
end

function NebulaeDebugWorld.regenerate()
    if NebulaeDebugWorld.reference then
        NebulaeDebugWorld.nebulae, NebulaeDebugWorld.region = buildOrion(NebulaeDebugWorld.reference)
        return
    end
    NebulaeDebugWorld.nebulae = {}
    local opt = NebulaeDebugWorld.options
    local bChoice = BIOMES[opt.biomeIndex].id
    local mChoice = COLOR_MODES[opt.colorModeIndex].id
    local hChoice = HARMONIES[opt.harmonyIndex].id
    local tChoice = TIERS[opt.tierIndex]
    local hueChoice = HUES[opt.hueIndex].val
    local morphChoice = MORPHOLOGIES[opt.morphologyIndex].id
    local aspectChoice = ASPECT_RATIOS[opt.aspectRatioIndex].id
    local chunk = MapConfig.chunk
    local span = NebulaeDebugWorld.viewMode == "focus" and tChoice.radius * 2.6
        or (chunk.size * chunk.tileSize + chunk.spacing) * chunk.worldScale
    NebulaeDebugWorld.region = Material.createRegion(opt.seed, 0, 0, span, hueChoice, hChoice, mChoice)

    if NebulaeDebugWorld.viewMode == "focus" then
        -- VISTA FOCO: 1 Nebulosa central grande
        local neb = buildNebula({
            x = 0,
            y = 0,
            seed = opt.seed,
            biomeType = bChoice or BiomeSystem.BiomeType.NEBULA_FIELD,
            colorMode = mChoice,
            harmony = hChoice,
            tier = tChoice,
            fixedHue = hueChoice,
            morphology = morphChoice,
            aspectRatio = aspectChoice
        })
        table.insert(NebulaeDebugWorld.nebulae, neb)
    else
        -- VISTA GALERÍA: 6 Nebulosas en formación (3 Forma A arriba, 3 Forma B abajo)
        local spacingX = 1800
        local startX = -spacingX
        local rowY_A = -900
        local rowY_B = 900

        local biomesList = {
            BiomeSystem.BiomeType.NEBULA_FIELD,
            BiomeSystem.BiomeType.RADIOACTIVE_ZONE,
            BiomeSystem.BiomeType.GRAVITY_ANOMALY,
            BiomeSystem.BiomeType.ASTEROID_BELT,
            BiomeSystem.BiomeType.ANCIENT_RUINS,
            BiomeSystem.BiomeType.DEEP_SPACE
        }

        for col = 1, 3 do
            local posX = startX + (col - 1) * spacingX
            local currentBiome = bChoice or biomesList[col]
            local nebA = buildNebula({
                x = posX,
                y = rowY_A,
                seed = opt.seed + col * 101,
                biomeType = currentBiome,
                colorMode = "A",
                layoutMode = "A",
                harmony = hChoice,
                tier = tChoice,
                fixedHue = hueChoice,
                morphology = morphChoice,
                aspectRatio = aspectChoice
            })
            table.insert(NebulaeDebugWorld.nebulae, nebA)

            local currentBiomeB = bChoice or biomesList[col + 3]
            local nebB = buildNebula({
                x = posX,
                y = rowY_B,
                seed = opt.seed + col * 202,
                biomeType = currentBiomeB,
                colorMode = "B",
                layoutMode = "B",
                harmony = hChoice,
                tier = tChoice,
                fixedHue = hueChoice,
                morphology = morphChoice,
                aspectRatio = aspectChoice
            })
            table.insert(NebulaeDebugWorld.nebulae, nebB)
        end
    end
end

function NebulaeDebugWorld.init(cfg)
    NebulaeDebugWorld.reference = nil
    NebulaeDebugWorld.options.seed = math.random(10000, 99999)
    NebulaeDebugWorld.viewMode = "focus"
    NebulaeDebugWorld.materialView = 0
    NebulaeDebugWorld.volumetric = MapConfig.nebulae.volumetric
    NebulaeDebugWorld.showHUD = true
    NebulaeDebugWorld.regenerate()
end

-- ============================================================================
-- ACTUALIZACIÓN
-- ============================================================================

function NebulaeDebugWorld.update(dt, player)
    -- Limitar jugador dentro del perímetro acotado (-3500 a 3500)
    if player then
        local maxDist = 3400
        if player.x < -maxDist then player.x = -maxDist; if player.dx then player.dx = math.max(0, player.dx) end end
        if player.x > maxDist then player.x = maxDist; if player.dx then player.dx = math.min(0, player.dx) end end
        if player.y < -maxDist then player.y = -maxDist; if player.dy then player.dy = math.max(0, player.dy) end end
        if player.y > maxDist then player.y = maxDist; if player.dy then player.dy = math.min(0, player.dy) end end
    end

    -- Identificar la nebulosa más cercana al jugador para telemetría
    local px = (player and player.x) or 0
    local py = (player and player.y) or 0
    local closest = nil
    local minDist = math.huge
    for _, neb in ipairs(NebulaeDebugWorld.nebulae) do
        local dx = neb.x - px
        local dy = neb.y - py
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < minDist then
            minDist = dist
            closest = neb
        end
    end
    NebulaeDebugWorld.closestNebula = closest
end

-- ============================================================================
-- RENDERIZADO DENTRO DE camera:apply()
-- ============================================================================

local function drawGrid(t)
    local maxDist = 3400
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.12, 0.20, 0.35, 0.22)
    for x = -maxDist, maxDist, 500 do
        love.graphics.line(x, -maxDist, x, maxDist)
    end
    for y = -maxDist, maxDist, 500 do
        love.graphics.line(-maxDist, y, maxDist, y)
    end

    -- Valla perimetral de contención
    local borderPulse = 0.6 + 0.4 * math.sin(t * 3.0)
    love.graphics.setColor(0.85, 0.45, 0.95, 0.40 * borderPulse)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", -maxDist, -maxDist, maxDist * 2, maxDist * 2)
    love.graphics.setLineWidth(1)

    -- Balizas luminosas en las esquinas
    love.graphics.setColor(1.0, 0.4, 0.9, 0.8 * borderPulse)
    love.graphics.circle("fill", -maxDist, -maxDist, 12)
    love.graphics.circle("fill", maxDist, -maxDist, 12)
    love.graphics.circle("fill", maxDist, maxDist, 12)
    love.graphics.circle("fill", -maxDist, maxDist, 12)
end

function NebulaeDebugWorld.draw(camera, player)
    local t = NebulaeDebugWorld.reference and 7 or love.timer.getTime()
    if not NebulaeDebugWorld.reference then drawGrid(t) end
    -- 2. Renderizar cada nebulosa utilizando NebulasShaders
    local shader = NebulasShaders.getShader and NebulasShaders.getShader()
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle")
    if not shader or not img then return end

    local iw, ih = img:getWidth(), img:getHeight()
    local scaleFactor = 2.0 / math.max(1, iw)
    local halfIw, halfIh = iw * 0.5, ih * 0.5

    -- PASO A: CUERPO PRINCIPAL DE LA NEBULOSA (Shader + Blend Aditivo)
    local oldBlend, oldAlphaMode = love.graphics.getBlendMode()
    if NebulaeDebugWorld.volumetric then
        Volume.begin(shader, NebulaeDebugWorld.materialView)
    else
        love.graphics.setBlendMode("add","alphamultiply")
    end
    NebulasShaders.setShader()

    for _, neb in ipairs(NebulaeDebugWorld.nebulae) do
        local cr, cg, cb = neb.color[1] or 1, neb.color[2] or 1, neb.color[3] or 1
        local ca = (neb.color[4] or 0.35) * 1.30
        local brightness = neb.brightness
        if NebulaeDebugWorld.volumetric then
            Volume.setCloud(shader, neb.emissionRegion or NebulaeDebugWorld.region, neb.x, neb.y, neb)
            ca = (neb.color[4] or .35) * 1.25
            brightness = OptimizedRenderer.calculateNebulaBrightness(neb, t)
        end

        local core = neb.coreColor or {cr, cg, cb}
        local coreR, coreG, coreB = core[1] or cr, core[2] or cg, core[3] or cb

        NebulasShaders.configureForNebula({
            seed = neb.seed or 0,
            noiseScale = neb.noiseScale or 2.5,
            warpAmp = neb.warpAmp or 0.5,
            warpFreq = neb.warpFreq or 1.0,
            softness = neb.softness or 0.28,
            intensity = neb.intensity,
            brightness = brightness or 1.25,
            parallax = 1.0,
            sparkleStrength = neb.sparkleStrength or 0.0,
            coreColor = { coreR, coreG, coreB },
            morphology = neb.morphology or 0.0,
            irregularity = neb.irregularity or 0.35
        }, t)

        local scale = neb.radius * scaleFactor
        local aspect = neb.aspectRatio or 1.0
        local rot = neb.rotation or 0.0
        local scaleX = scale * aspect
        local scaleY = scale / aspect
        love.graphics.setColor(cr, cg, cb, ca)
        love.graphics.draw(img, neb.x, neb.y, rot, scaleX, scaleY, halfIw, halfIh)
    end

    if NebulaeDebugWorld.volumetric then Volume.finish(shader) end
    NebulasShaders.unsetShader()
    if NebulaeDebugWorld.reference then
        love.graphics.setBlendMode(oldBlend, oldAlphaMode)
        love.graphics.setColor(1,1,1,1)
        return
    end

    love.graphics.setBlendMode("alpha", "alphamultiply")
    for _, neb in ipairs(NebulaeDebugWorld.nebulae) do

        -- Marcador de centro e información en el espacio del mundo
        love.graphics.setColor(0.3, 0.8, 1.0, 0.4)
        love.graphics.circle("line", neb.x, neb.y, 16)
        love.graphics.circle("fill", neb.x, neb.y, 3)

        local modeLabel = NebulaeDebugWorld.volumetric and EMISSION_MODES[NebulaeDebugWorld.options.colorModeIndex]
            or ((neb.colorMode == "B") and "[FORMA B: BI-TONAL]" or "[FORMA A: MONO-TONO]")
        local bName = "NEBULA"
        if type(neb.biomeType) == "number" then
            local pNames = {[1]="DEEP SPACE",[2]="NEBULA FIELD",[3]="ASTEROID BELT",[4]="GRAVITY ANOMALY",[5]="RADIOACTIVE ZONE",[6]="ANCIENT RUINS"}
            bName = pNames[neb.biomeType] or "NEBULA"
        end

        local morphLabel = morphologyName(neb)
        love.graphics.setColor(1, 1, 1, 0.85)
        local harmonyLabel = NebulaeDebugWorld.volumetric and "Luz regional" or neb.harmony
        love.graphics.printf(string.format("%s\n%s • %s\n%s", modeLabel, bName, morphLabel, harmonyLabel), neb.x - 200, neb.y + neb.radius * 0.45 + 30, 400, "center")
    end

    love.graphics.setBlendMode(oldBlend, oldAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- INTERFAZ DE USUARIO (HUD DE LABORATORIO)
-- ============================================================================

function NebulaeDebugWorld.drawHUD()
    if NebulaeDebugWorld.reference then
        if NebulaeDebugWorld.showHUD then
            love.graphics.setColor(.04,.06,.12,.86)
            love.graphics.rectangle("fill",20,20,350,61,7,7)
            love.graphics.setColor(1,1,1,1)
            love.graphics.print("Referencia de Orión  ·  "..MATERIAL_VIEWS[NebulaeDebugWorld.materialView+1],32,29)
            love.graphics.print("[G] Volver     [J] Material     [TAB] Ocultar",32,53)
        end
        return
    end
    if not NebulaeDebugWorld.showHUD then
        love.graphics.setColor(0.8, 0.85, 1.0, 0.6)
        love.graphics.printf("[TAB] Mostrar HUD de Laboratorio", 20, 20, 400, "left")
        return
    end

    local opt = NebulaeDebugWorld.options
    local sw = love.graphics.getWidth()

    -- Panel superior de estado y controles
    local panelW = 470
    local panelH = NebulaeDebugWorld.volumetric and 412 or 390
    local panelX = 20
    local panelY = 20

    love.graphics.setColor(0.04, 0.06, 0.12, 0.88)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(0.85, 0.45, 0.95, 0.75)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)

    -- Encabezado
    love.graphics.setColor(0.95, 0.65, 1.0, 1.0)
    love.graphics.printf("★ LABORATORIO DE NEBULOSAS (DEBUG) ★", panelX + 15, panelY + 12, panelW - 30, "left")

    local modeStr = NebulaeDebugWorld.volumetric and EMISSION_MODES[opt.colorModeIndex] or COLOR_MODES[opt.colorModeIndex].name
    local biomeStr = BIOMES[opt.biomeIndex].name
    local harmStr = HARMONIES[opt.harmonyIndex].name
    local tierStr = TIERS[opt.tierIndex].label .. " (" .. TIERS[opt.tierIndex].radius .. "px)"
    local hueStr = HUES[opt.hueIndex].name
    local morphStr = MORPHOLOGIES[opt.morphologyIndex].name
    if not NebulaeDebugWorld.volumetric and MORPHOLOGIES[opt.morphologyIndex].id == Shape.FAN then
        morphStr = MORPHOLOGIES[2].name
    end
    local aspectStr = ASPECT_RATIOS[opt.aspectRatioIndex].name
    local viewStr = (NebulaeDebugWorld.viewMode == "focus") and "1x Nebulosa Central (Foco)" or "6x Galería Comparativa (3x A / 3x B)"
    if NebulaeDebugWorld.volumetric and NebulaeDebugWorld.viewMode == "gallery" then
        viewStr = "6 nebulosas con luz compartida"
    end

    local y = panelY + 38
    local function printRow(label, value, keyHint, valColor)
        love.graphics.setColor(0.65, 0.75, 0.88, 0.90)
        love.graphics.print(label, panelX + 15, y)
        love.graphics.setColor(valColor or {0.35, 0.95, 0.85, 1.0})
        love.graphics.print(value, panelX + 130, y)
        love.graphics.setColor(1.0, 0.85, 0.35, 0.85)
        love.graphics.printf(keyHint, panelX + panelW - 100, y, 85, "right")
        y = y + 22
    end

    printRow("Render", NebulaeDebugWorld.volumetric and "Volumétrico" or "Original", "[L]")
    if NebulaeDebugWorld.volumetric then
        printRow("Material", MATERIAL_VIEWS[NebulaeDebugWorld.materialView + 1], "[J]")
    end
    printRow("Vista:", viewStr, "[V]", {1.0, 0.75, 0.35})
    printRow("Modo Color:", modeStr, "[M]", (opt.colorModeIndex == 2 and {0.4, 0.85, 1.0}) or (opt.colorModeIndex == 3 and {1.0, 0.45, 0.85}) or {0.35, 0.95, 0.85})
    printRow("Bioma / Gas:", biomeStr, "[B]")
    printRow("Armonía:", harmStr, "[H]")
    printRow("Matiz Base:", hueStr, "[C]")
    printRow("Morfología:", morphStr, "[O]", {0.45, 0.90, 1.0})
    printRow("Excentricidad:", aspectStr, "[E]", {1.0, 0.85, 0.45})
    printRow("Tamaño:", tierStr, "[T]")
    printRow("Semilla:", tostring(opt.seed), "[R / SPACE]")

    -- Separador
    love.graphics.setColor(0.3, 0.4, 0.6, 0.4)
    love.graphics.line(panelX + 15, y + 4, panelX + panelW - 15, y + 4)
    y = y + 10

    -- Atajos de acción rápida
    love.graphics.setColor(0.9, 0.95, 1.0, 0.9)
    love.graphics.print("ATAJOS DE TECLADO:", panelX + 15, y)
    y = y + 18
    love.graphics.setColor(0.70, 0.78, 0.88, 0.85)
    love.graphics.print("[G] Referencia de Orión    [R / SPACE] Nueva semilla", panelX + 15, y)
    y = y + 16
    love.graphics.print("[1-6] Teletransporte a nebulosa    [0] Teletransporte al centro", panelX + 15, y)
    y = y + 16
    love.graphics.print("[TAB] Ocultar / Mostrar este panel HUD", panelX + 15, y)

    -- Panel derecho: Datos de la nebulosa bajo el escáner
    local cur = NebulaeDebugWorld.closestNebula
    if cur then
        local targetW = 350
        local targetH = 190
        local targetX = sw - targetW - 20
        local targetY = 20

        love.graphics.setColor(0.04, 0.06, 0.12, 0.88)
        love.graphics.rectangle("fill", targetX, targetY, targetW, targetH, 8, 8)
        love.graphics.setColor(0.35, 0.75, 1.0, 0.75)
        love.graphics.rectangle("line", targetX, targetY, targetW, targetH, 8, 8)

        love.graphics.setColor(0.40, 0.85, 1.0, 1.0)
        love.graphics.print("TELEMETRÍA DE NEBULOSA EN FOCO", targetX + 15, targetY + 12)

        local ty = targetY + 34
        love.graphics.setColor(0.7, 0.8, 0.9, 0.9)
        local colorLabel = NebulaeDebugWorld.volumetric and modeStr or ((cur.colorMode == "B") and "Forma B (Bi-Tonal)" or "Forma A (Mono-Tono)")
        love.graphics.print("Color: "..colorLabel, targetX + 15, ty)
        ty = ty + 18
        love.graphics.print("Morfología: "..morphologyName(cur), targetX + 15, ty)
        ty = ty + 18
        local rotDeg = math.floor((math.deg(cur.rotation or 0) % 360) + 0.5)
        love.graphics.print(string.format("Orientación: %d° | Aspecto: %.2fx", rotDeg, cur.aspectRatio or 1.0), targetX + 15, ty)
        ty = ty + 18
        love.graphics.print("Armonía: "..(NebulaeDebugWorld.volumetric and harmStr or cur.harmony), targetX + 15, ty)
        ty = ty + 18
        love.graphics.print(string.format("Turbulencia Warp: %.2f (frec: %.2f)", cur.warpAmp, cur.warpFreq), targetX + 15, ty)
        ty = ty + 18
        love.graphics.print(string.format("Radio: %d px | Desgarro: %.2f", cur.radius, cur.irregularity or 0.35), targetX + 15, ty)
        ty = ty + 18
        love.graphics.print(string.format("Sparkles: %.2f | Brillo: %.2f", cur.sparkleStrength, cur.brightness), targetX + 15, ty)
    end
end

-- ============================================================================
-- INTERACCIÓN Y ATAJOS DE TECLADO
-- ============================================================================

local generationKeys = {r=true, space=true, v=true, m=true, b=true, h=true, c=true, o=true, e=true, t=true}

function NebulaeDebugWorld.keypressed(key, player, camera)
    local frame = NebulaeDebugWorld.reference
    if frame and (key == "g" or key == "l" or generationKeys[key]) then
        NebulaeDebugWorld.reference = nil
        NebulaeDebugWorld.volumetric = frame.volumetric
        NebulaeDebugWorld.materialView = frame.materialView
        if not generationKeys[key] then NebulaeDebugWorld.regenerate() end
        if key == "g" then return true end
    elseif key == "g" then
        local w,h = love.graphics.getDimensions()
        NebulaeDebugWorld.reference = {
            x = camera and camera.x or 0, y = camera and camera.y or 0,
            radius = math.min(.46*w,.67*h)/(camera and camera.zoom or 1),
            volumetric = NebulaeDebugWorld.volumetric, materialView = NebulaeDebugWorld.materialView
        }
        NebulaeDebugWorld.volumetric, NebulaeDebugWorld.materialView = true, 0
        NebulaeDebugWorld.regenerate()
        return true
    end
    if key == "j" and NebulaeDebugWorld.volumetric then
        NebulaeDebugWorld.materialView = (NebulaeDebugWorld.materialView + 1) % #MATERIAL_VIEWS
        return true
    end
    if NebulaeDebugWorld.reference and key ~= "tab" then return false end
    if key == "l" then
        NebulaeDebugWorld.volumetric = not NebulaeDebugWorld.volumetric
        return true
    end
    local opt = NebulaeDebugWorld.options

    -- [TAB]: Alternar HUD
    if key == 'tab' then
        NebulaeDebugWorld.showHUD = not NebulaeDebugWorld.showHUD
        return true
    end

    -- [V]: Alternar Vista (Foco 1x <-> Galería 6x)
    if key == 'v' then
        NebulaeDebugWorld.viewMode = (NebulaeDebugWorld.viewMode == "focus") and "gallery" or "focus"
        NebulaeDebugWorld.regenerate()
        return true
    end

    -- [SPACE] o [R]: Regenerar aleatorio con nueva semilla
    if key == 'space' or key == 'r' then
        opt.seed = math.random(10000, 999999)
        NebulaeDebugWorld.regenerate()
        return true
    end

    -- [M]: Alternar Modo de Color (Mixto -> Forma A -> Forma B)
    if key == 'm' then
        opt.colorModeIndex = (opt.colorModeIndex % #COLOR_MODES) + 1
        NebulaeDebugWorld.regenerate()
        return true
    end

    -- [B]: Ciclar Bioma de Energía
    if key == 'b' then
        opt.biomeIndex = (opt.biomeIndex % #BIOMES) + 1
        NebulaeDebugWorld.regenerate()
        return true
    end

    -- [H]: Ciclar Armonía
    if key == 'h' then
        opt.harmonyIndex = (opt.harmonyIndex % #HARMONIES) + 1
        NebulaeDebugWorld.regenerate()
        return true
    end

    -- [C]: Ciclar Matiz Base (Hue)
    if key == 'c' then
        opt.hueIndex = (opt.hueIndex % #HUES) + 1
        NebulaeDebugWorld.regenerate()
        return true
    end

    -- [O]: Ciclar las morfologías disponibles en el render activo.
    if key == 'o' then
        local count = NebulaeDebugWorld.volumetric and #MORPHOLOGIES or #MORPHOLOGIES-1
        opt.morphologyIndex = opt.morphologyIndex >= count and 1 or opt.morphologyIndex+1
        NebulaeDebugWorld.regenerate()
        return true
    end

    -- [E]: Ciclar Excentricidad / Aspect Ratio
    if key == 'e' then
        opt.aspectRatioIndex = (opt.aspectRatioIndex % #ASPECT_RATIOS) + 1
        NebulaeDebugWorld.regenerate()
        return true
    end

    -- [T]: Ciclar Tamaño / Tier
    if key == 't' then
        opt.tierIndex = (opt.tierIndex % #TIERS) + 1
        NebulaeDebugWorld.regenerate()
        return true
    end

    -- [0]: Teletransportar al centro del laboratorio
    if key == '0' then
        if player then
            player.x, player.y = 0, 0
            if player.dx then player.dx = 0 end
            if player.dy then player.dy = 0 end
            if player.body and player.body.setPosition then
                player.body:setPosition(0, 0)
                player.body:setLinearVelocity(0, 0)
            end
        end
        if camera then
            camera.x, camera.y = 0, 0
            camera:setPosition(0, 0)
        end
        return true
    end

    -- [1]..[6]: Teletransporte rápido a la nebulosa correspondiente
    local num = tonumber(key)
    if num and num >= 1 and num <= #NebulaeDebugWorld.nebulae then
        local target = NebulaeDebugWorld.nebulae[num]
        if target then
            local targetPX = target.x
            local targetPY = target.y + target.radius * 0.70

            if player then
                player.x = targetPX
                player.y = targetPY
                player.rotation = -math.pi * 0.5
                if player.dx then player.dx = 0 end
                if player.dy then player.dy = 0 end
                if player.body and player.body.setPosition then
                    player.body:setPosition(targetPX, targetPY)
                    player.body:setLinearVelocity(0, 0)
                end
            end

            if camera then
                camera.x = targetPX
                camera.y = targetPY - 100
                camera:setPosition(camera.x, camera.y)
            end
            return true
        end
    end

    return false
end

return NebulaeDebugWorld
