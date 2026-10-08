--!strict
-- Rebirth (see Rebirth.luau): the side menu button's progress chip, the Rebirth screen and the
-- big reveal afterwards. The screen shows the price, the bonus now and after, and what starts over;
-- the server checks the price and does the reset. Reads the server's Cash and Rebirths attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Music = require(script.Parent.Music)
local Screens = require(script.Parent.Screens)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton = UiKit.makeLabel, UiKit.makeButton
local WHITE = UiKit.WHITE

local RebirthUi = {}

local FOOTER = 76 -- room under the list for the Rebirth button
local CONFIRM_GUARD = 0.4 -- a double tap can't answer "are you sure?" by accident

local REASONS: { [string]: string } = {
	cash = "Not enough Cash yet",
	maxed = "You have done every rebirth!",
	cooldown = "Slow down!",
	loading = "Still loading your data",
}

local function luckText(done: number): string
	return `+{string.format("%.1f", Rebirth.luckBonus(done))}`
end

-- `rebirthButton` is the side menu's Rebirth button.
function RebirthUi.start(gui: ScreenGui, rebirthButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[RebirthUi] Remotes folder never arrived")
		return
	end
	local rebirthRemote = remotes:WaitForChild("Rebirth") :: RemoteEvent
	local rebirthResult = remotes:WaitForChild("RebirthResult") :: RemoteEvent

	local function done(): number
		local value = player:GetAttribute("Rebirths")
		return if type(value) == "number" then value else 0
	end
	local function cash(): number
		local value = player:GetAttribute("Cash")
		return if type(value) == "number" then value else 0
	end
	local function studioName(rebirths: number): string
		return `{player.DisplayName} Pictures{Rebirth.sequelSuffix(rebirths)}`
	end

	-- Screen: built once and updated in place, so its 3D pictures never redraw blank. -------------
	local panel, list, header = UiKit.makePanel(gui, "RebirthPanel", "Rebirth", nil, nil, FOOTER, UiKit.PURPLE)
	UiKit.panelIcon(panel, header, "rebirth")

	local function rowText(row: Frame, y: number, height: number, color: Color3, maxSize: number, title: boolean?): TextLabel
		local label = if title
			then UiKit.makeTitle(row, "", color, UDim2.new(1, -88, 0, height), UDim2.fromOffset(80, y))
			else makeLabel(row, "", color, UDim2.new(1, -88, 0, height), UDim2.fromOffset(80, y))
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		UiKit.textConstraint(label, maxSize)
		return label
	end

	-- What a rebirth is, and the studio's next name.
	local intro = UiKit.addRow(list, 1, 84)
	UiKit.rowIcon(intro, "clapper", 62)
	local introTitle = rowText(intro, 6, 32, WHITE, 28, true)
	local introText = rowText(intro, 42, 36, UiKit.MUTED, 17)

	-- The bonus: what it is now and after this rebirth.
	local bonus = UiKit.addRow(list, 2, 96)
	UiKit.rowIcon(bonus, "moneybag", 62)
	local bonusTitle = rowText(bonus, 6, 26, WHITE, 22, true)
	local cashLine = rowText(bonus, 36, 26, UiKit.CASH_GREEN, 22, true)
	local luckLine = rowText(bonus, 64, 24, UiKit.GOLD, 20, true)

	-- The price and how close the player is.
	local price = UiKit.addRow(list, 3, 96)
	UiKit.rowIcon(price, "coin", 62)
	local priceTitle = rowText(price, 6, 30, UiKit.GOLD, 26, true)
	local bar = Instance.new("Frame")
	bar.Name = "Progress"
	bar.BackgroundColor3 = UiKit.DARK
	bar.Position = UDim2.fromOffset(80, 42)
	bar.Size = UDim2.new(1, -92, 0, 16)
	bar.Parent = price
	UiKit.corner(bar, 8)
	UiKit.border(bar, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = UiKit.PURPLE
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar
	UiKit.corner(fill, 8)
	local priceText = rowText(price, 64, 24, UiKit.MUTED, 18)

	-- What stays and what starts over.
	local keep = UiKit.addRow(list, 4, 92)
	local tickHolder = Instance.new("Frame")
	tickHolder.Name = "Icon"
	tickHolder.BackgroundTransparency = 1
	tickHolder.AnchorPoint = Vector2.new(0, 0.5)
	tickHolder.Position = UDim2.new(0, 8, 0.5, 0)
	tickHolder.Size = UDim2.fromOffset(62, 62)
	tickHolder.Parent = keep
	UiKit.tick(tickHolder, keep.ZIndex + 1)
	local keepTitle = rowText(keep, 6, 26, UiKit.FRESH_GREEN, 22, true)
	keepTitle.Text = "You keep"
	local keepText = rowText(keep, 34, 52, WHITE, 17)
	keepText.Text = "Every actor, the Index, Fame and what it unlocks, scripts, your cinema's movies, films still filming, and everything from the Shop"

	local reset = UiKit.addRow(list, 5, 84)
	UiKit.rowIcon(reset, "arrow", 62)
	local resetTitle = rowText(reset, 6, 26, UiKit.WARN, 22, true)
	resetTitle.Text = "Starts over"
	local resetText = rowText(reset, 34, 44, WHITE, 17)

	-- Footer: the big button, and the "are you sure?" pair that replaces it for a moment.
	-- 12px margins and gaps; `left` and `width` are shares of the panel's width.
	local function footerButton(name: string, text: string, color: Color3, left: number, width: number): TextButton
		local x = if left > 0 then 6 else 12
		local w = if width < 1 then -18 else -24
		local b = makeButton(panel, text, color, UDim2.new(width, w, 0, 54), UDim2.new(left, x, 1, -(FOOTER - 10)))
		b.Name = name
		UiKit.textConstraint(b, 28)
		return b
	end
	local go = footerButton("RebirthGo", "REBIRTH!", UiKit.GREEN, 0, 1)
	local yes = footerButton("RebirthYes", "Yes, start over!", UiKit.GREEN, 0, 0.62)
	local no = footerButton("RebirthNo", "Cancel", UiKit.CLOSE_RED, 0.62, 0.38)
	yes.Visible = false
	no.Visible = false

	-- The "are you sure?" step stays until it is answered or the screen closes: no timer, so a slow
	-- reader (or a Studio playtest) never finds the Yes button gone.
	local confirming = false
	local confirmShownAt = 0
	local waiting = false -- asked the server, no answer yet

	local function setConfirming(on: boolean)
		confirming = on
		go.Visible = not on
		yes.Visible = on
		no.Visible = on
		if on then
			confirmShownAt = os.clock()
		end
	end

	-- Chip on the menu button and, when the screen is open, every number on it.
	local function update()
		local n = done()
		local cost = Rebirth.cost(n)
		local money = cash()
		local ready = cost ~= nil and money >= cost

		if cost == nil then
			UiKit.chip(rebirthButton, "MAX")
		elseif ready then
			UiKit.chip(rebirthButton, "READY!")
		else
			UiKit.chip(rebirthButton, `{math.floor(Rebirth.progress(money, n) * 100)}%`)
		end
		local chip = rebirthButton:FindFirstChild("Chip")
		if chip ~= nil and chip:IsA("TextLabel") then
			chip.BackgroundColor3 = if ready then UiKit.AWARD_GOLD else UiKit.GREEN
		end

		if not panel.Visible then
			return
		end
		if cost == nil then
			introTitle.Text = "Every rebirth done!"
			introText.Text = `{studioName(n)} has made all {Rebirth.Max} sequels.`
			bonusTitle.Text = "Your bonus, forever"
			cashLine.Text = `Movie Cash {Rebirth.multiplierText(n)}`
			luckLine.Text = `Luck {luckText(n)}`
			priceTitle.Text = "No more rebirths"
			priceText.Text = "You beat the sequel ladder!"
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = UiKit.AWARD_GOLD
			resetText.Text = "Nothing: there are no more rebirths."
			go.Text = "MAXED"
			UiKit.setEnabled(go, false, UiKit.GREEN)
			if confirming then
				setConfirming(false)
			end
			return
		end
		introTitle.Text = if n == 0 then "Make a sequel!" else `Make sequel number {n + 1}!`
		introText.Text = `Start your studio over as {studioName(n + 1)}, with a bigger bonus that lasts forever.`
		bonusTitle.Text = if n == 0 then "Bonus after this rebirth" else `Bonus after rebirth {n + 1}`
		cashLine.Text = `Movie Cash {Rebirth.multiplierText(n + 1)}   (now {Rebirth.multiplierText(n)})`
		luckLine.Text = `Luck {luckText(n + 1)}   (now {luckText(n)})`
		priceTitle.Text = `Costs ${Hud.comma(cost)}`
		local progress = Rebirth.progress(money, n)
		fill.Size = UDim2.fromScale(progress, 1)
		fill.BackgroundColor3 = if ready then UiKit.GREEN else UiKit.PURPLE
		priceText.Text = if ready
			then "Ready! You can afford it."
			else `${Hud.comma(money)} of ${Hud.comma(cost)}  ({math.floor(progress * 100)}%)`
		resetText.Text = `Your Cash, and every upgrade (sound stages too). You start again with ${Hud.comma(Config.StartingCash)} plus your waiting box office.`
		go.Text = if ready then "REBIRTH!" else `Need ${Hud.comma(cost - money)} more`
		UiKit.setEnabled(go, ready, UiKit.GREEN)
		if confirming and not ready then
			setConfirming(false)
		end
	end

	go.Activated:Connect(function()
		local cost = Rebirth.cost(done())
		if cost == nil then
			UiKit.toast(gui, REASONS.maxed)
		elseif cash() < cost then
			UiKit.toast(gui, "Save up more Cash first")
		else
			setConfirming(true)
		end
	end)
	no.Activated:Connect(function()
		setConfirming(false)
	end)
	yes.Activated:Connect(function()
		if os.clock() - confirmShownAt < CONFIRM_GUARD or waiting then
			return
		end
		setConfirming(false)
		waiting = true
		rebirthRemote:FireServer()
		-- Never leave the button dead if the answer gets lost.
		task.delay(5, function()
			waiting = false
		end)
	end)

	-- Reveal: a big card with the new studio name and bonus. ----------------------------------
	local overlay = Instance.new("Frame")
	overlay.Name = "RebirthReveal"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiKit.DARK
	overlay.BackgroundTransparency = 0.25
	overlay.Active = true -- swallows taps so the world is not clicked through
	overlay.Visible = false
	overlay.ZIndex = 12
	overlay.Parent = gui
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.52)
	card.Size = UDim2.fromScale(0.85, 0.62)
	card.BackgroundColor3 = UiKit.PANEL
	card.ZIndex = 13
	card.Parent = overlay
	UiKit.corner(card, 20)
	local cardLimit = Instance.new("UISizeConstraint")
	cardLimit.MaxSize = Vector2.new(440, 480)
	cardLimit.Parent = card
	local cardStroke = UiKit.border(card, 6, UiKit.PURPLE)

	local function cardLabel(y: number, h: number, size: number, color: Color3): TextLabel
		local label = UiKit.makeTitle(card, "", color, UDim2.new(0.9, 0, h, 0), UDim2.new(0.05, 0, y, 0), if size >= 30 then 3 else 2)
		label.ZIndex = 14
		UiKit.textConstraint(label, size)
		return label
	end
	local revealTitle = cardLabel(0.2, 0.16, 46, UiKit.GOLD)
	local revealName = cardLabel(0.37, 0.11, 30, WHITE)
	local revealCash = cardLabel(0.5, 0.1, 28, UiKit.CASH_GREEN)
	local revealLuck = cardLabel(0.6, 0.08, 22, UiKit.GOLD)
	local revealNote = cardLabel(0.69, 0.08, 18, UiKit.MUTED)
	local letsGo = makeButton(card, "Let's go!", UiKit.GREEN, UDim2.fromScale(0.6, 0.14), UDim2.fromScale(0.2, 0.81))
	letsGo.ZIndex = 14

	-- The rebirth icon spins on top of the card, with slow light rays behind it.
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.75)
	art.Position = UDim2.fromScale(0.5, 0)
	art.Size = UDim2.fromScale(0.42, 0.42)
	art.ZIndex = 15
	art.Parent = card
	local artAspect = Instance.new("UIAspectRatioConstraint")
	artAspect.Parent = art
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.42)
	rays.Size = UDim2.fromScale(1.3, 1.3)
	rays.ZIndex = 12
	rays.Parent = overlay
	local raysAspect = Instance.new("UIAspectRatioConstraint")
	raysAspect.Parent = rays
	local rayBars: { Frame } = {}
	for i = 1, 6 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(0.09, 1)
		ray.BackgroundColor3 = UiKit.PURPLE
		ray.BackgroundTransparency = 0.45
		ray.BorderSizePixel = 0
		ray.ZIndex = 12
		ray.Parent = rays
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		rayBars[i] = ray
	end
	RunService.RenderStepped:Connect(function()
		if overlay.Visible then
			local angle = os.clock() * 12
			for i, ray in rayBars do
				ray.Rotation = angle + i * 30
			end
		end
	end)

	local stopSpin: (() -> ())? = nil
	local function hideReveal()
		overlay.Visible = false
		if stopSpin ~= nil then
			stopSpin()
			stopSpin = nil
		end
		art:ClearAllChildren()
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = art
	end
	letsGo.Activated:Connect(hideReveal)

	local function showReveal(n: number, banked: number)
		hideReveal()
		UiKit.closePanels()
		revealTitle.Text = `REBIRTH {n}!`
		revealName.Text = studioName(n)
		revealCash.Text = `Movie Cash {Rebirth.multiplierText(n)} forever`
		revealLuck.Text = `Luck {luckText(n)}`
		revealNote.Text = if banked > 0
			then `Your box office came along: +${Hud.comma(banked)}`
			else "Rebuy your upgrades and roll some stars!"
		cardStroke.Color = UiKit.PURPLE
		overlay.Visible = true
		stopSpin = Icon3D.spin(Icon3D.outlined(art, "rebirth"), 30)
		Music.duck(4)
		Sfx.play("rebirthSting")
		Sfx.play("rebirth")
		Fx.flash(UiKit.PURPLE, 0.5)
		Fx.confetti(140)
	end

	rebirthResult.OnClientEvent:Connect(function(result)
		waiting = false
		if type(result) ~= "table" then
			return
		end
		if result.ok == true and type(result.rebirths) == "number" then
			showReveal(result.rebirths, if type(result.banked) == "number" then result.banked else 0)
		else
			UiKit.toast(gui, REASONS[result.reason] or "That didn't work")
		end
		update()
	end)

	player.AttributeChanged:Connect(function(name)
		if name == "Cash" or name == "Rebirths" then
			update()
		end
	end)

	-- togglePanel builds before it shows the panel, so the numbers are filled in just after.
	local function open()
		setConfirming(false)
	end
	rebirthButton.Activated:Connect(function()
		UiKit.togglePanel(panel, open)
		update()
	end)
	Screens.register("Rebirth", function()
		if not panel.Visible then
			UiKit.togglePanel(panel, open)
			update()
		end
	end)
	update()
end

return RebirthUi
