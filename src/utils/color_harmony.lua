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

-- Paletas de colores base de nebulosas astronómicas reales
local ASTRONOMICAL_PALETTES = {
    -- Nebulosa del Cangrejo: azules y blancos brillantes
    crab = {
        base = {h = 0.6, s = 0.8, v = 0.9},  -- Azul brillante
        harmonics = {
            {h = 0.65, s = 0.7, v = 0.95}, -- Azul-cian
            {h = 0.55, s = 0.9, v = 0.85}, -- Azul profundo
            {h = 0.0, s = 0.0, v = 1.0}    -- Blanco puro
        }
    },
    
    -- Nebulosa de Orión: rojos, magentas y azules
    orion = {
        base = {h = 0.95, s = 0.9, v = 0.8}, -- Rojo-magenta
        harmonics = {
            {h = 0.0, s = 0.85, v = 0.9},   -- Rojo brillante
            {h = 0.85, s = 0.8, v = 0.7},   -- Magenta
            {h = 0.6, s = 0.6, v = 0.4}     -- Azul tenue
        }
    },
    
    -- Nebulosa del Águila: naranjas y rojos
    eagle = {
        base = {h = 0.08, s = 0.9, v = 0.85}, -- Naranja brillante
        harmonics = {
            {h = 0.05, s = 0.95, v = 0.9},  -- Naranja-rojo
            {h = 0.02, s = 0.8, v = 0.7},   -- Rojo
            {h = 0.12, s = 0.7, v = 0.6}    -- Amarillo-naranja
        }
    },
    
    -- Nebulosa del Velo: verdes y azules
    veil = {
        base = {h = 0.3, s = 0.8, v = 0.75}, -- Verde brillante
        harmonics = {
            {h = 0.35, s = 0.9, v = 0.8},   -- Verde-azul
            {h = 0.25, s = 0.7, v = 0.65},  -- Verde lima
            {h = 0.5, s = 0.6, v = 0.5}     -- Azul-verde
        }
    },
    
    -- Nebulosa Roseta: rojos profundos y rosas
    rosette = {
        base = {h = 0.98, s = 0.9, v = 0.8}, -- Rosa-rojo
        harmonics = {
            {h = 0.02, s = 0.95, v = 0.85}, -- Rojo profundo
            {h = 0.92, s = 0.7, v = 0.9},   -- Rosa brillante
            {h = 0.08, s = 0.5, v = 0.6}    -- Naranja tenue
        }
    },
    
    -- Nebulosa del Corazón: rojos carmesí
    heart = {
        base = {h = 0.0, s = 0.95, v = 0.85}, -- Rojo puro
        harmonics = {
            {h = 0.98, s = 0.9, v = 0.9},   -- Rosa-rojo
            {h = 0.02, s = 0.8, v = 0.7},   -- Rojo oscuro
            {h = 0.95, s = 0.6, v = 0.6}    -- Rosa
        }
    },
    
    -- Nebulosa Helix: azules y verdes
    helix = {
        base = {h = 0.55, s = 0.8, v = 0.8}, -- Azul-verde
        harmonics = {
            {h = 0.6, s = 0.9, v = 0.85},   -- Azul brillante
            {h = 0.4, s = 0.7, v = 0.7},    -- Verde-azul
            {h = 0.65, s = 0.5, v = 0.5}    -- Azul tenue
        }
    },
    
    -- Nebulosa del Caballo: azules profundos con toques dorados
    horsehead = {
        base = {h = 0.65, s = 0.9, v = 0.6}, -- Azul profundo
        harmonics = {
            {h = 0.7, s = 0.8, v = 0.8},    -- Azul claro
            {h = 0.15, s = 0.7, v = 0.9},   -- Dorado
            {h = 0.6, s = 0.95, v = 0.4}    -- Azul muy oscuro
        }
    }
}

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
    end
}

-- Generar paleta armónica basada en nebulosa astronómica
function ColorHarmony.generateAstronomicalPalette(rng, paletteCount)
    paletteCount = paletteCount or 4
    
    -- Seleccionar paleta astronómica base aleatoriamente
    local paletteNames = {}
    for name, _ in pairs(ASTRONOMICAL_PALETTES) do
        table.insert(paletteNames, name)
    end
    
    local selectedName = paletteNames[rng:randomInt(1, #paletteNames)]
    local basePalette = ASTRONOMICAL_PALETTES[selectedName]
    
    -- Generar variaciones de la paleta base
    local colors = {}
    
    -- Color base principal
    local base = basePalette.base
    colors[1] = {
        hsv2rgb(base.h, base.s, base.v), 
        rng:randomRange(0.25, 0.45) -- Alpha variable
    }
    
    -- Agregar colores armónicos de la paleta
    for i = 2, math.min(paletteCount, #basePalette.harmonics + 1) do
        local harmonic = basePalette.harmonics[i - 1]
        if harmonic then
            local r, g, b = hsv2rgb(harmonic.h, harmonic.s, harmonic.v)
            colors[i] = {r, g, b, rng:randomRange(0.20, 0.40)}
        end
    end
    
    -- Si necesitamos más colores, generar variaciones
    while #colors < paletteCount do
        local baseColor = colors[rng:randomInt(1, #colors)]
        local h, s, v = rgb2hsv(baseColor[1], baseColor[2], baseColor[3])
        
        -- Variación sutil en HSV
        h = (h + rng:randomRange(-0.05, 0.05)) % 1.0
        s = math.max(0.6, math.min(1.0, s + rng:randomRange(-0.15, 0.15)))
        v = math.max(0.4, math.min(1.0, v + rng:randomRange(-0.2, 0.2)))
        
        local r, g, b = hsv2rgb(h, s, v)
        table.insert(colors, {r, g, b, rng:randomRange(0.20, 0.40)})
    end
    
    return colors, selectedName
end

-- Generar paleta usando teoría de armonía de color
function ColorHarmony.generateHarmonicPalette(rng, harmonyType, baseColor, paletteCount)
    harmonyType = harmonyType or "analogous"
    paletteCount = paletteCount or 4
    
    local baseH, baseS, baseV
    if baseColor then
        baseH, baseS, baseV = rgb2hsv(baseColor[1], baseColor[2], baseColor[3])
    else
        -- Generar color base aleatorio con alta saturación y valor
        baseH = rng:random()
        baseS = rng:randomRange(0.7, 0.95)
        baseV = rng:randomRange(0.6, 0.9)
    end
    
    local harmonyFunc = HARMONY_TYPES[harmonyType] or HARMONY_TYPES.analogous
    local hues = harmonyFunc(baseH, paletteCount)
    
    local colors = {}
    for i, h in ipairs(hues) do
        -- Variación sutil en saturación y valor para cada color
        local s = math.max(0.6, math.min(1.0, baseS + rng:randomRange(-0.1, 0.1)))
        local v = math.max(0.5, math.min(1.0, baseV + rng:randomRange(-0.15, 0.15)))
        
        local r, g, b = hsv2rgb(h, s, v)
        colors[i] = {r, g, b, rng:randomRange(0.25, 0.45)}
    end
    
    return colors
end

-- Generar paleta completamente aleatoria pero coherente
function ColorHarmony.generateRandomCoherentPalette(rng, paletteCount)
    paletteCount = paletteCount or 4
    
    -- Elegir tipo de armonía aleatoriamente
    local harmonyTypes = {"analogous", "complementary", "triadic", "splitComplementary"}
    local selectedHarmony = harmonyTypes[rng:randomInt(1, #harmonyTypes)]
    
    return ColorHarmony.generateHarmonicPalette(rng, selectedHarmony, nil, paletteCount)
end

-- Función principal para generar colores de nebulosa
function ColorHarmony.generateNebulaColor(rng, biomeType, seed)
    -- Usar semilla para determinismo
    if seed then
        rng = rng or love.math.newRandomGenerator(seed)
    end
    
    -- 70% probabilidad de usar paleta astronómica real, 30% armonía teórica
    if rng:random() < 0.7 then
        local colors, paletteName = ColorHarmony.generateAstronomicalPalette(rng, 1)
        return colors[1], paletteName
    else
        local colors = ColorHarmony.generateRandomCoherentPalette(rng, 1)
        return colors[1], "harmonic"
    end
end

-- Obtener paleta completa para un chunk (4-6 colores coherentes)
function ColorHarmony.generateChunkPalette(rng, chunkSeed, biomeType)
    local paletteSize = rng:randomInt(4, 6)
    
    -- 60% astronómica, 40% armónica
    if rng:random() < 0.6 then
        return ColorHarmony.generateAstronomicalPalette(rng, paletteSize)
    else
        local harmonyTypes = {"analogous", "complementary", "triadic"}
        local selectedHarmony = harmonyTypes[rng:randomInt(1, #harmonyTypes)]
        return ColorHarmony.generateHarmonicPalette(rng, selectedHarmony, nil, paletteSize), selectedHarmony
    end
end

return ColorHarmony