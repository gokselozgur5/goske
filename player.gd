extends CharacterBody3D

const SPEED := 5.0
const GRAVITY := 9.8
const COMFORT_RADIUS := 5.0

@export var goske_mat: StandardMaterial3D
@export var black_mat: StandardMaterial3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
var in_comfort: bool = true

func _ready() -> void:
	_apply_material()

func _physics_process(delta: float) -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	# Conversation aktifken Goske donuk dursun
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo and convo.is_open():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	# Conversation kapaliyken yavas tukenis recovery
	if gs:
		gs.recover_exhaustion(delta)

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_dir.x, 0, input_dir.y)
	direction = direction.rotated(Vector3.UP, deg_to_rad(45))
	direction = direction.normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	var dist := Vector2(position.x, position.z).length()
	var was_in_comfort := in_comfort
	in_comfort = dist < COMFORT_RADIUS
	if in_comfort != was_in_comfort:
		_apply_material()
		if was_in_comfort and not in_comfort:
			if gs:
				gs.record_comfort_exit()
	# Tukenis esik gecisi de material'i tetikleyebilir
	_apply_material_if_exhausted_changed(gs)

var _was_exhausted_black: bool = false

func _apply_material() -> void:
	if mesh == null:
		return
	var gs := get_tree().get_first_node_in_group("game_state")
	var exhausted: bool = false
	if gs != null and gs.exhaustion >= gs.EXHAUSTION_BLACK_THRESHOLD:
		exhausted = true
	var should_be_black: bool = (not in_comfort) or exhausted
	if should_be_black and black_mat:
		mesh.set_surface_override_material(0, black_mat)
	elif not should_be_black and goske_mat:
		mesh.set_surface_override_material(0, goske_mat)
	_was_exhausted_black = exhausted

func _apply_material_if_exhausted_changed(gs) -> void:
	if gs == null:
		return
	var exhausted: bool = gs.exhaustion >= gs.EXHAUSTION_BLACK_THRESHOLD
	if exhausted != _was_exhausted_black:
		_apply_material()
