--[[
    Themes, custom themes and the Skin system (colors + custom fonts + textures) — verbatim v1.9.4d.

    The Lua below is the v1.9.4d source, verbatim, split out of the original
    monolith. Only the prelude (binding the monolith's file-local upvalues to
    the module table) and the trailing module export are ours; the bodies are
    byte-identical to upload/CornUi.lua lines 326-459, 481-498, 563-655, 664-711. The window chrome,
    intro, stacking and every element behave exactly as v1.9.4d shipped.
]]

-- CornUi v1.9.4d (modular) — Core/Theme.lua
return function(Modules)
    local Library = Modules
    local Render = Modules.Render
    local create = Render.create
    local hasChildLayout = Render.hasChildLayout

-- ============ THEME PRESETS (v1.9.4d lines 326-459) ============

local Themes = {
    Dark = {
        Background = Color3.fromRGB(10, 10, 12),
        Header = Color3.fromRGB(16, 16, 19),
        Accent = Color3.fromRGB(255, 196, 48),
        TextOnAccent = Color3.fromRGB(20, 20, 24),
        Text = Color3.fromRGB(240, 240, 245),
        SubText = Color3.fromRGB(140, 140, 148),
        Element = Color3.fromRGB(20, 20, 24),
        ElementHover = Color3.fromRGB(28, 28, 33),
        Stroke = Color3.fromRGB(38, 38, 44),
        ToggleButton = Color3.fromRGB(20, 20, 24),
    },
    Light = {
        Background = Color3.fromRGB(246, 246, 249),
        Header = Color3.fromRGB(255, 255, 255),
        Accent = Color3.fromRGB(255, 178, 30),
        TextOnAccent = Color3.fromRGB(40, 28, 8),
        Text = Color3.fromRGB(25, 25, 28),
        SubText = Color3.fromRGB(110, 110, 118),
        Element = Color3.fromRGB(233, 233, 238),
        ElementHover = Color3.fromRGB(221, 221, 228),
        Stroke = Color3.fromRGB(212, 212, 220),
        ToggleButton = Color3.fromRGB(233, 233, 238),
    },
    Ocean = {
        Background = Color3.fromRGB(8, 20, 40),
        Header = Color3.fromRGB(12, 30, 50),
        Accent = Color3.fromRGB(64, 224, 208),
        TextOnAccent = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(220, 240, 255),
        SubText = Color3.fromRGB(160, 190, 210),
        Element = Color3.fromRGB(16, 35, 55),
        ElementHover = Color3.fromRGB(24, 45, 65),
        Stroke = Color3.fromRGB(40, 70, 90),
        ToggleButton = Color3.fromRGB(16, 35, 55),
    },
    Forest = {
        Background = Color3.fromRGB(10, 25, 10),
        Header = Color3.fromRGB(15, 35, 15),
        Accent = Color3.fromRGB(80, 200, 80),
        TextOnAccent = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(220, 255, 220),
        SubText = Color3.fromRGB(160, 200, 160),
        Element = Color3.fromRGB(15, 35, 15),
        ElementHover = Color3.fromRGB(25, 45, 25),
        Stroke = Color3.fromRGB(40, 80, 40),
        ToggleButton = Color3.fromRGB(15, 35, 15),
    },
    Sunset = {
        Background = Color3.fromRGB(40, 10, 20),
        Header = Color3.fromRGB(50, 15, 25),
        Accent = Color3.fromRGB(255, 140, 60),
        TextOnAccent = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(255, 220, 210),
        SubText = Color3.fromRGB(210, 160, 150),
        Element = Color3.fromRGB(50, 15, 25),
        ElementHover = Color3.fromRGB(65, 25, 35),
        Stroke = Color3.fromRGB(90, 40, 50),
        ToggleButton = Color3.fromRGB(50, 15, 25),
    },
    Amethyst = {
        Background = Color3.fromRGB(25, 15, 40),
        Header = Color3.fromRGB(30, 20, 45),
        Accent = Color3.fromRGB(180, 120, 255),
        TextOnAccent = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(240, 225, 255),
        SubText = Color3.fromRGB(180, 160, 200),
        Element = Color3.fromRGB(30, 20, 45),
        ElementHover = Color3.fromRGB(40, 30, 55),
        Stroke = Color3.fromRGB(60, 45, 80),
        ToggleButton = Color3.fromRGB(30, 20, 45),
    },
    Ruby = {
        Background = Color3.fromRGB(40, 10, 10),
        Header = Color3.fromRGB(50, 15, 15),
        Accent = Color3.fromRGB(255, 60, 60),
        TextOnAccent = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(255, 220, 220),
        SubText = Color3.fromRGB(210, 160, 160),
        Element = Color3.fromRGB(50, 15, 15),
        ElementHover = Color3.fromRGB(65, 25, 25),
        Stroke = Color3.fromRGB(90, 40, 40),
        ToggleButton = Color3.fromRGB(50, 15, 15),
    },
    Frost = {
        Background = Color3.fromRGB(20, 30, 45),
        Header = Color3.fromRGB(25, 35, 50),
        Accent = Color3.fromRGB(150, 220, 255),
        TextOnAccent = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(230, 245, 255),
        SubText = Color3.fromRGB(170, 190, 210),
        Element = Color3.fromRGB(25, 35, 50),
        ElementHover = Color3.fromRGB(35, 45, 60),
        Stroke = Color3.fromRGB(55, 70, 90),
        ToggleButton = Color3.fromRGB(25, 35, 50),
    },
    Candy = {
        Background = Color3.fromRGB(45, 20, 35),
        Header = Color3.fromRGB(55, 25, 42),
        Accent = Color3.fromRGB(255, 150, 200),
        TextOnAccent = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(255, 235, 245),
        SubText = Color3.fromRGB(220, 180, 200),
        Element = Color3.fromRGB(55, 25, 42),
        ElementHover = Color3.fromRGB(70, 35, 55),
        Stroke = Color3.fromRGB(100, 50, 75),
        ToggleButton = Color3.fromRGB(55, 25, 42),
    },
    Midnight = {
        Background = Color3.fromRGB(5, 5, 8),
        Header = Color3.fromRGB(8, 8, 12),
        Accent = Color3.fromRGB(200, 200, 220),
        TextOnAccent = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(255, 255, 255),
        SubText = Color3.fromRGB(150, 150, 160),
        Element = Color3.fromRGB(8, 8, 12),
        ElementHover = Color3.fromRGB(15, 15, 20),
        Stroke = Color3.fromRGB(25, 25, 30),
        ToggleButton = Color3.fromRGB(8, 8, 12),
    },
    Cyber = {
        Background = Color3.fromRGB(10, 5, 20),
        Header = Color3.fromRGB(15, 8, 28),
        Accent = Color3.fromRGB(0, 255, 150),
        TextOnAccent = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(0, 255, 150),
        SubText = Color3.fromRGB(100, 200, 150),
        Element = Color3.fromRGB(15, 8, 28),
        ElementHover = Color3.fromRGB(25, 15, 40),
        Stroke = Color3.fromRGB(0, 255, 150),
        ToggleButton = Color3.fromRGB(15, 8, 28),
    },
}

-- ============ REGISTER THEME + LIVE TABLE (lines 481-498) ============

function Library:RegisterTheme(name, themeTable)
    if type(name) ~= "string" or type(themeTable) ~= "table" then
        warn("[MobileUILib] RegisterTheme requires a name string and a table of colors")
        return
    end
    local merged = {}
    for k, v in pairs(Themes.Dark) do merged[k] = v end
    for k, v in pairs(themeTable) do merged[k] = v end
    Themes[name] = merged

    if #Library._themeHistory >= 5 then
        table.remove(Library._themeHistory, 1)
    end
    table.insert(Library._themeHistory, name)
end

local Theme = {}
for k, v in pairs(Themes.Frost) do Theme[k] = v end

-- ============ SKIN SYSTEM (lines 563-655) ============

-- ============================================================
-- SKIN SYSTEM
-- ============================================================
-- A Skin is a bundle layered on top of the existing Theme system — colors
-- still come from Themes/RegisterTheme, nothing about color-swapping
-- changes — plus four more independent layers a plain color palette
-- doesn't touch:
--   Fonts               — custom fonts (Font.new(...) for FontFace, or
--                          Enum.Font as a fallback — SetSkin tries FontFace
--                          first and falls back automatically)
--   AccentTexture        — tiled overlay on accent-colored CONTROLS:
--                          Slider/ProgressBar/Meter fill, Toggle's on-state
--                          switch. Subtle by default (meant to sit on top
--                          of a color, not replace it).
--   SelectedOptionTexture — tiled overlay on the currently-selected Tab
--                          button specifically. Kept separate from
--                          AccentTexture on purpose: both may currently
--                          render in Theme.Accent, but a skin might want a
--                          different texture (or none) for "this is the
--                          active choice" vs. "this is a slider/toggle".
--   WindowBGTexture       — tiled overlay behind the window only, dulled
--                          (this is what used to be called WindowTexture).
--   WindowTexture         — tiled overlay across the WHOLE UI: header,
--                          sidebar, panels, cards — every Background/
--                          Header/Element/ElementHover/ToggleButton
--                          surface currently on screen. NOT dulled by
--                          default — this is meant to visibly reskin the
--                          chrome, not add a faint watermark behind it.
--
--   Library:RegisterSkin("Carbon", {
--       Theme = "Dark",                                  -- or an inline color table, same shape as RegisterTheme
--       Fonts = {
--           Header = Font.new("rbxasset://fonts/families/..."),
--           Body   = Font.new("rbxasset://fonts/families/..."),
--           Accent = Font.new("rbxasset://fonts/families/..."),
--       },
--       AccentTexture = "rbxassetid://...",
--       AccentTextureTransparency = 0.25,                 -- optional, default shown
--       SelectedOptionTexture = "rbxassetid://...",
--       SelectedOptionTextureTransparency = 0.25,         -- optional, default shown
--       WindowBGTexture = "rbxassetid://...",
--       WindowBGTextureTransparency = 0.85,               -- optional, default shown (dulled)
--       WindowTexture = "rbxassetid://...",
--       WindowTextureTransparency = 0.12,                 -- optional, default shown (NOT dulled)
--   })
--   Window:SetSkin("Carbon")
--
-- SCOPE, stated plainly: AccentTexture reaches Slider fill, ProgressBar
-- fill, Meter fill, and Toggle's on-state switch (incl. three-state).
-- SelectedOptionTexture reaches the active Tab button only — Dropdown's
-- selected row and RadioGroup's selected option use a text-color change
-- rather than a background fill, so a texture overlay doesn't apply the
-- same way there; those would need a different treatment, not this one.
-- WindowTexture reaches every currently-on-screen surface at the moment
-- SetSkin runs, via the same "compare against what's on screen right now"
-- color-match trick SetTheme uses — it does not retroactively tag new
-- elements created after SetSkin, the same limitation AccentTexture has.
Library.Skins = {}
Library._currentAccentTexture = nil
Library._currentSelectedTexture = nil
Library._currentSkinName = nil

-- Library:RegisterSkin("Name", skinDef) — see the block comment above for
-- skinDef's shape.
function Library:RegisterSkin(name, skinDef)
    if type(name) ~= "string" or type(skinDef) ~= "table" then
        warn("[MobileUILib] RegisterSkin requires a name string and a skin definition table")
        return
    end
    Library.Skins[name] = skinDef
end

-- Generic tiled-overlay applier shared by AccentTexture, SelectedOptionTexture,
-- and the whole-UI WindowTexture. `overlayName` keeps the three kinds from
-- colliding on the same instance (an active Tab button, for instance, could
-- plausibly want both a SelectedOptionTexture AND get swept up in the
-- whole-UI WindowTexture pass — they need independent overlay children).
--
-- ZIndex is deliberately kept LOW (0), not layered above the surface's own
-- content — a Frame's BackgroundColor3 always renders behind all of its
-- children regardless of their ZIndex, so an overlay at ZIndex 0 sits
-- visibly on top of that flat color fill while still staying underneath
-- any text/knob/icon children (which default to ZIndex 1). This mirrors
-- the same ZIndex=0 approach Window:SetBackground already uses for exactly
-- this reason.
-- Roblox has no way to make one child "ignore" a UIListLayout/UIGridLayout/
-- UITableLayout/UIPageLayout on its parent — any child we insert gets
-- treated as a real list item and pushed into the stack, consuming a full
-- Size-worth of space. That's exactly what broke the tab sidebar: it's a
-- ScrollingFrame with BackgroundColor3 = Theme.Header (a WindowTexture
-- surface match) AND its own UIListLayout + AutomaticCanvasSize — a
-- 1,0,1,0-sized overlay child shoved every tab button down and forced the
-- canvas (and its accent-colored scrollbar) to grow to compensate.

-- ============ TILED OVERLAY APPLIERS (lines 664-711) ============

function Library:_applyTiledOverlay(inst, overlayName, on, textureId, transparency)
    if not inst then return end
    if hasChildLayout(inst) then return end -- see LAYOUT_CLASSES note above — skip rather than corrupt the layout
    local existing = inst:FindFirstChild(overlayName)
    if on and textureId then
        if not existing then
            local overlay = create("ImageLabel", {
                Name = overlayName,
                Image = textureId,
                ScaleType = Enum.ScaleType.Tile,
                TileSize = UDim2.new(0, 48, 0, 48),
                BackgroundTransparency = 1,
                ImageTransparency = transparency or 0.25,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 0,
            })
            overlay:SetAttribute("MUI_NoTheme", true)
            local existingCorner = inst:FindFirstChildOfClass("UICorner")
            if existingCorner then
                local c = Instance.new("UICorner")
                c.CornerRadius = existingCorner.CornerRadius
                c.Parent = overlay
            end
            overlay.Parent = inst
        else
            existing.Image = textureId
            existing.ImageTransparency = transparency or existing.ImageTransparency
        end
    elseif existing then
        existing:Destroy()
    end
end

Library._currentAccentTextureTransparency = 0.25
Library._currentSelectedTextureTransparency = 0.25

-- Shared by Window:SetSkin (the initial pass over every accent surface
-- already on screen) and any element whose "accent-colored" state can
-- change live after a skin is applied (Toggle's click handler/Set).
function Library:_applyAccentOverlay(inst, isAccent)
    Library:_applyTiledOverlay(inst, "MUI_AccentTexture", isAccent, Library._currentAccentTexture, Library._currentAccentTextureTransparency)
end

-- Shared by Window:SetSkin (initial pass) and Tab selection (selectTab(),
-- so switching tabs keeps the overlay on whichever button is active now).
function Library:_applySelectedOverlay(inst, isSelected)
    Library:_applyTiledOverlay(inst, "MUI_SelectedTexture", isSelected, Library._currentSelectedTexture, Library._currentSelectedTextureTransparency)
end

    -- Module export (ours): the live theme table + presets for the other
    -- modules' preludes. Both are THE tables v1.9.4d mutates in place.
    -- BindLiveTheme hands the same table to Render so stroke()'s verbatim
    -- `Theme.Stroke` default resolves (Render loads before this module).
    if Modules.Render and Modules.Render.BindLiveTheme then
        Modules.Render.BindLiveTheme(Theme)
    end
    return {
        Themes = Themes,
        Theme = Theme,
    }

end
