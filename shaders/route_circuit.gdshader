// Revêtement des vrais circuits. Même esprit que route.gdshader, mais les
// marquages suivent la route au lieu de suivre les axes du monde : le
// générateur de circuit range dans UV la position sur la route
// (UV.x = mètres depuis le centre, UV.y = mètres depuis le début de la route)
// et dans UV2.x la demi-largeur de la route à cet endroit (elle peut varier).
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform vec4 asphalte : source_color = vec4(0.26, 0.23, 0.27, 1.0);
uniform vec4 marquage : source_color = vec4(0.92, 0.9, 0.82, 1.0);
uniform vec4 bordure_a : source_color = vec4(0.95, 0.75, 0.15, 1.0);
uniform vec4 bordure_b : source_color = vec4(0.08, 0.07, 0.08, 1.0);
uniform vec4 neon : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float demi_largeur = 12.0; // utilisée seulement si UV2.x est vide
uniform float ligne_depart = 0.0; // distance de la ligne de départ
uniform float ligne_arrivee = -100.0; // distance de la ligne d'arrivée (négatif = pas d'arrivée à part)
uniform float longueur_damier = 4.0; // longueur du damier des lignes de départ et d'arrivée

float hasard(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float x = UV.x;
	float d = UV.y;
	float ax = abs(x);
	float demi = UV2.x > 0.0 ? UV2.x : demi_largeur;

	// Dalles de béton de 20 m.
	vec3 c = asphalte.rgb + (hasard(floor(d / 20.0)) - 0.5) * 0.05;
	c *= 1.0 - 0.5 * step(fract(d / 20.0), 0.015);

	// Pointillés : un trait de 6 m tous les 12 m, au centre et entre les voies.
	float voie = min(ax, abs(ax - demi * 0.5));
	float pointille = step(voie, 0.15) * step(fract(d / 12.0), 0.5);
	c = mix(c, marquage.rgb, pointille);

	// Bordures à damier jaune et noir, tous les 4 m.
	float bordure = step(demi - 1.2, ax);
	c = mix(c, mix(bordure_a.rgb, bordure_b.rgb, step(0.5, fract(d / 4.0))), bordure);

	// Lignes de départ et d'arrivée en damier noir et blanc.
	float damier = mod(floor(x / 1.0) + floor(d / 1.0), 2.0);
	float depart = step(ligne_depart, d) * step(d, ligne_depart + longueur_damier);
	depart = max(depart, step(ligne_arrivee, d) * step(d, ligne_arrivee + longueur_damier));
	c = mix(c, mix(vec3(0.05), vec3(0.95), damier), depart);

	// Liseré néon juste avant la bordure.
	float trait_neon = 1.0 - smoothstep(0.05, 0.15, abs(ax - (demi - 1.45)));

	ALBEDO = mix(c, neon.rgb, trait_neon);
	EMISSION = neon.rgb * trait_neon * 4.0;
	ROUGHNESS = 0.8;
}
