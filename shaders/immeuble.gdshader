// Les immeubles de nuit : une matière cartoon sombre, avec des fenêtres
// dessinées par le shader (pas besoin de modéliser chaque fenêtre). Seules
// quelques-unes sont allumées, pour garder des contrastes.
// Chaque immeuble reçoit, en plus de sa couleur, des réglages à lui
// (INSTANCE_CUSTOM) : r = part de fenêtres allumées, g = tirage au hasard,
// b = teinte des fenêtres (0 = chaud, 1 = froid).
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 couleur : source_color = vec4(1.0);
uniform vec4 fenetre_chaude : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform vec4 fenetre_froide : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float force_fenetres = 2.5;
uniform float hauteur_etage = 3.6;
uniform float largeur_fenetre = 3.2;
uniform float noir_et_blanc : hint_range(0.0, 1.0) = 0.0;

varying vec3 couleur_instance;
varying vec4 reglages;
varying vec3 position_monde;
varying vec3 normale_monde;

void vertex() {
	couleur_instance = COLOR.rgb;
	reglages = INSTANCE_CUSTOM;
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hasard(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec3 base = couleur.rgb * couleur_instance;
	vec3 lumiere = vec3(0.0);
	// Fenêtres seulement sur les murs (pas sur les toits).
	if (abs(normale_monde.y) < 0.5) {
		vec3 tangente = normalize(cross(vec3(0.0, 1.0, 0.0), normale_monde));
		vec2 p = vec2(dot(position_monde, tangente) / largeur_fenetre, position_monde.y / hauteur_etage);
		vec2 cellule = floor(p);
		vec2 dedans = fract(p);
		float vitre = step(0.18, dedans.x) * step(dedans.x, 0.82) * step(0.25, dedans.y) * step(dedans.y, 0.8);
		float tirage = hasard(vec3(cellule, reglages.g * 100.0) + normale_monde * 7.0);
		float allumee = step(tirage, reglages.r) * vitre;
		// Des étages entiers éteints, comme dans une vraie ville la nuit.
		allumee *= step(0.25, hasard(vec3(cellule.y, reglages.g * 50.0, 3.0)));
		vec3 teinte = mix(fenetre_chaude.rgb, fenetre_froide.rgb, reglages.b);
		teinte *= 0.6 + 0.4 * hasard(vec3(cellule, 9.0));
		base = mix(base, base * 0.55, vitre);  // vitres éteintes un peu plus sombres
		lumiere = teinte * allumee * force_fenetres;
	}
	float gris = dot(base, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(base, vec3(gris), noir_et_blanc);
	float gris_lumiere = dot(lumiere, vec3(0.299, 0.587, 0.114));
	EMISSION = mix(lumiere, vec3(gris_lumiere), noir_et_blanc);
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
