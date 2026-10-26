extends Node3D
## Fait tourner ce nœud sur lui-même (faisceau du phare, enseignes…).

@export var tours_par_minute := 6.0


func _process(delta: float) -> void:
	rotate_y(TAU * tours_par_minute / 60.0 * delta)
