-- Capture the live scene only while an inventory is visible. Both blur passes
-- finish before the UI is drawn, so cursor hitboxes and glyphs stay sharp.
local Backdrop = {}
local scene, horizontal, blur
local source = [[
extern vec2 stride;
vec4 effect(vec4 tint, Image frame, vec2 uv, vec2 screen) {
    vec4 c = Texel(frame,uv)*.227027;
    c += (Texel(frame,uv-stride*1.384615)+Texel(frame,uv+stride*1.384615))*.316216;
    c += (Texel(frame,uv-stride*3.230769)+Texel(frame,uv+stride*3.230769))*.070270;
    return c*tint;
}
]]

function Backdrop.begin()
    local g = love.graphics
    local w,h = g.getDimensions()
    local dpi = g.getDPIScale()
    if not scene or scene:getWidth() ~= w or scene:getHeight() ~= h or scene:getDPIScale() ~= dpi then
        if scene then scene:release(); horizontal:release() end
        scene = g.newCanvas(w,h,{dpiscale=dpi})
        horizontal = g.newCanvas(math.max(1,math.ceil(w/2)),math.max(1,math.ceil(h/2)),{dpiscale=dpi})
        scene:setFilter('linear','linear')
        horizontal:setFilter('linear','linear')
    end
    blur = blur or g.newShader(source)
    g.push('all')
    g.setCanvas(scene)
    g.clear(g.getBackgroundColor())
end

function Backdrop.finish()
    local g = love.graphics
    local w,h = scene:getDimensions()
    local hw,hh = horizontal:getDimensions()
    g.setCanvas(horizontal)
    g.origin()
    g.setScissor()
    g.setBlendMode('replace')
    g.setColor(1,1,1,1)
    g.setShader(blur)
    blur:send('stride',{2.4/w,0})
    g.draw(scene,0,0,0,hw/w,hh/h)
    g.pop()
    g.push('all')
    g.origin()
    g.setScissor()
    g.setBlendMode('replace')
    g.setShader(blur)
    blur:send('stride',{0,2.4/h})
    g.setColor(.76,.76,.76,1)
    g.draw(horizontal,0,0,0,w/hw,h/hh)
    g.pop()
end

return Backdrop
