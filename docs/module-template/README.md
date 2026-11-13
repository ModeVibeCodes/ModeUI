# Module template

A complete, working ModeUI module to copy when starting a new one. It shows
the current target's name above the middle of the screen, which is just enough
to exercise every part of the module contract in
[docs/ARCHITECTURE.md](../ARCHITECTURE.md#the-module-contract):

| File | Shows |
|---|---|
| `Example.xml` | the load order: `Init.lua` first |
| `Init.lua` | declaration with `L[...]` text, `modeLayout`, defaults, ranges and `Initialize(db)` validation |
| `Driver.lua` | `OnInitialize` with a message subscription, `OnEnable`/`OnDisable` with `addon.Events`, building frames on first enable, `addon.Defer` for frame changes, secret-safe text from `Domain.Name`, and `SetOption` |
| `Settings.lua` | a page built only when opened, with a toggle and a slider on the shared widgets |

`tests/template.lua` loads this folder as a real module, so the template keeps
working as the code around it changes.

## Starting a new module from it

1. Copy this folder to `ModeUI/Modules/<Name>/` and rename `Example.xml` to
   `<Name>.xml`. Don't copy this README.
2. In every file, replace `addon.Example` with `addon.<Name>`, the module ID
   `"example"` with your ID (it becomes the saved-settings key, so choose it
   once), and `example:refresh` with your own Defer key.
3. Replace the title, description, defaults, ranges and logic with your own.
   Keep the shape: declarations in `Init.lua`, behavior in `Driver.lua`, the page
   in `Settings.lua`, and more files named for their job as it grows.
4. Add `Modules\<Name>\<Name>.xml` to `ModeUI/ModeUI.toc`, after the other
   modules and before `Shared\Runtime\Boot.lua`.
5. Run the tests in the README, and add tests for your module.
