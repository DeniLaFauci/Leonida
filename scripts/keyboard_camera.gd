class_name KeyboardCamera
extends Camera3D

@export var move_speed : float = 12.0
@export var fast_multiplayer : float = 2.5
@export var rotate_speed : float = 1.6

var _yaw : float = 0.0
var _pitch : float = -0.15

func _ready() -> void:
	rotation = Vector3(_pitch, _yaw, 0.0)

func _process(delta : float) -> void:
	# Rotazione con le frecce direzionali
	var yaw_input : float = float(Input.is_key_pressed(KEY_LEFT)) - float(Input.is_key_pressed(KEY_RIGHT))
	var pitch_input : float = float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))

	_yaw += yaw_input * rotate_speed * delta
	_pitch = clampf(_pitch + pitch_input * rotate_speed * delta, deg_to_rad(-85.0), deg_to_rad(85.0))
	rotation = Vector3(_pitch, _yaw, 0.0)

	# Movimento: WASD + E (SALI) / Q (SCENDI) + SHIFT (VELOCE)
	var move_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move_dir -= global_transform.basis.z
	if Input.is_key_pressed(KEY_S): move_dir += global_transform.basis.z
	if Input.is_key_pressed(KEY_A): move_dir -= global_transform.basis.x
	if Input.is_key_pressed(KEY_D): move_dir += global_transform.basis.x
	if Input.is_key_pressed(KEY_E): move_dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): move_dir -= Vector3.UP

	if move_dir.length_squared() > 0.0:
		var speed : float = move_speed * (fast_multiplayer if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		global_position += move_dir.normalized() * speed * delta
