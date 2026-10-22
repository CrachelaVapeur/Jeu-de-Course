extends Node3D
## Construit le circuit d'essai par le code : une longue ligne droite dans une
## ville industrielle rouillée, avec portiques, murets et néons.
##
## Le décor est un « motif » de 1200 m tiré au hasard puis recopié bout à bout.
## Comme il se répète, on peut renvoyer le bolide au début sans que ça se voie
## (voir _boucler_circuit dans vehicule.gd) : la ligne droite paraît infinie.
##
## Pour changer le décor, changer « graine » (un autre tirage au hasard) ou
## les réglages ci-dessous, puis relancer.

@export var graine := 7
@export var longueur_motif := 1200.0
@export var demi_largeur := 15.0
@export var ecart_portiques := 60.0  ## doit diviser longueur_motif
@export var nombre_batiments := 70  ## par côté et par motif
@export var vehicule: Vehicule  ## sert à passer le décor en noir et blanc pendant le boost
@export var environnement: WorldEnvironment  ## le ciel et la brume passent aussi en noir et blanc
@export var saturation_boost := 2.0  ## saturation de l'image en boost : seules la route et le bolide, encore en couleur, en profitent
@export var contraste_boost := 1.35  ## contraste de l'image en boost
@export var glow_boost := 1.4  ## force du halo lumineux en boost
@export var bloom_boost := 0.2  ## voile lumineux doux sur toute l'image en boost

const SHADER_TOON := preload("res://shaders/toon.gdshader")
const SHADER_ROUTE := preload("res://shaders/route.gdshader")

# Palette « grunge SF » : rouilles, bétons sales, bleus-verts passés.
const COULEURS_BATIMENTS: Array[Color] = [
	Color(0.55, 0.28, 0.18), Color(0.42, 0.36, 0.32), Color(0.30, 0.40, 0.42),
	Color(0.62, 0.48, 0.30), Color(0.35, 0.25, 0.35), Color(0.48, 0.20, 0.15),
]
const COULEURS_NEONS: Array[Color] = [
	Color(0.2, 0.9, 1.0), Color(1.0, 0.2, 0.6), Color(1.0, 0.7, 0.1), Color(0.6, 0.3, 1.0),
]

# Nombre de recopies du motif : une derrière le départ, trois devant.
const COPIES := [-1, 0, 1, 2]

var _hasard := RandomNumberGenerator.new()
var _matieres_decor: Array[ShaderMaterial] = []
var _noir_et_blanc := 0.0
var _couleurs_ciel: Array[Color] = []
var _couleur_brume := Color.WHITE
var _saturation_normale := 1.0
var _contraste_normal := 1.0
var _glow_normal := 0.9
var _bloom_normal := 0.05


func _ready() -> void:
	_hasard.seed = graine
	_construire_sol_et_route()
	_construire_murets()
	_construire_portiques()
	_construire_batiments()
	_memoriser_ciel()


func _process(_delta: float) -> void:
	if vehicule == null or is_equal_approx(vehicule.distorsion, _noir_et_blanc):
		return
	_noir_et_blanc = vehicule.distorsion
	_appliquer_effets_boost(_noir_et_blanc)


func _construire_sol_et_route() -> void:
	var debut := longueur_motif  # derrière le départ
	var fin: float = -longueur_motif * (COPIES.max() + 1)
	var longueur := debut - fin

	var route := PlaneMesh.new()
	route.size = Vector2(demi_largeur * 2.0, longueur)
	var matiere_route := ShaderMaterial.new()
	matiere_route.shader = SHADER_ROUTE
	matiere_route.set_shader_parameter("demi_largeur", demi_largeur)
	route.material = matiere_route
	_ajouter_mesh(route, Vector3(0.0, 0.0, (debut + fin) * 0.5))

	var sol := PlaneMesh.new()
	sol.size = Vector2(3000.0, longueur)
	sol.material = _matiere(Color(0.45, 0.25, 0.18))
	_ajouter_mesh(sol, Vector3(0.0, -0.05, (debut + fin) * 0.5))


func _construire_murets() -> void:
	var blocs: Array[Transform3D] = []
	var neons: Array[Transform3D] = []
	var couleurs_neons: Array[Color] = []
	var pas := 6.0
	var z := 0.0
	while z > -longueur_motif:
		for cote in [-1.0, 1.0]:
			var x: float = cote * (demi_largeur + 0.3)
			blocs.append(Transform3D(Basis.from_scale(Vector3(0.6, 1.0, pas - 0.5)), Vector3(x, 0.5, z)))
			neons.append(Transform3D(Basis.from_scale(Vector3(0.65, 0.12, pas - 0.5)), Vector3(x, 1.06, z)))
			couleurs_neons.append(COULEURS_NEONS[0] if cote < 0.0 else COULEURS_NEONS[1])
		z -= pas

	_ajouter_en_masse(BoxMesh.new(), blocs, [], _matiere(Color(0.25, 0.24, 0.26)))
	_ajouter_en_masse(BoxMesh.new(), neons, couleurs_neons, _matiere(Color.WHITE, 4.0))


func _construire_portiques() -> void:
	var piliers: Array[Transform3D] = []
	var poutres: Array[Transform3D] = []
	var neons: Array[Transform3D] = []
	var couleurs_neons: Array[Color] = []
	var hauteur := 13.0
	var ecart := demi_largeur + 2.5
	var z := 0.0
	var i := 0
	while z > -longueur_motif:
		for cote in [-1.0, 1.0]:
			piliers.append(Transform3D(Basis.from_scale(Vector3(1.6, hauteur, 1.6)), Vector3(cote * ecart, hauteur * 0.5, z)))
		poutres.append(Transform3D(Basis.from_scale(Vector3(ecart * 2.0 + 1.6, 1.8, 2.2)), Vector3(0.0, hauteur, z)))
		neons.append(Transform3D(Basis.from_scale(Vector3(ecart * 2.0 - 2.0, 0.35, 0.35)), Vector3(0.0, hauteur - 1.05, z)))
		couleurs_neons.append(COULEURS_NEONS[i % COULEURS_NEONS.size()])
		z -= ecart_portiques
		i += 1

	var metal := _matiere(Color(0.38, 0.34, 0.33))
	_ajouter_en_masse(BoxMesh.new(), piliers, [], metal)
	_ajouter_en_masse(BoxMesh.new(), poutres, [], metal)
	_ajouter_en_masse(BoxMesh.new(), neons, couleurs_neons, _matiere(Color.WHITE, 5.0))


func _construire_batiments() -> void:
	var batiments: Array[Transform3D] = []
	var couleurs: Array[Color] = []
	var enseignes: Array[Transform3D] = []
	var couleurs_enseignes: Array[Color] = []

	for cote in [-1.0, 1.0]:
		# Bâtiments proches : ils défilent vite et donnent la vitesse.
		for i in nombre_batiments:
			var taille := Vector3(_hasard.randf_range(8, 28), _hasard.randf_range(10, 70), _hasard.randf_range(8, 28))
			var x: float = cote * (demi_largeur + 8.0 + taille.x * 0.5 + _hasard.randf_range(0, 60))
			var z := _hasard.randf_range(0.0, -longueur_motif)
			batiments.append(Transform3D(Basis.from_scale(taille), Vector3(x, taille.y * 0.5, z)))
			couleurs.append(COULEURS_BATIMENTS[_hasard.randi() % COULEURS_BATIMENTS.size()])

			# Une enseigne lumineuse sur la façade côté piste, une fois sur trois.
			if _hasard.randf() < 0.35:
				var h := _hasard.randf_range(4.0, taille.y - 2.0)
				var facade: float = x - cote * (taille.x * 0.5 + 0.1)
				enseignes.append(Transform3D(
					Basis.from_scale(Vector3(0.2, _hasard.randf_range(1.0, 4.0), taille.z * _hasard.randf_range(0.3, 0.8))),
					Vector3(facade, h, z)))
				couleurs_enseignes.append(COULEURS_NEONS[_hasard.randi() % COULEURS_NEONS.size()])

		# Tours lointaines : la silhouette de la ville à l'horizon.
		for i in int(nombre_batiments / 3.0):
			var taille := Vector3(_hasard.randf_range(20, 60), _hasard.randf_range(80, 260), _hasard.randf_range(20, 60))
			var x: float = cote * _hasard.randf_range(180, 600)
			var z := _hasard.randf_range(0.0, -longueur_motif)
			batiments.append(Transform3D(Basis.from_scale(taille), Vector3(x, taille.y * 0.5, z)))
			couleurs.append(COULEURS_BATIMENTS[_hasard.randi() % COULEURS_BATIMENTS.size()].darkened(0.3))

	_ajouter_en_masse(BoxMesh.new(), batiments, couleurs, _matiere(Color.WHITE))
	_ajouter_en_masse(BoxMesh.new(), enseignes, couleurs_enseignes, _matiere(Color.WHITE, 4.0))


# --- Effets d'ambiance en boost ---------------------------------------------
# Noir et blanc : la route et le bolide gardent leurs couleurs, seuls le décor,
# le ciel et la brume (qui teinte les bâtiments lointains) perdent les leurs.
# Contraste, saturation et halo lumineux montent en même temps.

func _memoriser_ciel() -> void:
	if environnement == null:
		return
	var env := environnement.environment
	var ciel := env.sky.sky_material as ProceduralSkyMaterial
	_couleurs_ciel.assign([
		ciel.sky_top_color, ciel.sky_horizon_color,
		ciel.ground_bottom_color, ciel.ground_horizon_color,
	])
	_couleur_brume = env.fog_light_color
	_saturation_normale = env.adjustment_saturation
	_contraste_normal = env.adjustment_contrast
	_glow_normal = env.glow_intensity
	_bloom_normal = env.glow_bloom


func _appliquer_effets_boost(valeur: float) -> void:
	for m in _matieres_decor:
		m.set_shader_parameter("noir_et_blanc", valeur)
	if environnement == null or _couleurs_ciel.is_empty():
		return
	var env := environnement.environment
	var ciel := env.sky.sky_material as ProceduralSkyMaterial
	ciel.sky_top_color = _vers_gris(_couleurs_ciel[0], valeur)
	ciel.sky_horizon_color = _vers_gris(_couleurs_ciel[1], valeur)
	ciel.ground_bottom_color = _vers_gris(_couleurs_ciel[2], valeur)
	ciel.ground_horizon_color = _vers_gris(_couleurs_ciel[3], valeur)
	env.fog_light_color = _vers_gris(_couleur_brume, valeur)
	# Le gris ne change pas quand on monte la saturation : seules les couleurs restantes ressortent.
	env.adjustment_saturation = lerpf(_saturation_normale, saturation_boost, valeur)
	env.adjustment_contrast = lerpf(_contraste_normal, contraste_boost, valeur)
	# Halo doux : les néons et les lumières bavent, ce qui donne un côté rêveur.
	env.glow_intensity = lerpf(_glow_normal, glow_boost, valeur)
	env.glow_bloom = lerpf(_bloom_normal, bloom_boost, valeur)


func _vers_gris(couleur: Color, valeur: float) -> Color:
	var gris := couleur.get_luminance()
	return couleur.lerp(Color(gris, gris, gris, couleur.a), valeur)


# --- Outils -----------------------------------------------------------------

func _matiere(couleur: Color, force_emission := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_TOON
	m.set_shader_parameter("couleur", couleur)
	m.set_shader_parameter("force_emission", force_emission)
	_matieres_decor.append(m)
	return m


func _ajouter_mesh(mesh: Mesh, position_mesh: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_mesh
	add_child(instance)


## Affiche le même objet des centaines de fois en une seule fois (MultiMesh),
## et recopie le motif devant et derrière. Beaucoup plus rapide que de créer
## un nœud par bâtiment.
func _ajouter_en_masse(mesh: Mesh, placements: Array[Transform3D], couleurs: Array[Color], matiere: Material) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not couleurs.is_empty()
	multi.mesh = mesh
	multi.instance_count = placements.size() * COPIES.size()

	var n := 0
	for copie in COPIES:
		var decalage := Vector3(0.0, 0.0, -longueur_motif * copie)
		for i in placements.size():
			multi.set_instance_transform(n, placements[i].translated(decalage))
			if multi.use_colors:
				multi.set_instance_color(n, couleurs[i])
			n += 1

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = matiere
	add_child(instance)
