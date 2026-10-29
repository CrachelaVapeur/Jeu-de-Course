extends Control
## Écran de démarrage : choix de la course et réglages graphiques.
##
## Toute l'interface est construite par le code (pas de nœuds à placer à la
## main). Pour ajouter une course au menu, ajouter une ligne dans COURSES.

const COURSES := [
	{"nom": "Circuit 1", "detail": "the full 14.5 km circuit", "scene": "res://scenes/circuit_01.tscn"},
	{"nom": "Test circuit", "detail": "small test circuit", "scene": "res://scenes/circuit_essai.tscn"},
	{"nom": "Speed test", "detail": "endless straight, to feel the speed", "scene": "res://scenes/main.tscn"},
]

const NOMS_PREREGLAGES: Array[String] = ["Low", "Medium", "High"]
const NOMS_MSAA: Array[String] = ["Off", "2x", "4x"]
const NOMS_ECHELLES: Array[String] = ["50%", "67%", "75%", "100%"]

var _g: Node = Engine.get_main_loop().root.get_node("Graphismes")  # l'autoload des réglages
var _page_menu: VBoxContainer
var _page_reglages: VBoxContainer
var _liste_prereglages: OptionButton
var _liste_echelle: OptionButton
var _liste_msaa: OptionButton
var _liste_manette: OptionButton
var _liste_texte: OptionButton
var _defilement: ScrollContainer  # contient la page des réglages
var _aide: Label  # le mot d'aide en bas du menu (noms des boutons)
var _cases: Dictionary = {}  # nom du réglage -> CheckButton
var _en_chargement := false  # vrai pendant qu'on remplit l'interface (évite les rappels)


func _ready() -> void:
	# Manette : le bouton du bas valide, celui de droite revient en arrière (réglages de
	# Godot « ui_accept » / « ui_cancel »), quel que soit le nom écrit dessus (voir boutons.gd).
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fond := ColorRect.new()
	fond.color = Color(0.05, 0.03, 0.09)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var colonne := VBoxContainer.new()
	colonne.custom_minimum_size = Vector2(520.0, 0.0)
	colonne.add_theme_constant_override("separation", 10)
	centre.add_child(colonne)

	var titre := Label.new()
	titre.text = "JEU DE COURSE"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 48)
	titre.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
	colonne.add_child(titre)

	_page_menu = VBoxContainer.new()
	_page_menu.add_theme_constant_override("separation", 10)
	colonne.add_child(_page_menu)
	# Les réglages défilent si l'écran est trop petit (grand texte sur l'AYN Thor) ;
	# la manette fait défiler toute seule jusqu'à la ligne choisie.
	_defilement = ScrollContainer.new()
	_defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_defilement.follow_focus = true
	colonne.add_child(_defilement)
	_page_reglages = VBoxContainer.new()
	_page_reglages.add_theme_constant_override("separation", 10)
	_page_reglages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_defilement.add_child(_page_reglages)

	_construire_page_menu()
	_construire_page_reglages()
	_montrer_page(_page_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _defilement.visible:
		_montrer_page(_page_menu)
		get_viewport().set_input_as_handled()


func _construire_page_menu() -> void:
	var sous_titre := _etiquette("Pick a race", 22, HORIZONTAL_ALIGNMENT_CENTER)
	_page_menu.add_child(sous_titre)
	for course in COURSES:
		var bouton := _bouton("%s  -  %s" % [course["nom"], course["detail"]])
		bouton.pressed.connect(_lancer.bind(course["scene"]))
		_page_menu.add_child(bouton)
	_page_menu.add_child(HSeparator.new())
	var reglages := _bouton("Settings")
	reglages.pressed.connect(func() -> void: _montrer_page(_page_reglages))
	_page_menu.add_child(reglages)
	# Pas de « Quit » sur téléphone / console Android : Godot y tue le jeu, le système le
	# relance aussitôt en arrière-plan sans fenêtre, et le lanceur de l'AYN Thor ne peut
	# plus l'ouvrir depuis son icône. On quitte avec le bouton Home, comme les autres jeux.
	if not OS.has_feature("mobile"):
		var quitter := _bouton("Quit")
		quitter.pressed.connect(func() -> void: get_tree().quit())
		_page_menu.add_child(quitter)
	_aide = _etiquette("", 16, HORIZONTAL_ALIGNMENT_CENTER)
	_page_menu.add_child(_aide)
	_actualiser_aide()


## Le mot d'aide en bas du menu, avec les noms des boutons de la manette choisie.
func _actualiser_aide() -> void:
	var style := Boutons.style_des_reglages(get_tree())
	_aide.text = "Confirm: %s / Enter    Back: %s / Esc\nIn a race: %s / Esc = pause menu,  %s / M = map" % [
		Boutons.nom("A", style), Boutons.nom("B", style), Boutons.nom("START", style), Boutons.nom("VIEW", style)]


func _construire_page_reglages() -> void:
	_page_reglages.add_child(_etiquette("Settings", 22, HORIZONTAL_ALIGNMENT_CENTER))
	_page_reglages.add_child(_etiquette("Low is made for weak laptops. High is the original look.", 16, HORIZONTAL_ALIGNMENT_CENTER))

	_liste_prereglages = OptionButton.new()
	for nom in NOMS_PREREGLAGES:
		_liste_prereglages.add_item(nom)
	_liste_prereglages.add_item("Custom")
	_liste_prereglages.item_selected.connect(_sur_prereglage)
	_page_reglages.add_child(_ligne("Preset", _liste_prereglages))

	_liste_echelle = OptionButton.new()
	for nom in NOMS_ECHELLES:
		_liste_echelle.add_item(nom)
	_liste_echelle.item_selected.connect(_sur_echelle)
	_page_reglages.add_child(_ligne("3D resolution (lower = faster)", _liste_echelle))

	_liste_msaa = OptionButton.new()
	for nom in NOMS_MSAA:
		_liste_msaa.add_item(nom)
	_liste_msaa.item_selected.connect(_sur_msaa)
	_page_reglages.add_child(_ligne("Anti-aliasing", _liste_msaa))

	_ajouter_case("ombres", "Shadows")
	_ajouter_case("glow", "Glow (bloom)")
	_ajouter_case("contours", "Outlines (speed test)")
	_ajouter_case("effets", "Speed lines and tunnel vision")
	_liste_manette = OptionButton.new()
	for nom in Boutons.NOMS_STYLES:
		_liste_manette.add_item(nom)
	_liste_manette.item_selected.connect(_sur_manette)
	_page_reglages.add_child(_ligne("Controller buttons", _liste_manette))

	_liste_texte = OptionButton.new()
	for nom in _g.NOMS_TAILLES_TEXTE:
		_liste_texte.add_item(nom)
	_liste_texte.item_selected.connect(_sur_taille_texte)
	_page_reglages.add_child(_ligne("Text size", _liste_texte))

	_ajouter_case("conduite_glisse", "Slide handling (test: Wipeout x Art of Rally)")
	_ajouter_case("afficher_guide", "Controls guide (top left)")
	_ajouter_case("afficher_fps", "Show FPS counter")

	var retour := _bouton("Back")
	retour.pressed.connect(func() -> void: _montrer_page(_page_menu))
	_page_reglages.add_child(retour)


func _ajouter_case(nom: String, texte: String) -> void:
	var case := CheckButton.new()
	case.toggled.connect(_sur_case.bind(nom))
	_cases[nom] = case
	_page_reglages.add_child(_ligne(texte, case))


func _montrer_page(page: Control) -> void:
	_page_menu.visible = page == _page_menu
	_defilement.visible = page == _page_reglages
	if page == _page_reglages:
		_remplir_reglages()
		_ajuster_defilement()
		_liste_prereglages.grab_focus()
	else:
		(_page_menu.get_child(1) as Button).grab_focus()


## Hauteur de la zone qui défile : toute la page si elle tient, sinon l'écran moins le titre.
func _ajuster_defilement() -> void:
	var disponible := get_viewport_rect().size.y - 120.0
	_defilement.custom_minimum_size.y = minf(_page_reglages.get_combined_minimum_size().y, disponible)


## Copie les réglages actuels dans les contrôles, sans déclencher les rappels.
func _remplir_reglages() -> void:
	_en_chargement = true
	var actuel: int = _g.prereglage_actuel()
	_liste_prereglages.select(actuel if actuel >= 0 else NOMS_PREREGLAGES.size())
	_liste_echelle.select(_indice_echelle(_g.echelle))
	_liste_msaa.select(_g.msaa)
	_liste_manette.select(_g.style_manette)
	_liste_texte.select(_g.taille_texte)
	for nom in _cases:
		(_cases[nom] as CheckButton).button_pressed = _g.get(nom)
	_en_chargement = false


func _indice_echelle(valeur: float) -> int:
	var meilleur := 0
	for i in _g.ECHELLES.size():
		if absf(_g.ECHELLES[i] - valeur) < absf(_g.ECHELLES[meilleur] - valeur):
			meilleur = i
	return meilleur


func _sur_prereglage(indice: int) -> void:
	if _en_chargement or indice >= NOMS_PREREGLAGES.size():
		return
	_g.appliquer_prereglage(indice)
	_remplir_reglages()


func _sur_echelle(indice: int) -> void:
	if _en_chargement:
		return
	_g.echelle = _g.ECHELLES[indice]
	_valider_reglages()


func _sur_msaa(indice: int) -> void:
	if _en_chargement:
		return
	_g.msaa = indice
	_valider_reglages()


func _sur_manette(indice: int) -> void:
	if _en_chargement:
		return
	_g.style_manette = indice
	_g.sauvegarder()
	_actualiser_aide()


func _sur_taille_texte(indice: int) -> void:
	if _en_chargement:
		return
	_g.taille_texte = indice
	_valider_reglages()
	_ajuster_defilement.call_deferred()  # l'écran « rétrécit » : la zone qui défile aussi


func _sur_case(active: bool, nom: String) -> void:
	if _en_chargement:
		return
	_g.set(nom, active)
	_valider_reglages()


func _valider_reglages() -> void:
	_g.appliquer_viewport()
	_g.sauvegarder()
	_remplir_reglages()  # met à jour la case « Preset » (Custom si plus aucun ne correspond)


func _lancer(chemin: String) -> void:
	get_tree().change_scene_to_file(chemin)


# --- Petits outils d'interface ----------------------------------------------

func _bouton(texte: String) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.custom_minimum_size = Vector2(0.0, 48.0)
	return bouton


func _etiquette(texte: String, taille: int, alignement: HorizontalAlignment) -> Label:
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.horizontal_alignment = alignement
	etiquette.add_theme_font_size_override("font_size", taille)
	return etiquette


func _ligne(texte: String, controle: Control) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	var etiquette := _etiquette(texte, 18, HORIZONTAL_ALIGNMENT_LEFT)
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(etiquette)
	ligne.add_child(controle)
	return ligne
