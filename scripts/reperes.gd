class_name Reperes
extends RefCounted
## Les repères qui donnent la sensation de vitesse le long de la route, et
## l'éclairage, utilisé avec parcimonie : chaque section a le sien, dans la
## teinte de sa zone (COULEURS_ZONES dans le fichier du circuit).
##
## Ce que le fichier de circuit peut donner, dans OBSTACLES :
## - {"type": "lampadaires", "a", "longueur", "ecart"} : lampadaires des deux
##   côtés, avec un cône de lumière ;
## - {"type": "balises", "a", "longueur"} : petites balises lumineuses sur les
##   murets ;
## - {"type": "portiques", "a", "longueur", "ecart"} : portiques lumineux
##   au-dessus de la route ;
## - {"type": "lignes_lumineuses", "a", "longueur"} : pointillés lumineux
##   (dessinés par le shader de la route).
## Ajoutés tout seuls : des chevrons à l'extérieur des virages serrés.

var _circuit
var _hasard := RandomNumberGenerator.new()
var _sans_couleur: Array[Color] = []


func _init(circuit, graine: int) -> void:
	_circuit = circuit
	_hasard.seed = graine + 31


func construire(obstacles: Array) -> void:
	for o in obstacles:
		match o.type:
			"lampadaires":
				_construire_lampadaires(o)
			"balises":
				_construire_balises(o)
			"portiques":
				var d: float = o.a
				while d < o.a + o.longueur:
					_circuit._construire_portique(d, _circuit.couleur_zone(d))
					d += o.ecart
	_construire_chevrons()


func _construire_lampadaires(o: Dictionary) -> void:
	var mats: Array[Transform3D] = []
	var tetes: Array[Transform3D] = []
	var couleurs: Array[Color] = []
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
		tetes.append(Transform3D(base.scaled_local(Vector3(0.8, 0.2, 2.4)), bout - Vector3.UP * 0.2))
		couleurs.append(_circuit.couleur_zone(d).lerp(Color.WHITE, 0.5))
		cote = -cote
		d += o.get("ecart", 45.0) * 0.5
	_circuit._ajouter_en_masse(BoxMesh.new(), mats, _sans_couleur, _circuit._matiere(Color(0.3, 0.3, 0.34)))
	_circuit._ajouter_en_masse(BoxMesh.new(), tetes, couleurs, _circuit._matiere(Color.WHITE, 1.2))


## Petites balises sur les murets, comme sur les routes de montagne.
func _construire_balises(o: Dictionary) -> void:
	var balises: Array[Transform3D] = []
	var couleurs: Array[Color] = []
	var d: float = o.a
	while d < o.a + o.longueur:
		var t: Dictionary = _circuit._cadre(d)
		if not _circuit._obstacle_a("trou", d):
			for cote in [-1.0, 1.0]:
				if _circuit._obstacle_a("sans_muret", d, "gauche" if cote < 0.0 else "droite"):
					continue
				var p: Vector3 = _circuit._bord(t, cote) + t.droite * (0.3 * cote) + t.haut * (_circuit.hauteur_muret + 0.35)
				balises.append(Transform3D(Basis.from_scale(Vector3(0.3, 0.5, 0.3)), p))
				couleurs.append(_circuit.couleur_zone(d))
		d += 25.0
	_circuit._ajouter_en_masse(BoxMesh.new(), balises, couleurs, _circuit._matiere(Color.WHITE, 1.8))


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
		if absf(virage) > 1.0 / 160.0 and not _circuit._obstacle_a("cratere", d) and not _circuit._obstacle_a("tunnel", d):
			# virage > 0 : on tourne à gauche, l'extérieur est à droite.
			var exterieur := 1.0 if virage > 0.0 else -1.0
			var p: Vector3 = _circuit._bord(t, exterieur) + t.droite * (1.0 * exterieur) + t.haut * 2.2
			var texte := Label3D.new()
			texte.text = "<<<" if virage > 0.0 else ">>>"
			texte.font_size = 110
			texte.outline_size = 0
			texte.modulate = _circuit.couleur_zone(d) * 1.4
			texte.shaded = false
			texte.double_sided = false
			# Le texte regarde vers les bolides qui arrivent (son +Z vers l'arrière).
			texte.transform = Transform3D(Basis.looking_at(t.avant), p)
			texte.pixel_size = 0.012
			_circuit.add_child(texte)
			d += 12.0
		else:
			d += 6.0
