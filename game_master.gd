extends Node

# Game Master: tum karakterleri (alters + NPC'ler) tek LLM call ile yonetir.
# FRP/DM mantigi - dramatic director, hangi karakter konusur, dunyada ne olur
# tek zihin karar verir. Manifesto: "AI must be structural, not cosmetic".
#
# Public API:
#   request_turn(history, world_state, on_complete)
#     on_complete(turn: Dictionary, error: String)
#     turn = {"speakers": [{id, line, trust_delta}], "world_events": [...]}

const API_URL := "https://api.anthropic.com/v1/messages"
const ANTHROPIC_VERSION := "2023-06-01"
const MODEL := "claude-haiku-4-5-20251001"
const MAX_TOKENS := 1000

var api_key: String = ""
var personas_node: Node = null

const SYSTEM_BASE := """Sen Goske oyununun GAME MASTER'isin. FRP'deki DM gibi: tum karakterleri sen oynursun, dunyayi sen yonetirsin, dramatik direktor olarak kim ne zaman konusur sen secersin.

OYUN: Goske bir yazilimci, hibrit, etrafindaki insanlar ona kavanozun icindeymis gibi uzak gelir. Iceride alter'lari (kendisi'nin baska yorumlanmis halleri) var. Disarida insanlar (NPC'ler) var. Yabancilasma teması.

OYUNCU: kanka, Goske'yi yonetir. Free text yazar, sen yorumlarsin.

KURAL:
- Her turn'de hangi karakter(ler)in konusacagina SEN karar verirsin
- Hepsinin konusmasi gerekmez. Bir alter susabilir, sadece bazilari konusabilir, vb. Anlamli sec.
- Sessizlestirilmis (silenced) karakterler ASLA konusmaz
- "narrator" karakterini BG3'teki Narrator gibi kullan: sahne atmosferi, Goske'nin ic durumu, mekan tasviri, alter'larin gorulmemis tepkileri. Her turn'de bir narrator satiri olabilir, bazen olmayabilir, bazen sadece narrator konusur (alter'lar susup sahne atmosferi onemli oldugunda).
- Asik fazla konusturma — manifesto: density > volume
- Trust deltalari her speaker icin ayri (-5 ile +5 arasi int)
- World events: exhaustion_delta (int), npc_affected (intensity 0-1)
- Cevabin SADECE asagidaki JSON formatinda, baska hicbir sey YOK:

{
  "speakers": [
    {"id": "<karakter_id>", "line": "<soyledikleri>", "trust_delta": <int>}
  ],
  "world_events": [
    {"type": "exhaustion_delta", "amount": <int>},
    {"type": "npc_affected", "npc_id": "<id>", "intensity": <float>}
  ],
  "narration": "<opsiyonel sahne notu, bos string olabilir>"
}

Turkce konus. Konvansiyonel RP cevaplari verme - manifesto: 'controlled ambiguity is a tool, not a flaw'."""

func _ready() -> void:
	_load_api_key()
	personas_node = get_node_or_null("/root/Main/AlterPersonas")

func _load_api_key() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://secrets.cfg")
	if err != OK:
		push_error("[GM] secrets.cfg yuklenemedi: %s" % err)
		return
	api_key = cfg.get_value("anthropic", "api_key", "")
	if api_key == "":
		push_error("[GM] api_key bos")

func request_turn(history: Array, world_state: Dictionary, on_complete: Callable) -> void:
	if api_key == "":
		on_complete.call({}, "no api key")
		return
	if personas_node == null:
		personas_node = get_node_or_null("/root/Main/AlterPersonas")

	var system := _build_system_prompt(world_state)
	# Anthropic API sadece role + content kabul eder; ekstra field'lari temizle
	var msgs: Array = []
	for entry in history:
		msgs.append({
			"role": str(entry.get("role", "user")),
			"content": str(entry.get("content", "")),
		})
	if msgs.is_empty() or msgs[0].get("role", "") != "user":
		msgs.insert(0, {"role": "user", "content": "[oyun basliyor]"})

	var body := {
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"system": system,
		"messages": msgs,
	}

	var headers := PackedStringArray([
		"x-api-key: " + api_key,
		"anthropic-version: " + ANTHROPIC_VERSION,
		"content-type: application/json",
	])

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_response.bind(http, on_complete))

	var err := http.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		on_complete.call({}, "http request error: %s" % err)
		http.queue_free()

func _build_system_prompt(world_state: Dictionary) -> String:
	var parts := PackedStringArray()
	parts.append(SYSTEM_BASE)

	parts.append("\n--- KARAKTERLER ---")
	if personas_node:
		for aid in personas_node.PERSONAS.keys():
			var c: Dictionary = personas_node.PERSONAS[aid]
			parts.append("\n[id: %s] %s — %s" % [aid, c.get("name", aid), c.get("core", "")])
			parts.append("  Sifatlar: %s" % ", ".join(_to_packed(c.get("traits", []))))
			parts.append("  Asla: %s" % ", ".join(_to_packed(c.get("forbidden", []))))
			parts.append("  Ses: %s" % c.get("voice", ""))
			var examples: Array = c.get("examples", [])
			if examples.size() > 0:
				parts.append("  Ornek satir: \"%s\"" % str(examples[0]))

	if not world_state.is_empty():
		parts.append("\n--- DUNYA STATE ---")
		parts.append(JSON.stringify(world_state))

	return "\n".join(parts)

func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, on_complete: Callable) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		on_complete.call({}, "result: %s" % result)
		return
	if response_code != 200:
		on_complete.call({}, "http %s: %s" % [response_code, body.get_string_from_utf8()])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed is Dictionary:
		on_complete.call({}, "json parse failed")
		return
	if not parsed.has("content"):
		on_complete.call({}, "no content field")
		return
	var content_arr = parsed["content"]
	if not (content_arr is Array and content_arr.size() > 0 and content_arr[0].has("text")):
		on_complete.call({}, "unexpected content shape")
		return
	var raw_text: String = content_arr[0]["text"].strip_edges()
	var turn := _parse_turn_json(raw_text)
	if turn.is_empty():
		on_complete.call({}, "turn json parse failed: %s" % raw_text.substr(0, 200))
		return
	on_complete.call(turn, "")

func _parse_turn_json(raw: String) -> Dictionary:
	var cleaned := raw
	if cleaned.begins_with("```"):
		var first_newline := cleaned.find("\n")
		if first_newline != -1:
			cleaned = cleaned.substr(first_newline + 1)
		if cleaned.ends_with("```"):
			cleaned = cleaned.substr(0, cleaned.length() - 3)
		cleaned = cleaned.strip_edges()
	var parsed = JSON.parse_string(cleaned)
	if parsed is Dictionary and parsed.has("speakers"):
		return parsed
	return {}

func _to_packed(arr: Array) -> PackedStringArray:
	var p := PackedStringArray()
	for item in arr:
		p.append(str(item))
	return p
