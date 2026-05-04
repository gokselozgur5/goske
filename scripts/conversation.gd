extends Control

# Conversation UI + Game Master integration.
# One API call per turn, GM dispatches multi-speaker response.

const FALLBACK_GREETING := "..."

@onready var history_label: RichTextLabel = $Panel/Margin/VBox/HistoryScroll/History
@onready var input_line: LineEdit = $Panel/Margin/VBox/InputLine
@onready var trust_red: Label = $Panel/Margin/VBox/TrustBar/TrustRed
@onready var trust_blue: Label = $Panel/Margin/VBox/TrustBar/TrustBlue
@onready var trust_green: Label = $Panel/Margin/VBox/TrustBar/TrustGreen

var participants: Array[String] = []
# history entry: {role, content, alter_id}
var history: Array = []
var greeted_alters: Array[String] = []

func _ready() -> void:
	add_to_group("conversation_ui")
	hide()
	input_line.text_submitted.connect(_on_user_submit)
	call_deferred("_connect_state_signals")

func _connect_state_signals() -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		if not gs.trust_changed.is_connected(_on_trust_changed):
			gs.trust_changed.connect(_on_trust_changed)
		if not gs.alter_silenced.is_connected(_on_alter_silenced):
			gs.alter_silenced.connect(_on_alter_silenced)
		if not gs.exhaustion_changed.is_connected(_on_exhaustion_changed):
			gs.exhaustion_changed.connect(_on_exhaustion_changed)
	_refresh_all_trust_labels()
	_refresh_exhaustion_label()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return visible

# Called when a pod opens
func start_with_trigger(triggering_alter_id: String) -> void:
	# If conversation already open, just merge new alters as participants.
	if not visible:
		_open_ui()
	var all_alters := get_tree().get_nodes_in_group("alters")
	var gs := get_tree().get_first_node_in_group("game_state")
	var ordered_ids: Array[String] = []
	if gs == null or (gs.is_unlocked(triggering_alter_id) and not gs.is_silenced(triggering_alter_id)):
		ordered_ids.append(triggering_alter_id)
	for a in all_alters:
		if a.alter_id != triggering_alter_id:
			if gs == null or (gs.is_unlocked(a.alter_id) and not gs.is_silenced(a.alter_id)):
				ordered_ids.append(a.alter_id)
	for aid in ordered_ids:
		if aid in greeted_alters:
			if not aid in participants:
				participants.append(aid)
		else:
			# New alter — automatic prompt: "X just woke, only X speaks"
			_request_alter_awakening(aid)
			participants.append(aid)
			greeted_alters.append(aid)

func _request_alter_awakening(alter_id: String) -> void:
	var gm := get_node_or_null("/root/Main/GameMaster")
	if gm == null:
		_append_alter_line(alter_id, FALLBACK_GREETING)
		return
	var temp_history: Array = history.duplicate()
	temp_history.append({
		"role": "user",
		"content": "[%s alter just woke up (left the pod). ONLY %s should speak — their first line.]" % [alter_id, alter_id],
	})
	gm.request_turn(temp_history, _world_state(), _on_gm_turn)

func _on_gm_turn(turn: Dictionary, error: String) -> void:
	if not is_open():
		return
	if error != "":
		history_label.append_text("[color=#aa6666]GM error: %s[/color]\n" % error)
		return
	var speakers: Array = turn.get("speakers", [])
	var gs_for_filter := get_tree().get_first_node_in_group("game_state")
	for sp in speakers:
		var sid: String = str(sp.get("id", ""))
		var line: String = str(sp.get("line", ""))
		var trust_delta: int = int(sp.get("trust_delta", 0))
		if sid == "" or line == "":
			continue
		# Defense: drop unauthorized speakers (sealed pods or silenced alters).
		# Narrator is always allowed.
		if sid != "narrator" and gs_for_filter != null:
			if not gs_for_filter.is_unlocked(sid):
				print("[GM] dropped unauthorized speaker (locked): ", sid)
				continue
			if gs_for_filter.is_silenced(sid):
				print("[GM] dropped silenced speaker: ", sid)
				continue
		_append_alter_line(sid, line)
		if trust_delta != 0:
			_apply_trust_delta(sid, trust_delta)
	# Narration (optional) — append as narrator speaker so it persists
	var narration: String = str(turn.get("narration", "")).strip_edges()
	if narration != "":
		_append_alter_line("narrator", narration)
	# World events
	var events: Array = turn.get("world_events", [])
	var gs := get_tree().get_first_node_in_group("game_state")
	for ev in events:
		_apply_world_event(ev, gs)
	# Default exhaustion (if GM emitted no event) — +5 per speaker
	if gs and not _events_have_exhaustion(events) and speakers.size() > 0:
		gs.add_exhaustion(gs.EXHAUSTION_PER_RESPONSE * speakers.size())

func _events_have_exhaustion(events: Array) -> bool:
	for ev in events:
		if ev.get("type", "") == "exhaustion_delta":
			return true
	return false

func _apply_world_event(ev: Dictionary, gs) -> void:
	if gs == null:
		return
	var t: String = str(ev.get("type", ""))
	match t:
		"exhaustion_delta":
			var amt: int = int(ev.get("amount", 0))
			if amt != 0:
				gs.add_exhaustion(amt)
		"npc_affected":
			# NPC system not implemented yet — log
			print("[GM] npc_affected: ", ev)
		_:
			print("[GM] unknown world_event: ", ev)

func _apply_trust_delta(alter_id: String, delta: int) -> void:
	if delta == 0:
		return
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		gs.adjust_trust(alter_id, delta)

func close() -> void:
	hide()
	participants.clear()

func _open_ui() -> void:
	history_label.clear()
	for entry in history:
		var aid: String = entry.get("alter_id", "")
		var raw_content: String = str(entry["content"])
		var line_only: String = raw_content
		var idx := raw_content.find("]: ")
		if idx != -1:
			line_only = raw_content.substr(idx + 3)
		if aid == "":
			history_label.append_text("[color=#dddddd][b]you:[/b] %s[/color]\n" % raw_content)
		elif aid == "narrator":
			history_label.append_text("[color=#d4c5a0][i]%s[/i][/color]\n" % line_only)
		else:
			var color := _color_for_alter(aid)
			history_label.append_text("[color=%s][b]%s:[/b] %s[/color]\n" % [color, aid, line_only])
	show()
	input_line.grab_focus()

func _on_user_submit(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return
	input_line.clear()
	if trimmed == "/reset":
		_reset_conversation()
		return
	if participants.is_empty():
		return
	_append_user_line(trimmed)
	var gm := get_node_or_null("/root/Main/GameMaster")
	if gm == null:
		return
	gm.request_turn(history, _world_state(), _on_gm_turn)

func _world_state() -> Dictionary:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return {}
	return {
		"trust": gs.alter_trust,
		"exhaustion": gs.exhaustion,
		"unlocked_alters": gs.unlocked_alters,
		"silenced_alters": gs.silenced_alters,
		"comfort_exits": gs.comfort_exits,
		"play_seconds": gs.play_seconds(),
	}

func _reset_conversation() -> void:
	history.clear()
	greeted_alters.clear()
	history_label.clear()
	history_label.append_text("[color=#888888]— history reset —[/color]\n")
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		for aid in ["red", "blue", "green"]:
			gs.alter_trust[aid] = gs.TRUST_DEFAULT
			gs.trust_changed.emit(aid, gs.TRUST_DEFAULT)

func _on_trust_changed(_alter_id: String, new_value: int) -> void:
	_set_trust_label(_alter_id, new_value)

func _on_alter_silenced(alter_id: String) -> void:
	if visible:
		history_label.append_text("[color=#888888]— %s alter went silent, sealed back in pod —[/color]\n" % alter_id)
	participants.erase(alter_id)

func _on_exhaustion_changed(_new_value: int) -> void:
	_refresh_exhaustion_label()

func _refresh_exhaustion_label() -> void:
	var ex_label: Label = get_node_or_null("/root/Main/UI/ExhaustionLabel")
	if ex_label == null:
		return
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return
	ex_label.text = "exhaustion %d/100" % gs.exhaustion
	var t: float = float(gs.exhaustion) / 100.0
	ex_label.add_theme_color_override("font_color", Color(0.4 + t * 0.6, 0.7 - t * 0.4, 0.4 - t * 0.3, 1.0))

func _refresh_all_trust_labels() -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return
	for aid in ["red", "blue", "green"]:
		_set_trust_label(aid, gs.get_trust(aid))

func _set_trust_label(alter_id: String, value: int) -> void:
	match alter_id:
		"red":
			if trust_red:
				trust_red.text = "red %d" % value
		"blue":
			if trust_blue:
				trust_blue.text = "blue %d" % value
		"green":
			if trust_green:
				trust_green.text = "green %d" % value

func _append_user_line(t: String) -> void:
	history.append({"role": "user", "content": t, "alter_id": ""})
	history_label.append_text("[color=#dddddd][b]you:[/b] %s[/color]\n" % t)

func _append_alter_line(alter_id: String, t: String) -> void:
	if alter_id == "narrator":
		var nar_content := "[narrator]: %s" % t
		history.append({"role": "user", "content": nar_content, "alter_id": alter_id})
		history_label.append_text("[color=#d4c5a0][i]%s[/i][/color]\n" % t)
		return
	var content := "[%s alter]: %s" % [alter_id, t]
	history.append({"role": "user", "content": content, "alter_id": alter_id})
	var color := _color_for_alter(alter_id)
	history_label.append_text("[color=%s][b]%s:[/b] %s[/color]\n" % [color, alter_id, t])

func _color_for_alter(id: String) -> String:
	match id:
		"red": return "#ff6666"
		"blue": return "#6699ff"
		"green": return "#66cc77"
		_: return "#cccccc"
