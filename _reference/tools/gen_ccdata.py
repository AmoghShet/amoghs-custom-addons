"""Generate ThreatManagement/CCData.lua: every crowd control on this client that damage can break.

Usage: python -I gen_ccdata.py "<WoW>/Data" "<addon>/CCData.lua"

Source: the client's Spell.dbc / SpellDuration.dbc / SkillLineAbility.dbc / SkillLine.dbc (via dbc.py).
Candidates = spells taught by a class/pet skill line (SkillLine category 7), the spells those
trigger (EffectTriggerSpell), plus a few applied by scripts or trap objects (EXTRA). Kept when:
  * the aura is removed by any damage (AuraInterruptFlags & 0x2), or by a damage-taken proc
    (procFlags), AND
  * it controls a hostile target (CC mechanic or a confuse/charm/fear/stun/root/transform aura).
Field indexes are calibrated against known spells at run time, not trusted blindly.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dbc import load_dbc

data_dir, out_path = sys.argv[1], sys.argv[2]
spell = load_dbc(data_dir, 'Spell')
dur = load_dbc(data_dir, 'SpellDuration')
sla = load_dbc(data_dir, 'SkillLineAbility')
skill = load_dbc(data_dir, 'SkillLine')
R = spell.rows

MECH, AIF, PROC, DUR, NAME, RANK = 3, 32, 34, 40, 136, 153
EFFECT, MECH_EFF, TARGET_A, AURA, TRIGGER = 71, 83, 86, 95, 115   # 3 fields each (one per effect)

# Exact calibration against known spells; abort rather than guess if the layout differs.
CHECKS = [
    (spell.string(R[118][NAME]) == 'Polymorph' and R[118][MECH] == 17, 'name/mechanic'),
    (R[1776][EFFECT:EFFECT + 3] == [2, 80, 6], 'effect types (Gouge)'),
    (R[1776][AURA + 2] == 12 and R[122][AURA + 1] == 26 and 7 in R[5782][AURA:AURA + 3], 'aura types'),
    (R[1776][MECH_EFF + 2] == 14 and R[122][MECH_EFF + 1] == 7, 'effect mechanics'),
    (R[118][TARGET_A] == 6 and R[1776][TARGET_A + 2] == 6, 'implicit targets'),
    (R[16689][TRIGGER + 2] == 19975 and R[11071][TRIGGER + 1] == 12494, 'trigger spells'),
    (R[118][AIF] & 0x2 and not R[853][AIF] & 0x2, 'aura interrupt flags'),
]
for ok, what in CHECKS:
    if not ok:
        raise SystemExit('Spell.dbc calibration failed: ' + what)

CC_MECHS = {1: 'charm', 2: 'disorient', 5: 'fear', 7: 'root', 10: 'sleep', 13: 'freeze', 14: 'knockout',
            17: 'polymorph', 20: 'shackle', 23: 'turn', 24: 'horror', 30: 'sapped', 12: 'stun'}
CC_AURAS = {5: 'confuse', 6: 'charm', 7: 'fear', 12: 'stun', 26: 'root', 56: 'transform'}
DAMAGE_TAKEN_PROCS = 0x000222A8 | 0x00100000   # taken melee/ranged/spell/periodic damage, "taken damage"

# Not reachable through class skill lines or trigger links; the same damage/CC filter still decides.
EXTRA = [51209,                       # Hungering Cold debuff (applied by script)
         3355, 14308, 14309, 60210,   # Freezing Trap / Freezing Arrow effects (trap objects)
         19185, 64803, 64804,         # Entrapment roots (trap objects)
         33395,                       # Water Elemental: Freeze
         4167, 50245, 54706,          # hunter pets: Web, Pin, Venom Web Spray
         55080,                       # Shattered Barrier freeze
         71319, 59634]                # Polymorph variants on no class skill line (Turkey #2, Penguin)

# --- candidates -----------------------------------------------------------
candidates = set(EXTRA)
for row in sla.rows.values():
    sl = skill.rows.get(row[1])
    if sl and sl[1] == 7 and row[2] in R:
        candidates.add(row[2])
for _ in range(2):                    # follow trigger chains two levels deep
    for s in list(candidates):
        for t in R[s][TRIGGER:TRIGGER + 3]:
            if t and t in R:
                candidates.add(t)


def duration(r):
    d = dur.rows.get(r[DUR])
    return (d[1] / 1000.0) if d and d[1] > 0 else 0


def category(r, mechs, auras, secs):
    if 7 in mechs or 26 in auras and not ({5, 6, 7, 12, 56} & auras):
        return 'root'
    if mechs & {5, 23, 24} or 7 in auras:
        return 'fear'
    if secs and secs <= 6:
        return 'short'
    return 'placed'


kept = {}
for s in sorted(candidates):
    r = R.get(s)
    if not r:
        continue
    any_damage = bool(r[AIF] & 0x2)
    proc_damage = bool(r[PROC] & DAMAGE_TAKEN_PROCS)
    if not (any_damage or proc_damage):
        continue
    auras = {a for a in r[AURA:AURA + 3] if a}
    mechs = {r[MECH]} | set(r[MECH_EFF:MECH_EFF + 3])
    mechs.discard(0)
    if not (mechs & set(CC_MECHS) or auras & set(CC_AURAS)):
        continue
    if 1 in r[TARGET_A:TARGET_A + 3] and not ({6} & set(r[TARGET_A:TARGET_A + 3])) and not (auras & {26, 7, 5}):
        continue                      # self-only effects (e.g. Ice Block)
    secs = duration(r)
    if secs == 0:
        continue                      # no lasting aura to break
    kept[s] = (spell.string(r[NAME]), spell.string(r[RANK]) or '', category(r, mechs, auras, secs),
               secs, 'any' if any_damage else 'proc')

# --- output ---------------------------------------------------------------
by_cat = {}
for s, (name, rank, cat, secs, how) in kept.items():
    by_cat.setdefault(cat, {}).setdefault(name, []).append((s, rank, secs, how))

lines = [
    '-- GENERATED by _reference/tools/gen_ccdata.py from this client\'s Spell.dbc. Do not edit by hand;',
    '-- re-run the generator instead. Every class/pet/talent crowd control that damage can break.',
    '-- [spellId] = { category, base duration in seconds, "any" = any damage breaks it / "proc" = damage may }',
    'local ADDON, ns = ...',
    'ns.CC_SPELLS = {',
]
for cat in ('placed', 'fear', 'root', 'short'):
    lines.append('\t-- %s' % cat)
    for name in sorted(by_cat.get(cat, {})):
        for s, rank, secs, how in sorted(by_cat[cat][name]):
            label = name + ((' (' + rank + ')') if rank else '')
            lines.append('\t[%d] = { "%s", %g, "%s" }, -- %s' % (s, cat, secs, how, label))
lines.append('}')
with open(out_path, 'w', encoding='utf-8', newline='\n') as fh:
    fh.write('\n'.join(lines) + '\n')

print('kept %d spell IDs -> %s' % (len(kept), out_path))
for cat in ('placed', 'fear', 'root', 'short'):
    names = by_cat.get(cat, {})
    print('%-7s %3d ids: %s' % (cat, sum(len(v) for v in names.values()), ', '.join(sorted(names))))
