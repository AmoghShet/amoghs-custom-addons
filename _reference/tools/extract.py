"""Extract the effective Blizzard UI code (FrameXML, GlueXML, Blizzard_* addons) from a 3.3.5a client.

Usage: python -I extract.py <WoW Data dir> <output dir>
Archives are applied lowest priority first, so later ones override earlier ones.
Only text code files (.lua .xml .toc .xsd) are written.
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mpq import MPQ

BS = chr(92)
data_dir, out_dir = sys.argv[1], sys.argv[2]
ORDER = ['enUS/locale-enUS.MPQ', 'enUS/patch-enUS.MPQ', 'enUS/patch-enUS-2.MPQ', 'enUS/patch-enUS-3.MPQ']
PREFIXES = ('interface' + BS + 'framexml' + BS, 'interface' + BS + 'gluexml' + BS, 'interface' + BS + 'addons' + BS)
EXTS = ('.lua', '.xml', '.toc', '.xsd')

winner = {}   # lower-cased name -> (archive, original name)
archives = {}
for rel in ORDER:
    m = MPQ(os.path.join(data_dir, rel))
    archives[rel] = m
    for n in m.listfile():
        ln = n.lower()
        if ln.startswith(PREFIXES) and ln.endswith(EXTS):
            winner[ln] = (rel, n)

manifest, errors = {}, []
for ln, (rel, n) in sorted(winner.items()):
    try:
        blob = archives[rel].read(n)
        if blob is None:
            errors.append((n, rel, 'not found / deleted'))
            continue
        dest = os.path.join(out_dir, *n.split(BS))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, 'wb') as fh:
            fh.write(blob)
        manifest[n.replace(BS, '/')] = os.path.basename(rel)
    except Exception as e:
        errors.append((n, rel, repr(e)))

with open(os.path.join(out_dir, 'SOURCE-MANIFEST.json'), 'w', encoding='utf-8') as fh:
    json.dump({'extracted_from': data_dir, 'archive_priority_low_to_high': ORDER,
               'files': manifest}, fh, indent=1)
print('extracted', len(manifest), 'files;', len(errors), 'errors')
for e in errors[:20]:
    print('  ERR', e)
from collections import Counter
print(Counter(manifest.values()))
