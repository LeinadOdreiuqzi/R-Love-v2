local Theme = require 'src.ui.combat_theme'
local View = require 'src.ui.combat_presentation'
local utf8 = require("utf8")

local WeaponHUD = {
    visible = true,
    carouselTimer = 0,
    carouselOpen = 0,
    lastSlot = nil
}

-- Extrae los primeros `n` caracteres UTF-8 completos sin cortar secuencias multibyte (ñ, á, ★, etc.)
local function utf8Sub(s, n)
    if not s or s == "" or n <= 0 then return "" end
    local ok, byteOffset = pcall(utf8.offset, s, n + 1)
    if ok and byteOffset then
        return string.sub(s, 1, byteOffset - 1)
    end
    return s
end

local function utf8Len(s)
    if not s then return 0 end
    local ok, len = pcall(utf8.len, s)
    return (ok and len) or string.len(s)
end

function WeaponHUD:init()
    Theme.init()
    self.carouselTimer = 0
    self.carouselOpen = 0
    self.lastSlot = nil
end

function WeaponHUD:update(dt)
    dt = dt or 0
    if self.carouselTimer > 0 then
        self.carouselTimer = math.max(0, self.carouselTimer - dt)
    end
    local holdExpand = love.keyboard and (love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl'))
    local target = (self.carouselTimer > 0 or holdExpand or self.isHoveringCarousel) and 1 or 0
    local speed = target > self.carouselOpen and 14 or 9
    self.carouselOpen = self.carouselOpen + (target - self.carouselOpen) * math.min(1, dt * speed)
end

function WeaponHUD:onWeaponSwitch(slot)
    if self.lastSlot ~= nil and self.lastSlot ~= slot then
        self.carouselTimer = 1.65
    end
    self.selectedSlot = slot
    self.lastSlot = slot
end

function WeaponHUD:setVisible(value) self.visible = value end
function WeaponHUD:isVisible() return self.visible end
function WeaponHUD:toggleVisibility() self.visible = not self.visible end
function WeaponHUD:setPosition(x, y) self.position = {x = x, y = y} end
function WeaponHUD:setColors(colors)
    for key, value in pairs(colors) do
        if Theme.colors[key] then Theme.colors[key] = value end
    end
end

-- Dibuja la silueta geométrica del arma según su familia/tipo de daño
local function drawWeaponGlyph(g, data, cx, cy, scale, color)
    scale = scale or 1
    g.setColor(color)
    g.setLineWidth(1.4)
    if data.damageType == 'kinetic' then
        -- Silueta de cañón/riel cinético
        g.polygon('line', cx - 14 * scale, cy + 4 * scale, cx + 13 * scale, cy, cx - 14 * scale, cy - 4 * scale)
        g.line(cx - 17 * scale, cy, cx - 14 * scale, cy)
    elseif data.damageType == 'explosive' then
        -- Silueta de lanzador / ojiva pesada
        g.circle('line', cx, cy, 6.5 * scale)
        g.line(cx - 13 * scale, cy, cx + 13 * scale, cy)
        g.line(cx - 9 * scale, cy - 4 * scale, cx - 5 * scale, cy, cx - 9 * scale, cy + 4 * scale)
    else
        -- Silueta de emisor de plasma / energía
        g.line(cx - 14 * scale, cy, cx - 6 * scale, cy - 5 * scale, cx, cy + 5 * scale, cx + 6 * scale, cy - 5 * scale, cx + 14 * scale, cy)
        g.circle('line', cx, cy, 3.2 * scale)
    end
    g.setLineWidth(1)
end

-- Dibuja la tira vertical de munición/recarga al costado derecho de la caja de arma (estilo Enter the Gungeon)
local function drawVerticalAmmoStrip(g, x, y, w, h, slot, color, colors)
    g.setColor(0.015, 0.03, 0.055, 0.88)
    g.rectangle('fill', x, y, w, h, 3, 3)
    g.setColor(color[1], color[2], color[3], 0.45)
    g.rectangle('line', x + 0.5, y + 0.5, w - 1, h - 1, 3, 3)

    local innerX, innerY = x + 2, y + 3
    local innerW, innerH = w - 4, h - 6

    if slot.reloading then
        local fillH = innerH * math.max(0, math.min(1, slot.progress or 0))
        g.setColor(colors.recipe[1], colors.recipe[2], colors.recipe[3], 0.9)
        g.rectangle('fill', innerX, innerY + innerH - fillH, innerW, fillH, 1, 1)
    elseif slot.ammo and slot.data and slot.data.maxAmmo then
        local maxAmmo = math.max(1, slot.data.maxAmmo)
        local curAmmo = math.max(0, math.min(maxAmmo, slot.ammo))
        local pips = math.min(12, maxAmmo)
        local gap = 1
        local pipH = math.max(2, (innerH - (pips - 1) * gap) / pips)
        local activePips = math.ceil((curAmmo / maxAmmo) * pips)
        for i = 1, pips do
            local py = innerY + innerH - i * pipH - (i - 1) * gap
            if i <= activePips then
                g.setColor(curAmmo == 0 and colors.danger or color)
            else
                g.setColor(0.14, 0.22, 0.30, 0.55)
            end
            g.rectangle('fill', innerX, py, innerW, pipH)
        end
    else
        -- Arma de energía continua
        g.setColor(color[1], color[2], color[3], 0.85)
        g.rectangle('fill', innerX, innerY, innerW, innerH, 1, 1)
    end
end

function WeaponHUD:layout(width, height)
    local compact = width < 760
    local cardW = compact and 126 or 148
    local cardH = compact and 50 or 56
    local stripW = 10
    local rightMargin = 16
    local bottomMargin = 16
    local gunX = self.position and self.position.x or (width - rightMargin - cardW - stripW - 4)
    local gunY = self.position and self.position.y or (height - bottomMargin - cardH)

    local abilW = compact and 106 or 124
    local abilH = compact and 38 or 42
    local abilX = 18
    local abilY = height - bottomMargin - abilH

    return {
        compact = compact,
        gunX = gunX, gunY = gunY, cardW = cardW, cardH = cardH, stripW = stripW,
        abilX = abilX, abilY = abilY, abilW = abilW, abilH = abilH
    }
end

function WeaponHUD:draw(player, suppressTooltip)
    if not self.visible or not player or player.isInEVA or not player.inventory or not player.weaponSystem then return end
    if player.abilitySystem and not player.abilitySystem:available() then return end

    Theme.init()
    local g, colors = love.graphics, Theme.colors
    local sw, sh = g.getDimensions()
    local layout = self:layout(sw, sh)
    local slots = View.weapons(player)
    local currentSlotIdx = player.weaponSystem.currentSlot or 1

    -- Detectar cambio de slot incluso si se invocó directo sin pasar por update
    if self.lastSlot == nil then
        self.lastSlot = currentSlotIdx
    elseif self.lastSlot ~= currentSlotIdx then
        self.lastSlot = currentSlotIdx
        self.carouselTimer = 1.65
    end

    local mx, my = love.mouse.getPosition()
    -- Construir lista circular de armas equipadas (para el carrusel tipo Enter the Gungeon)
    local otherEquipped = {}
    for offset = 1, 8 do
        local idx = ((currentSlotIdx - 1 + offset) % 9) + 1
        local s = slots[idx]
        if s and s.data then
            otherEquipped[#otherEquipped + 1] = s
        end
    end

    local stepH = math.min(32, math.max(18, math.floor((layout.gunY - 40) / math.max(1, #otherEquipped))))
    local deckHeight = math.max(12, (#otherEquipped * stepH + 4) * self.carouselOpen)
    self.isHoveringCarousel = not suppressTooltip and mx >= layout.gunX - 8
        and mx <= layout.gunX + layout.cardW + layout.stripW + 8
        and my >= layout.gunY - deckHeight and my <= layout.gunY + layout.cardH + 8

    local hovered = nil
    g.push('all')
    g.origin()

    -- =========================================================================
    -- 1. ESQUINA INFERIOR IZQUIERDA: HABILIDADES ACTIVAS Q Y R (Estilo Gungeon Active Items)
    -- =========================================================================
    if player.abilitySystem then
        for index, key in ipairs({'q', 'r'}) do
            local info = View.ability(player.abilitySystem, key)
            local x = layout.abilX + (index - 1) * (layout.abilW + 8)
            local y = layout.abilY
            local color = info.state == 'ACTIVA' and colors.active
                or info.state == 'RECARGA' and colors.recipe
                or colors.text

            Theme.panel(x, y, layout.abilW, layout.abilH, color, info.state == 'ACTIVA')

            -- Insignia de tecla [Q] / [R]
            g.setColor(0.06, 0.14, 0.22, 0.95)
            g.rectangle('fill', x + 5, y + 5, 18, 16, 3, 3)
            g.setColor(color[1], color[2], color[3], 0.85)
            g.rectangle('line', x + 5.5, y + 5.5, 17, 15, 3, 3)
            g.setFont(Theme.small)
            g.setColor(colors.text)
            g.printf(key:upper(), x + 5, y + 7, 18, 'center')

            -- Icono geométrico sutil + título corto
            g.setColor(colors.text)
            g.print(key == 'q' and 'Impulso' or 'Matriz', x + 28, y + 5)

            -- Estado y temporizador
            g.setColor(info.state == 'LISTA' and colors.active or color)
            local statusText = info.state
            if info.active > 0 then
                statusText = string.format('ACTIVA %.1fs', info.active)
            elseif info.remaining > 0 then
                statusText = string.format('CD %.1fs', info.remaining)
            end
            g.print(statusText, x + 6, y + (layout.compact and 20 or 23))

            -- Barra inferior de progreso/estado de la habilidad
            local maxCD = player.abilitySystem[key .. 'Duration'] or (key == 'q' and 6 or 25)
            local system = player.abilitySystem
            local activeDuration = key == 'q' and system.qActiveDuration or (system.field and system.field.duration)
            local ratio = info.active > 0 and math.min(1, info.active / (activeDuration or info.active))
                or info.remaining > 0 and math.max(0, 1 - info.remaining / maxCD)
                or 1
            g.setColor(0.08, 0.14, 0.20, 0.95)
            g.rectangle('fill', x + 5, y + layout.abilH - 5, layout.abilW - 10, 2.5)
            g.setColor(info.state == 'RECARGA' and colors.recipe or colors.active)
            g.rectangle('fill', x + 5, y + layout.abilH - 5, (layout.abilW - 10) * ratio, 2.5)
        end
    end

    -- =========================================================================
    -- 2. ESQUINA INFERIOR DERECHA: CARRUSEL DE ARMAS (Estilo Enter the Gungeon)
    -- =========================================================================
    local current = slots[currentSlotIdx] or slots[1]
    local gunX, gunY, cardW, cardH = layout.gunX, layout.gunY, layout.cardW, layout.cardH

    -- A) Estado colapsado: mostrar bordes de cartas apiladas detrás si hay más armas equipadas
    if self.carouselOpen <= 0.05 and #otherEquipped > 0 then
        local deckLayers = math.min(2, #otherEquipped)
        for d = deckLayers, 1, -1 do
            local inset = d * 4
            local lift = d * 4
            g.setColor(0.02, 0.05, 0.09, 0.72)
            g.rectangle('fill', gunX + inset, gunY - lift, cardW - inset * 2, 6, 3, 3)
            g.setColor(colors.muted[1], colors.muted[2], colors.muted[3], 0.32)
            g.rectangle('line', gunX + inset + 0.5, gunY - lift + 0.5, cardW - inset * 2 - 1, 6, 3, 3)
        end
    end

    -- B) Estado expandido (Carrusel al cambiar de arma o mantener Ctrl/hover):
    --    Despliega las demás armas equipadas en abanico vertical sobre el arma activa
    local maxVisibleDeck = #otherEquipped
    if self.carouselOpen > 0.02 and maxVisibleDeck > 0 then
        for i = maxVisibleDeck, 1, -1 do
            local slot = otherEquipped[i]
            local t = self.carouselOpen
            local scale = 1 - math.min(i, 4) * 0.025
            local w = math.floor(cardW * scale)
            local h = stepH - 3
            local cx = gunX + (cardW - w)
            local cy = gunY - math.floor((i * stepH + 4) * t)
            local alpha = (1 - (i - 1) * .045) * t
            local c = slot.data and slot.data.isEvolved and colors.evolved or colors.muted

            g.setColor(0.015, 0.035, 0.065, 0.86 * alpha)
            g.rectangle('fill', cx, cy, w, h, 4, 4)
            g.setColor(c[1], c[2], c[3], 0.55 * alpha)
            g.rectangle('line', cx + 0.5, cy + 0.5, w - 1, h - 1, 4, 4)

            -- Número de slot [1..9]
            g.setFont(Theme.small)
            g.setColor(colors.text[1], colors.text[2], colors.text[3], 0.9 * alpha)
            g.print('[' .. tostring(slot.slot) .. ']', cx + 5, cy + 4)

            -- Glifo compacto + nombre corto UTF-8
            drawWeaponGlyph(g, slot.data, cx + 36, cy + 12, 0.62, {c[1], c[2], c[3], 0.9 * alpha})
            local shortName = self:getShortWeaponName(slot.data.name):gsub('^★%s*', '')
            while Theme.small:getWidth(shortName) > w - 80 and utf8Len(shortName) > 1 do
                shortName = utf8Sub(shortName, utf8Len(shortName) - 1)
            end
            g.setColor(colors.text[1], colors.text[2], colors.text[3], 0.92 * alpha)
            g.print(shortName, cx + 49, cy + 3)
            if slot.ammo then
                local ammoColor = slot.ammo == 0 and colors.danger or colors.text
                g.setColor(ammoColor[1], ammoColor[2], ammoColor[3], alpha)
                g.printf(tostring(slot.ammo), cx + w - 30, cy + 3, 18, 'right')
            end

            if slot.data.isEvolved then
                g.setColor(colors.evolved[1], colors.evolved[2], colors.evolved[3], alpha)
                Theme.star(cx + w - 9, cy + 9, 3.5)
            end

            -- Mini indicador de munición en la tarjeta del carrusel
            local ammoRatio = slot.ammo and slot.data.maxAmmo and (slot.ammo / slot.data.maxAmmo) or 1
            g.setColor(0.09, 0.15, 0.21, 0.85 * alpha)
            g.rectangle('fill', cx + 5, cy + h - 5, w - 10, 2)
            g.setColor(c[1], c[2], c[3], 0.85 * alpha)
            g.rectangle('fill', cx + 5, cy + h - 5, (w - 10) * ammoRatio, 2)

            if mx >= cx and mx <= cx + w and my >= cy and my <= cy + h then
                hovered = slot.data
            end
        end
    end

    -- C) Tarjeta Principal del Arma Seleccionada (siempre visible en esquina inferior derecha)
    local activeColor = current and current.reloading and colors.recipe
        or (current and current.data and current.data.isEvolved and colors.evolved)
        or colors.active

    Theme.panel(gunX, gunY, cardW, cardH, activeColor, true)
    drawVerticalAmmoStrip(g, gunX + cardW + 4, gunY, layout.stripW, cardH, current or {}, activeColor, colors)

    if current and current.data then
        -- Insignia del slot activo + contador de armas en arsenal
        g.setFont(Theme.small)
        g.setColor(colors.active)
        g.print('[' .. tostring(current.slot) .. ']', gunX + 6, gunY + 4)

        if #otherEquipped > 0 then
            local order, total = 1, 0
            for idx = 1, 9 do
                if slots[idx] and slots[idx].data then
                    total = total + 1
                    if idx == current.slot then order = total end
                end
            end
            g.setColor(colors.muted)
            g.print(string.format('%d/%d', order, total), gunX + 26, gunY + 4)
        end

        -- Estrella de evolución e indicador de sinergias activas (+N)
        if current.data.isEvolved then
            g.setColor(colors.evolved)
            Theme.star(gunX + cardW - 10, gunY + 10, 4.5)
        end
        if current.amplifications > 0 then
            g.setColor(colors.active)
            g.print('+' .. current.amplifications, gunX + cardW - 22, gunY + 19)
        end

        -- Silueta principal del arma en el centro de la caja
        drawWeaponGlyph(g, current.data, gunX + cardW * 0.5, gunY + 23, 1.05, activeColor)

        -- Lectura de munición o estado de recarga en la base de la caja
        if current.reloading then
            g.setColor(colors.recipe)
            g.printf(string.format('RECARGA %d%%', math.floor((current.progress or 0) * 100)), gunX + 6, gunY + cardH - 18, cardW - 12, 'center')
        else
            g.setColor(current.ammo == 0 and colors.danger or colors.text)
            local ammoText = current.ammo and (current.ammo .. ' / ' .. current.data.maxAmmo) or 'ENERGÍA ∞'
            g.printf(ammoText, gunX + 6, gunY + cardH - 18, cardW - 12, 'center')
        end

        -- Nombre del arma seleccionada justo encima de la caja activa (o sobre el carrusel si está cerrado)
        g.setFont(Theme.font)
        g.setColor(current.data.isEvolved and colors.evolved or colors.text)
        local cleanName = (current.data.name or ''):gsub('★%s*', '')
        local nameWidth = cardW + layout.stripW + 40
        local _, wrapped = Theme.font:getWrap(cleanName, nameWidth)
        local nameY = gunY - deckHeight - #wrapped * Theme.font:getHeight() - 3
        g.printf(cleanName, gunX - 36, nameY, nameWidth, 'right')

        if mx >= gunX and mx <= gunX + cardW + layout.stripW + 4 and my >= gunY and my <= gunY + cardH then
            hovered = current.data
        end
    else
        g.setFont(Theme.small)
        g.setColor(colors.muted)
        g.printf('SIN ARMA [' .. tostring(currentSlotIdx) .. ']', gunX + 4, gunY + cardH * 0.5 - 6, cardW - 8, 'center')
    end

    g.pop()
    if hovered and not suppressTooltip then
        Theme.tooltip(player, hovered, mx, my)
    end
end

function WeaponHUD:getShortWeaponName(fullName)
    fullName = tostring(fullName or "Arma")
    local cleanName = fullName:gsub("^★%s*", "")
    local hasStar = (cleanName ~= fullName)

    if utf8Len(cleanName) <= 10 then
        return hasStar and ("★" .. utf8Sub(cleanName, 8)) or cleanName
    end
    
    -- Crear abreviación inteligente respetando fronteras UTF-8
    local words = {}
    for word in cleanName:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local result
    if #words == 1 then
        result = utf8Sub(cleanName, 9)
    elseif #words == 2 then
        result = utf8Sub(words[1], 5) .. " " .. utf8Sub(words[2], 4)
    else
        local initials = ""
        for _, word in ipairs(words) do
            initials = initials .. utf8Sub(word, 1)
        end
        result = initials
    end

    if hasStar then
        return "★" .. result
    end
    return result
end

return WeaponHUD

