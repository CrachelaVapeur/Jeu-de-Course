extends Control
## Les deux jauges du bas à droite : la barre de BOOST (au-dessus) et les 3 charges de DASH (en dessous).
##
## Barre de boost : elle se remplit en dérapant, du bleu au turquoise. Pleine, son cadre
## rayonne et le mot BOOST apparaît : c'est prêt. Pendant le boost elle se vide.
## Dash : trois ronds, avec un point au centre quand la charge est prête. Un rond
## sans point se recharge (l'arc montre où il en est).
## Tout est dessiné par le code (pas d'image), comme le guide des commandes.

var vehicule: Vehicule

const LARGEUR := 360.0
const HAUTEUR := 25.0
const BORD_DROIT := 60.0  ## distance au bord droit de l'écran
const BAS_BARRE := 40.0  ## distance entre le bas de la barre et le bas de l'écran
const RAYON_DASH := 10.0
const ECART_DASH := 34.0

const FOND := Color(0.04, 0.03, 0.09, 0.75)
const BLEU := Color(0.12, 0.38, 1.0)
const TURQUOISE := Color(0.1, 0.95, 0.88)
const BOOST_ACTIF := Color(1.0, 0.3, 0.7)
const DASH_PRET := Color(0.75, 1.0, 1.0)
const DASH_VIDE := Color(0.5, 0.55, 0.65, 0.5)

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
	if not vehicule.boost_infini:
		_dessiner_barre()
	_dessiner_dash()


func _dessiner_barre() -> void:
	var x0 := size.x - BORD_DROIT - LARGEUR
	var y0 := size.y - BAS_BARRE - HAUTEUR
	var cadre := Rect2(x0, y0, LARGEUR, HAUTEUR)
	var part := clampf(vehicule.jauge_boost / vehicule.jauge_max, 0.0, 1.0)
	var prete := part >= 0.999 and not vehicule.en_boost

	draw_rect(cadre, FOND)
	if part > 0.0:
		# Le dégradé est fixé sur la barre entière : il se dévoile en la remplissant.
		var largeur := LARGEUR * part
		var morceaux := 48
		for i in morceaux:
			var a := largeur * i / morceaux
			var b := largeur * (i + 1) / morceaux
			var t := (a + b) * 0.5 / LARGEUR
			var couleur := BLEU.lerp(TURQUOISE, t)
			if vehicule.en_boost:
				couleur = couleur.lerp(BOOST_ACTIF, 0.65)
			draw_rect(Rect2(x0 + a, y0, b - a + 0.6, HAUTEUR), couleur)

	var couleur_cadre := Color(0.85, 0.9, 1.0, 0.55)
	var epaisseur := 2.0
	if prete:
		# Cadre qui rayonne : un halo qui bat doucement autour de la barre.
		var pouls := 0.5 + 0.5 * sin(_temps * 6.0)
		for i in 6:
			var marge := 2.0 + i * 2.5
			var alpha := (0.38 - i * 0.055) * (0.55 + 0.45 * pouls)
			draw_rect(cadre.grow(marge), Color(TURQUOISE.r, TURQUOISE.g, TURQUOISE.b, alpha), false, 2.5)
		couleur_cadre = Color(0.75, 1.0, 0.97, 1.0)
		epaisseur = 3.0
	elif vehicule.en_boost:
		couleur_cadre = BOOST_ACTIF
		epaisseur = 3.0
	draw_rect(cadre, couleur_cadre, false, epaisseur)

	if prete:
		var police := ThemeDB.fallback_font
		var taille := 20
		var texte := "BOOST"
		var largeur_texte := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var pos := Vector2(x0 + (LARGEUR - largeur_texte) * 0.5, y0 + HAUTEUR * 0.5 + taille * 0.35)
		draw_string_outline(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 6, Color(0.02, 0.05, 0.12))
		draw_string(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(1, 1, 1))


func _dessiner_dash() -> void:
	var total := vehicule.dash_charges_max
	var y := size.y - BAS_BARRE + HAUTEUR * 0.5 + 6.0
	var x_droite := size.x - BORD_DROIT - RAYON_DASH
	for i in total:
		# Le rond de droite est la première charge utilisée en dernier : on lit de gauche à droite.
		var centre := Vector2(x_droite - (total - 1 - i) * ECART_DASH, y)
		var contenu := clampf(vehicule.dash_charges - i, 0.0, 1.0)
		if contenu >= 1.0:
			draw_circle(centre, RAYON_DASH + 3.0, Color(DASH_PRET.r, DASH_PRET.g, DASH_PRET.b, 0.18))
			draw_arc(centre, RAYON_DASH, 0.0, TAU, 32, DASH_PRET, 2.5, true)
			draw_circle(centre, 4.0, DASH_PRET)
		else:
			draw_arc(centre, RAYON_DASH, 0.0, TAU, 32, DASH_VIDE, 2.0, true)
			if contenu > 0.0:
				draw_arc(centre, RAYON_DASH, -PI * 0.5, -PI * 0.5 + TAU * contenu, 32, TURQUOISE, 2.5, true)
