shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

global uniform vec3 sun_direction;
global uniform vec3 sun_color;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// PALLETTE VERDE-OCEAN / SMERALDO STILE LEONIDA
uniform vec3 shallow_color : source_color = vec3(0.06, 0.32, 0.30);
uniform vec3 deep_color : source_color = vec3(0.01, 0.08, 0.11);
uniform vec3 foam_color : source_color = vec3(0.88, 0.93, 0.95);

uniform float beer_factor : hint_range(0.1, 3.0) = 0.55;
uniform float foam_depth : hint_range(0.05, 1.5) = 0.35;
uniform float refraction_strength : hint_range(0.0, 0.05) = 0.015;
uniform float wave_strength : hint_range(0.01, 0.5) = 0.12;
uniform float wave_speed : hint_range(0.1, 3.0) = 0.9;

varying vec3 world_pos;

// RUMORE PROCEDURALE LEGGERO PER SCHIUMA E MICRO-INCRESPATURE
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// MULTI-OTTAVA PER INCRESPATURE NITIDE CALCOLATE PER-PIXEL
float wave_height_detail(vec2 p, float t, float dist) {
	float h = 0.0;

	// ONDE GRANDI (VISIBILI ANCHE A MEDIA DISTANZA)
	h += sin(p.x * 0.75 + p.y * 0.45 + t * 1.3) * 0.45;
	h += sin(p.x * -0.55 + p.y * 1.15 - t * 1.1) * 0.30;

	// OTTAVE DI DETTAGLIO SPENTE PROGRESSIVAMENE CON LA DISTANZA
	float fade_mid = 1.0 - smoothstep(15.0, 75.0, dist);
	float fade_fine = 1.0 - smoothstep(5.0, 30.0, dist);

	h += (noise2d(p * 1.4 + vec2(t * 0.45, -t * 0.35)) - 0.5) * 0.55 * fade_mid;
	h += (noise2d(p * 3.8 - vec2(t * 0.65, t * 0.50)) - 0.5) * 0.25 * fade_fine;
	h += (noise2d(p * 8.5 + vec2(t * 0.90, t * 0.40)) - 0.5) * 0.10 * fade_fine;
	return h;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// SOLO UN LEGGERO RESPIRO LENTO SUI VERTICI PER EVITARE SPIGOLI
	VERTEX.y += sin(world_pos.x * 0.15 + TIME * wave_speed) * 0.04;
}

void fragment() {
	// 1. CALCOLO NORMALE CON ATTENAZIONE PROGRESSIVA PER DISTANZA 
	float dist = length(VERTEX);
	float dist_fade = 1.0 - smoothstep(10.0, 120.0, dist);
	float effective_strength = wave_strength * mix(0.06, 1.0, dist_fade);
 
	float eps = 0.06;
	float t = TIME * wave_speed;
	float h0 = wave_height_detail(world_pos.xz, t, dist);
	float hx = wave_height_detail(world_pos.xz + vec2(eps, 0.0), t, dist);
	float hz = wave_height_detail(world_pos.xz + vec2(0.0, eps), t, dist);

	vec3 world_normal = normalize(vec3((h0 - hx) * effective_strength / eps, 1.0, (h0 - hz) * effective_strength / eps));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	// 2. PROFONDITÀ LINEARE REALE
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	float water_depth = max((-view_pos.z) - (-VERTEX.z), 0.0);

	// 3. RIFRAZIONE DEL FONDALE GUIDATA DALLE MICRO-ONDE
	float refract_mask = clamp(water_depth * 2.0, 0.0, 1.0);
	vec2 distorted_uv = SCREEN_UV + world_normal.xz * refraction_strength * refract_mask;
	vec3 seabed = texture(screen_texture, distorted_uv).rgb;

	// 4. ASSORBIMENTO LAMBERT-BEER (VOLUME VERDE-SMERALDO TRASPARENTE)
	float trasmittance = exp(-water_depth * beer_factor);
	vec3 water_volume = mix(deep_color, shallow_color, trasmittance);
	vec3 underwater = mix(water_volume, seabed * mix(vec3(1.0), shallow_color * 2.4, 0.45), trasmittance);

	// 5. EFFETTO FRESNEL (TRASPARENTE GUARDANDO IN BASSO, RIFLETTENTE VERSO L'ORIZZONTE)
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 4.5);

	// 5. SCHIUMA SOTTILE LUNGO LA BATTIGLIA
	float foam_n = noise2d(world_pos.xz * 4.5 + vec2(t * 0.5, t * 0.3));
	float shore_edge = smoothstep(foam_depth, 0.0, water_depth);
	float foam_mask = smoothstep(0.35, 0.75, shore_edge * 0.85 + foam_n * shore_edge);

	// COMPOSIZIONE FINALE: LASCIA AL PBR DI GODOT IL RIFLESSO DEL CIELO E DEL SOLE
	ALBEDO = mix(underwater, foam_color, foam_mask * 0.8);
	float base_rough = mix(0.22, 0.035, dist_fade);
	ROUGHNESS = mix(base_rough, 0.45, foam_mask);
	METALLIC = 0.0;
	SPECULAR = mix(0.65, 1.0, fresnel);
}
