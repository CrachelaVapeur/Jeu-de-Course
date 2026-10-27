// Les immeubles de nuit : une matière cartoon sombre, avec des étages
// éclairés dessinés par le shader en lignes horizontales (pas besoin de
// modéliser les fenêtres). Seuls quelques morceaux d'étages sont allumés,
// pour garder des contrastes. De loin, les lignes se fondent en une lueur
// douce au lieu de scintiller.
// Chaque immeuble reçoit, en plus de sa couleur, des réglages à lui
// (INSTANCE_CUSTOM) : r = part de fenêtres allumées, g = tirage au hasard,
// b = teinte des fenêtres (0 = chaud, 1 = froid).
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 couleur : source_color = vec4(1.0);
uniform vec4 fenetre_chaude : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform vec4 fenetre_froide : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform float force_fenetres = 1.2;
uniform float hauteur_etage = 3.6;
uniform float largeur_fenetre = 14.0; // longueur d'un morceau de ligne allumé ou éteint
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
		// Une ligne claire au milieu de chaque étage, adoucie sur ses bords.
		float flou = max(fwidth(p.y), 0.001);
		float y = fract(p.y);
		float ligne = smoothstep(0.4 - flou, 0.4 + flou, y) * (1.0 - smoothstep(0.62 - flou, 0.62 + flou, y));
		float tirage = hasard(vec3(cellule, reglages.g * 100.0) + normale_monde * 7.0);
		float allumee = step(tirage, reglages.r);
		// De loin (plusieurs étages dans un pixel), on prend la moyenne : pas de scintillement.
		float loin = smoothstep(0.2, 0.6, flou);
		ligne = mix(ligne, 0.22, loin);
		allumee = mix(allumee, reglages.r, loin);
		vec3 teinte = mix(fenetre_chaude.rgb, fenetre_froide.rgb, reglages.b);
		teinte *= 0.7 + 0.3 * hasard(vec3(cellule, 9.0));
		lumiere = teinte * ligne * allumee * force_fenetres;
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
