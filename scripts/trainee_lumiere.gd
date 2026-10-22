extends MeshInstance3D
## Traînée de lumière derrière une flamme de réacteur, visible pendant le boost.
##
## À chaque tick de physique, on note la position de la sortie du réacteur.
## Ces points restent en place dans le monde pendant que le bolide avance : ils
## forment une traînée qui s'amincit et s'éteint avec le temps. On la dessine
## comme un ruban (deux bandes en croix, pour qu'elle se voie sous tous les angles).

@export var vehicule: Vehicule
@export var duree := 0.45  ## durée de vie de la traînée, en secondes
@export var largeur := 0.22  ## demi-largeur du ruban à la source
@export var couleur := Color(1.0, 0.3, 0.7)
@export var eclat := 3.0  ## au-dessus de 1, la traînée « brille » (avec le halo de l'environnement)
@export var pointe := Vector3.ZERO  ## d'où sort la traînée, dans le repère de la flamme : (0, 0, 0) = la sortie du réacteur, (0, 1, 0) = le bout de la flamme

const SHADER := preload("res://shaders/trainee.gdshader")

var _points: Array[Vector3] = []
var _ages: Array[float] = []
var _forces: Array[float] = []
var _maillage := ImmediateMesh.new()
var _source: Node3D


func _ready() -> void:
	_source = get_parent() as Node3D
	# Les points sont notés dans le monde : la traînée ne doit pas suivre le bolide.
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _maillage
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var matiere := ShaderMaterial.new()
	matiere.shader = SHADER
	matiere.set_shader_parameter("eclat", eclat)
	material_override = matiere

	vehicule.teleporte.connect(_sur_teleportation)


func _physics_process(delta: float) -> void:
	for i in _ages.size():
		_ages[i] += delta
	# Les points les plus anciens sont au début de la liste : on retire ceux qui ont fini de s'éteindre.
	while not _ages.is_empty() and _ages[0] > duree:
		_points.pop_front()
		_ages.pop_front()
		_forces.pop_front()

	# On ne laisse de lumière que pendant le boost (la traînée s'éteint toute seule ensuite).
	if vehicule.distorsion > 0.02:
		_points.append(_source.to_global(pointe))
		_ages.append(0.0)
		_forces.append(vehicule.distorsion)

	_dessiner()


func _dessiner() -> void:
	_maillage.clear_surfaces()
	if _points.size() < 2:
		return
	_ruban(Vector3.RIGHT)
	_ruban(Vector3.UP)


func _ruban(axe: Vector3) -> void:
	_maillage.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	# Du point le plus récent (épais, lumineux) au plus ancien (fin, éteint).
	for i in range(_points.size() - 1, -1, -1):
		var vie := clampf(1.0 - _ages[i] / duree, 0.0, 1.0)
		var intensite := vie * _forces[i]
		var demi_largeur := largeur * intensite
		var c := Color(couleur.r, couleur.g, couleur.b, intensite * intensite)
		_maillage.surface_set_color(c)
		_maillage.surface_add_vertex(_points[i] + axe * demi_largeur)
		_maillage.surface_set_color(c)
		_maillage.surface_add_vertex(_points[i] - axe * demi_largeur)
	_maillage.surface_end()


## Quand le bolide est renvoyé au début de la boucle (voir circuit.gd), on
## décale la traînée avec lui pour qu'elle ne soit pas coupée.
func _sur_teleportation(decalage: Vector3) -> void:
	for i in _points.size():
		_points[i] += decalage
