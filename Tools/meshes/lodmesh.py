"""Deus Ex (UE1, v68) LodMesh reader: exports a frame of each mesh as OBJ + MTL,
with its skins as PNG. Deus Ex stores vertices as 3 x int16 (+ pad)."""
import struct, sys, os, re
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'esrgan'))
import upkg
from upkg import R


def lazy(r, pkg):
    if pkg.ver > 61:
        r.i32()          # skip position
    return r.ci()


def read_lodmesh(pkg, e):
    r = pkg.body(e); pr = pkg.props(r)
    r.raw(25)            # FBox
    r.raw(16)            # FSphere
    n = lazy(r, pkg)
    verts = [struct.unpack_from('<hhh', r.raw(8)) for _ in range(n)]
    n = lazy(r, pkg); r.raw(n * 20)                     # tris (unused in LodMesh)
    n = r.ci(); seqs = []
    for _ in range(n):
        nm = pkg.names[r.ci()]; r.ci(); sf = r.i32(); nf = r.i32()
        k = r.ci()
        for _ in range(k): r.raw(4); r.ci()
        r.raw(4); seqs.append((nm, sf, nf))
    n = lazy(r, pkg); r.raw(n * 8)                      # connects
    r.raw(25); r.raw(16)
    n = lazy(r, pkg); r.raw(n * 4)                      # vertlinks
    n = r.ci(); texs = [r.ci() for _ in range(n)]
    n = r.ci(); r.raw(n * 25)
    n = r.ci(); r.raw(n * 16)
    framev = r.i32(); frames = r.i32()
    r.raw(8)
    scale = struct.unpack('<fff', r.raw(12)); origin = struct.unpack('<fff', r.raw(12))
    rot = struct.unpack('<iii', r.raw(12))
    r.raw(8)
    n = r.ci(); r.raw(n * 4)                            # TextureLOD
    # ULodMesh
    n = r.ci(); r.raw(n * 2)                            # CollapsePointThus
    n = r.ci(); r.raw(n * 2)                            # FaceLevel
    n = r.ci(); faces = [struct.unpack_from('<HHHH', r.raw(8)) for _ in range(n)]
    n = r.ci(); r.raw(n * 2)                            # CollapseWedgeThus
    n = r.ci(); wedges = [struct.unpack_from('<HBB', r.raw(4)) for _ in range(n)]
    n = r.ci(); mats = [struct.unpack_from('<Ii', r.raw(8)) for _ in range(n)]
    n = r.ci(); sfaces = [struct.unpack_from('<HHHH', r.raw(8)) for _ in range(n)]
    modelv = r.i32(); specialv = r.i32()
    return dict(verts=verts, framev=framev, frames=frames, scale=scale, origin=origin, rot=rot,
                faces=faces, wedges=wedges, mats=mats, texs=texs, seqs=seqs,
                specialv=specialv, modelv=modelv, sfaces=len(sfaces))


def export(pkg, e, m, out, frame=0, texcache={}):
    name = e['name']
    fv = m['framev']; sx, sy, sz = m['scale']
    base = frame * fv
    tex_names = []
    for ti, ref in enumerate(m['texs']):
        tn = pkg.objname(ref) if ref else None
        if ref > 0 and tn not in texcache:
            im, _ = pkg.texture(pkg.exports[ref - 1])
            if im is not None:
                im.save(os.path.join(out, 'textures', tn + '.png'))
            texcache[tn] = im
        tex_names.append((tn, ref > 0 and texcache.get(tn) is not None))
    sizes = {}
    for tn, ok in tex_names:
        if ok: sizes[tn] = texcache[tn].size
    # one material per (skin, poly flags) pair, so masked / translucent faces
    # stay separate from solid ones that share the same skin
    def mname(ti, pf):
        return '%s_m%d' % (name, ti) if pf == 0 else '%s_m%d_%x' % (name, ti, pf)
    used = []
    for a, b, c, mi in m['faces']:
        pf, ti = m['mats'][mi] if mi < len(m['mats']) else (0, 0)
        if (ti, pf) not in used: used.append((ti, pf))
    with open(os.path.join(out, name + '.mtl'), 'w') as f:
        for ti, pf in used:
            tn, ok = tex_names[ti] if ti < len(tex_names) else (None, False)
            f.write('newmtl %s\nKd 1 1 1\n' % mname(ti, pf))
            f.write('# polyflags 0x%x\n' % pf)
            if ok: f.write('map_Kd textures/%s.png\n' % tn)
            elif tn: f.write('# skin %s lives in another package\n' % tn)
            f.write('\n')
    with open(os.path.join(out, name + '.obj'), 'w') as f:
        f.write('# Deus Ex LodMesh %s, frame %d of %d (Unreal axes, mesh scale applied)\n' % (name, frame, m['frames']))
        f.write('# anim sequences: %s\nmtllib %s.mtl\n' % (', '.join('%s(%d)' % (a, b) for a, b, c in m['seqs']), name))
        # only the vertices this mesh's wedges use, special (weapon) verts skipped
        for x, y, z in m['verts'][base + m['specialv']: base + fv]:
            f.write('v %g %g %g\n' % (x * sx, y * sy, z * sz))
        for vi, u, v in m['wedges']:
            mi = 0
            f.write('vt %g %g\n' % (u / 255.0, 1 - v / 255.0))
        cur = None
        for a, b, c, mi in m['faces']:
            pf, ti = m['mats'][mi] if mi < len(m['mats']) else (0, 0)
            if (ti, pf) != cur:
                f.write('usemtl %s\n' % mname(ti, pf)); cur = (ti, pf)
            idx = [m['wedges'][w][0] + 1 for w in (a, b, c)]
            # UE1 winds clockwise: flip for OBJ
            f.write('f %d/%d %d/%d %d/%d\n' % (idx[0], a + 1, idx[2], c + 1, idx[1], b + 1))


if __name__ == '__main__':
    pkg = upkg.Package(sys.argv[1]); out = sys.argv[2]
    pat = re.compile(sys.argv[3] if len(sys.argv) > 3 else '.', re.I)
    os.makedirs(os.path.join(out, 'textures'), exist_ok=True)
    ok = bad = 0
    for e in pkg.exports:
        if pkg.clsname(e) != 'LodMesh' or not pat.search(e['name']): continue
        try:
            m = read_lodmesh(pkg, e)
            export(pkg, e, m, out)
            ok += 1
        except Exception as ex:
            print('FAIL', e['name'], ex); bad += 1
    print('exported', ok, 'failed', bad)
