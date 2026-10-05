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
local PauseMenu = require 'src.ui.pause_menu'
local DebugRenderer = require 'src.utils.debug_renderer'

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

    -- Calcular punto de entrada centrado y zoom dramático según el Tier
    local entryX, entryY = 0, 0
    local camX, camY = 0, 0
    local targetZoom = 0.55
    local tier = (cfg.meta and cfg.meta.tier) or 1
    if tier == 1 then
        entryX = 0
        entryY = 0
        camX = 0
        camY = 0
        targetZoom = 0.45
    elseif tier == 2 then
        entryX = 0
        entryY = 4900
        camX = 0
        camY = 4900
        targetZoom = 0.40
    elseif tier == 3 then
        entryX = 0
        entryY = 2900
        camX = 0
        camY = 2900
        targetZoom = 0.45
    end

    cfg.entry = { x = entryX, y = entryY }

    -- Entrar al subnivel: solo manejo de contexto (sin tocar el mapa principal)
    SubLevelManager.enter(cfg)

    -- Posicionar jugador y cámara exactamente en el punto de entrada
    local player = World.get('player')
    local camera = World.get('camera')
    if player then
        player.x = entryX
        player.y = entryY
        player.prevX = entryX
        player.prevY = entryY
        player.dx = 0
        player.dy = 0
        if player.body and player.body.setPosition then
            player.body:setPosition(entryX, entryY)
            player.body:setLinearVelocity(0, 0)
        end
    end
    if camera then
        camera.x = camX
        camera.y = camY
        camera:setPosition(camX, camY)
        camera.zoom = targetZoom
        camera.targetZoom = targetZoom
        camera:updateFrustum()
    end

    -- Inicializar BackgroundManager para estrellas de fondo
    local BackgroundManager = require 'src.shaders.background_manager'
    if BackgroundManager and BackgroundManager.init then
        BackgroundManager.init()
    end

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

    -- Actualizar fondo galáctico y estrellas profundas
    local BackgroundManager = require 'src.shaders.background_manager'
    if BackgroundManager and BackgroundManager.update and camera then
        BackgroundManager.update(dt, camera)
    end

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

    -- Actualizar motor celestial 2.5D (partículas y dinámicas orbitales)
    local CelestialRenderer = require 'src.sublevels.celestial_renderer'
    if CelestialRenderer and CelestialRenderer.update then
        CelestialRenderer.update(dt)
    end

    -- Simulación de peligro térmico coronal en Tier 2
    local currentTier = (self.config and self.config.meta and self.config.meta.tier) or 1
    if currentTier == 2 and player then
        local TauCetiDef = require 'src.sublevels.definitions.tau_ceti'
        local sunDef = TauCetiDef.tiers[2] and TauCetiDef.tiers[2].sun
        if sunDef and sunDef.heatDamageDistance then
            local px, py = player.x or 0, player.y or 0
            local dist = math.sqrt((px - sunDef.x)^2 + (py - sunDef.y)^2)
            if dist < sunDef.heatDamageDistance then
                local danger = math.max(0.0, math.min(1.0, 1.0 - (dist - sunDef.radius) / (sunDef.heatDamageDistance - sunDef.radius)))
                local dmg = (sunDef.heatDamageRate or 18) * danger * dt
                -- Aplicar daño ambiental térmico directamente a los stats (escudos y casco)
                -- para evitar disparar el sonido cinético de impacto de balas 60 veces por segundo
                if player.stats and player.stats.takeDamage then
                    local died = player.stats:takeDamage(dmg)
                    if died and player.die then
                        player:die()
                    end
                elseif player.takeDamage then
                    player:takeDamage(dmg)
                end
            end
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
    -- Pausa de simulación si el menú de pausa está abierto
    local PauseMenu = require 'src.ui.pause_menu'
    if PauseMenu.isOpen() then
        PauseMenu.update(dt)
        return
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

    -- Fondo espacial base
    love.graphics.clear(0.012, 0.016, 0.025, 1)

    -- Renderizar fondo galáctico profundo y estrellas de fondo antes de transformar cámara
    local BackgroundManager = require 'src.shaders.background_manager'
    if BackgroundManager and BackgroundManager.render and camera then
        BackgroundManager.render(camera)
    end
    local MapRenderer = require 'src.maps.systems.map_renderer'
    if MapRenderer then
        if not MapRenderer._microStars or not MapRenderer._microStars.initialized then
            MapRenderer.init()
        end
        MapRenderer.drawMicroStars(camera)
        MapRenderer.drawSmallStars(camera)
    end

    -- Renderizar escenario cósmico multi-capa con falso 3D y parallax (Tier 1 Tau Ceti)
    local CelestialRenderer = require 'src.sublevels.celestial_renderer'
    if CelestialRenderer and CelestialRenderer.drawScenicBackground then
        CelestialRenderer.drawScenicBackground(self.config, camera, player)
    end

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

    -- Efecto de viñeta de radiación térmica en pantalla (Tier 2)
    local currentTier = (self.config and self.config.meta and self.config.meta.tier) or 1
    if currentTier == 2 and player then
        local TauCetiDef = require 'src.sublevels.definitions.tau_ceti'
        local sunDef = TauCetiDef.tiers[2] and TauCetiDef.tiers[2].sun
        if sunDef and sunDef.heatDamageDistance then
            local px, py = player.x or 0, player.y or 0
            local dist = math.sqrt((px - sunDef.x)^2 + (py - sunDef.y)^2)
            if dist < sunDef.heatDamageDistance then
                local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
                local danger = math.max(0.0, math.min(1.0, 1.0 - (dist - sunDef.radius) / (sunDef.heatDamageDistance - sunDef.radius)))
                local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 7.0)
                love.graphics.setColor(1.0, 0.32, 0.08, danger * 0.40 * pulse)
                love.graphics.setLineWidth(14)
                love.graphics.rectangle("line", 0, 0, sw, sh)
                love.graphics.setLineWidth(1)
            end
        end
    end

    -- Dibujar HUD y UIs respetando estrictamente el flag global showHUD (alternable con 'L')
    local GameState = require 'src.core.game_state'
    local showHUD = (GameState and GameState.state and GameState.state.showHUD ~= false)

    local InventoryUI = require 'src.ui.inventory_ui'
    local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
    local inventoryOpen = (InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen()) or 
                         (EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen())

    if showHUD then
        if HUD and HUD.draw then HUD.draw(inventoryOpen) end

        -- Indicador simple de subnivel (ocultable con el HUD)
        local status = SubLevelManager.getStatus()
        local name = (status and status.current and status.current.meta and status.current.meta.name) or (status and status.current and status.current.type)
        if name then
            love.graphics.setColor(0.9, 0.95, 1.0, 0.75)
            love.graphics.printf(tostring(name), 16, 16, love.graphics.getWidth() - 32, 'left')
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    if InventoryUI and InventoryUI.draw and InventoryUI.isOpen and InventoryUI:isOpen() then
        InventoryUI:draw(player)
    end
    if EVAInventoryUI and EVAInventoryUI.draw and player and player.isInEVA and player.evaPlayer then
        if EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() then
            EVAInventoryUI:draw(player.evaPlayer)
        end
    end

    -- Overlays de depuración y rendimiento (F6 y F12)
    local DebugRenderer = require 'src.utils.debug_renderer'
    if DebugRenderer then
        if GameState and GameState.biomeDebug and GameState.biomeDebug.enabled and DebugRenderer.drawBiomeDebugOverlay then
            DebugRenderer.drawBiomeDebugOverlay()
        end
        if GameState and ((GameState.biomeDebug and GameState.biomeDebug.showPerformanceOverlay) or (GameState.advancedStats and GameState.advancedStats.enabled)) and DebugRenderer.drawPerformanceOverlay then
            DebugRenderer.drawPerformanceOverlay()
        end
    end

    -- Menú de Pausa (se renderiza con máxima prioridad sobre todo lo demás)
    if PauseMenu.isOpen() then
        PauseMenu.draw()
    end
end

function SubLevelScene:keypressed(key)
    local InventoryUI = require 'src.ui.inventory_ui'
    local EVAInventoryUI = require 'src.ui.eva_inventory_ui'
    local PauseMenu = require 'src.ui.pause_menu'
    local player = World.get('player')

    -- Si el menú de pausa ya está abierto, delegar a PauseMenu
    if PauseMenu.isOpen() then
        return false
    end

    -- 'escape': Cerrar inventario activo si hay alguno abierto; de lo contrario, abrir menú de pausa
    if key == 'escape' then
        if EVAInventoryUI and EVAInventoryUI.isOpen and EVAInventoryUI:isOpen() and player and player.isInEVA then
            EVAInventoryUI:toggle(player.evaPlayer)
            return true
        end
        if InventoryUI and InventoryUI.isOpen and InventoryUI:isOpen() then
            InventoryUI:toggle(player)
            return true
        end
        PauseMenu.open()
        return true
    end

    -- 'p': Alternar menú de pausa
    if key == 'p' then
        PauseMenu.toggle()
        return true
    end

    -- 'q': Salir del subnivel y regresar al mapa principal
    if key == 'q' then
        SubLevelManager.exit()
        if self.manager then self.manager:pop({ fadeDuration = 0.2 }) end
        return true
    end

    -- 'tab': Alternar inventario nave/EVA
    if key == 'tab' and player then
        local inEVA = player.isInEVA
        if inEVA then
            if EVAInventoryUI then EVAInventoryUI:toggle() end
        else
            if InventoryUI then InventoryUI:toggle() end
        end
        return true
    end

    -- 'e': Recolección manual, balizas de salto y portales de salida
    if key == 'e' then
        local CelestialRenderer = require 'src.sublevels.celestial_renderer'
        local player = World.get('player')
        local beacon = CelestialRenderer.checkBeaconInteraction(self.config, player)
        if beacon then
            if beacon.targetTier then
                self:jumpToTier(beacon.targetTier)
                return true
            elseif beacon.isExit then
                SubLevelManager.exit()
                if self.manager then self.manager:pop({ fadeDuration = 0.2 }) end
                return true
            end
        end

        local WorldItems = require 'src.item_systems.world_items'
        local collected = false
        if player and player.isInEVA and player.evaPlayer and player.evaPlayer.attemptPickup then
            player.evaPlayer:attemptPickup()
            collected = true
        else
            if WorldItems and WorldItems.tryManualCollection then
                collected = WorldItems.tryManualCollection() or false
            end
        end

        return true
    end

    -- Retornar false para cualquier otra tecla (como 'l' para ocultar HUD, F1-F12 para debugs, etc.)
    -- para que InputManager procese todos los atajos globales normalmente
    return false
end

function SubLevelScene:jumpToTier(targetTier)
    local TauCetiDef = require 'src.sublevels.definitions.tau_ceti'
    local tierDef = TauCetiDef.tiers[targetTier]
    if not tierDef then return end

    local SublevelWorld = require 'src.sublevels.sublevel_world'
    local World = require 'src.core.world'

    self.config.type = tierDef.id
    self.config.meta = {
        id = tierDef.id,
        name = "Tau Ceti - " .. tierDef.name,
        tier = targetTier,
        subworldId = "tau_ceti",
        accent = tierDef.accentColor or { 0.35, 0.75, 1.0 }
    }

    local entryX, entryY = 0, 0
    local camX, camY = 0, 0
    local targetZoom = 0.55
    if targetTier == 1 then
        entryX = 0
        entryY = 0
        camX = 0
        camY = 0
        targetZoom = 0.45
    elseif targetTier == 2 then
        entryX = 0
        entryY = 4900
        camX = 0
        camY = 4900
        targetZoom = 0.40
    elseif targetTier == 3 then
        entryX = 0
        entryY = 2900
        camX = 0
        camY = 2900
        targetZoom = 0.45
    end

    self.config.entry = { x = entryX, y = entryY }

    local player = World.get('player')
    local camera = World.get('camera')
    if player then
        player.x = entryX
        player.y = entryY
        player.prevX = entryX
        player.prevY = entryY
        if player.body and player.body.setPosition then
            player.body:setPosition(entryX, entryY)
            player.body:setLinearVelocity(0, 0)
        end
        if player.dx then player.dx = 0 end
        if player.dy then player.dy = 0 end
    end
    if camera then
        camera.x = camX
        camera.y = camY
        camera:setPosition(camX, camY)
        camera.zoom = targetZoom
        camera.targetZoom = targetZoom
        camera:updateFrustum()
    end

    self.world = SublevelWorld.new(self.config)

    local ok, am = pcall(require, 'src.audio.audio_manager')
    if ok and am and am.play then
        pcall(function() am.play("ui_click", { pitch = 1.3, volume = 0.20 }) end)
    end
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