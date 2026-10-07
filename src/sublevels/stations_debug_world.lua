-- src/sublevels/stations_debug_world.lua
-- Sistema de visualización, depuración y navegación de Megaestructuras Espaciales
-- Permite pruebas directas de parallax 2.5D, rotación y variantes de daño.

local StationsDebugDef = require 'src.sublevels.definitions.stations_debug'
local AncientRuinsRenderer = require 'src.maps.systems.ancient_ruins_renderer'

local StationsDebugWorld = {
    stations = {},
    autoRotate = false,
    closestStation = nil,
    tier = "debug_all"
}

function StationsDebugWorld.init(cfg)
    local meta = cfg and cfg.meta
    local tier = (meta and meta.tier) or "debug_all"
    StationsDebugWorld.tier = tier
    StationsDebugWorld.stations = StationsDebugDef.getStationsForTier(tier)
    StationsDebugWorld.autoRotate = false
    StationsDebugWorld.closestStation = nil
end

function StationsDebugWorld.update(dt, player)
    local px = (player and player.x) or 0
    local py = (player and player.y) or 0

    local closest = nil
    local minDist = math.huge

    for _, st in ipairs(StationsDebugWorld.stations) do
        if StationsDebugWorld.autoRotate then
            st.rotation = (st.rotation + (st.rotSpeed or 0.04) * dt) % (math.pi * 2)
        end

        local dx = st.x - px
        local dy = st.y - py
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < minDist then
            minDist = dist
            closest = st
        end
    end

    StationsDebugWorld.closestStation = closest
end

-- ============================================================================
-- RENDERIZADO EN ESPACIO DE MUNDO (DENTRO DE camera:apply())
-- ============================================================================

function StationsDebugWorld.draw(camera, player)
    if #StationsDebugWorld.stations == 0 then return end

    local px = (player and player.x) or 0
    local py = (player and player.y) or 0
    local t = love.timer.getTime()

    -- 1. Líneas de guía y cuadrícula de hangar entre estaciones alineadas
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.15, 0.25, 0.40, 0.25)

    -- Agrupar estaciones por fila (Y similar)
    local rows = {}
    for _, st in ipairs(StationsDebugWorld.stations) do
        local rKey = math.floor(st.y)
        rows[rKey] = rows[rKey] or {}
        table.insert(rows[rKey], st)
    end

    for _, rowList in pairs(rows) do
        table.sort(rowList, function(a, b) return a.x < b.x end)
        if #rowList >= 2 then
            local x1 = rowList[1].x - 600
            local x2 = rowList[#rowList].x + 600
            local yLine = rowList[1].y
            love.graphics.setColor(0.20, 0.35, 0.55, 0.30)
            love.graphics.line(x1, yLine, x2, yLine)

            -- Balizas de pista parpadeantes
            for _, st in ipairs(rowList) do
                local pulse = 0.5 + 0.5 * math.sin(t * 2.0 + st.seed * 0.1)
                love.graphics.setColor(0.3, 0.7, 1.0, 0.4 * pulse)
                love.graphics.circle("fill", st.x, yLine - 450, 4)
                love.graphics.circle("fill", st.x, yLine + 450, 4)
            end
        end
    end

    -- 2. Renderizar cada estación espacial mediante AncientRuinsRenderer
    for _, st in ipairs(StationsDebugWorld.stations) do
        -- Calcular LOD según distancia a la cámara
        local camX = (camera and camera.x) or px
        local camY = (camera and camera.y) or py
        local distToCam = math.sqrt((st.x - camX)^2 + (st.y - camY)^2)
        local lod = 0
        if distToCam > 7000 then lod = 3
        elseif distToCam > 4000 then lod = 2
        elseif distToCam > 2000 then lod = 1 end

        -- Dibujar la megaestructura
        AncientRuinsRenderer.renderPlaceholder(st, camera, lod)

        -- 3. Señalética holográfica flotante de Debug sobre la estación
        local tagY = st.y - st.size - 60
        local isNear = (st == StationsDebugWorld.closestStation)

        -- Línea vertical conectora
        love.graphics.setColor(0.35, 0.55, 0.75, isNear and 0.55 or 0.25)
        love.graphics.setLineWidth(1)
        love.graphics.line(st.x, tagY + 28, st.x, st.y - st.size * 0.7)

        -- Placa de fondo holográfica
        local tagW = 280
        local tagH = 50
        local tagX = st.x - tagW * 0.5

        local badgeCol = st.colorBadge or { 0.4, 0.7, 1.0 }
        love.graphics.setColor(0.04, 0.07, 0.12, isNear and 0.88 or 0.70)
        love.graphics.rectangle("fill", tagX, tagY, tagW, tagH, 5, 5)

        -- Borde Sci-Fi
        love.graphics.setColor(badgeCol[1], badgeCol[2], badgeCol[3], isNear and 0.90 or 0.45)
        love.graphics.setLineWidth(isNear and 1.8 or 1.0)
        love.graphics.rectangle("line", tagX, tagY, tagW, tagH, 5, 5)

        -- Badge de estado
        local badgeW = 100
        love.graphics.setColor(badgeCol[1] * 0.25, badgeCol[2] * 0.25, badgeCol[3] * 0.25, 0.9)
        love.graphics.rectangle("fill", tagX + tagW - badgeW - 6, tagY + 6, badgeW, 18, 3, 3)
        love.graphics.setColor(badgeCol[1], badgeCol[2], badgeCol[3], 1.0)
        love.graphics.printf(st.badgeText or "ESTADO", tagX + tagW - badgeW - 6, tagY + 8, badgeW, "center")

        -- Título de la estación
        love.graphics.setColor(1, 1, 1, isNear and 1.0 or 0.85)
        love.graphics.printf(st.shortName or st.name, tagX + 10, tagY + 8, tagW - badgeW - 20, "left")

        -- Subtexto técnico (LOD y distancia)
        local distSt = math.floor(math.sqrt((st.x - px)^2 + (st.y - py)^2))
        local subtext = string.format("LOD %d | Dist: %dm", lod, distSt)
        love.graphics.setColor(0.65, 0.75, 0.88, 0.80)
        love.graphics.printf(subtext, tagX + 10, tagY + 30, tagW - 20, "left")
    end

    love.graphics.setLineWidth(1)
end

-- ============================================================================
-- RENDERIZADO DE HUD DE CONTROL DE DEBUG (FUERA DE camera:apply())
-- ============================================================================

function StationsDebugWorld.drawHUD()
    if #StationsDebugWorld.stations == 0 then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()

    -- Banner flotante superior de controles
    local barW = math.min(760, sw - 40)
    local barH = 58
    local barX = math.floor((sw - barW) * 0.5)
    local barY = 14

    love.graphics.setColor(0.05, 0.08, 0.13, 0.85)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 8, 8)

    love.graphics.setColor(0.25, 0.65, 0.95, 0.75)
    love.graphics.setLineWidth(1.4)
    love.graphics.rectangle("line", barX, barY, barW, barH, 8, 8)

    -- Título del centro de pruebas
    love.graphics.setColor(0.95, 0.98, 1.0, 0.95)
    love.graphics.printf("ESTACIONES ESPACIALES (DEBUG)", barX, barY + 8, barW, "center")

    -- Línea de atajos de teletransporte
    local rotStatus = StationsDebugWorld.autoRotate and "ACTIVA" or "PAUSADA"
    local helpText = "[1-9] Teletransporte  |  [0] Origen  |  [R] Rotación: " .. rotStatus .. "  |  [Q] Salir"

    love.graphics.setColor(0.70, 0.82, 0.95, 0.85)
    love.graphics.printf(helpText, barX, barY + 32, barW, "center")

    -- Mini-panel inferior izquierdo con la estación actual más cercana
    if StationsDebugWorld.closestStation then
        local st = StationsDebugWorld.closestStation
        local infoW = 340
        local infoH = 68
        local infoX = 20
        local infoY = sh - infoH - 24

        love.graphics.setColor(0.04, 0.07, 0.12, 0.82)
        love.graphics.rectangle("fill", infoX, infoY, infoW, infoH, 6, 6)

        local bc = st.colorBadge or { 0.3, 0.7, 1.0 }
        love.graphics.setColor(bc[1], bc[2], bc[3], 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", infoX, infoY, infoW, infoH, 6, 6)

        love.graphics.setColor(bc[1], bc[2], bc[3], 1.0)
        love.graphics.printf(st.name, infoX + 10, infoY + 8, infoW - 20, "left")

        love.graphics.setColor(0.75, 0.82, 0.90, 0.80)
        love.graphics.printf(st.desc or "", infoX + 10, infoY + 28, infoW - 20, "left")
    end

    love.graphics.setLineWidth(1)
end

-- ============================================================================
-- TELETRANSPORTE Y ATAJOS DE TECLADO
-- ============================================================================

function StationsDebugWorld.keypressed(key, player, camera)
    -- 'r': Alternar rotación automática de las estaciones
    if key == 'r' then
        StationsDebugWorld.autoRotate = not StationsDebugWorld.autoRotate
        return true
    end

    -- '0': Teletransportar al centro
    if key == '0' then
        if player then
            player.x, player.y = 0, 0
            if player.dx then player.dx = 0 end
            if player.dy then player.dy = 0 end
            if player.body and player.body.setPosition then
                player.body:setPosition(0, 0)
                player.body:setLinearVelocity(0, 0)
            end
        end
        if camera then
            camera.x, camera.y = 0, 0
            camera:setPosition(0, 0)
        end
        return true
    end

    -- '1'..'9': Teletransporte rápido a la estación correspondiente
    local num = tonumber(key)
    if num and num >= 1 and num <= #StationsDebugWorld.stations then
        local target = StationsDebugWorld.stations[num]
        if target then
            -- Posicionar al jugador a 420 px por debajo de la estación para visualización óptima
            local targetPX = target.x
            local targetPY = target.y + 440

            if player then
                player.x = targetPX
                player.y = targetPY
                player.rotation = -math.pi * 0.5 -- Apuntando hacia la estación (hacia arriba)
                if player.dx then player.dx = 0 end
                if player.dy then player.dy = 0 end
                if player.body and player.body.setPosition then
                    player.body:setPosition(targetPX, targetPY)
                    player.body:setLinearVelocity(0, 0)
                end
            end

            if camera then
                camera.x = targetPX
                camera.y = targetPY - 120
                camera:setPosition(camera.x, camera.y)
            end
            return true
        end
    end

    return false
end

return StationsDebugWorld
