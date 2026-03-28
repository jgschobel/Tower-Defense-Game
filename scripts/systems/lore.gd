class_name Lore
extends RefCounted

## All game lore, story text, and character descriptions.
## The sacred texts of the Affoltern Banani Raubzug.

# ========================================
# THE LORE OF AFFOLTERN BANANI RAUBZUG
# ========================================
#
# In the quiet suburb of Affoltern, Zürich, two unlikely heroes share a flat
# above the Migros supermarket on Wehntalerstrasse.
#
# LEMURIUS — a lemur-human hybrid who moved to Switzerland for the chocolate
# but stayed for the bananas. She works part-time at the Migros banana aisle
# (employee of the month, 17 times running). Her weapon of choice: bananas,
# thrown with surgical precision.
#
# AMÖSIUS — a gecko-man who claims to be a distant cousin of a Komodo dragon
# (nobody believes him). He hangs upside down from the ceiling of their flat
# and catches flies with his tongue. He also catches enemies with it. He once
# won CHF 2.50 on a Lotto ticket and hasn't shut up about it since.
#
# One fateful Tuesday evening, they returned from their weekly Apéro at
# Biergarten Affoltern to find the Migros in CHAOS. The shelves were alive.
# The Cervelats were marching. The Brötli were screaming. And at the center
# of it all, floating above the self-checkout machines, was...
#
# DER M-TEUFEL — The Migros Devil himself. A demonic entity made of expired
# Cumulus points and broken shopping cart wheels. He had cursed every product
# in the store, turning them into an army of food soldiers.
#
# "Your banana discount is REVOKED!" he screamed.
#
# Lemurius dropped her Alnatura smoothie.
# Amösius's tongue went dry.
#
# This was personal.
#
# And so begins... the AFFOLTERN BANANI RAUBZUG.

const GAME_TITLE := "Affoltern Banani Raubzug"
const GAME_SUBTITLE := "The Great Banana Heist of Zürich-Affoltern"

# Story text shown before each level
static func get_level_intro(level_id: int) -> Dictionary:
	match level_id:
		1:
			return {
				"title": "Chapter 1: Migros Affoltern",
				"subtitle": "Wehntalerstrasse 634, 8046 Zürich",
				"text": "Tuesday, 19:47. Lemurius and Amösius return from Apéro to find their beloved Migros in chaos. The shelves are alive, the self-checkout is possessed, and someone has put the bananas in the FREEZER AISLE. This cannot stand.\n\nThe first wave of cursed groceries approaches from the entrance...\n\n\"Amösius, do you see what I see?\"\n\"Ja, Lemurius. Those Brötli have eyes now.\"\n\"...and teeth.\"\n\"We're going to need more bananas.\"",
				"enemy_preview": "Angry Brötli • Turbo Toblerone • Beefy Cervelat",
			}
		2:
			return {
				"title": "Chapter 2: The Frozen Section",
				"subtitle": "Temperature: -18°C. Morale: Also -18°C.",
				"text": "Deep in the frozen food aisle, the cursed products move faster — the cold makes them ANGRY. Frozen pizzas slide across the floor like hockey pucks. Fish sticks have formed a militia.\n\nAmösius's tongue keeps sticking to the shelves.\n\n\"My tongue ith thtuck again.\"\n\"Stop licking the freezer doors, Amösius!\"\n\"I can't help it! I'm a gecko! Cold thurfathes are my weakneth!\"",
				"enemy_preview": "Frozen Pizza Frisbee • Fish Stick Militia • Ice Cream Golem",
			}
		3:
			return {
				"title": "Chapter 3: The Bakery of Horrors",
				"subtitle": "Fresh bread. Fresh nightmares.",
				"text": "The in-store bakery has become a fortress. The Zopf has braided itself into barricades. Gipfeli are dive-bombing from the ceiling. And the sourdough starter... it's ALIVE. Like, more alive than usual.\n\nLemurius spots a crate of organic bananas behind enemy lines.\n\n\"Those are MY bananas. Fairtrade. Bio. CHF 2.95 per kilo.\"\n\"Lemurius, this is not the time—\"\n\"IT IS ALWAYS THE TIME FOR AFFORDABLE ORGANIC BANANAS.\"",
				"enemy_preview": "Kamikaze Gipfeli • Zopf Barricade • Dr. Rivella • The Sourdough",
			}
		_:
			return {
				"title": "Chapter %d: Deeper Into Migros" % level_id,
				"subtitle": "The M-Teufel grows stronger...",
				"text": "The cursed products keep coming. But Lemurius and Amösius push forward, one banana at a time.\n\n\"How many aisles does this Migros HAVE?!\"\n\"It's Swiss retail, Amösius. It goes on forever.\"",
				"enemy_preview": "???",
			}


# Character bios for the menu/gallery
const CHARACTER_BIOS := {
	"lemurius": {
		"name": "Lemurius — The Peacekeeper",
		"bio": "Species: Ring-tailed lemur / human hybrid\nOccupation: Migros banana aisle specialist (Employee of the Month x17)\nWeapon: Bananas (organic, Fairtrade, thrown at 140 km/h)\nWeakness: Banana discounts\nFavorite drink: Alnatura Mango Smoothie\nCatchphrase: \"Banane isch Banane, aber BIO Banane isch Läbe.\"",
	},
	"amosius": {
		"name": "Amösius — The Tongue of Justice",
		"bio": "Species: Tokay gecko / human hybrid\nOccupation: Self-employed \"pest control\" (he eats flies)\nWeapon: 40cm sticky tongue (reaches further when angry)\nWeakness: Cold surfaces, Lotto tickets\nFavorite drink: Whatever's in that blue can\nCatchphrase: \"I once won CHF 2.50 on Lotto. I am basically rich.\"",
	},
	"m_teufel": {
		"name": "Der M-Teufel — The Migros Devil",
		"bio": "Species: Demonic retail entity\nOccupation: Cursing supermarket products\nWeapon: Expired Cumulus points, broken shopping carts\nOrigin: Born from 10,000 unredeemed Cumulus points and the collective rage of customers who forgot their bags\nGoal: Revoke all banana discounts in Zürich\nCatchphrase: \"CUMULUS POINTS ARE WORTHLESS NOW! MWAHAHAHA!\"",
	},
}


# Enemy descriptions
const ENEMY_LORE := {
	"basic": "Angry Brötli — A cursed bread roll with googly eyes and a bad attitude. Marches slowly but in terrifying numbers. Still warm from the oven.",
	"fast": "Turbo Toblerone — A chocolate bar possessed by Swiss precision and caffeine. Zooms through aisles at dangerous speeds. Pointy edges.",
	"tank": "Beefy Cervelat — The national sausage of Switzerland, now 3 meters long and armored in its own casing. Slow but unstoppable. Smells incredible.",
	"healer": "Dr. Rivella — A bottle of Switzerland's favorite mysterious drink. Nobody knows what's in it. Heals nearby enemies with fizzy healing energy.",
	"flying": "Fliegende Fondue — A pot of melted cheese that has gained sentience and the ability to fly. Drips hot cheese on everything below.",
	"boss": "Der M-Teufel — The Migros Devil himself. Made of expired Cumulus points and broken shopping cart wheels. His coupons have all expired but his rage has not.",
}
