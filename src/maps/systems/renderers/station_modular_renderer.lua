local depthColor=require 'src.maps.systems.renderers.station_depth_color'
local View=require 'src.maps.systems.renderers.station_parallax'
-- Suspended Ancient habitat with a forked gallery and a ventral arch.
local dome=require 'src.maps.systems.renderers.ancient_city_dome'
local g=love.graphics
local Art={}
local size,unit=512,1.75
local poses={}
local serial=0
local shades={
    keel={.15,.20,.23}, steel={.32,.40,.41}, rim={.52,.60,.56},
    patina={.26,.43,.40}, copper={.71,.46,.27}, stone={.72,.68,.52},
    socket={.18,.27,.28}, light={.65,.87,.73}, scar={.28,.24,.23},
}
local paletteShader
local paletteSource=depthColor..[[
extern float centerDepth;
extern float domeRadius;
vec4 effect(vec4 tint,Image tex,vec2 uv,vec2 pixel) {
    vec4 p=Texel(tex,uv)*tint;
    if(p.a<=0.) return vec4(0.);
    vec2 localPos=(uv-vec2(.5))*vec2(2.,2.7);
    float arch=sqrt(max(0.,1.-dot(localPos,localPos)));
    float depth=centerDepth+domeRadius*(localPos.y*.68+arch*.23);
    vec3 rgb=depthColor(p.rgb/p.a,recession(depth/68.));
    return vec4(rgb*p.a,p.a);
}
]]
local function bake(canvas,state,angle,ix,iy)
    local c,s=math.cos(angle),math.sin(angle)
    local damaged,ruins=state=='damaged',state=='ruins'
    local queue={}
    local offsetX,offsetY=View.offset(ix,iy,90)
    local function project(x,y,z)
        local longitudinal=x*s+y*c
        local depth=longitudinal*.82+z*.57
        local magnification=1/(1-depth/210)
        return (x*c-y*s)*magnification+offsetX*(magnification-1),
            (longitudinal*.57-z*.82)*magnification+offsetY*(magnification-1),depth,magnification
    end
    local function enqueue(depth,command)
        queue[#queue+1]={depth=depth,order=#queue+1,draw=command}
    end
    local function face(vertices,mat,brightness)
        local points,depth={},0
        for _,v in ipairs(vertices) do
            local x,y,d=project(v[1],v[2],v[3])
            points[#points+1]=x
            points[#points+1]=y
            depth=depth+d
        end
        local meanDepth=depth/#vertices
        enqueue(meanDepth,function()
            paletteShader:send('centerDepth',meanDepth)
            paletteShader:send('domeRadius',0)
            local rgb=shades[mat]
            local level=ruins and brightness*.78 or brightness
            g.setColor(math.floor(rgb[1]*level*31)/31,math.floor(rgb[2]*level*31)/31,math.floor(rgb[3]*level*31)/31,1)
            g.polygon('fill',points)
        end)
    end
    -- A single bevel and an inset ribbon define each gallery at combat zoom.
    local function gallery(x,y,z,u,v,h,width)
        local dx,dy=u-x,v-y
        local length=math.sqrt(dx*dx+dy*dy)
        local nx,ny=-dy/length*width,dx/length*width
        local function edge(t,side,lift)
            return {x+t*dx+side*nx,y+t*dy+side*ny,z+t*(h-z)+lift}
        end
        for i=0,3 do
            local a,b=i/4,(i+1)/4
            local side=nx*s+ny*c>0 and 1 or -1
            face({edge(a,side,-2.4),edge(b,side,-2.4),edge(b,side,0),edge(a,side,0)},'steel',.85)
            for _,strip in ipairs({{-1,-.6,'stone'},{-.6,.48,'patina'},{.48,.65,'light'},{.65,1,'rim'}}) do
                face({edge(a,strip[1],0),edge(b,strip[1],0),edge(b,strip[2],0),edge(a,strip[2],0)},strip[3],1)
            end
        end
    end
    local function district(x,y,r,z,seed,damage)
        local px,py,depth,magnification=project(x,y,z)
        local sprite=dome(math.floor(r*unit),seed,damage)
        enqueue(depth+r*.28,function()
            paletteShader:send('centerDepth',depth-5)
            paletteShader:send('domeRadius',0)
            -- A shallow socket follows the glass rather than widening its outline.
            g.setColor(.19,.28,.30,1)
            local base=damage==2 and .74 or damage==1 and .80 or .94
            local socket=r*base*magnification
            g.ellipse('fill',px,py+2.4*magnification,socket,socket*.34,48)
            g.setColor(1,1,1,1)
            paletteShader:send('centerDepth',depth)
            paletteShader:send('domeRadius',r)
            g.draw(sprite,px,py,0,magnification/unit,magnification/unit,sprite:getWidth()/2,sprite:getHeight()/2)
        end)
    end
    -- A hollow, tapering yoke hangs from the central district. Alternate
    -- views reveal its thickness, with open sky visible through its centre.
    local arch={{-21,11},{-19,-8},{-10,-23},{0,-29},{10,-23},{19,-8},{21,11}}
    for i=1,#arch-1 do
        if not (ruins and (i==3 or i==4)) then
            local a,b=arch[i],arch[i+1]
            local function section(p,front,inner)
                return {p[1]*(inner and .70 or 1),-6+front,p[2]+(inner and 5 or 0)}
            end
            local near=c>=0 and 3 or -3
            face({section(a,near,false),section(b,near,false),section(b,near,true),section(a,near,true)},'stone',.86)
            face({section(a,-near,false),section(b,-near,false),section(b,near,false),section(a,near,false)},'steel',.74)
            face({section(a,near,true),section(b,near,true),section(b,-near,true),section(a,-near,true)},'patina',.92)
        end
    end
    if damaged or ruins then
        -- Split facing plate on the arch; the wreck exposes its inner straps.
        face({{-18,-2,-7},{-13,-2,-14},{-11,-2,-16},{-14,-2,-10}},'scar',1)
        if ruins then
            face({{-10,-3,-22},{-8,-3,-21},{-5,-3,-27}},'copper',1)
            face({{10,-3,-22},{8,-3,-19},{5,-3,-25}},'steel',1.2)
            gallery(54,6,1,56,11,-2,.85)
            gallery(62,24,-2,60,19,-4,.65)
        end
    end
    gallery(-64,3,2,-9,-6,10,3.5)
    gallery(9,-6,10,48,-9,5,4)
    gallery(47,-9,5,56,-51,11,2.8)
    if ruins then
        gallery(48,-9,5,54,6,3,3.2)
        gallery(62,23,-1,70,41,-4,3.2)
    else
        if damaged then
            gallery(48,-9,5,57,12,4,3.2)
            gallery(57,12,3,60,19,1.4,1.65)
            gallery(60,19,1.4,68,37,2,3.2)
        else
            gallery(48,-9,5,68,37,2,3.2)
        end
    end
    local wear=ruins and 2 or 0
    district(-66,3,22,3,67,wear)
    district(-3,-6,33,12,23,damaged and 1 or wear)
    district(56,-51,14,12,11,damaged and 1 or wear)
    district(ruins and 72 or 68,ruins and 44 or 37,20,ruins and -6 or 3,80,
        ruins and 2 or damaged and 1 or 0)
    table.sort(queue,function(a,b)
        if a.depth==b.depth then return a.order<b.order end
        return a.depth<b.depth
    end)
    g.push('all')
    g.reset()
    g.setCanvas(canvas)
    g.clear(0,0,0,0)
    g.translate(size/2,size/2)
    g.scale(unit)
    g.setBlendMode('alpha','premultiplied')
    paletteShader=paletteShader or g.newShader(paletteSource)
    g.setShader(paletteShader)
    for _,cmd in ipairs(queue) do cmd.draw() end
    g.pop()
end
local function pose(state,frame,ix,iy)
    local key=state..frame..':'..ix..':'..iy
    serial=serial+1
    local entry=poses[key]
    if not entry then
        local count,oldest=0,nil
        for k,v in pairs(poses) do
            count=count+1
            if not oldest or v.used<poses[oldest].used then oldest=k end
        end
        if count>=10 then entry=poses[oldest];poses[oldest]=nil
        else
            entry={canvas=g.newCanvas(size,size,{dpiscale=1})}
            entry.canvas:setFilter('nearest','nearest')
        end
        bake(entry.canvas,state,frame*math.pi/90,ix,iy)
        poses[key]=entry
    end
    entry.used=serial
    return entry.canvas
end
function Art.render(station,camera,x,y,radius,alpha,rotation,state)
    if radius<=0 or alpha<=0 then return end
    local yaw=station.rotation or rotation or 0
    local ix,iy=View.sample(station,camera,radius)
    local image=pose(state or 'operational',math.floor(yaw*90/math.pi+.5)%180,ix,iy)
    g.push('all')
    g.translate(x,y)
    g.setBlendMode('alpha','premultiplied')
    g.setColor(alpha,alpha,alpha,alpha)
    local scale=radius/(90*unit)
    g.draw(image,0,0,0,scale,scale,size/2,size/2)
    g.pop()
end
return Art
