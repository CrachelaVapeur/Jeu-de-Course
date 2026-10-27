// Revêtement des vrais circuits. Même esprit que route.gdshader, mais les
// marquages suivent la route au lieu de suivre les axes du monde : le
// générateur de circuit range dans UV la position sur la route
// (UV.x = mètres depuis le centre, UV.y = mètres depuis le début de la route)
// et dans UV2.x la demi-largeur de la route à cet endroit (elle peut varier).
// UV2.y = 1 : c'est le sol du cratère (de la terre tassée, avec des traces).
// UV2.y = 2 : les pointillés sont lumineux, et des vagues de lumière y courent.
// La couleur des sommets (COLOR) donne la teinte des lumières de la zone.
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform vec4 asphalte : source_color = vec4(0.26, 0.23, 0.27, 1.0);
uniform vec4 marquage : source_color = vec4(0.92, 0.9, 0.82, 1.0);
uniform vec4 bordure : source_color = vec4(0.36, 0.34, 0.37, 1.0);
uniform float force_neon = 1.2; // éclat du liseré lumineux au bord de la route
uniform float demi_largeur = 12.0; // utilisée seulement si UV2.x est vide
uniform float ligne_depart = 0.0; // distance de la ligne de départ
uniform float ligne_arrivee = -100.0; // distance de la ligne d'arrivée (négatif = pas d'arrivée à part)
uniform float longueur_damier = 4.0; // longueur du damier des lignes de départ et d'arrivée
uniform float vitesse_vagues = 140.0; // vitesse des vagues de lumière, en m/s
uniform vec4 terre : source_color = vec4(0.30, 0.22, 0.17, 1.0);
uniform vec4 terre_claire : source_color = vec4(0.42, 0.33, 0.25, 1.0);

float hasard(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// Un bruit doux (valeurs au hasard sur une grille, lissées entre elles).
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hasard(i.x * 7.0 + i.y * 157.0);
	float b = hasard(i.x * 7.0 + 7.0 + i.y * 157.0);
	float c = hasard(i.x * 7.0 + (i.y + 1.0) * 157.0);
	float d = hasard(i.x * 7.0 + 7.0 + (i.y + 1.0) * 157.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Le sol du cratère : de la terre tassée, avec des plaques plus claires et
// des traces de pneus qui suivent la route.
void sol_cratere(vec2 uv, out vec3 albedo, out vec3 emission) {
	float taches = bruit(uv / 25.0) * 0.6 + bruit(uv / 6.0) * 0.4;
	vec3 c = mix(terre.rgb, terre_claire.rgb, smoothstep(0.35, 0.75, taches));
	float traces = 0.0;
	for (int k = 0; k < 4; k++) {
		float centre = (hasard(float(k) * 3.1) - 0.5) * 60.0 + sin(uv.y / (90.0 + float(k) * 23.0) + float(k)) * 25.0;
		traces += 1.0 - smoothstep(0.4, 1.2, abs(abs(uv.x - centre) - 1.1));
	}
	c *= 1.0 - 0.18 * clamp(traces, 0.0, 1.0);
	albedo = c;
	emission = vec3(0.0);
}

void route(vec2 uv, float demi, bool lumineuse, float temps, vec3 teinte, out vec3 albedo, out vec3 emission) {
	float x = uv.x;
	float d = uv.y;
	float ax = abs(x);

	// Dalles de béton de 20 m.
	vec3 c = asphalte.rgb + (hasard(floor(d / 20.0)) - 0.5) * 0.05;
	c *= 1.0 - 0.5 * step(fract(d / 20.0), 0.015);

	// Une seule ligne de pointillés, au centre : un trait de 6 m tous les 12 m.
	float pointille = (1.0 - smoothstep(0.18, 0.28, ax)) * step(fract(d / 12.0), 0.5);
	c = mix(c, marquage.rgb, pointille);

	// Une bande de béton plus clair le long des bords.
	c = mix(c, bordure.rgb, step(demi - 1.2, ax));

	// Lignes de départ et d'arrivée en damier noir et blanc.
	float damier = mod(floor(x / 1.0) + floor(d / 1.0), 2.0);
	float depart = step(ligne_depart, d) * step(d, ligne_depart + longueur_damier);
	depart = max(depart, step(ligne_arrivee, d) * step(d, ligne_arrivee + longueur_damier));
	c = mix(c, mix(vec3(0.05), vec3(0.95), damier), depart);

	// Liseré néon juste avant la bordure.
	float trait_neon = 1.0 - smoothstep(0.05, 0.15, abs(ax - (demi - 1.45)));

	albedo = mix(c, teinte, trait_neon);
	emission = teinte * trait_neon * force_neon;
	if (lumineuse) {
		// Les pointillés brillent, et une vague plus forte court vers l'avant.
		float vague = pow(0.5 + 0.5 * sin((d - temps * vitesse_vagues) * 0.035), 8.0);
		albedo = mix(albedo, teinte, pointille);
		emission += teinte * pointille * (0.8 + 2.5 * vague);
	}
}

void fragment() {
	vec3 albedo;
	vec3 emission;
	if (UV2.y > 0.5 && UV2.y < 1.5) {
		sol_cratere(UV, albedo, emission);
		ROUGHNESS = 0.9;
	} else {
		vec3 teinte = COLOR.a > 0.0 ? COLOR.rgb : vec3(0.2, 0.7, 1.0);
		route(UV, UV2.x > 0.0 ? UV2.x : demi_largeur, UV2.y > 1.5, TIME, teinte, albedo, emission);
		ROUGHNESS = 0.8;
	}
	ALBEDO = albedo;
	EMISSION = emission;
}
