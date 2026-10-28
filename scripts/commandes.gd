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
	"recommencer": {"touches": [KEY_R], "bouton": JOY_BUTTON_START},
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
