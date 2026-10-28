extends SceneTree
## Charge chaque script et chaque shader du projet, et signale ceux qui ne
## compilent pas. Lancé par outils/verifier.sh (ou .ps1) :
##   godot --headless --path . --script res://outils/verifier_scripts.gd
## Loads every script and shader in the project and reports the ones that
## fail to compile.

const DOSSIERS_IGNORES := ["res://.godot", "res://outils"]


func _init() -> void:
	var erreurs := 0
	var nombre := 0
	for chemin in _fichiers("res://"):
		if chemin.ends_with(".gd"):
			nombre += 1
			var script := load(chemin) as GDScript
			if script == null or not script.can_instantiate():
				printerr("ÉCHEC / FAILED : ", chemin)
				erreurs += 1
		elif chemin.ends_with(".gdshader"):
			nombre += 1
			if load(chemin) == null:
				printerr("ÉCHEC / FAILED : ", chemin)
				erreurs += 1
	print("%d fichiers vérifiés, %d en erreur / %d files checked, %d failed" % [nombre, erreurs, nombre, erreurs])
	quit(1 if erreurs > 0 else 0)


func _fichiers(dossier: String) -> Array[String]:
	var trouves: Array[String] = []
	for nom in DirAccess.get_files_at(dossier):
		trouves.append(dossier.path_join(nom))
	for sous in DirAccess.get_directories_at(dossier):
		var chemin := dossier.path_join(sous)
		if chemin not in DOSSIERS_IGNORES and not sous.begins_with("."):
			trouves.append_array(_fichiers(chemin))
	return trouves
