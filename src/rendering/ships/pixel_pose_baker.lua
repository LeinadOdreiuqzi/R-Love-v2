-- Bake five bank poses once; callers retain geometry, materials and damage variants.
local Baker={}
local projection=[[
extern float bank;
extern float layer;
extern float layerStep;
extern float rootX;
vec2 projectHull(vec2 p) {
    float factor=1.0-.14*abs(bank)+.10*bank*sign(p.x);
    return vec2(p.x*factor,p.y+bank*p.x*.32);
}
vec4 position(mat4 transform_projection,vec4 vertex_position) {
    vec2 p=projectHull(vertex_position.xy+vec2(rootX,0.0))-projectHull(vec2(rootX,0.0));
    p+=vec2(-bank*.62,.74+.20*abs(bank))*layer*layerStep;
    return transform_projection*vec4(p,vertex_position.zw);
}
vec4 effect(vec4 tint,Image source,vec2 uv,vec2 screen) {
    if(layer>0.0) {
        float rim=layer/8.0;
        return vec4(tint.rgb*vec3(.30,.34,.43)*(1.0-.38*rim),tint.a);
    }
    return tint;
}
]]

function Baker.build(config)
    local g=love.graphics
    local source=g.newCanvas(config.width,config.height,{dpiscale=1})
    source:setFilter('nearest','nearest')
    local project=g.newShader(projection)
    local light=g.newShader(config.lighting)
    local result,count={},0
    local started=love.timer.getTime()
    project:send('layerStep',config.layerStep or 1)
    for variant=0,config.variants-1 do
        result[variant]={}
        for part=1,config.parts do
            local poses={};result[variant][part]=poses
            for index=-2,2 do
                g.push('all')
                g.reset()
                local bank=index/2*(config.bankAmplitude or 1)
                g.setCanvas(source);g.origin();g.clear(0,0,0,0)
                g.translate(config.width/2,config.height/2)
                g.setShader(project)
                project:send('bank',bank)
                project:send('rootX',config.rootX(part))
                for layer=8,0,-1 do
                    project:send('layer',layer)
                    config.paint(part,variant)
                end
                local sprite=g.newCanvas(config.width,config.height,{dpiscale=1})
                sprite:setFilter('nearest','nearest')
                g.setCanvas(sprite);g.origin();g.clear(0,0,0,0)
                g.setColor(1,1,1);g.setShader(light)
                light:send('bank',bank)
                if light:hasUniform('wear') then light:send('wear',variant) end
                if light:hasUniform('part') then light:send('part',part) end
                if config.setLights then config.setLights(light) end
                g.draw(source)
                poses[index]=sprite;count=count+1
                g.pop()
                if config.yieldWork then config.yieldWork() end
            end
        end
    end
    source:release();project:release();light:release()
    return result,{poses=count,bytes=count*config.width*config.height*4,
        bakeMs=(love.timer.getTime()-started)*1000}
end
return Baker
