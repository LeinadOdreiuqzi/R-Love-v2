// src/shaders/station_interior_light.glsl
// Shader de composición de iluminación dinámica para interiores de la estación espacial.
// Multiplica la textura de la escena por el lightmap virtual, protegiendo altas luces
// y aplicando un suave efecto de bloom/resplandor para emisivos (visores, pantallas, LEDs).

extern Image u_lightCanvas;
extern float u_bloomIntensity;

vec4 effect(vec4 color, Image sceneTex, vec2 texcoord, vec2 screen_coords) {
    vec4 sceneCol = Texel(sceneTex, texcoord);
    vec4 lightCol = Texel(u_lightCanvas, texcoord);

    if (sceneCol.a < 0.01) {
        return vec4(0.0);
    }

    // 1. Modulación en penumbra: Escena * Lightmap
    vec3 lit = sceneCol.rgb * lightCol.rgb;

    // 2. Aporte de resplandor / bloom para emisivos y luces intensas (light > 0.92)
    // Permite que consolas, el visor del astronauta y chispas brillen con intensidad propia
    vec3 overexposure = max(vec3(0.0), lightCol.rgb - vec3(0.92));
    float bloomWeight = (u_bloomIntensity > 0.0) ? u_bloomIntensity : 0.65;
    lit += overexposure * bloomWeight * sceneCol.rgb * 1.5;

    // 3. Sutil viñeta óptica en los extremos del visor / cámara
    vec2 uvNorm = texcoord - vec2(0.5);
    float vignette = 1.0 - dot(uvNorm, uvNorm) * 0.42;
    lit *= clamp(vignette, 0.78, 1.0);

    return vec4(lit, sceneCol.a) * color;
}
