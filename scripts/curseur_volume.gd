class_name CurseurVolume
extends HBoxContainer
## Une ligne de réglage de volume : le nom, un curseur de 0 à 100 % et la valeur.
##
## Sert dans le menu de démarrage et dans le menu de pause. Le réglage lui-même
## (volume_sfx, volume_musique) vit dans l'autoload Graphismes, qui l'applique aux
## bus audio « SFX » et « Music » et le sauvegarde.

var _g: Node = Engine.get_main_loop().root.get_node("Graphismes")  # l'autoload des réglages
var _reglage := ""
var _curseur := HSlider.new()
var _valeur := Label.new()
var _en_glissement := false  # vrai pendant qu'on tire le curseur à la souris


## nom_reglage : "volume_sfx" ou "volume_musique" (variables de Graphismes).
func preparer(texte: String, nom_reglage: String) -> void:
	_reglage = nom_reglage
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.add_theme_font_size_override("font_size", 18)
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(etiquette)
	_curseur.min_value = 0.0
	_curseur.max_value = 100.0
	_curseur.step = 5.0
	_curseur.custom_minimum_size = Vector2(200.0, 0.0)
	_curseur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_curseur.value_changed.connect(_sur_valeur)
	_curseur.drag_started.connect(func() -> void: _en_glissement = true)
	_curseur.drag_ended.connect(_sur_fin_glissement)
	add_child(_curseur)
	_valeur.custom_minimum_size = Vector2(56.0, 0.0)
	_valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_valeur)
	actualiser()


## Recopie le réglage actuel dans le curseur, sans déclencher de rappel.
func actualiser() -> void:
	_curseur.set_value_no_signal(roundf(float(_g.get(_reglage)) * 100.0))
	_valeur.text = "%d%%" % int(_curseur.value)


func _sur_valeur(pourcent: float) -> void:
	_g.set(_reglage, pourcent / 100.0)
	_g.appliquer_audio()
	_valeur.text = "%d%%" % int(pourcent)
	if not _en_glissement:
		_g.sauvegarder()  # flèches / manette : un pas = une sauvegarde


func _sur_fin_glissement(_change: bool) -> void:
	_en_glissement = false
	_g.sauvegarder()  # souris : on sauvegarde une seule fois, au lâcher
