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
const MAX_TOKENS := 2500

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
- You decide who speaks. Skipping an alter is a valid dramatic choice — silence speaks. If a participant is conspicuously absent for a few turns and the player notices, the narrator may briefly account for it ("red has been quiet").
- Narrator optional per turn.
- Manifesto: density > volume — keep each line short (1-2 sentences), don't pad.

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

Write in English. Avoid conventional RP filler. Manifesto: 'controlled ambiguity is a tool, not a flaw'.

--- WORLD FACTS (canon, don't contradict) ---

The room contains exactly THIRTEEN pods. Three of them — red, blue, green — can be opened by Goske; their occupants are alters Goske can converse with. The other TEN pods are sealed/silent/empty: their lids do not open, no alter inside speaks. Their condition is for the player to wonder about, not to resolve. Don't invent a different count.

Beyond the pod room, three NEIGHBORS exist at the edge of Goske's world: neighbor_1, neighbor_2, neighbor_3. They are not characters Goske meets directly — they are the people on the other side of the jar's glass. They have NO spoken dialogue (don't put them in the speakers array). The alters/narrator may reference them obliquely ("the woman in 5B", "the man across the hall", "the one who used to wave"). The only way they enter mechanics is via the npc_affected world_event: emit it with intensity 0..1 to visually drain a neighbor toward gray (Dragonrot infection). Use sparingly, only when exhaustion/alter dynamics genuinely propagate outward. Don't invent NPC ids beyond neighbor_1/2/3.

Goske has a small alone-zone (a worn carpet at the room's center). Standing on it and pressing space, Goske spends a DAY ALONE: exhaustion clears, but `days_alone` advances. As days_alone grows: alters may have drifted (their voices feel more distant or more rehearsed), neighbors may have moved further away (a good moment for npc_affected drift), the room may feel staler. Color the dialog by this counter rather than ignoring it.

--- MYSTERY THREAD (always present, never resolved) ---

Two questions are woven into every interaction. Don't state them outright; let them seep in.

SURFACE QUESTION (visible from the start):
"Who put me in this pod? What is this place? Are these clones — these alters — real, or am I imagining them?"
The player can engage with this directly. Alters can speculate, contradict each other, withhold.

DEEPER QUESTION (emerges gradually, mid-late turns):
"Why is there glass between me and other people? Did I put it there? Has it always been there? Can it be broken?"
This is the jar — Goske's lived alienation. Don't name "the jar" too early. Let alters circle it: notice Goske's distance, comment on isolation patterns, ask who he hasn't called, who passed him on the street unrecognized.

THE TWO LAYERS CONNECT: the pod is the literal of the jar. Realizing this is part of the arc.

PACING:
- Early turns (player just woke): alters speculate about the pod, ask what Goske remembers
- Mid turns: alters probe relationships, missed contacts, recurring distances
- Late turns: the jar emerges — first as metaphor an alter slips, then as recognition
- Never resolve. The thread is to be lived with. Resolution happens at the ending, not in dialogue."""

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

	# Only unlocked (pod opened) + narrator are listed. Sealed alters
	# are kept hidden from the GM so it can't impersonate them.
	var unlocked: Array = world_state.get("unlocked_alters", [])
	var silenced: Array = world_state.get("silenced_alters", [])

	parts.append("\n--- CHARACTERS (active roster) ---")
	if personas_node:
		for aid in personas_node.PERSONAS.keys():
			# Always include narrator. Otherwise: must be unlocked, not silenced.
			if aid != "narrator":
				if not (aid in unlocked):
					continue
				if aid in silenced:
					continue
			var c: Dictionary = personas_node.PERSONAS[aid]
			parts.append("\n[id: %s] %s — %s" % [aid, c.get("name", aid), c.get("core", "")])
			parts.append("  Traits: %s" % ", ".join(_to_packed(c.get("traits", []))))
			parts.append("  Never: %s" % ", ".join(_to_packed(c.get("forbidden", []))))
			parts.append("  Voice: %s" % c.get("voice", ""))
			var examples: Array = c.get("examples", [])
			if examples.size() > 0:
				parts.append("  Sample line: \"%s\"" % str(examples[0]))

	# Strict allowlist
	var active_ids := PackedStringArray(["narrator"])
	for aid in unlocked:
		if not (aid in silenced):
			active_ids.append(str(aid))
	parts.append("\n--- ACTIVE SPEAKER ALLOWLIST ---")
	parts.append("ONLY these IDs may appear in the speakers array: " + ", ".join(active_ids))
	parts.append("Any other ID is FORBIDDEN. Sealed pods stay sealed; their occupants do not speak. Silenced alters do not speak.")

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
