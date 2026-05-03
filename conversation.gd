extends Control

# Multi-alter conversation. Bir alter trigger ettiginde tum alter'lar
# katilir (manifesto: alter'lar zihindeki sesler). Cikis sadece ESC.

const FALLBACK_LINES := {
	"red": "Soylemen gerekeni soylemiyorsun. Ben soyleyebilirim.",
	"blue": "Bu durumda mantikli cikis zaten belli. Duygusal davranma.",
	"green": "Belki herkes iyi niyetlidir. Gormek istemedigin yer orasi.",
}

@onready var history_label: RichTextLabel = $Panel/Margin/VBox/HistoryScroll/History
@onready var input_line: LineEdit = $Panel/Margin/VBox/InputLine
@onready var trust_red: Label = $Panel/Margin/VBox/TrustBar/TrustRed
@onready var trust_blue: Label = $Panel/Margin/VBox/TrustBar/TrustBlue
@onready var trust_green: Label = $Panel/Margin/VBox/TrustBar/TrustGreen

var participants: Array[String] = []
# history entry: {"role": "user|assistant", "content": "...", "alter_id": ""}
var history: Array = []
# Daha once initial line atan alter'lar - aciliylikta tekrar atmasin
var greeted_alters: Array[String] = []

func _ready() -> void:
	add_to_group("conversation_ui")
	hide()
	input_line.text_submitted.connect(_on_user_submit)
	# Trust state degisikligini dinle
	call_deferred("_connect_trust_signal")

func _connect_trust_signal() -> void:
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

func _on_exhaustion_changed(new_value: int) -> void:
	_refresh_exhaustion_label()

func _refresh_exhaustion_label() -> void:
	var ex_label: Label = get_node_or_null("/root/Main/UI/ExhaustionLabel")
	if ex_label == null:
		return
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return
	ex_label.text = "tukenis %d/100" % gs.exhaustion
	# Renk degisimi: dusuk yesilimsi, yuksek kirmizimsi
	var t: float = float(gs.exhaustion) / 100.0
	ex_label.add_theme_color_override("font_color", Color(0.4 + t * 0.6, 0.7 - t * 0.4, 0.4 - t * 0.3, 1.0))

func _on_alter_silenced(alter_id: String) -> void:
	# Konusma history'sine bildirim, participants'tan cikar
	if visible:
		history_label.append_text("[color=#888888]— %s alter sessizlesti, kapsule geri kapandi —[/color]\n" % alter_id)
	participants.erase(alter_id)

func _on_trust_changed(alter_id: String, new_value: int) -> void:
	_set_trust_label(alter_id, new_value)

func _refresh_all_trust_labels() -> void:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs == null:
		return
	for aid in ["red", "blue", "green"]:
		_set_trust_label(aid, gs.get_trust(aid))

func _set_trust_label(alter_id: String, value: int) -> void:
	match alter_id:
		"red": if trust_red: trust_red.text = "red %d" % value
		"blue": if trust_blue: trust_blue.text = "blue %d" % value
		"green": if trust_green: trust_green.text = "green %d" % value

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return visible

# Bir alter trigger eder, tum alter'lar conversation'a katilir
func start_with_trigger(triggering_alter_id: String) -> void:
	if visible:
		return
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
	var llm := get_node_or_null("/root/Main/LLMClient")
	for aid in ordered_ids:
		if aid in greeted_alters:
			# Zaten konusmus, sadece participant olarak restore
			if not aid in participants:
				participants.append(aid)
		else:
			# Yeni alter, ilk satirini iste
			_request_initial(aid, llm)

func _request_initial(alter_id: String, llm) -> void:
	if llm == null:
		_add_participant_with_initial(alter_id, FALLBACK_LINES.get(alter_id, "..."))
		return
	var ctx := _context_for(alter_id)
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		gs.record_alter_engagement(alter_id)
	llm.request_alter_line(alter_id, ctx, _on_initial_response)

func _on_initial_response(alter_id: String, raw: String, error: String) -> void:
	if not is_open():
		return
	if error != "" or raw == "":
		_add_participant_with_initial(alter_id, FALLBACK_LINES.get(alter_id, "..."))
		return
	var parsed := _parse_alter_response(raw)
	_add_participant_with_initial(alter_id, parsed["line"])
	_apply_trust_delta(alter_id, parsed["trust_delta"])

func _add_participant_with_initial(alter_id: String, initial_line: String) -> void:
	if alter_id in participants:
		return
	participants.append(alter_id)
	if not alter_id in greeted_alters:
		greeted_alters.append(alter_id)
	_append_alter_line(alter_id, initial_line)

func _open_ui() -> void:
	# History korunur — label'i tazele
	history_label.clear()
	for entry in history:
		var aid: String = entry.get("alter_id", "")
		if aid == "":
			history_label.append_text("[color=#dddddd][b]kanka:[/b] %s[/color]\n" % entry["content"])
		else:
			var color := _color_for_alter(aid)
			history_label.append_text("[color=%s][b]%s:[/b] %s[/color]\n" % [color, aid, entry["content"]])
	show()
	input_line.grab_focus()

func close() -> void:
	hide()
	participants.clear()
	# history korunur — alter'lar bir sonraki acilista hatirlasin

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
	var llm := get_node_or_null("/root/Main/LLMClient")
	if llm == null:
		return
	var gs := get_tree().get_first_node_in_group("game_state")
	for alter_id in participants:
		if gs and gs.is_silenced(alter_id):
			continue
		var hist := _build_history_for(alter_id)
		var ctx := _context_for(alter_id)
		llm.request_alter_response(alter_id, hist, ctx, _on_alter_response)

func _reset_conversation() -> void:
	history.clear()
	greeted_alters.clear()
	history_label.clear()
	history_label.append_text("[color=#888888]— history sifirlandi —[/color]\n")
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		for aid in ["red", "blue", "green"]:
			gs.alter_trust[aid] = gs.TRUST_DEFAULT
			gs.trust_changed.emit(aid, gs.TRUST_DEFAULT)

func _on_alter_response(alter_id: String, raw: String, error: String) -> void:
	if not is_open():
		return
	if error != "":
		_append_alter_line(alter_id, "(hata: %s)" % error)
		return
	var parsed := _parse_alter_response(raw)
	_append_alter_line(alter_id, parsed["line"])
	_apply_trust_delta(alter_id, parsed["trust_delta"])
	# Tukenis ekonomisi: her alter cevabi tukenisi artirir
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		gs.add_exhaustion(gs.EXHAUSTION_PER_RESPONSE)

func _parse_alter_response(raw: String) -> Dictionary:
	# LLM bazen JSON'i markdown code block icine sariyor; temizle
	var cleaned := raw.strip_edges()
	if cleaned.begins_with("```"):
		var first_newline := cleaned.find("\n")
		if first_newline != -1:
			cleaned = cleaned.substr(first_newline + 1)
		if cleaned.ends_with("```"):
			cleaned = cleaned.substr(0, cleaned.length() - 3)
		cleaned = cleaned.strip_edges()
	var parsed = JSON.parse_string(cleaned)
	if parsed is Dictionary and parsed.has("line"):
		return {
			"line": str(parsed.get("line", raw)),
			"trust_delta": int(parsed.get("trust_delta", 0)),
		}
	return {"line": raw, "trust_delta": 0}

func _apply_trust_delta(alter_id: String, delta: int) -> void:
	if delta == 0:
		return
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		gs.adjust_trust(alter_id, delta)

func _build_history_for(alter_id: String) -> Array:
	var msgs: Array = []
	var pending: Array = []
	for entry in history:
		var entry_alter: String = entry.get("alter_id", "")
		if entry_alter == alter_id:
			if pending.size() > 0:
				msgs.append({"role": "user", "content": _join(pending, "\n")})
				pending = []
			msgs.append({"role": "assistant", "content": entry["content"]})
		else:
			var prefix := ""
			if entry_alter == "":
				prefix = "kanka: "
			else:
				prefix = "[%s alter]: " % entry_alter
			pending.append(prefix + entry["content"])
	if pending.size() > 0:
		msgs.append({"role": "user", "content": _join(pending, "\n")})
	return msgs

func _join(arr: Array, sep: String) -> String:
	var out := ""
	for i in range(arr.size()):
		if i > 0:
			out += sep
		out += str(arr[i])
	return out

func _append_user_line(t: String) -> void:
	history.append({"role": "user", "content": t, "alter_id": ""})
	history_label.append_text("[color=#dddddd][b]kanka:[/b] %s[/color]\n" % t)

func _append_alter_line(alter_id: String, t: String) -> void:
	history.append({"role": "assistant", "content": t, "alter_id": alter_id})
	var color := _color_for_alter(alter_id)
	history_label.append_text("[color=%s][b]%s:[/b] %s[/color]\n" % [color, alter_id, t])

func _context_for(alter_id: String) -> Dictionary:
	var gs := get_tree().get_first_node_in_group("game_state")
	if gs:
		return gs.context_for(alter_id)
	return {}

func _color_for_alter(id: String) -> String:
	match id:
		"red": return "#ff6666"
		"blue": return "#6699ff"
		"green": return "#66cc77"
		_: return "#cccccc"
