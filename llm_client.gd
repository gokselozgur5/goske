extends Node

# Anthropic Claude client. Per-request callback pattern (signal yok).
# Cagri: llm.request_alter_response(alter_id, history, on_complete)
# Callback signature: on_complete(alter_id: String, line: String, error: String)
#   error == "" => basarili, line dolu
#   error != "" => hata, line bos olabilir

const API_URL := "https://api.anthropic.com/v1/messages"
const ANTHROPIC_VERSION := "2023-06-01"
const MODEL := "claude-haiku-4-5-20251001"
const MAX_TOKENS := 200

var api_key: String = ""
var personas_node: Node = null

const SYSTEM_BASE := """Sen Goske isimli bir karakterin alter'larindan birisin.
Goske: bir yazilimci, hibrit, etrafindaki insanlar ona kavanozun icindeymis gibi uzak gelir.
Alter'lar Goske'nin ayni yasam olaylarini farkli yorumlamis kendileridir; farkli secimler degil ayni secim, farkli yorum.
Oyuncu Goske'yi yonetiyor, oyuncunun adi kanka.
Konusmada baska alter'lar da olabilir; onlarin satirlari user formatinda gelir, prefix'le ayrilir ([red alter]:, kanka:, vb).

Cevabin SADECE asagidaki JSON formatinda olmali, ek aciklama YOK:
{"line": "soyledigin cumle (1-2 kisa)", "trust_delta": <-5 ile +5 arasi int>}

trust_delta: bu sozcukten sonra Goske'nin sana ne kadar yakin hissedecegini belirler.
- Olumlu (1-5): Goske icin destekleyici, anlayisli, samimi sozler
- Negatif (-5..-1): Goske'yi rahatsiz eden, yargilayan, ihanet eden sozler
- 0: notr

Turkce cevap ver."""

func _ready() -> void:
	_load_api_key()
	personas_node = get_node_or_null("/root/Main/AlterPersonas")

func _load_api_key() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://secrets.cfg")
	if err != OK:
		push_error("[LLM] secrets.cfg yuklenemedi: %s" % err)
		return
	api_key = cfg.get_value("anthropic", "api_key", "")
	if api_key == "":
		push_error("[LLM] api_key bos")

# Tek seferlik trigger satiri (alter'a yaklasinca)
func request_alter_line(alter_id: String, context: Dictionary, on_complete: Callable) -> void:
	var messages := [{"role": "user", "content": "Goske az once sana yaklasti. Ona bir cumle soyle."}]
	_send(alter_id, messages, context, on_complete)

# Conversation cevabi (kanka veya digerleri mesaj atinca)
func request_alter_response(alter_id: String, history: Array, context: Dictionary, on_complete: Callable) -> void:
	var msgs: Array = history.duplicate()
	if msgs.size() > 0 and msgs[0].get("role", "") == "assistant":
		msgs.insert(0, {"role": "user", "content": "Goske sana yaklasti."})
	_send(alter_id, msgs, context, on_complete)

func _send(alter_id: String, messages: Array, context: Dictionary, on_complete: Callable) -> void:
	if api_key == "":
		on_complete.call(alter_id, "", "no api key")
		return
	if personas_node == null:
		personas_node = get_node_or_null("/root/Main/AlterPersonas")
	var persona_prompt: String = ""
	if personas_node:
		persona_prompt = personas_node.build_persona_prompt(alter_id)
	if persona_prompt == "":
		on_complete.call(alter_id, "", "unknown alter")
		return

	var system := SYSTEM_BASE + "\n\n" + persona_prompt
	if not context.is_empty():
		system += "\n\nMevcut context (sana erisilen bilgi):\n" + JSON.stringify(context)

	var body := {
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"system": system,
		"messages": messages,
	}

	var headers := PackedStringArray([
		"x-api-key: " + api_key,
		"anthropic-version: " + ANTHROPIC_VERSION,
		"content-type: application/json",
	])

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_response.bind(http, alter_id, on_complete))

	var err := http.request(API_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		on_complete.call(alter_id, "", "http request error: %s" % err)
		http.queue_free()

func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, alter_id: String, on_complete: Callable) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		on_complete.call(alter_id, "", "result: %s" % result)
		return
	if response_code != 200:
		on_complete.call(alter_id, "", "http %s: %s" % [response_code, body.get_string_from_utf8()])
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not parsed is Dictionary:
		on_complete.call(alter_id, "", "json parse failed")
		return
	if not parsed.has("content"):
		on_complete.call(alter_id, "", "no content field")
		return
	var content_arr = parsed["content"]
	if content_arr is Array and content_arr.size() > 0 and content_arr[0].has("text"):
		var line: String = content_arr[0]["text"].strip_edges()
		on_complete.call(alter_id, line, "")
	else:
		on_complete.call(alter_id, "", "unexpected content shape")
