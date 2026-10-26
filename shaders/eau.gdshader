// La mer de nuit : sombre, avec des reflets de lune qui bougent un peu et de
// fines rides claires, dessinées comme dans un dessin animé.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 couleur : source_color = vec4(0.04, 0.06, 0.12, 1.0);
uniform vec4 couleur_rides : source_color = vec4(0.35, 0.45, 0.7, 1.0);
uniform float noir_et_blanc : hint_range(0.0, 1.0) = 0.0;

varying vec3 position_monde;

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hasard(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Petites rides : des traits courts posés au hasard sur une grille qui dérive.
	vec2 p = position_monde.xz / vec2(14.0, 4.0) + vec2(TIME * 0.15, 0.0);
	vec2 cellule = floor(p);
	vec2 dedans = fract(p);
	float trait = step(0.82, hasard(cellule)) * step(abs(dedans.y - 0.5), 0.06) * step(0.2, dedans.x) * step(dedans.x, 0.8);
	vec3 c = mix(couleur.rgb, couleur_rides.rgb, trait * 0.6);
	float gris = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(c, vec3(gris), noir_et_blanc);
	ROUGHNESS = 0.2;
	SPECULAR = 0.8;
	// La surface ondule un peu pour faire danser les reflets.
	vec3 houle = vec3(sin(position_monde.x * 0.05 + TIME), 0.0, cos(position_monde.z * 0.07 + TIME * 0.8)) * 0.05;
	NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * houle);
}
