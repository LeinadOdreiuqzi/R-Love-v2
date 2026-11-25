-- Shared menu surfaces. Gameplay HUD colors and world rendering are independent.
local Menu = {
    plate = {16/255, 23/255, 28/255, .97},
    steel = {52/255, 70/255, 80/255, 1},
    paper = {228/255, 234/255, 229/255, 1},
    focus = {114/255, 214/255, 173/255, 1},
    muted = {.62, .69, .69, 1}
}

function Menu.ink(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], (alpha or 1) * (color[4] or 1))
end

-- Local-space coordinates keep the phosphor pattern attached to each projection.
local projection = [[
extern vec2 extent;
extern number phase;
extern number globe;
float trace(float distanceToLine, float width) {
    return 1.0 - smoothstep(width, width + 0.012, abs(distanceToLine));
}
vec4 effect(vec4 tint, Image texture, vec2 uv, vec2 screen) {
    vec2 q = uv;
    vec2 p = uv * extent;
    vec3 mint = vec3(.447,.839,.678);
    if (globe < .5) {
        vec2 margin = min(p, extent-p);
        vec2 feather = smoothstep(vec2(0.0), min(extent*.30,vec2(42.0,24.0)), margin);
        float field = feather.x*feather.y;
        float plume = exp(-3.0*q.x)*(.82+.18*cos(phase*6.283+q.x*2.2));
        vec3 ink = vec3(.019,.045,.048)+mint*(.032+.11*plume);
        return vec4(ink,tint.a*field*.89);
    }
    vec2 v = (q-.5)*2.8;
    v.x *= extent.x/extent.y;
    float radius = length(v);
    float z = sqrt(max(0.0,1.0-dot(v,v)));
    vec2 tilted = mat2(.94,.342,-.342,.94)*v;
    float lat = tilted.y*.90 + z*.436;
    float depth = z*.90 - tilted.y*.436;
    float lon = atan(tilted.x,depth+.00001);
    float meridian = trace(sin(lon*9.0+phase*6.283),.055);
    float parallel = trace(sin(asin(clamp(lat,-1.0,1.0))*12.0),.07);
    float grid = max(meridian,parallel)*step(radius,.996)*(.32+.60*z);
    vec2 orbit = mat2(.927,.375,-.375,.927)*v;
    float ring = length(vec2(orbit.x, orbit.y*3.2));
    float visible = max(step(1.0,radius),step(orbit.y,0.0));
    float rings = visible*(trace(ring-1.42,.008)+.4*trace(ring-1.48,.004));
    float rim = exp(-abs(radius-1.0)*65.0);
    float strength = (.09*z+grid+rim+rings)*.88;
    vec3 color = mix(mint,vec3(.88,.99,.89),min(1.0,rim+rings*.55));
    return vec4(color, tint.a*min(1.0,strength));
}
]]

local shader, surface
function Menu.project(x,y,w,h,phase,globe,alpha)
    if w <= 0 or h <= 0 then return end
    local g = love.graphics
    shader = shader or g.newShader(projection)
    -- UVs stay local even when a menu translates and scales its whole layout.
    surface = surface or g.newMesh({
        {0,0, 0,0}, {1,0, 1,0}, {1,1, 1,1}, {0,1, 0,1}
    }, 'fan', 'static')
    local previous = g.getShader()
    g.setShader(shader)
    shader:send('extent',{w,h})
    shader:send('phase',phase)
    shader:send('globe',globe and 1 or 0)
    g.setColor(1,1,1,alpha or 1)
    g.draw(surface,x,y,0,w,h)
    g.setShader(previous)
end

function Menu.panel(x,y,w,h,alpha)
    local loading = package.loaded['src.ui.loading_screen']
    local reduced = loading and loading.config and loading.config.reducedEffects
    Menu.project(x,y,w,h,reduced and 0 or love.timer.getTime()*.09,false,alpha)
end

-- An open registration mark describes an item footprint or interactive target.
function Menu.mark(x,y,w,h,color,active)
    local g = love.graphics
    Menu.ink(color,active and .98 or .66)
    g.rectangle('fill',x+2,y+h-3,math.max(2,w-4),active and 2 or 1)
    g.rectangle('fill',x+2,y+h-6,2,3)
end

return Menu
