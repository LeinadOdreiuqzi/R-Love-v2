-- src/audio/audio_manager.lua
-- Sistema de Audio completo para R-Love-v2
-- Soporta carga de archivos de audio reales (assets/audio) y síntesis procedural
-- de SFX retro-espaciales integrados en memoria (cero dependencias externas).

local AudioManager = {}

-- Configuración de volumen por defecto
AudioManager.config = {
    masterVolume = 0.7,
    sfxVolume = 0.8,
    musicVolume = 0.5,
    muted = false,
    maxVoicesPerSFX = 6
}

-- Estado interno
AudioManager.state = {
    initialized = false,
    sfxSources = {},      -- { [name] = { pool = { sources }, nextIndex = 1 } }
    currentMusic = nil,
    currentMusicName = nil,
    activeLoops = {},
    customPaths = {
        "assets/audio/",
        "assets/sounds/",
        "assets/music/"
    }
}

-- Muestreo de audio por defecto
local SAMPLE_RATE = 44100

-- ============================================================================
-- SINTETIZADOR PROCEDURAL DE EFECTOS DE SONIDO (SFX PROCEDURALES)
-- ============================================================================

local function clampSample(v)
    if v > 1.0 then return 1.0 end
    if v < -1.0 then return -1.0 end
    return v
end

-- Generadores procedurales para cada tipo de sonido
local Synthesizers = {
    -- Disparo de láser clásico espacial: barrido descendente rápido de frecuencia
    laser = function()
        local duration = 0.12
        local samples = math.floor(SAMPLE_RATE * duration)
        local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
        for i = 0, samples - 1 do
            local t = i / SAMPLE_RATE
            local progress = t / duration
            local freq = 920 * (1.0 - progress * 0.75)
            local env = (1.0 - progress)^1.5
            local sample = math.sin(2 * math.pi * freq * t) * env * 0.65
            sd:setSample(i, clampSample(sample))
        end
        return sd
    end,

    -- Disparo de plasma pesado: onda rica con oscilación y resonancia
    plasma = function()
        local duration = 0.22
        local samples = math.floor(SAMPLE_RATE * duration)
        local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
        for i = 0, samples - 1 do
            local t = i / SAMPLE_RATE
            local progress = t / duration
            local fMod = math.sin(2 * math.pi * 35 * t) * 60
            local freq = 360 - progress * 140 + fMod
            local env = math.sin(progress * math.pi * 0.5) * (1.0 - progress)
            local carrier = math.sin(2 * math.pi * freq * t)
            local sub = math.sin(2 * math.pi * (freq * 0.5) * t) * 0.5
            local sample = (carrier + sub) * env * 0.6
            sd:setSample(i, clampSample(sample))
        end
        return sd
    end,

    -- Disparo de escopeta de energía: ráfaga percusiva con transiente de ruido
    shotgun = function()
        local duration = 0.18
        local samples = math.floor(SAMPLE_RATE * duration)
        local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
        for i = 0, samples - 1 do
            local t = i / SAMPLE_RATE
            local progress = t / duration
            local freq = 500 * (1.0 - progress)^2 + 80
            local noise = (math.random() * 2 - 1) * math.exp(-progress * 25)
            local env = (1.0 - progress)^2.2
            local tone = math.sin(2 * math.pi * freq * t) * 0.4
            local sample = (tone + noise * 0.6) * env * 0.75
            sd:setSample(i, clampSample(sample))
        end
        return sd
    end,

    -- Impacto / golpe contra blindaje o asteroide
    hit = function()
        local duration = 0.08
        local samples = math.floor(SAMPLE_RATE * duration)
        local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
        for i = 0, samples - 1 do
            local t = i / SAMPLE_RATE
            local progress = t / duration
            local freq = 180 * math.exp(-progress * 18) + 60
            local env = math.exp(-progress * 30)
            local noise = (math.random() * 2 - 1) * 0.35
            local sample = (math.sin(2 * math.pi * freq * t) + noise) * env * 0.8
            sd:setSample(i, clampSample(sample))
        end
        return sd
    end,

    -- Explosión espacial con resonancia de subgraves y disipación progresiva
    explosion = function()
        local duration = 0.55
        local samples = math.floor(SAMPLE_RATE * duration)
        local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
        for i = 0, samples - 1 do
            local t = i / SAMPLE_RATE
            local progress = t / duration
            local env = math.exp(-progress * 5.5)
            local noise = (math.random() * 2 - 1) * 0.5
            local sub = math.sin(2 * math.pi * (85 * (1 - progress * 0.6)) * t) * 0.5
            local sample = (noise + sub) * env * 0.8
            sd:setSample(i, clampSample(sample))
        end
        return sd
    end,

    -- Postquemador / propulsión de boost: zumbido sordo y amortiguado dentro de la cabina
    boost = function()
        local duration = 0.42
        local samples = math.floor(SAMPLE_RATE * duration)
        local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
        
        -- Filtro paso-bajo digital IIR (simula el blindaje y aislamiento acústico del casco)
        local lpfState = 0
        local lpfCoeff = 0.032 -- Corta frecuencias agudas (>220 Hz), eliminando estática y chirridos
        
        for i = 0, samples - 1 do
            local t = i / SAMPLE_RATE
            local progress = t / duration
            
            -- Envolvente suave y amortiguada
            local env = math.sin(progress * math.pi)^1.5
            
            -- Ruido amortiguado a través del fuselaje
            local rawNoise = (math.random() * 2 - 1)
            lpfState = lpfState + lpfCoeff * (rawNoise - lpfState)
            local muffledNoise = lpfState * 0.35
            
            -- Frecuencias subgraves sordas de la cabina (50 Hz - 72 Hz)
            local subBass = math.sin(2 * math.pi * (50 + 12 * math.sin(progress * math.pi)) * t) * 0.45
            local lowHum = math.sin(2 * math.pi * 78 * t) * 0.15
            
            -- Señal acústica opaca con volumen interior balanceado
            local sample = (subBass + lowHum + muffledNoise) * env * 0.40
            sd:setSample(i, clampSample(sample))
        end
        return sd
    end,

    -- Alarma de advertencia de escudo crítico
    warning = function()
        local duration = 0.26
        local samples = math.floor(SAMPLE_RATE * duration)
        local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
        for i = 0, samples - 1 do
            local t = i / SAMPLE_RATE
            local progress = t / duration
            local freq = (progress < 0.5) and 820 or 1050
            local env = math.sin((progress % 0.5) * 2 * math.pi)
            local sample = math.sin(2 * math.pi * freq * t) * env * 0.5
            sd:setSample(i, clampSample(sample))
        end
        return sd
    end,

    -- Clic de interfaz / interacción
    ui_click = function()
        local duration = 0.025
        local samples = math.floor(SAMPLE_RATE * duration)
        local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
        for i = 0, samples - 1 do
            local t = i / SAMPLE_RATE
            local progress = t / duration
            local freq = 1400 * (1.0 - progress * 0.3)
            local env = (1.0 - progress)^2
            local sample = math.sin(2 * math.pi * freq * t) * env * 0.4
            sd:setSample(i, clampSample(sample))
        end
        return sd
    end,

    -- Equipar ítem / cambio de pasivo (acorde armónico agradable)
    item_equip = function()
        local duration = 0.16
        local samples = math.floor(SAMPLE_RATE * duration)
        local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
        for i = 0, samples - 1 do
            local t = i / SAMPLE_RATE
            local progress = t / duration
            local env = (1.0 - progress)^1.4
            local f1 = 523.25 -- C5
            local f2 = 659.25 -- E5
            local sample = (math.sin(2 * math.pi * f1 * t) + math.sin(2 * math.pi * f2 * t)) * 0.3 * env
            sd:setSample(i, clampSample(sample))
        end
        return sd
    end,

    -- Track 1: Síntesis 32-bit float continua, piano sintético melancólico, arpegios rápidos y percusión electrónica a 144 BPM
    track_1 = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateAstralPulse()
    end,
    astral_pulse = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateAstralPulse()
    end,
    stellar_velocity = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateAstralPulse()
    end,

    -- Track 2: Tradicional y nostálgica con koto, flauta de bambú, piano acústico y campanas
    track_2 = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateOpalineHaven()
    end,
    opaline_haven = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateOpalineHaven()
    end,
    ciudad_caolin = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateOpalineHaven()
    end,

    -- Track 3: Vals acústico en 3/4 con arpegios de nylon, cello y celesta
    track_3 = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateLunarWaltz()
    end,
    lunar_waltz = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateLunarWaltz()
    end,
    rises_the_moon = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateLunarWaltz()
    end,

    -- Track 4: Armonía modal en Fa menor, bajo acústico melódico, flauta y arpegios etéreos
    track_4 = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateAncientSanctuary()
    end,
    ancient_sanctuary = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateAncientSanctuary()
    end,
    secret_sanctuary = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateAncientSanctuary()
    end,

    -- Track 5: Groove percusivo sincopado, gotas cavernosas y retardo estéreo
    track_5 = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateCavernGroove()
    end,
    cavern_groove = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateCavernGroove()
    end,

    -- Track 6: Drone espacial ambiental enriquecido (acorde profundo + arpegio estelar)
    track_6 = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateSpaceAmbient()
    end,
    space_ambient = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateSpaceAmbient()
    end,

    -- Track 7: Vals modal de carrusel en 3/4 a 192 BPM con caja de música, acordeón musette, bajo pizzicato y flauta solista
    track_7 = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateCarouselWaltz()
    end,
    carousel_waltz = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateCarouselWaltz()
    end,

    -- Track 8: Arpegios de arpa en cascada líquida, coro celestial y flauta lírica en Fa mayor a 96 BPM
    track_8 = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateAngelicFountain()
    end,
    celestial_spring = function()
        local ProceduralMusic = require 'src.audio.procedural_music'
        return ProceduralMusic.generateAngelicFountain()
    end
}

-- ============================================================================
-- GESTIÓN DE FUENTES Y CARGA
-- ============================================================================

local function findAudioFile(name)
    if not love.filesystem then return nil end
    local extensions = {".ogg", ".wav", ".mp3"}
    for _, basePath in ipairs(AudioManager.state.customPaths) do
        for _, ext in ipairs(extensions) do
            local path = basePath .. name .. ext
            if love.filesystem.getInfo and love.filesystem.getInfo(path) then
                return path
            end
        end
    end
    return nil
end

local function createSource(name)
    if not love.audio or not love.sound then return nil end
    
    -- 1. Intentar cargar archivo físico si existe en disco
    local filePath = findAudioFile(name)
    if filePath then
        local success, src = pcall(function()
            return love.audio.newSource(filePath, "static")
        end)
        if success and src then
            return src
        end
    end

    -- 2. Fallback a sintetizador procedural
    local synth = Synthesizers[name]
    if synth then
        local success, soundData = pcall(synth)
        if success and soundData then
            local ok, src = pcall(function()
                return love.audio.newSource(soundData, "static")
            end)
            if ok and src then
                return src
            end
        end
    end

    return nil
end

local function getOrCreateVoicePool(name)
    local poolData = AudioManager.state.sfxSources[name]
    if poolData then return poolData end

    local baseSource = createSource(name)
    if not baseSource then return nil end

    local maxVoices = AudioManager.config.maxVoicesPerSFX
    local pool = { baseSource }
    for i = 2, maxVoices do
        local ok, cloned = pcall(function() return baseSource:clone() end)
        if ok and cloned then
            table.insert(pool, cloned)
        else
            break
        end
    end

    poolData = {
        sources = pool,
        nextIndex = 1
    }
    AudioManager.state.sfxSources[name] = poolData
    return poolData
end

-- ============================================================================
-- API PÚBLICA DE AUDIOMANAGER
-- ============================================================================

function AudioManager.init()
    if AudioManager.state.initialized then return end
    print("=== INITIALIZING AUDIO MANAGER ===")
    
    if not love.audio or not love.sound then
        print("[AudioManager] Audio modules not available in current environment")
        return
    end

    -- Pre-sintetizar efectos esenciales para evitar picos de frame durante el gameplay
    local preloadList = {"laser", "plasma", "shotgun", "hit", "explosion", "boost", "warning", "ui_click", "item_equip"}
    for _, sfx in ipairs(preloadList) do
        getOrCreateVoicePool(sfx)
    end

    -- Arrancar música/drone ambiental espacial en segundo plano
    AudioManager.playMusic("space_ambient", { loop = true, volume = 0.35 })

    AudioManager.state.initialized = true
    print("✓ AudioManager initialized with " .. #preloadList .. " synthesized sound effects")
end

function AudioManager.update(dt)
    -- En caso de lógica de fading dinámico o atenuación espacial
end

--[[
    Reproduce un efecto de sonido
    @param name: nombre del SFX ('laser', 'plasma', 'hit', 'explosion', 'boost', 'warning', 'ui_click', 'item_equip')
    @param options: tabla opcional { volume = 1.0, pitch = 1.0, randomizePitch = true }
--]]
function AudioManager.play(name, options)
    if AudioManager.config.muted or not love.audio then return nil end
    
    options = options or {}
    local poolData = getOrCreateVoicePool(name)
    if not poolData or #poolData.sources == 0 then return nil end

    local source = poolData.sources[poolData.nextIndex]
    poolData.nextIndex = (poolData.nextIndex % #poolData.sources) + 1

    local volume = (options.volume or 1.0) * AudioManager.config.masterVolume * AudioManager.config.sfxVolume
    local pitch = options.pitch or 1.0
    if options.randomizePitch ~= false and not options.pitch then
        -- Leve variación orgánica de tono (+- 5%) para evitar monotonía
        pitch = 1.0 + (math.random() - 0.5) * 0.1
    end

    pcall(function()
        source:stop()
        source:setVolume(math.max(0, math.min(1, volume)))
        source:setPitch(math.max(0.2, math.min(3.0, pitch)))
        source:play()
    end)

    return source
end

--[[
    Reproduce música de fondo
    @param name: nombre de la pista
    @param options: { loop = true, volume = 1.0 }
--]]
function AudioManager.playMusic(name, options)
    if not love.audio then return nil end
    options = options or {}
    
    if AudioManager.state.currentMusic and AudioManager.state.currentMusicName == name then
        if options.restart or options.forceRestart then
            pcall(function()
                AudioManager.state.currentMusic:stop()
                AudioManager.state.currentMusic:seek(0)
                local volume = (options.volume or 1.0) * AudioManager.config.masterVolume * AudioManager.config.musicVolume
                AudioManager.state.currentMusic:setVolume(AudioManager.config.muted and 0 or volume)
                AudioManager.state.currentMusic:setLooping(options.loop ~= false)
                AudioManager.state.currentMusic:play()
            end)
        end
        return AudioManager.state.currentMusic
    end

    AudioManager.stopMusic()

    -- Intentar buscar archivo o sintetizar ambiental
    local filePath = findAudioFile(name)
    local musicSource = nil
    if filePath then
        local ok, src = pcall(function() return love.audio.newSource(filePath, "stream") end)
        if ok then musicSource = src end
    end

    if not musicSource then
        local pool = getOrCreateVoicePool(name)
        if pool and #pool.sources > 0 then
            musicSource = pool.sources[1]
        end
    end

    if not musicSource then return nil end

    local volume = (options.volume or 1.0) * AudioManager.config.masterVolume * AudioManager.config.musicVolume
    local loop = (options.loop ~= false)

    pcall(function()
        musicSource:stop()
        musicSource:seek(0)
        musicSource:setLooping(loop)
        musicSource:setVolume(AudioManager.config.muted and 0 or volume)
        musicSource:play()
    end)

    AudioManager.state.currentMusic = musicSource
    AudioManager.state.currentMusicName = name
    return musicSource
end

function AudioManager.stopMusic()
    if AudioManager.state.currentMusic then
        pcall(function()
            AudioManager.state.currentMusic:stop()
            AudioManager.state.currentMusic:seek(0)
        end)
        AudioManager.state.currentMusic = nil
        AudioManager.state.currentMusicName = nil
    end
end

--[[
    Detiene toda la reproducción de audio (música, efectos y loops)
--]]
function AudioManager.stopAll()
    AudioManager.stopMusic()
    if love.audio and love.audio.stop then
        pcall(love.audio.stop)
    end
    AudioManager.state.activeLoops = {}
end

--[[
    Limpia y reinicia el estado de audio por completo (al reiniciar la seed o regenerar el mapa)
--]]
function AudioManager.reset()
    AudioManager.stopAll()
    if AudioManager.state.sfxSources then
        for _, poolData in pairs(AudioManager.state.sfxSources) do
            if poolData and poolData.sources then
                for _, src in ipairs(poolData.sources) do
                    pcall(function()
                        src:stop()
                        src:seek(0)
                    end)
                end
            end
        end
    end
end

-- ============================================================================
-- CONTROL DE VOLÚMENES Y ESTADO
-- ============================================================================

function AudioManager.setMasterVolume(volume)
    AudioManager.config.masterVolume = math.max(0, math.min(1, volume))
    AudioManager.applyVolumeSettings()
end

function AudioManager.setSFXVolume(volume)
    AudioManager.config.sfxVolume = math.max(0, math.min(1, volume))
end

function AudioManager.setMusicVolume(volume)
    AudioManager.config.musicVolume = math.max(0, math.min(1, volume))
    if AudioManager.state.currentMusic then
        local vol = AudioManager.config.muted and 0 or (AudioManager.config.masterVolume * AudioManager.config.musicVolume)
        pcall(function() AudioManager.state.currentMusic:setVolume(vol) end)
    end
end

function AudioManager.toggleMute()
    AudioManager.config.muted = not AudioManager.config.muted
    AudioManager.applyVolumeSettings()
    return AudioManager.config.muted
end

function AudioManager.isMuted()
    return AudioManager.config.muted
end

function AudioManager.applyVolumeSettings()
    local master = AudioManager.config.muted and 0 or AudioManager.config.masterVolume
    if love.audio and love.audio.setVolume then
        love.audio.setVolume(master)
    end
    if AudioManager.state.currentMusic then
        local vol = AudioManager.config.muted and 0 or (AudioManager.config.masterVolume * AudioManager.config.musicVolume)
        pcall(function() AudioManager.state.currentMusic:setVolume(vol) end)
    end
end

return AudioManager
