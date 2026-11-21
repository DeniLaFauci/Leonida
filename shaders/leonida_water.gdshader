shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

global uniform vec3 sun_direction;
global uniform vec3 sun_color;

uniform vec3 shallow_color : source_color = vec3(0.08, 0.45, 0.48);
uniform vec3 deep_color : source_color = vec3(0.01, 0.12, 0.18);
uniform float wave_height : hint_range(0.0, 1.0) = 0.18;
uniform float wave_speed : hint_range(0.1, 3.0) = 1.20;

varying vec3 world_pos;

float calc_wave(vec2 p, float t) {
	float w1 = sin(p.x * 0.35 + t * wave_speed) * 0.5;
	float w2 = cos(p.y * 0.45 + t * wave_speed * 0.85) * 0.35;
	float w3 = sin((p.x + p.y) * 0.22 - t * wave_speed * 1.1) * 0.25;
	return (w1 + w2 + w3) * wave_height;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = calc_wave(world_pos.xz, TIME);
	VERTEX.y += h;

	float eps = 0.25;
	float hx = calc_wave(world_pos.xz + vec2(eps, 0.0), TIME);
	float hz = calc_wave(world_pos.xz + vec2(0.0, eps), TIME);
	NORMAL = normalize(vec3(h - hx, eps, h - hz));
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 water_col = mix(deep_color, shallow_color, clamp(fresnel * 1.2, 0.0, 1.0));

	ALBEDO = water_col;
	ROUGHNESS = 0.06;
	METALLIC = 0.05;
	SPECULAR = mix(0.5, 1.0, fresnel);
}
