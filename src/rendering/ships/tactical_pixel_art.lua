local Art=require 'src.rendering.ships.ship_art'
local Baker=require 'src.rendering.ships.pixel_pose_baker'
local Tactical={}
local designs={
    FIGHTER={width=76,height=88,scale=64/3.10,amplitude=1,thickness=.15,
        engage=20,recover=13,turnRate=2.0,glass={.42,.22,.055},plate={.27,.105,.115},
        lightX=.94,lightY=.18,irisY=-.75},
    SENTINEL={width=80,height=100,scale=64/2.66,amplitude=.67,thickness=.24,
        engage=8,recover=7,turnRate=2.6,glass={.09,.27,.30},plate={.15,.22,.28},
        lightX=.78,lightY=-.46,irisY=-.08},
    EXPLORER={width=76,height=102,scale=64/2.76,amplitude=.84,thickness=.12,
        engage=12,recover=6,turnRate=2.1,glass={.09,.24,.32},plate={.11,.17,.29},
        lightX=.92,lightY=.24,irisY=-.63},
    CARGO={width=76,height=90,scale=64/2.72,amplitude=.46,thickness=.34,
        engage=5,recover=4,turnRate=2.3,glass={.08,.19,.17},plate={.30,.19,.07},
        lightX=.81,lightY=.17,irisY=-.95},
    GUNSHIP={width=76,height=96,scale=64/2.66,amplitude=.64,thickness=.31,
        engage=8,recover=6,turnRate=2.3,glass={.31,.16,.07},plate={.21,.16,.15},
        lightX=.85,lightY=-.52,irisY=-.65},
    SALVAGER={width=78,height=96,scale=64/2.53,amplitude=.61,thickness=.20,
        engage=8,recover=6,turnRate=2.1,glass={.10,.24,.18},plate={.24,.20,.09},
        lightX=1.10,lightY=-.92,irisY=-.97},
    TITAN_EXCAVATOR={width=146,height=198,scale=128/2.68,amplitude=.40,thickness=.39,
        engage=3.8,recover=3.4,turnRate=1.8,glass={.10,.27,.14},plate={.32,.23,.09},
        lightX=.97,lightY=-1.18,irisY=.56},
    ECLIPSE={width=148,height=218,scale=128/2.56,amplitude=.44,thickness=.33,
        engage=4.3,recover=3.6,turnRate=1.8,glass={.29,.12,.25},plate={.21,.12,.27},
        lightX=.87,lightY=.30,irisY=-.55},
    ARK_MONOLITH={width=148,height=194,scale=128/2.78,amplitude=.34,thickness=.29,
        engage=3.2,recover=3,turnRate=1.6,glass={.10,.26,.29},plate={.26,.21,.13},
        lightX=1.02,lightY=.02,irisY=0},
}
-- The legacy Dreadnought uses the Eclipse hull and shares its pose textures.
local function designFor(ship)
    return designs[ship.shipType=='DREADNOUGHT' and 'ECLIPSE' or ship.shipType]
end
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
            shader:send('irisY',d.irisY)
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
    local d=designFor(ship)
    if not d or ship.convoy or dt<=0 then return end
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
    if designFor(ship) then ship.visualBank=phase and math.sin(phase) or 0 end
end
local function indexOf(ship)
    return math.max(-2,math.min(2,math.floor((ship.visualBank or 0)*2+.5)))
end
-- Local display coordinates only. Physics and weapon trajectories use their original sockets.
function Tactical.project(ship,x,y,engine)
    local d=designFor(ship)
    if not d or ship.convoy or (ship.useStarterSprite and ship.sprite and ship.shipType=='EXPLORER') then
        return x,y
    end
    local bank=indexOf(ship)*.5*d.amplitude
    local offset=engine and d.thickness*.5*ship.size*(ship.worldScale or 1) or 0
    if engine and ship.shipType=='SENTINEL' then y=y+.25*ship.size*(ship.worldScale or 1) end
    return x*(1-.14*math.abs(bank)+.10*bank*(x<0 and -1 or 1))-bank*.62*offset,
        y+bank*x*.32+(.74+.20*math.abs(bank))*offset,-bank*.18
end
function Tactical.draw(ship,size,abandoned,classic)
    local d=designFor(ship)
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
