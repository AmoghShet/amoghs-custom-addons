# Amogh's Custom Addons

UI addons for **World of Warcraft 3.3.5a** (Wrath of the Lich King, build 12340, `## Interface: 30300`), made for and tested on [Warmane](https://www.warmane.com). They aim to look like part of the default Blizzard UI.

## The addons

| Addon | What it does | Open settings |
|---|---|---|
| **ThreatManagement** | Your threat % under the target portrait, in Blizzard's threat colours. Alerts below the error text when a mob starts attacking you, and when someone breaks crowd control ("Polymorph on X broken by Y"). Optional threat % under nameplates. | `/tm` (`/tm help` lists commands) |
| **RecountBlizzardSkin** | Restyles [Recount](https://www.wowace.com/projects/recount) to look like Blizzard's own windows: dialog-banner header, Friz Quadrata title, Blizzard bar textures. Needs Recount. | `/rbs` |
| **AddonManager** | The character-select AddOn List, in game: search box, All / Enabled / Disabled filter, an **AddOns** button in the Esc menu. | `/addons` or `/am` |

All settings pages are also under **Interface > AddOns**.

## Install

1. On GitHub, **Code > Download ZIP**, then extract it.
2. Copy the addon folders you want (`ThreatManagement`, `RecountBlizzardSkin`, `AddonManager`) into `World of Warcraft\Interface\AddOns\`. Keep the folder names as they are.
3. Fully restart the game (3.3.5a only reads new addons at startup, not on `/reload`).

## What else is here

- `docs/knowledge-base.md`: a cited reference for building addons on the 3.3.5a client: which APIs exist, what differs from retail and Wrath Classic, and how each claim was verified.
- `CLAUDE.md`: the short version of those rules, used when building these addons with Claude Code.
- `_templates/AddonSkeleton`: a starter addon (events, saved variables, timers, combat-safe changes, options panel, slash command).
- `_devtools/ClientProbe`: a dev-only addon that records facts about the running client.
- `_reference/tools`: Python scripts that read the game's own files (MPQ archives, DBC tables, BLP textures).

## Reference data you generate yourself

Some reference material comes from your own game client and isn't published here. Recreate it with Python 3 and Pillow (`pip install pillow`), passing your client's folder:

```
python -I _reference/tools/extract.py "<WoW>/Data" _reference/BlizzardInterfaceCode
python -I _reference/tools/assetindex.py "<WoW>/Data" _reference/asset-paths.txt
python -I _reference/tools/exescan.py "<WoW>/Wow.exe" --index _reference/wow-exe-identifiers.txt
```

`ThreatManagement/CCData.lua` (the crowd-control spell list) is generated from the client's Spell.dbc by `_reference/tools/gen_ccdata.py`.

## License

MIT, see [LICENSE](LICENSE). World of Warcraft is a trademark of Blizzard Entertainment; this project isn't affiliated with Blizzard or Warmane.
