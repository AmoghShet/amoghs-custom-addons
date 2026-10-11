import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mpq import MPQ

BS = chr(92)
D = sys.argv[1]
loc = ['enUS/locale-enUS.MPQ', 'enUS/patch-enUS.MPQ', 'enUS/patch-enUS-2.MPQ', 'enUS/patch-enUS-3.MPQ']
names = set()
for p in loc:
    for n in MPQ(os.path.join(D, p)).listfile():
        if n.lower().startswith('interface' + BS):
            names.add(n)
print('known Interface names across locale archives:', len(names))

def top(n):
    parts = n.split(BS)
    if parts[0].lower() == 'interface' and len(parts) > 2:
        return (parts[0] + BS + parts[1]).lower()
    return parts[0].lower()

for p in ['patch-4.mpq', 'Patch-A.MPQ', 'Patch-F.MPQ', 'Patch-G.MPQ', 'Patch-K.MPQ', 'Patch-T.MPQ']:
    m = MPQ(os.path.join(D, p))
    hits = sorted(n for n in names if m.find(n) is not None)
    tops = collections.Counter(top(n) for n in m.listfile())
    print('%-12s Interface-name hits=%d %s' % (p, len(hits), hits[:10]))
    print('             listfile top-level: %s' % dict(tops.most_common(10)))
