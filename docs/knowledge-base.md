# WoW 3.3.5a (Warmane) UI addon knowledge base

Verified reference for building UI addons for the client at `D:\WoW WotLK` (Wow.exe 3.3.5.12340, TOC `## Interface: 30300`).
Built 2026-10-11/12 from three deep-research rounds plus a research-mode verification pass against the files on this machine.

## How to read the evidence tags

| Tag | Meaning |
|---|---|
| **[LOCAL]** | Checked directly on this machine: Blizzard UI code extracted from this client's MPQs (`_reference/BlizzardInterfaceCode`), installed addon code, or WTF files. Strongest evidence. |
| **[PRIMARY]** | Primary web source: Blizzard's 3.3.5 FrameXML dump (github.com/wowgaming/3.3.5-interface-files), library source code, a project's own repo or README. |
| **[SECONDARY]** | warcraft.wiki.gg / wowprogramming.com. Reliable, but wiki pages describe current clients; 3.3.5 status is inferred from patch-history dates. |
| **[FORUM]** | Forum or community posts only. Lower confidence; test in game. |
| **[REASONING]** | My inference from the cited evidence. The assumption is stated. |

Anything not covered here is **unknown**: check `_reference` and installed addons before assuming it exists.

---

## 1. The client on this machine

- `Wow.exe` FileVersion **3.3.5.12340**, realmlist `logon.warmane.com`. [LOCAL]
- Archive load order for UI code: `Data\enUS\locale-enUS.MPQ` → `patch-enUS.MPQ` → `patch-enUS-2.MPQ` → `patch-enUS-3.MPQ` (later overrides earlier). 440 code files survive; 24 names are delete-markers in `patch-enUS.MPQ` (old `ThreatMeter`, `OptionsFrame`, `UIOptionsFrame`, `CombatLog.lua`, `Blizzard_VehicleUI`), so they are **not** part of the live UI. [LOCAL]
- Warmane's additional archives override **no** UI code. `Patch-F.MPQ` and `Patch-T.MPQ` replace login-screen (`Interface\GLUES\MODELS`) textures and creature/world art; `patch-4`, `Patch-G`, `Patch-K` hold textures and DBC files; `Patch-A` matched none of the 14,646 known `Interface\` names. Caveat: `Patch-A`/`Patch-T` have no `(listfile)`, so only known names could be tested. [LOCAL]
- `Interface\AddOns\Blizzard_*` on disk contain only `.pub` signature files; the real code is inside the MPQs. [LOCAL]
- `FrameXML.toc` line 3: `## Interface: 30300`. [LOCAL] [PRIMARY]

## 2. Addon structure and loading

- **Folder and TOC name must match:** `Interface\AddOns\MyAddon\MyAddon.toc`. A mismatch means the addon is not listed. GitHub zips unpack as `MyAddon-master`; rename. [SECONDARY] (warcraft.wiki.gg/wiki/TOC_format) + [FORUM] (Phanx, WoWInterface)
- **`## Interface: 30300`.** 24 of the 27 installed addons use it. [LOCAL] A different value marks the addon "out of date"; it still loads if "Load out of date AddOns" is ticked. [SECONDARY] Example: DiabolicUI (`## Interface: 70300`) has a SavedVariables file here, so it did load at some point. [LOCAL] [REASONING: assumes the file was written by this client, not copied]
- **Load order:** files listed in the TOC load top to bottom; XML `<Script file=…>` and `<Include file=…>` load at the point they are parsed. Put `LibStub`/`embeds.xml` first. Separate-addon libraries are ordered with `## Dependencies` / `## OptionalDeps`. [SECONDARY]
- **TOC features that do not exist on 3.3.5a** (all added years later per wiki patch history): flavor-suffixed TOCs (`_Wrath.toc`, `_Classic.toc`, 2021), comma-separated Interface values (10.2.7), `IconTexture`/`IconAtlas`/addon compartment (10.1.0), `Category`/`Group` (11.1.0), `LoadSavedVariablesFirst` (11.1.5). The wiki's "Wrath" value 30405 is Wrath Classic. [SECONDARY]
- **SavedVariables:** `## SavedVariables:` → `WTF\Account\<ACCT>\SavedVariables\<Addon>.lua`; `## SavedVariablesPerCharacter:` → `WTF\Account\<ACCT>\<Realm>\<Char>\SavedVariables\<Addon>.lua`. The client also writes `<Addon>.lua.bak`. [LOCAL]
- SavedVariables load **after** the addon's last file, so they are `nil` at file scope. Read them in `ADDON_LOADED` when `arg1` is your addon name. `VARIABLES_LOADED` has been unreliable for this since 3.0.2. [SECONDARY]
- Per-character enable list: `WTF\Account\<ACCT>\<Realm>\<Char>\AddOns.txt` (`Name: enabled|disabled`). [LOCAL]

```lua
local ADDON, ns = ...                  -- addon folder name + private table shared by the addon's files
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        MyAddonDB = MyAddonDB or {}    -- SavedVariables now available
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
```
`local ADDON, ns = ...` [LOCAL]: DiabolicUI (states 3.3.5a support, and has run on this client) opens its files with `local ADDON, Engine = ...`.

## 3. API availability

### 3.1 Missing on 3.3.5a, with replacements

| Missing | Evidence | Replacement |
|---|---|---|
| `C_Timer.*` (added 6.0.2) | 0 uses in 440 Blizzard files and 24 installed 30300 addons; 56 `OnUpdate` timers instead [LOCAL]; wiki patch history [SECONDARY] | `OnUpdate` accumulator, `AnimationGroup` timer (`CreateAnimationGroup` used by OmniCC here [LOCAL]), AceTimer-3.0 |
| `BackdropTemplate` (9.0.1 retail, 1.14.0 Classic) | 0 references in Blizzard code [LOCAL]; DBM-Core calls `SetBackdrop` on template-less frames, 45 `SetBackdrop` calls in 30300 addons [LOCAL] | `f:SetBackdrop({bgFile=…, edgeFile=…, tile=…, tileSize=…, edgeSize=…, insets={…}})` |
| `Texture:SetColorTexture` (7.0.3) | DiabolicUI adds it as an alias of `SetTexture` for pre-Legion clients [LOCAL]; 0 Blizzard refs [LOCAL] | `tex:SetTexture(r, g, b, a)` |
| `Mixin`, `CreateFromMixins` (7.0.3), Pools, `CallbackRegistry` | 0 Blizzard refs; no `Mixin.lua`/`SharedXML` [LOCAL]; ClassicAPI ships shims [PRIMARY] | local helper functions |
| `C_*` namespaces | 0 Blizzard refs [LOCAL]; ClassicAPI shims ~60 files [PRIMARY] | old global functions |
| `GetNumGroupMembers`, `IsInGroup`, `IsInRaid` (5.0.4) | DiabolicUI shims all three for pre-MoP; 0 uses in 30300 addons; Blizzard uses `GetNumRaidMembers` 65 times [LOCAL] | `GetNumRaidMembers`, `GetNumPartyMembers`, `GetRealNumRaidMembers`, `GetRealNumPartyMembers` |
| `CombatLogGetCurrentEventInfo` (8.0.1) | wiki [SECONDARY]; DBM/Recount read OnEvent args [LOCAL] | see §4 |
| `RegisterAddonMessagePrefix` (4.1) | 0 uses; GearScore calls `SendAddonMessage` without it [LOCAL] | none needed |
| `RegisterAttributeDriver` | 0 refs; `SecureStateDriver.lua` only defines `RegisterStateDriver`, `UnregisterStateDriver`, `RegisterUnitWatch`, `UnregisterUnitWatch` [LOCAL] | `RegisterStateDriver(frame, "visibility", "[combat] hide; show")` |
| `GameTooltip:IsForbidden`, `UnitIsTapDenied`, `GetAverageItemLevel`, `PlaySoundKitID`, `SOUNDKIT`, `LE_*` enums | all shimmed by DiabolicUI for 3.3.5 [LOCAL] | avoid, or shim |

### 3.2 Present on 3.3.5a (Blizzard code or 30300 addons use them) [LOCAL]

`wipe`/`table.wipe`, `strsplit`, `strjoin`, `strtrim`, `tContains`, `tinsert`, `tremove`, `debugstack`, `geterrorhandler`, `seterrorhandler`, `securecall`, `issecure`, `forceinsecure`, `loadstring`, `bit.band`, `GetTime`, `GetBuildInfo`, `hooksecurefunc`, `issecurevariable`, `CreateAnimationGroup`, `SendAddonMessage`, `GetAddOnMemoryUsage`, `UpdateAddOnMemoryUsage`, `GetAddOnCPUUsage`, `UnitAura`, `SetDrawLayer`, `SetTexCoord`, `SetUserPlaced`, `SetClampedToScreen`, `GetEffectiveScale`, `SetResizable`, `SetBackdrop`, `InCombatLockdown`, `UNIT_MANA` event.
Not seen in either corpus, so **unconfirmed** (may still exist; check before use): `debugprofilestart/stop`, `SetGradient`, `SetGradientAlpha`, `UNIT_POWER`, `UNIT_HEALTH_FREQUENT`, `UnitGetIncomingHeals`, `SecureHandlerWrapScript` usage by addons (the function itself is defined in `SecureHandlers.lua:651` [LOCAL]).

### 3.3 Wrath Classic is a different platform

Wrath Classic (3.4.x, TOC 30400+) pulled in API from retail 9.2.5 (at 3.4.0) and 10.1.0 (at 3.4.2). Its docs and addons are not valid references for 3.3.5a. [SECONDARY] (warcraft.wiki.gg Patch_3.4.0/API_changes, Patch_3.4.2/API_changes)

### 3.4 ClassicAPI

gitlab.com/Tsoukie-3.3.5/classicapi: a plain addon (no client patch) that shims Classic-era APIs (C_Timer, C_Container, Mixin, Pools, CallbackRegistry, NineSlice, PixelUtil…) on 3.3.5a. Self-described early development; had a breaking Enum refactor (1.21). Useful when porting Classic addons, or as reference code. [PRIMARY, single self-describing source]

## 4. Events and the combat log

- `COMBAT_LOG_EVENT_UNFILTERED` delivers its payload as `OnEvent` arguments:
  `OnEvent(self, event, timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)`. [LOCAL] DBM-Core.lua:345, Recount Tracker.lua:387+ [PRIMARY] 3.3.5 `Blizzard_CombatLog.lua` `CombatLog_OnEvent`
- No `hideCaster` (added 4.1.0), no `sourceRaidFlags`/`destRaidFlags` (4.2.0). Arg lists from Cata/Classic/wowprogramming's CLEU page are shifted by 1–3. [SECONDARY]
- Subevent-specific tails as used by Recount here [LOCAL]:
  - `SWING_DAMAGE`: `amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing`
  - `SPELL_DAMAGE` / `RANGE_DAMAGE` / `SPELL_PERIODIC_DAMAGE`: `spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing`
  - `SPELL_HEAL`: `spellId, spellName, spellSchool, amount, overheal, absorbed, critical`
  - `SWING_MISSED`: `missType, missAmount`; `SPELL_MISSED`: `spellId, spellName, spellSchool, missType, missAmount`
  - `SPELL_AURA_APPLIED`: `spellId, spellName, spellSchool, auraType, amount`
  - `SPELL_DRAIN`: `spellId, spellName, spellSchool, amount, powerType, extraAmount`
  - `ENVIRONMENTAL_DAMAGE`: `environmentalType, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing`

## 5. Secure code, combat lockdown, taint

- `InCombatLockdown()` returns **`1` or `nil`** (not a boolean). [SECONDARY] wowprogramming.com/docs/api/InCombatLockdown. Use truthiness.
- Lockdown starts after `PLAYER_REGEN_DISABLED` fires and ends before `PLAYER_REGEN_ENABLED` fires, so both handlers may still touch protected frames. Queue protected changes made during combat; apply them on `PLAYER_REGEN_ENABLED`; re-check `InCombatLockdown()` first. [SECONDARY] + [FORUM]
- **SecureActionButtonTemplate** `type` values in 3.3.5 (`SECURE_ACTIONS` keys): `actionbar, action, pet, multispell, spell, item, macro, cancelaura, stop, target, focus, assist, maintank, mainassist, click, attribute`. No `togglemenu` (5.2), no `InsecureActionButtonTemplate` (7.2). [LOCAL] `SECURE_ACTIONS.*` in this client's SecureTemplates.lua
- **Group headers** (`SecureGroupHeaderTemplate`, `SecurePartyHeaderTemplate`, `SecureRaidGroupHeaderTemplate` + pet variants), defined in `SecureTemplates.xml/.lua` [LOCAL]:
  - Header without a name: `if not ( name ) then self:Hide(); return; end`. [PRIMARY]
  - Children: `CreateFrame(templateType, name.."UnitButton"..i, self, buttonTemplate)`, `buttonTemplate = GetAttribute("template")`, `templateType` default `"Button"`. [PRIMARY]
  - Per-child setup: `header.initialConfigFunction` (a Lua **field**) is run via `securecall` on each new child; then `initial-anchor`, `initial-width`, `initial-height`, `initial-scale`, `initial-unitWatch` attributes are applied. [PRIMARY]
  - Children get `unit` set / cleared via `SetAttribute("unit", …)`. [PRIMARY]
  - Attributes: `showRaid, showParty, showPlayer, showSolo, nameList, groupFilter, strictFiltering, point, xOffset, yOffset, sortMethod ("INDEX"|"NAME"), sortDir, template, templateType, groupBy (nil|"GROUP"|"CLASS"|"ROLE"), groupingOrder, maxColumns, unitsPerColumn, startingIndex, columnSpacing, columnAnchorPoint`. [PRIMARY]
- **Secure handlers present** [LOCAL]: templates `SecureHandlerBase/State/Attribute/Click/DoubleClick/Drag/ShowHide/MouseUpDown/MouseWheel/EnterLeave`; functions `SecureHandlerWrapScript` (SecureHandlers.lua:651), `SecureHandlerExecute` (:708), `SecureHandlerSetFrameRef` (:723), `RegisterStateDriver`, `RegisterUnitWatch`. `state-visibility` is special-cased (shows/hides the frame); the state driver re-evaluates every 0.2 s (`STATE_DRIVER_UPDATE_THROTTLE`).

### Round-1 claims that failed verification, re-examined

| Claim as worded | Status | Evidence |
|---|---|---|
| "A raid-frame addon needs at least one XML file" | **False.** `template` can be Blizzard's `SecureUnitButtonTemplate`; per-button setup goes in the Lua `header.initialConfigFunction`. | [PRIMARY] SecureTemplates.lua |
| "`InCombatLockdown()` returns a boolean" | **False.** Returns `1`/`nil`. | [SECONDARY] wowprogramming |
| "A secure button's parents become protected; it must be created out of combat" | Unresolved here; see §9 (round 2). | |
| "Restrictions reach frames anchored to a protected frame" | Unresolved here; see §9 (round 2). | |

## 6. Options panels and slash commands

- `InterfaceOptions_AddCategory(frame, addOn, position)`; `frame.name` required; `frame.parent` (string) makes it a sub-category; optional `okay`, `cancel`, `default`, `refresh` methods (filled with no-ops when missing). [LOCAL] InterfaceOptionsFrame.lua
- `InterfaceOptionsFrame_OpenToCategory(panelOrName)` must be called **twice** when the frame is closed. Reason in the code: it searches the *visible* list buttons, then shows the frame; `InterfaceOptionsFrame_OnShow` refreshes the lists and opens `CONTROLS_LABEL` if nothing is displayed. Panels scrolled out of view are never selected. [LOCAL] [REASONING from the code]

## 7. Debugging tools built into this client

- `/framestack` or `/fstack`, `/eventtrace` or `/etrace`, `/dump <expr>`: defined in `ChatFrame.lua:2246-2265` and `GlobalStrings.lua:6472-6513`; they load `Blizzard_DebugTools` on demand. `/reload` → `ReloadUI`. [LOCAL]
- `Blizzard_DebugTools` files: `Blizzard_DebugTools.lua/.xml/.toc`, `Dump.lua`, `Localization.lua`. [LOCAL]
- Lua errors are hidden by default: `/console scriptErrors 1`. `scriptErrors` is not set in this machine's `Config.wtf`. [LOCAL]

## 8. Templates and animation

Exist in this client [LOCAL]: `UIPanelButtonTemplate`, `UIPanelCloseButton`, `UIPanelDialogTemplate`, `InputBoxTemplate`, `UIPanelScrollFrameTemplate`, `FauxScrollFrameTemplate`, `HybridScrollFrameTemplate`, `UIDropDownMenuTemplate`, `GameTooltipTemplate`, `OptionsCheckButtonTemplate`, `InterfaceOptionsCheckButtonTemplate`, `OptionsSliderTemplate`, `ChatConfigCheckButtonTemplate`, the secure templates above.
Do **not** exist: `BasicFrameTemplate`, `ButtonFrameTemplate`, `PortraitFrameTemplate`, `BackdropTemplate`, `TranslucentFrameTemplate` (0 references anywhere). [LOCAL]
Animation elements in `UI.xsd`: `AnimationGroup`, `Alpha`, `Scale`, `Translation`, `Rotation`, `Path` with `ControlPoints`. [LOCAL]

## 9. Widgets, templates and layout (round 2B + local checks)

### 9.1 Widget types
`UI.xsd` (identical in this client and both GitHub dumps) declares: `Frame`, `Button`, `CheckButton`, `EditBox`, `ScrollFrame`, `Slider`, `StatusBar`, `Cooldown` (`reverse`, `drawEdge`), `Model`, `PlayerModel`, `DressUpModel`, `TabardModel`, `ModelFFX`, `MessageFrame`, `ScrollingMessageFrame`, `SimpleHTML`, `GameTooltip`, `ColorSelect`, `MovieFrame`, `QuestPOIFrame`, `TaxiRouteFrame`, plus singletons `WorldFrame`, `Minimap`. **Absent:** `Line`, `ModelScene`, `Browser`, `OffScreenFrame`, `ScenarioPOIFrame`, `UnitPositionFrame`. [LOCAL] [PRIMARY]
(XSD declaration proves XML validity; it does not prove `CreateFrame` accepts every type.)

### 9.2 Template gotchas
- `UIPanelTemplates.xml` loads before any addon and also provides `UIPanelButtonTemplate2`, `UIPanelButtonGrayTemplate`, `UIPanelScrollBarTemplate`, `UIPanelScrollFrameTemplate2`, `FauxScrollFrameTemplateLight`, `UICheckButtonTemplate`, `TabButtonTemplate`, `GameMenuButtonTemplate`, `UIRadioButtonTemplate`, `AnimatedShineTemplate`, `AutoCastShineTemplate`, `DynamicScrollFrameTemplate`. [PRIMARY]
- **Scroll templates require a global name.** `UIPanelScrollFrameTemplate` / `FauxScrollFrameTemplate` find children with `_G[self:GetName().."ScrollBar"]`; an unnamed scroll frame errors in `ScrollFrame_OnLoad` ("attempt to concatenate a nil value"). No `parentKey` on these. [PRIMARY]
- Child regions of 3.3.5 templates are reached by global name: `_G[name.."Text"]`, `_G[name.."Low"]`, `_G[name.."High"]` (sliders); `_G[name.."Text"]` (check buttons). So give template-based widgets names. [PRIMARY]
- `OptionsCheckButtonTemplate` (gold label) runs `BlizzardOptionsPanel_CheckButton_OnClick` → `self.setFunc`; `InterfaceOptionsCheckButtonTemplate` (white label) runs `InterfaceOptionsPanel_CheckButton_OnClick`, which acts on `.cvar`, `.uvar`, `.invert`, `.dependentControls`, `.setFunc`. Override with `SetScript("OnClick", …)` or extend with `HookScript` if you don't want that logic. [PRIMARY]
- `OptionsSliderTemplate`: 144×17 horizontal slider with a backdrop (`bgFile` `Interface\Buttons\UI-SliderBar-Background`, `edgeFile` `Interface\Buttons\UI-SliderBar-Border`, `tile=true`, `tileSize=8`, `edgeSize=8`, `insets` 3/3/6/6). That table is also a working example of `SetBackdrop` fields. [PRIMARY]

### 9.3 Draw layers, strata, blend modes, fonts [LOCAL: UI.xsd, Fonts.xml, FontStyles.xml]
- Draw layers: `BACKGROUND`, `BORDER`, `ARTWORK`, `OVERLAY`, `HIGHLIGHT`. **No sublevels**: `<Layer>` only has `level`; `SetDrawLayer(layer)` takes one argument (sublevel added in 5.2.0). Order inside a layer is not controllable; use a different layer or nest frames. [LOCAL] [PRIMARY] [SECONDARY]
- Frame strata: `PARENT`, `BACKGROUND`, `LOW`, `MEDIUM`, `HIGH`, `DIALOG`, `FULLSCREEN`, `FULLSCREEN_DIALOG`, `TOOLTIP`.
- Blend (`alphaMode`): `DISABLE`, `BLEND`, `ALPHAKEY`, `ADD`, `MOD`. Font `outline`: `NONE`, `NORMAL`, `THICK`. Anchor points: `TOPLEFT TOPRIGHT BOTTOMLEFT BOTTOMRIGHT TOP BOTTOM LEFT RIGHT CENTER`.
- Font files: `Fonts\FRIZQT__.TTF` (default UI), `Fonts\ARIALN.TTF`, `Fonts\MORPHEUS.ttf`, `Fonts\FRIENDS.TTF`, `Fonts\skurri.ttf`. 149 named Font objects, e.g. `GameFontNormal(Small/Large/Huge)`, `GameFontHighlight(Small/Large)`, `GameFontDisable(Small/Large)`, `GameFontGreen*`, `GameFontRed*`, `GameFontWhite(Small)`.

### 9.4 Texture paths
Every `Interface\…` and `Fonts\…` path that exists in this client is listed in [`_reference/asset-paths.txt`](../_reference/asset-paths.txt) (14,760 paths, built by `_reference/tools/assetindex.py`). Confirmed present: `Interface\Buttons\WHITE8X8`, `Interface\Tooltips\UI-Tooltip-Background`, `Interface\Tooltips\UI-Tooltip-Border`, `Interface\DialogFrame\UI-DialogBox-Background/-Border`, `Interface\ChatFrame\ChatFrameBackground`, `Interface\TargetingFrame\UI-StatusBar`, `Interface\Icons\INV_Misc_QuestionMark`, `Interface\Buttons\ButtonHilight-Square`, `Interface\CharacterFrame\TempPortraitAlphaMask`. **Missing** (retail-only): `Interface\RaidFrame\Raid-Bar-Hp-Fill`. Always grep the list before hard-coding a path. [LOCAL]

### 9.5 Animations [LOCAL] [PRIMARY]
- Types: `Alpha`, `Scale`, `Translation` (XML element name; not "Translate"), `Rotation`, `Path` (+`ControlPoints`, curve `NONE|SMOOTH`).
- **Alpha is relative:** `anim:SetChange(-1)` / XML `change="…"`. `SetFromAlpha`/`SetToAlpha` do not exist (Legion). OmniCC on this machine uses `SetChange`. [LOCAL]
- Group `looping`: `NONE|REPEAT|BOUNCE`; animation `order` 1–100, `smoothing` `NONE|IN|OUT|IN_OUT|OUT_IN`, `startDelay`, `endDelay`.
- `AnimationSystem.lua` is an unrelated OnUpdate helper, not the AnimationGroup engine.

## 10. Events, API returns, slash commands (local checks)

- **Power events are per type** [LOCAL, Blizzard unit frames register them]: `UNIT_MANA`, `UNIT_RAGE`, `UNIT_ENERGY`, `UNIT_FOCUS`, `UNIT_RUNIC_POWER`, `UNIT_HAPPINESS`, `UNIT_MAXMANA/MAXRAGE/MAXENERGY/MAXFOCUS/MAXRUNIC_POWER/MAXHAPPINESS`, `UNIT_DISPLAYPOWER`, plus `UNIT_HEALTH`, `UNIT_MAXHEALTH`. `UNIT_POWER` does not appear anywhere (0 uses in Blizzard code and in 30300 addons).
- **`UnitAura` / `UnitBuff` / `UnitDebuff`** returns [LOCAL]: `name, rank, icon, count, debuffType, duration, expirationTime, caster, isStealable, shouldConsolidate` (positions 1–10 seen in TargetFrame/BuffFrame code). An 11th `spellId` return is **unverified** here.
- **`GetSpellInfo(id)`** returns [LOCAL]: `name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange` (no spellId return; no `GetSpellInfo` table form).
- **`GetItemInfo`**: positions 1 `name`, 2 `link`, 3 `quality` seen [LOCAL]; nil-until-cached behaviour: see §11.
- **Slash commands** [LOCAL ChatFrame.lua:4047-4075]: define `SLASH_MYADDON1 = "/myaddon"` (`2`, `3`… for aliases) and `SlashCmdList["MYADDON"] = function(msg, editBox) … end`. The typed command is uppercased and matched against the `SLASH_` globals, then cached in `hash_SlashCmdList`; the handler gets `strtrim(msg)` and the edit box. Lookup is lazy, so registering at file load is fine.
- **`print(...)`** exists [LOCAL RestrictedEnvironment.lua]: joins `tostringall(...)` with spaces into `DEFAULT_CHAT_FRAME`; `setprinthandler`/`getprinthandler` let you redirect it.
- **Time:** Blizzard code uses the globals `date(...)` and `time()`; no `os.*` use anywhere [LOCAL]. Prefer `date`/`time`/`GetTime()`.

## 11. Secure handlers in depth (round 2B + local)

- `SecureHandlerWrapScript(frame, script, header, preBody, postBody)` and `SecureHandlerExecute(header, body)` **error unless the header is explicitly protected** (`select(2, header:IsProtected())`): inherit `SecureHandlerBaseTemplate`, `SecureFrameTemplate` or another `Secure*` template. [PRIMARY]
- Only 12 scripts can be wrapped: `OnClick, OnDoubleClick, PreClick, PostClick, OnEnter, OnLeave, OnShow, OnHide, OnDragStart, OnReceiveDrag, OnMouseWheel, OnAttributeChanged`. Others → "Unsupported script type". [PRIMARY]
- Set up wraps/executes/frame refs **out of combat**; they work by setting attributes on a protected API frame. [PRIMARY, 2-1 vote → medium]
- **State drivers:** `RegisterStateDriver(frame, "id", "[cond] a; b")` → manager evaluates with `SecureCmdOptionParse` every 0.2 s and on modifier/combat/shapeshift/target events, and sets `state-id` only when the value changes. On a `SecureHandlerStateTemplate` frame that runs the snippet in attribute `_onstate-id` with `(self, stateid, newstate)`. [PRIMARY] [LOCAL]
- **`"visibility"` is special:** `show` → `frame:Show()`, `hide` → `frame:Hide()`, works in combat, never sets `state-visibility`, so `_onstate-visibility` never fires. Register the driver out of combat. [PRIMARY]
- `RegisterUnitWatch(frame[, asState])`: shows/hides the frame as its `unit` attribute's unit appears/disappears, or (with `asState`) sets `state-unitexists` to true/false instead. [LOCAL SecureStateDriver.lua]
- **Functions available inside secure snippets** [LOCAL RestrictedEnvironment.lua]: `math`, `string`, `select`, `tonumber`, `tostring`, `print`, `format`, `gmatch`, `gsub`, the `str*` helpers, the math shorthands (`abs … tan`, `floor`, `ceil`, `max`, `min`, `mod`, `random`); macro-condition functions `SecureCmdOptionParse, GetShapeshiftForm, IsStealthed, UnitExists, UnitIsDead, UnitIsGhost, UnitPlayerOrPetInParty, UnitPlayerOrPetInRaid, Is[Left/Right](Alt/Control/Shift)KeyDown, IsModifierKeyDown, IsModifiedClick, GetMouseButtonClicked, GetActionBarPage, GetBonusBarOffset, IsMounted, IsSwimming, IsFlying, IsFlyableArea, IsIndoors, IsOutdoors`; plus `GetBindingKey, HasAction, IsHarmfulSpell, IsHarmfulItem, IsHelpfulSpell, IsHelpfulItem, GetMultiCastTotemSpells, PlayerCanAttack, PlayerCanAssist, PlayerIsChanneling, PlayerPetSummary, PlayerInCombat, PlayerInGroup, UnitHasVehicleUI, RegisterStateDriver, GetActionInfo`. Restricted tables come from `RestrictedExecution.lua`.

## 12. Nameplates (round 2B)

- Stock 3.3.5 nameplates are **unnamed children of `WorldFrame`**: no unit token, no GUID, no `NAME_PLATE_*` events, no `C_NamePlate` (all 7.0.3). [SECONDARY] [PRIMARY]
- Detection pattern (LibNameplates-1.0 MINOR 34, bkader fork): poll `WorldFrame:GetNumChildren()` (OnUpdate ~0.01 s); when it changes, walk the children; a plate is an unnamed `Frame` with `GetID()==0` and at least one child and region (or another plate addon's marker). Identity is inferred: target = shown plate with alpha exactly 1 after `PLAYER_TARGET_CHANGED`; mouseover = plate whose highlight region is shown on `UPDATE_MOUSEOVER_UNIT` when `GetMouseFocus()==WorldFrame`; raid icons matched via `GetRaidTargetIndex`. [PRIMARY single library → medium]
- `awesome_wotlk` is a **client DLL** that adds `C_NamePlate`/`NAME_PLATE_*` to 3.3.5a. Not stock; don't assume it on Warmane. [PRIMARY]

## 13. Libraries (round 2A + local)

- **LibStub loads the highest MINOR of a library across all addons.** Whatever you embed can replace (or be replaced by) another addon's copy for the whole session. Only embed versions known to work on 3.3.5a. [PRIMARY] (LibStub semantics) [REASONING: an incompatible newer minor in your addon would break other addons too]
- **Ace3 cut-off:** `Release-r960` (2010-07-20) is the last formal Ace3 release whose TOC is `30300`; `r971` (2010-10-12) moved to 4.0.1/`40000`. [PRIMARY] wowace.com file pages + WoWUIDev/Ace3 git tags (3-0 for r960)
- r971-era minors **do run here**: Recount on this machine is `X-Curse-Packaged-Version: v4.0.1 release` with `## Interface: 30300` and embeds AceConfigDialog-3.0 **MINOR 50** and CallbackHandler-1.0 MINOR 6. [LOCAL]
- **Current upstream Ace3 will not run unmodified:** its TOC lists no 30300, and AceTimer-3.0 minor 17 indexes `C_Timer.After` at file load. [PRIMARY] (inferred from code; not tested in a 12340 client)
- **Installed 3.3.5-era versions on this machine** (safe baselines) [LOCAL]: AceAddon-3.0 5, AceEvent-3.0 3, AceTimer-3.0 5, AceConsole-3.0 7, AceLocale-3.0 2, AceComm-3.0 6, AceSerializer-3.0 3, AceConfig-3.0 2, AceConfigCmd-3.0 11/12, AceConfigDialog-3.0 42/43/50, AceConfigRegistry-3.0 11/12, CallbackHandler-1.0 3/5/6, LibSharedMedia-3.0 90000, LibDataBroker-1.1 4, LibCompress 6. Copy them from `D:\WoW WotLK\Interface\AddOns\<addon>\libs` rather than downloading.
- **NoM0Re/WeakAuras-WotLK** (github, `## Interface: 30300`, actively maintained, last push 2026-10-10) ships 20 3.3.5-ready libs: AceComm-3.0, AceSerializer-3.0, AceTimer-3.0, Archivist, CallbackHandler-1.0, LibCompress, LibCustomGlow-1.0, LibDBIcon-1.0, LibDataBroker-1.1, LibDeflate, LibGetFrame-1.0, LibGroupTalents-1.0, LibHealComm-4.0, LibRangeCheck-2.0, LibResComm-1.0, LibSerialize, LibSharedMedia-3.0, LibSpellRange-1.0, LibStub, SpecializedAbsorbs-1.0. Its AceTimer-3.0 is a custom **OnUpdate backport registered as MINOR 1018**, so if loaded it replaces every other AceTimer copy. Its CallbackHandler version was **not** confirmed (claim refuted 0-3). [PRIMARY]

## 14. Debugging (round 2A + local)

- `Blizzard_DebugTools.toc`: `## Interface: 30300`, `## LoadOnDemand: 1`, `## Secure: 1`. [LOCAL]
- `/framestack` (`/fstack`) toggles a tooltip of frames under the mouse (refresh 0.1 s); `/framestack true` includes hidden frames. `/eventtrace` (`/etrace`) accepts `start`, `stop`, a number N (capture N events), or nothing (toggle window); keeps 1000 entries. [PRIMARY] (Townlong-Yak 3.3.5 dump, build 12213 + wowgaming dump) [LOCAL aliases in GlobalStrings.lua]
- `/dump <expr>` → `DevTools_DumpCommand(msg, editBox)`; limits are globals you can raise: `DEVTOOLS_MAX_ENTRY_CUTOFF = 30`, `DEVTOOLS_LONG_STRING_CUTOFF = 200`, `DEVTOOLS_DEPTH_CUTOFF = 10`. [LOCAL Dump.lua:15-17]. **Note:** round 2A's verifiers *refuted* this claim 0-3; the client's own code proves it true.
- **Error handler** (`BasicControls.xml`) [LOCAL]: every Lua error loads `Blizzard_DebugTools`; if `GetCVarBool("scriptErrors")` the error window is shown, otherwise the error is recorded silently (`ScriptErrorsFrame_OnError(msg, HIDE_ERROR_FRAME)`). After `_ERROR_LIMIT` errors the `TOO_MANY_LUA_ERRORS` popup appears. Error-capture addons (BugGrabber) replace this via `seterrorhandler`.
- **BugSack for 3.3**: funkydude/BugSack commit `ea588f0` (2010-09-02) has `## Interface: 30300`, but it needs 3.3-era externals and a matching `!BugGrabber` that were not identified. [PRIMARY, low confidence]
- **CPU profiling** [LOCAL TitanPerformance]: `SetCVar("scriptProfile", "1")` then `ReloadUI()`; then `UpdateAddOnCPUUsage()` + `GetAddOnCPUUsage(i)`. Memory: `UpdateAddOnMemoryUsage()` + `GetAddOnMemoryUsage(i)` (KB). Leave `scriptProfile` off normally (it adds overhead).
- **Smooth health bars** [LOCAL UnitFrame.lua:199-256]: Blizzard polls `UnitHealth(unit)` in `OnUpdate` (when CVar `predictedHealth` is on), compares to a cached value and calls `SetValue` only on change; otherwise it uses `UNIT_HEALTH`. CVar-dependent setup waits for `VARIABLES_LOADED`.

## 15. Editor tooling (round 2A)

- Ketho's **"WoW API" VS Code extension has no 3.3.5 target** (mainline 12.0.1, Mists Classic 5.5.3, Classic Era 1.15.8 only; maintainer: private-server clients won't be supported). Its hovers will *not* warn that `C_Timer` etc. are missing here. [PRIMARY]
- `@araxiaonline/wow-wotlk-declarations` is TypeScript `.d.ts` for TypeScriptToLua (beta, includes post-WotLK modules). Not usable by LuaLS directly. [PRIMARY, single source]
- Practical substitute: grep `_reference/BlizzardInterfaceCode` and `_reference/asset-paths.txt`, and installed addons (`_reference/tools/apiusage.py`).

## 16. Warmane (round 2A + local)

- Warmane's Terms of Service contain **no addon rules** (no mention of addons, Warden, bots, unlockers). Conduct rules live elsewhere (a forum Rules thread, not read in full). [PRIMARY] warmane.com/policies/terms
- Warmane runs a closed core. Open-source TrinityCore 3.3.5 Warden can run server-supplied Lua (`LUA_EVAL_CHECK`, ≤170 chars, result returned via addon message prefix `_TW` on GUILD, only in world). Whether Warmane does this is **unknown**. [PRIMARY for TrinityCore only]
- Practical stance [REASONING]: write normal UI addons; never automate gameplay or call protected functions from insecure code; don't use the `_TW` addon prefix.

## 17. Dev loop and tooling (round 3B)

- **`/reload` vs restart** [SECONDARY + FORUM, medium; not yet tested here]: `/reload` re-runs existing `.lua`/`.xml`. It does **not** re-read `.toc` files or the AddOns folder on 3.3.5a (the wiki dates "/reload picks up TOC changes and new files" to 9.0.1 retail / 1.14.0 Classic). So **editing a TOC, adding a file to a TOC, or adding a new addon folder needs a full client exit + restart**. Logging out to character select is not known to re-scan.
- Still **untested**: whether an NTFS junction/symlink inside `Interface\AddOns` loads; whether `-console` / `exportInterfaceFiles` work on 12340 (not needed: the UI code is already extracted).
- **Linting:** no LuaLS/EmmyLua type definitions for 3.3.5 exist (search-based). Usable luacheck globals lists [PRIMARY]:
  - `ElvUI-WotLK/ElvUI` `.luacheckrc`: `std = lua51c`, ~42,000 3.3.5 globals generated from FrameXML and each Blizzard_* addon, **no `C_*` or post-WotLK names**, so luacheck flags `C_Timer` etc. Best choice. (No detected license.)
  - `bkader/Skada-WoTLK` `.luacheckrc`: ~33,600 names (a `_G` dump); not checked for retail contamination.
  - **Avoid** `NoM0Re/WeakAuras-WotLK` `.luacheckrc`: synced from retail, allows `C_Timer`, `C_Spell`, `C_Traits`…
  - Both good lists declare every name writable, so they won't catch accidental writes to Blizzard globals.
- **Dev/inspection addons** [PRIMARY]: `wowgaming/addon-archive` has 30300-era `!BugGrabber` 2.2 (r152), `BugSack` 3.3 (r225) and `WowLua` r40; historical snapshots, README says not to use as-is. A 3.3.5 ViragDevTool backport (robgha01) was confirmed in one pass and refuted (1-2) in another: **unverified**.

## 18. Libraries (round 3B additions)

- `bkader/SharedMedia` (`## Interface: 30300`) ships standalone LibStub (minor 2), CallbackHandler-1.0 (minor 6, the Lua-5.1-safe `loadstring` dispatcher) and LibSharedMedia-3.0 (**minor 3030002**, hand-bumped 3.3.5 build). [PRIMARY]
- Archived BugSack r225 embeds 30300-era LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0, AceLocale-3.0, AceComm-3.0, AceSerializer-3.0. [PRIMARY]
- **LibCustomGlow-1.0 from WeakAuras-WotLK is not standalone**: it needs WeakAuras' `Pools.lua` (CreateFramePool/CreateTexturePool shims, which themselves need its Mixin) and hard-codes textures under `Interface\AddOns\WeakAuras\Libs\`. [PRIMARY]
- **LibSharedMedia minor trap:** LibStub keeps the highest minor, so a retail LSM (build-derived minor, much larger than 3030002 or this machine's 90000) loaded by any addon would win. [REASONING]

## 19. Addon messages and chat limits

- Installed here [LOCAL]: ChatThrottleLib **v21** (Recount/AceComm) and v16 (Cartographer/LibRockComm), both `MAX_CPS = 800`, `BURST = 4000`. Installed addons send addon messages only on `PARTY`, `RAID`, `GUILD`, `BATTLEGROUND`, `WHISPER`.
- **Stock TrinityCore 3.3.5 / AzerothCore** [PRIMARY source code; Warmane's closed core may differ]:
  - Text over **255 bytes is silently dropped**; an addon message arrives as `prefix .. "\t" .. body`, so **prefix + body ≤ 254 bytes**. (2-1 vote)
  - Addon messages are accepted only on `PARTY`, `RAID`, `GUILD`, `BATTLEGROUND`, `WHISPER`; anything else is dropped and logged.
  - Flood control **mutes** (default 10 s), it doesn't kick: 100 addon messages or 10 regular chat lines per (game) second. Both share one mute, so an addon-message flood also silences your chat.
- ChatThrottleLib v31 (WeakAuras-WotLK) errors on text > 255 or prefix+1+msg > 255; AceComm-3.0 minor 14 splits payloads at `254 - #prefix` (one byte less for multipart). [PRIMARY]
- Practical rule [REASONING]: route addon traffic through ChatThrottleLib/AceComm; keep any regular chat output (announcements) under ~5 lines per second yourself, because CTL's byte budget alone allows more than the 10-lines/s regular-chat mute.

## 20. Protection and taint (round 3A + local)

- `frame:IsProtected()` returns **two 1/nil flags**: `isProtected` (explicit or implicit) and `isExplicitlyProtected` (declared protected at creation, e.g. inherits a `Secure*` template). [LOCAL SecureHandlers.lua:73, 571, 661, 712]
- **Direction of implicit protection:** a protected frame makes its **parent chain** and **any frame it is anchored to** implicitly protected (so `secureButton:SetPoint("TOP", myFrame)` or `secureButton:SetParent(myFrame)` protects `myFrame` in combat). Your insecure frame anchored to / parented under a secure frame does **not** become protected. Implicit protection clears when the links are removed out of combat. [SECONDARY wiki 2007-2013 + FORUM 2010, medium] (wowprogramming's Region:IsProtected page states the opposite direction; rejected as imprecise.)
- Explicitly protected frames stay protected forever; create them and set their attributes **out of combat**. Blizzard's untainted code (e.g. a group header adding children) can still create frames in combat, unless the path is tainted by an addon. [SECONDARY, 2-1 vote]
- **Taint model:** Blizzard code/variables start secure, addon code and SavedVariables start tainted; a global written by tainted code carries that taint until secure code overwrites it or the UI reloads. So never write globals Blizzard reads (including leaking `_` or common names). [SECONDARY + Whitehead 2008 slides, 2-1 vote]
- `securecall(func, ...)` keeps a secure caller secure and swallows errors; Blizzard calls `securecall("CloseSpecialWindows")` so addons can `tinsert(UISpecialFrames, "MyFrameName")` to make ESC close their frame safely. [LOCAL UIParent.lua]
- **Blocked actions** [LOCAL UIParent.lua:152-155, 781-785; GlobalStrings.lua]: UIParent listens for `ADDON_ACTION_BLOCKED`, `MACRO_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, `MACRO_ACTION_FORBIDDEN`. BLOCKED prints `INTERFACE_ACTION_BLOCKED` ("Interface action failed because of an AddOn") **once per session**; FORBIDDEN shows "%s has been blocked from an action only available to the Blizzard UI".
- `taintLog` CVar exists in this client's binary [LOCAL Wow.exe]; its output format/levels on 3.3.5 are not yet verified.

## 21. Events and data timing (round 3A + local)

- Login order: `ADDON_LOADED` (per addon; only arg = addon name; read SavedVariables here) → `PLAYER_LOGIN` (once) → `PLAYER_ENTERING_WORLD`. [SECONDARY + LOCAL UIParent.lua]
- `PLAYER_ENTERING_WORLD` fires on **every loading screen** (login, `/reload`, instance/continent change) and has **no arguments** on 3.3.5 (`isInitialLogin`/`isReloadingUi` are 8.0.1). Track first-login yourself (flag set in `PLAYER_LOGIN`). [SECONDARY + LOCAL]
- `VARIABLES_LOADED` = CVars/keybindings ready; no fixed position (can be after `PLAYER_ENTERING_WORLD`). Don't use it for SavedVariables. Blizzard uses it before reading CVars. [SECONDARY + LOCAL UnitFrame.lua]
- Talent data may be blank at `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD` on a fresh login (fine after `/reload`); `PLAYER_ALIVE` was the "talents ready" signal pre-5.4. Server-mirrored settings like `GetActionBarToggles()` may be wrong at login (Blizzard comment). [SECONDARY + FORUM + LOCAL]
- `UnitAura`/`UnitBuff`/`UnitDebuff` return **11 values**: `name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId` (spellId added 3.3.0). Retail docs (no rank; spellId 10th) are wrong here. [SECONDARY patch history + PRIMARY oUF 1.4.3, ElvUI-WotLK + LOCAL BuffFrame.lua pos 1-7,10]
- No `UNIT_HEALTH_FREQUENT` (4.0.6). Fast health = poll `UnitHealth` in `OnUpdate` (Blizzard and oUF both do). [SECONDARY + PRIMARY + LOCAL]
- **Inspect:** `NotifyInspect(unit)` → wait for `INSPECT_TALENT_READY` (no GUID payload; `INSPECT_READY` is 4.0.1+). Requests can be silently dropped (server throttle ~5/10 s on Blizzard; emulators also drop when out of range). Use timeouts, retries, spacing, and verify the unit. [LOCAL InspectTalentFrame.lua + SECONDARY + FORUM]
- **Talent API** (3.3.5 form): `GetNumTalentTabs(inspect, pet)`, `GetTalentTabInfo(tab, inspect, pet, talentGroup)` → `name, icon, pointsSpent, background, previewPointsSpent`; `GetNumTalents(tab, inspect, pet)`; `GetTalentInfo(tab, i, inspect, pet, talentGroup)` → `name, icon, tier, column, rank, maxRank, isExceptional, meetsPrereq, previewRank, meetsPreviewPrereq`; `GetActiveTalentGroup(inspect)`. The 8-return `GetTalentTabInfo` in most docs is 4.x / Wrath Classic. [LOCAL + PRIMARY]

## 22. Lua environment (round 3A + Wow.exe scan)

- Modified **Lua 5.1** with taint. **No `os` or `io` tables**, no `dofile`/`loadfile`. Time: globals `date()`, `time()` (local clock), `difftime()`, plus `GetTime()` (seconds, sub-second). [SECONDARY + LOCAL Wow.exe]
- Libraries: `string`, `table`, `math`, `coroutine`, `debug` (restricted), `bit`. **`bit` has exactly 8 functions**: `bnot, band, bor, bxor, lshift, rshift, arshift, mod` (32-bit; first six return unsigned; no `tobit/tohex`). [LOCAL Wow.exe disassembly]
- Present in the binary [LOCAL exescan]: `collectgarbage`, `gcinfo`, `getfenv`, `setfenv`, `loadstring`, `newproxy`, `debuglocals`, `debugprofilestart`, `debugprofilestop`, `GetFunctionCPUUsage`, `GetFrameCPUUsage`, `GetEventCPUUsage`, `UpdateAddOnCPUUsage`, `ResetCPUUsage`.
- **Timing code:** `local t = debugprofilestop(); ...; local ms = debugprofilestop() - t`. Don't call `debugprofilestart()` (resets a timer shared by all addons). [PRIMARY + SECONDARY]
- WoW-only helpers defined in Lua, not the engine: `tContains` (UIParent.lua:2771). [LOCAL]

## 23. Layout, scale, movement (round 3A + Wow.exe scan)

- Present: `SetMovable`, `SetResizable`, `SetMinResize(w, h)`, `SetMaxResize`, `StartMoving`, `StartSizing`, `StopMovingOrSizing`, `SetUserPlaced`, `IsUserPlaced`, `SetClampedToScreen`, `SetClampRectInsets`, `GetScreenWidth/Height`, `GetEffectiveScale`, `GetCursorPosition`, CVars `uiScale`, `useUiScale`. **Not present:** `SetResizeBounds` (10.0), `SetShown`. [LOCAL FrameXML + Wow.exe]
- Blizzard saves chat-window positions as a **fraction of screen size** and restores with `SetPoint(point, x*GetScreenWidth(), y*GetScreenHeight())` + `SetUserPlaced(true)`. [LOCAL FloatingChatFrame.lua:1100-1141]
- This machine: `uiScale 0.81`, `useUiScale 1`, `gxResolution 1366x768`. [LOCAL Config.wtf]
- Texture methods present: `SetTexCoord`, `SetVertexColor`, `SetGradient`, `SetGradientAlpha`, `SetDesaturated`, `SetBlendMode`, `SetRotation`; Animation setters `SetChange`, `SetOffset`, `SetDegrees`, `SetRadians`, `SetScale`, `SetDuration`, `SetSmoothing`, `SetLooping`. [LOCAL Wow.exe]
- `UnitGetIncomingHeals` is **absent** (4.0); heal prediction on 3.3.5 needs LibHealComm-4.0. [LOCAL Wow.exe + NoM0Re lib list]

### Binary-scan tool
`python -I _reference/tools/exescan.py "D:/WoW WotLK/Wow.exe" Name ...` and the index `_reference/wow-exe-identifiers.txt` (10,750 identifier strings). PRESENT is strong evidence; "absent" is not conclusive (it misses `wipe`, `tinsert`, `strupper`), so also grep the FrameXML.

## 24. Final gap-closing checks (direct lookups + local)

- **Event names in the engine** [LOCAL Wow.exe scan; consistent with every research claim]: present `INSPECT_TALENT_READY`, `UNIT_HEALTH`, `UNIT_MANA`, `UNIT_AURA`, `PLAYER_ALIVE`, `SPELLS_CHANGED`, `VARIABLES_LOADED`, `RAID_ROSTER_UPDATE`, `PARTY_MEMBERS_CHANGED`, `UNIT_SPELLCAST_SUCCEEDED`, `ADDON_ACTION_BLOCKED`; absent `GET_ITEM_INFO_RECEIVED`, `INSPECT_READY`, `UNIT_POWER(_FREQUENT)`, `UNIT_HEALTH_FREQUENT`, `NAME_PLATE_UNIT_ADDED`, `UNIT_ABSORB_AMOUNT_CHANGED`, **`GROUP_ROSTER_UPDATE`** (use `RAID_ROSTER_UPDATE` + `PARTY_MEMBERS_CHANGED`).
- **Uncached items** [LOCAL Cartographer_InstanceLoot/InstanceLoot.lua:503-510, copy in `_reference/third-party/`]: `GetItemInfo(id)` returns nil until the client has the item. Prime it with a hidden tooltip (`tip:SetOwner(frame, "ANCHOR_PRESERVE"); tip:SetHyperlink("item:"..id); tip:Hide()`) and retry ~1 s later. Returns used here: 1 `name`, 2 `link`, 3 `quality`, 10 `texture`.
- **Pixel-perfect scale** [SECONDARY warcraft.wiki.gg/wiki/UI_scaling, rule from 2.0.1]: UI height is 768 units, so `uiScale = 768 / verticalResolution` makes 1 unit = 1 pixel. The client's slider range is **0.64–1.0** (step 0.01) [LOCAL VideoOptionsPanels.lua:88]; lower values are ignored, so for taller screens set `UIParent:SetScale()` instead. This machine runs 1366×768 at `uiScale 0.81`, so pixel-perfect would be `1.0`.
- **`taintLog`** [SECONDARY warcraft.wiki.gg/wiki/CVar_taintLog; CVar present in Wow.exe]: `/console taintLog 1` logs blocked actions and the taint leading to them; `2` also logs tainted global reads/writes. Output: `D:\WoW WotLK\Logs\taint.log`, flushed periodically and on logout. (Values 3–5 are 12.0+.)

## 25. ClientProbe results (in-game, 2026-10-12) [LOCAL, strongest evidence]

Login + `/reload` on this client, read back from `WTF\Account\<ACCT>\SavedVariables\ClientProbe.lua`:
- **`/reload` does not re-read the TOC:** after editing both markers, `luaMarker` became "B" but the TOC's `X-ProbeMarker` stayed "A". **TOC edits / new files / new addons need a full restart.**
- **Junctions work:** the probe was loaded through an NTFS junction.
- **Protection direction confirmed** (`IsProtected()` → `isProtected | isExplicit`): secure button `1|1`; frame the secure button is anchored to `1|nil`; parent of a secure button `1|nil`; insecure frame anchored to a secure button `nil|nil`; insecure child of a secure button `nil|nil`. Returns are `1`/`nil`.
- **Returns:** `UnitAura` = 11 values, 11th = spellId (32235); `GetTalentTabInfo` 5; `GetTalentInfo` **7 on fresh login vs 10 after reload** (talent data incomplete at login); `GetSpellInfo` 9; `GetItemInfo` 11; `GetBuildInfo` 4 (`"3.3.5", "12340", "Jun 24 2010", 30300`).
- **Event order, fresh login:** addon `ADDON_LOADED`s → `VARIABLES_LOADED` → `SPELLS_CHANGED` → `ADDON_LOADED Blizzard_CombatLog` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` (0 args) → `PLAYER_ALIVE`. **On `/reload`:** `VARIABLES_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD`; no `SPELLS_CHANGED`, no `PLAYER_ALIVE`.
- **Environment:** `_VERSION` "Lua 5.1"; `os`, `io` **and `debug` are nil** (corrects §22); `bit` = `arshift, band, bnot, bor, bxor, lshift, mod, rshift`; present: `coroutine`, `getfenv`, `setfenv`, `loadstring`, `newproxy`, `gcinfo`, `collectgarbage`, `debugprofilestart/stop`, `date`, `time`, `difftime`, `wipe`, `tContains`, `print`, CPU/memory profiling functions; absent: `C_Timer`, `Mixin`, `CreateFromMixins`, `GetNumGroupMembers`, `IsInGroup`, `IsInRaid`, `RegisterAddonMessagePrefix`, `CombatLogGetCurrentEventInfo`, `UnitGetIncomingHeals`, `RegisterAttributeDriver`, `UnitIsTapDenied`.
- **Widgets:** present `SetSize`, `SetMinResize`, `SetMaxResize`, `SetClampRectInsets`, `HookScript`, `IsEventRegistered`, `SetBackdrop`, `SetTexture(r,g,b,a)`, `SetGradient`, `SetGradientAlpha`, `SetDesaturated`, `SetRotation`, `SetBlendMode`, `SetVertexColor`, `SetFormattedText`, `Alpha:SetChange`; absent `SetShown`, `SetResizeBounds`, `SetClipsChildren`, `SetColorTexture`, `SetAtlas`, `SetFromAlpha`. `SetDrawLayer(layer, 2)` doesn't error but `GetDrawLayer()` returns 1 value (sublevel ignored). `CreateAnimation("Translate")` also doesn't error (use "Translation", the documented name).
- `InCombatLockdown()` out of combat → `nil` (in-combat value not captured).

## 26. Crowd control that damage breaks (deep-research run 2026-10-12 + Spell.dbc)

Sources: this client's Spell.dbc [LOCAL]; TrinityCore 3.3.5 `Unit.cpp`, `SpellAuraEffects.cpp`, `SpellDefines.h`, `spell_dk.cpp`, `Opcodes.h` and AzerothCore `spell_ranks.sql` [PRIMARY for open-source cores; Warmane's core is closed, so strong evidence, not proof]. 24 of 25 checked claims confirmed 3-0. Used by `ThreatManagement/CCBreaks.lua` + generated `CCData.lua`.
- **Any damage breaks it** = Spell.dbc AuraInterruptFlags bit `0x2` (TAKE_DAMAGE). The server removes these auras on every damage event **before** checking the amount, so fully absorbed hits (`*_MISSED` with missType `"ABSORB"`) and DoT ticks break them; misses/immunes don't. Set on Polymorph (all), Sap, Blind, Freezing Trap/Arrow **Effect**, Wyvern Sting, Shackle Undead, Hibernate, Repentance, Seduction 6358. Clear on Hammer of Justice, Fear, Frost Nova, Cyclone, Banish. `0x01000000` is DIRECT_DAMAGE (not `0x02000000`, which is LANDING).
- **Damage may break it** (Hex 51514, Scare Beast, fears, roots: AIF without `0x2`, damage-taken procFlags such as `0xa22a8`): on TrinityCore a cumulative cap of **10% of the target's max health** (raised by Glyph of Fear / Frost Nova); one big hit can still break it at once. Warmane's exact rule is unknown.
- **Hungering Cold:** cast 49203 has no aura; the enemy debuff is **51209** (1 proc charge). The first damage that isn't a disease breaks it, DoT ticks included. Damaging player diseases (Spell.dbc dispel type 3, field 2): Frost Fever 55095, Blood Plague 55078, Wandering Plague 50526.
- **Cast ≠ debuff:** Freezing Trap 1499/14310/14311 summon objects that cast 3355/14308/14309; Freezing Arrow 60192 → 60210. Wyvern Sting has 6 ranks (19386, 24132, 24133, 27068, 49011, 49012; the 24131 chain is the DoT afterwards). Shackle Undead, Hibernate, Scare Beast: 3 ranks each. Polymorph variants with the same flags: Turtle, Pig, Black Cat, Rabbit, Turkey (61780 and 71319), Serpent 61025, Penguin 59634; 28270 doesn't exist here.
- **`SPELL_AURA_BROKEN(_SPELL)` probably never fires on Warmane:** the client handles them and the protocol has `SMSG_SPELLBREAKLOG` (0x14F), but no open-source 3.3.5 core (TrinityCore, AzerothCore, cMaNGOS, MaNGOS, ArcEmu, AscEmu) builds that packet; breaks arrive as plain `SPELL_AURA_REMOVED`. Detect breaks by timing (removed early, right after a hit). In-game check: break a Sap/Polymorph with `/etrace` running.
- Practitioner tables are weak for 3.3.5: BigDebuffs-WotLK (backported from Wrath Classic) keys Hungering Cold as 49203 and lists the nonexistent 28270.
- Not covered: CC from items/engineering (e.g. Gnomish Poultryizer) and racials. Item→spell links live on the server, so the client's DBCs can't enumerate them.

## Still open (needs in-game test or not found)

- ~~Whether an NTFS junction in `Interface\AddOns` loads~~ **Verified 2026-10-12** [LOCAL in-game screenshot]: addons linked with `New-Item -ItemType Junction` are listed and enabled in the AddOns screen. `/reload` ignoring TOC changes: verified, see §25.
- UIDropDownMenu/StaticPopup taint specifics on 3.3.5 (general rule: don't write Blizzard globals; prefer your own menus). Static read 2026-10-12: Blizzard resets `DropDownList.numButtons` itself on every menu open (`UIDropDownMenu.lua:49`), so an addon appending entries after `UnitPopup_ShowMenu` (e.g. AddFriend) shouldn't taint later Blizzard entries like Set Focus; not yet confirmed in game.
- Whether Warmane sends `SPELL_AURA_BROKEN(_SPELL)` (§26), and its damage cap for fears/roots/Hex.
- Warmane's actual rules-thread text, flood limits and Warden behaviour (searches found no policy text; ToS has none).
