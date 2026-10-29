extends AudioStreamPlayer
## Son de moteur fabriqué en direct (aucun fichier audio nécessaire).
##
## On génère deux ondes en dents de scie dont la hauteur monte avec la
## vitesse, plus un souffle qui grossit en boost. Ce sera à remplacer un jour
## par de vrais sons, mais ça suffit pour sentir la vitesse.

@export var vehicule: Vehicule
@export var frequence_ralenti := 50.0
@export var frequence_max := 210.0

@export_group("Concentration en boost")
@export var compensation_volume_db := 6.0  ## remonte le volume pour que l'effet étouffé ne le baisse pas
@export var clarte_etouffee := 0.03  ## plus c'est petit, plus le son est étouffé

const TAUX := 22050.0

var _lecture: AudioStreamGeneratorPlayback
var _phase_a := 0.0
var _phase_b := 0.0
var _frequence := 50.0
var _filtre := 0.0
var _volume_normal := 0.0


func _ready() -> void:
	var generateur := AudioStreamGenerator.new()
	generateur.mix_rate = TAUX
	generateur.buffer_length = 0.1
	stream = generateur
	_volume_normal = volume_db
	play()
	_lecture = get_stream_playback()


func _process(delta: float) -> void:
	if _lecture == null:
		return

	var ratio := absf(vehicule.ratio_vitesse())
	var frequence_voulue := frequence_ralenti + (frequence_max - frequence_ralenti) * minf(ratio, 2.3) / 2.3
	_frequence = lerpf(_frequence, frequence_voulue, 1.0 - exp(-8.0 * delta))
	var souffle := 0.4 if vehicule.en_boost else 0.04 + ratio * 0.06
	var clarte := 0.15 + vehicule.gaz * 0.25

	# En boost, on devient hyper concentré : le son s'étouffe, sans baisser de volume.
	var concentration := vehicule.distorsion
	volume_db = _volume_normal + compensation_volume_db * concentration
	clarte = lerpf(clarte, clarte_etouffee, concentration)

	for i in _lecture.get_frames_available():
		_phase_a = fmod(_phase_a + _frequence / TAUX, 1.0)
		_phase_b = fmod(_phase_b + _frequence * 1.503 / TAUX, 1.0)
		var onde := (_phase_a * 2.0 - 1.0) * 0.5 + (_phase_b * 2.0 - 1.0) * 0.3
		var brut := onde + randf_range(-1.0, 1.0) * souffle
		# Filtre passe-bas tout simple : adoucit le son, plus ouvert à fond.
		_filtre += (brut - _filtre) * clarte
		_lecture.push_frame(Vector2(_filtre, _filtre) * 0.35)
