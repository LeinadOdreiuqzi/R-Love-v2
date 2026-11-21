local Ribbon = {}
local widths={.06,.70,.94,.67,.41,.19,.025}
local lengths={-.8,-.35,.06,.52,.95,1.32,1.63}
local colors={{.13,.15,.21},{.62,.68,.73},{.27,.33,.41},{.08,.10,.16}}
local across={-1,-.48,-.20,1}
local indices={}
for i=0,#widths-2 do
    for j=1,3 do
        local a=i*4+j
        for _,v in ipairs({a,a+1,a+4,a+1,a+5,a+4}) do indices[#indices+1]=v end
    end
end

function Ribbon.update(f,dt)
    local size=(f.size or 14)*(f.worldScale or 1)
    local r=f.ribbon
    if not r then
        r={points={},vertices={},x=f.x,y=f.y,angle=f.rotation or 0}
        f.ribbon=r
    end
    local dx,dy=f.x-r.x,f.y-r.y
    local speed=math.sqrt(dx*dx+dy*dy)/math.max(.001,dt)
    local angle=speed>6 and math.atan2(dy,dx)+math.pi*.5 or f.rotation or r.angle
    r.angle=r.angle+((angle-r.angle+math.pi)%(2*math.pi)-math.pi)*(1-math.exp(-dt*14))
    r.speed=math.min(1,speed/190)
    r.x,r.y=f.x,f.y
    local bx,by=-math.sin(r.angle),math.cos(r.angle)
    for i,dist in ipairs(lengths) do
        local length=dist*size*(dist>0 and 1+r.speed*.42 or 1)
        local x,y=f.x+bx*length,f.y+by*length
        local p=r.points[i]
        if not p then p={x=x,y=y,vx=0,vy=0};r.points[i]=p end
        if i<=3 then p.x,p.y=x,y
        else
            local k=40-i*3
            local decay=math.exp(-k*dt)
            local ex,ey=p.x-x,p.y-y
            local ux,uy=p.vx+k*ex,p.vy+k*ey
            p.x,p.y=x+(ex+ux*dt)*decay,y+(ey+uy*dt)*decay
            p.vx,p.vy=(p.vx-k*ux*dt)*decay,(p.vy-k*uy*dt)*decay
            local rx,ry=p.x-f.x,p.y-f.y
            local clamp=math.max(1,math.sqrt(rx*rx+ry*ry)/(size*(dist+1.1)))
            p.x,p.y=f.x+rx/clamp,f.y+ry/clamp
        end
    end
end

function Ribbon.draw(f,size)
    if not f.ribbon then Ribbon.update(f,1/60) end
    local r=f.ribbon
    local core=f.monolithOwner.ship
    local elapsed=love.timer.getTime()-(f.lastDamageTime or -10)
    local grow=math.min(1,.45+math.max(0,f.monolithOwner.age-f.buddedAt)*1.5)
    for i,p in ipairs(r.points) do
        local before,after=r.points[math.max(1,i-1)],r.points[math.min(#widths,i+1)]
        local dx,dy=after.x-before.x,after.y-before.y
        local len=math.max(.001,math.sqrt(dx*dx+dy*dy))
        local nx,ny=dy/len,-dx/len
        local field=core and ((core.x-f.x)*nx+(core.y-f.y)*ny) or 0
        local ripple=math.max(0,1-math.abs(elapsed*14-i+1))*math.max(0,1-elapsed/.5)
        for j,k in ipairs(across) do
            local crest=(i==2 or i==4) and k*field>0 and math.abs(k)==1
            local offset=size*(widths[i]*(1-r.speed*.16)+ripple*.22+(crest and .32 or 0))*k
            local n=(i-1)*4+j
            local v=r.vertices[n] or {0,0,0,0,0,0,0,1}
            v[1],v[2]=(p.x-r.x+nx*offset)*grow,(p.y-r.y+ny*offset)*grow
            local color=colors[j]
            v[5],v[6],v[7]=color[1]+ripple*.26,color[2]+(crest and .45 or ripple*.24),color[3]+(crest and .35 or ripple*.18)
            r.vertices[n]=v
        end
    end
    if not r.mesh then
        r.mesh=love.graphics.newMesh(r.vertices,'triangles','dynamic')
        r.mesh:setVertexMap(indices)
    else r.mesh:setVertices(r.vertices) end
    love.graphics.setColor(1,1,1)
    love.graphics.draw(r.mesh)
end
return Ribbon
