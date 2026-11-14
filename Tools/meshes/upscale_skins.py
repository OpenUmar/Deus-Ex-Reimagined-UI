"""Upscale Deus Ex item skins 4x with 4x-PBRify_RPLKSRd_V3 (CPU is fine, ~2 s a skin).
Model: github.com/Kim2091/Kim2091-Models/releases/tag/4x-PBRify_RPLKSRd_V3
needs: pip install torch spandrel scipy pillow
usage: python upscale_skins.py <textures dir> <textures_hd dir> <model.pth>"""
import sys, os, glob, time
import numpy as np, torch, spandrel
from PIL import Image
from scipy import ndimage

src, dst, mp = sys.argv[1:4]
os.makedirs(dst, exist_ok=True)
torch.set_grad_enabled(False)
model = spandrel.ModelLoader().load_from_file(mp).eval()
S = model.scale
PAD = 8
SKIP = ("_pal", "BlackMaskTex", "BloodTex1", "TracerTex1")

def fill_masked(rgb, mask):
    """Give transparent pixels the colour of the nearest opaque pixel."""
    if mask.all() or not mask.any():
        return rgb
    idx = ndimage.distance_transform_edt(~mask, return_distances=False, return_indices=True)
    return rgb[idx[0], idx[1]]

def run(rgb):
    h, w = rgb.shape[:2]
    p = np.pad(rgb, ((PAD, PAD), (PAD, PAD), (0, 0)), mode="reflect")
    t = torch.from_numpy(p).permute(2, 0, 1)[None].float() / 255.0
    o = model(t).clamp(0, 1)[0].permute(1, 2, 0).numpy()
    o = o[PAD * S:PAD * S + h * S, PAD * S:PAD * S + w * S]
    return (o * 255 + 0.5).astype(np.uint8)

files = [f for f in sorted(glob.glob(os.path.join(src, "*.png")))
         if not any(s in os.path.basename(f) for s in SKIP)]
t0 = time.time()
for i, f in enumerate(files):
    im = Image.open(f).convert("RGBA")
    a = np.array(im)
    rgb, alpha = a[..., :3], a[..., 3]
    mask = alpha > 127
    masked = not mask.all()
    # keep the real colours: black index-0 pixels are genuine paint on solid
    # faces; the importer only cuts them out on faces the game masks
    up = run(rgb)
    if masked:
        al = Image.fromarray(alpha).resize((up.shape[1], up.shape[0]), Image.LANCZOS)
        al = np.where(np.array(al) > 127, 255, 0).astype(np.uint8)
        out = Image.fromarray(np.dstack([up, al]), "RGBA")
    else:
        out = Image.fromarray(up, "RGB")
    out.save(os.path.join(dst, os.path.basename(f)))
    print(f"{i+1}/{len(files)} {os.path.basename(f)} {im.size}->{out.size}"
          f"{' masked' if masked else ''} {time.time()-t0:.0f}s", flush=True)
