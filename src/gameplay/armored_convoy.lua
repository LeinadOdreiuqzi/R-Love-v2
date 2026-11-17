local World = require 'src.core.world'
local Seed = require 'src.utils.seed_system'
local Loot = require 'src.gameplay.loot'
local Sites = require 'src.gameplay.salvage_sites'
local AI = require 'src.entities.ai_controller'
local MapConfig = require 'src.maps.config.map_config'
local ForceField = require 'src.physics.convoy_force_field'
local Catalog = require 'src.gameplay.encounter_catalog'

local Convoy = {}
Convoy.__index = Convoy
local stops = {
    {name = 'Refrigeración', duration = 9, wave = {'FIGHTER', 'INTERCEPTOR'}},
    {name = 'Relevo', duration = 10, wave = {'FIGHTER', 'SENTINEL'}},
    {name = 'Alineación', duration = 11, wave = {'INTERCEPTOR', 'FIGHTER', 'GUNSHIP'}},
    {name = 'Carga de salto', duration = 13, wave = {'INTERCEPTOR', 'GUNSHIP', 'SENTINEL'}}
}
local initialEscort = {'FIGHTER', 'INTERCEPTOR', 'SENTINEL'}
local speed, armorMax, hullMax = 105, 170, 310
local travelDamage, responseTime = .25, 1.2
local faction = 'SALVAGE_CONVOY'

function Convoy.candidate(seed, cx, cy, biome, phase)
    if cx == 0 and cy == 0 then return end
    local chance = Catalog.chance(Catalog.armoredConvoy, biome, phase)
    if chance == 0 then return end
    local id = ('convoy:%d:%d'):format(cx, cy)
    local rng = love.math.newRandomGenerator(Seed.toNumeric(tostring(seed) .. ':' .. id))
    if rng:random() >= chance then return end
    return id, rng
end

local function routeFor(cx, cy, stride, chunk, rng)
    local size = MapConfig.chunk.tileSize * MapConfig.chunk.worldScale
    local startLane = rng:random(1, 3)
    local direction = rng:random() < .5 and -1 or 1
    for attempt = 0, 2 do
        local lane = (startLane + attempt - 1) % 3 + 1
        local y = stride * (.32 + lane * .09)
        local clear = true
        for ty = math.floor((y - 145) / size), math.ceil((y + 145) / size) do
            local row = chunk.tiles and chunk.tiles[ty]
            for tx = math.floor(stride * .24 / size), math.ceil(stride * .76 / size) do
                local tile = row and row[tx]
                if tile and tile >= MapConfig.ObjectType.ASTEROID_SMALL and tile <= MapConfig.ObjectType.ASTEROID_LARGE then
                    clear = false
                    break
                end
            end
            if not clear then break end
        end
        for _, object in ipairs(chunk.specialObjects or {}) do
            local ox, oy = (object.x or 0) * MapConfig.chunk.worldScale, (object.y or 0) * MapConfig.chunk.worldScale
            local margin = math.max(220, (object.radius or object.size or 0) * MapConfig.chunk.worldScale)
            if ox >= stride * .24 - margin and ox <= stride * .76 + margin and math.abs(oy - y) <= margin + 115 then
                clear = false
                break
            end
        end
        if clear then
            local route = {}
            for i = 0, #stops do
                route[i + 1] = {x = (cx + .5 + direction * (-.21 + i * .42 / #stops)) * stride, y = cy * stride + y}
            end
            return route
        end
    end
end

function Convoy.trySpawn(director, cx, cy, stride, px, py, map)
    local run = director.runState
    if not run or director.convoy or #director.ecosystem.activeAgents > director.ecosystem.maxActiveAgents - #initialEscort then return end
    local biome = director:getChunkBiomeAndBorder(cx, cy)
    local phase = Catalog.phaseForSector(cx, cy, stride)
    local id, rng = Convoy.candidate(run.seed, cx, cy, biome, phase)
    if not id or run.convoyVisited[id] then return end
    local chunk = map and map.getChunkNonBlocking(cx, cy)
    if not chunk or (chunk.status and chunk.status ~= 'complete') then return end
    local route = routeFor(cx, cy, stride, chunk, rng)
    if not route then return end
    local origin = route[1]
    local distance = (origin.x - px)^2 + (origin.y - py)^2
    if distance < 450^2 or distance > 1700^2 then return end
    if Convoy.start(director, run, id, route, rng) then run.convoyVisited[id] = true end
end

function Convoy:deploy(types, reinforcing)
    local ship = self.ship
    local sin, cos = math.sin(ship.rotation), math.cos(ship.rotation)
    local player = World.getPlayer()
    for index, kind in ipairs(types) do
        local side = index % 2 == 1 and -1 or 1
        local offsetX = index == 3 and 0 or side * 108
        local offsetY = (reinforcing and 195 or 70) + (index - 1) * 32
        local slot = #self.escorts + 1
        local escort = self.director:spawnEcologicalShip(ship.x + offsetX * cos - offsetY * sin,
            ship.y + offsetX * sin + offsetY * cos, kind, AI.ROLES.WARDEN, self.rng, {
                faction = faction, wingmanOf = ship, formationSlotIndex = slot,
                formationOffsetX = offsetX, formationOffsetY = 65 + (slot - 1) * 15,
                namePrefix = reinforcing and 'Refuerzo del convoy' or 'Escolta del convoy', suppressLoot = true,
                entryAngle = ship.rotation - math.pi * .5
            })
        if escort then
            self.escorts[slot] = escort
            if reinforcing and player and (player.x - ship.x)^2 + (player.y - ship.y)^2 <= 1100^2 then
                escort.aiController:onDamaged(0, player)
            end
        end
    end
end

function Convoy.start(director, run, id, route, rng)
    local Naves = require 'src.entities.naves'
    local origin = route[1]
    local ship = Naves:new(origin.x, origin.y, 'CARGO')
    local self = setmetatable({director = director, run = run, id = id, ship = ship, route = route,
        nextPoint = 2, armor = armorMax, hull = hullMax, escorts = {}, state = 'travel', rng = rng}, Convoy)
    director.convoy = self
    ship.convoy = self
    ship.projectileBarrier = ForceField
    ship.shipName, ship.aiFaction, ship.isAI, ship.isAbandoned = 'Convoy blindado', faction, true, false
    ship.stats.shield.currentShield = 0
    ship.rotation = math.atan2(route[2].y - origin.y, route[2].x - origin.x) + math.pi * .5
    ship.prevRotation = ship.rotation
    ship.update = function(_, dt) self:update(dt) end
    ship.takeDamage = function(_, amount, attacker, hitX, hitY) return self:takeDamage(amount, attacker, hitX, hitY) end
    World.addEntity(ship)

    self:deploy(initialEscort, false)
    return self
end

local function removeShip(ship)
    ship.isDestroyed = true
    require('src.entities.naves').removeShip(ship.shipId)
    World.removeEntity(ship)
end

local function isActiveEscort(escort)
    return escort and not escort.isDestroyed and not escort.isAbandoned and not escort.isPiloted
        and World.getEntityById(escort.entityId) == escort
end

function Convoy:finish(escaped)
    self.state = escaped and 'escaped' or 'destroyed'
    removeShip(self.ship)
    self.reinforcementTimer = nil
    for _, escort in ipairs(self.escorts) do
        if isActiveEscort(escort) then
            escort.aiController.wingmanOf = nil
            if escaped then removeShip(escort) end
        end
    end
    if not escaped then
        local ship = self.ship
        local id = Loot.registerConvoyWreck(self.run, self.id, ship.x, ship.y, ship.rotation, ForceField.scale(ship))
        Sites.addConvoyWreck(self.run, id)
    end
    self.director.convoy = nil
end

function Convoy:takeDamage(amount, attacker, hitX, hitY)
    local source = attacker and (attacker.owner or attacker)
    if self.state == 'destroyed' then return true end
    if amount <= 0 or not source or source == self.ship or source.aiFaction == faction or self.state == 'escaped'
        or source.combatContext ~= self.ship.combatContext then return false end
    -- Only the player can resolve the convoy encounter.
    local player = World.getPlayer()
    if not player or source ~= player or (player.x - self.ship.x)^2 + (player.y - self.ship.y)^2 > 1100^2 then return false end
    for _, escort in ipairs(self.escorts) do
        if isActiveEscort(escort) and escort.aiController.combatTarget ~= source then
            escort.aiController:onDamaged(amount, source)
        end
    end
    if self.state ~= 'exposed' then
        if hitX and hitY then
            self.fieldHitX, self.fieldHitY = ForceField.toLocal(self.ship, hitX, hitY)
        elseif (self.blockFlash or 0) < .05 and source.x and source.y then
            local x, y = ForceField.toLocal(self.ship, source.x, source.y)
            local length = math.sqrt(x * x + y * y)
            if length > 0 then self.fieldHitX, self.fieldHitY = x * 2.8 / length, y * 2.8 / length end
        end
        self.blockFlash = ForceField.flashDuration
        amount = amount * travelDamage
    end
    if self.armor > 0 then
        local absorbed = math.min(amount, self.armor)
        self.armor, amount = self.armor - absorbed, amount - absorbed
    end
    self.hull = math.max(0, self.hull - amount)
    if self.hull == 0 then
        self:finish(false)
        return true
    end
    return false
end

function Convoy:update(dt)
    if self.state == 'destroyed' or self.state == 'escaped' then return end
    local ship = self.ship
    ship:updateProjectiles(dt)
    self.blockFlash = math.max(0, (self.blockFlash or 0) - dt)
    if self.state == 'exposed' then
        ship:updateBurn(math.min(dt, self.remaining))
        if ship.isDestroyed then return end
        self.remaining = self.remaining - dt
        if self.remaining <= 0 then
            if self.nextPoint == #self.route then self:finish(true); return end
            self.state = 'travel'
            ship.projectileBarrier = ForceField
            self.nextPoint = self.nextPoint + 1
        elseif self.reinforcementTimer then
            self.reinforcementTimer = self.reinforcementTimer - dt
            if self.reinforcementTimer <= 0 then
                self.reinforcementTimer = nil
                self:deploy(self.stop.wave, true)
            end
        end
        return
    end
    ship:updateBurn(dt)
    if ship.isDestroyed then return end
    local point = self.route[self.nextPoint]
    local dx, dy = point.x - ship.x, point.y - ship.y
    local distance = math.sqrt(dx^2 + dy^2)
    if distance <= speed * dt then
        ship.x, ship.y = point.x, point.y
        ship.dx, ship.dy, ship.engineGlow = 0, 0, .12
        local stop = stops[self.nextPoint - 1]
        self.state, self.remaining = 'exposed', stop.duration
        ship.projectileBarrier = nil
        self.blockFlash = 0
        self.stop = stop
        self.reinforcementTimer = responseTime
    else
        ship.x, ship.y = ship.x + dx / distance * speed * dt, ship.y + dy / distance * speed * dt
        ship.dx, ship.dy, ship.engineGlow = dx / distance * speed / 60, dy / distance * speed / 60, .62
        ship.rotation = math.atan2(dy, dx) + math.pi * .5
    end
    ship:updateShipRegistry()
end

function Convoy:drawHUD(player, camera)
    local ship = self.ship
    local distance = math.sqrt((ship.x - player.x)^2 + (ship.y - player.y)^2)
    if distance > 1800 then return end
    local g = love.graphics
    local w, h = g.getDimensions()
    local x, y = camera:worldToScreen(ship.x, ship.y)
    x, y = math.max(86, math.min(w - 86, x)), math.max(90, math.min(h - 130, y))
    g.push('all')
    g.setColor(1, .72, .35)
    g.printf(('Convoy blindado · %.0f u'):format(distance), x - 115, y + 48, 230, 'center')
    if self.state == 'exposed' then
        g.setColor(.35, .95, 1)
        local status = ('%d/%d %s · %ds'):format(self.nextPoint - 1, #stops, self.stop.name, math.ceil(self.remaining))
        if self.reinforcementTimer then status = status .. ' · refuerzos' end
        local width = math.min(w - 20, 294)
        g.printf(status, math.max(10, math.min(w - width - 10, x - width / 2)), y + 65, width, 'center')
    else
        g.printf('Campo activo · daño reducido', x - 115, y + 65, 230, 'center')
        local nextStop = stops[self.nextPoint - 1]
        if nextStop then
            local point = self.route[self.nextPoint]
            local sx, sy = camera:worldToScreen(point.x, point.y)
            if sx > 55 and sx < w - 55 and sy > 60 and sy < h - 125 and math.abs(sx - x) > 110 then
                g.setColor(.45, .84, .90, .82)
                g.polygon('line', sx, sy - 6, sx + 6, sy, sx, sy + 6, sx - 6, sy)
                g.printf('Próxima parada', sx - 70, sy + 10, 140, 'center')
            end
        end
    end
    if distance <= 600 then
        local width = 64
        g.setColor(.10, .12, .16, .9)
        g.rectangle('fill', x - width / 2, y + 35, width, 8)
        g.setColor(1, .72, .35)
        g.rectangle('fill', x - width / 2, y + 35, width * self.armor / armorMax, 3)
        g.setColor(1, .35, .32)
        g.rectangle('fill', x - width / 2, y + 40, width * self.hull / hullMax, 3)
    end
    g.pop()
end

return Convoy
