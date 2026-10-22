// Lignes de vitesse façon anime, dessinées par-dessus l'image.
// Le cercle est découpé en fines « parts de gâteau » ; à chaque instant on en
// allume quelques-unes au hasard, uniquement vers les bords de l'écran.
shader_type canvas_item;

uniform float intensite : hint_range(0.0, 1.0) = 0.0;
uniform float nombre_lignes = 140.0;
uniform vec4 couleur : source_color = vec4(1.0, 0.97, 0.9, 0.85);

float hasard(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 centre = UV - 0.5;
	centre.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x; // corrige le format 16/9
	float rayon = length(centre);
	float tour = atan(centre.y, centre.x) / 6.28318 + 0.5;

	float part = floor(tour * nombre_lignes);
	float image = floor(TIME * 24.0); // change 24 fois par seconde, comme un dessin animé
	float allumee = step(1.0 - intensite * 0.45, hasard(part + image * 17.0));

	float position_dans_part = fract(tour * nombre_lignes);
	float finesse = 1.0 - smoothstep(0.0, 0.2, abs(position_dans_part - 0.5));
	float debut = 0.22 + hasard(part * 3.7 + image) * 0.2;
	float vers_bord = smoothstep(debut, debut + 0.25, rayon);

	float ligne = allumee * finesse * vers_bord * intensite;
	float vignette = smoothstep(0.35, 0.95, rayon) * intensite * 0.55;

	COLOR = vec4(couleur.rgb * step(vignette, ligne), max(ligne * couleur.a, vignette));
}
