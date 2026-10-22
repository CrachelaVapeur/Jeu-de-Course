// Le revêtement de la piste, entièrement dessiné par le calcul (pas de texture).
// Les marquages qui défilent sous le bolide sont un repère essentiel pour
// sentir la vitesse : dalles, pointillés, bordures à damier et néons.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 asphalte : source_color = vec4(0.26, 0.23, 0.27, 1.0);
uniform vec4 marquage : source_color = vec4(0.92, 0.9, 0.82, 1.0);
uniform vec4 bordure_a : source_color = vec4(0.95, 0.75, 0.15, 1.0);
uniform vec4 bordure_b : source_color = vec4(0.08, 0.07, 0.08, 1.0);
uniform vec4 neon : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float demi_largeur = 15.0;

varying vec3 position_monde;

float hasard(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = position_monde.x;
	float z = position_monde.z;
	float ax = abs(x);

	// Dalles de béton de 20 m. Le « mod 60 » fait se répéter le motif tous
	// les 1200 m, comme le reste du circuit.
	float dalle = mod(floor(z / 20.0), 60.0);
	vec3 c = asphalte.rgb + (hasard(dalle) - 0.5) * 0.05;
	c *= 1.0 - 0.5 * step(fract(z / 20.0), 0.015);

	// Pointillés : un trait de 6 m tous les 12 m, au centre et entre les voies.
	float voie = min(ax, abs(ax - demi_largeur * 0.5));
	float pointille = step(voie, 0.15) * step(fract(z / 12.0), 0.5);
	c = mix(c, marquage.rgb, pointille);

	// Bordures à damier jaune et noir, tous les 4 m.
	float bordure = step(demi_largeur - 1.2, ax);
	c = mix(c, mix(bordure_a.rgb, bordure_b.rgb, step(0.5, fract(z / 4.0))), bordure);

	// Liseré néon juste avant la bordure.
	float trait_neon = 1.0 - smoothstep(0.05, 0.15, abs(ax - (demi_largeur - 1.45)));

	ALBEDO = mix(c, neon.rgb, trait_neon);
	EMISSION = neon.rgb * trait_neon * 4.0;
	ROUGHNESS = 0.8;
}
