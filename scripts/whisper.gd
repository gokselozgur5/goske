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
	# Approach is rare novelty — drains monotony noticeably
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		gs.adjust_monotony(gs.MONOTONY_PER_WHISPER)
		gs.add_exhaustion(15)  # social damage from an unfiltered moment
	var gm := get_node_or_null("/root/Main/GameMaster")
	if gm == null:
		_show_text("...")
		return

	# Random "self-mix" — anchored to current trust trajectory, nudged by RNG.
	# This colors what falls out of Goske's mouth before they think.
	var r_anchor := 50
	var b_anchor := 50
	var g_anchor := 50
	if gs:
		r_anchor = gs.get_trust("red")
		b_anchor = gs.get_trust("blue")
		g_anchor = gs.get_trust("green")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rr: int = clamp(r_anchor + rng.randi_range(-30, 30), 0, 100)
	var bb: int = clamp(b_anchor + rng.randi_range(-30, 30), 0, 100)
	var gg: int = clamp(g_anchor + rng.randi_range(-30, 30), 0, 100)

	var prompt := """[Player approached %s. Goske's INSTANT internal mix is R=%d B=%d G=%d (random nudge from the run's trust). The dominant channel colors what Goske says BEFORE they think.

High R: angry, abrasive, the wrong thing said on purpose, blunt-funny.
High B: cold, statistical, off-putting analytical observation about the neighbor.
High G: naive, embarrassingly tender, oversharing, accidentally vulnerable.
Mixed: blend the dominant tones (angry-naive = uncomfortably honest; cold-tender = intimate but flat; etc.).

Output JSON with EXACTLY two speakers:
1. id="goske_outburst" — the unfiltered line that escapes Goske. Short (max ~15 words).
2. id="%s" — neighbor's brief reaction (frozen / softened / cold / shocked / fled). Even shorter.

trust_delta on goske_outburst can shift any of red/blue/green ±5 depending on which voice spoke through.

Optional: world_events with npc_affected if the outburst stains the neighbor.

DO NOT include suggestions in this turn — this is a single beat, not a back-and-forth.]""" % [npc_id, rr, bb, gg, npc_id]

	gm.request_turn([{"role": "user", "content": prompt}], _world_state(), _on_gm_response.bind(npc_id))

func _on_gm_response(turn: Dictionary, error: String, npc_id: String) -> void:
	if error != "":
		_show_text("...")
		return
	var speakers: Array = turn.get("speakers", [])
	if speakers.size() == 0:
		_show_text(str(turn.get("narration", "...")).strip_edges())
		return
	# Apply trust deltas + world events
	var gs := get_tree().get_first_node_in_group("game_state")
	for sp in speakers:
		var delta: int = int(sp.get("trust_delta", 0))
		var sid: String = str(sp.get("id", ""))
		if delta == 0 or gs == null:
			continue
		# goske_outburst's trust_delta is meant to shift the alter whose voice spoke through.
		# We can't tell which from the id alone, so fall back to nudging based on prompt mix:
		# the GM was told to choose deltas accordingly; apply them to all 3 alters slightly.
		# For npc reaction lines, ignore trust_delta.
		if sid == "goske_outburst":
			# Distribute the GM's intended shift across alters based on tone.
			# Simplest: apply as red delta (most outbursts are red-flavored).
			gs.adjust_trust("red", delta)
	for ev in turn.get("world_events", []):
		if ev.get("type", "") == "npc_affected":
			var nid: String = str(ev.get("npc_id", ""))
			var intensity: float = float(ev.get("intensity", 0.0))
			if nid != "" and gs:
				gs.update_npc_intensity(nid, intensity)
				for n in get_tree().get_nodes_in_group("npcs"):
					if n.has_method("set_intensity") and n.npc_id == nid:
						n.set_intensity(gs.npc_intensity.get(nid, 0.0))
						break
	# Sequential reveal: outburst first, then reaction
	_show_two_lines(speakers, npc_id)

func _show_two_lines(speakers: Array, npc_id: String) -> void:
	var outburst_line := ""
	var reaction_line := ""
	for sp in speakers:
		var sid: String = str(sp.get("id", ""))
		var line: String = str(sp.get("line", "")).strip_edges()
		if sid == "goske_outburst":
			outburst_line = line
		elif sid == npc_id:
			reaction_line = line
	if outburst_line == "" and reaction_line == "":
		_show_text("...")
		return
	# Show outburst — Goske's accidental voice
	if outburst_line != "":
		_show_text("Goske: " + outburst_line)
		await get_tree().create_timer(FADE_IN + HOLD_TIME * 0.6 + FADE_OUT).timeout
	# Show reaction
	if reaction_line != "":
		label.text = "%s: %s" % [npc_id, reaction_line]
		modulate.a = 0.0
		visible = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, FADE_IN)
		tw.tween_interval(HOLD_TIME * 0.7)
		tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
		tw.tween_callback(hide)

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
