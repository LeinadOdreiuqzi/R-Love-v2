-- Pixel-art cut stone. Each pixel intersects the same seeded set of quarry
-- faces in object space, so revisiting or zooming never rerolls a rock.
local Art = {}
local shader, white
local parameters = {}
local lightVector, radiance = {}, {}
local source = [[
#ifdef ROCK_BATCH
#ifdef VERTEX
attribute vec3 RockPose;
attribute vec4 RockData;
attribute vec4 RockTint;
attribute vec3 RockEmitter;
attribute vec3 RockLight;
#endif
varying vec4 rock;
varying vec4 instanceTint;
varying vec3 emitter;
varying vec3 lampColor;
#else
extern vec4 rock; // two 16-bit seed words, pixel grid width, world radius
extern vec3 emitter;
extern vec3 lampColor;
#endif
varying vec4 basis;
varying vec4 profile;
varying vec4 reachesA;
varying vec4 reachesB;

#ifdef VERTEX
float roll(float n) {
    vec3 p = fract((vec3(rock.xy, n) + n * vec3(7., 19., 31.)) * vec3(.1031,.1030,.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x+p.y)*p.z);
}
vec4 position(mat4 transform, vec4 vertex) {
#ifdef ROCK_BATCH
    rock = RockData;
    instanceTint = RockTint;
    emitter = RockEmitter;
    lampColor = RockLight;
    vertex.xy = RockPose.xy + vertex.xy * RockPose.z;
#endif
    float family = floor(roll(1.)*3.);
    float angle = roll(2.)*6.2831853;
    float width = family < 1. ? .55 : (family < 2. ? .74 : .84);
    basis = vec4(cos(angle), sin(angle), .85+.13*roll(3.), width*(.86+.20*roll(4.)));
    profile = vec4(.22 + .12*family + .07*roll(5.), floor(8.*roll(6.)),
                   .48+.24*roll(7.), roll(8.));
    reachesA = .84+.16*vec4(roll(9.),roll(10.),roll(11.),roll(12.));
    reachesB = .84+.16*vec4(roll(13.),roll(14.),roll(15.),roll(16.));
    return transform*vertex;
}
#endif

#ifdef PIXEL
void clipFace(vec3 n, float bound, vec2 xy, inout float front, inout float back, inout vec3 normal) {
    float dz = n.z + .44*n.y;
    float gap = bound-dot(n.xy,xy);
    if (dz > .0001) {
        float z = gap/dz;
        if (z < front) { front=z; normal=n; }
    } else if (dz < -.0001) {
        back=max(back,gap/dz);
    } else if (gap < 0.) {
        back=100.;
    }
}
vec4 effect(vec4 tint, Image tex, vec2 uv, vec2 screen) {
    vec2 pixel = floor(uv*rock.z)+.5;
    vec2 p = (pixel/rock.z-.5)*(48./21.);
    float phase=profile.w*6.2831853;
    float grain=sin(11.*p.x+phase)*cos(9.*p.y-phase)+.45*sin(17.*p.y+6.*p.x);
    float relief=.018*grain;
    vec3 normal=vec3(.10,-.36,1.);
    float front=(profile.x+relief-dot(normal.xy,p))/(1.+.44*normal.y);
    float back=-profile.x*.73;
    vec2 axis=vec2(1.,0.);
    for(int i=0; i<8; i++) {
        vec2 a=axis/basis.zw;
        vec2 n=vec2(basis.x*a.x-basis.y*a.y,basis.y*a.x+basis.x*a.y);
        float reach;
        if(i<4) reach=reachesA[i]; else reach=reachesB[i-4];
        if(abs(float(i)-profile.y)<.25) reach*=profile.z;
        clipFace(vec3(n,.12), reach+relief, p,front,back,normal);
        clipFace(vec3(n.x,n.y-.14,.94),reach+.03+relief,p,front,back,normal);
        axis=.70710678*vec2(axis.x-axis.y,axis.x+axis.y);
    }
    if(front<back) discard;
    normal=normalize(normal);
    float tone=clamp(floor(4.3+dot(normal,vec3(-.52,-.63,.57))*3.6),1.,8.);
    if(rock.z>16. && abs(grain)>1.02) tone+=sign(grain);
    float seam=p.y-.27*p.x+.11*sin(p.x*8.+phase)+relief;
    if(rock.z>32. && profile.w>.66 && abs(p.x)<.4 && front>.15 && abs(seam)<.032) tone-=2.;
    float t=clamp((tone-1.)/7.,0.,1.);
    vec3 stone=mix(vec3(35.,36.,48.),vec3(184.,164.,140.),t)/255.;
    vec3 incidence=normalize(emitter-vec3(p*rock.w,0.));
    stone+=(1.-stone)*floor(lampColor*max(dot(normal,incidence),0.)*22.+.5)/31.;
#ifdef ROCK_BATCH
    tint *= instanceTint;
#endif
    return vec4(stone*tint.rgb,tint.a);
}
#endif
]]

function Art.begin()
    if not shader then
        shader = love.graphics.newShader(source)
        local data = love.image.newImageData(1,1)
        data:setPixel(0,0,1,1,1,1)
        white = love.graphics.newImage(data)
        data:release()
    end
    love.graphics.setShader(shader)
end

-- El tamaño limita una transferencia a la GPU, nunca la cantidad visible.
local batchSize = 512
local batchShader, quad, instances
local rows, count = {}, 0
local batchSupported
local format = {
    {'RockPose','float',3}, {'RockData','float',4}, {'RockTint','float',4},
    {'RockEmitter','float',3}, {'RockLight','float',3}
}

function Art.beginBatch()
    if batchSupported == nil then
        batchSupported = love.graphics.getSupported().instancing
        if batchSupported then
            local ok
            ok, batchShader = pcall(love.graphics.newShader, '#define ROCK_BATCH\n' .. source)
            batchSupported = ok
        end
        if batchSupported then
            quad = love.graphics.newMesh({
                {-.5,-.5,0,0}, {.5,-.5,1,0}, {-.5,.5,0,1}, {.5,.5,1,1}
            }, 'strip', 'static')
            instances = love.graphics.newMesh(format, batchSize, 'points', 'stream')
            for _, attribute in ipairs(format) do
                quad:attachAttribute(attribute[1], instances, 'perinstance')
            end
        end
    end
    count = 0
    if batchSupported then
        love.graphics.setColor(1,1,1,1)
        love.graphics.setShader(batchShader)
    else
        Art.begin()
    end
end

function Art.flush()
    if count == 0 then return end
    instances:setVertices(rows, 1, count)
    love.graphics.drawInstanced(quad, count)
    count = 0
end

function Art.add(kind, seed, x, y, radius, zoom, alpha, lod, color, light)
    if not batchSupported then
        return Art.draw(kind, seed, x, y, radius, zoom, alpha, lod, color, light)
    end
    count = count + 1
    local row = rows[count] or {}
    rows[count] = row
    row[1], row[2], row[3] = x, y, radius * zoom * (48/21)
    row[4], row[5], row[6], row[7] = seed % 65536, math.floor(seed/65536), 16*kind, radius
    row[8], row[9], row[10] = .68+.6*color[1], .71+.55*color[2], .74+.55*color[3]
    row[11] = alpha * (lod >= 2 and .8 or 1)
    row[12], row[13], row[14] = light and light.x or 0, light and light.y or 0, 8
    for i=1,3 do row[14+i] = light and light.color[i]*light.power or 0 end
    if count == batchSize then Art.flush() end
end

local wasLit
function Art.draw(kind, seed, x, y, radius, zoom, alpha, lod, color, light)
    parameters[1], parameters[2] = seed % 65536, math.floor(seed/65536)
    parameters[3], parameters[4] = 16*kind, radius
    shader:send('rock', parameters)
    if light or wasLit == nil or wasLit then
        lightVector[1],lightVector[2],lightVector[3] = 0,0,8
        radiance[1],radiance[2],radiance[3] = 0,0,0
        if light then
            lightVector[1],lightVector[2] = light.x,light.y
            for i=1,3 do radiance[i]=light.color[i]*light.power end
        end
        shader:send('emitter',lightVector)
        shader:send('lampColor',radiance)
        wasLit = light ~= nil
    end
    love.graphics.setColor(.68+.6*color[1],.71+.55*color[2],.74+.55*color[3],alpha*(lod>=2 and .8 or 1))
    local extent = radius*zoom*(48/21)
    love.graphics.draw(white,x,y,0,extent,extent,.5,.5)
end

return Art
