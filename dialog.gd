extends Label

func _ready() -> void:
	add_to_group("dialog_box")
	hide()

func show_text(t: String) -> void:
	text = t
	show()

func clear() -> void:
	text = ""
	hide()
