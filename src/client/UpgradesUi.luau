--!strict
-- Upgrades screen: spend Cash on stages, cinema size, offline earnings, Luck, and the clapperboard.
-- Shows what each level gives (from the shared Upgrades definitions); the server prices, gates and
-- applies every purchase.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton = UiKit.makeLabel, UiKit.makeButton

local UpgradesUi = {}

function UpgradesUi.start(gui: ScreenGui, upgradesButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[UpgradesUi] Remotes folder never arrived")
		return
	end
	local buyUpgrade = remotes:WaitForChild("BuyUpgrade") :: RemoteEvent

	local panel, list = UiKit.makePanel(gui, "UpgradesPanel", "Upgrades")

	local function build()
		UiKit.clear(list)
		local stats = ClientState.stats()
		local cash = player:GetAttribute("Cash") or 0
		local fame = player:GetAttribute("Fame") or 0
		local order = 0

		-- Current effective stats at a glance.
		order += 1
		local summary = UiKit.addRow(list, order, 64)
		local rate = if ClientState.studio ~= nil then ClientState.studio.rate else Config.CinemaIncomePerSecond
		makeLabel(summary, `Luck x{string.format("%.2f", Upgrades.luck(stats))}  -  Fame {Hud.comma(fame)}`, UiKit.GOLD, UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 4))
		makeLabel(summary, `Royalties ${string.format("%.2f", rate)}/s  -  offline cap {Upgrades.offlineCap(stats) / 3600}h`, UiKit.MUTED, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 36))

		for _, upgrade in Upgrades.List do
			order += 1
			local level = Upgrades.level(stats, upgrade.id)
			local maxed = level >= upgrade.maxLevel
			local row = UiKit.addRow(list, order, 92)
			local title = makeLabel(row, `{upgrade.name}  Lv {level}/{upgrade.maxLevel}`, UiKit.WHITE, UDim2.new(0.62, 0, 0, 28), UDim2.fromOffset(10, 4))
			title.TextXAlignment = Enum.TextXAlignment.Left
			local now = makeLabel(row, upgrade.effect(level), UiKit.MUTED, UDim2.new(0.62, 0, 0, 20), UDim2.fromOffset(10, 34))
			now.TextXAlignment = Enum.TextXAlignment.Left

			if maxed then
				makeLabel(row, "MAX", UiKit.GOLD, UDim2.new(0.34, 0, 0, 44), UDim2.new(0.64, 0, 0, 24))
				continue
			end
			local nextEffect = makeLabel(row, "Next: " .. upgrade.effect(level + 1), UiKit.GREEN, UDim2.new(0.62, 0, 0, 20), UDim2.fromOffset(10, 62))
			nextEffect.TextXAlignment = Enum.TextXAlignment.Left

			local cost = upgrade.costs[level + 1]
			local needFame = upgrade.fame[level + 1]
			local locked = fame < needFame
			local affordable = cash >= cost
			local text = if locked then `Fame {Hud.comma(needFame)}` else `${Hud.comma(cost)}`
			local color = if locked then Color3.fromRGB(110, 70, 70) elseif affordable then UiKit.GREEN else Color3.fromRGB(70, 70, 80)
			local button = makeButton(row, text, color, UDim2.new(0.34, 0, 0, 44), UDim2.new(0.64, 0, 0, 24))
			button.Activated:Connect(function()
				if locked then
					UiKit.toast(gui, `Needs Fame {Hud.comma(needFame)}`)
				elseif not affordable then
					UiKit.toast(gui, "Not enough Cash")
				else
					buyUpgrade:FireServer(upgrade.id)
				end
			end)
		end
	end

	ClientState.changed:Connect(function()
		if panel.Visible then
			build()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if (name == "Cash" or name == "Fame") and panel.Visible then
			build()
		end
	end)

	upgradesButton.Activated:Connect(function()
		UiKit.togglePanel(panel, build)
	end)
end

return UpgradesUi
