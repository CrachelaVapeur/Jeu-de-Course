class_name Monstre
extends AnimatableBody3D
## Un monstre géant (façon Godzilla) qui erre lentement dans le cratère.
## Pour l'instant c'est une silhouette en blocs, en attendant un vrai modèle.
## Il est solide : le bolide rebondit dessus. Ses pas font trembler la caméra
## quand on est près.

signal pas_lourd(position_pied: Vector3)

@export var vitesse_marche := 7.0  ## mètres par seconde
@export var vitesse_rotation := 0.35  ## radians par seconde
@export var duree_pas := 1.8  ## secondes pour un pas
@export var echelle := 1.6  ## taille du monstre (1 = environ 60 m de haut)

## Donne un point au hasard où aller (un Vector3 sur le sol du cratère).
var point_au_hasard: Callable
## Donne la hauteur du sol sous une position.
var hauteur_sol: Callable
## Fabrique une matière (couleur, force d'émission) : le circuit donne la
## sienne, pour que le monstre passe en noir et blanc pendant le boost.
var fabrique_matiere: Callable

var _cible := Vector3.ZERO
var _cap := 0.0
var _phase := 0.0
var _jambes: Array[Node3D] = []
var _queue: Array[Node3D] = []
var _tete: Node3D
var _corps: Node3D
var _silhouette: Node3D  # tout ce qui se voit, mis à l'échelle
var _pause := 0.0


func _ready() -> void:
	sync_to_physics = true
	_construire()
	_cible = point_au_hasard.call()
	_cap = rotation.y


func _physics_process(delta: float) -> void:
	var vers := _cible - global_position
	vers.y = 0.0
	if vers.length() < 20.0:
		# Arrivé : il s'arrête un peu, puis repart ailleurs.
		_pause = randf_range(1.0, 4.0)
		_cible = point_au_hasard.call()
	if _pause > 0.0:
		_pause -= delta
		_animer(delta, 0.0)
		return

	# Il se tourne doucement vers sa cible, puis avance.
	var cap_voulu := atan2(-vers.x, -vers.z)
	var ecart := wrapf(cap_voulu - _cap, -PI, PI)
	_cap += clampf(ecart, -vitesse_rotation * delta, vitesse_rotation * delta)
	var avance := 1.0 - clampf(absf(ecart) / 1.2, 0.0, 0.8)
	var avant := Vector3(-sin(_cap), 0.0, -cos(_cap))
	var position_suivante := global_position + avant * vitesse_marche * avance * delta
	position_suivante.y = hauteur_sol.call(position_suivante)
	global_transform = Transform3D(Basis(Vector3.UP, _cap), position_suivante)
	_animer(delta, avance)


func _animer(delta: float, allure: float) -> void:
	var avant_phase := _phase
	_phase += delta / duree_pas * PI * maxf(allure, 0.0)
	# Les jambes se balancent l'une après l'autre.
	for i in _jambes.size():
		_jambes[i].rotation.x = sin(_phase + PI * i) * 0.35 * allure
	_corps.position.y = 34.0 + absf(sin(_phase)) * 1.5 * allure
	_corps.rotation.z = sin(_phase) * 0.04 * allure
	_tete.rotation.y = sin(_phase * 0.37) * 0.3
	for i in _queue.size():
		_queue[i].rotation.y = sin(_phase * 0.5 - i * 0.6) * 0.12
	# Un pas tombe chaque fois que la phase passe un multiple de PI.
	if floorf(_phase / PI) != floorf(avant_phase / PI):
		var cote := 1.0 if int(floorf(_phase / PI)) % 2 == 0 else -1.0
		pas_lourd.emit(global_transform * Vector3(7.0 * cote * echelle, 0.0, 0.0))


# --- La silhouette ------------------------------------------------------------

func _construire() -> void:
	var peau := _matiere(Color(0.26, 0.28, 0.33))
	var ventre := _matiere(Color(0.3, 0.27, 0.25))
	var plaques := _matiere(Color(0.55, 0.3, 1.0), 4.0)
	var yeux := _matiere(Color(1.0, 0.85, 0.2), 8.0)
	_silhouette = Node3D.new()
	_silhouette.scale = Vector3.ONE * echelle
	add_child(_silhouette)

	for cote in [-1.0, 1.0]:
		var hanche := Node3D.new()
		hanche.position = Vector3(7.5 * cote, 24.0, 2.0)
		_silhouette.add_child(hanche)
		_bloc(hanche, Vector3(0, -11, 0), Vector3(9, 24, 11), peau)
		_bloc(hanche, Vector3(0, -23, -3), Vector3(10, 3, 15), peau)  # pied
		_jambes.append(hanche)
		_forme(Vector3(7.5 * cote, 12.0, 2.0), Vector3(9, 24, 11))

	_corps = Node3D.new()
	_corps.position.y = 34.0
	_silhouette.add_child(_corps)
	_bloc(_corps, Vector3(0, 0, 0), Vector3(20, 26, 17), peau, -0.25)
	_bloc(_corps, Vector3(0, -2, -7.5), Vector3(14, 20, 4), ventre, -0.25)
	for cote in [-1.0, 1.0]:
		_bloc(_corps, Vector3(10.5 * cote, 2, -9), Vector3(3.5, 3.5, 11), peau, 0.6)
	_forme(Vector3(0, 34, 0), Vector3(20, 26, 17))

	_tete = Node3D.new()
	_tete.position = Vector3(0, 15, -8)
	_corps.add_child(_tete)
	_bloc(_tete, Vector3(0, 0, -4), Vector3(9, 9, 15), peau)
	_bloc(_tete, Vector3(0, -4.5, -6), Vector3(7.5, 3, 12), ventre)  # mâchoire
	for cote in [-1.0, 1.0]:
		_bloc(_tete, Vector3(3.2 * cote, 2.2, -10), Vector3(1.6, 1.0, 1.0), yeux)

	# La queue : des blocs de plus en plus petits, qui ondulent.
	var parent: Node3D = _corps
	var taille := Vector3(13, 11, 12)
	var depart := Vector3(0, -10, 9)
	for i in 6:
		var anneau := Node3D.new()
		anneau.position = depart
		anneau.rotation.x = 0.12
		parent.add_child(anneau)
		_bloc(anneau, Vector3(0, 0, taille.z * 0.5), taille, peau)
		_bloc(anneau, Vector3(0, taille.y * 0.5 + 1.0, taille.z * 0.5), Vector3(1.2, 3.5, 3.5), plaques, PI * 0.25)
		_queue.append(anneau)
		parent = anneau
		depart = Vector3(0, 0, taille.z * 0.95)
		taille *= 0.8
	_forme(Vector3(0, 20, 22), Vector3(12, 12, 26))

	# Les plaques lumineuses le long du dos.
	for i in 6:
		var y := 13.0 - i * 4.5
		var hauteur := 7.0 - absf(i - 1.5) * 0.9
		_bloc(_corps, Vector3(0, y, 7.0 + i * 0.9), Vector3(1.5, hauteur, hauteur), plaques, PI * 0.25 - 0.25)


func _bloc(parent: Node3D, position_bloc: Vector3, taille: Vector3, matiere: Material, inclinaison := 0.0) -> MeshInstance3D:
	var boite := BoxMesh.new()
	boite.size = taille
	var instance := MeshInstance3D.new()
	instance.mesh = boite
	instance.material_override = matiere
	instance.position = position_bloc
	instance.rotation.x = inclinaison
	parent.add_child(instance)
	return instance


## Une boîte de collision fixe (le monstre bouge en entier, ses jambes non).
func _forme(position_forme: Vector3, taille: Vector3) -> void:
	var forme := CollisionShape3D.new()
	forme.shape = BoxShape3D.new()
	forme.shape.size = taille * echelle
	forme.position = position_forme * echelle
	add_child(forme)


func _matiere(couleur: Color, force_emission := 0.0) -> Material:
	return fabrique_matiere.call(couleur, force_emission)
