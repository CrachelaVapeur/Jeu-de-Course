extends CanvasLayer
## Affichage à l'écran : compteur, jauge de boost et lignes de vitesse.

@export var vehicule: Vehicule

@onready var _compteur: Label = $Compteur
@onready var _jauge: ProgressBar = $Jauge
@onready var _lignes: ColorRect = $LignesVitesse
@onready var _tunnel: ColorRect = $Tunnel
@onready var _g: Node = get_node("/root/Graphismes")  # l'autoload des réglages


func _ready() -> void:
	# Le guide en icônes (coin en haut à gauche) remplace l'ancienne aide en texte.
	add_child(preload("res://scripts/guide_commandes.gd").new())
	($Aide as Label).visible = false
	# La carte (Select / M) puis le menu de pause (Start / Échap), par-dessus tout le reste.
	var carte: Control = preload("res://scripts/carte.gd").new()
	carte.vehicule = vehicule
	carte.circuit = get_parent().get_node_or_null("Circuit")
	add_child(carte)
	var pause: Control = preload("res://scripts/menu_pause.gd").new()
	pause.vehicule = vehicule
	add_child(pause)


func _process(delta: float) -> void:
	_compteur.text = "%d km/h" % absi(roundi(vehicule.vitesse_kmh()))
	_jauge.visible = not vehicule.boost_infini
	_jauge.max_value = vehicule.jauge_max
	_jauge.value = vehicule.jauge_boost
	_jauge.modulate = Color(1.0, 0.3, 0.7) if vehicule.en_boost else Color.WHITE

	# Les lignes apparaissent au-delà de 60 % de la vitesse max, à fond en boost.
	var debut := vehicule.vitesse_max * 0.6
	var intensite := clampf((vehicule.vitesse - debut) / (vehicule.vitesse_boost - debut), 0.0, 1.0)
	var matiere := _lignes.material as ShaderMaterial
	var actuelle: float = matiere.get_shader_parameter("intensite")
	matiere.set_shader_parameter("intensite", lerpf(actuelle, intensite, 1.0 - exp(-6.0 * delta)))

	# Vision en tunnel pendant le boost : le calque n'est affiché que quand l'effet est actif.
	# Les deux effets plein écran se coupent dans les réglages graphiques.
	_lignes.visible = _g.effets
	_tunnel.visible = _g.effets and vehicule.distorsion > 0.005
	(_tunnel.material as ShaderMaterial).set_shader_parameter("intensite", vehicule.distorsion)
