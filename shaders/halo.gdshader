// Halo lumineux qui fait toujours face à la caméra (aura de la pyramide,
// lanterne du phare). Un simple carré dont le centre brille.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 couleur : source_color = vec4(1.0, 0.6, 0.3, 1.0);
uniform float force = 0.6;
uniform float noir_et_blanc : hint_range(0.0, 1.0) = 0.0;
// Le brouillard normal dessine des rectangles sur ces objets transparents :
// on l'imite ici, en effaçant la lumière avec la distance.
uniform float brume = 0.0012;
// Sur cette distance (en mètres), le halo s'efface quand il s'approche d'un
// objet (sol, immeuble) : on ne voit pas de coupure nette là où il le traverse.
uniform float fondu = 0.0;
uniform sampler2D profondeur : hint_depth_texture, filter_nearest;

void vertex() {
	// Le carré tourne pour faire face à la caméra.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float lueur = pow(clamp(1.0 - r, 0.0, 1.0), 2.5);
	vec3 c = couleur.rgb;
	c = mix(c, vec3(dot(c, vec3(0.299, 0.587, 0.114))), noir_et_blanc);
	float pres_d_un_objet = 1.0;
	if (fondu > 0.0) {
		float z = texture(profondeur, SCREEN_UV).r;
		vec4 derriere = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
		pres_d_un_objet = clamp((VERTEX.z - derriere.z / derriere.w) / fondu, 0.0, 1.0);
	}
	ALBEDO = c * force * lueur * pres_d_un_objet * exp(-length(VERTEX) * brume);
}
