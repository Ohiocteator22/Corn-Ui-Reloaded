# CornUi v2.2.1 — v1.9.3 API compatibility restored (2026-11-16)

> **Hotfix 2026-11-21:** `TweenInfo` easing direction used the invalid
> `Enum.EasingStyle.Out`/`.In` (the real members live on `Enum.EasingDirection`)
> — 10 tween call sites across Window, Compat, Toggle, Dropdown, ColorPicker,
> NotificationCenter and CommandPalette. Module `Toggle` failed to load on live
> executors (`Out is not a valid member of "Enum.EasingStyle"`); all sites now
> use `Enum.EasingDirection`, and the smoke suite's Enum stub rejects invalid
> members so this class of bug can't pass CI again.
>
> **Visual restoration 2026-11-21:** the v2 shell had drifted from CornUi's
> actual look (invented "kernel" chrome, a Frost default theme, a navy
> frost/shatter intro overlay, chocolate-brown palettes). Rebuilt to the
> v1.9.x identity: near-black window (#0F1013), gold accent (#F1CE1B), 34px
> header, 98px sidebar rail with gold active pills, dark section cards, Dark
> as the default theme. The frost/shatter intro became a 0.2s fade that can
> never hide the window. The layout engine no longer uses UIListLayout or
> AutomaticSize anywhere — rows, sections, pages and the scroll canvas are
> placed by explicit Y arithmetic (attachStack), which cannot collapse on
> any executor.
>
> **Example seam 2026-11-21:** Example.lua no longer assumes a `CornUi`
> global — it loads the library itself via the real executor pattern
> (`loadstring(game:HttpGet(<locked Loader.lua URL>))()`), and the smoke
> suite's Example step exercises that seam end to end instead of seeding
> the global for it.

User brief: renaming methods broke every existing script. This release makes
the v1.9.3 API the public surface again and repositions the v2.2 widgets as
pure additions on top of it. Nothing was removed from v2.

## Why scripts broke, and the fix

- **Loader never booted.** Every module file is `return function(Modules)
  ... end`; the old Loader called the chunk once and stored the returned
  FACTORY as the module, so `Modules.Render` and friends were functions and
  the library could not start at all. The Loader now runs the factory with
  the shared Modules table. This is the same pattern the integration harness
  used (which is why it passed while the shipped Loader did not).
- **`Create___` restored everywhere.** New `Systems/Compat.lua` (loaded LAST)
  reattaches the v1 public API on top of the v2 internals:
  `Library:CreateWindow(config)` (accepting `Name`, `Subtitle`, `Icon`,
  `Theme`, `GuiName`, `TogglePosition`, plus v2's `Title`/`Size`),
  `window:CreateTab(name, config)` with tab icons,
  `tab:CreateSection(name)` including nested sections, and every v1 element
  method on tab, section AND card objects, exactly like the old TabMethods
  mixin. Prop names normalize (`Name` feeds `Title`, `Content` feeds `Text`),
  so v1 scripts get identical behavior and v2 scripts keep every prop
  (`Description`, `Multi`, `SubWindow`, `Loadstring`, toast `Buttons`, ...).
- **v1-only names are real elements again**, implemented on the v2 render
  layer: `CreateTextbox`, `CreateMultiDropdown`, `CreateHotkey`,
  `CreateChecklist`, `CreateMeter`, `CreateTimer`, plus
  `Library:RegisterElement` + `CreateCustom` for custom elements.
- **Library-level v1 methods**: `SetFlag`/`GetFlag` (colon-callable), the
  `Library.Flags` value table (live proxy over the flag store),
  `FlagChanged.Event`, `SaveConfig`/`LoadConfig`/`ListConfigs`/
  `DeleteConfig`/`ExportConfig`/`ImportConfig`, `RegisterTheme`/
  `RegisterSkin`, `PlaySound`/`PlayHaptic`, `TabMethods`, and a `Cornelius`
  shim over the v2 command system.
- **Window-level v1 methods**: `Notify` (v1 `Content` key, creates a
  notification center lazily instead of asserting), `SetTheme`,
  `SetThemeColor` (v1 color keys mapped to v2 Kind/Role, unknown keys warn
  instead of erroring), `SetBackground`/`ClearBackground`, `SetSkin`,
  `SetSpotlight`, `SetCornerRadius`, `SetOpacity`, `SetAnimationSpeed`,
  `SetBlur`, `SetShadow`, `RegisterCommand(keyword, fn)`, `GetActiveTab`,
  `ExportConfig`/`ImportConfig`.
- `AddTab` / `AddSection` still work (kept as aliases), and everything from
  2.2.0 — Statusbar, CommandPalette, Plugins, Host, webhook, autosave,
  `Theme.Set`, `SetQuality` — is untouched and remains available.

## Verification

`scripts/cornui_smoke.py` (Lua 5.5 via lupa, Roblox stubbed): loads all 25
modules in Loader-manifest order, runs 132 API-presence assertions, then 27
functional steps with REAL module code — window creation with v1 props, tab
with icon, nested sections, every v1 element creator with v1 prop names,
element-on-tab and element-on-card, custom elements, flags round-trip and
live element sync, config save/load/export/import, theme switch + color
patch, every window shim, and the v2 additions. **159 checks + steps, 0
failed.** Also fixed a Luau-only loop-variable assignment in
Systems/Commands.lua so the source compiles under strict Lua too.

---

# CornUi v2.2 — feature pass (2026-11-15)

User brief: "the sky, Roblox's servers, and the device are the limit." This
round wires the library into the executor/host environment and the network,
plus more UI polish. Verified by the extended integration harness:
**203 assertions, all passing**, plus a clean `luau-compile` pass over all
Lua files.

## Host integration layer (`Systems/Host.lua`, new)

One capability-detected, pcall-guarded surface for everything that touches
the executor: `HttpGet`, full `Request` (GET/POST — table bodies JSON-encoded,
implementation chain `request` → `http_request` → `syn.request` →
`http.request`), `SetClipboard` / `GetClipboard` (write/read global chains),
`QueueOnTeleport`, and `Identify`. Everything returns `(ok, result)` and
degrades to a `warn()` on executors that lack the global — hubs keep working
on minimal hosts. DiscordButton now uses the shared helper.

## Servers

- **Webhook notifications** — `window:EnableWebhook(url, { MinInterval })`
  mirrors every toast to a Discord-compatible webhook (plain `content`
  payload, rate-limited, queue capped at 10, send failures only `warn()`).
  `DisableWebhook` stops it.
- **Cloud config** — `Config.LoadFromUrl(url)` fetches + applies a JSON
  config from any URL (gist / repo raw / own host).
- **Config sharing without a server** — `Config.ExportToString()` /
  `ImportFromString(str)` round-trip the flag store through a
  `CornUiC1:`-prefixed base64 blob; `CopyToString()` / `PasteFromString()`
  move it through the clipboard (paste needs a `getclipboard` global and
  reports honestly when it's absent).

## Device

- **Statusbar** (`Elements/Statusbar.lua`, new) — `window:CreateStatusbar`:
  a draggable FPS / Lua-memory / device-tier pill. FPS is counted from
  `RunService.RenderStepped` and flushed inline when the sample window
  elapses — no polling loops, no scheduled work between frames.
- **Auto quality** — `window:EnableAutoQuality()`: touch device + viewport
  under 800px tall → one-time drop to Low with an explanatory toast.
- **Off-screen recovery** — drag-end now clamps any window (and the status
  bar) so 48px of width and the title strip always stay on screen; windows
  can no longer get lost on small viewports.
- **Teleport persistence** — `window:PersistAcrossTeleports(loaderUrl?)`
  queues a loader re-fetch so the hub re-runs after server hops (needs
  `queue_on_teleport`; warns honestly when unsupported).

## UI

- **Actionable toasts** — `Notify({ ..., Buttons = { { Text, Callback } } })`
  renders up to two thumb-sized buttons; clicking runs the callback and
  dismisses the toast.

## Harness

37 new assertions (166 → 203): Host identify/request/clipboard/teleport,
webhook mirror on/off, toast buttons render/run/dismiss/cap, config
string round-trip + clipboard round-trip + URL load (with honest base64 in
the harness prelude), statusbar render/tier/FPS/memory flush, auto-quality
apply + desktop no-op, and off-screen clamping at all three edges.

---

# CornUi v2.1 — feature pass (2026-11-15)

User brief: add new features, with creative freedom. Headliner: **Sub-UIs** —
buttons that spawn their own windows, built in a callback or fetched via
loadstring. Everything below is verified by the extended integration harness:
**166 assertions, all passing**, plus a clean `luau-compile` pass over all
Lua files.

## Multi-window (the Sub-UI core)

- **Any number of live windows.** Each `Window.New` gets a unique ScreenGui
  name (`CornUi_1`, `CornUi_2`, ...) and instance `Id`. Theme, flags, config
  and the command registry stay shared; tabs, pages, cleanups and the
  floating button are per-window.
- **`Window:Focus()`** — raises a window above all others via DisplayOrder;
  called automatically on creation, so the newest window is on top.
- **Command ownership** — `Commands.Register` accepts `Owner`; window and
  element commands carry their window, and `Window:Destroy` calls
  `Commands.Release(owner)` so no palette entry ever outlives its UI.
  Window command ids are namespaced per instance (`CornUi.W2.ToggleVisible`)
  so parallel windows never collide.
- **Minimize** — a `–` chip in the title bar collapses the window to a
  title-bar strip (tab strip + pages hidden, exact size restored on
  un-minimize, palette closed, instant on Low quality). `SetMinimized` /
  `IsMinimized` exposed; titleless windows refuse to minimize (no way back).

## Button → Sub-UI (`Elements/Basics.lua`)

`CreateButton` gained composable triggers — SubWindow, then Loadstring, then
Callback, all in one click:

- **`SubWindow = { Title, Size, Position, Name, TabTitle, SectionTitle,
  Intro, Singleton, Build }`** — spawns a real second window with a ready
  first tab/section and hands both to `Build(sub, section)`. Subs skip the
  intro by default. `Singleton` (default true) re-clicks refocus + restore
  the live window instead of stacking clones; each button tracks its own.
- **`Loadstring = "https://..." | code | function()`** — http-prefixed
  strings are HttpGet'd first, anything else compiles directly, functions
  return the source. Fetch/compile/run each guarded; failures surface as a
  toast (when the window has a notification center) plus `warn()`.
- **`Command = false`** — opts a button out of Cornelius (buttons now
  register their action as a palette command by default, matching toggles).

## New widgets (`Elements/Basics.lua`)

- **`Section:CreateStepper({ Flag, Title, Min, Max, Step, Default, Suffix,
  Callback })`** — Flag-backed number field with − / + tap buttons and a
  readout. Values snap to the step grid (Step = 0.1 shows "0.3", not float
  drift) and clamp to [Min, Max]; external `SetFlag` syncs the readout.
- **`Section:CreateCycle({ Flag, Title, Options, Default, Loop = true,
  Callback })`** — Flag-backed cycler with ‹ › tap buttons; the compact
  dropdown for 2–5 fixed options. Wraps unless `Loop = false`; unknown
  flag values fall back to the first option.

## Harness

42 new assertions: unique window ids/names, DisplayOrder stacking, Focus,
minimize + restore (incl. repeated-minimize no-op), sub-window spawn via
button click, Build callback, singleton refocus, button Cornelius command
run, command release on sub-window destroy, URL + inline + broken
loadstring paths, stepper step/clamp/sync/suffix, cycle next/prev/wrap/
no-loop/sync, and a final "no orphaned commands after destroying every
window" invariant.

---

# CornUi v2.0 — Change Log (2026-11-15 fix pass)

Baseline: the `v2.0-rewrite.zip` snapshot. Every change below is verified by an
offline integration harness (`scripts/cornui_integration_test.py`) that stubs
the Roblox environment, executes all 19 modules in the Loader's dependency
order, and drives every element end-to-end — **81 assertions, all passing**,
plus a `luau-compile` syntax check on all 20 files.

## Critical bugs fixed

### 1. Stroke-wrapped Frames were invisible and never re-themed (`Core/Render.lua`)
`Render.New` parented the built frame to `props.Parent` and *then* re-parented
it into a brand-new stroke wrapper that itself had **no parent** — any
`Render.New("Frame", { Parent = x, Stroke = {...} })` produced a parentless,
invisible subtree. Additionally, `Theme.Apply` bound the *wrapper*, so on
`Theme.Set` the visible frame never repainted and `BackgroundColor3` was
painted onto the transparent wrapper.

- `wrapWithStroke` now re-parents the wrapper into whatever parent the frame
  already had, and returns `(wrapper, inner)`.
- `Render.New` passes the *inner* instance to `Theme.Apply`, so theming always
  targets the visible frame.

### 2. `paint()` colored by instance class instead of binding kind (`Core/Theme.lua`)
A TextButton bound to a Frame role (the new Button element) took the
"TextLabel/TextButton/TextBox" branch and had its **text** colored with the
background color — its background never repainted. The color channel now
follows the binding kind: `Text`/`Icon` roles paint text/image color; `Frame`
roles paint the background and additionally pull the label color from
`Text.Default` so themed buttons stay readable in every theme.

### 3. `Config` Enum flags decoded to `nil` on real Roblox (`Systems/Config.lua`)
Encode stored `tostring(value.EnumType)` = `"Enum.KeyCode"`, but
`Enum["Enum.KeyCode"]` is not a valid lookup — the pcall swallowed the error
and every Keybind flag came back `nil` after `LoadConfig`. Encode now stores
`value.EnumType.Name` (`"KeyCode"`), which decodes correctly.

### 4. ColorPicker panel clipped by its own container (`Elements/ColorPicker.lua`)
The container was fixed at 44px while Render's Frame builder defaults
`ClipsDescendants = true`, so the 140px panel was visually cut off at the
section boundary. The container now uses `AutomaticSize.Y` (grows/shrinks with
panel visibility, same as Dropdown) and `Clip = false`.

## Schema gap closed

- **PatchRole clone-before-mutate** (`Core/Theme.lua`): patching a built-in
  theme now clones it into `"<name> Custom"` on first edit, switches to the
  clone, and repaints everything. `Theme.Set("Dark")` after editing Dark
  works as **reset to default**. Added `Theme.List()` (drives the Theme
  Editor dropdown, includes registered customs and clones) and
  `Theme.GetStyle(kind, role)` (seeds Theme Editor pickers with the current
  role color instead of white).

## New features

- **Elements**: `Section:CreateButton({ Title, Accent, Callback })`,
  `Section:CreateLabel({ Title, TextSize, Muted, ... })`,
  `Section:CreateRadioGroup({ Flag, Options, Default, Callback })` — restored
  from v1 parity (`Elements/Basics.lua`).
- **Render built-ins**: `Button` kind (TextButton styled through Frame theme
  roles; text color follows theme on repaint) and `Scroll` kind
  (ScrollingFrame with `ClipsDescendants` forced off — setting it true breaks
  ScrollingFrame input).
- **Window dragging**: invisible drag handle across the title bar, mouse +
  touch (`Core/Window.lua`).
- **Active tab highlight**: selected tab label uses `Text.Default`, inactive
  tabs use `Text.Muted`.
- **Scrollable page holder**: tab pages scroll (`AutomaticCanvasSize`) instead
  of clipping at the window edge.
- **Cleanup registry**: `Window:OnCleanup(fn)`; `Window:Destroy()` runs them.
  Slider, ColorPicker, Keybind, the window drag handle, and the floating
  button register their global `UserInputService` connections — previously
  they leaked for the whole session.
- **Floating button drag-vs-click**: a press that moves > 6px is a drag and no
  longer toggles visibility on release.
- **Keybind Escape**: Escape cancels a rebind in progress (checked before
  `gameProcessed`, since Roblox's menu often claims Escape) and the previous
  bind stays shown; listening now also respects `gameProcessed`.
- **Config export/import**: `Config.ExportConfig()` → JSON string (no disk
  access), `Config.ImportConfig(json)` → applies to live flags.
- **Honest SaveConfig**: returns `false, reason` when the executor lacks
  `writefile` instead of silently returning `true`.
- **Notification fade**: toast text and accent bar fade in/out together with
  the card (previously the text floated on nothing during the animation).
- **Loader**: `Modules.Version = "2.0.0"`.

## Robustness fixes

- Slider: no NaN when `Min == Max`; drag guarded when the track has zero
  absolute size (not laid out yet).
- ProgressBar: same `Min == Max` guard.
- ColorGradient: empty stop list (possible after a config round-trip) renders
  a blank strip instead of erroring; the cycle button no-ops on empty stops.
- Dropdown: option list padding so options aren't flush against the card edge.
- ThemeEditor: dropdown options come from `Theme.List()` (custom themes and
  `"<name> Custom"` clones appear automatically).
- Unused locals removed (`TweenService` in Spotlight/FloatingButton).

## Known cosmetic note
After you pick a custom color for a built-in theme, PatchRole switches the
session to `"<name> Custom"`. The Theme Editor dropdown keeps showing the
base name you picked until you next touch it — switching back to the base
name in the dropdown resets to defaults, by design.

## Still open (unchanged from schema)
Final font + signature corner motif; Cornelius command palette rewrite;
dark/light header toggle decision; GitHub push + Studio/device testing;
`Documentation.MD` rewrite.

---

# Overhaul (v2.1, same session)

User brief: full creative overhaul, "make CornUi your playground" — the only
hard constraints were (1) must not lag on low-end mobiles and (2) the Dark and
Light color schemes stay exactly as they are. Everything below is verified by
the extended integration harness: **116 assertions, all passing**, plus a
clean `luau-compile` pass over all 23 Lua files.

## Performance (the point of CornUi)

- **Quality system**: `CornUi.SetQuality("Low")` / `Render.SetQuality` /
  `Render.Motion()`. Low quality skips tweens, pop animations, stroke
  wrappers and the intro — property writes become instant. Hub UIs can expose
  this as a "potato mode" toggle.
- **ZIndexBehavior.Sibling** instead of Global (far less cross-branch
  resolution on weak devices).
- **ClipsDescendants is now opt-in** — the automatic-size + clipping combo
  forces extra layout passes; panels that needed clipping are Scroll
  containers now.
- **Lighter intro**: 9 shards instead of 24, shorter holds, skipped entirely
  on Low quality.
- **Toggle click path**: direct theme-color reads instead of re-running
  Theme.Apply (no rebinding/paint churn per click); Theme.OnChanged resyncs.
- **Cornelius rows are pooled** — zero instance churn while typing.
- **Dropdown option lists** are capped 190px ScrollingFrames (a 50-option
  dropdown no longer stretches the section).
- **Toast stack capped** at 5; oldest dies first.
- **Autosave debounced** after the last change instead of per-change.
- Loader retries each failed fetch once after 0.5s (transient GitHub 5xx no
  longer kills the whole load).

## Design overhaul (authentic, same Dark/Light palette)

- **Kernel chip**: gold rounded square with a roasted sheen (white→warm-dark
  gradient multiplying the themed Enabled color) on the title bar and the
  floating button (replacing the bare "C" letter).
- **Soft gold accent line** under the title bar (edge-faded via gradient).
- **Pill tabs**: active pill fills with Card color, text goes full
  contrast; a gold underline indicator slides between tabs (one tween).
- **Gold notches** beside section and card titles.
- **Labeled dividers**: `CreateDivider({ Title = "..." })` renders a centered
  chip interrupting the line.
- **Panels pop in** (0.12s UIScale tween, quality-gated): dropdowns, color
  picker, Cornelius, toasts (with fade).
- **Toggle knob** Back-eases; **buttons** duck transparency instantly on press
  (works even on Low quality); **dropdown header** got a rotating diamond.
- `Theme.Tokens` centralizes shell metrics.

## New: Cornelius (command palette)

The v1 flagship feature that was confirmed broken, rebuilt from scratch:
`Systems/Commands.lua` (registry + tokenized ranked search) and
`Elements/CommandPalette.lua` (overlay + search + pooled result rows).
Opens via Ctrl+K, the title-bar `• • •` chip, or the "Open Cornelius"
command. Toggles, tabs, and the window register commands automatically;
hubs can register their own. UI is opt-in and lazy — hubs that never create
it pay nothing.

## New: PluginManager element

`Section:CreatePluginManager({ Title })` lists registered plugins with
Enable/Disable rows (with a stale-label bug fixed during testing) and an
empty state. `Plugins.GetPlugin(name)` added to the lifecycle API.

## New/changed elements

- **Toggle**: `Description` prop (second muted line); command registration.
- **Slider**: tap the value label to type an exact value (v1 parity);
  garbage input rejected, clamped + rounded to increment.
- **Paragraph**: auto-grows with wrapped text (fixed `Height` still honored);
  required an `AutomaticSize` fix in the Render Text builder, which had been
  silently ignored (a real zero-height bug for wrapped text).
- **ThemeEditor**: "Reset theme to default" button (works thanks to the
  clone-on-patch system).
- **Keybind/ColorPicker/Dropdown**: unchanged behavior, resync hooks so
  direct-painted bits survive theme switches.

## Config

- `Config.EnableAutoSave(name, seconds)` — debounced dirty-flag autosave
  (token-guarded, no resave loop); `Window:EnableAutoSave` wires it into the
  window's cleanup registry.
- `Render` Scroll builder gained CornerRadius support.

## Docs

- `Documentation.MD` — full v2.1 API reference (install, quality, window,
  every element, Cornelius, flags, config, themes, render, plugins, design
  system, perf notes).
- `Example.lua` — runnable tour exercising every element + services.

## Verification

- Integration harness: 124 assertions — all elements, Cornelius open/search/
  run/Escape flow + **fuzzy ranking** (typo tolerance, transpositions,
  AND across words, exact-beats-fuzzy ordering, short-word noise guard),
  PluginManager enable/disable, quality system, autosave debounce, config
  round-trips, theme repaint + clone reset, stroke-wrapper and Enum-decode
  regressions, destroy cleanup.
- `luau-compile` clean on all 23 Lua files (21 modules + Loader + Example).
- Loader manifest cross-checked against the file tree (22 entries, none missing).

## Cornelius fuzzy ranking (final piece of the search polish)

`Commands.Search` kept the AND-tokenized exact tiers (title prefix > title
substring > keyword hit) and gained a fuzzy fallback: a bounded
optimal-string-alignment edit distance (insert/delete/substitute/transpose,
with a whole-row early abort so per-keystroke cost stays negligible) tried
per punctuation-trimmed token, only for query words of 4+ letters and only
after the exact tiers miss. Ranking is now worst-link — an entry's score is
its worst-matching word — so exact matches always outrank partly-fuzzy ones.

## Still open

Studio/device testing on real hardware and the GitHub push.
