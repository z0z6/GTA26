import cv2, numpy as np, itertools, json
imgs=[cv2.imread(f'/mnt/user-data/uploads/{i}.png') for i in range(1,10)]
# crop artifact margins: bottom 24px
crops=[im[:-24,:] for im in imgs]
orb=cv2.ORB_create(6000)
feats=[]
for im in crops:
    g=cv2.cvtColor(im,cv2.COLOR_BGR2GRAY)
    kp,des=orb.detectAndCompute(g,None)
    feats.append((kp,des))
bf=cv2.BFMatcher(cv2.NORM_HAMMING,crossCheck=True)
edges={}
for a,b in itertools.combinations(range(9),2):
    ka,da=feats[a];kb,db=feats[b]
    if da is None or db is None: continue
    m=bf.match(da,db)
    m=sorted(m,key=lambda x:x.distance)[:1500]
    if len(m)<15: continue
    # translation voting
    d=np.array([[kb[x.trainIdx].pt[0]-ka[x.queryIdx].pt[0], kb[x.trainIdx].pt[1]-ka[x.queryIdx].pt[1]] for x in m])
    # mode via rounding
    r=np.round(d/3).astype(int)
    vals,counts=np.unique(r,axis=0,return_counts=True)
    i=counts.argmax()
    t=vals[i]*3
    inl=np.sum(np.linalg.norm(d-t,axis=1)<4)
    if inl>=12:
        # refine
        sel=d[np.linalg.norm(d-t,axis=1)<4].mean(axis=0)
        edges[(a,b)]=(float(sel[0]),float(sel[1]),int(inl))
for k,v in edges.items(): print(k,v)
json.dump({f'{a}-{b}':v for (a,b),v in edges.items()},open('edges.json','w'))
