local MenuCamera = require 'src.ui.menu_camera'
-- src/ui/pause_menu.lua
-- Menú de Pausa modular con opciones estándar y panel de depuración de audio

local PauseMenu = {
    state = {
        isOpen = false,
        view = "main",
        selectedSubworld = nil,
        focus = 1
    }
}

local Theme = require 'src.ui.menu_theme'
local Glitch = require 'src.ui.text_glitch'
local labelSignal = {}
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
        id = "loot_debug",
        name = "Botín (Laboratorio)",
        color = { 0.35, 0.85, 0.85 },
        levels = {
            { id = "loot_lab", name = "Contenedores con llave", tier = 0, width = 8, height = 8 }
        }
    },
    {
        id = "ships_debug",
        name = "Naves y Nodrizas (Hangar)",
        color = { 0.82, 0.35, 1.00 },
        levels = {
            { id = "ships_gallery_all", name = "Catálogo Completo (10 Clases)", tier = "debug_ships", width = 16, height = 16, color = { 0.82, 0.35, 1.00 } }
        }
    },
    {
        id = "nebulae_debug",
        name = "Nebulosas (Laboratorio)",
        color = { 0.85, 0.45, 0.95 },
        levels = {
            { id = "nebulae_lab_sandbox", name = "Banco de Pruebas", tier = "debug_nebulae", width = 16, height = 16, color = { 0.85, 0.45, 0.95 } }
        }
    },
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
    if World.get('frontierEncounter') then return end
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
            PauseMenu.close()
            local scene = SubLevelScene:new(cfg)
            local LoadingScreen = require 'src.ui.loading_screen'
            local targetSeed = string.format("%08X", cfg.numericSeed or 0)
            if #targetSeed < 10 then
                targetSeed = targetSeed .. string.sub(currentSeed or "99", 1, 10 - #targetSeed)
            end
            LoadingScreen.startWarpJump({
                seed = targetSeed,
                title = "SALTO HIPERESPACIAL",
                destination = (cfg.meta and cfg.meta.name) or "Submundo",
                duration = 2.0,
                onMidpoint = function()
                    stateManager:push(scene, { suspendUnderlying = true, fadeDuration = 0 })
                end
            })
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
    MenuCamera.open('pause')
    PauseMenu.state.isOpen = true
    PauseMenu.state.view = "main"
    PauseMenu.state.remembered = {}
    PauseMenu.state.focus = 1
    labelSignal.text = nil
    PauseMenu.state.elapsed = 0
    PauseMenu.state.echo = nil
    PauseMenu.state.mx, PauseMenu.state.my = love.mouse.getPosition()

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
    local previous = PauseMenu.state.view
    local remembered = PauseMenu.state.remembered
    remembered[previous] = PauseMenu.state.focus
    PauseMenu.state.view = viewName
    PauseMenu.state.focus = (viewName == "main" or previous == "sublevels_detail") and remembered[viewName] or 1
    labelSignal.text = nil
    PauseMenu.state.elapsed = 0
    PauseMenu.state.echo = nil

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
-- Rows describe both the visible menu and its input targets.
local state = PauseMenu.state
local titleFont, rowFont, smallFont

local function rowsForView()
    local rows = {}
    local function add(id, label, detail, tint, value, disabled)
        rows[#rows+1] = {id=id, label=label, detail=detail, tint=tint, value=value, disabled=disabled}
    end
    local title
    if state.view == "main" then
        title = "PAUSA"
        add("resume", "Reanudar")
        add("options", "Opciones")
        local locked = World.get('frontierEncounter')
        add("sublevels", "Submundos", locked and "Combate activo", nil, nil, locked)
        add("audio_debug", "Depuración de audio")
        add("quit", "Salir del juego")
    elseif state.view == "options" then
        title = "OPCIONES"
        local reduced = require('src.ui.loading_screen').config.reducedEffects
        add("motion", "Movimiento reducido", reduced and "Activado" or "Desactivado")
    elseif state.view == "audio_debug" then
        title = "AUDIO"
        local audio = getAudio()
        local current = audio and audio.state and audio.state.currentMusicName
        for _, track in ipairs(SOUNDTRACKS) do
            local playing = current and (current == track.id or current == track.alias)
            add("track", track.name, playing and "Sonando" or track.alias, nil, track.id)
        end
        add("stop", "Detener música")
        local volume = audio and audio.config and audio.config.musicVolume or 1
        local percent = string.format("%d%%", math.floor(volume*100+.5))
        add("volume", "Bajar volumen", percent, nil, -.1)
        add("volume", "Subir volumen", percent, nil, .1)
    elseif state.view == "sublevels" then
        title = "SUBMUNDOS"
        for _, world in ipairs(SUBWORLDS) do
            add("world", world.name, nil, world.color, world)
        end
    else
        local world = state.selectedSubworld
        title = world.name
        for _, level in ipairs(world.levels) do
            add("level", level.name, nil, level.color or world.color, level)
        end
    end
    if state.view ~= "main" then add("back", "Volver") end
    return rows, title
end

local function activate(row)
    if not row or row.disabled then return end
    local id = row.id
    if id == "resume" then PauseMenu.close()
    elseif id == "quit" then love.event.quit()
    elseif id == "back" then PauseMenu.handleEscape()
    elseif id == "world" then
        state.selectedSubworld = row.value
        PauseMenu.setView("sublevels_detail")
    elseif id == "level" then launchSublevel(row.value, state.selectedSubworld)
    elseif id == "motion" then
        local config = require('src.ui.loading_screen').config
        config.reducedEffects = not config.reducedEffects
    elseif id == "track" or id == "stop" or id == "volume" then
        local audio = getAudio()
        if not audio then return end
        if id == "track" and audio.playMusic then audio.playMusic(row.value, {loop=true, volume=.45})
        elseif id == "stop" and audio.stopMusic then audio.stopMusic()
        elseif id == "volume" and audio.setMusicVolume then
            audio.setMusicVolume(math.max(0, math.min(1, (audio.config.musicVolume or 1)+row.value)))
        end
    else PauseMenu.setView(id) end
end

local function layout(count)
    local sw, sh = love.graphics.getDimensions()
    local scale = math.min(1, sw/360, sh/450)
    sw, sh = sw/scale, sh/scale
    local w = math.min(1060, sw-32)
    local wide = w >= 700
    local header = wide and 60 or 114
    local step = math.min(54, math.floor((sh-header-80)/count))
    local h = math.max(wide and 360 or 0, header+count*step+44)
    local x,y = math.floor((sw-w)/2),math.floor((sh-h)/2)
    local left = x+(wide and math.floor(w*.51) or 10)
    return x,y,w,h,step,scale,left,y+header
end

local function hit(rows, mx, my)
    local x,y,w,h,step,scale,left,top = layout(#rows)
    mx, my = mx/scale, my/scale
    local dy = my-top
    local i = math.floor(dy/step)+1
    if mx >= left and mx < x+w-12 and dy%step < step-3 and rows[i] then return i end
end

local persistence = .08

local function focus(i)
    if i and i ~= state.focus then
        state.echo, state.echoAge = state.focus, 0
        state.focus = i
    end
end

function PauseMenu.update(dt)
    if not state.isOpen then return end
    state.elapsed = state.elapsed + dt
    if state.echo then
        state.echoAge = state.echoAge + dt
        if state.echoAge >= persistence then state.echo = nil end
    end
    local mx,my = love.mouse.getPosition()
    if mx ~= state.mx or my ~= state.my then
        local rows = rowsForView()
        local i = hit(rows, mx,my)
        if i and not rows[i].disabled then focus(i) end
        state.mx, state.my = mx,my
    end
end

-- Centerlines for the beveled, slanted PAUSA wordmark in the native UI.
local letters = {
    P = {{0,28, 0,2, 21,2, 25,6, 25,12, 21,16, 1,16}},
    A = {{0,28, 7,2, 20,2, 27,28}, {4,18, 23,18}},
    U = {{0,1, 0,21, 5,27, 21,27, 26,21, 26,1}},
    S = {{26,2, 5,2, 1,6, 1,12, 5,15, 21,15, 25,18, 25,23, 21,27, 0,27}}
}

local function drawTitle(title,x,y,scale)
    local g = love.graphics
    if title ~= "PAUSA" then
        g.print(title,x,y,0,scale,scale,0,0,-.12)
        return
    end
    g.push('all')
    g.translate(x+7,y+6)
    g.scale(scale)
    g.shear(-.16,0)
    g.setLineWidth(5)
    g.setLineJoin('bevel')
    for letter in title:gmatch('.') do
        for _,stroke in ipairs(letters[letter]) do g.line(stroke) end
        g.translate(34,0)
    end
    g.pop()
end

local function drawPause()
    local g = love.graphics
    titleFont = titleFont or g.newFont(37)
    rowFont = rowFont or g.newFont(16)
    smallFont = smallFont or g.newFont(12)
    local rows,title = rowsForView()
    local x,y,w,h,step,uiScale,left,top = layout(#rows)
    local reduced = require('src.ui.loading_screen').config.reducedEffects
    local echo = (not reduced and state.echo) and math.max(0,1-state.echoAge/persistence) or 0
    local wide = w >= 700
    g.push('all')
    g.origin()
    g.setColor(.012,.027,.029,.72)
    g.rectangle('fill',0,0,g.getDimensions())
    g.scale(uiScale)

    local fieldW = wide and left-x-30 or w
    local size = wide and math.min(fieldW*1.02,h*.96) or 85
    local gx = wide and x+(fieldW-size)/2 or x+w-size
    local gy = wide and y+h-size+14 or y-4
    local phase = reduced and .25 or state.elapsed*.055+(state.focus-1)*.065
    if echo > 0 then phase = phase+(state.echo-state.focus)*.065*echo end
    Theme.project(gx,gy,size,size,phase,true,.90)

    local titleWidth = wide and fieldW-12 or w-100
    local baseWidth = title == "PAUSA" and 176 or titleFont:getWidth(title)
    local scale = math.min(titleWidth/baseWidth,wide and 3.1 or 1.9)
    local tx,ty = x+7,y+2
    g.setFont(titleFont)
    Theme.ink(Theme.paper)
    drawTitle(title,tx,ty,scale)
    local right = x+w-12
    for i,row in ipairs(rows) do
        local ry = top+(i-1)*step
        local selected = state.focus == i and not row.disabled
        local barH = step-4
        local font = step < 32 and smallFont or rowFont
        g.setFont(font)
        local detailWidth = row.detail and smallFont:getWidth(row.detail)+12 or 0
        local available = right-left-58-detailWidth
        local fit = math.min(selected and 1.35 or 1, available/font:getWidth(row.label),(barH-2)/font:getHeight())
        local labelX = left+16
        local labelY = ry+(barH-font:getHeight()*fit)/2
        if selected or (state.echo == i and echo > 0) then
            local glow = selected and 1 or .12*echo
            local center = ry+barH*.5
            Theme.ink(Theme.focus,glow)
            g.polygon('fill',left-14,center-5,left-3,center,left-17,center+5)
        end
        Theme.ink(selected and Theme.focus or row.disabled and Theme.muted or Theme.paper)
        if selected then
            Glitch.print(labelSignal,row.label,labelX,labelY,fit)
        else
            g.print(row.label,labelX,labelY,0,fit,fit)
        end
        if row.tint then
            Theme.ink(row.tint)
            g.rectangle('fill',right-44,ry+barH/2-4,9,8)
        end
        if row.detail then
            g.setFont(smallFont)
            Theme.ink(selected and Theme.focus or Theme.muted)
            g.printf(row.detail,left+10,ry+(barH-smallFont:getHeight())/2,right-left-46,'right')
        end
    end
    g.pop()
end

function PauseMenu.draw()
    if state.isOpen then MenuCamera.draw('pause',drawPause) end
end

function PauseMenu.mousepressed(x,y,button)
    if not state.isOpen then return false end
    if button == 1 then
        local rows = rowsForView()
        local i = hit(rows,x,y)
        if i and not rows[i].disabled then focus(i); activate(rows[i]) end
    end
    return true
end

function PauseMenu.mousereleased()
    return state.isOpen
end

function PauseMenu.keypressed(key)
    if not state.isOpen then return false end
    local rows = rowsForView()
    if key == "escape" then PauseMenu.handleEscape()
    elseif key == "p" then PauseMenu.close()
    elseif key == "return" or key == "kpenter" or key == "space" then activate(rows[state.focus])
    elseif key == "up" or key == "down" then
        local delta = key == "up" and -1 or 1
        local i = state.focus
        repeat i = (i-1+delta)%#rows+1 until not rows[i].disabled
        focus(i)
    end
    return true
end

return PauseMenu
