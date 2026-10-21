import bpy, sys, math
from mathutils import Vector
blend, out, gx, gy, gz, cx, cy, cz, lookx, looky, lookz = sys.argv[sys.argv.index('--')+1:][:11]
bpy.ops.wm.open_mainfile(filepath=blend)
sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.samples=24; sc.cycles.device='CPU'
sc.render.resolution_x=1400; sc.render.resolution_y=800
sc.world=bpy.data.worlds.new('w'); sc.world.use_nodes=True
sc.world.node_tree.nodes['Background'].inputs[0].default_value=(0.55,0.62,0.75,1)
sc.world.node_tree.nodes['Background'].inputs[1].default_value=1.0
sun=bpy.data.lights.new('s','SUN'); sun.energy=4
so=bpy.data.objects.new('s',sun); sc.collection.objects.link(so); so.rotation_euler=(math.radians(50),0,math.radians(30))
cam=bpy.data.cameras.new('c'); cam.lens=28
co=bpy.data.objects.new('c',cam); sc.collection.objects.link(co)
import os
ob=bpy.data.objects.get(os.environ.get('OBJ','')) 
ofs=ob.location if ob else Vector((0,0,0))
co.location=Vector((float(cx),float(cy),float(cz)))+ofs
d=Vector((float(lookx),float(looky),float(lookz)))+ofs-co.location
co.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
sc.camera=co
sc.render.filepath=out
bpy.ops.render.render(write_still=True)
