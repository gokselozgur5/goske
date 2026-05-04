extends Area3D

# Intro pod. Player walks up, presses E/Space, the pod opens, the alter
# inside rises and "wakes". Manifesto: the player chooses how many alters
# to wake; the choice can't be reversed.

@export var alter_id: String = ""
@export var lid_path: NodePath
@export var alter_root_path: NodePath

var opened: bool = false
var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# While closed: alter hidden, lying down, interaction off
	var alter := get_node_or_null(alter_root_path) as Node3D
	if alter:
		alter.visible = false
		# Lying down (90deg around X — sleeping pose)
		alter.rotation_degrees = Vector3(90, alter.rotation_degrees.y, 0)
		var iarea: Area3D = alter.get_node_or_null("InteractionArea")
		if iarea:
			iarea.monitoring = false
			iarea.monitorable = false

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
	if event.is_action_pressed("ui_accept"):
		if not opened:
			_open()
		elif convo != null:
			# Pod already open — reopen the conversation (history persists)
			convo.start_with_trigger(alter_id)

func _open() -> void:
	opened = true
	# Lid slides up — cubic ease-out: fast then settles
	var lid := get_node_or_null(lid_path) as Node3D
	if lid:
		var tw := create_tween()
		tw.tween_property(lid, "position:y", lid.position.y + 2.6, 0.85) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Alter visible, stand up — back ease (slight overshoot, cinematic)
	var alter := get_node_or_null(alter_root_path) as Node3D
	if alter:
		alter.visible = true
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(alter, "rotation_degrees:x", 0.0, 0.9) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var iarea: Area3D = alter.get_node_or_null("InteractionArea")
		if iarea:
			iarea.monitoring = true
			iarea.monitorable = true
	# Mark unlock in GameState
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs and gs.has_method("unlock_alter"):
		gs.unlock_alter(alter_id)
	# Open conversation right away with the freshly-woken alter
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo and not convo.is_open():
		convo.start_with_trigger(alter_id)
