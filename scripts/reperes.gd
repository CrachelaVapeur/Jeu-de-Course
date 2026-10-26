class_name Reperes
extends RefCounted
## Les repères qui donnent la sensation de vitesse le long de la route, et
## l'éclairage, utilisé avec parcimonie : chaque section a le sien.
##
## Ce que le fichier de circuit peut donner, dans OBSTACLES :
## - {"type": "lampadaires", "a", "longueur", "ecart"} : lampadaires des deux
##   côtés, avec un cône de lumière ;
## - {"type": "balises", "a", "longueur"} : petites balises lumineuses sur les
##   murets (blanches à gauche, rouges à droite) ;
## - {"type": "portiques", "a", "longueur", "ecart"} : portiques lumineux
##   au-dessus de la route ;
## - {"type": "lignes_lumineuses", "a", "longueur"} : pointillés lumineux
##   (dessinés par le shader de la route) ;
## - {"type": "panneau", "a", "texte"} : un grand panneau au-dessus de la route.
## Ajoutés tout seuls : des chevrons à l'extérieur des virages serrés, et le
## compte à rebours avant l'arrivée (courses d'un point à un autre).

const SHADER_FAISCEAU := preload("res://shaders/faisceau.gdshader")
const COULEURS_PORTIQUES: Array[Color] = [Color(1.0, 0.2, 0.6), Color(0.2, 0.9, 1.0), Color(0.6, 0.3, 1.0)]

var _circuit
var _hasard := RandomNumberGenerator.new()
var _sans_couleur: Array[Color] = []


func _init(circuit, graine: int) -> void:
	_circuit = circuit
	_hasard.seed = graine + 31


func construire(obstacles: Array) -> void:
	var nombre_portiques := 0
	for o in obstacles:
		match o.type:
			"lampadaires":
				_construire_lampadaires(o)
			"balises":
				_construire_balises(o)
			"portiques":
				var d: float = o.a
				while d < o.a + o.longueur:
					_circuit._construire_portique(d, COULEURS_PORTIQUES[nombre_portiques % COULEURS_PORTIQUES.size()])
					nombre_portiques += 1
					d += o.ecart
			"panneau":
				_construire_panneau(o.a, o.texte, Color(1.0, 0.85, 0.3))
	_construire_chevrons()
	if not _circuit._donnees.BOUCLE:
		for reste in [1000, 500, 250]:
			_construire_panneau(_circuit.ligne_arrivee - reste, "ARRIVÉE  %d m" % reste, Color(1.0, 0.3, 0.6))


func _construire_lampadaires(o: Dictionary) -> void:
	var mats: Array[Transform3D] = []
	var tetes: Array[Transform3D] = []
	var cones: Array[Transform3D] = []
	var hauteur := 11.0
	var d: float = o.a
	var cote := 1.0
	while d < o.a + o.longueur:
		var t: Dictionary = _circuit._cadre(d)
		var base := Basis.looking_at(Vector3(t.avant.x, 0.0, t.avant.z).normalized())
		# En quinconce : un à droite, puis un à gauche.
		var pied: Vector3 = _circuit._bord(t, cote) + t.droite * (1.4 * cote)
		mats.append(Transform3D(base.scaled_local(Vector3(0.4, hauteur, 0.4)), pied + Vector3.UP * (hauteur * 0.5)))
		var bout: Vector3 = pied + Vector3.UP * hauteur - t.droite * (4.5 * cote)
		mats.append(_circuit._poutre(pied + Vector3.UP * hauteur, bout, 0.3))
		tetes.append(Transform3D(base.scaled_local(Vector3(0.8, 0.3, 2.0)), bout - Vector3.UP * 0.2))
		cones.append(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.0)), bout - Vector3.UP * (hauteur * 0.5)))
		cote = -cote
		d += o.get("ecart", 45.0) * 0.5
	_circuit._ajouter_en_masse(BoxMesh.new(), mats, _sans_couleur, _circuit._matiere(Color(0.3, 0.3, 0.34)))
	var couleur := Color(1.0, 0.78, 0.5)
	_circuit._ajouter_en_masse(BoxMesh.new(), tetes, _sans_couleur, _circuit._matiere(couleur, 6.0))
	# Un léger cône de lumière sous chaque lampe.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 6.0
	cone.height = hauteur
	cone.radial_segments = 12
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var matiere := ShaderMaterial.new()
	matiere.shader = SHADER_FAISCEAU
	matiere.set_shader_parameter("couleur", couleur)
	matiere.set_shader_parameter("force", 0.25)
	_circuit._matieres_decor.append(matiere)
	_circuit._ajouter_en_masse(cone, cones, _sans_couleur, matiere)


## Petites balises sur les murets : blanches à gauche, rouges à droite,
## comme sur les routes de montagne.
func _construire_balises(o: Dictionary) -> void:
	var blanches: Array[Transform3D] = []
	var rouges: Array[Transform3D] = []
	var d: float = o.a
	while d < o.a + o.longueur:
		var t: Dictionary = _circuit._cadre(d)
		if not _circuit._obstacle_a("trou", d):
			for cote in [-1.0, 1.0]:
				if _circuit._obstacle_a("sans_muret", d, "gauche" if cote < 0.0 else "droite"):
					continue
				var p: Vector3 = _circuit._bord(t, cote) + t.droite * (0.3 * cote) + t.haut * (_circuit.hauteur_muret + 0.35)
				var placement := Transform3D(Basis.from_scale(Vector3(0.35, 0.7, 0.35)), p)
				if cote < 0.0:
					blanches.append(placement)
				else:
					rouges.append(placement)
		d += 25.0
	_circuit._ajouter_en_masse(BoxMesh.new(), blanches, _sans_couleur, _circuit._matiere(Color(0.9, 0.9, 1.0), 3.0))
	_circuit._ajouter_en_masse(BoxMesh.new(), rouges, _sans_couleur, _circuit._matiere(Color(1.0, 0.15, 0.1), 3.0))


## Des chevrons lumineux à l'extérieur des virages serrés : ils montrent le
## sens du virage et défilent vite.
func _construire_chevrons() -> void:
	var d := 20.0
	var longueur: float = _circuit.longueur
	while d < longueur - 20.0:
		var t: Dictionary = _circuit._cadre(d)
		var avant: Dictionary = _circuit._cadre(d - 15.0)
		var apres: Dictionary = _circuit._cadre(d + 15.0)
		var virage: float = avant.avant.signed_angle_to(apres.avant, Vector3.UP) / 30.0  # radians par mètre
		if absf(virage) > 1.0 / 110.0 and not _circuit._obstacle_a("cratere", d) and not _circuit._obstacle_a("tunnel", d):
			# virage > 0 : on tourne à gauche, l'extérieur est à droite.
			var exterieur := 1.0 if virage > 0.0 else -1.0
			var p: Vector3 = _circuit._bord(t, exterieur) + t.droite * (1.0 * exterieur) + t.haut * 2.2
			var texte := Label3D.new()
			texte.text = "<<<" if virage > 0.0 else ">>>"
			texte.font_size = 160
			texte.outline_size = 0
			texte.modulate = Color(1.0, 0.6, 0.1) * 3.0
			texte.shaded = false
			texte.double_sided = false
			# Le texte regarde vers les bolides qui arrivent (son +Z vers l'arrière).
			texte.transform = Transform3D(Basis.looking_at(t.avant), p)
			texte.pixel_size = 0.012
			_circuit.add_child(texte)
			d += 12.0
		else:
			d += 6.0


## Un grand panneau au-dessus de la route, avec un texte lumineux.
func _construire_panneau(d: float, texte: String, couleur: Color) -> void:
	var t: Dictionary = _circuit._cadre(d)
	var base := Basis(t.droite, Vector3.UP, -t.avant)
	var ecart: float = t.largeur * 0.5 + 1.5
	var hauteur := 10.0
	var elements: Array[Transform3D] = []
	for cote in [-1.0, 1.0]:
		elements.append(Transform3D(base.scaled_local(Vector3(0.8, hauteur + 6.0, 0.8)), t.pos + t.droite * (ecart * cote) + Vector3.UP * (hauteur * 0.5 - 3.0)))
	elements.append(Transform3D(base.scaled_local(Vector3(minf(ecart * 1.4, 26.0), 3.6, 0.5)), t.pos + Vector3.UP * (hauteur + 1.8)))
	_circuit._ajouter_en_masse(BoxMesh.new(), elements, _sans_couleur, _circuit._matiere(Color(0.12, 0.12, 0.15)))
	var etiquette := Label3D.new()
	etiquette.text = texte
	etiquette.font_size = 200
	etiquette.pixel_size = 0.012
	etiquette.modulate = couleur * 2.5
	etiquette.outline_size = 0
	etiquette.shaded = false
	etiquette.transform = Transform3D(base, t.pos + Vector3.UP * (hauteur + 1.8) - t.avant * 0.3)
	_circuit.add_child(etiquette)
