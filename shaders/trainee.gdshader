shader_type spatial;
// Traînée de lumière des réacteurs (voir trainee_lumiere.gd) : sans éclairage,
// ajoutée à l'image (la lumière s'additionne), et plus lumineuse que le blanc
// pour que le halo de l'environnement la fasse « briller ».
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float eclat = 3.0;

varying vec4 couleur_sommet;

void vertex() {
	couleur_sommet = COLOR;
}

void fragment() {
	ALBEDO = couleur_sommet.rgb * eclat;
	ALPHA = couleur_sommet.a;
}
