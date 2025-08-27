-- src/shaders/background_manager.lua
-- Sistema de gestión del fondo galáctico procedural

local BackgroundManager = {}
local GalacticBackground = require 'src.shaders.galactic_background'

-- Estado del sistema
BackgroundManager.state = {
    initialized = false,
    enabled = true,
    currentSeed = 0,
    lastCameraPosition = {x = 0, y = 0, zoom = 1},
    renderLayer = "background", -- Capa más profunda
    performanceMode = false
}

-- Configuración del sistema
BackgroundManager.config = {
    -- Configuración de renderizado
    rendering = {
        enabled = true,
        renderBehindStars = true, -- Renderizar detrás de las micro estrellas
        fadeWithZoom = true,
        minZoomVisibility = 0.1,
        maxZoomVisibility = 3.0
    },
    
    -- Configuración de performance
    performance = {
        adaptiveQuality = true,
        targetFrameTime = 0.016, -- 60 FPS
        qualityLevels = {
            low = {
                intensity = 0.3,
                detailLevel = 0.6,
                updateFrequency = 0.1
            },
            medium = {
                intensity = 0.5,
                detailLevel = 0.8,
                updateFrequency = 0.05
            },
            high = {
                intensity = 0.7,
                detailLevel = 1.0,
                updateFrequency = 0.02
            }
        },
        currentQuality = "medium"
    },
    
    -- Configuración visual
    visual = {
        baseIntensity = 0.6,
        detailLevel = 1.0,
        movementSpeed = 0.1,
        colorVariation = 0.3,
        
        -- Paletas de colores predefinidas
        colorPalettes = {
            default = {
                base = {0.05, 0.08, 0.15},
                dust = {0.12, 0.15, 0.25},
                gas = {0.08, 0.12, 0.20},
                nebula = {0.15, 0.10, 0.25}
            },
            warm = {
                base = {0.08, 0.06, 0.12},
                dust = {0.18, 0.12, 0.20},
                gas = {0.15, 0.10, 0.15},
                nebula = {0.20, 0.08, 0.18}
            },
            cold = {
                base = {0.03, 0.06, 0.18},
                dust = {0.08, 0.12, 0.28},
                gas = {0.05, 0.10, 0.25},
                nebula = {0.10, 0.08, 0.30}
            },
            alien = {
                base = {0.06, 0.12, 0.08},
                dust = {0.12, 0.25, 0.15},
                gas = {0.08, 0.20, 0.12},
                nebula = {0.15, 0.25, 0.10}
            }
        }
    },
    
    -- Configuración de variaciones por semilla
    seedVariation = {
        enabled = true,
        intensityRange = {0.4, 0.8},
        detailRange = {0.8, 1.2},
        speedRange = {0.05, 0.15},
        colorVariationRange = {0.1, 0.5}
    }
}

-- Estadísticas de rendimiento
BackgroundManager.stats = {
    frameTime = 0,
    renderTime = 0,
    lastUpdate = 0,
    qualityAdjustments = 0
}

function BackgroundManager.init()
    if BackgroundManager.state.initialized then return true end
    
    print("=== BACKGROUND MANAGER INITIALIZING ===")
    
    -- Inicializar el shader de fondo galáctico
    local success = GalacticBackground.init()
    if not success then
        print("✗ Failed to initialize galactic background shader")
        return false
    end
    
    -- Configurar valores iniciales
    BackgroundManager.applyQualitySettings(BackgroundManager.config.performance.currentQuality)
    
    BackgroundManager.state.initialized = true
    print("✓ Background Manager initialized successfully")
    print("✓ Rendering: " .. (BackgroundManager.config.rendering.enabled and "ON" or "OFF"))
    print("✓ Quality: " .. BackgroundManager.config.performance.currentQuality)
    
    return true
end

function BackgroundManager.update(dt, camera, gameState)
    if not BackgroundManager.state.initialized or not BackgroundManager.state.enabled then
        return
    end
    
    local startTime = love.timer.getTime()
    
    -- Actualizar estadísticas
    BackgroundManager.stats.lastUpdate = love.timer.getTime()
    
    -- Verificar si la cámara ha cambiado significativamente
    local cameraChanged = BackgroundManager.hasCameraChanged(camera)
    
    -- Actualizar semilla si es necesario
    if gameState and gameState.currentSeed and gameState.currentSeed ~= BackgroundManager.state.currentSeed then
        BackgroundManager.setSeed(gameState.currentSeed)
    end
    
    -- Calidad adaptativa
    if BackgroundManager.config.performance.adaptiveQuality then
        BackgroundManager.updateAdaptiveQuality(dt)
    end
    
    -- Actualizar posición de cámara
    BackgroundManager.state.lastCameraPosition = {
        x = camera.x or 0,
        y = camera.y or 0,
        zoom = camera.zoom or 1
    }
    
    BackgroundManager.stats.renderTime = love.timer.getTime() - startTime
end

function BackgroundManager.render(camera, gameState)
    if not BackgroundManager.state.initialized or not BackgroundManager.state.enabled then
        return
    end
    
    if not BackgroundManager.config.rendering.enabled then
        return
    end
    
    -- Verificar visibilidad por zoom
    local zoom = camera.zoom or 1.0
    if zoom < BackgroundManager.config.rendering.minZoomVisibility or 
       zoom > BackgroundManager.config.rendering.maxZoomVisibility then
        return
    end
    
    local startTime = love.timer.getTime()
    
    -- Calcular alpha basado en zoom si está habilitado
    local alpha = 1.0
    if BackgroundManager.config.rendering.fadeWithZoom then
        local minZoom = BackgroundManager.config.rendering.minZoomVisibility
        local maxZoom = BackgroundManager.config.rendering.maxZoomVisibility
        local fadeRange = 0.2 -- Rango de fade del 20%
        
        if zoom < minZoom + (maxZoom - minZoom) * fadeRange then
            alpha = (zoom - minZoom) / ((maxZoom - minZoom) * fadeRange)
        elseif zoom > maxZoom - (maxZoom - minZoom) * fadeRange then
            alpha = (maxZoom - zoom) / ((maxZoom - minZoom) * fadeRange)
        end
        
        alpha = math.max(0, math.min(1, alpha))
    end
    
    -- Renderizar el fondo
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, alpha)
    
    local seed = BackgroundManager.state.currentSeed
    GalacticBackground.render(camera, seed)
    
    love.graphics.setColor(1, 1, 1, 1) -- Restaurar color
    love.graphics.pop()
    
    BackgroundManager.stats.frameTime = love.timer.getTime() - startTime
end

function BackgroundManager.setSeed(seed)
    if not seed then return end
    
    BackgroundManager.state.currentSeed = seed
    
    -- Generar variación única para esta semilla
    GalacticBackground.generateVariation(seed)
    
    -- Forzar intensidad alta para máxima visibilidad
    GalacticBackground.setSettings({
        intensity = 70.0  -- Intensidad extremadamente alta
    })
    
    print("✓ Background seed set to: " .. tostring(seed))
    print("✓ Forced high intensity for maximum visibility")
end

function BackgroundManager.setEnabled(enabled)
    BackgroundManager.state.enabled = enabled
end

function BackgroundManager.isEnabled()
    return BackgroundManager.state.enabled and BackgroundManager.config.rendering.enabled
end

function BackgroundManager.setQuality(quality)
    if not BackgroundManager.config.performance.qualityLevels[quality] then
        print("⚠ Invalid quality level: " .. tostring(quality))
        return false
    end
    
    BackgroundManager.config.performance.currentQuality = quality
    BackgroundManager.applyQualitySettings(quality)
    
    print("✓ Background quality set to: " .. quality)
    return true
end

function BackgroundManager.applyQualitySettings(quality)
    local settings = BackgroundManager.config.performance.qualityLevels[quality]
    if not settings then return end
    
    local visualSettings = {
        intensity = settings.intensity,
        detailLevel = settings.detailLevel
    }
    
    GalacticBackground.setSettings(visualSettings)
end

function BackgroundManager.updateAdaptiveQuality(dt)
    local targetFrameTime = BackgroundManager.config.performance.targetFrameTime
    local currentFrameTime = BackgroundManager.stats.frameTime
    
    -- Solo ajustar si el tiempo de frame es significativamente diferente
    if currentFrameTime > targetFrameTime * 1.5 then
        -- Reducir calidad
        local currentQuality = BackgroundManager.config.performance.currentQuality
        if currentQuality == "high" then
            BackgroundManager.setQuality("medium")
            BackgroundManager.stats.qualityAdjustments = BackgroundManager.stats.qualityAdjustments + 1
        elseif currentQuality == "medium" then
            BackgroundManager.setQuality("low")
            BackgroundManager.stats.qualityAdjustments = BackgroundManager.stats.qualityAdjustments + 1
        end
    elseif currentFrameTime < targetFrameTime * 0.8 then
        -- Aumentar calidad
        local currentQuality = BackgroundManager.config.performance.currentQuality
        if currentQuality == "low" then
            BackgroundManager.setQuality("medium")
            BackgroundManager.stats.qualityAdjustments = BackgroundManager.stats.qualityAdjustments + 1
        elseif currentQuality == "medium" then
            BackgroundManager.setQuality("high")
            BackgroundManager.stats.qualityAdjustments = BackgroundManager.stats.qualityAdjustments + 1
        end
    end
end

function BackgroundManager.hasCameraChanged(camera)
    local last = BackgroundManager.state.lastCameraPosition
    local threshold = 50 -- Umbral de cambio significativo
    
    return math.abs((camera.x or 0) - last.x) > threshold or
           math.abs((camera.y or 0) - last.y) > threshold or
           math.abs((camera.zoom or 1) - last.zoom) > 0.1
end

function BackgroundManager.setColorPalette(paletteName)
    local palette = BackgroundManager.config.visual.colorPalettes[paletteName]
    if not palette then
        print("⚠ Invalid color palette: " .. tostring(paletteName))
        return false
    end
    
    GalacticBackground.setSettings({colorPalette = palette})
    print("✓ Background color palette set to: " .. paletteName)
    return true
end

function BackgroundManager.setIntensity(intensity)
    intensity = math.max(0, math.min(1, intensity))
    BackgroundManager.config.visual.baseIntensity = intensity
    GalacticBackground.setSettings({intensity = intensity})
end

function BackgroundManager.setDetailLevel(detailLevel)
    detailLevel = math.max(0.1, math.min(2.0, detailLevel))
    BackgroundManager.config.visual.detailLevel = detailLevel
    GalacticBackground.setSettings({detailLevel = detailLevel})
end

function BackgroundManager.setMovementSpeed(speed)
    speed = math.max(0, math.min(1, speed))
    BackgroundManager.config.visual.movementSpeed = speed
    GalacticBackground.setSettings({movementSpeed = speed})
end

function BackgroundManager.getStats()
    return {
        frameTime = BackgroundManager.stats.frameTime,
        renderTime = BackgroundManager.stats.renderTime,
        quality = BackgroundManager.config.performance.currentQuality,
        qualityAdjustments = BackgroundManager.stats.qualityAdjustments,
        enabled = BackgroundManager.state.enabled,
        initialized = BackgroundManager.state.initialized
    }
end

function BackgroundManager.debugPrint()
    print("=== BACKGROUND MANAGER DEBUG ===")
    local stats = BackgroundManager.getStats()
    print(string.format("Enabled: %s", stats.enabled and "YES" or "NO"))
    print(string.format("Quality: %s", stats.quality))
    print(string.format("Frame Time: %.3fms", stats.frameTime * 1000))
    print(string.format("Render Time: %.3fms", stats.renderTime * 1000))
    print(string.format("Quality Adjustments: %d", stats.qualityAdjustments))
    print(string.format("Current Seed: %d", BackgroundManager.state.currentSeed))
end

return BackgroundManager