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
| `/pac`       | Show help                                      |
| `/pac debug` | Toggle printing each popup's name as it opens |

### Keeping some popups in place

Edit the `SKIP` table at the top of `PopupAtCursor.lua` and uncomment (or add)
any popup names that should stay where Blizzard puts them. Use `/pac debug`
to find a popup's name.

## License

[MIT](LICENSE)
