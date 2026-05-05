extends Node

# Narrator-only TTS playback. Two-phase:
#   1. prepare(text)  → fires the HTTP request, awaits the MP3 bytes,
#                       sets the AudioStream. Returns true on success.
#   2. play_now()     → plays the prepared stream.
#
# Caller (conversation.gd) awaits prepare() before starting the typewriter
# so the voice and the text begin together. Manifesto: only the narrator
# is voiced. Goske's inner alters (red/blue/green) stay text-only.
#
# Cancel-on-new policy: a new prepare() call bumps the request token.
# Any in-flight request that comes back stale is dropped, and any
# currently-playing audio is stopped.

const TTS_PATH := "/tts"

var _http: HTTPRequest = null
var _audio: AudioStreamPlayer = null
var _request_token: int = 0
var _disabled: bool = false  # set true if local-dev (no proxy) or muted

func _ready() -> void:
	add_to_group("narrator_voice")
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Master"
	_audio.volume_db = -2.0
	add_child(_audio)

# Fires a TTS request, awaits the response, and stores the audio stream.
# Returns true if audio is ready to play. The caller should follow up with
# play_now() to actually start playback.
func prepare(text: String) -> bool:
	if _disabled:
		return false
	var clean := text.strip_edges()
	if clean == "":
		return false

	# Cancel any current playback + in-flight request.
	_request_token += 1
	var my_token := _request_token
	if _audio.playing:
		_audio.stop()
	if _http != null:
		_http.cancel_request()
		_http.queue_free()
		_http = null

	var tts_url := _resolve_tts_url()
	if tts_url == "":
		# No proxy configured (local dev). Silent fallback.
		_disabled = true
		return false

	_http = HTTPRequest.new()
	add_child(_http)

	var headers := PackedStringArray(["content-type: application/json"])
	var body := JSON.stringify({"text": clean})
	var err := _http.request(tts_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("[narrator_voice] request failed: %s" % err)
		_http.queue_free()
		_http = null
		return false

	# Await the HTTPRequest completion signal directly. Returns
	# [result, response_code, headers, body_bytes].
	var result: Array = await _http.request_completed

	# Stale: a newer prepare() call bumped the token while we were waiting.
	if my_token != _request_token:
		return false

	if _http != null:
		_http.queue_free()
		_http = null

	var response_code: int = int(result[1])
	var data: PackedByteArray = result[3]
	if response_code != 200 or data.is_empty():
		var msg := data.get_string_from_utf8()
		push_warning("[narrator_voice] tts http %d: %s" % [response_code, msg.substr(0, 200)])
		return false

	var stream := AudioStreamMP3.new()
	stream.data = data
	_audio.stream = stream
	return true

func play_now() -> void:
	if _audio == null or _audio.stream == null:
		return
	_audio.play()

# Hard cancel: stop audio + invalidate any in-flight request. Used when
# the conversation panel closes mid-narration.
func stop_audio() -> void:
	_request_token += 1
	if _audio != null and _audio.playing:
		_audio.stop()
	if _http != null:
		_http.cancel_request()
		_http.queue_free()
		_http = null

# Backward-compat: fire-and-forget shorthand.
func speak(text: String) -> void:
	var ok := await prepare(text)
	if ok:
		play_now()

func mute(enabled: bool) -> void:
	_disabled = enabled
	if enabled and _audio != null and _audio.playing:
		_audio.stop()

func is_muted() -> bool:
	return _disabled

func _resolve_tts_url() -> String:
	var gm := get_node_or_null("/root/Main/GameMaster")
	if gm == null:
		return ""
	if not bool(gm.via_proxy):
		return ""
	var base: String = String(gm.api_url).rstrip("/")
	if base == "":
		return ""
	return base + TTS_PATH
