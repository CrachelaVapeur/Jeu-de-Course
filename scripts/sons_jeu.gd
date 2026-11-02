extends Node
## Les bruitages du jeu (hors moteur, voir son_moteur.gd) : choc et raclement contre un mur,
## crissement de pneus en dérapage, boost (départ et fin), atterrissage, changement de rapport.
##
## Les fichiers sont dans audio/sfx/. POUR CHANGER UN SON : remplace le fichier par un autre du
## même nom (.wav ou .ogg, au choix ; .ogg est plus léger). Si un fichier manque, ce son est
## simplement muet. Les fichiers fournis sont provisoires (outils/generer_sons_provisoires.py).
##
## Noms attendus : choc_mur, raclement_mur (boucle), derapage (boucle), boost_depart,
## boost_fin, atterrissage, changement_rapport.

@export var vehicule: Vehicule
@export var dossier := "res://audio/sfx/"

@export_group("Volumes (dB)")
@export var volume_choc := 0.0
@export var volume_raclement := -6.0
@export var volume_derapage := -4.0
@export var volume_boost_depart := -2.0
@export var volume_boost_fin := -8.0
@export var volume_atterrissage := -2.0
@export var volume_rapport := -14.0
@export var activer_changement_rapport := false  ## le moteur coupe déjà un instant à chaque rapport

const EXTENSIONS := [".ogg", ".wav", ".mp3"]

var _choc: AudioStreamPlayer
var _raclement: AudioStreamPlayer
var _derapage: AudioStreamPlayer
var _boost_depart: AudioStreamPlayer
var _boost_fin: AudioStreamPlayer
var _atterrissage: AudioStreamPlayer
var _rapport: AudioStreamPlayer
var _en_boost_avant := false
var _niveau_derapage := 0.0  # 0 à 1, lissé
var _niveau_raclement := 0.0


func _ready() -> void:
	_choc = _creer("choc_mur", false, volume_choc)
	_raclement = _creer("raclement_mur", true, volume_raclement)
	_derapage = _creer("derapage", true, volume_derapage)
	_boost_depart = _creer("boost_depart", false, volume_boost_depart)
	_boost_fin = _creer("boost_fin", false, volume_boost_fin)
	_atterrissage = _creer("atterrissage", false, volume_atterrissage)
	_rapport = _creer("changement_rapport", false, volume_rapport)
	if vehicule == null:
		return
	vehicule.mur_touche.connect(func(force: float) -> void: _jouer(_choc, volume_choc, force / 30.0))
	vehicule.atterrissage.connect(func(force: float) -> void: _jouer(_atterrissage, volume_atterrissage, force / 25.0))
	vehicule.rapport_change.connect(func(_r: int) -> void:
		if activer_changement_rapport:
			_jouer(_rapport, volume_rapport, 1.0))
	vehicule.teleporte.connect(func(_d: Vector3) -> void: _couper_boucles())


## Charge « dossier/nom » avec la première extension trouvée ; null si le fichier n'existe pas.
func _creer(nom: String, boucle: bool, volume: float) -> AudioStreamPlayer:
	for extension in EXTENSIONS:
		var chemin: String = dossier + nom + extension
		if not ResourceLoader.exists(chemin):
			continue
		var flux := load(chemin) as AudioStream
		if flux == null:
			continue
		if boucle:
			_mettre_en_boucle(flux)
		var lecteur := AudioStreamPlayer.new()
		lecteur.stream = flux
		lecteur.volume_db = volume
		add_child(lecteur)
		return lecteur
	return null


func _mettre_en_boucle(flux: AudioStream) -> void:
	if flux is AudioStreamWAV:
		var wav := flux as AudioStreamWAV
		# (la taille en octets ne suffit pas : Godot peut compresser le son à l'import)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif "loop" in flux:
		flux.set("loop", true)


## Joue un son une fois ; « force » (0 à 1) règle le volume, la hauteur varie un peu.
func _jouer(lecteur: AudioStreamPlayer, volume: float, force: float) -> void:
	if lecteur == null:
		return
	lecteur.volume_db = volume + linear_to_db(clampf(force, 0.15, 1.0))
	lecteur.pitch_scale = randf_range(0.92, 1.08)
	lecteur.play()


func _process(delta: float) -> void:
	if vehicule == null:
		return
	# Boost : un son au départ, un autre à la fin.
	if vehicule.en_boost and not _en_boost_avant:
		_jouer(_boost_depart, volume_boost_depart, 1.0)
	elif _en_boost_avant and not vehicule.en_boost:
		_jouer(_boost_fin, volume_boost_fin, 1.0)
	_en_boost_avant = vehicule.en_boost

	var vitesse := absf(vehicule.vitesse)
	var rapport_vitesse := clampf(vitesse / vehicule.vitesse_max, 0.0, 1.0)

	# Crissement : plus fort quand le bolide est plus de travers, plus aigu avec la vitesse.
	var derape := vehicule.en_derapage and vehicule.is_on_floor() and vitesse > 8.0
	var voulu := clampf(absf(vehicule.glisse_signee()) / vehicule.angle_glisse_max * 1.3, 0.3, 1.0) if derape else 0.0
	_niveau_derapage = lerpf(_niveau_derapage, voulu, 1.0 - exp(-10.0 * delta))
	_regler_boucle(_derapage, _niveau_derapage, volume_derapage, lerpf(0.85, 1.25, rapport_vitesse))

	# Raclement : tant qu'on frotte un mur.
	var racle := vehicule.contact_mur() and vitesse > 12.0
	_niveau_raclement = lerpf(_niveau_raclement, rapport_vitesse * 0.8 + 0.2 if racle else 0.0, 1.0 - exp(-14.0 * delta))
	_regler_boucle(_raclement, _niveau_raclement, volume_raclement, lerpf(0.8, 1.2, rapport_vitesse))


func _regler_boucle(lecteur: AudioStreamPlayer, niveau: float, volume: float, hauteur: float) -> void:
	if lecteur == null:
		return
	if niveau < 0.02:
		if lecteur.playing:
			lecteur.stop()
		return
	lecteur.volume_db = volume + linear_to_db(niveau)
	lecteur.pitch_scale = hauteur
	if not lecteur.playing:
		lecteur.play()


func _couper_boucles() -> void:
	_niveau_derapage = 0.0
	_niveau_raclement = 0.0
