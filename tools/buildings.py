import numpy as np, cv2, json, math
F=3
pix=np.load('pix_cls.npy'); out=np.load('out.npy'); under=np.load('under2.npy')
Ht,Wt=out.shape
tile_b=(out==12).astype(np.uint8)
tb_up=np.kron(tile_b,np.ones((F,F),np.uint8))
tb_up=cv2.dilate(tb_up,np.ones((3,3),np.uint8))
mask=((pix==12)&(tb_up>0)).astype(np.uint8)
mask=cv2.morphologyEx(mask,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
# usun drobiazgi
n,lab,stats,_=cv2.connectedComponentsWithStats(mask,connectivity=8)
keep=np.zeros(n,bool);keep[1:]=stats[1:,cv2.CC_STAT_AREA]>=10
mask=keep[lab].astype(np.uint8)
cnts,_=cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_NONE)
print('kontury',len(cnts))
rng=np.random.default_rng(11)
res=[]
PX=1.0/F  # piksel -> jednostki kafla
for c in cnts:
    area=cv2.contourArea(c)
    if area<8: continue
    (cx,cy),(rw,rh),ang=cv2.minAreaRect(c)
    ra=max(rw*rh,1e-6)
    fill=area/ra
    atl=(area+0.5*cv2.arcLength(c,True))*PX*PX   # pole w kaflach^2 z korekta o pol piksela
    cxt,cyt=int(np.clip(cx/F,0,Wt-1)),int(np.clip(cy/F,0,Ht-1))
    ug=int(under[cyt,cxt])
    rect=None;pts=None
    if (fill>0.72 or (atl<8 and fill>0.58)) and rw>1 and rh>1:
        w2=(max(rw,rh)+1.0)*PX/2; h2=(min(rw,rh)+1.0)*PX/2
        a=math.radians(ang if rw>=rh else ang+90.0)
        rect=[round(cx*PX,2),round(cy*PX,2),round(w2,2),round(h2,2),round(a,3)]
        ca,sa=math.cos(a),math.sin(a)
        pts=[]
        for sx,sy in ((-1,-1),(1,-1),(1,1),(-1,1)):
            x=rect[0]+sx*w2*ca-sy*h2*sa; y=rect[1]+sx*w2*sa+sy*h2*ca
            pts.append((x,y))
        long_s=max(w2,h2)*2; short_s=min(w2,h2)*2
    else:
        ap=cv2.approxPolyDP(c,2.0,True).reshape(-1,2).astype(np.float64)
        if len(ap)<3: continue
        m=ap.mean(axis=0)
        per=cv2.arcLength(c,True)
        k=1+0.5*per/(2*max(area,1))
        ap=m+(ap-m)*min(k,1.5)
        pts=[(x*PX,y*PX) for x,y in ap]
        long_s=max(rw,rh)*PX; short_s=min(rw,rh)*PX
    asp=long_s/max(short_s,1e-3)
    # typ i pietra
    h=rng.random()
    if ug==3:  # przemysl
        t,fl,roof=4,(1 if atl<12 else 2),0
    elif atl<1.4:
        t,fl,roof=1,1,(1 if rect else 0)
    elif atl<8:
        t,fl,roof=0,(1 if h<0.3 else 2 if h<0.9 else 3),(1 if rect else 0)
        if rect and short_s>2.6: roof=2 if h<0.25 else 1
    elif atl<22:
        t,fl,roof=5,(3 if h<0.4 else 4 if h<0.8 else 2),(0 if h<0.7 else 1)
        if not rect: roof=0
    else:
        if asp>2.2 and atl>25: t,fl,roof=3,(4+int(h*3)),0
        else: t,fl,roof=2,(3+int(h*3)),0
    if ug in (4,6,5) and atl<10: fl=min(fl,2)
    if rect is None and roof!=0: roof=0
    wi=int(rng.integers(0,6)); ri=int(rng.integers(0,5))
    d={"p":[round(float(v),2) for xy in pts for v in xy],"n":int(fl),"r":int(roof),"t":int(t),"w":wi,"c":ri}
    if rect: d["q"]=rect
    res.append(d)
print('budynki',len(res),'wierzcholki',sum(len(d["p"])//2 for d in res))
from collections import Counter
print('typy',Counter(d["t"] for d in res),'dachy',Counter(d["r"] for d in res),'pietra',Counter(d["n"] for d in res))
json.dump(res,open('buildings.json','w'),separators=(',',':'))
import os;print('json bytes',os.path.getsize('buildings.json'))

# --- siatka kolizji liczona z wielokatow (R=klasa, G=podloze, B=pokrycie budynkiem) ---
import cv2
from PIL import Image
big=np.zeros((Ht*F,Wt*F),np.uint8)
for d in res:
    p=d["p"]
    pts=np.array([[p[i]*F,p[i+1]*F] for i in range(0,len(p),2)],np.float32)
    cv2.fillPoly(big,[np.round(pts).astype(np.int32)],255)
cov=big.reshape(Ht,F,Wt,F).mean(axis=(1,3))/255.0
cls3=out.copy()
cls3[cls3==12]=under[cls3==12]
solid_b=(cov>=0.45)&(~np.isin(out,[7,13]))
cls3[solid_b]=12
rgb=np.zeros((Ht,Wt,3),np.uint8)
rgb[:,:,0]=cls3*16;rgb[:,:,1]=under*16;rgb[:,:,2]=np.round(cov*15).astype(np.uint8)*16
Image.fromarray(rgb).save('grid3.png',optimize=True)
print('grid3: kafle zabudowy',int(solid_b.sum()),'(poprzednio',int((out==12).sum()),')')
