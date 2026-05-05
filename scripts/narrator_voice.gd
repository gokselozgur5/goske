extends Node

# Narrator-only TTS playback. Listens for `speak(text)` calls, posts the
# stripped text to the Worker /tts endpoint, plays the returned MP3.
#
# Manifesto: only the narrator speaks aloud. Goske's inner alters
# (red/blue/green) stay text-only — the outside world is voiced, the
# inside is silent.
#
# Cancel-on-new policy: a new speak() call cancels the in-flight HTTP
# request and stops any currently-playing audio. The latest narration
# always wins.

const TTS_PATH := "/tts"

var _http: HTTPRequest = null
var _audio: AudioStreamPlayer = null
var _request_token: int = 0
var _disabled: bool = false  # set true if local-dev (no proxy) or muted

func _ready() -> void:
	add_to_group("narrator_voice")
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Master"
	_audio.volume_db = -2.0  # leave a touch of headroom
	add_child(_audio)

func speak(text: String) -> void:
	if _disabled:
		return
	var clean := text.strip_edges()
	if clean == "":
		return

	# Bump the token so any in-flight response from a previous call
	# becomes stale and is dropped on arrival.
	_request_token += 1
	var my_token := _request_token

	# Cancel current playback + any in-flight HTTP request.
	if _audio.playing:
		_audio.stop()
	if _http != null:
		_http.cancel_request()
		_http.queue_free()
		_http = null

	var tts_url := _resolve_tts_url()
	if tts_url == "":
		# No proxy configured (local dev). Silent fallback — game still works,
		# narrator is just text. Turn this on in secrets.cfg via api_url.
		_disabled = true
		return

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_response.bind(my_token))

	var headers := PackedStringArray(["content-type: application/json"])
	var body := JSON.stringify({"text": clean})
	var err := _http.request(tts_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("[narrator_voice] request failed: %s" % err)
		if _http != null:
			_http.queue_free()
			_http = null

func mute(enabled: bool) -> void:
	_disabled = enabled
	if enabled and _audio and _audio.playing:
		_audio.stop()

func is_muted() -> bool:
	return _disabled

func _resolve_tts_url() -> String:
	# Read the proxy URL from GameMaster — it already loaded secrets.cfg
	# (or set the hardcoded WEB_PROXY_URL on web builds).
	var gm := get_node_or_null("/root/Main/GameMaster")
	if gm == null:
		return ""
	if not bool(gm.via_proxy):
		return ""
	var base: String = String(gm.api_url).rstrip("/")
	if base == "":
		return ""
	return base + TTS_PATH

func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, my_token: int) -> void:
	# Stale response (a newer speak() call superseded this one).
	if my_token != _request_token:
		return
	if _http != null:
		_http.queue_free()
		_http = null
	if response_code != 200 or body.is_empty():
		var msg := body.get_string_from_utf8()
		push_warning("[narrator_voice] tts http %d: %s" % [response_code, msg.substr(0, 200)])
		return

	var stream := AudioStreamMP3.new()
	stream.data = body
	_audio.stream = stream
	_audio.play()
