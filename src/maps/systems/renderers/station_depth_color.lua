-- Camera-space depth is normalized per design: positive is towards the viewer.
-- Pull far values into a cool palette while retaining differences between metals.
return [[
float recession(float depth) {
    return 1.0-smoothstep(-.82,.30,depth);
}
vec3 depthColor(vec3 rgb,float amount) {
    float value=dot(rgb,vec3(.27,.55,.18));
    vec3 slate=vec3(.064,.094,.155)+value*vec3(.38,.52,.68);
    return mix(rgb,slate,.82*amount);
}
]]
