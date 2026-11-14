import numpy as np
from PIL import Image
def backproject(orig, up, iters=2, k=1.0):
    """Iterative back-projection: make up (4x) consistent with orig when box-downscaled."""
    o = np.asarray(orig.convert('RGBA'), np.float32); u = np.asarray(up.convert('RGBA'), np.float32).copy()
    W, H = orig.size
    for _ in range(iters):
        d = np.asarray(Image.fromarray(u[..., :3].clip(0,255).astype(np.uint8)).resize((W, H), Image.BOX), np.float32)
        err = o[..., :3] - d
        err[o[..., 3] == 0] = 0
        e = np.stack([np.asarray(Image.fromarray(err[..., c]).resize(up.size, Image.BICUBIC)) for c in range(3)], -1)
        u[..., :3] += k * e
    return Image.fromarray(u.clip(0, 255).astype(np.uint8), 'RGBA')
