"""Index every Interface\\ and Fonts\\ asset path present in the client's MPQ archives.

Usage: python -I assetindex.py "<WoW>/Data" <out.txt> [name-to-check ...]
Writes one path per line (sorted, original case) and reports, for each name given,
whether it exists and in which archive(s).
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mpq import MPQ

BS = chr(92)
data_dir, out_path, checks = sys.argv[1], sys.argv[2], sys.argv[3:]
archives = []
for base, _, files in os.walk(data_dir):
    for f in files:
        if f.lower().endswith('.mpq'):
            archives.append(os.path.join(base, f))

where = {}
opened = []
for p in sorted(archives):
    try:
        m = MPQ(p)
    except Exception as e:
        print('skip', p, e)
        continue
    opened.append((p, m))
    for n in m.listfile():
        ln = n.lower()
        if ln.startswith('interface' + BS) or ln.startswith('fonts' + BS):
            where.setdefault(ln, [n, set()])[1].add(os.path.basename(p))

with open(out_path, 'w', encoding='utf-8') as fh:
    for ln in sorted(where):
        fh.write(where[ln][0] + '\n')
print('indexed %d asset paths from %d archives -> %s' % (len(where), len(opened), out_path))

for c in checks:
    lc = c.lower().replace('/', BS)
    hit = where.get(lc)
    if not hit:  # archives without a listfile can still be probed by hash
        arcs = sorted(os.path.basename(p) for p, m in opened if m.find(c.replace('/', BS)) is not None)
        print('%-55s %s' % (c, ('FOUND (no listfile) in ' + ', '.join(arcs)) if arcs else 'MISSING'))
    else:
        print('%-55s found in %s' % (c, ', '.join(sorted(hit[1]))))
