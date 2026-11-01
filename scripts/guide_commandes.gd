extends Control
## Guide des commandes dans le coin du HUD (idée reprise de Fuetazo, le jeu de Maximo).
##
## Deux colonnes, comme les deux mains sur la manette : à gauche ce qu'on fait
## de la main gauche, à droite de la main droite. Chaque bouton est dessiné par
## le code (pas d'image) avec son mot ; il s'allume tant qu'on le tient.
## Le guide montre la manette ou le clavier selon ce qu'on a touché en dernier,
## et s'atténue après une minute de jeu pour ne pas gêner.
## Il se coupe dans Settings > Controls guide (ou le menu de pause).
## Les noms et couleurs des boutons suivent la manette choisie dans Settings >
## Controller buttons (Xbox, Nintendo, PlayStation, ou Auto) : voir boutons.gd.

const ICONE := 34.0  ## taille d'un bouton, en pixels
const ECART := 10.0  ## entre un bouton et son mot
const LIGNE := 42.0  ## hauteur d'une ligne
const COLONNE := 215.0  ## largeur d'une colonne
const MARGE := 12.0  ## bord du panneau
const TAILLE_TEXTE := 17
const ATTENUER_APRES := 60.0  ## secondes de jeu avant d'atténuer le guide
const ALPHA_ATTENUE := 0.45

const TEXTE := Color(1.0, 0.97, 0.92)
const TEXTE_APPUYE := Color(1.0, 0.85, 0.35)
const CONTOUR := Color(0.03, 0.01, 0.05)
const FOND_PANNEAU := Color(0.04, 0.02, 0.07, 0.5)
const FOND_BOUTON := Color(0.1, 0.09, 0.14, 0.92)
const BORD_BOUTON := Color(0.85, 0.85, 0.92)
const ALLUME := Color(0.3, 0.9, 1.0)  ## couleur d'un bouton tenu (néon du jeu)

## Les quatre vues de caméra (croix directionnelle ou touches 1 à 4), dans l'ordre haut, droite, gauche, bas.
const VUES: Array[String] = ["vue_loin", "vue_pres", "vue_cockpit", "vue_capot"]

# Chaque ligne : [actions qui allument le bouton, bouton, mot affiché].
# Les boutons de manette sont désignés par leur position, avec le nom Xbox (voir boutons.gd).
const MANETTE_GAUCHE := [
	[["freiner"], "LT", "Brake / reverse"],
	[["gauche", "droite"], "LS", "Steer"],
	[VUES, "DPAD", "Views"],
	[["carte"], "VIEW", "Map"],
]
const MANETTE_DROITE := [
	[["accelerer"], "RT", "Accelerate"],
	[["deraper"], "RB", "Drift"],
	[["boost"], "A", "Boost"],
	[["camera"], "Y", "Camera"],
	[["pause"], "START", "Pause"],
]
const CLAVIER_GAUCHE := [
	[["accelerer"], "W", "Accelerate"],
	[["freiner"], "S", "Brake / reverse"],
	[["gauche", "droite"], "A  D", "Steer"],
	[["boost"], "Shift", "Boost"],
	[VUES, "1-4", "Views"],
]
const CLAVIER_DROITE := [
	[["deraper"], "Space", "Drift"],
	[["camera"], "C", "Camera"],
	[["recommencer"], "R", "Restart"],
	[["carte"], "M", "Map"],
	[["pause"], "Esc", "Pause"],
]

var _manette := false  # vrai : on montre la manette, faux : le clavier
var _appareil := -1  # la manette utilisée en dernier (pour deviner son style en mode Auto)
var _style_affiche := Boutons.Style.XBOX  # recalculé à chaque image (le réglage peut changer)
var _temps := 0.0
var _police: Font
var _g: Node  # l'autoload des réglages


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_police = ThemeDB.fallback_font
	_g = get_node("/root/Graphismes")
	_manette = not Input.get_connected_joypads().is_empty()


func _input(event: InputEvent) -> void:
	var manette := _manette
	if event is InputEventKey:
		manette = false
	elif event is InputEventJoypadButton:
		manette = true
		_appareil = event.device
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4:
		manette = true
		_appareil = event.device
	if manette != _manette:
		_manette = manette
		_temps = 0.0  # nouvel appareil : on remontre le guide en entier


func _process(delta: float) -> void:
	visible = _g.afficher_guide
	if not visible:
		return
	_temps += delta
	modulate.a = ALPHA_ATTENUE if _temps > ATTENUER_APRES else 1.0
	position = Vector2(16.0, 44.0 if _g.afficher_fps else 16.0)  # sous le compteur de FPS s'il est affiché
	# Avec un grand texte (Settings > Text size), le guide grandit moins que le reste
	# (racine carrée de l'agrandissement) pour ne pas cacher la route.
	scale = Vector2.ONE / sqrt(get_tree().root.content_scale_factor)
	_style_affiche = Boutons.style_reel(_g.style_manette, _appareil)
	queue_redraw()  # les boutons s'allument quand on les tient


func _draw() -> void:
	var gauche: Array = MANETTE_GAUCHE if _manette else CLAVIER_GAUCHE
	var droite: Array = MANETTE_DROITE if _manette else CLAVIER_DROITE
	var lignes := maxi(gauche.size(), droite.size())
	var panneau := StyleBoxFlat.new()
	panneau.bg_color = FOND_PANNEAU
	panneau.set_corner_radius_all(14)
	draw_style_box(panneau, Rect2(Vector2.ZERO, Vector2(MARGE * 2.0 + COLONNE * 2.0, MARGE * 2.0 + lignes * LIGNE - (LIGNE - ICONE))))
	for i in gauche.size():
		_ligne(Vector2(MARGE, MARGE + i * LIGNE), gauche[i])
	for i in droite.size():
		_ligne(Vector2(MARGE + COLONNE, MARGE + i * LIGNE), droite[i])


## Un bouton et son mot, en haut à gauche à « pos ».
func _ligne(pos: Vector2, entree: Array) -> void:
	var appuye := false
	for action: String in entree[0]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			appuye = true
	var bouton: String = entree[1]
	var largeur := _bouton_manette(pos, bouton, appuye) if _manette else _touche(pos, bouton, appuye)
	# Les mots commencent tous au même endroit dans une colonne, même si les boutons n'ont pas la même largeur.
	var base := pos + Vector2(maxf(largeur, ICONE * 1.55) + ECART, ICONE * 0.5 + TAILLE_TEXTE * 0.36)
	draw_string_outline(_police, base, entree[2], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_TEXTE, 6, CONTOUR)
	draw_string(_police, base, entree[2], HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE_TEXTE, TEXTE_APPUYE if appuye else TEXTE)


## Une touche de clavier (capuchon arrondi, aussi large que son nom). Renvoie sa largeur.
func _touche(pos: Vector2, nom: String, appuye: bool) -> float:
	var largeur := maxf(ICONE, _police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0)
	var style := _style(appuye, BORD_BOUTON, 7)
	style.border_width_bottom = 4  # l'épaisseur du capuchon
	draw_style_box(style, Rect2(pos, Vector2(largeur, ICONE)))
	_texte_centre(pos + Vector2(largeur * 0.5, ICONE * 0.45), nom, 15, appuye)
	return largeur


## Un bouton de manette, dessiné selon sa forme. Renvoie sa largeur.
func _bouton_manette(pos: Vector2, nom: String, appuye: bool) -> float:
	var centre := pos + Vector2(ICONE * 0.5, ICONE * 0.5)
	var style_manette := _style_affiche
	var affiche := Boutons.nom(nom, style_manette)
	match nom:
		"A", "B", "X", "Y":
			# Bouton de face : un rond avec sa lettre (ou son symbole PlayStation), dans sa couleur.
			var couleur := Boutons.couleur(nom, style_manette)
			draw_circle(centre, ICONE * 0.5, couleur if appuye else FOND_BOUTON)
			draw_arc(centre, ICONE * 0.5 - 1.0, 0.0, TAU, 32, couleur, 2.5, true)
			if style_manette == Boutons.Style.PLAYSTATION:
				_symbole_playstation(centre, nom, CONTOUR if appuye else couleur)
			else:
				_texte_centre(centre, affiche, 17, appuye, couleur)
			return ICONE
		"LT", "RT":
			# Gâchette : plus large, arrondie en haut.
			var style := _style(appuye, BORD_BOUTON, 5)
			style.corner_radius_top_left = 14
			style.corner_radius_top_right = 14
			draw_style_box(style, Rect2(pos, Vector2(ICONE * 1.3, ICONE)))
			_texte_centre(pos + Vector2(ICONE * 0.65, ICONE * 0.55), affiche, 14, appuye)
			return ICONE * 1.3
		"RB", "LB":
			# Bouton de tranche : une pilule plate.
			var style := _style(appuye, BORD_BOUTON, 12)
			draw_style_box(style, Rect2(pos + Vector2(0.0, ICONE * 0.18), Vector2(ICONE * 1.3, ICONE * 0.64)))
			_texte_centre(pos + Vector2(ICONE * 0.65, ICONE * 0.5), affiche, 14, appuye)
			return ICONE * 1.3
		"LS":
			# Stick : un anneau, la tête du stick, et deux flèches gauche / droite.
			draw_circle(centre, ICONE * 0.5, FOND_BOUTON)
			draw_arc(centre, ICONE * 0.5 - 1.0, 0.0, TAU, 32, ALLUME if appuye else BORD_BOUTON, 2.0, true)
			var decalage := Input.get_axis("gauche", "droite") * ICONE * 0.12
			draw_circle(centre + Vector2(decalage, 0.0), ICONE * 0.24, ALLUME if appuye else Color(0.55, 0.55, 0.62))
			for cote in [-1.0, 1.0]:
				var pointe := centre + Vector2(cote * ICONE * 0.44, 0.0)
				var dos := centre + Vector2(cote * ICONE * 0.32, 0.0)
				draw_colored_polygon(PackedVector2Array([pointe, dos + Vector2(0.0, -4.0), dos + Vector2(0.0, 4.0)]), BORD_BOUTON)
			return ICONE
		"DPAD":
			# Croix directionnelle : une croix arrondie, une petite flèche par branche ;
			# la flèche de la branche tenue s'allume.
			var bras := ICONE * 0.18  # demi-largeur d'une branche
			var b := bras
			var l := ICONE * 0.5  # longueur d'une branche depuis le centre
			var croix := PackedVector2Array()
			for coin: Vector2 in [Vector2(-b, -l), Vector2(b, -l), Vector2(b, -b), Vector2(l, -b), Vector2(l, b), Vector2(b, b),
					Vector2(b, l), Vector2(-b, l), Vector2(-b, b), Vector2(-l, b), Vector2(-l, -b), Vector2(-b, -b)]:
				croix.append(centre + coin)
			draw_colored_polygon(croix, FOND_BOUTON)
			croix.append(croix[0])
			draw_polyline(croix, BORD_BOUTON, 1.5, true)
			var directions: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]
			for i in VUES.size():
				var tenue := InputMap.has_action(VUES[i]) and Input.is_action_pressed(VUES[i])
				var dir := directions[i]
				var pointe := centre + dir * ICONE * 0.4
				var base := centre + dir * ICONE * 0.24
				var travers := Vector2(-dir.y, dir.x) * bras * 0.75
				draw_colored_polygon(PackedVector2Array([pointe, base + travers, base - travers]), ALLUME if tenue else Color(0.7, 0.7, 0.78))
			return ICONE
		"VIEW", "START":
			# Petits boutons du milieu : Xbox deux carrés (View) ou trois traits (Menu),
			# Nintendo « − » / « + », PlayStation trois traits debout (Create) ou couchés (Options).
			var rayon := ICONE * 0.4
			draw_circle(centre, rayon, ALLUME if appuye else FOND_BOUTON)
			draw_arc(centre, rayon - 1.0, 0.0, TAU, 32, BORD_BOUTON, 2.0, true)
			var couleur_trait := CONTOUR if appuye else BORD_BOUTON
			if style_manette == Boutons.Style.NINTENDO:
				draw_line(centre + Vector2(-6.0, 0.0), centre + Vector2(6.0, 0.0), couleur_trait, 2.5)
				if nom == "START":
					draw_line(centre + Vector2(0.0, -6.0), centre + Vector2(0.0, 6.0), couleur_trait, 2.5)
			elif style_manette == Boutons.Style.PLAYSTATION and nom == "VIEW":
				for x in [-4.0, 0.0, 4.0]:
					draw_line(centre + Vector2(x, -5.0), centre + Vector2(x, 5.0), couleur_trait, 1.8)
			elif nom == "VIEW":
				draw_rect(Rect2(centre + Vector2(-6.0, -5.0), Vector2(8.0, 7.0)), couleur_trait, false, 1.8)
				draw_rect(Rect2(centre + Vector2(-2.0, -2.0), Vector2(8.0, 7.0)), couleur_trait, false, 1.8)
			else:
				for y in [-4.0, 0.0, 4.0]:
					draw_line(centre + Vector2(-6.0, y), centre + Vector2(6.0, y), couleur_trait, 1.8)
			return ICONE
	return ICONE


## Les symboles PlayStation, dessinés (la police n'a pas ces caractères) :
## croix en bas, rond à droite, carré à gauche, triangle en haut.
func _symbole_playstation(centre: Vector2, position: String, couleur: Color) -> void:
	var r := ICONE * 0.2
	match position:
		"A":
			draw_line(centre + Vector2(-r, -r), centre + Vector2(r, r), couleur, 2.5, true)
			draw_line(centre + Vector2(-r, r), centre + Vector2(r, -r), couleur, 2.5, true)
		"B":
			draw_arc(centre, r, 0.0, TAU, 24, couleur, 2.5, true)
		"X":
			draw_rect(Rect2(centre - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), couleur, false, 2.5)
		"Y":
			var pointes := PackedVector2Array([centre + Vector2(0.0, -r * 1.1), centre + Vector2(r * 1.05, r * 0.75),
				centre + Vector2(-r * 1.05, r * 0.75), centre + Vector2(0.0, -r * 1.1)])
			draw_polyline(pointes, couleur, 2.5, true)


func _style(appuye: bool, bord: Color, coins: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ALLUME if appuye else FOND_BOUTON
	style.border_color = bord
	style.set_border_width_all(2)
	style.set_corner_radius_all(coins)
	style.anti_aliasing = true
	return style


func _texte_centre(centre: Vector2, texte: String, taille: int, appuye: bool, couleur := TEXTE) -> void:
	var largeur := _police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var base := centre + Vector2(-largeur * 0.5, taille * 0.36)
	draw_string(_police, base, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, CONTOUR if appuye else couleur)
