"""Builds the night-street / alley / convenience-store kit in Blender (bpy) and exports GLBs.
Run: python3 build_kit.py <outdir>
Conventions: 1 unit = 1 m, origin at base centre, building/prop FRONT faces Blender -Y
(= +Z in Godot after glTF export), Z-up in Blender -> Y-up in the GLB."""
import math, os, sys, random
import bpy, bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import textures

OUT = sys.argv[1]
TEX = os.path.join(OUT, "textures")
GLB = os.path.join(OUT, "glb")
os.makedirs(GLB, exist_ok=True)
textures.make_all(TEX)
rnd = random.Random(7)

# key -> spec. tex: png name or None. tile: metres per texture repeat. off: uv offset.
M = {}


def mat(key, tex=None, tile=(2, 2), off=(0, 0), color=None, emit=None, alpha=False):
    M[key] = dict(tex=tex or key, tile=tile, off=off, color=color, emit=emit, alpha=alpha)


mat("brick_red", "facade_brick_red", tile=(12, 8))
mat("brick_dark", "facade_brick_dark", tile=(12, 8))
mat("brick_tan", "facade_brick_tan", tile=(12, 8))
mat("shopfront_brick", "facade_shopfront", tile=(12, 8))
mat("tower_orange", tile=(24, 24))
mat("tower_green", tile=(24, 24))
mat("highrise_glass", tile=(10, 40))
mat("highrise_warm", tile=(10, 40))
mat("concrete", tile=(4, 4))
mat("concrete_dark", tile=(4, 4))
mat("wall_graffiti", tile=(4, 4))
mat("road_lines", tile=(8, 8), off=(0.5, 0))
mat("road_plain", tile=(8, 8))
mat("pavers", tile=(2, 2))
mat("slabs", tile=(2, 2))
mat("grass", tile=(2, 2))
mat("leaves", tile=(3, 3))
mat("bark", tile=(1, 1))
mat("metal_dark", tile=(1, 1))
mat("metal_grey", tile=(1, 1))
mat("red", tile=(1, 1))
mat("green_dark", tile=(1, 1))
mat("bin_green", tile=(1, 1))
mat("orange", tile=(1, 1))
mat("white", tile=(1, 1))
mat("yellow", tile=(1, 1))
mat("bottle_red", tile=(1, 1))
mat("black", tile=(1, 1))
mat("car_green", tile=(1, 1))
mat("roof_slate", tile=(1, 1))
mat("roof_tile", tile=(1, 1))
mat("dark_glass", tile=(1, 1))
mat("wood", tile=(1, 1))
mat("lamp_glow", tile=(1, 1), emit=((1.0, 0.62, 0.22), 4.0))
mat("light_strip", tile=(1, 1), emit=((1.0, 1.0, 0.95), 3.0))
mat("lamp_cone", "lamp_glow", tile=(1, 1), emit=((1.0, 0.62, 0.22), 1.0), alpha=True)
mat("chainlink", tile=(2, 2), alpha=True)
mat("store_front", tile=(10.8, 3.0), off=(0.5, -0.05))
mat("store_sign", tile=(4.4, 1.7), off=(0.5, -3.75 / 1.7))
mat("store_stripes", tile=(1, 1))
mat("billboard_ad", tile=(6.8, 3.3), off=(0.5, -5.35 / 3.3))
mat("goods", tile=(0.7, 0.7))
mat("fridge_glass", tile=(1, 1), emit=((0.7, 0.9, 1.0), 0.6))
mat("checker_tile", tile=(0.8, 0.8))
mat("cig_wall", tile=(1.0, 1.0))
mat("menu_board", tile=(2.0, 0.75), off=(0.5, -2.2 / 0.75))
for _k in ("skin", "hair", "uniform", "trousers", "sausage", "bun", "door_mat"):
    mat(_k, tile=(1, 1))

_bmats = {}


def get_material(key):
    if key in _bmats:
        return _bmats[key]
    s = M[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    img = bpy.data.images.load(os.path.join(TEX, s["tex"] + ".png"))
    img.pack()
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = img
    tn.interpolation = "Closest"
    nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    for n in ("Specular IOR Level", "Specular"):
        if n in bsdf.inputs:
            bsdf.inputs[n].default_value = 0.0
    if s["emit"]:
        col, st = s["emit"]
        bsdf.inputs["Emission Color"].default_value = (*col, 1.0)
        bsdf.inputs["Emission Strength"].default_value = st
    if s["alpha"]:
        nt.links.new(tn.outputs["Alpha"], bsdf.inputs["Alpha"])
        for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(m, attr, val)
            except Exception:
                pass
        if s["tex"] == "lamp_glow":
            bsdf.inputs["Alpha"].default_value = 0.16
            for l in list(nt.links):
                if l.to_socket == bsdf.inputs["Alpha"]:
                    nt.links.remove(l)
    _bmats[key] = m
    return m


class B:
    def __init__(s, name):
        s.name = name
        s.bm = bmesh.new()
        s.keys = []

    def mi(s, key):
        if key not in s.keys:
            s.keys.append(key)
        return s.keys.index(key)

    def _tag(s, verts, key):
        i = s.mi(key)
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            f.material_index = i

    def box(s, cx, cy, cz, sx, sy, sz, key, rz=0.0):
        r = bmesh.ops.create_cube(s.bm, size=1.0)
        vs = r["verts"]
        bmesh.ops.scale(s.bm, vec=(sx, sy, sz), verts=vs)
        if rz:
            bmesh.ops.rotate(s.bm, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(rz, 3, "Z"), verts=vs)
        bmesh.ops.translate(s.bm, vec=(cx, cy, cz), verts=vs)
        s._tag(vs, key)

    def cyl(s, cx, cy, cz, r1, r2, h, segs, key):
        r = bmesh.ops.create_cone(s.bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h)
        vs = r["verts"]
        bmesh.ops.translate(s.bm, vec=(cx, cy, cz + h / 2), verts=vs)
        s._tag(vs, key)

    def sphere(s, cx, cy, cz, r, key, sub=1, sq=1.0):
        res = bmesh.ops.create_icosphere(s.bm, subdivisions=sub, radius=r)
        vs = res["verts"]
        bmesh.ops.scale(s.bm, vec=(1, 1, sq), verts=vs)
        bmesh.ops.translate(s.bm, vec=(cx, cy, cz), verts=vs)
        s._tag(vs, key)

    def roof(s, cx, cy, z, w, d, h, key, overhang=0.3):
        """gable roof, ridge along Y"""
        hw, hd = w / 2 + overhang, d / 2 + overhang
        v = [s.bm.verts.new(p) for p in [
            (cx - hw, cy - hd, z), (cx + hw, cy - hd, z), (cx + hw, cy + hd, z), (cx - hw, cy + hd, z),
            (cx, cy - hd, z + h), (cx, cy + hd, z + h)]]
        i = s.mi(key)
        for idx in [(0, 1, 4), (2, 3, 5), (1, 2, 5, 4), (3, 0, 4, 5), (3, 2, 1, 0)]:
            f = s.bm.faces.new([v[k] for k in idx])
            f.material_index = i

    def quad(s, p0, p1, p2, p3, key):
        vs = [s.bm.verts.new(p) for p in (p0, p1, p2, p3)]
        f = s.bm.faces.new(vs)
        f.material_index = s.mi(key)

    def finish(s, scene_coll):
        bm = s.bm
        bm.normal_update()
        uv = bm.loops.layers.uv.verify()
        for f in bm.faces:
            key = s.keys[f.material_index]
            tw, th = M[key]["tile"]
            ou, ov = M[key]["off"]
            n = f.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for l in f.loops:
                p = l.vert.co
                if az >= ax and az >= ay:
                    u, v = p.x / tw, p.y / th
                elif ay >= ax:
                    u, v = p.x / tw, p.z / th
                else:
                    u, v = p.y / tw, p.z / th
                l[uv].uv = (u + ou, v + ov)
        me = bpy.data.meshes.new(s.name)
        bm.to_mesh(me)
        bm.free()
        for k in s.keys:
            me.materials.append(get_material(k))
        ob = bpy.data.objects.new(s.name, me)
        scene_coll.objects.link(ob)
        return ob


# ------------------------------------------------------------------ assets
def terrace(name, w, d, floors, key, roof=True):
    b = B(name)
    h = 3.4 * floors
    b.box(0, 0, h / 2, w, d, h, key)
    if roof:
        b.roof(0, 0, h, w, d, 1.6, "roof_slate", 0.25)
        for cx in (-w / 4, w / 4):
            b.box(cx, 0, h + 1.6, 0.7, 0.7, 1.2, "brick_dark")  # chimney
    return b


def tower(name, w, d, floors, key):
    b = B(name)
    h = 3.0 * floors
    b.box(0, 0, h / 2, w, d, h, key)
    b.box(0, 0, h + 0.6, w * 0.6, d * 0.6, 1.2, "concrete_dark")  # lift/plant room
    b.box(w * 0.2, 0, h + 1.4, 0.25, 0.25, 1.6, "metal_dark")
    return b


def beacon_tower(name):
    b = B(name)
    b.box(0, 0, 22, 4.0, 4.0, 44, "concrete")
    for i in range(4):
        z = 10 + i * 9
        b.box(0, -2.02, z, 0.8, 0.1, 0.8, "bottle_red")  # red aircraft lights on face
    b.cyl(0, 0, 44, 3.4, 3.4, 1.2, 8, "concrete_dark")
    for z in (45.2, 47.2, 49.2, 51.2):
        b.cyl(0, 0, z, 3.6, 3.6, 0.8, 8, "metal_dark")  # dish/pod stack
    b.cyl(0, 0, 52, 1.0, 0.4, 5.0, 6, "metal_grey")
    b.box(0, 0, 57.5, 0.12, 0.12, 6, "bottle_red")
    # round logo panel (generic, not any real brand)
    b.cyl(0, -2.25, 36, 1.5, 1.5, 0.15, 12, "white")
    return b


def highrise_b(name, w, d, floors, key):
    b = B(name)
    h = 3.4 * floors
    b.box(0, 0, h / 2, w, d, h, key)
    b.box(0, 0, h + 0.5, w * 0.7, d * 0.7, 1.0, "concrete_dark")
    return b


def flyover(name):
    b = B(name)
    L = 16.0
    b.box(0, 0, 6, 10, L, 1.0, "concrete_dark")          # deck
    b.box(0, 0, 6.52, 8.6, L, 0.06, "road_lines")          # road surface
    for sx in (-4.9, 4.9):
        b.box(sx, 0, 6.9, 0.3, L, 0.8, "concrete")           # parapets
        b.box(sx, 0, 7.45, 0.1, L, 0.12, "metal_grey")       # rail
    for py in (-7.2, 7.2):
        for px in (-3.5, 3.5):
            b.box(px, py, 2.75, 1.4, 1.4, 5.5, "concrete")   # pillars at the ends so pieces share them
    return b


def underpass_road(name):
    b = B(name)
    L = 16.0
    b.box(0, 0, -0.1, 9, L, 0.2, "road_lines")
    for sx in (-5, 5):
        b.box(sx, 0, 1.6, 0.4, L, 3.4, "concrete")
    return b


def road(name, w=8.0, L=8.0, lines=True):
    b = B(name)
    b.box(0, 0, -0.1, w, L, 0.2, "road_lines" if lines else "road_plain")
    return b


def sidewalk(name, L=8.0, w=3.0):
    b = B(name)
    b.box(0, 0, 0.075, w, L, 0.3, "pavers")
    b.box(-w / 2 - 0.1, 0, 0.0, 0.2, L, 0.3, "concrete")  # curb
    return b


def grass_verge(name, L=8.0, w=3.0):
    b = B(name)
    b.box(0, 0, 0.05, w, L, 0.1, "grass")
    return b


def alley_wall(name, L=6.0, h=6.0, key="brick_dark"):
    b = B(name)
    b.box(0, 0, h / 2, 0.5, L, h, key)
    return b


def alley_floor(name, L=8.0, w=4.0):
    b = B(name)
    b.box(0, 0, -0.05, w, L, 0.1, "slabs")
    b.box(0, 0, -0.04, 0.6, L, 0.06, "concrete_dark")  # drain gutter
    return b


def alley_mouth(name):
    """Entrance between two brick buildings: arch beam, hanging lamp, bollards. Opening 4m wide, faces -Y."""
    b = B(name)
    b.box(-5.0, 0, 4.0, 6.0, 5.0, 8.0, "brick_dark")
    b.box(5.0, 0, 4.0, 6.0, 5.0, 8.0, "brick_red")
    b.box(0, 0, 6.5, 4.2, 5.0, 3.0, "brick_dark")            # bridge over the 4 m opening
    b.box(0, 0, -0.04, 4.0, 5.0, 0.08, "slabs")
    b.box(0, -2.55, 4.9, 3.0, 0.2, 0.2, "metal_dark")         # sign bar
    b.box(-1.8, -2.7, 0.5, 0.2, 0.2, 1.0, "metal_dark")       # bollards
    b.box(1.8, -2.7, 0.5, 0.2, 0.2, 1.0, "metal_dark")
    return b


def alley_gate(name):
    """Chain-link gate + concrete blocks closing a road/alley (area exit)."""
    b = B(name)
    b.box(-2.2, 0, 1.0, 1.6, 0.8, 2.0, "concrete")
    b.box(2.2, 0, 1.0, 1.6, 0.8, 2.0, "concrete")
    b.quad((-3.0, 0, 0.0), (3.0, 0, 0.0), (3.0, 0, 3.0), (-3.0, 0, 3.0), "chainlink")
    b.box(0, 0, 3.05, 6.2, 0.1, 0.1, "metal_grey")
    b.box(0, 0.4, 0.12, 6.0, 0.4, 0.24, "concrete_dark")
    return b


def fire_escape(name):
    b = B(name)
    for i in range(4):
        z = 3.0 * (i + 1)
        b.box(0, 0, z, 2.0, 1.1, 0.1, "metal_dark")
        b.box(0, -0.55, z + 0.5, 2.0, 0.05, 1.0, "metal_dark")
    for i in range(12):
        b.box(0.7, 0.0, 0.3 + i * 0.75, 0.5, 0.5, 0.06, "metal_dark", rz=0)
    b.box(-0.95, 0, 6.5, 0.08, 0.08, 13.0, "metal_dark")
    b.box(0.95, 0, 6.5, 0.08, 0.08, 13.0, "metal_dark")
    return b


def street_lamp(name):
    b = B(name)
    b.cyl(0, 0, 0, 0.15, 0.09, 6.4, 6, "metal_dark")
    b.box(0, 0.5, 6.35, 0.1, 1.1, 0.1, "metal_dark")
    b.box(0, 1.1, 6.25, 0.5, 0.9, 0.18, "metal_dark")
    b.box(0, 1.1, 6.14, 0.42, 0.74, 0.06, "lamp_glow")
    return b


def lamp_cone(name):
    b = B(name)
    r = bmesh.ops.create_cone(b.bm, cap_ends=False, cap_tris=False, segments=8, radius1=2.2, radius2=0.5, depth=6.0)
    bmesh.ops.translate(b.bm, vec=(0, 0, 3.0), verts=r["verts"])
    b._tag(r["verts"], "lamp_cone")
    return b


def lamp_head_pos(b):
    pass


def railing(name, L=4.0):
    b = B(name)
    n = int(L / 0.25)
    b.box(0, 0, 1.0, 0.06, L, 0.06, "metal_dark")
    b.box(0, 0, 0.12, 0.06, L, 0.06, "metal_dark")
    for i in range(n + 1):
        b.box(0, -L / 2 + i * (L / n), 0.55, 0.05, 0.05, 1.0, "metal_dark")
    return b


def chainlink_fence(name, L=4.0):
    b = B(name)
    b.quad((0, -L / 2, 0), (0, L / 2, 0), (0, L / 2, 2.2), (0, -L / 2, 2.2), "chainlink")
    for y in (-L / 2, L / 2):
        b.cyl(0, y, 0, 0.05, 0.05, 2.3, 5, "metal_grey")
    return b


def wheelie_bin(name):
    b = B(name)
    b.box(0, 0, 0.5, 0.6, 0.7, 1.0, "bin_green")
    b.box(0, 0, 1.03, 0.64, 0.74, 0.08, "metal_dark")
    b.box(0, -0.4, 0.12, 0.6, 0.06, 0.2, "black")
    return b


def dumpster(name):
    b = B(name)
    b.box(0, 0, 0.9, 2.0, 1.1, 1.3, "bin_green")
    b.box(0, 0, 1.6, 2.1, 1.2, 0.1, "metal_dark")
    return b


def cone(name):
    b = B(name)
    b.box(0, 0, 0.02, 0.4, 0.4, 0.04, "black")
    b.cyl(0, 0, 0.04, 0.16, 0.03, 0.55, 8, "orange")
    return b


def bottle(name):
    b = B(name)
    b.cyl(0, 0, 0, 0.05, 0.05, 0.22, 6, "bottle_red")
    b.cyl(0, 0, 0.22, 0.05, 0.02, 0.12, 6, "bottle_red")
    return b


def bin_bag(name):
    b = B(name)
    b.sphere(0, 0, 0.3, 0.35, "black", sq=0.9)
    return b


def bench(name):
    b = B(name)
    b.box(0, 0, 0.45, 1.6, 0.5, 0.06, "wood")
    b.box(0, 0.24, 0.8, 1.6, 0.06, 0.45, "wood")
    for sx in (-0.7, 0.7):
        b.box(sx, 0, 0.22, 0.08, 0.45, 0.44, "metal_dark")
    return b


def bollard(name):
    b = B(name)
    b.cyl(0, 0, 0, 0.1, 0.1, 0.9, 6, "metal_dark")
    return b


def parking_sign(name):
    b = B(name)
    b.cyl(0, 0, 0, 0.04, 0.04, 2.4, 5, "metal_grey")
    b.box(0, -0.05, 2.1, 0.5, 0.04, 0.7, "metal_dark")
    return b


def phone_box(name):
    b = B(name)
    b.box(0, 0, 1.2, 1.0, 1.0, 2.4, "red")
    for sy in (-0.51,):
        b.box(0, sy, 1.4, 0.7, 0.03, 1.5, "dark_glass")
    b.box(0, 0, 2.45, 1.1, 1.1, 0.1, "red")
    return b


def bus_shelter(name):
    b = B(name)
    b.box(0, 0.8, 1.2, 3.0, 0.08, 2.4, "dark_glass")
    b.box(0, 0, 2.5, 3.2, 1.8, 0.1, "metal_dark")
    for sx in (-1.5, 1.5):
        b.box(sx, 0, 1.25, 0.1, 0.1, 2.5, "metal_dark")
    b.box(0, 0.4, 0.45, 2.2, 0.4, 0.06, "wood")
    return b


def tree_a(name):
    b = B(name)
    b.cyl(0, 0, 0, 0.28, 0.18, 4.0, 6, "bark")
    for (x, y, z, r) in [(0, 0, 5.3, 2.4), (1.4, 0.5, 4.5, 1.6), (-1.3, -0.4, 4.6, 1.7), (0.3, -1.2, 6.2, 1.4)]:
        b.sphere(x, y, z, r, "leaves", sub=1, sq=0.85)
    return b


def tree_b(name):
    b = B(name)
    b.cyl(0, 0, 0, 0.22, 0.12, 2.4, 6, "bark")
    for i, (r, z) in enumerate([(1.8, 2.0), (1.4, 3.6), (0.9, 5.0)]):
        b.cyl(0, 0, z, r, 0.05, 2.2, 7, "leaves")
    return b


def bush(name):
    b = B(name)
    b.sphere(0, 0, 0.45, 0.8, "leaves", sq=0.7)
    return b


def car_hatch(name):
    b = B(name)
    b.box(0, 0, 0.55, 1.7, 3.8, 0.7, "car_green")
    b.box(0, 0.25, 1.15, 1.55, 2.0, 0.55, "car_green")
    b.box(0, -0.74, 1.15, 1.5, 0.05, 0.45, "dark_glass")      # windscreen faces -Y
    b.box(0, 1.25, 1.15, 1.5, 0.05, 0.45, "dark_glass")
    for sx in (-0.9, 0.9):
        b.box(sx, 0.25, 1.15, 0.05, 1.8, 0.4, "dark_glass")
    for sx in (-0.85, 0.85):
        for sy in (-1.2, 1.3):
            b.box(sx, sy, 0.3, 0.2, 0.6, 0.6, "black")
    return b


def billboard(name):
    b = B(name)
    b.box(0, 0, 3.0, 0.3, 0.3, 6.0, "metal_dark")
    b.box(0, 0, 7.0, 7.0, 0.3, 3.5, "metal_dark")
    b.quad((-3.4, -0.17, 5.35), (3.4, -0.17, 5.35), (3.4, -0.17, 8.65), (-3.4, -0.17, 8.65), "billboard_ad")
    return b


# ---- store
def store_exterior(name):
    b = B(name)
    W, D, H = 12.0, 9.0, 4.0
    b.box(0, 0, H / 2, W, D, H, "concrete")                              # shell
    b.box(0, 0, H + 0.25, W + 0.4, D + 0.4, 0.5, "white")                # parapet band
    b.box(0, -D / 2 - 0.05, H - 0.35, W + 0.2, 0.1, 0.3, "store_stripes")
    # lit glass front (two panes either side of a door) - store_front texture holds both
    b.quad((-W / 2 + 0.6, -D / 2 - 0.03, 0.15), (W / 2 - 0.6, -D / 2 - 0.03, 0.15),
           (W / 2 - 0.6, -D / 2 - 0.03, 3.1), (-W / 2 + 0.6, -D / 2 - 0.03, 3.1), "store_front")
    # name sign above the door
    b.quad((-2.2, -D / 2 - 0.6, 3.75), (2.2, -D / 2 - 0.6, 3.75), (2.2, -D / 2 - 0.6, 5.45), (-2.2, -D / 2 - 0.6, 5.45), "store_sign")
    b.box(0, -D / 2 - 0.4, 4.6, 4.5, 0.2, 1.9, "black")                  # sign backing
    # forecourt slab + awning
    b.box(0, -D / 2 - 0.6, 3.5, W, 1.4, 0.12, "white")
    for sx in (-W / 2 + 0.3, W / 2 - 0.3):
        b.box(sx, -D / 2 - 1.2, 1.75, 0.15, 0.15, 3.5, "metal_grey")
    return b


def store_interior(name):
    """Shell only (floor, walls, ceiling, lit strips, glass front with a door gap).
    Furniture is placed as separate kit pieces so it can be moved in Godot.
    12 x 9 m to match the exterior. Door gap: Blender x -4..-2 on the front (-Y) wall."""
    b = B(name)
    W, D, H = 12.0, 9.0, 3.2
    b.box(0, 0, -0.05, W, D, 0.1, "checker_tile")
    b.box(0, 0, H + 0.05, W, D, 0.1, "white")
    for sx in (-W / 2, W / 2):
        b.box(sx, 0, H / 2, 0.2, D, H, "white")
    b.box(0, D / 2, H / 2, W, 0.2, H, "white")
    # front: glass either side of the door, header over it, metal frame
    b.box(-5.0, -D / 2, H / 2, 2.0, 0.12, H, "dark_glass")
    b.box(2.0, -D / 2, H / 2, 8.0, 0.12, H, "dark_glass")
    b.box(-3.0, -D / 2, 2.75, 2.0, 0.14, 0.9, "white")
    for fx in (-4.0, -2.0):
        b.box(fx, -D / 2, 1.15, 0.1, 0.16, 2.3, "metal_grey")
    b.box(-3.0, -D / 2 + 0.6, 0.006, 1.8, 1.1, 0.012, "door_mat")
    b.box(0, -D / 2 + 0.02, 0.2, W, 0.08, 0.4, "store_stripes")  # kick stripe along the glass
    for sx in (-3.5, 0.0, 3.5):
        b.box(sx, 0, H - 0.04, 0.3, D - 1.5, 0.06, "light_strip")
    return b


def back_bar(name):
    """Cigarette / lotto wall behind the till, with a menu board on top. 3 m wide."""
    b = B(name)
    b.box(0, 0.1, 1.0, 3.0, 0.3, 2.0, "metal_grey")
    b.box(0, -0.06, 1.45, 2.9, 0.04, 1.0, "cig_wall")
    b.box(0, -0.08, 0.45, 3.0, 0.4, 0.9, "wood")
    b.quad((-1.0, -0.12, 2.2), (1.0, -0.12, 2.2), (1.0, -0.12, 2.95), (-1.0, -0.12, 2.95), "menu_board")
    b.box(0, 0.0, 2.57, 2.1, 0.16, 0.8, "black")
    return b


def hotdog_roller(name):
    """Counter-top roller grill (sits on a 1.1 m counter)."""
    b = B(name)
    b.box(0, 0, 0.05, 0.62, 0.42, 0.1, "metal_grey")
    for i in range(5):
        y = -0.15 + i * 0.075
        b.box(0, y, 0.13, 0.5, 0.045, 0.045, "sausage")
    b.box(0, 0.2, 0.2, 0.62, 0.03, 0.22, "metal_grey")
    b.box(0, -0.25, 0.08, 0.3, 0.06, 0.08, "bun")
    return b


def ice_chest(name):
    """Low ice-cream freezer with a glass lid."""
    b = B(name)
    b.box(0, 0, 0.4, 1.6, 0.8, 0.8, "white")
    b.box(0, 0, 0.82, 1.5, 0.7, 0.04, "fridge_glass")
    b.box(0, -0.405, 0.6, 1.5, 0.01, 0.16, "store_stripes")
    return b


def clerk(name):
    """Night-shift clerk, idle behind the till. ~1.8 m, faces -Y (Godot +Z)."""
    b = B(name)
    for sx in (-0.11, 0.11):
        b.box(sx, -0.03, 0.04, 0.15, 0.27, 0.08, "black")         # shoes
        b.box(sx, 0, 0.47, 0.17, 0.2, 0.8, "trousers")           # legs
        b.box(sx * 2.85, 0, 1.25, 0.12, 0.14, 0.36, "uniform")   # upper arms
        b.box(sx * 2.7, -0.17, 1.02, 0.1, 0.34, 0.1, "skin")     # forearms, resting forward
    b.box(0, 0, 1.15, 0.48, 0.26, 0.64, "uniform")              # torso
    b.box(0, -0.132, 1.24, 0.46, 0.01, 0.1, "store_stripes")     # uniform stripe
    b.box(0.12, -0.135, 1.36, 0.08, 0.01, 0.04, "white")         # name badge
    b.box(0, 0, 1.5, 0.1, 0.1, 0.08, "skin")                    # neck
    b.box(0, 0, 1.66, 0.24, 0.25, 0.27, "skin")                 # head
    for sx in (-0.055, 0.055):
        b.box(sx, -0.126, 1.68, 0.04, 0.01, 0.03, "black")       # eyes
    b.box(0, 0.03, 1.8, 0.25, 0.24, 0.05, "hair")
    b.box(0, 0.01, 1.84, 0.26, 0.27, 0.07, "orange")             # cap
    b.box(0, -0.17, 1.81, 0.22, 0.12, 0.025, "orange")           # cap brim
    return b


def shelf_unit(name):
    b = B(name)
    b.box(0, 0, 0.9, 1.2, 0.5, 1.8, "goods")
    b.box(0, 0.26, 0.9, 1.2, 0.04, 1.8, "metal_grey")
    return b


def fridge_unit(name):
    b = B(name)
    b.box(0, 0, 1.0, 1.2, 0.7, 2.0, "metal_grey")
    b.box(0, -0.36, 1.0, 1.1, 0.04, 1.8, "fridge_glass")
    return b


def counter(name):
    b = B(name)
    b.box(0, 0, 0.55, 2.4, 0.7, 1.1, "wood")
    b.box(0, 0, 1.12, 2.5, 0.8, 0.05, "metal_grey")
    b.box(0.6, 0, 1.3, 0.4, 0.3, 0.3, "black")
    return b


def slush_machine(name):
    b = B(name)
    b.box(0, 0, 0.6, 0.9, 0.6, 1.2, "metal_grey")
    for sx in (-0.22, 0.22):
        b.box(sx, -0.31, 1.5, 0.36, 0.1, 0.5, "red" if sx < 0 else "orange")
    return b


ASSETS = [
    # (name, builder, group)
    ("terrace_a", lambda n: terrace(n, 6.0, 7.0, 2, "brick_red"), "buildings"),
    ("terrace_b", lambda n: terrace(n, 6.0, 7.0, 2, "brick_dark"), "buildings"),
    ("terrace_c", lambda n: terrace(n, 6.0, 7.0, 3, "brick_tan"), "buildings"),
    ("terrace_row", lambda n: terrace(n, 18.0, 8.0, 2, "brick_red"), "buildings"),
    ("shop_terrace", lambda n: terrace(n, 12.0, 8.0, 2, "shopfront_brick"), "buildings"),
    ("tower_block_orange", lambda n: tower(n, 24.0, 12.0, 8, "tower_orange"), "buildings"),
    ("tower_block_green", lambda n: tower(n, 18.0, 12.0, 10, "tower_green"), "buildings"),
    ("highrise_a", lambda n: highrise_b(n, 12.0, 12.0, 20, "highrise_glass"), "buildings"),
    ("highrise_b", lambda n: highrise_b(n, 10.0, 14.0, 14, "highrise_warm"), "buildings"),
    ("beacon_tower", beacon_tower, "landmarks"),
    ("flyover", flyover, "road"),
    ("underpass_road", underpass_road, "road"),
    ("road_straight", lambda n: road(n), "road"),
    ("road_plain", lambda n: road(n, lines=False), "road"),
    ("sidewalk", sidewalk, "road"),
    ("grass_verge", grass_verge, "road"),
    ("alley_wall", alley_wall, "alley"),
    ("alley_wall_tall", lambda n: alley_wall(n, 6.0, 12.0, "brick_red"), "alley"),
    ("alley_wall_graffiti", lambda n: alley_wall(n, 6.0, 6.0, "wall_graffiti"), "alley"),
    ("alley_floor", alley_floor, "alley"),
    ("alley_mouth", alley_mouth, "alley"),
    ("alley_gate", alley_gate, "alley"),
    ("fire_escape", fire_escape, "alley"),
    ("street_lamp", street_lamp, "props"),
    ("lamp_cone", lamp_cone, "props"),
    ("railing", railing, "props"),
    ("chainlink_fence", chainlink_fence, "props"),
    ("wheelie_bin", wheelie_bin, "props"),
    ("dumpster", dumpster, "props"),
    ("traffic_cone", cone, "props"),
    ("bottle", bottle, "props"),
    ("bin_bag", bin_bag, "props"),
    ("bench", bench, "props"),
    ("bollard", bollard, "props"),
    ("parking_sign", parking_sign, "props"),
    ("phone_box", phone_box, "props"),
    ("bus_shelter", bus_shelter, "props"),
    ("tree_a", tree_a, "nature"),
    ("tree_b", tree_b, "nature"),
    ("bush", bush, "nature"),
    ("car_hatch", car_hatch, "props"),
    ("billboard", billboard, "props"),
    ("store_exterior", store_exterior, "store"),
    ("store_interior", store_interior, "store"),
    ("shelf_unit", shelf_unit, "store"),
    ("fridge_unit", fridge_unit, "store"),
    ("counter", counter, "store"),
    ("slush_machine", slush_machine, "store"),
    ("back_bar", back_bar, "store"),
    ("hotdog_roller", hotdog_roller, "store"),
    ("ice_chest", ice_chest, "store"),
    ("clerk", clerk, "store"),
]


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_yup=True,
                              export_apply=True, export_image_format="AUTO")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    coll = scene.collection
    objs = []
    for name, fn, group in ASSETS:
        ob = fn("env_" + name).finish(coll) if False else None
    for name, fn, group in ASSETS:
        bld = fn("env_" + name)
        ob = bld.finish(coll)
        ob["group"] = group
        export(ob, os.path.join(GLB, "env_%s.glb" % name))
        objs.append((ob, group))
    # lay everything out on a sheet for the .blend + preview
    xs = {}
    for ob, group in objs:
        x = xs.get(group, 0.0)
        gi = ["buildings", "landmarks", "road", "alley", "props", "nature", "store"].index(group)
        dims = ob.dimensions
        ob.location = (x + dims.x / 2, gi * 40.0, 0)
        xs[group] = x + dims.x + 6
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "env_street_kit.blend"))
    print("ASSETS", len(objs))


main()
