# CornUi v2.1 — Documentation

CornUi is a mobile-first UI library for executor environments. v2.0 split the
v1.9 monolith into modules; v2.1 is the overhaul pass on top: a quality system
for weak devices, a redesigned shell around the corn identity, and Cornelius —
the command palette.

---

## Install

```lua
local CornUi = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/main/Loader.lua"
))()
```

The Loader burst-fetches every module in parallel (one retry on transient
failures), then executes them in dependency order. It returns the `Modules`
table.

### Weak-device mode

```lua
CornUi.SetQuality("Low")
```

Skips all tweens, pop animations, the intro, and stroke wrappers; everything
still works, it just snaps instantly instead of animating. Ship hubs with this
as an option — CornUi's whole point is not lagging on low-end mobiles.
Default is `"High"`.

---

## Quick start

```lua
local window = CornUi.Window.New({
    Title = "My Hub",
    Size = UDim2.fromOffset(520, 360),
    Intro = true,              -- Christmas shatter intro (auto-skipped on Low)
})

local tab = window:AddTab("Main")
local section = tab:AddSection("General")

section:CreateToggle({ Flag = "GodMode", Title = "God Mode", Default = false })

window:CreateNotificationCenter()
window:Notify({ Title = "Loaded", Text = "Hub ready.", Type = "Success" })

window:CreateCommandPalette()   -- Cornelius: Ctrl+K or the • • • title chip
window:CreateFloatingButton()   -- kernel chip that shows/hides the window
window:EnableAutoSave("default", 5)
```

`Flag` is the key into the central flag store. Every Flag-backed element
registers a UI controller, so `CornUi.Flags.SetFlag("GodMode", true)` flips
the live toggle, `LoadConfig` restores state, and multiple elements can share
one flag.

---

## Window

```lua
local Window = CornUi.Window
```

| Method | Description |
| --- | --- |
| `Window.New(props)` | Creates the shell. Props: `Title`, `Name`, `Size`, `Position`, `Intro` (default true). Multiple live windows are supported — each gets a unique ScreenGui name (`CornUi_1`, `CornUi_2`, ...) and instance `Id`. |
| `window:AddTab(title)` | Returns a Tab. Registers a "Go to tab: X" command. |
| `tab:AddSection(title)` | Returns a Section. |
| `window:SelectTab(tab)` | Switches tabs, styles the active pill, slides the indicator. |
| `window:SetVisible(bool)` | Show/hide; closes Cornelius when hiding. |
| `window:Focus()` | Raises this window above every other CornUi window (DisplayOrder). Called automatically on creation. |
| `window:SetMinimized(bool)` | Collapse the window to its title bar (the `–` chip toggles it). Titleless windows can't minimize. |
| `window:IsMinimized()` | Current minimize state. |
| `window:CreateFloatingButton(props)` | Kernel chip (draggable, 6px move threshold vs click). Props: `Position`, `Icon`. |
| `window:CreateSpotlight(props)` | Dimmer behind the window. Props: `Dimness` (0..1). |
| `window:CreateNotificationCenter(props)` | Toast stack (max 5 visible). |
| `window:Notify(toast)` | `{ Title, Text, Duration = 4, Type = "Default"|"Success"|"Warning"|"Error", Buttons = { { Text, Callback } } }` — up to 2 action buttons; clicking one runs its callback and dismisses the toast. Mirrors to a webhook when `EnableWebhook` is active. |
| `window:CreateCommandPalette(props)` | Cornelius. Props: `Width`, `TopOffset`, `MaxListHeight`, `Placeholder`. |
| `window:EnableAutoSave(name, seconds)` | Debounced config autosave; stops on Destroy. |
| `window:CreateStatusbar(props)` | Draggable FPS / Lua-memory / device-tier pill. Props: `Position`, `FpsWindow` (seconds, default 1). |
| `window:EnableAutoQuality()` | One-time check: touch device + viewport below 800px -> drops quality to Low with an explanatory toast. Returns whether it applied. |
| `window:EnableWebhook(url, props)` | Mirrors every toast to a Discord-compatible webhook (POST JSON). Props: `MinInterval` (default 2s); queue capped at 10. |
| `window:DisableWebhook()` | Stops mirroring. |
| `window:PersistAcrossTeleports(loaderUrl?)` | Queues a loader re-fetch via the host's teleport queue so the hub re-runs after server hops (needs `queue_on_teleport`). |
| `window:OnCleanup(fn)` | Register a function for Destroy to run (disconnect your input connections here). |
| `window:Destroy()` | Runs all cleanups, removes the ScreenGui, and releases every Cornelius command this window (and its elements) registered. |

The window drags from its title bar (mouse and touch). `window._palette` holds
`Open/Close/IsOpen` after Cornelius is created; `window:OpenCommandPalette()`
and `window:CloseCommandPalette()` are attached directly.

---

## Elements (all on Section)

```lua
local section = window:AddTab("Main"):AddSection("General")
```

Every value element takes `{ Flag, Title, Default, Callback }` unless noted.

| Element | Extra props |
| --- | --- |
| `section:CreateToggle(props)` | `Description` — muted second line. |
| `section:CreateSlider(props)` | `Min`, `Max`, `Increment`. Tap the value label to type an exact value. |
| `section:CreateDropdown(props)` | `Options` (array, required), `Multi` (flag value becomes an array). Option panel scrolls, capped at 190px. |
| `section:CreateColorPicker(props)` | `Default` (Color3). Panel with SV square + hue strip. |
| `section:CreateKeybind(props)` | `Default` (Enum.KeyCode), `OnPress`. Escape cancels a rebind. |
| `section:CreateTextInput(props)` | `Placeholder`. Commits on FocusLost. |
| `section:CreateButton(props)` | `Accent` (gold style), `Size`. Instant press-duck feedback. Sub-UI spawner: `SubWindow` and/or `Loadstring` (see Sub-UIs below); `Command = false` opts out of Cornelius. |
| `section:CreateLabel(props)` | `TextSize`, `Muted`, `XAlignment`, `Size`, `TextWrapped`. |
| `section:CreateParagraph(props)` | `Text`, `TextSize`, `Height` (omit to auto-grow). |
| `section:CreateDivider(props)` | `Title` — centered chip interrupting the line; `Transparency`. |
| `section:CreateCard(props)` | `Title`. Returns a card with `card:Add(instance)`. |
| `section:CreateImage(props)` | `Image` (asset id, required), `Size`, `ScaleType`. |
| `section:CreateProgressBar(props)` | `Min`, `Max`, optional `Flag` to auto-update. |
| `section:CreateRadioGroup(props)` | `Options` (array, required), `Default`. Single-select dots. |
| `section:CreateStepper(props)` | `Min`, `Max`, `Step`, `Suffix`. Flag number with −/+ tap buttons (mobile slider alternative). Readout snaps to the step grid. |
| `section:CreateCycle(props)` | `Options` (array, required), `Default`, `Loop` (default true). Flag cycler with ‹ › tap buttons — compact dropdown for short lists. |
| `section:CreateKeybindList(props)` | `Flags` (array of keybind flag names), `Labels` (map). Live-updating bound-key list. |
| `section:CreateColorGradient(props)` | `Default` — array of `{ Time, Color }` stops. Stores an array; callback gets `(stops, ColorSequence)`. |
| `section:CreateDiscordButton(props)` | `Invite` (required), `Title`, `Icon`, `OnClick`. Copies invite. |
| `section:CreateSearch(props)` | `Placeholder`, `Targets` (array of GuiObjects to auto-filter), `MatchKey`, `OnChanged`. |
| `section:CreateThemeEditor(props)` | Dropdown + color pickers + texture/font fields + Reset button. See Theme Editor below. |
| `section:CreatePluginManager(props)` | `Title`, `EmptyText`. Rows with Enable/Disable for every registered plugin. |

---

## Sub-UIs (multi-window)

CornUi allows any number of live windows: the main UI plus button-spawned
sub-UIs. Each window is fully independent (own ScreenGui, tabs, cleanup
registry); theme, flags, config and the command registry are shared. New
windows stack on top automatically, `–` in the title bar minimizes back to
the title strip, and destroying a window releases its commands so Cornelius
never runs something owned by a dead UI.

The easy path is a button — the two props compose with `Callback`:

```lua
-- 1) Callback-built sub-window (created fresh, or refocused if Singleton):
section:CreateButton({
    Title = "Open Player List",
    SubWindow = {
        Title = "Player List",            -- window props: Title, Size, Position, Name
        Size = UDim2.fromOffset(320, 240),
        TabTitle = "Main",                -- auto first tab/section ("Main")
        Intro = false,                    -- subs skip the intro by default
        Singleton = true,                 -- re-click raises the live window
        Build = function(sub, firstSection)
            firstSection:CreateToggle({ Flag = "ShowSelf", Title = "Show self" })
        end,
    },
})

-- 2) Loadstring sub-UI: runs another CornUi script that calls MakeWindow
--    itself. An http-prefixed string is HttpGet'd first; a plain string is
--    compiled as code; a function must return the source.
section:CreateButton({
    Title = "Run remote sub-UI",
    Loadstring = "https://raw.githubusercontent.com/you/YourHub/main/SubUI.lua",
})

section:CreateButton({
    Title = "Run inline snippet",
    Loadstring = 'print("hello from a sub-UI")',
})
```

You can also call `CornUi.Window.New(props)` directly for manual multi-window
setups. Loadstring failures (fetch, compile, runtime) surface as a toast when
the window has a notification center and a `warn()` always.

---

## Host — servers & device (v2.2)

`CornUi.Host` is the single integration point with the executor environment.
Every capability is capability-detected (executor globals vary) and
pcall-guarded: functions return `(ok, result)` and degrade to `warn()`
instead of throwing.

```lua
CornUi.Host.HttpGet(url)                 -- (ok, body)
CornUi.Host.Request({ Url, Method, Headers, Body })
                                         -- full GET/POST; table bodies are
                                         -- JSON-encoded; tries request /
                                         -- http_request / syn.request / http.request
CornUi.Host.SetClipboard(text)           -- setclipboard / toclipboard / set_clipboard
CornUi.Host.GetClipboard()               -- (ok, text) — rare; handle false
CornUi.Host.QueueOnTeleport(fn)          -- re-run code after teleports
CornUi.Host.Identify()                   -- executor name or "Unknown"
```

Typical uses:

- **Webhook notifications** — `window:EnableWebhook(url)` mirrors toasts to
  Discord (rate-limited, queue-capped, failures only warn).
- **Config sharing** — `Config.CopyToString()` puts a `CornUiC1:`-prefixed
  blob on the clipboard; friends run `Config.PasteFromString()`. No server
  involved. `Config.LoadFromUrl(url)` pulls a JSON config from a gist, repo
  raw file, or your own host instead.
- **Device telemetry** — `window:CreateStatusbar()` shows live FPS (counted
  from RenderStepped, no polling loops) and Lua GC memory, plus the device
  tier; `window:EnableAutoQuality()` drops weak touch devices to Low once.

---

## Themes (Skin System)

## Cornelius (command palette)

```lua
window:CreateCommandPalette()
```

Open with Ctrl+K, the `• • •` title-bar chip, or the registered command.
Type to filter (multi-word AND matching), Enter runs the first result, Escape
closes, click-outside closes.

Anything can register a command:

```lua
CornUi.Commands.Register({
    Id       = "MyHub.Aimbot",
    Title    = "Toggle: Aimbot",
    Keywords = "aimbot esp combat",
    Hint     = function() return Flags.GetFlag("Aimbot") and "On" or "Off" end,
    Run      = function() CornUi.Flags.SetFlag("Aimbot", not CornUi.Flags.GetFlag("Aimbot")) end,
})
```

Re-registering an `Id` replaces the entry. Toggles, buttons, tabs and the
window register themselves automatically; every entry they create is owned
by that window and released when it's destroyed. API: `Register`,
`Unregister`, `Release(owner)`, `Search(query, max)`, `Run(id)`, `Get(id)`,
`Count()`.

Search ranking: the query is AND-tokenized against title + keywords
(title prefix > title substring > keyword hit), with a fuzzy fallback for
typos — words of 4+ letters match within a bounded edit distance of 1–2
(covers "togle" → Toggle, "amibot" → Aimbot, transposed letters), while
shorter words stay exact so 2–3 letter queries don't drag in noise. An
entry's rank is its worst-matching word, so fully-exact results always
come above partly-fuzzy ones.

---

## Flags

```lua
CornUi.Flags.SetFlag("Key", value)          -- pushes to the live UI
CornUi.Flags.GetFlag("Key", default)
CornUi.Flags.GetAllFlags()
CornUi.Flags.FlagChanged:Connect(function(name, newValue, oldValue) end)
CornUi.Flags.OnFlagChanged("Key", callback) -- scoped listener
CornUi.Flags.RegisterElement(name, { Set = fn })  -- custom UI sync hook
```

## Config

```lua
CornUi.Config.SaveConfig("mine")     -- true / false, reason
CornUi.Config.LoadConfig("mine")     -- restores flags + UI
CornUi.Config.ExportConfig()         -- JSON string (no disk)
CornUi.Config.ImportConfig(json)     -- apply an exported string
CornUi.Config.ListConfigs()          -- {"mine", ...}
CornUi.Config.DeleteConfig("mine")
CornUi.Config.EnableAutoSave("mine", 5)  -- returns stop()

-- Share / cloud (v2.2):
CornUi.Config.ExportToString()       -- "CornUiC1:<base64>" portable string
CornUi.Config.ImportFromString(str)  -- apply a share string
CornUi.Config.CopyToString()         -- ExportToString + clipboard
CornUi.Config.PasteFromString()      -- clipboard -> ImportFromString (needs getclipboard)
CornUi.Config.LoadFromUrl(url)       -- fetch + apply a JSON config from any URL
```

Color3 / Vector2 / Vector3 / UDim2 / EnumItem / arrays survive round-trips.
Internal `__CornUi*` flags are excluded from saves.

---

## Themes (Skin System)

11 built-ins: Dark, Light, Ocean, Forest, Sunset, Amethyst, Ruby, Frost
(default), Candy, Midnight, Cyber. Dark and Light carry the corn palette
(roasted-husk darks, cream lights, gold kernel accent).

```lua
CornUi.Theme.Set("Light")                        -- live repaint of every instance
CornUi.Theme.Get()
CornUi.Theme.List()                              -- includes customs + clones
CornUi.Theme.GetStyle("Frame", "Enabled").Color  -- read the live role color
CornUi.Theme.Register("MyTheme", definition)     -- same shape as built-ins
CornUi.Theme.PatchRole(theme, kind, role, patch) -- live edit; clones built-ins
CornUi.Theme.SetTexture(theme, "Frame", "Window", "rbxassetid://123")
CornUi.Theme.ClearTexture(theme, "Frame", "Window")
CornUi.Theme.SetFont(theme, "Default", "GothamBold")  -- or an asset id
CornUi.Theme.OnChanged:Connect(function(name) end)
```

Patching a built-in never mutates it: the first patch clones it into
`"<name> Custom"` and switches to the clone, so `Theme.Set("Dark")` after
editing Dark resets to pristine defaults. The Theme Editor's Reset button
uses exactly this.

Theme shape: `{ Frame = { Default/Window/Card/Enabled = { Color, CornerRadius, Texture, ... } }, Text = { Default/Muted = { Color, Font } }, Icon = { Default } }`.

---

## Render primitives

```lua
CornUi.Render.New(kind, props)
```

Built-in kinds: `Frame`, `Text`, `Icon`, `Gradient`, `Button`, `Scroll`.
`RegisterBuilder(kind, fn)` adds more. Common props: `Name`, `Size`,
`Position`, `AnchorPoint`, `ZIndex`, `Visible`, `Parent`, `Theme`
(role string, or `false` to opt out), `CornerRadius`, `Clip` (opt-in),
`Stroke` (wrapper-based), `Texture`/`TextureTransparency` (Frame),
`Font` (Enum.Font or Font.new).

Quality API: `Render.Quality`, `Render.SetQuality("High"|"Low")`,
`Render.Motion()` (false on Low — gate your decorative tweens on it).

---

## Plugins

```lua
CornUi.Plugins.Register("Name", function(ctx)
    -- ctx = { Window, Render, Theme, Flags, Config, Modules }
    return {
        Init = function(ctx) end,
        Unload = function(ctx) end,
    }
end)

CornUi.Plugins.EnablePlugin("Name")
CornUi.Plugins.DisablePlugin("Name")
CornUi.Plugins.ReloadPlugin("Name")
CornUi.Plugins.UnloadPlugin("Name")
CornUi.Plugins.ListPlugins()   -- { { Name, Enabled }, ... }
CornUi.Plugins.GetPlugin("Name")
```

`Source` may also be a URL string (HttpGet + loadstring). `Section:CreatePluginManager`
renders the registry with Enable/Disable buttons.

---

## Design system

The shell is drawn with plain frames — zero image assets to download:

- **Kernel chip** — gold rounded square with a roasted sheen (title bar, floating button)
- **Accent line** — soft gold rule under the title bar
- **Pill tabs** — active pill fills with the Card color; a gold underline indicator slides between tabs
- **Gold notches** — beside section and card titles
- All colors come from theme roles, so every theme (and custom themes) restyles
  the whole shell automatically.

Metrics live in `Theme.Tokens` (TitleHeight, TabBarHeight, RowHeight, ...).

---

## Performance notes

- `ZIndexBehavior.Sibling` on the ScreenGui
- `ClipsDescendants` is opt-in (automatic-size + clipping is a costly combo)
- Intro is 9 shards and skipped on Low quality
- Cornelius UI is built once on opt-in and pools its result rows (no churn per keystroke)
- Dropdown option lists are capped 190px ScrollingFrames instead of unbounded growth
- Toggle clicks read theme colors directly instead of re-running the binding machinery
- Toast stack caps at 5; autosave is debounced after the last change
- All global input connections disconnect via `window:OnCleanup` on Destroy
