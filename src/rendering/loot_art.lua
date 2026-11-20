-- Pixel sprites in local hull coordinates. The bevels, lids and their moving
-- hardware share the same oblique projection so a joint stays on its plate.
local Art={}
local g=love.graphics
local colors={}
local function ink(hex)
    local color=colors[hex]
    if not color then
        color={math.floor(hex/65536)/255,math.floor(hex/256)%256/255,(hex%256)/255}
        colors[hex]=color
    end
    g.setColor(color)
end
local function point(x,y,z)
    return x*.92-y*.43,x*.26+y*.67-z*.86
end
local function face(color,...)
    local xyz={...}
    local xy={}
    for i=1,#xyz,3 do
        local x,y=point(xyz[i],xyz[i+1],xyz[i+2])
        xy[#xy+1]=x
        xy[#xy+1]=y
    end
    ink(color)
    g.polygon('fill',xy)
end
-- Octagonal footprint cuts the corners while preserving a broad cubic face.
local function plate(x,y,w,d,z,h,cut,top,front,side)
    local x0,x1,y0,y1=x-w/2,x+w/2,y-d/2,y+d/2
    local ring={{x0+cut,y0},{x1-cut,y0},{x1,y0+cut},{x1,y1-cut},
        {x1-cut,y1},{x0+cut,y1},{x0,y1-cut},{x0,y0+cut}}
    local roof={}
    for i,a in ipairs(ring) do
        local b=ring[i%8+1]
        if b[1]~=a[1] or b[2]~=a[2] then
            local ax,ay=point(a[1],a[2],z+h)
            local bx,by=point(b[1],b[2],z+h)
            if bx<ax then
                face(i==5 and front or side,a[1],a[2],z,b[1],b[2],z,b[1],b[2],z+h,a[1],a[2],z+h)
            end
            roof[#roof+1]=ax
            roof[#roof+1]=ay
        end
    end
    ink(top)
    g.polygon('fill',roof)
end
local function well(w,d,open,empty)
    plate(0,0,w,d,-4,4,3,0x556070,0x242837,0x343a4d)
    plate(0,0,w-4,d-4,0,1,2,0x182836,0x18212e,0x18212e)
    if open>.05 and not empty then
        local r=math.min(w,d)*.21
        face(0x449aab,-r,0,2,0,-r,2,0,0,5)
        face(0x96f2e6,0,-r,2,r,0,2,0,0,5)
        face(0x58c6ce,-r,0,2,0,0,5,r,0,2,0,r,2)
    end
end
local function vault(t,empty)
    local rise=math.min(1,t/.75)*10
    local gap=math.max(0,(t-.25)/.75)*3
    local top=16+gap
    -- A stepped radius rolls the bottom and lid into the vertical faces.
    plate(0,0,29,29,-15,1.5,3,0xbc8c5b,0x634359,0x443447)
    plate(0,0,32,32,-13.5,2,4,0xe4b77e,0x9b6a59,0x674955)
    plate(0,0,33,33,-11.5,11,4,0xc69b72,0xb37c64,0x795260)
    -- Recessed collar stays continuous across the opening at the equator.
    plate(0,0,30,30,-.5,1+gap,3,0x554758,0x483945,0x312e40)
    plate(0,0,33,33,.5+gap,12,4,0xe1b677,0xd4a278,0x946765)
    plate(0,0,32,32,12.5+gap,2,4,0xf1cf92,0xe4be86,0xb88d70)
    plate(0,0,30,30,14.5+gap,1.5,3.5,0xf4d69a,0xe8c18c,0xd0a47c)
    -- The gold clasp crosses the belt when shut. Both halves stay riveted
    -- to their own shell as the narrow equatorial opening appears.
    face(0x996455,-4,16.5,-6,4,16.5,-6,4,16.5,-1,-4,16.5,-1)
    face(0xeac283,-3,16.5,-4,3,16.5,-4,3,16.5,-1,-3,16.5,-1)
    face(0xffdb96,-4,16.5,1+gap,4,16.5,1+gap,4,16.5,7+gap,0,16.5,9+gap,-4,16.5,7+gap)
    face(0xa97854,-2,16.5,2+gap,2,16.5,2+gap,2,16.5,5+gap,-2,16.5,5+gap)
    -- Shallow grooves locate the centre tile within the three-by-three lid.
    for _,v in ipairs({-5.3,5.3}) do
        face(0xc6a274,v-.45,-14,top,v+.45,-14,top,v+.45,14,top,v-.45,14,top)
        face(0xc6a274,-14,v-.45,top,14,v-.45,top,14,v+.45,top,-14,v+.45,top)
    end
    plate(0,0,12,12,top,.5,1.8,0x725464,0x966c5d,0x77525a)
    -- Only the central plug rises. Its guide and the parts above it overlap
    -- at every frame, so the lifted tile remains attached to the cube.
    plate(0,0,9,9,top+.5,rise+.3,1,0x78878c,0x645669,0x433e51)
    if rise>1 then
        local light=empty and 0x665968 or 0x69d4cd
        plate(0,0,9.4,9.4,top+rise*.35,rise*.32,1,light,light,empty and 0x4d4555 or 0x389b9d)
    end
    plate(0,0,10.5,10.5,top+rise+.6,1.5,1.6,0xffe4aa,0xbf895b,0x936751)
    local z=top+rise+2.1
    face(0x705564,-4,0,z,0,-4,z,4,0,z,0,4,z)
    face(empty and 0x98817b or 0x8bf1db,-2.6,0,z,0,-2.6,z,2.6,0,z,0,2.6,z)
end

-- A folded corner guard is painted on the block's roof and only on its
-- camera-facing walls. The return around the corner follows the cut bevel.
local function cornerGuard(x,y,w,d,h,sx,sy)
    local X,Y=x+sx*w/2,y+sy*d/2
    local cut,arm,lip=1.3,5,1.5
    local function patch(color,coords)
        local vertices={}
        for i=1,#coords,3 do
            vertices[#vertices+1]=X-sx*coords[i]
            vertices[#vertices+1]=Y-sy*coords[i+1]
            vertices[#vertices+1]=coords[i+2]
        end
        face(color,unpack(vertices))
    end
    if sx==1 then patch(0xa56b42,{0,cut,1,0,arm,1,0,arm,h,0,cut,h}) end
    if sy==1 then patch(0xc38b52,{cut,0,1,arm,0,1,arm,0,h,cut,0,h}) end
    if sy==1 then
        patch(0xb67d4d,{0,cut,1,cut,0,1,cut,0,h,0,cut,h})
    end
    patch(0xffca7a,{cut,0,h,arm,0,h,arm,lip,h,0,lip,h,0,cut,h})
    patch(0xffca7a,{0,lip,h,lip,lip,h,lip,arm,h,0,arm,h})
end
local function locker(t,empty)
    well(35,18,t,empty)
    for _,sy in ipairs({-1,1}) do
        for _,sx in ipairs({-1,1}) do
            local x,y=sx*(8.7+5*t),sy*(4.5+5*t)
            local w=17.1-6*t
            plate(x,y,w,8.8,0,5+4*t,1.3,0x5a8292,0x35475d,0x273b50)
            plate(x,y,w-3,6.3,5+4*t,1,1,0x90b1b9,0x516d7b,0x415b6d)
            cornerGuard(x,y,w,8.8,5+4*t,sx,sy)
        end
    end
end
local function cases(t,empty)
    -- Offset miniature cases, stepped iridescent inlays and a folding handle.
    plate(-1,1,21,12,-2,3,1.3,0x5b638d,0x38405f,0x334457)
    plate(1,0,19,10,1,2,1,0x78a2a2,0x47436f,0x46617a)
    plate(1,0,16,8,3,1,1,0x1f303c,0x596380,0x596380)
    if t>.05 and not empty then
        plate(2,0,5,3,4,1,.7,0x85f5d8,0x388e96,0x388e96)
    end
    local y,z=-1-6*t,4+5*t
    plate(-1,y,20,10-3*t,z,2,1.2,0x766593,0x4b4169,0x475471)
    plate(-1,y,16,7-2*t,z+2,1,1,0x6ac6bb,0x51758f,0x51758f)
    plate(-2,y,12,5-2*t,z+3,1,.7,0xc69bb0,0x846986,0x846986)
    plate(-2,y,7,2,z+4,1,.4,0x73739a,0x73739a,0x73739a)
    for _,x in ipairs({-4,3}) do plate(x,6,2,4,0,2,0,0x93afbb,0x4c6379,0x4c6379) end
    plate(-.5,8,9,2,0,2,0,0x7999a6,0x42556c,0x42556c)
end
-- Marker count also communicates quality when hue is hard to distinguish.
local capsuleLights={
    common={lanes=1,core=0xb4e2da,glow={.34,.71,.65},power=.50},
    rare={lanes=2,core=0x99dbff,glow={.13,.47,1},power=.86},
    exceptional={lanes=3,core=0xffe6a3,glow={1,.49,.10},power=1.12},
}
local function capsule(t,empty,quality)
    local lamp=capsuleLights[quality] or capsuleLights.common
    local lens=empty and 0x48545b or lamp.core
    plate(0,0,70,43,-9,8,8,0x586675,0x303d50,0x263344)
    plate(0,0,57,34,-1,2,5,0x1d2b39,0x273649,0x273649)
    for x=-20,20,10 do
        plate(x,0,3,29,1,1,.5,0x607781,0x374854,0x374854)
        plate(x,0,1.6,9,2,1,.4,lens,0x495967,0x495967)
    end
    for _,sign in ipairs({-1,1}) do
        local y=sign*(9+12*t)
        plate(0,y,66,17,-1,8,4,0x808f95,0x49596b,0x354457)
        plate(0,y,57,14,7,2,3,0xc2c2b0,0x87949a,0x73818c)
        plate(0,y,24,10,9,1,2,0x536b70,0x4c5e68,0x4c5e68)
        for _,x in ipairs({-23,23}) do
            plate(x,y,6,17,7,3,1,0x687881,0x465460,0x435160)
            plate(x,y,3,10,10,1,.5,lens,0x50606a,0x50606a)
        end
        for lane=1,lamp.lanes do
            local x=(lane-(lamp.lanes+1)/2)*6
            plate(x,y,3.5,6,10,1,.6,lens,0x576873,0x576873)
        end
    end
end
-- Evaluate the light in sprite pixels so reflections follow the doors at
-- every zoom and roll, without baking a texture for each idle pulse.
local lightShader
local lightSource=[[
extern vec3 glow;
extern float power;
extern float opening;
vec2 project(float x,float y,float z) {
    return vec2(.92*x-.43*y,.26*x+.67*y-.86*z);
}
float pool(vec2 d,vec2 radius) {
    d/=radius;
    return exp(-dot(d,d));
}
vec4 effect(vec4 tint,Image tex,vec2 uv,vec2 screen) {
    vec4 hull=Texel(tex,uv);
    vec2 p=uv*112.-vec2(56.,60.);
    float light=0.;
    for(int i=0;i<2;i++) {
        float y=(float(i)*2.-1.)*(9.+12.*opening);
        vec2 door=p-project(0.,y,11.);
        door.y-=door.x*(.26/.92);
        light+=.57*pool(door,vec2(13.,5.));
        for(int j=0;j<2;j++) {
            vec2 lamp=p-project(float(j)*46.-23.,y,11.);
            light+=.68*pool(lamp,vec2(5.,5.))+.23*pool(lamp,vec2(11.,9.));
        }
    }
    vec2 bay=p-project(0.,0.,3.);
    bay.y-=bay.x*(.26/.92);
    light+=opening*.62*pool(bay,vec2(24.,5.));
    float intensity=light*power;
    vec3 surface=hull.rgb+(1.-hull.rgb)*glow*min(intensity,1.);
    surface=floor(surface*63.+.5)/63.;
    float halo=clamp(intensity*.42,0.,.48);
    return vec4(mix(glow,surface,hull.a),max(hull.a,halo))*tint;
}
]]
local cache={}
function Art.draw(kind,x,y,opening,empty,quality,angle,scale)
    local frame=math.floor(math.min(1,math.max(0,opening or 0))*8+.5)
    local key=table.concat({kind,frame,empty and 1 or 0,quality or ''},':')
    local sprite=cache[key]
    if not sprite then
        local width=kind=='capsule' and 112 or 80
        sprite=g.newCanvas(width,width,{dpiscale=1,msaa=0})
        sprite:setFilter('nearest','nearest')
        g.push('all')
        g.reset()
        g.setCanvas(sprite)
        g.clear(0,0,0,0)
        g.translate(width/2,width/2+4)
        local painter=kind=='capsule' and capsule or kind==32 and vault or kind==8 and cases or locker
        painter(frame/8,empty,quality)
        g.pop()
        cache[key]=sprite
    end
    g.setColor(1,1,1,1)
    local previousShader
    local lit=kind=='capsule' and not empty
    if lit then
        local lamp=capsuleLights[quality] or capsuleLights.common
        lightShader=lightShader or g.newShader(lightSource)
        previousShader=g.getShader()
        g.setShader(lightShader)
        local t=frame/8
        local pulse=.94+.06*math.sin(love.timer.getTime()*2)
        lightShader:send('glow',lamp.glow)
        lightShader:send('opening',t)
        lightShader:send('power',lamp.power*pulse*(1+.65*math.sin(t*math.pi)))
    end
    g.draw(sprite,x,y,angle or 0,scale or 1,scale or 1,sprite:getWidth()/2,sprite:getHeight()/2)
    if lit then g.setShader(previousShader) end
end
return Art
