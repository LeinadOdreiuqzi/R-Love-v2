-- src/utils/color_harmony.lua
-- Sistema de armonía de colores para nebulosas astronómicas
local ColorHarmony = {}

-- Conversión RGB <-> HSV (valores en [0,1])
local function rgb2hsv(r, g, b)
    local maxc = math.max(r, g, b)
    local minc = math.min(r, g, b)
    local v = maxc
    local d = maxc - minc
    local s = (maxc == 0) and 0 or d / maxc
    if d == 0 then return 0, 0, v end
    local h
    if maxc == r then
        h = ((g - b) / d) % 6
    elseif maxc == g then
        h = (b - r) / d + 2
    else
        h = (r - g) / d + 4
    end
    h = h / 6
    if h < 0 then h = h + 1 end
    return h, s, v
end

local function hsv2rgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local m = i % 6
    if m == 0 then return v, t, p
    elseif m == 1 then return q, v, p
    elseif m == 2 then return p, v, t
    elseif m == 3 then return p, q, v
    elseif m == 4 then return t, p, v
    else return v, p, q end
end

-- Exponer utilidades para conversión de color
ColorHarmony.rgb2hsv = rgb2hsv
ColorHarmony.hsv2rgb = hsv2rgb

-- Sistema simplificado: solo armonías procedurales



-- Tipos de armonía de color
local HARMONY_TYPES = {
    analogous = function(baseH, count)
        -- Colores análogos: ±30 grados en el círculo cromático
        local colors = {}
        local step = 0.083 -- 30 grados / 360 = ~0.083
        for i = 1, count do
            local offset = (i - 1) * step - step * (count - 1) / 2
            colors[i] = (baseH + offset) % 1.0
        end
        return colors
    end,
    
    complementary = function(baseH, count)
        -- Colores complementarios: opuestos en el círculo cromático
        local colors = {baseH}
        if count > 1 then
            colors[2] = (baseH + 0.5) % 1.0 -- Complementario
        end
        if count > 2 then
            colors[3] = (baseH + 0.33) % 1.0 -- Triádico
        end
        if count > 3 then
            colors[4] = (baseH + 0.67) % 1.0 -- Triádico complementario
        end
        return colors
    end,
    
    triadic = function(baseH, count)
        -- Colores triádicos: espaciados 120 grados
        local colors = {}
        for i = 1, count do
            colors[i] = (baseH + (i - 1) * 0.33) % 1.0
        end
        return colors
    end,
    
    splitComplementary = function(baseH, count)
        -- Complementario dividido: base + dos adyacentes al complementario
        local colors = {baseH}
        if count > 1 then
            colors[2] = (baseH + 0.42) % 1.0 -- 150 grados
        end
        if count > 2 then
            colors[3] = (baseH + 0.58) % 1.0 -- 210 grados
        end
        if count > 3 then
            colors[4] = (baseH + 0.17) % 1.0 -- 60 grados
        end
        return colors
    end,
    
    tetradic = function(baseH, count)
        -- Colores tetrádicos: rectángulo en el círculo cromático
        local colors = {baseH}
        if count > 1 then
            colors[2] = (baseH + 0.25) % 1.0 -- 90 grados
        end
        if count > 2 then
            colors[3] = (baseH + 0.5) % 1.0  -- 180 grados
        end
        if count > 3 then
            colors[4] = (baseH + 0.75) % 1.0 -- 270 grados
        end
        return colors
    end,
    
    monochromatic = function(baseH, count)
        -- Monocromático: mismo matiz, diferentes saturaciones/valores
        local colors = {}
        for i = 1, count do
            colors[i] = baseH -- Mismo matiz, variación en S/V se maneja después
        end
        return colors
    end,
    
    compound = function(baseH, count)
        -- Compuesto: base + análogos + complementario
        local colors = {baseH}
        if count > 1 then
            colors[2] = (baseH + 0.083) % 1.0 -- Análogo +30°
        end
        if count > 2 then
            colors[3] = (baseH - 0.083) % 1.0 -- Análogo -30°
        end
        if count > 3 then
            colors[4] = (baseH + 0.5) % 1.0   -- Complementario
        end
        return colors
    end,
    
    cosmic = function(baseH, count)
        -- Armonía cósmica: inspirada en espectros estelares
        local colors = {baseH}
        if count > 1 then
            colors[2] = (baseH + 0.15) % 1.0  -- Desplazamiento estelar
        end
        if count > 2 then
            colors[3] = (baseH + 0.72) % 1.0  -- Emisión nebular
        end
        if count > 3 then
            colors[4] = (baseH + 0.38) % 1.0  -- Línea de hidrógeno
        end
        return colors
    end,
    
    stellar = function(baseH, count)
        -- Secuencia estelar: del azul al rojo como las estrellas
        local colors = {}
        local blueStart = 0.6  -- Azul (estrellas calientes)
        local redEnd = 0.0     -- Rojo (estrellas frías)
        for i = 1, count do
            local t = (i - 1) / math.max(1, count - 1)
            colors[i] = (blueStart + t * (redEnd - blueStart + 1.0)) % 1.0
        end
        return colors
    end
}



-- Generar paleta usando teoría de armonía de color
function ColorHarmony.generateHarmonicPalette(rng, harmonyType, baseColor, paletteCount, satRange, valRange)
    harmonyType = harmonyType or "analogous"
    paletteCount = paletteCount or 4
    
    local baseH, baseS, baseV
    if baseColor then
        baseH, baseS, baseV = rgb2hsv(baseColor[1], baseColor[2], baseColor[3])
    else
        -- Generar color base aleatorio 100% LIBRE (0 a 360 grados, cualquier matiz)
        baseH = rng:random()
        local minS = (satRange and satRange[1]) or 0.85
        local maxS = (satRange and satRange[2]) or 1.00
        local minV = (valRange and valRange[1]) or 0.75
        local maxV = (valRange and valRange[2]) or 0.95
        baseS = rng:randomRange(minS, maxS)
        baseV = rng:randomRange(minV, maxV)
    end
    
    local harmonyFunc = HARMONY_TYPES[harmonyType] or HARMONY_TYPES.analogous
    local hues = harmonyFunc(baseH, paletteCount)
    
    local colors = {}
    for i, h in ipairs(hues) do
        local s, v
        
        -- Variaciones especiales según el tipo de armonía (saturación y luminosidad calibradas)
        if harmonyType == "monochromatic" then
            -- Para monocromático: variar saturación y valor dramáticamente
            s = math.max(0.65, math.min(1.0, baseS + rng:randomRange(-0.2, 0.2)))
            v = math.max(0.45, math.min(1.0, baseV + rng:randomRange(-0.25, 0.25)))
        elseif harmonyType == "stellar" then
            -- Para secuencia estelar: saturación muy alta, valor variable
            s = math.max(0.85, math.min(1.0, baseS + rng:randomRange(-0.05, 0.1)))
            v = math.max(0.5, math.min(1.0, 0.9 - (i - 1) * 0.12)) -- Degradado de brillo
        elseif harmonyType == "cosmic" then
            -- Para cósmico: saturación alta, valores altos
            s = math.max(0.8, math.min(1.0, baseS + rng:randomRange(-0.1, 0.15)))
            v = math.max(0.7, math.min(1.0, baseV + rng:randomRange(-0.1, 0.15)))
        else
            -- Variación estándar para otros tipos
            s = math.max(0.8, math.min(1.0, baseS + rng:randomRange(-0.05, 0.15)))
            v = math.max(0.6, math.min(1.0, baseV + rng:randomRange(-0.1, 0.15)))
        end
        
        local r, g, b = hsv2rgb(h, s, v)
        colors[i] = {r, g, b, rng:randomRange(0.25, 0.45)}
    end
    
    return colors
end

-- Perfiles de Energía y Armonía por Bioma (Opción A combinada con Opción B)
-- Mantiene el matiz base 100% LIBRE (0° a 360° en todos los biomas),
-- pero modula los tipos de armonía de choque/emisión, saturación y micro-destellos.
ColorHarmony.ENERGY_PROFILES = {
    -- 1. Espacio Profundo: Nubes interestelares frías, etéreas y sutiles
    DEEP_SPACE = {
        name = "DeepSpaceEther",
        harmonyWeights = {
            {"analogous", 40},          -- Transición suave atmosférica
            {"cosmic", 30},             -- Líneas espectrales tranquilas
            {"monochromatic", 20},      -- Degradados sutiles monocromáticos
            {"splitComplementary", 10}
        },
        satRange = {0.75, 0.92},        -- Saturación rica pero suave
        valRange = {0.70, 0.88},        -- Luminosidad serena
        coreAlpha = 0.48,
        sparkleRange = {0.0, 0.0}       -- Espacio frío sin destellos
    },

    -- 2. Campos de Nebulosas: Cunas estelares masivas, ricas y majestuosas (estilo Hubble/JWST)
    NEBULA_FIELD = {
        name = "StellarNursery",
        harmonyWeights = {
            {"cosmic", 36},             -- Líneas de emisión H-Alpha y O-III
            {"splitComplementary", 24}, -- Contraste equilibrado sofisticado
            {"complementary", 20},      -- Parejas visuales de alto impacto (ej. Turquesa/Dorado)
            {"triadic", 12},
            {"analogous", 8}
        },
        satRange = {0.88, 1.00},        -- Saturación cósmica vibrante
        valRange = {0.80, 0.98},        -- Alta emisión luminosa
        coreAlpha = 0.62,
        sparkleRange = {0.04, 0.12}     -- Ligeros destellos estelares
    },

    -- 3. Cinturón de Asteroides: Nubes de polvo mineral, partículas de silicato y regolito
    ASTEROID_BELT = {
        name = "MineralDust",
        harmonyWeights = {
            {"analogous", 35},          -- Polvo difuso en equilibrio
            {"compound", 28},           -- Riqueza cromática compleja
            {"cosmic", 22},
            {"splitComplementary", 15}
        },
        satRange = {0.80, 0.95},        -- Colores minerales profundos
        valRange = {0.72, 0.90},
        coreAlpha = 0.52,
        sparkleRange = {0.0, 0.08}      -- Destellos sutiles de silicato
    },

    -- 4. Anomalía Gravitacional: Lentes gravitacionales, espaciotiempo comprimido y energía densa
    GRAVITY_ANOMALY = {
        name = "GravitationalLens",
        harmonyWeights = {
            {"splitComplementary", 35}, -- Alto contraste focal
            {"cosmic", 30},             -- Emisión comprimida
            {"triadic", 22},
            {"monochromatic", 13}       -- Concentración de vacío
        },
        satRange = {0.85, 1.00},
        valRange = {0.75, 0.92},
        coreAlpha = 0.65,
        sparkleRange = {0.0, 0.10}
    },

    -- 5. Zona Radiactiva: Ionización de alta energía, radiación cuántica y choque plasmático
    RADIOACTIVE_ZONE = {
        name = "IonizedPlasma",
        harmonyWeights = {
            {"complementary", 42},      -- Máximo contraste complementario hiper-eléctrico
            {"triadic", 36},            -- Tríadas vibrantes de choque energético
            {"splitComplementary", 22}
        },
        satRange = {0.95, 1.00},        -- Saturación hiper-eléctrica pura
        valRange = {0.90, 1.00},        -- Luminosidad máxima de ionización
        coreAlpha = 0.70,
        sparkleRange = {0.25, 0.50}     -- Chispas procedimentales de ionización activa
    },

    -- 6. Ruinas Antiguas: Frecuencias exóticas arcanas, resonancia de tecnologías extintas
    ANCIENT_RUINS = {
        name = "ArcaneResonance",
        harmonyWeights = {
            {"complementary", 38},      -- Contraste reliquia
            {"cosmic", 32},             -- Emisión hiperdimensional
            {"triadic", 20},
            {"analogous", 10}
        },
        satRange = {0.85, 0.98},
        valRange = {0.80, 0.95},
        coreAlpha = 0.60,
        sparkleRange = {0.15, 0.35}     -- Destellos de resonancia relicta
    }
}

local function getEnergyProfile(biomeType)
    if type(biomeType) == "number" then
        local names = {
            [1] = "DEEP_SPACE",
            [2] = "NEBULA_FIELD",
            [3] = "ASTEROID_BELT",
            [4] = "GRAVITY_ANOMALY",
            [5] = "RADIOACTIVE_ZONE",
            [6] = "ANCIENT_RUINS"
        }
        biomeType = names[biomeType]
    end
    if type(biomeType) == "string" and ColorHarmony.ENERGY_PROFILES[biomeType] then
        return ColorHarmony.ENERGY_PROFILES[biomeType]
    end
    return ColorHarmony.ENERGY_PROFILES.NEBULA_FIELD
end

-- Generar paleta completamente aleatoria pero coherente
function ColorHarmony.generateRandomCoherentPalette(rng, paletteCount)
    paletteCount = paletteCount or 4
    
    local harmonyTypes = {
        {"analogous", 20},
        {"complementary", 15},
        {"triadic", 12},
        {"splitComplementary", 10},
        {"tetradic", 8},
        {"compound", 12},
        {"cosmic", 15},
        {"stellar", 5},
        {"monochromatic", 3}
    }
    
    local totalWeight = 0
    for _, entry in ipairs(harmonyTypes) do
        totalWeight = totalWeight + entry[2]
    end
    
    local randomValue = rng:randomInt(1, totalWeight)
    local currentWeight = 0
    local selectedHarmony = "analogous"
    
    for _, entry in ipairs(harmonyTypes) do
        currentWeight = currentWeight + entry[2]
        if randomValue <= currentWeight then
            selectedHarmony = entry[1]
            break
        end
    end
    
    return ColorHarmony.generateHarmonicPalette(rng, selectedHarmony, nil, paletteCount)
end

-- Función principal para generar colores de nebulosa
-- Integra AMBAS formas de generación en el universo:
--   • FORMA A: Nebulosa Mono-Tonal (Color celestial puro unificado con núcleo del mismo matiz)
--   • FORMA B: Nebulosa Bi-Tonal (Dual-Tone con filamentos exteriores y núcleo de color contrastante)
-- Ambas formas coexisten en cualquier sector y mantienen el espectro 100% LIBRE (0° a 360°).
function ColorHarmony.generateNebulaColor(rng, biomeType, seed, forceMode)
    -- Usar semilla para determinismo si se provee
    if seed and not rng then
        local ok, SeedSystem = pcall(require, "src.utils.seed_system")
        if ok and SeedSystem and SeedSystem.createRNG then
            rng = SeedSystem.createRNG(seed)
        end
    end
    if not rng then
        if love and love.math and love.math.newRandomGenerator then
            rng = love.math.newRandomGenerator(seed or 12345)
        else
            rng = math
        end
    end

    -- Garantizar existencia de métodos auxiliares randomInt y randomRange
    if not rng.randomInt then
        rng.randomInt = function(self, min, max)
            if max == nil then max = min; min = 1 end
            if max < min then min, max = max, min end
            local r = self.random and self:random() or math.random()
            return math.floor(min + r * (max - min + 1))
        end
    end
    if not rng.randomRange then
        rng.randomRange = function(self, min, max)
            if max == nil then
                return self.random and self:random() or math.random()
            end
            if max < min then min, max = max, min end
            local r = self.random and self:random() or math.random()
            return min + r * (max - min)
        end
    end

    -- Obtener perfil de energía del bioma
    local profile = getEnergyProfile(biomeType)
    local harmonyWeights = profile.harmonyWeights
    
    local totalWeight = 0
    for _, hw in ipairs(harmonyWeights) do totalWeight = totalWeight + hw[2] end
    local rVal = rng:randomInt(1, totalWeight)
    local selectedHarmony = harmonyWeights[1][1]
    local acc = 0
    for _, hw in ipairs(harmonyWeights) do
        acc = acc + hw[2]
        if rVal <= acc then
            selectedHarmony = hw[1]
            break
        end
    end
    
    -- Selección de Modo de Color: FORMA A vs FORMA B
    -- Si no se especifica forceMode, cualquier nebulosa tiene un 50% de probabilidad de ser Forma A o Forma B
    local mode = forceMode
    if not mode then
        mode = (rng:random() < 0.50) and "A" or "B"
    end

    local outerColor
    local coreColor

    if mode == "A" then
        -- FORMA A: Nebulosa Mono-Tonal Pura Armonizada
        -- Un solo color dominante para toda la nebulosa con núcleo denso del mismo matiz
        local palette = ColorHarmony.generateHarmonicPalette(rng, selectedHarmony, nil, 1, profile.satRange, profile.valRange)
        outerColor = palette[1] or {0.8, 0.4, 0.9, 0.35}

        -- El núcleo mantiene el mismo matiz pero con densidad lumínica concentrada
        local oh, os, ov = rgb2hsv(outerColor[1], outerColor[2], outerColor[3])
        local cr, cg, cb = hsv2rgb(oh, math.min(1.0, os * 1.05), math.min(1.0, ov * 1.15))
        coreColor = {cr, cg, cb, profile.coreAlpha or 0.55}
    else
        -- FORMA B: Nebulosa Bi-Tonal (Dual-Tone)
        -- Dos colores distintos entrelazados (exterior de un matiz, núcleo de matiz armónico contrastante)
        local palette = ColorHarmony.generateHarmonicPalette(rng, selectedHarmony, nil, 2, profile.satRange, profile.valRange)
        outerColor = palette[1] or {0.8, 0.4, 0.9, 0.35}
        coreColor = palette[2] or {0.2, 0.85, 0.95, 0.55}
    end
    
    local sparkle = 0.0
    if profile.sparkleRange and profile.sparkleRange[2] > 0 then
        sparkle = rng:randomRange(profile.sparkleRange[1], profile.sparkleRange[2])
    end

    -- Estructura retro-compatible: indexable como tabla {r, g, b, a}
    -- y con propiedades ricas para renderizado volumétrico
    local result = {
        outerColor[1], outerColor[2], outerColor[3], outerColor[4] or 0.35
    }
    result.core = { coreColor[1], coreColor[2], coreColor[3], profile.coreAlpha or 0.55 }
    result.mode = mode
    result.harmony = selectedHarmony
    result.energyStyle = profile.name
    result.sparkle = sparkle
    result.primary = outerColor
    
    return result, selectedHarmony
end

-- Obtener paleta completa para un chunk (4-6 colores coherentes modulados por el perfil de energía)
function ColorHarmony.generateChunkPalette(rng, chunkSeed, biomeType)
    local paletteSize = rng:randomInt(4, 6)
    local profile = getEnergyProfile(biomeType)
    
    local totalWeight = 0
    for _, hw in ipairs(profile.harmonyWeights) do totalWeight = totalWeight + hw[2] end
    local rVal = rng:randomInt(1, totalWeight)
    local selectedHarmony = profile.harmonyWeights[1][1]
    local acc = 0
    for _, hw in ipairs(profile.harmonyWeights) do
        acc = acc + hw[2]
        if rVal <= acc then
            selectedHarmony = hw[1]
            break
        end
    end
    
    local colors = ColorHarmony.generateHarmonicPalette(rng, selectedHarmony, nil, paletteSize, profile.satRange, profile.valRange)
    return colors, selectedHarmony
end

return ColorHarmony