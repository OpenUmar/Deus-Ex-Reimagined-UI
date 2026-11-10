"""Load RealESRGAN_x4plus_anime_6B.pth without torch and emit an ONNX graph."""
import zipfile, pickle, numpy as np, onnx, sys
from onnx import helper as H, TensorProto as T, numpy_helper as NH

DT = {'FloatStorage': np.float32, 'HalfStorage': np.float16}


def load_pth(path):
    z = zipfile.ZipFile(path); root = z.namelist()[0].split('/')[0]
    class U(pickle.Unpickler):
        def find_class(s, mod, name):
            if name == '_rebuild_tensor_v2':
                def rb(storage, off, size, stride, *a):
                    n = int(np.prod(size)) if size else 1
                    arr = np.lib.stride_tricks.as_strided(storage[off:], shape=size,
                                                          strides=[x * storage.itemsize for x in stride])
                    return np.ascontiguousarray(arr)
                return rb
            if mod == 'collections' and name == 'OrderedDict':
                import collections; return collections.OrderedDict
            if name in DT: return name
            return super().find_class(mod, name)
        def persistent_load(s, pid):
            _, typ, key, loc, n = pid
            return np.frombuffer(z.read(f'{root}/data/{key}'), dtype=DT[typ if isinstance(typ, str) else typ])
    return U(z.open(f'{root}/data.pkl')).load()


sd = load_pth(sys.argv[1]); sd = sd.get('params_ema', sd.get('params', sd))
inits, nodes = [], []; cnt = [0]
def nm(p): cnt[0] += 1; return f'{p}{cnt[0]}'
def conv(x, key):
    w = key + '.weight'; b = key + '.bias'
    for k in (w, b):
        if not any(i.name == k for i in inits): inits.append(NH.from_array(sd[k].astype(np.float32), k))
    o = nm('c'); nodes.append(H.make_node('Conv', [x, w, b], [o], pads=[1, 1, 1, 1], kernel_shape=[3, 3])); return o
def lrelu(x): o = nm('l'); nodes.append(H.make_node('LeakyRelu', [x], [o], alpha=0.2)); return o
def cat(xs): o = nm('k'); nodes.append(H.make_node('Concat', xs, [o], axis=1)); return o
inits.append(NH.from_array(np.array(0.2, np.float32), 'p2'))
def scale_add(x, r): m = nm('m'); nodes.append(H.make_node('Mul', [x, 'p2'], [m])); o = nm('a'); nodes.append(H.make_node('Add', [m, r], [o])); return o
inits.append(NH.from_array(np.array([1, 1, 2, 2], np.float32), 'sc'))
def up(x): o = nm('u'); nodes.append(H.make_node('Resize', [x, '', 'sc'], [o], mode='nearest')); return o

def rdb(x, k):
    x1 = lrelu(conv(x, k + '.conv1')); x2 = lrelu(conv(cat([x, x1]), k + '.conv2'))
    x3 = lrelu(conv(cat([x, x1, x2]), k + '.conv3')); x4 = lrelu(conv(cat([x, x1, x2, x3]), k + '.conv4'))
    return scale_add(conv(cat([x, x1, x2, x3, x4]), k + '.conv5'), x)

f = conv('input', 'conv_first'); b = f
nb = len({k.split('.')[1] for k in sd if k.startswith('body.')})
for i in range(nb):
    t = b
    for j in (1, 2, 3): t = rdb(t, f'body.{i}.rdb{j}')
    b = scale_add(t, b)
o = nm('a'); nodes.append(H.make_node('Add', [f, conv(b, 'conv_body')], [o]))
o = lrelu(conv(up(o), 'conv_up1')); o = lrelu(conv(up(o), 'conv_up2'))
o = conv(lrelu(conv(o, 'conv_hr')), 'conv_last')
nodes.append(H.make_node('Identity', [o], ['output']))
g = H.make_graph(nodes, 'rrdb', [H.make_tensor_value_info('input', T.FLOAT, [1, 3, None, None])],
                 [H.make_tensor_value_info('output', T.FLOAT, [1, 3, None, None])], inits)
m = H.make_model(g, opset_imports=[H.make_opsetid('', 17)]); m.ir_version = 8
onnx.checker.check_model(m); onnx.save(m, sys.argv[2]); print('blocks', nb, 'ok')
