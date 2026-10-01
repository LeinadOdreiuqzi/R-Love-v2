-- src/audio/procedural_music.lua
-- Generador de bandas sonoras procedurales en memoria (Tracker Algorítmico)
-- Inspirado en el diseño sonoro de Yoshi's Island (Underground) de Koji Kondo
-- Cero dependencias externas | Síntesis DSP en RAM pura

local ProceduralMusic = {}

local SAMPLE_RATE = 44100

-- ============================================================================
-- TEORÍA MUSICAL Y CONVERSIÓN DE NOTAS
-- ============================================================================

local function midiToFreq(note)
    return 440.0 * (2.0 ^ ((note - 69.0) / 12.0))
end

-- Mapeo semántico de notas (octavas 1 a 6)
local N = {
    -- Octava 1 (Sub-bajos profundos)
    C1 = 24, D1 = 26, Eb1 = 27, E1 = 28, F1 = 29, G1 = 31, Ab1 = 32, A1 = 33, Bb1 = 34, B1 = 35,
    -- Octava 2 (Bajos principales)
    C2 = 36, Cs2 = 37, D2 = 38, Eb2 = 39, E2 = 40, F2 = 41, Fs2 = 42, G2 = 43, Ab2 = 44, A2 = 45, Bb2 = 46, B2 = 47,
    -- Octava 3 (Bajos agudos y armonías)
    C3 = 48, Cs3 = 49, D3 = 50, Eb3 = 51, E3 = 52, F3 = 53, Fs3 = 54, G3 = 55, Ab3 = 56, A3 = 57, Bb3 = 58, B3 = 59,
    -- Octava 4 (Teclas / Chimes)
    C4 = 60, Cs4 = 61, D4 = 62, Eb4 = 63, E4 = 64, F4 = 65, Fs4 = 66, G4 = 67, Ab4 = 68, A4 = 69, Bb4 = 70, B4 = 71,
    -- Octava 5 y 6 (Gotas de agua y campanas)
    C5 = 72, D5 = 74, Eb5 = 75, E5 = 76, F5 = 77, G5 = 79, A5 = 81, Bb5 = 82,
    C6 = 84, D6 = 86, E6 = 88, F6 = 89, G6 = 91, A6 = 93, C7 = 96
}

local function clampSample(v)
    if v > 1.0 then return 1.0 end
    if v < -1.0 then return -1.0 end
    return v
end

-- ============================================================================
-- SÍNTESIS DE INSTRUMENTOS VIRTUALES (DSP)
-- ============================================================================

local Instruments = {
    -- 1. Bajo "Rubber Slap" (elástico, limpio, sin siseo ni zumbidos raros)
    rubberBass = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration
        
        -- Decaimiento percusivo natural
        local env = math.exp(-progress * 5.8)
        
        -- Onda senoidal pura fundamental + sub-octava con leve saturación analógica suave
        local fundamental = math.sin(2 * math.pi * freq * t)
        local sub = math.sin(2 * math.pi * (freq * 0.5) * t) * 0.5
        local body = math.sin(2 * math.pi * (freq * 2.0) * t) * 0.12
        
        -- Saturación sutil que engrosa el bajo sin distorsionar
        local sample = math.tanh((fundamental + sub + body) * 1.35)
        return sample * env * 0.52
    end,

    -- 2. Gota de agua de caverna cristalina (Water Drip)
    -- Barrido rápido y nítido de frecuencia ascendente sin interferencias
    waterDrip = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration
        local env = math.exp(-progress * 30.0)
        
        -- Salto de frecuencia exponencial que crea el "plop" acuático
        local freq = baseFreq * (1.0 + progress * 1.6)
        local sample = math.sin(2 * math.pi * freq * t) * env
        return sample * 0.35
    end,

    -- 3. Vibráfono / Rhodes apagado de caverna (Reemplaza el pad de "ondas")
    -- Sonido percusivo cálido, con espacio de silencio entre notas
    cavernKey = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration
        
        -- Decaimiento de campana / tecla acústica
        local env = math.exp(-progress * 7.0)
        
        local o1 = math.sin(2 * math.pi * freq * t)
        local o2 = math.sin(2 * math.pi * (freq * 2.76) * t) * 0.15 -- Armónico de lengüeta metálica
        
        return (o1 + o2) * env * 0.22
    end,

    -- 4. Chasquido de madera / Rim Click
    rimClick = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 48.0)
        local noise = (math.random() * 2 - 1)
        local pop = math.sin(2 * math.pi * 720 * t) * 0.6
        return (noise * 0.35 + pop) * env * 0.20
    end,

    -- 5. Bombo sordo amortiguado
    muffledKick = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 22.0)
        local freq = 60 * math.exp(-progress * 16.0) + 36
        local sample = math.sin(2 * math.pi * freq * t) * env
        return sample * 0.34
    end
}

-- ============================================================================
-- GENERADOR DE LA BANDA SONORA PRINCIPAL
-- ============================================================================

--[[
    Genera la pista "cavern_groove" extendida (16 compases / 45 segundos)
    Estructura musical completa A -> B -> C -> D con evolución y resolución cíclica perfecta
--]]
function ProceduralMusic.generateCavernGroove()
    local bpm = 86
    local stepDuration = 60.0 / (bpm * 4) -- Semicorchea (~0.1744 s)
    local totalSteps = 256 -- 16 compases completos (44.65 segundos)
    local totalDuration = totalSteps * stepDuration
    local totalSamples = math.floor(SAMPLE_RATE * totalDuration)

    -- Dos buffers independientes:
    -- 1. dryBuffer: para elementos secos directos (bajo y percusión)
    -- 2. wetBuffer: para elementos espaciales que pasan por el eco cavernoso (gotas y teclas)
    local dryBuffer = {}
    local wetBuffer = {}
    for i = 1, totalSamples do
        dryBuffer[i] = 0
        wetBuffer[i] = 0
    end

    local function addNote(buf, instrumentFn, note, startStep, durationSteps)
        local startTime = (startStep - 1) * stepDuration
        local noteDuration = durationSteps * stepDuration
        local startSample = math.floor(startTime * SAMPLE_RATE) + 1
        local numSamples = math.floor(noteDuration * SAMPLE_RATE)

        for s = 0, numSamples - 1 do
            local idx = startSample + s
            if idx <= totalSamples then
                local t = s / SAMPLE_RATE
                local sample = instrumentFn(note, t, noteDuration)
                buf[idx] = buf[idx] + sample
            end
        end
    end

    local function addPercussion(buf, percFn, startStep, durationSteps)
        local startTime = (startStep - 1) * stepDuration
        local noteDuration = durationSteps * stepDuration
        local startSample = math.floor(startTime * SAMPLE_RATE) + 1
        local numSamples = math.floor(noteDuration * SAMPLE_RATE)

        for s = 0, numSamples - 1 do
            local idx = startSample + s
            if idx <= totalSamples then
                local t = s / SAMPLE_RATE
                local sample = percFn(t, noteDuration)
                buf[idx] = buf[idx] + sample
            end
        end
    end

    -- ========================================================================
    -- SECCIÓN 1 (Compases 1-4): GROOVE PRINCIPAL DE PRESENTACIÓN
    -- ========================================================================
    -- Compás 1: D2 -> D2 -> F2 -> G2 -> A2
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 1, 3.5)
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 5, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 7, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 10, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.Ab2, 13, 1.5)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 15, 2.0)

    -- Compás 2: D2 -> C3 -> A2 -> F2 -> D2
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 17, 3.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C3, 21, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 24, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 27, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 31, 2.0)

    -- Compás 3: Síncopa en Re menor
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 33, 3.5)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 37, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 40, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 43, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C3, 46, 2.5)

    -- Compás 4: Cierre de frase
    addNote(dryBuffer, Instruments.rubberBass, N.D3, 49, 3.0)
    addNote(dryBuffer, Instruments.rubberBass, N.C3, 53, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 56, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 59, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.Eb2, 62, 1.5)
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 64, 1.0)

    -- Gotas de agua espaciales sección 1
    addNote(wetBuffer, Instruments.waterDrip, N.A5, 4, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.C6, 12, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.F6, 20, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.D6, 28, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.A5, 36, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.C6, 44, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.D6, 60, 3.0)

    -- ========================================================================
    -- SECCIÓN 2 (Compases 5-8): WALKING BASSLINE + TECLAS DE CAVERNA
    -- ========================================================================
    -- Compás 5: D2 -> F2 -> G2 -> G#2 -> A2 -> C3
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 65, 3.0)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 69, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 72, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.Ab2, 75, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 77, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C3, 80, 2.0)

    -- Compás 6: D3 -> A2 -> F2 -> D2 -> C2
    addNote(dryBuffer, Instruments.rubberBass, N.D3, 81, 3.0)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 85, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 88, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 91, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C2, 94, 2.0)

    -- Compás 7: Paseo rítmico
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 97, 3.5)
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 101, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 104, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 107, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C2, 110, 2.0)

    -- Compás 8: Subida melódica
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 113, 3.0)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 117, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 120, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 123, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C3, 126, 2.0)

    -- Teclas de caverna en contratiempos (acordes sutiles Dm7 en staccato cálido)
    addNote(wetBuffer, Instruments.cavernKey, N.F4, 68, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.A4, 68, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.D4, 76, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.F4, 84, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.C5, 84, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.A4, 100, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.D5, 108, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.F4, 116, 2.5)

    -- Gotas de agua sección 2
    addNote(wetBuffer, Instruments.waterDrip, N.E5, 71, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.A5, 87, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.C6, 103, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.F6, 119, 3.0)

    -- ========================================================================
    -- SECCIÓN 3 (Compases 9-12): VARIACIÓN ARMÓNICA (Gm7 -> Bb -> Am7)
    -- ========================================================================
    -- Compás 9: Sol Menor (G2 -> Bb2 -> D3 -> F3)
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 129, 3.5)
    addNote(dryBuffer, Instruments.rubberBass, N.Bb2, 133, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C3, 136, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.D3, 140, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.F3, 143, 2.0)

    -- Compás 10: Descenso en Sol
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 145, 3.5)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 149, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 152, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C2, 155, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.Bb1, 158, 2.5)

    -- Compás 11: Si Bemol Mayor (Bb1 -> D2 -> F2 -> G2 -> A2)
    addNote(dryBuffer, Instruments.rubberBass, N.Bb1, 161, 3.5)
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 165, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 168, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 171, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 174, 2.0)

    -- Compás 12: La Menor de transición (A1 -> C2 -> E2 -> G2)
    addNote(dryBuffer, Instruments.rubberBass, N.A1, 177, 3.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C2, 181, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.E2, 184, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 187, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 190, 2.0)

    -- Teclas de caverna Gm7 y Bbmaj7
    addNote(wetBuffer, Instruments.cavernKey, N.Bb4, 132, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.D5, 132, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.G4, 148, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.D5, 148, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.D4, 164, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.F4, 164, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.C5, 180, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.E4, 180, 2.5)

    -- Gotas sección 3
    addNote(wetBuffer, Instruments.waterDrip, N.G5, 135, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.Bb5, 151, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.D6, 167, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.E6, 183, 3.0)

    -- ========================================================================
    -- SECCIÓN 4 (Compases 13-16): DESARROLLO CROMÁTICO Y RESOLUCIÓN
    -- ========================================================================
    -- Compás 13: Subida cromática misteriosa
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 193, 3.0)
    addNote(dryBuffer, Instruments.rubberBass, N.Eb2, 197, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.E2, 200, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 203, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.Fs2, 206, 2.0)

    -- Compás 14: Continuación hacia el clímax
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 209, 3.0)
    addNote(dryBuffer, Instruments.rubberBass, N.Ab2, 213, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 216, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C3, 220, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.Cs3, 223, 2.0)

    -- Compás 15: Descenso melódico ágil
    addNote(dryBuffer, Instruments.rubberBass, N.D3, 225, 3.5)
    addNote(dryBuffer, Instruments.rubberBass, N.C3, 229, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 232, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.G2, 235, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 238, 2.0)

    -- Compás 16: Retorno impecable al tono fundamental
    addNote(dryBuffer, Instruments.rubberBass, N.D2, 241, 3.0)
    addNote(dryBuffer, Instruments.rubberBass, N.F2, 245, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.A2, 248, 2.0)
    addNote(dryBuffer, Instruments.rubberBass, N.C3, 251, 2.5)
    addNote(dryBuffer, Instruments.rubberBass, N.Cs3, 254, 2.0)

    -- Teclas de caverna sección 4
    addNote(wetBuffer, Instruments.cavernKey, N.A4, 196, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.D5, 212, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.F5, 228, 2.5)
    addNote(wetBuffer, Instruments.cavernKey, N.C5, 244, 2.5)

    -- Arpegio de gotas de lluvia cavernosas descendente
    addNote(wetBuffer, Instruments.waterDrip, N.A6, 198, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.F6, 214, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.D6, 230, 3.0)
    addNote(wetBuffer, Instruments.waterDrip, N.A5, 246, 3.0)

    -- ========================================================================
    -- PERCUSIÓN GLOBAL (16 compases sincronizados)
    -- ========================================================================
    for bar = 0, 15 do
        local base = bar * 16
        -- Bombo sordo en pulsos 1 y 9
        addPercussion(dryBuffer, Instruments.muffledKick, base + 1, 2.5)
        addPercussion(dryBuffer, Instruments.muffledKick, base + 9, 2.5)
        
        -- Rim click percusivo en pulsos 5 y 13
        addPercussion(dryBuffer, Instruments.rimClick, base + 5, 1.5)
        addPercussion(dryBuffer, Instruments.rimClick, base + 13, 1.5)
        
        -- Micro-chasquido sincopado de madera en compases pares
        if bar % 2 == 1 then
            addPercussion(dryBuffer, Instruments.rimClick, base + 15, 1.0)
        end
    end

    -- ========================================================================
    -- LÍNEA DE RETARDO / ECO EN MEMORIA (SOLO EN EL WET BUFFER)
    -- ========================================================================
    -- Retardo rítmico de 3 pasos (~523 ms) con amortiguación
    local delaySamples = math.floor(stepDuration * 3.0 * SAMPLE_RATE)
    local delayBuffer = {}
    for i = 1, delaySamples do
        delayBuffer[i] = 0
    end
    
    local delayIdx = 1
    local feedback = 0.35

    -- Doble pasada para loop continuo infinito
    for pass = 1, 2 do
        for i = 1, totalSamples do
            local dry = wetBuffer[i]
            local echo = delayBuffer[delayIdx]
            
            if pass == 2 then
                wetBuffer[i] = dry + echo * feedback
            end
            
            delayBuffer[delayIdx] = dry + echo * feedback
            delayIdx = (delayIdx % delaySamples) + 1
        end
    end

    -- ========================================================================
    -- MEZCLA FINAL: DRY (BAJO + RITMO LIMPIO) + WET (GOTAS + ECOS)
    -- ========================================================================
    local sd = love.sound.newSoundData(totalSamples, SAMPLE_RATE, 16, 1)
    for i = 0, totalSamples - 1 do
        local dry = dryBuffer[i + 1] or 0
        local wet = wetBuffer[i + 1] or 0
        local finalSample = (dry * 0.90 + wet * 0.70) * 0.85
        sd:setSample(i, clampSample(finalSample))
    end

    return sd
end

--[[
    Genera la pista "space_ambient" atmosférica enriquecida
--]]
function ProceduralMusic.generateSpaceAmbient()
    local duration = 8.0
    local samples = math.floor(SAMPLE_RATE * duration)
    local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)

    for i = 0, samples - 1 do
        local t = i / SAMPLE_RATE

        local lfo1 = 0.5 + 0.5 * math.sin(2 * math.pi * 0.125 * t)
        local lfo2 = 0.5 + 0.5 * math.cos(2 * math.pi * 0.25 * t)

        local b1 = math.sin(2 * math.pi * 73.42 * t) * 0.30
        local b2 = math.sin(2 * math.pi * 110.00 * t) * 0.25
        local b3 = math.sin(2 * math.pi * 174.61 * t) * 0.18
        local b4 = math.sin(2 * math.pi * 261.63 * t) * 0.12

        local chord = (b1 + b2 + b3 + b4) * (0.7 + 0.3 * lfo1)

        local twinklePhase = (t * 2.0) % 2.0
        local twinkleEnv = math.exp(-twinklePhase * 8.0)
        local twinkleFreq = 880 + 220 * math.floor((t * 2.0) % 4)
        local twinkle = math.sin(2 * math.pi * twinkleFreq * t) * twinkleEnv * 0.08 * lfo2

        local sample = (chord + twinkle) * 0.45
        sd:setSample(i, clampSample(sample))
    end

    return sd
end

return ProceduralMusic
