-- src/entities/weapon_system.lua
-- Sistema de Armas con Cambio Rápido tipo "Enter the Gungeon"

local WeaponSystem = {}
local ItemSystem = require 'src.item_systems.item_system'

-- Configuración del sistema de armas
local WEAPON_CONFIG = {
    MAX_WEAPON_SLOTS = 4,  -- Máximo 4 armas equipadas simultáneamente
    QUICK_SWITCH_KEYS = {"1", "2", "3", "4"},  -- Teclas para cambio rápido
    SCROLL_SWITCH = true,  -- Permitir cambio con rueda del mouse
    AUTO_RELOAD = true,    -- Recarga automática cuando se acaba la munición
    SHOW_WEAPON_HUD = true -- Mostrar HUD de armas
}

-- Armas por defecto para cada tipo de nave
local DEFAULT_WEAPONS = {
    EXPLORER = "basic_laser_pistol",  -- Arma versátil para exploración
    FIGHTER = "kinetic_assault_rifle", -- Arma de combate de alta cadencia
    CARGO = "basic_laser_pistol"      -- Arma básica para defensa
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
    
    -- Efectos visuales
    weaponSystem.muzzleFlash = {
        active = false,
        duration = 0.1,
        timer = 0
    }
    
    -- Input state para evitar múltiples activaciones
    weaponSystem.keyStates = {}
    for i = 1, 4 do
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
    
    -- Notificar al WeaponHUD del cambio
    local WeaponHUD = require 'src.ui.weapon_hud'
    WeaponHUD:onWeaponSwitch(slot)
    
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
    
    -- Verificar rate of fire
    local currentTime = love.timer.getTime()
    local timeSinceLastShot = currentTime - self.lastShotTime
    local fireRate = self.currentWeapon.fireRate or 1.0
    local shotInterval = 1.0 / fireRate
    
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
function WeaponSystem:shoot(mouseX, mouseY)
    if not self:canShoot() then
        return false
    end
    
    -- Verificar que la nave no esté en EVA
    if self.player.isInEVA then
        return false
    end
    
    -- Verificar que tenemos acceso al mundo de física
    if not _G.physicsManager or not _G.physicsManager:getWorld() then
        -- Error: Physics world not available
        return false
    end
    
    -- Convertir coordenadas del mouse a coordenadas del mundo
    local worldMouseX, worldMouseY
    if _G.camera then
        worldMouseX, worldMouseY = _G.camera:screenToWorld(mouseX, mouseY)
    else
        -- Fallback si no hay cámara
        worldMouseX, worldMouseY = mouseX, mouseY
    end
    
    -- Posición de spawn del proyectil (frente de la nave)
    local dx = worldMouseX - self.player.x
    local dy = worldMouseY - self.player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Evitar división por cero
    if distance < 1 then
        return false
    end
    
    -- Normalizar dirección para calcular posición de spawn
    dx = dx / distance
    dy = dy / distance
    
    local spawnDistance = self.player.size + 10 -- Un poco adelante de la nave
    local spawnX = self.player.x + dx * spawnDistance
    local spawnY = self.player.y + dy * spawnDistance
    
    -- Calcular ángulo de disparo
    local angle = math.atan2(dy, dx)
    
    -- Crear el proyectil usando el tipo del arma actual
    local weaponId = self.currentWeapon.id
    local projectileType = PROJECTILE_TYPES[weaponId] or "basic_red_projectile"
    local ProjectileClass = require('src.physics.projectiles.types.' .. projectileType)
    
    local projectilesCreated = 0
    
    -- Verificar si es una escopeta de energía para crear múltiples proyectiles
    if weaponId == "energy_shotgun" then
        -- Configuración de dispersión para escopeta
        local pelletCount = 5 -- Número de proyectiles por disparo
        local spreadAngle = math.pi / 6 -- 30 grados de dispersión total
        
        for i = 1, pelletCount do
            -- Calcular ángulo de dispersión para cada proyectil
            local spreadOffset = (i - (pelletCount + 1) / 2) / pelletCount
            local pelletAngle = angle + spreadOffset * spreadAngle
            
            -- Añadir variación aleatoria pequeña
            pelletAngle = pelletAngle + (math.random() - 0.5) * 0.1
            
            -- Crear proyectil individual
            local projectile = ProjectileClass.new(_G.physicsManager:getWorld(), spawnX, spawnY, pelletAngle)
            
            -- Agregar el proyectil al sistema de física
            if projectile and _G.physicsManager.addProjectile then
                _G.physicsManager:addProjectile(projectile)
                
                -- Almacenar el proyectil para actualizaciones y renderizado
                if not self.player.projectiles then
                    self.player.projectiles = {}
                end
                table.insert(self.player.projectiles, projectile)
                projectilesCreated = projectilesCreated + 1
            end
        end
    else
        -- Disparo normal para otras armas
        local projectile = ProjectileClass.new(_G.physicsManager:getWorld(), spawnX, spawnY, angle)
        
        -- Agregar el proyectil al sistema de física
        if projectile and _G.physicsManager.addProjectile then
            _G.physicsManager:addProjectile(projectile)
            
            -- Almacenar el proyectil para actualizaciones y renderizado
            if not self.player.projectiles then
                self.player.projectiles = {}
            end
            table.insert(self.player.projectiles, projectile)
            projectilesCreated = 1
        end
    end
    
    -- Si se crearon proyectiles exitosamente
    if projectilesCreated > 0 then
        -- Actualizar tiempo del último disparo
        self.lastShotTime = love.timer.getTime()
        
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
    
    -- Iniciar recarga
    self.isReloading = true
    self.reloadStartTime = love.timer.getTime()
    
    -- Recargando arma
    return true
end

-- Actualizar sistema de armas
function WeaponSystem:update(dt)
    -- Actualizar muzzle flash
    if self.muzzleFlash.active then
        self.muzzleFlash.timer = self.muzzleFlash.timer + dt
        if self.muzzleFlash.timer >= self.muzzleFlash.duration then
            self.muzzleFlash.active = false
        end
    end
    
    -- Actualizar recarga
    if self.isReloading and self.currentWeapon then
        local reloadTime = self.currentWeapon.reloadTime or 2.0
        local currentTime = love.timer.getTime()
        
        if currentTime - self.reloadStartTime >= reloadTime then
            -- Completar recarga
            self.ammunition[self.currentWeapon.id] = self.currentWeapon.maxAmmo
            self.isReloading = false
            -- Recarga completada
        end
    end
    
    -- Manejar input de cambio de armas
    self:handleWeaponSwitchInput()
end

-- Manejar input para cambio de armas
function WeaponSystem:handleWeaponSwitchInput()
    -- Cambio con teclas numéricas
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
    
    local info = {
        name = self.currentWeapon.name,
        slot = self.currentSlot,
        damage = self.currentWeapon.damage,
        fireRate = self.currentWeapon.fireRate,
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
                isCurrent = (slot == self.currentSlot)
            }
        end
    end
    return weapons
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