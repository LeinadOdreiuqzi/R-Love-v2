local Art = require 'src.rendering.ships.ship_art'
local ForceField = require 'src.physics.convoy_force_field'
local ConvoyArt = {}
local cache, fieldMesh, fieldShader
local width, height = 88, 100
local pivotX, pivotY, pixels = 44, 47, 64 / 3.4

local lighting = [[
float lightSpot(vec2 p, vec2 center, vec2 radius) {
    vec2 q = (p - center) / radius;
    return exp(-0.5 * dot(q,q));
}
vec4 effect(vec4 tint, Image source, vec2 uv, vec2 screen) {
    vec4 base = Texel(source,uv);
    if (base.a < 0.5) return vec4(0.0);
    vec3 c = base.rgb * .89;
    c += vec3(.15,.13,.16) * lightSpot(uv,vec2(.36,.28),vec2(.23,.24));
    c += vec3(.22,.065,.026) * lightSpot(uv,vec2(.70,.43),vec2(.19,.16));
    c += vec3(.11,.065,.052) * lightSpot(uv,vec2(.46,.75),vec2(.22,.14));
    return vec4(floor(clamp(c,0.0,1.0)*17.0+.5)/17.0,1.0);
}
]]

local fieldLighting = [[
extern vec4 strike;
extern float fieldTime;
varying float fieldHeight;

#ifdef VERTEX
attribute float FieldHeight;
vec4 position(mat4 transformProjection, vec4 vertexPosition) {
    fieldHeight = FieldHeight;
    float breath = sin(fieldTime * 1.67) + .28 * sin(fieldTime * 3.61 + 1.3);
    vec2 bias = vec2(.045 * sin(fieldTime * 1.91), -.16 * breath);
    vertexPosition.xy += fieldHeight * (bias + vertexPosition.xy * .016 * breath);
    return transformProjection * vertexPosition;
}
#endif

#ifdef PIXEL
float energySpot(vec2 pos, vec2 center, float falloff) {
    vec2 dx = pos - center;
    return exp(-falloff * dot(dx, dx));
}

vec4 effect(vec4 color, Image source, vec2 position, vec2 screen) {
    float t = fieldTime;
    vec2 leading = vec2(cos(t * 1.41 + .38 * sin(t * .73)), sin(t * 1.41 + .38 * sin(t * .73)));
    vec2 trailing = vec2(cos(t * -.81 + 2.2), sin(t * -.81 + 2.2));
    float rise = .5 + .5 * sin(t * 2.35 + dot(position, vec2(1.0, -.46)));
    float elevation = fieldHeight - rise;
    float crest = exp(-12.0 * elevation * elevation);
    float energy = energySpot(position, leading * mix(2.87, 2.35, fieldHeight), .95) * (.36 + .64 * crest);
    energy += energySpot(position, trailing * 2.53, 1.6) * (.22 + .20 * sin(t * 3.07 + .4));
    float dist = distance(position, strike.xy);
    float remaining = 1.0 - strike.z;
    float wave = dist - strike.z * 1.85;
    float glow = exp(-2.4 * dist * dist) * remaining * remaining;
    float ring = exp(-26.0 * wave * wave) * remaining;
    float pulse = max(glow, ring * .75) * strike.w;
    vec3 light = mix(mix(color.rgb, vec3(.50,.76,1.0), energy), vec3(.82,.96,1.0), pulse);
    return vec4(light, min(1.0, color.a * (.83 + 1.12 * energy + 2.5 * pulse) + pulse * .18));
}
#endif
]]

local function bakeField()
    local g = love.graphics
    local mesh = {}
    local points, crown = ForceField.points, {}
    local mist = {.38,.39,.96,0}
    local gleam = {.56,.69,1,.44}
    local foot = {.32,.49,.99,.58}
    local panels = {{.39,.52,.98,.13}, {.34,.41,.92,.14}, {.27,.40,.91,.17}, {.32,.48,.99,.16},
        {.33,.49,.98,.21}, {.42,.43,.95,.17}, {.49,.51,1,.22}, {.44,.55,1,.17}}
    for index, point in ipairs(points) do
        crown[index] = {point[1] * .81, point[2] * .81 - .23, 1}
    end
    local function vertex(point, color)
        local x, y = point[1], point[2]
        mesh[#mesh + 1] = {x, y, x, y, color[1], color[2], color[3], color[4], point[3] or 0}
    end
    local function quad(a, b, c, d, ca, cb, cc, cd)
        vertex(a,ca); vertex(b,cb); vertex(c,cc)
        vertex(a,ca); vertex(c,cc); vertex(d,cd)
    end
    local function scaled(p, factor)
        return {p[1] * factor, p[2] * factor}
    end
    local function edge(a, b, width, color)
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local k = width / math.sqrt(dx * dx + dy * dy) * .5
        local nx, ny = -dy * k, dx * k
        quad({a[1] + nx,a[2] + ny,a[3]}, {b[1] + nx,b[2] + ny,b[3]},
             {b[1] - nx,b[2] - ny,b[3]}, {a[1] - nx,a[2] - ny,a[3]}, color,color,color,color)
    end
    local tint = {.39,.49,1,.055}
    for i, a in ipairs(points) do
        local j = i % #points + 1
        local b = points[j]
        quad(scaled(a,1.095), scaled(b,1.095), b, a, mist,mist,foot,foot)
        quad(a,b,crown[j],crown[i], panels[i],panels[i],tint,tint)
        vertex(crown[i],tint); vertex(crown[j],tint); vertex({0,-.25,1},{.34,.44,.96,.022})
    end
    for i, a in ipairs(points) do
        local j = i % #points + 1
        edge(a,points[j],.076,foot)
        edge(crown[i],crown[j],.055,gleam)
        edge(a,crown[i],.05,gleam)
    end
    local format = {{'VertexPosition', 'float', 2}, {'VertexTexCoord', 'float', 2},
        {'VertexColor', 'byte', 4}, {'FieldHeight', 'float', 1}}
    fieldMesh = g.newMesh(format, mesh, 'triangles', 'static')
    fieldShader = g.newShader(fieldLighting, fieldLighting)
end

local depthTint = [[
vec4 effect(vec4 color, Image source, vec2 uv, vec2 screen) {
    return vec4(color.rgb * vec3(.36,.39,.47), color.a);
}
]]

local function bake()
    local g = love.graphics
    local source = g.newCanvas(width, height, {dpiscale = 1})
    source:setFilter('nearest', 'nearest')
    local light, depth = g.newShader(lighting), g.newShader(depthTint)
    local images = {}
    g.push('all')
    for _, exposed in ipairs({false, true}) do
        local hull = {shipType = exposed and 'ARMORED_CONVOY_EXPOSED' or 'ARMORED_CONVOY'}
        g.setCanvas(source)
        g.origin()
        g.setScissor()
        g.setBlendMode('alpha', 'alphamultiply')
        g.clear(0, 0, 0, 0)
        g.translate(pivotX, pivotY)
        g.setShader(depth)
        for offset = 5, 1, -1 do
            g.push()
            g.translate(offset * .55, offset)
            Art.draw(hull, pixels, false, true)
            g.pop()
        end
        g.setShader()
        Art.draw(hull, pixels, false, true)
        local sprite = g.newCanvas(width, height, {dpiscale = 1})
        sprite:setFilter('nearest', 'nearest')
        g.setCanvas(sprite)
        g.clear(0, 0, 0, 0)
        g.origin()
        g.setShader(light)
        g.setColor(1, 1, 1, 1)
        g.draw(source)
        images[exposed] = sprite
    end
    g.pop()
    source:release()
    light:release()
    depth:release()
    return images
end

function ConvoyArt.drawWreck(wreck)
    if not cache then cache = bake() end
    local g = love.graphics
    local size = wreck.size
    g.push('all')
    g.translate(wreck.x, wreck.y)
    g.rotate(wreck.rotation)
    g.scale(size, size)
    g.setColor(.64, .54, .53)
    g.draw(cache[true], 0, 0, 0, 1 / pixels, 1 / pixels, pivotX, pivotY)
    g.setColor(.075, .049, .060)
    g.polygon('fill', -.30,-.61, .15,-.33, .45,-.46, .27,-.05, -.19,.13, -.39,-.09)
    g.setColor(.45, .19, .12)
    g.polygon('fill', -.30,-.61, .15,-.33, .45,-.46, .23,-.23, .05,-.21)
    local flicker = .62 + .26 * math.sin(love.timer.getTime() * 7 + wreck.x)^2
    g.setColor(1, .44, .18, flicker)
    g.rectangle('fill', -.08, -.35, .10, .10)
    g.rectangle('fill', -.24, -.12, .07, .07)
    g.pop()
end

function ConvoyArt.draw(ship, size)
    if not cache then cache = bake() end
    local g = love.graphics
    local convoy = ship.convoy
    local exposed = convoy.state == 'exposed'
    if ship.engineGlow > .2 then
        ship:drawThrusterFlame(-size * .24, size * 1.73, size * .30, {1, .41, .18})
        ship:drawThrusterFlame(size * .24, size * 1.73, size * .30, {1, .41, .18})
    end
    g.setColor(1, 1, 1, 1)
    g.draw(cache[exposed], 0, 0, 0, size / pixels, size / pixels, pivotX, pivotY)
    if convoy.armor == 0 then
        g.setColor(1, .34, .13, .85)
        g.rectangle('fill', -size * .13, size * .64, size * .26, size * .10)
    end
    if not exposed then ConvoyArt.drawField(convoy, size) end
end

function ConvoyArt.drawField(convoy, size)
    local g = love.graphics
    if not fieldMesh then bakeField() end
    local flash = (convoy.blockFlash or 0) / ForceField.flashDuration
    g.setColor(1, 1, 1, 1)
    g.push('all')
    g.setShader(fieldShader)
    fieldShader:send('strike', {convoy.fieldHitX or 0, convoy.fieldHitY or -2.5, 1 - flash, flash > 0 and 1 or 0})
    fieldShader:send('fieldTime', love.timer.getTime())
    g.draw(fieldMesh, 0, 0, 0, size, size)
    g.pop()
end

return ConvoyArt
