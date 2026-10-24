import bpy, sys, re, math, os
from mathutils import Matrix, Vector
tscn, out, mode = sys.argv[sys.argv.index('--')+1:][:3]
GLB='/mnt/user-data/outputs/pkg/glb/'
GLB2='/mnt/user-data/outputs/pkg2/'
GLB0=os.path.join(os.path.dirname(os.path.abspath(__file__)),'../kit/out/glb/')
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene
t=open(tscn).read()
blocks=re.split(r'\n(?=\[node )',t)
def tf(s):
    n=[float(x) for x in re.findall(r'-?[\d.]+(?:e-?\d+)?',s.split('(',1)[1])]
    r=Matrix(((n[0],n[1],n[2]),(n[3],n[4],n[5]),(n[6],n[7],n[8])))  # rows
    # basis columns are local axes; godot->blender (x,y,z)->(x,-z,y)
    C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
    R=C@r@C.inverted()
    M=R.to_4x4(); M.translation=Vector((n[9],-n[11],n[10]))
    return M
cache={}
def load(asset):
    if asset in cache: return cache[asset]
    for d in (GLB0,GLB2,GLB):
        p=d+'env_%s.glb'%asset
        if os.path.exists(p): break
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=p)
    new=[o for o in bpy.data.objects if o not in before]
    roots=[o for o in new if o.parent is None]
    cache[asset]=(new,roots)
    for o in new: o.hide_viewport=True; o.hide_render=True
    return cache[asset]
placements=[]
marks=[]
for b in blocks[1:]:
    h=b.split('\n',1)[0]
    nm=re.search(r'name="([^"]+)"',h).group(1); par=re.search(r' parent="([^"]*)"',h)
    par=par.group(1) if par else None
    m=re.search(r'transform = (Transform3D\([^)]*\))',b)
    if par=='Set' and m:
        asset=re.sub(r'\d+$','',nm)
        if any(os.path.exists(d+'env_%s.glb'%asset) for d in (GLB0,GLB)): placements.append((asset,tf(m.group(1))))
    elif par in ('Enemies',) and m: marks.append(('e',tf(m.group(1))))
    elif nm=='Player' and m: marks.append(('p',tf(m.group(1))))
    elif nm=='SaveOrb' and m: marks.append(('o',tf(m.group(1))))
    elif par=='Set' is False: pass
# lamp cones/lights not drawn; place assets
for asset,M in placements:
    new,roots=load(asset)
    # duplicate hierarchy
    mp={}
    for o in new:
        c=o.copy()
        if o.data: c.data=o.data
        c.hide_viewport=False; c.hide_render=False
        sc.collection.objects.link(c); mp[o]=c
    for o in new:
        c=mp[o]
        if o.parent: c.parent=mp[o.parent]; c.matrix_parent_inverse=o.matrix_parent_inverse.copy()
        else: c.matrix_world=M@o.matrix_world if False else M
mat={}
def mk(col):
    m=bpy.data.materials.new('m'); m.use_nodes=True; m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=col; m.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value=col; m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=1.0; return m
cols={'e':(1,0.1,0.1,1),'p':(0.1,1,0.2,1),'o':(1,0.3,0.8,1)}
for kind,M in marks:
    bpy.ops.mesh.primitive_cube_add(size=1.2 if kind!='o' else 1.8)
    ob=bpy.context.active_object; ob.matrix_world=M@Matrix.Translation((0,0,1.0)); ob.data.materials.append(mk(cols[kind]))
# render
sc.render.engine='CYCLES'; sc.cycles.samples=16; sc.cycles.device='CPU'
sc.render.resolution_x=1500; sc.render.resolution_y=900
sc.world=bpy.data.worlds.new('w'); sc.world.use_nodes=True
sc.world.node_tree.nodes['Background'].inputs[0].default_value=(0.12,0.14,0.24,1); sc.world.node_tree.nodes['Background'].inputs[1].default_value=1.0
sun=bpy.data.lights.new('s','SUN'); sun.energy=3.5; so=bpy.data.objects.new('s',sun); sc.collection.objects.link(so); so.rotation_euler=(math.radians(55),0,math.radians(-35))
cam=bpy.data.cameras.new('c'); co=bpy.data.objects.new('c',cam); sc.collection.objects.link(co); sc.camera=co
if mode=='aerial':
    cam.lens=24; co.location=(34,60,95); tgt=Vector((0,-6,6))   # blender y = -godot z; look down the street from the south-east
elif mode=='top':
    cam.lens=30; co.location=(0,-2,150); tgt=Vector((0,-2,0)); 
elif mode.startswith('interior'):
    cam.lens=18
    if mode=='interior2': co.location=(4.6,-3.6,2.4); tgt=Vector((-2.0,2.0,0.9))
    else: co.location=(-5.4,-4.1,2.6); tgt=Vector((3.0,1.0,0.9))
    for x in (-3.5,0,3.5):
        L=bpy.data.lights.new('l','POINT'); L.energy=250; L.color=(1,0.97,0.9); lo=bpy.data.objects.new('l',L); sc.collection.objects.link(lo); lo.location=(x,0,2.8)
    sun.energy=0.0
else:  # street level from spawn: godot (0,2.6,46) looking north (-Z godot = +Y blender)
    cam.lens=26; co.location=(0,-48,3.4); tgt=Vector((0,0,2.4))
co.rotation_euler=(tgt-co.location).to_track_quat('-Z','Y').to_euler()
if mode=='top': co.rotation_euler=(0,0,0)
cam.clip_end=1000
sc.render.filepath=out; bpy.ops.render.render(write_still=True)
