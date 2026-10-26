extends RefCounted
## Circuit d'essai : il sert à tester le générateur en attendant le vrai
## croquis du premier circuit. Une boucle d'environ 2,7 km avec une colline,
## des virages relevés, des blocs, un tremplin au-dessus d'un trou et un
## passage sans muret.
##
## Comment lire ce fichier (le même format servira pour tous les circuits) :
## - POINTS : les points de passage vus de dessus, dans l'ordre de la course.
##   [x, z, hauteur] en mètres. x va vers la droite de la carte, z vers le bas
##   de la carte : le départ part vers le haut. Un 4e nombre, facultatif,
##   donne le dévers en degrés (positif = la route penche vers la droite,
##   pratique dans un virage à droite ; négatif = vers la gauche).
## - OBSTACLES : chacun est placé par sa distance depuis la ligne de départ
##   (« a », en mètres). La longueur totale du circuit s'affiche dans la
##   console au lancement, avec la distance de chaque point de passage.
##   Types possibles :
##   - « bloc » : décalage latéral (négatif = à gauche) et taille [largeur, hauteur, profondeur] ;
##   - « tremplin » : longueur et hauteur, sur toute la largeur de la route ;
##   - « trou » : longueur ; pas de route ni de muret, on tombe ;
##   - « sans_muret » : longueur et côté (« gauche », « droite » ou « deux »).

const NOM := "Circuit d'essai"
const BOUCLE := true
const TOURS := 3
const LARGEUR := 24.0
const HAUTEUR_SOL := -25.0  ## le sol du décor, sous la route : y arriver = chute

const POINTS := [
	[0, 0, 0],
	[0, -300, 0],
	[0, -550, 14],  # montée vers une butte
	[40, -760, 14],
	[200, -860, 6, 12],  # grand virage à droite, relevé
	[380, -760, 0, 10],
	[450, -500, 0],
	[450, -200, -4],  # légère descente
	[390, 60, -4, 8],
	[210, 160, 0, 12],
	[60, 110, 0, 6],
]

const OBSTACLES := [
	{"type": "bloc", "a": 180, "decalage": -5, "taille": [4, 3, 4]},
	{"type": "bloc", "a": 230, "decalage": 5, "taille": [4, 3, 4]},
	{"type": "bloc", "a": 280, "decalage": 0, "taille": [6, 2, 3]},
	{"type": "tremplin", "a": 1330, "longueur": 30, "hauteur": 4},
	{"type": "trou", "a": 1360, "longueur": 35},
	{"type": "sans_muret", "a": 1700, "longueur": 300, "cote": "droite"},
]
