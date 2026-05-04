extends Node

# Game Master: handles all characters (alters + future NPCs) through a single
# LLM call. FRP/DM pattern - dramatic director, decides who speaks each turn,
# what happens in the world. Manifesto: "AI must be structural, not cosmetic".
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

const SYSTEM_BASE := """You are the GAME MASTER of Goske, a narrative game. Like a tabletop DM: you play all characters, you run the world, you decide who speaks and when as a dramatic director.

GAME: Goske is a software developer, hybrid, the people around him feel as if they are inside a jar while he watches from the outside. Inside him are alters (different interpretations of the same self). Outside there are people (NPCs). Theme: alienation.

PLAYER: writes freely as Goske. You interpret their input.

RULES:
- You decide which character(s) speak each turn. Not all of them must speak. One alter may stay silent, only the narrator may speak, etc. Pick what is meaningful.
- Silenced characters NEVER speak.
- trust_delta per speaker, integer in -5..+5 range.
- world_events: exhaustion_delta (int), npc_affected (intensity 0..1).
- Use the "narrator" character like the BG3 Narrator: scene atmosphere, Goske's inner state, environment, an alter's unspoken reaction. Often one short narrator line per turn, sometimes none, sometimes only the narrator (when atmosphere matters more than speech).
- Don't make everyone talk every turn. Manifesto: density > volume.

OUTPUT: ONLY valid JSON, nothing else (no preamble, no markdown fences):

{
  "speakers": [
    {"id": "<character_id>", "line": "<their words>", "trust_delta": <int>}
  ],
  "world_events": [
    {"type": "exhaustion_delta", "amount": <int>},
    {"type": "npc_affected", "npc_id": "<id>", "intensity": <float>}
  ],
  "narration": "<optional scene note, may be empty string>"
}

Write in English. Avoid conventional RP filler. Manifesto: 'controlled ambiguity is a tool, not a flaw'."""

func _ready() -> void:
	_load_api_key()
	personas_node = get_node_or_null("/root/Main/AlterPersonas")

func _load_api_key() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://secrets.cfg")
	if err != OK:
		push_error("[GM] secrets.cfg failed to load: %s" % err)
		return
	api_key = cfg.get_value("anthropic", "api_key", "")
	if api_key == "":
		push_error("[GM] api_key empty")

func request_turn(history: Array, world_state: Dictionary, on_complete: Callable) -> void:
	if api_key == "":
		on_complete.call({}, "no api key")
		return
	if personas_node == null:
		personas_node = get_node_or_null("/root/Main/AlterPersonas")

	var system := _build_system_prompt(world_state)
	# Anthropic API only accepts {role, content}; strip extra fields
	var msgs: Array = []
	for entry in history:
		msgs.append({
			"role": str(entry.get("role", "user")),
			"content": str(entry.get("content", "")),
		})
	if msgs.is_empty() or msgs[0].get("role", "") != "user":
		msgs.insert(0, {"role": "user", "content": "[the game begins]"})

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

	parts.append("\n--- CHARACTERS ---")
	if personas_node:
		for aid in personas_node.PERSONAS.keys():
			var c: Dictionary = personas_node.PERSONAS[aid]
			parts.append("\n[id: %s] %s — %s" % [aid, c.get("name", aid), c.get("core", "")])
			parts.append("  Traits: %s" % ", ".join(_to_packed(c.get("traits", []))))
			parts.append("  Never: %s" % ", ".join(_to_packed(c.get("forbidden", []))))
			parts.append("  Voice: %s" % c.get("voice", ""))
			var examples: Array = c.get("examples", [])
			if examples.size() > 0:
				parts.append("  Sample line: \"%s\"" % str(examples[0]))

	if not world_state.is_empty():
		parts.append("\n--- WORLD STATE ---")
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
