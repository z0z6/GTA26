import numpy as np, scipy.ndimage as ndi
out=np.load('out.npy'); under=np.load('under2.npy')
H,W=out.shape
G=[1,2,3,4,5,6,11]
reg=under.copy()
road=np.isin(reg,[8,9,10]); water=(reg==7); void=(reg==13)
ground_mask=np.isin(reg,G)
# 1. wypelnij nie-grunt najblizszym gruntem, wygladz wskazniki klas gaussem i wybierz najsilniejsza
idx=ndi.distance_transform_edt(~ground_mask,return_distances=False,return_indices=True)
gf=reg[idx[0],idx[1]]
best=np.zeros((H,W)); gs=gf.copy()
for c in G:
    b=ndi.gaussian_filter((gf==c).astype(np.float32),sigma=1.5)
    m=b>best; best[m]=b[m]; gs[m]=c
# 2. usun male plamy gruntu (<18 kafli)
for c in G:
    lab,n=ndi.label(gs==c)
    if n==0: continue
    sz=np.bincount(lab.ravel())
    small=(sz[lab]<18)&(lab>0)
    if small.any():
        keep=~small
        i2=ndi.distance_transform_edt(~keep,return_distances=False,return_indices=True)
        gs=np.where(small,gs[i2[0],i2[1]],gs)
# 3. woda: mediana + zamkniecie, bez drobnicy
w2=ndi.median_filter(water.astype(np.uint8),size=3)>0
w2=ndi.binary_closing(w2,structure=np.ones((3,3)))
w2=ndi.binary_fill_holes(w2)|w2
lab,n=ndi.label(w2); sz=np.bincount(lab.ravel()); w2&=~((sz[lab]<12)&(lab>0))
# 4. drogi: zamkniecie, bez drobnych odcinkow
r2=ndi.binary_closing(road,structure=np.ones((3,3)))
lab,n=ndi.label(r2,structure=np.ones((3,3))); sz=np.bincount(lab.ravel()); r2&=~((sz[lab]<12)&(lab>0))
ri=ndi.distance_transform_edt(~road,return_distances=False,return_indices=True)
rcls=reg[ri[0],ri[1]]
for c in (9,10):
    lab,n=ndi.label(rcls==c,structure=np.ones((3,3)));sz=np.bincount(lab.ravel())
    rcls[(sz[lab]<25)&(lab>0)]=8
# 5. zlozenie
out2=gs.copy()
out2[w2]=7
out2[r2]=rcls[r2]
out2[void]=13
np.save('reg.npy',out2.astype(np.uint8))
print({int(k):int(v) for k,v in zip(*np.unique(out2,return_counts=True))})
from PIL import Image
cols={1:(242,239,233),2:(224,223,223),3:(235,219,232),4:(238,240,213),5:(205,235,176),6:(173,209,158),7:(170,211,223),8:(255,255,255),9:(250,170,100),10:(240,240,120),11:(170,203,175),13:(20,20,30)}
def prev(a,name):
    pv=np.zeros(a.shape+(3,),np.uint8)
    for k,c in cols.items(): pv[a==k]=c
    Image.fromarray(pv[380:520,380:640]).resize((780,420),Image.NEAREST).save(name)
prev(under,'ground_before.png'); prev(out2,'ground_after.png')
