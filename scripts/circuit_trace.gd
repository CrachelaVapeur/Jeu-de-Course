extends DecorBase
## Construit un vrai circuit à partir d'un fichier de données rangé dans
## circuits/ : la route (avec ses pentes et ses virages relevés), les murets,
## les obstacles (blocs, tremplins, trous, tunnels, ponts), les lignes de
## départ et d'arrivée, les piliers sous la route, le sol (mer, terre et
## montagnes, si le circuit a une carte du relief) et un décor de bâtiments.
## Gère aussi le chrono, les tours, et la réapparition quand on tombe.
##
## Pour créer un nouveau circuit : copier circuits/circuit_essai.gd, changer
## les points et les obstacles, puis choisir ce fichier dans « fichier_circuit »
## (Inspecteur, nœud Circuit).

@export_file("*.gd") var fichier_circuit := "res://circuits/circuit_essai.gd"
@export var pas := 2.0  ## distance entre deux tranches de route, en mètres (plus petit = plus lisse)
@export var graine := 3  ## change le tirage au hasard du décor
@export var nombre_batiments := 220
@export var epaisseur_route := 1.2
@export var hauteur_muret := 1.0

const SHADER_ROUTE := preload("res://shaders/route_circuit.gdshader")
const SHADER_EAU := preload("res://shaders/eau.gdshader")
const HAUTEUR_TUNNEL := 9.0

const COULEURS_BATIMENTS: Array[Color] = [
	Color(0.55, 0.28, 0.18), Color(0.42, 0.36, 0.32), Color(0.30, 0.40, 0.42),
	Color(0.62, 0.48, 0.30), Color(0.35, 0.25, 0.35), Color(0.48, 0.20, 0.15),
]
const COULEURS_NEONS: Array[Color] = [
	Color(0.2, 0.9, 1.0), Color(1.0, 0.2, 0.6), Color(1.0, 0.7, 0.1), Color(0.6, 0.3, 1.0),
]

var courbe := Curve3D.new()
var longueur := 0.0
var terrain: TerrainCarte  ## null si le circuit n'a pas de carte du relief
var ligne_depart := 0.0  ## distance de la ligne de départ
var ligne_arrivee := 0.0  ## distance de la ligne d'arrivée

var _donnees: GDScript
var _distances_points: Array[float] = []
var _tranches: Array[Dictionary] = []
var _hasard := RandomNumberGenerator.new()

# Chrono et tours
var _tour := 0
var _temps_tour := 0.0
var _temps_total := 0.0
var _meilleur_tour := INF
var _distance_precedente := -1.0
var _termine := false
var _affichage: Label


func _ready() -> void:
	_donnees = load(fichier_circuit)
	_hasard.seed = graine
	_construire_courbe()
	if _donnees.BOUCLE:
		ligne_depart = 0.0
		ligne_arrivee = 0.0
	else:
		ligne_depart = _constante("DEPART", 30.0)
		ligne_arrivee = longueur - _constante("ARRIVEE", 100.0)
	var relief: String = _constante("RELIEF", "")
	if relief != "":
		terrain = TerrainCarte.new(relief, _constante("ECHELLE", 1.0))
		terrain.niveau_mer = _constante("NIVEAU_MER", 0.0)
		terrain.hauteur_montagnes = _constante("HAUTEUR_MONTAGNES", 230.0)
	_decouper_en_tranches()
	_construire_route()
	_construire_murets()
	_construire_obstacles()
	_construire_piliers()
	_construire_portique(ligne_depart, Color(0.2, 0.9, 1.0))
	if not _donnees.BOUCLE:
		_construire_portique(ligne_arrivee, Color(1.0, 0.2, 0.6))
		# Un mur au bout de la route.
		var fin := _cadre(longueur - 2.0)
		_construire_bloc({"a": longueur - 2.0, "decalage": 0, "taille": [fin.largeur + 1.2, 4, 2]}, _matiere(Color(0.3, 0.28, 0.3)), _matiere(Color(1.0, 0.2, 0.6), 4.0))
	if terrain != null:
		_construire_terrain()
		var villes: Array = _constante("VILLES", [])
		var monuments: Array = _constante("MONUMENTS", [])
		Villes.new(self, _constante("ECHELLE", 1.0), graine).construire(villes, monuments)
		Cratere.new(self, graine).construire(_donnees.OBSTACLES)
	else:
		_construire_sol()
	_construire_batiments()
	_placer_vehicule()
	_creer_affichage()
	super()


func _physics_process(delta: float) -> void:
	if vehicule == null:
		return
	if Input.is_action_just_pressed("recommencer"):
		_remettre_chrono_a_zero()
	_suivre_les_tours(delta)
	# Tombé de la route (dans un trou, dans la mer, du haut d'une falaise) :
	# on réapparaît un peu plus tôt sur la route.
	var d := distance_sur_circuit(vehicule.global_position)
	if vehicule.global_position.y < _echantillon(d).y - 15.0:
		vehicule.reapparaitre()


# --- Tracé --------------------------------------------------------------------

## Distance (en mètres depuis la ligne de départ) du point du circuit le plus
## proche d'une position. Sert au chrono, et pourra servir aux adversaires IA.
func distance_sur_circuit(position_monde: Vector3) -> float:
	return courbe.get_closest_offset(position_monde)


## Une constante du fichier de circuit, ou une valeur par défaut si le
## fichier ne la donne pas.
func _constante(nom: String, defaut: Variant) -> Variant:
	return _donnees.get_script_constant_map().get(nom, defaut)


func _construire_courbe() -> void:
	var echelle: float = _constante("ECHELLE", 1.0)
	var points: Array[Vector3] = []
	for p in _donnees.POINTS:
		points.append(Vector3(p[0] * echelle, p[2], p[1] * echelle))
	if _donnees.BOUCLE:
		points.append(points[0])

	# Les « poignées » de chaque point sont calculées pour que la courbe
	# passe en douceur par tous les points (méthode de Catmull-Rom).
	var n := points.size()
	for i in n:
		var avant := _voisin(points, i - 1)
		var apres := _voisin(points, i + 1)
		var tangente := (apres - avant) / 6.0
		# Au sommet d'une butte, au fond d'un creux ou sur un plat, la route
		# reste horizontale : sinon elle « déborde » et creuse des bosses
		# qu'on n'a pas dessinées.
		if (points[i].y - avant.y) * (apres.y - points[i].y) <= 0.0:
			tangente.y = 0.0
		courbe.add_point(points[i], -tangente, tangente)

	courbe.bake_interval = 1.0
	longueur = courbe.get_baked_length()
	for p in points:
		_distances_points.append(courbe.get_closest_offset(p))
	if _donnees.BOUCLE:
		_distances_points[-1] = longueur

	var texte := "%s : %d m." % [_donnees.NOM, roundi(longueur)]
	# Pour un petit circuit, on affiche aussi la distance de chaque point.
	if _donnees.POINTS.size() <= 40:
		texte += " Points de passage :"
		for i in _donnees.POINTS.size():
			texte += " n°%d à %d m," % [i, roundi(_distances_points[i])]
	print(texte.trim_suffix(","))


func _voisin(points: Array[Vector3], i: int) -> Vector3:
	var n := points.size()
	if _donnees.BOUCLE:
		# Le dernier point est une copie du premier : on saute ce doublon.
		return points[posmod(i, n - 1)]
	return points[clampi(i, 0, n - 1)]


func _decouper_en_tranches() -> void:
	var nombre := ceili(longueur / pas)
	for i in nombre + 1:
		var d := minf(i * longueur / nombre, longueur)
		_tranches.append(_cadre(d))


## Le repère de la route à une distance donnée : position, direction (avant),
## côté droit et « haut » de la route (penché dans les virages relevés).
func _cadre(d: float) -> Dictionary:
	var pos := _echantillon(d)
	var avant := (_echantillon(d + 1.0) - _echantillon(d - 1.0)).normalized()
	var reglages := _reglages_a(d)
	var droite := avant.cross(Vector3.UP).normalized()
	droite = droite.rotated(avant, deg_to_rad(reglages.y))
	var haut := droite.cross(avant).normalized()
	return {"d": d, "pos": pos, "avant": avant, "droite": droite, "haut": haut, "largeur": reglages.x}


func _echantillon(d: float) -> Vector3:
	if _donnees.BOUCLE:
		d = fposmod(d, longueur)
	return courbe.sample_baked(clampf(d, 0.0, longueur), true)


## Largeur et dévers interpolés entre les points de passage.
func _reglages_a(d: float) -> Vector2:
	var points: Array = _donnees.POINTS
	var n := points.size()
	for i in _distances_points.size() - 1:
		var d0 := _distances_points[i]
		var d1 := _distances_points[i + 1]
		if d >= d0 and d <= d1:
			var t := (d - d0) / maxf(d1 - d0, 0.001)
			var a := _reglage_point(points[i])
			var b := _reglage_point(points[(i + 1) % n])
			return a.lerp(b, smoothstep(0.0, 1.0, t))
	return _reglage_point(points[0])


func _reglage_point(p: Array) -> Vector2:
	var devers: float = p[3] if p.size() > 3 else 0.0
	var largeur: float = p[4] if p.size() > 4 else _donnees.LARGEUR
	return Vector2(largeur, devers)


## Largeur de la route à l'endroit le plus proche d'un point vu de dessus.
func largeur_route_pres(p: Vector2) -> float:
	return _reglages_a(courbe.get_closest_offset(Vector3(p.x, 0.0, p.y))).x


func _obstacle_a(type: String, d: float, cote := "") -> bool:
	for o in _donnees.OBSTACLES:
		if o.type != type or d < o.a or d >= o.a + o.longueur:
			continue
		if cote == "" or not o.has("cote") or o.cote == "deux" or o.cote == cote:
			return true
	return false


func _bord(t: Dictionary, cote: float) -> Vector3:
	return t.pos + t.droite * (t.largeur * 0.5 * cote)


# --- Route et murets -------------------------------------------------------------

func _construire_route() -> void:
	var dessus := SurfaceTool.new()
	dessus.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dessous := SurfaceTool.new()
	dessous.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in _tranches.size() - 1:
		var a: Dictionary = _tranches[i]
		var b: Dictionary = _tranches[i + 1]
		if _obstacle_a("trou", (a.d + b.d) * 0.5):
			continue
		var al := _bord(a, -1.0)
		var ar := _bord(a, 1.0)
		var bl := _bord(b, -1.0)
		var br := _bord(b, 1.0)
		var uv_a: float = a.largeur * 0.5
		var uv_b: float = b.largeur * 0.5
		var milieu: float = (a.d + b.d) * 0.5
		if _obstacle_a("cratere", milieu):
			_construire_sol_cratere(dessus, a, b, milieu)
		else:
			_quad(dessus, [al, ar, br, bl], a.haut,
				[Vector2(-uv_a, a.d), Vector2(uv_a, a.d), Vector2(uv_b, b.d), Vector2(-uv_b, b.d)],
				[Vector2(uv_a, 0.0), Vector2(uv_a, 0.0), Vector2(uv_b, 0.0), Vector2(uv_b, 0.0)])

		# L'épaisseur de la route : visible au bord des trous et des ravins.
		var ea: Vector3 = a.haut * epaisseur_route
		var eb: Vector3 = b.haut * epaisseur_route
		_quad(dessous, [al - ea, al, bl, bl - eb], -a.droite)
		_quad(dessous, [ar, ar - ea, br - eb, br], a.droite)
		_quad(dessous, [ar - ea, al - ea, bl - eb, br - eb], -a.haut)
		# Les bouts de route au bord d'un trou sont fermés.
		if _obstacle_a("trou", b.d + pas * 0.5):
			_quad(dessous, [bl - eb, bl, br, br - eb], b.avant)
		if i > 0 and _obstacle_a("trou", a.d - pas * 0.5):
			_quad(dessous, [ar - ea, ar, al, al - ea], -a.avant)

	var matiere_route := ShaderMaterial.new()
	matiere_route.shader = SHADER_ROUTE
	matiere_route.set_shader_parameter("demi_largeur", _donnees.LARGEUR * 0.5)
	matiere_route.set_shader_parameter("ligne_depart", ligne_depart)
	if not _donnees.BOUCLE:
		matiere_route.set_shader_parameter("ligne_arrivee", ligne_arrivee)
	_ajouter_solide(dessus, matiere_route)
	_ajouter_solide(dessous, _matiere(Color(0.3, 0.27, 0.28)))


## Dans le cratère, le sol est découpé en petits carreaux pour pouvoir
## laisser des puits de lave (on n'y pose pas les carreaux).
## UV2.y = 1 indique au shader de la route que c'est le sol du cratère.
func _construire_sol_cratere(st: SurfaceTool, a: Dictionary, b: Dictionary, milieu: float) -> void:
	var demi_a: float = a.largeur * 0.5
	var demi_b: float = b.largeur * 0.5
	var nombre := ceili(maxf(a.largeur, b.largeur) / 4.0)
	for c in nombre:
		var f0 := -1.0 + 2.0 * c / nombre
		var f1 := -1.0 + 2.0 * (c + 1) / nombre
		if _dans_un_puits(milieu, (f0 + f1) * 0.5 * (demi_a + demi_b) * 0.5):
			continue
		var p := [
			a.pos + a.droite * (demi_a * f0), a.pos + a.droite * (demi_a * f1),
			b.pos + b.droite * (demi_b * f1), b.pos + b.droite * (demi_b * f0),
		]
		_quad(st, p, a.haut,
			[Vector2(demi_a * f0, a.d), Vector2(demi_a * f1, a.d), Vector2(demi_b * f1, b.d), Vector2(demi_b * f0, b.d)],
			[Vector2(demi_a, 1.0), Vector2(demi_a, 1.0), Vector2(demi_b, 1.0), Vector2(demi_b, 1.0)])


## Vrai si un point du cratère (distance sur le circuit, décalage latéral)
## tombe dans un puits de lave.
func _dans_un_puits(d: float, decalage: float) -> bool:
	for o in _donnees.OBSTACLES:
		if o.type == "puits" and Vector2(d - o.a, decalage - o.decalage).length() < o.rayon:
			return true
	return false


func _construire_murets() -> void:
	var murets := SurfaceTool.new()
	murets.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neons := SurfaceTool.new()
	neons.begin(Mesh.PRIMITIVE_TRIANGLES)
	var invisibles := SurfaceTool.new()
	invisibles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var epaisseur := 0.6

	for i in _tranches.size() - 1:
		var a: Dictionary = _tranches[i]
		var b: Dictionary = _tranches[i + 1]
		var milieu: float = (a.d + b.d) * 0.5
		if _obstacle_a("trou", milieu):
			continue
		for cote in [-1.0, 1.0]:
			if _obstacle_a("sans_muret", milieu, "gauche" if cote < 0.0 else "droite"):
				continue
			if _obstacle_a("cratere", milieu):
				# Un mur invisible, assez haut pour ne pas sortir du cratère.
				var ba := _bord(a, cote)
				var bb := _bord(b, cote)
				_quad(invisibles, [ba, ba + Vector3.UP * 4.0, bb + Vector3.UP * 4.0, bb], -a.droite * cote)
				continue
			var ia := _bord(a, cote)
			var ib := _bord(b, cote)
			var ha: Vector3 = a.haut * hauteur_muret
			var hb: Vector3 = b.haut * hauteur_muret
			var oa: Vector3 = a.droite * (epaisseur * cote)
			var ob: Vector3 = b.droite * (epaisseur * cote)
			var vers_route: Vector3 = -a.droite * cote
			_quad(murets, [ia, ia + ha, ib + hb, ib], vers_route)
			_quad(murets, [ia + ha, ia + ha + oa, ib + hb + ob, ib + hb], a.haut)
			_quad(murets, [ia + oa, ib + ob, ib + hb + ob, ia + ha + oa], -vers_route)

			# Bande lumineuse sur le dessus du muret.
			var la: Vector3 = ia + ha * 1.02 + oa * 0.25
			var lb: Vector3 = ib + hb * 1.02 + ob * 0.25
			var ra: Vector3 = ia + ha * 1.02 + oa * 0.75
			var rb: Vector3 = ib + hb * 1.02 + ob * 0.75
			neons.set_color(COULEURS_NEONS[0] if cote < 0.0 else COULEURS_NEONS[1])
			_quad(neons, [la, ra, rb, lb], a.haut)

	_ajouter_solide(murets, _matiere(Color(0.25, 0.24, 0.26)))
	_ajouter_visuel(neons, _matiere(Color.WHITE, 4.0))
	_ajouter_collision(invisibles)


# --- Obstacles -----------------------------------------------------------------

func _construire_obstacles() -> void:
	var matiere_bloc := _matiere(Color(0.62, 0.3, 0.16))
	var matiere_rayure := _matiere(Color(1.0, 0.7, 0.1), 3.0)
	var tremplins := SurfaceTool.new()
	tremplins.begin(Mesh.PRIMITIVE_TRIANGLES)

	for o in _donnees.OBSTACLES:
		match o.type:
			"bloc":
				_construire_bloc(o, matiere_bloc, matiere_rayure)
			"tremplin":
				_construire_tremplin(o, tremplins)
			"tunnel":
				_construire_tunnel(o)
			"pont":
				_construire_pont(o)

	_ajouter_solide(tremplins, _matiere(Color(0.95, 0.68, 0.12), 0.3))


func _construire_bloc(o: Dictionary, matiere: Material, matiere_rayure: Material) -> void:
	var t := _cadre(o.a)
	var taille := Vector3(o.taille[0], o.taille[1], o.taille[2])
	var base := Basis(t.droite, t.haut, -t.avant)
	var centre: Vector3 = t.pos + t.droite * float(o.decalage) + t.haut * (taille.y * 0.5)

	var corps := StaticBody3D.new()
	corps.transform = Transform3D(base, centre)
	add_child(corps)

	var forme := CollisionShape3D.new()
	forme.shape = BoxShape3D.new()
	forme.shape.size = taille
	corps.add_child(forme)

	var boite := BoxMesh.new()
	boite.size = taille
	var visuel := MeshInstance3D.new()
	visuel.mesh = boite
	visuel.material_override = matiere
	corps.add_child(visuel)

	# Une bande lumineuse pour repérer le bloc de loin.
	var bande := BoxMesh.new()
	bande.size = Vector3(taille.x + 0.04, 0.3, taille.z + 0.04)
	var visuel_bande := MeshInstance3D.new()
	visuel_bande.mesh = bande
	visuel_bande.material_override = matiere_rayure
	visuel_bande.position.y = taille.y * 0.25
	corps.add_child(visuel_bande)


## Un plan incliné sur toute la largeur, qui se termine par une chute nette :
## à pleine vitesse, le bolide décolle.
func _construire_tremplin(o: Dictionary, st: SurfaceTool) -> void:
	var precedente := {}
	var h_precedente := 0.0
	var nombre := maxi(ceili(o.longueur / pas), 1)
	for i in nombre + 1:
		var d: float = o.a + o.longueur * i / nombre
		var t := _cadre(d)
		var h: float = o.hauteur * float(i) / nombre
		if i > 0:
			var a := precedente
			var al: Vector3 = _bord(a, -1.0) + a.haut * h_precedente
			var ar: Vector3 = _bord(a, 1.0) + a.haut * h_precedente
			var bl: Vector3 = _bord(t, -1.0) + t.haut * h
			var br: Vector3 = _bord(t, 1.0) + t.haut * h
			_quad(st, [al, ar, br, bl], a.haut)
			_quad(st, [_bord(a, -1.0), al, bl, _bord(t, -1.0)], -a.droite)
			_quad(st, [ar, _bord(a, 1.0), _bord(t, 1.0), br], a.droite)
			if i == nombre:
				_quad(st, [bl, br, _bord(t, 1.0), _bord(t, -1.0)], t.avant)
		precedente = t
		h_precedente = h


## Un tunnel : murs, plafond, lampes au plafond, et une grande façade de
## béton à chaque entrée.
func _construire_tunnel(o: Dictionary) -> void:
	var parois := SurfaceTool.new()
	parois.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lampes: Array[Transform3D] = []
	var precedente := {}
	var nombre := maxi(ceili(o.longueur / pas), 1)
	for i in nombre + 1:
		var t := _cadre(o.a + o.longueur * float(i) / nombre)
		if i > 0:
			var a := precedente
			for cote in [-1.0, 1.0]:
				var bas_a: Vector3 = _bord(a, cote) + a.droite * (0.6 * cote) - a.haut * 0.5
				var bas_b: Vector3 = _bord(t, cote) + t.droite * (0.6 * cote) - t.haut * 0.5
				var haut_a: Vector3 = bas_a + Vector3.UP * HAUTEUR_TUNNEL
				var haut_b: Vector3 = bas_b + Vector3.UP * HAUTEUR_TUNNEL
				_quad(parois, [bas_a, haut_a, haut_b, bas_b], -a.droite * cote)
				# Le plafond monte un peu vers le milieu, comme une voûte.
				var milieu_a: Vector3 = a.pos + Vector3.UP * (HAUTEUR_TUNNEL + 2.5)
				var milieu_b: Vector3 = t.pos + Vector3.UP * (HAUTEUR_TUNNEL + 2.5)
				_quad(parois, [haut_a, milieu_a, milieu_b, haut_b], -Vector3.UP)
		precedente = t
	_ajouter_solide(parois, _matiere(Color(0.33, 0.31, 0.3)))

	var d: float = o.a + 6.0
	while d < o.a + o.longueur - 6.0:
		var t := _cadre(d)
		var base := Basis.looking_at(t.avant)
		lampes.append(Transform3D(base.scaled_local(Vector3(0.6, 0.25, 7.0)), t.pos + Vector3.UP * (HAUTEUR_TUNNEL + 2.2)))
		d += 16.0
	_ajouter_en_masse(BoxMesh.new(), lampes, [], _matiere(Color(1.0, 0.62, 0.25), 5.0))

	_construire_facade(_cadre(o.a))
	_construire_facade(_cadre(o.a + o.longueur))


func _construire_facade(t: Dictionary) -> void:
	var base := Basis.looking_at(Vector3(t.avant.x, 0.0, t.avant.z).normalized())
	var demi: float = t.largeur * 0.5 + 0.6
	var blocs: Array[Transform3D] = []
	for cote in [-1.0, 1.0]:
		blocs.append(Transform3D(base.scaled_local(Vector3(30.0, 70.0, 8.0)), t.pos + t.droite * ((demi + 15.0) * cote) + Vector3.UP * 5.0))
	blocs.append(Transform3D(base.scaled_local(Vector3(demi * 2.0 + 60.0, 30.0, 8.0)), t.pos + Vector3.UP * (HAUTEUR_TUNNEL + 2.5 + 15.0)))
	_ajouter_en_masse(BoxMesh.new(), blocs, [], _matiere(Color(0.36, 0.33, 0.32)))
	# Un bandeau lumineux au-dessus de l'entrée.
	var bandeau: Array[Transform3D] = [Transform3D(base.scaled_local(Vector3(demi * 2.0, 0.6, 8.4)), t.pos + Vector3.UP * (HAUTEUR_TUNNEL + 3.5))]
	_ajouter_en_masse(BoxMesh.new(), bandeau, [], _matiere(Color(1.0, 0.62, 0.25), 4.0))


## Un pont à haubans : deux paires de grands pylônes, d'où partent des
## câbles en éventail qui tiennent la route.
func _construire_pont(o: Dictionary) -> void:
	var pylones: Array[Transform3D] = []
	var cables: Array[Transform3D] = []
	var feux: Array[Transform3D] = []
	var hauteur_pylone := 75.0
	for fraction in [0.3, 0.7]:
		var t := _cadre(o.a + o.longueur * fraction)
		var base := Basis.looking_at(Vector3(t.avant.x, 0.0, t.avant.z).normalized())
		var sol := _hauteur_sol(t.pos.x, t.pos.z) - 5.0
		var sommet: float = t.pos.y + hauteur_pylone
		for cote in [-1.0, 1.0]:
			var pied: Vector3 = _bord(t, cote) + t.droite * (3.0 * cote)
			pylones.append(Transform3D(base.scaled_local(Vector3(3.5, sommet - sol, 3.5)), Vector3(pied.x, (sommet + sol) * 0.5, pied.z)))
			feux.append(Transform3D(base.scaled_local(Vector3(1.2, 1.2, 1.2)), Vector3(pied.x, sommet + 0.8, pied.z)))
			for k in range(1, 8):
				for sens in [-1.0, 1.0]:
					var accroche_t := _cadre(t.d + sens * k * 22.0)
					var accroche: Vector3 = _bord(accroche_t, cote) + accroche_t.droite * (0.8 * cote) + Vector3.UP * 1.0
					var haut := Vector3(pied.x, sommet - k * 3.0, pied.z)
					cables.append(_poutre(haut, accroche, 0.25))
		# Les traverses entre les deux pylônes, au-dessus de la route.
		var gauche: Vector3 = _bord(t, -1.0) - t.droite * 3.0
		var droite: Vector3 = _bord(t, 1.0) + t.droite * 3.0
		for h in [hauteur_pylone - 2.0, hauteur_pylone * 0.55]:
			pylones.append(_poutre(Vector3(gauche.x, t.pos.y + h, gauche.z), Vector3(droite.x, t.pos.y + h, droite.z), 2.5))
	_ajouter_en_masse(BoxMesh.new(), pylones, [], _matiere(Color(0.42, 0.40, 0.42)))
	_ajouter_en_masse(BoxMesh.new(), cables, [], _matiere(Color(0.75, 0.78, 0.85), 0.6))
	_ajouter_en_masse(BoxMesh.new(), feux, [], _matiere(Color(1.0, 0.1, 0.1), 8.0))


## Une poutre (une boîte allongée) entre deux points.
func _poutre(a: Vector3, b: Vector3, epaisseur: float) -> Transform3D:
	var axe := b - a
	var y := axe.normalized()
	var autre := Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT
	var x := y.cross(autre).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * epaisseur, y * axe.length(), z * epaisseur), (a + b) * 0.5)


# --- Piliers, portiques, sol et bâtiments --------------------------------------------------

func _hauteur_sol(x: float, z: float) -> float:
	if terrain != null:
		return terrain.hauteur_naturelle(x, z)
	return _donnees.HAUTEUR_SOL


func _construire_piliers() -> void:
	var piliers: Array[Transform3D] = []
	var d := 0.0
	while d < longueur:
		if not _obstacle_a("trou", d) and not _obstacle_a("tunnel", d) and not _obstacle_a("cratere", d):
			var t := _cadre(d)
			# Les routes larges ont deux rangées de piliers.
			var decalages := [0.0] if t.largeur < 30.0 else [-t.largeur * 0.3, t.largeur * 0.3]
			for decalage in decalages:
				var p: Vector3 = t.pos + t.droite * float(decalage)
				var bas := _hauteur_sol(p.x, p.z) - 2.0
				var haut: float = p.y - epaisseur_route
				if haut - bas > 3.0:
					piliers.append(Transform3D(Basis.from_scale(Vector3(3.0, haut - bas, 3.0)), Vector3(p.x, (haut + bas) * 0.5, p.z)))
		d += 40.0
	_ajouter_en_masse(BoxMesh.new(), piliers, [], _matiere(Color(0.36, 0.33, 0.33)))


## Un portique au-dessus de la route (départ ou arrivée).
func _construire_portique(d: float, couleur_neon: Color) -> void:
	var t := _cadre(d)
	var ecart: float = t.largeur * 0.5 + 2.5
	var hauteur := 12.0
	var base := Basis(t.droite, Vector3.UP, -t.avant)
	var elements: Array[Transform3D] = []
	for cote in [-1.0, 1.0]:
		elements.append(Transform3D(base.scaled_local(Vector3(1.6, hauteur + 20.0, 1.6)), t.pos + t.droite * (ecart * cote) + Vector3.UP * (hauteur * 0.5 - 10.0)))
	elements.append(Transform3D(base.scaled_local(Vector3(ecart * 2.0 + 1.6, 1.8, 2.2)), t.pos + Vector3.UP * hauteur))
	_ajouter_en_masse(BoxMesh.new(), elements, [], _matiere(Color(0.38, 0.34, 0.33)))
	var neon: Array[Transform3D] = [Transform3D(base.scaled_local(Vector3(ecart * 2.0 - 2.0, 0.4, 0.4)), t.pos + Vector3.UP * (hauteur - 1.1))]
	_ajouter_en_masse(BoxMesh.new(), neon, [], _matiere(couleur_neon, 5.0))


## Les limites du circuit vu de dessus (x, z), avec une marge.
func _emprise(marge: float) -> Rect2:
	var mini := Vector2(INF, INF)
	var maxi := Vector2(-INF, -INF)
	for t in _tranches:
		mini = Vector2(minf(mini.x, t.pos.x), minf(mini.y, t.pos.z))
		maxi = Vector2(maxf(maxi.x, t.pos.x), maxf(maxi.y, t.pos.z))
	return Rect2(mini, maxi - mini).grow(marge)


## Sol plat (circuits sans carte du relief).
func _construire_sol() -> void:
	var zone := _emprise(1500.0)
	var sol := PlaneMesh.new()
	sol.size = zone.size
	var instance := MeshInstance3D.new()
	instance.mesh = sol
	instance.material_override = _matiere(Color(0.45, 0.25, 0.18))
	instance.position = Vector3(zone.get_center().x, _donnees.HAUTEUR_SOL, zone.get_center().y)
	add_child(instance)


## Mer, terre et montagnes, d'après la carte du relief.
func _construire_terrain() -> void:
	var zone := _emprise(2000.0)
	var debut := Time.get_ticks_msec()
	var zone_a := func(d: float) -> int:
		if _obstacle_a("tunnel", d):
			return TerrainCarte.ZONE_TUNNEL
		if _obstacle_a("cratere", d):
			return TerrainCarte.ZONE_CRATERE
		return TerrainCarte.ZONE_ROUTE
	var mesh := terrain.construire(_tranches, zone_a, zone.position, zone.end)
	_ajouter_visuel_mesh(mesh, _matiere(Color.WHITE))
	print("Terrain construit en %d ms" % (Time.get_ticks_msec() - debut))

	var mer := PlaneMesh.new()
	mer.size = zone.size * 3.0
	var matiere_mer := ShaderMaterial.new()
	matiere_mer.shader = SHADER_EAU
	_matieres_decor.append(matiere_mer)
	var instance := MeshInstance3D.new()
	instance.mesh = mer
	instance.material_override = matiere_mer
	instance.position = Vector3(zone.get_center().x, terrain.niveau_mer, zone.get_center().y)
	add_child(instance)


## Bâtiments tirés au hasard autour du circuit, jamais sur la route.
func _construire_batiments() -> void:
	var nombre: int = _constante("BATIMENTS", nombre_batiments)
	if nombre <= 0:
		return
	var zone := _emprise(500.0)
	var sol_y: float = _donnees.HAUTEUR_SOL
	var batiments: Array[Transform3D] = []
	var couleurs: Array[Color] = []
	var marge: float = _donnees.LARGEUR * 0.5 + 18.0
	var essais := 0
	while batiments.size() < nombre and essais < nombre * 20:
		essais += 1
		var x := _hasard.randf_range(zone.position.x, zone.end.x)
		var z := _hasard.randf_range(zone.position.y, zone.end.y)
		var taille := Vector3(_hasard.randf_range(10, 35), _hasard.randf_range(30, 110), _hasard.randf_range(10, 35))
		var proche := courbe.get_closest_point(Vector3(x, 0.0, z))
		var ecart := Vector2(proche.x - x, proche.z - z).length()
		if ecart < marge + maxf(taille.x, taille.z) * 0.75:
			continue
		batiments.append(Transform3D(Basis.from_scale(taille), Vector3(x, sol_y + taille.y * 0.5, z)))
		var couleur := COULEURS_BATIMENTS[_hasard.randi() % COULEURS_BATIMENTS.size()]
		couleurs.append(couleur if ecart < 250.0 else couleur.darkened(0.3))
	_ajouter_en_masse(BoxMesh.new(), batiments, couleurs, _matiere(Color.WHITE))


# --- Véhicule, chrono et tours -----------------------------------------------------

func _placer_vehicule() -> void:
	if vehicule == null:
		return
	# On part juste avant la ligne : le chrono démarre en la franchissant.
	var t := _cadre(longueur - 12.0 if _donnees.BOUCLE else ligne_depart - 14.0)
	var avant := Vector3(t.avant.x, 0.0, t.avant.z).normalized()
	vehicule.piste_droite = false
	# La chute est surveillée par le circuit (voir _physics_process) ; le
	# bolide ne garde qu'une limite de secours, tout en bas.
	vehicule.hauteur_chute = _donnees.HAUTEUR_SOL - 50.0
	vehicule.global_transform = Transform3D(Basis.looking_at(avant), t.pos + t.haut * 0.3)


func _creer_affichage() -> void:
	var calque := CanvasLayer.new()
	add_child(calque)
	_affichage = Label.new()
	_affichage.anchor_left = 1.0
	_affichage.anchor_right = 1.0
	_affichage.offset_left = -520.0
	_affichage.offset_right = -40.0
	_affichage.offset_top = 24.0
	_affichage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_affichage.add_theme_font_size_override("font_size", 30)
	_affichage.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_affichage.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.05))
	_affichage.add_theme_constant_override("outline_size", 10)
	calque.add_child(_affichage)
	_mettre_a_jour_affichage()


func _suivre_les_tours(delta: float) -> void:
	var d := distance_sur_circuit(vehicule.global_position)
	if _tour > 0 and not _termine:
		_temps_tour += delta
		_temps_total += delta

	if _donnees.BOUCLE and _distance_precedente >= 0.0:
		var quart := longueur * 0.25
		if _distance_precedente > longueur - quart and d < quart:
			_ligne_franchie()
		elif _distance_precedente < quart and d > longueur - quart and _tour > 0:
			_tour -= 1  # franchie à l'envers
	elif not _donnees.BOUCLE and _distance_precedente >= 0.0:
		# Course d'un point à un autre : une ligne de départ, une d'arrivée.
		if _tour == 0 and _distance_precedente < ligne_depart and d >= ligne_depart:
			_tour = 1
		elif _tour == 1 and d >= ligne_arrivee:
			_ligne_franchie()
	_distance_precedente = d
	_mettre_a_jour_affichage()


func _ligne_franchie() -> void:
	if _termine:
		return
	if _tour > 0:
		_meilleur_tour = minf(_meilleur_tour, _temps_tour)
	if _tour >= _donnees.TOURS:
		_termine = true
		return
	_tour += 1
	_temps_tour = 0.0


func _remettre_chrono_a_zero() -> void:
	_tour = 0
	_temps_tour = 0.0
	_temps_total = 0.0
	_termine = false
	_distance_precedente = -1.0


func _mettre_a_jour_affichage() -> void:
	if _affichage == null:
		return
	var texte := ""
	if _termine:
		texte = "Terminé ! %s" % _format_temps(_temps_total)
	elif _tour == 0:
		texte = "Chrono : franchis la ligne"
	elif _donnees.BOUCLE:
		texte = "Tour %d / %d   %s" % [_tour, _donnees.TOURS, _format_temps(_temps_tour)]
	else:
		texte = "%s   %d m" % [_format_temps(_temps_total), maxi(roundi(ligne_arrivee - _distance_precedente), 0)]
	if _meilleur_tour < INF:
		texte += "\n%s %s" % ["Meilleur tour" if _donnees.BOUCLE else "Meilleur temps", _format_temps(_meilleur_tour)]
	_affichage.text = texte


func _format_temps(secondes: float) -> String:
	return "%d:%05.2f" % [int(secondes / 60.0), fmod(secondes, 60.0)]


# --- Outils -----------------------------------------------------------------

## Ajoute un quadrilatère (deux triangles). Les sommets sont donnés dans
## l'ordre du tour ; « normale » indique le côté visible.
func _quad(st: SurfaceTool, p: Array, normale: Vector3, uv: Array = [], uv2: Array = []) -> void:
	for tri in [[0, 1, 2], [0, 2, 3]]:
		var ordre: Array = tri
		# Godot affiche les triangles dont les sommets tournent dans le sens
		# des aiguilles d'une montre vus du côté visible : on remet dans l'ordre.
		var a: Vector3 = p[ordre[0]]
		var b: Vector3 = p[ordre[1]]
		var c: Vector3 = p[ordre[2]]
		if (b - a).cross(c - a).dot(normale) > 0.0:
			ordre = [ordre[0], ordre[2], ordre[1]]
		for k in ordre:
			st.set_normal(normale)
			if not uv.is_empty():
				st.set_uv(uv[k])
			if not uv2.is_empty():
				st.set_uv2(uv2[k])
			st.add_vertex(p[k])


## Ajoute un objet visible ET solide (le bolide roule ou bute dessus).
func _ajouter_solide(st: SurfaceTool, matiere: Material) -> void:
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return
	_ajouter_visuel_mesh(mesh, matiere)
	_ajouter_collision_mesh(mesh)


## Ajoute un objet solide mais invisible.
func _ajouter_collision(st: SurfaceTool) -> void:
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		_ajouter_collision_mesh(mesh)


func _ajouter_collision_mesh(mesh: Mesh) -> void:
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var trimesh := mesh.create_trimesh_shape()
	trimesh.backface_collision = true
	forme.shape = trimesh
	corps.add_child(forme)
	add_child(corps)


func _ajouter_visuel(st: SurfaceTool, matiere: Material) -> void:
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		_ajouter_visuel_mesh(mesh, matiere)


func _ajouter_visuel_mesh(mesh: Mesh, matiere: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = matiere
	add_child(instance)


func _ajouter_en_masse(mesh: Mesh, placements: Array[Transform3D], couleurs: Array[Color], matiere: Material) -> void:
	if placements.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not couleurs.is_empty()
	multi.mesh = mesh
	multi.instance_count = placements.size()
	for i in placements.size():
		multi.set_instance_transform(i, placements[i])
		if multi.use_colors:
			multi.set_instance_color(i, couleurs[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = matiere
	add_child(instance)
