"""Generates the night-street Godot area scenes (.tscn text) from the env_* GLB kit.
Run: python3 gen_levels.py <outdir>      (writes <outdir>/*.tscn)
World frame (Godot): road runs along Z; player enters from the SOUTH (+Z) heading north (-Z)."""
import math, os, random, sys

GLB = "res://Import/Environment/env_%s.glb"
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
AREAS = "res://scenes/areas/"


def bl(cx, cy, cz, sx, sy, sz):
    """Blender-space box (centre, size) -> Godot-space (centre, size)."""
    return (cx, cz, -cy, sx, sz, sy)


def ramp(edge_x, top, out, run=0.5, length=8.0, t=0.1):
    """Godot-space slab sloping from the ground at edge_x + out*run up to (edge_x, top), running along Z.
    Lets the player walk up a ledge too tall for the capsule to ride over. Returns (centre, size, roll)."""
    th = math.atan2(top, run)
    nx, ny = out * math.sin(th), math.cos(th)
    cx, cy = edge_x + out * run / 2 - nx * t / 2, top / 2 - ny * t / 2
    return (cx, cy, 0.0, math.hypot(run, top), t, length, -out * math.degrees(th))


# Sidewalk top (pavers box in build_kit.sidewalk): 0.225 m, too tall to walk up without a ramp.
CURB_TOP = 0.225

COL = {
    "terrace_a": [bl(0, 0, 3.4, 6, 7, 6.8)],
    "terrace_b": [bl(0, 0, 3.4, 6, 7, 6.8)],
    "terrace_c": [bl(0, 0, 5.1, 6, 7, 10.2)],
    "terrace_row": [bl(0, 0, 3.4, 18, 8, 6.8)],
    "shop_terrace": [bl(0, 0, 3.4, 12, 8, 6.8)],
    "tower_block_orange": [bl(0, 0, 12, 24, 12, 24)],
    "tower_block_green": [bl(0, 0, 15, 18, 12, 30)],
    "highrise_a": [bl(0, 0, 34, 12, 12, 68)],
    "highrise_b": [bl(0, 0, 23.8, 10, 14, 47.6)],
    "beacon_tower": [bl(0, 0, 22, 4, 4, 44)],
    "flyover": [bl(0, 0, 6, 10, 16, 1)] + [bl(px, py, 2.75, 1.4, 1.4, 5.5) for px in (-3.5, 3.5) for py in (-7.2, 7.2)]
               + [bl(-4.9, 0, 6.9, 0.3, 16, 0.8), bl(4.9, 0, 6.9, 0.3, 16, 0.8)],
    "alley_wall": [bl(0, 0, 3, 0.5, 6, 6)],
    "alley_wall_tall": [bl(0, 0, 6, 0.5, 6, 12)],
    "alley_wall_graffiti": [bl(0, 0, 3, 0.5, 6, 6)],
    "alley_mouth": [bl(-5, 0, 4, 6, 5, 8), bl(5, 0, 4, 6, 5, 8), bl(0, 0, 6.5, 4.2, 5, 3)],
    "alley_gate": [bl(-2.2, 0, 1, 1.6, 0.8, 2), bl(2.2, 0, 1, 1.6, 0.8, 2), bl(0, 0, 1.5, 6, 0.3, 3)],
    "street_lamp": [bl(0, 0, 3.2, 0.3, 0.3, 6.4)],
    "railing": [bl(0, 0, 0.55, 0.1, 4, 1.1)],
    "chainlink_fence": [bl(0, 0, 1.1, 0.1, 4, 2.2)],
    "wheelie_bin": [bl(0, 0, 0.55, 0.6, 0.7, 1.1)],
    "dumpster": [bl(0, 0, 0.8, 2, 1.1, 1.5)],
    "bench": [bl(0, 0, 0.45, 1.6, 0.5, 0.9)],
    "bollard": [bl(0, 0, 0.45, 0.2, 0.2, 0.9)],
    "parking_sign": [bl(0, 0, 1.2, 0.1, 0.1, 2.4)],
    "phone_box": [bl(0, 0, 1.25, 1, 1, 2.5)],
    "bus_shelter": [bl(0, 0.8, 1.2, 3, 0.1, 2.4)],
    "tree_a": [bl(0, 0, 2, 0.5, 0.5, 4)],
    "tree_b": [bl(0, 0, 1.2, 0.4, 0.4, 2.4)],
    "car_hatch": [bl(0, 0, 0.72, 1.7, 3.8, 1.45)],
    "billboard": [bl(0, 0, 3, 0.4, 0.4, 6)],
    "store_exterior": [bl(0, 0, 2, 12, 9, 4)],
    "sidewalk": [bl(0, 0, 0.075, 3, 8, 0.3), ramp(-1.5, CURB_TOP, -1), ramp(1.5, CURB_TOP, 1)],
    "fire_escape": [bl(0, 0, 6.5, 2.0, 1.1, 13.0)],
    "shelf_unit": [bl(0, 0, 0.9, 1.2, 0.5, 1.8)],
    "fridge_unit": [bl(0, 0, 1, 1.2, 0.7, 2)],
    "counter": [bl(0, 0, 0.6, 2.4, 0.7, 1.2)],
    "slush_machine": [bl(0, 0, 0.6, 0.9, 0.6, 1.2)],
    "store_interior": [bl(0, 0, -0.05, 12, 9, 0.1), bl(-6, 0, 1.6, 0.2, 9, 3.2), bl(6, 0, 1.6, 0.2, 9, 3.2),
                       bl(0, 4.5, 1.6, 12, 0.2, 3.2), bl(-5, -4.5, 1.6, 2, 0.2, 3.2), bl(2, -4.5, 1.6, 8, 0.2, 3.2)],
    "back_bar": [bl(0, 0, 1.0, 3.0, 0.5, 2.0)],
    "ice_chest": [bl(0, 0, 0.45, 1.6, 0.8, 0.9)],
    "clerk": [bl(0, 0, 0.9, 0.6, 0.5, 1.8)],
    "apartment_door": [bl(0, 0, 1.5, 2.2, 1.2, 3.0)],
}
WIDTH = {"terrace_a": 6, "terrace_b": 6, "terrace_c": 6, "terrace_row": 18, "shop_terrace": 12,
         "tower_block_orange": 24, "tower_block_green": 18, "highrise_a": 12, "highrise_b": 10,
         "alley_mouth": 16, "store_exterior": 12}
DEPTH = {"terrace_a": 7, "terrace_b": 7, "terrace_c": 7, "terrace_row": 8, "shop_terrace": 8,
         "tower_block_orange": 12, "tower_block_green": 12, "highrise_a": 12, "highrise_b": 14,
         "alley_mouth": 5, "store_exterior": 9}


def f(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"


def tf(x=0.0, y=0.0, z=0.0, yaw=0.0):
    a = math.radians(yaw)
    c, s = math.cos(a), math.sin(a)
    return "Transform3D(%s, 0, %s, 0, 1, 0, %s, 0, %s, %s, %s, %s)" % (f(c), f(s), f(-s), f(c), f(x), f(y), f(z))


def tf_roll(x=0.0, y=0.0, z=0.0, roll=0.0):
    """Rotation about Z (degrees; + tips local +X up)."""
    a = math.radians(roll)
    c, s = math.cos(a), math.sin(a)
    return "Transform3D(%s, %s, 0, %s, %s, 0, 0, 0, 1, %s, %s, %s)" % (f(c), f(-s), f(s), f(c), f(x), f(y), f(z))


class Scn:
    def __init__(self, root_name):
        self.root = root_name
        self.ext = {}
        self.subs = {}
        self.sub_lines = []
        self.lines = []
        self.names = {}
        self.parents = {"."}
        self.cnt = {}
        # per roadside (-1 west, 1 east): z spans with a building (or wall) on them, and the x of the
        # building fronts. street_bounds() closes everything else.
        self.cover = {-1: [], 1: []}
        self.line = {-1: 7.2, 1: 7.2}

    def ex(self, typ, path):
        k = (typ, path)
        if k not in self.ext:
            self.ext[k] = "e%d" % (len(self.ext) + 1)
        return self.ext[k]

    def sub(self, typ, body):
        k = (typ, body)
        if k not in self.subs:
            sid = "s%d" % (len(self.subs) + 1)
            self.subs[k] = sid
            self.sub_lines.append('[sub_resource type="%s" id="%s"]\n%s\n' % (typ, sid, body))
        return self.subs[k]

    def box(self, size):
        return self.sub("BoxShape3D", "size = Vector3(%s, %s, %s)" % tuple(f(v) for v in size))

    def uniq(self, parent, name):
        key = (parent, name)
        n = self.names.get(key, 0)
        self.names[key] = n + 1
        return name if n == 0 else "%s%d" % (name, n + 1)

    def node(self, name, typ=None, parent=None, props=(), inst=None, groups=None):
        if parent is None:
            head = '[node name="%s" type="%s"]' % (name, typ)
            path = "."
        else:
            name = self.uniq(parent, name)
            assert parent in self.parents, "missing parent " + parent
            g = ' groups=["%s"]' % '", "'.join(groups) if groups else ""
            if inst:
                head = '[node name="%s" parent="%s" instance=ExtResource("%s")%s]' % (name, parent, inst, g)
            else:
                head = '[node name="%s" type="%s" parent="%s"%s]' % (name, typ, parent, g)
            path = name if parent == "." else parent + "/" + name
        self.parents.add(path)
        self.lines.append(head)
        for p in props:
            self.lines.append(p)
        self.lines.append("")
        return path

    def text(self):
        out = ["[gd_scene format=3]", ""]
        for (typ, path), eid in self.ext.items():
            out.append('[ext_resource type="%s" path="%s" id="%s"]' % (typ, path, eid))
        out.append("")
        out.extend(self.sub_lines)
        out.extend(self.lines)
        return "\n".join(out).rstrip() + "\n"


# ---------------------------------------------------------------- placement helpers
# Big flat ground pieces: kept off the PS1 vertex-snap grid (PS1Renderer), or their huge triangles slide in
# steps and neighbouring tiles split apart at the seams.
NO_SNAP = {"road_straight", "road_plain", "underpass_road", "sidewalk", "grass_verge", "alley_floor"}
NO_SNAP_META = "metadata/ps1_no_vertex_snap = true"


def place(sc, asset, x, z, yaw=0.0, y=0.0, parent="Set", col=True):
    """Instance env_<asset>.glb; solid (StaticBody) when it has a collision spec."""
    gid = sc.ex("PackedScene", GLB % asset)
    boxes = COL.get(asset) if col else None
    props = ["transform = " + tf(x, y, z, yaw)] + ([NO_SNAP_META] if asset in NO_SNAP else [])
    if boxes:
        p = sc.node(asset, "StaticBody3D", parent, props)
        sc.node("Model", None, p, inst=gid)
        for i, b in enumerate(boxes):
            xf = tf_roll(b[0], b[1], b[2], b[6]) if len(b) > 6 else tf(b[0], b[1], b[2])
            sc.node("Col%d" % i, "CollisionShape3D", p,
                    ["transform = " + xf, "shape = SubResource(\"%s\")" % sc.box(b[3:6])])
        return p
    p = sc.node(asset, "Node3D", parent, props)
    sc.node("Model", None, p, inst=gid)
    return p


def omni(sc, parent, x, y, z, color=(1.0, 0.69, 0.38), energy=2.2, rng=11.0, name="Light"):
    sc.node(name, "OmniLight3D", parent,
            ["transform = " + tf(x, y, z), "light_color = Color(%s, %s, %s, 1)" % tuple(f(c) for c in color),
             "light_energy = " + f(energy), "omni_range = " + f(rng), "omni_attenuation = 1.3"])


def lamp(sc, x, z, side, parent="Set"):
    """side -1: pole on the west pavement, arm toward +X; +1: east pavement, arm toward -X."""
    yaw = -90.0 if side < 0 else 90.0
    p = place(sc, "street_lamp", x, z, yaw, parent=parent)
    omni(sc, p, 0, 5.9, -1.1, name="LampLight")
    cid = sc.ex("PackedScene", GLB % "lamp_cone")
    sc.node("Cone", None, p, ["transform = " + tf(0, 0, -1.1)], inst=cid)


def tiles(z0, z1, step=8.0):
    """Centres of step-long tiles covering z1..z0 (z0 south, z1 north)."""
    n = int(math.ceil((z0 - z1) / step))
    return [z0 - step / 2 - i * step for i in range(n)]


def street(sc, z0, z1, skip_east=None):
    for zc in tiles(z0, z1):
        place(sc, "road_straight", 0, zc, parent="Set")
        place(sc, "sidewalk", -5.7, zc, 180, parent="Set")
        if skip_east is None or not skip_east(zc):
            place(sc, "sidewalk", 5.7, zc, 0, parent="Set")


def row(sc, side, z_start, seq, setback=0.0):
    """Buildings in a row along one side of the road facing it. seq: (asset, width?) or (None, gap)."""
    zc = z_start
    out = []
    sc.line[side] = 7.2 + setback
    for asset, w in seq:
        if asset is None:
            zc -= w
            continue
        w = WIDTH.get(asset, w)
        d = DEPTH[asset]
        x = side * (7.2 + d / 2 + setback)
        place(sc, asset, x, zc - w / 2, 90 if side < 0 else -90, parent="Set")
        out.append((asset, x, zc - w / 2))
        sc.cover[side].append((zc - w, zc))
        zc -= w
    return out


def gaps(spans, lo, hi):
    """The parts of lo..hi (z) that no (z0, z1) span covers."""
    out, z = [], lo
    for z0, z1 in sorted(spans):
        if z0 > z:
            out.append((z, min(z0, hi)))
        z = max(z, z1)
    if z < hi:
        out.append((z, hi))
    return [(a, b) for a, b in out if b - a > 0.01]


def street_bounds(sc, south=46.0, north=-70.0, ends=(52.0, -74.0)):
    """Closes every stretch of roadside with no building on it (gaps in a row, the ends of the street) with
    an invisible wall and a chain-link fence, so the player can't walk round behind the buildings."""
    bs = sc.node("StreetBounds", "StaticBody3D", ".")
    for side in (-1, 1):
        x = side * sc.line[side]
        for z0, z1 in gaps(sc.cover[side], ends[1], ends[0]):
            sc.node("Wall", "CollisionShape3D", bs, ["transform = " + tf(x + side * 0.5, 5, (z0 + z1) / 2),
                                                     "shape = SubResource(\"%s\")" % sc.box((1, 12, z1 - z0))])
            a, b = max(z0, north), min(z1, south)
            for i in range(int(math.ceil((b - a) / 4.0 - 0.01))):
                place(sc, "chainlink_fence", x + side * 0.1, b - 2 - 4 * i, 0, parent="Set", col=False)


def alley(sc, side, zc, length=20.0, dead_end=True, x_from=None):
    """A 4 m alley running away from the road from z=zc. Returns the x of the dead end."""
    x0 = side * (7.2 + 5.0)
    n = int(math.ceil(length / 6.0))
    for i in range(n):
        x = x0 + side * (3 + 6 * i)
        place(sc, "alley_wall_tall" if i == n - 1 else "alley_wall", x, zc - 2.25, 90, parent="Set")
        place(sc, "alley_wall_graffiti" if i % 2 else "alley_wall", x, zc + 2.25, 90, parent="Set")
    for i in range(int(math.ceil(length / 8.0))):
        place(sc, "alley_floor", x0 + side * (4 + 8 * i), zc, 90, parent="Set", col=False)
    xe = x0 + side * (6 * n)
    if dead_end:
        place(sc, "alley_wall", xe + side * 0.25, zc, 0, parent="Set")
    return xe


def beams_and_world(sc, name, env, moon_color=(0.95, 0.4, 0.28), rain=True, seed=1, zlen=(48, -70), half=40,
                    skyline=True, beacon=(-46, -150)):
    """Root-level nodes shared by every street area."""
    sc.node(name, "Node3D")
    envid = sc.sub("Environment", env)
    sc.node("WorldEnvironment", "WorldEnvironment", ".", ["environment = SubResource(\"%s\")" % envid])
    # moonlight
    a, b = math.radians(30), math.radians(-48)
    ca, sa, cb, sb = math.cos(a), math.sin(a), math.cos(b), math.sin(b)
    # R = Ry(a) * Rx(b)
    r = [[ca, sa * sb, sa * cb], [0, cb, -sb], [-sa, ca * sb, ca * cb]]
    basis = ", ".join(f(v) for row_ in r for v in row_)
    sc.node("Moonlight", "DirectionalLight3D", ".",
            ["transform = Transform3D(%s, 0, 30, 0)" % basis, "light_color = Color(0.5, 0.58, 0.95, 1)",
             "light_energy = 0.75", "shadow_enabled = true", "directional_shadow_max_distance = 70.0"])
    sc.node("Set", "Node3D", ".")
    sc.node("Loot", "Node3D", ".")
    sc.node("Enemies", "Node3D", ".")
    # ground: collision + dark visible plane, sunk 8 cm below the road and pavements so they never z-fight
    gsh = sc.box((240, 1, 300))
    g = sc.node("Ground", "StaticBody3D", ".", ["transform = " + tf(0, -0.5, -12), NO_SNAP_META])
    sc.node("Col", "CollisionShape3D", g, ["shape = SubResource(\"%s\")" % gsh])
    pm = sc.sub("PlaneMesh", "size = Vector2(240, 300)")
    gm = sc.sub("StandardMaterial3D", "albedo_color = Color(0.06, 0.07, 0.08, 1)\nroughness = 1.0")
    sc.node("Visual", "MeshInstance3D", g, ["transform = " + tf(0, 0.42, 0), "mesh = SubResource(\"%s\")" % pm,
                                           "surface_material_override/0 = SubResource(\"%s\")" % gm])
    # bounds
    bs = sc.node("Bounds", "StaticBody3D", ".")
    for nm, (x, z, sx, sz) in {"West": (-half - 1, -14, 1, 140), "East": (half + 1, -14, 1, 140),
                               "South": (0, zlen[0] + 4, 2 * half + 4, 1), "North": (0, zlen[1] - 4, 2 * half + 4, 1)}.items():
        sc.node(nm, "CollisionShape3D", bs, ["transform = " + tf(x, 5, z), "shape = SubResource(\"%s\")" % sc.box((sx, 12, sz))])
    # moon (unshaded, ignores fog, kept out of the PS1 material swap)
    ms = sc.sub("SphereMesh", "radius = 9.0\nheight = 18.0\nradial_segments = 12\nrings = 6")
    mm = sc.sub("StandardMaterial3D", "shading_mode = 0\ndisable_fog = true\nalbedo_color = Color(%s, %s, %s, 1)" % tuple(f(c) for c in moon_color))
    sc.node("Moon", "MeshInstance3D", ".", ["transform = " + tf(-62, 58, -165), "mesh = SubResource(\"%s\")" % ms,
                                            "material_override = SubResource(\"%s\")" % mm, "cast_shadow = 0",
                                            "metadata/ps1_keep_materials = true"])
    if beacon:
        place(sc, "beacon_tower", beacon[0], beacon[1], 0, parent="Set")
    if skyline:
        rnd = random.Random(seed)
        for i in range(10):
            side = -1 if i % 2 == 0 else 1
            kind = rnd.choice(["highrise_a", "highrise_b"])
            x = side * rnd.uniform(40, 80)
            z = zlen[0] - 10 - i * rnd.uniform(14, 20)
            place(sc, kind, x, z, 90 if side < 0 else -90, parent="Set", col=False)
    if rain:
        rid = sc.ex("Script", "res://scripts/world/rain.gd")
        sc.node("Rain", "Node3D", ".", ["script = ExtResource(\"%s\")" % rid])


# The sky is the fog colour: fog_sky_affect 1 fades distant buildings into it (fog_sky_affect 0 renders a
# custom-colour background black under fog).
def night_env(fog=(0.07, 0.085, 0.22), density=0.014, ambient=(0.30, 0.33, 0.58), energy=0.95, bg=(0.07, 0.085, 0.22),
              brightness=1.18):
    return ("background_mode = 1\nbackground_color = Color(%s, %s, %s, 1)\nambient_light_source = 2\n"
            "ambient_light_color = Color(%s, %s, %s, 1)\nambient_light_energy = %s\ntonemap_mode = 0\n"
            "fog_enabled = true\nfog_mode = 0\nfog_light_color = Color(%s, %s, %s, 1)\nfog_light_energy = 1.0\n"
            "fog_density = %s\nfog_sky_affect = 1.0\nadjustment_enabled = true\nadjustment_brightness = %s\n"
            "adjustment_contrast = 1.1\nadjustment_saturation = 1.15"
            % (*[f(c) for c in bg], *[f(c) for c in ambient], f(energy), *[f(c) for c in fog], f(density),
               f(brightness)))


# ---------------------------------------------------------------- gameplay helpers
ENEMY = {"grunt": "res://scenes/enemy.tscn", "suit": "res://scenes/suit_guy.tscn", "monk": "res://scenes/floating_monk.tscn"}
TINT = {"red": (1.0, 0.5, 0.42), "purple": (0.58, 0.42, 0.72), "none": None}


def enemy(sc, kind, name, x, z, level, tint="red", yaw=0.0, y=0.15):
    eid = sc.ex("PackedScene", ENEMY[kind])
    props = ["transform = " + tf(x, y if kind != "monk" else 1.4, z, yaw), "level_override = %d" % level]
    t = TINT[tint]
    if t:
        props.append("body_tint = Color(%s, %s, %s, 1)" % tuple(f(c) for c in t))
    sc.node(name, None, "Enemies", props, inst=eid)


def sack(sc, name, x, z, item="potion", count=3, y=0.15):
    stk = sc.ex("Script", "res://scripts/commands/item_stack.gd")
    res = sc.ex("Resource", "res://resources/items/%s.tres" % item)
    sid = sc.sub("Resource", "script = ExtResource(\"%s\")\nitem = ExtResource(\"%s\")\ncount = %d" % (stk, res, count))
    pid = sc.ex("PackedScene", "res://scenes/pickup.tscn")
    sc.node(name, None, "Loot", ["transform = " + tf(x, y, z), "item = SubResource(\"%s\")" % sid], inst=pid)


def gates(sc, spawn_south_z=38.0, spawn_north_z=-58.0, north=None, south=None, extra_spawns=(), width=16.0):
    """North/south AreaExit gates + FromSouth/FromNorth spawns. north/south = (scene, spawn, name).
    width must span the street between the building lines so nobody walks round a gate."""
    sc.node("Gates", "Node3D", ".")
    sc.node("FromSouth", "Marker3D", "Gates", ["transform = " + tf(0, 0.25, spawn_south_z)], groups=["spawn_points"])
    sc.node("FromNorth", "Marker3D", "Gates", ["transform = " + tf(0, 0.25, spawn_north_z, 180)], groups=["spawn_points"])
    for nm, x, y, z, yaw in extra_spawns:
        sc.node(nm, "Marker3D", "Gates", ["transform = " + tf(x, y, z, yaw)], groups=["spawn_points"])
    scr = sc.ex("Script", "res://scripts/world/area_exit.gd")
    for nm, spec, z, yaw in (("NorthGate", north, -68.0, 0.0), ("SouthGate", south, 46.0, 180.0)):
        if spec:
            sc.node(nm, "Area3D", "Gates", ["transform = " + tf(0, 0, z, yaw), "script = ExtResource(\"%s\")" % scr,
                                           "target_scene = \"%s\"" % spec[0], "target_spawn = &\"%s\"" % spec[1],
                                           "area_name = \"%s\"" % spec[2], "size = Vector3(%s, 4, 1.5)" % f(width)])


def player(sc, x=0.0, z=38.0, yaw=0.0):
    pid = sc.ex("PackedScene", "res://scenes/player.tscn")
    sc.node("Player", None, ".", ["transform = " + tf(x, 0.25, z, yaw)], inst=pid)


def barrier(sc, z, parent="Set"):
    """Chain-link + concrete block closing the road (end of the street)."""
    for x in (-15.0, -9.0, -3.0, 3.0, 9.0, 15.0):
        place(sc, "alley_gate", x, z, 0, parent=parent)
    for x in (-21.0, 21.0):
        place(sc, "alley_gate", x, z, 0, parent=parent)


def parked(sc, x, z, yaw=0.0):
    place(sc, "car_hatch", x, z, yaw, parent="Set")


def finish(sc, fname):
    with open(os.path.join(OUT, fname), "w", newline="\n") as fh:
        fh.write(sc.text())


# ================================================================ AREA 1  Terrace Street
def area1():
    sc = Scn("TerraceStreet")
    beams_and_world(sc, "TerraceStreet", night_env(), seed=11)
    player(sc)
    street(sc, 48, -72)
    row(sc, -1, 40, [("terrace_row", 18), (None, 2), ("terrace_a", 6), ("terrace_b", 6), (None, 4),
                     ("terrace_c", 6), ("alley_mouth", 16), ("terrace_a", 6), ("terrace_row", 18)])
    row(sc, 1, 40, [("terrace_b", 6), ("terrace_a", 6), ("terrace_c", 6), (None, 8), ("terrace_row", 18),
                    ("terrace_b", 6), ("terrace_a", 6), (None, 2), ("terrace_c", 6), ("terrace_b", 6), ("terrace_a", 6)])
    # alley on the west side: z centre = 40-18-2-12-4-6-8 = -10.0 -> mouth centre
    azc = 40 - 18 - 2 - 6 - 6 - 4 - 6 - 8
    xe = alley(sc, -1, azc, length=24)
    place(sc, "dumpster", xe + 2.2, azc - 1.2, 0, parent="Set")
    place(sc, "wheelie_bin", xe + 1.0, azc + 1.4, 20, parent="Set")
    place(sc, "bin_bag", xe + 1.4, azc - 0.4, 0, parent="Set", col=False)
    # against the south wall (inner face azc + 2), railing toward the alley
    place(sc, "fire_escape", xe + 8.0, azc + 1.5, 180, parent="Set")
    omni(sc, "Set", xe + 7, 4.0, azc, color=(1, 0.65, 0.3), energy=1.6, rng=9, name="AlleyLight")
    sack(sc, "AlleyPotions", xe + 2.5, azc + 0.6)
    enemy(sc, "grunt", "AlleyGrunt", xe + 5, azc, 2, "red", 90)
    # street dressing
    for i, z in enumerate((36, 16, -4, -24, -44, -64)):
        lamp(sc, -6.8 if i % 2 == 0 else 6.8, z, -1 if i % 2 == 0 else 1)
    parked(sc, 2.6, 22, 0); parked(sc, -2.6, -2, 180); parked(sc, 2.6, -36, 0)
    for z in (30, 6, -18, -30, -52):
        place(sc, "tree_a", -6.7 if z % 2 == 0 else 6.7, z, 0, parent="Set")
    for z, x in ((26, -6.6), (-12, 6.6), (-40, -6.6)):
        place(sc, "wheelie_bin", x, z, 90 if x < 0 else -90, parent="Set")
    place(sc, "traffic_cone", 1.2, 10, 0, parent="Set", col=False); place(sc, "traffic_cone", 2.2, 10.8, 0, parent="Set", col=False)
    for i in range(3):
        place(sc, "bottle", 5.0 + 0.5 * i, 14 - 0.7 * i, 40 * i, y=0.225, parent="Set", col=False)
    place(sc, "bench", 6.4, -22, -90, parent="Set")
    place(sc, "parking_sign", -4.6, 28, 90, parent="Set")
    barrier(sc, -70)
    barrier(sc, 46)
    # enemies up the street
    enemy(sc, "grunt", "GruntA", -3, 24, 2, "red", 180)
    enemy(sc, "grunt", "GruntB", 3, 8, 2, "red", 180)
    enemy(sc, "grunt", "GruntC", -2, -14, 3, "purple", 180)
    enemy(sc, "grunt", "GruntD", 4, -34, 3, "red", 180)
    enemy(sc, "suit", "SuitE", 0, -52, 3, "none", 0)
    sack(sc, "StreetPotions", 6.3, 30, "potion", 2, y=0.3)
    # the player's front door, on the first house on the right; the new-game intro plays on it
    door = place(sc, "apartment_door", 7.2 - 0.6, 37.0, -90, y=CURB_TOP, parent="Set")
    omni(sc, door, 0, 2.6, 0.9, color=(1.0, 0.75, 0.45), energy=1.2, rng=6, name="PorchLight")
    sc.node("Intro", None, door, inst=sc.ex("PackedScene", "res://scenes/apartment_intro.tscn"))
    gates(sc, north=(AREAS + "area_estate.tscn", "FromSouth", "The Estate"))
    street_bounds(sc)
    finish(sc, "area_terrace_street.tscn")


# ================================================================ AREA 2  The Estate
def area2():
    sc = Scn("Estate")
    beams_and_world(sc, "Estate", night_env(fog=(0.07, 0.11, 0.18), ambient=(0.28, 0.36, 0.5)), seed=22, beacon=(52, -150))
    player(sc)
    street(sc, 48, -72)
    # west: three grass strips then the orange slab; east: green slab
    for zc in tiles(48, -72):
        for k in range(3):
            place(sc, "grass_verge", -8.7 - 3 * k, zc, 0, parent="Set", col=False)
            place(sc, "grass_verge", 8.7 + 3 * k, zc, 0, parent="Set", col=False)
    T = ["terrace_a", "terrace_b", "terrace_c"]
    row(sc, -1, 44, [(T[i % 3], 6) for i in range(6)] + [("tower_block_orange", 24)] + [(T[(i + 1) % 3], 6) for i in range(7)], setback=9.0)
    row(sc, 1, 44, [(T[i % 3], 6) for i in range(4)] + [("tower_block_green", 18)] + [(T[(i + 2) % 3], 6) for i in range(10)], setback=9.0)
    for i, z in enumerate((36, 18, 0, -18, -36, -56)):
        lamp(sc, -6.8 if i % 2 == 0 else 6.8, z, -1 if i % 2 == 0 else 1)
    for z in (30, 14, -8, -26, -40, -58):
        place(sc, "tree_a" if z % 4 == 2 else "tree_b", -10.5 if z % 3 else 10.5, z, 0, parent="Set")
        place(sc, "bush", 12.5 if z % 3 else -12.5, z + 3, 0, parent="Set", col=False)
    place(sc, "bus_shelter", 6.0, 20, -90, parent="Set")
    place(sc, "bench", -6.4, 2, 90, parent="Set"); place(sc, "bench", -6.4, -14, 90, parent="Set")
    parked(sc, -2.6, 32, 0); parked(sc, 2.6, -8, 180); parked(sc, -2.6, -44, 0)
    for z in (22, -10, -30):
        place(sc, "chainlink_fence", -14.5, z, 0, parent="Set"); place(sc, "chainlink_fence", -14.5, z - 4, 0, parent="Set")
    place(sc, "wheelie_bin", -6.6, 24, 90, parent="Set"); place(sc, "dumpster", 6.8, -22, -90, parent="Set")
    enemy(sc, "grunt", "GruntA", 3, 28, 3, "red", 180)
    enemy(sc, "suit", "SuitB", -3, 12, 3, "none", 180)
    enemy(sc, "grunt", "GruntC", 0, -2, 4, "purple", 180)
    enemy(sc, "grunt", "GruntD", -4, -22, 4, "red", 180)
    enemy(sc, "suit", "SuitE", 5, -40, 4, "none", 180)
    enemy(sc, "grunt", "GruntF", 0, -56, 4, "purple", 180)
    sack(sc, "EstateTonic", -8.0, -6.0, "tonic", 2, y=0.15)
    barrier(sc, -70)
    gates(sc, north=(AREAS + "area_shop_corner.tscn", "FromSouth", "Shop Corner"),
          south=(AREAS + "area_terrace_street.tscn", "FromNorth", "Terrace Street"), width=2 * sc.line[1] + 1)
    street_bounds(sc)
    finish(sc, "area_estate.tscn")


# ================================================================ AREA 3  Shop Corner (save orb + shop)
STORE_Z = -14.0


def area3():
    sc = Scn("ShopCorner")
    beams_and_world(sc, "ShopCorner", night_env(ambient=(0.32, 0.34, 0.6)), seed=33, beacon=(-60, -140))
    player(sc)
    street(sc, 48, -72)
    # east side: row, STORE, row.  Store centred on STORE_Z, 12 wide, front on the pavement line.
    row(sc, 1, 40, [("terrace_a", 6), ("terrace_b", 6), ("terrace_c", 6), ("terrace_a", 6), ("terrace_b", 6), ("terrace_c", 6), ("terrace_a", 6), ("terrace_b", 6)])
    zc = STORE_Z
    place(sc, "store_exterior", 7.2 + 4.5, zc, -90, parent="Set")
    sc.cover[1].append((zc - 6, zc + 6))
    row(sc, 1, STORE_Z - 6, [("shop_terrace", 12), ("terrace_a", 6), ("terrace_b", 6), (None, 4), ("terrace_c", 6), ("terrace_a", 6), ("terrace_b", 6)])
    # west side: brick row with a graffiti wall gap, an alley (loot), more row
    row(sc, -1, 44, [("terrace_b", 6), ("terrace_a", 6), ("terrace_c", 6), ("terrace_row", 18), ("alley_mouth", 16),
                     ("terrace_b", 6), ("terrace_c", 6), ("terrace_a", 6)])
    azc = 44 - 6 - 6 - 6 - 18 - 8
    xe = alley(sc, -1, azc, length=18)
    place(sc, "dumpster", xe + 2.2, azc + 1.2, 0, parent="Set"); place(sc, "bin_bag", xe + 1.4, azc - 1.0, 0, parent="Set", col=False)
    sack(sc, "AlleyTonic", xe + 2.5, azc - 0.6, "tonic", 2)
    enemy(sc, "suit", "AlleySuit", xe + 5, azc, 4, "none", 90)
    # SAVE ORB beside the shop door
    oid = sc.ex("PackedScene", "res://scenes/save_orb.tscn")
    sc.node("SaveOrb", None, ".", ["transform = " + tf(5.7, 0.3, zc + 9.0), "area_name = \"Shop Corner\""], inst=oid)
    # shop door -> interior
    scr = sc.ex("Script", "res://scripts/world/area_exit.gd")
    sc.node("Gates", "Node3D", ".")
    sc.node("FromSouth", "Marker3D", "Gates", ["transform = " + tf(0, 0.25, 38)], groups=["spawn_points"])
    sc.node("FromNorth", "Marker3D", "Gates", ["transform = " + tf(0, 0.25, -58, 180)], groups=["spawn_points"])
    sc.node("FromStore", "Marker3D", "Gates", ["transform = " + tf(4.9, 0.3, zc, 90)], groups=["spawn_points"])
    sc.node("ShopDoor", "Area3D", "Gates", ["transform = " + tf(6.4, 0, zc, -90), "script = ExtResource(\"%s\")" % scr,
                                           "target_scene = \"%sstore_612.tscn\"" % AREAS, "target_spawn = &\"FromDoor\"",
                                           "area_name = \"6-12\"", "size = Vector3(3, 3.2, 1.2)"])
    sc.node("NorthGate", "Area3D", "Gates", ["transform = " + tf(0, 0, -68), "script = ExtResource(\"%s\")" % scr,
                                            "target_scene = \"%sarea_underpass.tscn\"" % AREAS, "target_spawn = &\"FromSouth\"",
                                            "area_name = \"The Underpass\"", "size = Vector3(16, 4, 1.5)"])
    sc.node("SouthGate", "Area3D", "Gates", ["transform = " + tf(0, 0, 46, 180), "script = ExtResource(\"%s\")" % scr,
                                            "target_scene = \"%sarea_estate.tscn\"" % AREAS, "target_spawn = &\"FromNorth\"",
                                            "area_name = \"The Estate\"", "size = Vector3(16, 4, 1.5)"])
    # lamps (extra pair at the shop so the pocket reads as safe), props
    for i, z in enumerate((36, 14, STORE_Z + 6, STORE_Z - 8, -34, -56)):
        lamp(sc, -6.8 if i % 2 == 0 else 6.8, z, -1 if i % 2 == 0 else 1)
    omni(sc, "Set", 6.0, 3.2, STORE_Z, color=(1.0, 0.95, 0.8), energy=2.6, rng=10, name="ShopGlow")
    place(sc, "bench", 6.4, STORE_Z + 13, -90, parent="Set"); place(sc, "bin_bag", 6.6, STORE_Z - 9, 0, parent="Set", col=False)
    place(sc, "phone_box", -6.6, 26, 90, parent="Set"); place(sc, "bollard", 4.4, STORE_Z + 6, 0, parent="Set")
    place(sc, "bollard", 4.4, STORE_Z - 6, 0, parent="Set")
    parked(sc, -2.6, 20, 0); parked(sc, 2.6, -40, 180)
    for z in (30, -22, -48):
        place(sc, "tree_a", -6.7, z, 0, parent="Set")
    place(sc, "billboard", -10, -44, 90, parent="Set", col=True)
    enemy(sc, "grunt", "GruntA", -3, 26, 4, "red", 180)
    enemy(sc, "grunt", "GruntB", 3, 12, 4, "purple", 180)
    enemy(sc, "suit", "SuitC", -2, -30, 5, "none", 180)
    enemy(sc, "grunt", "GruntD", 4, -44, 5, "red", 180)
    enemy(sc, "grunt", "GruntE", -3, -56, 5, "purple", 180)
    barrier(sc, -70)
    street_bounds(sc)
    finish(sc, "area_shop_corner.tscn")


# ================================================================ AREA 4  The Underpass
def area4():
    sc = Scn("Underpass")
    beams_and_world(sc, "Underpass", night_env(fog=(0.12, 0.08, 0.17), ambient=(0.34, 0.3, 0.5), bg=(0.12, 0.08, 0.17)),
                    moon_color=(0.9, 0.28, 0.2), seed=44, beacon=(60, -150))
    player(sc)
    street(sc, 48, -72)
    row(sc, -1, 44, [("terrace_c", 6), ("terrace_b", 6), ("terrace_a", 6), ("terrace_row", 18)])
    row(sc, 1, 44, [("terrace_a", 6), ("terrace_c", 6), ("terrace_b", 6), ("terrace_row", 18)])
    # concrete flank walls + flyover across the road at z=-20 (three pieces, shared pillars)
    for x in (-16.0, 0.0, 16.0):
        place(sc, "flyover", x, -20, 90, parent="Set")
    for z in (5, -1, -7, -13, -25, -31, -37):
        place(sc, "alley_wall_tall", -9.9, z, 0, parent="Set")
        place(sc, "alley_wall_tall", 9.9, z, 0, parent="Set")
    for side in (-1, 1):
        sc.cover[side].append((-40, 8))  # the flank walls close this stretch
    place(sc, "alley_wall_graffiti", -9.3, -4, 0, parent="Set"); place(sc, "alley_wall_graffiti", 9.3, -34, 0, parent="Set")
    for z in (-8, -32):
        omni(sc, "Set", 0, 5.2, z, color=(0.75, 0.9, 1.0), energy=1.8, rng=12, name="UnderLight")
    omni(sc, "Set", 0, 5.2, -20, color=(0.75, 0.9, 1.0), energy=1.8, rng=12, name="UnderLight")
    # farther along: tower/highrise backdrop + billboard
    row(sc, -1, -40, [("highrise_b", 10), ("highrise_a", 12), ("terrace_a", 6), ("terrace_b", 6)])
    row(sc, 1, -40, [("highrise_a", 12), ("highrise_b", 10), ("terrace_b", 6), ("terrace_a", 6)])
    place(sc, "billboard", -14, -64, 90, parent="Set")
    for i, z in enumerate((38, 20, 2, -44, -58)):
        lamp(sc, -6.8 if i % 2 == 0 else 6.8, z, -1 if i % 2 == 0 else 1)
    parked(sc, 2.6, 30, 0); parked(sc, -2.6, 10, 180); parked(sc, 2.6, -50, 180)
    for z in (-12, -28):
        place(sc, "traffic_cone", 1.0, z, 0, parent="Set", col=False); place(sc, "traffic_cone", -1.4, z - 1.2, 0, parent="Set", col=False)
    place(sc, "dumpster", -6.9, -38, 90, parent="Set"); place(sc, "wheelie_bin", 6.6, 6, -90, parent="Set")
    enemy(sc, "grunt", "GruntA", -3, 30, 5, "red", 180)
    enemy(sc, "suit", "SuitB", 3, 14, 5, "none", 180)
    enemy(sc, "grunt", "GruntC", 0, -2, 6, "purple", 180)
    enemy(sc, "monk", "MonkD", 0, -20, 6, "none", 180)
    enemy(sc, "suit", "SuitE", -4, -46, 6, "none", 180)
    enemy(sc, "grunt", "GruntF", 3, -58, 6, "red", 180)
    sack(sc, "UnderpassPotions", 6.3, -24, "potion", 3, y=0.3)
    barrier(sc, -70)
    gates(sc, north=(AREAS + "area_downtown.tscn", "FromSouth", "Downtown"),
          south=(AREAS + "area_shop_corner.tscn", "FromNorth", "Shop Corner"))
    street_bounds(sc)
    finish(sc, "area_underpass.tscn")


# ================================================================ AREA 5  Downtown
def area5():
    sc = Scn("Downtown")
    beams_and_world(sc, "Downtown", night_env(fog=(0.1, 0.1, 0.22), ambient=(0.34, 0.36, 0.62), density=0.011), seed=55,
                    beacon=(-6, -158))
    player(sc)
    street(sc, 48, -72)
    row(sc, -1, 44, [("highrise_b" if i % 2 == 0 else "highrise_a", 10) for i in range(11)])
    row(sc, 1, 44, [("highrise_a" if i % 2 == 0 else "highrise_b", 10) for i in range(11)])
    for i, z in enumerate((38, 24, 10, -4, -18, -32, -46, -60)):
        lamp(sc, -6.8 if i % 2 == 0 else 6.8, z, -1 if i % 2 == 0 else 1)
    place(sc, "phone_box", -6.6, 30, 90, parent="Set"); place(sc, "phone_box", 6.6, -26, -90, parent="Set")
    place(sc, "bus_shelter", 6.0, 6, -90, parent="Set")
    place(sc, "billboard", 8, -12, -90, parent="Set"); place(sc, "billboard", -8, -52, 90, parent="Set")
    parked(sc, 2.6, 26, 0); parked(sc, -2.6, 0, 180); parked(sc, 2.6, -36, 0); parked(sc, -2.6, -58, 180)
    for z in (20, -10, -40):
        place(sc, "bollard", -4.5, z, 0, parent="Set"); place(sc, "bollard", 4.5, z - 2, 0, parent="Set")
        place(sc, "wheelie_bin", 6.7, z + 4, -90, parent="Set")
    enemy(sc, "suit", "SuitA", -3, 26, 6, "none", 180)
    enemy(sc, "grunt", "GruntB", 3, 16, 6, "purple", 180)
    enemy(sc, "monk", "MonkC", 0, 0, 7, "none", 180)
    enemy(sc, "suit", "SuitD", 4, -20, 7, "none", 180)
    enemy(sc, "grunt", "GruntE", -3, -34, 7, "red", 180)
    enemy(sc, "monk", "MonkF", 0, -52, 8, "none", 180)
    sack(sc, "DowntownTonic", -6.3, -8, "tonic", 3, y=0.3)
    barrier(sc, -70)
    gates(sc, north=("res://scenes/test_plaza.tscn", "FromSouth", "Times Square"),
          south=(AREAS + "area_underpass.tscn", "FromNorth", "The Underpass"))
    street_bounds(sc)
    finish(sc, "area_downtown.tscn")


# ================================================================ Shop interior
def store():
    """6-12 interior, 12 x 9 m (matches the exterior). Door in the front (+Z) wall at x=-3.
    Godot frame: x -6..6, z -4.5 (back) .. 4.5 (front glass)."""
    sc = Scn("Store612")
    env = ("background_mode = 1\nbackground_color = Color(0.02, 0.02, 0.03, 1)\nambient_light_source = 2\n"
           "ambient_light_color = Color(0.85, 0.88, 0.8, 1)\nambient_light_energy = 0.7\ntonemap_mode = 0")
    sc.node("Store612", "Node3D")
    sc.node("WorldEnvironment", "WorldEnvironment", ".", ["environment = SubResource(\"%s\")" % sc.sub("Environment", env)])
    sc.node("Set", "Node3D", ".")
    sc.node("Enemies", "Node3D", ".")
    sc.node("Loot", "Node3D", ".")
    place(sc, "store_interior", 0, 0, 0, parent="Set")
    # drinks fridges along the back wall
    for x in (-5.2, -4.0, -2.8, -1.6, -0.4):
        place(sc, "fridge_unit", x, -4.05, 0, parent="Set")
    # two double-sided aisles running front-to-back
    for ax in (-3.6, -0.6):
        for z in (-1.8, -0.6, 0.6):
            place(sc, "shelf_unit", ax - 0.25, z, -90, parent="Set")
            place(sc, "shelf_unit", ax + 0.25, z, 90, parent="Set")
    # till: two counter pieces along the east side, customer side facing -X
    place(sc, "counter", 3.6, -0.2, -90, parent="Set")
    place(sc, "counter", 3.6, 2.2, -90, parent="Set")
    place(sc, "hotdog_roller", 3.6, -0.9, -90, y=1.15, parent="Set", col=False)
    place(sc, "back_bar", 5.7, 1.0, -90, parent="Set")
    place(sc, "clerk", 4.6, 1.4, -90, parent="Set")
    place(sc, "slush_machine", 2.2, -4.05, 0, parent="Set", col=True)
    place(sc, "ice_chest", 1.0, 3.2, 0, parent="Set")
    for x in (-3.5, 0.0, 3.5):
        omni(sc, "Set", x, 2.9, 0, color=(1.0, 0.98, 0.9), energy=1.4, rng=7, name="Tube")
    omni(sc, "Set", -3.0, 2.4, 6.5, color=(1.0, 0.62, 0.3), energy=1.2, rng=6, name="StreetGlow")
    player(sc, -3.0, 2.0, 0)
    sc.node("Gates", "Node3D", ".")
    for nm in ("FromDoor", "FromSouth"):
        sc.node(nm, "Marker3D", "Gates", ["transform = " + tf(-3.0, 0.25, 2.0, 0)], groups=["spawn_points"])
    scr = sc.ex("Script", "res://scripts/world/area_exit.gd")
    sc.node("DoorOut", "Area3D", "Gates", ["transform = " + tf(-3.0, 0, 4.95, 180), "script = ExtResource(\"%s\")" % scr,
                                          "target_scene = \"%sarea_shop_corner.tscn\"" % AREAS, "target_spawn = &\"FromStore\"",
                                          "area_name = \"Shop Corner\"", "size = Vector3(2.2, 3, 1.0)",
                                          "haze_color = Color(1, 0.82, 0.35, 0.25)"])
    shop = sc.ex("Script", "res://scripts/world/shop_counter.gd")
    stock = sc.ex("Resource", "res://resources/shop/store_612_stock.tres")
    sc.node("ShopCounter", "Node3D", ".", ["transform = " + tf(2.9, 0, 1.0), "script = ExtResource(\"%s\")" % shop,
                                           "radius = 1.9", "stock = ExtResource(\"%s\")" % stock])
    menu = sc.ex("PackedScene", "res://scenes/shop_menu.tscn")
    sc.node("ShopMenu", None, ".", [], inst=menu)
    finish(sc, "store_612.tscn")


for fn in (area1, area2, area3, area4, area5, store):
    fn()
print("wrote", sorted(os.listdir(OUT)))
