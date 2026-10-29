import numpy as np, cv2, json, math
import scipy.ndimage as ndi
from PIL import Image
F=3
pix=np.load('pix_cls.npy'); out=np.load('out.npy'); reg=np.load('reg.npy')
Ht,Wt=out.shape
tile_b=(out==12).astype(np.uint8)
tb_up=cv2.dilate(np.kron(tile_b,np.ones((F,F),np.uint8)),np.ones((3,3),np.uint8))
mask=((pix==12)&(tb_up>0)).astype(np.uint8)
mask=cv2.morphologyEx(mask,cv2.MORPH_CLOSE,np.ones((5,5),np.uint8))
mask=cv2.morphologyEx(mask,cv2.MORPH_OPEN,np.ones((3,3),np.uint8))
n,lab,stats,_=cv2.connectedComponentsWithStats(mask,connectivity=8)
keep=np.zeros(n,bool);keep[1:]=stats[1:,cv2.CC_STAT_AREA]>=12
mask=keep[lab].astype(np.uint8)
cnts,_=cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_NONE)
print('kontury',len(cnts))

def manhattan(pts):
    n=len(pts); edges=[]
    for i in range(n):
        a=pts[i]; b=pts[(i+1)%n]
        d=b-a; o='h' if abs(d[0])>=abs(d[1]) else 'v'
        edges.append([o,(a+b)/2.0,float(np.linalg.norm(d))+1e-6])
    merged=[]
    for e in edges:
        if merged and merged[-1][0]==e[0]:
            m=merged[-1]; w=m[2]+e[2]; m[1]=(m[1]*m[2]+e[1]*e[2])/w; m[2]=w
        else: merged.append([e[0],e[1].copy(),e[2]])
    if len(merged)>1 and merged[0][0]==merged[-1][0]:
        a=merged.pop(); m=merged[0]; w=m[2]+a[2]; m[1]=(m[1]*m[2]+a[1]*a[2])/w; m[2]=w
    if len(merged)<4 or len(merged)%2: return None
    v=[]
    for i in range(len(merged)):
        e1=merged[i]; e2=merged[(i+1)%len(merged)]
        if e1[0]=='h': v.append((e2[1][0],e1[1][1]))
        else: v.append((e1[1][0],e2[1][1]))
    return np.array(v)

def rot(p,c,a):
    ca,sa=math.cos(a),math.sin(a)
    d=p-c
    return np.stack([d[:,0]*ca-d[:,1]*sa,d[:,0]*sa+d[:,1]*ca],1)+c

rng=np.random.default_rng(11)
res=[];PX=1.0/F
stat={'rect':0,'manh':0,'poly':0}
for c in cnts:
    area=cv2.contourArea(c)
    if area<10: continue
    (cx,cy),(rw,rh),ang=cv2.minAreaRect(c)
    ra=max(rw*rh,1e-6); fill=area/ra
    atl=(area+0.5*cv2.arcLength(c,True))*PX*PX
    cxt,cyt=int(np.clip(cx/F,0,Wt-1)),int(np.clip(cy/F,0,Ht-1))
    ug=int(reg[cyt,cxt]) if reg[cyt,cxt]!=13 else 1
    rect=None;pts=None
    a=math.radians(ang if rw>=rh else ang+90.0)
    if (fill>0.66 or (atl<8 and fill>0.55)) and rw>1 and rh>1:
        w2=(max(rw,rh)+1.0)*PX/2; h2=(min(rw,rh)+1.0)*PX/2
        rect=[round(cx*PX,2),round(cy*PX,2),round(w2,2),round(h2,2),round(a,3)]
        ca,sa=math.cos(a),math.sin(a)
        pts=[(rect[0]+sx*w2*ca-sy*h2*sa, rect[1]+sx*w2*sa+sy*h2*ca) for sx,sy in ((-1,-1),(1,-1),(1,1),(-1,1))]
        long_s=w2*2; short_s=h2*2; stat['rect']+=1
    else:
        cp=c.reshape(-1,2).astype(np.float64)
        ctr=np.array([cx,cy])
        rp=rot(cp,ctr,-a)
        ap=cv2.approxPolyDP(rp.astype(np.float32).reshape(-1,1,2),2.4,True).reshape(-1,2).astype(np.float64)
        mh=manhattan(ap) if len(ap)>=4 else None
        ok=False
        if mh is not None:
            ar=abs(0.5*np.sum(mh[:,0]*np.roll(mh[:,1],-1)-np.roll(mh[:,0],-1)*mh[:,1]))
            ratio=ar/max(area,1)
            if 0.80<ratio<1.30:
                back=rot(mh,ctr,a)
                m=back.mean(axis=0); k=1+0.5*cv2.arcLength(c,True)/(2*max(area,1))
                back=m+(back-m)*min(k,1.5)
                pts=[(x*PX,y*PX) for x,y in back]; ok=True; stat['manh']+=1
        if not ok:
            if fill>0.5:
                w2=(max(rw,rh)+1.0)*PX/2; h2=(min(rw,rh)+1.0)*PX/2
                rect=[round(cx*PX,2),round(cy*PX,2),round(w2,2),round(h2,2),round(a,3)]
                ca,sa=math.cos(a),math.sin(a)
                pts=[(rect[0]+sx*w2*ca-sy*h2*sa, rect[1]+sx*w2*sa+sy*h2*ca) for sx,sy in ((-1,-1),(1,-1),(1,1),(-1,1))]
                stat['rect']+=1
            else:
                ap2=cv2.approxPolyDP(c,3.0,True).reshape(-1,2).astype(np.float64)
                if len(ap2)<3: continue
                m=ap2.mean(axis=0); k=1+0.5*cv2.arcLength(c,True)/(2*max(area,1))
                ap2=m+(ap2-m)*min(k,1.5); pts=[(x*PX,y*PX) for x,y in ap2]; stat['poly']+=1
        long_s=max(rw,rh)*PX; short_s=min(rw,rh)*PX
    asp=long_s/max(short_s,1e-3)
    h=rng.random()
    if ug==3: t,fl,roof=4,(1 if atl<12 else 2),0
    elif atl<1.4: t,fl,roof=1,1,(1 if rect else 0)
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
    d={"p":[round(float(v),2) for xy in pts for v in xy],"n":int(fl),"r":int(roof),"t":int(t),"w":int(rng.integers(0,6)),"c":int(rng.integers(0,5))}
    if rect: d["q"]=rect
    res.append(d)
print('budynki',len(res),stat,'wierzcholki',sum(len(d["p"])//2 for d in res))
json.dump(res,open('buildings.json','w'),separators=(',',':'))

# siatka: R=klasa, G=podloze, B=pokrycie
big=np.zeros((Ht*F,Wt*F),np.uint8)
for d in res:
    p=d["p"]
    pts=np.array([[p[i]*F,p[i+1]*F] for i in range(0,len(p),2)],np.float32)
    cv2.fillPoly(big,[np.round(pts).astype(np.int32)],255)
cov=big.reshape(Ht,F,Wt,F).mean(axis=(1,3))/255.0
under=reg.copy()
cls3=reg.copy()
roadm=np.isin(reg,[8,9,10])
solid_b=((cov>=0.5)&~np.isin(reg,[7,13])&~(roadm&(cov<0.8)))
cls3[solid_b]=12
rgb=np.zeros((Ht,Wt,3),np.uint8)
rgb[:,:,0]=cls3*16;rgb[:,:,1]=under*16;rgb[:,:,2]=np.round(cov*15).astype(np.uint8)*16
Image.fromarray(rgb).save('grid4.png',optimize=True)
print('grid4: kafle zabudowy',int(solid_b.sum()))
# podglad
x0,y0,w,h=470,420,90,50;S=10
im=Image.new('RGB',(w*S,h*S),(235,232,222))
from PIL import ImageDraw
dr=ImageDraw.Draw(im)
for bd in res:
    p=bd['p'];pp=[((p[i]-x0)*S,(p[i+1]-y0)*S) for i in range(0,len(p),2)]
    dr.polygon(pp,fill=(170,175,200),outline=(60,50,50))
im.save('poly_preview2.png')
