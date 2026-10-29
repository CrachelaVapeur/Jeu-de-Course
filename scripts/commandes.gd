extends Node
## Déclare les commandes du jeu (clavier + manette) au lancement.
##
## Ce script est chargé automatiquement (voir « autoload » dans project.godot).
## On utilise la position physique des touches : « W » désigne la touche en
## haut à gauche du pavé ZQSD, donc ça marche en AZERTY comme en QWERTY.

const COMMANDES := {
	"accelerer": {"touches": [KEY_W, KEY_UP], "axe": [JOY_AXIS_TRIGGER_RIGHT, 1.0]},
	"freiner": {"touches": [KEY_S, KEY_DOWN], "axe": [JOY_AXIS_TRIGGER_LEFT, 1.0]},
	"gauche": {"touches": [KEY_A, KEY_LEFT], "axe": [JOY_AXIS_LEFT_X, -1.0]},
	"droite": {"touches": [KEY_D, KEY_RIGHT], "axe": [JOY_AXIS_LEFT_X, 1.0]},
	"boost": {"touches": [KEY_SHIFT], "bouton": JOY_BUTTON_A},
	"deraper": {"touches": [KEY_SPACE, KEY_X], "bouton": JOY_BUTTON_RIGHT_SHOULDER},
	"recommencer": {"touches": [KEY_R]},  # sur manette : dans le menu de pause (Start)
	"camera": {"touches": [KEY_C], "bouton": JOY_BUTTON_Y},  # vue suivante (poursuite, lointaine, cockpit, capot)
	# Une vue directement : croix directionnelle ou touches 1 à 4.
	"vue_loin": {"touches": [KEY_1], "bouton": JOY_BUTTON_DPAD_UP},
	"vue_pres": {"touches": [KEY_2], "bouton": JOY_BUTTON_DPAD_RIGHT},
	"vue_cockpit": {"touches": [KEY_3], "bouton": JOY_BUTTON_DPAD_LEFT},
	"vue_capot": {"touches": [KEY_4], "bouton": JOY_BUTTON_DPAD_DOWN},
	"pause": {"touches": [KEY_ESCAPE], "bouton": JOY_BUTTON_START},  # menu de pause (voir menu_pause.gd)
	"carte": {"touches": [KEY_M], "bouton": JOY_BUTTON_BACK},  # carte du circuit (voir carte.gd)
}


func _ready() -> void:
	for nom in COMMANDES:
		var def: Dictionary = COMMANDES[nom]
		if not InputMap.has_action(nom):
			InputMap.add_action(nom, 0.2)  # 0.2 = zone morte des sticks

		for touche in def["touches"]:
			var ev_touche := InputEventKey.new()
			ev_touche.physical_keycode = touche
			InputMap.action_add_event(nom, ev_touche)

		if def.has("axe"):
			var ev_axe := InputEventJoypadMotion.new()
			ev_axe.axis = def["axe"][0]
			ev_axe.axis_value = def["axe"][1]
			InputMap.action_add_event(nom, ev_axe)

		if def.has("bouton"):
			var ev_bouton := InputEventJoypadButton.new()
			ev_bouton.button_index = def["bouton"]
			InputMap.action_add_event(nom, ev_bouton)

	# Menus à la manette : Godot ne met aucun bouton de manette dans « valider » ni « retour »
	# (seulement Entrée et Échap). Comme sur PC : le bouton du BAS valide (A Xbox, B Nintendo,
	# croix PlayStation), celui de DROITE revient en arrière (voir boutons.gd).
	for paire in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = paire[1]
		if not InputMap.action_has_event(paire[0], ev):
			InputMap.action_add_event(paire[0], ev)
