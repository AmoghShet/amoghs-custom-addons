"""Minimal read-only MPQ (v1/v2) reader for WoW 3.3.5a archives.

Supports: hash/block table decryption, (listfile), single-unit and sectored files,
zlib (0x02), bzip2 (0x10) and PKWARE DCL implode (flag 0x100 or mask 0x08).
Never writes to the archive.
"""
import struct, zlib, bz2, os, sys

# ---------------------------------------------------------------- crypto
_CRYPT = [0] * 0x500
def _init_crypt():
    seed = 0x00100001
    for i in range(0x100):
        idx = i
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            t1 = (seed & 0xFFFF) << 0x10
            seed = (seed * 125 + 3) % 0x2AAAAB
            t2 = seed & 0xFFFF
            _CRYPT[idx] = t1 | t2
            idx += 0x100
_init_crypt()

M32 = 0xFFFFFFFF

def hash_string(s, htype):
    s1, s2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in s.upper().replace('/', '\\').encode('latin-1'):
        s1 = (_CRYPT[(htype << 8) + ch] ^ ((s1 + s2) & M32)) & M32
        s2 = (ch + s1 + s2 + (s2 << 5) + 3) & M32
    return s1

def decrypt(data, key):
    n = len(data) // 4
    vals = struct.unpack('<%dI' % n, data[:n * 4])
    out = []
    s2 = 0xEEEEEEEE
    for v in vals:
        s2 = (s2 + _CRYPT[0x400 + (key & 0xFF)]) & M32
        ch = (v ^ ((key + s2) & M32)) & M32
        out.append(ch)
        key = ((((~key) << 0x15) + 0x11111111) & M32) | (key >> 0x0B)
        s2 = (ch + s2 + (s2 << 5) + 3) & M32
    return struct.pack('<%dI' % n, *out) + data[n * 4:]

# ---------------------------------------------------------------- PKWARE DCL explode
_LEN_BITS = [3,2,3,3,4,4,4,5,5,5,5,6,6,6,7,7]
_LEN_CODE = [0x05,0x03,0x01,0x06,0x0A,0x02,0x0C,0x14,0x04,0x18,0x08,0x30,0x10,0x20,0x40,0x00]
_EX_LEN_BITS = [0,0,0,0,0,0,0,0,1,2,3,4,5,6,7,8]
_LEN_BASE = [0,1,2,3,4,5,6,7,8,10,14,22,38,70,134,262]
_DIST_BITS = [2,4,4,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,
              7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8]
_DIST_CODE = [0x03,0x0D,0x05,0x19,0x09,0x11,0x01,0x3E,0x1E,0x2E,0x0E,0x36,0x16,0x26,0x06,0x3A,
              0x1A,0x2A,0x0A,0x32,0x12,0x22,0x42,0x02,0x7C,0x3C,0x5C,0x1C,0x6C,0x2C,0x4C,0x0C,
              0x74,0x34,0x54,0x14,0x64,0x24,0x44,0x04,0x78,0x38,0x58,0x18,0x68,0x28,0x48,0x08,
              0xF0,0x70,0xB0,0x30,0xD0,0x50,0x90,0x10,0xE0,0x60,0xA0,0x20,0xC0,0x40,0x80,0x00]

def _build_decode(bits, codes):
    table = {}
    for i, (b, c) in enumerate(zip(bits, codes)):
        table[(b, c)] = i
    return table
_LEN_DEC = _build_decode(_LEN_BITS, _LEN_CODE)
_DIST_DEC = _build_decode(_DIST_BITS, _DIST_CODE)

class _BitReader:
    def __init__(self, data, pos):
        self.data, self.pos, self.buf, self.n = data, pos, 0, 0
    def bits(self, k):
        while self.n < k:
            b = self.data[self.pos] if self.pos < len(self.data) else 0
            self.pos += 1
            self.buf |= b << self.n
            self.n += 8
        v = self.buf & ((1 << k) - 1)
        self.buf >>= k
        self.n -= k
        return v
    def decode(self, table, maxbits):
        code, length = 0, 0
        while length < maxbits:
            code |= self.bits(1) << length
            length += 1
            if (length, code) in table:
                return table[(length, code)]
        raise ValueError('bad huffman code')

def explode(data):
    ctype, dict_bits = data[0], data[1]
    if ctype != 0:
        raise ValueError('binary-mode implode only (ASCII mode unsupported)')
    br = _BitReader(data, 2)
    out = bytearray()
    while True:
        if br.bits(1) == 0:
            out.append(br.bits(8))
            continue
        li = br.decode(_LEN_DEC, 7)
        length = _LEN_BASE[li] + (br.bits(_EX_LEN_BITS[li]) if _EX_LEN_BITS[li] else 0)
        if length == 517:  # end-of-stream (519 once the +2 below is applied)
            break
        length += 2
        di = br.decode(_DIST_DEC, 8)
        if length == 2:
            dist = (di << 2) | br.bits(2)
        else:
            dist = (di << dict_bits) | br.bits(dict_bits)
        dist += 1
        start = len(out) - dist
        for k in range(length):
            out.append(out[start + k])
    return bytes(out)

# ---------------------------------------------------------------- archive
F_IMPLODE, F_COMPRESS, F_ENCRYPTED, F_FIX_KEY = 0x100, 0x200, 0x10000, 0x20000
F_SINGLE, F_DELETE, F_SECTOR_CRC, F_EXISTS = 0x1000000, 0x2000000, 0x4000000, 0x80000000

class MPQ:
    def __init__(self, path):
        self.path = path
        self.f = open(path, 'rb')
        off = 0
        while True:
            self.f.seek(off)
            magic = self.f.read(4)
            if magic == b'MPQ\x1a':
                break
            if not magic:
                raise ValueError('no MPQ header')
            off += 0x200
        self.base = off
        hdr = self.f.read(28)
        (self.header_size, self.archive_size, self.version, shift,
         ht_off, bt_off, ht_n, bt_n) = struct.unpack('<IIHHIIII', hdr)
        self.sector_size = 512 << shift
        hi_ht = hi_bt = 0
        if self.version >= 1:
            ext = self.f.read(12)
            _hibt, hi_ht, hi_bt = struct.unpack('<QHH', ext)
        ht_off |= hi_ht << 32
        bt_off |= hi_bt << 32
        self.f.seek(self.base + ht_off)
        ht = decrypt(self.f.read(ht_n * 16), hash_string('(hash table)', 3))
        self.hashes = [struct.unpack_from('<IIHHI', ht, i * 16) for i in range(ht_n)]
        self.f.seek(self.base + bt_off)
        bt = decrypt(self.f.read(bt_n * 16), hash_string('(block table)', 3))
        self.blocks = [struct.unpack_from('<IIII', bt, i * 16) for i in range(bt_n)]

    def find(self, name):
        n = len(self.hashes)
        i = hash_string(name, 0) % n
        a, b = hash_string(name, 1), hash_string(name, 2)
        start = i
        while True:
            na, nb, loc, plat, bi = self.hashes[i]
            if bi == 0xFFFFFFFF:
                return None
            if na == a and nb == b and bi != 0xFFFFFFFE:
                return bi
            i = (i + 1) % n
            if i == start:
                return None

    def _decomp(self, chunk, size, flags):
        if len(chunk) >= size:
            return chunk[:size]
        if flags & F_IMPLODE:
            return explode(chunk)
        mask, body = chunk[0], chunk[1:]
        if mask == 0x02:
            return zlib.decompress(body)
        if mask == 0x10:
            return bz2.decompress(body)
        if mask == 0x08:
            return explode(body)
        raise ValueError('unsupported compression mask 0x%02x' % mask)

    def read(self, name):
        bi = self.find(name)
        if bi is None:
            return None
        pos, csize, fsize, flags = self.blocks[bi]
        if not flags & F_EXISTS or flags & F_DELETE:
            return None
        key = None
        if flags & F_ENCRYPTED:
            key = hash_string(name.replace('/', '\\').split('\\')[-1], 3)
            if flags & F_FIX_KEY:
                key = ((key + pos) ^ fsize) & M32
        self.f.seek(self.base + pos)
        raw = self.f.read(csize)
        if flags & F_SINGLE:
            if key is not None:
                raw = decrypt(raw, key)
            return self._decomp(raw, fsize, flags) if flags & (F_COMPRESS | F_IMPLODE) else raw[:fsize]
        nsec = (fsize + self.sector_size - 1) // self.sector_size
        if not flags & (F_COMPRESS | F_IMPLODE):
            out = bytearray()
            for s in range(nsec):
                chunk = raw[s * self.sector_size:(s + 1) * self.sector_size]
                if key is not None:
                    chunk = decrypt(chunk, (key + s) & M32)
                out += chunk
            return bytes(out[:fsize])
        nofs = nsec + 1 + (1 if flags & F_SECTOR_CRC else 0)
        ofs_raw = raw[:nofs * 4]
        if key is not None:
            ofs_raw = decrypt(ofs_raw, (key - 1) & M32)
        ofs = struct.unpack('<%dI' % nofs, ofs_raw)
        out = bytearray()
        for s in range(nsec):
            chunk = raw[ofs[s]:ofs[s + 1]]
            if key is not None:
                chunk = decrypt(chunk, (key + s) & M32)
            expect = min(self.sector_size, fsize - s * self.sector_size)
            out += self._decomp(chunk, expect, flags)
        return bytes(out[:fsize])

    def listfile(self):
        data = self.read('(listfile)')
        if not data:
            return []
        return [l.strip() for l in data.decode('latin-1').replace(';', '\n').splitlines() if l.strip()]


if __name__ == '__main__':
    for p in sys.argv[1:]:
        try:
            m = MPQ(p)
            lf = m.listfile()
            ui = [n for n in lf if n.lower().startswith('interface\\framexml') or n.lower().startswith('interface\\addons') or n.lower().startswith('interface\\gluexml')]
            print('%-40s v%d sector=%d hashes=%d blocks=%d listfile=%d  UI-code-files=%d' % (
                os.path.basename(p), m.version + 1, m.sector_size, len(m.hashes), len(m.blocks), len(lf), len(ui)))
        except Exception as e:
            print('%-40s ERROR %s' % (os.path.basename(p), e))
