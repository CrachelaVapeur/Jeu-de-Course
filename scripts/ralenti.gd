extends Node
## L'anticipation du boost : à l'appui, le temps ralentit presque à l'arrêt, la caméra se rapproche
## (et le champ de vision se resserre), le temps de « charger »... puis le temps reprend et
## l'animation normale du boost se déclenche (la caméra décroche, le champ de vision s'ouvre).
## La caméra lit « vehicule.anticipation_boost » (0 = rien, 1 = au plus près) ; voir camera_poursuite.gd.
## Tout se mesure en temps réel (le ralenti ne rallonge pas l'anticipation).

@export var vehicule: Vehicule
@export var actif := true
@export var echelle := 0.15  ## vitesse du jeu pendant l'anticipation (1 = normal, 0.15 = très lent)
@export var entree := 0.08  ## s : temps pour ralentir
@export var tenue := 0.35  ## s : durée au plus lent (la caméra reste près)
@export var sortie := 0.15  ## s : temps pour reprendre la vitesse normale
## Le son ralentit aussi (0 = pas du tout, 1 = autant que le jeu).
@export_range(0.0, 1.0) var part_son := 0.6

var _tween: Tween
var _boost_avant := false


func _ready() -> void:
	if vehicule != null:
		vehicule.teleporte.connect(func(_d: Vector3) -> void: _remettre_normal())


func _exit_tree() -> void:
	_remettre_normal()


func _process(_delta: float) -> void:
	if vehicule == null:
		return
	if vehicule.en_boost and not _boost_avant and actif and not get_tree().paused:
		_lancer()
	_boost_avant = vehicule.en_boost


func _lancer() -> void:
	if _tween != null:
		_tween.kill()
	var total := entree + tenue + sortie
	# Le tween ignore le ralenti du jeu : il dure en temps réel.
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_method(_animer, 0.0, total, total)
	_tween.tween_callback(_remettre_normal)


## t = temps réel écoulé depuis l'appui.
func _animer(t: float) -> void:
	var k := 0.0  # 0 = normal, 1 = anticipation à fond
	if t < entree:
		k = ease(t / entree, 0.4)
	elif t < entree + tenue:
		k = 1.0
	else:
		k = 1.0 - smoothstep(0.0, 1.0, (t - entree - tenue) / sortie)
	vehicule.anticipation_boost = k
	Engine.time_scale = lerpf(1.0, echelle, k)
	AudioServer.playback_speed_scale = lerpf(1.0, Engine.time_scale, part_son)


func _remettre_normal() -> void:
	if _tween != null:
		_tween.kill()
	if vehicule != null:
		vehicule.anticipation_boost = 0.0
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
