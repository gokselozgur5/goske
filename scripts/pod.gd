extends Area3D

# Intro pod. Player walks up, presses E/Space, the pod opens, the alter
# inside rises and "wakes". Manifesto: the player chooses how many alters
# to wake; the choice can't be reversed.

@export var alter_id: String = ""
@export var lid_path: NodePath
@export var alter_root_path: NodePath
@export var pod_shell_path: NodePath = NodePath("PodShell")

var opened: bool = false
var player_in_range: bool = false
var _black_mat: StandardMaterial3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# While closed: alter hidden, sunk into the pod, interaction off.
	# We don't lie them down anymore — the rigged humanoid's pivot doesn't
	# play nicely with X-axis rotation, so we just hide + drop them and
	# float them up on _open instead.
	var alter := get_node_or_null(alter_root_path) as Node3D
	if alter:
		alter.visible = false
		var iarea: Area3D = alter.get_node_or_null("InteractionArea")
		if iarea:
			iarea.monitoring = false
			iarea.monitorable = false
	# Pod içindeki human mesh — siyah silüet olarak göster
	_black_mat = StandardMaterial3D.new()
	_black_mat.albedo_color = Color(0.04, 0.04, 0.04, 1.0)
	var shell := get_node_or_null(pod_shell_path) as Node3D
	if shell:
		var human := _find_human_mesh(shell)
		if human:
			human.visible = true
			for i in human.get_surface_override_material_count():
				human.set_surface_override_material(i, _black_mat)

func _on_body_entered(body: Node) -> void:
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.name == "Player":
		player_in_range = false

func _input(event: InputEvent) -> void:
	if not player_in_range:
		return
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo and convo.is_open():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if not opened:
			_open()
		elif convo != null:
			# Pod already open — reopen the conversation (history persists)
			convo.start_with_trigger(alter_id)

func _open() -> void:
	opened = true
	var particles := get_node_or_null("OpenParticles") as GPUParticles3D
	if particles:
		particles.restart()
	# Alter materializes outside the pod — fade in from invisible
	var alter := get_node_or_null(alter_root_path) as Node3D
	if alter:
		alter.visible = true
		var ap := _find_anim_player(alter)
		if ap and ap.has_animation("Idle"):
			ap.play("Idle")
		# Materialize: drop in from slightly above
		var origin_y := alter.position.y
		alter.position.y = origin_y + 1.5
		var tw := create_tween()
		tw.tween_property(alter, "position:y", origin_y, 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var iarea: Area3D = alter.get_node_or_null("InteractionArea")
		if iarea:
			iarea.monitoring = true
			iarea.monitorable = true
	# Pod boşalsın — silüeti gizle
	var shell := get_node_or_null(pod_shell_path) as Node3D
	if shell:
		_debug_meshes(shell)
		var human := _find_human_mesh(shell)
		if human:
			human.visible = false
		else:
			print("[pod] human mesh not found in shell: ", pod_shell_path)
	# Mark unlock in GameState
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs and gs.has_method("unlock_alter"):
		gs.unlock_alter(alter_id)
	# Open conversation right away
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo and not convo.is_open():
		convo.start_with_trigger(alter_id)

func _play_pod_animation() -> void:
	var shell := get_node_or_null(pod_shell_path) as Node3D
	if shell == null:
		return
	# scifi_lab.glb ships an AnimationPlayer at its root level with a
	# single "Scene" track (8.33s). Find it and play it once.
	var ap := _find_anim_player(shell)
	if ap and ap.has_animation("Scene"):
		ap.play("Scene")

func _debug_meshes(n: Node, depth: int = 0) -> void:
	if n is MeshInstance3D:
		print("[pod] mesh: ", "  ".repeat(depth), n.name)
	for c in n.get_children():
		_debug_meshes(c, depth + 1)

func _find_human_mesh(n: Node) -> Node:
	if n is MeshInstance3D and "Human" in n.name:
		return n
	for c in n.get_children():
		var found := _find_human_mesh(c)
		if found:
			return found
	return null

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null
