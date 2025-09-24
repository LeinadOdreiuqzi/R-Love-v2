-- src/ui/weapon_hud.lua
-- HUD de Armas tipo "Enter the Gungeon"

local WeaponHUD = {}

-- Configuración del HUD de armas
local HUD_CONFIG = {
    position = {
        x = 50,  -- Posición X desde la izquierda
        y = 50   -- Posición Y desde arriba
    },
    slotSize = 60,      -- Tamaño de cada slot de arma
    slotSpacing = 70,   -- Espaciado entre slots
    maxSlots = 4,       -- Máximo número de slots a mostrar
    
    -- Colores
    colors = {
        background = {0.1, 0.1, 0.1, 0.8},
        border = {0.3, 0.3, 0.3, 1.0},
        activeBorder = {1.0, 0.8, 0.2, 1.0},
        text = {1.0, 1.0, 1.0, 1.0},
        ammoText = {0.8, 0.8, 0.8, 1.0},
        reloadBar = {0.2, 0.8, 0.2, 1.0},
        noAmmoText = {1.0, 0.3, 0.3, 1.0}
    },
    
    -- Fuentes
    fonts = {
        weaponName = nil,
        ammo = nil,
        keyHint = nil
    },
    
    -- Animaciones
    animation = {
        switchScale = 1.2,      -- Escala cuando se cambia de arma
        switchDuration = 0.2,   -- Duración de la animación
        pulseSpeed = 3.0        -- Velocidad del pulso de recarga
    }
}

-- Estado del HUD
local hudState = {
    visible = true,
    lastWeaponSwitch = 0,
    switchAnimationTimer = 0,
    currentSwitchSlot = nil
}

function WeaponHUD:init()
    -- Inicializar fuentes si están disponibles
    local success, font = pcall(love.graphics.newFont, 12)
    if success then
        HUD_CONFIG.fonts.weaponName = font
    end
    
    success, font = pcall(love.graphics.newFont, 10)
    if success then
        HUD_CONFIG.fonts.ammo = font
    end
    
    success, font = pcall(love.graphics.newFont, 8)
    if success then
        HUD_CONFIG.fonts.keyHint = font
    end
end

function WeaponHUD:update(dt)
    -- Actualizar animaciones
    if hudState.switchAnimationTimer > 0 then
        hudState.switchAnimationTimer = hudState.switchAnimationTimer - dt
        if hudState.switchAnimationTimer <= 0 then
            hudState.currentSwitchSlot = nil
        end
    end
end

function WeaponHUD:draw(player)
    if not hudState.visible or not player or not player.weaponSystem then
        return
    end
    
    local weaponSystem = player.weaponSystem
    local equippedWeapons = weaponSystem:getEquippedWeapons()
    local currentWeaponInfo = weaponSystem:getCurrentWeaponInfo()
    
    -- Guardar estado gráfico completo
    love.graphics.push()
    local r, g, b, a = love.graphics.getColor()
    local currentFont = love.graphics.getFont()
    local currentLineWidth = love.graphics.getLineWidth()
    
    -- Dibujar slots de armas
    for slot = 1, HUD_CONFIG.maxSlots do
        local x = HUD_CONFIG.position.x + (slot - 1) * HUD_CONFIG.slotSpacing
        local y = HUD_CONFIG.position.y
        
        self:drawWeaponSlot(x, y, slot, equippedWeapons[slot], currentWeaponInfo)
    end
    
    -- Dibujar información del arma actual
    if currentWeaponInfo then
        self:drawCurrentWeaponInfo(currentWeaponInfo)
    end
    
    -- Restaurar estado gráfico completo
    love.graphics.setColor(r, g, b, a)
    love.graphics.setFont(currentFont)
    love.graphics.setLineWidth(currentLineWidth)
    love.graphics.pop()
end

function WeaponHUD:drawWeaponSlot(x, y, slot, weaponData, currentWeaponInfo)
    local isActive = currentWeaponInfo and currentWeaponInfo.slot == slot
    local hasWeapon = weaponData ~= nil
    
    -- Calcular escala para animación
    local scale = 1.0
    if hudState.currentSwitchSlot == slot and hudState.switchAnimationTimer > 0 then
        local progress = hudState.switchAnimationTimer / HUD_CONFIG.animation.switchDuration
        scale = 1.0 + (HUD_CONFIG.animation.switchScale - 1.0) * progress
    end
    
    love.graphics.push()
    love.graphics.translate(x + HUD_CONFIG.slotSize/2, y + HUD_CONFIG.slotSize/2)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-HUD_CONFIG.slotSize/2, -HUD_CONFIG.slotSize/2)
    
    -- Dibujar fondo del slot
    love.graphics.setColor(HUD_CONFIG.colors.background)
    love.graphics.rectangle("fill", 0, 0, HUD_CONFIG.slotSize, HUD_CONFIG.slotSize)
    
    -- Dibujar borde
    love.graphics.setLineWidth(2)
    if isActive then
        love.graphics.setColor(HUD_CONFIG.colors.activeBorder)
    else
        love.graphics.setColor(HUD_CONFIG.colors.border)
    end
    love.graphics.rectangle("line", 0, 0, HUD_CONFIG.slotSize, HUD_CONFIG.slotSize)
    
    if hasWeapon then
        local weapon = weaponData.weapon
        
        -- Dibujar icono del arma (placeholder)
        love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
        love.graphics.rectangle("fill", 10, 10, HUD_CONFIG.slotSize - 20, HUD_CONFIG.slotSize - 20)
        
        -- Dibujar nombre del arma (abreviado)
        if HUD_CONFIG.fonts.weaponName then
            love.graphics.setFont(HUD_CONFIG.fonts.weaponName)
            love.graphics.setColor(HUD_CONFIG.colors.text)
            local shortName = self:getShortWeaponName(weapon.name)
            local textWidth = HUD_CONFIG.fonts.weaponName:getWidth(shortName)
            love.graphics.print(shortName, (HUD_CONFIG.slotSize - textWidth) / 2, HUD_CONFIG.slotSize - 15)
        end
        
        -- Dibujar munición si aplica
        if weapon.maxAmmo and weaponData.ammo then
            self:drawAmmoInfo(weapon, weaponData.ammo, isActive)
        end
        
        -- Dibujar barra de recarga si está recargando
        if isActive and currentWeaponInfo.isReloading then
            self:drawReloadBar(currentWeaponInfo.reloadProgress)
        end
    end
    
    -- Dibujar número del slot
    if HUD_CONFIG.fonts.keyHint then
        love.graphics.setFont(HUD_CONFIG.fonts.keyHint)
        love.graphics.setColor(HUD_CONFIG.colors.text)
        love.graphics.print(tostring(slot), 2, 2)
    end
    
    love.graphics.pop()
end

function WeaponHUD:drawAmmoInfo(weapon, currentAmmo, isActive)
    if not HUD_CONFIG.fonts.ammo then
        return
    end
    
    love.graphics.setFont(HUD_CONFIG.fonts.ammo)
    
    local ammoText = currentAmmo .. "/" .. weapon.maxAmmo
    local textWidth = HUD_CONFIG.fonts.ammo:getWidth(ammoText)
    
    -- Color según la cantidad de munición
    if currentAmmo == 0 then
        love.graphics.setColor(HUD_CONFIG.colors.noAmmoText)
    else
        love.graphics.setColor(HUD_CONFIG.colors.ammoText)
    end
    
    love.graphics.print(ammoText, (HUD_CONFIG.slotSize - textWidth) / 2, HUD_CONFIG.slotSize - 30)
end

function WeaponHUD:drawReloadBar(progress)
    local barWidth = HUD_CONFIG.slotSize - 10
    local barHeight = 4
    local barX = 5
    local barY = HUD_CONFIG.slotSize - 8
    
    -- Fondo de la barra
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    -- Barra de progreso con efecto de pulso
    local pulseAlpha = 0.8 + 0.2 * math.sin(love.timer.getTime() * HUD_CONFIG.animation.pulseSpeed)
    love.graphics.setColor(HUD_CONFIG.colors.reloadBar[1], HUD_CONFIG.colors.reloadBar[2], HUD_CONFIG.colors.reloadBar[3], pulseAlpha)
    love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)
end

function WeaponHUD:drawCurrentWeaponInfo(weaponInfo)
    if not weaponInfo then
        return
    end
    
    local infoX = HUD_CONFIG.position.x
    local infoY = HUD_CONFIG.position.y + HUD_CONFIG.slotSize + 20
    
    -- Dibujar nombre del arma actual
    if HUD_CONFIG.fonts.weaponName then
        love.graphics.setFont(HUD_CONFIG.fonts.weaponName)
        love.graphics.setColor(HUD_CONFIG.colors.text)
        love.graphics.print("Arma: " .. weaponInfo.name, infoX, infoY)
    end
    
    -- Dibujar información de daño
    if weaponInfo.damage and HUD_CONFIG.fonts.ammo then
        love.graphics.setFont(HUD_CONFIG.fonts.ammo)
        love.graphics.setColor(HUD_CONFIG.colors.ammoText)
        local damageText = "Daño: " .. weaponInfo.damage.min .. "-" .. weaponInfo.damage.max
        love.graphics.print(damageText, infoX, infoY + 20)
    end
    
    -- Dibujar estado de recarga
    if weaponInfo.isReloading then
        love.graphics.setColor(HUD_CONFIG.colors.reloadBar)
        love.graphics.print("Recargando...", infoX, infoY + 35)
    end
end

function WeaponHUD:getShortWeaponName(fullName)
    -- Acortar nombres largos para que quepan en el slot
    if string.len(fullName) <= 8 then
        return fullName
    end
    
    -- Crear abreviación inteligente
    local words = {}
    for word in fullName:gmatch("%S+") do
        table.insert(words, word)
    end
    
    if #words == 1 then
        return string.sub(fullName, 1, 8)
    elseif #words == 2 then
        return string.sub(words[1], 1, 4) .. " " .. string.sub(words[2], 1, 3)
    else
        -- Usar iniciales
        local initials = ""
        for _, word in ipairs(words) do
            initials = initials .. string.sub(word, 1, 1)
        end
        return initials
    end
end

function WeaponHUD:onWeaponSwitch(slot)
    -- Activar animación de cambio
    hudState.lastWeaponSwitch = love.timer.getTime()
    hudState.switchAnimationTimer = HUD_CONFIG.animation.switchDuration
    hudState.currentSwitchSlot = slot
end

function WeaponHUD:setVisible(visible)
    hudState.visible = visible
end

function WeaponHUD:isVisible()
    return hudState.visible
end

function WeaponHUD:toggleVisibility()
    hudState.visible = not hudState.visible
end

-- Configurar posición del HUD
function WeaponHUD:setPosition(x, y)
    HUD_CONFIG.position.x = x
    HUD_CONFIG.position.y = y
end

-- Configurar colores del HUD
function WeaponHUD:setColors(colors)
    for key, color in pairs(colors) do
        if HUD_CONFIG.colors[key] then
            HUD_CONFIG.colors[key] = color
        end
    end
end

return WeaponHUD