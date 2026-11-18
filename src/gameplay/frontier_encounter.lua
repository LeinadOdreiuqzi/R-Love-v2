local World = require 'src.core.world'
local Phase = require 'src.gameplay.phase_system'
local Boss = require 'src.entities.frontier_boss'
local Art = require 'src.rendering.ships.frontier_boss_art'
local Loot = require 'src.gameplay.loot'
local Seed = require 'src.utils.seed_system'
local Config = require 'src.maps.config.map_config'

local Encounter = {}
Encounter.__index = Encounter

local function discardShots(ship)
    for _, shot in ipairs(ship.projectiles or {}) do
        shot.explosion_radius = 0
        shot:destroy('encounter_finished')
    end
end

local function removeShip(ship)
    discardShots(ship)
    ship.isDestroyed = true
    require('src.entities.naves').removeShip(ship.shipId)
    World.removeEntity(ship)
end

local function spawnPosition(player)
    local Naves = require 'src.entities.naves'
    local map = World.getMap()
    local stride = (Config.chunk.size*Config.chunk.tileSize+Config.chunk.spacing)*Config.chunk.worldScale
    local inward = math.atan2(-player.y,-player.x)
    for _, distance in ipairs({480,680}) do
        for attempt = 0,11 do
            local angle = inward + attempt*math.pi/6
            local x,y = Phase.clampPlayerToCurrentPhase(player.x+math.cos(angle)*distance,player.y+math.sin(angle)*distance)
            local chunk = map and map.getChunkNonBlocking(math.floor(x/stride),math.floor(y/stride))
            if chunk and (not chunk.status or chunk.status=='complete') then
                local probe = {x=x,y=y,dx=0,dy=0,size=95,worldScale=1}
                Naves.resolveAsteroidCollisions(probe,0)
                if (probe.x-x)^2+(probe.y-y)^2 < 16 and (x-player.x)^2+(y-player.y)^2 > 300^2 then
                    return {x=x,y=y}
                end
            end
        end
    end
end

local function suspendAmbient(self)
    self.suspended,self.bodies = {},{}
    for _,ship in ipairs(require('src.entities.naves').getAllShips()) do
        if ship~=self.player then
            self.suspended[#self.suspended+1] = {ship=ship,context=ship.combatContext}
            ship.combatContext = self.suspended
            for _,shot in ipairs(ship.projectiles or {}) do
                local body=shot.body
                if body and not body:isDestroyed() then
                    self.bodies[#self.bodies+1] = {body=body,active=body:isActive()}
                    body:setActive(false)
                end
            end
        end
    end
end

function Encounter.start()
    if World.get('frontierEncounter') then return false end
    local player,run,director=World.getPlayer(),World.getRunState(),World.getDirector()
    if not player or not run or not director or run.defeat or player.isInEVA then return false end
    local position=spawnPosition(player)
    if not position then
        Phase.state.frontierMessage='Busca un tramo de frontera con espacio para el combate'
        return false
    end
    local self=setmetatable({player=player,run=run,director=director,spawn=position,
        minions={},totalDeployed=0,supportTimer=2.4,supportWarning=true,time=0},Encounter)
    self.rng=love.math.newRandomGenerator(Seed.toNumeric(tostring(run.seed)..':portero'))
    if player.hyperTravelEnabled then player:toggleHyperTravel() end
    suspendAmbient(self)
    World.set('frontierEncounter',self)
    self.boss=Boss.new(self)
    Phase.state.frontierMessage=nil
    return true
end

function Encounter:activeGuards()
    local count=0
    for _,ship in ipairs(self.minions) do
        if not ship.isDestroyed and not ship.isAbandoned then count=count+1 end
    end
    return count
end

function Encounter:constrain(ship,x,y)
    local oldX,oldY=ship.x,ship.y
    ship.x,ship.y=Phase.clampPlayerToCurrentPhase(x,y)
    ship:resolveAsteroidCollisions(0)
    x,y=ship.x,ship.y
    ship.x,ship.y=oldX,oldY
    return x,y
end

function Encounter:deployGuards()
    local boss=self.boss.ship
    local count=math.min(2,4-self:activeGuards(),8-self.totalDeployed)
    for index=1,count do
        local side=index==1 and -1 or 1
        local x=boss.x+math.cos(boss.rotation)*side*125
        local y=boss.y+math.sin(boss.rotation)*side*125
        local kind=self.boss.enraged and index==2 and 'GUNSHIP' or index==1 and 'INTERCEPTOR' or 'FIGHTER'
        local ship=self.director:spawnEcologicalShip(x,y,kind,'WARDEN',self.rng,{
            faction='FRONTIER_PORTERO',suppressLoot=true,namePrefix='Escolta de El Portero'})
        if ship then
            local ai=ship.aiController
            local config={}
            for key,value in pairs(ai.config) do config[key]=value end
            config.intactChance=0
            ai.config=config
            ship.combatContext=self.player.combatContext
            ship.frontierOwner=self
            ship:resolveAsteroidCollisions(0)
            ai:onDamaged(0,self.player)
            self.minions[#self.minions+1]=ship
            self.totalDeployed=self.totalDeployed+1
        end
    end
    boss:addImpactEffect(boss.x,boss.y,{.35,.85,1})
end

function Encounter:resumeAmbient()
    for _,saved in ipairs(self.suspended) do
        if saved.ship.combatContext==self.suspended then saved.ship.combatContext=saved.context end
    end
    for _,saved in ipairs(self.bodies) do
        if not saved.body:isDestroyed() then saved.body:setActive(saved.active) end
    end
    self.suspended,self.bodies={},{}
end

function Encounter:dispose()
    if self.disposed then return end
    self.disposed=true
    self:resumeAmbient()
    for _,ship in ipairs(self.minions) do removeShip(ship) end
    removeShip(self.boss.ship)
    if World.get('frontierEncounter')==self then World.set('frontierEncounter',nil) end
end

function Encounter:onVictory()
    if self.victory or self.run.defeat then return end
    self.victory,self.supportWarning,self.withdrawal=true,false,3
    self.run.frontierVictories=self.run.frontierVictories or {}
    self.run.frontierVictories[1]=true
    local ship=self.boss.ship
    Loot.registerFrontierWreck(self.run,ship.x,ship.y,ship.rotation)
    require('src.entities.naves').removeShip(ship.shipId)
    Phase.expandToPhase(2)
    for _,guard in ipairs(self.minions) do
        guard.aiController.active=false
        guard.burn=nil
        discardShots(guard)
    end
end

function Encounter:update(dt)
    self.time=self.time+dt
    if self.run.defeat then
        self.supportWarning=false
        return
    end
    if self.victory then
        self.withdrawal=self.withdrawal-dt
        for _,guard in ipairs(self.minions) do
            if not guard.isDestroyed then
                guard:savePreviousState()
                local angle=math.atan2(guard.y-self.boss.ship.y,guard.x-self.boss.ship.x)
                guard.x,guard.y=guard.x+math.cos(angle)*380*dt,guard.y+math.sin(angle)*380*dt
                guard.rotation=angle+math.pi*.5
                guard.engineGlow=.8
            end
        end
        if self.withdrawal<=0 then self:dispose() end
        return
    end
    self.boss:update(dt)
    if self.victory or self.run.defeat then return end
    self.supportTimer=self.supportTimer-dt
    self.supportWarning=self.supportTimer<=2 and self:activeGuards()<4 and self.totalDeployed<8
    if self.supportTimer<=0 then
        self:deployGuards()
        self.supportTimer=self.boss.enraged and 16 or 20
        self.supportWarning=false
    end
    for _,guard in ipairs(self.minions) do
        if not guard.isDestroyed and not guard.isAbandoned then
            guard:savePreviousState()
            guard.aiController.combatMemoryTimer=10
            guard:update(dt)
        end
    end
end

function Encounter:draw()
    local g=love.graphics
    g.push('all')
    if not self.victory then
        if not self.run.defeat then self.boss:drawTelegraphs() end
        for _,guard in ipairs(self.minions) do
            if not guard.isDestroyed and not guard.isAbandoned then
                g.setColor(.27,.73,1,.15+.08*math.sin(self.time*4)^2)
                g.setLineWidth(1.5)
                g.line(guard.x,guard.y,self.boss.ship.x,self.boss.ship.y)
            end
        end
        Art.draw(self.boss)
        self.boss.ship:drawProjectiles()
    end
    g.pop()
end

function Encounter:drawHUD()
    if not self.victory then self.boss:drawHUD() end
    if not self.victory and not self.run.defeat then
        local camera=World.getCamera()
        local ship=self.boss.ship
        local x,y=camera:worldToScreen(ship.x,ship.y)
        local g=love.graphics
        local width,height=g.getDimensions()
        if x<24 or x>width-24 or y<95 or y>height-130 then
            x,y=math.max(40,math.min(width-40,x)),math.max(104,math.min(height-140,y))
            local distance=math.sqrt((ship.x-self.player.x)^2+(ship.y-self.player.y)^2)
            g.push('all')
            g.setColor(1,.59,.34)
            g.polygon('line',x,y-8,x+8,y,x,y+8,x-8,y)
            g.printf(('Portero · %.0f u'):format(distance),math.max(8,math.min(width-128,x-60)),y+13,120,'center')
            g.pop()
        end
    end
    if self.run.defeat then
        local Theme=require 'src.ui.combat_theme'
        Theme.init()
        local g=love.graphics
        g.push('all')
        g.setColor(.02,.025,.04,.75)
        g.rectangle('fill',0,0,g.getDimensions())
        g.setFont(Theme.title)
        g.setColor(1,.48,.36)
        g.printf('NAVE DESTRUIDA',20,g.getHeight()*.43,g.getWidth()-40,'center')
        g.setFont(Theme.font)
        g.setColor(.86,.89,.92)
        g.printf('Enter · Nueva partida',20,g.getHeight()*.43+32,g.getWidth()-40,'center')
        g.pop()
    end
end

function Encounter:keypressed(key)
    if self.run.defeat and (key=='return' or key=='kpenter') then
        require('src.core.game_loader').changeSeedWithLoading(Seed.generate())
        return true
    end
    if key=='e' then return not self.victory end
    return key=='y' or key=='f' or key=='0' or key=='b'
end

return Encounter
