local Art={}
local Math=require 'src.utils.math_util'
local World=require 'src.core.world'
local Rig=require 'src.rendering.ships.frontier_boss_rig'
local Baker=require 'src.rendering.ships.pixel_pose_baker'
local poses,cacheStats
local lighting=[[
extern float bank;
extern float wear;
extern float part;
float splat(vec2 p,vec2 center,vec2 radius) {
    vec2 q=(p-center)/radius;
    return exp(-.5*dot(q,q));
}
vec4 effect(vec4 tint,Image source,vec2 uv,vec2 screen) {
    vec4 base=Texel(source,uv);
    if(base.a<.5) return vec4(0.0);
    vec2 p=uv*112.0-vec2(56.0);
    float side=part==2.0 ? -1.0 : 1.0;
    float plate=splat(p,vec2(part==1.0 ? -5.0 : side*17.0,-19.0),vec2(9.0,18.0));
    float ridge=splat(p,vec2(-4.0+bank*9.0,-29.0),vec2(3.0,12.0));
    float bounce=splat(p,vec2(side*20.0,15.0),vec2(14.0,10.0));
    float scorch=splat(p,vec2(part==1.0 ? 6.0 : side*20.0,part==1.0 ? 21.0 : 5.0),vec2(9.0,13.0));
    float damage=wear>=2.0 && (part==2.0 || wear==3.0) ? .35 : wear*.05;
    vec3 color=base.rgb*(.87+.08*bank*side)*(1.0-scorch*damage)
        +vec3(.12,.17,.24)*plate*(1.0-bank*side*.5)
        +vec3(.19,.22,.27)*ridge+vec3(.13,.026,.012)*bounce;
    return vec4(floor(clamp(color,0.0,1.0)*17.0+.5)/17.0,base.a);
}
]]
local palette={rim={.055,.075,.105},dark={.105,.14,.19},steel={.32,.39,.46},
    face={.43,.51,.58},edge={.66,.72,.74},red={.43,.105,.09},redTop={.65,.21,.14},
    seam={.075,.09,.115},copper={.43,.26,.16},raw={.58,.48,.35},warm={.96,.48,.18}}

local function geometry(part,wear)
    local vertices={}
    local function face(color,...)
        color=type(color)=='string' and palette[color] or color
        for _,triangle in ipairs(love.math.triangulate({...})) do
            for index=1,6,2 do
                vertices[#vertices+1]={triangle[index],triangle[index+1],0,0,color[1],color[2],color[3],1}
            end
        end
    end
    local function rect(color,x,y,w,h) face(color,x,y,x+w,y,x+w,y+h,x,y+h) end
    if part==1 then
        face('rim',-12,-37,12,-37,18,-20,15,27,8,37,-8,37,-15,27,-18,-20)
        face('dark',-11,-34,11,-34,15,-20,12,27,6,34,-6,34,-12,27,-15,-20)
        -- Raised prow: stepped shoulder, bevel and a narrow dorsal crest.
        face('steel',-11,-32,0,-40,11,-32,13,-21,8,-12,-8,-12,-13,-21)
        face('face',-8,-31,0,-37,8,-31,9,-23,4,-17,-7,-18,-10,-23)
        face('edge',-8,-31,0,-37,0,-34,-6,-29,-8,-21,-10,-23)
        face('dark',8,-31,12,-22,7,-14,3,-17,9,-24)
        face('steel',-3,-35,0,-38,3,-35,3,-25,0,-23,-3,-25)
        rect('seam',-5,-27,10,4);rect('warm',-4,-27,8,1)
        face('steel',-10,-10,10,-10,11,22,6,29,-6,29,-11,22)
        face('edge',-10,-10,-8,-10,-8,20,-5,27,-7,27,-11,21)
        face('dark',8,-10,11,-9,11,22,6,29,5,26,8,20)
        face('rim',-7,-7,7,-7,8,15,0,21,-8,15)
        face('copper',-5,-5,5,-5,6,13,0,17,-6,13)
        face('dark',-3,-3,3,-3,4,12,0,15,-4,12)
        for _,side in ipairs({-1,1}) do
            for row=0,3 do rect('seam',side==1 and 9 or -11,-4+row*5,2,2) end
            rect('edge',side==1 and 11 or -12,-17,1,2)
        end
        face('red',-9,23,-3,27,3,27,9,23,7,31,-7,31)
        rect('dark',-8,31,16,4);rect('warm',-4,32,8,1)
        for _,side in ipairs({-1,1}) do
            rect('rim',side==1 and 3 or -9,29,6,5)
            rect('steel',side==1 and 4 or -8,29,4,1)
        end
        if wear>=1 then
            face('raw',5,-31,8,-28,7,-26,5,-28)
            rect('seam',-10,19,3,1);rect('raw',-10,18,2,1)
            rect('dark',5,24,3,2)
        end
        if wear>=2 then
            face('seam',7,-21,11,-22,9,-17,7,-16)
            face('raw',9,-22,11,-23,10,-19)
            rect('seam',8,11,3,5);rect('copper',8,12,1,3)
        end
        if wear==3 then
            face('rim',-7,-7,7,-7,6,17,0,21,-7,14)
            for row=0,3 do rect('copper',-5,-4+row*5,9,1) end
            face('raw',-7,-8,-3,-5,-6,0,-8,-2)
            face('dark',-7,23,-1,25,1,32,-7,30)
            rect('raw',-6,24,2,4)
        end
    else
        local side=part==2 and -1 or 1
        local function wing(color,...)
            local points={...}
            for index=1,#points,2 do points[index]=points[index]*side end
            face(color,unpack(points))
        end
        local function panel(color,x,y,w,h) rect(color,side==1 and x or -(x+w),y,w,h) end
        wing('rim',0,-12,16,-25,30,-21,37,-8,30,21,13,28,4,12)
        wing('dark',2,-10,17,-23,29,-19,34,-7,28,19,14,25,6,11)
        wing('steel',4,-10,17,-21,28,-17,32,-7,23,4,9,5)
        wing('face',6,-10,18,-19,27,-15,28,-8,22,-3,10,0)
        wing('edge',6,-10,18,-19,20,-18,10,-8,8,-1,6,-2)
        wing('dark',27,-15,32,-7,23,4,21,1,28,-8)
        wing('seam',8,5,30,-1,28,19,14,25,7,17)
        if wear>=2 and (side==-1 or wear==3) then
            -- Missing armor reveals recessed ribs, cables and a broken raised rim.
            wing('dark',10,8,28,2,25,18,15,23,10,17)
            for row=0,3 do panel('copper',14,7+row*3,9-row,1) end
            panel('steel',13,9,2,10);panel('rim',17,9,2,10)
            wing('red',9,7,17,5,16,9,12,12,14,18,18,21,15,24,9,17)
            wing('redTop',9,7,17,5,16,7,11,10)
            wing('red',26,4,30,1,27,18,23,21,23,16,25,13,23,9)
            wing('raw',26,4,28,3,25,11,23,10)
            wing('raw',12,14,15,18,13,20,11,17)
            wing('rim',18,-26,25,-25,27,-12,22,-10,18,-15)
            panel('copper',20,-20,3,4);panel('raw',19,-24,2,3)
        else
            wing('red',10,7,29,0,26,18,15,23,9,16)
            wing('redTop',12,8,27,3,25,10,13,15)
            wing('copper',13,15,25,10,24,12,14,18)
            wing('dark',17,-27,25,-27,29,-8,21,-5)
            wing('steel',18,-26,24,-26,26,-12,23,-9,20,-11)
            panel('warm',19,-24,5,2);panel('edge',19,-26,4,1)
        end
        panel('dark',10,19,12,3);panel('steel',12,19,8,1)
        for row=0,2 do panel('rim',26,-6+row*3,3,1) end
        panel('edge',9,-7,1,2);panel('edge',23,15,1,2)
        if wear>=1 then
            wing('raw',29,-10,31,-8,29,-5,28,-7)
            panel('seam',14,10,3,1);panel('raw',14,9,2,1)
        end
    end
    return love.graphics.newMesh(vertices,'triangles','static')
end

local function ensurePoses(yieldWork)
    if poses then return end
    local meshes={}
    for wear=0,3 do
        meshes[wear]={}
        for part=1,3 do meshes[wear][part]=geometry(part,wear) end
    end
    poses,cacheStats=Baker.build({yieldWork=yieldWork,width=112,height=112,parts=3,variants=4,lighting=lighting,
        rootX=function(part) return part==1 and 0 or part==2 and -Rig.pivot or Rig.pivot end,
        paint=function(part,wear) love.graphics.setColor(1,1,1);love.graphics.draw(meshes[wear][part]) end})
    for _,parts in pairs(meshes) do for _,mesh in ipairs(parts) do mesh:release() end end
end

function Art.getCacheStats() return cacheStats end
function Art.preload(yieldWork) ensurePoses(yieldWork) end
function Art.damageStage(boss,wreck)
    if wreck then return 3 end
    local health=boss.ship.stats and boss.ship.stats.health
    local ratio=health and health.currentHealth/health.maxHealth or 1
    return ratio<=.5 and 2 or ratio<=.75 and 1 or 0
end

function Art.draw(boss,wreck)
    ensurePoses()
    local g,ship=love.graphics,boss.ship
    local wear=Art.damageStage(boss,wreck)
    local spread=wreck and .27 or boss.armSpread or 0
    local bank=wreck and 0 or Rig.bank(boss.bank)
    local index=bank*2
    local alpha=wreck and 1 or World.get('interpolationAlpha') or 1
    local pose={x=Math.lerp(ship.prevX or ship.x,ship.x,alpha),y=Math.lerp(ship.prevY or ship.y,ship.y,alpha),
        rotation=Math.lerpAngle(ship.prevRotation or ship.rotation,ship.rotation,alpha)}
    local light=wreck and .68 or 1
    local time=boss.time or love.timer.getTime()
    g.push('all');g.translate(pose.x,pose.y);g.rotate(pose.rotation);g.scale(Rig.scale)
    for _,side in ipairs({-1,1}) do
        local x,y=Rig.project(side*Rig.pivot,0,bank)
        g.setColor(.075*light,.10*light,.14*light);g.setLineWidth(12)
        local sx,sy=Rig.project(side*9,1,bank);g.line(sx,sy,x,y)
        g.setColor(.35*light,.40*light,.45*light);g.setLineWidth(5);g.line(sx,sy,x,y)
    end
    local function arm(side)
        local x,y=Rig.project(side*Rig.pivot,0,bank)
        g.setColor(light,light,light)
        g.draw(poses[wear][side==-1 and 2 or 3][index],x,y,side*spread,1,1,56,56)
    end
    -- The far pod goes below the spine, the near pod overlaps its shoulder.
    local far=bank>=0 and -1 or 1
    arm(far)
    g.setColor(light,light,light);g.draw(poses[wear][1][index],0,0,0,1,1,56,56)
    arm(-far)
    local exposure=wreck and 0 or boss.coreExposure or 0
    local coreX,coreY=Rig.project(-bank*1.5,5,bank)
    if not wreck then
        local pulse=.75+.25*math.sin(time*5)^2
        g.setColor(1-exposure*.64,.43+exposure*.5,.18+exposure*.82,.6+.3*pulse)
        for row=0,3 do
            local x,y=Rig.project(-3,-3+row*4,bank)
            g.rectangle('fill',x,y,6,1+exposure)
        end
        g.setColor(.25,.85,1,exposure*.22)
        g.circle('fill',coreX,coreY,8)
        for _,side in ipairs({-1,1}) do
            local x,y=Rig.project(side*6,34,bank)
            g.push();g.translate(x,y);g.rotate(-bank*.15)
            ship:drawThrusterFlame(0,0,7,{1,.38,.21});g.pop()
        end
    else
        g.setColor(.9,.38,.12,.25+.2*math.sin(time*2)^2)
        g.rectangle('fill',coreX-1,coreY+8,2,1)
    end
    if wear>=2 then
        local sx,sy=Rig.armPoint(-1,spread,bank,-19,6)
        local blink=math.sin(time*13)+math.sin(time*7)
        g.setColor(1,.35,.08,wreck and .2 or .35+.2*math.max(0,blink))
        g.rectangle('fill',sx,sy,2,1)
        if not wreck then
            for spark=1,3 do
                local age=(time*.7+spark*.31)%1
                g.setColor(.9,.48,.18,(1-age)*.45)
                g.rectangle('fill',math.floor(sx-4*age+spark),math.floor(sy+age*9),1,1)
            end
            local age=time-(boss.fractureTime or -100)
            if age>=0 and age<.7 then
                for chip=1,4 do
                    local dx,dy=-8-chip*5,chip*4-10
                    g.setColor(.62,.38,.22,(1-age/.7)*.8)
                    g.rectangle('fill',math.floor(sx+dx*age),math.floor(sy+dy*age+age*age*12),2,1)
                end
            end
        end
    end
    g.pop()
    if not wreck and boss.emitter then
        g.push('all')
        for _,side in ipairs({-1,1}) do
            if wear<2 or side==1 then
                local x,y=Rig.emitter(ship,spread,boss.bank,side,pose)
                local charge=boss.phase=='sweepWarning' or boss.phase=='pinWarning' or boss.phase=='chargeWarning'
                local intensity=charge and math.min(1,boss.elapsed/1.3) or .12
                g.setColor(1,.53,.24,.06+.12*intensity);g.circle('fill',x,y,7+7*intensity)
                g.setColor(1,.76,.42,.5+.4*intensity);g.circle('fill',x,y,2+intensity)
                if charge then
                    local spin=time*2.8*side
                    g.setLineWidth(1.5);g.arc('line','open',x,y,10+4*(1-intensity),spin,spin+math.pi*1.3)
                end
            end
        end
        g.pop()
    end
end
function Art.drawWreck(wreck)
    Art.draw({ship={x=wreck.x,y=wreck.y,rotation=wreck.rotation or math.pi}},true)
end
return Art
