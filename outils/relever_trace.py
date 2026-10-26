# Relève le tracé du circuit 1 sur la heatmap d'Eric et écrit les points de
# passage (à recopier dans circuits/circuit_01.gd).
# Usage : python3 outils/relever_trace.py docs/circuit_01/heatmap_elevation.png > points.txt
# Il faut : pip install numpy scipy scikit-image pillow
#
# Étapes : on repère les pixels de la ligne, on la réduit à un trait d'un
# pixel, on la parcourt du départ à l'arrivée, on ajoute à la main la
# traversée du cratère (la ligne y disparaît), on met le tout à l'échelle
# (15 km), puis on lit la hauteur dans la couleur (rouge = sol, blanc =
# montagne), on lisse, on limite les pentes, et on calcule largeur et dévers.
import sys
HEATMAP = sys.argv[1]
import numpy as np, math
from PIL import Image
from skimage.morphology import skeletonize
from skimage.measure import label
from collections import deque
im=np.asarray(Image.open(HEATMAP).convert('RGB')).astype(int)
R,G,B=im[...,0],im[...,1],im[...,2]
m=(R>200)&(G>=45)
sk=skeletonize(m)
lab=label(sk,connectivity=2)
H,W=sk.shape
def voisins(p):
    y,x=p
    for dy in (-1,0,1):
        for dx in (-1,0,1):
            if (dy or dx) and 0<=y+dy<H and 0<=x+dx<W and sk[y+dy,x+dx]: yield (y+dy,x+dx)
def bfs(src,comp):
    par={src:None};q=deque([src]);last=src
    while q:
        p=q.popleft();last=p
        for v in voisins(p):
            if v not in par and lab[v]==comp: par[v]=p;q.append(v)
    return par,last
def chemin(start,comp):
    # du pixel le plus proche de start jusqu'au plus lointain
    ys,xs=np.nonzero(lab==comp)
    i=np.argmin((xs-start[0])**2+(ys-start[1])**2)
    src=(ys[i],xs[i])
    par,far=bfs(src,comp)
    path=[];p=far
    while p is not None: path.append(p);p=par[p]
    return path[::-1]
c1=chemin((50,620),1)
c2=chemin((1185,640),2)
# print(len(c1),c1[0][::-1],c1[-1][::-1],len(c2),c2[0][::-1],c2[-1][::-1])
def xy(path): return [(x,y) for y,x in path]
p1=xy(c1);p2=xy(c2)
# traversée du cratère (à la main, le long de son axe)
crat=[(1408,345),(1375,385),(1345,425),(1315,470),(1290,520),(1262,565),(1225,610),(1192,632)]
pts=p1+crat+p2
# rééchantillonnage tous les 3 px
def resample(pts,step):
    out=[pts[0]];acc=0.0
    for a,b in zip(pts,pts[1:]):
        seg=math.dist(a,b)
        if seg==0: continue
        t=step-acc
        while t<=seg:
            out.append((a[0]+(b[0]-a[0])*t/seg,a[1]+(b[1]-a[1])*t/seg));t+=step
        acc=(acc+seg)%step
    out.append(pts[-1]);return out
pts=resample(pts,3.0)
# lissage léger de la position
P=np.array(pts)
for _ in range(4):
    P[1:-1]=0.25*P[:-2]+0.5*P[1:-1]+0.25*P[2:]
L=np.sum(np.linalg.norm(np.diff(P,axis=0),axis=1))
# print('longueur px',L)


R,G=im[...,0],im[...,1]
ligne=(R>200)&(G>=45)
ys,xs=np.nonzero(ligne)
ECH=15000.0/np.sum(np.linalg.norm(np.diff(P,axis=0),axis=1))
print('# echelle', ECH)
# distance cumulée (m)
seg=np.linalg.norm(np.diff(P,axis=0),axis=1)*ECH
D=np.concatenate([[0],np.cumsum(seg)])
def idx(px,py): return int(np.argmin((P[:,0]-px)**2+(P[:,1]-py)**2))
# hauteur d'après la couleur de la ligne (rouge = sol, blanc = montagne)
H_SOL,H_MONT=12.0,170.0
t=np.zeros(len(P));ok=np.zeros(len(P),bool)
for i,(x,y) in enumerate(P):
    xi,yi=int(round(x)),int(round(y))
    win=ligne[yi-3:yi+4,xi-3:xi+4]
    if win.sum()>0:
        g=G[yi-3:yi+4,xi-3:xi+4][win]
        t[i]=np.clip((g.max()-69)/162.0,0,1);ok[i]=True
i_c0,i_c1=idx(1408,345),idx(1192,632)
ok[i_c0+1:i_c1]=False
t=np.interp(D,D[ok],t[ok])
h=H_SOL+t*(H_MONT-H_SOL)
# le pont : bosse au-dessus de l'eau
ib0,ib1=idx(845,512),idx(1100,535)
mid=(D[ib0]+D[ib1])/2;half=(D[ib1]-D[ib0])/2
for i in range(ib0,ib1+1):
    u=(D[i]-mid)/half
    h[i]+=26*(1-u*u)
# lissage (fenêtre ~150 m) puis pente max
def lisse(v,w):
    out=v.copy()
    for i in range(len(v)):
        m=(np.abs(D-D[i])<w);out[i]=v[m].mean()
    return out
h=lisse(h,120)
PMAX=0.12
dD=np.diff(D)
for _ in range(3000):
    dh=np.diff(h);lim=PMAX*dD
    exc=np.sign(dh)*np.maximum(np.abs(dh)-lim,0)/2
    h[1:]-=exc;h[:-1]+=exc
h=lisse(h,40)

# largeurs par zones
zones=[((50,620),26),((250,520),24),((290,468),18),((505,410),18),((470,520),22),((560,545),20),((790,505),22),
 ((845,512),20),((1100,535),20),((1150,510),24),((1380,250),20),((1640,185),20),((1480,275),26),((1408,345),40),
 ((1345,425),110),((1300,500),150),((1255,570),110),((1195,630),30),((1110,655),22),((1040,690),20),((1220,830),20),((1290,668),28),((1600,580),34),((1893,500),38)]
zi=[idx(*p) for p,_ in zones];zw=[w for _,w in zones]
order=np.argsort(zi);zi=np.array(zi)[order];zw=np.array(zw)[order]
larg=np.interp(np.arange(len(P)),zi,zw)
# dévers selon la courbure
W=np.column_stack([P[:,0],P[:,1]])*ECH
dev=np.zeros(len(P))
for i in range(4,len(P)-4):
    a=W[i]-W[i-4];b=W[i+4]-W[i]
    ha=math.atan2(a[1],a[0]);hb=math.atan2(b[1],b[0])
    dth=(hb-ha+math.pi)%(2*math.pi)-math.pi
    ds=(np.linalg.norm(a)+np.linalg.norm(b))/2
    k=dth/ds  # >0 : virage à droite (x vers la droite, z vers le bas)
    r=1/max(abs(k),1e-6)
    dev[i]=math.copysign(min(12.0,900.0/r),k) if r<500 else 0
dev=lisse(dev,40)
# décimation : un point tous les ~45 m, plus serré dans les virages
garde=[0];last=0
for i in range(1,len(P)-1):
    if D[i]-D[last]>=45 or (abs(dev[i])>6 and D[i]-D[last]>=25):
        garde.append(i);last=i
garde.append(len(P)-1)
print('# points', len(garde), 'longueur', D[-1])
lm={'tunnel_debut':idx(290,468),'tunnel_fin':idx(505,410),'pont_debut':ib0,'pont_fin':ib1,'cratere_debut':i_c0,'cratere_fin':i_c1,'ville1':idx(560,545),'ville2':idx(1110,655),'finale':idx(1290,668)}
for k, v in lm.items(): print('#', k, int(D[v]), 'm')

for i in garde:
    print("\t[%.1f, %.1f, %.0f, %.0f, %.0f],  # %d m" % (P[i,0], P[i,1], h[i], dev[i], larg[i], D[i]))
