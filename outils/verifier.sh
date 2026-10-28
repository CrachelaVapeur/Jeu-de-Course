#!/usr/bin/env bash
# Vérification rapide du projet, à lancer avant chaque fusion dans main.
# Quick project check, to run before every merge into main.
#
#   GODOT=/chemin/vers/godot outils/verifier.sh
#
# 1. importe le projet ; 2. compile tous les scripts et shaders ;
# 3. lance chaque scène jouable quelques secondes sans fenêtre.
# Renvoie 0 si tout va bien, 1 sinon. / Exits 0 when everything passes.

set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
SCENES="scenes/main.tscn scenes/circuit_essai.tscn scenes/circuit_01.tscn"
journal="$(mktemp)"
echec=0

echo "== Import"
"$GODOT" --headless --import --path . >"$journal" 2>&1
if grep -E "SCRIPT ERROR|^ERROR" "$journal"; then echec=1; fi

echo "== Scripts et shaders / Scripts and shaders"
if ! "$GODOT" --headless --path . --script res://outils/verifier_scripts.gd >"$journal" 2>&1; then
	grep -E "ÉCHEC|SCRIPT ERROR|ERROR" "$journal"
	echec=1
fi
tail -n 1 "$journal"

for scene in $SCENES; do
	echo "== $scene"
	"$GODOT" --headless --path . "res://$scene" --quit-after 120 >"$journal" 2>&1
	if grep -E "SCRIPT ERROR|^ERROR" "$journal"; then echec=1; else echo "OK"; fi
done

rm -f "$journal"
if [ "$echec" -ne 0 ]; then
	echo "ÉCHEC : corriger avant de fusionner. / FAILED: fix before merging."
	exit 1
fi
echo "Tout est bon. / All good."
