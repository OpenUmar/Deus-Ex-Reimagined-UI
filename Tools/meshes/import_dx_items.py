# Deus Ex item mesh importer for Blender (4.2+ / 5.x)
# Open Blender > Scripting tab > Open this file > Run Script.
#
# Fixes the exported OBJs on import:
#   * Unreal is left-handed and Z-up: the mesh is mirrored back (so text and
#     decals read correctly) and stood upright, which also turns the faces
#     right side out (they import inside-out otherwise, hence the odd shading).
#   * Follows each material's Unreal poly flags (written by lodmesh.py into the
#     .mtl): masked faces cut out their black pixels, translucent faces are
#     additive glows, unlit faces glow at full brightness, solid faces stay
#     opaque. Black "mask" faces (muzzle flash cards) are deleted.
#   * Effect skins kept in other packages (biocell core, nano glows) are
#     procedural in game; they glow in their own palette's colours.
#   * Smooth-by-angle shading and a matte material instead of shiny plastic.
#   * Uses the 4x upscaled skins from textures_hd when that folder exists.
#   * Switches the viewport to Material Preview so the textures show.

import bpy, os, math, glob

# ---- settings -----------------------------------------------------------
FOLDER  = os.path.expanduser(r"~\Downloads\DeusEx_ItemMeshes")
ONLY    = []        # e.g. ["MedKit", "GlockPickup"]; empty = every OBJ
SKIP    = ("Fragment", "Rockchip", "Blood", "Effect", "FX", "Spit",
           "Comet", "Tracer", "LaserBeam", "InvisibleWeapon", "TestBox")
SKIP_FIRST_PERSON = True   # bare weapon names / *POV are hand-held models
GRID_SPACING = 45.0
CLEAR_SCENE  = True
USE_HD       = True    # use the 4x PBRify skins in textures_hd when present
# --------------------------------------------------------------------------

MASK_TEX = ("BlackMaskTex",)

# Effect skins live in Textures/Effects.utx and are procedural (the engine
# animates them live), so they have no stored picture. They are drawn
# additively. Order of preference: textures/<skin>.png, then the effect's own
# palette (textures/<skin>_pal.png) run through a noise pattern, then a flat
# colour from the table below.
FX_COLOURS = {   # fallback only; taken from each effect's own palette
    "BioCell_SFX": (0.25, 0.25, 1.0), "Nano_SFX": (0.5, 0.51, 1.0),
    "Nano_SFX_A": (0.28, 0.69, 1.0), "Wepn_EMPG_SFX": (0.84, 0.84, 1.0),
    "Wepn_Prod_FX": (0.84, 0.84, 1.0), "Wepn_Prifle_SFX": (0.38, 1.0, 0.19),
    "WEPN_NESword_SFX": (0.5, 0.51, 1.0), "WavyBlade": (0.42, 0.75, 1.0),
    "ambrosia_SFX": (0.37, 1.0, 0.08), "Gas_Tear_A": (1.0, 1.0, 1.0),
    "OneFlame_J": (1.0, 0.99, 0.72), "OneFlame_G": (1.0, 1.0, 0.51),
    "RadAttack": (0.98, 1.0, 0.93), "flmethrwr_flme": (0.84, 0.84, 1.0),
}
FX_STRENGTH = 3.0

PF_MASKED, PF_TRANSLUCENT, PF_MODULATED, PF_UNLIT = 0x2, 0x4, 0x40, 0x400000

def mtl_info(obj_path):
    """material name -> dict(flags, skin, fx) read from the .mtl"""
    mtl = os.path.splitext(obj_path)[0] + ".mtl"
    out, cur = {}, None
    if not os.path.exists(mtl):
        return out
    for line in open(mtl, encoding="utf-8", errors="ignore"):
        line = line.strip()
        if line.startswith("newmtl "):
            cur = out.setdefault(line[7:].strip(), {"flags": 0, "skin": None, "fx": None})
        elif cur is None:
            continue
        elif line.startswith("# polyflags "):
            cur["flags"] = int(line.split()[2], 16)
        elif line.startswith("map_Kd "):
            cur["skin"] = os.path.splitext(os.path.basename(line[7:].strip()))[0]
        elif line.startswith("# skin "):
            cur["fx"] = line[7:].split()[0]
    return out

def skin_path(folder, skin):
    hd = os.path.join(folder, "textures_hd", skin + ".png")
    if USE_HD and os.path.exists(hd):
        return hd
    p = os.path.join(folder, "textures", skin + ".png")
    return p if os.path.exists(p) else None

def make_glow(mat, skin, folder, image=None, strength=None):
    mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    add = nt.nodes.new("ShaderNodeAddShader")
    em = nt.nodes.new("ShaderNodeEmission")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em.inputs["Strength"].default_value = FX_STRENGTH if strength is None else strength
    png = image or os.path.join(folder, "textures", skin + ".png")
    pal = os.path.join(folder, "textures", skin + "_pal.png")
    if not image and os.path.exists(pal) and not os.path.exists(png):
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 6.0
        noise.inputs["Detail"].default_value = 4.0
        xyz = nt.nodes.new("ShaderNodeCombineXYZ")
        xyz.inputs["Y"].default_value = 0.5
        ramp = nt.nodes.new("ShaderNodeTexImage")
        ramp.image = bpy.data.images.load(pal, check_existing=True)
        ramp.extension = 'EXTEND'
        nt.links.new(noise.outputs["Fac"], xyz.inputs["X"])
        nt.links.new(xyz.outputs[0], ramp.inputs["Vector"])
        nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    elif os.path.exists(png):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(png, check_existing=True)
        nt.links.new(tex.outputs["Color"], em.inputs["Color"])
    else:
        c = FX_COLOURS.get(skin, (0.5, 0.8, 1.0))
        em.inputs["Color"].default_value = (*c, 1.0)
    nt.links.new(em.outputs[0], add.inputs[0])
    nt.links.new(tr.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], outn.inputs["Surface"])
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = 'BLENDED'
    else:
        mat.blend_method = 'BLEND'

def wanted(name, all_names):
    if ONLY:
        return name in ONLY
    if any(s in name for s in SKIP):
        return False
    if SKIP_FIRST_PERSON:
        if name.endswith("POV"):
            return False
        if name + "Pickup" in all_names or name + "3rd" in all_names:
            return False                     # first-person version
        if name.endswith("3rd") and name[:-3] + "Pickup" in all_names:
            return False                     # Pickup is the same model
    return True

def fix_material(mat, flags, image):
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    tex = next((n for n in nt.nodes if n.type == 'TEX_IMAGE'), None)
    if bsdf:
        bsdf.inputs["Roughness"].default_value = 0.55
        bsdf.inputs["Metallic"].default_value = 0.0
        spec = bsdf.inputs.get("Specular IOR Level")
        if spec: spec.default_value = 0.35
    if tex and image:
        tex.image = bpy.data.images.load(image, check_existing=True)
    masked = bool(flags & PF_MASKED)
    if tex and tex.image and bsdf:
        tex.interpolation = 'Linear'
        tex.image.alpha_mode = 'STRAIGHT' if masked else 'CHANNEL_PACKED'
        for l in list(bsdf.inputs["Alpha"].links):
            nt.links.remove(l)
        if masked:                     # only masked faces cut out black
            nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        else:
            bsdf.inputs["Alpha"].default_value = 1.0
        if flags & PF_UNLIT:           # drawn fullbright in game
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 1.0
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = 'DITHERED'
    elif masked:
        mat.blend_method = 'CLIP'

def is_mask(info):
    return bool(info and info["skin"] and any(m in info["skin"] for m in MASK_TEX))

def fix_object(o, obj_path):
    me = o.data
    info = mtl_info(obj_path)
    folder = os.path.dirname(obj_path)
    def inf(m):
        return info.get(m.name) or info.get(m.name.rsplit(".", 1)[0])
    # delete faces that use a mask material
    mask_ids = {i for i, m in enumerate(me.materials) if m and is_mask(inf(m))}
    if mask_ids:
        import bmesh
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in mask_ids],
                         context='FACES')
        bm.to_mesh(me); bm.free()
    for m in me.materials:
        if not m:
            continue
        d = inf(m) or {"flags": 0, "skin": None, "fx": None}
        img = skin_path(folder, d["skin"]) if d["skin"] else None
        if d["fx"]:
            make_glow(m, d["fx"], folder)
        elif d["flags"] & (PF_TRANSLUCENT | PF_MODULATED) and img:
            make_glow(m, d["skin"], folder, image=img, strength=1.0)
        else:
            fix_material(m, d["flags"], img)
    # mirror back to right-handed; applying the -1 scale also flips the winding
    o.rotation_euler = (0, 0, 0)
    o.scale = (1, -1, 1)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Unreal's winding is the reverse of Blender's, so the faces come in
    # inside-out; flip them so the normals point outward
    import bmesh
    bm = bmesh.new(); bm.from_mesh(me)
    if bm.calc_volume(signed=True) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(me)
    bm.free()
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    except Exception:
        bpy.ops.object.shade_smooth()
    o.select_set(False)

def main():
    if CLEAR_SCENE:
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete()
    files = sorted(glob.glob(os.path.join(FOLDER, "*.obj")))
    names = {os.path.splitext(os.path.basename(f))[0] for f in files}
    todo = [f for f in files if wanted(os.path.splitext(os.path.basename(f))[0], names)]
    cols = max(1, math.ceil(math.sqrt(len(todo))))
    for i, f in enumerate(todo):
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.wm.obj_import(filepath=f, forward_axis='Y', up_axis='Z')
        for o in bpy.context.selected_objects:
            o.name = os.path.splitext(os.path.basename(f))[0]
            fix_object(o, f)
            o.location = ((i % cols) * GRID_SPACING, -(i // cols) * GRID_SPACING, 0)
    # viewport: Material Preview, and a clip range that suits these sizes
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type == 'VIEW_3D':
            for sp in area.spaces:
                if sp.type == 'VIEW_3D':
                    sp.shading.type = 'MATERIAL'
                    sp.clip_end = 100000
    print(f"Imported {len(todo)} item meshes from {FOLDER}")

main()
