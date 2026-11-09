--[[
    Projectile - Clase Base para Proyectiles
    
    Esta clase define la estructura base para todos los proyectiles del juego.
    Maneja la física básica, ciclo de vida, y comportamientos comunes.
    
    Características:
    - Integración con Box2D para física realista
    - Sistema de vida útil y destrucción automática
    - Efectos visuales y de partículas
    - Detección y manejo de colisiones
    - Cálculo de trayectorias
--]]

local CollisionQuery = require 'src.physics.projectiles.collision_query'
local ProjectileVFX = require('src.physics.projectiles.projectile_vfx')
local Projectile = {}
Projectile.__index = Projectile

-- Dependencias
local PhysicsConfig = require('src.physics.config.physics_config')

-- Enumeraciones de estado
local ProjectileState = {
    ACTIVE = "active",
    EXPLODING = "exploding",
    DESTROYED = "destroyed"
}

-- Tipos de proyectiles
local ProjectileType = {
    BASIC = "basic",
    LASER = "laser",
    MISSILE = "missile",
    PLASMA = "plasma",
    TORPEDO = "torpedo"
}

--[[
    Constructor de la clase Projectile
    @param world: mundo Box2D
    @param x, y: posición inicial
    @param angle: ángulo de disparo en radianes
    @param speed: velocidad inicial
    @param config: configuración específica del proyectil
    @return: nueva instancia de Projectile
--]]
function Projectile.new(world, x, y, angle, speed, config)
    local self = setmetatable({}, Projectile)
    
    -- Configuración básica
    self.world = world
    self.type = config.type or ProjectileType.BASIC
    self.state = ProjectileState.ACTIVE
    
    -- Propiedades físicas (con soporte para calibración de hardpoint Nivel 4)
    local speedMult = (config and config.speedMultiplier) or 1.0
    local effectiveSpeed = speed * speedMult
    self.x = x
    self.y = y
    self.prevX = x
    self.prevY = y
    self.angle = angle
    self.speed = effectiveSpeed
    self.initial_velocity_x = math.cos(angle) * effectiveSpeed
    self.initial_velocity_y = math.sin(angle) * effectiveSpeed
    
    -- Configuración del proyectil
    self.config = self:mergeConfig(config)
    if config and config.scaleMultiplier then
        self.config.size = (self.config.size or 1.0) * config.scaleMultiplier
        self.scaleMultiplier = config.scaleMultiplier
    end
    self.hardpointOrigin = config and config.hardpointOrigin or "NOSE_CENTER"
    self.hardpointLevel = config and config.hardpointLevel or 1
    self.overcharged = not not (config and config.overcharged)
    
    -- Propiedades de vida útil
    self.lifetime = self.config.lifetime or PhysicsConfig.PROJECTILE_LIFETIME.DEFAULT
    self.age = 0
    self.max_distance = self.config.max_distance or math.huge
    self.distance_traveled = 0
    
    -- Propiedades de daño y efectos
    local rawDamage = self.config.damage
    if type(rawDamage) == "table" then
        local minD = tonumber(rawDamage.min or rawDamage[1]) or 10
        local maxD = tonumber(rawDamage.max or rawDamage[2]) or minD
        self.damage = (maxD > minD) and (minD + math.random() * (maxD - minD)) or minD
    else
        self.damage = tonumber(rawDamage) or 10
    end
    self.owner = self.config.owner
    self.explosion_radius = self.config.explosion_radius or 0
    self.statusEffect = self.config.statusEffect
    self.penetration = self.config.penetration or false
    self.bouncesRemaining = tonumber(self.config.bounces) or 0
    self.homingStrength = tonumber(self.config.homingStrength) or 0
    self.isBoomerang = not not self.config.isBoomerang
    self.chainArc = tonumber(self.config.chainArc) or 0
    self.knockbackForce = tonumber(self.config.knockbackForce) or 0
    self.graviticPull = tonumber(self.config.graviticPull) or 0
    self.graviticRadius = tonumber(self.config.graviticRadius) or 125
    self.hitTargets = {}
    
    -- Referencias de Box2D
    self.body = nil
    self.fixture = nil
    self.shape = nil
    
    -- Efectos visuales
    self.trail_particles = {}
    self.visual_effects = {}
    
    -- Inicializar cuerpo físico
    self:createPhysicsBody()
    
    -- Configurar callbacks
    self:setupCallbacks()
    ProjectileVFX.attach(self)
    
    return self
end

--[[
    Combina configuración por defecto con configuración personalizada
    @param custom_config: configuración personalizada
    @return: configuración combinada
--]]
function Projectile:mergeConfig(custom_config)
    -- TODO: Implementar fusión inteligente de configuraciones
    local default_config = PhysicsConfig.getProjectileConfig(custom_config.type)
    local merged = {}
    
    -- Copiar configuración por defecto
    for key, value in pairs(default_config) do
        merged[key] = value
    end
    
    -- Sobrescribir con configuración personalizada
    if custom_config then
        for key, value in pairs(custom_config) do
            merged[key] = value
        end
    end
    
    return merged
end

--[[
    Crea el cuerpo físico Box2D para el proyectil
--]]
function Projectile:createPhysicsBody()
    if not self.world or not love.physics then
        -- Modo cinemático ligero (desacoplado de Box2D)
        self.vx = self.initial_velocity_x
        self.vy = self.initial_velocity_y
        return
    end
    
    -- Crear cuerpo dinámico
    self.body = love.physics.newBody(self.world, self.x, self.y, "dynamic")
    
    -- Crear forma según el tipo de proyectil
    self.shape = self:createShape()
    
    -- Crear fixture con propiedades físicas
    self.fixture = love.physics.newFixture(self.body, self.shape)
    self:configureFixture()
    
    -- Establecer velocidad inicial
    self.body:setLinearVelocity(self.initial_velocity_x, self.initial_velocity_y)
    
    -- Configurar como proyectil (detección continua de colisiones)
    self.body:setBullet(true)
    
    -- Almacenar referencia al proyectil en el cuerpo
    self.body:setUserData(self)
end

--[[
    Crea la forma geométrica del proyectil según su tipo
    @return: forma Box2D
--]]
function Projectile:createShape()
    -- TODO: Implementar creación de formas específicas por tipo
    local shape_type = self.config.shape_type or "circle"
    
    if shape_type == "circle" then
        local radius = self.config.radius or 2
        return love.physics.newCircleShape(radius)
    elseif shape_type == "rectangle" then
        local width = self.config.width or 4
        local height = self.config.height or 2
        return love.physics.newRectangleShape(width, height)
    elseif shape_type == "polygon" then
        local vertices = self.config.vertices or {-2, -1, 2, -1, 2, 1, -2, 1}
        return love.physics.newPolygonShape(vertices)
    else
        -- Forma por defecto: círculo pequeño
        return love.physics.newCircleShape(2)
    end
end

--[[
    Configura las propiedades físicas del fixture
--]]
function Projectile:configureFixture()
    -- TODO: Implementar configuración completa del fixture
    
    -- Propiedades físicas básicas
    self.fixture:setDensity(self.config.density)
    self.fixture:setFriction(self.config.friction)
    self.fixture:setRestitution(self.config.restitution)
    
    -- Configurar categorías y máscaras de colisión
    self.fixture:setCategory(PhysicsConfig.COLLISION_CATEGORIES.PROJECTILE)
    -- Projectile pairs have no gameplay collision handler. Exclude them before
    -- Box2D builds contacts, especially when volleys share a muzzle position.
    self.fixture:setMask(PhysicsConfig.COLLISION_MASKS.PROJECTILE,
        PhysicsConfig.COLLISION_CATEGORIES.PROJECTILE)
    
    -- Configurar como sensor si es necesario
    if self.config.sensor then
        self.fixture:setSensor(true)
    end
end

--[[
    Configura los callbacks de colisión y eventos
--]]
function Projectile:setupCallbacks()
    -- TODO: Implementar callbacks específicos del proyectil
    -- Los callbacks se manejarán a través del CollisionHandler
    -- pero aquí se pueden definir comportamientos específicos
end

--[[
    Actualiza el proyectil
    @param dt: tiempo delta
--]]
function Projectile:update(dt)
    if self.state == ProjectileState.DESTROYED then
        return
    end
    
    -- Actualizar edad
    self.age = self.age + dt
    if self.body then self.x, self.y = self.body:getPosition() end

    -- Comportamientos cinemáticos especiales (Homing, Boomerang, Atracción Gravítica)
    local Naves = package.loaded['src.entities.naves']
    if self.isBoomerang and self.owner and self.owner.x and self.owner.y and self.age > (self.lifetime * 0.45) then
        local dx = self.owner.x - self.x
        local dy = self.owner.y - self.y
        local distSq = dx * dx + dy * dy
        if distSq > 400 then
            local targetAngle = math.atan2(dy, dx)
            local diff = targetAngle - (self.angle or 0)
            while diff > math.pi do diff = diff - 2 * math.pi end
            while diff < -math.pi do diff = diff + 2 * math.pi end
            self.angle = (self.angle or 0) + diff * math.min(1.0, dt * 6.5)
            local spd = self.speed or 320
            self.vx = math.cos(self.angle) * spd
            self.vy = math.sin(self.angle) * spd
            if self.body then self.body:setLinearVelocity(self.vx, self.vy) end
        else
            self:destroy("boomerang_returned")
            return
        end
    elseif self.homingStrength and self.homingStrength > 0 and Naves and Naves.getAllShips then
        local ships = Naves.getAllShips()
        local ownerCtx = self.owner and self.owner.combatContext
        local bestShip, bestDistSq = nil, 460 * 460
        for i = 1, #ships do
            local s = ships[i]
            if s and s ~= self.owner and s.combatContext == ownerCtx and not s.isAbandoned and s.x and s.y then
                local dx = s.x - self.x
                local dy = s.y - self.y
                local dSq = dx * dx + dy * dy
                if dSq < bestDistSq then
                    bestDistSq = dSq
                    bestShip = s
                end
            end
        end
        if bestShip then
            local targetAngle = math.atan2(bestShip.y - self.y, bestShip.x - self.x)
            local diff = targetAngle - (self.angle or 0)
            while diff > math.pi do diff = diff - 2 * math.pi end
            while diff < -math.pi do diff = diff + 2 * math.pi end
            self.angle = (self.angle or 0) + diff * math.min(1.0, dt * self.homingStrength)
            local spd = self.speed or 320
            self.vx = math.cos(self.angle) * spd
            self.vy = math.sin(self.angle) * spd
            if self.body then self.body:setLinearVelocity(self.vx, self.vy) end
        end
    end

    if self.graviticPull and self.graviticPull > 0 and Naves and Naves.getAllShips then
        local ships = Naves.getAllShips()
        local ownerCtx = self.owner and self.owner.combatContext
        local pullRadiusSq = self.graviticRadius * self.graviticRadius
        for i = 1, #ships do
            local s = ships[i]
            if s and s ~= self.owner and s.combatContext == ownerCtx and s.x and s.y then
                local dx = self.x - s.x
                local dy = self.y - s.y
                local dSq = dx * dx + dy * dy
                if dSq > 16 and dSq < pullRadiusSq then
                    local dist = math.sqrt(dSq)
                    local pull = (self.graviticPull * 0.12) * dt
                    s.dx = (s.dx or 0) + (dx / dist) * pull
                    s.dy = (s.dy or 0) + (dy / dist) * pull
                end
            end
        end
    end
    
    -- Actualizar distancia recorrida (cinemática o Box2D)
    if not self.body then
        self.x = (self.x or 0) + (self.vx or self.initial_velocity_x or 0) * dt
        self.y = (self.y or 0) + (self.vy or self.initial_velocity_y or 0) * dt
        local spd = math.sqrt((self.vx or self.initial_velocity_x or 0)^2 + (self.vy or self.initial_velocity_y or 0)^2)
        self.distance_traveled = self.distance_traveled + (spd * dt)
    else
        self:updateDistanceTraveled(dt)
    end
    
    -- Verificar colisiones espaciales contra naves y asteroides
    self:checkSpatialCollisions()
    ProjectileVFX.updateProjectile(self, dt)
    if self.state == ProjectileState.DESTROYED then
        return
    end

    -- Verificar condiciones de destrucción
    self:checkDestructionConditions()
    
    -- Actualizar efectos visuales
    self:updateVisualEffects(dt)
    
    -- Aplicar fuerzas especiales según el tipo
    self:applySpecialForces(dt)
end

--[[
    Actualiza la distancia recorrida por el proyectil
    @param dt: tiempo delta
--]]
function Projectile:updateDistanceTraveled(dt)
    -- TODO: Implementar cálculo preciso de distancia
    if self.body then
        local vx, vy = self.body:getLinearVelocity()
        local speed = math.sqrt(vx * vx + vy * vy)
        self.distance_traveled = self.distance_traveled + (speed * dt)
    end
end

-- Distancia mínima al cuadrado entre un punto (cx, cy) y el segmento (x1, y1) -> (x2, y2)
local function distSqPointToSegment(cx, cy, x1, y1, x2, y2)
    local vx = x2 - x1
    local vy = y2 - y1
    local lenSq = vx * vx + vy * vy
    if lenSq <= 0.0001 then
        local dx = cx - x1
        local dy = cy - y1
        return dx * dx + dy * dy, x1, y1
    end
    local t = ((cx - x1) * vx + (cy - y1) * vy) / lenSq
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local hitX = x1 + t * vx
    local hitY = y1 + t * vy
    local dx = cx - hitX
    local dy = cy - hitY
    return dx * dx + dy * dy, hitX, hitY
end

--[[
    Comprueba colisiones espaciales continuas (raycast por segmento) contra naves, asteroides y estaciones
--]]
function Projectile:checkSpatialCollisions()
    if self.state == ProjectileState.DESTROYED then return end

    local px, py = self:getPosition()
    local x1 = self.prevX or px
    local y1 = self.prevY or py
    self.prevX = px
    self.prevY = py

    local projRadius = math.max(3, (self.config and (self.config.radius or self.config.size)) or 3)
    local World = package.loaded['src.core.world']

    -- 1. Colisión continua contra naves (distintas al propietario del proyectil)
    local Naves = package.loaded['src.entities.naves']
    if Naves and Naves.getAllShips then
        local ships = Naves.getAllShips()
        local ownerCtx = self.owner and self.owner.combatContext
        for i = 1, #ships do
            local ship = ships[i]
            if ship and ship ~= self.owner and ship.combatContext == ownerCtx and ship.x and ship.y and not (self.hitTargets and self.hitTargets[ship]) then
                local shipRadius = math.max(15, (ship.size or 14) * 1.15)
                local hitDist = shipRadius + projRadius
                local distSq, hitX, hitY = distSqPointToSegment(ship.x, ship.y, x1, y1, px, py)
                if distSq <= (hitDist * hitDist) then
                    if ship.takeDamage then
                        ship:takeDamage(self.damage, self.owner)
                    end
                    local angle = self.angle or self:getAngle()
                    local kb = 2.0 + (self.knockbackForce or 0) * 0.08
                    ship.dx = (ship.dx or 0) + math.cos(angle) * kb
                    ship.dy = (ship.dy or 0) + math.sin(angle) * kb

                    -- Efecto de ralentización criogénica
                    if self.config and self.config.statusEffect == "cryo_slow" then
                        ship.dx = (ship.dx or 0) * 0.65
                        ship.dy = (ship.dy or 0) * 0.65
                    end

                    -- Arco voltaico en cadena (chainArc)
                    if self.chainArc and self.chainArc > 0 then
                        local arcsLeft = self.chainArc
                        for j = 1, #ships do
                            local otherShip = ships[j]
                            if otherShip and otherShip ~= self.owner and otherShip ~= ship and otherShip.combatContext == ownerCtx and otherShip.x and otherShip.y then
                                local adx = otherShip.x - ship.x
                                local ady = otherShip.y - ship.y
                                if (adx * adx + ady * ady) <= (220 * 220) then
                                    if otherShip.takeDamage then
                                        otherShip:takeDamage(self.damage * 0.45, self.owner)
                                        ProjectileVFX.arc(self, ship.x, ship.y, otherShip.x, otherShip.y)
                                    end
                                    arcsLeft = arcsLeft - 1
                                    if arcsLeft <= 0 then break end
                                end
                            end
                        end
                    end

                    if ship.addImpactEffect then
                        ship:addImpactEffect(hitX, hitY, self.config and self.config.color)
                    elseif self.owner and self.owner.addImpactEffect then
                        self.owner:addImpactEffect(hitX, hitY, self.config and self.config.color)
                    end

                    if self.penetration then
                        ProjectileVFX.impact(self, hitX, hitY)
                        self.hitTargets = self.hitTargets or {}
                        self.hitTargets[ship] = true
                    elseif self.bouncesRemaining and self.bouncesRemaining > 0 then
                        ProjectileVFX.impact(self, hitX, hitY)
                        self.bouncesRemaining = self.bouncesRemaining - 1
                        self.hitTargets = self.hitTargets or {}
                        self.hitTargets[ship] = true
                        self.x, self.y = hitX, hitY
                        self.prevX, self.prevY = hitX, hitY
                        self.angle = (self.angle or 0) + math.pi + (math.random() - 0.5) * 0.7
                        local spd = self.speed or 320
                        self.vx = math.cos(self.angle) * spd
                        self.vy = math.sin(self.angle) * spd
                        if self.body then
                            self.body:setPosition(hitX, hitY)
                            self.body:setLinearVelocity(self.vx, self.vy)
                        end
                        return
                    else
                        self.x, self.y = hitX, hitY
                        if (self.explosion_radius or 0) <= 0 then
                            ProjectileVFX.impact(self, hitX, hitY)
                        end
                        self:destroy("ship_hit")
                        return
                    end
                end
            end
        end
    end

    -- 2. Colisión contra estructuras en subniveles si estamos en un subnivel activo
    local okSub, SubLevelManager = pcall(function() return require 'src.maps.systems.sublevel_manager' end)
    if okSub and SubLevelManager and SubLevelManager.getStatus then
        local status = SubLevelManager.getStatus()
        if status and status.active then
            local meta = status.current and status.current.meta
            if meta and meta.subworldId == "stations_debug" then
                local StationsDebugWorld = package.loaded['src.sublevels.stations_debug_world']
                if StationsDebugWorld and StationsDebugWorld.stations then
                    for i = 1, #StationsDebugWorld.stations do
                        local st = StationsDebugWorld.stations[i]
                        if st and st.x and st.y then
                            local stRadius = (st.size or 120) * 0.45
                            local hitDist = stRadius + projRadius
                            local distSq, hitX, hitY = distSqPointToSegment(st.x, st.y, x1, y1, px, py)
                            if distSq <= (hitDist * hitDist) then
                                local audio = World and ((World.getAudio and World.getAudio()) or World.get('audio'))
                                if audio and audio.play then
                                    audio.play("hit", { volume = 0.5, pitchVariation = 0.1 })
                                end
                                if self.owner and self.owner.addImpactEffect then
                                    self.owner:addImpactEffect(hitX, hitY, self.config and self.config.color)
                                end
                                self.x, self.y = hitX, hitY
                                self:destroy("station_hit")
                                return
                            end
                        end
                    end
                end
            end
            return
        end
    end

    local Map = package.loaded['src.maps.map']
    local MapConfig = package.loaded['src.maps.config.map_config']
    if not Map or not Map.getChunkNonBlocking or not MapConfig then return end

    local ws = MapConfig.chunk.worldScale or 1.0
    local tileSizeScaled = MapConfig.chunk.tileSize * ws
    local sizePixels = MapConfig.chunk.size * MapConfig.chunk.tileSize
    local strideScaled = (sizePixels + (MapConfig.chunk.spacing or 0)) * ws
    local baseSizes = (MapConfig.asteroids and MapConfig.asteroids.baseSizes) or {8, 15, 25}
    local sizeScale = (MapConfig.asteroids and MapConfig.asteroids.sizeScale) or 1.0

    local segMinX = math.min(x1, px)
    local segMaxX = math.max(x1, px)
    local segMinY = math.min(y1, py)
    local segMaxY = math.max(y1, py)

    local margin = projRadius + (baseSizes[3] or 25) * sizeScale * ws * 1.45
    local minCX = math.floor((segMinX - margin) / strideScaled)
    local maxCX = math.floor((segMaxX + margin) / strideScaled)
    local minCY = math.floor((segMinY - margin) / strideScaled)
    local maxCY = math.floor((segMaxY + margin) / strideScaled)

    local audio = World and ((World.getAudio and World.getAudio()) or World.get('audio'))

    -- 2A. Asteroides en la rejilla de tiles del chunk
    for cy = minCY, maxCY do
        for cx = minCX, maxCX do
            local chunk
            if self.collisionQuery and self.collisionQuery.map == Map then
                chunk = CollisionQuery.get(self.collisionQuery, cx, cy)
            else
                chunk = Map.getChunkNonBlocking(cx, cy)
            end
            if chunk and chunk.tiles then
                local chunkBaseX = cx * strideScaled
                local chunkBaseY = cy * strideScaled
                local chunkBaseTileX = cx * MapConfig.chunk.size
                local chunkBaseTileY = cy * MapConfig.chunk.size

                local minTX = math.max(0, math.floor((segMinX - margin - chunkBaseX) / tileSizeScaled))
                local maxTX = math.min(MapConfig.chunk.size - 1, math.ceil((segMaxX + margin - chunkBaseX) / tileSizeScaled))
                local minTY = math.max(0, math.floor((segMinY - margin - chunkBaseY) / tileSizeScaled))
                local maxTY = math.min(MapConfig.chunk.size - 1, math.ceil((segMaxY + margin - chunkBaseY) / tileSizeScaled))

                for ty = minTY, maxTY do
                    local row = chunk.tiles[ty]
                    if row then
                        local astY = chunkBaseY + ty * tileSizeScaled
                        local globalY = chunkBaseTileY + ty
                        for tx = minTX, maxTX do
                            local tileType = row[tx]
                            if tileType and tileType >= MapConfig.ObjectType.ASTEROID_SMALL and tileType <= MapConfig.ObjectType.ASTEROID_LARGE then
                                local astX = chunkBaseX + tx * tileSizeScaled
                                local globalX = chunkBaseTileX + tx
                                local baseSize = (baseSizes[tileType] or 15) * sizeScale * ws
                                local state = (globalX * 1103515245 + globalY * 12345 + tileType * 2654435761) % 4294967296
                                state = (state * 1664525 + 1013904223) % 4294967296
                                local r1 = state / 4294967296
                                local astRadius = baseSize * (0.8 + r1 * 0.4) * 1.05

                                local hitDist = astRadius + projRadius
                                local distSq, hitX, hitY = distSqPointToSegment(astX, astY, x1, y1, px, py)
                                if distSq <= (hitDist * hitDist) then
                                    chunk.asteroidHP = chunk.asteroidHP or {}
                                    local hpKey = ty * MapConfig.chunk.size + tx
                                    local defaultHP = (tileType == 1 and 25) or (tileType == 2 and 60) or 130
                                    local curHP = (chunk.asteroidHP[hpKey] or defaultHP) - (self.damage or 10)

                                    if curHP <= 0 then
                                        if tileType == MapConfig.ObjectType.ASTEROID_LARGE then
                                            row[tx] = MapConfig.ObjectType.ASTEROID_MEDIUM
                                            chunk.asteroidHP[hpKey] = 60
                                        else
                                            row[tx] = MapConfig.ObjectType.EMPTY
                                            chunk.asteroidHP[hpKey] = nil
                                        end
                                        if audio and audio.play then
                                            audio.play("explosion", { volume = 0.55, pitchVariation = 0.12 })
                                        end
                                    else
                                        chunk.asteroidHP[hpKey] = curHP
                                        if audio and audio.play then
                                            audio.play("hit", { volume = 0.45, pitchVariation = 0.12 })
                                        end
                                    end

                                    if self.owner and self.owner.addImpactEffect then
                                        self.owner:addImpactEffect(hitX, hitY, self.config and self.config.color)
                                    end
                                    self.x, self.y = hitX, hitY
                                    self:destroy("asteroid_hit")
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Reuse immutable solid candidates for the synchronous projectile batch.
    local query = self.collisionQuery or CollisionQuery.begin(Map)
    for _, obj in ipairs(CollisionQuery.solids(query, minCX, maxCX, minCY, maxCY, strideScaled, ws)) do
        local hitDist = obj.radius + projRadius
        local distSq, hitX, hitY = distSqPointToSegment(obj.x, obj.y, x1, y1, px, py)
        if distSq <= hitDist * hitDist then
            if audio and audio.play then audio.play("hit", {volume = .5, pitchVariation = .1}) end
            if self.owner and self.owner.addImpactEffect then
                self.owner:addImpactEffect(hitX, hitY, self.config and self.config.color)
            end
            self.x, self.y = hitX, hitY
            self:destroy("special_object_hit")
            return
        end
    end
end

--[[
    Verifica las condiciones para destruir el proyectil
--]]
function Projectile:checkDestructionConditions()
    -- TODO: Implementar verificaciones completas de destrucción
    
    -- Verificar tiempo de vida
    if self.age >= self.lifetime then
        self:destroy("lifetime_expired")
        return
    end
    
    -- Verificar distancia máxima
    if self.distance_traveled >= self.max_distance then
        self:destroy("max_distance_reached")
        return
    end
    
    -- Verificar si está fuera de los límites del mundo
    if self:isOutOfBounds() then
        self:destroy("out_of_bounds")
        return
    end
end

--[[
    Verifica si el proyectil está fuera de los límites del mundo
    @return: true si está fuera de límites
--]]
function Projectile:isOutOfBounds()
    local x, y = self:getPosition()
    local world_bounds = self.config.world_bounds
    
    if world_bounds then
        return x < world_bounds.min_x or x > world_bounds.max_x or
               y < world_bounds.min_y or y > world_bounds.max_y
    end
    
    return false
end

--[[
    Actualiza los efectos visuales del proyectil
    @param dt: tiempo delta
--]]
function Projectile:updateVisualEffects(dt)
    if self.vfxProfile then return end
    -- TODO: Implementar actualización de efectos visuales
    
    -- Actualizar partículas de estela
    self:updateTrailParticles(dt)
    
    -- Actualizar otros efectos visuales
    for i = #self.visual_effects, 1, -1 do
        local effect = self.visual_effects[i]
        effect:update(dt)
        
        if effect:isFinished() then
            table.remove(self.visual_effects, i)
        end
    end
end

--[[
    Actualiza las partículas de estela del proyectil
    @param dt: tiempo delta
--]]
function Projectile:updateTrailParticles(dt)
    -- TODO: Implementar sistema de partículas de estela
    -- Crear nuevas partículas en la posición actual
    -- Actualizar partículas existentes
    -- Eliminar partículas expiradas
end

--[[
    Aplica fuerzas especiales según el tipo de proyectil
    @param dt: tiempo delta
--]]
function Projectile:applySpecialForces(dt)
    -- TODO: Implementar fuerzas específicas por tipo
    
    if self.type == ProjectileType.MISSILE then
        -- Aplicar propulsión continua
        self:applyThrust(dt)
    elseif self.type == ProjectileType.PLASMA then
        -- Aplicar efectos de plasma
        self:applyPlasmaEffects(dt)
    end
    
    -- Aplicar resistencia del aire si está habilitada
    if PhysicsConfig.AIR_RESISTANCE.ENABLED then
        self:applyAirResistance(dt)
    end
end

--[[
    Aplica propulsión para misiles
    @param dt: tiempo delta
--]]
function Projectile:applyThrust(dt)
    -- TODO: Implementar propulsión de misiles
    if self.body and self.config.thrust_force then
        local thrust_x = math.cos(self.angle) * self.config.thrust_force
        local thrust_y = math.sin(self.angle) * self.config.thrust_force
        self.body:applyForce(thrust_x, thrust_y)
    end
end

--[[
    Aplica efectos específicos de plasma
    @param dt: tiempo delta
--]]
function Projectile:applyPlasmaEffects(dt)
    -- TODO: Implementar efectos de plasma
    -- Efectos de ionización, campo electromagnético, etc.
end

--[[
    Aplica resistencia del aire al proyectil
    @param dt: tiempo delta
--]]
function Projectile:applyAirResistance(dt)
    -- TODO: Implementar resistencia del aire realista
    if self.body then
        local vx, vy = self.body:getLinearVelocity()
        local speed = math.sqrt(vx * vx + vy * vy)
        
        if speed > 0 then
            local drag_force = PhysicsConfig.AIR_RESISTANCE.COEFFICIENT * speed * speed
            local drag_x = -(vx / speed) * drag_force
            local drag_y = -(vy / speed) * drag_force
            
            self.body:applyForce(drag_x, drag_y)
        end
    end
end

--[[
    Maneja la colisión del proyectil
    @param other: el otro objeto que colisionó
    @param contact: información del contacto
--]]
function Projectile:onCollision(other, contact)
    -- TODO: Implementar manejo completo de colisiones
    
    if self.state == ProjectileState.DESTROYED then
        return
    end
    
    -- Determinar tipo de colisión
    local collision_type = self:determineCollisionType(other)
    
    -- Manejar según el tipo de colisión
    if collision_type == "target" then
        self:handleTargetHit(other, contact)
    elseif collision_type == "environment" then
        self:handleEnvironmentHit(other, contact)
    elseif collision_type == "shield" then
        self:handleShieldHit(other, contact)
    end
end

--[[
    Determina el tipo de colisión basado en el otro objeto
    @param other: el otro objeto
    @return: tipo de colisión
--]]
function Projectile:determineCollisionType(other)
    -- TODO: Implementar lógica de determinación de tipo de colisión
    -- Analizar las categorías de colisión del otro objeto
    return "target" -- Placeholder
end

--[[
    Maneja el impacto contra un objetivo
    @param target: el objetivo impactado
    @param contact: información del contacto
--]]
function Projectile:handleTargetHit(target, contact)
    -- TODO: Implementar manejo de impacto contra objetivo
    
    -- Aplicar daño
    if target.takeDamage then
        target:takeDamage(self.damage, self)
    end
    
    -- Crear efectos de impacto
    self:createImpactEffects(contact)
    
    -- Destruir proyectil si no tiene penetración
    if not self.penetration then
        self:destroy("target_hit")
    end
end

--[[
    Maneja el impacto contra el entorno
    @param environment: el objeto del entorno
    @param contact: información del contacto
--]]
function Projectile:handleEnvironmentHit(environment, contact)
    -- TODO: Implementar manejo de impacto contra entorno
    
    -- Crear efectos de impacto
    self:createImpactEffects(contact)
    
    -- Destruir proyectil
    self:destroy("environment_hit")
end

--[[
    Maneja el impacto contra un escudo
    @param shield: el escudo impactado
    @param contact: información del contacto
--]]
function Projectile:handleShieldHit(shield, contact)
    -- TODO: Implementar manejo de impacto contra escudo
    
    -- Reducir energía del escudo
    if shield.absorbDamage then
        local absorbed = shield:absorbDamage(self.damage)
        
        -- Si el escudo no absorbió todo el daño, continuar
        if absorbed < self.damage then
            self.damage = self.damage - absorbed
            return -- Continuar con el proyectil
        end
    end
    
    -- Crear efectos de escudo
    self:createShieldEffects(contact)
    
    -- Destruir proyectil
    self:destroy("shield_hit")
end

--[[
    Crea efectos visuales de impacto
    @param contact: información del contacto
--]]
function Projectile:createImpactEffects(contact)
    -- TODO: Implementar creación de efectos de impacto
    local x, y = contact:getPositions()
    
    -- Crear partículas de impacto
    -- Crear flash de impacto
    -- Crear ondas de choque si es necesario
end

--[[
    Crea efectos visuales de escudo
    @param contact: información del contacto
--]]
function Projectile:createShieldEffects(contact)
    -- TODO: Implementar efectos específicos de escudo
    local x, y = contact:getPositions()
    
    -- Crear efectos de energía
    -- Crear ondas de escudo
    -- Crear chispas eléctricas
end

--[[
    Destruye el proyectil
    @param reason: razón de la destrucción
--]]
function Projectile:destroy(reason)
    if self.state == ProjectileState.DESTROYED then
        return
    end
    
    self.state = ProjectileState.DESTROYED
    
    -- Crear efectos de destrucción si es necesario
    if self.explosion_radius > 0 then
        self:createExplosion()
    elseif reason and reason ~= "ship_hit" and reason:match("_hit$") then
        local x, y = self:getPosition()
        ProjectileVFX.impact(self, x, y)
    end
    
    -- Limpiar cuerpo físico
    if self.body then
        self.body:destroy()
        self.body = nil
        self.fixture = nil
        self.shape = nil
    end
    
    -- Limpiar efectos visuales
    self:cleanupVisualEffects()
    
    print("[Projectile] Destruido por: " .. (reason or "unknown"))
end

--[[
    Crea una explosión en la posición del proyectil
--]]
function Projectile:createExplosion()
    local x, y = self:getPosition()
    local radius = tonumber(self.explosion_radius) or 0
    if radius <= 0 then return end
    ProjectileVFX.impact(self, x, y, radius)

    local Naves = package.loaded['src.entities.naves']
    if Naves and Naves.getAllShips then
        local ships = Naves.getAllShips()
        local ownerCtx = self.owner and self.owner.combatContext
        local rSq = radius * radius
        for i = 1, #ships do
            local s = ships[i]
            if s and s ~= self.owner and s.combatContext == ownerCtx and s.x and s.y then
                local dx = s.x - x
                local dy = s.y - y
                local dSq = dx * dx + dy * dy
                if dSq <= rSq then
                    local falloff = math.max(0.35, 1.0 - math.sqrt(dSq) / math.max(1, radius))
                    if s.takeDamage then
                        s:takeDamage((self.damage or 15) * 0.65 * falloff, self.owner)
                    end
                    if s.addImpactEffect then
                        s:addImpactEffect(s.x, s.y, self.config and self.config.color)
                    end
                end
            end
        end
    end
end

--[[
    Limpia todos los efectos visuales
--]]
function Projectile:cleanupVisualEffects()
    -- TODO: Implementar limpieza de efectos
    self.trail_particles = {}
    self.visual_effects = {}
end

--[[
    Renderiza el proyectil
--]]
function Projectile:draw()
    if self.state == ProjectileState.DESTROYED then
        return
    end
    
    -- Guardar todo el estado gráfico (colores, fuentes, blend modes, etc.)
    love.graphics.push("all")
    
    -- Obtener posición y rotación
    local x, y = self:getPosition()
    local angle = self:getAngle()
    
    -- Dibujar el proyectil según su tipo
    self:drawProjectileBody(x, y, angle)
    
    -- Dibujar efectos visuales
    self:drawVisualEffects()
    
    -- Dibujar debug si está habilitado
    if PhysicsConfig.DEBUG_DRAW_ENABLED then
        self:drawDebug(x, y, angle)
    end
    
    -- Restaurar todo el estado gráfico
    love.graphics.pop()
end

--[[
    Dibuja el cuerpo del proyectil
    @param x, y: posición
    @param angle: ángulo de rotación
--]]
function Projectile:drawProjectileBody(x, y, angle)
    -- TODO: Implementar renderizado específico por tipo
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Dibujar según el tipo
    if self.type == ProjectileType.LASER then
        self:drawLaser()
    elseif self.type == ProjectileType.MISSILE then
        self:drawMissile()
    elseif self.type == ProjectileType.PLASMA then
        self:drawPlasma()
    else
        self:drawBasicProjectile()
    end
    
    love.graphics.pop()
end

--[[
    Dibuja un proyectil básico
--]]
function Projectile:drawBasicProjectile()
    -- TODO: Implementar renderizado de proyectil básico
    love.graphics.setColor(1, 1, 0, 1) -- Amarillo
    love.graphics.circle("fill", 0, 0, 2)
    love.graphics.setColor(1, 1, 1, 1) -- Resetear color
end

--[[
    Dibuja un proyectil láser
--]]
function Projectile:drawLaser()
    -- TODO: Implementar renderizado de láser
    love.graphics.setColor(1, 0, 0, 1) -- Rojo
    love.graphics.rectangle("fill", -4, -1, 8, 2)
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Dibuja un misil
--]]
function Projectile:drawMissile()
    -- TODO: Implementar renderizado de misil
    love.graphics.setColor(0.8, 0.8, 0.8, 1) -- Gris
    love.graphics.rectangle("fill", -6, -2, 12, 4)
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Dibuja un proyectil de plasma
--]]
function Projectile:drawPlasma()
    -- TODO: Implementar renderizado de plasma
    love.graphics.setColor(0, 1, 1, 0.8) -- Cian transparente
    love.graphics.circle("fill", 0, 0, 3)
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Dibuja los efectos visuales del proyectil
--]]
function Projectile:drawVisualEffects()
    -- TODO: Implementar renderizado de efectos visuales
    
    -- Dibujar partículas de estela
    self:drawTrailParticles()
    
    -- Dibujar otros efectos
    for _, effect in ipairs(self.visual_effects) do
        effect:draw()
    end
end

--[[
    Dibuja las partículas de estela
--]]
function Projectile:drawTrailParticles()
    -- TODO: Implementar renderizado de estela
    for _, particle in ipairs(self.trail_particles) do
        particle:draw()
    end
end

--[[
    Dibuja información de debug
    @param x, y: posición
    @param angle: ángulo
--]]
function Projectile:drawDebug(x, y, angle)
    -- TODO: Implementar renderizado de debug
    
    -- Dibujar velocidad
    if PhysicsConfig.DEBUG_INFO.SHOW_VELOCITY and self.body then
        local vx, vy = self.body:getLinearVelocity()
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.line(x, y, x + vx * 0.1, y + vy * 0.1)
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Dibujar información de texto
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("Age: %.1f", self.age), x + 10, y - 20)
    love.graphics.print(string.format("Dist: %.1f", self.distance_traveled), x + 10, y - 5)
end

--[[
    Verifica si el proyectil está destruido
    @return: true si está destruido
--]]
function Projectile:isDestroyed()
    return self.state == ProjectileState.DESTROYED
end

--[[
    Obtiene la posición actual del proyectil
    @return: x, y
--]]
function Projectile:getPosition()
    if self.body then
        return self.body:getPosition()
    end
    return self.x or 0, self.y or 0
end

--[[
    Obtiene el ángulo actual del proyectil
    @return: ángulo en radianes
--]]
function Projectile:getAngle()
    if self.body then
        return self.body:getAngle()
    end
    return self.angle or 0
end

--[[
    Obtiene la velocidad actual del proyectil
    @return: vx, vy
--]]
function Projectile:getVelocity()
    if self.body then
        return self.body:getLinearVelocity()
    end
    return self.vx or self.initial_velocity_x or 0, self.vy or self.initial_velocity_y or 0
end

-- Exportar enumeraciones para uso externo
Projectile.State = ProjectileState
Projectile.Type = ProjectileType

return Projectile
