extends WorldEnvironment

# Drives the global saturation post-process from GameState.monotony.
# Monotony 0.0 → fully colored world. 1.0 → grayscale (Camus's room).

func _ready() -> void:
	if environment:
		environment.adjustment_enabled = true
	# GameState may not be ready on the same frame; defer.
	call_deferred("_hook")

func _hook() -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return
	if not gs.monotony_changed.is_connected(_on_monotony_changed):
		gs.monotony_changed.connect(_on_monotony_changed)
	_on_monotony_changed(gs.monotony)

func _on_monotony_changed(value: float) -> void:
	if environment == null:
		return
	# Linear: monotony 0 → saturation 1.0, monotony 1 → saturation 0.0
	environment.adjustment_saturation = 1.0 - value
