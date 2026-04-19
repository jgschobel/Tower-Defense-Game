class_name Lore
extends RefCounted

## All game lore, story text, and character descriptions.
## D'heilige Schrifte vom Affoltern Banani Raubzug.

const GAME_TITLE := "Affoltern Banani Raubzug"
const GAME_SUBTITLE := "De Grooss Banane-Raubzug vo Züri-Affoltern"

static func get_level_intro(level_id: int) -> Dictionary:
	# Kept tight per user feedback — no fluff, one punchy beat per page.
	match level_id:
		1:
			return {
				"title": "Kapitel 1: Migros Affoltern",
				"subtitle": "19:47. Chaos im Laden.",
				"text": "D'Regäl sind läbig. D'Banane isch ide Tiefchüel-Abteilig. Das gaht gar nöd.\n\n\"Amösius — die Brötli händ Auge.\"\n\"...und Zähn.\"\n\"Mir bruuched meh Banane.\"",
				"enemy_preview": "Bösi Brötli • Turbo Toblerone • Beefy Cervelat",
			}
		2:
			return {
				"title": "Kapitel 2: D'Tiefchüel-Abteilig",
				"subtitle": "-18°C. Produkt aggressiv.",
				"text": "Gfrorni Pizza rutschet wie Hockey-Pucks. Fischstäbli händ es Militär.\n\n\"Mini Zunge isch a de Gfrüürer-Türe fescht!\"\n\"Hör uf z'schlecke, Amösius!\"",
				"enemy_preview": "Gfrorni Pizza • Fischstäbli-Militär • Glacé-Golem",
			}
		3:
			return {
				"title": "Kapitel 3: D'Bäckerei vom Gruse",
				"subtitle": "De Suurteig läbt.",
				"text": "Zopf-Barrikade. Kamikaze-Gipfeli. De Suurteig LÄBT.\n\n\"Bio-Banane hinder de Feind. CHF 2.95 s'Kilo.\"\n\"Lemurius, jetzt isch nöd—\"\n\"ES ISCH IMMER DE MOMENT FÜR BIO-BANANE.\"",
				"enemy_preview": "Kamikaze-Gipfeli • Zopf-Barrikade • Dr. Rivella • De Suurteig",
			}
		4:
			return {
				"title": "Kapitel 4: D'Chäsi-Keller",
				"subtitle": "Es gärt im Undergrund.",
				"text": "Raclette-Bombe rollet dur de Gang. Fondue-Tröpfli bränned.\n\n\"De Tüüfel isch PERSÖNLICH da unde.\"\n\"Zwei vo denne?! Ich han nur EI Banane übrig!\"\n\"Wirf sie bio. Immer bio.\"",
				"enemy_preview": "Raclette-Bombe • Fondue-Wolke • Zwei Tüüfel • Chäs-Healer",
			}
		_:
			return {
				"title": "Kapitel %d: Tüüfer id Migros" % level_id,
				"subtitle": "De M-Tüüfel wird stärcher.",
				"text": "D'verfluechte Produkt chömed nöd zum ufhöre.\n\n\"Wieviel Gäng het die Migros?!\"\n\"S'isch Schwiizer Detailhandel. Das gaht ewig.\"",
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
	"kuehne": {
		"name": "Kühne — D'Bluemene-Magie",
		"bio": "Art: Wildi Blueme / Naturmagier-Hybrid\nBruef: Wildgarten-Wächterin, Pollen-Sommelier\nWaffe: Magische Pollen-Wölkli (verwirred Feind, slow-down Garantie)\nSchwächi: Heuschnupfe, Parfumerie-Gang\nLieblings-Getränk: Hollersirup mit Sprudel\nSpruch: \"D'Natur het immer es letschts Wort — i dem Fall es nieses.\"",
	},
	"jojo": {
		"name": "JoJo — De Chemie-Magier",
		"bio": "Art: Chaos-Wissenschaftler / Erlenmeyer-Liebhaber\nBruef: Sälbständig erforschi Reaktione (meistens au bi Regel)\nWaffe: Säure-Erlenmeyer-Flask, bliibendi Acid-Pool wo Feinde übergeht\nSchwächi: Gegestoff, pH-neutrali Diskussione\nLieblings-Getränk: Destilliert, mit ere Priise Manganat\nSpruch: \"Das isch nid es Problem, das isch en EXOTHERMI Lösig.\"",
	},
	"cordula": {
		"name": "Cordula — D'Fasnachts-Piratin",
		"bio": "Art: Fasnacht-Korsarin mit chronischem Party-Instinkt\nBruef: Kapitänin vom Chaos-Schiff \"D'Banani\"\nWaffe: Fasnachts-Volleyball (splash-bouncer — trifft sibe Feind mit eim Wurf)\nSchwächi: Konfetti-Überdosis, leise Bibliothekä\nLieblings-Getränk: Ovo-Pudel mit Limetti-Zest\nSpruch: \"Wenn de Ball zruggchunnt, gwönned beidi Parteie.\"",
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
