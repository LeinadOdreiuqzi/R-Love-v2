local Model = require 'src.maps.systems.renderers.station_ring_model'
local makePoseCache = require 'src.maps.systems.renderers.station_pose_cache'
local g = love.graphics
local Renderer = {}
local size, unit, frames = 256, 1.19, 120

local projection = [[
extern vec2 yaw;
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
    vec4 clip=transform_projection*vec4(location.xy,0.,1.);
    clip.z=-location.z*.006*clip.w;
    return clip;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 tint, Image tex, vec2 uv, vec2 pixel) {
    vec3 n=normalize(normal);
    if(n.z<0.) n=-n;
    vec3 light=normalize(vec3(-.48,-.69,.65));
    float diffuse=max(dot(n,light),0.);
    // Store cylindrical coordinates and stationary illumination in the pose.
    if(track.z>.5) return vec4(track.xy,track.z*.2,.2+.4*diffuse);
    vec2 d=(location.xy-vec2(-38.,-40.))/80.;
    vec3 rgb=surface*(.39+.65*diffuse+.14*exp(-dot(d,d)));
    rgb+=vec3(.10,.13,.15)*pow(max(dot(n,normalize(light+vec3(0.,0.,1.))),0.),18.);
    if(surface.g>.87 || surface.r>.97) rgb=surface;
    rgb=mix(rgb,vec3(dot(rgb,vec3(.28,.54,.18))),wear*.17);
    return vec4(floor(clamp(rgb,0.,1.)*31.+.5)/31.,1.);
}
#endif
]]
local cabinShader
local display = [[
extern float clockPhase;
extern float damaged;
vec4 effect(vec4 tint, Image tex, vec2 uv, vec2 screen) {
    vec4 p=Texel(tex,uv);
    if(p.a<.01) return vec4(0.);
    if(p.a<.65) {
        float lane=floor(p.b*5.+.5);
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
        p.rgb=rgb;
    }
    return vec4(p.rgb*tint.rgb,tint.a);
}
]]
local orbitFrames=240
local orbitPeriod={operational=24,damaged=36}
local pose = makePoseCache(Model,projection,size,unit,12,function(shader,state,frame,tilt)
    local angle=math.floor(frame/orbitFrames)*math.pi*2/frames
    local orbit=(frame%orbitFrames)*math.pi*2/orbitFrames
    shader:send('carrierYaw',{math.cos(orbit),math.sin(orbit)})
    local elevation=math.rad(38+tilt*2)
    shader:send('yaw',{math.cos(angle),math.sin(angle)})
    shader:send('pitch',{math.sin(elevation),math.cos(elevation)})
    shader:send('wear',state=='ruins' and 2 or state=='damaged' and 1 or 0)
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
    local sprite=pose(state,frame*orbitFrames+orbit,seed%5)
    cabinShader=cabinShader or g.newShader(display)
    g.push('all')
    g.translate(x,y)
    if camera then
        local dx=math.max(-1,math.min(1,(station.x-camera.x)/3000))
        local dy=math.max(-1,math.min(1,(station.y-camera.y)/3000))
        g.shear(dx*.035,dy*.025)
    end
    g.setColor(1,1,1,alpha)
    g.setShader(cabinShader)
    cabinShader:send('clockPhase',(time/9)%1)
    cabinShader:send('damaged',state=='damaged' and 1 or 0)
    local scale=radius/(100*unit)
    g.draw(sprite,0,0,0,scale,scale,size/2,size/2)
    g.pop()
end
return Renderer
