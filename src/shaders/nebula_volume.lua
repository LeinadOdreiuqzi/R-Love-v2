local Material = require 'src.maps.nebula_material'
local Shape = require 'src.maps.nebula_shape'

local Volume = {}
local layer, display, radianceScale
local lightFrame = {}
local outerColor = {}
local embeddedFrame = {0,0,0,0}
local noSource = {0,0,0,0}
local hadSource
local lastRegion

-- La exposición se aplica una vez al conjunto de nubes, a resolución del destino.
local displayCode = [[
    extern float inverseScale;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
        vec4 volume = Texel(tex,uv);
        vec3 light = volume.rgb*inverseScale;
        float peak = max(light.r,max(light.g,light.b));
        light *= (1.0-exp(-1.8*peak))/max(.00001,peak);
        #ifndef LOVE_GAMMA_CORRECT
            light = mix(12.92*light,1.055*pow(light,vec3(1.0/2.4))-.055,step(vec3(.0031308),light));
        #endif
        return vec4(light,volume.a);
    }
]]

function Volume.begin(shader, view)
    local g = love.graphics
    local target = g.getCanvas()
    local w, h = g.getDimensions()
    local dpi = g.getDPIScale()
    if target then
        w, h = target:getDimensions()
        dpi = target:getDPIScale()
    end
    if not display then
        display = g.newShader(displayCode)
        radianceScale = g.getCanvasFormats().rgba16f and 1 or .25
        display:send("inverseScale", 1 / radianceScale)
    end
    if not layer or layer:getWidth() ~= w or layer:getHeight() ~= h or layer:getDPIScale() ~= dpi then
        local old = layer
        local format = radianceScale == 1 and "rgba16f" or "rgba8"
        layer = g.newCanvas(w, h, {format = format, dpiscale = dpi})
        if old then old:release() end
    end
    g.push("all")
    g.setCanvas(layer)
    g.setScissor()
    g.setStencilTest()
    g.setColorMask(true,true,true,true)
    g.clear(0,0,0,0)
    g.setBlendMode("alpha", "premultiplied")
    shader:send("u_volumeLight", radianceScale)
    shader:send("u_materialView", view or 0)
    lastRegion = nil
    hadSource = nil
end

function Volume.setCloud(shader, region, x, y, nebula)
    if lastRegion ~= region then
        shader:send("u_gasBand", region.gas)
        shader:send("u_frontBand", region.front)
        shader:send("u_outerBand", Material.outerColor(region, outerColor))
        lastRegion = region
    end
    local aspect = nebula.aspectRatio or 1
    local radius = nebula.size or nebula.radius or 140
    -- Cada cuadruplicación del radio duplica el detalle fino, hasta cuatro veces.
    local dustRadius = nebula.dustRadius or radius
    shader:send("u_dustDetailScale", math.sqrt(math.max(1, math.min(16, dustRadius / 480))))
    local structure = Shape.forCloud(nebula)
    Material.projectLight(region, x, y, radius, aspect, nebula.rotation or 0, lightFrame)
    shader:send("u_regionLight", lightFrame)
    local star = structure.source
    if star then
        embeddedFrame[1], embeddedFrame[2] = star[1], star[2]
        embeddedFrame[3], embeddedFrame[4] = aspect/star[3], 1/(aspect*star[3])
        shader:send("u_embeddedLight", embeddedFrame)
    elseif hadSource ~= false then
        shader:send("u_embeddedLight", noSource)
    end
    hadSource = star ~= nil
    shader:send("u_structure", unpack(structure))
end

function Volume.finish(shader)
    local g = love.graphics
    shader:send("u_volumeLight", 0)
    g.pop()
    g.push("all")
    g.origin()
    g.setColor(1,1,1,1)
    g.setBlendMode("alpha", "premultiplied")
    g.setShader(display)
    g.draw(layer)
    g.pop()
    lastRegion = nil
end

return Volume
