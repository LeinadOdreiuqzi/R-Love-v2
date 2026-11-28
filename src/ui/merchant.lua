local Merchant = require 'src.gameplay.merchant'
local Items = require 'src.item_systems.item_system'
local Menu = require 'src.ui.menu_theme'
local Glitch = require 'src.ui.text_glitch'
local Glyph = require 'src.ui.inventory.item_glyph'
local Art = require 'src.rendering.ships.merchant_art'
local UI = {}
UI.__index = UI
local gold = {.98,.75,.40}
local muted = Menu.muted
local holdDuration = .65
local bodyFont, titleFont
local W,H = 816,490

local function frame()
    local w,h = love.graphics.getDimensions()
    local s = math.min((w-16)/W,(h-16)/H,1.6)
    return (w-W*s)/2,(h-H*s)/2,s
end

function UI.world(run,ship)
    local signal = run and ship and Merchant.signal(run,ship)
    if signal and signal.discovered then Art.draw(signal.x,signal.y,1.5) end
end

function UI.hud(run,ship,camera)
    local signal = run and ship and Merchant.signal(run,ship)
    if not signal or not camera or ship.isInEVA or run.defeat then return end
    local g = love.graphics
    local w,h = g.getDimensions()
    local x,y = w/2,h*.18
    local label = 'Señal mercante'
    if signal.discovered then
        local distance = math.sqrt((ship.x-signal.x)^2+(ship.y-signal.y)^2)
        local sx,sy = camera:worldToScreen(signal.x,signal.y)
        x,y = math.max(90,math.min(w-90,sx)),math.max(45,math.min(h-70,sy-52))
        label = distance <= 240 and '[E] Comerciar' or ('Mercante · %d u'):format(distance)
    end
    g.push('all')
    g.translate(x,y)
    g.setColor(.05,.08,.09,.91)
    g.rectangle('fill',-79,-12,158,24,3)
    g.setColor(gold)
    g.push()
    g.translate(-66,0)
    g.rotate(signal.bearing)
    g.polygon('fill',6,0,-4,-4,-2,0,-4,4)
    g.pop()
    g.printf(label,-57,-g.getFont():getHeight()/2,130,'center')
    g.pop()
end

function UI.open(manager,run,ship)
    if not manager or not run or not ship then return false end
    local view = Merchant.open(run,ship)
    if not view then return false end
    local scene = setmetatable({name='Merchant', manager=manager, run=run, ship=ship,
        view=view, selected=1, titleSignal={}},UI)
    manager:push(scene,{suspendUnderlying=true,fadeDuration=0})
    return true
end

local function count(inv,id)
    local qty = 0
    for _,entry in pairs(inv:getCompartment('ship').items) do
        if entry.data.id == id then qty=qty+(entry.quantity or 1) end
    end
    return qty
end

function UI:act(action)
    if action=='close' then self.manager:pop({fadeDuration=0}); return end
    self.hold=nil
    if type(action)=='number' then self.selected=action; self.message=nil; return end
    local ok,why
    local run,ship,phase = self.run,self.ship,self.view.phase
    if action=='sell' then ok,why=Merchant.sellRecord(run,ship,phase)
    elseif action=='learn' then ok,why=Merchant.learnSchematic(run,ship,phase)
    else ok,why=Merchant.buy(run,ship,phase,self.selected,action) end
    local view=Merchant.open(run,ship)
    if not view or view.phase~=phase then self:act('close'); return end
    self.view=view
    self.success=ok
    local results={sell='Registro vendido.',learn='Esquema registrado.'}
    self.message=ok and (results[action] or 'Añadido a la bodega: '..Items:getItem(view.offers[self.selected].item).name) or why
end

-- Each cell keeps the original offer index for the transaction API.
local function shelves(offers)
    local groups = {
        {name='Suministros'}, {name='Equipo'}, {name='Canjes'}
    }
    for index, offer in ipairs(offers) do
        local group = groups[2]
        if not offer.credits then group = groups[3]
        elseif Items:getItem(offer.item).category == 'consumable' then group = groups[1] end
        group[#group+1] = index
    end
    local rows = {}
    for _,group in ipairs(groups) do
        if #group > 0 then rows[#rows+1] = group end
    end
    return rows
end

local function navigate(scene,key)
    local rows = shelves(scene.view.offers)
    for r,row in ipairs(rows) do
        for c,index in ipairs(row) do
            if scene.selected == index then
                if key == 'left' or key == 'right' then
                    return row[(c-1+(key=='left' and -1 or 1)) % #row+1]
                end
                local nextRow = rows[(r-1+(key=='up' and -1 or 1)) % #rows+1]
                return nextRow[math.min(c,#nextRow)]
            end
        end
    end
end

local function buttonAt(scene,x,y)
    local ox,oy,s=frame()
    x,y=(x-ox)/s,(y-oy)/s
    for _,b in ipairs(scene.buttons or {}) do
        if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then return b end
    end
end

function UI:startSale(source)
    if not self.hold and count(self.ship.inventory,'survey_record')>0 then
        self.hold={source=source,time=0}
    end
end

function UI:update(dt)
    local x,y=love.mouse.getPosition()
    local target=buttonAt(self,x,y)
    if self.buttons and (x~=self.lastX or y~=self.lastY) then
        self.lastX,self.lastY=x,y
        if target and type(target.action)=='number' and target.action~=self.selected then
            self:act(target.action)
        end
    end
    local hold=self.hold
    if not hold then return end
    local pressed
    if hold.source=='mouse' then
        pressed=love.mouse.isDown(1) and target and target.action=='sell'
    else
        pressed=love.keyboard.isDown('f')
    end
    if not pressed or not love.window.hasFocus() then self.hold=nil; return end
    hold.time=hold.time+dt
    if hold.time>=holdDuration then self:act('sell') end
end

function UI:keypressed(key)
    if key=='escape' or key=='e' then self:act('close')
    elseif key=='up' or key=='down' or key=='left' or key=='right' then
        self:act(navigate(self,key))
    elseif key=='c' then self:act('credits')
    elseif key=='t' then self:act('materials')
    elseif key=='f' then self:startSale('key')
    elseif key=='r' then self:act('learn')
    elseif key=='p' then self.hold=nil end
    return key~='p' and key~='f11' and key~='return'
end

function UI:mousepressed(x,y,button)
    local target=buttonAt(self,x,y)
    if button==1 and target then
        if target.action=='sell' then self:startSale('mouse')
        else self:act(target.action) end
    end
    return true
end

function UI:mousereleased(x,y,button)
    if button==1 and self.hold and self.hold.source=='mouse' then self.hold=nil end
    return true
end

function UI:draw()
    local g = love.graphics
    local ox,oy,s=frame()
    local v,inv=self.view,self.ship.inventory
    g.push('all')
    if not bodyFont then
        bodyFont=g.newFont(13,'normal',2)
        titleFont=g.newFont(21,'normal',2)
        bodyFont:setFilter('linear','linear')
        titleFont:setFilter('linear','linear')
    end
    g.setFont(bodyFont)
    g.translate(ox,oy); g.scale(s)
    self.buttons={}
    local function text(label,x,y,color,scale)
        g.setColor(color or Menu.paper)
        g.print(label,x,y,0,scale or 1)
    end
    local function hit(x,y,w,h,action)
        table.insert(self.buttons,{x=x,y=y,w=w,h=h,action=action})
    end
    local function button(x,y,w,label,action,available)
        g.setColor(available and Menu.steel or Menu.plate)
        g.rectangle('fill',x,y,w,29)
        if action=='sell' and self.hold then
            g.setColor(.16,.40,.33,1)
            g.rectangle('fill',x,y,w*self.hold.time/holdDuration,29)
            g.setColor(Menu.focus)
            g.rectangle('fill',x,y+26,w*self.hold.time/holdDuration,3)
        end
        text(label,x+9,y+6,available and Menu.paper or muted)
        hit(x,y,w,29,action)
    end
    local ink={.11,.13,.14}
    local tile={.12,.15,.16}
    local function fill(x,y,w,h,color)
        g.setColor(color)
        g.rectangle('fill',x,y,w,h)
    end
    fill(0,0,W,58,{.035,.055,.065,.88})
    fill(0,65,506,337,{.035,.055,.065,.63})
    Art.draw(32,27,.56)
    g.setColor(Menu.paper)
    g.setFont(titleFont)
    Glitch.print(self.titleSignal,'Mercante itinerante',69,7)
    g.setFont(bodyFont)
    text(('Fase %02d'):format(v.phase),70,36,muted)
    text(('%d créditos'):format(v.credits),631,20,Menu.focus,1.12)
    button(753,13,57,'Salir','close',true)
    fill(5,58,806,1,Menu.steel)

    local rows=shelves(v.offers)
    for r,row in ipairs(rows) do
        local y=69+(r-1)*111
        text(row.name:upper(),8,y,Menu.sage)
        fill(104,y+8,396,1,ink)
        local pitch=math.min(166,math.floor(498/#row))
        local width=pitch-7
        local iconSize=#row>3 and 32 or 48
        for c,index in ipairs(row) do
            local offer=v.offers[index]
            local item=Items:getItem(offer.item)
            local x,top=8+(c-1)*pitch,y+21
            local selected=self.selected==index
            fill(x,top,width,83,selected and Menu.steel or tile)
            fill(x,top,width,18,selected and Menu.focus or Menu.sage)
            local price=offer.credits and (offer.credits..' cr') or 'Canje'
            if offer.credits and offer.materials then price=price..' / canje' end
            text(price,x+6,top+1,ink)
            text(offer.remaining>0 and ('×'..offer.remaining) or 'Agotado',
                x+width-(offer.remaining>0 and 27 or 55),top+1,ink)
            g.setColor(item.rarity.color)
            Glyph(item,x+4,top+24,iconSize)
            g.setColor(Menu.paper)
            g.printf(item.name,x+iconSize+7,top+21,width-iconSize-10)
            if selected then
                g.setColor(Menu.focus)
                g.rectangle('line',x+.5,top+.5,width-1,82)
            end
            hit(x,top,width,83,index)
        end
    end

    local offer=v.offers[self.selected]
    local item=Items:getItem(offer.item)
    local right=526
    fill(512,69,298,369,{.055,.078,.086,.91})
    fill(512,69,3,369,item.rarity.color)
    text(item.rarity.name,right,80,item.rarity.color)
    g.setColor(Menu.paper)
    g.printf(item.name,right,106,208,'left',0,1.28)
    g.setColor(muted)
    g.printf(item.description or '',right,154,265)
    local unlocked=not offer.schematic or v.learned[offer.schematic]
    if offer.schematic then
        text(unlocked and 'Esquema registrado' or 'Requiere esquema de reparación',right,218,gold)
    end
    local hasMaterials=true
    if offer.materials then
        text('MATERIALES',right,241,Menu.sage)
        text('Tienes / coste',711,241,muted)
        local ids={}
        for id in pairs(offer.materials) do ids[#ids+1]=id end
        table.sort(ids)
        for i,id in ipairs(ids) do
            local held=count(inv,id)
            local needed=offer.materials[id]
            if held<needed then hasMaterials=false end
            local y=247+i*19
            text(Items:getItem(id).name,right,y)
            text(('%d / %d'):format(held,needed),753,y,held>=needed and Menu.focus or gold)
        end
    end
    local active=unlocked and offer.remaining>0
    if offer.credits then button(right,326,270,('[C] Comprar por %d créditos'):format(offer.credits),'credits',active and v.credits>=offer.credits) end
    if offer.materials then button(right,360,270,'[T] Canjear materiales','materials',active and hasMaterials) end

    fill(8,411,490,1,Menu.steel)
    local records=count(inv,'survey_record')
    button(right,399,270,('Mantén [F] · Vender registro (+%d cr)'):format(v.recordPrice),'sell',records>0)
    button(8,423,400,v.learned.kit_schematic and 'Esquema registrado' or '[R] Registrar esquema de reparación','learn',not v.learned.kit_schematic and count(inv,'kit_schematic')>0)
    if self.message then
        fill(8,461,W-16,25,Menu.plate)
        text(self.message,16,465,self.success and Menu.focus or gold)
    end
    g.pop()
end
return UI
