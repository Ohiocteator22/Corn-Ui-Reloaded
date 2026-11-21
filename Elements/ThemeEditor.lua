--[[
    CornUi v2.0 — Elements/ThemeEditor.lua
    Registers Section:CreateThemeEditor(props).
    A dropdown to switch between registered themes (live, via Theme.Set),
    plus per-kind/role color pickers for the active theme so users can
    customize on top of a base theme without writing Lua.

    props = {
        Title = "Appearance",
        Editable = {               -- which Kind/Role pairs show a color picker
            { Kind = "Frame", Role = "Window", Label = "Window Background" },
            { Kind = "Frame", Role = "Card",   Label = "Card Background" },
            { Kind = "Frame", Role = "Enabled",Label = "Accent" },
            { Kind = "Text",  Role = "Default",Label = "Text" },
        },
        TextureEditable = {        -- which Frame roles get a custom-texture asset id field
            { Role = "Window",  Label = "Window Background Texture" },
            { Role = "Card",    Label = "Card Background Texture" },
            { Role = "Enabled", Label = "Accent Texture" },
        },
        FontEditable = {           -- which Text roles get a custom-font field
            { Role = "Default", Label = "Font" },
        },
    }

    Texture/Font fields accept either a bare rbxassetid (e.g. "rbxassetid://1234"
    or just "1234" for a custom uploaded asset) or, for Font, an Enum.Font
    name (e.g. "GothamBold"). Leave the field blank and refocus-away to clear
    a texture back to plain Color.

    Depends on Dropdown, ColorPicker, and TextInput already being registered
    on Section.
]]

return function(Modules)

    local Flags = Modules.Flags
    local Section = Modules.Window.Section
    local Theme = Modules.Theme

    local ThemeEditor = {}

    local DEFAULT_EDITABLE = {
        { Kind = "Frame", Role = "Window",  Label = "Window Background" },
        { Kind = "Frame", Role = "Card",    Label = "Card Background" },
        { Kind = "Frame", Role = "Default", Label = "Element Background" },
        { Kind = "Frame", Role = "Enabled", Label = "Accent" },
        { Kind = "Text",  Role = "Default", Label = "Text" },
        { Kind = "Text",  Role = "Muted",   Label = "Muted Text" },
    }

    local DEFAULT_TEXTURE_EDITABLE = {
        { Role = "Window",  Label = "Window Background Texture" },
        { Role = "Card",    Label = "Card Background Texture" },
        { Role = "Enabled", Label = "Accent Texture" },
    }

    local DEFAULT_FONT_EDITABLE = {
        { Role = "Default", Label = "Font" },
    }

    function ThemeEditor.New(section, props)
        props = props or {}
        local editable = props.Editable or DEFAULT_EDITABLE
        local textureEditable = props.TextureEditable or DEFAULT_TEXTURE_EDITABLE
        local fontEditable = props.FontEditable or DEFAULT_FONT_EDITABLE

        assert(Section.CreateDropdown, "ThemeEditor requires Elements/Dropdown.lua to be loaded first")
        assert(Section.CreateColorPicker, "ThemeEditor requires Elements/ColorPicker.lua to be loaded first")
        assert(Section.CreateTextInput, "ThemeEditor requires Elements/TextInput.lua to be loaded first")

        local baseFlag = "__CornUi_ThemeBase"
        local initialBase = Flags.GetFlag(baseFlag, Theme.Get() or "Dark")

        -- Built from the live theme registry (Theme.List) rather than a
        -- hardcoded list, so Theme.Register-ed custom themes and the
        -- "<name> Custom" clones PatchRole creates all appear here.
        section:CreateDropdown({
            Title = "Theme",
            Flag = baseFlag,
            Options = Theme.List(),
            Default = initialBase,
            Callback = function(name)
                Theme.Set(name)
            end,
        })

        for _, entry in ipairs(editable) do
            local flagName = ("__CornUi_ThemeColor_%s_%s"):format(entry.Kind, entry.Role)

            -- Seed the picker with the role's CURRENT color instead of white,
            -- so opening the editor doesn't suggest repainting everything white.
            local style = Theme.GetStyle(entry.Kind, entry.Role)

            section:CreateColorPicker({
                Title = entry.Label,
                Flag = flagName,
                Default = (style and style.Color) or Color3.fromRGB(255, 255, 255),
                Callback = function(color)
                    -- Live-patch the active theme's color for this Kind/Role,
                    -- then re-apply so every tracked instance repaints.
                    local current = Theme.Get()
                    Theme.PatchRole(current, entry.Kind, entry.Role, { Color = color })
                end,
            })
        end

        for _, entry in ipairs(textureEditable) do
            local flagName = ("__CornUi_ThemeTexture_%s"):format(entry.Role)

            section:CreateTextInput({
                Title = entry.Label,
                Flag = flagName,
                Placeholder = "rbxassetid://... (blank to clear)",
                Callback = function(text)
                    local current = Theme.Get()
                    if text == "" then
                        Theme.ClearTexture(current, "Frame", entry.Role)
                    else
                        Theme.SetTexture(current, "Frame", entry.Role, text)
                    end
                end,
            })
        end

        for _, entry in ipairs(fontEditable) do
            local flagName = ("__CornUi_ThemeFont_%s"):format(entry.Role)

            section:CreateTextInput({
                Title = entry.Label,
                Flag = flagName,
                Placeholder = "GothamBold, or rbxassetid://... for a custom font",
                Callback = function(text)
                    if text == "" then return end
                    Theme.SetFont(Theme.Get(), entry.Role, text)
                end,
            })
        end

        -- Reset: since PatchRole clones built-ins into "<name> Custom", simply
        -- re-setting the base theme name restores its pristine palette.
        section:CreateButton({
            Title = "Reset theme to default",
            Callback = function()
                Theme.Set(Flags.GetFlag(baseFlag, Theme.Get() or "Frost"))
            end,
        })

        Theme.Set(initialBase)
    end

    Section.CreateThemeEditor = function(section, props)
        return ThemeEditor.New(section, props)
    end

    return ThemeEditor
end
