shader_type spatial;

varying vec3 world_position;

uniform vec3 grid_color : source_color = vec3(0.0, 0.8, 1.0);
uniform vec3 base_color : source_color = vec3(0.03, 0.03, 0.05);
uniform float grid_size = 2.0;
uniform float line_width = 0.03;
uniform float roughness = 0.15;
uniform float metallic = 0.85;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 grid = abs(fract(world_position.xz / grid_size - 0.5) - 0.5) / (line_width / grid_size);
    float line = min(grid.x, grid.y);
    float grid_mask = 1.0 - min(line, 1.0);
    
    ALBEDO = mix(base_color, grid_color, grid_mask * 0.3);
    ROUGHNESS = roughness;
    METALLIC = metallic;
    
    // Grid lines emit light
    EMISSION = grid_color * grid_mask * 0.8;
}
