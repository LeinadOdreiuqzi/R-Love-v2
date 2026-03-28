-- src/states/sublevel_scene.lua
-- Escena de Subnivel: mapa limitado reutilizando el generador principal

local StateBase = require 'src.states.state_base'
local SubLevelManager = require 'src.maps.systems.sublevel_manager'
local Map = require 'src.maps.map'
local MapConfig = require 'src.maps.config.map_config'
local SublevelWorld = require 'src.sublevels.sublevel_world'
local HUD = require 'src.ui.hud'
local ChunkManager = require 'src.maps.chunk_manager'
local OptimizedRenderer = require 'src.maps.optimized_renderer'
local WorldItems = require 'src.item_systems.world_items'
local DebugGrid = require 'src.sublevels.debug_grid'
local SublevelSpawns = require 'src.sublevels.spawns'
local SublevelDecor = require 'src.sublevels.decor'
local SublevelEntities = require 'src.sublevels.entities'
local World = require 'src.core.world'

local SubLevelScene = setmetatable({}, { __index = StateBase })
SubLevelScene.__index = SubLevelScene

function SubLevelScene:new(config)
    local o = StateBase.new(self, {
        name = "SubLevelScene",
        suspendUnderlying = true,
        isOverlay = false
    })
    o.config = config or nil
    o.time = 0
    o._prevHudState = {}
    return o
end

function SubLevelScene:enter(params)
    self.time = 0
    local cfg = self.config or params
    if not cfg then
        -- Crear una configuración mínima derivada de la posición del jugador
        local SeedSystem = require 'src.utils.seed_system'
        local currentSeed = (Map and Map.seed) or SeedSystem.generate()
        local player = World.get('player')
        local px, py = 0, 0
        if player and player.x and player.y then px, py = player.x, player.y end
        cfg = SubLevelManager.createConfig({
            parentSeed = currentSeed,
            type = SubLevelManager.Types.Generic,
            cx = math.floor(px / (Map.stride or 1)),
            cy = math.floor(py / (Map.stride or 1)),
            width = 8, height = 8,
            entryX = nil, entryY = nil,
        })
    end

    -- Calcular punto de entrada al centro del subnivel si no está definido
    do
        local sizePixels = (MapConfig.chunk.size or 64) * (MapConfig.chunk.tileSize or 32)
        local spacing = MapConfig.chunk.spacing or 0
        local stride = (sizePixels + spacing) * (MapConfig.chunk.worldScale or 1)
        local cx = math.floor((cfg.size and cfg.size.width or 8) / 2)
        local cy = math.floor((cfg.size and cfg.size.height or 8) / 2)
        cfg.entry = cfg.entry or {}
        cfg.entry.x = cfg.entry.x or (cx * stride + stride * 0.5)
        cfg.entry.y = cfg.entry.y or (cy * stride + stride * 0.5)
    end

    -- Entrar al subnivel: solo manejo de contexto (sin tocar el mapa principal)
    SubLevelManager.enter(cfg)

    -- Crear instancia de mundo del subnivel basada en archivo/config precreada
    self.world = SublevelWorld.new(cfg)

    -- Inicializar módulos futuros del subnivel
    if SublevelSpawns and SublevelSpawns.init then SublevelSpawns.init(cfg) end
    if SublevelDecor and SublevelDecor.init then SublevelDecor.init(cfg) end
    if SublevelEntities and SublevelEntities.init then SublevelEntities.init(cfg) end

    -- Desactivar visuales de fases en HUD dentro del subnivel
    if HUD and HUD.setPhaseVisualsEnabled then
        HUD.setPhaseVisualsEnabled(false)
    end
end

function SubLevelScene:update(dt)
    self.time = self.time + dt

    local camera = World.get('camera')
    local physicsManager = World.get('physics')
    local player = World.get('player')

    -- Actualizar cámara
    if camera and camera.update then
        camera:update(dt)
    end

    -- Actualizar mundo de física local
    if physicsManager and physicsManager.update then
        physicsManager:update(dt)
    end

    -- Actualizar jugador
    if player and player.update then
        if player.savePreviousState then player:savePreviousState() end
        player:update(dt)
    end

    -- Actualizar items del mundo
    if WorldItems and WorldItems.update then
        WorldItems.update(dt)
    end

    -- Limitar movimiento del jugador a bounds [-20000, 20000]
    if player then
        local minB, maxB = -20000, 20000
        if player.x then player.x = math.max(minB, math.min(maxB, player.x)) end
        if player.y then player.y = math.max(minB, math.min(maxB, player.y)) end
        if player.isInEVA and player.evaPlayer then
            local p = player.evaPlayer
            if p.x then p.x = math.max(minB, math.min(maxB, p.x)) end
            if p.y then p.y = math.max(minB, math.min(maxB, p.y)) end
        end
    end

    -- Actualizar instancia de mundo del subnivel
    if self.world and self.world.update then
        self.world:update(dt, player)
    end

    -- Actualizar módulos del subnivel
    if SublevelSpawns and SublevelSpawns.update then SublevelSpawns.update(dt, self.world, player) end
    if SublevelDecor and SublevelDecor.update then SublevelDecor.update(dt, self.world, player) end
    if SublevelEntities and SublevelEntities.update then SublevelEntities.update(dt, self.world, player) end

    -- Mantener optimizaciones activas
    if type(OptimizedRenderer) == "table" and OptimizedRenderer.update then
        OptimizedRenderer.update(dt, player and player.x or 0, player and player.y or 0, camera)
    end

    -- Seguir a la entidad activa
    if camera and type(camera.follow) == "function" and player and player.getActiveEntity then
        local activeEntity = player:getActiveEntity()
        camera:follow(activeEntity, dt)
    end
    -- Actualizar HUD para mantener todos los sistemas visibles
    if HUD and HUD.update then HUD.update(dt) end

    -- Actualizar UIs vía orquestador unificado
    local UIManager = require 'src.ui.ui_manager'
    UIManager.updateAll(dt, player)
end

function SubLevelScene:draw()
    local camera = World.get('camera')
    local player = World.get('player')

    -- Fondo limpio para la escena limitada
    love.graphics.clear(0, 0, 0, 1)

    -- Aplicar transformación de cámara
    if camera then camera:apply() end

    -- Dibujar instancia de mundo del subnivel y jugador
    if self.world and self.world.draw then
        self.world:draw(camera)
    end
    if player and player.draw then player:draw() end

    -- Dibujar decoraciones y entidades propias del subnivel
    if SublevelDecor and SublevelDecor.draw then SublevelDecor.draw(camera, self.world) end
    if SublevelEntities and SublevelEntities.draw then SublevelEntities.draw(camera, self.world) end

    -- Dibujar items del mundo en el subnivel
    do
        local px, py = 0, 0
        if player then px, py = player.x or 0, player.y or 0 end
        if WorldItems and WorldItems.draw then
            WorldItems.draw(camera, px, py)
        end
    end

    -- Grilla de debug (F4) dentro del subnivel
    if DebugGrid and DebugGrid.draw then DebugGrid.draw(camera) end

    -- Restaurar transformación
    if camera then camera:unapply() end

    -- Dibujar HUD y UIs (inventario nave/EVA) para mantener funcionalidad completa
    local InventoryUI = require 'src.ui.inventory_ui'
    local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
    local inventoryOpen = (InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen()) or 
                         (EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen())
    if HUD and HUD.draw then HUD.draw(inventoryOpen) end
    if InventoryUI and InventoryUI.draw then InventoryUI:draw(player) end
    if EVAInventoryUI and EVAInventoryUI.draw and player and player.isInEVA and player.evaPlayer then
        EVAInventoryUI:draw(player.evaPlayer)
    end

    -- Dibujar un indicador de subnivel sencillo
    local status = SubLevelManager.getStatus()
    love.graphics.setColor(0.9, 0.95, 1.0, 0.95)
    local label = "SUBNIVEL ACTIVO"
    if status and status.current and status.current.type then
        label = label .. " - " .. tostring(status.current.type)
    end
    love.graphics.printf(label, 16, 16, love.graphics.getWidth() - 32, 'left')
    love.graphics.setColor(1, 1, 1, 1)
end

function SubLevelScene:keypressed(key)
    -- Controles de inventario y sistemas del jugador dentro del subnivel
    local InventoryUI = require 'src.ui.inventory_ui'
    local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
    local player = World.get('player')
    
    if key == 'tab' and player then
        local inEVA = player.isInEVA
        if inEVA then
            -- Alternar inventario EVA
            if EVAInventoryUI then EVAInventoryUI:toggle() end
        else
            -- Alternar inventario de la nave
            if InventoryUI then InventoryUI:toggle() end
        end
        return true
    end

    -- Recolección manual y bloqueo de herencia de fases
    if key == 'e' then
        local WorldItems = require 'src.item_systems.world_items'
        local collected = false
        local player = World.get('player')

        if player and player.isInEVA and player.evaPlayer and player.evaPlayer.attemptPickup then
            -- En EVA: usar intento específico del EVA player
            player.evaPlayer:attemptPickup()
            collected = true
        else
            -- En nave: intentar recolección manual centralizada
            if WorldItems and WorldItems.tryManualCollection then
                collected = WorldItems.tryManualCollection() or false
            end
        end

        -- Consumir la tecla para evitar que PhaseSystem maneje 'e' en subniveles
        return true
    end

    if key == 'escape' or key == 'q' then
        -- Salir del subnivel y regresar al mapa principal
        SubLevelManager.exit()
        if self.manager then self.manager:pop({ fadeDuration = 0.2 }) end
        return true
    end
    return false
end

function SubLevelScene:mousepressed(x, y, button)
    local player = World.get('player')
    -- Propagar clicks a inventarios si están abiertos; si no, permitir disparo
    local InventoryUI = require 'src.ui.inventory_ui'
    local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() and player and player.isInEVA and player.evaPlayer then
        EVAInventoryUI:mousepressed(x, y, button, player.evaPlayer)
        return true
    end
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        InventoryUI:mousepressed(x, y, button, player)
        return true
    end
    if button == 1 and player and not player.isInEVA and player.shoot then
        player:shoot(x, y)
        return true
    end
    return false
end

function SubLevelScene:mousereleased(x, y, button)
    local player = World.get('player')
    -- Propagar release para completar drag-and-drop en inventarios
    local InventoryUI = require 'src.ui.inventory_ui'
    local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
    if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() and player and player.isInEVA and player.evaPlayer then
        EVAInventoryUI:mousereleased(x, y, button, player.evaPlayer)
        return true
    end
    if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
        InventoryUI:mousereleased(x, y, button, player)
        return true
    end
    return false
end

function SubLevelScene:exit()
    -- Asegurar restauración de contexto del mapa principal
    SubLevelManager.exit()
    self.world = nil
    -- Restaurar visuales de fases al salir del subnivel
    if HUD and HUD.setPhaseVisualsEnabled then
        HUD.setPhaseVisualsEnabled(true)
    end
end

return SubLevelScene