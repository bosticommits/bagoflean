--!strict
-- Sound settings: a small speaker button (bottom right on computers, under the event line on
-- phones) opens a panel with Music and Effects volume (- / + in steps of 10%, and a mute switch).
-- Changes apply at once; the server saves them with the player's data (SoundSettingsService), and
-- they come back as the MusicVolume and SfxVolume attributes on the next join.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Music = require(script.Parent.Music)
local Screens = require(script.Parent.Screens)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local SAVE_DELAY = 0.6 -- batch quick taps into one save

local SoundSettingsUi = {}

function SoundSettingsUi.start(gui: ScreenGui, remotes: Instance)
	local player = Players.LocalPlayer
	local remote = remotes:WaitForChild("SoundSettings", 10)
	local saveRemote: RemoteEvent? = if remote ~= nil and remote:IsA("RemoteEvent") then remote else nil

	local volumes = { music = Sounds.DEFAULT_MUSIC, sfx = Sounds.DEFAULT_SFX }
	-- The level a mute switch goes back to.
	local unmuted = { music = Sounds.DEFAULT_MUSIC, sfx = Sounds.DEFAULT_SFX }
	local saveToken = 0
	local pendingSave = false

	local button = UiKit.makeButton(gui, "🔊", UiKit.NAVY, UDim2.fromOffset(48, 48))
	button.Name = "SoundButton"
	UiKit.textConstraint(button, 30)
	local function place()
		if UserInputService.TouchEnabled then
			-- Phones: the thumbstick is bottom left and jump bottom right; the event line is top right.
			button.AnchorPoint = Vector2.new(1, 0)
			button.Position = UDim2.new(1, -12, 0, if UiKit.isCompact() then 66 else 86)
		else
			button.AnchorPoint = Vector2.new(1, 1)
			button.Position = UDim2.new(1, -16, 1, -16)
		end
	end
	UiKit.onViewportChanged(place)
	place()

	local panel, list = UiKit.makePanel(gui, "SoundPanel", "Sound", nil, nil, nil, UiKit.BLUE)

	local function apply()
		Music.setVolume(volumes.music)
		Sfx.setVolume(volumes.sfx)
		button.Text = if volumes.music <= 0 and volumes.sfx <= 0 then "🔇" else "🔊"
	end

	local function save()
		saveToken += 1
		local mine = saveToken
		pendingSave = true
		task.delay(SAVE_DELAY, function()
			if mine ~= saveToken then
				return
			end
			pendingSave = false
			if saveRemote ~= nil then
				saveRemote:FireServer(volumes.music, volumes.sfx)
			end
		end)
	end

	-- The rows are built once and updated in place, so pressing a button never flickers.
	local refreshers: { () -> () } = {}
	local function build()
		for _, refresh in refreshers do
			refresh()
		end
	end

	local function set(key: string, value: number)
		local clean = Sounds.cleanVolume(value, 0)
		if key == "music" then
			volumes.music = clean
		else
			volumes.sfx = clean
		end
		if clean > 0 then
			unmuted[key] = clean
		end
		apply()
		save()
		build()
		Sfx.play("click") -- at the new Effects level
	end

	local ROW = 80
	local function volumeRow(order: number, key: string, title: string)
		local function value(): number
			return if key == "music" then volumes.music else volumes.sfx
		end
		local row = UiKit.addRow(list, order, ROW)
		local name = UiKit.makeTitle(row, title, UiKit.WHITE, UDim2.new(0.27, -16, 0, 40), UDim2.fromOffset(12, 20))
		name.TextXAlignment = Enum.TextXAlignment.Left

		local minus = UiKit.makeButton(row, "-", UiKit.BLUE, UDim2.fromOffset(44, 44), UDim2.new(0.27, 0, 0, 18))
		minus:SetAttribute("Silent", true)
		minus.Activated:Connect(function()
			set(key, value() - 1 / Sounds.STEPS)
		end)
		local amount = UiKit.makeTitle(row, "", UiKit.GOLD, UDim2.fromOffset(76, 40), UDim2.new(0.27, 48, 0, 20))
		amount.Name = "Amount"
		local plus = UiKit.makeButton(row, "+", UiKit.BLUE, UDim2.fromOffset(44, 44), UDim2.new(0.27, 128, 0, 18))
		plus:SetAttribute("Silent", true)
		plus.Activated:Connect(function()
			set(key, value() + 1 / Sounds.STEPS)
		end)
		local toggle = UiKit.makeButton(row, "", UiKit.GREEN, UDim2.new(0.73, -196, 0, 44), UDim2.new(0.27, 184, 0, 18))
		toggle:SetAttribute("Silent", true)
		toggle.Activated:Connect(function()
			set(key, if value() <= 0 then unmuted[key] else 0)
		end)

		table.insert(refreshers, function()
			local v = value()
			amount.Text = `{math.floor(v * 100 + 0.5)}%`
			amount.TextColor3 = if v > 0 then UiKit.GOLD else UiKit.FAINT
			toggle.Text = if v > 0 then "ON" else "OFF"
			toggle.BackgroundColor3 = if v > 0 then UiKit.GREEN else UiKit.DISABLED
		end)
	end

	volumeRow(1, "music", "Music")
	volumeRow(2, "sfx", "Effects")
	build()
	-- Only two rows: cap the window's height so it fits them instead of standing mostly empty.
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit ~= nil then
		limit.MaxSize = Vector2.new(limit.MaxSize.X, 60 + 2 * (ROW + 8) + 30)
	end

	-- Saved settings arrive with the player's data; a change still waiting to save wins.
	local function load()
		local music, sfx = player:GetAttribute("MusicVolume"), player:GetAttribute("SfxVolume")
		if pendingSave or music == nil or sfx == nil then
			return
		end
		volumes.music = Sounds.cleanVolume(music, Sounds.DEFAULT_MUSIC)
		volumes.sfx = Sounds.cleanVolume(sfx, Sounds.DEFAULT_SFX)
		if volumes.music > 0 then
			unmuted.music = volumes.music
		end
		if volumes.sfx > 0 then
			unmuted.sfx = volumes.sfx
		end
		apply()
		if panel.Visible then
			build()
		end
	end
	player:GetAttributeChangedSignal("MusicVolume"):Connect(load)
	player:GetAttributeChangedSignal("SfxVolume"):Connect(load)
	load()

	button.Activated:Connect(function()
		UiKit.togglePanel(panel, build)
	end)
	Screens.register("Sound", function()
		if not panel.Visible then
			UiKit.togglePanel(panel, build)
		end
	end)
end

return SoundSettingsUi
