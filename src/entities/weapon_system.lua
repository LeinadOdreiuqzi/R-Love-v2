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

-- Tipos de proyectiles por arma
local PROJECTILE_TYPES = {
    basic_laser_pistol = "basic_red_projectile",
    plasma_rifle = "plasma_projectile", 
    combat_knife = "melee_projectile",
    laser_basic = "basic_red_projectile",
    -- Agregar más tipos según se necesiten
}

function WeaponSystem:new(player)
    local weaponSystem = {}
    setmetatable(weaponSystem, self)
    self.__index = self
    
    -- Referencia al jugador
    weaponSystem.player = player
    
    -- Slots de armas (máximo 4 armas equipadas)
    weaponSystem.weaponSlots = {
        [1] = nil,  -- Slot 1 - Tecla "1"
        [2] = nil,  -- Slot 2 - Tecla "2" 
        [3] = nil,  -- Slot 3 - Tecla "3"
        [4] = nil   -- Slot 4 - Tecla "4"
    }
    
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
    
    return weaponSystem
end

-- Equipar arma en un slot específico
function WeaponSystem:equipWeapon(weaponItem, slot)
    if not weaponItem or not slot then
        return false
    end
    
    -- Validar que es un arma
    if weaponItem.category ~= ItemSystem.CATEGORIES.EQUIPABLE or 
       weaponItem.equipType ~= ItemSystem.EQUIPABLE_TYPES.WEAPON then
        print("[WEAPON_SYSTEM] Error: Item no es un arma válida")
        return false
    end
    
    -- Validar slot
    if slot < 1 or slot > WEAPON_CONFIG.MAX_WEAPON_SLOTS then
        print("[WEAPON_SYSTEM] Error: Slot inválido: " .. slot)
        return false
    end
    
    -- Desequipar arma anterior si existe
    if self.weaponSlots[slot] then
        self:unequipWeapon(slot)
    end
    
    -- Equipar nueva arma
    self.weaponSlots[slot] = weaponItem
    
    -- Inicializar munición si es necesario
    if weaponItem.maxAmmo then
        self.ammunition[weaponItem.id] = weaponItem.maxAmmo
    end
    
    -- Si no hay arma actual, seleccionar esta
    if not self.currentWeapon then
        self:switchToSlot(slot)
    end
    
    print("[WEAPON_SYSTEM] Arma equipada: " .. weaponItem.name .. " en slot " .. slot)
    return true
end

-- Desequipar arma de un slot
function WeaponSystem:unequipWeapon(slot)
    if not slot or slot < 1 or slot > WEAPON_CONFIG.MAX_WEAPON_SLOTS then
        return false
    end
    
    local weapon = self.weaponSlots[slot]
    if not weapon then
        return false
    end
    
    -- Si es el arma actual, cambiar a otra disponible
    if self.currentSlot == slot then
        self:switchToNextAvailableWeapon()
    end
    
    -- Remover del slot
    self.weaponSlots[slot] = nil
    
    print("[WEAPON_SYSTEM] Arma desequipada: " .. weapon.name .. " del slot " .. slot)
    return true
end

-- Cambiar a un slot específico
function WeaponSystem:switchToSlot(slot)
    if not slot or slot < 1 or slot > WEAPON_CONFIG.MAX_WEAPON_SLOTS then
        return false
    end
    
    local weapon = self.weaponSlots[slot]
    if not weapon then
        print("[WEAPON_SYSTEM] No hay arma en slot " .. slot)
        return false
    end
    
    -- Cambiar arma actual
    self.currentSlot = slot
    self.currentWeapon = weapon
    self.isReloading = false  -- Cancelar recarga si estaba en proceso
    
    -- Notificar al WeaponHUD del cambio
    local WeaponHUD = require 'src.ui.weapon_hud'
    WeaponHUD:onWeaponSwitch(slot)
    
    print("[WEAPON_SYSTEM] Cambiado a: " .. weapon.name .. " (Slot " .. slot .. ")")
    return true
end

-- Cambiar a la siguiente arma disponible
function WeaponSystem:switchToNextAvailableWeapon()
    local startSlot = self.currentSlot
    local nextSlot = startSlot
    
    repeat
        nextSlot = nextSlot + 1
        if nextSlot > WEAPON_CONFIG.MAX_WEAPON_SLOTS then
            nextSlot = 1
        end
        
        if self.weaponSlots[nextSlot] then
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
    local startSlot = self.currentSlot
    local prevSlot = startSlot
    
    repeat
        prevSlot = prevSlot - 1
        if prevSlot < 1 then
            prevSlot = WEAPON_CONFIG.MAX_WEAPON_SLOTS
        end
        
        if self.weaponSlots[prevSlot] then
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
    
    -- Usar el método de disparo existente del jugador pero con parámetros del arma actual
    local success = self.player:shoot(mouseX, mouseY)
    
    if success then
        -- Actualizar tiempo del último disparo
        self.lastShotTime = love.timer.getTime()
        
        -- Consumir munición si aplica
        if self.currentWeapon.maxAmmo then
            self.ammunition[self.currentWeapon.id] = (self.ammunition[self.currentWeapon.id] or 0) - 1
        end
        
        -- Consumir energía si aplica
        if self.currentWeapon.energyCost and self.player.stats and self.player.stats.energy then
            self.player.stats.energy.currentEnergy = math.max(0, 
                self.player.stats.energy.currentEnergy - self.currentWeapon.energyCost)
        end
        
        -- Activar muzzle flash
        self.muzzleFlash.active = true
        self.muzzleFlash.timer = 0
        
        print("[WEAPON_SYSTEM] Disparado: " .. self.currentWeapon.name)
    end
    
    return success
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
    
    print("[WEAPON_SYSTEM] Recargando: " .. self.currentWeapon.name)
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
            print("[WEAPON_SYSTEM] Recarga completada: " .. self.currentWeapon.name)
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
    for slot = 1, WEAPON_CONFIG.MAX_WEAPON_SLOTS do
        if self.weaponSlots[slot] then
            weapons[slot] = {
                weapon = self.weaponSlots[slot],
                ammo = self.ammunition[self.weaponSlots[slot].id],
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
    
    -- Buscar armas en el inventario
    for _, item in pairs(self.player.inventory.items) do
        if item.category == ItemSystem.CATEGORIES.EQUIPABLE and 
           item.equipType == ItemSystem.EQUIPABLE_TYPES.WEAPON then
            
            -- Buscar slot libre
            for slot = 1, WEAPON_CONFIG.MAX_WEAPON_SLOTS do
                if not self.weaponSlots[slot] then
                    self:equipWeapon(item, slot)
                    return true
                end
            end
        end
    end
    
    return false
end

return WeaponSystem