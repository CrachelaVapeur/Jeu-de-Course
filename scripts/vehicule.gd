class_name Vehicule
extends CharacterBody3D
## Le bolide du joueur : conduite arcade, boost et animations.
##
## Pas de vraie physique de voiture ici : on calcule nous-mêmes la vitesse et
## la direction. C'est plus simple à régler et c'est ce que font la plupart des
## jeux de course arcade (on veut des sensations, pas une simulation).
##
## Deux modes :
## - « piste_droite » (scène d'essai main.tscn) : sol plat, murs invisibles,
##   ligne droite sans fin ;
## - sinon (vrais circuits) : le moteur physique de Godot gère le relief. Le
##   bolide suit les pentes, décolle des tremplins, retombe avec la gravité,
##   rebondit sur les blocs et réapparaît s'il tombe dans un trou.

## Émis quand le bolide frotte un mur. « force » sert à doser la secousse.
signal mur_touche(force: float)
## Émis quand on renvoie le bolide au début de la boucle (voir circuit.gd),
## ou quand il réapparaît après une chute.
signal teleporte(decalage: Vector3)
## Émis quand le bolide retombe au sol après un saut. « force » = vitesse de chute.
signal atterrissage(force: float)

@export_group("Vitesse (en mètres par seconde, ×3.6 pour des km/h)")
@export var vitesse_max := 75.0
@export var vitesse_boost := 139.0  ## 500 km/h : la vitesse la plus haute du jeu
@export var acceleration := 26.0
@export var acceleration_boost := 60.0  ## atteinte au bout de la montée du boost
@export var freinage := 60.0
@export var frottement := 8.0

@export_group("Direction")
@export var vitesse_rotation := 1.1  ## en radians par seconde
@export var redressement := 0.4  ## le bolide se remet doucement droit si on lâche
@export var angle_max := 0.6  ## on ne peut pas faire demi-tour (piste droite)
@export var demi_largeur_piste := 13.0

@export_group("Boost")
@export var jauge_max := 100.0
@export var consommation := 22.0  ## par seconde de boost
@export var recharge := 10.0  ## par seconde sans boost
@export var attaque_distorsion := 8.0  ## vitesse à laquelle l'effet de boost s'installe
@export var relachement_distorsion := 2.5  ## vitesse à laquelle il s'efface après le boost
## Secondes pour que le boost donne toute sa poussée : il démarre doucement,
## puis pousse de plus en plus fort (une courbe qui se creuse, pas un coup sec).
@export var duree_montee_boost := 2.5

@export_group("Apparence")
## Matière (toon) appliquée au modèle 3D. Les couleurs viennent des couleurs de sommets du modèle.
@export var matiere_modele: Material

@export_group("Circuit")
## Coché : ancienne ligne droite d'essai. Décoché : vrai circuit avec relief.
@export var piste_droite := true
## Longueur après laquelle on renvoie le bolide au départ. Doit être la même
## valeur que « longueur_motif » dans circuit.gd.
@export var longueur_boucle := 1200.0

@export_group("Relief (vrais circuits)")
@export var vitesse_rotation_circuit := 1.6  ## on tourne plus franchement que sur la ligne droite
@export var gravite := 32.0  ## plus forte que la vraie (9.8) : les sauts sont plus nerveux
@export var effet_pente := 0.5  ## 0 = les pentes ne changent pas la vitesse, 1 = effet réaliste
@export var controle_en_l_air := 0.35  ## part de la direction qu'on garde pendant un saut
@export var hauteur_chute := -30.0  ## en dessous de cette altitude, on réapparaît
@export var perte_choc := 0.75  ## part de la vitesse perdue en percutant un bloc de face

@export_group("Poids et direction (vrais circuits)")
@export var raideur_volant := 9.0  ## plus c'est petit, plus le volant met de temps à tourner
@export var inertie_lacet := 7.0  ## plus c'est petit, plus le bolide met de temps à pivoter (poids)
@export var facteur_rotation := 1.0  ## multiplie la vitesse de rotation (1 = comme avant)
@export var rigidite_haute_vitesse := 0.0  ## part de rotation perdue à pleine vitesse hors dérapage : sans dérapage, pas de virage serré

@export_group("Dérapage (vrais circuits)")
## Comme OutRun : on déclenche le dérapage en levant le pied ou en freinant en virage, à
## grande vitesse seulement. Hors dérapage la direction est lourde ; en dérapage elle devient
## légère : le bolide est « sur rail » et le volant règle la trajectoire.
@export var vitesse_min_derapage := 27.8  ## m/s (100 km/h) : en dessous, impossible d'amorcer un dérapage, et s'il est en cours il s'arrête
@export var duree_transition := 0.6  ## secondes pour passer de la conduite normale au dérapage complet (l'arrière se déleste progressivement)
@export var angle_entree_lent := 0.35  ## radians : angle visé à l'entrée du dérapage, à basse vitesse
@export var angle_entree_vite := 0.75  ## radians : idem à pleine vitesse (le bolide se met presque en travers)
@export var bonus_feinte := 1.3  ## entrée plus ample si on a braqué à l'opposé juste avant (feinte)
@export var delai_amorce := 0.7  ## secondes pendant lesquelles un appui (frein, Espace) ou un lever de pied reste « armé » : on peut braquer juste après
@export var angle_glisse_max := 1.0  ## radians : angle maximum
@export var poussee_glisse := 1.1  ## rad/s : braquer dans le sens de la glisse l'augmente
@export var rappel_glisse := 1.2  ## rad/s : contre-braquer ramène le bolide vers la ligne droite
@export var angle_bascule := 0.15  ## radians : quasi droit ; si on contre-braque encore, on bascule de l'autre côté
@export var acceleration_laterale := 42.0  ## m/s² : force de l'arc en dérapage (arc = ce chiffre ÷ vitesse)
@export var effet_volant_rail := 1.0  ## légèreté du volant en dérapage : 1 = aussi vif qu'en conduite normale, il resserre ou élargit l'arc
@export var redressement_gaz := 0.12  ## rad/s : sous les gaz, volant au neutre, la glisse se réduit
@export var redressement_sans_gaz := 0.35  ## idem sans les gaz : lever le pied aide à redresser
@export var angle_sortie := 0.12  ## radians : sous cet angle, on a retrouvé l'adhérence
@export var reactivite_glisse := 6.0  ## lissage de l'angle de glisse
@export var seuil_contre_braquage := 0.3  ## braquage à l'opposé à partir duquel on considère qu'on contre-braque
@export var adherence_normale := 9.0  ## hors dérapage la trajectoire rattrape vite le nez
@export var perte_vitesse_derapage := 0.18  ## part de vitesse perdue par seconde à glisse maximale
@export var recharge_boost_derapage := 14.0  ## jauge gagnée par seconde de dérapage

var vitesse := 0.0
var en_derapage := false
var jauge_boost := 100.0
var en_boost := false
var gaz := 0.0
## 0 = conduite normale, 1 = plein effet de boost. La caméra (champ de vision)
## et le son (concentration) s'en servent pour rester synchronisés.
var distorsion := 0.0
## 0 au début du boost, 1 quand il pousse à fond (voir duree_montee_boost).
var montee_boost := 0.0

## Rayon des roues (en mètres) : sert à faire tourner les roues à la bonne vitesse.
const RAYON_AVANT := 0.34
const RAYON_ARRIERE := 0.42
## Au-delà, les roues tourneraient trop vite pour l'écran (effet « roue de chariot »).
const ROTATION_VISUELLE_MAX := 28.0  # radians par seconde
const BRAQUAGE_MAX := 0.45  # radians, roues avant

var _cap := 0.0  # angle du bolide autour de l'axe vertical (là où pointe le nez)
var _cap_trajectoire := 0.0  # direction dans laquelle on se déplace vraiment
var _sens_derapage := 0.0  # -1 / +1 : côté du dérapage en cours (+1 = nez à gauche)
var _fumees: Array[CPUParticles3D] = []  # nuages de gomme aux roues arrière
var _glisse := 0.0  # angle entre la trajectoire et le nez, en dérapage
var _angle_tenu := 0.0  # angle de glisse visé (sans lissage)
var _t_derapage := 0.0  # temps écoulé depuis le début du dérapage
var _amorce := 0.0  # temps restant pendant lequel l'amorce du dérapage est armée
var _gaz_precedent := 0.0
var _sens_braquage := 0.0  # dernier côté braqué franchement (pour la feinte)
var _sens_precedent := 0.0
var _temps_depuis_changement := 9.0
var _volant := 0.0  # braquage lissé (-1..1) : le volant a du poids
var _lacet := 0.0  # vitesse de rotation actuelle du nez (inertie)
var _temps := 0.0
var _contact_mur := false
var _normale_sol := Vector3.UP
var _depart := Transform3D.IDENTITY
# Positions sûres récentes (au sol), pour réapparaître après une chute.
var _historique: Array[Transform3D] = []
var _minuteur_historique := 0.0
var _bloque_depuis := 0.0  # secondes passées à accélérer sans avancer

@onready var _carrosserie: Node3D = $Carrosserie
@onready var _flammes: Array[Node3D] = [
	$Carrosserie/ReacteurG/Flamme,
	$Carrosserie/ReacteurD/Flamme,
]
var _pivots_avant: Array[Node3D] = []  # tournent à gauche/droite (braquage)
var _roues_avant: Array[Node3D] = []  # tournent sur elles-mêmes
var _roues_arriere: Array[Node3D] = []
var _longueur_laterale := 0.0  # longueur lissée des flammes d'échappement latérales
var _largeur_laterale := 1.0
var _angle_roue_avant := 0.0
var _angle_roue_arriere := 0.0

@onready var _flammes_laterales: Array[Node3D] = [
	$Carrosserie/SortieG/Flamme,
	$Carrosserie/SortieD/Flamme,
]
@onready var _matiere_flamme: StandardMaterial3D = (
	$Carrosserie/ReacteurG/Flamme/Mesh as MeshInstance3D
).get_active_material(0)


func _ready() -> void:
	jauge_boost = jauge_max
	_depart = global_transform
	_cap = rotation.y
	_cap_trajectoire = _cap
	# Le modèle importé arrive avec une matière standard : on la remplace par la matière cartoon.
	for noeud in $Carrosserie/Modele.find_children("*", "MeshInstance3D", true, false):
		(noeud as MeshInstance3D).material_override = matiere_modele
	# Chaque roue du modèle est un nœud « RoueXxx » (qu'on oriente) qui contient
	# un maillage (qu'on fait tourner).
	for nom in ["RoueAvG", "RoueAvD"]:
		var pivot := $Carrosserie/Modele.find_child(nom, true, false) as Node3D
		_pivots_avant.append(pivot)
		_roues_avant.append(pivot.get_child(0) as Node3D)
	for nom in ["RoueArG", "RoueArD"]:
		var pivot := $Carrosserie/Modele.find_child(nom, true, false) as Node3D
		_roues_arriere.append(pivot.get_child(0) as Node3D)
	_creer_fumees()


## Nuages de fumée aux deux roues arrière, actifs pendant un dérapage.
## Ils restent dans le monde (ils ne suivent pas le bolide) : ça dessine une traînée.
func _creer_fumees() -> void:
	var matiere := StandardMaterial3D.new()
	matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	matiere.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	matiere.vertex_color_use_as_albedo = true
	matiere.albedo_color = Color.WHITE
	matiere.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Petite texture ronde de 16×16 pixels, nette (look PS1) : un rond en pixels, pas un carré.
	var rond := Gradient.new()
	rond.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	rond.offsets = PackedFloat32Array([0.0, 0.55, 0.95])
	var texture_ronde := GradientTexture2D.new()
	texture_ronde.gradient = rond
	texture_ronde.fill = GradientTexture2D.FILL_RADIAL
	texture_ronde.fill_from = Vector2(0.5, 0.5)
	texture_ronde.fill_to = Vector2(1.0, 0.5)
	texture_ronde.width = 16
	texture_ronde.height = 16
	matiere.albedo_texture = texture_ronde
	var maillage := QuadMesh.new()
	maillage.size = Vector2.ONE
	maillage.material = matiere
	var degrade := Gradient.new()
	degrade.colors = PackedColorArray([Color(0.95, 0.95, 1.0, 0.0), Color(0.9, 0.92, 1.0, 0.75), Color(0.7, 0.72, 0.85, 0.0)])
	degrade.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	var croissance := Curve.new()
	croissance.add_point(Vector2(0.0, 0.4))
	croissance.add_point(Vector2(1.0, 1.0))
	for pivot in _roues_arriere_pivots():
		var nuage := CPUParticles3D.new()
		nuage.local_coords = false
		nuage.emitting = false
		nuage.amount = 56
		nuage.lifetime = 0.9
		nuage.mesh = maillage
		nuage.direction = Vector3(0.0, 1.0, 0.0)
		nuage.spread = 35.0
		nuage.initial_velocity_min = 0.6
		nuage.initial_velocity_max = 2.2
		nuage.gravity = Vector3(0.0, 0.4, 0.0)
		nuage.scale_amount_min = 1.4
		nuage.scale_amount_max = 2.6
		nuage.scale_amount_curve = croissance
		nuage.color_ramp = degrade
		nuage.position = to_local(pivot.global_position) * Vector3(1.0, 0.0, 1.0) + Vector3(0.0, 0.15, 0.0)
		add_child(nuage)
		_fumees.append(nuage)


func _roues_arriere_pivots() -> Array[Node3D]:
	var pivots: Array[Node3D] = []
	for nom in ["RoueArG", "RoueArD"]:
		pivots.append($Carrosserie/Modele.find_child(nom, true, false) as Node3D)
	return pivots


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("recommencer"):
		_recommencer()

	_conduire(delta)
	_mettre_a_jour_distorsion(delta)
	if piste_droite:
		_avancer_tout_droit(delta)
		_garder_sur_la_piste()
		_boucler_circuit()
	else:
		_avancer_sur_le_relief(delta)
		_surveiller_chute(delta)
	_animer(delta)
	for nuage in _fumees:
		nuage.emitting = en_derapage and is_on_floor()


## Combien on va vite par rapport à la vitesse max normale (1.0 = vitesse max,
## plus de 2.0 en plein boost).
func cap_camera() -> float:
	# Pendant un dérapage, la caméra regarde surtout la trajectoire : on voit le
	# bolide de travers (comme dans OutRun) au lieu de rester collé derrière son nez.
	return _cap - _glisse * 0.75 if en_derapage else _cap


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
		montee_boost = minf(montee_boost + delta / duree_montee_boost, 1.0)
		# La poussée grandit avec le carré de la montée : douce au début, très
		# forte à la fin.
		var poussee := lerpf(0.15, 1.0, montee_boost * montee_boost)
		vitesse = move_toward(vitesse, vitesse_boost, acceleration_boost * poussee * delta)
	else:
		montee_boost = maxf(montee_boost - delta * 2.0, 0.0)
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
	if piste_droite:
		# Plus on va vite, plus l'angle permis est petit : à 600 km/h, quelques
		# degrés suffisent déjà à traverser la piste.
		var angle_permis := angle_max / (1.0 + ratio_vitesse())
		_cap = clampf(_cap + virage * vitesse_rotation * maniabilite * delta, -angle_permis, angle_permis)
		if virage == 0.0:
			_cap = move_toward(_cap, 0.0, redressement * delta)
	else:
		var controle := 1.0 if is_on_floor() else controle_en_l_air
		_volant = lerpf(_volant, virage, 1.0 - exp(-raideur_volant * delta))
		_mettre_a_jour_derapage(delta)
		if en_derapage:
			_piloter_derapage(_volant, maniabilite * controle, delta)
		else:
			# Sous-virage : plus les pneus saturent, moins le nez suit le volant.
			var cible := _volant * vitesse_rotation_circuit * facteur_rotation * maniabilite * controle
			# Direction lourde à grande vitesse : on ne tourne serré qu'en dérapant.
			cible *= 1.0 - rigidite_haute_vitesse * smoothstep(0.5, 1.0, ratio_vitesse())
			_lacet = lerpf(_lacet, cible, 1.0 - exp(-inertie_lacet * delta))
			_cap += _lacet * delta
			if absf(angle_difference(_cap_trajectoire, _cap)) > 0.25:
				# Fin de dérapage : le nez revient vers la trajectoire, sans à-coup sur la direction.
				_cap = lerp_angle(_cap, _cap_trajectoire, 1.0 - exp(-6.0 * delta))
			else:
				# L'adhérence ramène vite la trajectoire dans l'axe du nez.
				_cap_trajectoire = lerp_angle(_cap_trajectoire, _cap, 1.0 - exp(-adherence_normale * delta))
	rotation.y = _cap


## Décide si on est en dérapage. Comme dans OutRun, on l'amorce exprès : à grande
## vitesse, on braque franchement tout en lâchant le gaz (ou en freinant, ou avec la
## touche « deraper »). Braquer seul, sans amorce, ne fait jamais déraper.
func _mettre_a_jour_derapage(delta: float) -> void:
	# Une amorce = un APPUI bref (frein, Espace) ou un lever de pied, fait à grande vitesse.
	# Elle reste armée un instant : on a le temps de braquer, et il n'est pas nécessaire de
	# garder la touche enfoncée (le frein fait d'ailleurs chuter la vitesse).
	var appui := Input.is_action_just_pressed("freiner") or Input.is_action_just_pressed("deraper")
	var levee := _gaz_precedent > 0.5 and gaz < 0.1
	_gaz_precedent = gaz
	if (appui or levee) and vitesse >= vitesse_min_derapage:
		_amorce = delai_amorce
	else:
		_amorce = maxf(_amorce - delta, 0.0)

	_temps_depuis_changement += delta
	if absf(_volant) > 0.5 and signf(_volant) != _sens_braquage:
		_sens_precedent = _sens_braquage
		_sens_braquage = signf(_volant)
		_temps_depuis_changement = 0.0

	if not is_on_floor() or vitesse < vitesse_min_derapage:
		en_derapage = false
		_amorce = 0.0
		return
	if en_derapage:
		return
	if _amorce <= 0.0 or absf(_volant) < 0.35:
		return

	_amorce = 0.0
	en_derapage = true
	_sens_derapage = signf(_volant)
	var angle := lerpf(angle_entree_lent, angle_entree_vite, clampf(ratio_vitesse(), 0.0, 1.0))
	# Feinte : un coup de volant à l'opposé juste avant donne une entrée plus ample.
	if _sens_precedent == -_sens_derapage and _temps_depuis_changement < 0.8:
		angle = minf(angle * bonus_feinte, angle_glisse_max)
	_angle_tenu = angle
	# On part de la glisse actuelle (quasi nulle) : l'angle monte progressivement (voir _piloter_derapage).
	_glisse = clampf(angle_difference(_cap_trajectoire, _cap), -0.2, 0.2)
	_t_derapage = 0.0
	_lacet = 0.0


## Dérapage « sur rail » (comme OutRun) : le bolide glisse sur un arc régulier, le nez
## pointé vers l'intérieur du virage. Le volant règle la trajectoire, il ne coupe pas le dérapage :
## - volant au neutre : l'arc est stable ; sous les gaz l'angle diminue très lentement ;
## - braquer dans le sens de la glisse : l'arc se resserre (et l'angle grandit un peu) ;
## - contre-braquer : l'arc s'élargit ; en tenant franchement, on bascule de l'autre côté.
func _piloter_derapage(volant: float, manoeuvre: float, delta: float) -> void:
	var relatif := volant * _sens_derapage  # + = dans le sens de la glisse, - = contre

	var angle := _angle_tenu
	if relatif > 0.1:
		# Plus on braque, plus l'angle visé est grand ; braquer à moitié ne pousse qu'à moitié.
		var angle_vise := lerpf(angle_entree_lent, minf(angle_entree_vite * 1.2, angle_glisse_max), clampf(relatif, 0.0, 1.0))
		if angle < angle_vise:
			angle = minf(angle + relatif * poussee_glisse * delta, angle_vise)
	elif relatif < -0.1:
		# Contre-braquer redresse le bolide vers la ligne droite : pas de saut d'un côté à l'autre.
		angle -= -relatif * rappel_glisse * delta
	else:
		angle -= lerpf(redressement_sans_gaz, redressement_gaz, clampf(gaz, 0.0, 1.0)) * delta
	if Input.get_action_strength("freiner") > 0.3:
		angle += 0.2 * delta  # freiner en dérapage déstabilise l'arrière
	angle = clampf(angle, 0.0, angle_glisse_max)
	# Quasi droit et on contre-braque encore (en continu) : on bascule en dérapage de l'autre côté.
	if angle < angle_bascule and relatif < -seuil_contre_braquage:
		_sens_derapage = -_sens_derapage
		relatif = -relatif
		angle = angle_bascule
		_t_derapage = 0.0  # la glisse réelle repasse par zéro toute seule (pas de saut)
	_angle_tenu = angle

	# Transition : l'arrière se déleste progressivement (angle et arc montent ensemble).
	_t_derapage += delta
	var progression := smoothstep(0.0, 1.0, _t_derapage / duree_transition)
	_glisse = lerpf(_glisse, _sens_derapage * angle * progression, 1.0 - exp(-reactivite_glisse * delta))

	# L'arc : une accélération latérale (donc un arc plus large à haute vitesse), réglée par le volant.
	var arc := _sens_derapage * acceleration_laterale / maxf(vitesse, 25.0)
	arc *= clampf(angle / 0.5, 0.6, 1.3) * lerpf(0.4, 1.0, progression)
	# Le volant agit directement sur la trajectoire, aussi vif qu'en conduite normale :
	# braquer dans le sens de la glisse resserre l'arc, braquer à l'opposé l'élargit.
	arc += volant * vitesse_rotation_circuit * facteur_rotation * manoeuvre * effet_volant_rail
	_cap_trajectoire += arc * delta
	_cap = _cap_trajectoire + _glisse

	vitesse = maxf(vitesse - vitesse * perte_vitesse_derapage * absf(_glisse) / angle_glisse_max * delta, 0.0)
	jauge_boost = minf(jauge_boost + recharge_boost_derapage * delta, jauge_max)

	if angle < angle_sortie and relatif > -seuil_contre_braquage:
		en_derapage = false
		_lacet = 0.0


func _avancer_tout_droit(delta: float) -> void:
	var direction := Vector3(-sin(_cap), 0.0, -cos(_cap))
	position += direction * vitesse * delta


func _avancer_sur_le_relief(delta: float) -> void:
	var avant := Vector3(-sin(_cap_trajectoire), 0.0, -cos(_cap_trajectoire))
	var en_l_air := not is_on_floor()

	if not en_l_air:
		# On avance le long du sol : la direction est « couchée » sur la pente.
		_normale_sol = get_floor_normal()
		var le_long_du_sol := (avant - _normale_sol * avant.dot(_normale_sol)).normalized()
		# Ça freine en montée et ça accélère en descente.
		vitesse = maxf(vitesse - gravite * effet_pente * le_long_du_sol.y * delta, 0.0)
		velocity = le_long_du_sol * vitesse
	else:
		# En l'air : on garde l'élan, la gravité nous ramène vers le sol.
		velocity.x = avant.x * vitesse
		velocity.z = avant.z * vitesse
		velocity.y -= gravite * delta
		_normale_sol = _normale_sol.lerp(Vector3.UP, 1.0 - exp(-3.0 * delta))

	var vitesse_chute := -velocity.y
	move_and_slide()

	if en_l_air and is_on_floor() and vitesse_chute > 6.0:
		atterrissage.emit(vitesse_chute)

	_gerer_chocs(avant)


func _gerer_chocs(avant: Vector3) -> void:
	var touche := false
	for i in get_slide_collision_count():
		var normale := get_slide_collision(i).get_normal()
		if absf(normale.y) > 0.6:
			continue  # c'est le sol, pas un obstacle
		touche = true
		var de_face := -avant.dot(normale)  # 1 = de face, 0 = on frotte
		if de_face > 0.1 and not _contact_mur:
			mur_touche.emit(vitesse * de_face)
			vitesse *= 1.0 - perte_choc * de_face
			# L'obstacle nous dévie : on repart le long de sa paroi.
			var le_long := avant - normale * avant.dot(normale)
			if le_long.length() > 0.1:
				_cap = atan2(-le_long.x, -le_long.z)
				_cap_trajectoire = _cap
				en_derapage = false
	if touche and _contact_mur:
		# Toujours collé à l'obstacle : on ne peut pas aller plus vite que ce
		# qu'on avance vraiment (sinon le compteur s'affole contre un bloc).
		vitesse = minf(vitesse, maxf(get_real_velocity().dot(avant), 0.0) + 5.0)
	_contact_mur = touche


func _surveiller_chute(delta: float) -> void:
	if global_position.y < hauteur_chute:
		_reapparaitre()
		return

	# Coincé (on accélère mais on n'avance plus depuis 2 s) : on réapparaît.
	if gaz > 0.5 and get_real_velocity().length() < 2.0:
		_bloque_depuis += delta
		if _bloque_depuis > 2.0:
			_bloque_depuis = 0.0
			_reapparaitre()
			return
	else:
		_bloque_depuis = 0.0

	# Toutes les 0,25 s, on note où on est si on roule normalement au sol.
	_minuteur_historique += delta
	if _minuteur_historique >= 0.25 and is_on_floor() and not _contact_mur:
		_minuteur_historique = 0.0
		_historique.append(global_transform)
		if _historique.size() > 12:
			_historique.pop_front()


## Remet le bolide sur la route, un peu avant l'endroit où il est tombé.
func reapparaitre() -> void:
	_reapparaitre()


func _reapparaitre() -> void:
	# On repart d'une position notée environ 1,5 s avant la chute, donc
	# avant le trou, avec un peu de vitesse pour ne pas repartir de zéro.
	var cible := _depart
	if _historique.size() >= 6:
		cible = _historique[_historique.size() - 6]
	elif not _historique.is_empty():
		cible = _historique[0]
	_historique.clear()

	var ancienne := global_position
	global_transform = cible
	_cap = rotation.y
	_cap_trajectoire = _cap
	en_derapage = false
	_volant = 0.0
	_lacet = 0.0
	velocity = Vector3.ZERO
	vitesse = vitesse_max * 0.4
	teleporte.emit(global_position - ancienne)


func _mettre_a_jour_distorsion(delta: float) -> void:
	var rapidite := attaque_distorsion if en_boost else relachement_distorsion
	# L'effet suit la montée du boost : il s'installe en même temps que la poussée.
	distorsion = lerpf(distorsion, montee_boost if en_boost else 0.0, 1.0 - exp(-rapidite * delta))


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

	# La carrosserie épouse la pente (ou suit sa trajectoire pendant un saut).
	var n := global_basis.inverse() * _normale_sol
	var tangage_sol := atan2(n.z, n.y)
	var roulis_sol := atan2(-n.x, n.y)
	if not piste_droite and not is_on_floor():
		var horizontale := Vector2(velocity.x, velocity.z).length()
		tangage_sol = clampf(atan2(velocity.y, maxf(horizontale, 1.0)) * 0.6, -0.5, 0.5)

	# La voiture roule sur ses roues : petites vibrations de suspension (plus fortes
	# à grande vitesse), léger roulis dans les virages, nez qui se lève en boost.
	var allure := clampf(ratio_vitesse(), 0.0, 1.0)
	_carrosserie.position.y = 0.7 + (sin(_temps * 37.0) * 0.004 + sin(_temps * 13.0) * 0.003) * allure
	_carrosserie.rotation.z = lerpf(_carrosserie.rotation.z, roulis_sol + virage * 0.07 * allure, lissage)
	_carrosserie.rotation.x = lerpf(_carrosserie.rotation.x, tangage_sol + (0.04 if en_boost else 0.0), lissage)

	_animer_roues(delta, virage, lissage)

	var longueur_flamme := 0.3 + gaz * 0.8 + (1.6 if en_boost else 0.0)
	var vibration := 1.0 + sin(_temps * 60.0) * 0.08
	for flamme in _flammes:
		flamme.scale.y = lerpf(flamme.scale.y, longueur_flamme, lissage) * vibration

	# Flammes latérales : de plus en plus longues avec la vitesse, énormes en boost.
	var allure_flamme := clampf(ratio_vitesse(), 0.0, 1.0)
	var longueur_laterale := pow(allure_flamme, 2.0) * 0.8 + (2.2 if en_boost else 0.0)
	var largeur_laterale := 1.0 + (0.8 if en_boost else 0.0)
	_longueur_laterale = lerpf(_longueur_laterale, longueur_laterale, lissage)
	_largeur_laterale = lerpf(_largeur_laterale, largeur_laterale, lissage)
	for flamme in _flammes_laterales:
		flamme.visible = _longueur_laterale > 0.08
		flamme.scale = Vector3(_largeur_laterale, maxf(_longueur_laterale, 0.01) * vibration, _largeur_laterale)

	var couleur := Color(1.0, 0.2, 0.6) if en_boost else Color(0.3, 0.9, 1.0)
	_matiere_flamme.emission = _matiere_flamme.emission.lerp(couleur, lissage)


func _animer_roues(delta: float, virage: float, lissage: float) -> void:
	# Les roues avant tournent vers le virage (moins quand on va vite).
	var braquage := virage * BRAQUAGE_MAX / (1.0 + ratio_vitesse())
	for pivot in _pivots_avant:
		pivot.rotation.y = lerpf(pivot.rotation.y, braquage, lissage)

	# Rotation des roues : vitesse / rayon = radians par seconde (le haut de la roue va vers l'avant).
	var rot_avant := minf(vitesse / RAYON_AVANT, ROTATION_VISUELLE_MAX)
	var rot_arriere := minf(vitesse / RAYON_ARRIERE, ROTATION_VISUELLE_MAX)
	_angle_roue_avant = fmod(_angle_roue_avant - rot_avant * delta, TAU)
	_angle_roue_arriere = fmod(_angle_roue_arriere - rot_arriere * delta, TAU)
	for roue in _roues_avant:
		roue.rotation.x = _angle_roue_avant
	for roue in _roues_arriere:
		roue.rotation.x = _angle_roue_arriere


func _recommencer() -> void:
	var ancienne := global_position
	global_transform = _depart
	_cap = rotation.y
	_cap_trajectoire = _cap
	en_derapage = false
	_volant = 0.0
	_lacet = 0.0
	velocity = Vector3.ZERO
	vitesse = 0.0
	jauge_boost = jauge_max
	distorsion = 0.0
	montee_boost = 0.0
	_historique.clear()
	teleporte.emit(global_position - ancienne)
