// Revêtement des vrais circuits. Même esprit que route.gdshader, mais les
// marquages suivent la route au lieu de suivre les axes du monde : le
// générateur de circuit range dans UV la position sur la route
// (UV.x = mètres depuis le centre, UV.y = mètres depuis la ligne de départ).
shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

uniform vec4 asphalte : source_color = vec4(0.26, 0.23, 0.27, 1.0);
uniform vec4 marquage : source_color = vec4(0.92, 0.9, 0.82, 1.0);
uniform vec4 bordure_a : source_color = vec4(0.95, 0.75, 0.15, 1.0);
uniform vec4 bordure_b : source_color = vec4(0.08, 0.07, 0.08, 1.0);
uniform vec4 neon : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float demi_largeur = 12.0;
uniform float longueur_depart = 4.0; // longueur du damier de la ligne de départ

float hasard(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float x = UV.x;
	float d = UV.y;
	float ax = abs(x);

	// Dalles de béton de 20 m.
	vec3 c = asphalte.rgb + (hasard(floor(d / 20.0)) - 0.5) * 0.05;
	c *= 1.0 - 0.5 * step(fract(d / 20.0), 0.015);

	// Pointillés : un trait de 6 m tous les 12 m, au centre et entre les voies.
	float voie = min(ax, abs(ax - demi_largeur * 0.5));
	float pointille = step(voie, 0.15) * step(fract(d / 12.0), 0.5);
	c = mix(c, marquage.rgb, pointille);

	// Bordures à damier jaune et noir, tous les 4 m.
	float bordure = step(demi_largeur - 1.2, ax);
	c = mix(c, mix(bordure_a.rgb, bordure_b.rgb, step(0.5, fract(d / 4.0))), bordure);

	// Ligne de départ en damier noir et blanc.
	float damier = mod(floor(x / 1.0) + floor(d / 1.0), 2.0);
	float depart = step(0.0, d) * step(d, longueur_depart);
	c = mix(c, mix(vec3(0.05), vec3(0.95), damier), depart);

	// Liseré néon juste avant la bordure.
	float trait_neon = 1.0 - smoothstep(0.05, 0.15, abs(ax - (demi_largeur - 1.45)));

	ALBEDO = mix(c, neon.rgb, trait_neon);
	EMISSION = neon.rgb * trait_neon * 4.0;
	ROUGHNESS = 0.8;
}
