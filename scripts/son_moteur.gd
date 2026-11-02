extends AudioStreamPlayer
## Son de moteur fabriqué en direct (aucun fichier audio nécessaire).
##
## Trois oscillateurs lus dans une table d'onde riche en harmoniques (le cœur du moteur, un
## second légèrement désaccordé pour la « rugosité », un grave en dessous), passés dans un
## filtre qui s'ouvre avec les gaz et le régime. Ajoutés : pulsation des cylindres au ralenti,
## coupure à chaque changement de rapport, son plus sourd quand on lâche les gaz, souffle du
## vent selon la vitesse, souffle de boost. Ce sera à remplacer un jour par de vrais sons.

@export var vehicule: Vehicule
@export var frequence_ralenti := 48.0
@export var frequence_max := 230.0
## Coché : la hauteur du son suit le régime de la boîte de vitesses (il monte dans chaque rapport
## puis retombe au passage). Décoché : il suit la vitesse, comme avant.
@export var suivre_la_boite := true

@export_group("Timbre")
@export var harmoniques := 9  ## plus il y en a, plus le son est riche et agressif
@export var chute_harmoniques := 0.85  ## plus c'est grand, plus les aigus s'éteignent vite (son rond)
@export var desaccord := 0.011  ## écart du second oscillateur (rugosité)
@export var part_grave := 0.5  ## volume de l'oscillateur grave
@export var pulsation_ralenti := 0.28  ## ballottement des cylindres à bas régime (0 = aucun)
@export_group("Gaz et rapports")
@export var volume_sans_gaz := 0.55  ## part du volume quand on lâche les gaz
@export var coupure_rapport := 0.75  ## part du son coupée un instant à chaque changement de rapport
@export var duree_coupure := 0.12  ## s
@export_group("Vent")
@export var volume_vent := 0.22
@export_group("Concentration en boost")
@export var compensation_volume_db := 6.0  ## remonte le volume pour que l'effet étouffé ne le baisse pas
@export var clarte_etouffee := 0.03  ## plus c'est petit, plus le son est étouffé

const TAUX := 22050.0
const TAILLE_TABLE := 512

var _lecture: AudioStreamGeneratorPlayback
var _table := PackedFloat32Array()
var _phase_a := 0.0
var _phase_b := 0.0
var _phase_grave := 0.0
var _phase_pulse := 0.0
var _frequence := 48.0
var _filtre := 0.0
var _filtre_vent := 0.0
var _gaz_lisses := 0.0
var _coupure := 0.0  # 1 juste après un changement de rapport, retombe à 0
var _volume_normal := 0.0
var pic := 0.0  # plus grand échantillon envoyé (sert aux tests : doit rester sous 1)


func _ready() -> void:
	_fabriquer_table()
	var generateur := AudioStreamGenerator.new()
	generateur.mix_rate = TAUX
	generateur.buffer_length = 0.1
	stream = generateur
	bus = Graphismes.BUS_SFX  # le curseur « SFX volume » des réglages règle aussi le moteur
	_volume_normal = volume_db
	play()
	_lecture = get_stream_playback()
	if vehicule != null:
		vehicule.rapport_change.connect(func(_r: int) -> void: _coupure = 1.0)


## Un cycle d'onde : la fondamentale plus ses harmoniques (de plus en plus faibles), avec un petit
## décalage de phase pour que ça ne sonne pas comme un orgue.
func _fabriquer_table() -> void:
	_table.resize(TAILLE_TABLE)
	var maxi := 0.0
	for i in TAILLE_TABLE:
		var x := float(i) / TAILLE_TABLE
		var somme := 0.0
		for k in range(1, harmoniques + 1):
			somme += sin(TAU * k * x + float(k * k) * 0.35) / pow(float(k), chute_harmoniques * 1.6)
		_table[i] = somme
		maxi = maxf(maxi, absf(somme))
	for i in TAILLE_TABLE:
		_table[i] /= maxi


func _lire(phase: float) -> float:
	var p := phase * TAILLE_TABLE
	var i := int(p)
	var f := p - float(i)
	return lerpf(_table[i % TAILLE_TABLE], _table[(i + 1) % TAILLE_TABLE], f)


func _process(delta: float) -> void:
	if _lecture == null:
		return

	var ratio := absf(vehicule.ratio_vitesse())
	var frequence_voulue := frequence_ralenti + (frequence_max - frequence_ralenti) * minf(ratio, 2.3) / 2.3
	var regime := clampf(ratio / 2.3, 0.0, 1.0)
	if suivre_la_boite:
		regime = clampf(vehicule.regime, 0.0, 1.0)
		frequence_voulue = frequence_ralenti + (frequence_max - frequence_ralenti) * regime
	_frequence = lerpf(_frequence, frequence_voulue, 1.0 - exp(-8.0 * delta))
	_gaz_lisses = lerpf(_gaz_lisses, vehicule.gaz, 1.0 - exp(-9.0 * delta))
	_coupure = maxf(_coupure - delta / duree_coupure, 0.0)

	# Volume : plein gaz = fort, gaz lâchés = plus sourd ; chaque changement de rapport coupe un instant.
	var charge := lerpf(volume_sans_gaz, 1.0, _gaz_lisses)
	var niveau := charge * (1.0 - coupure_rapport * _coupure)
	# Brillance : le filtre s'ouvre avec les gaz et le régime, et se ferme à la coupure.
	var clarte := lerpf(0.06, 0.38, _gaz_lisses * 0.7 + regime * 0.3) * (1.0 - 0.6 * _coupure)
	var souffle_boost := 0.35 if vehicule.en_boost else 0.0
	var vent := volume_vent * pow(minf(ratio, 1.6) / 1.6, 1.5)

	# En boost, on devient hyper concentré : le son s'étouffe, sans baisser de volume.
	var concentration := vehicule.distorsion
	volume_db = _volume_normal + compensation_volume_db * concentration
	clarte = lerpf(clarte, clarte_etouffee, concentration)

	var pulsation := pulsation_ralenti * (1.0 - regime) * (1.0 - regime)
	for i in _lecture.get_frames_available():
		_phase_a = fmod(_phase_a + _frequence / TAUX, 1.0)
		_phase_b = fmod(_phase_b + _frequence * (1.0 + desaccord) / TAUX, 1.0)
		_phase_grave = fmod(_phase_grave + _frequence * 0.5 / TAUX, 1.0)
		_phase_pulse = fmod(_phase_pulse + _frequence * 0.25 / TAUX, 1.0)
		var onde := _lire(_phase_a) * 0.5 + _lire(_phase_b) * 0.35 + sin(TAU * _phase_grave) * part_grave * 0.4
		# Les cylindres « ballottent » au ralenti : le volume ondule au rythme des allumages.
		onde *= 1.0 - pulsation * (0.5 + 0.5 * sin(TAU * _phase_pulse))
		var bruit := randf_range(-1.0, 1.0)
		var brut := onde * niveau + bruit * souffle_boost
		_filtre += (brut - _filtre) * clarte
		_filtre_vent += (bruit - _filtre_vent) * 0.12
		var sortie := (_filtre + _filtre_vent * vent) * 0.38
		pic = maxf(pic, absf(sortie))
		_lecture.push_frame(Vector2(sortie, sortie))
