"""Extract textures from the client's MPQs and convert them to PNG for viewing.

Usage: python -I blp2png.py "<WoW>/Data" <out dir> "Interface\\Path\\Texture" ...
Searches every archive (highest-priority patch last wins) and writes <out>/<basename>.png,
printing each texture's size so texcoords can be worked out.
"""
import sys, os, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mpq import MPQ
from PIL import Image

data_dir, out_dir, names = sys.argv[1], sys.argv[2], sys.argv[3:]
os.makedirs(out_dir, exist_ok=True)

archives = []
for base, _, files in os.walk(data_dir):
    for f in files:
        if f.lower().endswith('.mpq'):
            archives.append(os.path.join(base, f))
# Lowest priority first: base archives, then patches in name order (letters after digits).
archives.sort(key=lambda p: (os.path.basename(p).lower().startswith('patch'), os.path.basename(p).lower()))
opened = [MPQ(p) for p in archives]

for name in names:
    if not name.lower().endswith('.blp'):
        name += '.blp'
    blob = None
    for m in opened:
        data = m.read(name.replace('/', '\\'))
        if data:
            blob, source = data, os.path.basename(m.path)
    if not blob:
        print('%-60s NOT FOUND' % name)
        continue
    img = Image.open(io.BytesIO(blob))
    img.load()
    out = os.path.join(out_dir, os.path.basename(name)[:-4] + '.png')
    img.save(out)
    print('%-60s %4dx%-4d %s -> %s' % (name, img.width, img.height, source, out))
