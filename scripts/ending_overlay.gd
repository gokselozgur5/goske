extends Control

# Full-screen ending overlay.
# Static label + Voronoi-resolved id ("Justified Rage", "Empty Jar", etc.)
# is decided by compute_ending(). The narration text under it is written
# by the GM on the spot, run-aware — manifesto: "no canonical run".
# Static theme from endings.gd is used as a fallback when the GM call
# fails / times out.

@onready var label: Label = $Center/VBox/Label
@onready var theme_label: Label = $Center/VBox/ThemeLabel
@onready var coords_label: Label = $Center/VBox/CoordsLabel
@onready var bg: ColorRect = $BG

const NARRATION_TIMEOUT := 12.0  # seconds before falling back to static

var _waiting: bool = false
var _ending: Dictionary = {}
var _hint_label: Label = null

func _ready() -> void:
	add_to_group("ending_overlay")
	hide()
	modulate.a = 0.0
	_build_hint_label()

func _build_hint_label() -> void:
	_hint_label = Label.new()
	_hint_label.text = "enter — play again        esc — dismiss"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.anchor_left = 0.5
	_hint_label.anchor_right = 0.5
	_hint_label.offset_top = -64
	_hint_label.offset_bottom = -32
	_hint_label.offset_left = -260
	_hint_label.offset_right = 260
	_hint_label.modulate.a = 0.0
	add_child(_hint_label)

func _show_hint() -> void:
	if _hint_label == null:
		return
	var tw := create_tween()
	tw.tween_property(_hint_label, "modulate:a", 1.0, 0.9)

func show_ending() -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return
	var e: Dictionary = gs.compute_ending()
	if e.is_empty():
		return
	_ending = e
	label.text = str(e.get("label", ""))
	# Loading state — single ellipsis until the GM responds (or timeout).
	theme_label.text = "…"
	if _hint_label:
		_hint_label.modulate.a = 0.0
	coords_label.text = "red %d   blue %d   green %d   ·   days alone %d" % [
		gs.get_trust("red"), gs.get_trust("blue"), gs.get_trust("green"), gs.days_alone
	]
	var col: Color = e.get("color", Color(0.5, 0.5, 0.55))
	if bg:
		bg.color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 1.0)
	show()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 1.2)

	# Ask the GM for a run-aware narration. Falls back to static theme on
	# timeout / error.
	_waiting = true
	_request_narration()

func _request_narration() -> void:
	var gm := get_node_or_null("/root/Main/GameMaster")
	if gm == null:
		_apply_fallback("(GM not available)")
		return
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		_apply_fallback(str(_ending.get("theme", "")))
		return

	var run_summary := _build_run_summary(gs)
	var prompt := """[ENDING TRIGGERED] Resolved ending: "%s".
Voronoi centroid (R, B, G): (%d, %d, %d).
Run state at the moment of resolution: %s

Write 2-3 SHORT sentences for the final ending narration. Literary, somber, run-specific. Don't name the centroid coordinates or the system mechanics. Reference what kanka actually did — pod choices, restless days, neighbor whispers, where the trust trajectory landed. Write in second person. No bold/markup, plain prose.

Output JSON:
{"speakers": [{"id": "narrator", "line": "<2-3 sentences>", "trust_delta": 0}], "world_events": [], "narration": ""}""" % [
		str(_ending.get("label", "")),
		int(_ending.get("centroid", Vector3.ZERO).x),
		int(_ending.get("centroid", Vector3.ZERO).y),
		int(_ending.get("centroid", Vector3.ZERO).z),
		run_summary,
	]
	gm.request_turn([{"role": "user", "content": prompt}], _world_state(gs), _on_narration)
	# Timeout fallback
	var t := get_tree().create_timer(NARRATION_TIMEOUT)
	t.timeout.connect(_on_narration_timeout)

func _build_run_summary(gs) -> String:
	var parts := PackedStringArray()
	parts.append("trust(red=%d, blue=%d, green=%d)" % [gs.get_trust("red"), gs.get_trust("blue"), gs.get_trust("green")])
	parts.append("days_alone=%d" % gs.days_alone)
	parts.append("comfort_exits=%d" % gs.comfort_exits)
	parts.append("monotony=%.2f" % gs.monotony)
	parts.append("tension=%.2f" % gs.tension)
	parts.append("mystery_phase=%s" % gs.mystery_phase)
	parts.append("unlocked_alters=%s" % str(gs.unlocked_alters))
	parts.append("silenced_alters=%s" % str(gs.silenced_alters))
	if not gs.npc_intensity.is_empty():
		parts.append("npc_intensity=%s" % str(gs.npc_intensity))
	return ", ".join(parts)

func _world_state(gs) -> Dictionary:
	return {
		"trust": gs.alter_trust,
		"exhaustion": gs.exhaustion,
		"days_alone": gs.days_alone,
		"mystery_phase": gs.mystery_phase,
		"monotony": gs.monotony,
		"tension": gs.tension,
		"unlocked_alters": gs.unlocked_alters,
		"silenced_alters": gs.silenced_alters,
		"comfort_exits": gs.comfort_exits,
		"npc_intensity": gs.npc_intensity,
	}

func _on_narration(turn: Dictionary, error: String) -> void:
	if not _waiting:
		return  # already timed out / dismissed
	_waiting = false
	if error != "":
		_apply_fallback(str(_ending.get("theme", "")))
		return
	var line := ""
	var speakers: Array = turn.get("speakers", [])
	if speakers.size() > 0:
		line = str(speakers[0].get("line", "")).strip_edges()
	if line == "":
		line = str(turn.get("narration", "")).strip_edges()
	if line == "":
		_apply_fallback(str(_ending.get("theme", "")))
		return
	theme_label.text = line
	_show_hint()

func _on_narration_timeout() -> void:
	if not _waiting:
		return
	_waiting = false
	_apply_fallback(str(_ending.get("theme", "")))

func _apply_fallback(text: String) -> void:
	if text == "" or text == null:
		text = str(_ending.get("theme", "—"))
	theme_label.text = text
	_show_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		# Enter / Space → play again. Reload to the title screen so the next
		# run starts fresh (no autoloads — scene change resets state).
		_play_again()
		get_viewport().set_input_as_handled()

func _dismiss() -> void:
	_waiting = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(hide)

func _play_again() -> void:
	_waiting = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
