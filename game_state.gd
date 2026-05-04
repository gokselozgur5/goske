extends Node

# Holds runtime game state. Alters get filtered subsets via context_for(id).
# Asymmetric info access (manifesto: "AI partner exists with partial access
# to truth").

var play_started_ms: int = 0
var comfort_exits: int = 0
var alter_engagements: Dictionary = {}  # alter_id -> int
var alter_trust: Dictionary = {}  # alter_id -> int (0-100, default 50)
var unlocked_alters: Array[String] = []
var silenced_alters: Array[String] = []
var exhaustion: int = 0  # 0-100

const TRUST_DEFAULT := 50
const EXHAUSTION_PER_RESPONSE := 5
const EXHAUSTION_BLACK_THRESHOLD := 70
const EXHAUSTION_SILENCE_THRESHOLD := 90
const EXHAUSTION_RECOVERY_PER_SEC := 0.8

signal trust_changed(alter_id: String, new_value: int)
signal alter_unlocked(alter_id: String)
signal exhaustion_changed(new_value: int)
signal alter_silenced(alter_id: String)

func _ready() -> void:
	play_started_ms = Time.get_ticks_msec()
	add_to_group("game_state")

func play_seconds() -> int:
	return int(float(Time.get_ticks_msec() - play_started_ms) / 1000.0)

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

func is_silenced(alter_id: String) -> bool:
	return alter_id in silenced_alters

func add_exhaustion(amount: int) -> void:
	exhaustion = clamp(exhaustion + amount, 0, 100)
	exhaustion_changed.emit(exhaustion)
	if exhaustion >= EXHAUSTION_SILENCE_THRESHOLD:
		_maybe_silence_top_trust_alter()

func recover_exhaustion(delta: float) -> void:
	if exhaustion <= 0:
		return
	# Accumulate float, apply when >= 1.0
	_recovery_accumulator += EXHAUSTION_RECOVERY_PER_SEC * delta
	if _recovery_accumulator >= 1.0:
		var step: int = int(_recovery_accumulator)
		_recovery_accumulator -= float(step)
		exhaustion = clamp(exhaustion - step, 0, 100)
		exhaustion_changed.emit(exhaustion)

var _recovery_accumulator: float = 0.0

func _maybe_silence_top_trust_alter() -> void:
	# Highest-trust unlocked alter goes silent (Sekiro Dragonrot infection)
	var max_trust: int = -1
	var target: String = ""
	for aid in unlocked_alters:
		if aid in silenced_alters:
			continue
		if get_trust(aid) > max_trust:
			max_trust = get_trust(aid)
			target = aid
	if target != "":
		silenced_alters.append(target)
		alter_silenced.emit(target)

# Subset of state visible to a specific alter (asymmetric access)
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
			# Censored: only neutral/positive metrics
			return {
				"play_seconds": full["play_seconds"],
				"engagements": full["engagements"],
				"my_trust": full["my_trust"],
			}
		_:
			return {}
