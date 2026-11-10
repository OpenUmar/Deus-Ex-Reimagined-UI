"""Convert upscaled RGBA PNGs to 8-bit PCX for UCC import (#exec TEXTURE IMPORT).
Index 0 is the mask key (transparent pixels, alpha < 128) and keeps the original key colour;
the visible pixels get the other 255 palette entries.
usage: topcx.py ORIG_DIR UP_DIR OUT_DIR [regex]"""
import sys, os, re, glob, numpy as np
from PIL import Image


def to_pcx(orig, up, dst):
    o = np.asarray(orig.convert('RGBA')); key = tuple(int(v) for v in o[..., :3][o[..., 3] == 0][0]) if (o[..., 3] == 0).any() else (0, 0, 0)
    u = up.convert('RGBA'); a = np.asarray(u)[..., 3]; hole = a < 128
    rgb = u.convert('RGB')
    q = rgb.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    idx = np.asarray(q).astype(np.uint16) + 1
    idx[hole] = 0
    pal = [*key] + q.getpalette()[:255 * 3]
    pal += [0] * (768 - len(pal))
    out = Image.fromarray(idx.astype(np.uint8), 'P'); out.putpalette(pal)
    out.save(dst)


if __name__ == '__main__':
    od, ud, dd = sys.argv[1:4]; rx = re.compile(sys.argv[4] if len(sys.argv) > 4 else '.', re.I)
    os.makedirs(dd, exist_ok=True); n = 0
    for f in sorted(glob.glob(os.path.join(ud, '*.png'))):
        b = os.path.basename(f)
        if not rx.search(b): continue
        to_pcx(Image.open(os.path.join(od, b)), Image.open(f), os.path.join(dd, b[:-4] + '.pcx')); n += 1
    print('pcx', n)
