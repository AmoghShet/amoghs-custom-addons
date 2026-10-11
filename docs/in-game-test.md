# In-game verification (about 10 minutes)

Settles what research couldn't: whether linked addon folders load, what `/reload` re-reads, how protection flows, real return counts, event order, and whether the starter skeleton runs.
The **ClientProbe** addon records everything into its SavedVariables, so you don't need to copy anything out of the game.

## 1. Link the two test addons into the game (WoW closed)

Run in PowerShell. A junction is just a pointer, so the files stay in this dev folder:

```powershell
New-Item -ItemType Junction -Path "D:\WoW WotLK\Interface\AddOns\ClientProbe" -Target "D:\WoW WotLK\Amogh's Custom Addons\_devtools\ClientProbe"; New-Item -ItemType Junction -Path "D:\WoW WotLK\Interface\AddOns\AddonSkeleton" -Target "D:\WoW WotLK\Amogh's Custom Addons\_templates\AddonSkeleton"
```

## 2. In the game

1. Start WoW. At character select, open **AddOns**: are **ClientProbe** and **AddonSkeleton** listed? (This is the junction test. If they're missing, tell me and I'll switch to copying.)
2. Log in on a character that has **any buff** on it.
3. Type `/console scriptErrors 1`, then wait about 10 seconds.
4. Optional: hit a training dummy for a few seconds, then leave combat.
5. Try the skeleton: `/askel`, drag its window, then `/askel options`, `/askel hide`, `/askel show`. Note any error popups.
6. **Without leaving the game**, run this in PowerShell. It changes a marker in the probe's TOC and Lua file:

   ```powershell
   $p = "D:\WoW WotLK\Amogh's Custom Addons\_devtools\ClientProbe"; (Get-Content "$p\ClientProbe.toc") -replace 'X-ProbeMarker: A','X-ProbeMarker: B' | Set-Content "$p\ClientProbe.toc"; (Get-Content "$p\ClientProbe.lua") -replace 'LUA_MARKER = "A"','LUA_MARKER = "B"' | Set-Content "$p\ClientProbe.lua"
   ```

7. Type `/reload` (out of combat) and wait about 5 seconds.
8. **Exit the game normally** (Esc → Exit Game). That makes the client write the SavedVariables file.

## 3. Tell me "probe done"

Mention whether the addons were listed and any errors you saw. I'll read `WTF\Account\<you>\SavedVariables\ClientProbe.lua` and fold the results into the docs.

## Removing the links later

`rmdir` removes only the link, never the files it points to. Don't use `Remove-Item -Recurse` on a junction.

```powershell
cmd /c rmdir "D:\WoW WotLK\Interface\AddOns\ClientProbe"
```
