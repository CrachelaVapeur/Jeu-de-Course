# Vérification rapide du projet (Windows), à lancer avant chaque fusion dans main.
# Quick project check (Windows), to run before every merge into main.
#
#   $env:GODOT = "C:\chemin\vers\Godot_v4.7-stable_win64_console.exe"
#   powershell -ExecutionPolicy Bypass -File outils\verifier.ps1
#
# Utiliser la version « console » de Godot pour voir les messages.
# Use the "console" build of Godot so its messages are printed.

$Godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
Set-Location (Join-Path $PSScriptRoot "..")
$Scenes = @("scenes/main.tscn", "scenes/circuit_essai.tscn", "scenes/circuit_01.tscn")
$Echec = $false

function Erreurs($Sortie) {
	$Sortie | Where-Object { $_ -match "SCRIPT ERROR|^ERROR|ÉCHEC" }
}

Write-Host "== Import"
$Sortie = & $Godot --headless --import --path . 2>&1 | ForEach-Object { "$_" }
$Trouvees = Erreurs $Sortie
if ($Trouvees) { $Trouvees; $Echec = $true }

Write-Host "== Scripts et shaders / Scripts and shaders"
$Sortie = & $Godot --headless --path . --script res://outils/verifier_scripts.gd 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { Erreurs $Sortie; $Echec = $true }
$Sortie | Select-Object -Last 1

foreach ($Scene in $Scenes) {
	Write-Host "== $Scene"
	$Sortie = & $Godot --headless --path . "res://$Scene" --quit-after 120 2>&1 | ForEach-Object { "$_" }
	$Trouvees = Erreurs $Sortie
	if ($Trouvees) { $Trouvees; $Echec = $true } else { Write-Host "OK" }
}

if ($Echec) {
	Write-Host "ÉCHEC : corriger avant de fusionner. / FAILED: fix before merging."
	exit 1
}
Write-Host "Tout est bon. / All good."
