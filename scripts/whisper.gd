extends Control

# One-way "whisper" UI — a single line bleeds through from a neighbor.
# Goske can't reply. The line fades in, holds, fades out. Per-NPC
# once-per-run (NPC tracks its own whisper_used flag).

@onready var label: Label = $Center/Label

const FADE_IN := 0.5
const HOLD_TIME := 6.0
const FADE_OUT := 1.5

func _ready() -> void:
	add_to_group("whisper_ui")
	hide()
	modulate.a = 0.0
	# Listen to NPC requests
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.has_signal("whisper_requested") and not n.whisper_requested.is_connected(_on_whisper_requested):
			n.whisper_requested.connect(_on_whisper_requested)

func _on_whisper_requested(npc_id: String) -> void:
	# A whisper is rare novelty — drains monotony noticeably
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		gs.adjust_monotony(gs.MONOTONY_PER_WHISPER)
	var gm := get_node_or_null("/root/Main/GameMaster")
	if gm == null:
		_show_text("...")
		return
	# One-shot prompt — GM produces a single short line, NPC's voice,
	# second-person, no dialogue affordance after.
	var prompt := "[The player approached %s and chose to listen. Generate ONE short whisper from %s — second-person, atmospheric, like a single line bleeding through glass. The neighbor speaks once. Goske does not reply.\n\nReturn ONLY the whisper text, no JSON, no quotation marks, no preamble. One sentence, max two.]" % [npc_id, npc_id]
	# Direct call bypassing the speakers schema — we want raw text.
	# Reuse request_turn but ignore JSON structure on parse fail.
	gm.request_turn([{"role": "user", "content": prompt}], _world_state(), _on_gm_response.bind(npc_id))

func _on_gm_response(turn: Dictionary, error: String, _npc_id: String) -> void:
	# The GM may try to honor JSON. If a speaker line came through, use
	# its content (any speaker; whisper is one-line). Otherwise show "...".
	var line := ""
	if error == "" and turn.has("speakers"):
		var speakers: Array = turn.get("speakers", [])
		if speakers.size() > 0 and speakers[0].has("line"):
			line = str(speakers[0]["line"]).strip_edges()
	if line == "":
		line = str(turn.get("narration", "")).strip_edges()
	if line == "":
		line = "..."
	_show_text(line)

func _world_state() -> Dictionary:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return {}
	return {
		"trust": gs.alter_trust,
		"exhaustion": gs.exhaustion,
		"days_alone": gs.days_alone,
		"mystery_phase": gs.mystery_phase,
		"npc_intensity": gs.npc_intensity,
	}

func _show_text(t: String) -> void:
	label.text = t
	show()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, FADE_IN)
	tw.tween_interval(HOLD_TIME)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(hide)
