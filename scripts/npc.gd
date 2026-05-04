extends Node3D

# A "neighbor" — someone outside the jar. Visually present but
# unreachable; the GM may reference them and the Dragonrot infection
# may dim them as exhaustion spreads.
#
# Public:
#   set_intensity(v: float)  # 0 = normal, 1 = fully drained / infected

@export var npc_id: String = ""
@export var base_color: Color = Color(0.7, 0.65, 0.6, 1.0)

@onready var mesh: MeshInstance3D = $MeshInstance3D
var intensity: float = 0.0
var _material: StandardMaterial3D

func _ready() -> void:
	add_to_group("npcs")
	_material = StandardMaterial3D.new()
	_material.albedo_color = base_color
	_material.roughness = 0.7
	if mesh:
		mesh.set_surface_override_material(0, _material)

func set_intensity(v: float) -> void:
	intensity = clamp(v, 0.0, 1.0)
	if _material == null:
		return
	# Drain saturation toward gray, darken slightly as intensity rises
	var gray := Color(0.18, 0.18, 0.2, 1.0)
	_material.albedo_color = base_color.lerp(gray, intensity)
	_material.roughness = 0.7 + intensity * 0.25
