// Matière « voiture simple » : couleurs unies, sans texture ni effet PlayStation.
//
// Le modèle (models/muscle_car_ps1.glb) porte dans la couleur de chaque sommet :
//   rouge/vert/bleu = la nuance de la pièce (clair / sombre), ce qui donne du relief à la carrosserie
//   alpha           = la matière (0 à 7) : peinture, vitre, pneu, métal, garniture, phare, feu arrière, moteur.
// Chaque matière a sa couleur ci-dessous, réglable dans l'Inspecteur (la peinture surtout).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform vec4 peinture : source_color = vec4(0.95, 0.68, 0.03, 1.0);  // carrosserie
uniform vec4 vitre : source_color = vec4(0.10, 0.14, 0.2, 1.0);
uniform vec4 pneu : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform vec4 metal : source_color = vec4(0.62, 0.64, 0.68, 1.0);  // jantes, chrome, échappements
uniform vec4 garniture : source_color = vec4(0.09, 0.09, 0.1, 1.0);  // dessous, pare-chocs sombres
uniform vec4 phare : source_color = vec4(1.0, 0.95, 0.72, 1.0);
uniform vec4 feu_arriere : source_color = vec4(0.9, 0.08, 0.06, 1.0);
uniform vec4 moteur : source_color = vec4(0.36, 0.38, 0.43, 1.0);
uniform float lumiere_phares : hint_range(0.0, 3.0) = 0.8;
uniform float noir_et_blanc : hint_range(0.0, 1.0) = 0.0;  // utilisé par l'effet de boost

varying vec4 donnees;

void vertex() {
	donnees = COLOR;
}

void fragment() {
	int k = int(floor(donnees.a * 8.0));
	vec3 couleur = peinture.rgb;
	float eclat = 0.0;
	if (k == 1) { couleur = vitre.rgb; }
	else if (k == 2) { couleur = pneu.rgb; }
	else if (k == 3) { couleur = metal.rgb; }
	else if (k == 4) { couleur = garniture.rgb; }
	else if (k == 5) { couleur = phare.rgb; eclat = lumiere_phares; }
	else if (k == 6) { couleur = feu_arriere.rgb; eclat = lumiere_phares; }
	else if (k == 7) { couleur = moteur.rgb; }
	vec3 base = couleur * donnees.rgb * 1.1;
	float gris = dot(base, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(base, vec3(gris), noir_et_blanc);
	EMISSION = couleur * eclat * (1.0 - noir_et_blanc);
	ROUGHNESS = 1.0;
}
