"""Read client DBC tables (WDBC format) straight out of the 3.3.5a MPQ archives.

    from dbc import load_dbc
    table = load_dbc("D:/WoW WotLK/Data", "Spell")   # DBFilesClient\\Spell.dbc
    rec = table.rows[118]                            # list of uint32 fields, keyed by field 0 (ID)
    table.string(rec[i])                             # resolve a string field

The highest-priority archive containing the file wins: root custom patches (patch-?.MPQ letters)
over numbered patches over locale patches over base archives. Field meanings are not hard-coded;
callers calibrate them against known records.
"""
import os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mpq import MPQ

BS = chr(92)


def _priority(path):
    base = os.path.basename(path).lower()
    in_locale = os.path.basename(os.path.dirname(path)).lower() != 'data'
    if base.startswith('patch'):
        suffix = base[5:].split('.')[0].lstrip('-')
        if suffix and suffix.isalpha() and not in_locale and len(suffix) == 1:
            return (3, suffix)          # patch-A..Z in Data root: highest
        return (2 if not in_locale else 1, suffix)
    return (0, base)


class DBC:
    def __init__(self, blob, source):
        magic, self.count, self.fields, self.size, self.strsize = struct.unpack_from('<4s4I', blob, 0)
        if magic != b'WDBC':
            raise ValueError('not a WDBC file')
        self.source = source
        body = 20
        self.strings = blob[body + self.count * self.size:]
        self.rows = {}
        for r in range(self.count):
            vals = list(struct.unpack_from('<%dI' % self.fields, blob, body + r * self.size))
            self.rows[vals[0]] = vals

    def string(self, offset):
        if offset >= len(self.strings):
            return None
        end = self.strings.find(b'\0', offset)
        return self.strings[offset:end].decode('utf-8', 'replace')

    @staticmethod
    def as_int(v):
        return v - (1 << 32) if v >= 1 << 31 else v

    @staticmethod
    def as_float(v):
        return struct.unpack('<f', struct.pack('<I', v))[0]


def load_dbc(data_dir, name):
    path = 'DBFilesClient' + BS + name + '.dbc'
    archives = []
    for base, _, files in os.walk(data_dir):
        for f in files:
            if f.lower().endswith('.mpq'):
                archives.append(os.path.join(base, f))
    best = None
    for p in archives:
        m = MPQ(p)
        if m.find(path) is not None:
            blob = m.read(path)
            if blob and (best is None or _priority(p) > best[0]):
                best = (_priority(p), blob, os.path.basename(p))
    if not best:
        raise FileNotFoundError(path)
    return DBC(best[1], best[2])
