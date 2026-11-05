--!strict
-- "Odds" details for anything that boosts casting Luck and costs Robux (the 2x Luck pass, Lucky
-- Casting, the Spotlight Owl): the tier chances now next to the chances with the boost, worked out
-- with Actors.tierChances like the server's roll, before the player buys. One modal panel, built on
-- first use. Roblox requires the odds of paid random items to be shown before purchase.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton, makeTitle = UiKit.makeLabel, UiKit.makeButton, UiKit.makeTitle

local LuckDetails = {}

local ROUNDING_NOTE = "Probabilities are rounded; total of displayed individual probabilities may not equal 100%."

local built: { panel: Frame, show: (title: string, multiplier: number, note: string?) -> () }? = nil

local function build(gui: ScreenGui)
	local player = Players.LocalPlayer
	local panel, list, header = UiKit.makePanel(gui, "LuckDetailsPanel", "Luck odds", 116, true, nil, UiKit.TEAL)
	UiKit.panelIcon(panel, header, "clover")
	UiKit.addExclusive(panel) -- other panels close it, like the screens it opens from
	local tabRow = Instance.new("Frame")
	tabRow.Name = "LuckTabs" -- not "Agencies": makePanel would shrink those tabs below 44 px
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(10, 58)
	tabRow.Size = UDim2.new(1, -20, 0, 44)
	tabRow.Parent = panel

	local agencyId = "Open"
	local title, multiplier, note = "", 1, nil :: string?
	local render: () -> ()
	local tabs: { [string]: TextButton } = {}
	local tabList: { TextButton } = {}
	for slot, agency in Actors.Agencies do
		local button = makeButton(tabRow, agency.name, UiKit.TAB_OFF, UDim2.new(0.32, 0, 1, 0), UDim2.new((slot - 1) * 0.34, 0, 0, 0))
		tabs[agency.id] = button
		table.insert(tabList, button)
		button.Activated:Connect(function()
			agencyId = agency.id
			render()
		end)
	end
	UiKit.evenText(tabList, 24)

	local function textRow(order: number, text: string, color: Color3, height: number)
		local row = UiKit.addRow(list, order, height)
		UiKit.plainRow(row)
		local label = makeLabel(row, text, color, UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4))
		label.TextWrapped = true
		UiKit.textConstraint(label, 18)
	end

	render = function()
		UiKit.clear(list)
		for id, button in tabs do
			UiKit.styleTab(button, id == agencyId)
		end
		local agency = Actors.getAgency(agencyId) or Actors.Agencies[1]
		local luck = player:GetAttribute("Luck") or Config.BaseLuck
		local now = Actors.tierChances(luck, agency.minTier)
		local boosted = Actors.tierChances(luck * multiplier, agency.minTier)
		local order = 1
		textRow(order, `{title}: your Luck x{string.format("%.2f", luck)} becomes x{string.format("%.2f", luck * multiplier)}`, UiKit.GOLD, 52)
		for tierIndex = #Actors.Tiers, 1, -1 do
			local tier = Actors.Tiers[tierIndex]
			if boosted[tier.id] > 0 or now[tier.id] > 0 then
				order += 1
				local row = UiKit.addRow(list, order, 62)
				local name = makeTitle(row, tier.name, tier.color, UDim2.new(0.34, 0, 0, 30), UDim2.fromOffset(10, 3))
				local outline = row:FindFirstChild("Outline") :: UIStroke
				outline.Color = tier.color
				name.TextXAlignment = Enum.TextXAlignment.Left
				UiKit.textConstraint(name, 24)
				local withIt = makeLabel(row, Actors.percent(boosted[tier.id]), UiKit.CASH_GREEN, UDim2.new(0.66, -10, 0, 30), UDim2.new(0.34, 0, 0, 3))
				withIt.TextXAlignment = Enum.TextXAlignment.Right
				local current = makeLabel(row, `Now: {Actors.percent(now[tier.id])}`, UiKit.MUTED, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 35))
				current.TextXAlignment = Enum.TextXAlignment.Right
				UiKit.textConstraint(current, 16)
			end
		end
		-- Variants are rolled apart from the actor, so they get the same now / boosted pair.
		order += 1
		textRow(order, "Variants are rolled separately for every actor", UiKit.GOLD, 34)
		local variantsNow, variantsBoosted = Actors.variantChances(luck), Actors.variantChances(luck * multiplier)
		for _, variant in Actors.Variants do
			order += 1
			local row = UiKit.addRow(list, order, 62)
			local name = makeTitle(row, variant.name, variant.color, UDim2.new(0.5, 0, 0, 30), UDim2.fromOffset(10, 3))
			name.TextXAlignment = Enum.TextXAlignment.Left
			UiKit.textConstraint(name, 22)
			local withIt = makeLabel(row, Actors.percent(variantsBoosted[variant.id]), UiKit.CASH_GREEN, UDim2.new(0.5, -10, 0, 30), UDim2.new(0.5, 0, 0, 3))
			withIt.TextXAlignment = Enum.TextXAlignment.Right
			local current = makeLabel(row, `Now: {Actors.percent(variantsNow[variant.id])}`, UiKit.MUTED, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 35))
			current.TextXAlignment = Enum.TextXAlignment.Right
			UiKit.textConstraint(current, 16)
		end
		if note ~= nil then
			order += 1
			textRow(order, note, UiKit.MUTED, 56)
		end
		order += 1
		textRow(order, `Luck only changes the odds; it never guarantees a pull. {ROUNDING_NOTE}`, UiKit.MUTED, 82)
	end

	built = {
		panel = panel,
		show = function(newTitle, newMultiplier, newNote)
			title, multiplier, note = newTitle, newMultiplier, newNote
			-- Start on the best agency the player's Fame has unlocked.
			agencyId = "Open"
			for _, agency in Actors.Agencies do
				if (player:GetAttribute("Fame") or 0) >= agency.fame then
					agencyId = agency.id
				end
			end
			render()
			panel.Visible = true
		end,
	}
end

-- Opens the table for a boost that multiplies casting Luck by `multiplier` (1 when it changes
-- nothing right now). `note` is one short extra line (how long it lasts, when it starts).
function LuckDetails.open(gui: ScreenGui, title: string, multiplier: number, note: string?)
	if built == nil then
		build(gui)
	end
	if built ~= nil then
		built.show(title, multiplier, note)
	end
end

-- A small "Odds" button (44 px tall) for the top-right corner of a card that sells a Luck boost.
function LuckDetails.cornerButton(card: GuiObject, onActivated: () -> ()): TextButton
	local button = makeButton(card, "Odds", UiKit.BLUE, UDim2.fromOffset(64, 44), UDim2.new(1, -70, 0, 6))
	button.Name = "OddsButton"
	button.ZIndex = 6
	UiKit.textConstraint(button, 20)
	button.Activated:Connect(onActivated)
	return button
end

return LuckDetails
