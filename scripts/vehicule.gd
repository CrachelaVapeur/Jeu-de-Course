class_name Vehicule
extends Node3D
## Le bolide du joueur : conduite arcade, boost et animations.
##
## Pas de vraie physique ici : on calcule nous-mêmes la vitesse et la
## direction. C'est plus simple à régler et c'est ce que font la plupart des
## jeux de course arcade (on veut des sensations, pas une simulation).

## Émis quand le bolide frotte un mur. « force » sert à doser la secousse.
signal mur_touche(force: float)
## Émis quand on renvoie le bolide au début de la boucle (voir circuit.gd).
signal teleporte(decalage: Vector3)

@export_group("Vitesse (en mètres par seconde, ×3.6 pour des km/h)")
@export var vitesse_max := 75.0
@export var vitesse_boost := 170.0
@export var acceleration := 26.0
@export var acceleration_boost := 110.0
@export var freinage := 60.0
@export var frottement := 8.0

@export_group("Direction")
@export var vitesse_rotation := 1.1  ## en radians par seconde
@export var redressement := 0.4  ## le bolide se remet doucement droit si on lâche
@export var angle_max := 0.6  ## on ne peut pas faire demi-tour (piste droite)
@export var demi_largeur_piste := 13.0

@export_group("Boost")
@export var jauge_max := 100.0
@export var consommation := 30.0  ## par seconde de boost
@export var recharge := 10.0  ## par seconde sans boost
@export var attaque_distorsion := 8.0  ## vitesse à laquelle l'effet de boost s'installe
@export var relachement_distorsion := 2.5  ## vitesse à laquelle il s'efface après le boost

@export_group("Circuit")
## Longueur après laquelle on renvoie le bolide au départ. Doit être la même
## valeur que « longueur_motif » dans circuit.gd.
@export var longueur_boucle := 1200.0

var vitesse := 0.0
var jauge_boost := 100.0
var en_boost := false
var gaz := 0.0
## 0 = conduite normale, 1 = plein effet de boost. La caméra (champ de vision)
## et le son (concentration) s'en servent pour rester synchronisés.
var distorsion := 0.0

var _cap := 0.0  # angle du bolide autour de l'axe vertical
var _temps := 0.0
var _contact_mur := false

@onready var _carrosserie: Node3D = $Carrosserie
@onready var _flammes: Array[Node3D] = [
	$Carrosserie/ReacteurG/Flamme,
	$Carrosserie/ReacteurD/Flamme,
]
@onready var _matiere_flamme: StandardMaterial3D = (
	$Carrosserie/ReacteurG/Flamme/Mesh as MeshInstance3D
).get_active_material(0)


func _ready() -> void:
	jauge_boost = jauge_max


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("recommencer"):
		_recommencer()

	_conduire(delta)
	_mettre_a_jour_distorsion(delta)
	_garder_sur_la_piste()
	_boucler_circuit()
	_animer(delta)


## Combien on va vite par rapport à la vitesse max normale (1.0 = vitesse max,
## plus de 2.0 en plein boost).
func ratio_vitesse() -> float:
	return vitesse / vitesse_max


func vitesse_kmh() -> float:
	return vitesse * 3.6


func _conduire(delta: float) -> void:
	gaz = Input.get_action_strength("accelerer")
	var frein := Input.get_action_strength("freiner")
	var virage := Input.get_axis("droite", "gauche")

	en_boost = Input.is_action_pressed("boost") and jauge_boost > 0.0

	if en_boost:
		jauge_boost = maxf(jauge_boost - consommation * delta, 0.0)
		vitesse = move_toward(vitesse, vitesse_boost, acceleration_boost * delta)
	else:
		jauge_boost = minf(jauge_boost + recharge * delta, jauge_max)
		if vitesse > vitesse_max:
			# Après un boost, on redescend doucement : la vitesse « reste » un peu.
			vitesse = move_toward(vitesse, vitesse_max, frottement * 3.0 * delta)
		elif gaz > 0.0:
			vitesse = move_toward(vitesse, vitesse_max * gaz, acceleration * delta)
		else:
			vitesse = move_toward(vitesse, 0.0, frottement * delta)

	if frein > 0.0:
		vitesse = move_toward(vitesse, 0.0, freinage * frein * delta)

	# On tourne moins vite à très haute vitesse, sinon c'est ingérable.
	var maniabilite := clampf(vitesse / 15.0, 0.0, 1.0) / (1.0 + ratio_vitesse() * 0.6)
	# Plus on va vite, plus l'angle permis est petit : à 600 km/h, quelques
	# degrés suffisent déjà à traverser la piste.
	var angle_permis := angle_max / (1.0 + ratio_vitesse())
	_cap = clampf(_cap + virage * vitesse_rotation * maniabilite * delta, -angle_permis, angle_permis)
	if virage == 0.0:
		_cap = move_toward(_cap, 0.0, redressement * delta)
	rotation.y = _cap

	var direction := Vector3(-sin(_cap), 0.0, -cos(_cap))
	position += direction * vitesse * delta


func _mettre_a_jour_distorsion(delta: float) -> void:
	var rapidite := attaque_distorsion if en_boost else relachement_distorsion
	distorsion = lerpf(distorsion, 1.0 if en_boost else 0.0, 1.0 - exp(-rapidite * delta))


func _garder_sur_la_piste() -> void:
	if absf(position.x) <= demi_largeur_piste:
		_contact_mur = false
		return

	position.x = clampf(position.x, -demi_largeur_piste, demi_largeur_piste)
	if not _contact_mur:
		# La force du choc dépend de l'angle : de face ça fait mal, en frottant moins.
		mur_touche.emit(vitesse * absf(sin(_cap)))
		vitesse *= 0.8
		_cap *= 0.3  # le mur nous redresse
	_contact_mur = true


func _boucler_circuit() -> void:
	# Le décor se répète tous les « longueur_boucle » mètres : on peut donc
	# renvoyer le bolide en arrière sans que le joueur ne voie rien.
	if position.z < -longueur_boucle:
		var decalage := Vector3(0.0, 0.0, longueur_boucle)
		position += decalage
		teleporte.emit(decalage)


func _animer(delta: float) -> void:
	_temps += delta
	var virage := Input.get_axis("droite", "gauche")
	var lissage := 1.0 - exp(-6.0 * delta)

	# Le bolide flotte, penche dans les virages et lève le nez en boost.
	_carrosserie.position.y = 0.7 + sin(_temps * 3.0) * 0.06
	_carrosserie.rotation.z = lerpf(_carrosserie.rotation.z, virage * 0.35, lissage)
	_carrosserie.rotation.x = lerpf(_carrosserie.rotation.x, 0.05 if en_boost else 0.0, lissage)

	var longueur_flamme := 0.3 + gaz * 0.8 + (1.6 if en_boost else 0.0)
	var vibration := 1.0 + sin(_temps * 60.0) * 0.08
	for flamme in _flammes:
		flamme.scale.y = lerpf(flamme.scale.y, longueur_flamme, lissage) * vibration

	var couleur := Color(1.0, 0.2, 0.6) if en_boost else Color(0.3, 0.9, 1.0)
	_matiere_flamme.emission = _matiere_flamme.emission.lerp(couleur, lissage)


func _recommencer() -> void:
	position = Vector3.ZERO
	vitesse = 0.0
	_cap = 0.0
	jauge_boost = jauge_max
	distorsion = 0.0
