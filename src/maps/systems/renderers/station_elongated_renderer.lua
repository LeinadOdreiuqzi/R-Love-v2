local Model = require 'src.maps.systems.renderers.final_weapon_model'
local Renderer = {}
local g = love.graphics
local size, unit, frames = 256, 86, 120
local models, cache = {}, {}
local slots, serial = 0, 0
local bakeShader, displayShader

local projection = [[
extern vec2 roll;
extern float wear;
varying vec3 surface;
varying vec3 normal;
varying vec3 location;
#ifdef VERTEX
attribute vec3 FaceNormal;
attribute vec3 Material;
vec3 orient(vec3 v) {
    float side = dot(v.yz,vec2(roll.x,-roll.y));
    float radial = dot(v.yz,roll.yx);
    float axis = .82*v.x-.57236*radial;
    return vec3(-.77*axis-.638*side,.638*axis-.77*side,.57236*v.x+.82*radial);
}
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    location = orient(vertex_position.xyz);
    surface = Material;
    normal = orient(FaceNormal);
    vec4 clip = transform_projection * vec4(location.xy,0.,1.);
    clip.z = -location.z*.4*clip.w;
    return clip;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 tint, Image tex, vec2 uv, vec2 pixel) {
    vec3 n = normalize(normal);
    if(n.z < 0.) n = -n;
    vec3 light = normalize(vec3(-.45,-.66,.68));
    float diffuse = max(dot(n,light),0.);
    vec2 key = location.xy-vec2(-.28,-.42);
    float highlight = exp(-dot(key,key)*3.8);
    vec2 core = location.xy-vec2(-.04,.03);
    float spill = exp(-dot(core,core)*10.)*(1.-wear*.5);
    vec3 rgb = surface*(.43+.59*diffuse+.17*highlight);
    rgb += vec3(.14,.055,.09)*spill + vec3(.17,.19,.22)*pow(max(dot(n,normalize(light+vec3(0.,0.,1.))),0.),14.);
    rgb = mix(rgb,vec3(dot(rgb,vec3(.3,.52,.18))),wear*.22);
    // Replacement blending lets the coverage channel also identify lit materials.
    float tag = 1.;
    if(surface.r>.91 && wear<1.5) {
        rgb = surface + vec3(.16,.28,.15)*exp(-dot(core,core)*1200.);
        tag = .5;
    }
    return vec4(floor(clamp(rgb,0.,1.)*31.+.5)/31.,tag);
}
#endif
]]

local emission = [[
extern float power;
vec4 effect(vec4 tint, Image tex, vec2 uv, vec2 screen) {
    vec4 p = Texel(tex,uv);
    if(p.a < .01) return vec4(0.);
    if(p.a < .65) p.rgb *= power;
    return vec4(p.rgb*tint.rgb,tint.a);
}
]]

-- Share poses across instances and bound GPU memory, including debug auto-rotation.
local function pose(state, frame)
    serial = serial+1
    local key = state..frame
    local entry = cache[key]
    if entry then
        entry.used = serial
        return entry.canvas
    end
    local canvas
    if slots == 18 then
        local oldest
        for k,v in pairs(cache) do
            if not oldest or v.used < cache[oldest].used then oldest = k end
        end
        canvas = cache[oldest].canvas
        cache[oldest] = nil
    else
        canvas = g.newCanvas(size,size,{dpiscale=1})
        canvas:setFilter('nearest','nearest')
        slots = slots+1
    end
    models[state] = models[state] or Model.build(state)
    bakeShader = bakeShader or g.newShader(projection)
    local roll = frame*2*math.pi/frames
    g.push('all')
    g.reset()
    g.setCanvas({canvas,depth=true})
    g.clear(0,0,0,0,0,1)
    g.setDepthMode('less',true)
    g.setBlendMode('replace','premultiplied')
    g.translate(size/2,size/2)
    g.scale(unit)
    g.setShader(bakeShader)
    bakeShader:send('roll',{math.cos(roll),math.sin(roll)})
    bakeShader:send('wear',state=='ruins' and 2 or state=='damaged' and 1 or 0)
    g.draw(models[state])
    g.pop()
    cache[key] = {canvas=canvas,used=serial}
    return canvas
end

function Renderer.render(station,camera,x,y,finalSize,alpha,rotation,state)
    if alpha<=0 or finalSize<=0 then return end
    state = state or 'operational'
    local frame = math.floor((rotation or 0)*frames/(2*math.pi)+.5)%frames
    local sprite = pose(state,frame)
    local scale = finalSize*1.95/unit
    local time = love.timer.getTime() + (station.seed or 0)%17
    local power = .93+.07*math.sin(time*3)
    if state=='damaged' then power=.64+.28*math.sin(time*7)+.08*math.sin(time*23) end
    displayShader = displayShader or g.newShader(emission)
    g.push('all')
    g.translate(x,y)
    if camera then
        local dx = math.max(-1,math.min(1,(station.x-camera.x)/3200))
        local dy = math.max(-1,math.min(1,(station.y-camera.y)/3200))
        g.shear(dx*.055,dy*.04)
    end
    g.setShader(displayShader)
    displayShader:send('power',power)
    g.setColor(1,1,1,alpha)
    g.draw(sprite,0,0,0,scale,scale,size/2,size/2)
    g.pop()
end
return Renderer
