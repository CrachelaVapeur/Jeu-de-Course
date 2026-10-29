extends Camera3D
## Caméra qui suit le bolide et fabrique une bonne partie de la sensation de
## vitesse : champ de vision qui s'élargit, recul quand on accélère fort,
## tremblements en boost et lors des chocs.
## Touche C (bouton Y de la manette) : passe à la vue suivante.
## Croix directionnelle (ou touches 1 à 4) : choisit une vue directement
## (haut : poursuite lointaine, droite : poursuite proche, gauche : cockpit,
## bas : capot). La vue choisie est gardée pour les courses suivantes.

@export var cible: Vehicule

@export var distance := 6.5
@export var hauteur := 2.2
@export var distance_loin := 10.5  ## vue « poursuite lointaine » : plus loin...
@export var hauteur_loin := 3.6  ## ...et plus haut, pour mieux lire les virages et les glisses
## En côte ou en descente, part de la pente que la caméra suit (elle se place
## derrière et au-dessus du bolide par rapport à la route, pas à l'horizontale).
## 0 = toujours à l'horizontale (ancienne caméra), 1 = toute la pente.
@export var suivi_pente := 0.85
@export var retard_pente := 4.0  ## plus c'est petit, plus la caméra met de temps à suivre la pente
@export var garde_sol := 0.9  ## hauteur minimale de la caméra au-dessus de la route ou du terrain
@export var fov_min := 68.0
@export var fov_max := 112.0  ## atteint à pleine vitesse
@export var fov_distorsion := 160.0  ## champ de vision pendant le boost : l'espace semble se déformer
@export var recul_max := 3.0  ## la caméra « décroche » quand le boost démarre
@export var secousse_pleine_vitesse := 0.08  ## tremblement en plein boost (monte progressivement avec la vitesse)
## Poursuite : derrière le bolide. Cockpit : depuis le siège du pilote.
## Capot : sur le nez du bolide.
## Poursuite lointaine : plus loin et plus haut.
@export_enum("Poursuite", "Cockpit", "Capot", "Poursuite lointaine") var vue := 0
## Sur une paroi de half-pipe, part de la pente que la caméra suit (elle
## penche avec le bolide). 0 = toujours droite, 1 = collée à la paroi.
@export var penche_paroi := 0.6

var _cap_camera := 0.0
var _vitesse_precedente := 0.0
var _recul := 0.0
var _secousse := 0.0
var _haut := Vector3.UP  # le « haut » de la caméra, lissé
var _pente := 0.0  # angle de la route (en radians, > 0 en montée), lissé
var _place_libre := 1.0  # part de la distance voulue sans obstacle entre le bolide et la caméra
var _reglages: Node  # l'autoload des réglages (la vue choisie y est gardée)

## Ordre des vues avec C / Y : poursuite, poursuite lointaine, cockpit, capot.
const ORDRE_VUES: Array[int] = [0, 3, 1, 2]
## Action de commande -> vue choisie directement (croix directionnelle ou touches 1 à 4).
const VUES_DIRECTES := {"vue_loin": 3, "vue_pres": 0, "vue_cockpit": 1, "vue_capot": 2}


func _ready() -> void:
	cible.teleporte.connect(func(decalage: Vector3) -> void: global_position += decalage)
	cible.mur_touche.connect(_sur_choc)
	cible.atterrissage.connect(func(force: float) -> void: _sur_choc(force * 0.6))
	_cap_camera = cible.rotation.y
	_reglages = get_node_or_null("/root/Graphismes")
	if _reglages != null:
		vue = _reglages.vue_camera


func _changer_vue(nouvelle: int) -> void:
	vue = nouvelle
	if _reglages != null:
		_reglages.vue_camera = vue
		_reglages.sauvegarder()


func _physics_process(delta: float) -> void:
	# 1. La caméra suit l'angle du bolide avec un peu de retard (plus doux).
	_cap_camera = lerp_angle(_cap_camera, cible.cap_camera(), 1.0 - exp(-5.0 * delta))
	var arriere := Vector3(sin(_cap_camera), 0.0, cos(_cap_camera))

	# 2. Quand on accélère fort, la caméra recule un peu puis rattrape.
	var acceleration := (cible.vitesse - _vitesse_precedente) / delta
	_vitesse_precedente = cible.vitesse
	_recul = lerpf(_recul, clampf(acceleration * 0.04, -1.0, recul_max), 1.0 - exp(-3.0 * delta))

	if Input.is_action_just_pressed("camera"):
		_changer_vue(ORDRE_VUES[(ORDRE_VUES.find(vue) + 1) % ORDRE_VUES.size()])
	for action: String in VUES_DIRECTES:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			_changer_vue(VUES_DIRECTES[action])
	if vue == 1 or vue == 2:
		global_transform = cible.repere_cockpit(vue == 2)
	else:
		_placer_en_poursuite(arriere, delta)

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


## Vue de poursuite (proche ou lointaine). « arriere » : direction horizontale vers l'arrière du bolide.
func _placer_en_poursuite(arriere: Vector3, delta: float) -> void:
	var loin := vue == 3
	var recul := (distance_loin if loin else distance) + _recul
	var haut_camera := hauteur_loin if loin else hauteur

	# Sur une paroi, la caméra se place au-dessus du bolide par rapport à
	# la paroi (pas dans le vide) et penche avec lui.
	var haut_voulu := Vector3.UP.lerp(cible.normale_sol(), penche_paroi).normalized()
	# lerp + normalized plutôt que slerp : slerp plante (erreur d'axe) quand les deux vecteurs sont presque égaux.
	_haut = _haut.lerp(haut_voulu, 1.0 - exp(-4.0 * delta)).normalized()

	# Au sol : la pente de la route sous le bolide. En l'air : la direction de
	# son vol (en plongeant d'une crête, la caméra monte derrière et regarde la descente).
	var avant := -arriere
	var pente_voulue := 0.0
	if cible.piste_droite or cible.is_on_floor():
		var n := cible.normale_sol()
		var le_long := (avant - n * avant.dot(n)).normalized()
		pente_voulue = asin(clampf(le_long.y, -1.0, 1.0))
	else:
		var horizontale := Vector2(cible.velocity.x, cible.velocity.z).length()
		pente_voulue = clampf(atan2(cible.velocity.y, maxf(horizontale, 1.0)), -0.6, 0.4)
	pente_voulue *= suivi_pente
	_pente = lerpf(_pente, pente_voulue, 1.0 - exp(-retard_pente * delta))
	# Avant et arrière « couchés » sur la pente : la caméra reste derrière et
	# au-dessus du bolide par rapport à la route, et regarde la route devant.
	var avant_pente := avant * cos(_pente) + Vector3.UP * sin(_pente)

	var voulue := cible.global_position - avant_pente * recul + _haut * haut_camera
	voulue = _eviter_le_decor(voulue, delta)
	global_position = voulue
	look_at(cible.global_position + avant_pente * 12.0 + _haut * 1.0, _haut)


## Garde la caméra hors du décor : au-dessus de la route et du terrain, et
## devant tout mur ou plafond (tunnel) qui la séparerait du bolide.
func _eviter_le_decor(voulue: Vector3, delta: float) -> Vector3:
	var espace := get_world_3d().direct_space_state
	var exclus: Array[RID] = [cible.get_rid()]

	# 1. Pas sous la route : on regarde le sol juste sous la caméra.
	var depuis := Vector3(voulue.x, maxf(voulue.y, cible.global_position.y) + 2.0, voulue.z)
	var rayon := PhysicsRayQueryParameters3D.create(depuis, voulue + Vector3.DOWN * 4.0)
	rayon.exclude = exclus
	var sol := espace.intersect_ray(rayon)
	if not sol.is_empty():
		voulue.y = maxf(voulue.y, (sol["position"] as Vector3).y + garde_sol)

	# 2. Rien entre le bolide et la caméra (plafond du tunnel, mur) : on se
	# rapproche tout de suite, et on repart en arrière doucement ensuite.
	var oeil := cible.global_position + _haut * 1.2
	rayon = PhysicsRayQueryParameters3D.create(oeil, voulue)
	rayon.exclude = exclus
	var obstacle := espace.intersect_ray(rayon)
	var libre := 1.0
	if not obstacle.is_empty():
		var longueur := maxf(oeil.distance_to(voulue), 0.01)
		libre = clampf((oeil.distance_to(obstacle["position"]) - 0.4) / longueur, 0.15, 1.0)
	_place_libre = libre if libre < _place_libre else lerpf(_place_libre, libre, 1.0 - exp(-3.0 * delta))
	return oeil.lerp(voulue, _place_libre)


func _sur_choc(force: float) -> void:
	_secousse = maxf(_secousse, clampf(force / 40.0, 0.15, 0.8))


## Fait trembler la caméra (pas du monstre, explosions…). force : 0 à 40 environ.
func secouer(force: float) -> void:
	_sur_choc(force)
