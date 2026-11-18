-- Bake oriented station meshes to a bounded set of native-resolution sprites.
local g = love.graphics
return function(model,projection,size,unit,capacity,configure)
    local models,cache={},{}
    local slots,serial=0,0
    local shader
    return function(state,frame,tilt,ix,iy)
        serial=serial+1
        local key=state..':'..frame..':'..(tilt or 0)..':'..ix..':'..iy
        if cache[key] then
            cache[key].used=serial
            return cache[key].canvas
        end
        local canvas
        if slots==capacity then
            local oldest
            for k,v in pairs(cache) do
                if not oldest or v.used<cache[oldest].used then oldest=k end
            end
            canvas=cache[oldest].canvas
            cache[oldest]=nil
        else
            canvas=g.newCanvas(size,size,{dpiscale=1})
            canvas:setFilter('nearest','nearest')
            slots=slots+1
        end
        models[state]=models[state] or model.build(state)
        shader=shader or g.newShader(projection)
        g.push('all')
        g.reset()
        g.setCanvas({canvas,depth=true})
        g.clear(0,0,0,0,0,1)
        g.setDepthMode('less',true)
        g.setBlendMode('replace','premultiplied')
        g.translate(size/2,size/2)
        g.scale(unit)
        g.setShader(shader)
        configure(shader,state,frame,tilt,ix,iy)
        g.draw(models[state])
        g.pop()
        cache[key]={canvas=canvas,used=serial}
        return canvas
    end
end
