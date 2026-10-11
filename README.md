# Amogh's Custom Addons

UI addons for **World of Warcraft 3.3.5a** (Wrath of the Lich King, build 12340), made for and tested on [Warmane](https://www.warmane.com). They should work on any 3.3.5a server; they won't work on retail or Wrath Classic, whose addon API is different.

Two ideas run through all of them:

- **Look like part of the game.** Blizzard's own fonts, colours, textures and window art, so nothing looks bolted on.
- **Show, don't play for you.** They surface information the game already has (threat, who's attacking you, who broke crowd control) and leave every decision to you.

| Addon | In one line | Open settings |
|---|---|---|
| [ThreatManagement](#threatmanagement) | Your threat % on the target frame, plus "mob is attacking you" and "crowd control broken" alerts | `/tm` |
| [Recount Blizzard Skin](#recount-blizzard-skin) | Makes the Recount damage meter look like a Blizzard window | `/rbs` |
| [AddonManager](#addonmanager) | The character-select AddOn List, in game, with search and filters | `/addons` |

Every addon also has a settings page under **Esc > Interface > AddOns**.

## Install

1. On GitHub, click **Code > Download ZIP** and extract it.
2. Copy the addon folders you want (`ThreatManagement`, `RecountBlizzardSkin`, `AddonManager`) into `World of Warcraft\Interface\AddOns\`. Keep the folder names exactly as they are.
3. Fully restart the game. 3.3.5a only picks up new addons at startup, not on `/reload`.

Recount Blizzard Skin also needs [Recount](https://www.wowace.com/projects/recount) installed.

---

## ThreatManagement

Threat information where your eyes already are in combat, plus two kinds of alert in the same spot and style as Blizzard's red error text and Deadly Boss Mods' warnings.

### Threat % on the target frame

- Shows your threat on the current target as a number under the target's portrait. When the target-of-target frame is showing, it moves under that instead so the two never overlap.
- It's the same number as Blizzard's own threat readout, coloured the way Blizzard colours threat, so the colour shifts as you get closer to pulling aggro and turns red once you have it.
- Hidden when you have no threat on the target.
- Settings: text size, left/right and up/down position, a 20-second preview so you can place it without being in combat, and an option to hide Blizzard's own threat box above the target frame.

### Aggro alerts

A red **"Bonechewer Raider is attacking you!"** appears just below Blizzard's error text the moment a mob turns on you.

- A mob counts as attacking you when it auto-attacks you (melee or ranged), or when any unit you can see (target, focus, mouseover, party/raid members' targets) is targeting you. Spell damage alone doesn't count, so a boss's area attack doesn't trigger false alarms.
- Each mob alerts once per fight. After 10 seconds with no contact, it can alert again.
- Several mobs at once are grouped: "X and Y are attacking you!", "X and 3 others are attacking you!".
- Solo, mobs you pulled yourself don't alert, since you already know. In a group, every new attacker does.
- Settings: on/off, an optional raid-warning sound, alert size, and a test button.

### Crowd-control break alerts

An orange **"Polymorph on Bonechewer Raider broken by Varian (Swipe)"** tells you whose crowd control broke, who broke it and with what. The breaker's name is shown in their class colour; your own breaks read "You broke…" and "Your pet broke…". If one hit breaks CC on several mobs, they're grouped into one line.

- **Covers every crowd control in the game that damage can break**: 86 spell IDs across all ranks, generated from the client's own spell data rather than a hand-written list. They come in four groups you can switch on and off separately:
  - **Placed CC:** Polymorph (every variant), Sap, Blind, Freezing Trap, Freezing Arrow, Wyvern Sting, Shackle Undead, Hibernate, Repentance, Seduction, Hex, Hungering Cold
  - **Fears:** Fear, Howl of Terror, Psychic Scream, Intimidating Shout, Scare Beast, Turn Evil
  - **Roots:** Frost Nova, Frostbite, Entangling Roots, Freeze (Water Elemental), Shattered Barrier
  - **Short CC:** Gouge, Dragon's Breath, Scatter Shot
- **Whose CC:** your whole group's (the default), or only your own.
- **Optional chat announce:** when someone breaks *your* placed CC, say so in party or raid chat.
- How breaks are detected: the game has a dedicated "broken" combat-log event, but the open-source server software most private servers are built on never sends it. So the addon also watches for crowd control that ends noticeably before its timer, right after the target took a hit; the last hitter is the breaker. That check is what keeps roots and fears that simply run out from counting as breaks. Fully absorbed hits count (they break CC too), and Hungering Cold ignores Death Knight diseases, which don't break it.

### Threat on nameplates (optional, off by default)

- Shows your threat % under enemy nameplates while nameplates are on (press **V**).
- 3.3.5 nameplates don't say which mob they belong to, so each plate is matched to a mob the game *can* report threat for: your target, your mouseover, raid-marked mobs, and mobs your party or raid is targeting. Plates it can't match show nothing rather than a guess.
- The last known value stays up, faded, for a few seconds after a plate stops matching.
- Settings: on/off, text size, and how long to keep the faded value.

### Commands

| Command | Does |
|---|---|
| `/tm` | Open the settings page |
| `/tm help` | List every command and the current settings |
| `/tm test` | Show a sample 75% on the target frame for 20 seconds |
| `/tm on` / `off` | Turn the target-frame number on or off |
| `/tm size <n>` / `pos <x> <y>` | Text size (0.5–2) and offset of the target-frame number |
| `/tm blizzard on` / `off` | Show or hide Blizzard's threat box above the target frame |
| `/tm alerts on` / `off`, `alerts sound on` / `off`, `alerts size <n>`, `alerts test` | Aggro alerts |
| `/tm cc` / `cc test` | Open the Crowd Control settings page / show a sample alert |
| `/tm plates on` / `off`, `platesize <n>`, `platepos <x> <y>`, `stale <sec>` | Nameplate threat |
| `/tm reset` | Back to default settings |

---

## Recount Blizzard Skin

Restyles [Recount](https://www.wowace.com/projects/recount) so its windows look like they shipped with the game. It never edits Recount's files: turn this addon off and Recount looks exactly as it did.

### Windows

- Tooltip-style border and dark background in Blizzard's tooltip colours.
- A choice of three headers:
  - **Banner** (default): the gold-trimmed banner from the Video and Interface options windows.
  - **Title bar:** the dark stone strip from the Character and Spellbook windows, with the close button in its slot.
  - **Plain:** no header art, just the tooltip-style window.
- Window titles always use Friz Quadrata, the game's own UI font.
- Restyled scrollbars and resize grips, and an optional dark strip behind each bar.
- Applies to every Recount window: the main meter, the detail window and the graphs.

### Colours, bars and font

- The first time it runs on a Recount profile, it sets Recount's colours, bar texture and font to Blizzard's: grey outline, gold title, the health-bar texture and Friz Quadrata.
- These go into Recount's own settings, so you can keep fine-tuning them in Recount's configuration.
- One button switches back to Recount's originals (red outline, white title, Recount's bars and Arial font), another back to Blizzard's. You can mix: Recount's colours with Blizzard's window shape and header works fine.

### Commands

| Command | Does |
|---|---|
| `/rbs` | Open the settings page |
| `/rbs header banner` / `bar` / `plain` | Pick the header style |
| `/rbs apply` | Blizzard colours, bars and font |
| `/rbs restore` | Recount's original colours, bars and font |

---

## AddonManager

The AddOn List from the character-select screen, available in game, with a search box and a filter. No need to log out to check or switch an addon.

- **Open it** from the new **AddOns** button in the Esc menu (between Macros and Log Out), or with `/addons` or `/am`.
- **Search** as you type, by addon title or folder name.
- **Filter** to All, Enabled or Disabled.
- Each row shows the addon's status the same way Blizzard's list does: "Dependency missing", "Out of date", "Only loadable on demand" and so on.
- Hover an addon for its description, dependencies, version and, if it's loaded, how much memory it uses.
- **Nothing changes until you press Okay.** Ticking boxes only marks changes; once anything has changed, Okay becomes **Reload UI**, because the game only loads or unloads addons on a reload. Cancel, the X or Esc throws the changes away.
- When a search or filter is active, **Enable All / Disable All** become **Enable Shown / Disable Shown** and only affect the addons in the list.

---

## For developers

The repo also holds everything used to build these addons:

- `docs/knowledge-base.md`: a cited reference for building addons on the 3.3.5a client: which APIs exist, what differs from retail and Wrath Classic, and how each claim was verified.
- `CLAUDE.md`: the short version of those rules, used when building these addons with Claude Code.
- `_templates/AddonSkeleton`: a starter addon (events, saved variables, timers, combat-safe changes, options panel, slash command).
- `_devtools/ClientProbe`: a dev-only addon that records facts about the running client.
- `_devtools/sync_addons.py`: copies the addons from this repo into the game's `Interface\AddOns` folder (`python -I _devtools/sync_addons.py "<WoW>/Interface/AddOns"`). Only new or changed files are copied; nothing is deleted.
- `_reference/tools`: Python scripts that read the game's own files (MPQ archives, DBC tables, BLP textures).

### Reference data you generate yourself

Some reference material comes from your own game client and isn't published here. Recreate it with Python 3 and Pillow (`pip install pillow`), passing your client's folder:

```
python -I _reference/tools/extract.py "<WoW>/Data" _reference/BlizzardInterfaceCode
python -I _reference/tools/assetindex.py "<WoW>/Data" _reference/asset-paths.txt
python -I _reference/tools/exescan.py "<WoW>/Wow.exe" --index _reference/wow-exe-identifiers.txt
```

`ThreatManagement/CCData.lua` (the crowd-control spell list) is generated from the client's Spell.dbc by `_reference/tools/gen_ccdata.py`.

## License

MIT, see [LICENSE](LICENSE). World of Warcraft is a trademark of Blizzard Entertainment; this project isn't affiliated with Blizzard or Warmane.
