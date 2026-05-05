extends Area3D

@export var alter_id: String = ""
var bubble: Label3D

func _ready() -> void:
	add_to_group("alters")
	body_entered.connect(_on_body_entered)
	_create_bubble()

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs and gs.has_method("record_action"):
		gs.record_action("approached_" + alter_id)
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo == null or convo.is_open():
		return
	convo.start_with_trigger(alter_id)

func _create_bubble() -> void:
	# Speech bubble lives on the alter ROOT (parent of this Area3D),
	# so it tracks the visible mesh, not the trigger volume.
	var alter_root := get_parent()
	if alter_root == null:
		return
	bubble = Label3D.new()
	bubble.name = "Bubble"
	bubble.position = Vector3(0, 1.8, 0)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.font_size = 32
	bubble.outline_size = 10
	bubble.outline_modulate = Color(0, 0, 0, 0.9)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.width = 600
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var col := _alter_color()
	bubble.modulate = Color(col.r, col.g, col.b, 0.0)
	bubble.visible = false
	alter_root.add_child.call_deferred(bubble)

func show_bubble(text: String) -> void:
	if bubble == null:
		return
	bubble.text = text
	bubble.visible = true
	var col := _alter_color()
	bubble.modulate = Color(col.r, col.g, col.b, 0.0)
	var tw := create_tween()
	tw.tween_property(bubble, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.5)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.7)
	tw.tween_callback(_on_bubble_hidden)

func _on_bubble_hidden() -> void:
	if bubble:
		bubble.visible = false

func _alter_color() -> Color:
	match alter_id:
		"red":
			return Color(1.0, 0.55, 0.55)
		"blue":
			return Color(0.55, 0.7, 1.0)
		"green":
			return Color(0.55, 0.9, 0.6)
		_:
			return Color(0.95, 0.95, 0.95)
