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
@export var vitesse_max := 85.0  ## environ 306 km/h sans boost
@export var vitesse_boost := 146.0  ## environ 525 km/h : la vitesse la plus haute du jeu
@export var acceleration := 26.0
@export var acceleration_boost := 82.0  ## atteinte au bout de la montée du boost
@export var freinage := 60.0
@export var frottement := 8.0
## Marche arrière : on reste sur « freiner » une fois arrêté.
@export var vitesse_marche_arriere := 14.0  ## environ 50 km/h
@export var acceleration_marche_arriere := 12.0

@export_group("Direction")
@export var vitesse_rotation := 1.1  ## en radians par seconde
@export var redressement := 0.4  ## le bolide se remet doucement droit si on lâche
@export var angle_max := 0.6  ## on ne peut pas faire demi-tour (piste droite)
@export var demi_largeur_piste := 13.0

@export_group("Boost")
@export var jauge_max := 100.0
@export var boost_infini := true  ## phase de test des voitures : pas de jauge, boost illimité
@export var consommation := 30.0  ## par seconde de boost
@export var recharge := 10.0  ## par seconde sans boost
@export var attaque_distorsion := 8.0  ## vitesse à laquelle l'effet de boost s'installe
@export var relachement_distorsion := 5.0  ## vitesse à laquelle il s'efface après le boost
## Secondes pour que le boost donne toute sa poussée : il démarre doucement,
## puis pousse de plus en plus fort (une courbe qui se creuse, pas un coup sec).
## 0 = toute la poussée d'un coup.
@export var duree_montee_boost := 0.0
## Après le boost, vitesse perdue par seconde pour revenir à la vitesse max (plus c'est grand, plus le boost s'arrête net).
@export var freinage_apres_boost := 48.0

@export_group("Apparence")
## Où se trouvent les yeux du pilote, dans le repère de la carrosserie (vue cockpit).
@export var position_cockpit := Vector3(0.0, 0.62, 0.45)
## Caméra posée sur le nez du bolide (vue capot : on ne voit plus la voiture).
@export var position_capot := Vector3(0.0, 0.3, -2.3)
## Matière (toon) appliquée au modèle 3D. Les couleurs viennent des couleurs de sommets du modèle.
@export var matiere_modele: Material
## Effet « Redline » (le film d'animation) : en boost, le bolide s'étire vers l'arrière,
## comme happé par la vitesse (le nez ne bouge pas). 0 = pas d'effet, 0.35 = 35 % plus long.
@export var etirement_boost := 0.35
@export var affinement_boost := 0.12  ## en même temps, il s'affine d'autant (largeur et hauteur)

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

@export_group("Half-pipe (vrais circuits)")
## Sur une paroi penchée, la pente fait tourner le bolide vers l'intérieur,
## comme dans un vrai virage relevé : plus on va vite, plus on monte haut sur
## la paroi, et c'est elle qui fait le virage. 1 = comme en vrai, 0 = rien
## (plus que 1 : la paroi tient mieux qu'en vrai, c'est un jeu d'arcade).
@export var effet_paroi := 2.5
@export var rotation_paroi_max := 1.5  ## rad/s : la paroi ne fait jamais tourner plus vite
## La paroi guide aussi : si on y monte ou descend en biais, le nez revient
## doucement à l'horizontale de la paroi (sinon on rebondirait d'un bord à
## l'autre). Plus c'est grand, plus on reste à sa hauteur.
@export var guidage_paroi := 5.0
@export var collage_paroi := 4.0  ## m/s : on est plaqué contre la paroi pour ne pas la quitter

@export_group("Poids et direction (vrais circuits)")
@export var raideur_volant := 9.0  ## plus c'est petit, plus le volant met de temps à tourner
@export var inertie_lacet := 7.0  ## plus c'est petit, plus le bolide met de temps à pivoter (poids)
@export var facteur_rotation := 1.0  ## multiplie la vitesse de rotation (1 = comme avant)
@export var rigidite_haute_vitesse := 0.0  ## part de rotation perdue à pleine vitesse hors dérapage : sans dérapage, pas de virage serré

@export_group("Dérapage (vrais circuits)")
## UNE seule variable pilote tout : le « grip » de l'arrière (1 = pleine adhérence, 0 = il glisse).
## - un appui sur frein / Espace, ou lâcher le gaz, fait chuter le grip d'un coup (au-dessus de la
##   vitesse minimale) ; tenir Espace le maintient bas ;
## - le grip remonte tout seul ; bien plus lentement tant qu'on braque (pneus saturés) ;
## - plus le grip est bas, plus le nez se met en travers, plus la courbure est « tenue » (volant
##   lâché = on garde l'élan) et plus elle change progressivement (jamais de saut de côté) ;
## - en dessous de « seuil_derapage », on est « en dérapage » (fumée, recharge de boost).
@export var vitesse_min_derapage := 27.8  ## m/s (100 km/h) : en dessous, le grip revient et rien ne peut le faire chuter
@export var seuil_derapage := 0.6  ## grip en dessous duquel on est « en dérapage »
@export var impulsion_appui := 0.8  ## grip perdu d'un coup à un appui sur frein ou Espace
@export var impulsion_levee := 0.5  ## grip perdu d'un coup quand on lâche le gaz
@export var grip_frein_a_main := 0.2  ## grip maintenu tant qu'Espace est tenu
@export var grip_frein := 0.5  ## grip maintenu tant que le frein est tenu en virage
@export var recuperation := 0.45  ## par seconde : le grip remonte quand le volant est au neutre
@export var recuperation_en_virage := 0.05  ## par seconde : idem tant qu'on braque (le dérapage dure le temps du virage)
@export var angle_entree_lent := 0.35  ## radians : angle de glisse à pleine courbure, à basse vitesse
@export var angle_entree_vite := 0.75  ## radians : idem à pleine vitesse (le bolide se met presque en travers)
@export var angle_glisse_max := 1.0  ## radians : angle maximum
@export var facteur_rotation_derapage := 1.15  ## le volant tourne un peu plus fort quand le grip est bas
@export var variation_courbure := 3.0  ## rad/s² : vitesse max de changement de courbure à grip nul (plus petit = plus progressif)
@export var variation_courbure_grip := 20.0  ## idem à plein grip (conduite normale)
@export var maintien_courbure_gaz := 0.35  ## par seconde : volant lâché, grip bas, sous gaz : la courbure s'ouvre lentement
@export var maintien_courbure_sans_gaz := 1.0  ## idem sans les gaz : lever le pied aide à redresser
@export var maintien_courbure_grip := 7.0  ## idem à plein grip : on redresse tout de suite
@export var reactivite_glisse := 6.0  ## lissage de l'angle de glisse
@export var perte_vitesse_derapage := 0.18  ## part de vitesse perdue par seconde à glisse maximale
@export var recharge_boost_derapage := 14.0  ## jauge gagnée par seconde de dérapage

@export_group("Mode glisse (essai de Maximo : Wipeout × Art of Rally)")
## Conduite d'essai, activée dans le menu (Settings > Slide handling). Décoché = conduite d'origine.
## - braquer fort à haute vitesse fait glisser l'arrière tout seul (pas besoin de bouton) ;
## - la glisse garde l'élan (on perd peu de vitesse) ;
## - le boost en glisse sert à se recaler : la trajectoire rejoint la direction du nez
##   et l'arrière se replante. On vise avec le nez, puis on boost pour sortir de la glisse.
@export var mode_glisse := false
@export var braquage_glisse := 0.7  ## au-delà de ce braquage (0..1), le grip part tout seul
@export var perte_grip_braquage := 1.6  ## grip perdu par seconde en braquant fort
@export var perte_vitesse_glisse := 0.06  ## remplace « perte_vitesse_derapage » dans ce mode
@export var correction_boost := 2.2  ## rad/s : en boost, la trajectoire rejoint le nez
@export var reprise_grip_boost := 1.5  ## grip regagné par seconde en boost

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
const DEMI_LONGUEUR := 2.1  # mètres, du centre au nez (pour garder le nez en place quand on s'étire)
const HAUTEUR_PIVOT := 0.7  # mètres entre le pivot de la carrosserie et le bas du modèle (voir vehicule.tscn)

var _cap := 0.0  # angle du bolide autour de l'axe vertical (là où pointe le nez)
var _cap_trajectoire := 0.0  # direction dans laquelle on se déplace vraiment
var _sens_derapage := 0.0  # -1 / +1 : côté du dérapage en cours (+1 = nez à gauche)
var _fumees: Array[CPUParticles3D] = []  # nuages de gomme aux roues arrière
var _grip := 1.0  # adhérence de l'arrière : 1 = normale, 0 = glisse totale
var _glisse := 0.0  # angle entre la trajectoire et le nez, en dérapage
var _ignorer_boost := false  # vrai après une perte de focus, jusqu'au relâchement de la touche
var _omega := 0.0  # vitesse de rotation de la trajectoire en dérapage (rad/s) : la courbure
var _appui_en_attente := false  # un appui frein/Espace reçu, pas encore pris en compte par la physique
var _gaz_precedent := 0.0
var _volant := 0.0  # braquage lissé (-1..1) : le volant a du poids
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
var _decalage_etirement := 0.0  # recul de la carrosserie pendant l'étirement du boost

@onready var _flammes_laterales: Array[Node3D] = [
	$Carrosserie/SortieG/Flamme,
	$Carrosserie/SortieD/Flamme,
]
@onready var _matiere_flamme: StandardMaterial3D = (
	$Carrosserie/ReacteurG/Flamme/Mesh as MeshInstance3D
).get_active_material(0)


func _ready() -> void:
	jauge_boost = jauge_max
	var reglages := get_node_or_null("/root/Graphismes")
	if reglages != null:
		mode_glisse = reglages.conduite_glisse
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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("deraper") or event.is_action_pressed("freiner"):
		_appui_en_attente = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_ignorer_boost = true


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
	return _cap - _glisse * 0.75


func ratio_vitesse() -> float:
	return vitesse / vitesse_max


## Le point de vue du pilote (ou du nez, si « capot ») : il suit la
## carrosserie (pente, roulis, dérapage).
func repere_cockpit(capot := false) -> Transform3D:
	# Sans l'étirement du boost : la caméra ne doit être ni déformée ni reculée avec lui.
	var repere := _carrosserie.global_transform
	repere.basis = repere.basis.orthonormalized()
	repere.origin -= repere.basis.z * _decalage_etirement
	return repere * Transform3D(Basis.IDENTITY, position_capot if capot else position_cockpit)


## La direction du « haut » du sol sous le bolide (penchée sur une paroi).
func normale_sol() -> Vector3:
	return _normale_sol


func vitesse_kmh() -> float:
	return vitesse * 3.6


func _conduire(delta: float) -> void:
	gaz = Input.get_action_strength("accelerer")
	var frein := Input.get_action_strength("freiner")
	var virage := Input.get_axis("droite", "gauche")

	# Sécurité : si la fenêtre perd le focus pendant qu'on tient la touche, le jeu peut rater
	# son relâchement. On ignore alors le boost jusqu'à ce qu'on lâche vraiment la touche.
	if _ignorer_boost and not Input.is_action_pressed("boost"):
		_ignorer_boost = false
	en_boost = Input.is_action_pressed("boost") and not _ignorer_boost and (boost_infini or jauge_boost > 0.0)

	if en_boost:
		if not boost_infini:
			jauge_boost = maxf(jauge_boost - consommation * delta, 0.0)
		montee_boost = minf(montee_boost + delta / duree_montee_boost, 1.0) if duree_montee_boost > 0.0 else 1.0
		# La poussée grandit avec le carré de la montée : douce au début, très
		# forte à la fin.
		var poussee := lerpf(0.15, 1.0, montee_boost * montee_boost)
		vitesse = move_toward(vitesse, vitesse_boost, acceleration_boost * poussee * delta)
	else:
		montee_boost = maxf(montee_boost - delta * 2.0, 0.0)
		jauge_boost = minf(jauge_boost + recharge * delta, jauge_max)
		if vitesse > vitesse_max:
			# Après un boost, on redescend doucement : la vitesse « reste » un peu.
			vitesse = move_toward(vitesse, vitesse_max, freinage_apres_boost * delta)
		elif gaz > 0.0:
			# En marche arrière, accélérer commence par freiner.
			var poussee_avant := acceleration if vitesse >= 0.0 else freinage
			vitesse = move_toward(vitesse, vitesse_max * gaz, poussee_avant * delta)
		elif frein <= 0.0:
			vitesse = move_toward(vitesse, 0.0, frottement * delta)

	if frein > 0.0 and gaz <= 0.0 and vitesse <= 0.0:
		# Arrêté et toujours sur le frein : on recule, comme dans la plupart des jeux.
		vitesse = move_toward(vitesse, -vitesse_marche_arriere * frein, acceleration_marche_arriere * delta)
	elif frein > 0.0:
		vitesse = move_toward(vitesse, 0.0, freinage * frein * delta)

	# On tourne moins vite à très haute vitesse, sinon c'est ingérable.
	var maniabilite := clampf(absf(vitesse) / 15.0, 0.0, 1.0) / (1.0 + absf(ratio_vitesse()) * 0.6)
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
		_mettre_a_jour_grip(virage, maniabilite * controle, delta)
		_conduire_avec_grip(virage, maniabilite * controle, delta)
	rotation.y = _cap


## Vitesse de rotation maximale du volant, en tenant compte du grip (un peu plus vive quand il est bas).
func _rotation_max(manoeuvre: float) -> float:
	return vitesse_rotation_circuit * facteur_rotation * manoeuvre * lerpf(facteur_rotation_derapage, 1.0, _grip)


## L'unique variable : le grip de l'arrière. Les appuis le font chuter, le temps le fait remonter.
func _mettre_a_jour_grip(brut: float, manoeuvre: float, delta: float) -> void:
	var appui := _appui_en_attente or Input.is_action_just_pressed("freiner") or Input.is_action_just_pressed("deraper")
	_appui_en_attente = false
	var levee := _gaz_precedent > 0.5 and gaz < 0.1
	_gaz_precedent = gaz

	if vitesse < vitesse_min_derapage:
		# Trop lent : le grip revient, et rien ne peut le faire chuter.
		_grip = minf(_grip + 3.0 * delta, 1.0)
	else:
		if appui:
			_grip = maxf(_grip - impulsion_appui, 0.05)
		if levee:
			_grip = maxf(_grip - impulsion_levee, 0.05)
		if mode_glisse:
			if en_boost:
				_grip = minf(_grip + reprise_grip_boost * delta, 1.0)  # le boost replante l'arrière
			elif absf(brut) > braquage_glisse and gaz > 0.3:
				_grip = maxf(_grip - perte_grip_braquage * delta, grip_frein_a_main)  # braquer fort fait glisser
		var plancher := 1.0
		if Input.is_action_pressed("deraper"):
			plancher = grip_frein_a_main
		elif Input.get_action_strength("freiner") > 0.3 and absf(brut) > 0.1:
			plancher = grip_frein
		if plancher < 1.0:
			# Frein à main ou frein tenu : on maintient le grip bas.
			_grip = move_toward(_grip, minf(plancher, _grip), 3.0 * delta)
		else:
			var rec := recuperation_en_virage if absf(brut) > 0.1 else recuperation
			_grip = minf(_grip + rec * delta, 1.0)

	en_derapage = _grip < seuil_derapage


## Le virage, quel que soit le grip. La trajectoire tourne à la vitesse « _omega » (la courbure) ;
## à plein grip elle suit le volant tout de suite, à grip bas elle change progressivement et se
## maintient volant lâché. Le nez se met en travers d'autant plus que le grip est bas et que la
## courbure est forte. Aucun changement brusque : tout est continu en fonction du grip.
func _conduire_avec_grip(brut: float, manoeuvre: float, delta: float) -> void:
	var rotation_max := _rotation_max(manoeuvre)
	if absf(brut) > 0.1:
		var cible := _volant * rotation_max
		var pas := (cible - _omega) * (1.0 - exp(-inertie_lacet * delta))
		var limite := lerpf(variation_courbure, variation_courbure_grip, smoothstep(0.4, 0.9, _grip)) * delta
		_omega += clampf(pas, -limite, limite)
	else:
		# Volant lâché : on garde l'élan (grip bas) ou on redresse (plein grip).
		var maintien := lerpf(maintien_courbure_sans_gaz, maintien_courbure_gaz, clampf(gaz, 0.0, 1.0))
		maintien = lerpf(maintien, maintien_courbure_grip, smoothstep(0.5, 1.0, _grip))
		_omega *= exp(-maintien * delta)
	_cap_trajectoire += _omega * delta

	if absf(_omega) > 0.04:
		_sens_derapage = signf(_omega)
	var charge := clampf(absf(_omega) / maxf(rotation_max, 0.1), 0.0, 1.0)
	var angle_max_vitesse := lerpf(angle_entree_lent, angle_entree_vite, clampf(ratio_vitesse(), 0.0, 1.0))
	var angle := charge * angle_max_vitesse * (1.0 - smoothstep(0.2, 1.0, _grip))
	if en_derapage and Input.get_action_strength("freiner") > 0.3:
		angle *= 1.15  # freiner en dérapage déstabilise l'arrière
	angle = minf(angle, angle_glisse_max)
	_glisse = lerpf(_glisse, _sens_derapage * angle, 1.0 - exp(-reactivite_glisse * delta))
	if mode_glisse and en_boost and absf(_glisse) > 0.01:
		# Le boost pousse dans l'axe du nez : la trajectoire tourne vers lui (le nez ne bouge pas).
		var pas := clampf(_glisse, -correction_boost * delta, correction_boost * delta)
		_cap_trajectoire += pas
		_glisse -= pas
	_cap = _cap_trajectoire + _glisse

	if en_derapage:
		var perte := perte_vitesse_glisse if mode_glisse else perte_vitesse_derapage
		vitesse = maxf(vitesse - vitesse * perte * absf(_glisse) / angle_glisse_max * delta, 0.0)
		jauge_boost = minf(jauge_boost + recharge_boost_derapage * delta, jauge_max)


func _avancer_tout_droit(delta: float) -> void:
	var direction := Vector3(-sin(_cap), 0.0, -cos(_cap))
	position += direction * vitesse * delta


func _avancer_sur_le_relief(delta: float) -> void:
	var en_l_air := not is_on_floor()
	if not en_l_air:
		_normale_sol = get_floor_normal()
		_tourner_avec_la_paroi(delta)
	var avant := Vector3(-sin(_cap_trajectoire), 0.0, -cos(_cap_trajectoire))

	if not en_l_air:
		# On avance le long du sol : la direction est « couchée » sur la pente.
		var le_long_du_sol := (avant - _normale_sol * avant.dot(_normale_sol)).normalized()
		# Ça freine en montée et ça accélère en descente.
		# (Sans jamais changer de sens tout seul : on ne recule pas dans une côte.)
		var nouvelle := vitesse - gravite * effet_pente * le_long_du_sol.y * delta
		vitesse = maxf(nouvelle, 0.0) if vitesse >= 0.0 else minf(nouvelle, 0.0)
		velocity = le_long_du_sol * vitesse
		if _normale_sol.y < 0.97:
			# Sur une paroi : on reste plaqué contre elle (pas de petit saut).
			velocity -= _normale_sol * collage_paroi
	else:
		# En l'air : on garde l'élan, la gravité nous ramène vers le sol.
		velocity.x = avant.x * vitesse
		velocity.z = avant.z * vitesse
		velocity.y -= gravite * delta
		_normale_sol = _normale_sol.lerp(Vector3.UP, 1.0 - exp(-3.0 * delta))

	var vitesse_chute := -velocity.y
	move_and_slide()
	if not en_l_air and not is_on_floor():
		# Godot n'aimante pas au sol un corps qui monte (vitesse vers le haut) : en côte, la
		# moindre bosse faisait décoller le bolide (petits sauts invisibles, voiture qui
		# « flotte », direction réduite). On l'aimante à la main ; sur un vrai tremplin ou
		# au bord d'un trou, il n'y a plus de route sous lui et il décolle quand même.
		apply_floor_snap()

	if en_l_air and is_on_floor() and vitesse_chute > 6.0:
		atterrissage.emit(vitesse_chute)

	_gerer_chocs(avant)


## Dans un virage relevé, la paroi pousse le bolide vers l'intérieur : il
## tourne tout seul. En vrai, pour une pente d'angle θ, on tourne de
## gravité × tan(θ) / vitesse radians par seconde. Trop vite pour le virage,
## on monte sur la paroi, plus raide, qui fait tourner plus fort ; trop
## lent, on redescend : on trouve tout seul la bonne hauteur.
func _tourner_avec_la_paroi(delta: float) -> void:
	if vitesse < 5.0 or _normale_sol.y < 0.1:
		return
	var droite := Vector3(cos(_cap_trajectoire), 0.0, -sin(_cap_trajectoire))
	var avant := Vector3(-sin(_cap_trajectoire), 0.0, -cos(_cap_trajectoire))
	var penche := _normale_sol.dot(droite)  # > 0 : le sol penche vers la droite
	var pente := penche / _normale_sol.y  # tan(θ)
	var rotation_paroi := -gravite * effet_paroi * pente / maxf(vitesse, 20.0)
	# Guidage : « en_biais » < 0 quand on monte sur la paroi, > 0 quand on
	# en descend. On tourne pour revenir le long de la paroi.
	var en_biais := _normale_sol.dot(avant)
	rotation_paroi += guidage_paroi * en_biais * signf(penche)
	# Seulement sur une vraie paroi (plus de 12° environ) : les routes
	# simplement penchées dans les virages (dévers) restent comme avant.
	rotation_paroi *= smoothstep(0.2, 0.35, absf(penche))
	rotation_paroi = clampf(rotation_paroi, -rotation_paroi_max, rotation_paroi_max)
	_cap_trajectoire += rotation_paroi * delta
	_cap += rotation_paroi * delta
	rotation.y = _cap


func _gerer_chocs(avant: Vector3) -> void:
	var touche := false
	var plus_de_face := 0.0
	# Au-delà de cette pente, ce n'est plus un sol (une paroi de half-pipe
	# reste un sol jusqu'à « floor_max_angle »). Un plafond ou le rebord
	# enroulé d'un half-pipe (normale vers le bas) compte comme un mur.
	var sol_min := cos(floor_max_angle) - 0.02
	var centre := global_position + Vector3.UP * 0.55  # le centre de la forme de collision
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normale := collision.get_normal()
		if normale.y > sol_min:
			continue  # c'est le sol, pas un obstacle
		if (collision.get_position() - centre).dot(_normale_sol) < -0.3:
			continue  # touché par-dessous : c'est encore le sol (vu de l'envers)
		touche = true
		var de_face := -avant.dot(normale)  # 1 = de face, 0 = on frotte
		plus_de_face = maxf(plus_de_face, de_face)
		if de_face > 0.1 and not _contact_mur:
			mur_touche.emit(vitesse * de_face)
			vitesse *= 1.0 - perte_choc * de_face
			# L'obstacle nous dévie : on repart le long de sa paroi.
			var le_long := avant - normale * avant.dot(normale)
			if le_long.length() > 0.1:
				_cap = atan2(-le_long.x, -le_long.z)
				_cap_trajectoire = _cap
				_glisse = 0.0
				_omega = 0.0
				_grip = 1.0
				en_derapage = false
		elif de_face > 0.02 and de_face < 0.5 and _contact_mur:
			# On frotte déjà le long du mur : le nez suit doucement la paroi,
			# comme contre un rail, sans perdre de vitesse.
			var le_long := avant - normale * avant.dot(normale)
			if le_long.length() > 0.1:
				var ecart := angle_difference(_cap_trajectoire, atan2(-le_long.x, -le_long.z)) * 0.5
				_cap_trajectoire += ecart
				_cap += ecart
	if touche and _contact_mur and plus_de_face > 0.3:
		# Toujours collé à l'obstacle : on ne peut pas aller plus vite que ce
		# qu'on avance vraiment (sinon le compteur s'affole contre un bloc).
		# Pas quand on glisse le long d'un mur : là, on garde sa vitesse.
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
	_grip = 1.0
	_glisse = 0.0
	_omega = 0.0
	_volant = 0.0
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
	# Les roues restent posées sur le sol, même très penché (paroi de
	# half-pipe) : la carrosserie se place le long de la normale du sol.
	var suspension := (sin(_temps * 37.0) * 0.004 + sin(_temps * 13.0) * 0.003) * allure
	_carrosserie.position = Vector3(0.0, 0.55, 0.0) + n.normalized() * (0.15 + suspension)
	_carrosserie.rotation.z = lerpf(_carrosserie.rotation.z, roulis_sol + virage * 0.07 * allure, lissage)
	# Nez qui se lève en boost ; avec l'effet « Redline », le bolide reste à plat en
	# s'étirant (sinon l'arrière, plus long, rentrerait dans la route).
	var leve_nez := (0.04 if en_boost else 0.0) * (1.0 - distorsion if etirement_boost > 0.0 else 1.0)
	_carrosserie.rotation.x = lerpf(_carrosserie.rotation.x, tangage_sol + leve_nez, lissage)

	# Effet « Redline » : la carrosserie s'étire vers l'arrière et s'affine, au rythme
	# de « distorsion » (qui suit la montée du boost). On la recule de la moitié de
	# l'allongement pour que le nez reste en place, et on la remonte d'autant qu'elle
	# s'aplatit pour que les roues restent sur la route (le modèle est 0,7 m sous le pivot).
	var etirement := etirement_boost * distorsion
	var affinement := 1.0 - affinement_boost * distorsion
	_carrosserie.scale = Vector3(affinement, affinement, 1.0 + etirement)
	_decalage_etirement = DEMI_LONGUEUR * etirement
	var remontee := HAUTEUR_PIVOT * (1.0 - affinement)
	_carrosserie.position += Basis.from_euler(_carrosserie.rotation) * Vector3(0.0, remontee, _decalage_etirement)

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
	_grip = 1.0
	_glisse = 0.0
	_omega = 0.0
	_volant = 0.0
	velocity = Vector3.ZERO
	vitesse = 0.0
	jauge_boost = jauge_max
	distorsion = 0.0
	montee_boost = 0.0
	_historique.clear()
	teleporte.emit(global_position - ancienne)
