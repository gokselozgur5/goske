extends CharacterBody3D

const SPEED := 5.0
const GRAVITY := 9.8
const COMFORT_RADIUS := 5.0
const DASH_SPEED := 22.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 0.7

var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO

@export var goske_mat: StandardMaterial3D
@export var black_mat: StandardMaterial3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var head_mesh: MeshInstance3D = $HeadMesh
var in_comfort: bool = true
var _was_exhausted_black: bool = false

# Isometric camera — a sibling Camera3D in the scene root with a fixed
# rotation. We move it every frame to keep the player centered, but
# we NEVER touch its basis: the angle stays constant so screen-space
# input keys map to a stable world direction.
var _camera: Camera3D = null
const CAMERA_OFFSET := Vector3(6.0, 6.0, 6.0)
const CAMERA_TARGET_OFFSET := Vector3(0, 1.0, 0)

# Optional rigged body — UAL1 mannequin with AnimationPlayer. Resolved on
# _ready; if absent (legacy main.tscn), animation state is skipped.
var _anim: AnimationPlayer = null
var _current_anim: String = ""
# Godot strips the "_Loop" suffix from glb animations on import and sets
# loop_mode=LINEAR; the real names are "Idle" / "Walk".
const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walk"

func _ready() -> void:
	_apply_material()
	_resolve_animation_player()
	_play_anim(ANIM_IDLE)
	_resolve_camera()

func _resolve_camera() -> void:
	# Look at scene-root siblings for a Camera3D first; fall back to any
	# Camera3D in the tree.
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is Camera3D:
				_camera = child
				return
	_camera = get_viewport().get_camera_3d()

func _resolve_animation_player() -> void:
	# Recursive search — UAL1's AnimationPlayer sits a few levels deep
	# under Body/Armature in the imported glb tree.
	var body := get_node_or_null("Body")
	if body == null:
		return
	_anim = _find_anim_recursive(body)

func _find_anim_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim_recursive(c)
		if found != null:
			return found
	return null

func _play_anim(name: String) -> void:
	if _anim == null:
		return
	if _current_anim == name:
		return
	if not _anim.has_animation(name):
		return
	_anim.play(name)
	_current_anim = name

func _update_camera() -> void:
	# Position-follow only. The camera's rotation is set once in the scene
	# (isometric basis); we never look_at, so the angle stays put.
	if _camera == null:
		return
	_camera.global_position = global_position + CAMERA_OFFSET

func _physics_process(delta: float) -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	# Conversation open: only freeze if the input field has focus
	# (otherwise the player can roam while alters speak through bubbles).
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo and convo.is_open():
		velocity = Vector3.ZERO
		move_and_slide()
		_play_anim(ANIM_IDLE)
		_update_camera()
		return
	var subtitle := get_tree().get_first_node_in_group("opening_subtitle")
	if subtitle and subtitle._active:
		velocity = Vector3.ZERO
		move_and_slide()
		_play_anim(ANIM_IDLE)
		_update_camera()
		return
	# Slow exhaustion recovery while idle (and not typing)
	if gs:
		gs.recover_exhaustion(delta)

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_dir.x, 0, input_dir.y)
	direction = direction.rotated(Vector3.UP, deg_to_rad(45))
	direction = direction.normalized()

	# Dash timers
	_dash_cooldown_timer = max(0.0, _dash_cooldown_timer - delta)
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * DASH_SPEED
		velocity.z = _dash_dir.z * DASH_SPEED
	else:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED

	# Trigger dash on Space — use last move dir, fall back to facing dir
	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		var d := direction if direction.length_squared() > 0.01 else Vector3(sin(rotation.y), 0, cos(rotation.y))
		_dash_dir = d.normalized()
		_dash_timer = DASH_DURATION
		_dash_cooldown_timer = DASH_COOLDOWN

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Animation state — walk while moving, idle while still
	var moving := Vector2(velocity.x, velocity.z).length_squared() > 0.04
	_play_anim(ANIM_WALK if moving else ANIM_IDLE)

	# Face the direction of movement. UAL1 mannequin's local forward is
	# +Z (its mesh "looks" toward +Z by default), so atan2(vx, vz) makes
	# the model face the velocity vector.
	if moving:
		var yaw := atan2(velocity.x, velocity.z)
		rotation.y = yaw

	# Third-person camera: place behind the player (in player local +Z)
	# and look at the torso. The camera rotates with the player because
	# we transform the offset through the player's basis.
	_update_camera()

	var dist := Vector2(position.x, position.z).length()
	var was_in_comfort := in_comfort
	in_comfort = dist < COMFORT_RADIUS
	if in_comfort != was_in_comfort:
		_apply_material()
		if was_in_comfort and not in_comfort:
			if gs:
				gs.record_comfort_exit()
	# Exhaustion threshold change can also flip the material
	_apply_material_if_exhausted_changed(gs)

func _apply_material() -> void:
	if mesh == null:
		return
	var gs := get_tree().get_first_node_in_group("game_state")
	var exhausted: bool = false
	if gs != null and gs.exhaustion >= gs.EXHAUSTION_BLACK_THRESHOLD:
		exhausted = true
	var should_be_black: bool = (not in_comfort) or exhausted
	var target_mat = black_mat if should_be_black else goske_mat
	if target_mat:
		mesh.set_surface_override_material(0, target_mat)
		if head_mesh:
			head_mesh.set_surface_override_material(0, target_mat)
	_was_exhausted_black = exhausted

func _apply_material_if_exhausted_changed(gs) -> void:
	if gs == null:
		return
	var exhausted: bool = gs.exhaustion >= gs.EXHAUSTION_BLACK_THRESHOLD
	if exhausted != _was_exhausted_black:
		_apply_material()
