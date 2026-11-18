-- Sideways travel of the camera, expressed in apparent station radii. Near
-- the station this is linear, just like the map's background parallax.
local View={}
local steps=64
-- Keep the static perspective while damping the change in viewpoint during flight.
local cameraTravel=.35
function View.sample(station,camera,radius)
    if not camera then return 0,0 end
    local scale=(camera.zoom or 1)/radius
    local function axis(distance)
        local offset=distance*scale
        local magnitude=math.abs(offset)
        if magnitude>1 then
            -- The slope matches the linear region at one radius and eases to zero.
            local tail=magnitude-1
            offset=(offset<0 and -1 or 1)*(1+tail/(1+2*tail))
        end
        return math.floor(offset*steps+.5)
    end
    return axis(station.x-camera.x),axis(station.y-camera.y)
end
function View.offset(ix,iy,modelRadius)
    local gain=modelRadius*cameraTravel/steps
    return ix*gain,iy*gain
end
-- Perspective around the camera rather than the sprite centre. At zero
-- depth the projected anchor agrees exactly with camera:worldToScreen.
View.shader=[[
extern vec2 cameraOffset;
extern float focalDistance;
vec4 projectStation(mat4 transformProjection,vec3 location) {
    float w=1.-location.z/focalDistance;
    vec2 xy=location.xy+cameraOffset*(1.-w);
    return transformProjection*vec4(xy,0.,w);
}
]]
return View
