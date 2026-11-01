extends MultiMeshInstance3D
## La fumée des pneus pendant un dérapage : des nuages 3D low poly (icosaèdres à
## facettes) semés régulièrement le long du chemin de chaque roue, donc une
## traînée continue même à 400 km/h. Chaque nuage monte un peu, grossit puis
## rétrécit jusqu'à disparaître.

@export var nombre_max := 900  ## nuages en vie en même temps (toutes roues)
@export var espacement := 0.45  ## distance entre deux nuages le long du chemin (m)
@export var duree_vie := 1.3  ## s
@export var taille_min := 0.7
@export var taille_max := 1.2
@export var montee := 1.4  ## m/s vers le haut
@export var dispersion := 0.9  ## m/s de dérive sur les côtés

var _suivant := 0
var _actif: Array[bool] = []
var _age: PackedFloat32Array
var _taille: PackedFloat32Array
var _position: PackedVector3Array
var _vitesse: PackedVector3Array
var _orientation: Array[Basis] = []
var _derniers := {}
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var matiere := StandardMaterial3D.new()
	matiere.albedo_color = Color(0.93, 0.94, 1.0)
	matiere.roughness = 1.0
	matiere.emission_enabled = true
	matiere.emission = Color(0.8, 0.82, 0.88)
	matiere.emission_energy_multiplier = 0.9
	var maillage := _icosaedre_facettes()
	maillage.surface_set_material(0, matiere)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = maillage
	multimesh.instance_count = nombre_max
	custom_aabb = AABB(Vector3(-20000, -2000, -20000), Vector3(40000, 4000, 40000))
	_age.resize(nombre_max)
	_taille.resize(nombre_max)
	_position.resize(nombre_max)
	_vitesse.resize(nombre_max)
	for i in nombre_max:
		_actif.append(false)
		_orientation.append(Basis.IDENTITY)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_hasard.randomize()


## Sème des nuages entre la dernière position de cette roue et « point ».
func emettre(roue: Variant, point: Vector3) -> void:
	var avant: Variant = _derniers.get(roue)
	if avant == null:
		_derniers[roue] = point
		_semer(point)
		return
	var segment: Vector3 = point - (avant as Vector3)
	var longueur := segment.length()
	if longueur > 8.0:  # téléportation : on repart de zéro
		_derniers[roue] = point
		return
	var n := int(longueur / espacement)
	for k in range(1, n + 1):
		_semer((avant as Vector3) + segment * (float(k) / float(n)) * (float(n) * espacement / longueur))
	if n > 0:
		_derniers[roue] = (avant as Vector3) + segment * (float(n) * espacement / longueur)


func lever(roue: Variant) -> void:
	_derniers.erase(roue)


func _semer(point: Vector3) -> void:
	var i := _suivant
	_suivant = (_suivant + 1) % nombre_max
	_actif[i] = true
	_age[i] = 0.0
	_taille[i] = _hasard.randf_range(taille_min, taille_max)
	_position[i] = point + Vector3(_hasard.randf_range(-0.15, 0.15), 0.0, _hasard.randf_range(-0.15, 0.15))
	_vitesse[i] = Vector3(_hasard.randf_range(-dispersion, dispersion), montee * _hasard.randf_range(0.6, 1.2), _hasard.randf_range(-dispersion, dispersion))
	_orientation[i] = Basis.from_euler(Vector3(_hasard.randf() * TAU, _hasard.randf() * TAU, _hasard.randf() * TAU))


func _physics_process(delta: float) -> void:
	for i in nombre_max:
		if not _actif[i]:
			continue
		_age[i] += delta
		var t := _age[i] / duree_vie
		if t >= 1.0:
			_actif[i] = false
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		_position[i] += _vitesse[i] * delta
		# Grossit vite puis rétrécit jusqu'à rien.
		var echelle := _taille[i] * (lerpf(0.35, 1.0, t / 0.3) if t < 0.3 else lerpf(1.0, 0.0, (t - 0.3) / 0.7))
		multimesh.set_instance_transform(i, Transform3D(_orientation[i].scaled(Vector3.ONE * echelle), _position[i]))


## Un icosaèdre (20 triangles) aux faces plates : le nuage « low poly ».
func _icosaedre_facettes() -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var p: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for tri in f:
		for i in tri:
			st.add_vertex(p[i].normalized() * 0.5)
	st.generate_normals()
	return st.commit()
