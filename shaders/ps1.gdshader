// Matière « PlayStation 1 » : texture pixel art sans lissage, sommets qui « sautillent » sur une
// grille grossière (c'est ce qui donnait ce tremblement des modèles PS1) et éclairage simple.
//
// Le modèle (voir models/muscle_car_ps1.glb) ne contient pas de coordonnées UV. À la place, chaque
// triangle porte dans sa couleur de sommet :
//   rouge/vert/bleu = la nuance de la pièce (clair, sombre)
//   alpha           = le numéro de la case de l'atlas (0 à 7) : peinture, vitre, pneu, métal,
//                     garniture, phare, feu arrière, moteur.
// Le shader calcule lui-même la position dans la texture à partir de la position sur la voiture,
// ce qui garde des pixels de la même taille partout.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 teinte_peinture : source_color = vec4(1.0);  // couleur de la carrosserie (blanc = gris de la texture)
uniform float taille_tuile = 1.6;  // largeur en mètres d'une case de texture : plus petit = pixels plus fins
uniform float resolution_sommets = 140.0;  // grille des sommets (0 = désactivé). Plus bas = plus de tremblement
uniform float noir_et_blanc : hint_range(0.0, 1.0) = 0.0;

varying vec3 pos_objet;
varying vec3 normale_objet;
varying vec4 donnees;

void vertex() {
	pos_objet = VERTEX;
	normale_objet = NORMAL;
	donnees = COLOR;
	if (resolution_sommets > 0.0) {
		vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * resolution_sommets + 0.5) / resolution_sommets;
		POSITION = vec4(ndc * clip.w, clip.z, clip.w);
	}
}

void fragment() {
	vec3 n = abs(normale_objet);
	vec2 p;
	if (n.x >= n.y && n.x >= n.z) {
		p = pos_objet.zy;
	} else if (n.y >= n.z) {
		p = pos_objet.xz;
	} else {
		p = pos_objet.xy;
	}
	float numero = floor(donnees.a * 8.0);
	vec2 case_atlas = vec2(mod(numero, 4.0), floor(numero / 4.0));
	vec2 dans_la_case = fract(p / taille_tuile) * 0.96 + 0.02;
	vec2 uv = (case_atlas + dans_la_case) * vec2(0.25, 0.5);
	vec3 texel = texture(atlas, uv).rgb;
	vec3 teinte = numero < 0.5 ? teinte_peinture.rgb : vec3(1.0);
	vec3 base = texel * teinte * donnees.rgb * 1.4;
	float gris = dot(base, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(base, vec3(gris), noir_et_blanc);
	ROUGHNESS = 1.0;
}
