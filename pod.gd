extends Area3D

# Acilis sahnesi kapsulu. Goske yaklasir, E/Space basarsa pod acilir,
# icindeki alter dikilir ve "uyanir". Manifesto: kanka kac alter
# uyandiracagini secer, sonradan degistirilemez.

@export var alter_id: String = ""
@export var lid_path: NodePath
@export var alter_root_path: NodePath

var opened: bool = false
var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Pod kapali ise alter gizli + yatik + interaction kapali
	var alter := get_node_or_null(alter_root_path) as Node3D
	if alter:
		alter.visible = false
		# Yatik pozisyon (X ekseni etrafinda 90 derece - yatak gibi)
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
	if opened or not player_in_range:
		return
	# Conversation aciksa Space LineEdit'e gider, pod acma yapma
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo and convo.is_open():
		return
	if event.is_action_pressed("ui_accept"):
		_open()

func _open() -> void:
	opened = true
	# Lid yukari kay
	var lid := get_node_or_null(lid_path) as Node3D
	if lid:
		var tw := create_tween()
		tw.tween_property(lid, "position:y", lid.position.y + 2.5, 0.6).set_trans(Tween.TRANS_CUBIC)
	# Alter visible olsun, dikilsin
	var alter := get_node_or_null(alter_root_path) as Node3D
	if alter:
		alter.visible = true
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(alter, "rotation_degrees:x", 0.0, 0.5)
		# Interaction enable
		var iarea: Area3D = alter.get_node_or_null("InteractionArea")
		if iarea:
			iarea.monitoring = true
			iarea.monitorable = true
	# GameState'e unlock kaydet
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs and gs.has_method("unlock_alter"):
		gs.unlock_alter(alter_id)
	# Pod acilir acilmaz alter ile konusma baslat
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo and not convo.is_open():
		convo.start_with_trigger(alter_id)
