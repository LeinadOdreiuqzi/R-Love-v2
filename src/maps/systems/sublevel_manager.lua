-- src/maps/systems/sublevel_manager.lua
-- Gestor de subniveles: estructura y esqueleto para reutilizar el generador

local SubLevelManager = {}

local Map = require 'src.maps.map'
local MapGenerator = require 'src.maps.systems.map_generator'
local SeedSystem = require 'src.utils.seed_system'

-- Opcional: usar PhaseSystem para límites temporales
-- No usar PhaseSystem en subniveles: límites propios del subnivel
local PhaseSystem = nil

-- Estado interno
SubLevelManager.state = {
    active = false,
    stack = {}, -- permitir subniveles anidados
    current = nil,
}

-- Plantillas mínimas de tipos de subnivel (para futura personalización)
SubLevelManager.Types = {
    Generic = 'GENERIC',
    Station = 'STATION',
    Ruins = 'RUINS',
}

-- Crear configuración determinista de subnivel basada en la seed y un contexto
function SubLevelManager.createConfig(opts)
    opts = opts or {}
    local parentSeed = opts.parentSeed or Map.seed
    local key = tostring(opts.type or SubLevelManager.Types.Generic)
    local context = string.format("%s:%s:%s", tostring(opts.context or "base"), tostring(opts.cx or 0), tostring(opts.cy or 0))

    -- Semilla numérica determinista a partir de cadena compuesta
    local numericSeed = SeedSystem.toNumeric(tostring(parentSeed) .. '|' .. key .. '|' .. context)

    return {
        type = key,
        parentSeed = parentSeed,
        numericSeed = numericSeed,
        -- Tamaño en celdas de chunk (mapa limitado)
        size = {
            width = opts.width or 12,
            height = opts.height or 12,
        },
        -- Punto de entrada relativo (para posicionar jugador/cámara)
        entry = {
            x = opts.entryX or 0,
            y = opts.entryY or 0,
        },
        -- Metadatos libres para especializaciones futuras
        meta = opts.meta or {},
    }
end

local function pushPreviousContext()
    local prev = {
        seed = Map.seed,
        numericSeed = Map.numericSeed,
        player = nil,
        camera = nil,
    }
    if _G.player then
        prev.player = {
            x = _G.player.x, y = _G.player.y,
            dx = _G.player.dx, dy = _G.player.dy,
            rotation = _G.player.rotation,
        }
    end
    if _G.camera then
        prev.camera = { x = _G.camera.x, y = _G.camera.y, zoom = _G.camera.zoom }
    end
    table.insert(SubLevelManager.state.stack, prev)
end

local function computeTemporaryBoundsFromSize(cfg)
    -- Calcular límites simétricos en torno al origen usando stride alineado
    local stride = nil
    -- Obtener stride desde PhaseSystem si está disponible, si no, calcular desde Map
    if PhaseSystem and PhaseSystem.config and PhaseSystem.config.chunkAlignment then
        stride = PhaseSystem.config.chunkAlignment.chunkStride or nil
    end
    if not stride then
        local MapConfig = require 'src.maps.config.map_config'
        local sizePixels = (MapConfig.chunk.size or 64) * (MapConfig.chunk.tileSize or 32)
        local spacing = MapConfig.chunk.spacing or 0
        stride = (sizePixels + spacing) * (MapConfig.chunk.worldScale or 1.0)
    end

    local w = math.max(1, (cfg.size and cfg.size.width) or 12)
    local h = math.max(1, (cfg.size and cfg.size.height) or 12)
    local halfW = (w * stride) / 2
    local halfH = (h * stride) / 2

    return {
        minX = -halfW,
        maxX =  halfW,
        minY = -halfH,
        maxY =  halfH,
        size = math.max(w * stride, h * stride),
        fibValue = 1, -- marcador (no afecta)
    }
end

-- Entrar a un subnivel: habilita modo subnivel en el generador y regenera el mapa
function SubLevelManager.enter(cfg)
    if SubLevelManager.state.active then
        -- Soportar anidación: apilar contexto actual
        pushPreviousContext()
    else
        -- Primer subnivel: apilar contexto principal
        pushPreviousContext()
        SubLevelManager.state.active = true
    end

    SubLevelManager.state.current = cfg

    -- No regenerar el mapa principal ni activar modo global de subnivel
    -- La escena del subnivel gestionará su propia instancia de mundo

    -- Reposicionar jugador y cámara al punto de entrada
    if _G.player then
        _G.player.x = cfg.entry.x or 0
        _G.player.y = cfg.entry.y or 0
        _G.player.dx = 0; _G.player.dy = 0
    end
    if _G.camera then
        _G.camera:setPosition(cfg.entry.x or 0, cfg.entry.y or 0)
    end
end

-- Salir del subnivel: restaurar contexto previo
function SubLevelManager.exit()
    if not SubLevelManager.state.active then return end
    local prev = table.remove(SubLevelManager.state.stack)
    SubLevelManager.state.current = nil

    -- No tocar el mapa principal al salir; sólo restaurar posición

    -- Restaurar jugador y cámara
    if prev and prev.player and _G.player then
        _G.player.x = prev.player.x; _G.player.y = prev.player.y
        _G.player.dx = prev.player.dx; _G.player.dy = prev.player.dy
        _G.player.rotation = prev.player.rotation
    end
    if prev and prev.camera and _G.camera then
        _G.camera:setPosition(prev.camera.x, prev.camera.y)
        _G.camera.zoom = prev.camera.zoom or _G.camera.zoom
    end

    -- Restaurar semilla del mapa para evitar fugas de estado
    if prev and Map then
        if prev.seed ~= nil then Map.seed = prev.seed end
        if prev.numericSeed ~= nil then Map.numericSeed = prev.numericSeed end
    end

    -- Si la pila quedó vacía, desactivar estado
    if #SubLevelManager.state.stack == 0 then
        SubLevelManager.state.active = false
    end
end

-- Información de estado (para HUD o debug)
function SubLevelManager.getStatus()
    local cur = SubLevelManager.state.current
    return {
        active = SubLevelManager.state.active,
        depth = #SubLevelManager.state.stack,
        current = cur and {
            type = cur.type,
            size = cur.size,
            numericSeed = cur.numericSeed,
        } or nil
    }
end

return SubLevelManager