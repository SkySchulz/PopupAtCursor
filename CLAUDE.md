# PopupAtCursor

World of Warcraft addon that moves StaticPopup dialogs to the mouse cursor,
with an options panel for popups to leave in place. Single Lua file plus `.toc`.

## Build and test

- `make lint`: `luac -p`, then `luacheck` (skipped with a note if not installed), on every
  `.lua` the `.toc` loads. Run after every Lua change. `.luacheckrc` sets Lua 5.1 and lists
  the WoW globals in use: add new API calls to `read_globals`, globals the addon writes to `globals`.
- `make package`: `build-tools/make-tarball.sh` → `.release/PopupAtCursor-<version>.tar.gz`.
- `make install ADDONS=<dir>`: `build-tools/install-tarball.sh`, which rebuilds the
  tarball and replaces `<dir>/PopupAtCursor`.
- Use these tools; don't hand-roll `tar`/`cp` commands. The Makefile is a thin wrapper,
  so keep the logic in `build-tools/` scripts.
- **Never run the installer (script or `make install`) without an explicit scratch
  `ADDONS`/dir argument when testing.** The default is the user's real
  `/Applications/World of Warcraft/_retail_/Interface/AddOns`. Use `make -n install` to
  check the default path. Only install there when the user asks.
- `.release/` is gitignored build output.

## Lua and WoW constraints

- WoW runs Lua 5.1. Local `luac` is newer (5.5), so passing `luac -p` doesn't prove
  5.1 compatibility: avoid `goto`, `//`, bitwise operators, integer-specific behavior and
  `<const>`/`<close>`.
- Must work on every client in `## Interface` (Retail plus several Classic flavors).
  Guard APIs that may be missing (e.g. `Settings.*` with a fallback to
  `InterfaceOptions_AddCategory`), and prefer templates present everywhere
  (`UIPanelScrollFrameTemplate`, `UICheckButtonTemplate`, `UIPanelButtonTemplate`).
- Popup frames are `StaticPopup1..4`. Their prompt fontstring may be `.text`, `.Text` or
  `<name>Text`, so check all three.
- Saved settings: `PopupAtCursorDB` = `{ skip = {name=true}, seen = {name=text|true}, debug = bool,
  graph = bool }`.
- Changing the `.toc` (including `SavedVariables`) needs a full game restart; Lua-only
  changes need just `/reload`. Bump `## Version:` for each test build.
- Nothing can be tested in-game from here: say what still needs an in-game check.

## Git

- Remote: `git@github.com:SkySchulz/PopupAtCursor.git` (public), branch `main`.
- Stage changes and give the user a ready-to-run `! git commit ...` command; commit or
  push only when explicitly asked.
- Commit messages end with the Co-Authored-By trailer.
- Keep README in sync when commands or behavior change.
