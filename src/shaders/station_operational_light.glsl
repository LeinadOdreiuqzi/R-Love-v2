// src/shaders/station_operational_light.glsl
// Shader para estaciones espaciales operacionales (Luces encendidas, energía plena).
// Estética Sci-Fi limpia, luminosa y tecnológica:
// - Iluminación homogénea y clara sin sombras opresivas de penumbra.
// - Fidelidad cromática completa y contraste nítido de pixel art.
// - Resplandor / bloom en tiras LED de techo, pantallas y consolas.
// - Realce cromático sutil de arquitectura espacial activa.

extern Image u_lightCanvas;
extern vec3 u_accentColor;
extern float u_bloomIntensity;
extern float u_exposure;

vec4 effect(vec4 color, Image sceneTex, vec2 texcoord, vec2 screen_coords) {
    vec4 sceneCol = Texel(sceneTex, texcoord);
    vec4 lightCol = Texel(u_lightCanvas, texcoord);

    if (sceneCol.a < 0.01) {
        return vec4(0.0);
    }

    // 1. Modulación para estación operacional:
    // La luz ambiente es alta (~0.88 - 0.95) y las luminarias aportan hasta ~1.30.
    // Modulamos la escena manteniendo una base luminosa nítida y bien iluminada:
    float exp = (u_exposure > 0.0) ? u_exposure : 1.0;
    vec3 lightFactor = clamp(lightCol.rgb, 0.70, 1.35) * exp;
    vec3 lit = sceneCol.rgb * lightFactor;

    // 2. Resplandor / Bloom suave para emisivos activos (luminarias, consolas, LEDs)
    float luma = dot(lightCol.rgb, vec3(0.299, 0.587, 0.114));
    if (luma > 0.92) {
        float bloomWeight = (u_bloomIntensity > 0.0) ? u_bloomIntensity : 0.60;
        float glow = (luma - 0.92) * bloomWeight;
        lit += lightCol.rgb * glow * 1.10;
    }

    // 3. Tinte cromático sutil de tecnología limpia (blanco puro / xenón / acento)
    vec3 accent = (length(u_accentColor) > 0.01) ? u_accentColor : vec3(0.55, 0.85, 1.0);
    vec3 tint = mix(vec3(1.0), accent, 0.04);
    lit *= tint;

    return vec4(lit, sceneCol.a) * color;
}
