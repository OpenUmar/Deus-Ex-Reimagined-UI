"""Clean re-trace for flat graphic icons (aug icons): the shape's outline is
smoothed at 16x, cut hard, and box-sampled back to 4x (crisp anti-aliased
edges, no speckle); inside, the original's shading, smoothly upscaled.
usage: retrace.py SRC_DIR OUT_DIR"""
import sys, os, glob, numpy as np
from PIL import Image, ImageFilter

def retrace(o, t=40, sigma=5.0):
    o = o.convert('RGBA'); w, h = o.size
    big = o.resize((w * 16, h * 16), Image.BICUBIC)
    L = np.asarray(big.convert('L').filter(ImageFilter.GaussianBlur(sigma))).astype(np.float32)
    a = np.asarray(big)[..., 3].astype(np.float32)
    m = ((L > t) & (a > 127)).astype(np.float32) * 255
    mask = Image.fromarray(m.astype(np.uint8)).resize((w * 4, h * 4), Image.BOX)
    fill = o.resize((w * 4, h * 4), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=1))
    rgb = np.asarray(fill)[..., :3].astype(np.float32)
    M = np.asarray(mask).astype(np.float32)[..., None] / 255
    # lift the inside a touch where the bicubic fill dimmed near the edge
    out = np.dstack([(rgb * M).clip(0, 255), np.asarray(fill)[..., 3:4]]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')

if __name__ == '__main__':
    src, dst = sys.argv[1:3]; os.makedirs(dst, exist_ok=True); n = 0
    for f in sorted(glob.glob(os.path.join(src, '*.png'))):
        retrace(Image.open(f)).save(os.path.join(dst, os.path.basename(f))); n += 1
    print('retraced', n)
