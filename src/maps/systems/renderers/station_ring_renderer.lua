local depthColor=require 'src.maps.systems.renderers.station_depth_color'
local View=require 'src.maps.systems.renderers.station_parallax'
local Model = require 'src.maps.systems.renderers.station_ring_model'
local makePoseCache = require 'src.maps.systems.renderers.station_pose_cache'
local g = love.graphics
local Renderer = {}
local size, unit, frames = 384, 1.19, 120

local projection = depthColor..[[
extern vec2 yaw;
]]..View.shader..[[
extern vec2 carrierYaw;
extern vec2 pitch;
extern float wear;
varying vec3 surface;
varying vec3 location;
varying vec3 normal;
varying vec3 track;
#ifdef VERTEX
attribute vec3 Material;
attribute vec3 FaceNormal;
attribute vec4 Route;
vec3 orient(vec3 v) {
    if(Route.w>.5) v.xy=vec2(dot(v.xy,vec2(carrierYaw.x,-carrierYaw.y)), dot(v.xy,carrierYaw.yx));
    float y = dot(v.xy,yaw.yx);
    return vec3(dot(v.xy,vec2(yaw.x,-yaw.y)), y*pitch.x-v.z*pitch.y,
                y*pitch.y+v.z*pitch.x);
}
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    location=orient(vertex_position.xyz);
    normal=orient(FaceNormal);
    surface=Material;
    track=Route.xyz;
    vec4 clip=projectStation(transform_projection,location);
    clip.z=-location.z*.006*clip.w;
    return clip;
}
#endif
#ifdef PIXEL
#ifdef DRAW_CARRIERS
extern Image staticHull;
#endif
vec4 effect(vec4 tint, Image tex, vec2 uv, vec2 pixel) {
    // The static pose carries its nearest surface depth in the alpha byte.
    float hullDepth=.5+location.z/256.;
#ifdef DRAW_CARRIERS
    if(Texel(staticHull,pixel/love_ScreenSize.xy).a>hullDepth+.5/255.) discard;
#endif
    vec3 n=normalize(normal);
    if(n.z<0.) n=-n;
    vec3 light=normalize(vec3(-.48,-.69,.65));
    float diffuse=max(dot(n,light),0.);
    // Store cylindrical coordinates and stationary illumination in the pose.
    float farTone=recession(location.z/85.);
    if(track.z>.5) {
        // Four lanes share the blue byte with six bits of depth tone.
        float encoded=(track.z-1.)*64.+floor(farTone*63.+.5);
        return vec4(track.xy,encoded/255.,.2+.4*diffuse);
    }
    vec2 d=(location.xy-vec2(-38.,-40.))/80.;
    vec3 rgb=surface*(.39+.65*diffuse+.14*exp(-dot(d,d)));
    rgb+=vec3(.10,.13,.15)*pow(max(dot(n,normalize(light+vec3(0.,0.,1.))),0.),18.);
    if(surface.g>.87 || surface.r>.97) rgb=surface;
    rgb=mix(rgb,vec3(dot(rgb,vec3(.28,.54,.18))),wear*.17);
    rgb=depthColor(rgb,farTone*(surface.g>.87 || surface.r>.97 ? .28 : 1.));
    #ifdef DRAW_CARRIERS
    hullDepth=1.;
#endif
    return vec4(floor(clamp(rgb,0.,1.)*31.+.5)/31.,hullDepth);
}
#endif
]]
local cabinShader
local display = depthColor..[[
extern Image elevators;
extern float clockPhase;
extern float damaged;
vec4 effect(vec4 tint, Image tex, vec2 uv, vec2 screen) {
    vec4 p=Texel(elevators,uv);
    if(p.a<.01) {
        vec4 hull=Texel(tex,uv);
        return hull.a>0. ? vec4(hull.rgb*tint.rgb,tint.a) : vec4(0.);
    }
    if(p.a<.65) {
        float code=floor(p.b*255.+.5);
        float lane=1.+floor(code/64.);
        float tone=mod(code,64.)/63.;
        float phase=fract(clockPhase+lane*.23);
        // Dwell behind each terminal before the return journey.
        float car=clamp(1.-abs(phase*2.-1.)*1.34,-.12,1.);
        float along=abs(p.r-car);
        vec3 rgb=vec3(.46,.58,.63);
        if(fract(p.r*5.)<.055) rgb=vec3(.20,.28,.32);
        if(along<.075) {
            float window=p.g;
            rgb=vec3(.83,.86,.81);
            if(along<.047 && window<.78)
                rgb=mix(vec3(.26,.95,.96),vec3(1.,.67,.24),damaged);
        }
        rgb=floor(rgb*(.49+1.36*(p.a-.2))*31.+.5)/31.;
        p.rgb=depthColor(rgb,tone*(along<.047 ? .28 : 1.));
    }
    return vec4(p.rgb*tint.rgb,tint.a);
}
]]
local orbitFrames=240
local orbitPeriod={operational=24,damaged=36}
local function configure(shader,state,frame,tilt,ix,iy,orbit)
    shader:send('cameraOffset',{View.offset(ix,iy,100)})
    shader:send('focalDistance',340)
    local angle=frame*math.pi*2/frames
    shader:send('carrierYaw',{math.cos(orbit),math.sin(orbit)})
    local elevation=math.rad(38+tilt*2)
    shader:send('yaw',{math.cos(angle),math.sin(angle)})
    shader:send('pitch',{math.sin(elevation),math.cos(elevation)})
    shader:send('wear',state=='ruins' and 2 or state=='damaged' and 1 or 0)
end
local hullPose=makePoseCache(Model,projection,size,unit,12,function(shader,state,frame,tilt,ix,iy)
    configure(shader,state,frame,tilt,ix,iy,0)
end)
local carriers={build=function(state) return Model.build(state,'carriers') end}
local elevatorPose=makePoseCache(carriers,'#define DRAW_CARRIERS\n'..projection,size,unit,3,
    function(shader,state,key,tilt,ix,iy)
        local frame=math.floor(key/orbitFrames)
        configure(shader,state,frame,tilt,ix,iy,key%orbitFrames*2*math.pi/orbitFrames)
        shader:send('staticHull',hullPose(state,frame,tilt,ix,iy))
    end)

function Renderer.render(station,camera,x,y,radius,alpha,rotation,state)
    if alpha<=0 or radius<=0 then return end
    state=state or 'operational'
    local seed=station.seed or 0
    local angle=station.rotation or rotation or 0
    local frame=math.floor(angle*frames/(2*math.pi)+.5)%frames
    local time=love.timer.getTime()+seed%13
    local period=orbitPeriod[state]
    local orbit=period and math.floor((time/period%1)*orbitFrames+.5)%orbitFrames or 0
    local ix,iy=View.sample(station,camera,radius)
    local sprite=hullPose(state,frame,seed%5,ix,iy)
    local elevators=elevatorPose(state,frame*orbitFrames+orbit,seed%5,ix,iy)
    cabinShader=cabinShader or g.newShader(display)
    g.push('all')
    g.translate(x,y)
    g.setColor(1,1,1,alpha)
    g.setShader(cabinShader)
    cabinShader:send('elevators',elevators)
    cabinShader:send('clockPhase',(time/9)%1)
    cabinShader:send('damaged',state=='damaged' and 1 or 0)
    local scale=radius/(100*unit)
    g.draw(sprite,0,0,0,scale,scale,size/2,size/2)
    g.pop()
end
return Renderer
