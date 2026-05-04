extends Node

# 17 endings, partitioned across the (red_trust, blue_trust, green_trust)
# 0..100 cube via Voronoi: each ending has a centroid; the resolved
# ending is the centroid closest in Euclidean distance to the run's final
# trust trio.
#
# Asymmetric by design — (R,0,0) is not the mirror of (0,0,B). Every
# region carries its own theme, not just a numeric label.

const ENDINGS: Array = [
	# All-low — the player walked away without committing to anyone.
	{
		"id": "empty_jar",
		"label": "The Empty Jar",
		"centroid": Vector3(0, 0, 0),
		"color": Color(0.2, 0.2, 0.22),
		"theme": "You fell silent before they did. The pods stayed sealed; the room kept itself.",
	},
	# Pure red — anger ran the run.
	{
		"id": "the_red_voice",
		"label": "Anger Found Its Voice",
		"centroid": Vector3(100, 0, 0),
		"color": Color(0.85, 0.25, 0.25),
		"theme": "What you wouldn't say, red said. The silences broke. The neighbors closed their windows.",
	},
	# Pure blue — pure analysis won.
	{
		"id": "cold_solution",
		"label": "The Cold Solution",
		"centroid": Vector3(0, 100, 0),
		"color": Color(0.25, 0.5, 0.85),
		"theme": "Blue wrote the equation. The variables resolved. The room stayed at room temperature.",
	},
	# Pure green — naive hope carried it.
	{
		"id": "believing_through",
		"label": "Believing Through",
		"centroid": Vector3(0, 0, 100),
		"color": Color(0.35, 0.78, 0.4),
		"theme": "Green never stopped looking for the kindness underneath. You followed.",
	},
	# Red + green dominant — fierce + naive
	{
		"id": "the_sermon",
		"label": "The Sermon",
		"centroid": Vector3(80, 0, 80),
		"color": Color(0.78, 0.55, 0.35),
		"theme": "Anger dressed in hope. You stood at the door of someone's apartment with a speech you'd rehearsed, and they let you in.",
	},
	# Red + blue — surgical anger
	{
		"id": "cold_blade",
		"label": "Cold Blade",
		"centroid": Vector3(80, 80, 0),
		"color": Color(0.6, 0.4, 0.55),
		"theme": "Red carried the blow, blue chose the angle. What you cut, you cut clean. You did not look back.",
	},
	# Blue + green — calm constructor
	{
		"id": "engineer_of_hope",
		"label": "Engineer of Hope",
		"centroid": Vector3(0, 80, 80),
		"color": Color(0.4, 0.7, 0.65),
		"theme": "You built something small and patient. It did not collapse. Years from now, somebody will pass through it without noticing.",
	},
	# All-high — polyphonic integration
	{
		"id": "many_voices_one_body",
		"label": "Many Voices, One Body",
		"centroid": Vector3(85, 85, 85),
		"color": Color(0.9, 0.85, 0.78),
		"theme": "Three voices learned the same throat. The jar is still there, but it speaks now.",
	},
	# Balanced — Camus's null
	{
		"id": "meursault_returns",
		"label": "Meursault Returns",
		"centroid": Vector3(50, 50, 50),
		"color": Color(0.55, 0.55, 0.6),
		"theme": "Nothing tipped. The light was the same. You went on as you always had. The neighbors waved.",
	},
	# Red dominant w/ blue support
	{
		"id": "justified_rage",
		"label": "Justified Rage",
		"centroid": Vector3(80, 35, 0),
		"color": Color(0.78, 0.4, 0.3),
		"theme": "You were right. You proved it. Being right cost what it cost. Red counted out the price.",
	},
	# Red dominant w/ green support
	{
		"id": "the_burning_hopeful",
		"label": "The Burning Hopeful",
		"centroid": Vector3(80, 0, 35),
		"color": Color(0.85, 0.5, 0.45),
		"theme": "You wanted them to be better. You shouted that they could. Some heard you. Some shut a door.",
	},
	# Blue dominant w/ red support
	{
		"id": "calculated_rupture",
		"label": "Calculated Rupture",
		"centroid": Vector3(35, 80, 0),
		"color": Color(0.45, 0.55, 0.6),
		"theme": "Blue ran the numbers and red carried out the result. You ended things on a Tuesday. You marked it on the calendar.",
	},
	# Blue dominant w/ green support
	{
		"id": "patient_architect",
		"label": "Patient Architect",
		"centroid": Vector3(0, 80, 35),
		"color": Color(0.4, 0.65, 0.55),
		"theme": "Blue laid the lines, green watered them. You moved slowly enough that no one noticed you were moving.",
	},
	# Green dominant w/ red support
	{
		"id": "naive_defiance",
		"label": "Naïve Defiance",
		"centroid": Vector3(35, 0, 80),
		"color": Color(0.6, 0.5, 0.7),
		"theme": "Hope took red's posture. You said no like you meant yes underneath. Some saw through it. Some didn't.",
	},
	# Green dominant w/ blue support
	{
		"id": "quiet_faith",
		"label": "Quiet Faith",
		"centroid": Vector3(0, 35, 80),
		"color": Color(0.5, 0.7, 0.55),
		"theme": "Green did the believing, blue did the bookkeeping. You kept going. Most days you forgot to ask why.",
	},
	# One voice high, rest collapsed — the survivor
	{
		"id": "the_last_note",
		"label": "The Last Note",
		"centroid": Vector3(15, 85, 15),
		"color": Color(0.45, 0.4, 0.5),
		"theme": "Two voices fell quiet. The third kept speaking — flatly, clearly, into a room nobody else had ever entered.",
	},
	# All-mid-low — none won, none lost
	{
		"id": "static",
		"label": "Static",
		"centroid": Vector3(30, 30, 30),
		"color": Color(0.4, 0.4, 0.42),
		"theme": "The jar narrowed without breaking. The neighbors became weather. The voices wore thin in the same key.",
	},
]

func compute_ending(red_trust: int, blue_trust: int, green_trust: int) -> Dictionary:
	var p := Vector3(float(red_trust), float(blue_trust), float(green_trust))
	var best: Dictionary = {}
	var best_dist := INF
	for e in ENDINGS:
		var c: Vector3 = e["centroid"]
		var d: float = p.distance_squared_to(c)
		if d < best_dist:
			best_dist = d
			best = e
	return best
