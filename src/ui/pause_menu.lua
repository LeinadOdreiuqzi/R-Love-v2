-- src/ui/pause_menu.lua
-- Menú de Pausa modular con opciones estándar y panel de depuración de audio

local PauseMenu = {
    state = {
        isOpen = false,
        view = "main", -- "main" | "audio_debug" | "sublevels" | "sublevels_detail"
        selectedSubworld = nil,
        fadeAlpha = 0,
        hoveredButton = nil
    }
}

local World = require 'src.core.world'
local GameState = require 'src.core.game_state'

local function getAudio()
    local ok, am = pcall(require, 'src.audio.audio_manager')
    if ok and am then return am end
    return World.get('audio')
end

-- Lista de soundtracks disponibles para depuración
local SOUNDTRACKS = {
    { id = "track_1", alias = "astral_pulse",      name = "Track 1" },
    { id = "track_2", alias = "opaline_haven",     name = "Track 2" },
    { id = "track_3", alias = "lunar_waltz",       name = "Track 3" },
    { id = "track_4", alias = "ancient_sanctuary", name = "Track 4" },
    { id = "track_5", alias = "cavern_groove",     name = "Track 5" },
    { id = "track_6", alias = "space_ambient",     name = "Track 6" },
    { id = "track_7", alias = "carousel_waltz",    name = "Track 7" },
    { id = "track_8", alias = "celestial_spring",  name = "Track 8" }
}

-- Lista de submundos y sus subniveles
local SUBWORLDS = {
    {
        id = "stations_debug",
        name = "Estaciones (Debug)",
        color = { 0.25, 0.85, 0.95 },
        levels = {
            { id = "stations_gallery_all", name = "Todas las Estaciones", tier = "debug_all", width = 16, height = 16, color = { 0.25, 0.85, 0.95 } }
        }
    },
    {
        id = "tau_ceti",
        name = "Tau Ceti",
        color = { 0.78, 0.42, 0.95 },
        levels = {
            { id = "tau_ceti_1", name = "Nivel 1", tier = 1, width = 8, height = 8, color = { 0.40, 0.70, 1.00 } },
            { id = "tau_ceti_2", name = "Nivel 2", tier = 2, width = 8, height = 8, color = { 1.00, 0.75, 0.30 } },
            { id = "tau_ceti_3", name = "Nivel 3", tier = 3, width = 8, height = 8, color = { 0.30, 0.90, 0.65 } }
        }
    },
    {
        id = "sandbox",
        name = "Sandbox",
        color = { 0.45, 0.70, 0.90 },
        levels = {
            { id = "sandbox_1", name = "Nivel 1", tier = 0, width = 8, height = 8, color = { 0.60, 0.65, 0.75 } }
        }
    }
}

local function launchSublevel(levelDef, subworldDef)
    PauseMenu.close()

    local ok, err = pcall(function()
        local SubLevelManager = require 'src.maps.systems.sublevel_manager'
        local SubLevelScene = require 'src.sublevels.sublevel_scene'
        local GameState = require 'src.core.game_state'
        local Map = require 'src.maps.map'

        local currentSeed = (GameState and GameState.state and GameState.state.currentSeed) or (Map and Map.seed) or "SUBLEVEL_SEED"
        local cfg = SubLevelManager.createConfig({
            parentSeed = currentSeed,
            type = levelDef.id,
            width = levelDef.width or 8,
            height = levelDef.height or 8,
            context = "menu|" .. tostring(levelDef.id),
            meta = {
                id = levelDef.id,
                name = (subworldDef and subworldDef.name or "") .. " - " .. levelDef.name,
                tier = levelDef.tier,
                subworldId = subworldDef and subworldDef.id or "default",
                accent = levelDef.color or { 0.35, 0.75, 1.0 }
            }
        })

        local stateManager = World.get('stateManager')
        if stateManager then
            local scene = SubLevelScene:new(cfg)
            stateManager:push(scene, { suspendUnderlying = true, fadeDuration = 0.25 })
        end
    end)

    if not ok then
        print("[PauseMenu] Error launching sublevel: " .. tostring(err))
    end
end



-- ============================================================================
-- CONTROL DE ESTADO
-- ============================================================================

function PauseMenu.isOpen()
    return PauseMenu.state.isOpen
end

function PauseMenu.open()
    PauseMenu.state.isOpen = true
    PauseMenu.state.view = "main"
    PauseMenu.state.fadeAlpha = 0
    PauseMenu.state.hoveredButton = nil

    if GameState and GameState.state then
        GameState.state.paused = true
    end

    local audio = getAudio()
    if audio and audio.play then
        pcall(function() audio.play("ui_click", { pitch = 0.9, volume = 0.5 }) end)
    end
end

function PauseMenu.close()
    PauseMenu.state.isOpen = false
    PauseMenu.state.view = "main"
    PauseMenu.state.hoveredButton = nil

    if GameState and GameState.state then
        GameState.state.paused = false
    end

    local audio = getAudio()
    if audio and audio.play then
        pcall(function() audio.play("ui_click", { pitch = 1.1, volume = 0.5 }) end)
    end
end

function PauseMenu.toggle()
    if PauseMenu.isOpen() then
        PauseMenu.close()
    else
        PauseMenu.open()
    end
end

function PauseMenu.setView(viewName)
    PauseMenu.state.view = viewName
    PauseMenu.state.hoveredButton = nil

    local audio = getAudio()
    if audio and audio.play then
        pcall(function() audio.play("ui_click", { pitch = 1.05, volume = 0.5 }) end)
    end
end

function PauseMenu.handleEscape()
    if not PauseMenu.state.isOpen then return end

    if PauseMenu.state.view == "sublevels_detail" then
        PauseMenu.setView("sublevels")
    elseif PauseMenu.state.view ~= "main" then
        PauseMenu.setView("main")
    else
        PauseMenu.close()
    end
end

-- ============================================================================
-- ACTUALIZACIÓN
-- ============================================================================

function PauseMenu.update(dt)
    if not PauseMenu.state.isOpen then return end
    PauseMenu.state.fadeAlpha = math.min(1.0, PauseMenu.state.fadeAlpha + dt * 8.0)
end

-- ============================================================================
-- RENDERIZADO
-- ============================================================================

function PauseMenu.draw()
    if not PauseMenu.state.isOpen then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local alpha = PauseMenu.state.fadeAlpha

    -- Fondo oscurecido
    love.graphics.setColor(0, 0, 0, 0.65 * alpha)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if PauseMenu.state.view == "main" then
        PauseMenu.drawMainView(sw, sh, alpha)
    elseif PauseMenu.state.view == "audio_debug" then
        PauseMenu.drawAudioDebugView(sw, sh, alpha)
    elseif PauseMenu.state.view == "sublevels" then
        PauseMenu.drawSublevelsListView(sw, sh, alpha)
    elseif PauseMenu.state.view == "sublevels_detail" then
        PauseMenu.drawSublevelsDetailView(sw, sh, alpha)
    end
end

-- ─── VISTA PRINCIPAL ────────────────────────────────────────────────────────

function PauseMenu.drawMainView(sw, sh, alpha)
    local pw, ph = 380, 420
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)

    -- Sombra exterior
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle("fill", px + 6, py + 6, pw, ph, 10, 10)

    -- Fondo del panel
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95 * alpha)
    love.graphics.rectangle("fill", px, py, pw, ph, 10, 10)

    -- Borde sutil
    love.graphics.setColor(0.2, 0.45, 0.75, 0.55 * alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", px, py, pw, ph, 10, 10)

    -- Título
    love.graphics.setColor(0.9, 0.94, 1.0, alpha)
    love.graphics.printf("PAUSA", px, py + 24, pw, "center")

    -- Línea divisoria
    love.graphics.setColor(0.2, 0.4, 0.65, 0.4 * alpha)
    love.graphics.line(px + 40, py + 54, px + pw - 40, py + 54)

    -- Botones principales
    local mx, my = love.mouse.getPosition()
    local btnW = pw - 60
    local btnH = 42
    local startY = py + 70
    local gap = 12

    local buttons = {
        {
            id = "resume",
            label = "Reanudar",
            color = {0.2, 0.75, 0.45},
            enabled = true
        },
        {
            id = "options",
            label = "Opciones",
            color = {0.55, 0.6, 0.7},
            enabled = false,
            badge = "Próximamente"
        },
        {
            id = "audio_debug",
            label = "Depuración de Audio",
            color = {0.2, 0.65, 1.0},
            enabled = true
        },
        {
            id = "sublevels",
            label = "Submundos",
            color = {0.78, 0.42, 0.95},
            enabled = true
        },
        {
            id = "quit",
            label = "Salir del Juego",
            color = {0.9, 0.3, 0.3},
            enabled = true
        }
    }

    PauseMenu.state.hoveredButton = nil

    for i, btn in ipairs(buttons) do
        local bx = px + 30
        local by = startY + (i - 1) * (btnH + gap)

        local isHover = (mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH)
        if isHover and btn.enabled then
            PauseMenu.state.hoveredButton = btn.id
        end

        -- Fondo
        if not btn.enabled then
            love.graphics.setColor(0.08, 0.10, 0.14, 0.5 * alpha)
        elseif isHover then
            love.graphics.setColor(btn.color[1] * 0.22, btn.color[2] * 0.22, btn.color[3] * 0.22, 0.9 * alpha)
        else
            love.graphics.setColor(0.09, 0.12, 0.18, 0.75 * alpha)
        end
        love.graphics.rectangle("fill", bx, by, btnW, btnH, 6, 6)

        -- Borde
        if not btn.enabled then
            love.graphics.setColor(0.2, 0.24, 0.30, 0.4 * alpha)
        elseif isHover then
            love.graphics.setColor(btn.color[1], btn.color[2], btn.color[3], 0.9 * alpha)
        else
            love.graphics.setColor(btn.color[1] * 0.45, btn.color[2] * 0.45, btn.color[3] * 0.45, 0.45 * alpha)
        end
        love.graphics.setLineWidth(isHover and 1.8 or 1)
        love.graphics.rectangle("line", bx, by, btnW, btnH, 6, 6)

        -- Texto
        local textColor = btn.enabled and (isHover and {1, 1, 1} or {0.9, 0.93, 0.98}) or {0.45, 0.5, 0.55}
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)
        love.graphics.printf(btn.label, bx, by + 13, btnW, "center")

        -- Badge de Próximamente
        if btn.badge then
            local badgeW = 90
            local badgeH = 18
            local badgex = bx + btnW - badgeW - 10
            local badgey = by + (btnH - badgeH) / 2
            love.graphics.setColor(0.16, 0.18, 0.24, 0.65 * alpha)
            love.graphics.rectangle("fill", badgex, badgey, badgeW, badgeH, 4, 4)
            love.graphics.setColor(0.5, 0.55, 0.62, 0.75 * alpha)
            love.graphics.printf(btn.badge, badgex, badgey + 2, badgeW, "center")
        end
    end

    -- Pie de panel
    love.graphics.setColor(0.4, 0.48, 0.58, 0.65 * alpha)
    love.graphics.printf("[ESC] Reanudar", px, py + ph - 24, pw, "center")
end

-- ─── VISTA DE SUBMUNDOS (LISTA DE SISTEMAS) ─────────────────────────────────

function PauseMenu.drawSublevelsListView(sw, sh, alpha)
    local buttons = {}
    for _, world in ipairs(SUBWORLDS) do
        table.insert(buttons, {
            id = world.id,
            label = world.name,
            color = world.color or { 0.78, 0.42, 0.95 },
            enabled = true,
            world = world
        })
    end
    table.insert(buttons, {
        id = "back",
        label = "Volver",
        color = { 0.35, 0.55, 0.80 },
        enabled = true
    })

    local pw = 380
    local btnW = pw - 60
    local btnH = 42
    local gap = 12
    local totalBtnH = #buttons * btnH + (#buttons - 1) * gap
    local ph = 70 + totalBtnH + 34
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    local startY = py + 70

    -- Sombra exterior
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle("fill", px + 6, py + 6, pw, ph, 10, 10)

    -- Fondo del panel
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95 * alpha)
    love.graphics.rectangle("fill", px, py, pw, ph, 10, 10)

    -- Borde sutil
    love.graphics.setColor(0.55, 0.35, 0.9, 0.55 * alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", px, py, pw, ph, 10, 10)

    -- Título
    love.graphics.setColor(0.9, 0.94, 1.0, alpha)
    love.graphics.printf("SUBMUNDOS", px, py + 24, pw, "center")

    -- Línea divisoria
    love.graphics.setColor(0.4, 0.3, 0.65, 0.4 * alpha)
    love.graphics.line(px + 40, py + 54, px + pw - 40, py + 54)

    -- Botones
    local mx, my = love.mouse.getPosition()
    for i, btn in ipairs(buttons) do
        local bx = px + 30
        local by = startY + (i - 1) * (btnH + gap)
        local isHover = (mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH)

        if isHover then
            PauseMenu.state.hoveredButton = btn.id
        end

        -- Fondo del botón
        if isHover then
            love.graphics.setColor(btn.color[1] * 0.22, btn.color[2] * 0.22, btn.color[3] * 0.22, 0.9 * alpha)
        else
            love.graphics.setColor(0.09, 0.12, 0.18, 0.75 * alpha)
        end
        love.graphics.rectangle("fill", bx, by, btnW, btnH, 6, 6)

        -- Borde del botón
        if isHover then
            love.graphics.setColor(btn.color[1], btn.color[2], btn.color[3], 0.9 * alpha)
        else
            love.graphics.setColor(btn.color[1] * 0.45, btn.color[2] * 0.45, btn.color[3] * 0.45, 0.45 * alpha)
        end
        love.graphics.setLineWidth(isHover and 1.8 or 1)
        love.graphics.rectangle("line", bx, by, btnW, btnH, 6, 6)

        -- Texto
        local textColor = isHover and { 1, 1, 1 } or { 0.9, 0.93, 0.98 }
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)
        love.graphics.printf(btn.label, bx, by + 13, btnW, "center")
    end

    -- Pie de panel
    love.graphics.setColor(0.4, 0.48, 0.58, 0.65 * alpha)
    love.graphics.printf("[ESC] Volver", px, py + ph - 24, pw, "center")
end

-- ─── VISTA DE NIVELES DEL SUBMUNDO ──────────────────────────────────────────

function PauseMenu.drawSublevelsDetailView(sw, sh, alpha)
    local world = PauseMenu.state.selectedSubworld or SUBWORLDS[1]
    local levels = (world and world.levels) or {}
    local buttons = {}
    for _, lvl in ipairs(levels) do
        table.insert(buttons, {
            id = lvl.id,
            label = lvl.name,
            color = lvl.color or { 0.4, 0.7, 1.0 },
            enabled = true,
            level = lvl
        })
    end
    table.insert(buttons, {
        id = "back",
        label = "Volver",
        color = { 0.35, 0.55, 0.80 },
        enabled = true
    })

    local pw = 380
    local btnW = pw - 60
    local btnH = 42
    local gap = 12
    local totalBtnH = #buttons * btnH + (#buttons - 1) * gap
    local ph = 70 + totalBtnH + 34
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    local startY = py + 70

    -- Sombra exterior
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle("fill", px + 6, py + 6, pw, ph, 10, 10)

    -- Fondo del panel
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95 * alpha)
    love.graphics.rectangle("fill", px, py, pw, ph, 10, 10)

    -- Borde sutil
    love.graphics.setColor(0.55, 0.35, 0.9, 0.55 * alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", px, py, pw, ph, 10, 10)

    -- Encabezado con el nombre del submundo
    love.graphics.setColor(0.9, 0.94, 1.0, alpha)
    local title = string.upper(world and world.name or "SUBNIVELES")
    love.graphics.printf(title, px, py + 24, pw, "center")

    -- Línea divisoria
    love.graphics.setColor(0.4, 0.3, 0.65, 0.4 * alpha)
    love.graphics.line(px + 40, py + 54, px + pw - 40, py + 54)

    -- Botones
    local mx, my = love.mouse.getPosition()
    for i, btn in ipairs(buttons) do
        local bx = px + 30
        local by = startY + (i - 1) * (btnH + gap)
        local isHover = (mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH)

        if isHover then
            PauseMenu.state.hoveredButton = btn.id
        end

        -- Fondo del botón
        if isHover then
            love.graphics.setColor(btn.color[1] * 0.22, btn.color[2] * 0.22, btn.color[3] * 0.22, 0.9 * alpha)
        else
            love.graphics.setColor(0.09, 0.12, 0.18, 0.75 * alpha)
        end
        love.graphics.rectangle("fill", bx, by, btnW, btnH, 6, 6)

        -- Borde del botón
        if isHover then
            love.graphics.setColor(btn.color[1], btn.color[2], btn.color[3], 0.9 * alpha)
        else
            love.graphics.setColor(btn.color[1] * 0.45, btn.color[2] * 0.45, btn.color[3] * 0.45, 0.45 * alpha)
        end
        love.graphics.setLineWidth(isHover and 1.8 or 1)
        love.graphics.rectangle("line", bx, by, btnW, btnH, 6, 6)

        -- Texto
        local textColor = isHover and { 1, 1, 1 } or { 0.9, 0.93, 0.98 }
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)
        love.graphics.printf(btn.label, bx, by + 13, btnW, "center")
    end

    -- Pie de panel
    love.graphics.setColor(0.4, 0.48, 0.58, 0.65 * alpha)
    love.graphics.printf("[ESC] Volver", px, py + ph - 24, pw, "center")
end

-- ─── VISTA DE DEPURACIÓN DE AUDIO ───────────────────────────────────────────

function PauseMenu.drawAudioDebugView(sw, sh, alpha)
    local pw, ph = 460, 560
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)

    local audio = getAudio()
    local currentTrack = (audio and audio.state and audio.state.currentMusicName) or "Ninguna"
    local musicVolume = (audio and audio.config and audio.config.musicVolume) or 1.0

    -- Sombra y fondo
    love.graphics.setColor(0, 0, 0, 0.5 * alpha)
    love.graphics.rectangle("fill", px + 6, py + 6, pw, ph, 10, 10)

    love.graphics.setColor(0.06, 0.08, 0.12, 0.96 * alpha)
    love.graphics.rectangle("fill", px, py, pw, ph, 10, 10)

    love.graphics.setColor(0.2, 0.55, 0.9, 0.6 * alpha)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", px, py, pw, ph, 10, 10)

    -- Encabezado
    love.graphics.setColor(0.9, 0.94, 1.0, alpha)
    love.graphics.printf("Depuración de Audio", px, py + 18, pw, "center")

    -- Línea divisoria
    love.graphics.setColor(0.2, 0.4, 0.65, 0.4 * alpha)
    love.graphics.line(px + 30, py + 44, px + pw - 30, py + 44)

    -- Indicador de Pista Actual
    local statusY = py + 52
    local isPlaying = (currentTrack ~= "Ninguna")

    love.graphics.setColor(0.08, 0.11, 0.16, 0.8 * alpha)
    love.graphics.rectangle("fill", px + 25, statusY, pw - 50, 32, 6, 6)
    love.graphics.setColor(0.2, 0.4, 0.6, 0.45 * alpha)
    love.graphics.rectangle("line", px + 25, statusY, pw - 50, 32, 6, 6)

    love.graphics.setColor(isPlaying and 0.2 or 0.6, isPlaying and 0.85 or 0.3, isPlaying and 0.4 or 0.3, alpha)
    love.graphics.circle("fill", px + 42, statusY + 16, 5)

    local currentTrackName = "Ninguna"
    if currentTrack ~= "Ninguna" then
        for _, trk in ipairs(SOUNDTRACKS) do
            if trk.id == currentTrack or (trk.alias and trk.alias == currentTrack) then
                currentTrackName = trk.name
                break
            end
        end
        if currentTrackName == "Ninguna" then
            currentTrackName = currentTrack
        end
    end

    love.graphics.setColor(0.85, 0.9, 0.98, alpha)
    love.graphics.printf("Pista actual: " .. currentTrackName, px + 58, statusY + 9, pw - 90, "left")

    -- Lista de Soundtracks
    local mx, my = love.mouse.getPosition()
    local listY = statusY + 38
    local itemH = 34
    local gap = 5
    local iw = pw - 50
    local ix = px + 25

    for i, track in ipairs(SOUNDTRACKS) do
        local iy = listY + (i - 1) * (itemH + gap)
        local isCurrent = (currentTrack == track.id or (track.alias and currentTrack == track.alias))
        local isHover = (mx >= ix and mx <= ix + iw and my >= iy and my <= iy + itemH)

        -- Fondo del elemento
        if isCurrent then
            love.graphics.setColor(0.10, 0.20, 0.30, 0.85 * alpha)
        elseif isHover then
            love.graphics.setColor(0.09, 0.14, 0.20, 0.8 * alpha)
        else
            love.graphics.setColor(0.07, 0.10, 0.15, 0.6 * alpha)
        end
        love.graphics.rectangle("fill", ix, iy, iw, itemH, 6, 6)

        -- Borde
        if isCurrent then
            love.graphics.setColor(0.3, 0.75, 1.0, 0.85 * alpha)
            love.graphics.setLineWidth(1.6)
        elseif isHover then
            love.graphics.setColor(0.25, 0.55, 0.80, 0.7 * alpha)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(0.18, 0.24, 0.32, 0.4 * alpha)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", ix, iy, iw, itemH, 6, 6)

        -- Nombre
        love.graphics.setColor(isCurrent and 0.4 or 0.95, isCurrent and 0.9 or 0.95, isCurrent and 1.0 or 0.95, alpha)
        love.graphics.printf(track.name, ix + 16, iy + 9, iw - 120, "left")

        -- Botón a la derecha
        local btnW, btnH = 90, 24
        local btnX = ix + iw - btnW - 8
        local btnY = iy + (itemH - btnH) / 2
        local isBtnHover = (mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH)

        if isCurrent then
            love.graphics.setColor(0.15, 0.5, 0.28, 0.85 * alpha)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
            love.graphics.setColor(0.4, 0.9, 0.55, alpha)
            love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 4, 4)
            love.graphics.printf("Sonando", btnX, btnY + 5, btnW, "center")
        else
            love.graphics.setColor(isBtnHover and 0.25 or 0.12, isBtnHover and 0.55 or 0.30, isBtnHover and 0.85 or 0.55, 0.8 * alpha)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
            love.graphics.setColor(0.3, 0.7, 0.95, alpha)
            love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 4, 4)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.printf("Reproducir", btnX, btnY + 5, btnW, "center")
        end
    end

    -- Controles inferiores: Detener y Volumen
    local ctrlY = listY + #SOUNDTRACKS * (itemH + gap) + 8
    local ctrlW = pw - 50
    local ctrlX = px + 25

    -- Botón Detener
    local stopW, stopH = 100, 30
    local isStopHover = (mx >= ctrlX and mx <= ctrlX + stopW and my >= ctrlY and my <= ctrlY + stopH)
    love.graphics.setColor(isStopHover and 0.7 or 0.45, 0.18, 0.18, 0.85 * alpha)
    love.graphics.rectangle("fill", ctrlX, ctrlY, stopW, stopH, 4, 4)
    love.graphics.setColor(1, 0.4, 0.4, alpha)
    love.graphics.rectangle("line", ctrlX, ctrlY, stopW, stopH, 4, 4)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("Detener", ctrlX, ctrlY + 7, stopW, "center")

    -- Control de Volumen (+ / -)
    local volBoxX = ctrlX + stopW + 12
    local volBoxW = ctrlW - stopW - 12
    love.graphics.setColor(0.08, 0.11, 0.16, 0.8 * alpha)
    love.graphics.rectangle("fill", volBoxX, ctrlY, volBoxW, stopH, 4, 4)
    love.graphics.setColor(0.2, 0.35, 0.5, 0.5 * alpha)
    love.graphics.rectangle("line", volBoxX, ctrlY, volBoxW, stopH, 4, 4)

    -- Botón [-]
    local btnMinusX = volBoxX + 4
    local btnMinusW = 24
    local isMinusHover = (mx >= btnMinusX and mx <= btnMinusX + btnMinusW and my >= ctrlY + 3 and my <= ctrlY + 27)
    love.graphics.setColor(isMinusHover and 0.25 or 0.15, 0.35, 0.5, 0.9 * alpha)
    love.graphics.rectangle("fill", btnMinusX, ctrlY + 3, btnMinusW, 24, 3, 3)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("-", btnMinusX, ctrlY + 5, btnMinusW, "center")

    -- Porcentaje
    local pct = math.floor(musicVolume * 100 + 0.5)
    love.graphics.setColor(0.9, 0.93, 0.98, alpha)
    love.graphics.printf(string.format("Volumen: %d%%", pct), btnMinusX + btnMinusW, ctrlY + 7, volBoxW - 60, "center")

    -- Botón [+]
    local btnPlusX = volBoxX + volBoxW - 28
    local btnPlusW = 24
    local isPlusHover = (mx >= btnPlusX and mx <= btnPlusX + btnPlusW and my >= ctrlY + 3 and my <= ctrlY + 27)
    love.graphics.setColor(isPlusHover and 0.25 or 0.15, 0.35, 0.5, 0.9 * alpha)
    love.graphics.rectangle("fill", btnPlusX, ctrlY + 3, btnPlusW, 24, 3, 3)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("+", btnPlusX, ctrlY + 5, btnPlusW, "center")

    -- Botón Volver
    local backY = py + ph - 42
    local isBackHover = (mx >= ctrlX and mx <= ctrlX + ctrlW and my >= backY and my <= backY + 30)
    love.graphics.setColor(isBackHover and 0.16 or 0.10, isBackHover and 0.28 or 0.18, isBackHover and 0.44 or 0.28, 0.8 * alpha)
    love.graphics.rectangle("fill", ctrlX, backY, ctrlW, 30, 4, 4)
    love.graphics.setColor(0.3, 0.55, 0.8, alpha)
    love.graphics.rectangle("line", ctrlX, backY, ctrlW, 30, 4, 4)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("Volver", ctrlX, backY + 7, ctrlW, "center")
end

-- ============================================================================
-- ENTRADA DE RATÓN
-- ============================================================================

function PauseMenu.mousepressed(x, y, button)
    if not PauseMenu.state.isOpen or button ~= 1 then return false end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local audio = getAudio()

    if PauseMenu.state.view == "main" then
        local pw, ph = 380, 420
        local px = math.floor((sw - pw) / 2)
        local py = math.floor((sh - ph) / 2)
        local btnW = pw - 60
        local btnH = 42
        local startY = py + 70
        local gap = 12

        -- 1. Reanudar
        local b1y = startY
        if x >= px + 30 and x <= px + 30 + btnW and y >= b1y and y <= b1y + btnH then
            PauseMenu.close()
            return true
        end

        -- 2. Opciones (No configurado por ahora)
        local b2y = startY + (btnH + gap)
        if x >= px + 30 and x <= px + 30 + btnW and y >= b2y and y <= b2y + btnH then
            if audio and audio.play then pcall(function() audio.play("ui_click", { pitch = 0.7, volume = 0.3 }) end) end
            return true
        end

        -- 3. Depuración de Audio
        local b3y = startY + 2 * (btnH + gap)
        if x >= px + 30 and x <= px + 30 + btnW and y >= b3y and y <= b3y + btnH then
            PauseMenu.setView("audio_debug")
            return true
        end

        -- 4. Submundos
        local b4y = startY + 3 * (btnH + gap)
        if x >= px + 30 and x <= px + 30 + btnW and y >= b4y and y <= b4y + btnH then
            PauseMenu.setView("sublevels")
            return true
        end

        -- 5. Salir del Juego
        local b5y = startY + 4 * (btnH + gap)
        if x >= px + 30 and x <= px + 30 + btnW and y >= b5y and y <= b5y + btnH then
            love.event.quit()
            return true
        end

    elseif PauseMenu.state.view == "audio_debug" then
        local pw, ph = 460, 560
        local px = math.floor((sw - pw) / 2)
        local py = math.floor((sh - ph) / 2)
        local statusY = py + 52
        local listY = statusY + 38
        local itemH = 34
        local gap = 5
        local iw = pw - 50
        local ix = px + 25

        -- Clic en pistas de la lista
        for i, track in ipairs(SOUNDTRACKS) do
            local iy = listY + (i - 1) * (itemH + gap)
            if x >= ix and x <= ix + iw and y >= iy and y <= iy + itemH then
                if audio and audio.playMusic then
                    local src = audio.playMusic(track.id, { loop = true, volume = 0.45 })
                    if src and audio.play then
                        pcall(function() audio.play("ui_click", { pitch = 1.15, volume = 0.5 }) end)
                    end
                end
                return true
            end
        end

        local ctrlY = listY + #SOUNDTRACKS * (itemH + gap) + 8
        local ctrlW = pw - 50
        local ctrlX = px + 25
        local stopW, stopH = 100, 30

        -- Clic en Detener
        if x >= ctrlX and x <= ctrlX + stopW and y >= ctrlY and y <= ctrlY + stopH then
            if audio and audio.stopMusic then
                audio.stopMusic()
                if audio.play then pcall(function() audio.play("ui_click", { pitch = 0.8, volume = 0.5 }) end) end
            end
            return true
        end

        -- Controles de volumen
        local volBoxX = ctrlX + stopW + 12
        local volBoxW = ctrlW - stopW - 12

        -- Botón [-]
        local btnMinusX = volBoxX + 4
        local btnMinusW = 24
        if x >= btnMinusX and x <= btnMinusX + btnMinusW and y >= ctrlY + 3 and y <= ctrlY + 27 then
            if audio and audio.setMusicVolume then
                local currentVol = audio.config.musicVolume or 1.0
                audio.setMusicVolume(math.max(0, currentVol - 0.1))
                if audio.play then pcall(function() audio.play("ui_click", { pitch = 0.95, volume = 0.4 }) end) end
            end
            return true
        end

        -- Botón [+]
        local btnPlusX = volBoxX + volBoxW - 28
        local btnPlusW = 24
        if x >= btnPlusX and x <= btnPlusX + btnPlusW and y >= ctrlY + 3 and y <= ctrlY + 27 then
            if audio and audio.setMusicVolume then
                local currentVol = audio.config.musicVolume or 1.0
                audio.setMusicVolume(math.min(1.0, currentVol + 0.1))
                if audio.play then pcall(function() audio.play("ui_click", { pitch = 1.1, volume = 0.4 }) end) end
            end
            return true
        end

        -- Botón Volver
        local backY = py + ph - 42
        if x >= ctrlX and x <= ctrlX + ctrlW and y >= backY and y <= backY + 30 then
            PauseMenu.setView("main")
            return true
        end

    elseif PauseMenu.state.view == "sublevels" then
        local buttons = {}
        for _, world in ipairs(SUBWORLDS) do
            table.insert(buttons, {
                id = world.id,
                action = function()
                    PauseMenu.state.selectedSubworld = world
                    PauseMenu.setView("sublevels_detail")
                end
            })
        end
        table.insert(buttons, {
            id = "back",
            action = function()
                PauseMenu.setView("main")
            end
        })

        local pw = 380
        local btnW = pw - 60
        local btnH = 42
        local gap = 12
        local totalBtnH = #buttons * btnH + (#buttons - 1) * gap
        local ph = 70 + totalBtnH + 34
        local px = math.floor((sw - pw) / 2)
        local py = math.floor((sh - ph) / 2)
        local startY = py + 70

        for i, btn in ipairs(buttons) do
            local bx = px + 30
            local by = startY + (i - 1) * (btnH + gap)
            if x >= bx and x <= bx + btnW and y >= by and y <= by + btnH then
                btn.action()
                return true
            end
        end

    elseif PauseMenu.state.view == "sublevels_detail" then
        local world = PauseMenu.state.selectedSubworld or SUBWORLDS[1]
        local levels = (world and world.levels) or {}
        local buttons = {}
        for _, level in ipairs(levels) do
            table.insert(buttons, {
                id = level.id,
                action = function()
                    launchSublevel(level, world)
                end
            })
        end
        table.insert(buttons, {
            id = "back",
            action = function()
                PauseMenu.setView("sublevels")
            end
        })

        local pw = 380
        local btnW = pw - 60
        local btnH = 42
        local gap = 12
        local totalBtnH = #buttons * btnH + (#buttons - 1) * gap
        local ph = 70 + totalBtnH + 34
        local px = math.floor((sw - pw) / 2)
        local py = math.floor((sh - ph) / 2)
        local startY = py + 70

        for i, btn in ipairs(buttons) do
            local bx = px + 30
            local by = startY + (i - 1) * (btnH + gap)
            if x >= bx and x <= bx + btnW and y >= by and y <= by + btnH then
                btn.action()
                return true
            end
        end
    end

    return true
end

function PauseMenu.mousereleased(x, y, button)
    if PauseMenu.state.isOpen then
        return true
    end
    return false
end

-- ============================================================================
-- ENTRADA DE TECLADO
-- ============================================================================

function PauseMenu.keypressed(key)
    if not PauseMenu.state.isOpen then return false end

    if key == "escape" then
        PauseMenu.handleEscape()
        return true
    elseif key == "p" then
        PauseMenu.close()
        return true
    end

    return true
end

return PauseMenu
