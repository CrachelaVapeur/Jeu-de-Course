extends Node3D
## Fait osciller doucement ce nœud autour de sa position de départ, comme un
## projecteur qui balaie le ciel (faisceaux de la pyramide). Il ne fait pas
## de tour complet : il va et vient de quelques degrés.

@export var amplitude_degres := 7.0  ## de combien le faisceau s'écarte, au plus
@export var periode := 16.0  ## durée d'un aller-retour, en secondes
@export var decalage := 0.0  ## pour que les projecteurs ne bougent pas ensemble (0 à 1)

var _base := Basis.IDENTITY
var _temps := 0.0


func _ready() -> void:
	_base = basis


func _process(delta: float) -> void:
	_temps += delta
	var phase := TAU * (_temps / periode + decalage)
	var amplitude := deg_to_rad(amplitude_degres)
	# Deux mouvements de vitesses différentes : le faisceau dessine une
	# boucle lente et irrégulière plutôt qu'un simple va-et-vient.
	var gauche_droite := amplitude * sin(phase)
	var haut_bas := amplitude * 0.5 * sin(phase * 0.63 + 1.7)
	basis = _base * Basis.from_euler(Vector3(haut_bas, 0.0, gauche_droite))
