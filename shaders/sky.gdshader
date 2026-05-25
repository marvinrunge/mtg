shader_type sky;

uniform vec3 sky_top : source_color = vec3(0.08, 0.18, 0.36);
uniform vec3 sky_horizon : source_color = vec3(0.48, 0.38, 0.48);
uniform vec3 cloud_color : source_color = vec3(0.9, 0.85, 0.92);
uniform float cloud_scale = 0.3;
uniform float cloud_speed = 0.01;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.38;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = rot * p * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

void sky() {
    float dy = EYEDIR.y;
    vec3 sky_base = mix(sky_horizon, sky_top, clamp(dy * 2.5, 0.0, 1.0));
    
    if (dy > 0.0) {
        // Flat projection for clouds overhead
        vec2 uv = EYEDIR.xz / (dy + 0.02);
        uv += TIME * cloud_speed;
        
        float n = fbm(uv * cloud_scale);
        float cloud_mask = smoothstep(1.0 - cloud_density, 1.0 - cloud_density + 0.2, n);
        
        // Fade clouds near the horizon
        cloud_mask *= smoothstep(0.0, 0.15, dy);
        
        COLOR = mix(sky_base, cloud_color, cloud_mask);
    } else {
        COLOR = sky_base;
    }
}
