class_name SynergyTable
extends RefCounted

## Friend-pair synergy bonuses for Synergie-Combo (ROADMAP P1).
## Checks are bidirectional — tower order in a pair doesn't matter.
## Consumed by BaseTower._refresh_synergies() on every topology change.

const PAIRS: Array = [
	{
		"a": "basic", "b": "cordula",
		"range_mul": 1.20, "dmg_mul": 1.0, "atk_speed_mul": 1.0,
		"slow_dur_add": 0.0, "pierce_add": 0,
		"label": "Mir gsehnd alles"
	},
	{
		"a": "sniper", "b": "splash",
		"range_mul": 1.0, "dmg_mul": 1.15, "atk_speed_mul": 1.0,
		"slow_dur_add": 0.0, "pierce_add": 0,
		"label": "Präzision + Chaos"
	},
	{
		"a": "slow", "b": "cordula",
		"range_mul": 1.0, "dmg_mul": 1.0, "atk_speed_mul": 1.0,
		"slow_dur_add": 0.5, "pierce_add": 0,
		"label": "Isi Stützig"
	},
	{
		"a": "splash", "b": "basic",
		"range_mul": 1.0, "dmg_mul": 1.0, "atk_speed_mul": 1.0,
		"slow_dur_add": 0.0, "pierce_add": 1,
		"label": "Banana-Volleyball"
	},
	{
		"a": "joe", "b": "justus",
		"range_mul": 1.0, "dmg_mul": 1.0, "atk_speed_mul": 1.25,
		"slow_dur_add": 0.0, "pierce_add": 0,
		"label": "Vater/Sohn Rapid"
	},
]


static func find_bonus(id_a: String, id_b: String) -> Dictionary:
	for p in PAIRS:
		if (p.a == id_a and p.b == id_b) or (p.a == id_b and p.b == id_a):
			return p
	return {}
