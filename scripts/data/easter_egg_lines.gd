class_name EasterEggLines
extends RefCounted

# Swiss German voice-lines for the "Hoi-Schatz" love-tap easter egg.
# Tap any placed tower 7× in 3s to hear what they have to say.
static func get_lines(tower_id: String) -> Array:
	match tower_id:
		"basic":
			return ["Hoi Schatz!", "Bi dr Bani z'Affoltere!", "Mir gönds guet!", "Wer bisch du dann?"]
		"cordula":
			return ["Mir gönds guet, gell?", "Lueg, i bi's!", "Confetti!", "Alles super!"]
		"sniper":
			return ["Ruig, ruig, alles unter Kontrolle.", "Ich has im Griff.", "Kei Problem!"]
		"splash":
			return ["Was machsch du dänn?", "Hey hey hey!", "Exothermi!"]
		"slow":
			return ["Brrr, kalt isch's!", "Warm dich a!", "Zunge raus!"]
		"joe":
			return ["Hoi zäme!", "Alles guet?", "Joe isch hie!"]
		"justus":
			return ["Vater-Sohn-Power!", "Kei Stress!", "Los go!"]
		"seve":
			return ["Ciao bella!", "Seve isch am Start!", "Hoi!"]
		"farm":
			return ["Bio-Frücht für alli!", "Wachset und gedihet!"]
		"support":
			return ["Ich bi für euch da!", "Support-Modus!"]
		_:
			return []
