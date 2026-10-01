-- src/audio/procedural_music.lua
-- Motor de síntesis procedural y composición algorítmica para bandas sonoras
-- Cero dependencias externas | Síntesis DSP en RAM pura

local ProceduralMusic = {}

local SAMPLE_RATE = 44100
local TWO_PI = math.pi * 2.0

-- ============================================================================
-- TEORÍA MUSICAL Y CONVERSIÓN DE NOTAS
-- ============================================================================

local function midiToFreq(note)
    return 440.0 * (2.0 ^ ((note - 69.0) / 12.0))
end

-- Mapeo semántico de notas (octavas 1 a 7 con sostenidos y bemoles)
local N = {}
local baseNotes = {
    C = 0, Cs = 1, Db = 1, D = 2, Ds = 3, Eb = 3, E = 4,
    F = 5, Fs = 6, Gb = 6, G = 7, Gs = 8, Ab = 8, A = 9,
    As = 10, Bb = 10, B = 11
}
for oct = 1, 7 do
    for name, semi in pairs(baseNotes) do
        N[name .. oct] = (oct + 1) * 12 + semi
    end
end


local function clampSample(v)
    if v > 1.0 then return 1.0 end
    if v < -1.0 then return -1.0 end
    return v
end

-- ============================================================================
-- SÍNTESIS DE INSTRUMENTOS VIRTUALES (DSP)
-- ============================================================================

local NOISE_TABLE = {}
for i = 1, 1024 do
    NOISE_TABLE[i] = (math.random() * 2 - 1) * 0.04
end

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
    end,

    -- 6. Bajo melódico acústico (cálido, redondo y resonante)
    warmUprightBass = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration
        local env = math.exp(-progress * 4.4)
        local fundamental = math.sin(TWO_PI * freq * t)
        local octave = math.sin(TWO_PI * (freq * 2.0) * t) * 0.28
        local twelfth = math.sin(TWO_PI * (freq * 3.0) * t) * 0.08
        local tri = (math.abs(((freq * t) % 1.0) - 0.5) * 4.0 - 1.0) * 0.15
        local sample = math.tanh((fundamental + octave + twelfth + tri) * 1.3)
        return sample * env * 0.48
    end,

    -- 7. Teclas de cristal / Rhodes etéreo
    crystalRhodes = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration
        local env = math.exp(-progress * 5.0)
        local tine = math.sin(TWO_PI * (freq * 3.98) * t) * 0.30 * math.exp(-progress * 18.0)
        local body = math.sin(TWO_PI * freq * t)
        local overtone = math.sin(TWO_PI * (freq * 2.0) * t) * 0.18
        local trem = 1.0 + 0.06 * math.sin(TWO_PI * 4.2 * t)
        return (body + overtone + tine) * env * trem * 0.22
    end,

    -- 8. Vibráfono cálido de jazz / Celesta acústica (Timbre melódico redondo, cálido y resonante)
    warmVibraphone = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration
        local attack = math.min(1.0, t / 0.014)
        local decay = math.exp(-progress * 3.0)
        local trem = 1.0 + 0.07 * math.sin(TWO_PI * 4.2 * t)
        
        local fund = math.sin(TWO_PI * freq * t)
        local octave = math.sin(TWO_PI * (freq * 2.0) * t) * 0.18
        local chime = math.sin(TWO_PI * (freq * 3.98) * t) * 0.12 * math.exp(-progress * 14.0)
        
        local sample = math.tanh((fund + octave + chime) * 1.15)
        return sample * attack * decay * trem * 0.36
    end,
    ancientFlute = function(note, t, duration)
        return Instruments.warmVibraphone(note, t, duration)
    end,

    -- 9. Side-stick / Rimshot de madera cálida
    sideStick = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 52.0)
        local pop = math.sin(TWO_PI * 840 * t) * 0.65
        local noise = (math.random() * 2 - 1) * 0.35
        return (pop + noise) * env * 0.20
    end,

    -- 10. Shaker suave
    softShaker = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 38.0)
        return (math.random() * 2 - 1) * env * 0.09
    end,

    -- 11. Golpe sordo amortiguado (Thud)
    muffledThud = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 20.0)
        local freq = 55 * math.exp(-progress * 18.0) + 32
        return math.sin(TWO_PI * freq * t) * env * 0.30
    end,

    -- 12. Bajo acústico de nylon (pulgar limpio, definido y profundo con ataque preciso sin artefactos)
    nylonBass = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.003)
        local decay = math.exp(-progress * 3.2)

        local w = TWO_PI * freq * t
        local h1 = math.sin(w)
        local h2 = math.sin(w * 2.0) * 0.45 * math.exp(-progress * 6.0)
        local h3 = math.sin(w * 3.0) * 0.14 * math.exp(-progress * 10.0)

        local sample = math.tanh((h1 + h2 + h3) * 1.3) * attack * decay
        return sample * 0.46
    end,

    -- 13. Cuerdas pulsadas de nylon para acordes (suaves, cálidas y aireadas)
    nylonChord = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.006)
        local decay = math.exp(-progress * 3.8)

        local w = TWO_PI * freq * t
        local h1 = math.sin(w)
        local h2 = math.sin(w * 2.0) * 0.30 * math.max(0, 1.0 - progress * 0.8)
        local h3 = math.sin(w * 3.0) * 0.10 * math.max(0, 1.0 - progress * 0.9)

        local sample = math.tanh((h1 + h2 + h3) * 1.15) * attack * decay
        return sample * 0.35
    end,

    -- Alias por compatibilidad
    nylonGuitar = function(note, t, duration)
        return Instruments.nylonChord(note, t, duration)
    end,

    -- 14. Cello de cámara (arco lento y suave que entra como colchón armónico)
    chamberCello = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.22)
        local release = math.exp(-math.max(0, (progress - 0.70) * 5.0))
        local env = attack * release

        local vibDelay = 0.20
        local vibAmount = t > vibDelay and math.min(1.0, (t - vibDelay) / 0.4) * 0.009 or 0
        local freq = baseFreq * (1.0 + math.sin(TWO_PI * 4.6 * t) * vibAmount)

        local f1 = math.sin(TWO_PI * freq * t) * 0.72
        local f2 = math.sin(TWO_PI * (freq * 2.0) * t) * 0.20
        local f3 = math.sin(TWO_PI * (freq * 3.0) * t) * 0.06

        return (f1 + f2 + f3) * env * 0.25
    end,

    -- 15. Celesta acústica / Notas de cuna dulces con decaimiento melancólico
    lullabyCeleste = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.010)
        local decay = math.exp(-progress * 2.8)
        local trem = 1.0 + 0.05 * math.sin(TWO_PI * 3.8 * t)

        local fund = math.sin(TWO_PI * freq * t)
        local oct = math.sin(TWO_PI * (freq * 2.0) * t) * 0.18
        local tine = math.sin(TWO_PI * (freq * 3.98) * t) * 0.14 * math.exp(-progress * 12.0)

        local sample = math.tanh((fund + oct + tine) * 1.1) * attack * decay * trem
        return sample * 0.32
    end,

    -- 16. [16-bit Style] Cuerda tradicional punteada (Koto / Shamisen)
    -- Cuantización sutil estilo soundfont vintage, micro-deslizamiento inicial y armónicos brillantes
    folkKoto = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        local pitchBend = t < 0.03 and (1.0 + (0.03 - t) * 0.35) or 1.0
        local freq = baseFreq * pitchBend

        local attack = math.min(1.0, t / 0.002)
        local decay = (1.0 - progress) * (1.0 - progress) * (1.0 - progress)

        local w = TWO_PI * freq * t
        local h1 = math.sin(w)
        local h2 = math.sin(w * 2.0) * 0.38
        local h3 = math.sin(w * 3.0) * 0.18

        local raw = (h1 + h2 + h3) * attack * decay
        local quantLevels = 2048
        local quantized = math.floor(raw * quantLevels + 0.5) / quantLevels
        return math.tanh(quantized * 1.3) * 0.40
    end,

    -- 17. [32-bit Floating Point] Flauta de bambú expresiva (Shinobue / Shakuhachi)
    -- Respiración acústica, transiciones suaves, vibrato lírico y armónicos de madera
    bambooFlute = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.07)
        local release = math.max(0, 1.0 - math.max(0, (progress - 0.75) / 0.25))
        local env = attack * release

        local vibDelay = 0.12
        local vibDepth = t > vibDelay and math.min(1.0, (t - vibDelay) / 0.35) * 0.012 or 0
        local freq = baseFreq * (1.0 + math.sin(TWO_PI * 4.8 * t) * vibDepth)

        local w = TWO_PI * freq * t
        local f1 = math.sin(w)
        local f2 = math.sin(w * 2.0) * 0.28
        local f3 = math.sin(w * 3.0) * 0.10

        local sIdx = math.floor(t * 44100) % 1024 + 1
        local breath = NOISE_TABLE[sIdx] * (1.0 - progress)

        local sample = math.tanh((f1 + f2 + f3 + breath) * 1.1) * env
        return sample * 0.34
    end,

    -- 18. [16-bit Style] Campanilla / Chime nostálgico
    -- Timbre puro con textura cálida estilo soundfont clásico
    nostalgicChime = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.005)
        local decay = (1.0 - progress) * (1.0 - progress)

        local fund = math.sin(TWO_PI * freq * t)
        local part2 = math.sin(TWO_PI * (freq * 2.76) * t) * 0.24
        local part3 = math.sin(TWO_PI * (freq * 5.40) * t) * 0.10

        local raw = (fund + part2 + part3) * attack * decay
        local quantLevels = 1024
        local quantized = math.floor(raw * quantLevels + 0.5) / quantLevels
        return quantized * 0.26
    end,

    -- 19. [32-bit Floating Point] Bajo acústico folk
    -- Redondo, profundo, con respuesta dinámica de cuerda y cuerpo resonante
    warmFolkBass = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.004)
        local decay = (1.0 - progress) * (1.0 - progress) * (1.0 - progress)

        local w = TWO_PI * freq * t
        local h1 = math.sin(w)
        local h2 = math.sin(w * 2.0) * 0.30
        local sub = math.sin(w * 0.5) * 0.16

        local sample = math.tanh((h1 + h2 + sub) * 1.25) * attack * decay
        return sample * 0.45
    end,

    -- 20. [32-bit Floating Point] Colchón de cuerdas etéreas (Swell Pad)
    -- Amplitud estéreo suave, ataque lento y calidez armónica
    etherealPad = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.25)
        local release = math.exp(-math.max(0, (progress - 0.72) * 4.0))
        local env = attack * release

        local w = TWO_PI * freq * t
        local o1 = math.sin(w)
        local o2 = math.sin(w * 2.0) * 0.22
        return (o1 + o2) * env * 0.16
    end,

    -- 21. [16-bit Style] Percusión de madera tradicional (Woodblock / Clave suave)
    woodBlock = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 26.0)
        local freq = 740 * math.exp(-progress * 16.0) + 420
        local sample = math.sin(TWO_PI * freq * t) * env
        return math.tanh(sample * 1.4) * 0.22
    end,

    -- 22. [32-bit Style] Tambor acústico suave (Taiko tenue de fondo)
    softTaiko = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 7.5)
        local freq = 78 * math.exp(-progress * 8.0) + 44
        local tone = math.sin(TWO_PI * freq * t)
        local body = math.sin(TWO_PI * (freq * 1.52) * t) * 0.25 * math.exp(-progress * 15.0)
        return math.tanh((tone + body) * 1.3) * env * 0.35
    end,

    -- 23. Piano acústico normal (macillo de fieltro, doble cuerda con unísono acústico y decaimiento cantarín)
    acousticPiano = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        -- 1. Transiente percusivo del macillo de fieltro (< 2 ms)
        local attack = math.min(1.0, t / 0.0018)
        local hammerKnock = math.sin(TWO_PI * 155.0 * t) * math.exp(-t * 220.0) * 0.20

        -- 2. Doble cuerda al unísono con micro-desafine natural (chorus acústico)
        local detune = 1.0008
        local w1 = TWO_PI * baseFreq * t
        local w2 = TWO_PI * (baseFreq * detune) * t

        -- 3. Decaimiento dual acústico (prompt sound + sustain cantarín)
        local prompt = (1.0 - progress) * (1.0 - progress) * (1.0 - progress)
        local sustain = math.exp(-progress * 2.2)

        local h1 = (math.sin(w1) + math.sin(w2)) * 0.55 * sustain
        local h2 = math.sin(w1 * 2.0) * 0.35 * (sustain * 0.6 + prompt * 0.4)
        local h3 = math.sin(w1 * 3.0) * 0.18 * prompt
        local h4 = math.sin(w1 * 4.0) * 0.07 * (prompt * prompt)

        -- Resonancia cálida del cuerpo y arpa de madera
        local body = math.sin(TWO_PI * (baseFreq * 0.5) * t) * 0.08 * sustain

        local stringSound = (h1 + h2 + h3 + h4 + body) * attack
        local sample = (stringSound + hammerKnock) * 0.55
        return math.tanh(sample * 1.15) * 0.46
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

--[[
    Genera la pista "ancient_sanctuary" (16 compases / ~49.2 segundos)
    Armonía modal melancólica en Fa menor, bajo acústico melódico, flauta y arpegios etéreos
--]]
function ProceduralMusic.generateAncientSanctuary()
    local bpm = 78
    local stepDuration = 60.0 / (bpm * 4) -- ~0.1923 s por semicorchea
    local totalSteps = 256 -- 16 compases (~49.23 segundos)
    local totalDuration = totalSteps * stepDuration
    local totalSamples = math.floor(SAMPLE_RATE * totalDuration)

    local bassBuffer = {}
    local wetBuffer = {}
    for i = 1, totalSamples do
        bassBuffer[i] = 0
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
    -- COMPASES 1-4: INTRO Y ESTABLECIMIENTO DEL GROOVE (Fm9 -> Db -> Bbm -> C7)
    -- ========================================================================
    -- Compás 1
    addNote(bassBuffer, Instruments.warmUprightBass, N.F1, 1, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F1, 5, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab1, 7, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb1, 10, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 13, 1.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Eb2, 15, 2.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.C4, 3, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Eb4, 6, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.G4, 9, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Ab4, 12, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.C5, 15, 3.0)

    -- Compás 2
    addNote(bassBuffer, Instruments.warmUprightBass, N.F1, 17, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 21, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab1, 24, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F1, 27, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Eb1, 30, 2.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.Ab3, 19, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.C4, 22, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Eb4, 25, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.F4, 28, 3.0)

    -- Compás 3
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb1, 33, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F2, 37, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab2, 40, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb1, 43, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Db2, 46, 2.5)

    addNote(wetBuffer, Instruments.crystalRhodes, N.Db4, 35, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.F4, 38, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Ab4, 41, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.C5, 44, 3.0)

    -- Compás 4
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 49, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.G2, 53, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb2, 56, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 59, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.E2, 62, 2.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.C4, 51, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.F4, 54, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.G4, 57, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Bb4, 60, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.E4, 63, 2.5)

    -- ========================================================================
    -- COMPASES 5-8: TEMA PRINCIPAL (FLAUTA ANTIGUA + GROOVE)
    -- ========================================================================
    -- Compás 5
    addNote(bassBuffer, Instruments.warmUprightBass, N.F1, 65, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F1, 69, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab1, 71, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb1, 74, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 77, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Eb2, 79, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.Ab4, 65, 6.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.G4, 71, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.F4, 74, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Eb4, 78, 3.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.C4, 67, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Eb4, 73, 3.0)

    -- Compás 6
    addNote(bassBuffer, Instruments.warmUprightBass, N.Db2, 81, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F2, 85, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab2, 88, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C3, 91, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab2, 94, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.F4, 81, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.C4, 85, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Eb4, 88, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.F4, 91, 6.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.Ab4, 83, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.C5, 89, 3.0)

    -- Compás 7
    addNote(bassBuffer, Instruments.warmUprightBass, N.Eb2, 97, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.G2, 101, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb2, 104, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab1, 107, 3.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 110, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.G4, 97, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Ab4, 100, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.C5, 103, 5.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Bb4, 108, 4.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.Eb4, 99, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Bb4, 105, 3.0)

    -- Compás 8
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb1, 113, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Db2, 117, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F2, 120, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 123, 3.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.E2, 126, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.Ab4, 113, 3.5)
    addNote(wetBuffer, Instruments.warmVibraphone, N.G4, 117, 2.5)
    addNote(wetBuffer, Instruments.warmVibraphone, N.F4, 120, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.E4, 124, 5.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.Db4, 115, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.G4, 121, 3.0)

    -- ========================================================================
    -- COMPASES 9-12: VARIACIÓN MODAL Y REGISTRO ALTO
    -- ========================================================================
    -- Compás 9
    addNote(bassBuffer, Instruments.warmUprightBass, N.Db2, 129, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab2, 133, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C3, 136, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F3, 139, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Eb3, 142, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.C5, 129, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Db5, 133, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.C5, 137, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Bb4, 140, 4.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.F4, 131, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Ab4, 135, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.C5, 141, 3.0)

    -- Compás 10
    addNote(bassBuffer, Instruments.warmUprightBass, N.Eb2, 145, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb2, 149, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Db3, 152, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.G2, 155, 3.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb2, 158, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.Bb4, 145, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.C5, 149, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Bb4, 152, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Ab4, 155, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.G4, 158, 3.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.G4, 147, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Bb4, 153, 3.0)

    -- Compás 11
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 161, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.G2, 165, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb2, 168, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F2, 171, 3.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab2, 174, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.Eb5, 161, 5.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.D5, 166, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.C5, 169, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Bb4, 173, 4.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.Eb4, 163, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.G4, 167, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.C5, 172, 3.0)

    -- Compás 12
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb1, 177, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F2, 181, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab2, 184, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.G2, 187, 3.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F2, 190, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.C5, 177, 3.5)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Bb4, 181, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Ab4, 184, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.G4, 187, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.F4, 190, 3.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.Db4, 179, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.F4, 185, 3.0)

    -- ========================================================================
    -- COMPASES 13-16: CLÍMAX MÍSTICO Y RESOLUCIÓN CIRCULAR
    -- ========================================================================
    -- Compás 13
    addNote(bassBuffer, Instruments.warmUprightBass, N.Gb1, 193, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Db2, 197, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F2, 200, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb2, 203, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Db3, 206, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.F5, 193, 6.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Eb5, 199, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Db5, 203, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.C5, 207, 2.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.Bb4, 195, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Db5, 201, 3.0)

    -- Compás 14
    addNote(bassBuffer, Instruments.warmUprightBass, N.F1, 209, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 213, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Db2, 216, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.F2, 219, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab2, 222, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.Db5, 209, 5.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.C5, 214, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Bb4, 217, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Ab4, 221, 4.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.Ab4, 211, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.C5, 217, 3.0)

    -- Compás 15
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 225, 3.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.G2, 229, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb2, 232, 2.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Db3, 235, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.C3, 238, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.G4, 225, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Bb4, 229, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Db5, 233, 4.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.C5, 237, 4.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.G4, 227, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Bb4, 233, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.E5, 237, 3.0)

    -- Compás 16
    addNote(bassBuffer, Instruments.warmUprightBass, N.C2, 241, 3.0)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Bb1, 245, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Ab1, 248, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.G1, 251, 2.5)
    addNote(bassBuffer, Instruments.warmUprightBass, N.Gb1, 254, 2.0)

    addNote(wetBuffer, Instruments.warmVibraphone, N.Bb4, 241, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.Ab4, 244, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.G4, 247, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.E4, 250, 3.0)
    addNote(wetBuffer, Instruments.warmVibraphone, N.F4, 253, 4.0)

    addNote(wetBuffer, Instruments.crystalRhodes, N.C4, 243, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.Eb4, 247, 3.0)
    addNote(wetBuffer, Instruments.crystalRhodes, N.G4, 251, 3.0)

    -- ========================================================================
    -- PERCUSIÓN ORGÁNICA (16 compases)
    -- ========================================================================
    for bar = 0, 15 do
        local base = bar * 16
        -- Bombo sordo en pulsos 1 y 9
        addPercussion(bassBuffer, Instruments.muffledThud, base + 1, 2.5)
        addPercussion(bassBuffer, Instruments.muffledThud, base + 9, 2.5)

        -- Side-stick en pulsos 5 y 13
        addPercussion(bassBuffer, Instruments.sideStick, base + 5, 1.5)
        addPercussion(bassBuffer, Instruments.sideStick, base + 13, 1.5)

        -- Shaker suave continuo en semicorcheas intermedias
        addPercussion(bassBuffer, Instruments.softShaker, base + 3, 1.0)
        addPercussion(bassBuffer, Instruments.softShaker, base + 7, 1.0)
        addPercussion(bassBuffer, Instruments.softShaker, base + 11, 1.0)
        addPercussion(bassBuffer, Instruments.softShaker, base + 15, 1.0)

        -- Ghost note en rim click en compases 4, 8, 12, 16
        if bar % 4 == 3 then
            addPercussion(bassBuffer, Instruments.sideStick, base + 16, 0.8)
        end
    end

    -- ========================================================================
    -- LÍNEA DE RETARDO / REVERB ESPACIAL (SOLO EN EL WET BUFFER)
    -- ========================================================================
    local delaySamples = math.floor(stepDuration * 4.0 * SAMPLE_RATE) -- ~769 ms
    local delayBuffer = {}
    for i = 1, delaySamples do
        delayBuffer[i] = 0
    end

    local delayIdx = 1
    local feedback = 0.32

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

    -- Mezcla final: Bajo y percusión directa + Flauta y arpegios con espacialidad
    local sd = love.sound.newSoundData(totalSamples, SAMPLE_RATE, 16, 1)
    for i = 0, totalSamples - 1 do
        local bass = bassBuffer[i + 1] or 0
        local wet = wetBuffer[i + 1] or 0
        local finalSample = (bass * 0.88 + wet * 0.72) * 0.82
        sd:setSample(i, clampSample(finalSample))
    end

    return sd
end

--[[
    Genera la pista "lunar_waltz" (36 compases en compás de 3/4 / ~77.14 segundos)
    Composición acústica: bajo de pulgar de nylon definido, acordes cálidos, cello de soporte
    y celesta/caja de música con puente melancólico y resolución dulce en coda.
--]]
function ProceduralMusic.generateLunarWaltz()
    local bpm = 84
    local beatDuration = 60.0 / bpm
    local stepDuration = beatDuration / 4.0 -- 12 pasos por compás (~0.1786 s)
    local totalBars = 36 -- 36 compases (~77.14 segundos)
    local totalSteps = totalBars * 12
    local totalDuration = totalSteps * stepDuration
    local totalSamples = math.floor(SAMPLE_RATE * totalDuration)

    local guitarBuffer = {}
    local wetBuffer = {}
    for i = 1, totalSamples do
        guitarBuffer[i] = 0
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

    local function addChord(buf, instrumentFn, notes, startStep, durationSteps)
        for _, note in ipairs(notes) do
            addNote(buf, instrumentFn, note, startStep, durationSteps)
        end
    end

    -- Estructura armónica completa de 36 compases
    local harmony = {
        -- Compases 1-4: Intro de guitarra acústica sola
        { bass = N.C2, chord = {N.E3, N.G3, N.B3} },         -- 1: Cmaj7
        { bass = N.C2, chord = {N.E3, N.G3, N.Bb3} },        -- 2: C7
        { bass = N.F2, chord = {N.A3, N.C4, N.E4} },         -- 3: Fmaj7
        { bass = N.F1, chord = {N.Ab3, N.C4, N.D4} },        -- 4: Fm6

        -- Compases 5-12: Estrofa 1
        { bass = N.C2, chord = {N.E3, N.G3, N.B3} },         -- 5: Cmaj7
        { bass = N.C2, chord = {N.E3, N.G3, N.Bb3} },        -- 6: C7
        { bass = N.F2, chord = {N.A3, N.C4, N.E4} },         -- 7: Fmaj7
        { bass = N.F1, chord = {N.Ab3, N.C4, N.D4} },        -- 8: Fm6
        { bass = N.C2, chord = {N.E3, N.G3, N.B3} },         -- 9: Cmaj7
        { bass = N.A1, chord = {N.G3, N.Cs4, N.E4} },        -- 10: A7
        { bass = N.D2, chord = {N.F3, N.A3, N.C4} },         -- 11: Dm7
        { bass = N.G1, chord = {N.F3, N.B3, N.D4} },         -- 12: G7

        -- Compases 13-20: Estrofa 2 (Desarrollo melódico)
        { bass = N.C2, chord = {N.E3, N.G3, N.B3} },         -- 13: Cmaj7
        { bass = N.C2, chord = {N.E3, N.G3, N.Bb3} },        -- 14: C7
        { bass = N.F2, chord = {N.A3, N.C4, N.E4} },         -- 15: Fmaj7
        { bass = N.F1, chord = {N.Ab3, N.C4, N.D4} },        -- 16: Fm6
        { bass = N.E2, chord = {N.G3, N.B3, N.D4} },         -- 17: Em7
        { bass = N.A1, chord = {N.C4, N.E4, N.G4} },         -- 18: Am7
        { bass = N.D2, chord = {N.F3, N.A3, N.C4, N.E4} },   -- 19: Dm9
        { bass = N.G1, chord = {N.F3, N.Ab3, N.B3, N.D4} },  -- 20: G7(b9)

        -- Compases 21-28: Puente Melancólico
        { bass = N.F2, chord = {N.A3, N.C4, N.E4} },         -- 21: Fmaj7
        { bass = N.Ab1, chord = {N.Ab3, N.C4, N.D4} },       -- 22: Fm6
        { bass = N.E2, chord = {N.G3, N.B3, N.D4} },         -- 23: Em7
        { bass = N.A1, chord = {N.G3, N.Cs4, N.E4} },        -- 24: A7
        { bass = N.D2, chord = {N.F3, N.A3, N.C4} },         -- 25: Dm7
        { bass = N.F1, chord = {N.Ab3, N.C4, N.Eb4, N.G4} }, -- 26: Fm9 (Melancolía armónica profunda)
        { bass = N.G1, chord = {N.E3, N.G3, N.B3, N.E4} },   -- 27: Cmaj7/G
        { bass = N.G1, chord = {N.F3, N.B3, N.D4} },         -- 28: G7

        -- Compases 29-36: Coda y Outro Dulce
        { bass = N.F2, chord = {N.A3, N.C4, N.E4} },         -- 29: Fmaj7
        { bass = N.Ab1, chord = {N.Ab3, N.C4, N.D4} },       -- 30: Fm6
        { bass = N.C2, chord = {N.E3, N.G3, N.B3} },         -- 31: Cmaj7
        { bass = N.A1, chord = {N.C4, N.E4, N.G4} },         -- 32: Am7
        { bass = N.D2, chord = {N.F3, N.A3, N.C4} },         -- 33: Dm7
        { bass = N.Ab1, chord = {N.Ab3, N.C4, N.D4} },       -- 34: Fm6
        { bass = N.C2, chord = {N.E3, N.G3, N.B3} },         -- 35: Cmaj7
        { bass = N.G1, chord = {N.F3, N.B3, N.D4} }          -- 36: G7sus4 -> G7
    }

    -- 1. Base rítmica de guitarra de nylon
    for barIdx, h in ipairs(harmony) do
        local base = (barIdx - 1) * 12
        -- Pulso 1: Golpe de pulgar limpio y nítido
        addNote(guitarBuffer, Instruments.nylonBass, h.bass, base + 1, 4.0)

        -- Cello suave entra a partir del compás 5 como colchón armónico
        if barIdx >= 5 and barIdx <= 34 then
            addNote(wetBuffer, Instruments.chamberCello, h.bass, base + 1, 10.0)
        end

        -- Pulsos 2 y 3: Acordes suaves y cálidos de cuerdas pulsadas
        addChord(guitarBuffer, Instruments.nylonChord, h.chord, base + 5, 3.5)
        addChord(guitarBuffer, Instruments.nylonChord, h.chord, base + 9, 3.5)
    end

    -- 2. Melodía poética y dulce (Celesta / Caja de música acústica)
    local melodyNotes = {
        -- Compás 5-12: Estrofa 1
        { N.E4, 49, 4.0 }, { N.G4, 53, 4.0 }, { N.B4, 57, 4.0 },
        { N.Bb4, 61, 4.0 }, { N.A4, 65, 4.0 }, { N.G4, 69, 4.0 },
        { N.A4, 73, 4.0 }, { N.C5, 77, 4.0 }, { N.E5, 81, 4.0 },
        { N.D5, 85, 4.0 }, { N.C5, 89, 3.5 }, { N.Ab4, 93, 4.0 },
        { N.G4, 97, 6.0 }, { N.E4, 103, 5.0 },
        { N.G4, 109, 4.0 }, { N.A4, 113, 4.0 }, { N.Cs5, 117, 4.0 },
        { N.F4, 121, 3.0 }, { N.A4, 124, 3.0 }, { N.D5, 127, 3.0 }, { N.C5, 130, 3.0 },
        { N.B4, 133, 4.0 }, { N.A4, 137, 4.0 }, { N.G4, 141, 4.0 },

        -- Compás 13-20: Estrofa 2 (Registro superior)
        { N.E5, 145, 6.0 }, { N.G5, 151, 6.0 },
        { N.Bb5, 157, 4.0 }, { N.A5, 161, 4.0 }, { N.G5, 165, 4.0 },
        { N.A5, 169, 4.0 }, { N.C6, 173, 4.0 }, { N.E6, 177, 4.0 },
        { N.D6, 181, 4.0 }, { N.C6, 185, 4.0 }, { N.Ab5, 189, 4.0 },
        { N.G5, 193, 6.0 }, { N.E5, 199, 6.0 },
        { N.C5, 205, 4.0 }, { N.E5, 209, 4.0 }, { N.A5, 213, 4.0 },
        { N.F5, 217, 4.0 }, { N.E5, 221, 4.0 }, { N.D5, 225, 4.0 },
        { N.B4, 229, 4.0 }, { N.D5, 233, 4.0 }, { N.F5, 237, 4.0 },

        -- Compás 21-28: Puente Melancólico
        { N.E5, 241, 4.0 }, { N.D5, 245, 4.0 }, { N.C5, 249, 4.0 },
        { N.C5, 253, 4.0 }, { N.Ab4, 257, 4.0 }, { N.F4, 261, 4.0 },
        { N.G4, 265, 4.0 }, { N.B4, 269, 4.0 }, { N.D5, 273, 4.0 },
        { N.Cs5, 277, 4.0 }, { N.E5, 281, 4.0 }, { N.G5, 285, 4.0 },
        { N.F5, 289, 4.0 }, { N.E5, 293, 4.0 }, { N.D5, 297, 4.0 },
        -- Compás 26 (Fm9 - Punto álgido de melancolía)
        { N.C5, 301, 3.0 }, { N.Eb5, 304, 3.0 }, { N.G5, 307, 3.0 }, { N.Ab5, 310, 4.0 },
        { N.E5, 313, 4.0 }, { N.D5, 317, 4.0 }, { N.C5, 321, 4.0 },
        { N.B4, 325, 4.0 }, { N.D5, 329, 4.0 }, { N.F5, 333, 4.0 },

        -- Compás 29-36: Coda y Outro Dulce
        { N.A5, 337, 4.0 }, { N.C6, 341, 4.0 }, { N.E6, 345, 5.0 },
        { N.D6, 349, 4.0 }, { N.C6, 353, 4.0 }, { N.Ab5, 357, 4.0 },
        { N.G5, 361, 4.0 }, { N.E5, 365, 4.0 }, { N.C5, 369, 4.0 },
        { N.E5, 373, 4.0 }, { N.C5, 377, 4.0 }, { N.A4, 381, 4.0 },
        { N.F4, 385, 3.0 }, { N.A4, 388, 3.0 }, { N.C5, 391, 3.0 }, { N.E5, 394, 3.0 },
        -- Compás 34 (Fm6 dulce y nostálgico)
        { N.D5, 397, 4.0 }, { N.C5, 401, 4.0 }, { N.Ab4, 405, 5.0 },
        -- Compás 35 (Cmaj7 resolución dulce)
        { N.G4, 409, 4.0 }, { N.E4, 413, 4.0 }, { N.C4, 417, 4.0 },
        -- Compás 36 (Cadencia final suave hacia el reinicio)
        { N.B4, 421, 3.0 }, { N.G4, 424, 3.0 }, { N.D4, 427, 3.0 }, { N.C4, 430, 3.0 }
    }

    for _, m in ipairs(melodyNotes) do
        addNote(wetBuffer, Instruments.lullabyCeleste, m[1], m[2], m[3])
    end

    -- 3. Retardo estéreo y espacialidad (~535 ms)
    local delaySamples = math.floor(stepDuration * 3.0 * SAMPLE_RATE)
    local delayBuffer = {}
    for i = 1, delaySamples do
        delayBuffer[i] = 0
    end

    local delayIdx = 1
    local feedback = 0.28

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

    -- 4. Mezcla final
    local sd = love.sound.newSoundData(totalSamples, SAMPLE_RATE, 16, 1)
    for i = 0, totalSamples - 1 do
        local g = guitarBuffer[i + 1] or 0
        local w = wetBuffer[i + 1] or 0
        local finalSample = (g * 0.88 + w * 0.72) * 0.82
        sd:setSample(i, clampSample(finalSample))
    end

    return sd
end

--[[
    Genera la pista "opaline_haven" (24 compases en compás de 4/4 / ~68.57 segundos)
    Composición tradicional y nostálgica con instrumentos de 16-bit (koto tradicional punteado,
    chimes vintage, percusión de madera) y 32-bit (flauta de bambú expresiva, bajo folk acústico
    y cuerdas etéreas con resolución cíclica).
--]]
function ProceduralMusic.generateOpalineHaven()
    local bpm = 84
    local beatDuration = 60.0 / bpm
    local stepDuration = beatDuration / 4.0 -- Semicorchea (~0.1786 s, 16 pasos por compás)
    local totalBars = 24
    local totalSteps = totalBars * 16 -- 384 pasos (~68.57 s)
    local totalDuration = totalSteps * stepDuration
    local totalSamples = math.floor(SAMPLE_RATE * totalDuration)

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

    local function addPerc(buf, percFn, startStep, durationSteps)
        local startTime = (startStep - 1) * stepDuration
        local dur = durationSteps * stepDuration
        local startSample = math.floor(startTime * SAMPLE_RATE) + 1
        local numSamples = math.floor(dur * SAMPLE_RATE)

        for s = 0, numSamples - 1 do
            local idx = startSample + s
            if idx <= totalSamples then
                local t = s / SAMPLE_RATE
                local sample = percFn(t, dur)
                buf[idx] = buf[idx] + sample
            end
        end
    end

    -- Esquema armónico de 24 compases en Re Menor / Fa Mayor modal (Dorian / Eólico)
    local barChords = {
        -- Compases 1-4: Introducción tradicional (Koto + percusión sutil)
        { bass = N.D2, pad = {N.F3, N.A3},  koto = {N.D3, N.F3, N.A3, N.D4} }, -- 1: Dm9
        { bass = N.C2, pad = {N.E3, N.G3},  koto = {N.C3, N.E3, N.G3, N.C4} }, -- 2: Cadd9
        { bass = N.Bb1, pad = {N.D3, N.F3}, koto = {N.Bb2, N.D3, N.F3, N.A3} },-- 3: Bbmaj7
        { bass = N.A1, pad = {N.Cs3, N.E3}, koto = {N.A2, N.Cs3, N.E3, N.A3} },-- 4: A7

        -- Compases 5-12: Tema A (Flauta de bambú introduce la melodía principal)
        { bass = N.D2, pad = {N.F3, N.A3},  koto = {N.D3, N.A3, N.D4, N.F4} }, -- 5: Dm9
        { bass = N.Bb1, pad = {N.D3, N.F3}, koto = {N.Bb2, N.F3, N.Bb3, N.D4} },-- 6: Bbmaj7
        { bass = N.C2, pad = {N.E3, N.G3},  koto = {N.C3, N.G3, N.C4, N.E4} }, -- 7: C
        { bass = N.F2, pad = {N.A3, N.C4},  koto = {N.F3, N.C4, N.F4, N.A4} }, -- 8: Fmaj9
        { bass = N.G2, pad = {N.Bb3, N.D4}, koto = {N.G3, N.D4, N.G4, N.Bb4} },-- 9: Gm9
        { bass = N.A1, pad = {N.C3, N.E3},  koto = {N.A2, N.E3, N.A3, N.C4} }, -- 10: Am7
        { bass = N.Bb1, pad = {N.D3, N.F3}, koto = {N.Bb2, N.F3, N.Bb3, N.D4} },-- 11: Bbmaj7
        { bass = N.A1, pad = {N.Cs3, N.E3}, koto = {N.A2, N.E3, N.G3, N.Cs4} },-- 12: A7

        -- Compases 13-20: Tema B (Desarrollo lírico, registro alto, campanillas)
        { bass = N.D2, pad = {N.F3, N.A3},  koto = {N.D3, N.A3, N.D4, N.F4} }, -- 13: Dm
        { bass = N.C2, pad = {N.E3, N.G3},  koto = {N.C3, N.G3, N.C4, N.E4} }, -- 14: C
        { bass = N.Bb1, pad = {N.D3, N.F3}, koto = {N.Bb2, N.F3, N.Bb3, N.D4} },-- 15: Bbmaj7
        { bass = N.F2, pad = {N.A3, N.C4},  koto = {N.F3, N.C4, N.F4, N.A4} }, -- 16: Fmaj7
        { bass = N.G2, pad = {N.Bb3, N.D4}, koto = {N.G3, N.D4, N.G4, N.Bb4} },-- 17: Gm9
        { bass = N.E2, pad = {N.G3, N.Bb3}, koto = {N.E3, N.Bb3, N.D4, N.G4} },-- 18: Em7b5
        { bass = N.A1, pad = {N.Cs3, N.E3}, koto = {N.A2, N.E3, N.A3, N.Cs4} },-- 19: A7
        { bass = N.D2, pad = {N.F3, N.A3},  koto = {N.D3, N.A3, N.D4, N.F4} }, -- 20: Dm9

        -- Compases 21-24: Coda y Puente Cíclico
        { bass = N.Bb1, pad = {N.D3, N.F3}, koto = {N.Bb2, N.F3, N.Bb3, N.D4} },-- 21: Bbmaj7
        { bass = N.C2, pad = {N.E3, N.G3},  koto = {N.C3, N.G3, N.C4, N.D4} }, -- 22: Cadd9
        { bass = N.D2, pad = {N.F3, N.A3},  koto = {N.D3, N.F3, N.A3, N.D4} }, -- 23: Dm9
        { bass = N.A1, pad = {N.E3, N.G3},  koto = {N.A2, N.E3, N.G3, N.A3} }  -- 24: A7sus4 -> Dm
    }

    -- 1. Capa armónica y rítmica
    for bar = 1, totalBars do
        local c = barChords[bar]
        local baseStep = (bar - 1) * 16

        -- Bajo Folk acústico (32-bit)
        addNote(dryBuffer, Instruments.warmFolkBass, c.bass, baseStep + 1, 6.0)
        addNote(dryBuffer, Instruments.warmFolkBass, c.bass, baseStep + 9, 5.0)
        if bar % 2 == 0 then
            addNote(dryBuffer, Instruments.warmFolkBass, c.bass + 7, baseStep + 13, 3.5)
        end

        -- Acordes de soporte de piano acústico (mano izquierda en pulso 1)
        if bar >= 5 and bar <= 24 then
            for _, pNote in ipairs(c.pad) do
                addNote(dryBuffer, Instruments.acousticPiano, pNote, baseStep + 1, 6.0)
            end
        end

        -- Arpegio tradicional de Koto (16-bit vintage)
        local kNotes = c.koto
        addNote(dryBuffer, Instruments.folkKoto, kNotes[1], baseStep + 1, 4.0)
        addNote(dryBuffer, Instruments.folkKoto, kNotes[2], baseStep + 5, 4.0)
        addNote(dryBuffer, Instruments.folkKoto, kNotes[3], baseStep + 9, 4.0)
        addNote(dryBuffer, Instruments.folkKoto, kNotes[4], baseStep + 13, 4.0)

        -- Percusión tradicional sutil (16-bit y 32-bit)
        if bar >= 3 then
            -- Taiko suave en pulso 1 y pulso 3 (32-bit)
            addPerc(dryBuffer, Instruments.softTaiko, baseStep + 1, 4.0)
            addPerc(dryBuffer, Instruments.softTaiko, baseStep + 9, 4.0)

            -- Woodblock tradicional en contratiempos (16-bit)
            addPerc(dryBuffer, Instruments.woodBlock, baseStep + 5, 2.0)
            addPerc(dryBuffer, Instruments.woodBlock, baseStep + 11, 2.0)
            addPerc(dryBuffer, Instruments.woodBlock, baseStep + 15, 2.0)
        end
    end

    -- 2. Melodía Lírica de Piano Acústico Normal (macillo, doble cuerda y sustain)
    local pianoMelody = {
        -- Compás 5-8 (Frase inicial nostálgica)
        { N.D4, 65, 4.0 }, { N.F4, 69, 4.0 }, { N.A4, 73, 6.0 }, { N.G4, 79, 2.0 },
        { N.F4, 81, 4.0 }, { N.D4, 85, 4.0 }, { N.C4, 89, 7.0 },
        { N.F4, 97, 4.0 }, { N.G4, 101, 4.0 }, { N.A4, 105, 5.0 }, { N.C5, 110, 3.0 },
        { N.A4, 113, 6.0 }, { N.G4, 119, 2.0 }, { N.F4, 121, 6.0 },

        -- Compás 9-12 (Respuesta melancólica)
        { N.G4, 129, 4.0 }, { N.A4, 133, 4.0 }, { N.Bb4, 137, 5.0 }, { N.D5, 142, 3.0 },
        { N.C5, 145, 6.0 }, { N.A4, 151, 2.0 }, { N.F4, 153, 6.0 },
        { N.G4, 161, 4.0 }, { N.F4, 165, 4.0 }, { N.D4, 169, 6.0 }, { N.C4, 175, 2.0 },
        { N.D4, 177, 10.0 },

        -- Compás 13-16 (Tema B - Registro elevado y apasionado)
        { N.A4, 193, 3.0 }, { N.C5, 196, 3.0 }, { N.D5, 199, 4.0 }, { N.F5, 203, 6.0 },
        { N.E5, 209, 4.0 }, { N.D5, 213, 4.0 }, { N.C5, 217, 7.0 },
        { N.D5, 225, 4.0 }, { N.F5, 229, 4.0 }, { N.G5, 233, 5.0 }, { N.A5, 238, 3.0 },
        { N.G5, 241, 6.0 }, { N.F5, 247, 2.0 }, { N.D5, 249, 7.0 },

        -- Compás 17-20 (Clímax y caída dulce)
        { N.Bb4, 257, 4.0 }, { N.D5, 261, 4.0 }, { N.F5, 265, 5.0 }, { N.G5, 270, 3.0 },
        { N.E5, 273, 6.0 }, { N.D5, 279, 2.0 }, { N.Cs5, 281, 6.0 },
        { N.D5, 289, 8.0 }, { N.F5, 297, 4.0 }, { N.E5, 301, 4.0 },
        { N.D5, 305, 12.0 },

        -- Compás 21-24 (Coda nostálgica hacia el reinicio)
        { N.F4, 321, 4.0 }, { N.A4, 325, 4.0 }, { N.C5, 329, 6.0 }, { N.A4, 335, 2.0 },
        { N.G4, 337, 4.0 }, { N.F4, 341, 4.0 }, { N.E4, 345, 6.0 }, { N.C4, 351, 2.0 },
        { N.D4, 353, 14.0 }
    }

    for _, p in ipairs(pianoMelody) do
        addNote(wetBuffer, Instruments.acousticPiano, p[1], p[2], p[3])
    end

    -- 3. Campanillas y Chimes Nostálgicos (16-bit vintage accents)
    local chimeNotes = {
        -- Acentos en compases de reposo
        { N.D6, 77, 4.0 }, { N.A5, 81, 4.0 }, { N.F5, 85, 4.0 },
        { N.C6, 109, 4.0 }, { N.G5, 113, 4.0 },
        { N.D6, 141, 4.0 }, { N.Bb5, 145, 4.0 },
        { N.A5, 173, 4.0 }, { N.F5, 177, 4.0 }, { N.D5, 181, 4.0 },

        { N.F6, 205, 4.0 }, { N.E6, 209, 4.0 }, { N.C6, 213, 4.0 },
        { N.A6, 237, 4.0 }, { N.G6, 241, 4.0 }, { N.D6, 245, 4.0 },
        { N.G6, 269, 4.0 }, { N.E6, 273, 4.0 }, { N.Cs6, 277, 4.0 },
        { N.D6, 301, 5.0 }, { N.A5, 306, 5.0 },

        -- Coda final
        { N.C6, 333, 4.0 }, { N.A5, 337, 4.0 }, { N.F5, 341, 4.0 },
        { N.D5, 361, 6.0 }, { N.A5, 367, 6.0 }, { N.D6, 373, 8.0 }
    }

    for _, ch in ipairs(chimeNotes) do
        addNote(wetBuffer, Instruments.nostalgicChime, ch[1], ch[2], ch[3])
    end

    -- 4. Procesamiento de retardo espacial estéreo (~428 ms)
    local delaySamples = math.floor(stepDuration * 2.4 * SAMPLE_RATE)
    local delayBuffer = {}
    for i = 1, delaySamples do
        delayBuffer[i] = 0
    end

    local delayIdx = 1
    local feedback = 0.28

    for i = 1, totalSamples do
        local dry = wetBuffer[i]
        local echo = delayBuffer[delayIdx]
        local wetVal = dry + echo * feedback
        wetBuffer[i] = wetVal
        delayBuffer[delayIdx] = wetVal
        delayIdx = (delayIdx % delaySamples) + 1
    end

    -- 5. Mezcla y masterización continua a 32-bit
    local sd = love.sound.newSoundData(totalSamples, SAMPLE_RATE, 16, 1)
    for i = 0, totalSamples - 1 do
        local dry = dryBuffer[i + 1] or 0
        local wet = wetBuffer[i + 1] or 0
        local finalSample = (dry * 0.85 + wet * 0.78) * 0.80
        sd:setSample(i, clampSample(finalSample))
    end

    return sd
end

return ProceduralMusic
