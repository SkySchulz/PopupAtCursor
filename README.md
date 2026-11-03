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

| Command      | What it does                                   |
| ------------ | ---------------------------------------------- |
| `/pac`       | Open the options panel                         |
| `/pac debug` | Toggle printing each popup's name as it opens |
| `/pac help`  | List commands                                  |

### Keeping some popups in place

Open **Options → AddOns → Popup At Cursor** (or type `/pac`) and check any
popup that should stay where Blizzard puts it. The list shows common popups
plus every popup you've seen, each with a short version of its prompt; hover
a row for the full text. **Forget unchecked** clears seen popups you haven't
checked. Settings are saved per account in `PopupAtCursorDB`.

## Building a test package

With `make` (run `make help` for the list):

```sh
make package                    # lint, then build the tarball
make install                    # lint, build, install into the Retail AddOns folder
make install ADDONS="/path/to/AddOns"
```

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

[MIT](LICENSE)
