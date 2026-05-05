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
var npc_intensity: Dictionary = {}  # npc_id -> float (0..1, Dragonrot severity)
var days_alone: int = 0
# Mystery thread phase: "early" | "mid" | "late"
# Derived from play_seconds + interactions, but exposed as a field so the GM
# can tag turns explicitly via mystery_phase in world_events.
var mystery_phase: String = "early"
# Monotony: routine accumulates, novelty drains. Drives the saturation
# post-process — at 1.0 the world is grayscale, at 0.0 fully colored.
var monotony: float = 0.0
# Tension: drama escalation. Rises in pressured moments, decays in idle.
# Drives trust-delta multipliers + narrator pacing. Disco Elysium "stakes
# escalating" without a click-options UI (manifesto: no canned trees).
var tension: float = 0.0
var ending_shown: bool = false  # one-shot guard so the overlay only fires once per run
var meta_breaches: int = 0  # how many times the GM has broken the 4th wall
# Last action's flavor — every interaction (pod open, rest, alter approach,
# outburst) rolls an RGB mix anchored to current trust + random nudge.
# The GM reads this on the NEXT turn and colors voices accordingly.
var last_action: Dictionary = {}

const TRUST_DEFAULT := 50
const EXHAUSTION_PER_RESPONSE := 5
const EXHAUSTION_BLACK_THRESHOLD := 70
const EXHAUSTION_SILENCE_THRESHOLD := 90
const EXHAUSTION_RECOVERY_PER_SEC := 0.8
const MONOTONY_PER_RESPONSE := 0.018
const MONOTONY_PER_REST := 0.05
const MONOTONY_PER_COMFORT_EXIT := -0.04
const MONOTONY_PER_WHISPER := -0.08
const TENSION_DECAY_PER_TURN := 0.06  # drains slightly each turn that isn't escalating

signal trust_changed(alter_id: String, new_value: int)
signal alter_unlocked(alter_id: String)
signal exhaustion_changed(new_value: int)
signal alter_silenced(alter_id: String)
signal npc_affected(npc_id: String, new_intensity: float)
signal day_passed(new_days_alone: int)
signal mystery_phase_changed(new_phase: String)
signal action_recorded(label: String, color: Dictionary)
signal monotony_changed(new_value: float)
signal tension_changed(new_value: float)

func _ready() -> void:
	play_started_ms = Time.get_ticks_msec()
	add_to_group("game_state")

func play_seconds() -> int:
	return int(float(Time.get_ticks_msec() - play_started_ms) / 1000.0)

func record_comfort_exit() -> void:
	comfort_exits += 1
	# Stepping outside the comfort circle is novelty — pushes monotony down.
	adjust_monotony(MONOTONY_PER_COMFORT_EXIT)
	record_action("comfort_exit")

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
	record_action("opened_pod_" + alter_id)

func is_unlocked(alter_id: String) -> bool:
	return alter_id in unlocked_alters

func is_silenced(alter_id: String) -> bool:
	return alter_id in silenced_alters

# Engine starts the action; LLM colors the outcome. Every interaction
# records what was done + a random self-mix. The GM reads this on the
# next turn and tints prose, alter reactions, narrator beats.
func record_action(label: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rr: int = clamp(get_trust("red") + rng.randi_range(-30, 30), 0, 100)
	var bb: int = clamp(get_trust("blue") + rng.randi_range(-30, 30), 0, 100)
	var gg: int = clamp(get_trust("green") + rng.randi_range(-30, 30), 0, 100)
	last_action = {
		"label": label,
		"color": {"r": rr, "b": bb, "g": gg},
	}
	action_recorded.emit(label, last_action["color"])

func compute_ending() -> Dictionary:
	var endings_node := get_node_or_null("/root/Main/Endings")
	if endings_node == null or not endings_node.has_method("compute_ending"):
		return {}
	return endings_node.compute_ending(
		get_trust("red"),
		get_trust("blue"),
		get_trust("green"),
	)

# Should the run end now? Returns the FIRST matching reason or "" if none.
# First match wins; reasons are ordered most-decisive → least.
func check_ending_trigger() -> String:
	if ending_shown:
		return ""
	# 1. Total Dragonrot: all woken alters silenced.
	if unlocked_alters.size() >= 1 and silenced_alters.size() == unlocked_alters.size():
		return "all_silenced"
	# 2. Extreme isolation.
	if days_alone >= 30:
		return "isolation_extreme"
	# 3. Late mystery + a tipping condition.
	if mystery_phase == "late":
		if days_alone >= 7:
			return "late_phase_isolation"
		if comfort_exits >= 15:
			return "late_phase_wandering"
		if silenced_alters.size() >= 2:
			return "late_phase_silenced"
	# 4. Trust extremes — a committed run.
	for aid in unlocked_alters:
		var t: int = get_trust(aid)
		if t >= 85:
			return "trust_high_" + aid
		if t <= 15:
			return "trust_low_" + aid
	return ""

func rest() -> void:
	# Spend a day alone: clear exhaustion, advance the day counter.
	exhaustion = 0
	_recovery_accumulator = 0.0
	exhaustion_changed.emit(exhaustion)
	days_alone += 1
	day_passed.emit(days_alone)
	# Resting is itself routine — adds to monotony
	adjust_monotony(MONOTONY_PER_REST)
	record_action("rested")

func set_tension(value: float) -> void:
	var new_val: float = clamp(value, 0.0, 1.0)
	if abs(new_val - tension) < 0.0001:
		return
	tension = new_val
	tension_changed.emit(tension)

func decay_tension() -> void:
	if tension <= 0.0:
		return
	set_tension(tension - TENSION_DECAY_PER_TURN)

# Trust deltas amplify under tension. Lower bound 1.0x at no tension,
# up to ~2x at full rupture.
func tension_multiplier() -> float:
	return 1.0 + tension

# 4th-wall meta breach is allowed only under tight, earned conditions.
# Capped at 2 per run.
func meta_eligible() -> bool:
	if meta_breaches >= 2:
		return false
	if tension < 0.85:
		return false
	if comfort_exits < 5:
		return false
	if days_alone < 3:
		return false
	return true

func adjust_monotony(delta: float) -> void:
	var new_val: float = clamp(monotony + delta, 0.0, 1.0)
	if abs(new_val - monotony) < 0.0001:
		return
	monotony = new_val
	monotony_changed.emit(monotony)

func set_mystery_phase(phase: String) -> void:
	if phase == mystery_phase:
		return
	if not (phase in ["early", "mid", "late"]):
		return
	mystery_phase = phase
	mystery_phase_changed.emit(phase)

func update_npc_intensity(npc_id: String, intensity: float) -> void:
	# Highest intensity wins (Dragonrot accumulates, doesn't undo).
	var current: float = npc_intensity.get(npc_id, 0.0)
	var new_val: float = clamp(max(current, intensity), 0.0, 1.0)
	if new_val == current:
		return
	npc_intensity[npc_id] = new_val
	npc_affected.emit(npc_id, new_val)

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
