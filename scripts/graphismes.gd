extends Node
## Réglages graphiques (autoload « Graphismes »), sauvegardés dans user://.
##
## Les réglages « Élevé » correspondent au rendu d'origine du jeu. « Bas » est
## prévu pour les petits PC portables (carte graphique intégrée).
## Ils s'appliquent à chaque scène qui démarre : on change donc les réglages
## depuis le menu, puis on lance une course.

const FICHIER := "user://reglages_graphiques.cfg"

## Échelle de rendu 3D proposée (le HUD reste net, seul le monde 3D est réduit).
const ECHELLES: Array[float] = [0.5, 0.67, 0.75, 1.0]

## Valeurs de chaque préréglage : bas, moyen, élevé.
const PREREGLAGES := [
	{"echelle": 0.5, "msaa": 0, "ombres": false, "glow": false, "contours": false, "effets": false},
	{"echelle": 0.75, "msaa": 0, "ombres": true, "glow": true, "contours": false, "effets": true},
	{"echelle": 1.0, "msaa": 1, "ombres": true, "glow": true, "contours": true, "effets": true},
]

var echelle := 1.0  ## échelle de rendu 3D (0.5 = moitié de la résolution)
var msaa := 1  ## 0 = aucun, 1 = 2x, 2 = 4x
var ombres := true
var glow := true  ## halo lumineux
var contours := true  ## traits sombres autour des objets (scène main)
var effets := true  ## lignes de vitesse et vision en tunnel
var afficher_fps := false

var _label_fps: Label


func _ready() -> void:
	charger()
	_creer_compteur_fps()
	get_tree().node_added.connect(_sur_noeud_ajoute)
	appliquer_viewport()


func _process(_delta: float) -> void:
	_label_fps.visible = afficher_fps
	if afficher_fps:
		_label_fps.text = "%d FPS" % Engine.get_frames_per_second()


func appliquer_prereglage(indice: int) -> void:
	var p: Dictionary = PREREGLAGES[indice]
	echelle = p["echelle"]
	msaa = p["msaa"]
	ombres = p["ombres"]
	glow = p["glow"]
	contours = p["contours"]
	effets = p["effets"]
	appliquer_viewport()
	sauvegarder()


## Renvoie l'indice du préréglage qui correspond aux réglages actuels, ou -1.
func prereglage_actuel() -> int:
	for i in PREREGLAGES.size():
		var p: Dictionary = PREREGLAGES[i]
		if (is_equal_approx(echelle, p["echelle"]) and msaa == p["msaa"] and ombres == p["ombres"]
				and glow == p["glow"] and contours == p["contours"] and effets == p["effets"]):
			return i
	return -1


func appliquer_viewport() -> void:
	var racine := get_tree().root
	racine.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if echelle >= 1.0 else Viewport.SCALING_3D_MODE_FSR
	racine.scaling_3d_scale = echelle
	racine.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][msaa]


func sauvegarder() -> void:
	var cfg := ConfigFile.new()
	for nom in ["echelle", "msaa", "ombres", "glow", "contours", "effets", "afficher_fps"]:
		cfg.set_value("graphismes", nom, get(nom))
	cfg.save(FICHIER)


func charger() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) != OK:
		return
	echelle = cfg.get_value("graphismes", "echelle", echelle)
	msaa = cfg.get_value("graphismes", "msaa", msaa)
	ombres = cfg.get_value("graphismes", "ombres", ombres)
	glow = cfg.get_value("graphismes", "glow", glow)
	contours = cfg.get_value("graphismes", "contours", contours)
	effets = cfg.get_value("graphismes", "effets", effets)
	afficher_fps = cfg.get_value("graphismes", "afficher_fps", afficher_fps)


## Appelé pour chaque nœud qui entre dans l'arbre : coupe les ombres, le halo
## et les contours des scènes selon les réglages.
func _sur_noeud_ajoute(noeud: Node) -> void:
	if noeud is Light3D and not ombres:
		(noeud as Light3D).shadow_enabled = false
	elif noeud is WorldEnvironment:
		var env := (noeud as WorldEnvironment).environment
		if env != null:
			# L'Environment est partagé entre les chargements : on retient sa valeur d'origine.
			if not env.has_meta("glow_origine"):
				env.set_meta("glow_origine", env.glow_enabled)
			env.glow_enabled = glow and env.get_meta("glow_origine")
	elif noeud.name == &"Contours" and noeud is MeshInstance3D:
		(noeud as MeshInstance3D).visible = contours


func _creer_compteur_fps() -> void:
	var couche := CanvasLayer.new()
	couche.layer = 100
	add_child(couche)
	_label_fps = Label.new()
	_label_fps.position = Vector2(12.0, 8.0)
	_label_fps.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_label_fps.add_theme_color_override("font_outline_color", Color.BLACK)
	_label_fps.add_theme_constant_override("outline_size", 6)
	couche.add_child(_label_fps)
