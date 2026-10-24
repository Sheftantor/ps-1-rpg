"""Builds env_apartment_door.glb: a stone entrance porch for a terrace house with a working front door,
used by the new-game intro (scripts/world/apartment_intro.gd).
Run: blender --background --python build_apartment_door.py -- <project root>
     (or exec it in a live Blender with PROJECT already set; it builds in its own scene and leaves the rest
     of the open file alone).
Same conventions as build_kit.py: 1 unit = 1 m, origin at base centre, FRONT faces Blender -Y (+Z in
Godot), Z-up -> Y-up in the GLB. Textures are the kit's own PNGs from Import/Environment, nearest-filtered
and tiled in metres. The door is a child object hinged on +X, with two actions exported as separate glTF
animations: door_open (swings out toward the street, ~1 s) and door_close (~0.75 s)."""
import math, os, sys
import bpy, bmesh

if "PROJECT" not in globals():
    PROJECT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
ENV = os.path.join(PROJECT, "Import", "Environment")
OUT = os.path.join(ENV, "env_apartment_door.glb")
FPS = 24

# key -> (kit texture, metres per texture repeat, (emission colour, strength) or None)
TEX = {
    "concrete": ("env_alley_gate_concrete.png", 4.0, None),
    "concrete_dark": ("env_alley_gate_concrete_dark.png", 4.0, None),
    "wood": ("env_bench_wood.png", 1.0, None),
    "black": ("env_bin_bag_black.png", 1.0, None),
    "metal_dark": ("env_bench_metal_dark.png", 1.0, None),
    "dark_glass": ("env_bus_shelter_dark_glass.png", 1.0, None),
    "lamp_glow": ("env_street_lamp_lamp_glow.png", 1.0, ((1.0, 0.62, 0.22), 4.0)),
}
_mats = {}


def material(key):
    if key in _mats:
        return _mats[key]
    png, _, emit = TEX[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    img = bpy.data.images.load(os.path.join(ENV, png), check_existing=True)
    img.pack()
    # The exporter names images after the file: make Godot extract env_apartment_door_<key>.png, like the kit.
    img.name = key
    img.filepath_raw = key + ".png"
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = img
    tn.interpolation = "Closest"
    nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    for n in ("Specular IOR Level", "Specular"):
        if n in bsdf.inputs:
            bsdf.inputs[n].default_value = 0.0
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit[0], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit[1]
    _mats[key] = m
    return m


class Mesh:
    """Boxes with kit-style planar UVs (projected along each face's main axis, tiled in metres)."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.keys = []

    def box(self, cx, cy, cz, sx, sy, sz, key):
        if key not in self.keys:
            self.keys.append(key)
        r = bmesh.ops.create_cube(self.bm, size=1.0)
        bmesh.ops.scale(self.bm, vec=(sx, sy, sz), verts=r["verts"])
        bmesh.ops.translate(self.bm, vec=(cx, cy, cz), verts=r["verts"])
        for f in {f for v in r["verts"] for f in v.link_faces}:
            f.material_index = self.keys.index(key)

    def finish(self, coll):
        bm = self.bm
        bm.normal_update()
        uv = bm.loops.layers.uv.verify()
        for f in bm.faces:
            t = TEX[self.keys[f.material_index]][1]
            n = f.normal
            for l in f.loops:
                p = l.vert.co
                if abs(n.z) >= abs(n.x) and abs(n.z) >= abs(n.y):
                    l[uv].uv = (p.x / t, p.y / t)
                elif abs(n.y) >= abs(n.x):
                    l[uv].uv = (p.x / t, p.z / t)
                else:
                    l[uv].uv = (p.y / t, p.z / t)
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for k in self.keys:
            me.materials.append(material(k))
        ob = bpy.data.objects.new(self.name, me)
        coll.objects.link(ob)
        return ob


# Porch: 2.2 wide, 1.2 deep, 3 tall. 1 m x 2.3 m opening; the door sits 0.15 m back from the front face,
# in front of a 1 m deep black recess (no interior: the camera never goes inside).
W, D, OPEN_W, OPEN_H, DOOR_Y = 2.2, 1.2, 1.0, 2.3, -0.45
HINGE = (OPEN_W / 2, DOOR_Y, 0.0)


def porch():
    m = Mesh("env_apartment_door")
    pier = (W - OPEN_W) / 2
    for s in (-1, 1):
        px = s * (OPEN_W / 2 + pier / 2)
        m.box(px, 0, OPEN_H / 2, pier, D, OPEN_H, "concrete")                  # piers
        m.box(px, -0.005, 0.1, pier + 0.04, D + 0.01, 0.2, "concrete_dark")    # plinth
    m.box(0, 0, OPEN_H + 0.35, W, D, 0.7, "concrete")                          # lintel
    m.box(0, -0.12, 3.06, W + 0.3, D + 0.24, 0.12, "concrete_dark")            # hood
    m.box(0, -D / 2 - 0.02, OPEN_H + 0.18, 0.3, 0.06, 0.36, "concrete_dark")   # keystone
    m.box(0, DOOR_Y - 0.07, 0.02, OPEN_W, 0.16, 0.04, "concrete_dark")         # threshold
    # black recess behind the door
    depth = D / 2 - DOOR_Y
    yc = (DOOR_Y + D / 2) / 2
    m.box(0, D / 2 - 0.03, OPEN_H / 2, OPEN_W, 0.06, OPEN_H, "black")
    for s in (-1, 1):
        m.box(s * (OPEN_W / 2 - 0.01), yc, OPEN_H / 2, 0.02, depth, OPEN_H, "black")
    m.box(0, yc, OPEN_H - 0.01, OPEN_W, depth, 0.02, "black")
    m.box(0, yc, 0.005, OPEN_W, depth, 0.01, "black")
    # lantern on the left pier, house number on the right
    lx = -(OPEN_W / 2 + pier / 2)
    m.box(lx, -D / 2 - 0.08, 2.0, 0.2, 0.14, 0.3, "lamp_glow")
    m.box(lx, -D / 2 - 0.08, 2.18, 0.26, 0.18, 0.06, "metal_dark")
    m.box(lx, -D / 2 - 0.02, 2.0, 0.06, 0.06, 0.06, "metal_dark")
    m.box(-lx, -D / 2 - 0.01, 1.6, 0.22, 0.02, 0.16, "metal_dark")
    return m


def door():
    """In hinge space: the leaf runs from the hinge toward -X."""
    m = Mesh("Door")
    w, h = OPEN_W - 0.03, OPEN_H - 0.06
    m.box(-w / 2 - 0.005, 0, 0.04 + h / 2, w, 0.06, h, "wood")
    m.box(-w / 2, -0.032, 1.78, 0.46, 0.008, 0.62, "dark_glass")    # window
    m.box(-w / 2, -0.034, 1.22, 0.28, 0.01, 0.06, "metal_dark")     # letterbox
    for s in (-1, 1):
        m.box(-w + 0.09, s * 0.07, 1.02, 0.05, 0.08, 0.05, "metal_dark")  # knobs
    return m


def action(ob, name, keys):
    """keys: [(frame, degrees)] about Z. Stashed on an NLA track so the exporter writes it as its own clip.
    The track is muted so it doesn't pose the door in the file (the exporter skips muted strips, not tracks)."""
    act = bpy.data.actions.new(name)
    ob.animation_data.action = act
    for frame, deg in keys:
        ob.rotation_euler = (0.0, 0.0, math.radians(deg))
        ob.keyframe_insert("rotation_euler", index=2, frame=frame)
    slot = getattr(ob.animation_data, "action_slot", None)
    ob.animation_data.action = None
    track = ob.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, keys[0][0], act)
    if slot is not None and hasattr(strip, "action_slot"):
        strip.action_slot = slot
    track.mute = True
    return act


def main():
    # Headless: build in the throwaway startup scene. In a live Blender: in a scene of its own, made the
    # window's scene for the export (exporting with a temp_override'd scene crashes the depsgraph in 5.2).
    win = None if bpy.app.background else bpy.context.window
    previous = win.scene if win else None
    if win is None:
        sc = bpy.context.scene
        for ob in list(sc.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
    else:
        old = bpy.data.scenes.get("ApartmentDoor")
        if old:
            for ob in list(old.objects):
                bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.scenes.remove(old)
        sc = bpy.data.scenes.new("ApartmentDoor")
        win.scene = sc
    sc.render.fps = FPS
    p = porch().finish(sc.collection)
    d = door().finish(sc.collection)
    d.parent = p
    d.location = HINGE
    d.animation_data_create()
    # out toward the street: +Z swings the free edge to -Y
    action(d, "door_open", [(1, 0.0), (5, 4.0), (26, 100.0)])
    action(d, "door_close", [(1, 100.0), (17, 3.0), (19, 0.0)])
    d.rotation_euler = (0.0, 0.0, 0.0)
    sc.frame_start, sc.frame_end, sc.frame_current = 1, 26, 1

    for ob in sc.objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = p
    bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format="GLB", export_yup=True,
                              export_apply=True, export_image_format="AUTO", export_animations=True,
                              export_animation_mode="ACTIONS")
    if previous is not None:
        win.scene = previous
    print("wrote", OUT)


main()
