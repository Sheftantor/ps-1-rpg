import re, sys, os, math, glob, itertools
OUT=sys.argv[1]
KIT=set(os.listdir('/mnt/user-data/outputs/pkg/glb'))|set(os.listdir(os.path.join(os.path.dirname(os.path.abspath(__file__)),'../kit/out/glb')))
KNOWN={'res://scenes/player.tscn','res://scenes/enemy.tscn','res://scenes/suit_guy.tscn','res://scenes/floating_monk.tscn','res://scenes/pickup.tscn','res://scenes/save_orb.tscn','res://scripts/world/area_exit.gd','res://scripts/commands/item_stack.gd','res://resources/items/potion.tres','res://resources/items/tonic.tres','res://scripts/world/rain.gd','res://scripts/world/shop_counter.gd','res://resources/shop/store_612_stock.tres','res://scenes/shop_menu.tscn'}
errs=0
def parse_tf(s):
    n=[float(x) for x in re.findall(r'-?[\d.]+(?:e-?\d+)?',s.split('(',1)[1])]
    return n
for fn in sorted(glob.glob(OUT+'/*.tscn')):
    t=open(fn).read(); name=os.path.basename(fn)
    ext=dict(re.findall(r'\[ext_resource type="[^"]+" path="([^"]+)" id="([^"]+)"\]',t))
    ids={v:k for k,v in ext.items()}
    subs=set(re.findall(r'\[sub_resource type="[^"]+" id="([^"]+)"\]',t))
    for p in ext:
        if p.startswith('res://Import/Environment/'):
            if os.path.basename(p) not in KIT: print(name,'MISSING GLB',p); errs+=1
        elif p not in KNOWN and not p.startswith('res://scenes/areas/'): print(name,'UNKNOWN res',p); errs+=1
    for m in re.findall(r'ExtResource\("([^"]+)"\)',t):
        if m not in ids: print(name,'bad ext id',m); errs+=1
    for m in re.findall(r'SubResource\("([^"]+)"\)',t):
        if m not in subs: print(name,'bad sub id',m); errs+=1
    # nodes
    blocks=re.split(r'\n(?=\[node )',t)
    seen={}; paths={'.'}
    boxes=[]; items=[]
    for b in blocks[1:]:
        h=b.split('\n',1)[0]
        nm=re.search(r'name="([^"]+)"',h).group(1)
        par=re.search(r' parent="([^"]*)"',h)
        if par is None: paths.add('.'); continue
        par=par.group(1)
        if par not in paths: print(name,'missing parent',par,'for',nm); errs+=1
        key=(par,nm)
        if key in seen: print(name,'dup',key); errs+=1
        seen[key]=1
        paths.add(nm if par=='.' else par+'/'+nm)
    # geometry
    sub_box={}
    for m in re.finditer(r'\[sub_resource type="BoxShape3D" id="([^"]+)"\]\nsize = Vector3\(([^)]*)\)',t):
        sub_box[m.group(1)]=[float(x) for x in m.group(2).split(',')]
    body_tf={}
    for b in blocks[1:]:
        h=b.split('\n',1)[0]; nm=re.search(r'name="([^"]+)"',h).group(1)
        par=re.search(r' parent="([^"]*)"',h).group(1) if ' parent=' in h else None
        tfm=re.search(r'transform = (Transform3D\([^)]*\))',b)
        if 'type="StaticBody3D"' in h and par=='Set' and tfm:
            body_tf[nm if par=='.' else par+'/'+nm]=parse_tf(tfm.group(1))
        if 'type="CollisionShape3D"' in h and par and par.startswith('Set/') and par in body_tf:
            bt=body_tf[par]; ct=parse_tf(tfm.group(1)) if tfm else [1,0,0,0,1,0,0,0,1,0,0,0]
            sz=sub_box[re.search(r'SubResource\("([^"]+)"\)',b).group(1)]
            c,s=bt[0],bt[2]  # row0 = (c,0,s)
            lx,ly,lz=ct[9],ct[10],ct[11]
            wx=bt[9]+c*lx+s*lz; wz=bt[11]-s*lx+c*lz; wy=bt[10]+ly
            yaw=math.degrees(math.atan2(s,c))
            sx,sy,sz_=sz
            if abs(abs(yaw)-90)<1: sx,sz_=sz_,sx
            boxes.append((par.split('/')[1].rstrip('0123456789'),(wx-sx/2,wx+sx/2),(wy-sy/2,wy+sy/2),(wz-sz_/2,wz+sz_/2)))
        if re.search(r'instance=ExtResource',h) and par in ('Enemies','.',) and tfm and nm in ('Player',) or (par=='Enemies' and tfm):
            T=parse_tf(tfm.group(1)); items.append((nm,T[9],T[10],T[11]))
    # overlaps between solids (ignore ground-ish)
    skip={'sidewalk','alley_gate','bollard','traffic_cone'}
    for a,b_ in itertools.combinations(boxes,2):
        if a[0] in skip or b_[0] in skip: continue
        ox=min(a[1][1],b_[1][1])-max(a[1][0],b_[1][0]); oy=min(a[2][1],b_[2][1])-max(a[2][0],b_[2][0]); oz=min(a[3][1],b_[3][1])-max(a[3][0],b_[3][0])
        if ox>0.4 and oy>0.4 and oz>0.4:
            print(name,'OVERLAP',a[0],b_[0],'(%.1f,%.1f,%.1f)'%(ox,oy,oz),'at x=%.0f z=%.0f'%((a[1][0]+a[1][1])/2,(a[3][0]+a[3][1])/2))
    for nm,x,y,z in items:
        for bx in boxes:
            if bx[1][0]<x<bx[1][1] and bx[3][0]<z<bx[3][1] and bx[2][0]<y+0.5<bx[2][1]+0.1 and bx[2][1]>0.6:
                print(name,'INSIDE SOLID',nm,'(%.1f,%.1f)'%(x,z),bx[0]); errs+=1
    print(name,'nodes',len(blocks)-1,'solids',len(boxes))
print('errors',errs)
