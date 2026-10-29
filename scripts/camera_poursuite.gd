extends Camera3D
## Caméra qui suit le bolide et fabrique une bonne partie de la sensation de
## vitesse : champ de vision qui s'élargit, recul quand on accélère fort,
## tremblements en boost et lors des chocs.
## Touche C (bouton Y de la manette) : passe en vue cockpit et revient.

@export var cible: Vehicule

@export var distance := 6.5
@export var hauteur := 2.2
@export var fov_min := 68.0
@export var fov_max := 112.0  ## atteint à pleine vitesse
@export var fov_distorsion := 160.0  ## champ de vision pendant le boost : l'espace semble se déformer
@export var recul_max := 3.0  ## la caméra « décroche » quand le boost démarre
@export var secousse_pleine_vitesse := 0.08  ## tremblement en plein boost (monte progressivement avec la vitesse)
@export var vue_cockpit := false  ## vrai : on voit la route depuis le siège du pilote

var _cap_camera := 0.0
var _vitesse_precedente := 0.0
var _recul := 0.0
var _secousse := 0.0


func _ready() -> void:
	cible.teleporte.connect(func(decalage: Vector3) -> void: global_position += decalage)
	cible.mur_touche.connect(_sur_choc)
	cible.atterrissage.connect(func(force: float) -> void: _sur_choc(force * 0.6))
	_cap_camera = cible.rotation.y


func _physics_process(delta: float) -> void:
	# 1. La caméra suit l'angle du bolide avec un peu de retard (plus doux).
	_cap_camera = lerp_angle(_cap_camera, cible.cap_camera(), 1.0 - exp(-5.0 * delta))
	var arriere := Vector3(sin(_cap_camera), 0.0, cos(_cap_camera))

	# 2. Quand on accélère fort, la caméra recule un peu puis rattrape.
	var acceleration := (cible.vitesse - _vitesse_precedente) / delta
	_vitesse_precedente = cible.vitesse
	_recul = lerpf(_recul, clampf(acceleration * 0.04, -1.0, recul_max), 1.0 - exp(-3.0 * delta))

	if Input.is_action_just_pressed("camera"):
		vue_cockpit = not vue_cockpit
	if vue_cockpit:
		global_transform = cible.repere_cockpit()
	else:
		global_position = cible.global_position + arriere * (distance + _recul) + Vector3.UP * hauteur
		look_at(cible.global_position - arriere * 12.0 + Vector3.UP * 1.0)

	# 3. Le champ de vision s'élargit avec la vitesse : c'est l'effet le plus fort.
	var ratio := clampf(cible.vitesse / cible.vitesse_boost, 0.0, 1.0)
	var fov_voulu := lerpf(fov_min, fov_max, pow(ratio, 1.4))
	# Pendant le boost, le champ de vision s'ouvre encore plus : le temps et l'espace se déforment.
	fov_voulu = lerpf(fov_voulu, fov_distorsion, cible.distorsion)
	fov = lerpf(fov, fov_voulu, 1.0 - exp(-4.0 * delta))

	# 4. Tremblements : permanents en boost, plus forts lors des chocs.
	var secousse_vitesse := pow(ratio, 4.0) * secousse_pleine_vitesse
	var amplitude := _secousse + (0.06 if cible.en_boost else 0.0) + ratio * 0.015 + secousse_vitesse
	h_offset = randf_range(-amplitude, amplitude)
	v_offset = randf_range(-amplitude, amplitude)
	# À pleine vitesse, l'image penche aussi un peu de gauche à droite.
	rotate_object_local(Vector3.BACK, randf_range(-1.0, 1.0) * secousse_vitesse * 0.15)
	_secousse = move_toward(_secousse, 0.0, delta * 1.5)


func _sur_choc(force: float) -> void:
	_secousse = maxf(_secousse, clampf(force / 40.0, 0.15, 0.8))


## Fait trembler la caméra (pas du monstre, explosions…). force : 0 à 40 environ.
func secouer(force: float) -> void:
	_sur_choc(force)
