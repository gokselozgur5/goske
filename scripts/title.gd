extends Control

# Title screen. Renders a minimal opening frame: name, hook, key hints,
# and waits for the player to press anything to load main.tscn.
#
# Built code-side so we don't fight the .tscn format. The root scene
# is just a Control with this script attached.

const HOOK := "Three voices wake up inside you.\nThe neighbors keep their distance.\nYou are alone with all of them."
const HINTS := "WASD  move        E  interact        F  free-text        Esc  close"

var _bg: ColorRect
var _begin_label: Label
var _can_start: bool = false
var _starting: bool = false
var _blink_t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	# Tiny grace period so a held key from the previous scene doesn't auto-skip.
	await get_tree().create_timer(0.4).timeout
	_can_start = true

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.04, 0.04, 0.06, 1.0)
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Soft red/blue/green accent strip near the top — quiet visual nod to the
	# trust triple without spelling it out.
	var strip := HBoxContainer.new()
	strip.anchor_left = 0.5
	strip.anchor_right = 0.5
	strip.anchor_top = 0.16
	strip.anchor_bottom = 0.16
	strip.offset_left = -120
	strip.offset_right = 120
	strip.offset_top = -2
	strip.offset_bottom = 2
	strip.add_theme_constant_override("separation", 12)
	add_child(strip)
	for col in [Color(0.85, 0.20, 0.18), Color(0.18, 0.40, 0.85), Color(0.18, 0.70, 0.30)]:
		var dot := ColorRect.new()
		dot.color = col
		dot.custom_minimum_size = Vector2(64, 4)
		strip.add_child(dot)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 28)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "GOSKE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.92, 0.90, 0.86))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a 2.5D narrative"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 24)
	vbox.add_child(spacer)

	var hook := Label.new()
	hook.text = HOOK
	hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hook.add_theme_font_size_override("font_size", 24)
	hook.add_theme_color_override("font_color", Color(0.78, 0.76, 0.72))
	vbox.add_child(hook)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(1, 36)
	vbox.add_child(spacer2)

	var hints := Label.new()
	hints.text = HINTS
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.add_theme_font_size_override("font_size", 18)
	hints.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
	vbox.add_child(hints)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(1, 24)
	vbox.add_child(spacer3)

	_begin_label = Label.new()
	_begin_label.text = "press any key to begin"
	_begin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_label.add_theme_font_size_override("font_size", 20)
	_begin_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
	vbox.add_child(_begin_label)

	var credit := Label.new()
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.anchor_left = 0.5
	credit.anchor_right = 0.5
	credit.offset_top = -36
	credit.offset_bottom = -16
	credit.offset_left = -160
	credit.offset_right = 160
	credit.text = "alienation, voices, and the people outside the jar"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color(0.40, 0.40, 0.45))
	add_child(credit)

func _process(delta: float) -> void:
	if _begin_label == null:
		return
	_blink_t += delta
	var a: float = 0.55 + 0.35 * sin(_blink_t * 2.4)
	_begin_label.modulate.a = a

func _unhandled_input(event: InputEvent) -> void:
	if not _can_start or _starting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_start()
	elif event is InputEventMouseButton and event.pressed:
		_start()

func _start() -> void:
	_starting = true
	get_viewport().set_input_as_handled()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
