class_name Lore
extends RefCounted

## All game lore, story text, and character descriptions.
## D'heilige Schrifte vom Affoltern Banani Raubzug.

const GAME_TITLE := "Affoltern Banani Raubzug"
const GAME_SUBTITLE := "De Grooss Banane-Raubzug vo Züri-Affoltern"

## Multi-page dialogue scaffolding (ROADMAP #47). Each level can now
## provide a `pages` array (optional) in its intro dict. story_screen
## advances through them one tap at a time. Page = {speaker, text}
## where speaker rotates across the 5 friends + guest characters so
## the plot actually evolves instead of reading like one monologue.
##
## Falls back to the legacy single `text` field if `pages` is absent,
## so old levels still render. Migration is per-level, incremental.
static func get_level_pages(level_id: int) -> Array:
	var intro: Dictionary = get_level_intro(level_id)
	if intro.has("pages") and intro["pages"] is Array:
		return intro["pages"]
	# Legacy conversion: wrap the flat `text` block as a single page
	# spoken by Lemurius so the new UI has something to render.
	var legacy_text: String = intro.get("text", "")
	if legacy_text == "":
		return []
	return [{"speaker": "Lemurius", "text": legacy_text}]


static func get_level_intro(level_id: int) -> Dictionary:
	# Kept tight per user feedback — no fluff, one punchy beat per page.
	match level_id:
		1:
			return {
				"title": "Kapitel 1: Migros Affoltern",
				"subtitle": "19:47. Chaos im Laden.",
				"text": "D'Regäl sind läbig. D'Banane isch ide Tiefchüel-Abteilig. Das gaht gar nöd.\n\n\"Amösius — die Brötli händ Auge.\"\n\"...und Zähn.\"\n\"Mir bruuched meh Banane.\"",
				"enemy_preview": "Bösi Brötli • Turbo Toblerone • Beefy Cervelat",
				"pages": [
					{"speaker": "Lemurius", "text": "D'Regäl sind läbig. Öpper het d'Banane ide Tiefchüel-Abteilig versteckt. Das gaht gar nöd."},
					{"speaker": "Amösius", "text": "Lemurius — die Brötli händ Auge."},
					{"speaker": "Lemurius", "text": "...und Zähn."},
					{"speaker": "Cordula", "text": "Dä M-Tüüfel isch wider am Werch. Mir bruuched ä Plan."},
					{"speaker": "Lemurius", "text": "Ich han scho eine. Meh Banane."},
				],
			}
		2:
			return {
				"title": "Kapitel 2: D'Tiefchüel-Abteilig",
				"subtitle": "-18°C. Produkt aggressiv.",
				"text": "Gfrorni Pizza rutschet wie Hockey-Pucks. Fischstäbli händ es Militär.\n\n\"Mini Zunge isch a de Gfrüürer-Türe fescht!\"\n\"Hör uf z'schlecke, Amösius!\"",
				"enemy_preview": "Gfrorni Pizza • Fischstäbli-Militär • Glacé-Golem",
				"pages": [
					{"speaker": "Amösius", "text": "AAAH — mini Zunge isch a de Gfrüürer-Türe fescht!"},
					{"speaker": "Kühne", "text": "Amösius. S'het minus achzäh Grad. Hör uf z'schlecke."},
					{"speaker": "Amösius", "text": "Ich han nöd gschleckt. Ich han... probiert z'rieche."},
					{"speaker": "Lemurius", "text": "Gfrorni Pizza rutschet wie Hockey-Pucks. Fischstäbli händ es Militär gründet. Mir müend durch."},
					{"speaker": "JoJo", "text": "Faszinierend — dr Glacé-Golem schmilzt erst bi −12°C. Ich bruuch meh Chämi-Fläsche."},
					{"speaker": "Lemurius", "text": "Nacher. JETZT — LOS!"},
				],
			}
		3:
			return {
				"title": "Kapitel 3: D'Bäckerei vom Gruse",
				"subtitle": "De Suurteig läbt.",
				"text": "Zopf-Barrikade. Kamikaze-Gipfeli. De Suurteig LÄBT.\n\n\"Bio-Banane hinder de Feind. CHF 2.95 s'Kilo.\"\n\"Lemurius, jetzt isch nöd—\"\n\"ES ISCH IMMER DE MOMENT FÜR BIO-BANANE.\"",
				"enemy_preview": "Kamikaze-Gipfeli • Zopf-Barrikade • Dr. Rivella • De Suurteig",
				"pages": [
					{"speaker": "Lemurius", "text": "Zopf-Barrikade. Kamikaze-Gipfeli. Und de Suurteig... LÄBT."},
					{"speaker": "Kühne", "text": "Ich spür sini Energie. Uralti Hefe-Magie. 200 Jaar alt, mindischtens."},
					{"speaker": "Micheli", "text": "Halt! Nach Läde-schluss isch d'Bäckerei gesperrt. Iir chönd nöd ine!"},
					{"speaker": "Lemurius", "text": "Micheli — de Suurteig het s'Bewusstsie übercho. Er griift a."},
					{"speaker": "Micheli", "text": "...Ich ruf mim Vorgesetzte a. Aber schnell — ich han nur no 20 Minute uf de Schicht."},
					{"speaker": "JoJo", "text": "Bio-Banane hinder de Feind. CHF 2.95 s'Kilo."},
					{"speaker": "Lemurius", "text": "ES ISCH IMMER DE MOMENT FÜR BIO-BANANE."},
				],
			}
		4:
			return {
				"title": "Kapitel 4: D'Chäsi-Keller",
				"subtitle": "Es gärt im Undergrund.",
				"text": "Raclette-Bombe rollet dur de Gang. Fondue-Tröpfli bränned.\n\n\"De Tüüfel isch PERSÖNLICH da unde.\"\n\"Zwei vo denne?! Ich han nur EI Banane übrig!\"\n\"Wirf sie bio. Immer bio.\"",
				"enemy_preview": "Raclette-Bombe • Fondue-Wolke • Zwei Tüüfel • Chäs-Healer",
				"pages": [
					{"speaker": "Amösius", "text": "Rächt nach unde... es gärt. Und s'stinkt. Aber positiv."},
					{"speaker": "Lemurius", "text": "Raclette-Bombe. Fondue-Tröpfli wo bränned. De Tüüfel isch PERSÖNLICH da une."},
					{"speaker": "Cordula", "text": "Wart — ZWEI vo dene?! Ich han nur EI Volleyball!"},
					{"speaker": "Amösius", "text": "Ich han nur ei Zunge. Und die isch no chli gfrore vo vorhin."},
					{"speaker": "Lemurius", "text": "Mir händ genau was mir bruuched. Wirf bio. Immer bio."},
					{"speaker": "Cordula", "text": "Ich liebe die Crew."},
				],
			}
		5:
			return {
				"title": "Kapitel 5: D'Kasse — Endkampf",
				"subtitle": "Kasse 8 spukt. DREI Tüüfel.",
				"text": "D'Coupon-Tüüfel blocke de Uusgang. Cumulus-Punkte explodiered i de Luft.\n\n\"Dr Tüüfel het sich verDREIfacht!\"\n\"Cordula — Volleyball-Zeit.\"\n\"ENDLICH en gschider Endkampf.\"",
				"enemy_preview": "Coupon-Tüüfel • Quittige-Swarm • DREI Tüüfel zum Schluss",
				"pages": [
					{"speaker": "Lemurius", "text": "D'Coupon-Tüüfel blocke de Uusgang. Cumulus-Punkte explodiered i de Luft."},
					{"speaker": "Trudi", "text": "Achtung — Kasse 8 isch gschlossä wäge übernatürliche Zwischefäll. Bitte d'andere Kasse benütze."},
					{"speaker": "Cordula", "text": "Trudi! Du häsch us scho immer uf de Schnellchasse ine gloh — au mit 12 Artikle statt 10."},
					{"speaker": "Trudi", "text": "Mir sind Kolleginne. Aber dr Tüüfel zahlt trotzdem volle Priis."},
					{"speaker": "Lemurius", "text": "Dr Tüüfel het sich verDREIfacht!"},
					{"speaker": "Cordula", "text": "Volleyball-Zeit."},
					{"speaker": "Trudi", "text": "ENDLICH en gschider Endkampf. Ich wart scho dr ganz Abig druf."},
				],
			}
		6:
			return {
				"title": "Bonus: S'Parkhuus",
				"subtitle": "Neon. Beton. 5 Tüüfel.",
				"text": "Mir händ dänkt mir sind dure. Falsch.\n\n\"Im Parkhuus? Ernschthaft?\"\n\"Fünf Tüüfel. Bringed eui Cumulus-Karte, wär bruuched Glück.\"\n\"Ich han mini no!\"\n\"Amösius, din Cumulus isch abglaufe sit 2011.\"",
				"enemy_preview": "FÜNF Tüüfel • Schwärm • Alles uf einisch",
				"pages": [
					{"speaker": "Kühne", "text": "Im Parkhuus? Ernschthaft? D'Neon-Energie tötet mini Blueme."},
					{"speaker": "Amösius", "text": "Fünf Tüüfel. Ich zelle sie. Einer... zwei... ja. Fünf."},
					{"speaker": "Lemurius", "text": "Bring dini Cumulus-Karte. Wär bruuched Glück."},
					{"speaker": "Amösius", "text": "Mini isch no gültig! Ich han si 2011 ernüüret... glaub ich."},
					{"speaker": "Kühne", "text": "Amösius. Dini Cumulus isch abglaufe sit 2011."},
					{"speaker": "Amösius", "text": "...Ich kämpf trotzdem. Für d'Punkte."},
				],
			}
		7:
			return {
				"title": "Kapitel 7: S'Dach",
				"subtitle": "Wind. Mööwe. Neon.",
				"text": "De Tüüfel flüücht aufs Dach. D'Affoltner Skyline bränned im Sunneunergang.\n\n\"Warum flüüchtemer immer uf d'Dächer?\"\n\"Cordula, dis Segel!\"\n\"Ich han kes Segel, ich han en Volleyball.\"\n\"...funktioniert au.\"",
				"enemy_preview": "Flüügend alles • 4 Tüüfel • Fondue-Bomben vom Himmel",
				"pages": [
					{"speaker": "Lemurius", "text": "De Tüüfel flüücht aufs Dach. D'Affoltner Skyline bränned im Sunneunergang."},
					{"speaker": "JoJo", "text": "Warum flüüchtemer immer uf d'Dächer? Statistisch isch das en schlechti Strategie."},
					{"speaker": "Lemurius", "text": "Cordula — dis Segel!"},
					{"speaker": "Cordula", "text": "Ich han kes Segel. Ich han en Volleyball."},
					{"speaker": "JoJo", "text": "...funktioniert au."},
					{"speaker": "Lemurius", "text": "Letzti Wäll. Für d'Banane vo Affoltern — LOS!"},
				],
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
	"swarm": "Tofu-Schwarm — Chliini Tofu-Würfli wo i Rudel marschiered. Einzeln harmlos, zäme en echti Bedrohig. Härdi Viganer füegend immer meh derzue.",
	"basic": "Bösi Brötli — Es verfluechts Brötli mit Guggelauge und ere schlechte Laune. Marschiert langsam aber i grusige Zahl. No warm vom Ofe.",
	"fast": "Turbo Toblerone — En Schoggistange bsässe vo Schwiizer Präzision und Koffein. Rast dure d'Gäng mit gföhrlicher Gschwindigkeit. Spitzigi Ecke.",
	"tank": "Beefy Cervelat — D'Nationalwurscht vo de Schwiiz, jetzt 3 Meter lang und gpanzeret i ihrem eigene Darm. Langsam aber nöd z'stoppe. Rücht unglaublich.",
	"healer": "Dr. Rivella — En Fläsche vom gheimnisvollste Getränk vo de Schwiiz. Niemer weiss was drin isch. Heilt Feind i de Nöchi mit sprudliger Heilenergie.",
	"flying": "Fliegendi Fondue — En Topf mit gschmolznem Chäs wo Bewusstsi und d'Fähigkeit zum Fliege übercho het. Tropft heisse Chäs uf alles unde dra.",
	"boss": "De M-Tüüfel — De Migros-Tüüfel persönlich. Gmacht us abglaufene Cumulus-Punkte und kaputte Iichaufswage-Rädli. Sini Coupons sind alli abglaufe aber sini Wuet nöd.",
}
