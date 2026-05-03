extends Node

# Oyun state'i tutar; alter'lar context_for(id) ile filtered subset alir.
# Asymmetric info access: her alter farkli veri gorur (manifesto:
# "AI partner exists with partial access to truth").

var play_started_ms: int = 0
var comfort_exits: int = 0
var alter_engagements: Dictionary = {}  # alter_id -> int
var alter_trust: Dictionary = {}  # alter_id -> int (0-100, default 50)
var unlocked_alters: Array[String] = []

const TRUST_DEFAULT := 50

signal trust_changed(alter_id: String, new_value: int)
signal alter_unlocked(alter_id: String)

func _ready() -> void:
	play_started_ms = Time.get_ticks_msec()
	add_to_group("game_state")

func play_seconds() -> int:
	return int((Time.get_ticks_msec() - play_started_ms) / 1000)

func record_comfort_exit() -> void:
	comfort_exits += 1

func record_alter_engagement(alter_id: String) -> void:
	alter_engagements[alter_id] = alter_engagements.get(alter_id, 0) + 1

func get_trust(alter_id: String) -> int:
	return alter_trust.get(alter_id, TRUST_DEFAULT)

func adjust_trust(alter_id: String, delta: int) -> void:
	var current: int = get_trust(alter_id)
	var new_val: int = clamp(current + delta, 0, 100)
	alter_trust[alter_id] = new_val
	trust_changed.emit(alter_id, new_val)

func unlock_alter(alter_id: String) -> void:
	if alter_id in unlocked_alters:
		return
	unlocked_alters.append(alter_id)
	alter_unlocked.emit(alter_id)

func is_unlocked(alter_id: String) -> bool:
	return alter_id in unlocked_alters

# Bu alter'in gorebildigi context subset'i
func context_for(alter_id: String) -> Dictionary:
	var full := {
		"play_seconds": play_seconds(),
		"comfort_exits": comfort_exits,
		"engagements": alter_engagements,
	}
	full["my_trust"] = get_trust(alter_id)
	match alter_id:
		"red":
			return full
		"blue":
			return full
		"green":
			return {
				"play_seconds": full["play_seconds"],
				"engagements": full["engagements"],
				"my_trust": full["my_trust"],
			}
		_:
			return {}
