extends Control

# Full-screen ending overlay. Triggered by /ending in conversation
# (or, later, by gameplay-driven thresholds). Shows the resolved
# ending's label + theme blurb, drawn from the Voronoi partition.

@onready var label: Label = $Center/VBox/Label
@onready var theme_label: Label = $Center/VBox/ThemeLabel
@onready var coords_label: Label = $Center/VBox/CoordsLabel
@onready var bg: ColorRect = $BG

func _ready() -> void:
	add_to_group("ending_overlay")
	hide()
	modulate.a = 0.0

func show_ending() -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return
	var e: Dictionary = gs.compute_ending()
	if e.is_empty():
		return
	label.text = str(e.get("label", ""))
	theme_label.text = str(e.get("theme", ""))
	coords_label.text = "red %d   blue %d   green %d   ·   days alone %d" % [
		gs.get_trust("red"), gs.get_trust("blue"), gs.get_trust("green"), gs.days_alone
	]
	var col: Color = e.get("color", Color(0.5, 0.5, 0.55))
	if bg:
		bg.color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 1.0)
	show()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.2)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()

func _dismiss() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(hide)
