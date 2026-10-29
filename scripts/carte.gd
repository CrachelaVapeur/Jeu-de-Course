extends Control
## Carte du circuit, vue de dessus : Select sur la manette, M au clavier
## (on l'ouvre et on la ferme ; la course continue pendant ce temps).
##
## Le tracé vient de la courbe du circuit (circuit_trace.gd). On y voit la
## ligne de départ et le bolide (une flèche qui pointe dans sa direction).
## La ligne droite d'essai (main.tscn) n'a pas de tracé : la carte le dit.

var vehicule: Vehicule  ## donné par le HUD
var circuit: Node  ## donné par le HUD ; null ou sans « courbe » = pas de carte

const COULEUR_ROUTE := Color(0.85, 0.88, 1.0)
const COULEUR_BORD := Color(0.05, 0.03, 0.09)
const COULEUR_BOLIDE := Color(1.0, 0.75, 0.2)
const COULEUR_DEPART := Color(0.3, 0.9, 1.0)
const MARGE := 40.0  # entre le tracé et le bord du panneau

var _points: PackedVector2Array  # le tracé vu de dessus (x, z), en mètres
var _cadre := Rect2()  # l'emprise du tracé, en mètres
var _police: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_police = ThemeDB.fallback_font
	if circuit != null and "courbe" in circuit:
		var courbe: Curve3D = circuit.courbe
		var tous := courbe.get_baked_points()
		var pas := maxi(tous.size() / 600, 1)  # environ 600 points suffisent pour le dessin
		for i in range(0, tous.size(), pas):
			_points.append(Vector2(tous[i].x, tous[i].z))
		_cadre = Rect2(_points[0], Vector2.ZERO)
		for p in _points:
			_cadre = _cadre.expand(p)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("carte"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()  # le bolide bouge


func _draw() -> void:
	var ecran := get_viewport_rect().size
	var cote := minf(ecran.x, ecran.y) * 0.82
	var panneau := Rect2((ecran - Vector2(cote, cote)) * 0.5, Vector2(cote, cote))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.03, 0.02, 0.06, 0.82)
	fond.set_corner_radius_all(18)
	fond.border_color = Color(0.3, 0.9, 1.0, 0.5)
	fond.set_border_width_all(2)
	draw_style_box(fond, panneau)
	_texte(panneau.position + Vector2(24.0, 40.0), "MAP", 26, Color(1.0, 0.55, 0.3))
	_texte(panneau.position + Vector2(24.0, cote - 20.0), "%s / M: close" % Boutons.nom("VIEW", Boutons.style_des_reglages(get_tree())), 16, Color(0.75, 0.75, 0.85))

	if _points.size() < 2:
		_texte(panneau.get_center() - Vector2(150.0, 0.0), "No map for this track", 24, COULEUR_ROUTE)
		return

	# Mise à l'échelle : le tracé remplit le panneau en gardant ses proportions.
	var zone := panneau.grow(-MARGE - 20.0)
	var echelle := minf(zone.size.x / maxf(_cadre.size.x, 1.0), zone.size.y / maxf(_cadre.size.y, 1.0))
	var decalage := zone.get_center() - _cadre.get_center() * echelle
	var ecran_points := PackedVector2Array()
	for p in _points:
		ecran_points.append(p * echelle + decalage)
	if circuit.get("_donnees") != null and circuit._donnees.BOUCLE:
		ecran_points.append(ecran_points[0])
	draw_polyline(ecran_points, COULEUR_BORD, 12.0, true)
	draw_polyline(ecran_points, COULEUR_ROUTE, 6.0, true)

	# La ligne de départ : un petit trait en travers du tracé.
	var courbe: Curve3D = circuit.courbe
	var d_depart: float = circuit.ligne_depart
	var a := courbe.sample_baked(d_depart)
	var b := courbe.sample_baked(d_depart + 5.0)
	var depart := Vector2(a.x, a.z) * echelle + decalage
	var sens := (Vector2(b.x, b.z) - Vector2(a.x, a.z)).normalized()
	var travers := Vector2(-sens.y, sens.x) * 12.0
	draw_line(depart - travers, depart + travers, COULEUR_DEPART, 5.0, true)

	# Le bolide : une flèche qui pointe là où va son nez.
	if vehicule != null:
		var pos := Vector2(vehicule.global_position.x, vehicule.global_position.z) * echelle + decalage
		var avant3 := -vehicule.global_basis.z
		var avant := Vector2(avant3.x, avant3.z).normalized()
		var cote_fleche := Vector2(-avant.y, avant.x)
		var fleche := PackedVector2Array([pos + avant * 14.0, pos - avant * 9.0 + cote_fleche * 9.0, pos - avant * 4.0, pos - avant * 9.0 - cote_fleche * 9.0])
		draw_colored_polygon(fleche, COULEUR_BOLIDE)
		fleche.append(fleche[0])
		draw_polyline(fleche, COULEUR_BORD, 2.0, true)


func _texte(pos: Vector2, texte: String, taille: int, couleur: Color) -> void:
	draw_string_outline(_police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 6, COULEUR_BORD)
	draw_string(_police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
