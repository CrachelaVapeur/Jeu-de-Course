// Faisceau de lumière (phare, projecteurs de la pyramide) : un cône
// transparent qui s'ajoute à l'image et s'efface vers son bout et sur ses bords.
// Sur le côté d'un CylinderMesh, UV.y vaut 0 en haut (la source) et 0,5 en bas (le bout large).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 couleur : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float force = 0.5;
uniform float noir_et_blanc : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Plus fort près de la source, et quand on regarde le cône de côté.
	float le_long = pow(clamp(1.0 - UV.y * 2.0, 0.0, 1.0), 2.0);
	float bords = pow(abs(dot(NORMAL, VIEW)), 1.5);
	vec3 c = couleur.rgb;
	c = mix(c, vec3(dot(c, vec3(0.299, 0.587, 0.114))), noir_et_blanc);
	ALBEDO = c * force * le_long * bords;
}
