# Mod Fixes & Speedups

The Binding of Isaac: Repentance+ mod (REPENTOGON). Author: blackhellvelz.

English · [Русский](#русский)

Fixes for crashes and errors that happen when big mods are installed together, plus a few speedups. Everything is done at runtime from this mod's own folder: no files of other mods are changed, and every fix switches itself off if its mod isn't installed.

### Speedups
- **Faster json.decode** of the game's shared JSON module: mods with big save files (Passive Skill Trees and others) load and read saves noticeably faster.
- **Item lookup by name**: Isaac.GetItemIdByName walks the whole item list on every call, and mods call it thousands of times while loading — now it is an index.
- **Custom Health API cache** (Fiend Folio, Furtherance, Repentance Plus…): health getters are cached within a frame instead of a full resync on every call.


### Fixes
- Crash when starting Greed / Greedier as Lilith with Fiend Folio and Reshaken (TSIL library).
- Game enums (Achievement, LaserVariant, TearFlags…) overwritten by IPECAC during loading — restored.
- IPECAC: the game could hang for minutes while loading mods (a grid scan of a room that doesn't exist yet); Lil Larry locked forever; error at the start of every run ("IpecacMod is causing errors!"); missing achievement pictures — drawn in the game's style; Tainted Moses was invisible — skin, white hair, portrait and name added; old Fiend Folio names for its compatibility code.
- Fiend Folio: crash in the co-op fix when the player is re-created (Epiphany doors, restart).
- Lost and Forgotten: errors from wisps outside a Robot run and from cursed pickups.
- Reshaken (TSIL): player callbacks without a player at the start of a run.
- Epiphany: Tarnished Eden in Greed mode picked items from missing pools.
- Dead Sea Scrolls: the "Pause" item spam in every DSS menu (FPS drop while the menu is open) and the "Invalid character" log flood from mod texts.
- Mod Translator: a typo that broke a Reshaken easter egg.
- Mod Config Menu: the EID preview gets a dark backing so it doesn't overlap the menu text.


### Requirements
- [REPENTOGON](https://steamcommunity.com/sharedfiles/filedetails/?id=3127536138)

Useful with: Fiend Folio, IPECAC, Lost and Forgotten, Epiphany, Reshaken, Furtherance, Repentance Plus, Mod Translator, Encyclopedia, Passive Skill Trees, External Item Descriptions, Mod Config Menu. The name starts with two spaces so it loads before other mods.

### Links
Source code: [GitHub](https://github.com/blackhellvelz-prog/isaac-mod-fixes-and-speedups)
More from the same set: Basement Scrapbook Menu, Dead Sea Scrolls: Unrolled, Talents for Everyone, Peat, Isaac-Style, Russian Translation for Mods.

## Install

Subscribe on Steam Workshop — that's all. To install by hand, copy this folder into `The Binding of Isaac Rebirth/mods/`.

## Repository

This repository is the mod folder itself: `main.lua` is the entry point, the other `.lua` files are its modules, `resources/` — pictures, `metadata.xml` — the Workshop page. Pictures that belong to the game or to other mods are not stored here. Other mods this one works with — [CREDITS.md](CREDITS.md). Code license — [LICENSE](LICENSE) (MIT).

## Русский

Исправления вылетов и ошибок, которые возникают, когда большие моды стоят вместе, и несколько ускорений. Всё делается во время игры из папки этого мода: файлы других модов не меняются, а каждая правка сама выключается, если её мода нет.

### Ускорение
- **Быстрый json.decode** общего модуля JSON игры: моды с большими сохранениями (Passive Skill Trees и другие) заметно быстрее грузятся и читают сохранения.
- **Поиск предмета по имени**: Isaac.GetItemIdByName перебирает весь список предметов на каждом вызове, а моды при загрузке зовут его тысячи раз — теперь это указатель.
- **Кэш Custom Health API** (Fiend Folio, Furtherance, Repentance Plus…): здоровье игрока считается раз за кадр, а не полной пересинхронизацией на каждом вызове.


### Исправления
- Вылет при старте «Жадности» / «Жадности+» за Лилит с Fiend Folio и Reshaken (библиотека TSIL).
- Перечисления игры (Achievement, LaserVariant, TearFlags…), затёртые IPECAC при загрузке, — возвращаются.
- IPECAC: игра могла минутами висеть на загрузке модов (обход клеток комнаты, которой ещё нет); Lil Larry заперт навсегда; ошибка в начале каждого забега («IpecacMod is causing errors!»); нет картинок достижений — нарисованы в стиле игры; Порченый Моисей был невидимым — добавлены кожа, седые волосы, портрет и имя; старые имена Fiend Folio для его кода совместимости.
- Fiend Folio: вылет в правке для кооператива, когда игрок пересоздаётся (двери Epiphany, рестарт).
- Lost and Forgotten: ошибки огоньков вне забега за Робота и проклятых подборов.
- Reshaken (TSIL): колбэки игрока без игрока в начале забега.
- Epiphany: Потускневший Эдем в «Жадности» брал предметы из несуществующих пулов.
- Dead Sea Scrolls: предмет «Пауза» в каждом меню DSS (падение FPS, пока меню открыто) и поток «Invalid character» в логе от текстов модов.
- Mod Translator: опечатка, ломавшая пасхалку Reshaken.
- Mod Config Menu: под образцом EID — тёмная подложка, чтобы он не налезал на текст меню.


### Нужно
- [REPENTOGON](https://steamcommunity.com/sharedfiles/filedetails/?id=3127536138)

Полезен с модами: Fiend Folio, IPECAC, Lost and Forgotten, Epiphany, Reshaken, Furtherance, Repentance Plus, Mod Translator, Encyclopedia, Passive Skill Trees, External Item Descriptions, Mod Config Menu. Имя начинается с двух пробелов, чтобы мод грузился раньше остальных.

### Ссылки
Исходный код: [GitHub](https://github.com/blackhellvelz-prog/isaac-mod-fixes-and-speedups)
Из того же набора: Basement Scrapbook Menu, Dead Sea Scrolls: Unrolled, Talents for Everyone, Peat, Isaac-Style, Russian Translation for Mods.

### Установка

Подписаться в Мастерской Steam — и всё. Вручную: скопировать эту папку в `The Binding of Isaac Rebirth/mods/`.
