extends Control
## Menu de pause d'une course : Start sur la manette, Échap au clavier.
##
## Le jeu s'arrête (get_tree().paused) tant qu'il est ouvert. On y trouve :
## reprendre, recommencer, le style de conduite (d'origine ou « glisse »,
## changé tout de suite, sans relancer la course), le guide des commandes
## et le retour au menu de démarrage.
## Start, Échap ou B referment le menu.

const SCENE_MENU := "res://scenes/menu_principal.tscn"

var vehicule: Vehicule  ## donné par le HUD

var _g: Node  # l'autoload des réglages
var _reprendre: Button
var _bouton_conduite: Button
var _bouton_guide: Button
var _bouton_manette: Button
var _bouton_texte: Button
var _defilement: ScrollContainer
var _colonne: VBoxContainer
var _explication: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # il doit marcher pendant la pause
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_g = get_node("/root/Graphismes")

	var voile := ColorRect.new()
	voile.color = Color(0.02, 0.01, 0.04, 0.72)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	# Le menu défile si le texte est trop grand pour l'écran ; la manette suit le bouton choisi.
	_defilement = ScrollContainer.new()
	_defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_defilement.follow_focus = true
	centre.add_child(_defilement)
	_colonne = VBoxContainer.new()
	_colonne.custom_minimum_size = Vector2(480.0, 0.0)
	_colonne.add_theme_constant_override("separation", 10)
	_defilement.add_child(_colonne)
	var colonne := _colonne

	var titre := Label.new()
	titre.text = "PAUSED"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 44)
	titre.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
	colonne.add_child(titre)

	_reprendre = _bouton(colonne, "Resume", fermer)
	_bouton(colonne, "Restart", _recommencer)
	colonne.add_child(HSeparator.new())
	_bouton_conduite = _bouton(colonne, "", _changer_conduite)
	_explication = Label.new()
	_explication.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_explication.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explication.custom_minimum_size = Vector2(480.0, 0.0)
	_explication.add_theme_font_size_override("font_size", 15)
	_explication.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	colonne.add_child(_explication)
	_bouton_guide = _bouton(colonne, "", _changer_guide)
	_bouton_manette = _bouton(colonne, "", _changer_manette)
	_bouton_texte = _bouton(colonne, "", _changer_taille_texte)
	colonne.add_child(HSeparator.new())
	_bouton(colonne, "Main menu", _vers_le_menu)


func _input(event: InputEvent) -> void:
	# _input passe avant les boutons : Start / Échap ouvrent et ferment toujours le menu,
	# même si un bouton a le focus.
	if event.is_action_pressed("pause"):
		if visible:
			fermer()
		else:
			ouvrir()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		fermer()
		get_viewport().set_input_as_handled()


func ouvrir() -> void:
	visible = true
	get_tree().paused = true
	_actualiser()
	_ajuster_defilement()
	_reprendre.grab_focus()


## Hauteur de la zone qui défile : tout le menu s'il tient, sinon presque tout l'écran.
func _ajuster_defilement() -> void:
	var hauteur := minf(_colonne.get_combined_minimum_size().y, get_viewport_rect().size.y - 40.0)
	_defilement.custom_minimum_size = Vector2(_colonne.get_combined_minimum_size().x + 12.0, hauteur)


func fermer() -> void:
	visible = false
	get_tree().paused = false


## Comme la touche R : la voiture et le chrono écoutent l'action « recommencer ».
func _recommencer() -> void:
	fermer()
	Input.action_press("recommencer")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("recommencer")


func _changer_conduite() -> void:
	_g.conduite_glisse = not _g.conduite_glisse
	_g.sauvegarder()
	if vehicule != null:
		vehicule.mode_glisse = _g.conduite_glisse  # tout de suite, sans relancer la course
	_actualiser()


func _changer_guide() -> void:
	_g.afficher_guide = not _g.afficher_guide
	_g.sauvegarder()
	_actualiser()


## Passe au style de manette suivant : Auto, Xbox, Nintendo, PlayStation.
func _changer_manette() -> void:
	_g.style_manette = (_g.style_manette + 1) % Boutons.NOMS_STYLES.size()
	_g.sauvegarder()
	_actualiser()


## Passe à la taille de texte suivante : Normal, Large, Extra large.
func _changer_taille_texte() -> void:
	_g.taille_texte = (_g.taille_texte + 1) % _g.TAILLES_TEXTE.size()
	_g.appliquer_viewport()
	_g.sauvegarder()
	_actualiser()
	_ajuster_defilement.call_deferred()


func _vers_le_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_MENU)


func _actualiser() -> void:
	var glisse: bool = _g.conduite_glisse
	var style := Boutons.style_des_reglages(get_tree())
	_bouton_conduite.text = "Handling: %s" % ("Slide (Wipeout x Art of Rally)" if glisse else "Classic")
	_explication.text = ("Steer hard at speed to powerslide, no button needed. Boost (%s / Shift) in a slide to shoot where the nose points." % Boutons.nom("A", style)
			if glisse else "The original handling. Drift with %s / Space or by lifting off the throttle in a turn." % Boutons.nom("RB", style))
	_bouton_guide.text = "Controls guide: %s" % ("On" if _g.afficher_guide else "Off")
	var choisi: int = _g.style_manette
	var nom_style := Boutons.NOMS_STYLES[choisi]
	if choisi == Boutons.Style.AUTO:
		nom_style += " (%s)" % Boutons.NOMS_STYLES[style]  # ce qu'Auto a deviné
	_bouton_manette.text = "Controller buttons: %s" % nom_style
	_bouton_texte.text = "Text size: %s" % _g.NOMS_TAILLES_TEXTE[_g.taille_texte]


func _bouton(parent: Control, texte: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.custom_minimum_size = Vector2(0.0, 48.0)
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	return bouton
