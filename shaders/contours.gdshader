// Contours noirs façon bande dessinée (style Borderlands), sur toute l'image.
//
// Ce shader est posé sur un rectangle collé devant la caméra. Pour chaque
// pixel, il regarde la profondeur et l'orientation des surfaces autour de lui :
// là où ça change brusquement (bord d'un objet, arête d'une boîte), il dessine
// un trait sombre. Aucun travail à faire objet par objet.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform sampler2D tex_profondeur : hint_depth_texture, filter_nearest;
uniform sampler2D tex_normales : hint_normal_roughness_texture, filter_nearest;

uniform vec4 couleur : source_color = vec4(0.04, 0.02, 0.05, 1.0);
uniform float epaisseur = 1.5; // en pixels
uniform float seuil_profondeur = 0.12;
uniform float seuil_normales = 0.6;
uniform float distance_fondu = 400.0; // au-delà, les traits s'effacent dans le brouillard

void vertex() {
	// Le rectangle couvre tout l'écran, quelle que soit la caméra.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float profondeur(vec2 uv, mat4 inv_projection) {
	float d = texture(tex_profondeur, uv).r;
	if (d < 0.000001) {
		return 100000.0; // le ciel : « infiniment » loin
	}
	vec4 vue = inv_projection * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -vue.z / vue.w;
}

vec3 normale(vec2 uv) {
	return texture(tex_normales, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = epaisseur / VIEWPORT_SIZE;
	vec2 g = SCREEN_UV - vec2(px.x, 0.0);
	vec2 d = SCREEN_UV + vec2(px.x, 0.0);
	vec2 h = SCREEN_UV - vec2(0.0, px.y);
	vec2 b = SCREEN_UV + vec2(0.0, px.y);

	float c = profondeur(SCREEN_UV, INV_PROJECTION_MATRIX);
	// Sur une surface plane, l'inverse de la profondeur varie de façon
	// régulière à l'écran : on ne détecte donc que les vraies ruptures, pas
	// la route qui s'éloigne.
	float rupture = abs(c / profondeur(g, INV_PROJECTION_MATRIX) + c / profondeur(d, INV_PROJECTION_MATRIX) - 2.0)
		+ abs(c / profondeur(h, INV_PROJECTION_MATRIX) + c / profondeur(b, INV_PROJECTION_MATRIX) - 2.0);
	float trait = step(seuil_profondeur, rupture);

	vec3 n = normale(SCREEN_UV);
	float pli = (1.0 - dot(n, normale(d))) + (1.0 - dot(n, normale(b)));
	trait = max(trait, step(seuil_normales, pli));

	trait *= 1.0 - smoothstep(distance_fondu * 0.4, distance_fondu, c);

	ALBEDO = couleur.rgb;
	ALPHA = trait * couleur.a;
}
