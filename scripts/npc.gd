extends Node3D

# A "neighbor" — someone outside the jar. Visually present but
# unreachable for two-way dialogue; the GM may reference them, the
# Dragonrot infection may dim them, and once per run the player can
# trigger a one-way "whisper" — a single line that bleeds through
# the glass before silence resumes.
#
# Public:
#   set_intensity(v: float)  # 0 = normal, 1 = fully drained / infected

@export var npc_id: String = ""
@export var base_color: Color = Color(0.7, 0.65, 0.6, 1.0)

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var head_mesh: MeshInstance3D = $HeadMesh
var intensity: float = 0.0
var _material: StandardMaterial3D
var player_in_range: bool = false
var whisper_used: bool = false

signal whisper_requested(npc_id: String)

func _ready() -> void:
	add_to_group("npcs")
	_material = StandardMaterial3D.new()
	_material.albedo_color = base_color
	_material.roughness = 0.7
	if mesh:
		mesh.set_surface_override_material(0, _material)
	if head_mesh:
		head_mesh.set_surface_override_material(0, _material)
	# Set up an Area3D child for proximity detection (created at runtime
	# so the scene file stays simple — the Node3D root carries no body).
	var area := Area3D.new()
	area.name = "WhisperArea"
	add_child(area)
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	shape.shape = sph
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func set_intensity(v: float) -> void:
	intensity = clamp(v, 0.0, 1.0)
	if _material == null:
		return
	# Drain saturation toward gray, darken slightly as intensity rises
	var gray := Color(0.18, 0.18, 0.2, 1.0)
	_material.albedo_color = base_color.lerp(gray, intensity)
	_material.roughness = 0.7 + intensity * 0.25

func _on_body_entered(body: Node) -> void:
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.name == "Player":
		player_in_range = false

func _input(event: InputEvent) -> void:
	if not player_in_range or whisper_used:
		return
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo and convo.is_open():
		return
	if event.is_action_pressed("ui_accept"):
		whisper_used = true
		whisper_requested.emit(npc_id)
