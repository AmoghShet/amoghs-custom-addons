"""Copy the addons in this repo into the game's AddOns folder as real files.

Usage: python -I _devtools/sync_addons.py ["<WoW>/Interface/AddOns"]   (default: D:/WoW WotLK/Interface/AddOns)

This repo is the master copy; the game gets plain copies so the AddOns folder can be zipped or
copied to another machine (Mac/Linux via Wine) as is. An addon is any top-level folder here with
<Name>/<Name>.toc. Only new or changed files are copied. Nothing is ever deleted: a file removed
from an addon stays behind in AddOns, harmless because the game loads only files its .toc lists.
Refuses to write through a link (the old junction setup) so it can't loop back into this repo.
"""
import os, sys, shutil, filecmp

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
dest_root = sys.argv[1] if len(sys.argv) > 1 else 'D:/WoW WotLK/Interface/AddOns'

if not os.path.isdir(dest_root):
    raise SystemExit('AddOns folder not found: ' + dest_root)

addons = sorted(n for n in os.listdir(REPO)
                if not n.startswith(('.', '_')) and os.path.isfile(os.path.join(REPO, n, n + '.toc')))

for name in addons:
    src, dst = os.path.join(REPO, name), os.path.join(dest_root, name)
    real, plain = os.path.normcase(os.path.realpath(dst)), os.path.normcase(os.path.abspath(dst))
    if os.path.islink(dst) or (os.path.isdir(dst) and real != plain):  # realpath resolves junctions too
        raise SystemExit('%s is a link, not a folder; remove the link first' % dst)
    copied = 0
    for base, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d != '__pycache__']
        out = os.path.join(dst, os.path.relpath(base, src))
        os.makedirs(out, exist_ok=True)
        for f in files:
            s, d = os.path.join(base, f), os.path.join(out, f)
            if not os.path.exists(d) or not filecmp.cmp(s, d, shallow=False):
                shutil.copy2(s, d)
                copied += 1
    print('%-22s %s' % (name, ('%d file(s) updated' % copied) if copied else 'up to date'))
