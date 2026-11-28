-- A small cargo tug with an offset bridge and paired banks of freight pods.
-- Draw in native pixels; the same hull is used in flight and on the manifest.
local Art = {}
function Art.draw(x, y, scale)
    local g = love.graphics
    g.push('all')
    g.translate(x,y)
    g.scale(scale,scale)
    local function plate(color, ...)
        g.setColor(color)
        g.polygon('fill', ...)
    end
    local function rect(color,a,b,w,h)
        g.setColor(color)
        g.rectangle('fill',a,b,w,h)
    end
    local shadow, hull, deck = {.09,.14,.18}, {.24,.33,.36}, {.55,.65,.63}
    local ochre, sun, amber = {.56,.33,.17}, {.91,.67,.33}, {1,.81,.45}
    plate(shadow,-44,-9,24,-9,44,-3,44,5,32,12,-44,12)
    plate(hull,-42,-12,29,-12,44,-4,32,6,-42,6)
    rect(deck,-35,-7,57,4)
    for _,y0 in ipairs({-21,5}) do
        for i=0,2 do
            local a,y=-30+i*17,y0
            rect(shadow,a-1,y+4,16,15)
            rect(ochre,a,y+2,15,13)
            plate(sun,a,y+2,a+3,y,a+14,y,a+14,y+9,a+11,y+11,a,y+11)
            for _,dx in ipairs({3,10}) do rect(hull,a+dx,y+1,2,10) end
            rect(amber,a+5,y+1,4,1)
        end
    end
    plate(hull,18,-16,29,-16,39,-9,35,-2,18,-2)
    plate(deck,18,-18,29,-18,38,-12,34,-6,18,-6)
    plate(shadow,26,-16,30,-15,35,-12,33,-10,27,-12)
    rect({.51,.92,.85},28,-14,4,2)
    rect(deck,22,-24,1,7)
    rect(amber,21,-25,3,2)
    for _,yy in ipairs({-8,1}) do
        rect(shadow,-46,yy,8,6)
        rect({.38,.72,.72},-47,yy+1,2,3)
    end
    g.pop()
end
return Art
