# 🌽 CornUi

A **mobile-first Roblox UI framework** designed to work identically on **touch devices and desktop**.

CornUi provides an Orion-style development experience with a modern architecture:

- Plugin system
- Theme engine
- Command palette
- Flag manager
- Advanced widgets
- Mobile-first scaling
- Custom backgrounds
- Notification system
- Config support

Built for developers who want a clean, expandable UI framework instead of a collection of scripts.

---

# ✨ Features

## Core UI

✅ Window system  
✅ Tabs  
✅ Sections  
✅ Buttons  
✅ Toggles  
✅ Sliders  
✅ Textboxes  
✅ Dropdowns  
✅ Keybinds  
✅ Color Pickers  

Designed to work on:

- 📱 Mobile
- 🖥️ Desktop
- 🎮 Controller-compatible setups

---

# 🎨 Theme Engine

CornUi includes a complete theme system.

Built-in themes:

- Dark
- Light

Custom themes can be registered:

```lua
Corn:RegisterTheme("Sunset", {
    Background = Color3.fromRGB(30,12,10),
    Accent = Color3.fromRGB(255,120,60)
})
```
--------------------------------------------------
🔌 Plugin System

CornUi supports external plugins.

Plugins can extend the library without modifying the core source.

Example:
```lua 
    Corn:LoadPlugin(
    "https://example.com/MyPlugin.lua",
    Window
    )
```
multiple Plugins-
```lua
    Corn:LoadPlugins({
        "Plugin1.lua",
        "Plugin2.lua"
    }, Window)
```


-------------------------------------------------

+ to use the loader, use loadstring(game:HttpGet("https://raw.githubusercontent.com/Ohiocteator22/Corn-Ui-Reloaded/refs/heads/main/Loader/Corn%20Ui%20loader.lua"))()
