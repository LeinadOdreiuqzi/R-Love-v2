-- src/entities/weapon_system.lua
-- Sistema de Armas con Cambio Rápido tipo "Enter the Gungeon"

local WeaponSystem = {}
local ItemSystem = require 'src.item_systems.item_system'
local World = require 'src.core.world'

-- Configuración del sistema de armas
local WEAPON_CONFIG = {
    MAX_WEAPON_SLOTS = 9,  -- Máximo 9 armas equipadas simultáneamente (estilo Enter the Gungeon)
    QUICK_SWITCH_KEYS = {"1", "2", "3", "4", "5", "6", "7", "8", "9"},  -- Teclas para cambio rápido
    SCROLL_SWITCH = true,  -- Permitir cambio con rueda del mouse
    AUTO_RELOAD = true,    -- Recarga automática cuando se acaba la munición
    SHOW_WEAPON_HUD = true -- Mostrar HUD de armas
}

WeaponSystem.MAX_WEAPON_SLOTS = WEAPON_CONFIG.MAX_WEAPON_SLOTS
WeaponSystem.CONFIG = WEAPON_CONFIG

-- Armas por defecto para cada tipo de nave
local DEFAULT_WEAPONS = {
    EXPLORER = "basic_laser_pistol",        -- Arma versátil para exploración
    FIGHTER = "kinetic_assault_rifle",       -- Arma de combate de alta cadencia
    CARGO = "basic_laser_pistol",            -- Arma básica para defensa
    INTERCEPTOR = "kinetic_assault_rifle",   -- Ráfagas rápidas de asalto
    GUNSHIP = "heavy_plasma_cannon",         -- Artillería pesada de plasma
    SALVAGER = "energy_shotgun",             -- Dispersión industrial a corta distancia
    SENTINEL = "plasma_rifle",               -- Rifle de precisión autómata
    TITAN_EXCAVATOR = "energy_shotgun",      -- Defensas de racimo en Barcaza Madre
    ECLIPSE = "heavy_plasma_cannon",         -- Artillería pesada de Portanaves Eclipse
    DREADNOUGHT = "heavy_plasma_cannon",     -- Alias compatible
    ARK_MONOLITH = "plasma_rifle"            -- Haz de contención de Arca Centinela
}

-- Tipos de proyectiles por arma
local PROJECTILE_TYPES = {
    basic_laser_pistol = "basic_red_projectile",
    plasma_rifle = "plasma_projectile", 
    kinetic_assault_rifle = "kinetic_projectile",
    heavy_plasma_cannon = "heavy_plasma_projectile",
    energy_shotgun = "energy_shotgun_projectile",
    laser_basic = "basic_red_projectile",
    -- Agregar más tipos según se necesiten
}

function WeaponSystem:new(player)
    local weaponSystem = {}
    setmetatable(weaponSystem, self)
    self.__index = self
    
    -- Referencia al jugador
    weaponSystem.player = player
    
    -- Ya no usamos weaponSlots internos, ahora usamos el compartimento 'weapons' del InventorySystem
    -- Los slots de armas se manejan a través de player.inventory:getCompartment('weapons')
    
    -- Estado del sistema
    weaponSystem.currentSlot = 1
    weaponSystem.currentWeapon = nil
    weaponSystem.lastShotTime = 0
    weaponSystem.isReloading = false
    weaponSystem.reloadStartTime = 0
    
    -- Munición por arma (si aplica)
    weaponSystem.ammunition = {}
    
    -- Nivel de progresión de hardpoints (1 a 4) por id de arma
    weaponSystem.hardpointLevels = {}
    
    -- Efectos visuales por hardpoint
    weaponSystem.muzzleFlash = {
        active = false,
        duration = 0.1,
        timer = 0
    }
    weaponSystem.activeMuzzleFlashes = {}
    
    -- Input state para evitar múltiples activaciones
    weaponSystem.keyStates = {}
    for i = 1, WEAPON_CONFIG.MAX_WEAPON_SLOTS do
        weaponSystem.keyStates[tostring(i)] = false
    end
    weaponSystem.scrollState = 0
    
    -- Equipar arma por defecto en slot 1
    weaponSystem:equipDefaultWeapon()
    
    return weaponSystem
end

-- Equipar arma por defecto según el tipo de nave
function WeaponSystem:equipDefaultWeapon()
    if not self.player or not self.player.shipType then
        return false
    end
    
    local defaultWeaponId
    
    -- Intentar obtener el arma por defecto desde la configuración de la nave
    if self.player.shipSettings and self.player.shipSettings.defaultWeapon then
        defaultWeaponId = self.player.shipSettings.defaultWeapon
    else
        -- Fallback a la tabla DEFAULT_WEAPONS
        defaultWeaponId = DEFAULT_WEAPONS[self.player.shipType]
    end
    
    if not defaultWeaponId then
        -- Fallback final a arma básica
        defaultWeaponId = "basic_laser_pistol"
    end
    
    -- Obtener el arma desde el sistema de items
    local defaultWeapon = ItemSystem:getItem(defaultWeaponId)
    if defaultWeapon then
        -- Equipar en slot 1 (slot reservado para arma por defecto)
        self:equipWeapon(defaultWeapon, 1)
        return true
    end
    
    return false
end

-- Equipar arma en un slot específico
function WeaponSystem:equipWeapon(weaponItem, slot)
    if not weaponItem or not slot then
        -- Error: weaponItem o slot es nil
        return false
    end
    
    -- Verificar que el jugador tiene inventario
    if not self.player.inventory then
        return false
    end
    
    -- Usar el sistema de inventario para equipar el arma
    local success = self.player.inventory:addWeaponToSlot(weaponItem, slot)
    if not success then
        return false
    end
    
    -- Inicializar nivel de hardpoint del arma (1 por defecto)
    local hpLevel = math.max(1, math.min(4, tonumber(weaponItem.hardpointLevel or self.hardpointLevels[weaponItem.id]) or 1))
    weaponItem.hardpointLevel = hpLevel
    self.hardpointLevels[weaponItem.id] = hpLevel
    local slotEntry = self.player.inventory:getWeaponInSlot(slot)
    if slotEntry and slotEntry.data then
        slotEntry.data.hardpointLevel = hpLevel
    end

    -- Inicializar munición si es necesario
    if weaponItem.maxAmmo then
        self.ammunition[weaponItem.id] = weaponItem.maxAmmo
    end
    
    -- Si no hay arma actual, seleccionar esta
    if not self.currentWeapon then
        self:switchToSlot(slot)
    end
    
    -- Arma equipada
    return true
end

-- Obtener el nivel de hardpoint (1 a 4) de un slot o arma
function WeaponSystem:getWeaponHardpointLevel(slotOrWeapon)
    local w = nil
    if type(slotOrWeapon) == "table" then
        w = slotOrWeapon.data or slotOrWeapon
    elseif type(slotOrWeapon) == "number" and self.player and self.player.inventory then
        local entry = self.player.inventory:getWeaponInSlot(slotOrWeapon)
        w = entry and entry.data
    else
        w = self.currentWeapon
    end
    if not w then return 1 end
    return math.max(1, math.min(4, tonumber(w.hardpointLevel or self.hardpointLevels[w.id]) or 1))
end

-- Establecer el nivel de hardpoint (1 a 4) de un slot de arma
function WeaponSystem:setWeaponHardpointLevel(slot, level)
    slot = slot or self.currentSlot
    local clamped = math.max(1, math.min(4, math.floor(tonumber(level) or 1)))
    if not self.player or not self.player.inventory then return false end
    local entry = self.player.inventory:getWeaponInSlot(slot)
    if not entry or not entry.data then return false end
    entry.data.hardpointLevel = clamped
    self.hardpointLevels[entry.data.id] = clamped
    if self.currentSlot == slot and self.currentWeapon then
        self.currentWeapon.hardpointLevel = clamped
    end
    return true, clamped
end

-- Mejorar el nivel de hardpoints de un arma (ej. al recoger duplicado o mejora estilo Heavy Weapon)
function WeaponSystem:upgradeWeaponHardpointLevel(slot, delta)
    slot = slot or self.currentSlot
    local current = self:getWeaponHardpointLevel(slot)
    local nextLevel = math.max(1, math.min(4, current + (tonumber(delta) or 1)))
    return self:setWeaponHardpointLevel(slot, nextLevel)
end

-- Obtener los emisores físicos activos según el nivel de hardpoints (1 a 4)
function WeaponSystem:getActiveHardpointEmitters(weapon)
    weapon = weapon or self.currentWeapon
    local level = self:getWeaponHardpointLevel(weapon)
    local weaponId = weapon and weapon.id or "basic_laser_pistol"
    local isHeavyOrShotgun = (weaponId == "energy_shotgun" or weaponId == "heavy_plasma_cannon")

    if level == 1 then
        -- Nivel 1 (Estándar): Disparo central desde la proa de la nave (NOSE_CENTER)
        return {
            { name = "NOSE_CENTER", angleOffset = 0.0, damageScale = 1.0, speedMult = 1.0, scaleMult = 1.0, overcharged = false }
        }, 1
    elseif level == 2 then
        -- Nivel 2: Simetría bilateral desde ambos extremos lógicos (Ala Izquierda + Ala Derecha)
        return {
            { name = "WING_LEFT",  angleOffset = 0.0, damageScale = 0.85, speedMult = 1.0, scaleMult = 1.0, overcharged = false },
            { name = "WING_RIGHT", angleOffset = 0.0, damageScale = 0.85, speedMult = 1.0, scaleMult = 1.0, overcharged = false }
        }, 2
    elseif level == 3 then
        -- Nivel 3: Batería trifásica (Ambos extremos de las alas + Cañón Central de Proa)
        return {
            { name = "WING_LEFT",   angleOffset = -0.025, damageScale = 0.80, speedMult = 1.05, scaleMult = 1.05, overcharged = false },
            { name = "WING_RIGHT",  angleOffset =  0.025, damageScale = 0.80, speedMult = 1.05, scaleMult = 1.05, overcharged = false },
            { name = "NOSE_CENTER", angleOffset =  0.0,   damageScale = 0.90, speedMult = 1.08, scaleMult = 1.10, overcharged = false }
        }, 3
    else
        -- Nivel 4: Sobrecarga de proyectil + Emisores totales en extremos exteriores
        if isHeavyOrShotgun then
            return {
                { name = "WING_LEFT",   angleOffset = -0.04, damageScale = 1.10, speedMult = 1.20, scaleMult = 1.30, overcharged = true },
                { name = "WING_RIGHT",  angleOffset =  0.04, damageScale = 1.10, speedMult = 1.20, scaleMult = 1.30, overcharged = true },
                { name = "NOSE_CENTER", angleOffset =  0.0,  damageScale = 1.25, speedMult = 1.25, scaleMult = 1.35, overcharged = true }
            }, 4
        else
            return {
                { name = "WING_LEFT",    angleOffset = -0.015, damageScale = 0.90, speedMult = 1.20, scaleMult = 1.25, overcharged = true },
                { name = "WING_RIGHT",   angleOffset =  0.015, damageScale = 0.90, speedMult = 1.20, scaleMult = 1.25, overcharged = true },
                { name = "NOSE_CENTER",  angleOffset =  0.0,   damageScale = 1.15, speedMult = 1.25, scaleMult = 1.35, overcharged = true },
                { name = "OUTER_WING_L", angleOffset = -0.055, damageScale = 0.80, speedMult = 1.20, scaleMult = 1.20, overcharged = true },
                { name = "OUTER_WING_R", angleOffset =  0.055, damageScale = 0.80, speedMult = 1.20, scaleMult = 1.20, overcharged = true }
            }, 4
        end
    end
end

-- Desequipar arma de un slot
function WeaponSystem:unequipWeapon(slot)
    if not slot or slot < 1 or slot > WEAPON_CONFIG.MAX_WEAPON_SLOTS then
        return false
    end
    
    -- Verificar que el jugador tiene inventario
    if not self.player.inventory then
        return false
    end
    
    -- Obtener el arma antes de removerla
    local weapon = self.player.inventory:getWeaponInSlot(slot)
    if not weapon then
        return false
    end
    
    -- Si es el arma actual, cambiar a otra disponible
    if self.currentSlot == slot then
        self:switchToNextAvailableWeapon()
    end
    
    -- Remover del slot usando el sistema de inventario
    local removedWeapon = self.player.inventory:removeWeaponFromSlot(slot)
    
    -- Arma desequipada
    return removedWeapon ~= nil
end

-- Cambiar a un slot específico
function WeaponSystem:switchToSlot(slot)
    if not slot or slot < 1 or slot > WEAPON_CONFIG.MAX_WEAPON_SLOTS then
        return false
    end
    
    -- Verificar que el jugador tiene inventario
    if not self.player.inventory then
        return false
    end
    
    -- Obtener el arma del compartimento weapons
    local weaponItem = self.player.inventory:getWeaponInSlot(slot)
    if not weaponItem then
        -- No hay arma en slot
        return false
    end
    
    -- Cambiar arma actual
    self.currentSlot = slot
    self.currentWeapon = weaponItem.data  -- Usar .data ya que el compartimento almacena {data, quantity}
    self.isReloading = false  -- Cancelar recarga si estaba en proceso

    -- Inicializar munición si aún no existe (por ej., equipada vía drag-and-drop en inventario)
    if self.currentWeapon and self.currentWeapon.maxAmmo and self.ammunition[self.currentWeapon.id] == nil then
        self.ammunition[self.currentWeapon.id] = self.currentWeapon.maxAmmo
    end
    
    -- Notificar al WeaponHUD del cambio
    local WeaponHUD = require 'src.ui.weapon_hud'
    WeaponHUD:onWeaponSwitch(slot)
    
    local audio = (World.getAudio and World.getAudio()) or World.get('audio')
    if audio and audio.play then
        audio.play("ui_click", { pitch = 1.3, volume = 0.5 })
    end
    
    -- Cambiado a arma
    return true
end

-- Cambiar a la siguiente arma disponible
function WeaponSystem:switchToNextAvailableWeapon()
    if not self.player.inventory then
        return false
    end
    
    local startSlot = self.currentSlot
    local nextSlot = startSlot
    
    repeat
        nextSlot = nextSlot + 1
        if nextSlot > WEAPON_CONFIG.MAX_WEAPON_SLOTS then
            nextSlot = 1
        end
        
        if self.player.inventory:getWeaponInSlot(nextSlot) then
            return self:switchToSlot(nextSlot)
        end
    until nextSlot == startSlot
    
    -- No hay armas disponibles
    self.currentWeapon = nil
    self.currentSlot = 1
    return false
end

-- Cambiar a la anterior arma disponible
function WeaponSystem:switchToPreviousWeapon()
    if not self.player.inventory then
        return false
    end
    
    local startSlot = self.currentSlot
    local prevSlot = startSlot
    
    repeat
        prevSlot = prevSlot - 1
        if prevSlot < 1 then
            prevSlot = WEAPON_CONFIG.MAX_WEAPON_SLOTS
        end
        
        if self.player.inventory:getWeaponInSlot(prevSlot) then
            return self:switchToSlot(prevSlot)
        end
    until prevSlot == startSlot
    
    return false
end

-- Verificar si se puede disparar
function WeaponSystem:canShoot()
    if not self.currentWeapon then
        return false
    end
    
    if self.isReloading then
        return false
    end
    
    -- Verificar rate of fire (incluyendo modificador pasivo fire_rate)
    local currentTime = love.timer.getTime()
    local timeSinceLastShot = currentTime - self.lastShotTime
    local fireRate = self.currentWeapon.fireRate or 1.0
    local fireRateMod = self.player and self.player.passiveModifiers and self.player.passiveModifiers.fire_rate
    if type(fireRateMod) == "table" then
        fireRate = (fireRate + (fireRateMod.flat or 0)) * (1.0 + ((fireRateMod.percent or 0) / 100.0))
    elseif type(fireRateMod) == "number" then
        fireRate = fireRate * (1.0 + (fireRateMod > 1 and (fireRateMod / 100.0) or fireRateMod))
    end
    local shotInterval = 1.0 / math.max(0.05, fireRate)
    
    if timeSinceLastShot < shotInterval then
        return false
    end
    
    -- Verificar munición si aplica
    if self.currentWeapon.maxAmmo then
        local ammo = self.ammunition[self.currentWeapon.id] or 0
        if ammo <= 0 then
            -- Iniciar recarga automática si no está ya recargando
            if not self.isReloading then
                self:reload()
            end
            return false
        end
    end
    
    -- Verificar energía si aplica
    if self.currentWeapon.energyCost and self.player.stats then
        local currentEnergy = self.player.stats.energy and self.player.stats.energy.currentEnergy or 100
        if currentEnergy < self.currentWeapon.energyCost then
            return false
        end
    end
    
    return true
end

-- Disparar arma actual
function WeaponSystem:shoot(mouseX, mouseY, isWorldCoords)
    if not self:canShoot() then
        return false
    end
    
    -- Verificar que la nave no esté en EVA
    if self.player.isInEVA then
        return false
    end
    
    -- Obtener gestor de física (opcional si opera por cinemática desacoplada)
    local physMgr = World.get('physics')
    local box2dWorld = (physMgr and physMgr.getWorld and physMgr:getWorld()) or nil
    
    -- Convertir coordenadas del mouse a coordenadas del mundo (o usar directamente si isWorldCoords)
    local worldMouseX, worldMouseY
    if isWorldCoords then
        worldMouseX, worldMouseY = mouseX, mouseY
    else
        local camera = World.get('camera')
        if camera then
            worldMouseX, worldMouseY = camera:screenToWorld(mouseX, mouseY)
        else
            -- Fallback si no hay cámara
            worldMouseX, worldMouseY = mouseX, mouseY
        end
    end
    
    -- Posición de spawn del proyectil (frente de la nave)
    local dx = worldMouseX - self.player.x
    local dy = worldMouseY - self.player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Evitar división por cero
    if distance < 1 then
        return false
    end
    
    -- Normalizar dirección base hacia el objetivo
    dx = dx / distance
    dy = dy / distance
    local baseAngle = math.atan2(dy, dx)

    -- Calcular daño efectivo incluyendo modificador pasivo de daño
    local rawDamage = self.currentWeapon.damage or 15
    local baseDamage = 15
    if type(rawDamage) == "table" then
        local minD = tonumber(rawDamage.min or rawDamage[1]) or 15
        local maxD = tonumber(rawDamage.max or rawDamage[2]) or minD
        if maxD > minD then
            baseDamage = minD + math.random() * (maxD - minD)
        else
            baseDamage = minD
        end
    elseif type(rawDamage) == "number" then
        baseDamage = rawDamage
    end
    local dmgMod = self.player and self.player.passiveModifiers and self.player.passiveModifiers.damage
    local effectiveDamage = baseDamage
    if type(dmgMod) == "table" then
        effectiveDamage = (baseDamage + (dmgMod.flat or 0)) * (1.0 + ((dmgMod.percent or 0) / 100.0))
    elseif type(dmgMod) == "number" then
        effectiveDamage = baseDamage * (1.0 + (dmgMod > 1 and (dmgMod / 100.0) or dmgMod))
    end

    -- Balancear daño saliente de agentes IA para permitir duelos tácticos sin muertes instantáneas
    if self.player and self.player.isAI and not self.player.isPiloted then
        effectiveDamage = math.max(4, effectiveDamage * 0.34)
    end

    -- Si estamos dentro de un subnivel, aplicar límites de mundo a proyectiles
    local inSublevel = false
    local bounds = nil
    local ok, SubLevelManager = pcall(function() return require 'src.maps.systems.sublevel_manager' end)
    if ok and SubLevelManager and SubLevelManager.getStatus then
        local status = SubLevelManager.getStatus()
        if status and status.active then
            inSublevel = true
            bounds = { min_x = -20000, max_x = 20000, min_y = -20000, max_y = 20000 }
        end
    end

    -- Crear proyectiles desde los Hardpoints Físicos activos (Niveles 1 a 4 estilo Heavy Weapon)
    local weaponId = self.currentWeapon.id
    local projectileType = self.currentWeapon.projectileArchetype or PROJECTILE_TYPES[weaponId] or "basic_red_projectile"
    local ProjectileClass = require('src.physics.projectiles.types.' .. projectileType)
    local emitters, hpLevel = self:getActiveHardpointEmitters(self.currentWeapon)
    local projectilesCreated = 0

    self.shotCounter = (self.shotCounter or 0) + 1
    local synergyMods = self.currentWeapon.synergyMods or {}
    if synergyMods.damageMult then
        effectiveDamage = effectiveDamage * synergyMods.damageMult
    end

    -- Modificador pasivo de velocidad de proyectil (Acelerador Magnético, etc.)
    local projSpeedMod = self.player and self.player.passiveModifiers and self.player.passiveModifiers.projectile_speed
    local passiveSpeedMult = 1.0
    if type(projSpeedMod) == "table" then
        passiveSpeedMult = 1.0 + ((projSpeedMod.percent or 0) / 100.0)
    elseif type(projSpeedMod) == "number" then
        passiveSpeedMult = 1.0 + (projSpeedMod > 1 and (projSpeedMod / 100.0) or projSpeedMod)
    end
    local totalSpeedMult = passiveSpeedMult * (synergyMods.speedMult or 1.0)

    -- Evaluar refracción prismática (por pasiva o amplificación de Regla 3)
    local prismEveryN = synergyMods.prismEveryN
    if not prismEveryN and self.player and self.player.abilities then
        if tonumber(self.player.abilities.prism_extra_shot_every) then
            prismEveryN = tonumber(self.player.abilities.prism_extra_shot_every)
        end
    end
    local triggerPrismSplit = (prismEveryN and prismEveryN > 0 and (self.shotCounter % prismEveryN == 0))

    -- Evaluar arco voltaico por impacto
    local chainArcCount = (self.currentWeapon.chainArc or 0) + (synergyMods.chainArcBonus or 0)
    if self.player and self.player.abilities and tonumber(self.player.abilities.chain_lightning_on_hit) then
        chainArcCount = chainArcCount + tonumber(self.player.abilities.chain_lightning_on_hit)
    end

    for _, emitter in ipairs(emitters) do
        local hpWorldX, hpWorldY, hpLocalX, hpLocalY
        if self.player and self.player.getHardpointWorldPosition then
            hpWorldX, hpWorldY, hpLocalX, hpLocalY = self.player:getHardpointWorldPosition(emitter.name)
        else
            local spawnDistance = (self.player and self.player.size or 14) + 10
            hpWorldX = self.player.x + dx * spawnDistance
            hpWorldY = self.player.y + dy * spawnDistance
            hpLocalX, hpLocalY = 0, -spawnDistance
        end

        -- Calcular vector de convergencia desde este hardpoint hacia el objetivo
        local hdx = worldMouseX - hpWorldX
        local hdy = worldMouseY - hpWorldY
        local hDist = math.sqrt(hdx * hdx + hdy * hdy)
        local emitterAngle = baseAngle
        if distance > 42 and hDist > 8 then
            emitterAngle = math.atan2(hdy, hdx)
        end
        emitterAngle = emitterAngle + (emitter.angleOffset or 0)

        -- Empujar levemente el origen a lo largo del vector de tiro para limpiar el casco
        local spawnX = hpWorldX + math.cos(emitterAngle) * 5.0
        local spawnY = hpWorldY + math.sin(emitterAngle) * 5.0

        local emitterCustomConfig = {
            owner = self.player,
            weaponId = weaponId,
            damage = effectiveDamage * (emitter.damageScale or 1.0),
            hardpointOrigin = emitter.name,
            hardpointLevel = hpLevel,
            speedMultiplier = (emitter.speedMult or 1.0) * totalSpeedMult,
            scaleMultiplier = emitter.scaleMult or 1.0,
            overcharged = emitter.overcharged or false,
            penetration = emitter.overcharged or self.currentWeapon.penetration or synergyMods.forcePenetration or false,
            bounces = self.currentWeapon.bounces or 0,
            homingStrength = (self.currentWeapon.homingStrength or 0) + (synergyMods.homingBonus or 0),
            isBoomerang = self.currentWeapon.isBoomerang or false,
            clusterCount = self.currentWeapon.clusterCount or 0,
            chainArc = chainArcCount,
            explosion_radius = (self.currentWeapon.explosionRadius or 0) * (1.0 + (synergyMods.explosionRadiusBonus or 0)),
            knockbackForce = self.currentWeapon.knockbackForce or 0,
            graviticPull = self.currentWeapon.graviticPull or 0,
            statusEffect = self.currentWeapon.statusEffect or (synergyMods.addCryoSlow and "cryo_slow") or nil,
            voidDetonator = self.currentWeapon.voidDetonator or false,
            color = self.currentWeapon.color
        }
        if inSublevel and bounds then
            emitterCustomConfig.world_bounds = bounds
        end

        -- Registrar fogonazo (muzzle flash) localizado en las coordenadas del hardpoint
        self.activeMuzzleFlashes = self.activeMuzzleFlashes or {}
        table.insert(self.activeMuzzleFlashes, {
            name = emitter.name,
            lx = hpLocalX,
            ly = hpLocalY,
            timer = 0,
            duration = 0.09,
            level = hpLevel,
            overcharged = emitter.overcharged or false
        })

        local basePelletCount = tonumber(self.currentWeapon.projectileCount) or ((weaponId == "energy_shotgun") and 5 or 1)
        if #emitters > 1 and basePelletCount >= 5 then
            basePelletCount = math.max(3, basePelletCount - 1)
        end
        local spreadAngle = tonumber(self.currentWeapon.spreadAngle) or ((basePelletCount > 1) and (math.pi / 6) or 0.0)

        if basePelletCount > 1 then
            for i = 1, basePelletCount do
                local spreadOffset = (i - (basePelletCount + 1) / 2) / math.max(1, basePelletCount - 1)
                local jitter = (spreadAngle > 0.2) and ((math.random() - 0.5) * 0.06) or 0
                local pelletAngle = emitterAngle + spreadOffset * spreadAngle + jitter
                local projectile = ProjectileClass.new(box2dWorld, spawnX, spawnY, pelletAngle, nil, emitterCustomConfig)
                if projectile then
                    if physMgr and physMgr.addProjectile then
                        physMgr:addProjectile(projectile)
                    end
                    if not self.player.projectiles then
                        self.player.projectiles = {}
                    end
                    table.insert(self.player.projectiles, projectile)
                    projectilesCreated = projectilesCreated + 1
                end
            end
        else
            local singleAngle = emitterAngle + ((spreadAngle > 0) and ((math.random() - 0.5) * spreadAngle) or 0)
            local projectile = ProjectileClass.new(box2dWorld, spawnX, spawnY, singleAngle, nil, emitterCustomConfig)
            if projectile then
                if physMgr and physMgr.addProjectile then
                    physMgr:addProjectile(projectile)
                end
                if not self.player.projectiles then
                    self.player.projectiles = {}
                end
                table.insert(self.player.projectiles, projectile)
                projectilesCreated = projectilesCreated + 1
            end
        end

        -- Proyectiles adicionales por Lente de Refracción Prismática / Matriz de Tormenta Refractada
        if triggerPrismSplit then
            for _, offsetRad in ipairs({ -0.14, 0.14 }) do
                local splitConfig = {}
                for k, v in pairs(emitterCustomConfig) do splitConfig[k] = v end
                splitConfig.damage = (emitterCustomConfig.damage or 10) * 0.65
                local splitProj = ProjectileClass.new(box2dWorld, spawnX, spawnY, emitterAngle + offsetRad, nil, splitConfig)
                if splitProj then
                    if physMgr and physMgr.addProjectile then
                        physMgr:addProjectile(splitProj)
                    end
                    if not self.player.projectiles then
                        self.player.projectiles = {}
                    end
                    table.insert(self.player.projectiles, splitProj)
                    projectilesCreated = projectilesCreated + 1
                end
            end
        end
    end

    -- Si se crearon proyectiles exitosamente
    if projectilesCreated > 0 then
        self.muzzleFlash.active = true
        self.muzzleFlash.timer = 0

        -- Aplicar micro-retroceso físico diegético (kickback) según calibre y número de emisores
        if self.player and not self.player.hyperTravelEnabled then
            local baseKick = (weaponId == "heavy_plasma_cannon" or weaponId == "energy_shotgun") and 1.45 or 0.55
            local kickScale = baseKick * (0.75 + 0.25 * #emitters)
            if self.player.isAI and not self.player.isPiloted then
                kickScale = kickScale * 0.35
            end
            self.player.dx = (self.player.dx or 0) - dx * kickScale
            self.player.dy = (self.player.dy or 0) - dy * kickScale
        end
        -- Actualizar tiempo del último disparo
        self.lastShotTime = love.timer.getTime()
        if self.player then
            self.player._lastShotTimestamp = self.lastShotTime
        end
        
        -- Audio de disparo según tipo de arma (con atenuación espacial para naves del ecosistema)
        local audio = (World.getAudio and World.getAudio()) or World.get('audio')
        if audio and audio.play then
            local volMult = 1.0
            local mainPlayer = World.getPlayer and World.getPlayer() or World.get('player')
            if mainPlayer and self.player and self.player ~= mainPlayer then
                local distSq = (self.player.x - mainPlayer.x)^2 + (self.player.y - mainPlayer.y)^2
                local maxHearDistSq = 1800 * 1800
                if distSq > maxHearDistSq then
                    volMult = 0
                else
                    volMult = math.max(0.1, 1.0 - math.sqrt(distSq) / 1800) * 0.65
                end
            end
            if volMult > 0.05 then
                if weaponId == "energy_shotgun" then
                    audio.play("shotgun", { pitchVariation = 0.08, volume = 0.85 * volMult })
                elseif weaponId == "heavy_plasma_cannon" or weaponId == "plasma_rifle" then
                    audio.play("plasma", { pitchVariation = 0.06, volume = 0.9 * volMult })
                else
                    audio.play("laser", { pitchVariation = 0.06, volume = 0.8 * volMult })
                end
            end
        end
        
        -- Consumir munición si aplica
        if self.currentWeapon.maxAmmo then
            self.ammunition[self.currentWeapon.id] = (self.ammunition[self.currentWeapon.id] or 0) - 1
            
            -- Verificar si se agotó la munición e iniciar recarga automática
            if self.ammunition[self.currentWeapon.id] <= 0 and not self.isReloading then
                self:reload()
            end
        end
        
        -- Proyectiles disparados
        return true
    else
        -- Error: Could not create projectiles
        return false
    end
end

-- Calcular tiempo de recarga efectivo (aplicando modificador pasivo reload_speed)
function WeaponSystem:getEffectiveReloadTime(weapon)
    weapon = weapon or self.currentWeapon
    local baseReload = (weapon and weapon.reloadTime) or 2.0
    local reloadMod = self.player and self.player.passiveModifiers and self.player.passiveModifiers.reload_speed
    local reloadMult = 1.0
    if type(reloadMod) == "table" then
        reloadMult = 1.0 + ((reloadMod.percent or 0) / 100.0)
    elseif type(reloadMod) == "number" then
        reloadMult = 1.0 + (reloadMod > 1 and (reloadMod / 100.0) or reloadMod)
    end
    return baseReload / math.max(0.25, reloadMult)
end

-- Recargar arma actual
function WeaponSystem:reload()
    if not self.currentWeapon or not self.currentWeapon.maxAmmo then
        return false
    end
    
    if self.isReloading then
        return false
    end
    
    local currentAmmo = self.ammunition[self.currentWeapon.id] or 0
    if currentAmmo >= self.currentWeapon.maxAmmo then
        return false  -- Ya está llena
    end
    
    -- Si el arma es un Detonador de Agujas de Vacío (voidDetonator), detonar proyectiles activos al recargar
    if self.currentWeapon.voidDetonator and self.player and self.player.projectiles then
        for i = #self.player.projectiles, 1, -1 do
            local proj = self.player.projectiles[i]
            if proj and proj.config and proj.config.voidDetonator and proj.state == "active" then
                proj.explosion_radius = math.max(proj.explosion_radius or 0, 28)
                proj.damage = (proj.damage or 14) * 1.45
                proj:destroy("void_detonation")
            end
        end
    end

    -- Iniciar recarga
    self.isReloading = true
    self.reloadStartTime = love.timer.getTime()
    
    local audio = (World.getAudio and World.getAudio()) or World.get('audio')
    if audio and audio.play then
        audio.play("item_equip", { pitch = 1.25, volume = 0.65 })
    end
    
    -- Recargando arma
    return true
end

-- Actualizar sistema de armas
function WeaponSystem:update(dt)
    -- Sincronizar currentWeapon por si ocurrió una evolución en el slot activo
    if self.player and self.player.inventory then
        local activeEntry = self.player.inventory:getWeaponInSlot(self.currentSlot)
        if activeEntry and activeEntry.data and activeEntry.data ~= self.currentWeapon then
            self.currentWeapon = activeEntry.data
            if self.currentWeapon.maxAmmo and self.ammunition[self.currentWeapon.id] == nil then
                self.ammunition[self.currentWeapon.id] = self.currentWeapon.maxAmmo
            end
        elseif not activeEntry and self.currentWeapon then
            self:switchToNextAvailableWeapon()
        end
    end

    -- Actualizar muzzle flash general
    if self.muzzleFlash.active then
        self.muzzleFlash.timer = self.muzzleFlash.timer + dt
        if self.muzzleFlash.timer >= self.muzzleFlash.duration then
            self.muzzleFlash.active = false
        end
    end

    -- Actualizar fogonazos localizados por hardpoint
    if self.activeMuzzleFlashes and #self.activeMuzzleFlashes > 0 then
        for i = #self.activeMuzzleFlashes, 1, -1 do
            local mf = self.activeMuzzleFlashes[i]
            mf.timer = (mf.timer or 0) + dt
            if mf.timer >= (mf.duration or 0.09) then
                table.remove(self.activeMuzzleFlashes, i)
            end
        end
    end
    
    -- Actualizar recarga
    if self.isReloading and self.currentWeapon then
        local reloadTime = self:getEffectiveReloadTime(self.currentWeapon)
        local currentTime = love.timer.getTime()
        
        if currentTime - self.reloadStartTime >= reloadTime then
            -- Completar recarga
            self.ammunition[self.currentWeapon.id] = self.currentWeapon.maxAmmo
            self.isReloading = false
            -- Recarga completada
        end
    end

    -- Pasiva: Funda de Recarga Inercial (holster_auto_reload) — recarga armas guardadas tras 2.5s
    if self.player and self.player.abilities and self.player.abilities.holster_auto_reload and self.player.inventory then
        self.holsterTimers = self.holsterTimers or {}
        for slot = 1, WEAPON_CONFIG.MAX_WEAPON_SLOTS do
            local entry = self.player.inventory:getWeaponInSlot(slot)
            if slot ~= self.currentSlot and entry and entry.data and entry.data.maxAmmo then
                local wid = entry.data.id
                local curAmmo = self.ammunition[wid]
                if curAmmo == nil then
                    self.ammunition[wid] = entry.data.maxAmmo
                elseif curAmmo < entry.data.maxAmmo then
                    self.holsterTimers[wid] = (self.holsterTimers[wid] or 0) + dt
                    if self.holsterTimers[wid] >= 2.5 then
                        self.ammunition[wid] = entry.data.maxAmmo
                        self.holsterTimers[wid] = 0
                    end
                else
                    self.holsterTimers[wid] = 0
                end
            elseif entry and entry.data then
                self.holsterTimers[entry.data.id] = 0
            end
        end
    end
    
    -- Manejar input de cambio de armas
    self:handleWeaponSwitchInput()
end

-- Manejar input para cambio de armas
function WeaponSystem:handleWeaponSwitchInput()
    if self.player and self.player.isAI and not self.player.isPiloted then
        return
    end
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        return
    end
    local HUD = package.loaded['src.ui.hud']
    if HUD and HUD.isSeedInputVisible and HUD.isSeedInputVisible() then
        return
    end

    -- Cambio con teclas numéricas (1 a 9)
    for i = 1, WEAPON_CONFIG.MAX_WEAPON_SLOTS do
        local key = tostring(i)
        local isPressed = love.keyboard.isDown(key)
        
        if isPressed and not self.keyStates[key] then
            self:switchToSlot(i)
        end
        
        self.keyStates[key] = isPressed
    end
    
    -- Cambio con rueda del mouse (si está habilitado)
    if WEAPON_CONFIG.SCROLL_SWITCH then
        -- Esto se manejará en el evento wheelmoved
    end
end

-- Manejar rueda del mouse para cambio de armas
function WeaponSystem:wheelmoved(x, y)
    if not WEAPON_CONFIG.SCROLL_SWITCH then
        return
    end
    
    if y > 0 then
        self:switchToNextAvailableWeapon()
    elseif y < 0 then
        self:switchToPreviousWeapon()
    end
end

-- Obtener información del arma actual
function WeaponSystem:getCurrentWeaponInfo()
    if not self.currentWeapon then
        return nil
    end
    
    local emitters, hpLevel = self:getActiveHardpointEmitters(self.currentWeapon)
    local info = {
        name = self.currentWeapon.name,
        slot = self.currentSlot,
        damage = self.currentWeapon.damage,
        fireRate = self.currentWeapon.fireRate,
        hardpointLevel = hpLevel,
        emitterCount = #emitters,
        ammo = nil,
        maxAmmo = self.currentWeapon.maxAmmo,
        isReloading = self.isReloading,
        reloadProgress = 0
    }
    
    -- Calcular munición actual
    if self.currentWeapon.maxAmmo then
        info.ammo = self.ammunition[self.currentWeapon.id] or 0
    end
    
    -- Calcular progreso de recarga
    if self.isReloading then
        local reloadTime = self.currentWeapon.reloadTime or 2.0
        local elapsed = love.timer.getTime() - self.reloadStartTime
        info.reloadProgress = math.min(elapsed / reloadTime, 1.0)
    end
    
    return info
end

-- Obtener todas las armas equipadas
function WeaponSystem:getEquippedWeapons()
    local weapons = {}
    
    if not self.player.inventory then
        return weapons
    end
    
    for slot = 1, WEAPON_CONFIG.MAX_WEAPON_SLOTS do
        local weaponItem = self.player.inventory:getWeaponInSlot(slot)
        if weaponItem then
            weapons[slot] = {
                weapon = weaponItem.data,
                ammo = self.ammunition[weaponItem.data.id],
                hardpointLevel = self:getWeaponHardpointLevel(weaponItem.data),
                isCurrent = (slot == self.currentSlot)
            }
        end
    end
    return weapons
end

-- Obtener cantidad de armas actualmente equipadas en los 9 slots
function WeaponSystem:getEquippedWeaponCount()
    if not self.player or not self.player.inventory then
        return 0
    end
    local count = 0
    for slot = 1, WEAPON_CONFIG.MAX_WEAPON_SLOTS do
        if self.player.inventory:getWeaponInSlot(slot) then
            count = count + 1
        end
    end
    return count
end

-- Auto-equipar arma desde inventario
function WeaponSystem:autoEquipFromInventory()
    if not self.player.inventory then
        return false
    end
    
    -- Obtener el compartimento ship (inventario principal)
    local shipComp = self.player.inventory:getCompartment('ship')
    if not shipComp then
        return false
    end
    
    -- Buscar armas en el inventario principal
    for i = 1, shipComp.maxSlots do
        local item = shipComp.items[i]
        if item and item.data and item.data.category == ItemSystem.CATEGORIES.EQUIPABLE and 
           item.data.equipType == ItemSystem.EQUIPABLE_TYPES.WEAPON then
            
            -- Buscar slot libre en el compartimento weapons (empezar desde slot 2)
            for slot = 2, WEAPON_CONFIG.MAX_WEAPON_SLOTS do
                if not self.player.inventory:getWeaponInSlot(slot) then
                    -- Equipar el arma
                    if self:equipWeapon(item.data, slot) then
                        -- Remover del inventario principal
                        shipComp.items[i] = nil
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

return WeaponSystem