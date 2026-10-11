"""Count how often API names appear in installed addons that target only Interface 30300.

Usage: python -I apiusage.py "<WoW>/Interface/AddOns" name1 name2 ...
Prints: name, total hits, first addon that uses it.
"""
import os, re, sys

root, names = sys.argv[1], sys.argv[2:]
iface = re.compile(r'^##\s*Interface:\s*30300\s*$', re.I | re.M)
dirs = []
for d in sorted(os.listdir(root)):
    toc = os.path.join(root, d, d + '.toc')
    if os.path.isfile(toc):
        with open(toc, encoding='latin-1') as fh:
            if iface.search(fh.read()):
                dirs.append(d)

texts = {}
for d in dirs:
    for base, _, files in os.walk(os.path.join(root, d)):
        for f in files:
            if f.lower().endswith('.lua'):
                p = os.path.join(base, f)
                with open(p, encoding='latin-1') as fh:
                    texts[os.path.relpath(p, root)] = fh.read()

print('scanned %d addons (%d lua files) targeting 30300' % (len(dirs), len(texts)))
for n in names:
    total, first = 0, ''
    for p, t in texts.items():
        c = t.count(n)
        if c and not first:
            first = p
        total += c
    print('%-28s %5d  %s' % (n, total, first))
