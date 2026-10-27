import cv2, numpy as np, json
pos=np.round(json.load(open('pos.json'))).astype(int)
imgs=[cv2.imread(f'/mnt/user-data/uploads/{i}.png') for i in range(1,10)]
Wm=max(p[0]+im.shape[1] for p,im in zip(pos,imgs));Hm=max(p[1]+im.shape[0] for p,im in zip(pos,imgs))
print(Wm,Hm)
mos=np.zeros((Hm,Wm,3),np.uint8);have=np.zeros((Hm,Wm),bool)
for i,(p,im) in enumerate(zip(pos,imgs)):
    h,w=im.shape[:2]
    valid=np.ones((h,w),bool)
    valid[-26:,:]=False
    if i in (4,7,8): valid[-70:,-80:]=False
    # edge strip 2px
    region=have[p[1]:p[1]+h,p[0]:p[0]+w]
    m=valid&~region
    mos[p[1]:p[1]+h,p[0]:p[0]+w][m]=im[m]
    have[p[1]:p[1]+h,p[0]:p[0]+w]|=valid
print('holes',(~have).sum())
cv2.imwrite('mosaic.png',mos);np.save('have.npy',have)
sm=cv2.resize(mos,(Wm//2,Hm//2),interpolation=cv2.INTER_AREA)
cv2.imwrite('mosaic_small.png',sm)
