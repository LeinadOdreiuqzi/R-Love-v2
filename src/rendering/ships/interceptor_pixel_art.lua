local LocalLight=require 'src.rendering.local_light'
local Art = require 'src.rendering.ships.ship_art'

local PixelArt = {}
local poses
local width, height = 72, 85
local hullScale = 64 / 2.9
local pivotX, pivotY = width * .5, height * .60

local projection = [[
extern float bank;
extern float depth;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec2 p = vertex_position.xy;
    // The far wing foreshortens while the near wing drops in the projection.
    float side = sign(p.x);
    p.x *= 1.0 - .21 * abs(bank) + .16 * bank * side;
    p.y += bank * vertex_position.x * .43;
    // Dorsal plating and the raised cockpit move relative to the lower hull.
    float spine = 1.0 - smoothstep(.14,.53,abs(vertex_position.x));
    p.x += bank * (.10 + .15 * spine);
    p += vec2(-bank * .31, .06 + .10 * abs(bank)) * depth;
    return transform_projection * vec4(p,vertex_position.zw);
}

vec4 effect(vec4 tint, Image source, vec2 uv, vec2 screen) {
    if (depth > 0.0) {
        vec3 wall = mix(vec3(.065,.054,.11), tint.rgb * vec3(.47,.42,.66), .66);
        return vec4(wall,1.0);
    }
    return tint;
}
]]

local lighting = [[
extern float bank;

float splat(vec2 p, vec2 center, vec2 radius, float angle) {
    vec2 d = p - center;
    float c = cos(angle), s = sin(angle);
    vec2 q = vec2(c*d.x+s*d.y,-s*d.x+c*d.y) / radius;
    return exp(-0.5 * dot(q,q));
}

vec4 effect(vec4 tint, Image source, vec2 uv, vec2 screen) {
    vec4 base = Texel(source, uv);
    if (base.a < 0.5) return vec4(0.0);
    vec2 projected = (uv * vec2(72.0,85.0) - vec2(36.0,51.0)) / (64.0/2.9);
    float side = sign(projected.x - bank * .10);
    float x = (projected.x - bank * .10) / (1.0 - .21 * abs(bank) + .16 * bank * side);
    vec2 p = vec2(x, projected.y - bank * x * .43);
    float top = splat(p, vec2(-.15+bank*.21,-1.05), vec2(.16,.83), -.14);
    float wings = (.85-bank*.65) * splat(p, vec2(-.70,-.03), vec2(.17,.59), -.3) +
        (.85+bank*.65) * splat(p, vec2(.72,-.02), vec2(.16,.55), .3);
    float emitters = splat(p, vec2(-1.22,-.53), vec2(.15,.28), .48) +
        splat(p, vec2(1.22,-.53), vec2(.15,.28), -.48);
    float bounce = splat(p, vec2(bank*.10,.99), vec2(.27,.23), 0.0);
    vec3 shaded = base.rgb * .86 + vec3(.22,.28,.41) * top
        + vec3(.18,.20,.31) * wings + vec3(.26,.062,.35) * emitters
        + vec3(.32,.091,.42) * bounce;
    return vec4(floor(clamp(shaded,0.0,1.0)*15.0+.5)/15.0, 1.0);
}
]]

local function buildPoses(yieldWork)
    local g = love.graphics
    local source = g.newCanvas(width, height, {dpiscale = 1})
    source:setFilter('nearest', 'nearest')
    local shader = g.newShader(lighting)
    local project = g.newShader(projection)
    local hull = {shipType = 'INTERCEPTOR'}
    local result = {}
    for index = -2, 2 do
        g.push('all')
        g.reset()
        local bank = index / 2
        g.setCanvas(source)
        g.setShader(project)
        g.origin()
        g.setScissor()
        g.setBlendMode('alpha', 'alphamultiply')
        g.clear(0, 0, 0, 0)
        project:send('bank', bank)
        g.translate(pivotX, pivotY)
        for layer = 8, 0, -1 do
            project:send('depth', layer / 8)
            Art.draw(hull, hullScale, false, true)
        end

        local sprite = g.newCanvas(width, height, {dpiscale = 1})
        sprite:setFilter('nearest', 'nearest')
        g.setCanvas(sprite)
        g.clear(0, 0, 0, 0)
        g.origin()
        g.setShader(shader)
        shader:send('bank', bank)
        g.setColor(1, 1, 1, 1)
        g.draw(source)
        result[index] = sprite
        g.pop()
        if yieldWork then yieldWork() end
    end
    source:release()
    shader:release()
    project:release()
    return result
end

function PixelArt.update(ship, dt, previousRotation)
    if ship.shipType ~= 'INTERCEPTOR' or dt <= 0 then return end
    local turn = (ship.rotation - previousRotation + math.pi) % (2 * math.pi) - math.pi
    local speed = math.sqrt(ship.dx^2 + ship.dy^2)
    local speedFactor = math.min(1, speed / 5)
    local target = math.max(-1, math.min(1, turn / dt / 2.2)) * speedFactor
    local bank = ship.visualBank or 0
    local response = math.abs(target) > math.abs(bank) and 15 or 8
    ship.visualBank = bank + (target - bank) * (1 - math.exp(-dt * response))
end

local function poseIndex(ship)
    return math.max(-2,math.min(2,math.floor((ship.visualBank or 0)*2+.5)))
end

-- Same dorsal-surface projection as the vertex shader, in display units.
function PixelArt.project(ship,x,y)
    local size=ship.size*(ship.worldScale or 1)
    local bank=poseIndex(ship)*.5
    local t=math.max(0,math.min(1,(math.abs(x)/size-.14)/(.53-.14)))
    local spine=1-t*t*(3-2*t)
    return x*(1-.21*math.abs(bank)+.16*bank*(x<0 and -1 or 1))
        +size*bank*(.10+.15*spine), y+bank*x*.43
end

function PixelArt.preload(yieldWork)
    if not poses then poses = buildPoses(yieldWork) end
end

function PixelArt.draw(ship, size, abandoned, reflection)
    PixelArt.preload()
    local g = love.graphics
    local index = abandoned and 0 or poseIndex(ship)
    if not abandoned and (ship.engineGlow or 0) > 0 and (not ship.stats or ship.stats:canMove()) then
        g.push()
        g.translate(index * size * .11, size * 1.07)
        g.rotate(-index * .115)
        ship:drawThrusterFlame(0, 0, size * .46, {.87, .26, 1})
        g.pop()
    end
    local light = abandoned and .60 or 1
    g.setColor(light, light, light, 1)
    LocalLight.draw(reflection,poses[index], 0, 0, 0, size / hullScale, size / hullScale, pivotX, pivotY)
    if abandoned then
        g.setColor(1, .24, .20, .42 + .40 * math.sin(love.timer.getTime() * 4)^2)
        g.circle('fill', 0, -size * .25, math.max(1, size * .095), 8)
    end
end

return PixelArt
