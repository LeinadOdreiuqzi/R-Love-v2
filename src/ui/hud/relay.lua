-- Bright phosphor persists on either side of the live instrument image.
-- Only the pilot instruments are captured; the world is already on the screen.
local Relay = {}
local held, shader, rng
local started, nextAt, phase, direction
local lastPlayer, lastSlot

local fieldShader = [[
extern vec2 pixels;
extern float progress;
extern float phase;
extern float direction;
vec4 effect(vec4 tint, Image history, vec2 uv, vec2 screen) {
    float rise = smoothstep(0.0,.13,progress);
    float decay = 1.0-smoothstep(.26,1.0,progress);
    float energy = rise*decay;
    vec2 axis = vec2(direction, .25*cos(phase));
    vec2 offset = axis*(1.0+6.0*energy)/pixels;
    vec3 nearEcho = Texel(history, uv-offset).rgb;
    vec3 farEcho = Texel(history, uv+offset*.64).rgb;
    vec3 center = Texel(history, uv).rgb;
    vec3 outer = max(nearEcho-center*.76,0.0);
    vec3 inner = max(farEcho-center*.76,0.0);
    float nearLight = max(outer.r,max(outer.g,outer.b));
    float farLight = max(inner.r,max(inner.g,inner.b));
    vec3 emission = nearLight*vec3(.27,.92,.68)+farLight*vec3(.30,.49,.76);
    return vec4(emission*energy,0.0)*tint;
}
]]

function Relay.draw(drawInstruments, inventoryOpen, player)
    local loading = package.loaded['src.ui.loading_screen']
    local g = love.graphics
    if inventoryOpen or not player or (loading and loading.config.reducedEffects) then
        started, nextAt = nil, nil
        drawInstruments(inventoryOpen)
        return
    end

    local now = love.timer.getTime()
    local w,h = g.getDimensions()
    local dpi = g.getDPIScale()
    if held and (held:getWidth() ~= w or held:getHeight() ~= h or held:getDPIScale() ~= dpi) then
        held:release()
        held = nil
        started, nextAt = nil, nil
    end
    local slot = player.weaponSystem and player.weaponSystem.currentSlot
    if lastPlayer ~= player then
        started, nextAt, lastPlayer = nil, nil, player
    elseif lastSlot ~= slot and (not started or now-started >= .48) then
        nextAt = now
    end
    lastSlot = slot
    rng = rng or love.math.newRandomGenerator(os.time())
    nextAt = nextAt or now+.65
    if now >= nextAt then
        started, nextAt = now, now+2.1+rng:random()*1.3
        phase, direction = rng:random()*6.28, rng:random(0,1)*2-1
        held = held or g.newCanvas(w,h,{dpiscale=dpi})
        local target = g.getCanvas()
        g.push('all')
        g.setCanvas(held)
        g.origin()
        g.setScissor()
        g.clear(0,0,0,0)
        drawInstruments(inventoryOpen)
        g.setCanvas(target)
        g.origin()
        g.setShader()
        g.setColor(1,1,1,1)
        g.setBlendMode('alpha','premultiplied')
        g.draw(held)
        g.pop()
        return
    end

    drawInstruments(inventoryOpen)
    if not started then return end
    local t = (now-started)/.48
    if t >= 1 or t < 0 then started = nil; return end
    shader = shader or g.newShader(fieldShader)
    g.push('all')
    g.origin()
    g.setShader(shader)
    shader:send('pixels',{w,h})
    shader:send('progress',t)
    shader:send('phase',phase)
    shader:send('direction',direction)
    g.setBlendMode('add','premultiplied')
    g.setColor(1,1,1,1)
    g.draw(held)
    g.pop()
end

return Relay
