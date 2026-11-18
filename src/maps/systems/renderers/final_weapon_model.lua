-- Final Weapon, modelada en coordenadas axiales. X positivo mira al emisor.
local Model = {}
local tau = 2 * math.pi
local palette = {
    shell = {0.40, 0.21, 0.36}, edge = {0.63, 0.35, 0.53},
    wine = {0.32, 0.105, 0.23}, joint = {0.14, 0.12, 0.20},
    steel = {0.32, 0.30, 0.41}, silver = {0.49, 0.46, 0.56},
    brass = {0.60, 0.43, 0.31}, gold = {0.81, 0.63, 0.45},
    vent = {0.65, 0.28, 0.45}, plasma = {1, 0.79, 0.92},
    ember = {0.98, 0.43, 0.17}, scar = {0.24, 0.19, 0.22},
}
local function polar(x, radius, angle, tangent)
    local c, s = math.cos(angle), math.sin(angle)
    tangent = tangent or 0
    return {x, radius*c - tangent*s, radius*s + tangent*c}
end

function Model.build(state)
    local vertices = {}
    local ruins = state == 'ruins'
    local worn = state ~= 'operational'
    local function triangle(a,b,c,material)
        local ux,uy,uz = b[1]-a[1], b[2]-a[2], b[3]-a[3]
        local vx,vy,vz = c[1]-a[1], c[2]-a[2], c[3]-a[3]
        local nx,ny,nz = uy*vz-uz*vy, uz*vx-ux*vz, ux*vy-uy*vx
        local length = math.sqrt(nx*nx+ny*ny+nz*nz)
        if length < 0.00001 then return end
        local color = palette[material]
        for _,p in ipairs({a,b,c}) do
            vertices[#vertices+1] = {p[1],p[2],p[3], nx/length,ny/length,nz/length,
                color[1],color[2],color[3]}
        end
    end
    local function face(a,b,c,d,material)
        triangle(a,b,c,material)
        triangle(a,c,d,material)
    end
    -- Lathed armour and the stepped, recessed muzzle share a physical axis.
    local function band(x1,r1,x2,r2,material,segmented)
        for i=0,23 do
            local a,b = tau*i/24, tau*(i+1)/24
            local m = segmented and i%4 == 0 and 'joint' or material
            face(polar(x1,r1,a),polar(x2,r2,a),polar(x2,r2,b),polar(x1,r1,b),m)
        end
    end
    local shaft = ruins and -0.51 or -1.19
    band(shaft,0,shaft,0.07,'scar')
    for i=0,7 do
        local t,u = i/8,(i+1)/8
        local x = shaft*(1-t)
        local r = 0.07+0.26*t
        band(x,r,shaft*(1-u)-0.018,0.07+0.26*u,'steel',true)
        band(shaft*(1-u)-0.018,0.07+0.26*u,shaft*(1-u),0.065+0.26*u,'silver')
    end
    band(-0.32,0.27,-0.17,0.36,'brass',true)
    band(-0.17,0.36,-0.12,0.37,'gold')
    band(-0.12,0.37,0.04,0.39,'wine',true)
    band(0.04,0.39,0.16,0.34,'shell')
    band(0.16,0.34,0.17,0.29,'brass',true)
    band(0.17,0.29,0.07,0.22,'joint')
    band(0.07,0.22,0.095,0.19,'steel',true)
    band(0.095,0.19,0.055,0.11,'wine')
    band(0.055,0.11,0.06,0.085,ruins and 'scar' or 'vent')
    band(0.06,0.085,0.075,0,ruins and 'joint' or worn and 'ember' or 'plasma')

    -- Each rib has a raised keel, bevelled sidewalls and an inset radiator.
    -- The hooked tip advances towards the viewer as the radius folds back.
    local sections = {
        {-0.15,0.22,0.055}, {-0.095,0.35,0.095}, {-0.055,0.54,0.12},
        {0.00,0.75,0.14}, {0.085,0.94,0.13}, {0.17,1.08,0.092},
        {0.30,1.15,0.052}, {0.44,1.19,0.004},
    }
    for blade=0,11 do
        local inner = blade%2 == 1
        local span = inner and 0.65 or 1
        local angle = tau*blade/12 + 0.19
        local broken = worn and (blade==0 or blade==7 or (ruins and blade%3==0))
        local last = broken and (ruins and 2 or 4) or #sections
        local function point(row,side,height)
            local p = sections[row]
            return polar(p[1]*span+height, p[2]*span, angle+0.15*(row/8)^2,
                p[3]*side*span)
        end
        for row=1,last-1 do
            local function strip(l,h1,r,h2,material)
                face(point(row,l,h1),point(row,r,h2),point(row+1,r,h2),point(row+1,l,h1),material)
            end
            strip(-1,-0.04,1,-0.04,'wine')
            strip(-1,-0.04,-1,0,'joint')
            strip(1,0,1,-0.04,'joint')
            strip(-1,0,-0.68,0.025,'edge')
            strip(0.67,0.03,1,0,'wine')
            strip(-0.68,0.025,0.1,0.052,inner and 'wine' or 'shell')
            strip(0.1,0.052,0.67,0.03,'shell')
            if row>=2 and row<=5 then
                local function slat(t,side)
                    local a,b=point(row,side,0.059),point(row+1,side,0.059)
                    return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}
                end
                for rib=0,2 do
                    local t = rib/3
                    face(slat(t,-0.47),slat(t,0.42),slat(t+0.21,0.42),slat(t+0.21,-0.47),
                        broken and 'scar' or ruins and 'steel' or 'vent')
                end
            end
        end
        if broken then
            face(point(last,-1,-0.04),point(last,1,-0.04),point(last,1,0.03),point(last,-1,0.03),'scar')
            for i=-1,1 do
                triangle(point(last,i*0.48-0.12,0),point(last,i*0.48+0.12,0),
                    point(last+1,i*0.43,-0.015),i==0 and 'brass' or 'silver')
            end
        end
    end
    if ruins then
        -- Torn tips drift clear of their sockets, with the fracture face visible.
        for i,angle in ipairs({0.98,2.95,4.82}) do
            local radius = 0.98 + 0.07*i
            local a = polar(0.16,radius,angle,-0.07)
            local b = polar(0.19,radius,angle,0.085)
            local tip = polar(0.32,radius+0.21,angle,0.045)
            local ridge = polar(0.24,radius+0.055,angle)
            triangle(a,b,ridge,'silver')
            triangle(a,ridge,tip,'shell')
            triangle(ridge,b,tip,'wine')
        end
    end
    return love.graphics.newMesh({{'VertexPosition','float',3},{'FaceNormal','float',3},
        {'Material','float',3}}, vertices,'triangles','static')
end
return Model
