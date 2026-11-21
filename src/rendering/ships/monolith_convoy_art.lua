local FieldArt = require 'src.rendering.ships.convoy_art'
local Art = {sizeMultiplier=1.22}
local shard
local Ribbon=require 'src.rendering.ships.ferro_ribbon'

-- The escort and the articulated hull use the same faceted plate.
local function plate(x,y,angle,sx,sy)
    local g=love.graphics
    if not shard then
        g.push('all')
        shard=g.newCanvas(32,48,{dpiscale=1})
        shard:setFilter('nearest','nearest')
        g.setCanvas(shard)
        g.origin()
        g.setShader()
        g.clear(0,0,0,0)
        g.setColor(.12,.13,.21)
        g.polygon('fill',16,1,29,18,24,39,11,47,3,27,7,12)
        g.setColor(.34,.32,.46)
        g.polygon('fill',16,1,18,26,11,47,3,27,7,12)
        g.setColor(.54,.52,.59)
        g.polygon('fill',16,1,11,19,3,27,7,12)
        g.setColor(.18,.22,.30)
        g.polygon('fill',18,26,29,18,24,39,11,47)
        g.setColor(.27,.88,.75)
        g.polygon('fill',10,19,16,13,13,22,8,29)
        g.pop()
    end
    g.draw(shard,x,y,angle,sx,sy,16,24)
end

local function hull(size,open,fold,dead,hurt)
    local g=love.graphics
    g.push('all')
    g.scale(size/24)
    g.setColor(dead and .52 or 1,dead and .53 or 1,dead and .57 or 1)
    plate(0,0,0,.86,1.7)
    for _,side in ipairs({-1,1}) do
        for row=1,3 do
            local spread=10+open*2+fold*(4-row)*7
            local tilt=side*(.12+fold*(.86-row*.14))
            if dead and row==1 then tilt=tilt+side*.6 end
            plate(side*spread,(row-2)*18+fold*(row-1)*4,tilt,side*.55,.74)
            if not dead then
                local x,y=side*spread,(row-2)*18+fold*(row-1)*4
                local pull=2+open*3+fold*2
                g.setColor(.31,.40,.46)
                g.polygon('fill',x,y+8,x+side*(6+pull),y-10,x+side*4,y+2)
                g.setColor(.31,.76,.72)
                g.line(x+side*3,y+2,x+side*(5+pull),y-8)
                g.setColor(1,1,1)
            end
        end
    end
    if hurt then
        g.setColor(.09,.08,.13)
        g.polygon('fill',-3,-17,4,-8,0,-4,5,6,-3,-3,-1,-8)
    end
    g.pop()
end

function Art.draw(ship,size)
    local c=ship.convoy
    local g=love.graphics
    -- Filaments follow the actual departing fragments until surface tension breaks.
    for _,f in ipairs(c.escorts or {}) do
        local age=(c.age or 0)-(f.buddedAt or -10)
        if age>=0 and age<.7 and not f.isDestroyed then
            local dx,dy=f.x-ship.x,f.y-ship.y
            local cos,sin=math.cos(ship.rotation),math.sin(ship.rotation)
            local x,y=dx*cos+dy*sin,dy*cos-dx*sin
            local ax,ay=f.budSide*size*.56,f.budRow*size*.6
            local length=math.sqrt((x-ax)^2+(y-ay)^2)
            if length<size*3 and length>0 then
                local neck=(1-age/.7)*size*.18
                g.push('all')
                g.translate(ax,ay)
                g.rotate(math.atan2(y-ay,x-ax))
                g.setColor(.30,.36,.43)
                g.polygon('fill',0,-neck,length*.55,-neck*.4,length,0,length*.55,neck*.4,0,neck)
                g.pop()
            end
        end
    end
    hull(size,c.aperture or 0,c.fold or 0,false,c.hull and c.hull<155)
    if c.state=='travel' then FieldArt.drawField(c,size) end
end

function Art.fragment(size,ship)
    love.graphics.push()
    love.graphics.rotate(-(ship.rotation or 0))
    Ribbon.draw(ship,size)
    love.graphics.pop()
end

function Art.wreck(w)
    local g=love.graphics
    g.push('all')
    g.translate(w.x,w.y)
    g.rotate(w.rotation)
    hull(w.size,.65,w.fold or 0,true,true)
    g.pop()
end
return Art
