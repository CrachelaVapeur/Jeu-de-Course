// Revêtement des vrais circuits. Même esprit que route.gdshader, mais les
// marquages suivent la route au lieu de suivre les axes du monde : le
// générateur de circuit range dans UV la position sur la route
// (UV.x = mètres depuis le centre, UV.y = mètres depuis le début de la route)
// et dans UV2.x la demi-largeur de la route à cet endroit (elle peut varier).
// UV2.y = 1 : c'est le sol du cratère (roche noire fendue de lave).
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
uniform vec4 roche : source_color = vec4(0.12, 0.07, 0.07, 1.0);
uniform vec4 lave : source_color = vec4(1.0, 0.25, 0.05, 1.0);

float hasard(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// Distance au bord de la cellule la plus proche (motif de dalles fendues).
float fissures(vec2 p) {
	vec2 cellule = floor(p);
	float d1 = 10.0;
	float d2 = 10.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 voisine = cellule + vec2(float(i), float(j));
			vec2 centre = voisine + vec2(hasard(voisine.x * 7.0 + voisine.y * 131.0), hasard(voisine.x * 17.0 - voisine.y * 59.0));
			float d = length(p - centre);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void sol_cratere(vec2 uv, out vec3 albedo, out vec3 emission) {
	vec2 p = uv / 9.0;
	float fente = 1.0 - smoothstep(0.02, 0.09, fissures(p));
	// La lave ne brille pas partout : par plaques.
	float plaques = smoothstep(0.35, 0.8, hasard(floor(uv.y / 40.0) * 3.0 + floor(uv.x / 30.0)));
	vec3 c = roche.rgb * (0.8 + 0.4 * hasard(floor(p.x) * 13.0 + floor(p.y) * 7.0));
	albedo = mix(c, lave.rgb * 0.5, fente);
	emission = lave.rgb * fente * (0.6 + 2.5 * plaques);
}

void route(vec2 uv, float demi, out vec3 albedo, out vec3 emission) {
	float x = uv.x;
	float d = uv.y;
	float ax = abs(x);

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

	albedo = mix(c, neon.rgb, trait_neon);
	emission = neon.rgb * trait_neon * 4.0;
}

void fragment() {
	vec3 albedo;
	vec3 emission;
	if (UV2.y > 0.5) {
		sol_cratere(UV, albedo, emission);
		ROUGHNESS = 0.9;
	} else {
		route(UV, UV2.x > 0.0 ? UV2.x : demi_largeur, albedo, emission);
		ROUGHNESS = 0.8;
	}
	ALBEDO = albedo;
	EMISSION = emission;
}
