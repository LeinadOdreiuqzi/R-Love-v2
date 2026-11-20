-- Distance and reach are in world units. Size and luminosity belong to the emitter.
local Light={}
function Light.powerAt(dx,dy,range,power)
    if range<=0 or power<=0 then return 0 end
    local falloff=math.max(0,1-(dx*dx+dy*dy)/(range*range))
    return power*falloff*falloff
end
function Light.toHull(dx,dy,rotation,color,power,shade)
    local c,s=math.cos(rotation),math.sin(rotation)
    return {x=dx*c+dy*s,y=dy*c-dx*s,color=color,power=power,shade=shade}
end

-- A small radial texture scopes the visible bloom to the emitter itself.
local halo
function Light.halo(x,y,radius,r,g,b,power)
    if power<=0 or radius<=0 then return end
    if not halo then
        local pixels=love.image.newImageData(32,32)
        pixels:mapPixel(function(px,py)
            local dx,dy=(px-15.5)/16,(py-15.5)/16
            local a=math.max(0,1-dx*dx-dy*dy)
            return 1,1,1,a*a*a
        end)
        halo=love.graphics.newImage(pixels)
        halo:setFilter('linear','linear')
        pixels:release()
    end
    love.graphics.setColor(r,g,b,math.min(1,power))
    love.graphics.draw(halo,x,y,0,radius/16,radius/16,16,16)
end
local shader
local source=[[
extern vec2 texel;
extern vec2 pivot;
extern vec2 extent;
extern vec3 emitter;
extern float positional;
extern vec3 radiance;
extern float shade;
extern vec2 flashPosition;
extern vec3 flashColor;
extern float flashRange;
float heightAt(Image image,vec2 uv) {
    vec4 p=Texel(image,uv);
    return p.a*(.6+.4*dot(p.rgb,vec3(.30,.55,.15)));
}
vec4 effect(vec4 tint,Image image,vec2 uv,vec2 screen) {
    vec4 hull=Texel(image,uv);
    if(hull.a<.01) return hull*tint;
    vec2 slope=vec2(heightAt(image,uv-vec2(texel.x,0.))-heightAt(image,uv+vec2(texel.x,0.)),
                    heightAt(image,uv-vec2(0.,texel.y))-heightAt(image,uv+vec2(0.,texel.y)));
    vec2 p=(uv-pivot)*extent;
    vec3 normal=normalize(vec3((uv-pivot)*3.5+slope*2.5, .75));
    vec3 light=normalize(emitter-vec3(p*positional,0.));
    float diffuse=max(dot(normal,light),0.);
    float spec=pow(max(dot(normal,normalize(light+vec3(0.,0.,1.))),0.),10.);
    vec3 delta=radiance*(.46*diffuse+.28*spec);
    vec2 offset=flashPosition-p;
    float fade=max(0.,1.-dot(offset,offset)/(flashRange*flashRange));

    if(shade>0.) {
        // Broad hull curvature sets the terminator; fine slopes still break
        // it up at plates and wing edges without turning every decal black.
        vec3 form=normalize(vec3((uv-pivot)*3.5,.42));
        float facing=mix(dot(form,light),dot(normal,light),.24);
        float night=1.-smoothstep(-.16,.32,facing);
        float band=floor(night*5.+.5)/5.;
        hull.rgb*=1.-shade*band*vec3(1.,.94,.84);
        // Restrict stellar highlights to the day side. Muzzle light can
        // still illuminate metal on the night side.
        delta*=1.-band;
    }
    delta+=flashColor*fade*fade*.6*max(dot(normal,normalize(vec3(offset,5.))),0.);
    return vec4(hull.rgb+(1.-hull.rgb)*floor(delta*31.+.5)/31.,hull.a)*tint;
}
]]
function Light.draw(light,image,x,y,angle,sx,sy,ox,oy)
    local g=love.graphics
    if not light then
        g.draw(image,x,y,angle,sx,sy,ox,oy)
        return
    end
    shader=shader or g.newShader(source)
    local w,h=image:getDimensions()
    local old=g.getShader()
    ox,oy=ox or 0,oy or 0
    shader:send('texel',{1/w,1/h})
    shader:send('pivot',{(ox-x/sx)/w,(oy-y/sy)/h})
    shader:send('extent',{w*sx,h*sy})
    shader:send('emitter',{light.x,light.y,light.directionZ or 8})
    shader:send('positional',light.directionZ and 0 or 1)
    shader:send('shade',(light.shade or 0)*math.sqrt(math.min(1,light.power)))
    local flash=light.flash
    shader:send('flashRange',flash and flash.range or 1)
    shader:send('flashPosition',flash and {flash.x,flash.y} or {0,0})
    shader:send('flashColor',flash and {flash.color[1]*flash.power,flash.color[2]*flash.power,flash.color[3]*flash.power} or {0,0,0})
    local col=light.color
    shader:send('radiance',{col[1]*light.power,col[2]*light.power,col[3]*light.power})
    g.setShader(shader)
    g.draw(image,x,y,angle,sx,sy,ox,oy)
    g.setShader(old)
end
return Light
