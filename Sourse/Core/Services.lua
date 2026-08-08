-- ============================================================
-- CORNUI CORE SERVICES
-- Extracted from CornUi v1.9.3
-- ============================================================

local Services = {}

-- Roblox Services
Services.UserInputService = game:GetService("UserInputService")
Services.TweenService = game:GetService("TweenService")
Services.Players = game:GetService("Players")
Services.RunService = game:GetService("RunService")
Services.HttpService = game:GetService("HttpService")
Services.Stats = game:GetService("Stats")
Services.GuiService = game:GetService("GuiService")
Services.MarketplaceService = game:GetService("MarketplaceService")
Services.ContextActionService = game:GetService("ContextActionService")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.TeleportService = game:GetService("TeleportService")
Services.ProximityPromptService = game:GetService("ProximityPromptService")

-- Player references
Services.LocalPlayer = Services.Players.LocalPlayer

Services.PlayerGui = Services.LocalPlayer
    and Services.LocalPlayer:WaitForChild("PlayerGui")

return Services
