"""Minimal Unreal Engine 1 (Deus Ex) package reader: lists objects and exports
Texture objects (P8 + palette, RGBA8) to PNG."""
import struct, sys, os, re
from PIL import Image


class R:
    def __init__(s, b, p=0): s.b, s.p = b, p
    def u8(s): v = s.b[s.p]; s.p += 1; return v
    def i32(s): v = struct.unpack_from('<i', s.b, s.p)[0]; s.p += 4; return v
    def u32(s): v = struct.unpack_from('<I', s.b, s.p)[0]; s.p += 4; return v
    def u16(s): v = struct.unpack_from('<H', s.b, s.p)[0]; s.p += 2; return v
    def ci(s):
        b0 = s.u8(); neg = b0 & 0x80; v = b0 & 0x3F
        if b0 & 0x40:
            sh = 6
            while True:
                b = s.u8(); v |= (b & 0x7F) << sh; sh += 7
                if not b & 0x80: break
        return -v if neg else v
    def raw(s, n): v = s.b[s.p:s.p + n]; s.p += n; return v


class Package:
    def __init__(s, path):
        s.b = open(path, 'rb').read(); r = R(s.b)
        assert r.u32() == 0x9E2A83C1
        s.ver = r.u16(); r.u16(); r.u32()
        nc, no, ec, eo, ic, io = (r.u32() for _ in range(6))
        r.p = no; s.names = []
        for _ in range(nc):
            if s.ver >= 64:
                n = r.ci(); t = r.raw(n)
            else:
                st = r.p
                while s.b[r.p]: r.p += 1
                t = s.b[st:r.p + 1]; r.p += 1
            s.names.append(t.rstrip(b'\0').decode('latin1')); r.u32()
        r.p = io; s.imports = []
        for _ in range(ic):
            cp = r.ci(); cn = r.ci(); pk = r.i32(); on = r.ci()
            s.imports.append(dict(cls=s.names[cn], pkg=pk, name=s.names[on]))
        r.p = eo; s.exports = []
        for _ in range(ec):
            c = r.ci(); sup = r.ci(); pk = r.i32(); on = r.ci(); fl = r.u32(); sz = r.ci()
            off = r.ci() if sz > 0 else 0
            s.exports.append(dict(cls=c, pkg=pk, name=s.names[on], flags=fl, size=sz, off=off))

    def objname(s, ref):
        if ref > 0: return s.exports[ref - 1]['name']
        if ref < 0: return s.imports[-ref - 1]['name']
        return 'None'

    def clsname(s, e):
        c = e['cls']
        if c < 0: return s.imports[-c - 1]['name']
        if c > 0: return s.exports[c - 1]['name']
        return 'Class'

    def path(s, e):
        parts = [e['name']]; pk = e['pkg']
        while pk > 0:
            p = s.exports[pk - 1]; parts.insert(0, p['name']); pk = p['pkg']
        return '.'.join(parts)

    def props(s, r):
        out = {}
        while True:
            name = s.names[r.ci()]
            if name == 'None': return out
            info = r.u8(); typ = info & 0x0F; st = (info >> 4) & 7; arr = info & 0x80
            if typ == 10: r.ci()
            size = {0: 1, 1: 2, 2: 4, 3: 12, 4: 16}.get(st)
            if st == 5: size = r.u8()
            elif st == 6: size = r.u16()
            elif st == 7: size = r.i32()
            if arr and typ != 3:
                b = r.u8()
                if b & 0x80:
                    r.p -= 1
                    r.p += 2 if (b & 0xC0) == 0x80 else 4
            if typ == 3: out[name] = bool(arr); continue
            st0 = r.p
            if typ == 5: out[name] = r.ci()
            elif typ == 1: out[name] = r.u8()
            elif typ == 2: out[name] = r.i32()
            else: out[name] = None
            r.p = st0 + size

    def body(s, e):
        r = R(s.b, e['off'])
        if e['flags'] & 0x02000000:
            node = r.ci(); r.ci(); r.raw(8); r.i32()
            if node: r.ci()
        return r

    def palette(s, ref):
        if ref <= 0: return None
        e = s.exports[ref - 1]; r = s.body(e); s.props(r)
        n = r.ci(); d = r.raw(n * 4)
        return [tuple(d[i * 4:i * 4 + 4]) for i in range(n)]

    def texture(s, e):
        r = s.body(e); pr = s.props(r)
        n = r.ci()
        if n < 1: return None, pr
        if s.ver >= 63: r.i32()
        dn = r.ci(); data = r.raw(dn)
        us = r.i32(); vs = r.i32()
        fmt = pr.get('Format', 0)
        if fmt == 0:
            pal = s.palette(pr.get('Palette', 0))
            if pal is None: return None, pr
            px = bytearray(us * vs * 4)
            for i, c in enumerate(data[:us * vs]):
                rr, gg, bb, _ = pal[c]
                a = 0 if c == 0 else 255
                px[i * 4:i * 4 + 4] = bytes((rr, gg, bb, a))
            return Image.frombytes('RGBA', (us, vs), bytes(px)), pr
        if fmt == 5:
            im = Image.frombytes('RGBA', (us, vs), data[:us * vs * 4])
            b, g, rch, a = im.split()
            return Image.merge('RGBA', (rch, g, b, a)), pr
        return None, pr


if __name__ == '__main__':
    pkg = Package(sys.argv[1]); mode = sys.argv[2]
    if mode == 'list':
        pat = re.compile(sys.argv[3] if len(sys.argv) > 3 else '.', re.I)
        for e in pkg.exports:
            if pkg.clsname(e) == 'Texture' and pat.search(pkg.path(e)):
                print(pkg.path(e), e['size'])
    elif mode == 'export':
        pat = re.compile(sys.argv[3], re.I); out = sys.argv[4]; os.makedirs(out, exist_ok=True)
        n = 0
        for e in pkg.exports:
            if pkg.clsname(e) == 'Texture' and pat.search(pkg.path(e)):
                im, pr = pkg.texture(e)
                if im is None: print('skip', pkg.path(e), pr.get('Format')); continue
                im.save(os.path.join(out, pkg.path(e) + '.png')); n += 1
        print('exported', n)
