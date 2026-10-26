// Halo lumineux qui fait toujours face à la caméra (aura de la pyramide,
// lanterne du phare). Un simple carré dont le centre brille.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 couleur : source_color = vec4(1.0, 0.6, 0.3, 1.0);
uniform float force = 0.6;
uniform float noir_et_blanc : hint_range(0.0, 1.0) = 0.0;

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
	ALBEDO = c * force * lueur;
}
