import json, numpy as np
E=json.load(open('edges.json'))
n=9
rows=[];rhs=[]
for k,(dx,dy,w) in E.items():
    a,b=map(int,k.split('-'))
    wt=min(w,600)**0.5
    # origin_b - origin_a = -d
    for ax,val in ((0,-dx),(1,-dy)):
        r=np.zeros(n);r[b]=1;r[a]=-1
        rows.append((ax,r*wt,val*wt))
sol={}
pos=np.zeros((n,2))
for ax in (0,1):
    A=[r for (x,r,v) in rows if x==ax];y=[v for (x,r,v) in rows if x==ax]
    A.append(np.eye(n)[0]*100);y.append(0)
    s,res,_,_=np.linalg.lstsq(np.array(A),np.array(y),rcond=None)
    pos[:,ax]=s
pos-=pos.min(axis=0)
print(np.round(pos,1))
for k,(dx,dy,w) in E.items():
    a,b=map(int,k.split('-'))
    pr=-(pos[b]-pos[a])
    print(k,w,'resid',np.round(pr-np.array([dx,dy]),1))
json.dump(pos.tolist(),open('pos.json','w'))
