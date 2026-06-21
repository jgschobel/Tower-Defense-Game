class_name EnemyMeta
extends RefCounted

## Pure-data helpers describing enemies for UI consumption. Extracted
## from scripts/ui/hud.gd (which was 2,834 lines and counting) as the
## first step of the audit-recommended split into focused modules.
##
## Every method here takes only an enemy_id and returns presentation
## data — no scene-graph state. Safe to call from any UI script.

## Threat-tier color ramp. 1=trivial 5=MOAB-class.
## BTD-style green → yellow → orange → red → black ramp.
const THREAT_RAMP: Array = [
	Color(0.45, 0.85, 0.40, 1.0),  # 1 — trivial (grunt)
	Color(1.00, 0.85, 0.20, 1.0),  # 2 — moderate
	Color(1.00, 0.55, 0.18, 1.0),  # 3 — dangerous (camo / lead / fast)
	Color(0.95, 0.25, 0.20, 1.0),  # 4 — severe (boss / berserker)
	Color(0.18, 0.12, 0.18, 1.0),  # 5 — MOAB-class (dark)
]


## Threat-tier 1..5 — drives chip border color, badge intensity, etc.
static func threat_tier(enemy_id: String) -> int:
	match enemy_id:
		"moab_migros", "bfb_cumulus", "ddt_schwarz", \
		"selbschtbedienigs_wage", "selbschtskan_schiff":
			return 5
		"boss", "berserker", "linsen_golem", "glace_golem", \
		"roeschti_bombe", "cherry_bomb":
			return 4
		"camo", "lead", "regrow", "fondue_bomb", "tofu_ninja", \
		"cumulus_blob", "pasta_express":
			return 3
		"fast", "tank", "healer", "flying", "smoothie_slime":
			return 2
		_:
			return 1


static func threat_color(enemy_id: String) -> Color:
	var tier: int = threat_tier(enemy_id)
	return THREAT_RAMP[clampi(tier - 1, 0, THREAT_RAMP.size() - 1)]


## Loads the enemy's portrait texture from its .tres data.
## Returns null if the file doesn't exist or has no custom_texture.
static func icon_texture(enemy_id: String) -> Texture2D:
	var data_path := "res://resources/enemy_data/%s.tres" % enemy_id
	if not ResourceLoader.exists(data_path):
		return null
	var ed = load(data_path)
	if ed and "custom_texture" in ed and ed.custom_texture is Texture2D:
		return ed.custom_texture
	return null


## Fallback colored-swatch tint when the portrait isn't available.
## Used as the chip body when icon_texture() returns null.
static func preview_color(enemy_id: String) -> Color:
	match enemy_id:
		"basic":          return Color(0.9, 0.8, 0.5)
		"fast":           return Color(0.8, 0.5, 0.2)
		"tank":           return Color(0.5, 0.35, 0.25)
		"healer":         return Color(0.4, 0.7, 0.95)
		"flying":         return Color(0.3, 0.75, 0.35)
		"boss":           return Color(0.9, 0.2, 0.15)
		"swarm":          return Color(0.9, 0.9, 0.75)
		"camo":           return Color(0.3, 0.4, 0.3)
		"lead":           return Color(0.5, 0.5, 0.55)
		"regrow":         return Color(0.5, 0.8, 0.4)
		"fondue_bomb":    return Color(0.9, 0.7, 0.2)
		"glace_golem":    return Color(0.5, 0.8, 0.95)
		"berserker":      return Color(0.7, 0.15, 0.15)
		"cumulus_blob":   return Color(0.4, 0.5, 0.85)
		"linsen_golem":   return Color(0.5, 0.55, 0.25)
		"smoothie_slime": return Color(0.25, 0.8, 0.3)
		"tofu_ninja":            return Color(0.92, 0.92, 0.82)
		"pasta_express":         return Color(0.92, 0.82, 0.55)
		"cherry_bomb":           return Color(0.85, 0.15, 0.25)
		"selbschtbedienigs_wage": return Color(0.75, 0.1, 0.1)
		"selbschtskan_schiff":   return Color(0.55, 0.55, 0.65)
		"moab_migros":           return Color(0.8, 0.25, 0.05)
		"bfb_cumulus":           return Color(0.3, 0.3, 0.9)
		"ddt_schwarz":           return Color(0.1, 0.08, 0.15)
		"roeschti_bombe":        return Color(0.85, 0.55, 0.18)
		_: return Color(0.6, 0.6, 0.7)


## Compact display name suited to small UI rows (preview chips, top-
## bar tags). Full localized name lives on EnemyData.display_name.
static func short_name(enemy_id: String) -> String:
	match enemy_id:
		"basic":          return "Brötli"
		"fast":           return "Toblerone"
		"tank":           return "Cervelat"
		"healer":         return "Dr.Rivella"
		"flying":         return "Fondue"
		"swarm":          return "Schwarm"
		"camo":           return "Schatte"
		"lead":           return "Büchse"
		"regrow":         return "Gipfeli"
		"fondue_bomb":    return "Fondue-Bombe"
		"glace_golem":    return "Glacé"
		"berserker":      return "Seitän"
		"cumulus_blob":   return "Cumulus"
		"linsen_golem":   return "Linsen"
		"smoothie_slime": return "Smoothie"
		"tofu_ninja":            return "Ninja"
		"boss":                  return "M-TÜÜFEL"
		"pasta_express":         return "Pasta"
		"cherry_bomb":           return "Kirschbombe"
		"selbschtbedienigs_wage": return "SB-Wage"
		"selbschtskan_schiff":   return "Kopierer"
		"moab_migros":           return "Mega-Tank"
		"bfb_cumulus":           return "Cumulus-D."
		"ddt_schwarz":           return "Schwarz-Iir."
		"roeschti_bombe":        return "Röschti-B."
		_: return enemy_id.capitalize()


## One-line strategic counter hint per enemy type — shown on first-
## appearance reveal so the player knows what to build against it.
## Pattern from BTD6 Game Hints, Swiss-German for our game.
## Empty string = no special counter required (grunt enemies).
static func counter_hint(enemy_id: String) -> String:
	match enemy_id:
		"camo":           return "→ Bruch Sicht-Türm (Kühne T2+) zum gseh"
		"lead":           return "→ Bruch Magie / Pure Schade (Pollen, Volley)"
		"regrow":         return "→ Bruch Pure Schade (sunscht wachsed sii)"
		"flying":         return "→ Bruch en Turm wo flügend trifft (JoJo)"
		"healer":         return "→ Killed de Healer zerscht (priorisier en)"
		"fast":           return "→ Bruch schnälli Wäffe (Lemurius / JoJo)"
		"swarm":          return "→ Bruch Flächeschade (JoJo splash / Cordula)"
		"tank":           return "→ Bruch schweri Schade (Kühne T3, Cordula)"
		"berserker":      return "→ Hoche Schade vor er d'Mitti erreicht!"
		"fondue_bomb":    return "→ Sprängt z'rugg sini Nochbere (Abstand!)"
		"glace_golem":    return "→ Schmilzt zu chleinerem Cumulus-Blob"
		"cumulus_blob":   return "→ Stilet dini Cumulus — schnäll wäg!"
		"linsen_golem":   return "→ Linsen-Pansring: Magie / Pure Schade"
		"smoothie_slime": return "→ Spaltet uf — bring Splash-Türm"
		"tofu_ninja":     return "→ Camo + schnäll — Kühne mit Sichtweiti"
		"boss":           return "→ ALL Türm zäme — tier-3 unbedingt!"
		"moab_migros":    return "→ MOAB-Klasse: schweri Pure Schade nöötig"
		"bfb_cumulus":    return "→ Flüged + camo — Kühne T3 + Sicht-Aura"
		"ddt_schwarz":    return "→ Schnäll, camo, bly — JEDI Konter-Türm"
		"selbschtskan_schiff": return "→ Wechslet sini Hülle: diversifizier dini Türm"
		"roeschti_bombe": return "→ Sprängt nach ~3s — kill schnäll und zer Sicht"
		"cherry_bomb":    return "→ Massivi Spräng-Schade — chli Pause halte"
		"selbschtbedienigs_wage": return "→ MOAB-Klasse! Tötet schnäll — spawnt 6 Feind bim Tod"
		"pasta_express":  return "→ Schnäll wie SBB-Express — Lemurius / JoJo kontered"
		_:                return ""
