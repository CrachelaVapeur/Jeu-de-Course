class_name Villes
extends RefCounted
## Les villes et les grands monuments d'un circuit : immeubles aux étages
## éclairés par endroits, feux rouges sur les plus hautes tours, pyramide
## lumineuse, cheminées d'usine, phare géant.
## Les immeubles se tiennent à distance de la route, et ceux qui en sont
## proches restent bas : la ville se voit comme une silhouette, au loin.
##
## Ce que le fichier de circuit peut donner :
## - VILLES : [{"centre": [x, y], "rayon": r, "hauteur_max": h, "teinte": t}, …]
##   (x, y et rayon en pixels de la carte, comme les points du tracé ;
##   teinte des lumières : 0 = chaude, 1 = froide) ;
## - MONUMENTS : [{"type": "pyramide" | "cheminees" | "phare", "position": [x, y], …}, …].

const SHADER_IMMEUBLE := preload("res://shaders/immeuble.gdshader")
const SHADER_FAISCEAU := preload("res://shaders/faisceau.gdshader")
const SHADER_HALO := preload("res://shaders/halo.gdshader")
const SCRIPT_TOURNER := preload("res://scripts/tourner.gd")

const COULEURS_IMMEUBLES: Array[Color] = [
	Color(0.22, 0.24, 0.30), Color(0.30, 0.30, 0.34), Color(0.18, 0.20, 0.24),
	Color(0.34, 0.31, 0.30), Color(0.25, 0.28, 0.36), Color(0.40, 0.38, 0.40),
]
## Distance libre entre le bord de la route et les premiers immeubles.
const RECUL := 45.0
## Au-delà de cette distance de la route, les immeubles ont toute leur hauteur.
const RECUL_HAUTEUR := 260.0

var _circuit  # le circuit (circuit_trace.gd) : pour ses matières et ses outils
var _echelle := 1.0
var _hasard := RandomNumberGenerator.new()
var _sans_couleur: Array[Color] = []  # pour les objets qui n'ont pas de couleur à eux


func _init(circuit, echelle: float, graine: int) -> void:
	_circuit = circuit
	_echelle = echelle
	_hasard.seed = graine


func construire(villes: Array, monuments: Array) -> void:
	for ville in villes:
		_construire_ville(ville)
	for m in monuments:
		match m.type:
			"pyramide":
				_construire_pyramide(m)
			"cheminees":
				_construire_cheminees(m)
			"phare":
				_construire_phare(m)


# --- Immeubles ---------------------------------------------------------------

func _construire_ville(ville: Dictionary) -> void:
	var centre := Vector2(ville.centre[0], ville.centre[1]) * _echelle
	var rayon: float = ville.rayon * _echelle
	var hauteur_max: float = ville.get("hauteur_max", 150.0)
	var corps: Array[Transform3D] = []
	var couleurs: Array[Color] = []
	var reglages: Array[Color] = []
	var toits: Array[Transform3D] = []
	var feux: Array[Transform3D] = []
	var teinte: float = ville.get("teinte", 0.35)

	# Un quadrillage de pâtés de maisons, un peu déformé pour faire naturel.
	var pas_ilot := 34.0
	var n := ceili(rayon / pas_ilot)
	for j in range(-n, n + 1):
		for i in range(-n, n + 1):
			var p := centre + Vector2(i, j) * pas_ilot + Vector2(_hasard.randf_range(-6, 6), _hasard.randf_range(-6, 6))
			var eloignement := p.distance_to(centre) / rayon
			if eloignement > 1.0 or _hasard.randf() < 0.12:
				continue  # hors de la ville, ou une place
			var sol: float = _circuit._hauteur_sol(p.x, p.y)
			if sol < _circuit.terrain.niveau_mer + 1.0 or sol > _circuit.terrain.niveau_mer + 30.0:
				continue  # dans la mer ou dans la montagne
			var largeur := _hasard.randf_range(12.0, 26.0)
			var profondeur := _hasard.randf_range(12.0, 26.0)
			var ecart_route: float = _distance_route(p) - _circuit.largeur_route_pres(p) * 0.5 - maxf(largeur, profondeur) * 0.75
			if ecart_route < RECUL:
				continue
			# Plus haut au centre, avec quelques tours qui dépassent, mais bas
			# près de la route.
			var hauteur := lerpf(hauteur_max, 18.0, pow(eloignement, 0.6)) * _hasard.randf_range(0.45, 1.1)
			if _hasard.randf() < 0.08:
				hauteur *= 1.6
			hauteur *= lerpf(0.3, 1.0, smoothstep(RECUL, RECUL_HAUTEUR, ecart_route))
			hauteur = maxf(hauteur, 12.0)
			var angle := _hasard.randf_range(-0.15, 0.15)
			var base := Basis(Vector3.UP, angle)
			corps.append(Transform3D(base.scaled_local(Vector3(largeur, hauteur, profondeur)), Vector3(p.x, sol + hauteur * 0.5, p.y)))
			couleurs.append(COULEURS_IMMEUBLES[_hasard.randi() % COULEURS_IMMEUBLES.size()])
			reglages.append(Color(_hasard.randf_range(0.05, 0.3), _hasard.randf(), 1.0 if _hasard.randf() < teinte else 0.0, 0.0))
			var sommet := sol + hauteur
			# Les grandes tours ont un étage en retrait et une antenne ; les plus
			# hautes, un feu rouge.
			if hauteur > 70.0:
				var h2 := hauteur * _hasard.randf_range(0.12, 0.25)
				corps.append(Transform3D(base.scaled_local(Vector3(largeur * 0.65, h2, profondeur * 0.65)), Vector3(p.x, sommet + h2 * 0.5, p.y)))
				couleurs.append(couleurs[-1])
				reglages.append(reglages[-1])
				sommet += h2
				var antenne := _hasard.randf_range(8.0, 25.0)
				toits.append(Transform3D(base.scaled_local(Vector3(0.6, antenne, 0.6)), Vector3(p.x, sommet + antenne * 0.5, p.y)))
				if hauteur > 110.0:
					feux.append(Transform3D(base.scaled_local(Vector3(1.2, 1.2, 1.2)), Vector3(p.x, sommet + antenne, p.y)))
			else:
				# Les petits immeubles ont des blocs techniques sur le toit.
				toits.append(Transform3D(base.scaled_local(Vector3(largeur * 0.3, 3.0, profondeur * 0.3)), Vector3(p.x, sommet + 1.5, p.y)))

	var matiere := ShaderMaterial.new()
	matiere.shader = SHADER_IMMEUBLE
	_circuit._matieres_decor.append(matiere)
	_ajouter_immeubles(corps, couleurs, reglages, matiere)
	_circuit._ajouter_en_masse(BoxMesh.new(), toits, _sans_couleur, _circuit._matiere(Color(0.2, 0.2, 0.24)))
	_circuit._ajouter_en_masse(BoxMesh.new(), feux, _sans_couleur, _circuit._matiere(Color(1.0, 0.1, 0.06), 2.5))
	print("Ville : %d immeubles" % corps.size())


func _ajouter_immeubles(placements: Array[Transform3D], couleurs: Array[Color], reglages: Array[Color], matiere: Material) -> void:
	if placements.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = BoxMesh.new()
	multi.instance_count = placements.size()
	for i in placements.size():
		multi.set_instance_transform(i, placements[i])
		multi.set_instance_color(i, couleurs[i])
		multi.set_instance_custom_data(i, reglages[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = matiere
	_circuit.add_child(instance)


func _distance_route(p: Vector2) -> float:
	var proche: Vector3 = _circuit.courbe.get_closest_point(Vector3(p.x, 0.0, p.y))
	return Vector2(proche.x, proche.z).distance_to(p)


# --- Monuments -----------------------------------------------------------------

## Une immense pyramide à gradins, à la Blade Runner : des fenêtres en
## lignes, un sommet qui brille, une aura orange et des projecteurs.
func _construire_pyramide(m: Dictionary) -> void:
	var p := Vector2(m.position[0], m.position[1]) * _echelle
	var cote: float = m.get("base", 280.0)
	var hauteur: float = m.get("hauteur", 200.0)
	var sol: float = _circuit._hauteur_sol(p.x, p.y)
	var marches := 12
	var gradins: Array[Transform3D] = []
	var reglages: Array[Color] = []
	var couleurs: Array[Color] = []
	for k in marches:
		var t := float(k) / marches
		var taille := cote * (1.0 - t) + 8.0
		var h := hauteur / marches
		gradins.append(Transform3D(Basis.from_scale(Vector3(taille, h, taille)), Vector3(p.x, sol + h * (k + 0.5), p.y)))
		couleurs.append(Color(0.36, 0.32, 0.30))
		reglages.append(Color(0.55, float(k) * 0.37, 0.0, 0.0))
	var matiere := ShaderMaterial.new()
	matiere.shader = SHADER_IMMEUBLE
	matiere.set_shader_parameter("hauteur_etage", hauteur / marches / 2.0)
	matiere.set_shader_parameter("largeur_fenetre", 6.0)
	matiere.set_shader_parameter("force_fenetres", 1.4)
	_circuit._matieres_decor.append(matiere)
	_ajouter_immeubles(gradins, couleurs, reglages, matiere)

	var sommet := Vector3(p.x, sol + hauteur + 4.0, p.y)
	var pointe: Array[Transform3D] = [Transform3D(Basis.from_scale(Vector3(10, 8, 10)), sommet)]
	_circuit._ajouter_en_masse(BoxMesh.new(), pointe, _sans_couleur, _circuit._matiere(Color(1.0, 0.75, 0.4), 3.0))

	# L'aura : un grand halo, et une vraie lumière qui éclaire les alentours.
	_ajouter_halo(Vector3(p.x, sol + hauteur * 0.55, p.y), cote * 2.6, Color(1.0, 0.6, 0.3), 0.2)
	_ajouter_halo(sommet, 120.0, Color(1.0, 0.8, 0.5), 0.4)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.65, 0.35)
	lumiere.light_energy = 3.0
	lumiere.omni_range = cote * 2.5
	lumiere.position = Vector3(p.x, sol + hauteur * 0.6, p.y)
	_circuit.add_child(lumiere)

	# Des projecteurs qui partent du sommet en éventail, comme sur la carte.
	for k in 4:
		var direction := Vector3(cos(k * TAU / 4.0 + 0.4), 0.55, sin(k * TAU / 4.0 + 0.4)).normalized()
		_ajouter_faisceau(sommet, direction, 900.0, 40.0, Color(1.0, 0.85, 0.6), 0.12)


## Trois grosses cheminées d'usine en chantier, avec des grues et des feux.
func _construire_cheminees(m: Dictionary) -> void:
	var p := Vector2(m.position[0], m.position[1]) * _echelle
	var corps: Array[Transform3D] = []
	var echafaudages: Array[Transform3D] = []
	var grues: Array[Transform3D] = []
	var feux: Array[Transform3D] = []
	var decalages := [Vector2(-60, 10), Vector2(0, -20), Vector2(60, 15)]
	for k in decalages.size():
		var q: Vector2 = p + decalages[k]
		var sol: float = _circuit._hauteur_sol(q.x, q.y)
		var hauteur := 90.0 + 25.0 * k
		corps.append(Transform3D(Basis.from_scale(Vector3(22, hauteur, 22)), Vector3(q.x, sol + hauteur * 0.5, q.y)))
		var haut := sol + hauteur
		# Un échafaudage autour du sommet, éclairé de l'intérieur.
		echafaudages.append(Transform3D(Basis.from_scale(Vector3(26, 16, 26)), Vector3(q.x, haut + 8.0, q.y)))
		for g in 2:
			var angle := _hasard.randf() * TAU
			var bout := Vector3(q.x, haut + 16.0, q.y) + Vector3(cos(angle), 0.9, sin(angle)) * 30.0
			grues.append(_circuit._poutre(Vector3(q.x, haut + 10.0, q.y), bout, 1.2))
			feux.append(Transform3D(Basis.from_scale(Vector3(1.5, 1.5, 1.5)), bout))
	var cylindre := CylinderMesh.new()
	cylindre.radial_segments = 12
	_circuit._ajouter_en_masse(cylindre, corps, _sans_couleur, _circuit._matiere(Color(0.45, 0.52, 0.62)))
	_circuit._ajouter_en_masse(cylindre, echafaudages, _sans_couleur, _circuit._matiere(Color(1.0, 0.78, 0.5), 0.5))
	_circuit._ajouter_en_masse(BoxMesh.new(), grues, _sans_couleur, _circuit._matiere(Color(0.1, 0.1, 0.12)))
	_circuit._ajouter_en_masse(BoxMesh.new(), feux, _sans_couleur, _circuit._matiere(Color(1.0, 0.1, 0.06), 2.5))


## Un phare géant sur la presqu'île, avec un double faisceau qui tourne.
func _construire_phare(m: Dictionary) -> void:
	var p := Vector2(m.position[0], m.position[1]) * _echelle
	var hauteur: float = m.get("hauteur", 240.0)
	var sol: float = maxf(_circuit._hauteur_sol(p.x, p.y), _circuit.terrain.niveau_mer)
	var tour := CylinderMesh.new()
	tour.top_radius = 10.0
	tour.bottom_radius = 24.0
	tour.height = hauteur
	tour.radial_segments = 16
	var instance := MeshInstance3D.new()
	instance.mesh = tour
	instance.material_override = _circuit._matiere(Color(0.62, 0.6, 0.58))
	instance.position = Vector3(p.x, sol + hauteur * 0.5, p.y)
	_circuit.add_child(instance)
	# Des bandes lumineuses le long de la tour.
	var bandes: Array[Transform3D] = []
	for k in range(1, 6):
		var y := sol + hauteur * k / 6.0
		var r := lerpf(24.0, 10.0, float(k) / 6.0) + 0.6
		bandes.append(Transform3D(Basis.from_scale(Vector3(r * 2.0, 1.2, r * 2.0)), Vector3(p.x, y, p.y)))
	var cylindre := CylinderMesh.new()
	cylindre.radial_segments = 16
	_circuit._ajouter_en_masse(cylindre, bandes, _sans_couleur, _circuit._matiere(Color(0.35, 0.85, 1.0), 1.5))

	var lanterne := Vector3(p.x, sol + hauteur + 8.0, p.y)
	var verre: Array[Transform3D] = [Transform3D(Basis.from_scale(Vector3(18, 16, 18)), lanterne)]
	_circuit._ajouter_en_masse(cylindre, verre, _sans_couleur, _circuit._matiere(Color(0.85, 0.95, 1.0), 3.0))
	_ajouter_halo(lanterne, 160.0, Color(0.8, 0.92, 1.0), 0.35)

	var pivot := Node3D.new()
	pivot.set_script(SCRIPT_TOURNER)
	pivot.set("tours_par_minute", 5.0)
	pivot.position = lanterne
	_circuit.add_child(pivot)
	for sens in [-1.0, 1.0]:
		# Le cône est couché à l'horizontale, sa pointe sur la lanterne.
		var faisceau := _faisceau(1600.0, 70.0, Color(0.85, 0.95, 1.0), 0.15)
		faisceau.rotation.z = PI * 0.5 * sens
		faisceau.position = Vector3(800.0 * sens, 0.0, 0.0)
		pivot.add_child(faisceau)


# --- Lumières ------------------------------------------------------------------

func _ajouter_halo(position_halo: Vector3, taille: float, couleur: Color, force: float) -> void:
	var carre := QuadMesh.new()
	carre.size = Vector2(taille, taille)
	var matiere := ShaderMaterial.new()
	matiere.shader = SHADER_HALO
	matiere.set_shader_parameter("couleur", couleur)
	matiere.set_shader_parameter("force", force)
	_circuit._matieres_decor.append(matiere)
	var instance := MeshInstance3D.new()
	instance.mesh = carre
	instance.material_override = matiere
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = position_halo
	_circuit.add_child(instance)


## Un cône de lumière vertical, centré sur l'origine du nœud : sa pointe
## (la source) est en haut, il s'ouvre vers le bas sur « longueur » mètres.
func _faisceau(longueur: float, rayon: float, couleur: Color, force: float) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 1.5
	cone.bottom_radius = rayon
	cone.height = longueur
	cone.radial_segments = 24
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var matiere := ShaderMaterial.new()
	matiere.shader = SHADER_FAISCEAU
	matiere.set_shader_parameter("couleur", couleur)
	matiere.set_shader_parameter("force", force)
	_circuit._matieres_decor.append(matiere)
	var instance := MeshInstance3D.new()
	instance.mesh = cone
	instance.material_override = matiere
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _ajouter_faisceau(depart: Vector3, direction: Vector3, longueur: float, rayon: float, couleur: Color, force: float) -> void:
	var faisceau := _faisceau(longueur, rayon, couleur, force)
	# Le cylindre est vertical : on l'oriente pour que son axe suive « direction ».
	var y := -direction
	var autre := Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT
	var x := y.cross(autre).normalized()
	var z := x.cross(y)
	faisceau.transform = Transform3D(Basis(x, y, z), depart + direction * longueur * 0.5)
	_circuit.add_child(faisceau)
