"""Real-ESRGAN (RealESRGAN_x4plus_anime_6B, ONNX/CPU) batch upscaler for Deus Ex UI textures.

usage: esrgan.py SRC_DIR OUT_DIR [regex]
 - Tile groups (Foo_1..Foo_N) are assembled into one image, upscaled together and
   cut back into tiles at 4x, so seams between pieces stay invisible.
 - Alpha goes through the model as greyscale; masked (binary) alpha is re-thresholded.
 - Output is 4x, PNG, same file names."""
import sys, os, re, glob, collections, time, numpy as np, onnxruntime as ort
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bp import backproject
from PIL import Image

_s = None
def sess():
    global _s
    if _s is None:
        o = ort.SessionOptions(); o.intra_op_num_threads = os.cpu_count()
        _s = ort.InferenceSession(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.environ.get('ESR_MODEL', 'anime6B') + '.onnx'),
                                  o, providers=['CPUExecutionProvider'])
    return _s


def run(rgb, tile=128, pad=10):
    h, w, _ = rgb.shape; p = 8
    x = np.pad(rgb, ((p, p), (p, p), (0, 0)), mode='reflect' if min(h, w) > p else 'edge')
    x = x.transpose(2, 0, 1)[None].astype(np.float32); H, W = x.shape[2:]
    out = np.zeros((1, 3, H * 4, W * 4), np.float32)
    for y0 in range(0, H, tile):
        for x0 in range(0, W, tile):
            y1, x1 = min(y0 + tile, H), min(x0 + tile, W)
            ya, xa, yb, xb = max(y0 - pad, 0), max(x0 - pad, 0), min(y1 + pad, H), min(x1 + pad, W)
            o = sess().run(None, {'input': x[:, :, ya:yb, xa:xb]})[0]
            out[:, :, y0 * 4:y1 * 4, x0 * 4:x1 * 4] = o[:, :, (y0 - ya) * 4:(y1 - ya) * 4, (x0 - xa) * 4:(x1 - xa) * 4]
    return out[0, :, p * 4:-p * 4, p * 4:-p * 4].transpose(1, 2, 0).clip(0, 1)


def upscale(im):
    im = im.convert('RGBA'); arr = np.asarray(im); a = arr[..., 3]; rgb = arr[..., :3].copy()
    hole = a == 0
    if hole.any() and (~hole).any() and rgb[hole].mean() > 24:   # coloured key (magenta): bleed edges inward
        from scipy.ndimage import distance_transform_edt
        _, (iy, ix) = distance_transform_edt(hole, return_indices=True); rgb = rgb[iy, ix]
    res = Image.fromarray((run(rgb.astype(np.float32) / 255) * 255 + .5).astype(np.uint8))
    if a.min() < 255:
        binary = set(np.unique(a).tolist()) <= {0, 255}
        if binary:   # mask key: smooth resize + threshold is as good as the network and half the cost
            ab = np.asarray(Image.fromarray(a).resize(res.size, Image.LANCZOS), np.float32) / 255
        else:
            ab = run(np.repeat(a[..., None].astype(np.float32) / 255, 3, 2))[..., 0]
        res.putalpha(Image.fromarray(((ab > .5) * 255 if binary else ab * 255 + .5).astype(np.uint8)))
    return backproject(im, res)


def layout(sizes):
    n = len(sizes)
    if n == 6: cols = 3
    elif n == 4: cols = 2
    elif n == 2: cols = 2 if sizes[0][1] == sizes[1][1] else 1
    else: cols = n
    rows = (n + cols - 1) // cols
    cw = [max(sizes[r * cols + c][0] for r in range(rows) if r * cols + c < n) for c in range(cols)]
    rh = [max(sizes[r * cols + c][1] for c in range(cols) if r * cols + c < n) for r in range(rows)]
    pos = [(sum(cw[:i % cols]), sum(rh[:i // cols])) for i in range(n)]
    return pos, (sum(cw), sum(rh))


def main(src, out, pat='.'):
    os.makedirs(out, exist_ok=True); rx = re.compile(pat, re.I)
    files = sorted(f for f in glob.glob(os.path.join(src, '*.png')) if rx.search(os.path.basename(f)))
    groups = collections.defaultdict(list); single = []
    for f in files:
        m = re.match(r'(.*)_(\d+)\.png$', os.path.basename(f))
        (groups[m.group(1)].append((int(m.group(2)), f)) if m else single.append(f))
    for k, v in list(groups.items()):
        if len(v) < 2 or sorted(i for i, _ in v) != list(range(1, len(v) + 1)):
            single += [f for _, f in v]; del groups[k]
    t0 = time.time(); done = 0
    for k, v in groups.items():
        v.sort(); ims = [Image.open(f).convert('RGBA') for _, f in v]
        dsts = [os.path.join(out, os.path.basename(f)) for _, f in v]
        if all(os.path.exists(d) for d in dsts): continue
        pos, size = layout([i.size for i in ims])
        canvas = Image.new('RGBA', size, (0, 0, 0, 0))
        for im, p in zip(ims, pos): canvas.paste(im, p)
        big = upscale(canvas)
        for im, p, d in zip(ims, pos, dsts):
            big.crop((p[0] * 4, p[1] * 4, (p[0] + im.width) * 4, (p[1] + im.height) * 4)).save(d)
        done += len(v); print(f'[{time.time() - t0:6.0f}s] group {k} x{len(v)}', flush=True)
    for f in single:
        d = os.path.join(out, os.path.basename(f))
        if os.path.exists(d): continue
        upscale(Image.open(f)).save(d); done += 1
        print(f'[{time.time() - t0:6.0f}s] {os.path.basename(f)}', flush=True)


if __name__ == '__main__':
    main(*sys.argv[1:])
