extends Area3D

@export var alter_id: String = ""

func _ready() -> void:
	add_to_group("alters")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	var convo := get_tree().get_first_node_in_group("conversation_ui")
	if convo == null or convo.is_open():
		return
	convo.start_with_trigger(alter_id)
