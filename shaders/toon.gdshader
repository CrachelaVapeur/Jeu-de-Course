// Matière « cartoon » utilisée par presque tous les objets.
// L'éclairage est découpé en aplats (diffuse_toon) au lieu d'un dégradé doux,
// ce qui donne le côté dessin animé. Les contours noirs sont ajoutés à part,
// par contours.gdshader.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 couleur : source_color = vec4(1.0);
// Au-dessus de 0, l'objet brille (néons, réacteurs). Avec le « glow » de
// l'environnement, une valeur de 3 à 6 donne un joli halo.
uniform float force_emission = 0.0;
uniform float rugosite : hint_range(0.0, 1.0) = 0.85;

// Couleur propre à chaque instance (bâtiments générés en masse, etc.).
varying vec3 couleur_instance;

void vertex() {
	couleur_instance = COLOR.rgb;
}

void fragment() {
	vec3 base = couleur.rgb * couleur_instance;
	ALBEDO = base;
	ROUGHNESS = rugosite;
	SPECULAR = 0.3;
	EMISSION = base * force_emission;
	RIM = 0.35;
	RIM_TINT = 0.6;
}
