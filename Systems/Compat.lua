--[[
    CornUi v1.9.4d (modular) — Systems/Compat.lua

    Nothing here rewrites v1.9.4d anymore: every module above already IS the
    v1.9.4d code, and the loader's shared table IS the Library facade, so the
    full v1 API (CreateWindow, CreateTab, Tab:Create___, Flags, Configs,
    RegisterTheme/RegisterSkin/SetSkin, Cornelius) is live as shipped.

    This final module only:
      1. asserts the verbatim API surface actually landed (a CI guard: a
         broken extraction fails the load with a named list, never silently),
      2. bridges the Cornelius global onto the facade,
      3. leaves the v2 add-ons (CommandPalette, Statusbar, Host, Assets)
         exactly as they are — additions over the old version, never instead
         of it.
]]

return function(Modules)

    local Library = Modules

    local missing = {}
    local function need(label, ok)
        if not ok then missing[#missing + 1] = label end
    end

    need("Library:CreateWindow", type(Library.CreateWindow) == "function")
    need("Library.WindowMethods", type(Library.WindowMethods) == "table")
    need("Library.TabMethods", type(Library.TabMethods) == "table")
    need("Library.Flags", type(Library.Flags) == "table")
    need("Library.FlagChanged", Library.FlagChanged ~= nil)
    need("Library:GetFlag", type(Library.GetFlag) == "function")
    need("Library:SetFlag", type(Library.SetFlag) == "function")
    need("Library.SaveConfig", type(Library.SaveConfig) == "function")
    need("Library.LoadConfig", type(Library.LoadConfig) == "function")
    need("Library.RegisterTheme", type(Library.RegisterTheme) == "function")
    need("Library.RegisterSkin", type(Library.RegisterSkin) == "function")
    need("Library.Skins", type(Library.Skins) == "table")
    need("Library.RegisterElement", type(Library.RegisterElement) == "function")
    need("Library:PlaySound", type(Library.PlaySound) == "function")
    need("Library:_wrapElement", type(Library._wrapElement) == "function")
    need("window:CreateTab", type(Library.WindowMethods.CreateTab) == "function")
    need("window:Notify", type(Library.WindowMethods.Notify) == "function")
    need("window:SetTheme", type(Library.WindowMethods.SetTheme) == "function")
    need("window:SetSkin", type(Library.WindowMethods.SetSkin) == "function")
    need("tab:CreateSection", type(Library.TabMethods.CreateSection) == "function")
    need("tab:CreateToggle", type(Library.TabMethods.CreateToggle) == "function")
    need("tab:CreateButton", type(Library.TabMethods.CreateButton) == "function")
    need("tab:CreateSlider", type(Library.TabMethods.CreateSlider) == "function")
    need("tab:CreateDropdown", type(Library.TabMethods.CreateDropdown) == "function")
    need("tab:CreateColorPicker", type(Library.TabMethods.CreateColorPicker) == "function")
    need("tab:CreateTextbox", type(Library.TabMethods.CreateTextbox) == "function")
    need("tab:CreateKeybind", type(Library.TabMethods.CreateKeybind) == "function")
    need("tab:CreateNotificationCenter", type(Library.TabMethods.CreateNotificationCenter) == "function")
    need("tab:CreateThemeEditor", type(Library.TabMethods.CreateThemeEditor) == "function")
    need("tab:CreatePluginManager", type(Library.TabMethods.CreatePluginManager) == "function")
    need("Cornelius global", type(Cornelius) == "table" and Cornelius.HandleCommand ~= nil)

    if #missing > 0 then
        error("CornUi v1.9.4d (modular) failed to assemble the verbatim API surface:\n  - "
            .. table.concat(missing, "\n  - "))
    end

    -- Cornelius ships as a global in v1.9.4d; mirror it on the facade.
    Library.Cornelius = Cornelius

    return { bridged = true }
end
