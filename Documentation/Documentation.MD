# CornUi Documentation

A mobile-first Roblox UI library — Orion-style window/tabs/elements, but built to work identically on touch and desktop.

## Loading the library

```lua
local Corn = loadstring(game:HttpGet('https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Sourse/CornUi.lua'))()
```

`Corn` is the library table (also called `Library` internally). Everything below hangs off it, a `Window`, or a `Tab`/`Section`.

---

## 1. Windows

### `Corn:CreateWindow(config)`

Builds and returns a `Window`. Only one window exists at a time — calling this again destroys the previous one.

| Field | Type | Notes |
|---|---|---|
| `Name` | string | Title text, also doubles as the command palette input |
| `Subtitle` | string | Optional second line under the title; grows the header height |
| `Icon` | number/string | Asset id (raw number or `rbxassetid://...`), used in the header and the floating toggle button |
| `Theme` | string | `"Dark"` (default), `"Light"`, or any name registered via `RegisterTheme` |
| `Intro` | table | `{ Image, Text, Duration }` — controls the intro animation; `Image = false` skips the intro image, `Duration` is how long it holds before the reveal |

```lua
local Window = Corn:CreateWindow({
    Name = "Corn Hub",
    Subtitle = "v1.0",
    Icon = 80406291512141,
    Theme = "Dark",
})
```

The window auto-scales to the player's actual screen resolution, respects the mobile safe-area/notch, and is fully draggable by its header. A floating toggle button is placed on-screen so the whole hub can be hidden and re-summoned at any time — important on mobile, where there's no keybind to bring it back.

### Window methods

**`Window:Notify(config)`**
Pops a toast notification with a countdown bar.

| Field | Type |
|---|---|
| `Title` | string |
| `Content` | string |
| `Duration` | number (seconds, default 4) |
| `Type` | `"success"` \| `"error"` \| `"warning"` \| `"info"` (optional — colors the accent bar and adds an icon) |

```lua
Window:Notify({ Title = "Saved", Content = "Settings updated.", Type = "success" })
```

**`Window:SetTheme(name)`**
Live-swaps the whole hub between `"Dark"`, `"Light"`, or any custom registered theme, tweening every matching color across every element at once.

**`Window:SetThemeColor(key, color)`**
Single-key recolor, used internally by the Theme Editor widget. Only two keys are editable this way: `"Background"` (the hub's base color) and `"ToggleButton"` (the floating show/hide button) — the corn-yellow accent is intentionally excluded so it can never be recolored.

**`Window:SetBackground(input)`**
Sets an image or video backdrop behind everything in the hub.

```lua
Window:SetBackground(123456789)                 -- bare asset id
Window:SetBackground("rbxassetid://123456789")  -- asset string
Window:SetBackground({ Type = "Video", Texture = "rbxassetid://...", Volume = 0 })
```

If given a local filename (e.g. `"wallpaper.jpg"`) it will try to resolve it through `getcustomasset()` when the executor supports it.

**`Window:ClearBackground()`**
Removes whatever `SetBackground` added.

**`Window:RegisterCommand(keyword, fn)`**
Adds a command to the title-bar command palette. Tap/click the title, type a registered keyword (optionally followed by arguments), and press enter — `fn(window, argString, args)` fires, then the title reverts to the hub's name. A `"t-notif"` test command is registered by default.

```lua
Window:RegisterCommand("speed", function(window, argString)
    local n = tonumber(argString) or 16
    -- apply n to WalkSpeed...
    window:Notify({ Title = "Speed", Content = "Set to " .. n, Type = "success" })
end)
```

**`Window:SetSpotlight(active)`**
Dims the rest of the hub while a popover (dropdown, color picker) is open. Reference-counted internally — used by those widgets automatically, rarely called directly.

**`Window:CreateTab(name, config)`**
See [Tabs](#2-tabs-and-sections) below.

---

## 2. Tabs and Sections

### `Window:CreateTab(name, config)`

Adds a tab to the sidebar and returns a `Tab`. `config.Icon` accepts the same asset-id formats as the window icon.

```lua
local Tab = Window:CreateTab("Main", { Icon = 123456 })
```

### `Tab:CreateSection(name)`

Groups elements visually within a tab. A `Section` supports every element method a `Tab` does (buttons, toggles, etc. can be created directly on either).

```lua
local Section = Tab:CreateSection("Movement")
```

---

## 3. Elements

All element methods below exist on both `Tab` and `Section` objects.

### `CreateLabel(text)`
Plain, non-interactive text line.

### `CreateButton(config)`
| Field | Type |
|---|---|
| `Name` | string |
| `Callback` | function |

Includes a ripple effect and a brief accent-color flash on tap.

### `CreateToggle(config)`
| Field | Type |
|---|---|
| `Name` | string |
| `Default` | boolean |
| `Flag` | string (optional — syncs into the Flag Manager) |
| `Callback` | function(state) |

Returns `{ Set(value), Get() }`.

### `CreateSlider(config)`
| Field | Type |
|---|---|
| `Name` | string |
| `Min` / `Max` | number |
| `Default` | number |
| `Flag` | string (optional) |
| `Callback` | function(value) |

Drag or tap-and-drag along the track; touch gets a larger invisible hit area than the visible bar. Returns `{ Set(value) }`.

### `CreateTextbox(config)` (alias: `CreateTextBox`)
| Field | Type |
|---|---|
| `Name` | string |
| `Default` | string |
| `Placeholder` | string |
| `Flag` | string (optional) |
| `Callback` | function(text, enterPressed) |

Fires on focus lost (tapping away or pressing enter). Returns `{ Set(value), Get() }`.

### `CreateKeybind(config)`
| Field | Type |
|---|---|
| `Name` | string |
| `Default` | `Enum.KeyCode` |
| `Flag` | string (optional) |
| `Callback` | function(keyCode) |

Click the key button, then press any key to bind it. Returns `{ Set(keyCode), Get() }`.

### `CreateColorPicker(config)`
| Field | Type |
|---|---|
| `Name` | string |
| `Default` | `Color3` |
| `Flag` | string (optional) |
| `Callback` | function(color) |

Expands into a saturation/value square plus a hue strip when tapped; dims the rest of the hub via the window's spotlight while open. Returns `{ Set(color), Get() }`.

### `CreateDropdown(config)`
| Field | Type |
|---|---|
| `Name` | string |
| `Options` | table of strings |
| `Default` | one of `Options` |
| `Flag` | string (optional) |
| `Callback` | function(selected) |

Scrollable and height-capped (shows up to 6 items before scrolling) so long option lists don't blow up the layout. Returns `{ Set(value) }`.

### `CreateSearch(config)`
| Field | Type |
|---|---|
| `Placeholder` | string |

Filters the visible elements within the **same tab/section it's placed in** by name, keywords, and description as you type. Shows a "not available or removed" message when nothing matches.

```lua
Section:CreateSearch({ Placeholder = "Search..." })
```

To make an element show up in search results beyond its literal name, any element's `config` can include:
- `Keywords` — a string or array of strings
- `Description` — a string

### `CreateThemeEditor(config)`
Adds two color pickers pre-wired to `Window:SetThemeColor` — one for the hub's background, one for the floating toggle button.

| Field | Type |
|---|---|
| `Title` | string (optional, defaults to "Theme Editor") |
| `UIColorName` | string (optional label override) |
| `ToggleColorName` | string (optional label override) |

```lua
Tab:CreateThemeEditor()
```

### `CreateDiscordButton(config)`
| Field | Type |
|---|---|
| `Name` | string (default "Join Discord") |
| `Invite` | string, e.g. `"discord.gg/xxxx"` |

Opens a popup with a selectable text field containing the invite. Roblox LocalScripts have no OS clipboard access, so this can't auto-copy — the player selects and copies it manually.

```lua
Tab:CreateDiscordButton({ Name = "Join Discord", Invite = "discord.gg/kdBxp8BGuT" })
```

---

## 4. Flag Manager

A shared value store so any flagged element can be read or written from anywhere, without holding a reference to the element itself.

- `Corn:GetFlag(name)` → current value
- `Corn:SetFlag(name, value)` → sets it and fires the change event
- `Corn.FlagChanged` → a `BindableEvent`'s `.Event`, fires `(name, value)` on every change

```lua
Corn.FlagChanged:Connect(function(name, value)
    if name == "MyPlugin_Enabled" then
        -- react to it
    end
end)
```

Any element created with a `Flag = "..."` field auto-syncs into this system.

---

## 5. Themes

Two built-in presets: `"Dark"` and `"Light"`.

### `Corn:RegisterTheme(name, themeTable)`
Registers a custom named preset. Any color you don't specify falls back to the Dark preset's value.

```lua
Corn:RegisterTheme("Sunset", {
    Background = Color3.fromRGB(30, 12, 10),
    Accent = Color3.fromRGB(255, 120, 60),
})

local Window = Corn:CreateWindow({ Name = "Hub", Theme = "Sunset" })
```

Themeable keys: `Background`, `Header`, `Accent`, `TextOnAccent`, `Text`, `SubText`, `Element`, `ElementHover`, `Stroke`, `ToggleButton`.

---

## 6. Plugin System

Plugins are separate Lua files, hosted externally, loaded at runtime — they extend the hub without editing `CornUi.lua` itself.

### Loading plugins

```lua
Corn:LoadPlugin(url, Window)          -- single plugin
Corn:LoadPlugins({ url1, url2 }, Window)  -- several at once, in order
```

`Window` is optional — omit it if the plugin only needs Flags/Themes, pass it if the plugin needs to register commands, add tabs, send notifications, or set a background.

Every step — fetching, compiling, and running a plugin, plus its `Init` call — is wrapped in `pcall`. A broken or malicious plugin can't take down the hub or the other plugins loaded alongside it; it just fails with a `warn()` and everything else keeps running.

### Writing a plugin

A plugin file returns a table:

```lua
return {
    Name = "Admin Commands",   -- optional, used for Corn.Plugins[] and warn() messages
    Version = "1.0.0",         -- optional, informational only
    Init = function(ctx)
        ctx:RegisterCommand("speed", function(window, argString)
            local n = tonumber(argString) or 16
            -- ...
        end)
    end,
}
```

### The `ctx` object

The only surface a plugin should touch — a stable wrapper over the library/window internals so plugins don't depend on private fields that might change later:

| Member | Description |
|---|---|
| `ctx.Library` | the raw library table, for advanced use |
| `ctx.Window` | the window this plugin was loaded against (may be `nil`) |
| `ctx.Player` | `Players.LocalPlayer` |
| `ctx:GetFlag(name)` / `ctx:SetFlag(name, value)` | Flag Manager |
| `ctx.FlagChanged` | the Flag Manager's change event |
| `ctx:RegisterTheme(name, themeTable)` | custom themes |
| `ctx:RegisterCommand(keyword, fn)` | command palette (needs a window) |
| `ctx:SetBackground(sourceOrConfig)` / `ctx:ClearBackground()` | backdrop FX (needs a window) |
| `ctx:CreateTab(name, tabConfig)` | adds a tab to the hub (needs a window) |
| `ctx:Notify(notifConfig)` | fires a notification (needs a window) |

---

## 7. Known limitations

- **No real background blur.** Roblox's 2D GUI layer has no blur API; the "glass" look on the main window is an approximated transparency + diagonal light-streak, not a true frosted-glass effect.
- **No OS clipboard access from LocalScripts.** `CreateDiscordButton` works around this with a copyable text field instead of a one-tap copy.
- **`Library.Flags.ReducedMotion`** — when set to `true` *before* calling `CreateWindow`, every tween in the library (ripples, tab transitions, theme swaps, and the intro) is skipped in favor of instantly jumping to the end state, and the intro animation is skipped entirely. Useful for a "reduced motion" / performance-mode setting.
- **Search is scoped, not global.** `CreateSearch` filters elements within the tab/section it's placed in, not the entire hub — Roblox has no built-in fuzzy-search-everything primitive without a manual index.
