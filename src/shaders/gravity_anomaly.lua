-- src/shaders/gravity_anomaly.lua
-- Placeholders de anomalías gravitacionales para el bioma gravity_anomaly

local GravityAnomaly = {}
local MapConfig = require 'src.maps.config.map_config'
local PerlinNoise = require 'src.maps.perlin_noise'

-- Configuración de placeholders (sistema de anclaje replicado de asteroides)
GravityAnomaly.config = {
    -- Placeholder de ondas gravitacionales
    waves = {
        spawnChance = 0.80,  -- 15% de probabilidad por chunk en bioma gravity_anomaly
        minSize = 40,
        maxSize = 120,
        animationDuration = 3.0,  -- Duración total de la animación
        fadeInTime = 0.8,         -- Tiempo de aparición
        fadeOutTime = 1.2,        -- Tiempo de desaparición
        pulseFrequency = 2.0,     -- Frecuencia de pulsación
        color = {0.4, 0.2, 0.8, 0.6},  -- Color púrpura translúcido
        waveCount = 3,            -- Número de ondas concéntricas
        waveSpacing = 15          -- Espaciado entre ondas
    },
    
    -- Placeholder de lente gravitacional
    lens = {
        spawnChance = 0.80,  -- 12% de probabilidad por chunk en bioma gravity_anomaly
        minSize = 60,
        maxSize = 150,
        animationDuration = 4.5,  -- Duración total de la animación
        fadeInTime = 1.0,         -- Tiempo de aparición
        fadeOutTime = 1.5,        -- Tiempo de desaparición
        distortionStrength = 0.3, -- Intensidad del efecto visual
        color = {0.6, 0.4, 0.9, 0.4},  -- Color violeta translúcido
        innerRadius = 0.3,        -- Radio interno (proporción del tamaño total)
        outerRadius = 1.0         -- Radio externo
    }
}

-- Sistema de anomalías gravitacionales
-- Las anomalías se manejan por chunk y por el sistema continuo

-- Sistema de detección continua del bioma del jugador
GravityAnomaly.playerBiomeTracker = {
    lastBiomeCheck = 0,
    checkInterval = 0.3,  -- Verificar cada 0.3 segundos
    isInGravityBiome = false,
    nextSpawnTime = 0,  -- Tiempo absoluto para el próximo spawn
    spawnInterval = 1.5,  -- Generar anomalía cada 1.5 segundos en promedio
    maxContinuousAnomalies = 8,  -- Máximo de anomalías continuas activas
    exitGraceSeconds = 1.5,  -- Tolerancia al salir del bioma para evitar parpadeo
    lastInBiomeTime = 0,     -- Última vez (timestamp) que se detectó el bioma válido
    continuousAnomalies = {}  -- Anomalías generadas por el sistema continuo
}

-- Función para generar anomalías en un chunk del bioma gravity_anomaly
function GravityAnomaly.generateAnomalies(chunk, chunkX, chunkY, biomeType, rng)
    local BiomeSystem = require 'src.maps.biome_system'
    
    -- Solo generar en bioma gravity_anomaly
    if biomeType ~= BiomeSystem.BiomeType.GRAVITY_ANOMALY then
        return
    end
    
    -- Inicializar lista de anomalías del chunk si no existe
    if not chunk.gravityAnomalies then
        chunk.gravityAnomalies = {}
    end
    
    local chunkSize = MapConfig.chunk.size
    local tileSize = MapConfig.chunk.tileSize
    local worldScale = MapConfig.chunk.worldScale
    
    -- Generar ondas gravitacionales
    if rng:random() < GravityAnomaly.config.waves.spawnChance then
        local wave = {
            type = "wave",
            x = rng:random() * chunkSize * tileSize,
            y = rng:random() * chunkSize * tileSize,
            size = rng:random() * (GravityAnomaly.config.waves.maxSize - GravityAnomaly.config.waves.minSize) + GravityAnomaly.config.waves.minSize,
            startTime = love.timer.getTime() + rng:random() * 2.0,  -- Retraso aleatorio
            duration = GravityAnomaly.config.waves.animationDuration,
            phase = rng:random() * math.pi * 2,  -- Fase inicial aleatoria
            chunkX = chunkX,
            chunkY = chunkY
        }
        table.insert(chunk.gravityAnomalies, wave)
    end
    
    -- Generar lente gravitacional (DESACTIVADO: solo se usa el efecto shader en el sistema continuo)
    -- if rng:random() < GravityAnomaly.config.lens.spawnChance then
    --     local lens = {
    --         type = "lens",
    --         x = rng:random() * chunkSize * tileSize,
    --         y = rng:random() * chunkSize * tileSize,
    --         size = rng:random() * (GravityAnomaly.config.lens.maxSize - GravityAnomaly.config.lens.minSize) + GravityAnomaly.config.lens.minSize,
    --         startTime = love.timer.getTime() + rng:random() * 3.0,  -- Retraso aleatorio
    --         duration = GravityAnomaly.config.lens.animationDuration,
    --         rotation = rng:random() * math.pi * 2,  -- Rotación inicial aleatoria
    --         rotationSpeed = (rng:random() - 0.5) * 0.5,  -- Velocidad de rotación
    --         chunkX = chunkX,
    --         chunkY = chunkY
    --     }
    --     table.insert(chunk.gravityAnomalies, lens)
    -- end
end

-- Función para actualizar anomalías activas y regenerar nuevas
function GravityAnomaly.update(dt, chunkInfo, getChunkFunc)
    local currentTime = love.timer.getTime()
    
    -- Si no se proporcionan parámetros de chunk, no hay nada que hacer
    if not chunkInfo or not getChunkFunc then
        return
    end
    
    local BiomeSystem = require 'src.maps.biome_system'
    
    -- Regenerar anomalías en chunks del bioma gravity_anomaly
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.biome and chunk.biome.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                if not chunk.gravityAnomalies then
                    chunk.gravityAnomalies = {}
                end
                
                -- Limpiar anomalías expiradas del chunk
                for i = #chunk.gravityAnomalies, 1, -1 do
                    local anomaly = chunk.gravityAnomalies[i]
                    local elapsed = currentTime - anomaly.startTime
                    
                    if elapsed > anomaly.duration then
                        table.remove(chunk.gravityAnomalies, i)
                    end
                end
                
                -- Regenerar anomalías si hay pocas activas
                local activeCount = 0
                for _, anomaly in ipairs(chunk.gravityAnomalies) do
                    local elapsed = currentTime - anomaly.startTime
                    if elapsed >= 0 and elapsed <= anomaly.duration then
                        activeCount = activeCount + 1
                    end
                end
                
                -- Si hay menos de 2 anomalías activas, intentar generar nuevas
                if activeCount < 2 then
                    local SeedSystem = require 'src.utils.seed_system'
                    local rng = SeedSystem.makeRNG(chunkX * 1000 + chunkY + math.floor(currentTime / 5))
                    
                    -- Intentar generar onda gravitacional
                    if rng:random() < GravityAnomaly.config.waves.spawnChance * 0.3 then  -- Reducir probabilidad para evitar spam
                        local wave = {
                            type = "wave",
                            x = rng:random() * MapConfig.chunk.size * MapConfig.chunk.tileSize,
                            y = rng:random() * MapConfig.chunk.size * MapConfig.chunk.tileSize,
                            size = rng:random() * (GravityAnomaly.config.waves.maxSize - GravityAnomaly.config.waves.minSize) + GravityAnomaly.config.waves.minSize,
                            startTime = currentTime + rng:random() * 2.0,
                            duration = GravityAnomaly.config.waves.animationDuration,
                            phase = rng:random() * math.pi * 2,
                            chunkX = chunkX,
                            chunkY = chunkY
                        }
                        table.insert(chunk.gravityAnomalies, wave)
                    end
                    
                    -- Intentar generar lente gravitacional
                    if rng:random() < GravityAnomaly.config.lens.spawnChance * 0.25 then  -- Reducir probabilidad para evitar spam
                        -- Placeholder de lente desactivado: no generar en chunks
                     end
                end
            end
        end
    end
end

-- Función para renderizar ondas gravitacionales
function GravityAnomaly.drawWaveAnomaly(anomaly, screenX, screenY, pxSize, elapsed)
    if not anomaly then return end
    
    local config = GravityAnomaly.config.waves
    elapsed = elapsed or 0
    
    -- Calcular alpha basado en el tiempo de vida
    local alpha = 1.0
    if elapsed < config.fadeInTime then
        alpha = elapsed / config.fadeInTime
    elseif elapsed > (anomaly.duration - config.fadeOutTime) then
        local fadeStart = anomaly.duration - config.fadeOutTime
        alpha = 1.0 - ((elapsed - fadeStart) / config.fadeOutTime)
    end
    
    -- Efecto de pulsación
    local pulsePhase = elapsed * config.pulseFrequency * 2 * math.pi
    local pulseScale = 1.0 + 0.1 * math.sin(pulsePhase)
    
    love.graphics.push()
    love.graphics.origin()
    
    -- Dibujar ondas concéntricas usando pxSize directamente (como asteroides)
    for i = 1, config.waveCount do
        local waveAlpha = alpha * (1.0 - (i - 1) / config.waveCount) * 0.8
        local waveRadius = pxSize + (i - 1) * config.waveSpacing
        waveRadius = waveRadius * pulseScale
        
        love.graphics.setColor(config.color[1], config.color[2], config.color[3], waveAlpha)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", screenX, screenY, waveRadius)
    end
    
    love.graphics.pop()
end

-- Función para renderizar lente gravitacional
function GravityAnomaly.drawLensAnomaly(anomaly, screenX, screenY, pxSize, elapsed)
    if not anomaly then return end
    
    local config = GravityAnomaly.config.lens
    elapsed = elapsed or 0
    
    -- Calcular alpha basado en el tiempo de vida
    local alpha = 1.0
    if elapsed < config.fadeInTime then
        alpha = elapsed / config.fadeInTime
    elseif elapsed > (anomaly.duration - config.fadeOutTime) then
        local fadeStart = anomaly.duration - config.fadeOutTime
        alpha = 1.0 - ((elapsed - fadeStart) / config.fadeOutTime)
    end
    
    -- Calcular rotación actual
    local currentRotation = (anomaly.rotation or 0) + elapsed * (anomaly.rotationSpeed or 0)
    
    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(screenX, screenY)
    love.graphics.rotate(currentRotation)
    
    -- Usar pxSize directamente (como asteroides)
    local outerRadius = pxSize * config.outerRadius
    local innerRadius = pxSize * config.innerRadius
    
    -- Dibujar anillo exterior
    love.graphics.setColor(config.color[1], config.color[2], config.color[3], config.color[4] * alpha)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, outerRadius)
    
    -- Dibujar anillo interior con mayor intensidad
    love.graphics.setColor(config.color[1], config.color[2], config.color[3], config.color[4] * alpha * 1.5)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, innerRadius)
    
    -- Dibujar líneas de distorsión
    local distortionLines = 8
    for i = 1, distortionLines do
        local angle = (i / distortionLines) * math.pi * 2
        local x1 = math.cos(angle) * innerRadius
        local y1 = math.sin(angle) * innerRadius
        local x2 = math.cos(angle) * outerRadius
        local y2 = math.sin(angle) * outerRadius
        
        love.graphics.setColor(config.color[1], config.color[2], config.color[3], config.color[4] * alpha * 0.7)
        love.graphics.setLineWidth(1)
        love.graphics.line(x1, y1, x2, y2)
    end
    
    love.graphics.pop()
end

-- Función principal para renderizar anomalías
function GravityAnomaly.drawAnomalies(chunkInfo, camera, getChunkFunc)
    local rendered = 0
    local maxAnomaliesPerFrame = 50  -- Límite de rendimiento
    
    for chunkY = chunkInfo.startY, chunkInfo.endY do
        for chunkX = chunkInfo.startX, chunkInfo.endX do
            if rendered >= maxAnomaliesPerFrame then return rendered end
            
            local chunk = getChunkFunc(chunkX, chunkY)
            if chunk and chunk.gravityAnomalies then
                local chunkBaseX = chunkX * MapConfig.chunk.size * MapConfig.chunk.tileSize * MapConfig.chunk.worldScale
                local chunkBaseY = chunkY * MapConfig.chunk.size * MapConfig.chunk.tileSize * MapConfig.chunk.worldScale
                
                for _, anomaly in ipairs(chunk.gravityAnomalies) do
                    if rendered >= maxAnomaliesPerFrame then return rendered end
                    
                    local worldX = chunkBaseX + anomaly.x * MapConfig.chunk.worldScale
                    local worldY = chunkBaseY + anomaly.y * MapConfig.chunk.worldScale
                    
                    -- Convertir a pantalla una sola vez (igual que asteroides)
                    local screenX, screenY = camera:worldToScreen(worldX, worldY)
                    
                    -- Calcular pxSize exactamente como asteroides: finalSize * camera.zoom
                    local pxSize = anomaly.size * (camera.zoom or 1)
                    
                    -- Culling simple como asteroides
                    local margin = 200
                    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
                    local drawThis = (screenX + pxSize >= -margin) and (screenX - pxSize <= w + margin) and 
                                   (screenY + pxSize >= -margin) and (screenY - pxSize <= h + margin)

                    if drawThis then
                        if anomaly.type == "wave" then
                            -- Placeholder de ondas desactivado: el efecto se aplica vía shader
                            -- No incrementar 'rendered' ya que no se dibuja nada aquí
                        elseif anomaly.type == "lens" then
                            -- Placeholder de lente desactivado: no dibujar ni contar
                        end
                    end
                end
            end
        end
    end
    
    return rendered
end

-- Función para actualizar el sistema de anomalías continuas basado en el bioma del jugador
function GravityAnomaly.updateContinuousSystem(dt, playerX, playerY)
    local currentTime = love.timer.getTime()
    local tracker = GravityAnomaly.playerBiomeTracker
    
    -- Verificar bioma del jugador periódicamente
    if currentTime - tracker.lastBiomeCheck >= tracker.checkInterval then
        tracker.lastBiomeCheck = currentTime
        
        -- Obtener información del bioma actual del jugador
        local BiomeSystem = require 'src.maps.biome_system'
        local biomeInfo = BiomeSystem.getPlayerBiomeInfo(playerX, playerY)
        
        -- Debug: mostrar información del bioma actual
        if biomeInfo then
            print(string.format("[GravityAnomaly DEBUG] Jugador en bioma: %s (tipo: %d) en posición (%.1f, %.1f)", biomeInfo.name or "unknown", biomeInfo.type or -1, playerX, playerY))
            
            -- Almacenar coordenadas del jugador para uso en updateContinuousAnomalies
            tracker.lastPlayerX = playerX
            tracker.lastPlayerY = playerY
            
            -- Detectar si estamos en bioma de gravity anomaly real con periodo de gracia
            local BiomeSystem = require 'src.maps.biome_system'
            local rawIsIn = (biomeInfo.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY)
            if rawIsIn then
                tracker.isInGravityBiome = true
                tracker.lastInBiomeTime = currentTime
            else
                local lastTime = tracker.lastInBiomeTime or 0
                local withinGrace = (lastTime > 0) and ((currentTime - lastTime) <= (tracker.exitGraceSeconds or 0))
                tracker.isInGravityBiome = withinGrace and true or false
            end
            

        else
            print("[GravityAnomaly DEBUG] No se pudo obtener información del bioma")
        end
        
        -- Actualizar estado del tracker
        local wasInGravityBiome = tracker.wasInGravityBiome or false
        
        -- Si entró al bioma, reiniciar el timer de spawn
        if tracker.isInGravityBiome and not wasInGravityBiome then
            tracker.nextSpawnTime = 0  -- Resetear para inicializar en el próximo frame
            print("[GravityAnomaly] Jugador entró al bioma gravity_anomaly - Iniciando anomalías continuas")
        elseif not tracker.isInGravityBiome and wasInGravityBiome then
            -- Resetear el tiempo de spawn al salir del bioma
            tracker.nextSpawnTime = 0
            -- Limpiar anomalías continuas al salir del bioma
            tracker.continuousAnomalies = {}
            print("[GravityAnomaly] Jugador salió del bioma gravity_anomaly - Deteniendo anomalías continuas")
        end
        
        -- Actualizar el estado anterior para la próxima verificación
        tracker.wasInGravityBiome = tracker.isInGravityBiome
    end
    
    -- Esta función se ha movido al final del archivo como función exportada
end

-- Función para renderizar anomalías continuas
function GravityAnomaly.drawContinuousAnomalies(camera)
    if not camera then return end
    -- Preparar lista de lentes visibles en pantalla
    local lenses = {}

    -- Convertir anomalías continuas tipo lente a uniforms normalizados para shader
    for i = #GravityAnomaly.playerBiomeTracker.continuousAnomalies, 1, -1 do
        local anomaly = GravityAnomaly.playerBiomeTracker.continuousAnomalies[i]
        if anomaly and anomaly.type == "lens" then
            local sx, sy = camera:worldToScreen(anomaly.x, anomaly.y)
            local pxSize = anomaly.size * (camera.zoom or 1)
            -- Normalizar a 0..1 basado en tamaño de pantalla actual
            local sw = love.graphics.getWidth()
            local sh = love.graphics.getHeight()
            local nx = sx / sw
            local ny = sy / sh

            -- Fase/duración para animar el radio de la lente
            local t = love.timer.getTime()
            local elapsed = t - (anomaly.startTime or t)
            local dur = anomaly.duration or 2.0
            local phase01 = 0.0
            if dur > 0 then
                phase01 = math.max(0, math.min(1, elapsed / dur))
            end

            -- Curvas de aparición/desaparición (fade in/out)
            local fadeIn = GravityAnomaly.config.lens.fadeInTime or 0.8
            local fadeOut = GravityAnomaly.config.lens.fadeOutTime or 1.0
            local scale = 1.0
            if elapsed < fadeIn then
                local x = elapsed / math.max(0.0001, fadeIn)
                scale = 1.0 * (1 - (1 - x)^3)
            elseif elapsed > dur - fadeOut then
                local x = math.max(0.0, (dur - elapsed) / math.max(0.0001, fadeOut))
                scale = x^3
            else
                scale = 1.0
            end

            -- Pulso suave durante la vida útil (opcional)
            local pulse = 1.0
            local freq = 2.0
            pulse = 1.0 + 0.05 * math.sin(phase01 * math.pi * 2.0 * freq)

            -- Radio base normalizado por pantalla y ajustado por fase y pulso (toma el size del placeholder)
            local baseRadius = pxSize / math.min(sw, sh)
            local nr = baseRadius * scale * 0.75 * pulse -- reducir tamaño ~25%
            nr = math.max(0.001, nr)

            -- Ancho del borde a partir del placeholder (outer-inner en píxeles -> normalizado)
            local lensCfg = GravityAnomaly.config.lens
            local widthRatio = math.max(0.05, (lensCfg.outerRadius or 1.0) - (lensCfg.innerRadius or 0.3))
            local desiredEdgePx = pxSize * widthRatio * 0.35 -- factor para no exagerar
            local edge_softness = math.max(0.005, math.min(0.25, desiredEdgePx / math.min(sw, sh)))

            -- Sincronizar el "poder" del lente con la fase
            local baseMag = anomaly.magnification or 1.45
            local baseDist = anomaly.distortion or 0.85
            local mag = 1.0 + (baseMag - 1.0) * scale  -- acompaña el tamaño
            local dist = baseDist * (0.5 + 0.5 * scale) -- 50% al inicio -> 100% en fase plena

            table.insert(lenses, {
                pos = {nx, ny},
                radius = nr,
                magnification = mag,
                distortion_strength = dist,
                edge_softness = edge_softness,
                chromatic_aberration = 0.0006,
                effect_type = 0
            })
        end
    end

    -- Convertir anomalías continuas tipo onda a pases de shader (effect_type=1)
    for i = #GravityAnomaly.playerBiomeTracker.continuousAnomalies, 1, -1 do
        local anomaly = GravityAnomaly.playerBiomeTracker.continuousAnomalies[i]
        if anomaly and anomaly.type == "wave" then
            local sx, sy = camera:worldToScreen(anomaly.x, anomaly.y)
            local pxSize = anomaly.size * (camera.zoom or 1)
            local sw = love.graphics.getWidth()
            local sh = love.graphics.getHeight()
            local nx = sx / sw
            local ny = sy / sh

            local t = love.timer.getTime()
            local elapsed = t - (anomaly.startTime or t)
            local dur = anomaly.duration or (GravityAnomaly.config.waves and GravityAnomaly.config.waves.animationDuration) or 3.0
            if elapsed < 0 or elapsed > dur then
                -- fuera de vida útil
            else
                local wcfg = GravityAnomaly.config.waves
                -- Calcular factor de aparición/desaparición
                local alpha = 1.0
                if wcfg then
                    if elapsed < (wcfg.fadeInTime or 0.6) then
                        alpha = elapsed / math.max(0.0001, (wcfg.fadeInTime or 0.6))
                    elseif elapsed > dur - (wcfg.fadeOutTime or 0.8) then
                        local x = (dur - elapsed) / math.max(0.0001, (wcfg.fadeOutTime or 0.8))
                        alpha = math.max(0.0, x)
                    end
                end

                -- Pulso en radio
                local pulseScale = 1.0
                if wcfg and wcfg.pulseFrequency then
                    pulseScale = 1.0 + 0.1 * math.sin(elapsed * wcfg.pulseFrequency * 2.0 * math.pi)
                end

                -- Radio base y spacing normalizados
                local baseRadius = pxSize / math.min(sw, sh)
                local spacingPx = (wcfg and wcfg.waveSpacing) or 15
                local spacingN = spacingPx / math.min(sw, sh)

                -- Anchura y amplitud de la banda en unidades normalizadas
                local widthN = math.max(0.002, math.min(0.05, (spacingPx * 0.6) / math.min(sw, sh)))
                local ampN = math.max(0.001, math.min(0.01, (spacingPx * 0.25) / math.min(sw, sh))) * alpha

                local count = (wcfg and wcfg.waveCount) or 3
                for k = 1, count do
                    local radiusN = (baseRadius + (k - 1) * spacingN) * pulseScale
                    table.insert(lenses, {
                        pos = {nx, ny},
                        radius = radiusN,
                        effect_type = 1,
                        wave_width = widthN,
                        wave_amplitude = ampN,
                        -- Valores no usados por wave, pero enviados para consistencia
                        magnification = 1.0,
                        distortion_strength = 0.0,
                        edge_softness = 0.01,
                        chromatic_aberration = 0.0
                    })
                end
            end
        end
    end

    if #lenses == 0 then
        return
    end

    local function drawBackgroundLayers()
        local Map = require 'src.maps.map'
        local MapRenderer = require 'src.maps.systems.map_renderer'
        local BackgroundManager = require 'src.shaders.background_manager'
        BackgroundManager.render(camera)
        local chunkInfo = Map.calculateVisibleChunksTraditional(camera)
        MapRenderer.drawBiomeBackground(chunkInfo, Map.getChunkNonBlocking)
        MapRenderer.drawMicroStars(camera)
        MapRenderer.drawSmallStars(camera)
        MapRenderer.drawEnhancedStars(chunkInfo, camera, Map.getChunkNonBlocking, Map.starConfig)
        MapRenderer.drawNebulae(chunkInfo, camera, Map.getChunkNonBlocking)
        MapRenderer.drawAsteroids(chunkInfo, camera, Map.getChunkNonBlocking)
        MapRenderer.drawSpecialObjects(chunkInfo, camera, Map.getChunkNonBlocking)
        MapRenderer.drawBiomeFeatures(chunkInfo, camera, Map.getChunkNonBlocking)
    end

    _G.__magnifier = _G.__magnifier or require('src/shaders/MagnifyingGlass').new({
        magnification = 1.45,
        distortion_strength = 0.85,
        edge_softness = 0.16,
        chromatic_aberration = 0.0006
    })

    _G.__magnifier:applyMultiple(lenses, drawBackgroundLayers)
end

-- Utilidad: comprobar si hay lentes activas actualmente
function GravityAnomaly.hasActiveLenses()
    local tracker = GravityAnomaly.playerBiomeTracker
    local t = love.timer.getTime()
    for i = 1, #tracker.continuousAnomalies do
        local a = tracker.continuousAnomalies[i]
        if a and a.type == 'lens' then
            local e = t - a.startTime
            if e >= 0 and e <= (a.duration or 0) then
                return true
            end
        end
    end
    return false
end

-- Nuevo: solo dibuja los overlays de anomalías continuas (ondas y anillos de lente)
function GravityAnomaly.drawContinuousOverlays(camera)
    local tracker = GravityAnomaly.playerBiomeTracker
    local currentTime = love.timer.getTime()

    for _, anomaly in ipairs(tracker.continuousAnomalies) do
        local elapsed = currentTime - anomaly.startTime
        if elapsed >= 0 and elapsed <= anomaly.duration then
            local screenX, screenY = camera:worldToScreen(anomaly.x, anomaly.y)
            local pxSize = anomaly.size * (camera.zoom or 1)
            local margin = 200
            local w, h = love.graphics.getWidth(), love.graphics.getHeight()
            local drawThis = (screenX + pxSize >= -margin) and (screenX - pxSize <= w + margin) and 
                             (screenY + pxSize >= -margin) and (screenY - pxSize <= h + margin)
            if drawThis then
                if anomaly.type == 'wave' then
                    -- Placeholder de ondas desactivado: el efecto se aplica vía shader
                elseif anomaly.type == 'lens' then
                    -- Placeholder de lente desactivado en overlays continuos
                 end
            end
        end
    end
end
-- Función para actualizar anomalías continuas (llamada desde map.lua)
function GravityAnomaly.updateContinuousAnomalies(camera)
    local tracker = GravityAnomaly.playerBiomeTracker
    local currentTime = love.timer.getTime()

    -- Limpiar anomalías expiradas
    for i = #tracker.continuousAnomalies, 1, -1 do
        local anomaly = tracker.continuousAnomalies[i]
        local elapsed = currentTime - (anomaly.startTime or 0)
        if elapsed > (anomaly.duration or 0) then
            table.remove(tracker.continuousAnomalies, i)
        end
    end

    -- Si no estamos en el bioma de gravedad, no spawnear
    if not tracker.isInGravityBiome then
        return
    end

    -- Contar activas
    local activeCount = 0
    for _, anomaly in ipairs(tracker.continuousAnomalies) do
        local elapsed = currentTime - (anomaly.startTime or 0)
        if elapsed >= 0 and elapsed <= (anomaly.duration or 0) then
            activeCount = activeCount + 1
        end
    end

    -- Inicializar siguiente spawn al entrar
    if tracker.nextSpawnTime == 0 then
        local quickSpawn = 0.3 + math.random() * 0.5
        tracker.nextSpawnTime = currentTime + quickSpawn
    end

    -- Spawnear si es tiempo y por debajo del máximo
    if currentTime >= tracker.nextSpawnTime and activeCount < (tracker.maxContinuousAnomalies or 6) then
        local jitter = (math.random() - 0.5) * tracker.spawnInterval * 0.4
        tracker.nextSpawnTime = currentTime + (tracker.spawnInterval or 1.5) + jitter

        -- Calcular área en mundo basada en la pantalla con margen
        local left, top, right, bottom
        if camera and type(camera.screenToWorld) == 'function' then
            local w, h = love.graphics.getWidth(), love.graphics.getHeight()
            local marginPx = 1200
            local wl, wt = camera:screenToWorld(-marginPx, -marginPx)
            local wr, wb = camera:screenToWorld(w + marginPx, h + marginPx)
            left, right = math.min(wl, wr), math.max(wl, wr)
            top, bottom = math.min(wt, wb), math.max(wt, wb)
        else
            -- Fallback a un área alrededor del último jugador
            local cx = tracker.lastPlayerX or 0
            local cy = tracker.lastPlayerY or 0
            local spread = 3000
            left, right = cx - spread, cx + spread
            top, bottom = cy - spread, cy + spread
        end

        local BiomeSystem = require 'src.maps.biome_system'
        local chunkWorldSize = MapConfig.chunk.size * MapConfig.chunk.tileSize * MapConfig.chunk.worldScale
        local x, y

        -- Intentar encontrar punto dentro del bioma de gravedad
        for _ = 1, 6 do
            local rx = left + math.random() * (right - left)
            local ry = top + math.random() * (bottom - top)
            local cx = math.floor(rx / chunkWorldSize)
            local cy = math.floor(ry / chunkWorldSize)
            local info = BiomeSystem.getBiomeInfo(cx, cy)
            if info and info.type == BiomeSystem.BiomeType.GRAVITY_ANOMALY then
                x, y = rx, ry
                break
            end
        end

        if not x or not y then
            x = (left + right) * 0.5 + (math.random() - 0.5) * 1000
            y = (top + bottom) * 0.5 + (math.random() - 0.5) * 1000
        end

        -- Elegir tipo y crear anomalía
        local isWave = (math.random() < 0.55)
        if isWave then
            table.insert(tracker.continuousAnomalies, {
                type = 'wave',
                x = x,
                y = y,
                size = math.random() * (GravityAnomaly.config.waves.maxSize - GravityAnomaly.config.waves.minSize) + GravityAnomaly.config.waves.minSize,
                startTime = currentTime,
                duration = GravityAnomaly.config.waves.animationDuration,
                phase = math.random() * math.pi * 2
            })
        else
            table.insert(tracker.continuousAnomalies, {
                type = 'lens',
                x = x,
                y = y,
                size = math.random() * (GravityAnomaly.config.lens.maxSize - GravityAnomaly.config.lens.minSize) + GravityAnomaly.config.lens.minSize,
                startTime = currentTime,
                duration = GravityAnomaly.config.lens.animationDuration,
                rotation = math.random() * math.pi * 2,
                rotationSpeed = (math.random() - 0.5) * 0.5
            })
        end
    end
end
return GravityAnomaly