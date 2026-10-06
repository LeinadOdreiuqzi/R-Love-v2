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

local NOISE_TABLE_NORM = {}
for i = 1, 2048 do
    NOISE_TABLE_NORM[i] = (math.random() * 2 - 1)
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
    end,

    -- 24. [32-bit Float] Bombo electrónico contundente (Punch Kick)
    electroKick = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 14.0)

        -- Caída rápida de tono (pitch drop agresivo de 160 Hz a 42 Hz)
        local freq = 160.0 * math.exp(-progress * 28.0) + 42.0
        local sub = math.sin(TWO_PI * freq * t)

        -- Click inicial de pegada (transiente de macillo < 4 ms)
        local click = math.sin(TWO_PI * 920.0 * t) * math.exp(-t * 450.0) * 0.45

        return math.tanh((sub + click) * 1.5) * env * 0.65
    end,

    -- 25. [32-bit Float] Caja electrónica con transiente nítido (Snare / Clap)
    crispSnare = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local bodyEnv = math.exp(-progress * 22.0)
        local noiseEnv = math.exp(-progress * 16.0)

        -- Tono resonante de caja
        local tone = math.sin(TWO_PI * 185.0 * t) * 0.45 + math.sin(TWO_PI * 315.0 * t) * 0.25
        local body = tone * bodyEnv

        -- Ráfaga de ruido blanco brillante
        local sIdx = math.floor(t * 44100) % 2048 + 1
        local noise = NOISE_TABLE_NORM[sIdx] * noiseEnv * 0.55

        return math.tanh((body + noise) * 1.4) * 0.52
    end,

    -- 26. [32-bit Float] Charles electrónico cerrado y abierto (Hi-Hat)
    fastHat = function(t, duration, isOpen)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local decayRate = isOpen and 14.0 or 48.0
        local env = math.exp(-progress * decayRate)

        -- Mezcla inarmónica metálica de altas frecuencias
        local m1 = math.sin(TWO_PI * 4200.0 * t)
        local m2 = math.sin(TWO_PI * 6700.0 * t) * 0.65
        local m3 = math.sin(TWO_PI * 8900.0 * t) * 0.45
        local sIdx = math.floor(t * 44100) % 2048 + 1
        local noise = NOISE_TABLE_NORM[sIdx] * 0.40

        local metal = (m1 + m2 + m3 + noise) * 0.35
        return math.tanh(metal * 1.5) * env * (isOpen and 0.28 or 0.20)
    end,

    -- 27. [32-bit Float] Bajo sintetizado galopante (Rolling Bass con sub-armónico)
    rollingBass = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.003)
        local decay = math.exp(-progress * 4.8)

        local w = TWO_PI * freq * t
        -- Diente de sierra sintética rica con corte de filtro dinámico
        local h1 = math.sin(w)
        local h2 = math.sin(w * 2.0) * 0.50 * (1.0 - progress * 0.5)
        local h3 = math.sin(w * 3.0) * 0.28 * (1.0 - progress * 0.7)
        local sub = math.sin(w * 0.5) * 0.35 -- Sub-bajo sólido

        local saw = (h1 + h2 + h3 + sub) * attack * decay
        return math.tanh(saw * 1.45) * 0.48
    end,

    -- 28. [32-bit Float] Pluck / sintetizador brillante para arpegios rápidos (Sparkle Pluck)
    sparklePluck = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.002)
        local decay = math.exp(-progress * 6.5)

        -- Doble oscilador ligeramente detuneado para dar brillo estéreo
        local w1 = TWO_PI * baseFreq * t
        local w2 = TWO_PI * (baseFreq * 1.002) * t

        local f1 = (math.sin(w1) + math.sin(w2)) * 0.50
        local f2 = math.sin(w1 * 2.0) * 0.35 * math.exp(-progress * 12.0)
        local f3 = math.sin(w1 * 3.0) * 0.15 * math.exp(-progress * 18.0)

        local sample = math.tanh((f1 + f2 + f3) * 1.3) * attack * decay
        return sample * 0.38
    end,

    -- 29. [32-bit Float] Lead de Piano Sintético Melancólico (Synth Piano Lead: transiente de macillo, micro-chorus analógico y sustain cantarín)
    synthPianoLead = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        -- Transiente percusivo de macillo sintético (< 2.5 ms)
        local attack = math.min(1.0, t / 0.0025)
        local hammer = math.sin(TWO_PI * 190.0 * t) * math.exp(-t * 280.0) * 0.18

        -- Modulación melancólica sutil en notas sostenidas (>160 ms)
        local vibDelay = 0.16
        local vibDepth = t > vibDelay and math.min(1.0, (t - vibDelay) / 0.28) * 0.0035 or 0
        local freq = baseFreq * (1.0 + math.sin(TWO_PI * 4.5 * t) * vibDepth)

        -- Doble oscilador unísono con micro-chorus analógico (1.0012) para calidez melancólica
        local w1 = TWO_PI * freq * t
        local w2 = TWO_PI * (freq * 1.0012) * t

        -- Envolvente dual de piano sintetizado: brillo inicial dinámico + sustain cantarín
        local brightnessDecay = math.exp(-progress * 8.0)
        local singingSustain = math.exp(-progress * 2.4)
        local promptDecay = (1.0 - progress) * (1.0 - progress)
        local release = math.max(0, 1.0 - math.max(0, (progress - 0.82) / 0.18))

        -- Armónicos de piano sintetizado (cuerpo acústico + tine/campana brillante)
        local fund = (math.sin(w1) + math.sin(w2)) * 0.50 * (singingSustain * 0.7 + promptDecay * 0.3)
        local h2 = math.sin(w1 * 2.0) * 0.32 * singingSustain
        local h3 = math.sin(w1 * 3.0) * 0.22 * brightnessDecay -- Brillo de lengüeta/tine
        local h4 = math.sin(w1 * 4.0) * 0.10 * brightnessDecay
        local body = math.sin(w1 * 0.5) * 0.08 * singingSustain -- Calidez subarmónica

        local pianoTone = (fund + h2 + h3 + h4 + body) * attack * release
        local sample = (pianoTone + hammer) * 1.15
        return math.tanh(sample) * 0.48
    end,
    singingLead = function(note, t, duration)
        return Instruments.synthPianoLead(note, t, duration)
    end,
    supersawLead = function(note, t, duration)
        return Instruments.synthPianoLead(note, t, duration)
    end,

    -- 30. [32-bit Float] Acordes de sintetizador envolvente (Saw Chords)
    sawChords = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.015)
        local release = math.exp(-math.max(0, (progress - 0.70) * 5.0))
        local env = attack * release

        local w = TWO_PI * baseFreq * t
        local wDetune = TWO_PI * (baseFreq * 1.004) * t

        local h1 = (math.sin(w) + math.sin(wDetune)) * 0.50
        local h2 = math.sin(w * 2.0) * 0.25

        local sample = math.tanh((h1 + h2) * 1.1) * env
        return sample * 0.22
    end,

    -- 31. [32-bit Float] Campanilla cristalina de contra-melodía (Crystal Bell)
    crystalBell = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.003)
        local decay = math.exp(-progress * 4.0)

        local fund = math.sin(TWO_PI * freq * t)
        local tine = math.sin(TWO_PI * (freq * 3.0) * t) * 0.20 * math.exp(-progress * 10.0)

        return (fund + tine) * attack * decay * 0.25
    end,

    -- 32. [32-bit Float] Caja de música mecánica de púas de latón (Music Box)
    carouselMusicBox = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.0015)
        local decay = math.exp(-progress * 5.2)

        -- Púa de acero sobre cilindro de latón (parciales inarmónicos)
        local fund = math.sin(TWO_PI * baseFreq * t)
        local part2 = math.sin(TWO_PI * (baseFreq * 2.76) * t) * 0.28 * math.exp(-progress * 9.0)
        local part3 = math.sin(TWO_PI * (baseFreq * 5.40) * t) * 0.14 * math.exp(-progress * 15.0)

        -- Click mecánico sutil de escape
        local click = math.sin(TWO_PI * 1400.0 * t) * math.exp(-t * 350.0) * 0.12

        local sample = (fund + part2 + part3 + click) * attack * decay
        return math.tanh(sample * 1.1) * 0.38
    end,

    -- 33. [32-bit Float] Acordeón de carrusel (Doble lengüeta batiente estilo Musette)
    carouselAccordion = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        -- Ataque de fuelle de aire
        local attack = math.min(1.0, t / 0.018)
        local release = math.max(0, 1.0 - math.max(0, (progress - 0.75) / 0.25))
        local env = attack * release

        -- Doble lengüeta afinada con batido musette (desafine de 2.4 cents)
        local w1 = TWO_PI * baseFreq * t
        local w2 = TWO_PI * (baseFreq * 1.0025) * t

        -- Onda compuesta rica en armónicos impares (lengüeta libre en cámara de madera)
        local r1 = math.sin(w1) + math.sin(w1 * 2.0) * 0.35 + math.sin(w1 * 3.0) * 0.25
        local r2 = math.sin(w2) + math.sin(w2 * 2.0) * 0.35 + math.sin(w2 * 3.0) * 0.25

        -- Soplido de aire tenue
        local sIdx = math.floor(t * 44100) % 2048 + 1
        local breath = NOISE_TABLE_NORM[sIdx] * 0.03 * (1.0 - progress * 0.5)

        local raw = (r1 + r2 + breath) * 0.40
        return math.tanh(raw * 1.25) * env * 0.32
    end,

    -- 34. [32-bit Float] Piano de salón melódico (macillo de fieltro, triple unísono acústico y decaimiento cantarín)
    carouselPianoLead = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        -- 1. Transiente percusivo del macillo de fieltro (< 2.5 ms)
        local attack = math.min(1.0, t / 0.0020)
        local hammerKnock = math.sin(TWO_PI * 170.0 * t) * math.exp(-t * 260.0) * 0.16

        -- 2. Triple cuerda al unísono acústico con micro-batido de concierto (afinado fino)
        local w1 = TWO_PI * baseFreq * t
        local w2 = TWO_PI * (baseFreq * 1.0006) * t
        local w3 = TWO_PI * (baseFreq * 0.9994) * t

        -- 3. Decaimiento armónico acústico natural (prompt sound inicial + sustain dulce)
        local prompt = math.exp(-t * 14.0)
        local sustain = math.exp(-progress * 2.6)
        local release = math.max(0, 1.0 - math.max(0, (progress - 0.88) / 0.12))

        local h1 = (math.sin(w1) * 0.48 + math.sin(w2) * 0.28 + math.sin(w3) * 0.24) * sustain
        local h2 = math.sin(w1 * 2.0) * 0.30 * (sustain * 0.65 + prompt * 0.35)
        local h3 = math.sin(w1 * 3.0) * 0.14 * prompt
        local h4 = math.sin(w1 * 4.0) * 0.05 * (prompt * prompt)

        -- 4. Resonancia del arpa y caja armónica de madera
        local body = math.sin(TWO_PI * (baseFreq * 0.5) * t) * 0.08 * sustain

        local stringSound = (h1 + h2 + h3 + h4 + body) * attack * release
        local sample = (stringSound + hammerKnock) * 0.70
        return math.tanh(sample * 1.18) * 0.50
    end,

    twinWoodwindLead = function(note, t, duration)
        return Instruments.carouselPianoLead(note, t, duration)
    end,

    -- 35. [32-bit Float] Bajo pizzicato acústico de madera (Pizzicato Upright Bass)
    pizzWaltzBass = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.003)
        local decay = math.exp(-progress * 4.2)

        local w = TWO_PI * freq * t
        local fund = math.sin(w)
        local h2 = math.sin(w * 2.0) * 0.35 * (1.0 - progress * 0.6)
        local sub = math.sin(w * 0.5) * 0.25

        -- Transiente de cuerda pulsada con el pulgar
        local pluck = math.sin(TWO_PI * 130.0 * t) * math.exp(-t * 220.0) * 0.22

        local sample = (fund + h2 + sub + pluck) * attack * decay
        return math.tanh(sample * 1.35) * 0.50
    end,

    -- 36. [32-bit Float] Glockenspiel de juguete brillante (Toy Glockenspiel)
    toyGlockenspiel = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.001)
        local decay = math.exp(-progress * 6.5)

        local bar1 = math.sin(TWO_PI * freq * t)
        local bar2 = math.sin(TWO_PI * (freq * 3.0) * t) * 0.25 * math.exp(-progress * 12.0)
        local strike = math.sin(TWO_PI * 2200.0 * t) * math.exp(-t * 500.0) * 0.15

        return (bar1 + bar2 + strike) * attack * decay * 0.30
    end,

    -- 37. [32-bit Float] Pandereta de carrusel (Carousel Tambourine)
    carnivalTambourine = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 24.0)

        -- Tintineo de cascabeles metálicos
        local j1 = math.sin(TWO_PI * 5400.0 * t)
        local j2 = math.sin(TWO_PI * 7200.0 * t) * 0.7
        local j3 = math.sin(TWO_PI * 9600.0 * t) * 0.5
        local sIdx = math.floor(t * 44100) % 2048 + 1
        local noise = NOISE_TABLE_NORM[sIdx] * 0.45

        local metal = (j1 + j2 + j3 + noise) * 0.30
        return math.tanh(metal * 1.4) * env * 0.24
    end,

    -- 38. [32-bit Float] Bombo acústico de carrusel (Soft Carnival Drum)
    carnivalKick = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local progress = t / duration
        local env = math.exp(-progress * 10.0)
        local freq = 110.0 * math.exp(-progress * 14.0) + 48.0
        local tone = math.sin(TWO_PI * freq * t)
        return math.tanh(tone * 1.3) * env * 0.45
    end,

    -- 39. [32-bit Float] Tictac mecánico de engranajes (Clockwork Tick)
    clockworkTick = function(t, duration)
        if t < 0 or t >= duration then return 0 end
        local env = math.exp(-t * 220.0)
        local tick = math.sin(TWO_PI * 1850.0 * t) * env
        return tick * 0.18
    end,

    -- 40. [32-bit Float] Arpa nostálgica etérea (pulsación de yema de dedos, dispersión armónica y resonancia de caja)
    angelicHarp = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.0025)
        local pluckFlesh = (t < 0.035) and (math.sin(TWO_PI * 160.0 * t) * math.exp(-t * 260.0) * 0.18) or 0
        local pluckNail = (t < 0.015) and (math.sin(TWO_PI * 2200.0 * t) * math.exp(-t * 650.0) * 0.05) or 0

        local w1 = TWO_PI * baseFreq * t
        local prompt = (t < 0.45) and math.exp(-t * 14.0) or 0
        local sustain = math.exp(-progress * 2.2)
        local release = (progress > 0.88) and math.max(0, 1.0 - (progress - 0.88) / 0.12) or 1.0

        local h1 = math.sin(w1) * sustain
        local h2 = math.sin(w1 * 2.0008) * 0.28 * (sustain * 0.7 + prompt * 0.3)
        local h3 = (prompt > 0.001) and (math.sin(w1 * 3.002) * 0.10 * prompt) or 0

        local body = math.sin(w1 * 0.5) * 0.09 * sustain

        local stringSound = (h1 + h2 + h3 + body) * attack * release
        local sample = (stringSound + pluckFlesh + pluckNail) * 0.62
        return math.tanh(sample * 1.12) * 0.40
    end,

    -- 41. [32-bit Float] Coro celestial etéreo melancólico (respiración profunda, formantes 'Aah' envolventes)
    celestialChoir = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.40)
        local release = math.max(0, 1.0 - math.max(0, (progress - 0.75) / 0.25))
        local env = attack * release

        -- Modulación lenta y nostálgica
        local vib = math.sin(TWO_PI * 3.8 * t) * 0.0030
        local f1 = baseFreq * (1.0 + vib)
        local f2 = baseFreq * 1.0015 * (1.0 - vib * 0.7)
        local f3 = baseFreq * 0.9985 * (1.0 + vib * 0.5)

        local o1 = math.sin(TWO_PI * f1 * t)
        local o2 = math.sin(TWO_PI * f2 * t) * 0.85
        local o3 = math.sin(TWO_PI * f3 * t) * 0.85

        local formant1 = math.sin(TWO_PI * 720.0 * t) * 0.10
        local formant2 = math.sin(TWO_PI * 1150.0 * t) * 0.06

        local raw = (o1 + o2 + o3 + formant1 + formant2) * 0.28
        return math.tanh(raw * 1.15) * env * 0.32
    end,

    -- 42. [32-bit Float] Piano de cola acústico nostálgico / fieltro íntimo (felt hammer, micro-deriva nostálgica, decaimiento dulce)
    angelicPianoLead = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local baseFreq = midiToFreq(note)
        local progress = t / duration

        -- 1. Transiente cálido de macillo de fieltro (~3.2 ms, amortiguado y suave)
        local attack = math.min(1.0, t / 0.0032)
        local hammerKnock = math.sin(TWO_PI * 145.0 * t) * math.exp(-t * 220.0) * 0.10

        -- 2. Deriva nostálgica muy sutil (efecto cinta vintage / piano vertical íntimo)
        local drift = math.sin(TWO_PI * 1.35 * t) * 0.00075

        -- 3. Triple cuerda al unísono acústico con micro-batido
        local w1 = TWO_PI * (baseFreq * (1.0 + drift)) * t
        local w2 = TWO_PI * (baseFreq * (1.0005 + drift * 0.8)) * t
        local w3 = TWO_PI * (baseFreq * (0.9995 - drift * 0.6)) * t

        -- 4. Decaimiento armónico acústico nostálgico (sustain más cantarín y resonante)
        local prompt = math.exp(-t * 11.0)
        local sustain = math.exp(-progress * 1.8)
        local release = math.max(0, 1.0 - math.max(0, (progress - 0.90) / 0.10))

        local h1 = (math.sin(w1) * 0.52 + math.sin(w2) * 0.26 + math.sin(w3) * 0.22) * sustain
        local h2 = math.sin(w1 * 2.0) * 0.28 * (sustain * 0.70 + prompt * 0.30)
        local h3 = math.sin(w1 * 3.0) * 0.10 * prompt
        local h4 = math.sin(w1 * 4.0) * 0.03 * (prompt * prompt)

        -- 5. Resonancia de caja armónica de madera
        local body = math.sin(TWO_PI * (baseFreq * 0.5) * t) * 0.10 * sustain

        local stringSound = (h1 + h2 + h3 + h4 + body) * attack * release
        local sample = (stringSound + hammerKnock) * 0.72
        return math.tanh(sample * 1.15) * 0.48
    end,

    silverFlute = function(note, t, duration)
        return Instruments.angelicPianoLead(note, t, duration)
    end,

    -- 43. [32-bit Float] Destellos de campanas de cristal (Stardust Crystal Chimes)
    stardustChime = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.001)
        local decay = math.exp(-progress * 5.8)

        local c1 = math.sin(TWO_PI * freq * t)
        local c2 = math.sin(TWO_PI * (freq * 2.756) * t) * 0.24 * math.exp(-progress * 10.0)
        local c3 = math.sin(TWO_PI * (freq * 5.404) * t) * 0.12 * math.exp(-progress * 16.0)
        local strike = math.sin(TWO_PI * 3400.0 * t) * math.exp(-t * 600.0) * 0.18

        return (c1 + c2 + c3 + strike) * attack * decay * 0.28
    end,

    -- 44. [32-bit Float] Contrabajo acústico profundo (Deep Upright Bass)
    deepAcousticBass = function(note, t, duration)
        if t < 0 or t >= duration then return 0 end
        local freq = midiToFreq(note)
        local progress = t / duration

        local attack = math.min(1.0, t / 0.004)
        local decay = math.exp(-progress * 3.2)

        local w = TWO_PI * freq * t
        local fund = math.sin(w)
        local sub = math.sin(w * 0.5) * 0.35
        local h2 = math.sin(w * 2.0) * 0.25 * (1.0 - progress * 0.6)
        local woodKnock = math.sin(TWO_PI * 110.0 * t) * math.exp(-t * 180.0) * 0.20

        local sample = (fund + sub + h2 + woodKnock) * attack * decay
        return math.tanh(sample * 1.3) * 0.48
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

-- ============================================================================
-- GENERADOR DE LA BANDA SONORA "ASTRAL_PULSE"
-- ============================================================================

--[[
    Pista electrónica melódica de alta energía (144 BPM, 40 compases / ~66.67 s)
    Síntesis continua de 32-bit en punto flotante:
    - Arpegios rápidos en semicorcheas con doble oscilador detuneado
    - Bajo galopante con sub-graves y modulación armónica
    - Percusión electrónica: Bombo 4-on-the-floor con caída exponencial y caja nítida
    - Lead melódico de piano sintético (Synth Piano Lead) con transiente percusivo, micro-chorus analógico y sustain cantarín
    - Acordes estéreo y contra-melodías de campana cristalina
    - Estructura: Intro (8) -> Estrofa A (8) -> Pre-coro (8) -> Coro clímax (12) -> Outro (4)
--]]
function ProceduralMusic.generateAstralPulse()
    local bpm = 144
    local beatDuration = 60.0 / bpm
    local stepDuration = beatDuration / 4.0 -- Semicorchea (~0.10417 s)
    local totalBars = 40
    local totalSteps = totalBars * 16 -- 640 semicorcheas (~66.67 s)
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

    local function addPerc(buf, percFn, startStep, durationSteps, param)
        local startTime = (startStep - 1) * stepDuration
        local dur = durationSteps * stepDuration
        local startSample = math.floor(startTime * SAMPLE_RATE) + 1
        local numSamples = math.floor(dur * SAMPLE_RATE)

        for s = 0, numSamples - 1 do
            local idx = startSample + s
            if idx <= totalSamples then
                local t = s / SAMPLE_RATE
                local sample = percFn(t, dur, param)
                buf[idx] = buf[idx] + sample
            end
        end
    end

    -- Esquema armónico de 40 compases (Progresión IV - V - iii - vi)
    local barChords = {}
    local progCycle = {
        { bass = N.Bb1, chords = {N.D4, N.F4, N.A4},   arp = {N.Bb3, N.D4, N.F4, N.A4} },  -- 1: Bbmaj7
        { bass = N.C2,  chords = {N.E4, N.G4, N.C5},   arp = {N.C4, N.E4, N.G4, N.C5} },   -- 2: C
        { bass = N.A1,  chords = {N.C4, N.E4, N.A4},   arp = {N.A3, N.C4, N.E4, N.A4} },   -- 3: Am7
        { bass = N.D2,  chords = {N.F4, N.A4, N.D5},   arp = {N.D4, N.F4, N.A4, N.D5} },   -- 4: Dm
        { bass = N.Bb1, chords = {N.D4, N.F4, N.A4},   arp = {N.Bb3, N.D4, N.F4, N.A4} },  -- 5: Bbmaj7
        { bass = N.C2,  chords = {N.E4, N.G4, N.C5},   arp = {N.C4, N.E4, N.G4, N.C5} },   -- 6: C
        { bass = N.D2,  chords = {N.F4, N.A4, N.C5},   arp = {N.D4, N.F4, N.A4, N.C5} },   -- 7: Dm7
        { bass = N.F1,  chords = {N.F4, N.A4, N.C5},   arp = {N.F3, N.A3, N.C4, N.F4} }    -- 8: F/A
    }

    for b = 1, totalBars do
        local cycleIdx = ((b - 1) % 8) + 1
        barChords[b] = progCycle[cycleIdx]
    end

    -- 1. Base rítmica y arpegios
    for bar = 1, totalBars do
        local c = barChords[bar]
        local baseStep = (bar - 1) * 16

        -- Arpegio veloz de 16 semicorcheas (Sparkle Pluck)
        local arpNotes = c.arp
        for s = 1, 16 do
            local noteIdx = ((s - 1) % #arpNotes) + 1
            addNote(wetBuffer, Instruments.sparklePluck, arpNotes[noteIdx], baseStep + s, 2.0)
        end

        -- Bajo galopante (Rolling Bass) a partir del compás 5
        if bar >= 5 and bar <= 38 then
            for s = 1, 16, 2 do
                local bassNote = (s == 15) and (c.bass + 12) or c.bass
                addNote(dryBuffer, Instruments.rollingBass, bassNote, baseStep + s, 1.8)
            end
        end

        -- Acordes de sintetizador (Saw Chords) en pre-coro y coro (compases 17 a 36)
        if (bar >= 17 and bar <= 36) then
            for _, chNote in ipairs(c.chords) do
                addNote(dryBuffer, Instruments.sawChords, chNote, baseStep + 1, 4.0)
                addNote(dryBuffer, Instruments.sawChords, chNote, baseStep + 7, 3.0)
                addNote(dryBuffer, Instruments.sawChords, chNote, baseStep + 11, 4.0)
            end
        end

        -- Batería electrónica a partir del compás 9
        if bar >= 9 and bar <= 38 then
            -- Bombo 4-on-the-floor
            addPerc(dryBuffer, Instruments.electroKick, baseStep + 1, 3.0)
            addPerc(dryBuffer, Instruments.electroKick, baseStep + 5, 3.0)
            addPerc(dryBuffer, Instruments.electroKick, baseStep + 9, 3.0)
            addPerc(dryBuffer, Instruments.electroKick, baseStep + 13, 3.0)

            -- Caja en pulsos 2 y 4 (pasos 5 y 13)
            addPerc(dryBuffer, Instruments.crispSnare, baseStep + 5, 3.0)
            addPerc(dryBuffer, Instruments.crispSnare, baseStep + 13, 3.0)

            -- Redoble en compás de transición (compás 24 y 36)
            if bar == 24 or bar == 36 then
                addPerc(dryBuffer, Instruments.crispSnare, baseStep + 11, 2.0)
                addPerc(dryBuffer, Instruments.crispSnare, baseStep + 14, 1.5)
                addPerc(dryBuffer, Instruments.crispSnare, baseStep + 15, 1.5)
            end

            -- Charles en semicorcheas con acento abierto en contratiempos
            for h = 1, 16 do
                local isOpen = (h % 4 == 3)
                addPerc(dryBuffer, Instruments.fastHat, baseStep + h, 1.5, isOpen)
            end
        elseif bar >= 5 and bar <= 8 then
            -- Solo charles cerrado en la segunda mitad de la intro
            for h = 1, 16, 2 do
                addPerc(dryBuffer, Instruments.fastHat, baseStep + h, 1.0, false)
            end
        end
    end

    -- 2. Melodía Principal (Piano Sintético Melancólico / Synth Piano Lead)
    -- Compases 9-16 (Estrofa 1)
    local verseMelody = {
        { N.F4, 129, 3.0 }, { N.G4, 132, 3.0 }, { N.A4, 135, 4.0 }, { N.C5, 139, 4.0 },
        { N.D5, 145, 6.0 }, { N.C5, 151, 4.0 }, { N.A4, 155, 4.0 },
        { N.G4, 161, 4.0 }, { N.F4, 165, 4.0 }, { N.E4, 169, 4.0 }, { N.D4, 173, 4.0 },
        { N.F4, 177, 8.0 }, { N.G4, 185, 4.0 },

        { N.F4, 193, 3.0 }, { N.G4, 196, 3.0 }, { N.A4, 199, 4.0 }, { N.C5, 203, 4.0 },
        { N.D5, 209, 6.0 }, { N.F5, 215, 4.0 }, { N.E5, 219, 4.0 },
        { N.D5, 225, 4.0 }, { N.C5, 229, 4.0 }, { N.A4, 233, 4.0 }, { N.G4, 237, 4.0 },
        { N.A4, 241, 12.0 }
    }

    -- Compases 17-24 (Pre-coro con tensión ascendente)
    local preChorusMelody = {
        { N.D4, 257, 4.0 }, { N.F4, 261, 4.0 }, { N.A4, 265, 4.0 }, { N.D5, 269, 4.0 },
        { N.C5, 273, 6.0 }, { N.Bb4, 279, 4.0 }, { N.A4, 283, 4.0 },
        { N.G4, 289, 4.0 }, { N.A4, 293, 4.0 }, { N.Bb4, 297, 4.0 }, { N.C5, 301, 4.0 },
        { N.D5, 305, 8.0 }, { N.E5, 313, 6.0 },

        { N.F5, 321, 6.0 }, { N.E5, 327, 4.0 }, { N.D5, 331, 4.0 },
        { N.E5, 337, 6.0 }, { N.D5, 343, 4.0 }, { N.C5, 347, 4.0 },
        { N.D5, 353, 14.0 }, { N.E5, 367, 3.0 }
    }

    -- Compases 25-36 (Coro clímax / Registro álgido y emotivo)
    local chorusMelody = {
        { N.F5, 385, 4.0 }, { N.G5, 389, 4.0 }, { N.A5, 393, 6.0 }, { N.G5, 399, 4.0 },
        { N.F5, 403, 4.0 }, { N.E5, 407, 4.0 }, { N.D5, 411, 4.0 }, { N.C5, 415, 6.0 },
        { N.D5, 421, 6.0 }, { N.F5, 427, 4.0 }, { N.A5, 431, 6.0 },
        { N.G5, 437, 8.0 }, { N.E5, 445, 4.0 },

        { N.F5, 449, 4.0 }, { N.G5, 453, 4.0 }, { N.A5, 457, 6.0 }, { N.C6, 463, 4.0 },
        { N.D6, 467, 8.0 }, { N.C6, 475, 4.0 }, { N.A5, 479, 4.0 },
        { N.G5, 483, 4.0 }, { N.F5, 487, 4.0 }, { N.G5, 491, 4.0 }, { N.A5, 495, 4.0 },
        { N.D5, 499, 12.0 },

        -- Compases 33-36 (Coda del coro y resolución)
        { N.Bb5, 513, 4.0 }, { N.A5, 517, 4.0 }, { N.G5, 521, 4.0 }, { N.F5, 525, 4.0 },
        { N.E5, 529, 4.0 }, { N.F5, 533, 4.0 }, { N.G5, 537, 6.0 },
        { N.A5, 545, 8.0 }, { N.G5, 553, 4.0 }, { N.F5, 557, 4.0 },
        { N.D5, 561, 14.0 }
    }

    for _, m in ipairs(verseMelody) do
        addNote(wetBuffer, Instruments.synthPianoLead, m[1], m[2], m[3])
    end
    for _, m in ipairs(preChorusMelody) do
        addNote(wetBuffer, Instruments.synthPianoLead, m[1], m[2], m[3])
    end
    for _, m in ipairs(chorusMelody) do
        addNote(wetBuffer, Instruments.synthPianoLead, m[1], m[2], m[3])
    end

    -- 3. Contra-melodía de campanas cristalinas (Crystal Bell)
    local bells = {
        { N.D6, 387, 4.0 }, { N.A6, 395, 4.0 }, { N.F6, 403, 4.0 },
        { N.E6, 419, 4.0 }, { N.C6, 427, 4.0 },
        { N.D6, 451, 4.0 }, { N.F6, 459, 4.0 }, { N.A6, 467, 4.0 },
        { N.G6, 485, 4.0 }, { N.E6, 493, 4.0 },
        { N.D6, 515, 4.0 }, { N.Bb5, 523, 4.0 }, { N.G5, 531, 4.0 },
        { N.A5, 547, 6.0 }, { N.D6, 563, 8.0 }
    }
    for _, b in ipairs(bells) do
        addNote(wetBuffer, Instruments.crystalBell, b[1], b[2], b[3])
    end

    -- 4. Procesamiento de retardo espacial tempo-sincronizado (~312 ms)
    local delaySamples = math.floor(stepDuration * 3.0 * SAMPLE_RATE)
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
        local finalSample = (dry * 0.82 + wet * 0.75) * 0.82
        sd:setSample(i, clampSample(finalSample))
    end

    return sd
end

-- ============================================================================
-- GENERADOR DE LA BANDA SONORA "TRACK 7" (VALS MODAL DE CARRUSEL EN 3/4)
-- ============================================================================

--[[
    Pista en compás de 3/4 (Vals mecánico de carrusel, 192 BPM, 64 compases / 60.0 s)
    Síntesis continua de 32-bit en coma flotante:
    - Caja de música mecánica con parciales inarmónicos de lengüeta metálica
    - Acordeón de carrusel con batido musette de doble lengüeta
    - Bajo acústico pizzicato en primer pulso y bombo de feria
    - Melodía solista de piano de salón acústico con macillo de fieltro, triple unísono y decaimiento cantarín
    - Glockenspiel brillante en notas álgidas del clímax
    - Tictac rítmico continuo de engranajes mecánicos y pandereta
    - Estructura: Tema A (16) -> Tema B (16) -> Clímax (16) -> Coda y resolución (16)
--]]
function ProceduralMusic.generateCarouselWaltz()
    local bpm = 192
    local beatDuration = 60.0 / bpm -- 0.3125 s
    local stepDuration = beatDuration / 4.0 -- Semicorchea (12 pasos por compás de 3/4, ~0.078125 s)
    local totalBars = 64
    local totalSteps = totalBars * 12 -- 768 pasos (60.0 s)
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

    -- Esquema armónico de 64 compases en La menor (Vals modal de carrusel)
    local progression = {
        -- Tema A (1-8)
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.D2, chords = {N.D4, N.F4, N.A4},   box = {N.D5, N.F5, N.A5} },
        { bass = N.G1, chords = {N.B3, N.D4, N.G4},   box = {N.G4, N.B4, N.D5} },
        { bass = N.C2, chords = {N.C4, N.E4, N.G4},   box = {N.C5, N.E5, N.G5} },
        { bass = N.F1, chords = {N.C4, N.F4, N.A4},   box = {N.A4, N.C5, N.F5} },
        { bass = N.B1, chords = {N.D4, N.F4, N.B4},   box = {N.B4, N.D5, N.F5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.Gs4, N.B4, N.E5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },

        -- Tema A Repetición (9-16)
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.D2, chords = {N.D4, N.F4, N.A4},   box = {N.D5, N.F5, N.A5} },
        { bass = N.G1, chords = {N.B3, N.D4, N.G4},   box = {N.G4, N.B4, N.D5} },
        { bass = N.C2, chords = {N.C4, N.E4, N.G4},   box = {N.C5, N.E5, N.G5} },
        { bass = N.F1, chords = {N.C4, N.F4, N.A4},   box = {N.A4, N.C5, N.F5} },
        { bass = N.B1, chords = {N.D4, N.F4, N.B4},   box = {N.B4, N.D5, N.F5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.Gs4, N.B4, N.E5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },

        -- Tema B (17-24)
        { bass = N.D2, chords = {N.D4, N.F4, N.A4},   box = {N.D5, N.F5, N.A5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.Gs4, N.B4, N.E5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.D2, chords = {N.D4, N.F4, N.A4},   box = {N.D5, N.F5, N.A5} },
        { bass = N.G1, chords = {N.B3, N.D4, N.G4},   box = {N.G4, N.B4, N.D5} },
        { bass = N.C2, chords = {N.C4, N.E4, N.G4},   box = {N.C5, N.E5, N.G5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.Gs4, N.B4, N.E5} },

        -- Tema B2 / Tensión creciente (25-32)
        { bass = N.F1, chords = {N.C4, N.F4, N.A4},   box = {N.A4, N.C5, N.F5} },
        { bass = N.G1, chords = {N.B3, N.D4, N.G4},   box = {N.G4, N.B4, N.D5} },
        { bass = N.E1, chords = {N.B3, N.E4, N.G4},   box = {N.E4, N.G4, N.B4} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.D2, chords = {N.D4, N.F4, N.A4},   box = {N.D5, N.F5, N.A5} },
        { bass = N.B1, chords = {N.D4, N.F4, N.B4},   box = {N.B4, N.D5, N.F5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.Gs4, N.B4, N.E5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.B4, N.E5, N.Gs5} },

        -- Clímax / Gran Carrusel (33-40)
        { bass = N.F1, chords = {N.C4, N.F4, N.A4},   box = {N.A4, N.C5, N.F5} },
        { bass = N.G1, chords = {N.B3, N.D4, N.G4},   box = {N.G4, N.B4, N.D5} },
        { bass = N.E1, chords = {N.B3, N.E4, N.G4},   box = {N.E4, N.G4, N.B4} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.D2, chords = {N.D4, N.F4, N.A4},   box = {N.D5, N.F5, N.A5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.Gs4, N.B4, N.E5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.A1, chords = {N.Cs4, N.E4, N.G4},  box = {N.A4, N.Cs5, N.E5} },

        -- Clímax 2 (41-48)
        { bass = N.D2, chords = {N.D4, N.F4, N.A4},   box = {N.D5, N.F5, N.A5} },
        { bass = N.G1, chords = {N.B3, N.D4, N.G4},   box = {N.G4, N.B4, N.D5} },
        { bass = N.C2, chords = {N.C4, N.E4, N.G4},   box = {N.C5, N.E5, N.G5} },
        { bass = N.F1, chords = {N.C4, N.F4, N.A4},   box = {N.A4, N.C5, N.F5} },
        { bass = N.B1, chords = {N.D4, N.F4, N.B4},   box = {N.B4, N.D5, N.F5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.Gs4, N.B4, N.E5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },

        -- Coda / Desaceleración y caja de música solitaria (49-56)
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.D2, chords = {N.D4, N.F4, N.A4},   box = {N.D5, N.F5, N.A5} },
        { bass = N.G1, chords = {N.B3, N.D4, N.G4},   box = {N.G4, N.B4, N.D5} },
        { bass = N.C2, chords = {N.C4, N.E4, N.G4},   box = {N.C5, N.E5, N.G5} },
        { bass = N.F1, chords = {N.C4, N.F4, N.A4},   box = {N.A4, N.C5, N.F5} },
        { bass = N.B1, chords = {N.D4, N.F4, N.B4},   box = {N.B4, N.D5, N.F5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.Gs4, N.B4, N.E5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },

        -- Resolución cíclica (57-64)
        { bass = N.F1, chords = {N.C4, N.F4, N.A4},   box = {N.A4, N.C5, N.F5} },
        { bass = N.G1, chords = {N.B3, N.D4, N.G4},   box = {N.G4, N.B4, N.D5} },
        { bass = N.E1, chords = {N.B3, N.E4, N.G4},   box = {N.E4, N.G4, N.B4} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.D2, chords = {N.D4, N.F4, N.A4},   box = {N.D5, N.F5, N.A5} },
        { bass = N.E1, chords = {N.D4, N.E4, N.Gs4},  box = {N.Gs4, N.B4, N.E5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} },
        { bass = N.A1, chords = {N.C4, N.E4, N.A4},   box = {N.A4, N.C5, N.E5} }
    }

    -- 1. Capa Rítmica de Vals (Bajo pizzicato en 1, Acordeón en 2 y 3, Percusión y Reloj)
    for bar = 1, totalBars do
        local p = progression[bar]
        local baseStep = (bar - 1) * 12

        -- Pulso 1 (paso 1): Bajo y bombo
        if bar <= 48 or (bar >= 57 and bar <= 62) then
            addNote(dryBuffer, Instruments.pizzWaltzBass, p.bass, baseStep + 1, 4.0)
            if bar >= 9 and bar <= 48 then
                addPerc(dryBuffer, Instruments.carnivalKick, baseStep + 1, 4.0)
            end
        end

        -- Pulsos 2 y 3 (pasos 5 y 9): Acordeón y pandereta
        if bar >= 5 and bar <= 52 then
            for _, chNote in ipairs(p.chords) do
                addNote(wetBuffer, Instruments.carouselAccordion, chNote, baseStep + 5, 3.2)
                addNote(wetBuffer, Instruments.carouselAccordion, chNote, baseStep + 9, 3.2)
            end
            if bar >= 9 and bar <= 48 then
                addPerc(dryBuffer, Instruments.carnivalTambourine, baseStep + 5, 2.0)
                addPerc(dryBuffer, Instruments.carnivalTambourine, baseStep + 9, 2.0)
            end
        end

        -- Caja de música en arpegio de carrusel (giro continuo de 6 corcheas: pasos 1, 3, 5, 7, 9, 11)
        local bNotes = p.box
        local bPat = { bNotes[1], bNotes[2], bNotes[3], bNotes[2], bNotes[3], bNotes[1] + 12 }
        for sIdx = 1, 6 do
            local stepOffset = (sIdx - 1) * 2 + 1
            addNote(wetBuffer, Instruments.carouselMusicBox, bPat[sIdx], baseStep + stepOffset, 2.5)
        end

        -- Tictac mecánico continuo de engranajes
        addPerc(dryBuffer, Instruments.clockworkTick, baseStep + 1, 1.0)
        addPerc(dryBuffer, Instruments.clockworkTick, baseStep + 4, 1.0)
        addPerc(dryBuffer, Instruments.clockworkTick, baseStep + 7, 1.0)
        addPerc(dryBuffer, Instruments.clockworkTick, baseStep + 10, 1.0)
    end

    -- 2. Melodía Solista de Piano de Salón (Carousel Melodic Piano)
    -- Compases 9-16 (Tema A Melancólico)
    local themeAMelody = {
        { N.E5, 97, 4.0 },  { N.D5, 101, 2.0 }, { N.C5, 103, 4.0 }, { N.B4, 107, 2.0 },
        { N.A4, 109, 6.0 }, { N.D5, 115, 4.0 }, { N.F5, 119, 2.0 },
        { N.G5, 121, 6.0 }, { N.D5, 127, 4.0 }, { N.B4, 131, 2.0 },
        { N.C5, 133, 8.0 }, { N.E5, 141, 4.0 },
        { N.F5, 145, 6.0 }, { N.E5, 151, 4.0 }, { N.C5, 155, 2.0 },
        { N.D5, 157, 6.0 }, { N.C5, 163, 4.0 }, { N.B4, 167, 2.0 },
        { N.Gs4, 169, 6.0 },{ N.B4, 175, 4.0 }, { N.D5, 179, 2.0 },
        { N.C5, 181, 4.0 }, { N.B4, 185, 2.0 }, { N.A4, 187, 6.0 }
    }

    -- Compases 17-32 (Tema B - Vals Giratorio)
    local themeBMelody = {
        { N.F5, 193, 4.0 }, { N.E5, 197, 2.0 }, { N.D5, 199, 4.0 }, { N.F5, 203, 2.0 },
        { N.E5, 205, 6.0 }, { N.C5, 211, 4.0 }, { N.A4, 215, 2.0 },
        { N.B4, 217, 4.0 }, { N.C5, 221, 2.0 }, { N.D5, 223, 4.0 }, { N.Gs4, 227, 2.0 },
        { N.A4, 229, 8.0 }, { N.C5, 237, 4.0 },

        { N.D5, 241, 4.0 }, { N.E5, 245, 2.0 }, { N.F5, 247, 4.0 }, { N.A5, 251, 2.0 },
        { N.G5, 253, 6.0 }, { N.D5, 259, 4.0 }, { N.B4, 263, 2.0 },
        { N.C5, 265, 8.0 }, { N.E5, 273, 4.0 },
        { N.E5, 277, 6.0 }, { N.D5, 283, 4.0 }, { N.Gs4, 287, 2.0 },

        -- Escala ascendente de tensión hacia el clímax (compases 25-32)
        { N.A5, 289, 4.0 }, { N.G5, 293, 2.0 }, { N.F5, 295, 4.0 }, { N.A5, 299, 2.0 },
        { N.B5, 301, 4.0 }, { N.A5, 305, 2.0 }, { N.G5, 307, 4.0 }, { N.B5, 311, 2.0 },
        { N.G5, 313, 6.0 }, { N.E5, 319, 4.0 }, { N.G5, 323, 2.0 },
        { N.A5, 325, 6.0 }, { N.C6, 331, 4.0 }, { N.E6, 335, 2.0 },
        { N.F6, 337, 4.0 }, { N.E6, 341, 2.0 }, { N.D6, 343, 4.0 }, { N.F6, 347, 2.0 },
        { N.D6, 349, 6.0 }, { N.B5, 355, 4.0 }, { N.F5, 359, 2.0 },
        { N.Gs5, 361, 6.0 },{ N.B5, 367, 4.0 }, { N.D6, 371, 2.0 },
        { N.E6, 373, 6.0 }, { N.B5, 379, 4.0 }, { N.Gs5, 383, 2.0 }
    }

    -- Compases 33-48 (Clímax - Registro Álgido y Apasionado)
    local climaxMelody = {
        { N.C6, 385, 4.0 }, { N.B5, 389, 2.0 }, { N.A5, 391, 4.0 }, { N.G5, 395, 2.0 },
        { N.B5, 397, 6.0 }, { N.D6, 403, 4.0 }, { N.B5, 407, 2.0 },
        { N.G5, 409, 6.0 }, { N.B5, 415, 4.0 }, { N.E5, 419, 2.0 },
        { N.E5, 421, 6.0 }, { N.A5, 427, 4.0 }, { N.C6, 431, 2.0 },
        { N.A5, 433, 6.0 }, { N.F5, 439, 4.0 }, { N.D5, 443, 2.0 },
        { N.Gs5, 445, 6.0 },{ N.B5, 451, 4.0 }, { N.D6, 455, 2.0 },
        { N.C6, 457, 6.0 }, { N.B5, 463, 4.0 }, { N.A5, 467, 2.0 },
        { N.Cs6, 469, 6.0 },{ N.E6, 475, 4.0 }, { N.G5, 479, 2.0 },

        { N.F5, 481, 6.0 }, { N.A5, 487, 4.0 }, { N.F5, 491, 2.0 },
        { N.G5, 493, 6.0 }, { N.B5, 499, 4.0 }, { N.D6, 503, 2.0 },
        { N.E5, 505, 6.0 }, { N.G5, 511, 4.0 }, { N.C6, 515, 2.0 },
        { N.C6, 517, 6.0 }, { N.A5, 523, 4.0 }, { N.F5, 527, 2.0 },
        { N.D5, 529, 6.0 }, { N.F5, 535, 4.0 }, { N.B5, 539, 2.0 },
        { N.B5, 541, 4.0 }, { N.A5, 545, 2.0 }, { N.Gs5, 547, 4.0 }, { N.B5, 551, 2.0 },
        { N.A5, 553, 10.0 },{ N.E5, 563, 2.0 },
        { N.A4, 565, 12.0 }
    }

    for _, m in ipairs(themeAMelody) do
        addNote(wetBuffer, Instruments.carouselPianoLead, m[1], m[2], m[3])
    end
    for _, m in ipairs(themeBMelody) do
        addNote(wetBuffer, Instruments.carouselPianoLead, m[1], m[2], m[3])
    end
    for _, m in ipairs(climaxMelody) do
        addNote(wetBuffer, Instruments.carouselPianoLead, m[1], m[2], m[3])
    end

    -- 3. Destellos de Glockenspiel en el Clímax (Compases 33-48)
    local glockNotes = {
        { N.A6, 385, 3.0 }, { N.G6, 397, 3.0 }, { N.B6, 409, 3.0 },
        { N.C6, 421, 3.0 }, { N.F6, 433, 3.0 }, { N.Gs6, 445, 3.0 },
        { N.A6, 457, 3.0 }, { N.Cs6, 469, 3.0 }, { N.D6, 481, 3.0 },
        { N.G6, 493, 3.0 }, { N.C6, 505, 3.0 }, { N.F6, 517, 3.0 },
        { N.B5, 529, 3.0 }, { N.Gs6, 541, 3.0 }, { N.A6, 553, 5.0 }
    }
    for _, g in ipairs(glockNotes) do
        addNote(wetBuffer, Instruments.toyGlockenspiel, g[1], g[2], g[3])
    end

    -- 4. Procesamiento de retardo espacial estéreo (~312 ms)
    local delaySamples = math.floor(beatDuration * SAMPLE_RATE)
    local delayBuffer = {}
    for i = 1, delaySamples do
        delayBuffer[i] = 0
    end

    local delayIdx = 1
    local feedback = 0.25

    for i = 1, totalSamples do
        local dry = wetBuffer[i]
        local echo = delayBuffer[delayIdx]
        local wetVal = dry + echo * feedback
        wetBuffer[i] = wetVal
        delayBuffer[delayIdx] = wetVal
        delayIdx = (delayIdx % delaySamples) + 1
    end

    -- 5. Mezcla final y masterización continua a 32 bits
    local sd = love.sound.newSoundData(totalSamples, SAMPLE_RATE, 16, 1)
    for i = 0, totalSamples - 1 do
        local dry = dryBuffer[i + 1] or 0
        local wet = wetBuffer[i + 1] or 0
        local finalSample = (dry * 0.85 + wet * 0.75) * 0.82
        sd:setSample(i, clampSample(finalSample))
    end

    return sd
end

ProceduralMusic.generateTrack7 = ProceduralMusic.generateCarouselWaltz

-- ============================================================================
-- GENERADOR DE LA BANDA SONORA "TRACK 8" (PAISAJE CELESTIAL NOSTÁLGICO EN 4/4)
-- ============================================================================

--[[
    Pista en compás de 4/4 (Paisaje etéreo y melancólico en Fa mayor, 84 BPM, 32 compases / 91.4 s)
    Síntesis continua de 32-bit en coma flotante:
    - Arpa de concierto en cascadas fluidas de 16 notas por compás con pulsación cálida
    - Coro celestial 'Aah' multi-voz con formantes armónicos envolventes y respiración suave
    - Piano de cola acústico de fieltro con micro-deriva nostálgica, decaimiento dulce y fraseo lírico
    - Destellos de campanas de cristal en las crestas melódicas
    - Contrabajo acústico profundo en el pulso 1
    - Retardo espacial con amortiguación cálida paso bajo (difusión nostálgica de catedral)
    - Estructura: Intro (8) -> Melodía A (8) -> Variación Modal B (8) -> Clímax (4) -> Coda (4)
--]]
function ProceduralMusic.generateAngelicFountain()
    local bpm = 84 -- Tempo reposado, íntimo y nostálgico
    local beatDuration = 60.0 / bpm -- ~0.71428 s
    local stepDuration = beatDuration / 4.0 -- Semicorchea (~0.17857 s, 16 pasos por compás de 4/4)
    local totalBars = 32
    local totalSteps = totalBars * 16 -- 512 pasos (~91.43 s)
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

    -- Esquema de acordes y arpegios en cascada de 16 notas por compás en Fa Mayor
    local barsData = {
        -- 1. Fmaj9 (Paz y añoranza pura)
        {
            bass = N.F1,
            choir = { N.A3, N.C4, N.E4, N.G4 },
            harp = { N.F3, N.A3, N.C4, N.E4, N.G4, N.A4, N.C5, N.E5, N.G5, N.E5, N.C5, N.A4, N.G4, N.E4, N.C4, N.A3 }
        },
        -- 2. Dm9 (Suspiro melancólico en Re menor)
        {
            bass = N.D2,
            choir = { N.F3, N.A3, N.C4, N.E4 },
            harp = { N.D3, N.F3, N.A3, N.C4, N.E4, N.F4, N.A4, N.C5, N.E5, N.C5, N.A4, N.F4, N.E4, N.C4, N.A3, N.F3 }
        },
        -- 3. Bbmaj9 (Lirismo subdominante)
        {
            bass = N.Bb1,
            choir = { N.F3, N.Bb3, N.D4, N.F4 },
            harp = { N.Bb2, N.D3, N.F3, N.A3, N.C4, N.D4, N.F4, N.A4, N.C5, N.A4, N.F4, N.D4, N.C4, N.A3, N.F3, N.D3 }
        },
        -- 4. C9sus4 -> C7 (Suspensión armónica)
        {
            bass = N.C2,
            choir = { N.G3, N.Bb3, N.D4, N.E4 },
            harp = { N.C3, N.F3, N.G3, N.Bb3, N.D4, N.E4, N.G4, N.Bb4, N.D5, N.Bb4, N.G4, N.E4, N.D4, N.Bb3, N.G3, N.E3 }
        },
        -- 5. Fmaj9
        {
            bass = N.F1,
            choir = { N.A3, N.C4, N.E4, N.G4 },
            harp = { N.F3, N.A3, N.C4, N.E4, N.G4, N.A4, N.C5, N.E5, N.G5, N.E5, N.C5, N.A4, N.G4, N.E4, N.C4, N.A3 }
        },
        -- 6. Dm9
        {
            bass = N.D2,
            choir = { N.F3, N.A3, N.C4, N.E4 },
            harp = { N.D3, N.F3, N.A3, N.C4, N.E4, N.F4, N.A4, N.C5, N.E5, N.C5, N.A4, N.F4, N.E4, N.C4, N.A3, N.F3 }
        },
        -- 7. Gm9 (Nostalgia profunda con novena y oncena)
        {
            bass = N.G1,
            choir = { N.G3, N.Bb3, N.D4, N.F4 },
            harp = { N.G2, N.Bb2, N.D3, N.F3, N.A3, N.Bb3, N.D4, N.F4, N.A4, N.F4, N.D4, N.Bb3, N.A3, N.F3, N.D3, N.Bb2 }
        },
        -- 8. C7(add9)
        {
            bass = N.C2,
            choir = { N.E3, N.G3, N.Bb3, N.D4 },
            harp = { N.C3, N.E3, N.G3, N.Bb3, N.D4, N.E4, N.G4, N.Bb4, N.C5, N.Bb4, N.G4, N.E4, N.D4, N.Bb3, N.G3, N.E3 }
        }
    }

    -- Construcción de la progresión de 32 compases
    local progression = {}
    for i = 1, 8 do progression[i] = barsData[i] end
    for i = 1, 8 do progression[8 + i] = barsData[i] end

    -- Sección B modal
    progression[17] = {
        bass = N.A1,
        choir = { N.A3, N.C4, N.E4, N.G4 },
        harp = { N.A2, N.C3, N.E3, N.G3, N.A3, N.C4, N.E4, N.G4, N.A4, N.G4, N.E4, N.C4, N.A3, N.G3, N.E3, N.C3 }
    }
    progression[18] = barsData[2] -- Dm9
    progression[19] = barsData[7] -- Gm9
    progression[20] = barsData[4] -- C9sus4
    progression[21] = barsData[3] -- Bbmaj9
    progression[22] = {
        bass = N.A1,
        choir = { N.A3, N.C4, N.E4, N.A4 },
        harp = { N.A2, N.C3, N.E3, N.A3, N.C4, N.E4, N.A4, N.C5, N.E5, N.C5, N.A4, N.E4, N.C4, N.A3, N.E3, N.C3 }
    }
    progression[23] = barsData[7] -- Gm9
    progression[24] = barsData[8] -- C7

    -- Clímax
    progression[25] = barsData[1]
    progression[26] = barsData[2]
    progression[27] = barsData[3]
    progression[28] = barsData[4]

    -- Coda y resolución
    progression[29] = barsData[1]
    progression[30] = barsData[2]
    progression[31] = barsData[7]
    progression[32] = barsData[1]

    -- 1. Capa Armónica y Cascada de Arpa
    for bar = 1, totalBars do
        local p = progression[bar]
        local baseStep = (bar - 1) * 16

        -- Bajo acústico profundo en el pulso 1
        if bar <= 30 then
            addNote(dryBuffer, Instruments.deepAcousticBass, p.bass, baseStep + 1, 14.0)
        end

        -- Coro celestial sostenido
        if bar <= 31 then
            for _, chNote in ipairs(p.choir) do
                addNote(dryBuffer, Instruments.celestialChoir, chNote, baseStep + 1, 16.0)
            end
        end

        -- Arpa en cascada líquida (16 notas continuas)
        local hNotes = p.harp
        for s = 1, 16 do
            addNote(wetBuffer, Instruments.angelicHarp, hNotes[s], baseStep + s, 3.8)
        end
    end

    -- 2. Melodía Solista de Piano Íntimo y Nostálgico
    -- Fraseo con suspiros líricos, notas de apoyatura y pausas expresivas
    local pianoMelody = {
        -- Sección A (Compases 9-16)
        -- C9: Entrada dulce en la 9ª (G4) que asciende al 3º (A4) y reposa en C5
        { N.G4, 129, 4.0 }, { N.A4, 133, 4.0 }, { N.C5, 137, 8.0 },
        -- C10: Suspensión melancólica en E5 (9ª de Dm) que desciende suavemente a D5 y A4
        { N.E5, 145, 6.0 }, { N.D5, 151, 2.0 }, { N.C5, 153, 4.0 }, { N.A4, 157, 4.0 },
        -- C11: Lamento lírico sobre Bbmaj9 (D5 -> C5 -> Bb4)
        { N.D5, 161, 6.0 }, { N.C5, 167, 2.0 }, { N.Bb4, 169, 4.0 }, { N.A4, 173, 4.0 },
        -- C12: Resolución tenue a C7 (G4 -> F4 -> E4)
        { N.G4, 177, 8.0 }, { N.F4, 185, 4.0 }, { N.E4, 189, 4.0 },

        -- C13: Segunda frase con mayor anhelo emotivo (Fmaj9)
        { N.A4, 193, 4.0 }, { N.C5, 197, 4.0 }, { N.E5, 201, 4.0 }, { N.G5, 205, 4.0 },
        -- C14: Caída delicada sobre Dm9
        { N.F5, 209, 6.0 }, { N.E5, 215, 2.0 }, { N.D5, 217, 4.0 }, { N.A4, 221, 4.0 },
        -- C15: Gm9 con la 9ª tierna (A4) y 11ª (C5)
        { N.D5, 225, 6.0 }, { N.C5, 231, 2.0 }, { N.Bb4, 233, 4.0 }, { N.A4, 237, 4.0 },
        -- C16: Cadencia nostálgica hacia E4
        { N.G4, 241, 6.0 }, { N.Bb4, 247, 2.0 }, { N.D5, 249, 4.0 }, { N.E4, 253, 4.0 },

        -- Sección B Modal (Compases 17-24): Añoranza y recuerdos lejanos
        -- C17 (Am): La frase se eleva hacia los agudos con suavidad
        { N.C5, 257, 4.0 }, { N.E5, 261, 4.0 }, { N.A5, 265, 8.0 },
        -- C18 (Dm9): Suspiro en G5 descendiendo a F5 y E5
        { N.G5, 273, 6.0 }, { N.F5, 279, 2.0 }, { N.E5, 281, 4.0 }, { N.D5, 285, 4.0 },
        -- C19 (Gm9): Melodía expresiva
        { N.D5, 289, 6.0 }, { N.E5, 295, 2.0 }, { N.F5, 297, 4.0 }, { N.G5, 301, 4.0 },
        -- C20 (C9sus4): Suspensión tierna
        { N.G5, 305, 8.0 }, { N.F5, 313, 4.0 }, { N.E5, 317, 4.0 },
        -- C21 (Bbmaj9): Canto nostálgico
        { N.F5, 321, 6.0 }, { N.G5, 327, 2.0 }, { N.A5, 329, 4.0 }, { N.Bb5, 333, 4.0 },
        -- C22 (Am): Reflexión íntima
        { N.C6, 337, 8.0 }, { N.A5, 345, 4.0 }, { N.E5, 349, 4.0 },
        -- C23 (Gm9):
        { N.G5, 353, 6.0 }, { N.A5, 359, 2.0 }, { N.Bb5, 361, 4.0 }, { N.D6, 365, 4.0 },
        -- C24 (C7):
        { N.E6, 369, 8.0 }, { N.D6, 377, 4.0 }, { N.C6, 381, 4.0 },

        -- Clímax (Compases 25-28): Máxima emoción melancólica
        { N.A5, 385, 6.0 }, { N.G5, 391, 2.0 }, { N.F5, 393, 4.0 }, { N.C5, 397, 4.0 },
        { N.D5, 401, 8.0 }, { N.F5, 409, 4.0 }, { N.A5, 413, 4.0 },
        { N.Bb5, 417, 6.0 },{ N.A5, 423, 2.0 }, { N.F5, 425, 4.0 }, { N.D5, 429, 4.0 },
        { N.G5, 433, 8.0 }, { N.F5, 441, 4.0 }, { N.E5, 445, 4.0 },

        -- Coda (Compases 29-32): Despedida suave y paz nostálgica
        { N.F5, 449, 12.0 }, { N.C5, 461, 4.0 },
        { N.D5, 465, 8.0 },  { N.A4, 473, 8.0 },
        { N.Bb4, 481, 8.0 }, { N.C5, 489, 8.0 },
        { N.F4, 497, 16.0 }
    }

    for _, m in ipairs(pianoMelody) do
        addNote(wetBuffer, Instruments.angelicPianoLead, m[1], m[2], m[3])
    end

    -- 3. Destellos de Campanas de Cristal (Stardust Chimes)
    local chimeNotes = {
        { N.C6, 65, 4.0 },  { N.F6, 97, 4.0 },  { N.A6, 129, 4.0 },
        { N.E6, 161, 4.0 }, { N.D6, 193, 4.0 }, { N.C6, 225, 4.0 },

        { N.A6, 385, 4.0 }, { N.C6, 393, 4.0 },
        { N.F6, 401, 4.0 }, { N.D6, 409, 4.0 },
        { N.D6, 417, 4.0 }, { N.Bb5, 425, 4.0 },
        { N.G6, 433, 4.0 }, { N.E6, 441, 4.0 },

        { N.A5, 465, 6.0 }, { N.F6, 497, 8.0 }
    }

    for _, c in ipairs(chimeNotes) do
        addNote(wetBuffer, Instruments.stardustChime, c[1], c[2], c[3])
    end

    -- 4. Procesamiento de retardo espacial estéreo con amortiguación cálida (Analog Tape / Warm Cathedral Echo)
    local delaySamples = math.floor(beatDuration * 0.5 * SAMPLE_RATE)
    local delayBuffer = {}
    for i = 1, delaySamples do
        delayBuffer[i] = 0
    end

    local delayIdx = 1
    local feedback = 0.35
    local prevEcho = 0.0

    for i = 1, totalSamples do
        local dry = wetBuffer[i]
        local rawEcho = delayBuffer[delayIdx]
        local dampedEcho = rawEcho * 0.65 + prevEcho * 0.35
        prevEcho = dampedEcho

        local wetVal = dry + dampedEcho * feedback
        wetBuffer[i] = wetVal
        delayBuffer[delayIdx] = wetVal
        delayIdx = (delayIdx % delaySamples) + 1
    end

    -- 5. Mezcla final y masterización continua a 32 bits
    local sd = love.sound.newSoundData(totalSamples, SAMPLE_RATE, 16, 1)
    for i = 0, totalSamples - 1 do
        local dry = dryBuffer[i + 1] or 0
        local wet = wetBuffer[i + 1] or 0
        local finalSample = clampSample((dry * 0.70 + wet * 0.68) * 0.76)
        sd:setSample(i, finalSample)
    end

    return sd
end

ProceduralMusic.generateTrack8 = ProceduralMusic.generateAngelicFountain

return ProceduralMusic
