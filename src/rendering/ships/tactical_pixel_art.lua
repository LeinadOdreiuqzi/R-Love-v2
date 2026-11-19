local Art=require 'src.rendering.ships.ship_art'
local Baker=require 'src.rendering.ships.pixel_pose_baker'
local Tactical={}
local designs={
    FIGHTER={width=76,height=88,scale=64/3.10,amplitude=1,thickness=.15,
        engage=20,recover=13,turnRate=2.0,glass={.42,.22,.055},plate={.27,.105,.115},
        lightX=.94,lightY=.18},
    SENTINEL={width=80,height=100,scale=64/2.66,amplitude=.67,thickness=.24,
        engage=8,recover=7,turnRate=2.6,glass={.09,.27,.30},plate={.15,.22,.28},
        lightX=.78,lightY=-.46},
}
local lighting=[[
extern float bank;
extern vec2 hullExtent;
extern vec2 shoulder;
extern vec3 glassLight;
extern vec3 plateLight;
extern float irisY;
float spot(vec2 p,vec2 center,vec2 radius) {
    vec2 d=(p-center)/radius;
    return exp(-.5*dot(d,d));
}
vec4 effect(vec4 tint,Image tex,vec2 uv,vec2 screen) {
    vec4 base=Texel(tex,uv);
    if(base.a<.5) return vec4(0.);
    vec2 p=(uv-.5)*hullExtent;
    p.x/=1.-.14*abs(bank)+.10*bank*sign(p.x);
    p.y-=bank*p.x*.32;
    float left=spot(p,vec2(-shoulder.x,shoulder.y),vec2(.23,.54));
    float right=spot(p,shoulder,vec2(.23,.54));
    float glass=spot(p,vec2(bank*.12,irisY),vec2(.16,.37));
    float rim=spot(p,vec2(-.18+bank*.22,-1.05),vec2(.19,.48));
    vec3 rgb=base.rgb*(.86+.12*bank*clamp(p.x,-1.,1.));
    rgb+=plateLight*((.89-.66*bank)*left+(.71+.66*bank)*right+.58*rim);
    rgb+=glassLight*glass;
    return vec4(floor(clamp(rgb,0.,1.)*23.+.5)/23.,1.);
}
]]
local function prepare(id,d)
    if d.poses then return end
    local hull={shipType=id}
    local poses=Baker.build{
        width=d.width,height=d.height,variants=1,parts=1,bankAmplitude=d.amplitude,
        layerStep=d.thickness/8,lighting=lighting,rootX=function() return 0 end,
        paint=function() Art.draw(hull,d.scale,false,true) end,
        setLights=function(shader)
            shader:send('hullExtent',{d.width/d.scale,d.height/d.scale})
            shader:send('shoulder',{d.lightX,d.lightY})
            shader:send('irisY',id=='FIGHTER' and -.75 or -.08)
            shader:send('glassLight',d.glass)
            shader:send('plateLight',d.plate)
        end,
    }
    d.poses=poses[0][1]
end
function Tactical.preload()
    for id,d in pairs(designs) do prepare(id,d) end
end
function Tactical.update(ship,dt,previousRotation)
    local d=designs[ship.shipType]
    if not d or dt<=0 then return end
    local turn=(ship.rotation-previousRotation+math.pi)%(2*math.pi)-math.pi
    local speed=math.sqrt(ship.dx^2+ship.dy^2)
    local target=math.max(-1,math.min(1,turn/(dt*d.turnRate)))*math.min(1,speed/5)
    local old=ship.visualBank or 0
    local rate=math.abs(target)>math.abs(old) and d.engage or d.recover
    ship.visualBank=old+(target-old)*(1-math.exp(-dt*rate))
end
-- In the stationary hangar exhibit the existing rotation control also
-- sweeps through the baked poses. Flight uses the measured turn rate.
function Tactical.previewBank(ship,phase)
    if designs[ship.shipType] then ship.visualBank=phase and math.sin(phase) or 0 end
end
local function indexOf(ship)
    return math.max(-2,math.min(2,math.floor((ship.visualBank or 0)*2+.5)))
end
-- Local display coordinates only. Physics and weapon trajectories use their original sockets.
function Tactical.project(ship,x,y,engine)
    local d=designs[ship.shipType]
    if not d then return x,y end
    local bank=indexOf(ship)*.5*d.amplitude
    local offset=engine and d.thickness*.5*ship.size*(ship.worldScale or 1) or 0
    if engine and ship.shipType=='SENTINEL' then y=y+.25*ship.size*(ship.worldScale or 1) end
    return x*(1-.14*math.abs(bank)+.10*bank*(x<0 and -1 or 1))-bank*.62*offset,
        y+bank*x*.32+(.74+.20*math.abs(bank))*offset,-bank*.18
end
function Tactical.draw(ship,size,abandoned,classic)
    local d=designs[ship.shipType]
    if not d then return false end
    if classic then return Art.draw(ship,size,abandoned) end
    prepare(ship.shipType,d)
    Art.drawEngines(ship,size,abandoned,Tactical.project)
    local g=love.graphics
    local value=abandoned and .60 or 1
    g.setColor(value,value,value,1)
    g.draw(d.poses[abandoned and 0 or indexOf(ship)],0,0,0,size/d.scale,size/d.scale,d.width/2,d.height/2)
    Art.drawLights(ship,size,abandoned,Tactical.project)
    return true
end
return Tactical
