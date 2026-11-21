local Swarm = {}
local function alive(f)
    return not f.isDestroyed and not f.isAbandoned
end

-- Compute screenable positions on the threatened side of the core. Ease into
-- newly vacant positions, so shooting a hole in the formation buys time.
function Swarm.form(c,px,py,dt)
    local core=c.ship
    local angle=math.atan2(py-core.y,px-core.x)
    local count,rank=0,0
    for _,f in ipairs(c.escorts) do if alive(f) then count=count+1 end end
    for _,f in ipairs(c.escorts) do
        if alive(f) then
            rank=rank+1
            local a=angle+(rank-(count+1)*.5)*.46
            local radius=math.max(90,(core.size or 25)*(core.worldScale or 1)*3.8)
            local blend=1-math.exp(-dt*2.4)
            f.arcX=(f.arcX or f.x-core.x)*(1-blend)+math.cos(a)*radius*blend
            f.arcY=(f.arcY or f.y-core.y)*(1-blend)+math.sin(a)*radius*blend
        end
    end
end

function Swarm.steer(f,dt)
    if not f.arcX then return end
    local c=f.monolithOwner
    local vx=(c.ship.x+f.arcX-f.x)*3+(c.ship.dx or 0)*60
    local vy=(c.ship.y+f.arcY-f.y)*3+(c.ship.dy or 0)*60
    local spacing=math.max(36,(f.size or 14)*(f.worldScale or 1)*3)
    for _,n in ipairs(c.escorts) do
        if n~=f and alive(n) then
            local x,y=f.x-n.x,f.y-n.y
            local d=math.sqrt(x*x+y*y)
            if d>0 and d<spacing*2 then
                local repulsion=math.max(0,spacing-d)*6/d
                vx=vx+x*repulsion+((n.dx or 0)-(f.dx or 0))*6
                vy=vy+y*repulsion+((n.dy or 0)-(f.dy or 0))*6
            end
        end
    end
    local scale=math.max(1,math.sqrt(vx*vx+vy*vy)/230)
    local mix=1-math.exp(-dt*10)
    f.dx=(f.dx or 0)*(1-mix)+vx/(60*scale)*mix
    f.dy=(f.dy or 0)*(1-mix)+vy/(60*scale)*mix
end
return Swarm
