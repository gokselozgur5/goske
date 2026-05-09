extends Node3D

@export var pod_shell_path: NodePath = NodePath("PodShell")

var _black_mat: StandardMaterial3D = null

func _ready() -> void:
	_black_mat = StandardMaterial3D.new()
	_black_mat.albedo_color = Color(0.04, 0.04, 0.04, 1.0)
	var shell := get_node_or_null(pod_shell_path) as Node3D
	if shell == null:
		return
	_apply_black(shell)

func _apply_black(n: Node) -> void:
	if n is MeshInstance3D and "Human" in n.name:
		n.visible = true
		for i in n.get_surface_override_material_count():
			n.set_surface_override_material(i, _black_mat)
		return
	for c in n.get_children():
		_apply_black(c)
