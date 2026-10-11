"""Check whether API / CVar / method names appear as strings in the 3.3.5a client binary.

Usage:
  python -I exescan.py "<WoW>/Wow.exe" Name1 Name2 ...      -> PRESENT/absent per name
  python -I exescan.py "<WoW>/Wow.exe" --index <out.txt>     -> write every identifier-like string

Calibration (verified 2026-10-12): PRESENT is strong evidence the name exists in the engine
(C_Timer, SetColorTexture, SetFromAlpha, GetNumGroupMembers are correctly absent). "absent" is
NOT conclusive: wipe, tinsert, tremove, strupper exist but are not found. Functions defined in
FrameXML Lua (e.g. tContains) are never in the binary: grep _reference/BlizzardInterfaceCode too.
"""
import re, sys

exe, args = sys.argv[1], sys.argv[2:]
data = open(exe, 'rb').read()

if args and args[0] == '--index':
    found = set(m.group(1).decode() for m in re.finditer(rb'\x00([A-Za-z_][A-Za-z0-9_]{2,63})\x00', data))
    with open(args[1], 'w', encoding='utf-8') as fh:
        for s in sorted(found):
            fh.write(s + '\n')
    print('wrote %d identifiers to %s' % (len(found), args[1]))
else:
    for n in args:
        hit = re.search(rb'\x00' + re.escape(n.encode()) + rb'\x00', data) is not None
        print('%-32s %s' % (n, 'PRESENT' if hit else 'absent'))
