class_name TerrainCarte
extends RefCounted
## Le sol d'un circuit : mer, terre ferme et montagnes, lus dans une petite
## image « relief » (rouge = montagnes, vert = terre, noir = mer). Les
## montagnes sont taillées en marches, avec des falaises comme dans Redline.
##
## Le sol s'adapte à la route : il est creusé quand la route passe dans la
## montagne, il remonte sous la route quand elle frôle le sol, et il reste
## au-dessus des tunnels.

var niveau_mer := 0.0
var hauteur_montagnes := 230.0
var hauteur_marche := 26.0  ## hauteur d'une marche de falaise

var _image: Image
var _metres_par_pixel := 1.0
var _bruit := FastNoiseLite.new()
var _bruit_fin := FastNoiseLite.new()


func _init(chemin_image: String, echelle_carte: float, largeur_carte_px := 1920.0) -> void:
	var texture: Texture2D = load(chemin_image)
	_image = texture.get_image()
	if _image.is_compressed():
		_image.decompress()
	_metres_par_pixel = echelle_carte * largeur_carte_px / _image.get_width()
	# Bruit « en crêtes » : des arêtes et des vallées, comme une vraie chaîne.
	_bruit.seed = 7
	_bruit.frequency = 1.0 / 1400.0
	_bruit.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_bruit.fractal_octaves = 4
	_bruit_fin.seed = 11
	_bruit_fin.frequency = 1.0 / 120.0


## Hauteur du sol « naturel », avant que la route ne le creuse.
func hauteur_naturelle(x: float, z: float) -> float:
	var c := _lire(x / _metres_par_pixel, z / _metres_par_pixel)
	var terre := smoothstep(0.3, 0.7, c.g)
	var h := lerpf(niveau_mer - 25.0, niveau_mer + 6.0 + _bruit_fin.get_noise_2d(x, z) * 3.0, terre)
	var montagne := smoothstep(0.05, 0.9, c.r)
	if montagne > 0.0:
		var crete := clampf(_bruit.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
		var relief := montagne * hauteur_montagnes * (0.15 + 0.85 * pow(crete, 1.5))
		# Des marches : de longs plateaux, puis une falaise presque droite.
		var k := relief / hauteur_marche
		relief = (floorf(k) + smoothstep(0.55, 0.95, k - floorf(k))) * hauteur_marche
		h += relief
	return h


## Construit le maillage du sol autour de la route.
## tranches : les tranches de la route (voir circuit_trace.gd) ;
## dans_tunnel : une fonction qui dit si une distance est dans un tunnel.
func construire(tranches: Array[Dictionary], dans_tunnel: Callable, coin_min: Vector2, coin_max: Vector2, pas_grille := 20.0) -> ArrayMesh:
	var nx := ceili((coin_max.x - coin_min.x) / pas_grille) + 1
	var nz := ceili((coin_max.y - coin_min.y) / pas_grille) + 1
	var total := nx * nz

	var hauteurs := PackedFloat32Array()
	hauteurs.resize(total)
	for j in nz:
		for i in nx:
			hauteurs[j * nx + i] = hauteur_naturelle(coin_min.x + i * pas_grille, coin_min.y + j * pas_grille)

	# Pour chaque point du sol proche de la route : la tranche la plus proche.
	var distance := PackedFloat32Array()
	distance.resize(total)
	distance.fill(INF)
	var hauteur_route := PackedFloat32Array()
	hauteur_route.resize(total)
	var demi_largeur := PackedFloat32Array()
	demi_largeur.resize(total)
	var tunnel := PackedByteArray()
	tunnel.resize(total)
	for n in range(0, tranches.size(), 2):
		var t: Dictionary = tranches[n]
		var demi: float = t.largeur * 0.5
		var rayon := demi + 75.0
		var pos: Vector3 = t.pos
		var en_tunnel: bool = dans_tunnel.call(t.d)
		var i0 := maxi(floori((pos.x - rayon - coin_min.x) / pas_grille), 0)
		var i1 := mini(ceili((pos.x + rayon - coin_min.x) / pas_grille), nx - 1)
		var j0 := maxi(floori((pos.z - rayon - coin_min.y) / pas_grille), 0)
		var j1 := mini(ceili((pos.z + rayon - coin_min.y) / pas_grille), nz - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var k := j * nx + i
				var d := Vector2(coin_min.x + i * pas_grille - pos.x, coin_min.y + j * pas_grille - pos.z).length()
				if d < distance[k]:
					distance[k] = d
					hauteur_route[k] = pos.y
					demi_largeur[k] = demi
					tunnel[k] = 1 if en_tunnel else 0

	for k in total:
		var d := distance[k]
		if d == INF:
			continue
		var naturel := hauteurs[k]
		var route := hauteur_route[k]
		var demi := demi_largeur[k]
		if tunnel[k] == 1:
			# La montagne reste au-dessus du tunnel.
			if d < demi + 30.0:
				hauteurs[k] = maxf(naturel, route + 20.0)
		elif naturel > route - 1.5:
			# La route passe dans la montagne : on creuse une tranchée.
			hauteurs[k] = lerpf(route - 1.5, naturel, smoothstep(demi + 20.0, demi + 70.0, d))
		elif route - naturel < 10.0 and route > niveau_mer + 2.0:
			# La route frôle le sol : le sol remonte jusqu'à elle (remblai).
			hauteurs[k] = lerpf(route - 0.4, naturel, smoothstep(demi + 8.0, demi + 45.0, d))

	return _maillage(hauteurs, nx, nz, coin_min, pas_grille)


func _maillage(hauteurs: PackedFloat32Array, nx: int, nz: int, coin_min: Vector2, pas_grille: float) -> ArrayMesh:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var couleurs := PackedColorArray()
	sommets.resize(nx * nz)
	normales.resize(nx * nz)
	couleurs.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k := j * nx + i
			var h := hauteurs[k]
			sommets[k] = Vector3(coin_min.x + i * pas_grille, h, coin_min.y + j * pas_grille)
			var gauche := hauteurs[j * nx + maxi(i - 1, 0)]
			var droite := hauteurs[j * nx + mini(i + 1, nx - 1)]
			var haut := hauteurs[maxi(j - 1, 0) * nx + i]
			var bas := hauteurs[mini(j + 1, nz - 1) * nx + i]
			var n := Vector3(gauche - droite, 2.0 * pas_grille, haut - bas).normalized()
			normales[k] = n
			# Les couleurs de sommets ne sont pas converties automatiquement :
			# on les passe de sRGB (ce qu'on écrit) en linéaire (ce qu'attend le rendu).
			couleurs[k] = _couleur(h, n.y).srgb_to_linear()

	var indices := PackedInt32Array()
	indices.resize((nx - 1) * (nz - 1) * 6)
	var c := 0
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var d := a + nx
			var e := d + 1
			# Sens des aiguilles d'une montre vu du dessus : face visible vers le ciel.
			indices[c] = a
			indices[c + 1] = b
			indices[c + 2] = d
			indices[c + 3] = b
			indices[c + 4] = e
			indices[c + 5] = d
			c += 6

	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_COLOR] = couleurs
	tableaux[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	return mesh


## Couleurs inspirées des falaises de Redline : plateaux sable, parois brunes,
## sommets gris clair.
func _couleur(h: float, pente_douce: float) -> Color:
	if h < niveau_mer - 1.0:
		return Color(0.10, 0.12, 0.18)
	var plateau := Color(0.62, 0.47, 0.32)
	var paroi := Color(0.30, 0.17, 0.11)
	var sommet := Color(0.55, 0.55, 0.6)
	var plaine := Color(0.24, 0.21, 0.21)
	var couleur := plaine.lerp(plateau, smoothstep(niveau_mer + 15.0, niveau_mer + 45.0, h))
	couleur = couleur.lerp(sommet, smoothstep(160.0, 220.0, h))
	return couleur.lerp(paroi, 1.0 - smoothstep(0.55, 0.8, pente_douce))


func _lire(u: float, v: float) -> Color:
	var largeur := _image.get_width()
	var hauteur := _image.get_height()
	u = clampf(u, 0.0, largeur - 1.001)
	v = clampf(v, 0.0, hauteur - 1.001)
	var i := int(u)
	var j := int(v)
	var fu := u - i
	var fv := v - j
	var haut := _image.get_pixel(i, j).lerp(_image.get_pixel(i + 1, j), fu)
	var bas := _image.get_pixel(i, j + 1).lerp(_image.get_pixel(i + 1, j + 1), fu)
	return haut.lerp(bas, fv)
