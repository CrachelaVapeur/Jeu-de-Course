"""Fabrique des sons PROVISOIRES (bruits synthétiques) dans audio/sfx/.
Ils servent juste à entendre le système de sons du jeu. Pour mettre un vrai son,
remplace simplement le fichier par un autre du même nom (.wav ou .ogg).
Usage : python outils/generer_sons_provisoires.py
"""
import os
import wave

import numpy as np

TAUX = 44100
rng = np.random.default_rng(1)
dossier = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")
os.makedirs(dossier, exist_ok=True)


def ecrire(nom, signal):
    signal = np.asarray(signal, dtype=np.float64)
    signal = signal / max(np.abs(signal).max(), 1e-9) * 0.8
    donnees = (signal * 32767).astype("<i2")
    with wave.open(os.path.join(dossier, nom), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(TAUX)
        f.writeframes(donnees.tobytes())


def temps(duree):
    return np.arange(int(duree * TAUX)) / TAUX


def passe_bas(x, k):
    sortie = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += (v - acc) * k
        sortie[i] = acc
    return sortie


def boucle_douce(x, fondu=0.05):
    """Fait un fondu croisé début/fin pour que la boucle ne « claque » pas."""
    n = int(fondu * TAUX)
    x = x.copy()
    rampe = np.linspace(0, 1, n)
    x[:n] = x[:n] * rampe + x[-n:] * (1 - rampe)
    return x[:-n]


# Choc contre un mur : claque + grondement qui retombe.
t = temps(0.45)
bruit = rng.uniform(-1, 1, t.size)
ecrire("choc_mur.wav", (passe_bas(bruit, 0.35) * np.exp(-t * 9) + np.sin(2 * np.pi * 70 * t) * np.exp(-t * 14)))

# Raclement contre un mur : bruit grave et granuleux, en boucle.
t = temps(0.8)
bruit = rng.uniform(-1, 1, t.size)
raclement = passe_bas(bruit, 0.25) * (0.7 + 0.3 * np.sin(2 * np.pi * 37 * t))
ecrire("raclement_mur.wav", boucle_douce(raclement))

# Crissement de pneus en dérapage : sifflement aigu qui ondule, en boucle.
t = temps(1.0)
bruit = rng.uniform(-1, 1, t.size)
bande = bruit - passe_bas(bruit, 0.05)
crissement = bande * 0.4 + np.sin(2 * np.pi * (1500 + 120 * np.sin(2 * np.pi * 5 * t)) * t) * 0.5
ecrire("derapage.wav", boucle_douce(crissement * (0.8 + 0.2 * np.sin(2 * np.pi * 9 * t))))

# Départ du boost : souffle qui monte puis un coup grave.
t = temps(1.2)
bruit = rng.uniform(-1, 1, t.size)
ouverture = np.linspace(0.02, 0.6, t.size)
souffle = np.zeros_like(bruit)
acc = 0.0
for i in range(t.size):
    acc += (bruit[i] - acc) * ouverture[i]
    souffle[i] = acc
enveloppe = np.minimum(t / 0.5, 1.0) * np.exp(-np.maximum(t - 0.5, 0) * 2.5)
ecrire("boost_depart.wav", souffle * enveloppe + np.sin(2 * np.pi * 55 * t) * np.exp(-t * 6) * 0.6)

# Fin du boost : souffle qui retombe.
t = temps(0.7)
bruit = rng.uniform(-1, 1, t.size)
ecrire("boost_fin.wav", passe_bas(bruit, 0.2) * np.exp(-t * 5))

# Atterrissage : gros « boum » grave.
t = temps(0.4)
ecrire("atterrissage.wav", np.sin(2 * np.pi * 55 * t * np.exp(-t * 3)) * np.exp(-t * 9) + passe_bas(rng.uniform(-1, 1, t.size), 0.3) * np.exp(-t * 20) * 0.5)

# Changement de rapport : petit clac.
t = temps(0.12)
ecrire("changement_rapport.wav", (passe_bas(rng.uniform(-1, 1, t.size), 0.5) + np.sin(2 * np.pi * 220 * t)) * np.exp(-t * 45))
print("Sons provisoires écrits dans", os.path.abspath(dossier))
