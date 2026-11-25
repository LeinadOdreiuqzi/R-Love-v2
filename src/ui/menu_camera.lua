-- One transparent UI layer: the optics never sample the game world.
local Camera = {}
local layer, optics
local openings = {}
local trail = {}
local drawGlyph = require 'src.ui.inventory.item_glyph'
local lifetime = .095

local source = [[
extern vec2 texel;
extern float exposure;
extern float grainFrame;
vec4 effect(vec4 color, Image image, vec2 uv, vec2 screen) {
    vec4 core = Texel(image,uv);
    vec2 axis = (uv-.5)*2.0;
    float radius = dot(axis,axis);
    vec2 d = texel*(2.3+radius);
    vec3 nearLight = (Texel(image,uv+vec2(d.x,0)).rgb + Texel(image,uv-vec2(d.x,0)).rgb
        + Texel(image,uv+vec2(0,d.y)).rgb + Texel(image,uv-vec2(0,d.y)).rgb)*.25;
    vec3 farLight = (Texel(image,uv+d*2.1).rgb + Texel(image,uv-d*2.1).rgb)*.5;
    vec3 halo = max(nearLight-.09,0.0)*.43 + max(farLight-.14,0.0)*.13;
    float light = dot(core.rgb,vec3(.22,.68,.10));
    float noise = fract(52.9829189*fract(dot(floor(screen)+grainFrame,vec2(.06711056,.00583715))))-.5;
    float grain = noise*.052*smoothstep(.012,.10,light)*(1.0-smoothstep(.45,.85,light));
    // Lift the translucent glass and compress the highlights separately.
    float glass = core.a*(1.0-smoothstep(.08,.65,light));
    vec3 emission = core.rgb*vec3(.91,1.08,1.06) + glass*vec3(.004,.072,.076);
    emission += halo*vec3(.56,1.0,.88) + grain;
    float vignette = smoothstep(.14,1.75,radius)*.28;
    float alpha = max(core.a,max(halo.r,max(halo.g,halo.b)));
    return vec4(max(emission,vec3(0.0))*exposure*(1.0-vignette),
        alpha+(1.0-alpha)*vignette)*color;
}
]]

local function reduced()
    local loading = package.loaded['src.ui.loading_screen']
    return loading and loading.config.reducedEffects
end

function Camera.open(key)
    openings[key] = love.timer.getTime()
    trail = {}
end

function Camera.draw(key, drawContent, ...)
    local g = love.graphics
    local w,h = g.getDimensions()
    local dpi = g.getDPIScale()
    if not layer or layer:getWidth() ~= w or layer:getHeight() ~= h or layer:getDPIScale() ~= dpi then
        if layer then layer:release() end
        layer = g.newCanvas(w,h,{dpiscale=dpi})
        layer:setFilter('linear','linear')
        trail = {}
    end
    optics = optics or g.newShader(source)
    local now = love.timer.getTime()
    local still = reduced()
    local target = g.getCanvas()
    g.push('all')
    g.setCanvas(layer)
    g.origin()
    g.setScissor()
    g.setShader()
    g.setBlendMode('alpha','alphamultiply')
    g.clear(0,0,0,0)
    drawContent(...)
    g.setCanvas(target)
    g.pop()
    g.push('all')
    g.origin()
    g.setColor(1,1,1,1)
    g.setBlendMode('alpha','premultiplied')
    g.setShader(optics)
    optics:send('texel',{1/w,1/h})
    local settle = math.max(0,1-(now-(openings[key] or -1))/.22)
    optics:send('exposure',still and 1 or 1-.29*settle*settle)
    optics:send('grainFrame',still and 0 or math.floor(now*12)%251)
    g.draw(layer)
    g.pop()
end

-- Keep only recent positions. Drawing the glyph alone leaves stack counts clear.
function Camera.itemEcho(key,data,x,y,size)
    if reduced() or trail.key ~= key or (data and trail.data ~= data) then
        trail = {key=key,data=data}
    end
    if reduced() then return end
    local now = love.timer.getTime()
    while trail[1] and now-trail[1].time >= lifetime do table.remove(trail,1) end
    local last = trail[#trail]
    if data and last and (last.x ~= x or last.y ~= y) then trail.moved = now end
    local strength = trail.moved and math.max(0,1-(now-trail.moved)/lifetime) or 0
    local old = trail[1]
    if old and strength > 0 and (old.x ~= x or old.y ~= y) then
        love.graphics.push('all')
        love.graphics.setColor(.56,1.0,.85,.22*strength)
        drawGlyph(trail.data,old.x,old.y,old.size)
        love.graphics.pop()
    end
    if data then trail[#trail+1] = {time=now,x=x,y=y,size=size} end
end

return Camera
