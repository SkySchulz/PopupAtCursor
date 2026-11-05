# Popup At Cursor

A small World of Warcraft addon that moves Blizzard's static popup dialogs
(confirmations like "Bind this item?", "Delete item?", summons, and so on) to
your mouse cursor, with the first button lined up under the pointer.

Works on Retail and the Classic clients listed under `## Interface` in the `.toc`.

## Install

Copy the `PopupAtCursor` folder into `World of Warcraft/_retail_/Interface/AddOns/`
(or the matching `_classic_` / `_classic_era_` folder) and reload the UI.

## Usage

The addon works automatically once enabled.

| Command         | What it does                                                      |
| --------------- | ----------------------------------------------------------------- |
| `/pac`          | Open the options panel                                            |
| `/pac debug`    | Toggle printing each popup's name as it opens                     |
| `/pac graph`    | Show or hide the FPS and latency graph                            |
| `/pac graph tl` | Move the graph to a corner or edge: `tl` `tc` `tr` `bl` `bc` `br` |
| `/pac help`     | List commands                                                     |

### Keeping some popups in place

Open **Options → AddOns → Popup At Cursor** (or type `/pac`) and check any
popup that should stay where Blizzard puts it. The list shows common popups
plus every popup you've seen, each with a short version of its prompt; hover
a row for the full text. **Forget unchecked** clears seen popups you haven't
checked. Settings are saved per account in `PopupAtCursorDB`.

### FPS and latency graph

A small graph (top-left by default) shows the last 120 seconds of frame
rate (bars) and latency (line). Underneath, two lines give the current FPS
and latency and their minimum, average and maximum for that period. Green
means at least 60 fps or under 20 ms, yellow means 30–60 fps or 20–60 ms,
and red means under 30 fps or over 60 ms.
It's on by default; `/pac graph` or **Show FPS and latency graph** in the
options panel hides or shows it, and the choice is saved.
Hold Shift and drag the graph to place it anywhere, or use `/pac graph tl`
(and `tc`, `tr`, `bl`, `bc`, `br`) to snap it to a screen corner or edge; the
position is saved. Without Shift, clicks pass through it.
Latency comes from the game, which updates it only about every 30 seconds.

## Building a test package

With `make` (run `make help` for the list):

```sh
make lint                       # luac -p, plus luacheck if installed
make package                    # lint, then build the tarball
make install                    # lint, build, install into the Retail AddOns folder
make install ADDONS="/path/to/AddOns"
```

`make lint` runs [luacheck](https://github.com/lunarmodules/luacheck) when
it's installed (`brew install luacheck`, or `luarocks install luacheck`);
`.luacheckrc` holds its settings and the WoW globals the addon uses.

Or call the scripts directly:

```sh
build-tools/make-tarball.sh
```

This writes `.release/PopupAtCursor-<version>.tar.gz`, using the version from
the `.toc` and including only the files the `.toc` loads. Untar it inside
`Interface/AddOns/`, or install it with:

```sh
build-tools/install-tarball.sh                  # default Retail AddOns folder
build-tools/install-tarball.sh "/path/to/AddOns" # or any other AddOns folder
```

The installer defaults to
`/Applications/World of Warcraft/_retail_/Interface/AddOns` (or `$WOW_ADDONS`
if set), rebuilds the tarball from the current source, and replaces any existing
`PopupAtCursor` folder there. `-t FILE` installs a specific tarball as-is;
`-h` shows help.

## License

[MIT](LICENSE). See [COPYRIGHT.md](COPYRIGHT.md) for copyright and trademark notices.
