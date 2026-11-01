extends Control
## Les deux jauges du bas à droite : la barre DEVILMAYDRIVE (au-dessus) et les charges de BOOST (en dessous).
##
## Devilmaydrive : la jauge de style. Elle se remplit en dérapant (violet puis orange, de plus
## en plus chaud) ; plus elle est haute, plus la vitesse max monte (le bonus s'affiche à
## droite). Pleine, son cadre rayonne.
## Boost : un rond par charge. Un rond avec un point est une charge prête. Pendant un boost,
## le rond qu'on vient d'utiliser se vide en rose.
## Tout est dessiné par le code (pas d'image), comme le guide des commandes.

var vehicule: Vehicule

const LARGEUR := 360.0
const HAUTEUR := 25.0
const BORD_DROIT := 60.0  ## distance au bord droit de l'écran
const BAS_BARRE := 40.0  ## distance entre le bas de la barre et le bas de l'écran
const RAYON_ROND := 10.0
const ECART_ROND := 34.0

const FOND := Color(0.04, 0.03, 0.09, 0.75)
const FROID := Color(0.45, 0.2, 1.0)  ## début de la barre
const CHAUD := Color(1.0, 0.55, 0.1)  ## fin de la barre
const BOOST_ROSE := Color(1.0, 0.3, 0.7)
const ROND_PRET := Color(1.0, 0.75, 0.9)
const ROND_VIDE := Color(0.5, 0.55, 0.65, 0.5)

var _temps := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_temps += delta
	visible = vehicule != null
	queue_redraw()


func _draw() -> void:
	if vehicule == null:
		return
	_dessiner_barre()
	if not vehicule.boost_infini:
		_dessiner_boost()


func _dessiner_barre() -> void:
	var x0 := size.x - BORD_DROIT - LARGEUR
	var y0 := size.y - BAS_BARRE - HAUTEUR
	var cadre := Rect2(x0, y0, LARGEUR, HAUTEUR)
	var part := clampf(vehicule.style / vehicule.style_max, 0.0, 1.0)
	var pleine := part >= 0.999

	draw_rect(cadre, FOND)
	if part > 0.0:
		# Le dégradé est fixé sur la barre entière : il se dévoile en la remplissant.
		var largeur := LARGEUR * part
		var morceaux := 48
		for i in morceaux:
			var a := largeur * i / morceaux
			var b := largeur * (i + 1) / morceaux
			var t := (a + b) * 0.5 / LARGEUR
			draw_rect(Rect2(x0 + a, y0, b - a + 0.6, HAUTEUR), FROID.lerp(CHAUD, t))

	# Quatre repères : la barre se lit en cinq paliers.
	for i in range(1, 5):
		var x := x0 + LARGEUR * i / 5.0
		draw_line(Vector2(x, y0 + HAUTEUR * 0.6), Vector2(x, y0 + HAUTEUR), Color(1, 1, 1, 0.35), 1.5)

	var couleur_cadre := Color(0.85, 0.9, 1.0, 0.55)
	var epaisseur := 2.0
	if pleine:
		# Cadre qui rayonne : un halo qui bat doucement autour de la barre.
		var pouls := 0.5 + 0.5 * sin(_temps * 6.0)
		for i in 6:
			var marge := 2.0 + i * 2.5
			var alpha := (0.38 - i * 0.055) * (0.55 + 0.45 * pouls)
			draw_rect(cadre.grow(marge), Color(CHAUD.r, CHAUD.g, CHAUD.b, alpha), false, 2.5)
		couleur_cadre = Color(1.0, 0.9, 0.7, 1.0)
		epaisseur = 3.0
	draw_rect(cadre, couleur_cadre, false, epaisseur)

	var police := ThemeDB.fallback_font
	var taille := 14
	var y_texte := y0 + HAUTEUR * 0.5 + taille * 0.35
	_texte(police, Vector2(x0 + 8.0, y_texte), "DEVILMAYDRIVE", taille)
	if part > 0.0:
		var bonus := "+%d km/h" % roundi(vehicule.style_bonus_vitesse * part * 3.6)
		var l := police.get_string_size(bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		_texte(police, Vector2(x0 + LARGEUR - 8.0 - l, y_texte), bonus, taille)


func _texte(police: Font, pos: Vector2, texte: String, taille: int) -> void:
	draw_string_outline(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 6, Color(0.05, 0.02, 0.1))
	draw_string(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(1, 1, 1))


func _dessiner_boost() -> void:
	var total := vehicule.boost_charges_max
	var y := size.y - BAS_BARRE + HAUTEUR * 0.5 + 6.0
	var x_droite := size.x - BORD_DROIT - RAYON_ROND
	for i in total:
		var centre := Vector2(x_droite - (total - 1 - i) * ECART_ROND, y)
		if i < vehicule.boost_charges:
			# Charge prête : rond plein avec un point au centre.
			draw_circle(centre, RAYON_ROND + 3.0, Color(ROND_PRET.r, ROND_PRET.g, ROND_PRET.b, 0.18))
			draw_arc(centre, RAYON_ROND, 0.0, TAU, 32, ROND_PRET, 2.5, true)
			draw_circle(centre, 4.0, ROND_PRET)
		else:
			draw_arc(centre, RAYON_ROND, 0.0, TAU, 32, ROND_VIDE, 2.0, true)
			if i == vehicule.boost_charges and vehicule.en_boost:
				# La charge qu'on est en train de brûler se vide en rose.
				var reste := clampf(vehicule.boost_restant / vehicule.duree_boost, 0.0, 1.0)
				draw_arc(centre, RAYON_ROND, -PI * 0.5, -PI * 0.5 + TAU * reste, 32, BOOST_ROSE, 3.0, true)
