--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local CastingUi = require(script.Parent.CastingUi)
local ClientState = require(script.Parent.ClientState)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Music = require(script.Parent.Music)
local RebirthUi = require(script.Parent.RebirthUi)
local RewardsUi = require(script.Parent.RewardsUi)
local Sfx = require(script.Parent.Sfx)
local ShopUi = require(script.Parent.ShopUi)
local SideMenu = require(script.Parent.SideMenu)
local SoundSettingsUi = require(script.Parent.SoundSettingsUi)
local Stands = require(script.Parent.Stands)
local StudioUi = require(script.Parent.StudioUi)
local Tutorial = require(script.Parent.Tutorial)
local UpgradesUi = require(script.Parent.UpgradesUi)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Startup guard: a duplicated client script must not build the UI twice.
if playerGui:FindFirstChild("MovieMogulUI") then
	warn(`[MovieMogul] duplicate client Main ignored ({script:GetFullName()}); remove the extra copy`)
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "MovieMogulUI"
gui.ResetOnSpawn = false
-- Sibling ordering: a panel's children always draw above the panel itself, whatever their ZIndex.
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = playerGui

Sfx.start()
Music.start()
local side = SideMenu.start(gui)
local cashPlus = Hud.start(gui, side.wallet)

local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if remotes ~= nil then
	-- State first, so every screen sees synced data from its first frame.
	ClientState.start(remotes)
	Fx.start(remotes)
	CastingUi.start(gui, side.actors)
	StudioUi.start(gui, side.studio)
	UpgradesUi.start(gui, side.upgrade)
	RebirthUi.start(gui, side.rebirth)
	ShopUi.start(gui, side.shop, cashPlus)
	RewardsUi.start(gui, side.rewards, side.codes)
	Stands.start()
	SoundSettingsUi.start(gui, remotes)
	Tutorial.start(gui, remotes)
else
	warn("[MovieMogul] Remotes folder never arrived")
end

-- VIP chat tag. The server sets PassVIP on players who own the pass; this only decorates text.
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	if source then
		local speaker = Players:GetPlayerByUserId(source.UserId)
		if speaker ~= nil and speaker:GetAttribute("PassVIP") then
			properties.PrefixText = `<font color="#FFCD46">[VIP]</font> {message.PrefixText}`
		end
	end
	return properties
end
