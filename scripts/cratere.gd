class_name Cratere
extends RefCounted
## La zone cratère : puits de lave, rochers et monstre.
##
## Ce que le fichier de circuit peut donner, dans OBSTACLES :
## - {"type": "cratere", "a": …, "longueur": …} : la zone large, sans murets ;
## - {"type": "puits", "a": …, "decalage": …, "rayon": …} : un puits de lave
##   (on y tombe) ; « decalage » est la distance au centre de la route
##   (négatif = à gauche) ;
## - {"type": "rochers", "a": …, "longueur": …, "nombre": …} : des rochers
##   éparpillés, à contourner ;
## - {"type": "monstre", "a": …, "longueur": …} : le monstre, qui erre entre
##   ces deux distances.

const SCRIPT_MONSTRE := preload("res://scripts/monstre.gd")

var _circuit
var _hasard := RandomNumberGenerator.new()
var _rocher: Mesh
var _sans_couleur: Array[Color] = []


func _init(circuit, graine: int) -> void:
	_circuit = circuit
	_hasard.seed = graine + 17
	_rocher = _maillage_rocher()


func construire(obstacles: Array) -> void:
	for o in obstacles:
		match o.type:
			"cratere":
				_construire_rebords(o)
			"puits":
				_construire_puits(o)
			"rochers":
				_construire_rochers(o)
			"monstre":
				_construire_monstre(o)


## De gros rochers le long des bords : ils montrent où est le mur invisible.
func _construire_rebords(o: Dictionary) -> void:
	var rochers: Array[Transform3D] = []
	var d: float = o.a
	while d < o.a + o.longueur:
		var t: Dictionary = _circuit._cadre(d)
		for cote in [-1.0, 1.0]:
			var taille := _hasard.randf_range(5.0, 12.0)
			var p: Vector3 = t.pos + t.droite * ((t.largeur * 0.5 + taille * 0.35) * cote)
			rochers.append(_placement_rocher(p, taille))
		d += _hasard.randf_range(9.0, 15.0)
	_circuit._ajouter_en_masse(_rocher, rochers, _sans_couleur, _circuit._matiere(Color(0.2, 0.13, 0.12)))


## Un puits de lave : un trou dans le sol, des parois sombres, de la lave
## qui brille au fond et éclaire les parois.
func _construire_puits(o: Dictionary) -> void:
	var t: Dictionary = _circuit._cadre(o.a)
	var centre: Vector3 = t.pos + t.droite * float(o.decalage)
	var rayon: float = o.rayon + 2.0  # un peu plus large : le sol est découpé en carreaux
	var profondeur := 22.0

	var paroi := CylinderMesh.new()
	paroi.top_radius = rayon
	paroi.bottom_radius = rayon * 0.7
	paroi.height = profondeur
	paroi.cap_top = false
	paroi.radial_segments = 20
	var matiere_paroi: ShaderMaterial = _circuit._matiere(Color(0.18, 0.1, 0.09))
	var instance := MeshInstance3D.new()
	instance.mesh = paroi
	instance.material_override = matiere_paroi
	instance.position = centre - Vector3.UP * (profondeur * 0.5 - 0.3)
	_circuit.add_child(instance)
	# On voit l'intérieur de la paroi : on affiche aussi ses faces arrière.
	var paroi_interieure := instance.duplicate() as MeshInstance3D
	paroi_interieure.scale = Vector3(-1.0, 1.0, 1.0)  # retourne les faces
	_circuit.add_child(paroi_interieure)

	var lave := CylinderMesh.new()
	lave.top_radius = rayon * 0.72
	lave.bottom_radius = rayon * 0.72
	lave.height = 1.0
	var flaque := MeshInstance3D.new()
	flaque.mesh = lave
	flaque.material_override = _circuit._matiere(Color(1.0, 0.3, 0.05), 6.0)
	flaque.position = centre - Vector3.UP * (profondeur - 1.0)
	_circuit.add_child(flaque)

	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.35, 0.1)
	lumiere.light_energy = 4.0
	lumiere.omni_range = rayon * 3.5
	lumiere.position = centre - Vector3.UP * (profondeur * 0.5)
	_circuit.add_child(lumiere)


## Des rochers éparpillés dans le cratère, solides.
func _construire_rochers(o: Dictionary) -> void:
	var rochers: Array[Transform3D] = []
	var essais := 0
	while rochers.size() < int(o.nombre) and essais < 500:
		essais += 1
		var d := _hasard.randf_range(o.a, o.a + o.longueur)
		var t: Dictionary = _circuit._cadre(d)
		var decalage: float = _hasard.randf_range(-1.0, 1.0) * (t.largeur * 0.5 - 8.0)
		var taille := _hasard.randf_range(3.0, 8.0)
		if _circuit._dans_un_puits(d, decalage) or _pres_d_un_puits(d, decalage, taille + 10.0):
			continue
		var p: Vector3 = t.pos + t.droite * decalage
		var placement := _placement_rocher(p, taille)
		rochers.append(placement)
		var corps := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		forme.shape = BoxShape3D.new()
		forme.shape.size = placement.basis.get_scale() * 0.75
		corps.add_child(forme)
		corps.transform = Transform3D(placement.basis.orthonormalized(), placement.origin)
		_circuit.add_child(corps)
	_circuit._ajouter_en_masse(_rocher, rochers, _sans_couleur, _circuit._matiere(Color(0.26, 0.17, 0.15)))


func _construire_monstre(o: Dictionary) -> void:
	var monstre: Monstre = SCRIPT_MONSTRE.new()
	monstre.fabrique_matiere = _circuit._matiere
	monstre.point_au_hasard = func() -> Vector3:
		for essai in 30:
			var d := _hasard.randf_range(o.a + 40.0, o.a + o.longueur - 40.0)
			var t: Dictionary = _circuit._cadre(d)
			var decalage: float = _hasard.randf_range(-1.0, 1.0) * (t.largeur * 0.5 - 25.0)
			if not _pres_d_un_puits(d, decalage, 25.0):
				return t.pos + t.droite * decalage
		return _circuit._cadre(o.a + o.longueur * 0.5).pos
	monstre.hauteur_sol = func(p: Vector3) -> float:
		return _circuit._echantillon(_circuit.distance_sur_circuit(p)).y
	var depart: Dictionary = _circuit._cadre(o.a + o.longueur * 0.5)
	monstre.position = depart.pos
	_circuit.add_child(monstre)
	# Ses pas font trembler la caméra, d'autant plus qu'on est près.
	monstre.pas_lourd.connect(func(p: Vector3) -> void:
		var camera: Camera3D = _circuit.get_viewport().get_camera_3d()
		if camera != null and camera.has_method("secouer"):
			var distance: float = camera.global_position.distance_to(p)
			if distance < 300.0:
				camera.secouer(lerpf(25.0, 4.0, distance / 300.0)))


func _pres_d_un_puits(d: float, decalage: float, marge: float) -> bool:
	for o in _circuit._donnees.OBSTACLES:
		if o.type == "puits" and Vector2(d - o.a, decalage - o.decalage).length() < o.rayon + marge:
			return true
	return false


func _placement_rocher(p: Vector3, taille: float) -> Transform3D:
	var base := Basis.from_euler(Vector3(_hasard.randf_range(-0.4, 0.4), _hasard.randf() * TAU, _hasard.randf_range(-0.4, 0.4)))
	var echelle := Vector3(taille * _hasard.randf_range(0.8, 1.4), taille * _hasard.randf_range(0.5, 0.9), taille * _hasard.randf_range(0.8, 1.4))
	return Transform3D(base.scaled_local(echelle), p + Vector3.UP * echelle.y * 0.3)


## Un rocher à facettes : une sphère grossière aux sommets bousculés.
func _maillage_rocher() -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 7
	sphere.rings = 4
	var tableaux := sphere.get_mesh_arrays()
	var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	var bruit := FastNoiseLite.new()
	bruit.frequency = 2.0
	for i in sommets.size():
		var v := sommets[i]
		sommets[i] = v * (1.0 + 0.25 * bruit.get_noise_3dv(v * 3.0))
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	var brut := ArrayMesh.new()
	brut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	var st := SurfaceTool.new()
	st.create_from(brut, 0)
	st.deindex()
	st.generate_normals()  # sommets séparés : chaque face a sa normale, d'où les facettes
	return st.commit()
