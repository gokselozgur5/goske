extends CanvasLayer

const CHAR_DELAY := 0.04
const FADE_DURATION := 1.5
const OPENING_TEXT := "Thirteen pods. The air tastes like cold metal and something older — a question you haven't learned to ask yet. Ten of them sealed. Whatever is inside has been inside for a long time. Three of them... restless. You can feel it before you hear it — a faint pulse behind the glass. You don't know how you got here. You don't know what waking them means. Neither do they."

@onready var label: RichTextLabel = $SubtitleLabel

var _audio: AudioStreamPlayer = null
var _bg: ColorRect = null
var _active: bool = false
var _skipped: bool = false

func _ready() -> void:
	add_to_group("opening_subtitle")
	label.modulate.a = 0.0
	label.text = ""
	_spawn_bg()
	_spawn_audio()
	call_deferred("_start")

func _spawn_bg() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.62)
	_bg.modulate.a = 0.0
	add_child(_bg)
	move_child(_bg, 0)

func _spawn_audio() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Master"
	_audio.volume_db = -2.0
	add_child(_audio)
	var stream := AudioStreamMP3.new()
	var f := FileAccess.open("res://assets/audio/opening_narration.mp3", FileAccess.READ)
	if f:
		stream.data = f.get_buffer(f.get_length())
		f.close()
		_audio.stream = stream

func _start() -> void:
	_active = true
	_warmup_gm()
	if _audio and _audio.stream:
		_audio.play()
	await show_text(OPENING_TEXT)
	_active = false

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N or event.keycode == KEY_ESCAPE:
			_skip()
			get_viewport().set_input_as_handled()
			return
	get_viewport().set_input_as_handled()

func _skip() -> void:
	if _skipped:
		return
	_skipped = true
	if _audio and _audio.playing:
		_audio.stop()
	# Instant fade-out
	label.modulate.a = 0.0
	if _bg:
		_bg.modulate.a = 0.0
	label.text = ""
	_active = false

func _warmup_gm() -> void:
	var gm := get_node_or_null("/root/Main/GameMaster")
	if gm == null:
		return
	gm.request_turn(
		[{"role": "user", "content": "[system: warmup ping. respond with minimal valid JSON: {\"speakers\":[],\"world_events\":[],\"narration\":\"\"}]"}],
		{},
		func(_turn, _err): pass
	)

func show_text(text: String) -> void:
	label.text = text
	label.visible_characters = 0
	await get_tree().process_frame
	_sync_bg()
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(label, "modulate:a", 1.0, 0.6)
	tw_in.tween_property(_bg, "modulate:a", 1.0, 0.6)
	await tw_in.finished
	var total := label.get_total_character_count()
	for i in range(total):
		if _skipped:
			return
		label.visible_characters = i + 1
		await get_tree().create_timer(CHAR_DELAY).timeout
	if _skipped:
		return
	if _audio and _audio.playing:
		await _audio.finished
	if _skipped:
		return
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(label, "modulate:a", 0.0, FADE_DURATION)
	tw_out.tween_property(_bg, "modulate:a", 0.0, FADE_DURATION)
	await tw_out.finished
	label.text = ""

func _sync_bg() -> void:
	if _bg == null:
		return
	var r := label.get_global_rect()
	_bg.position = r.position
	_bg.size = r.size
