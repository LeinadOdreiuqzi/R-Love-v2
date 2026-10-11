-- src/sublevels/nebulae_debug_world.lua
-- Sistema de visualización, banco de pruebas y laboratorio interactivo de nebulosas
-- Permite testear la generación procedural aleatoria o parametrizada (Forma A / Forma B / Biomas / Armonías)

local NebulaeDebugDef = require 'src.sublevels.definitions.nebulae_debug'
local ColorHarmony = require 'src.utils.color_harmony'
local NebulasShaders = require 'src.shaders.nebulas_shaders'
local ShaderManager = require 'src.shaders.shader_manager'
local BiomeSystem = require 'src.maps.biome_system'
local MapConfig = require 'src.maps.config.map_config'
local SeedSystem = require 'src.utils.seed_system'

local NebulaeDebugWorld = {
    nebulae = {},
    viewMode = "focus",     -- "focus" (1 nebulosa central) o "gallery" (6 nebulosas comparativas)
    showHUD = true,
    closestNebula = nil,
    
    -- Opciones configurables para generación específica
    options = {
        colorModeIndex = 1,     -- 1: "RANDOM", 2: "A" (Mono-Tono), 3: "B" (Bi-Tonal)
        biomeIndex = 1,         -- 1: "ALL", 2..7: Biomas específicos
        harmonyIndex = 1,       -- 1: "ALL", 2..6: Armonías específicas
        tierIndex = 2,          -- 1: small, 2: medium, 3: large, 4: gigantic
        hueIndex = 1,           -- 1: Libre 360°, 2..9: Matices fijos
        morphologyIndex = 1,    -- 1: Aleatoria, 2: Difusa, 3: Anular, 4: Bipolar, 5: Filamentosa
        aspectRatioIndex = 1,   -- 1: Libre/Orgánico, 2: Circular 1:1, 3: Elíptica Horiz, 4: Elíptica Vert
        seed = 10101
    }
}

-- Listas de opciones
local COLOR_MODES = {
    { id = nil, name = "Mixto (50% A / 50% B)" },
    { id = "A", name = "Forma A (Mono-Tonal Puro)" },
    { id = "B", name = "Forma B (Bi-Tonal Dual-Tone)" }
}

local MORPHOLOGIES = {
    { id = nil, name = "Aleatoria / Mixta" },
    { id = 0,   name = "Difusa Clásica" },
    { id = 1,   name = "Anular / Bubble" },
    { id = 2,   name = "Bipolar / Alas" },
    { id = 3,   name = "Filamentosa / Velo" }
}

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

local HARMONIES = {
    { id = nil, name = "Aleatoria / Perfil" },
    { id = "cosmic", name = "Cosmic (Emisión Estelar)" },
    { id = "complementary", name = "Complementary (Alto Contraste)" },
    { id = "splitComplementary", name = "Split-Complementary (Equilibrado)" },
    { id = "triadic", name = "Triadic (Tríada Energética)" },
    { id = "analogous", name = "Analogous (Transición Suave)" }
}

local TIERS = {
    { name = "small",    label = "Pequeña",   radius = 280,  scale = 1.0 },
    { name = "medium",   label = "Mediana",    radius = 420,  scale = 1.3 },
    { name = "large",    label = "Grande",     radius = 650,  scale = 1.8 },
    { name = "gigantic", label = "Gigantesca", radius = 950,  scale = 2.4 }
}

local HUES = {
    { val = nil,    name = "Libre 360° (Todo el espectro)" },
    { val = 0.00,   name = "Rojo / Carmesí (0°)" },
    { val = 0.10,   name = "Dorado / Ámbar (36°)" },
    { val = 0.25,   name = "Lima Eléctrico (90°)" },
    { val = 0.38,   name = "Esmeralda Puro (137°)" },
    { val = 0.50,   name = "Cian / Turquesa (180°)" },
    { val = 0.62,   name = "Azul Cobalto (223°)" },
    { val = 0.77,   name = "Violeta / Amatista (277°)" },
    { val = 0.90,   name = "Magenta / Fucsia (324°)" }
}

-- Función para construir una nebulosa con parámetros específicos o procedurales
local function buildNebula(params)
    local seed = params.seed or math.random(1, 999999)
    local rng
    if SeedSystem and (SeedSystem.makeRNG or SeedSystem.createRNG) then
        local fn = SeedSystem.makeRNG or SeedSystem.createRNG
        rng = fn(seed)
    elseif love and love.math and love.math.newRandomGenerator then
        local gen = love.math.newRandomGenerator(seed)
        rng = {
            random = function(self) return gen:random() end,
            randomRange = function(self, min, max) return min + gen:random() * (max - min) end,
            randomInt = function(self, min, max) return gen:random(min, max) end
        }
    else
        rng = {
            random = function(self) return math.random() end,
            randomRange = function(self, min, max) return min + math.random() * (max - min) end,
            randomInt = function(self, min, max) return math.random(min, max) end
        }
    end

    local bType = params.biomeType or BiomeSystem.BiomeType.NEBULA_FIELD
    local mode = params.colorMode

    -- Generar color usando el sistema integrado
    local colorObj, harmony = ColorHarmony.generateNebulaColor(rng, bType, seed, mode)
    
    -- Si se forzó un matiz específico
    if params.fixedHue then
        local baseH = params.fixedHue
        local profile = ColorHarmony.ENERGY_PROFILES.NEBULA_FIELD
        if type(bType) == "number" then
            local pNames = {[1]="DEEP_SPACE",[2]="NEBULA_FIELD",[3]="ASTEROID_BELT",[4]="GRAVITY_ANOMALY",[5]="RADIOACTIVE_ZONE",[6]="ANCIENT_RUINS"}
            profile = ColorHarmony.ENERGY_PROFILES[pNames[bType]] or profile
        end
        local palCount = (mode == "B") and 2 or 1
        local r, g, b = ColorHarmony.hsv2rgb(baseH, (profile.satRange and profile.satRange[2]) or 0.95, (profile.valRange and profile.valRange[2]) or 0.90)
        local pal = ColorHarmony.generateHarmonicPalette(rng, harmony, {r, g, b}, palCount, profile.satRange, profile.valRange)
        colorObj[1], colorObj[2], colorObj[3] = pal[1][1], pal[1][2], pal[1][3]
        if mode == "B" and pal[2] then
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

function NebulaeDebugWorld.regenerate()
    NebulaeDebugWorld.nebulae = {}
    local opt = NebulaeDebugWorld.options
    local bChoice = BIOMES[opt.biomeIndex].id
    local mChoice = COLOR_MODES[opt.colorModeIndex].id
    local hChoice = HARMONIES[opt.harmonyIndex].id
    local tChoice = TIERS[opt.tierIndex]
    local hueChoice = HUES[opt.hueIndex].val
    local morphChoice = MORPHOLOGIES[opt.morphologyIndex].id
    local aspectChoice = ASPECT_RATIOS[opt.aspectRatioIndex].id

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
    NebulaeDebugWorld.options.seed = math.random(10000, 99999)
    NebulaeDebugWorld.viewMode = "focus"
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

function NebulaeDebugWorld.draw(camera, player)
    local t = love.timer.getTime()

    -- 1. Grilla y límites del laboratorio espacial acotado
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

    -- 2. Renderizar cada nebulosa utilizando NebulasShaders
    local shader = NebulasShaders.getShader and NebulasShaders.getShader()
    local img = ShaderManager and ShaderManager.getBaseImage and ShaderManager.getBaseImage("circle")
    if not shader or not img then return end

    local iw, ih = img:getWidth(), img:getHeight()
    local scaleFactor = 2.0 / math.max(1, iw)
    local halfIw, halfIh = iw * 0.5, ih * 0.5

    -- PASO A: CUERPO PRINCIPAL DE LA NEBULOSA (Shader + Blend Aditivo)
    local oldBlend, oldAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    NebulasShaders.setShader()

    for _, neb in ipairs(NebulaeDebugWorld.nebulae) do
        local cr, cg, cb = neb.color[1] or 1, neb.color[2] or 1, neb.color[3] or 1
        local ca = (neb.color[4] or 0.35) * 1.30

        local core = neb.coreColor or {cr, cg, cb}
        local coreR, coreG, coreB = core[1] or cr, core[2] or cg, core[3] or cb

        NebulasShaders.configureForNebula({
            seed = neb.seed or 0,
            noiseScale = neb.noiseScale or 2.5,
            warpAmp = neb.warpAmp or 0.5,
            warpFreq = neb.warpFreq or 1.0,
            softness = neb.softness or 0.28,
            brightness = neb.brightness or 1.25,
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

    NebulasShaders.unsetShader()

    -- PASO B: NIEBLA SUAVE DE FONDO (Alpha blend)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    for _, neb in ipairs(NebulaeDebugWorld.nebulae) do
        local fogScale = (neb.radius * 1.2) * scaleFactor
        local aspect = neb.aspectRatio or 1.0
        local rot = neb.rotation or 0.0
        local fogScaleX = fogScale * aspect
        local fogScaleY = fogScale / aspect
        local cr, cg, cb = neb.color[1] or 1, neb.color[2] or 1, neb.color[3] or 1
        love.graphics.setColor(cr, cg, cb, 0.06)
        love.graphics.draw(img, neb.x, neb.y, rot, fogScaleX, fogScaleY, halfIw, halfIh)

        -- Marcador de centro e información en el espacio del mundo
        love.graphics.setColor(0.3, 0.8, 1.0, 0.4)
        love.graphics.circle("line", neb.x, neb.y, 16)
        love.graphics.circle("fill", neb.x, neb.y, 3)

        local modeLabel = (neb.colorMode == "B") and "[FORMA B: BI-TONAL]" or "[FORMA A: MONO-TONO]"
        local bName = "NEBULA"
        if type(neb.biomeType) == "number" then
            local pNames = {[1]="DEEP SPACE",[2]="NEBULA FIELD",[3]="ASTEROID BELT",[4]="GRAVITY ANOMALY",[5]="RADIOACTIVE ZONE",[6]="ANCIENT RUINS"}
            bName = pNames[neb.biomeType] or "NEBULA"
        end

        local morphNames = {[0]="Difusa",[1]="Anular (Ring)",[2]="Bipolar (Alas)",[3]="Filamentosa"}
        local morphLabel = morphNames[neb.morphology or 0] or "Difusa"
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.printf(string.format("%s\n%s • %s\nArmonía: %s", modeLabel, bName, morphLabel, neb.harmony), neb.x - 200, neb.y + neb.radius * 0.45 + 30, 400, "center")
    end

    love.graphics.setBlendMode(oldBlend, oldAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- INTERFAZ DE USUARIO (HUD DE LABORATORIO)
-- ============================================================================

function NebulaeDebugWorld.drawHUD()
    if not NebulaeDebugWorld.showHUD then
        love.graphics.setColor(0.8, 0.85, 1.0, 0.6)
        love.graphics.printf("[TAB] Mostrar HUD de Laboratorio", 20, 20, 400, "left")
        return
    end

    local opt = NebulaeDebugWorld.options
    local sw = love.graphics.getWidth()

    -- Panel superior de estado y controles
    local panelW = 470
    local panelH = 390
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

    local modeStr = COLOR_MODES[opt.colorModeIndex].name
    local biomeStr = BIOMES[opt.biomeIndex].name
    local harmStr = HARMONIES[opt.harmonyIndex].name
    local tierStr = TIERS[opt.tierIndex].label .. " (" .. TIERS[opt.tierIndex].radius .. "px)"
    local hueStr = HUES[opt.hueIndex].name
    local morphStr = MORPHOLOGIES[opt.morphologyIndex].name
    local aspectStr = ASPECT_RATIOS[opt.aspectRatioIndex].name
    local viewStr = (NebulaeDebugWorld.viewMode == "focus") and "1x Nebulosa Central (Foco)" or "6x Galería Comparativa (3x A / 3x B)"

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
    love.graphics.print("[R / SPACE] Regenerar con nueva semilla aleatoria", panelX + 15, y)
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
        love.graphics.print(string.format("Color: %s", (cur.colorMode == "B") and "Forma B (Bi-Tonal)" or "Forma A (Mono-Tono)"), targetX + 15, ty)
        ty = ty + 18
        local morphNames = {[0]="Difusa Clásica",[1]="Anular / Bubble",[2]="Bipolar (Alas)",[3]="Filamentosa / Velo"}
        love.graphics.print(string.format("Morfología: %s", morphNames[cur.morphology or 0] or "Difusa"), targetX + 15, ty)
        ty = ty + 18
        local rotDeg = math.floor((math.deg(cur.rotation or 0) % 360) + 0.5)
        love.graphics.print(string.format("Orientación: %d° | Aspecto: %.2fx", rotDeg, cur.aspectRatio or 1.0), targetX + 15, ty)
        ty = ty + 18
        love.graphics.print(string.format("Armonía: %s", cur.harmony), targetX + 15, ty)
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

function NebulaeDebugWorld.keypressed(key, player, camera)
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

    -- [O]: Ciclar Morfología (Aleatoria -> Difusa -> Anular -> Bipolar -> Filamentosa)
    if key == 'o' then
        opt.morphologyIndex = (opt.morphologyIndex % #MORPHOLOGIES) + 1
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
