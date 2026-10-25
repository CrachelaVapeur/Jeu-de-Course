class_name DecorBase
extends Node3D
## Base commune des scripts qui construisent un décor (ligne droite d'essai,
## vrais circuits) : matières cartoon et ambiance « noir et blanc » en boost.
##
## Un script de décor écrit « extends DecorBase » et crée ses matières avec
## _matiere() : elles passent alors automatiquement en noir et blanc pendant
## le boost.

@export var vehicule: Vehicule  ## sert à passer le décor en noir et blanc pendant le boost
@export var environnement: WorldEnvironment  ## le ciel et la brume passent aussi en noir et blanc
@export var saturation_boost := 2.0  ## saturation de l'image en boost : seules la route et le bolide, encore en couleur, en profitent
@export var contraste_boost := 1.35  ## contraste de l'image en boost
@export var glow_boost := 1.4  ## force du halo lumineux en boost
@export var bloom_boost := 0.2  ## voile lumineux doux sur toute l'image en boost

const SHADER_TOON := preload("res://shaders/toon.gdshader")

var _matieres_decor: Array[ShaderMaterial] = []
var _noir_et_blanc := 0.0
var _couleurs_ciel: Array[Color] = []
var _couleur_brume := Color.WHITE
var _saturation_normale := 1.0
var _contraste_normal := 1.0
var _glow_normal := 0.9
var _bloom_normal := 0.05


func _ready() -> void:
	_memoriser_ciel()


func _process(_delta: float) -> void:
	if vehicule == null or is_equal_approx(vehicule.distorsion, _noir_et_blanc):
		return
	_noir_et_blanc = vehicule.distorsion
	_appliquer_effets_boost(_noir_et_blanc)


# --- Effets d'ambiance en boost ---------------------------------------------
# Noir et blanc : la route et le bolide gardent leurs couleurs, seuls le décor,
# le ciel et la brume (qui teinte les bâtiments lointains) perdent les leurs.
# Contraste, saturation et halo lumineux montent en même temps.

func _memoriser_ciel() -> void:
	if environnement == null:
		return
	var env := environnement.environment
	var ciel := env.sky.sky_material as ProceduralSkyMaterial
	_couleurs_ciel.assign([
		ciel.sky_top_color, ciel.sky_horizon_color,
		ciel.ground_bottom_color, ciel.ground_horizon_color,
	])
	_couleur_brume = env.fog_light_color
	_saturation_normale = env.adjustment_saturation
	_contraste_normal = env.adjustment_contrast
	_glow_normal = env.glow_intensity
	_bloom_normal = env.glow_bloom


func _appliquer_effets_boost(valeur: float) -> void:
	for m in _matieres_decor:
		m.set_shader_parameter("noir_et_blanc", valeur)
	if environnement == null or _couleurs_ciel.is_empty():
		return
	var env := environnement.environment
	var ciel := env.sky.sky_material as ProceduralSkyMaterial
	ciel.sky_top_color = _vers_gris(_couleurs_ciel[0], valeur)
	ciel.sky_horizon_color = _vers_gris(_couleurs_ciel[1], valeur)
	ciel.ground_bottom_color = _vers_gris(_couleurs_ciel[2], valeur)
	ciel.ground_horizon_color = _vers_gris(_couleurs_ciel[3], valeur)
	env.fog_light_color = _vers_gris(_couleur_brume, valeur)
	# Le gris ne change pas quand on monte la saturation : seules les couleurs restantes ressortent.
	env.adjustment_saturation = lerpf(_saturation_normale, saturation_boost, valeur)
	env.adjustment_contrast = lerpf(_contraste_normal, contraste_boost, valeur)
	# Halo doux : les néons et les lumières bavent, ce qui donne un côté rêveur.
	env.glow_intensity = lerpf(_glow_normal, glow_boost, valeur)
	env.glow_bloom = lerpf(_bloom_normal, bloom_boost, valeur)


func _vers_gris(couleur: Color, valeur: float) -> Color:
	var gris := couleur.get_luminance()
	return couleur.lerp(Color(gris, gris, gris, couleur.a), valeur)


# --- Outils -----------------------------------------------------------------

func _matiere(couleur: Color, force_emission := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_TOON
	m.set_shader_parameter("couleur", couleur)
	m.set_shader_parameter("force_emission", force_emission)
	_matieres_decor.append(m)
	return m


func _ajouter_mesh(mesh: Mesh, position_mesh: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_mesh
	add_child(instance)
