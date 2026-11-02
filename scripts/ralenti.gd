extends Node
## Petits ralentis (« slow motion ») sur les gros événements : un choc violent contre un mur,
## un atterrissage brutal. Le jeu ralentit net, tient un instant, puis reprend sa vitesse
## normale en douceur. Plus c'est violent, plus le ralenti est fort.
## Les réglages sont ci-dessous ; décoche « actif » pour tout couper.

@export var vehicule: Vehicule
@export var actif := true
## Pause entre deux ralentis (s), pour ne pas ralentir à chaque frottement.
@export var pause_entre_ralentis := 2.0
## Le son ralentit aussi (0 = pas du tout, 1 = autant que le jeu).
@export_range(0.0, 1.0) var part_son := 0.5

@export_group("Choc contre un mur")
@export var seuil_choc := 30.0  ## force minimale (m/s de vitesse de face) ; 30 = environ 110 km/h de face
@export var echelle_choc := 0.3  ## vitesse du jeu au plus fort du ralenti (1 = normal)
@export var tenue_choc := 0.12  ## s : durée au plus lent
@export var retour_choc := 0.4  ## s : durée pour revenir à la vitesse normale

@export_group("Atterrissage brutal")
@export var seuil_atterrissage := 22.0  ## vitesse de chute minimale (m/s)
@export var echelle_atterrissage := 0.5
@export var tenue_atterrissage := 0.1
@export var retour_atterrissage := 0.3

var _tween: Tween
var _libre_a := 0.0  # heure (temps réel, en s) à partir de laquelle un nouveau ralenti est permis


func _ready() -> void:
	if vehicule == null:
		return
	vehicule.mur_touche.connect(func(force: float) -> void:
		_declencher(force, seuil_choc, echelle_choc, tenue_choc, retour_choc))
	vehicule.atterrissage.connect(func(force: float) -> void:
		_declencher(force, seuil_atterrissage, echelle_atterrissage, tenue_atterrissage, retour_atterrissage))
	vehicule.teleporte.connect(func(_d: Vector3) -> void: _remettre_normal())


func _exit_tree() -> void:
	_remettre_normal()


## « force » doit dépasser « seuil » ; à 2 fois le seuil (ou plus) le ralenti est à fond.
func _declencher(force: float, seuil: float, echelle: float, tenue: float, retour: float) -> void:
	if not actif or force < seuil or get_tree().paused:
		return
	var maintenant := Time.get_ticks_msec() / 1000.0
	if maintenant < _libre_a:
		return
	_libre_a = maintenant + tenue + retour + pause_entre_ralentis
	var intensite := clampf((force - seuil) / seuil, 0.0, 1.0)
	var vitesse_jeu := lerpf(lerpf(1.0, echelle, 0.6), echelle, intensite)
	if _tween != null:
		_tween.kill()
	_regler(vitesse_jeu)
	# Le tween ignore le ralenti du jeu : il dure en temps réel.
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_interval(tenue)
	_tween.tween_method(_regler, vitesse_jeu, 1.0, retour).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _regler(vitesse_jeu: float) -> void:
	Engine.time_scale = vitesse_jeu
	AudioServer.playback_speed_scale = lerpf(1.0, vitesse_jeu, part_son)


func _remettre_normal() -> void:
	if _tween != null:
		_tween.kill()
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
