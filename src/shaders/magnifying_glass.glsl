// Simplified Magnifying Glass Shader for Game Use
// Essential refraction and chromatic aberration effects

#ifdef PIXEL
// Basic magnifying glass parameters
uniform vec2 u_magnifier_pos;      // Position of the magnifier center (0-1 normalized)
uniform float u_magnifier_radius;  // Radius of the magnifying effect (0-1)
uniform float u_distortion_strength; // Strength of the distortion effect (0-2)
uniform float u_magnification;     // Magnification factor (1-3)
uniform float u_edge_softness;     // Softness of the magnifier edge (0-1)
uniform float u_chromatic_aberration; // Chromatic aberration strength (0-0.01)

// New: effect selection and wave params
uniform int u_effect_type;         // 0 = lens, 1 = wave
uniform float u_wave_width;        // Width of the ripple band around radius (0-1, normalized)
uniform float u_wave_amplitude;    // Amplitude of radial displacement for ripple (0-0.05 typical)

// Simplified refraction calculation (lens)
vec2 calculateRefraction(vec2 uv, vec2 center, float radius) {
    vec2 offset = uv - center;
    float distance = length(offset);

    // Only apply effect within the magnifier radius
    if (distance > radius) {
        return uv;
    }

    // Calculate normalized distance from center (0 at center, 1 at edge)
    float normalizedDist = distance / radius;

    // Simple lens distortion using quadratic falloff
    float distortionFactor = 1.0 - normalizedDist * normalizedDist;

    // Apply magnification with smooth falloff
    vec2 magnifiedOffset = offset * (1.0 / u_magnification) * distortionFactor;

    // Add barrel distortion
    float barrelDistortion = 1.0 + normalizedDist * normalizedDist * u_distortion_strength * 0.1;
    magnifiedOffset *= barrelDistortion;

    // Ensure we never sample exactly the same center pixel (avoid seeing the object at the very center)
    // Push the sample a minimum amount away from the center, stronger near the center and fading toward the edge
    vec2 dir = (distance > 1e-5) ? (offset / max(distance, 1e-5)) : vec2(1.0, 0.0);
    float minCenterShift = u_distortion_strength * 0.02; // tune as needed
    float centerInfluence = 1.0 - normalizedDist; // 1 at center, 0 at edge
    magnifiedOffset += dir * (minCenterShift * centerInfluence);

    // Calculate final UV and clamp to screen
    vec2 finalUV = center + magnifiedOffset;
    finalUV = clamp(finalUV, vec2(0.0), vec2(1.0));

    return finalUV;
}

// Simplified chromatic aberration (lens)
vec3 sampleWithChromaticAberration(sampler2D tex, vec2 uv, vec2 center, float radius) {
    // Fast path: no chromatic aberration requested -> single sample
    if (u_chromatic_aberration <= 0.0) {
        vec2 uvClamped = clamp(uv, vec2(0.0), vec2(1.0));
        return Texel(tex, uvClamped).rgb;
    }

    vec2 offset = uv - center;
    float distance = length(offset);

    if (distance > radius) {
        return Texel(tex, uv).rgb;
    }

    float normalizedDist = distance / radius;

    // Simple chromatic aberration - different offsets for each color channel
    float aberrationStrength = u_chromatic_aberration * normalizedDist;

    vec2 redOffset = offset * (1.0 + aberrationStrength * 0.8);
    vec2 greenOffset = offset * (1.0 + aberrationStrength * 1.0);
    vec2 blueOffset = offset * (1.0 + aberrationStrength * 1.2);

    vec2 redUV = center + redOffset;
    vec2 greenUV = center + greenOffset;
    vec2 blueUV = center + blueOffset;

    // Clamp UV coordinates
    redUV = clamp(redUV, vec2(0.0), vec2(1.0));
    greenUV = clamp(greenUV, vec2(0.0), vec2(1.0));
    blueUV = clamp(blueUV, vec2(0.0), vec2(1.0));

    // Sample each color channel separately
    float r = Texel(tex, redUV).r;
    float g = Texel(tex, greenUV).g;
    float b = Texel(tex, blueUV).b;

    return vec3(r, g, b);
}

// Main effect function
vec4 effect(vec4 color, sampler2D texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec3 original = Texel(texture, uv).rgb;

    float distanceFromCenter = length(uv - u_magnifier_pos);

    // Effect type: 0 = lens (existing behavior)
    if (u_effect_type == 0) {
        // Early exit if completely outside magnifier area
        if (distanceFromCenter > u_magnifier_radius + u_edge_softness) {
            return vec4(original, 1.0) * color;
        }

        // Calculate refracted UV coordinates
        vec2 refractedUV = calculateRefraction(uv, u_magnifier_pos, u_magnifier_radius);

        // Sample the texture with chromatic aberration
        vec3 refractedColor = sampleWithChromaticAberration(texture, refractedUV, u_magnifier_pos, u_magnifier_radius);

        // Calculate smooth edge blending
        float edgeBlend = 1.0;
        float edgeStart = u_magnifier_radius - u_edge_softness;

        if (distanceFromCenter > edgeStart) {
            float edgeDistance = distanceFromCenter - edgeStart;
            float t = clamp(edgeDistance / u_edge_softness, 0.0, 1.0);
            edgeBlend = 1.0 - smoothstep(0.0, 1.0, t);
        }

        // Blend between original and refracted color based on distance
        vec3 finalColor;
        if (distanceFromCenter < u_magnifier_radius) {
            // Inside the lens: only refracted color, avoid sampling original
            finalColor = refractedColor;
        } else {
            // Edge ring (soft transition): need original color for blending
            float hardT = smoothstep(0.0, 0.7, edgeBlend);
            finalColor = mix(refractedColor, original, hardT);
        }

        // Reduce central brightness boost to avoid dimming around
        if (distanceFromCenter < u_magnifier_radius) {
            float normalizedDist = distanceFromCenter / u_magnifier_radius;
            float brightnessFactor = 1.0 + (1.0 - normalizedDist) * 0.04;
            finalColor *= brightnessFactor;
        }

        return vec4(finalColor, 1.0) * color;
    }

    // Effect type: 1 = wave (radial ripple band centered at radius)
    // Early exit if completely outside band influence
    float maxInfluence = u_magnifier_radius + u_wave_width + u_edge_softness;
    if (distanceFromCenter > maxInfluence) {
        return vec4(original, 1.0) * color;
    }

    // Triangular bell profile around the target radius
    float d = abs(distanceFromCenter - u_magnifier_radius);
    float band = 1.0 - smoothstep(0.0, u_wave_width, d);

    // Apply radial displacement proportional to band intensity
    vec2 dir = (distanceFromCenter > 1e-5) ? normalize(uv - u_magnifier_pos) : vec2(1.0, 0.0);
    vec2 wavedUV = uv + dir * (u_wave_amplitude * band);
    wavedUV = clamp(wavedUV, vec2(0.0), vec2(1.0));

    vec3 wavedColor = Texel(texture, wavedUV).rgb;

    // Edge blending near outermost influence to avoid harsh cutoff
    float outerT = smoothstep(u_magnifier_radius + u_wave_width, maxInfluence, distanceFromCenter);
    vec3 finalWave = mix(wavedColor, original, outerT);

    return vec4(finalWave, 1.0) * color;
}
#endif