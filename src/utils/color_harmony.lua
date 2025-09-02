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
function ColorHarmony.generateHarmonicPalette(rng, harmonyType, baseColor, paletteCount)
    harmonyType = harmonyType or "analogous"
    paletteCount = paletteCount or 4
    
    local baseH, baseS, baseV
    if baseColor then
        baseH, baseS, baseV = rgb2hsv(baseColor[1], baseColor[2], baseColor[3])
    else
        -- Generar color base aleatorio con saturación muy alta y valor alto
        baseH = rng:random()
        baseS = rng:randomRange(0.85, 1.0)
        baseV = rng:randomRange(0.75, 0.95)
    end
    
    local harmonyFunc = HARMONY_TYPES[harmonyType] or HARMONY_TYPES.analogous
    local hues = harmonyFunc(baseH, paletteCount)
    
    local colors = {}
    for i, h in ipairs(hues) do
        local s, v
        
        -- Variaciones especiales según el tipo de armonía (saturación aumentada)
        if harmonyType == "monochromatic" then
            -- Para monocromático: variar saturación y valor dramáticamente
            s = math.max(0.7, math.min(1.0, baseS + rng:randomRange(-0.2, 0.3)))
            v = math.max(0.4, math.min(1.0, baseV + rng:randomRange(-0.3, 0.3)))
        elseif harmonyType == "stellar" then
            -- Para secuencia estelar: saturación muy alta, valor variable
            s = math.max(0.9, math.min(1.0, baseS + rng:randomRange(-0.05, 0.1)))
            v = math.max(0.5, math.min(1.0, 0.9 - (i - 1) * 0.12)) -- Degradado de brillo
        elseif harmonyType == "cosmic" then
            -- Para cósmico: saturación alta, valores altos
            s = math.max(0.8, math.min(1.0, baseS + rng:randomRange(-0.1, 0.2)))
            v = math.max(0.7, math.min(1.0, baseV + rng:randomRange(-0.1, 0.2)))
        else
            -- Variación estándar para otros tipos (saturación aumentada)
            s = math.max(0.8, math.min(1.0, baseS + rng:randomRange(-0.05, 0.15)))
            v = math.max(0.6, math.min(1.0, baseV + rng:randomRange(-0.1, 0.2)))
        end
        
        local r, g, b = hsv2rgb(h, s, v)
        colors[i] = {r, g, b, rng:randomRange(0.25, 0.45)}
    end
    
    return colors
end

-- Generar paleta completamente aleatoria pero coherente
function ColorHarmony.generateRandomCoherentPalette(rng, paletteCount)
    paletteCount = paletteCount or 4
    
    -- Elegir tipo de armonía aleatoriamente con pesos
    local harmonyTypes = {
        {"analogous", 20},        -- Más común, suave
        {"complementary", 15},    -- Contrastante
        {"triadic", 12},          -- Vibrante
        {"splitComplementary", 10}, -- Equilibrado
        {"tetradic", 8},          -- Complejo
        {"compound", 12},         -- Híbrido
        {"cosmic", 15},           -- Espacial
        {"stellar", 5},           -- Secuencial
        {"monochromatic", 3}      -- Sutil
    }
    
    -- Selección ponderada
    local totalWeight = 0
    for _, entry in ipairs(harmonyTypes) do
        totalWeight = totalWeight + entry[2]
    end
    
    local randomValue = rng:randomInt(1, totalWeight)
    local currentWeight = 0
    local selectedHarmony = "analogous" -- fallback
    
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
function ColorHarmony.generateNebulaColor(rng, biomeType, seed)
    -- Usar semilla para determinismo
    if seed then
        rng = rng or love.math.newRandomGenerator(seed)
    end
    
    -- Usar solo armonías procedurales
    local colors = ColorHarmony.generateRandomCoherentPalette(rng, 1)
    return colors[1], "procedural"
end

-- Obtener paleta completa para un chunk (4-6 colores coherentes)
function ColorHarmony.generateChunkPalette(rng, chunkSeed, biomeType)
    local paletteSize = rng:randomInt(4, 6)
    
    -- Usar solo armonías procedurales para máxima diversidad
    local colors = ColorHarmony.generateRandomCoherentPalette(rng, paletteSize)
    return colors, "procedural"
end

return ColorHarmony