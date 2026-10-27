import cv2, numpy as np, scipy.ndimage as ndi, base64, io, json
from PIL import Image
F=3
m=cv2.imread('mosaic.png')[:,:,::-1].astype(np.int32)
have=np.load('have.npy')
H,W=m.shape[:2]
Ht,Wt=H//F,W//F
m=m[:Ht*F,:Wt*F];have=have[:Ht*F,:Wt*F]
PAL=[((238,240,213),4),((242,239,233),1),((224,223,223),2),((173,209,158),6),((205,235,176),5),((200,250,204),5),
((217,208,201),12),((196,181,171),12),((170,211,223),7),((235,219,232),3),((255,214,209),3),((242,218,217),3),
((255,255,255),8),((252,214,164),9),((246,250,190),10),((254,254,178),10),((170,203,175),11),((237,237,237),1),
((255,255,228),1),((204,204,204),2),((187,187,187),2),((0,0,0),255),((70,70,70),255),((120,120,120),255),
((200,215,170),5),((222,252,226),5),((136,224,190),5),((200,214,190),5),((180,210,150),6),((146,182,132),6),
((228,226,226),2),((212,212,212),2),((218,220,196),4),((235,235,228),1),((250,248,244),1),((253,231,196),9),((236,206,168),9)]
pc=np.array([p[0] for p in PAL],np.float32);pk=np.array([p[1] for p in PAL],np.uint8)
cls=np.zeros((Ht*F,Wt*F),np.uint8)
CH=200
for y0 in range(0,Ht*F,CH):
    blk=m[y0:y0+CH].astype(np.float32)
    d=((blk[:,:,None,:]-pc[None,None,:,:])**2).sum(-1)
    cls[y0:y0+CH]=pk[d.argmin(-1)]
print('pixels classified')
# aggregate
cnt=np.zeros((14,Ht,Wt),np.uint8)
r=cls.reshape(Ht,F,Wt,F)
for c in list(range(1,13))+[255]:
    k=c if c<14 else 13
    if c==255: continue
    cnt[c]=(r==c).sum(axis=(1,3))
hv=have.reshape(Ht,F,Wt,F).sum(axis=(1,3))
road=cnt[8].astype(int)+cnt[9]+cnt[10]
bld=cnt[12].astype(int)
wat=cnt[7].astype(int)
ground_ids=[1,2,3,4,5,6,11]
gstack=np.stack([cnt[i] for i in ground_ids]).astype(int)
# water bias: thin rivers
out=np.zeros((Ht,Wt),np.uint8)
gbest=np.array(ground_ids)[gstack.argmax(0)]
gtot=gstack.sum(0)
out[:]=np.where(gtot>0,gbest,1)
out[(wat>=4)&(wat>=bld)]=7
out[(bld>=4)]=12
isroad=(road>=3)&(road>=bld-1)
mainc=np.stack([cnt[8],cnt[9]*1.5+0.01,cnt[10]*1.2+0.01]).astype(float)
rc=np.array([8,9,10])[mainc.argmax(0)]
out[isroad]=rc[isroad]
# small road components -> remove (label halos)
lab,n=ndi.label(np.isin(out,[8,9,10]),structure=np.ones((3,3)))
sz=np.bincount(lab.ravel())
small=(sz[lab]<9)&(lab>0)
# fill with nearest non-road ground
base=out.copy()
base[np.isin(base,[8,9,10,12])]=0
idx=ndi.distance_transform_edt(base==0,return_distances=False,return_indices=True)
filled=base[idx[0],idx[1]]
out[small]=filled[small]
# main-road specks -> local road
for c in (9,10):
    lab2,n2=ndi.label(out==c,structure=np.ones((3,3)))
    sz2=np.bincount(lab2.ravel())
    sp=(sz2[lab2]<25)&(lab2>0)
    out[sp]=8
# remove tiny buildings (<2 tiles)
lab,n=ndi.label(out==12)
sz=np.bincount(lab.ravel())
tiny=(sz[lab]<2)&(lab>0)
base=out.copy();base[np.isin(base,[12])]=0
idx=ndi.distance_transform_edt(base==0,return_distances=False,return_indices=True)
filled=base[idx[0],idx[1]]
out[tiny]=filled[tiny]
# label islands inside water -> water
wm=(out==7)
filled=ndi.binary_fill_holes(wm)
holes=filled&~wm
lab3,n3=ndi.label(holes)
sz3=np.bincount(lab3.ravel())
fix=holes&(sz3[lab3]<60)&(out!=12)
out[fix]=7
# void
out[hv<F*F*0.5]=13
# underlying ground for buildings
base=out.copy();base[np.isin(base,[12,13])]=0
base[np.isin(base,[8,9,10])]=0
idx=ndi.distance_transform_edt(base==0,return_distances=False,return_indices=True)
under=base[idx[0],idx[1]]
lab,n=ndi.label(out==12)
area=np.bincount(lab.ravel(),minlength=n+1)
key=lab[lab>0].astype(np.int64)*16+under[lab>0]
bc=np.bincount(key,minlength=(n+1)*16).reshape(n+1,16)
dom=bc.argmax(1)
rng=np.random.default_rng(5)
lv=np.zeros((Ht,Wt),np.uint8);ci=np.zeros((Ht,Wt),np.uint8)
lvc=np.zeros(n+1,np.uint8);cic=rng.integers(0,9,n+1).astype(np.uint8)
for i in range(1,n+1):
    a=area[i];d=dom[i];h=rng.random()
    if d==3: l=2 if a>30 else (1 if h<0.4 else 2)
    elif a<8: l=1+(h<0.5)
    elif a<30: l=2+(h<0.5)
    elif a<80: l=3+(h<0.5)
    else: l=4+int(h*3)
    if d in (4,6,5) and a<30: l=min(l,2)
    lvc[i]=l
lv[lab>0]=lvc[lab[lab>0]];ci[lab>0]=cic[lab[lab>0]]
print('buildings',n,'tiles',(out==12).sum(), 'grid',Wt,Ht)
# class histogram
print({int(k):int(v) for k,v in zip(*np.unique(out,return_counts=True))})
rgb=np.zeros((Ht,Wt,3),np.uint8)
rgb[:,:,0]=out*16;rgb[:,:,1]=lv*16;rgb[:,:,2]=ci*16
Image.fromarray(rgb).save('grid.png',optimize=True)
import os;print('png bytes',os.path.getsize('grid.png'))
# preview
colors={0:(255,0,255),1:(242,239,233),2:(224,223,223),3:(235,219,232),4:(238,240,213),5:(205,235,176),6:(173,209,158),7:(170,211,223),8:(255,255,255),9:(250,170,100),10:(240,240,120),11:(170,203,175),12:(150,110,100),13:(20,20,30)}
pv=np.zeros((Ht,Wt,3),np.uint8)
for k,c in colors.items(): pv[out==k]=c
Image.fromarray(pv).save('preview.png')
np.save('out.npy',out);np.save('lv.npy',lv)

# --- dodatkowe wyjscia dla wersji 3D ---
np.save('pix_cls.npy',cls)
base2=out.copy();base2[np.isin(base2,[12,13])]=0
idx2=ndi.distance_transform_edt(base2==0,return_distances=False,return_indices=True)
under2=base2[idx2[0],idx2[1]]
under2[out==13]=13
np.save('under2.npy',under2)
rgb2=np.zeros((Ht,Wt,3),np.uint8)
rgb2[:,:,0]=out*16;rgb2[:,:,1]=under2*16
Image.fromarray(rgb2).save('grid2.png',optimize=True)
print('grid2 saved')
