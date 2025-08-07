-- src/maps/coordinate_system.lua
-- Sistema de coordenadas relativas para manejo de grandes distancias

local CoordinateSystem = {}

-- Configuración del sistema
CoordinateSystem.config = {
    -- Tamaño de cada sector (en unidades del juego)
    sectorSize = 1000000,  -- 1 millón de unidades por sector
    -- Distancia máxima desde el origen antes de recalcular
    maxDistanceFromOrigin = 500000,  -- 500k unidades
    -- Precisión mínima para comparaciones
    epsilon = 0.001
}

-- Estado actual del sistema
CoordinateSystem.state = {
    -- Origen actual del mundo (sector coordinates)
    originSectorX = 0,
    originSectorY = 0,
    -- Offset actual dentro del sector
    originOffsetX = 0,
    originOffsetY = 0,
    -- Contador de reubicaciones
    relocations = 0,
    -- Tiempo de la última reubicación
    lastRelocation = 0
}

-- Cache de conversiones para optimización
CoordinateSystem.cache = {
    lastPlayerX = 0,
    lastPlayerY = 0,
    lastSectorX = 0,
    lastSectorY = 0,
    cacheValid = false
}

-- Inicializar el sistema de coordenadas
function CoordinateSystem.init(playerX, playerY)
    playerX = playerX or 0
    playerY = playerY or 0
    
    -- Calcular sector inicial basado en posición del jugador
    local sectorX = math.floor(playerX / CoordinateSystem.config.sectorSize)
    local sectorY = math.floor(playerY / CoordinateSystem.config.sectorSize)
    
    CoordinateSystem.state.originSectorX = sectorX
    CoordinateSystem.state.originSectorY = sectorY
    CoordinateSystem.state.originOffsetX = playerX - (sectorX * CoordinateSystem.config.sectorSize)
    CoordinateSystem.state.originOffsetY = playerY - (sectorY * CoordinateSystem.config.sectorSize)
    CoordinateSystem.state.relocations = 0
    CoordinateSystem.state.lastRelocation = love.timer.getTime()
    
    -- Invalidar cache
    CoordinateSystem.cache.cacheValid = false
    
    print("CoordinateSystem initialized at sector (" .. sectorX .. ", " .. sectorY .. ")")
    print("Origin offset: (" .. CoordinateSystem.state.originOffsetX .. ", " .. CoordinateSystem.state.originOffsetY .. ")")
end

-- Convertir coordenadas del mundo a coordenadas relativas al origen actual
function CoordinateSystem.worldToRelative(worldX, worldY)
    -- Calcular sector de las coordenadas del mundo
    local sectorX = math.floor(worldX / CoordinateSystem.config.sectorSize)
    local sectorY = math.floor(worldY / CoordinateSystem.config.sectorSize)
    
    -- Calcular offset dentro del sector
    local offsetX = worldX - (sectorX * CoordinateSystem.config.sectorSize)
    local offsetY = worldY - (sectorY * CoordinateSystem.config.sectorSize)
    
    -- Calcular diferencia de sectores respecto al origen
    local sectorDiffX = sectorX - CoordinateSystem.state.originSectorX
    local sectorDiffY = sectorY - CoordinateSystem.state.originSectorY
    
    -- Calcular coordenadas relativas
    local relativeX = (sectorDiffX * CoordinateSystem.config.sectorSize) + offsetX - CoordinateSystem.state.originOffsetX
    local relativeY = (sectorDiffY * CoordinateSystem.config.sectorSize) + offsetY - CoordinateSystem.state.originOffsetY
    
    return relativeX, relativeY
end

-- Convertir coordenadas relativas a coordenadas del mundo
function CoordinateSystem.relativeToWorld(relativeX, relativeY)
    -- Calcular coordenadas del mundo basadas en el origen actual
    local worldX = relativeX + CoordinateSystem.state.originOffsetX + 
                   (CoordinateSystem.state.originSectorX * CoordinateSystem.config.sectorSize)
    local worldY = relativeY + CoordinateSystem.state.originOffsetY + 
                   (CoordinateSystem.state.originSectorY * CoordinateSystem.config.sectorSize)
    
    return worldX, worldY
end

-- Obtener coordenadas de sector para coordenadas del mundo
function CoordinateSystem.getSectorCoordinates(worldX, worldY)
    local sectorX = math.floor(worldX / CoordinateSystem.config.sectorSize)
    local sectorY = math.floor(worldY / CoordinateSystem.config.sectorSize)
    local offsetX = worldX - (sectorX * CoordinateSystem.config.sectorSize)
    local offsetY = worldY - (sectorY * CoordinateSystem.config.sectorSize)
    
    return sectorX, sectorY, offsetX, offsetY
end

-- Verificar si es necesario reubicar el origen
function CoordinateSystem.needsRelocation(playerX, playerY)
    local relativeX, relativeY = CoordinateSystem.worldToRelative(playerX, playerY)
    local distance = math.sqrt(relativeX * relativeX + relativeY * relativeY)
    
    return distance > CoordinateSystem.config.maxDistanceFromOrigin
end

-- Reubicar el origen del sistema de coordenadas
function CoordinateSystem.relocateOrigin(newPlayerX, newPlayerY, callback)
    local oldSectorX = CoordinateSystem.state.originSectorX
    local oldSectorY = CoordinateSystem.state.originSectorY
    local oldOffsetX = CoordinateSystem.state.originOffsetX
    local oldOffsetY = CoordinateSystem.state.originOffsetY
    
    -- Calcular nuevo sector basado en posición del jugador
    local newSectorX = math.floor(newPlayerX / CoordinateSystem.config.sectorSize)
    local newSectorY = math.floor(newPlayerY / CoordinateSystem.config.sectorSize)
    
    -- Calcular nuevo offset
    local newOffsetX = newPlayerX - (newSectorX * CoordinateSystem.config.sectorSize)
    local newOffsetY = newPlayerY - (newSectorY * CoordinateSystem.config.sectorSize)
    
    -- Actualizar estado
    CoordinateSystem.state.originSectorX = newSectorX
    CoordinateSystem.state.originSectorY = newSectorY
    CoordinateSystem.state.originOffsetX = newOffsetX
    CoordinateSystem.state.originOffsetY = newOffsetY
    CoordinateSystem.state.relocations = CoordinateSystem.state.relocations + 1
    CoordinateSystem.state.lastRelocation = love.timer.getTime()
    
    -- Invalidar cache
    CoordinateSystem.cache.cacheValid = false
    
    print("Origin relocated from sector (" .. oldSectorX .. ", " .. oldSectorY .. ") to (" .. newSectorX .. ", " .. newSectorY .. ")")
    print("Relocation #" .. CoordinateSystem.state.relocations)
    
    -- Ejecutar callback si se proporciona (para notificar a otros sistemas)
    if callback then
        callback(oldSectorX, oldSectorY, newSectorX, newSectorY, oldOffsetX, oldOffsetY, newOffsetX, newOffsetY)
    end
    
    return true
end

-- Actualizar el sistema (llamar cada frame)
function CoordinateSystem.update(playerX, playerY, forceRelocation)
    -- Verificar si necesita reubicación
    if forceRelocation or CoordinateSystem.needsRelocation(playerX, playerY) then
        return CoordinateSystem.relocateOrigin(playerX, playerY)
    end
    
    -- Actualizar cache si es necesario
    if not CoordinateSystem.cache.cacheValid or 
       math.abs(CoordinateSystem.cache.lastPlayerX - playerX) > CoordinateSystem.config.epsilon or
       math.abs(CoordinateSystem.cache.lastPlayerY - playerY) > CoordinateSystem.config.epsilon then
        
        CoordinateSystem.cache.lastPlayerX = playerX
        CoordinateSystem.cache.lastPlayerY = playerY
        CoordinateSystem.cache.lastSectorX, CoordinateSystem.cache.lastSectorY = 
            CoordinateSystem.getSectorCoordinates(playerX, playerY)
        CoordinateSystem.cache.cacheValid = true
    end
    
    return false
end

-- Calcular distancia entre dos puntos en coordenadas del mundo (manejo de precisión)
function CoordinateSystem.worldDistance(x1, y1, x2, y2)
    -- Convertir a relativas para mantener precisión
    local rel1X, rel1Y = CoordinateSystem.worldToRelative(x1, y1)
    local rel2X, rel2Y = CoordinateSystem.worldToRelative(x2, y2)
    
    local dx = rel2X - rel1X
    local dy = rel2Y - rel1Y
    
    return math.sqrt(dx * dx + dy * dy)
end

-- Interpolar entre dos posiciones del mundo
function CoordinateSystem.worldLerp(x1, y1, x2, y2, t)
    -- Convertir a relativas para mantener precisión
    local rel1X, rel1Y = CoordinateSystem.worldToRelative(x1, y1)
    local rel2X, rel2Y = CoordinateSystem.worldToRelative(x2, y2)
    
    local lerpX = rel1X + (rel2X - rel1X) * t
    local lerpY = rel1Y + (rel2Y - rel1Y) * t
    
    return CoordinateSystem.relativeToWorld(lerpX, lerpY)
end

-- Verificar si dos coordenadas del mundo están en el mismo sector
function CoordinateSystem.sameSection(x1, y1, x2, y2)
    local sector1X = math.floor(x1 / CoordinateSystem.config.sectorSize)
    local sector1Y = math.floor(y1 / CoordinateSystem.config.sectorSize)
    local sector2X = math.floor(x2 / CoordinateSystem.config.sectorSize)
    local sector2Y = math.floor(y2 / CoordinateSystem.config.sectorSize)
    
    return sector1X == sector2X and sector1Y == sector2Y
end

-- Obtener información del estado actual
function CoordinateSystem.getState()
    return {
        originSector = {
            x = CoordinateSystem.state.originSectorX,
            y = CoordinateSystem.state.originSectorY
        },
        originOffset = {
            x = CoordinateSystem.state.originOffsetX,
            y = CoordinateSystem.state.originOffsetY
        },
        relocations = CoordinateSystem.state.relocations,
        lastRelocation = CoordinateSystem.state.lastRelocation,
        sectorSize = CoordinateSystem.config.sectorSize,
        maxDistance = CoordinateSystem.config.maxDistanceFromOrigin
    }
end

-- Obtener estadísticas del sistema
function CoordinateSystem.getStats()
    local currentTime = love.timer.getTime()
    local timeSinceLastRelocation = currentTime - CoordinateSystem.state.lastRelocation
    
    return {
        relocations = CoordinateSystem.state.relocations,
        timeSinceLastRelocation = timeSinceLastRelocation,
        currentSector = {
            x = CoordinateSystem.state.originSectorX,
            y = CoordinateSystem.state.originSectorY
        },
        cacheHits = CoordinateSystem.cache.cacheValid and 1 or 0
    }
end

-- Función de debug para verificar precisión
function CoordinateSystem.debugPrecision(testX, testY)
    local relX, relY = CoordinateSystem.worldToRelative(testX, testY)
    local backX, backY = CoordinateSystem.relativeToWorld(relX, relY)
    
    local errorX = math.abs(testX - backX)
    local errorY = math.abs(testY - backY)
    
    print("Debug Precision Test:")
    print("  Input: (" .. testX .. ", " .. testY .. ")")
    print("  Relative: (" .. relX .. ", " .. relY .. ")")
    print("  Back to World: (" .. backX .. ", " .. backY .. ")")
    print("  Error: (" .. errorX .. ", " .. errorY .. ")")
    print("  Within Epsilon: " .. (errorX < CoordinateSystem.config.epsilon and errorY < CoordinateSystem.config.epsilon))
    
    return errorX < CoordinateSystem.config.epsilon and errorY < CoordinateSystem.config.epsilon
end

return CoordinateSystem