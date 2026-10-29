class_name Boutons
extends RefCounted
## Noms et couleurs des boutons de manette selon le style choisi (idée reprise de Fuetazo).
##
## Les commandes sont liées à la POSITION des boutons, pas à leur lettre : le
## bouton du bas valide et booste, celui de droite revient en arrière, etc.
## Seuls les noms et les dessins changent d'une manette à l'autre, jamais les
## commandes. Dans le code, chaque position porte son nom Xbox (A = bas,
## B = droite, X = gauche, Y = haut, LB / RB, LT / RT, START, VIEW).
## Le style se choisit dans Settings (ou le menu de pause) ; « Auto » le devine
## d'après le nom de la manette.

enum Style { AUTO, XBOX, NINTENDO, PLAYSTATION }

const NOMS_STYLES: Array[String] = ["Auto", "Xbox", "Nintendo (Switch, AYN Thor...)", "PlayStation"]

## Position -> nom écrit sur le bouton, par style. (PlayStation : les symboles sont
## dessinés par le guide ; dans un texte, on écrit leur nom.)
const NOMS := {
	Style.XBOX: {"A": "A", "B": "B", "X": "X", "Y": "Y", "LB": "LB", "RB": "RB",
		"LT": "LT", "RT": "RT", "START": "Menu", "VIEW": "View"},
	Style.NINTENDO: {"A": "B", "B": "A", "X": "Y", "Y": "X", "LB": "L", "RB": "R",
		"LT": "ZL", "RT": "ZR", "START": "+", "VIEW": "−"},
	Style.PLAYSTATION: {"A": "Cross", "B": "Circle", "X": "Square", "Y": "Triangle", "LB": "L1", "RB": "R1",
		"LT": "L2", "RT": "R2", "START": "Options", "VIEW": "Create"},
}

## Couleur des boutons de face, par position. Nintendo : les couleurs de la Super
## Nintendo, celles des consoles rétro comme la Thor.
const COULEURS := {
	Style.XBOX: {"A": Color(0.42, 0.8, 0.3), "B": Color(0.95, 0.32, 0.3), "X": Color(0.3, 0.6, 1.0), "Y": Color(1.0, 0.78, 0.2)},
	Style.NINTENDO: {"A": Color(1.0, 0.82, 0.3), "B": Color(0.95, 0.3, 0.3), "X": Color(0.4, 0.85, 0.4), "Y": Color(0.4, 0.6, 1.0)},
	Style.PLAYSTATION: {"A": Color(0.5, 0.65, 1.0), "B": Color(1.0, 0.4, 0.4), "X": Color(0.95, 0.55, 0.85), "Y": Color(0.35, 0.85, 0.7)},
}


## Le style vraiment affiché : le choix du joueur, ou (Auto) celui deviné d'après la manette.
## « appareil » : la manette utilisée en dernier (-1 = la première branchée).
static func style_reel(choisi: int, appareil := -1) -> int:
	if choisi != Style.AUTO:
		return choisi
	if appareil < 0:
		var manettes := Input.get_connected_joypads()
		if manettes.is_empty():
			return Style.XBOX
		appareil = manettes[0]
	var nom := Input.get_joy_name(appareil).to_lower()
	for indice in ["nintendo", "switch", "pro controller", "joy-con"]:
		if nom.contains(indice):
			return Style.NINTENDO
	for indice in ["playstation", "dualsense", "dualshock", "ps4", "ps5", "sony"]:
		if nom.contains(indice):
			return Style.PLAYSTATION
	return Style.XBOX


## Le nom du bouton à cette position, pour ce style (déjà résolu, pas Auto).
static func nom(position: String, style: int) -> String:
	return NOMS.get(style, NOMS[Style.XBOX]).get(position, position)


static func couleur(position: String, style: int) -> Color:
	return COULEURS.get(style, COULEURS[Style.XBOX]).get(position, Color.WHITE)


## Le style résolu d'après les réglages (pratique pour les menus).
static func style_des_reglages(arbre: SceneTree) -> int:
	var reglages := arbre.root.get_node_or_null("Graphismes")
	return style_reel(reglages.style_manette if reglages != null else Style.AUTO)
