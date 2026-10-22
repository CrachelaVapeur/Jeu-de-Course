shader_type canvas_item;
// Vision en tunnel pendant le boost : le centre de l'écran reste net, les bords
// s'étirent vers le centre (flou radial), se décalent en couleurs (aberration
// chromatique) et s'assombrissent (vignette).
// « intensite » est envoyée par hud.gd (0 = aucun effet, 1 = plein effet).

uniform sampler2D ecran : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float intensite : hint_range(0.0, 1.0) = 0.0;
uniform float rayon_net : hint_range(0.0, 2.0) = 0.35;  // taille de la zone centrale bien nette
uniform float douceur : hint_range(0.1, 3.0) = 1.2;  // largeur de la transition net -> effets
uniform float flou_radial : hint_range(0.0, 0.5) = 0.12;  // longueur des traînées sur les bords
uniform float aberration : hint_range(0.0, 0.05) = 0.015;  // séparation des couleurs sur les bords
uniform float assombrissement : hint_range(0.0, 1.0) = 0.8;  // force de la vignette
uniform vec3 couleur_bord = vec3(0.03, 0.01, 0.05);

const int ECHANTILLONS = 12;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centre = vec2(0.5);
	float largeur_sur_hauteur = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	// Distance au centre : 1.0 en haut et en bas de l'écran, plus sur les côtés.
	float distance_centre = length((uv - centre) * vec2(largeur_sur_hauteur, 1.0)) * 2.0;

	// « effet » vaut 0 au centre et monte vers les bords.
	float effet = smoothstep(rayon_net, rayon_net + douceur, distance_centre) * intensite;
	float noir = smoothstep(rayon_net + 0.3, rayon_net + douceur + 1.0, distance_centre) * assombrissement * intensite;

	// Flou radial : chaque point est pris un peu plus près du centre, ce qui étire
	// l'image vers l'extérieur. Rouge et bleu sont pris à une échelle un peu
	// différente de celle du vert : c'est l'aberration chromatique.
	vec3 somme = vec3(0.0);
	for (int i = 0; i < ECHANTILLONS; i++) {
		float t = float(i) / float(ECHANTILLONS - 1);
		vec2 p = centre + (uv - centre) * (1.0 - t * flou_radial * effet);
		float lod = effet * 1.5;
		somme.r += textureLod(ecran, centre + (p - centre) * (1.0 + aberration * effet), lod).r;
		somme.g += textureLod(ecran, p, lod).g;
		somme.b += textureLod(ecran, centre + (p - centre) * (1.0 - aberration * effet), lod).b;
	}
	vec3 couleur = somme / float(ECHANTILLONS);

	// Vignette : les bords s'assombrissent.
	couleur = mix(couleur, couleur_bord, noir);
	COLOR = vec4(couleur, 1.0);
}
