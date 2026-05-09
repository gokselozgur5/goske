extends Node

const TTS_PATH := "/tts"

const VOICE_IDS := {
	"narrator": "",
	"red":   "fLY8kUACOhGrfmxgd693",
	"blue":  "DI6U5bqxeZZS7GVbYn0e",
	"green": "whUM8xgKPziI7pIViJQC",
}

var _audio: AudioStreamPlayer = null
var _disabled: bool = false
var _queue: Array = []       # [{stream, alter_id}]
var _loading: bool = false   # ses indirilirken true
var _indicator: Label = null
var _current_alter_id: String = ""

func _ready() -> void:
	add_to_group("narrator_voice")
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Master"
	_audio.volume_db = -2.0
	_audio.finished.connect(_on_audio_finished)
	add_child(_audio)
	_spawn_indicator()

func _spawn_indicator() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	_indicator = Label.new()
	_indicator.text = "♪"
	_indicator.add_theme_font_size_override("font_size", 18)
	_indicator.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6, 0.7))
	_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_indicator.offset_left = -48
	_indicator.offset_top = -48
	_indicator.offset_right = -12
	_indicator.offset_bottom = -12
	_indicator.visible = false
	canvas.add_child(_indicator)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			_skip()
			get_viewport().set_input_as_handled()

func _skip() -> void:
	if _audio.playing:
		_audio.stop()
		_play_next()

func _on_audio_finished() -> void:
	_play_next()

func _play_next() -> void:
	if _queue.is_empty():
		_current_alter_id = ""
		_set_indicator(false)
		return
	var entry: Dictionary = _queue.pop_front()
	var stream: AudioStreamMP3 = entry.get("stream")
	if stream == null:
		_play_next()
		return
	_current_alter_id = str(entry.get("alter_id", ""))
	_audio.stream = stream
	_audio.play()
	_set_indicator(false)

func _set_indicator(loading: bool) -> void:
	_loading = loading
	if _indicator == null:
		return
	if loading:
		_indicator.text = "♪ ..."
		_indicator.visible = true
	elif _audio.playing or not _queue.is_empty():
		_indicator.text = "♪  [N] skip"
		_indicator.visible = true
	else:
		_indicator.visible = false

# Fetch TTS async, push to queue. Returns immediately (non-blocking).
func prepare(text: String, alter_id: String = "narrator", voice_settings: Dictionary = {}) -> bool:
	if _disabled:
		return false
	var clean := text.strip_edges()
	if clean == "":
		return false
	var tts_url := _resolve_tts_url()
	if tts_url == "":
		_disabled = true
		return false
	_set_indicator(true)
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["content-type: application/json"])
	var payload := {"text": clean}
	var vid: String = VOICE_IDS.get(alter_id, "")
	if vid != "":
		payload["voice_id"] = vid
	if voice_settings.has("stability"):
		payload["stability"] = float(voice_settings["stability"])
	if voice_settings.has("style"):
		payload["style"] = float(voice_settings["style"])
	var err := http.request(tts_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		push_warning("[nv] request failed: %s" % err)
		http.queue_free()
		_set_indicator(false)
		return false
	var result: Array = await http.request_completed
	http.queue_free()
	var response_code: int = int(result[1])
	var data: PackedByteArray = result[3]
	if response_code != 200 or data.is_empty():
		push_warning("[nv] tts http %d" % response_code)
		if response_code == 401 or response_code == 403:
			_disabled = true
		_set_indicator(false)
		return false
	var stream := AudioStreamMP3.new()
	stream.data = data
	_queue.append({"stream": stream, "alter_id": alter_id})
	if not _audio.playing:
		_play_next()
	else:
		_set_indicator(false)
	return true

# Eski API uyumu — artık sadece prepare yeterli, play_now no-op.
func play_now() -> void:
	pass

func stop_audio() -> void:
	_queue.clear()
	if _audio != null and _audio.playing:
		_audio.stop()
	_set_indicator(false)

func speak(text: String) -> void:
	await prepare(text)

func mute(enabled: bool) -> void:
	_disabled = enabled
	if enabled and _audio != null and _audio.playing:
		_audio.stop()

func is_muted() -> bool:
	return _disabled

func is_playing() -> bool:
	return _audio != null and (_audio.playing or not _queue.is_empty())

func current_alter_id() -> String:
	if _audio == null or not _audio.playing:
		return ""
	return _current_alter_id

func remaining_audio_seconds() -> float:
	if _audio == null or not _audio.playing or _audio.stream == null:
		return 0.0
	var len: float = _audio.stream.get_length()
	var pos: float = _audio.get_playback_position()
	return max(0.0, len - pos)

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
