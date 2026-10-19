# Credits

Other mods this mod works with. Their files are not changed and not included here: our code reads their data or wraps their functions at runtime, and does nothing when the mod is not installed.

| Mod | Author | What our code does | Where |
|---|---|---|---|
| [IPECAC Community Mod](https://steamcommunity.com/sharedfiles/filedetails/?id=1925867065) | pedroff_1 | Lil Larry lock callback removed; BowelMovementDips table created before its run-start callback; enums it overwrites restored; its loading-time grid scan skipped outside a run; Book of Plagues transformation stub; missing achievement and Tainted Moses pictures provided at its own paths | `compat_runtime.lua, ipecac_plague_banner.lua, moses_b_hair.lua` |
| [Fiend Folio: Reloaded](https://steamcommunity.com/sharedfiles/filedetails/?id=3778123093) | Erfly | co-op heat check keeps an EntityPtr instead of the player object; old global names for other mods' compatibility code | `compat_runtime.lua, ff_legacy_globals.lua` |
| [Lost and Forgotten](https://steamcommunity.com/sharedfiles/filedetails/?id=3440586497) | ENFOR | LNF.GetLastData and Lost.GetCursedPickupMod / GetCursedRunesMod are wrapped to avoid nil errors | `compat_runtime.lua` |
| [The Binding of Isaac Reshaken](https://steamcommunity.com/sharedfiles/filedetails/?id=3134600246) | Kattack | its TSIL library: grid spawning and player callbacks are guarded at run start | `compat_runtime.lua` |
| [The Binding of Isaac: Epiphany](https://steamcommunity.com/sharedfiles/filedetails/?id=3012430463) | The Epiphany Team | PoolTableHelper:GetItemsFromPools keeps only pools that exist in Greed mode | `compat_runtime.lua` |
| [Mod Translator](https://steamcommunity.com/sharedfiles/filedetails/?id=2881743468) | Goganidze | its Reshaken run-start callback is wrapped so the easter-egg roll never hits the broken key | `compat_runtime.lua` |
| [Encyclopedia - An In-Game Wiki!](https://steamcommunity.com/sharedfiles/filedetails/?id=2376005362) | AgentCucco | the DSS 'Pause' item spam is throttled; unsupported characters are cleaned from DSS strings | `compat_runtime.lua` |
| [Furtherance](https://steamcommunity.com/sharedfiles/filedetails/?id=3513706025) | Benny | Custom Health API (shipped in it, Fiend Folio and Repentance Plus) gets a per-frame health cache | `chapi_resync_cache.lua` |
| [External Item Descriptions](https://steamcommunity.com/sharedfiles/filedetails/?id=836319872) | Wofsauge | the description preview in Mod Config Menu gets a dark backing | `ui_tweaks.lua` |

Library: [REPENTOGON](https://steamcommunity.com/sharedfiles/filedetails/?id=3127536138) by jerb and the REPENTOGON team — required.

Thanks to the authors of these mods and to the whole Isaac modding community.
