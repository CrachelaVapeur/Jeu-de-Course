# Jeu de Course

Jeu de course SF d'Eric et Willy : un univers original, déjanté, stylisé et un peu grunge, dans l'esprit de *Redline*, du Motorball d'*Alita* et de *Borderlands*. L'ossature s'inspire de *Star Wars: Galactic Racer*.

Le document de conception (GDD) et les comptes rendus de session sont dans le dossier Google Drive « Projet jeu Eric & Willy ».

## Lancer le prototype

1. Ouvrir **Godot 4.7** et cliquer sur **Importer**.
2. Choisir le fichier `project.godot` de ce dossier.
3. Appuyer sur **F5** (ou sur le bouton ▶ en haut à droite).

## Commandes

| Action       | Clavier (AZERTY)    | Manette          |
|--------------|---------------------|------------------|
| Accélérer    | Z ou ↑              | Gâchette droite  |
| Freiner      | S ou ↓              | Gâchette gauche  |
| Tourner      | Q / D ou ← / →      | Stick gauche     |
| Boost        | Espace ou Maj       | A                |
| Recommencer  | R                   | Start            |

En QWERTY, ce sont les touches W A S D, à la même place.

## Ce que contient le prototype

![Le prototype en plein boost](docs/capture_boost.png)

Ce premier prototype sert à régler la **sensation de vitesse**. Il propose une ligne droite sans fin dans une ville industrielle au coucher du soleil, avec un bolide qui va de 270 km/h en vitesse normale à environ 525 km/h en boost.

Les effets qui donnent la vitesse :

- **Champ de vision qui s'élargit** avec la vitesse. C'est l'effet le plus fort.
- **Caméra qui décroche** un instant quand le boost démarre, puis rattrape le bolide.
- **Tremblements** en boost et lors des chocs contre les murets.
- **Lignes de vitesse façon anime** sur les bords de l'écran.
- **Marquages au sol, murets et portiques** qui défilent, comme repères visuels.
- **Son de moteur** qui monte dans les aigus, et souffle du boost.
- **Rendu cartoon** : éclairage en aplats (et contours noirs façon BD sur la ligne droite d'essai ; les circuits n'en ont plus pour l'instant).

## Circuit 1 (en construction)

![Le cratère en terre, avec Cyber City 2 et le phare au loin](docs/circuit_01/capture_cratere.png)

C'est la scène lancée par **F5** : `scenes/circuit_01.tscn`. Une course de nuit d'environ 14,5 km, d'un point à un autre, d'après la carte annotée d'Eric (`docs/circuit_01/`) : départ dans un canyon, long tunnel, Cyber City 1, pont à haubans au-dessus de l'embouchure, montée dans la montagne, saut au-dessus d'une crevasse, zone cratère, Cyber City 2 et longue ligne droite finale. La route est large (36 m au plus étroit), ses virages sont amples, et rien de solide ne se trouve sur la trajectoire.

Les deux villes se tiennent à distance de la route : de près, des immeubles bas ; au loin, des silhouettes dont les étages s'allument en lignes, noyées dans la brume. Il y a aussi la pyramide lumineuse avec ses projecteurs, des cheminées d'usine, et un phare géant au faisceau tournant. Le cratère est un grand champ libre en terre où un monstre géant (une silhouette provisoire en blocs) se promène au hasard : il est solide, et ses pas font trembler la caméra.

Chaque zone a une seule teinte de lumière (`COULEURS_ZONES` dans `circuits/circuit_01.gd`) : blanc froid dans le canyon et sur le pont, cyan dans le tunnel, ambre dans Cyber City 1, violet dans la montagne, cyan dans Cyber City 2 et sur la ligne finale. Pour la sensation de vitesse, chaque section a ses repères dans cette teinte : bandes dans le tunnel, lampadaires dans les villes et sur le pont, balises sur les murets, portiques dans la montée, chevrons dans les virages, et sur la ligne droite finale des pointillés lumineux où courent des vagues de lumière.

Si le bolide passe sous la route après un choc, ou reste coincé, il est remis sur la route.

![La ligne droite finale et ses lignes lumineuses](docs/circuit_01/capture_ligne_droite.png)

![Les villes, la pyramide et le phare](docs/circuit_01/vue_villes.png)

Le sol (mer, terre ferme, montagnes en falaises) est construit à partir d'une petite image, `circuits/circuit_01_relief.png` : rouge = montagnes, vert = terre, noir = mer. On peut la repeindre dans n'importe quel logiciel de dessin.

## Circuits avec relief

![Le circuit d'essai, en plein saut au-dessus d'un trou](docs/capture_circuit_essai.png)

La scène `scenes/circuit_essai.tscn` (à ouvrir puis lancer avec **F6**, « lancer la scène actuelle ») est un vrai circuit en boucle : montées, descentes, virages relevés, blocs à éviter, tremplin au-dessus d'un trou et passage sans muret. Si on tombe, on réapparaît un peu plus tôt sur la route. Un chrono compte les tours et garde le meilleur.

Tout le circuit est construit par le code à partir d'un petit fichier de données, `circuits/circuit_essai.gd` : une liste de points de passage vus de dessus (avec leur hauteur et leur dévers) et une liste d'obstacles placés par leur distance depuis le départ. Le mode d'emploi est en tête du fichier. Pour créer un nouveau circuit, on copie ce fichier, on change les points et les obstacles, et on indique le nouveau fichier dans le réglage `fichier_circuit` du nœud **Circuit**.

## Organisation des fichiers

```
project.godot           Réglages du projet (scène de départ, fenêtre…)
circuits/
  circuit_essai.gd      Le tracé et les obstacles du circuit d'essai
  circuit_01.gd         Le tracé du circuit 1 (points relevés sur la carte)
  circuit_01_relief.png La carte du relief du circuit 1
outils/                 Petits scripts Python qui ont relevé le circuit 1 sur la carte
scenes/
  main.tscn             La scène principale : décor, caméra, son, affichage
  circuit_essai.tscn    Un petit circuit d'essai avec relief et obstacles
  circuit_01.tscn       Le circuit 1, de nuit
  vehicule.tscn         Le bolide (formes simples, à remplacer par un vrai modèle)
scripts/
  commandes.gd          Les touches clavier et manette
  vehicule.gd           Conduite, boost, animations du bolide
  camera_poursuite.gd   Caméra et effets de vitesse
  decor_base.gd         Ce que partagent tous les décors (effets du boost)
  circuit.gd            Construction de la ligne droite par le code
  circuit_trace.gd      Construction d'un circuit à partir d'un fichier de données
  terrain_carte.gd      Le sol : mer, terre et montagnes, d'après la carte du relief
  villes.gd             Les villes et les monuments (pyramide, cheminées, phare)
  tourner.gd            Fait tourner un objet (faisceau du phare)
  cratere.gd            La zone cratère et son monstre
  monstre.gd            Le monstre qui erre dans le cratère
  reperes.gd            Les repères de vitesse : lampadaires, balises, portiques, chevrons
  son_moteur.gd         Son de moteur généré en direct
  hud.gd                Compteur, jauge de boost, lignes de vitesse
shaders/
  toon.gdshader         Matière cartoon des objets
  contours.gdshader     Contours noirs sur toute l'image
  route.gdshader        Marquages de la piste
  route_circuit.gdshader  Marquages qui suivent les virages des circuits
  eau.gdshader          La mer de nuit
  immeuble.gdshader     Les fenêtres allumées des immeubles
  faisceau.gdshader     Les faisceaux de lumière
  halo.gdshader         Les halos lumineux
  lignes_vitesse.gdshader  Lignes de vitesse à l'écran
```

## Bidouiller les réglages

Presque tous les réglages sont modifiables dans l'éditeur, sans toucher au code. Il suffit de cliquer sur un nœud de la scène et de regarder l'**Inspecteur** à droite :

- **Vehicule** : vitesses, accélération, maniabilité, durée du boost.
- **Camera** : champ de vision minimum et maximum, distance, recul.
- **Circuit** : `graine` (change le tirage du décor) et nombre de bâtiments.

Changez une valeur, relancez avec F5 et comparez. C'est la meilleure façon de comprendre ce que fait chaque réglage.
