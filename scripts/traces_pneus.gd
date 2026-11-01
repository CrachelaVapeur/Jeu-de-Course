extends MultiMeshInstance3D
## Les traces de pneus noires laissées sur la route pendant un dérapage.
## Un nombre fixe de petits rectangles posés bout à bout : quand il n'y en a
## plus, les plus anciens sont réutilisés (les vieilles traces disparaissent).

@export var nombre_max := 900  ## total pour toutes les roues
@export var largeur := 0.4  ## largeur d'une trace (m)
@export var decollement := 0.045  ## au-dessus de la route, pour ne pas clignoter avec elle (m)
@export var pas_min := 0.5  ## distance minimale entre deux morceaux de trace (m)

var _suivant := 0
var _derniers := {}  # roue (clé) -> dernière position posée


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var morceau := BoxMesh.new()
	morceau.size = Vector3(largeur, 0.01, 1.0)
	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matiere.albedo_color = Color(0.03, 0.03, 0.035)
	morceau.material = matiere
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = morceau
	multimesh.instance_count = nombre_max
	for i in nombre_max:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	# Tout l'espace : les morceaux sont partout sur le circuit.
	custom_aabb = AABB(Vector3(-20000, -2000, -20000), Vector3(40000, 4000, 40000))


## Pose un morceau de trace sous la roue « roue » (une clé quelconque), au point
## « contact », sur un sol de normale « normale ».
func tracer(roue: Variant, contact: Vector3, normale: Vector3) -> void:
	var avant_point: Variant = _derniers.get(roue)
	_derniers[roue] = contact
	if avant_point == null:
		return
	var segment: Vector3 = contact - avant_point
	var longueur := segment.length()
	if longueur < 0.01 or longueur > 6.0:
		return  # trop court, ou on a sauté / téléporté : pas de trait
	var z := segment / longueur
	var x := normale.cross(z).normalized()
	var y := z.cross(x)
	var basis := Basis(x, y, z * (longueur + 0.08))
	var milieu: Vector3 = (contact + avant_point) * 0.5 + normale * decollement
	multimesh.set_instance_transform(_suivant, Transform3D(basis, milieu))
	_suivant = (_suivant + 1) % nombre_max


## À appeler quand la roue ne laisse plus de trace (le prochain morceau repart de zéro).
func lever(roue: Variant) -> void:
	_derniers.erase(roue)
