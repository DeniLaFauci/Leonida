class_name DayNightCycle
extends DirectionalLight3D

@export_range(0.0, 24.0, 0.01) var time_of_day: float = 15.0
@export var day_duration_seconds: float = 600.0
@export var pause_cycle: bool = false
@export var max_sun_energy: float = 3.0
@export var azimuth_angle: float = 145.0

var sun_color_gradient: Gradient

func _ready() -> void:
	shadow_enabled = true
	directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	directional_shadow_blend_splits = true
	directional_shadow_max_distance = 250.0
	_init_default_curves()
	_update_lighting()

func _process(delta: float) -> void:
	if not pause_cycle and day_duration_seconds > 0.0:
		time_of_day += (delta / day_duration_seconds) * 24.0
		if time_of_day > 24.0: time_of_day -= 24.0
	_update_lighting()

func _update_lighting() -> void:
	var day_progress: float = time_of_day / 24.0
	var sun_pitch: float = (day_progress * 360.0) - 90.0
	rotation_degrees = Vector3(-sun_pitch, azimuth_angle, 0.0)

	var sun_height: float = sin(deg_to_rad(sun_pitch))
	var normalized_height: float = clampf((sun_height + 0.15) / 1.15, 0.0, 1.0)

	if sun_color_gradient: light_color = sun_color_gradient.sample(normalized_height)
	light_energy = clampf(sun_height * max_sun_energy, 0.6, max_sun_energy) if sun_height > 0.0 else 0.0
	visible = sun_height > -0.05

	RenderingServer.global_shader_parameter_set("sun_direction", -global_transform.basis.z)
	RenderingServer.global_shader_parameter_set("sun_color", light_color)

func _init_default_curves() -> void:
	sun_color_gradient = Gradient.new()
	sun_color_gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 1.0])
	sun_color_gradient.colors = PackedColorArray([
		Color(0.85, 0.28, 0.12),
		Color(1.0, 0.62, 0.32),
		Color(1.0, 0.92, 0.82),
		Color(1.0, 0.98, 0.95)
	])
