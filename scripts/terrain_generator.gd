class_name TerrainGenerator
extends MeshInstance3D

@export var grid_size : int = 120
@export var world_size : float = 160.0
@export var max_height : float = 5.5
@export var noise_seed : int = 42

func _ready() -> void:
	_generate_coast()

func _generate_coast() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.018
	noise.fractal_octaves = 4

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var step : float = world_size / float(grid_size)
	var half : float = world_size * 0.5

	for z in range(grid_size):
		for x in range(grid_size):
			var p00 := _get_point(x, z, step, half, noise)
			var p10 := _get_point(x + 1, z, step, half, noise)
			var p01 := _get_point(x, z + 1, step, half, noise)
			var p11 := _get_point(x + 1, z + 1, step, half, noise)

			_add_triangle(st, p00, p10, p01)
			_add_triangle(st, p10, p11, p01)

	st.generate_normals()
	mesh = st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.92
	material_override = mat

func _get_point(gx: int, gz: int, step: float, half: float, noise: FastNoiseLite) -> Vector3:
	var wx : float = gx * step - half
	var wz : float = gz * step - half
	var dist : float = Vector2(wx, wz).length() / half
	var island_mask : float = clampf(1.0 - pow(dist, 2.2), 0.0, 1.0)
	var n : float = (noise.get_noise_2d(wx, wz) + 1.0) * 0.5
	var y : float = (n * max_height * island_mask) - 1.4
	return Vector3(wx, y, wz)

func _add_triangle(st: SurfaceTool, a : Vector3, b : Vector3, c : Vector3) -> void:
	for v: Vector3 in [a, b, c]:
		st.set_color(_height_to_color(v.y))
		st.add_vertex(v)

func _height_to_color(y: float) -> Color:
	var wet_sand := Color(0.55, 0.43, 0.28)
	var dry_sand := Color(0.76, 0.65, 0.44)
	var tropical_grass := Color(0.18, 0.38, 0.14)

	if y < 0.20: return wet_sand
	elif y < 0.75: return wet_sand.lerp(dry_sand, (y - 0.20) / 0.55)
	else: return dry_sand.lerp(tropical_grass, clampf((y - 0.75) / 0.85, 0.0, 1.0))
