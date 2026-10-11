# WoW 3.3.5a addon development (Warmane) — project guide

This folder holds custom UI addons for the **World of Warcraft 3.3.5a** client at `D:\WoW WotLK`, played on Warmane.
The user may call it "3.5.5"; it is **3.3.5a, build 12340, TOC `## Interface: 30300`, Lua 5.1**.

Detailed, cited reference: [docs/knowledge-base.md](docs/knowledge-base.md). Read the relevant section before building anything non-trivial.

## Ground truth on this machine (verified 2026-10-11)

- `D:\WoW WotLK\Wow.exe` FileVersion 3.3.5.12340; realmlist `logon.warmane.com`.
- The UI code is **stock Blizzard 3.3.5**. Warmane's extra archives (`Data\patch-4.mpq`, `Patch-A/F/G/K/T.MPQ`) replace no FrameXML/Blizzard_* Lua or XML (only login-screen models, textures, creatures, DBC).
- Blizzard's UI source, extracted from this client's MPQs: `_reference/BlizzardInterfaceCode/Interface/{FrameXML,GlueXML,AddOns}` (440 files, includes `FrameXML/UI.xsd`). `SOURCE-MANIFEST.json` lists the archive each file came from.
- Addons load **only** from `D:\WoW WotLK\Interface\AddOns\<Name>\<Name>.toc`. This dev folder is outside it, so link each addon with an NTFS junction: `New-Item -ItemType Junction -Path "D:\WoW WotLK\Interface\AddOns\<Name>" -Target "D:\WoW WotLK\Amogh's Custom Addons\<Name>"` (**verified 2026-10-12**: junctioned ClientProbe and AddonSkeleton appear in the in-game AddOns list). Remove a link with `[System.IO.Directory]::Delete($path, $false)` in PowerShell (deletes only the link; refuses a real non-empty folder). `cmd /c rmdir` is blocked by this session's safety hook; never `Remove-Item -Recurse`.
- Addons the user removed are moved (not deleted) to `D:\WoW WotLK\Interface\AddOns_removed\` (2026-10-12: CameraPlus, the whole Cartographer suite, DiabolicUI, OneBag3, TitanCoords). Files the docs cite from them are copied to `_reference/third-party/`.
- Per-character addon on/off state: `WTF\Account\<ACCT>\<Realm>\<Char>\AddOns.txt`. Saved variables: account-wide `WTF\Account\<ACCT>\SavedVariables\<Addon>.lua`, per-character `WTF\Account\<ACCT>\<Realm>\<Char>\SavedVariables\<Addon>.lua` (client keeps a `.bak`).

## Verify before you use any API, template, event or widget method

Most online docs target retail or Wrath Classic (3.4.x, TOC 30400+), whose API is very different. Do not trust them for this client.

1. `grep -r` the name in `_reference/BlizzardInterfaceCode` (definition or Blizzard usage = exists).
2. Check working code in installed 30300 addons: `python -I _reference/tools/apiusage.py "D:/WoW WotLK/Interface/AddOns" 'Name('`.
3. On warcraft.wiki.gg, read the page's patch history. Added after 3.3.0 → **not available**. wowprogramming.com documents the 3.x/4.0 era (closer, but some pages show 4.x payloads).
4. Still unsure → say so, and guard: `if SomeFunc then ... end`.

Absence from all 440 Blizzard files is strong evidence for templates/Lua helpers; for C-side engine functions also need a second source.

## Not on this client → use instead

| Missing in 3.3.5a | Use instead |
|---|---|
| `C_Timer.After/NewTicker` | `OnUpdate` with an elapsed accumulator, or an `AnimationGroup` timer, or AceTimer-3.0 |
| `"BackdropTemplate"` | Plain `CreateFrame("Frame", name, parent)` then `f:SetBackdrop({...})` (native method) |
| `tex:SetColorTexture(r,g,b,a)` | `tex:SetTexture(r,g,b,a)` |
| `Mixin`, `CreateFromMixins`, object pools, `CallbackRegistry` | Write a small local helper |
| any `C_*` namespace (`C_Container`, `C_Map`, `C_Spell`, …) | the old global functions (`GetContainerItemInfo`, `GetSpellInfo`, …) |
| `GetNumGroupMembers`, `IsInGroup`, `IsInRaid` | `GetNumRaidMembers()`, `GetNumPartyMembers()` (inside a battleground these count the BG group; `GetRealNumRaidMembers/PartyMembers` count your own group) |
| `CombatLogGetCurrentEventInfo()` | CLEU args arrive in `OnEvent` directly (see below) |
| `RegisterAddonMessagePrefix` | not needed: just `SendAddonMessage(prefix, msg, channel[, target])` |
| `RegisterAttributeDriver` | `RegisterStateDriver(frame, "visibility", "[combat] hide; show")` |
| `BasicFrameTemplate`, `ButtonFrameTemplate`, `PortraitFrameTemplate`, `TranslucentFrameTemplate` | build the frame yourself, or `UIPanelDialogTemplate` |
| `## Interface: 30300, 11500` lists, `_Wrath.toc`/`_Classic.toc` flavor files, `IconTexture`, `Category`, `LoadSavedVariablesFirst` | plain single `MyAddon.toc` with `## Interface: 30300` |
| `GameTooltip:IsForbidden()`, `UnitIsTapDenied`, `SOUNDKIT`, `LE_*` enums | don't call them; DiabolicUI's `engine/blizzard-compatibility.lua` shows shims (copy in `_reference/third-party/DiabolicUI/`) |

## Rules that bite on 3.3.5a

- **TOC/load:** folder name must equal `.toc` name. Files load top to bottom; libraries first. SavedVariables are `nil` while your files run; read them in `ADDON_LOADED` when `arg1 == "MyAddon"`, then unregister.
- **Combat log:** `f:SetScript("OnEvent", function(self, event, timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)`. There is **no** `hideCaster` and **no** src/dst raid flags. Cata/Classic argument lists are shifted. (Confirmed by DBM-Core.lua:345 and Recount Tracker.lua on this machine.)
- **Combat lockdown:** `InCombatLockdown()` returns `1`/`nil`, so test truthiness, never `== true`. Protected changes (Show/Hide, SetPoint, SetAttribute on secure frames) are blocked in combat: queue them and apply on `PLAYER_REGEN_ENABLED`.
- **Secure action buttons** (`SecureActionButtonTemplate`) accept `type` = `actionbar, action, pet, multispell, spell, item, macro, cancelaura, stop, target, focus, assist, maintank, mainassist, click, attribute`. No `togglemenu`.
- **Group headers** (`SecureGroupHeaderTemplate` / `SecurePartyHeaderTemplate` / `SecureRaidGroupHeaderTemplate`): the header **must have a global name** or it hides itself. `template` = an XML template name (Blizzard's `SecureUnitButtonTemplate` works, so no XML of your own is needed); `templateType` defaults to `"Button"`; per-button Lua setup goes in `header.initialConfigFunction = function(btn) ... end` (a plain field, not an attribute); `initial-width/height/scale/anchor/unitWatch` attributes on children are applied for you. The header sets each child's `unit` attribute.
- **Options panel:** `panel.name` required (`parent`, `okay`, `cancel`, `default`, `refresh` optional), then `InterfaceOptions_AddCategory(panel)`. To open it, call `InterfaceOptionsFrame_OpenToCategory(panel)` **twice**: the first call shows the frame, whose OnShow selects "Controls". Only visible list rows are searched.
- **Debugging built in:** `/console scriptErrors 1` (errors are hidden by default), `/fstack` (`/framestack`), `/etrace` (`/eventtrace`), `/dump <expr>` (raise `DEVTOOLS_MAX_ENTRY_CUTOFF`/`DEPTH_CUTOFF` for bigger dumps), `/reload`, `print(...)`.
- **Animations:** types Alpha, Scale, Translation (not "Translate"), Rotation, Path. **Alpha is relative**: `anim:SetChange(-1)`. There is no `SetFromAlpha/SetToAlpha`.
- **Draw layers:** only `BACKGROUND, BORDER, ARTWORK, OVERLAY, HIGHLIGHT`. **No sublevels**: `SetDrawLayer(layer)` takes one arg; XML has no `textureSubLevel`. Textures in the **same layer have no guaranteed order** (creation order doesn't decide it), so anything that must sit on top of other art goes in a higher layer (AddonManager's divider strips showed the dark list background through as a "black notch" until moved from BACKGROUND to BORDER; Blizzard's AddonList.xml puts them in ARTWORK).
- **Template children are found by global name** (`_G[name.."ScrollBar"]`, `_G[name.."Text"]`): give every frame built from `UIPanelScrollFrameTemplate`, `FauxScrollFrameTemplate`, `OptionsSliderTemplate` or the options check buttons a **global name**, or it errors / you can't reach its labels.
- **Secure handlers:** `SecureHandlerWrapScript`/`SecureHandlerExecute` need an **explicitly protected** header (inherit `SecureHandlerBaseTemplate`/`SecureFrameTemplate`); only 12 scripts are wrappable (OnClick, OnDoubleClick, PreClick, PostClick, OnEnter, OnLeave, OnShow, OnHide, OnDragStart, OnReceiveDrag, OnMouseWheel, OnAttributeChanged); set up wraps and state drivers out of combat.
- **Nameplates** are unnamed `WorldFrame` children: no unit token, GUID, `NAME_PLATE_*` events or `C_NamePlate`. Detect by polling `WorldFrame:GetNumChildren()`.
- **Unit events:** `UNIT_MANA/RAGE/ENERGY/FOCUS/RUNIC_POWER/HAPPINESS` (+`UNIT_MAX*`, `UNIT_DISPLAYPOWER`); no `UNIT_POWER`. Smooth bars: poll `UnitHealth` in `OnUpdate`, `SetValue` only on change (Blizzard's own pattern).
- **Returns:** `UnitAura/UnitBuff/UnitDebuff` → `name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, shouldConsolidate, spellId` (11 values; retail's no-rank/spellId-10th form is wrong here). `GetSpellInfo` → `name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange`. Talent APIs take `(tab, [index,] inspect, pet, talentGroup)`; `GetTalentTabInfo` returns 5 values.
- **Events that differ:** group changes = `RAID_ROSTER_UPDATE` + `PARTY_MEMBERS_CHANGED` (no `GROUP_ROSTER_UPDATE`); inspect = `NotifyInspect` → `INSPECT_TALENT_READY` (no `INSPECT_READY`; requests can silently drop, so use timeouts); `PLAYER_ENTERING_WORLD` fires on every loading screen with **no args**; no `UNIT_HEALTH_FREQUENT`, `GET_ITEM_INFO_RECEIVED`, `UNIT_ABSORB_AMOUNT_CHANGED`.
- **Uncached items:** `GetItemInfo` returns nil until cached: prime with a hidden tooltip `SetHyperlink("item:"..id)` and retry ~1 s later.
- **Lua:** no `os`/`io` (use `date()`, `time()`, `difftime()`, `GetTime()`); `bit` has only `bnot band bor bxor lshift rshift arshift mod`; time code with `debugprofilestop()` deltas, never call `debugprofilestart()`.
- **Protection direction:** anchoring/parenting a secure frame **to your frame** makes your frame protected in combat; the reverse doesn't. Never write globals Blizzard reads (including `_`). Make ESC close your window with `tinsert(UISpecialFrames, "MyFrameName")`.
- **Pixel-perfect:** `uiScale = 768 / screenHeight` (slider range 0.64–1.0). Taint debugging: `/console taintLog 1` → `Logs\taint.log`.
- **Slash commands:** `SLASH_MYADDON1 = "/myaddon"`; `SlashCmdList.MYADDON = function(msg, editBox) end` (msg is already trimmed).
- **Texture/font paths:** grep `_reference/asset-paths.txt` (every Interface\ and Fonts\ path in this client). E.g. `Interface\Buttons\WHITE8X8` exists; `Interface\RaidFrame\Raid-Bar-Hp-Fill` does not.

- **Reload vs restart:** `/reload` re-runs existing `.lua`/`.xml`, but a new addon folder, a new file, or any `.toc` edit needs a **full client restart** (verified in game 2026-10-12 by ClientProbe; docs §25).
- **Lua has no `debug` library** either (probe: `debug == nil`).
- **Addon messages:** `SendAddonMessage(prefix, msg, channel[, target])` only on `PARTY/RAID/GUILD/BATTLEGROUND/WHISPER`; keep `#prefix + #msg <= 254` or the server silently drops it; flooding (100 addon msgs or 10 chat lines per second on stock cores) mutes you for ~10 s. Use ChatThrottleLib/AceComm for traffic and pace chat announcements yourself.

## Libraries

- LibStub keeps the **highest MINOR** across all addons, so an embedded copy affects every addon. Only embed 3.3.5-safe versions.
- **Do not** drop in current upstream Ace3 (its AceTimer needs `C_Timer`). Ace3 `Release-r960` is the last 30300 release; r971-era minors also work here (Recount runs AceConfigDialog 50).
- First choice: copy libs already installed here (`D:\WoW WotLK\Interface\AddOns\*\libs`, versions in docs §13). Second: NoM0Re/WeakAuras-WotLK `WeakAuras/Libs` (3.3.5-maintained; its AceTimer is an OnUpdate backport, MINOR 1018).
- Ketho's VS Code "WoW API" extension does **not** know 3.3.5; don't trust its hovers for availability.

## Templates that exist in this client (safe to inherit)

`UIPanelButtonTemplate`, `UIPanelCloseButton`, `UIPanelDialogTemplate`, `InputBoxTemplate`, `UIPanelScrollFrameTemplate`, `FauxScrollFrameTemplate`, `HybridScrollFrameTemplate`, `UIDropDownMenuTemplate`, `GameTooltipTemplate`, `OptionsCheckButtonTemplate`, `InterfaceOptionsCheckButtonTemplate`, `OptionsSliderTemplate`, `ChatConfigCheckButtonTemplate`, `SecureUnitButtonTemplate`, `SecureActionButtonTemplate`, `SecureHandler*Template` (State, Attribute, Click, DoubleClick, Drag, ShowHide, MouseUpDown, MouseWheel, EnterLeave). Check `_reference` for anything else.

## Tools in this folder

- `_reference/tools/exescan.py`: checks whether a function/event/CVar name exists as a string in `Wow.exe`; `_reference/wow-exe-identifiers.txt` is the full 10,750-name index. PRESENT = strong evidence; "absent" is only meaningful with a second source (it misses `wipe`, `tinsert`).
- `_reference/asset-paths.txt`: every texture/font path in the client.
- `_reference/tools/blp2png.py`: extracts any client texture (BLP) to PNG so it can be viewed with Read; use it to measure texcoords (PIL is installed). E.g. the Character/Spellbook header strip is rows 13-33 of `UI-Character-General-TopRight` (128x256), close slot x 69-92.
- `_reference/tools/dbc.py`: reads any client DBC table out of the MPQs (`load_dbc(DATA, "Spell")`). Spell.dbc lives only in the enUS archives (Warmane patches don't override it). Calibrated 3.3.5 Spell.dbc fields: 3 Mechanic, 4 Attributes, 32 AuraInterruptFlags (`0x2` = removed by any damage), 34 procFlags (`0x100000` = proc on damage taken), 40 DurationIndex (→ SpellDuration.dbc field 1 ms), 95-97 EffectApplyAuraName, 136 Name (enUS), 153 Rank. SkillLineAbility: 1 SkillLine, 2 Spell; SkillLine: 1 category (7 = class skills), 3 name. Calibrate against known spells before trusting a field (e.g. 118 = Polymorph Rank 1).
- `_reference/tools/gen_ccdata.py`: regenerates `ThreatManagement/CCData.lua` (every class/pet/talent CC that damage can break, with category and base duration) from Spell.dbc. Exact Spell.dbc layout it asserts: 71-73 Effect, 83-85 EffectMechanic, 86-88 ImplicitTargetA, 95-97 EffectApplyAuraName (note: 95, not 94), 115-117 EffectTriggerSpell.
- **Load-order gotcha:** AceAddon `OnInitialize` runs at that addon's own `ADDON_LOADED`, before dependants load, so anything it builds there (e.g. Recount's main/detail/graph windows) must be handled directly at your load, not via hooks.
- `_templates/AddonSkeleton`: verified starter addon (events, saved vars, OnUpdate timers, combat queue, movable backdrop frame, options panel, slash command). Loaded in game during the junction test; unlinked from AddOns 2026-10-12 at the user's request (source stays here).

- `_reference/tools/mpq.py`: read-only MPQ reader for 3.3.5 archives (zlib/bzip2/implode). `extract.py` re-extracts the UI code; `probe.py` checks custom patches for UI overrides; `apiusage.py` counts API use in installed 30300 addons. Run with `python -I`.
