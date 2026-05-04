extends Area3D

# Goske's "alone time" — staying on this zone and pressing Space
# spends a day alone. Resets exhaustion (introvert load) but advances
# days_alone, which the GM uses to color the next conversations
# (alters may drift, neighbors may have gone further away).
#
# Manifesto: trade-off — social presence costs, isolation also costs.

var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

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
		_do_rest()

func _do_rest() -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs and gs.has_method("rest"):
		gs.rest()
