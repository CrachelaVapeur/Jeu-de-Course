# Fabrique la carte du relief (rouge = montagnes, vert = terre, noir = mer)
# à partir des couleurs de la carte annotée.
import sys
import numpy as np
from PIL import Image
from scipy import ndimage
carte, sortie = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(carte).convert('RGB')).astype(int)
couleurs = {0: (74, 73, 99), 1: (209, 201, 188), 2: (254, 180, 6)}  # mer, terre, montagne
cls = np.full(im.shape[:2], -1)
for k, c in couleurs.items():
    cls[np.abs(im - np.array(c)).sum(-1) < 25] = k
# Étiquettes, piste et dessins : on prend la couleur de la zone la plus proche.
_, ind = ndimage.distance_transform_edt(cls < 0, return_indices=True)
cls = cls[ind[0], ind[1]]
terre = ndimage.gaussian_filter((cls >= 1).astype(float), 2.0)
mont = ndimage.gaussian_filter((cls == 2).astype(float), 12.0)
out = np.zeros(im.shape[:2] + (3,), np.uint8)
out[..., 0] = (mont * 255).round()
out[..., 1] = (terre * 255).round()
Image.fromarray(out).resize((im.shape[1] // 2, im.shape[0] // 2), Image.BILINEAR).save(sortie, optimize=True)
