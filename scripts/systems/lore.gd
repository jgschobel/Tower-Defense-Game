class_name Lore
extends RefCounted

## All game lore, story text, and character descriptions.
## D'heilige Schrifte vom Affoltern Banani Raubzug.

const GAME_TITLE := "Affoltern Banani Raubzug"
const GAME_SUBTITLE := "De Grooss Banane-Raubzug vo Züri-Affoltern"

static func get_level_intro(level_id: int) -> Dictionary:
	match level_id:
		1:
			return {
				"title": "Kapitel 1: Migros Affoltern",
				"subtitle": "Jonas Furrer-Strasse 25, 8046 Züri",
				"text": "Ziischtig, 19:47. D'Lemurius und de Amösius chömed vom Apéro zrugg und finded ihri gliebti Migros im totale Chaos. D'Regäl sind läbig, de Sälf-Tscheckout isch bsässe, und öpper het d'Banane id TIEFCHÜEL-ABTEILIG gstellt. Das gaht gar nöd.\n\nDi erschti Welle vo verfluechtne Lääbesmittel chunnt vom Igang...\n\n\"Amösius, gsehsch du das au?\"\n\"Ja, Lemurius. Die Brötli händ jetzt Auge.\"\n\"...und Zähn.\"\n\"Mir bruuched meh Banane.\"",
				"enemy_preview": "Bösi Brötli • Turbo Toblerone • Beefy Cervelat",
			}
		2:
			return {
				"title": "Kapitel 2: D'Tiefchüel-Abteilig",
				"subtitle": "Temperatur: -18°C. Moral: Au -18°C.",
				"text": "Tüüf ide Tiefchüel-Abteilig sind d'verfluechte Produkt schnäller — d'Chelti macht sie AGGRESSIV. Gfrorni Pizza rutschet über de Bode wie Hockey-Pucks. Fischstäbli händ es Militär bildet.\n\nEm Amösius sini Zunge bliibt immer a de Regäl härige.\n\n\"Mini Zunge isch scho wieder fescht!\"\n\"Hör uf d'Gfrüürer-Türe z'schlecke, Amösius!\"\n\"Ich chan nüt defür! Ich bi en Gecko! Chalti Oberfläche sind mini Schwächi!\"",
				"enemy_preview": "Gfrorni Pizza • Fischstäbli-Militär • Glacé-Golem",
			}
		3:
			return {
				"title": "Kapitel 3: D'Bäckerei vom Gruse",
				"subtitle": "Frischs Brot. Frischi Alpträum.",
				"text": "D'Migros-Bäckerei isch zur Festig worde. De Zopf het sich sälber zu Barrikade gflochte. Gipfeli mached Sturzflüg vo de Decki. Und de Suurteig... er LÄBT. Also, no meh als süsch.\n\nD'Lemurius gseht en Chischte Bio-Banane hinder de feindliche Linie.\n\n\"Das sind MINI Banane. Fairtrade. Bio. CHF 2.95 s'Kilo.\"\n\"Lemurius, jetzt isch nöd de Moment—\"\n\"ES ISCH IMMER DE MOMENT FÜR GÜNSTIGI BIO-BANANE.\"",
				"enemy_preview": "Kamikaze-Gipfeli • Zopf-Barrikade • Dr. Rivella • De Suurteig",
			}
		_:
			return {
				"title": "Kapitel %d: Tüüfer id Migros" % level_id,
				"subtitle": "De M-Tüüfel wird stärcher...",
				"text": "D'verfluechte Produkt höred nöd uf cho. Aber d'Lemurius und de Amösius kämpfed sich dure, eini Banane uf einisch.\n\n\"Wieviel Gäng het die Migros EIGENTLICH?!\"\n\"S'isch Schwiizer Detailhandel, Amösius. Das gaht ewig wiiter.\"",
				"enemy_preview": "???",
			}


const CHARACTER_BIOS := {
	"lemurius": {
		"name": "Lemurius — D'Friedeswächterin",
		"bio": "Art: Ringelschwanz-Lemur / Mönsch-Hybrid\nBruef: Migros Banane-Gang Spezialistin (Mitarbeiterin vom Monet x17)\nWaffe: Banane (Bio, Fairtrade, gworfe mit 140 km/h)\nSchwächi: Banane-Rabatt\nLieblings-Getränk: Alnatura Mango Smoothie\nSpruch: \"Banane isch Banane, aber BIO Banane isch Läbe.\"",
	},
	"amosius": {
		"name": "Amösius — D'Zunge vo de Grächtigkeit",
		"bio": "Art: Tokay Gecko / Mönsch-Hybrid\nBruef: Sälbständigi \"Schädlingsbekämpfig\" (er frisst Mugge)\nWaffe: 40cm chläbrigi Zunge (reicht wiiter wenn er verruckt isch)\nSchwächi: Chalti Oberfläche, Lotto-Zettel\nLieblings-Getränk: Was au immer i dere blaue Dose isch\nSpruch: \"Ich han mal CHF 2.50 im Lotto gwunne. Ich bi basically riich.\"",
	},
	"m_teufel": {
		"name": "De M-Tüüfel — De Migros-Tüüfel",
		"bio": "Art: Dämonischi Detailhandels-Entität\nBruef: Supermarkt-Produkt verfluche\nWaffe: Abglaufeni Cumulus-Punkte, kaputti Iichaufswäge\nUrsprung: Gebore us 10'000 nöd iglööste Cumulus-Punkte und de kollektive Wuet vo Chunde wo ihri Täsche vergässe händ\nZiel: Alli Banane-Rabatt z'Züri widerruefe\nSpruch: \"CUMULUS-PUNKTE SIND JETZT WÄRTLOS! MWAHAHAHA!\"",
	},
}

const ENEMY_LORE := {
	"basic": "Bösi Brötli — Es verfluechts Brötli mit Guggelauge und ere schlechte Laune. Marschiert langsam aber i grusige Zahl. No warm vom Ofe.",
	"fast": "Turbo Toblerone — En Schoggistange bsässe vo Schwiizer Präzision und Koffein. Rast dure d'Gäng mit gföhrlicher Gschwindigkeit. Spitzigi Ecke.",
	"tank": "Beefy Cervelat — D'Nationalwurscht vo de Schwiiz, jetzt 3 Meter lang und gpanzeret i ihrem eigene Darm. Langsam aber nöd z'stoppe. Rücht unglaublich.",
	"healer": "Dr. Rivella — En Fläsche vom gheimnisvollste Getränk vo de Schwiiz. Niemer weiss was drin isch. Heilt Feind i de Nöchi mit sprudliger Heilenergie.",
	"flying": "Fliegendi Fondue — En Topf mit gschmolznem Chäs wo Bewusstsi und d'Fähigkeit zum Fliege übercho het. Tropft heisse Chäs uf alles unde dra.",
	"boss": "De M-Tüüfel — De Migros-Tüüfel persönlich. Gmacht us abglaufene Cumulus-Punkte und kaputte Iichaufswage-Rädli. Sini Coupons sind alli abglaufe aber sini Wuet nöd.",
}
