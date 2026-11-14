"""De-smear an ESRGAN 4x result: blend back some of the original's own detail
(Lanczos), sharpen lightly, and add a fine luminance grain so flat areas stop
reading as plastic. usage: refine.py ORIG_DIR ESR_DIR OUT_DIR"""
import sys, os, glob, numpy as np
from PIL import Image, ImageFilter

def refine(o, e, mix=0.35, grain=4.0, seed=7):
    o = o.convert('RGBA'); e = e.convert('RGBA')
    lan = o.resize(e.size, Image.LANCZOS)
    E = np.asarray(e).astype(np.float32); L = np.asarray(lan).astype(np.float32)
    rgb = E[..., :3] * (1 - mix) + L[..., :3] * mix
    im = Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).filter(ImageFilter.UnsharpMask(radius=1.6, percent=85, threshold=2))
    rgb = np.asarray(im).astype(np.float32)
    rng = np.random.default_rng(seed)
    n = rng.normal(0, grain, rgb.shape[:2])[..., None]
    lum = rgb.mean(-1, keepdims=True) / 255.0
    rgb = rgb + n * (0.4 + 0.6 * lum)          # less grain in the darks
    out = np.dstack([rgb.clip(0, 255), E[..., 3:4]]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')

if __name__ == '__main__':
    od, ed, out = sys.argv[1:4]; os.makedirs(out, exist_ok=True)
    for f in sorted(glob.glob(os.path.join(ed, '*.png'))):
        n = os.path.basename(f)
        refine(Image.open(os.path.join(od, n)), Image.open(f)).save(os.path.join(out, n))
    print('refined', len(glob.glob(os.path.join(out, '*.png'))))
