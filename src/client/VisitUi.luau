--!strict
-- Studio visits (rules in Shared/Visits, checks in src/server/VisitService). This file shows them:
--   * the Visit screen: every studio on the server with its owner, applause, Masterpieces, top star
--     and what it is filming, and a VISIT button that jumps you to its gate (GO HOME for your own);
--   * the tour card, on the right while you stand on someone else's studio, with the APPLAUD button;
--   * applause in the world: clapping hands over whoever applauds, "+1" over the studio's gate;
--   * premieres seen from the studio you are visiting, and the owner's notices ("Ava is touring
--     your studio!").
-- The server decides everything (who is touring, whether applause counts); the remotes carry only
-- which lot to jump to.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local LotModels = require(ReplicatedStorage.Shared.Models.LotModels)
local Movies = require(ReplicatedStorage.Shared.Movies)
local Visits = require(ReplicatedStorage.Shared.Visits)
local Fx = require(script.Parent.Fx)
local Screens = require(script.Parent.Screens)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeTitle, makeButton = UiKit.makeLabel, UiKit.makeTitle, UiKit.makeButton

local VisitUi = {}

local CARD_WIDTH = 260
local CARD_HEIGHT = 178
local PREMIERE_SHOW_SECONDS = 7
local HEAR_DISTANCE = 140 -- applause is heard this close to the studio

type Studio = {
	index: number,
	ownerId: number,
	name: string,
	likes: number,
	trophies: number,
	topStar: string?,
	topTier: string?,
	nextPremiere: number?,
	spotlight: boolean,
}

local bases: { CFrame } = {}
for index = 1, Config.LotCount do
	bases[index] = MapModels.lotBase(index)
end

local function lotModel(index: number): Model?
	local lots = workspace:FindFirstChild("Lots")
	local model = if lots ~= nil then lots:FindFirstChild("Lot" .. index) else nil
	return if model ~= nil and model:IsA("Model") then model else nil
end

local function number(value: any): number
	return if type(value) == "number" then value else 0
end

-- The lot the Spotlight special event is shining on, if one is live.
local function spotlightLot(): number?
	local raw = ReplicatedStorage:GetAttribute("SpecialEvent")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, event = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if ok and type(event) == "table" and event.id == "Spotlight" and type(event.lot) == "number" then
		return event.lot
	end
	return nil
end

-- Every claimed studio, read from the lots' attributes (LotService and VisitService keep them).
local function studios(): { Studio }
	local spot = spotlightLot()
	local list: { Studio } = {}
	for index = 1, Config.LotCount do
		local model = lotModel(index)
		local ownerId = if model ~= nil then model:GetAttribute("OwnerUserId") else nil
		if model ~= nil and type(ownerId) == "number" then
			local name = model:GetAttribute("StudioName")
			local star = model:GetAttribute("TopStar")
			local tier = model:GetAttribute("TopStarTier")
			local nextPremiere = model:GetAttribute("NextPremiere")
			table.insert(list, {
				index = index,
				ownerId = ownerId,
				name = if type(name) == "string" then name else "STUDIO",
				likes = number(model:GetAttribute("Likes")),
				trophies = number(model:GetAttribute("Trophies")),
				topStar = if type(star) == "string" then star else nil,
				topTier = if type(tier) == "string" then tier else nil,
				nextPremiere = if type(nextPremiere) == "number" then nextPremiere else nil,
				spotlight = spot == index,
			})
		end
	end
	return list
end

local function root(): BasePart?
	local character = Players.LocalPlayer.Character
	local part = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if part ~= nil and part:IsA("BasePart") then part else nil
end

-- The lot the local player stands on (`margin` widens each lot), or nil.
local function standingOn(margin: number?): number?
	local part = root()
	return if part ~= nil then Visits.lotAt(part.Position, bases, margin) else nil
end

local function myLot(): number?
	local index = Players.LocalPlayer:GetAttribute("LotIndex")
	-- The attribute outlives a released lot, so check the lot still names us as its owner.
	if type(index) == "number" then
		local model = lotModel(index)
		if model ~= nil and model:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			return index
		end
	end
	return nil
end

-- Round owner headshots, fetched once per player.
local headshots: { [number]: string } = {}
local function headshot(image: ImageLabel, userId: number)
	local cached = headshots[userId]
	if cached ~= nil then
		image.Image = cached
		return
	end
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and type(content) == "string" then
			headshots[userId] = content
			if image.Parent ~= nil then
				image.Image = content
			end
		end
	end)
end

local function statusColor(kind: string): Color3
	if kind == "ready" then
		return UiKit.GOLD
	elseif kind == "filming" then
		return UiKit.BLUE:Lerp(UiKit.WHITE, 0.35)
	end
	return UiKit.FAINT
end

-- Hands that rise and fade over a character's head (applause, seen by everyone near).
local function handsOver(character: Model?, count: number)
	local head = if character ~= nil then character:FindFirstChild("Head") else nil
	if head == nil or not head:IsA("BasePart") then
		return
	end
	for i = 1, count do
		task.delay((i - 1) * 0.18, function()
			if head.Parent == nil then
				return
			end
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(2.2, 2.2) -- studs
			gui.StudsOffsetWorldSpace = Vector3.new((i - (count + 1) / 2) * 1.1, 2.2, 0)
			gui.LightInfluence = 0
			gui.MaxDistance = HEAR_DISTANCE
			gui.Parent = head
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Text = "👏"
			label.TextScaled = true
			label.Font = UiKit.DISPLAY_FONT
			label.Parent = gui
			local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(gui, info, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 3.5, 0) }):Play()
			TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
			Debris:AddItem(gui, 1.2)
		end)
	end
end

-- Gold "+1" rising off a studio's applause sign when an applause counts.
local function plusOne(index: number)
	local model = lotModel(index)
	local sign = if model ~= nil then model:FindFirstChild("ApplauseSign") else nil
	if sign == nil or not sign:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(4, 2.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = HEAR_DISTANCE
	gui.Parent = sign
	local label = makeTitle(gui, "+1", UiKit.GOLD, UDim2.fromScale(1, 1))
	UiKit.textConstraint(label, 100)
	TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil then
		TweenService:Create(stroke, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	end
	Debris:AddItem(gui, 1.5)
end

local function validLot(index: any): boolean
	return type(index) == "number" and index == math.floor(index) and index >= 1 and index <= Config.LotCount
end

local function near(index: number): boolean
	local part = root()
	if part == nil then
		return false
	end
	return (part.Position - bases[index].Position).Magnitude <= HEAR_DISTANCE
end

-- `visitButton` is the side menu's Visit button.
function VisitUi.start(gui: ScreenGui, visitButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[VisitUi] Remotes folder never arrived")
		return
	end
	local visitRemote = remotes:WaitForChild("VisitStudio") :: RemoteEvent
	local applaudRemote = remotes:WaitForChild("Applaud") :: RemoteEvent
	local applauseRemote = remotes:WaitForChild("Applause") :: RemoteEvent
	local noticeRemote = remotes:WaitForChild("VisitNotice") :: RemoteEvent
	local arrivedRemote = remotes:WaitForChild("VisitArrived") :: RemoteEvent
	local premiereRemote = remotes:WaitForChild("LotPremiere") :: RemoteEvent

	-- Visit screen -------------------------------------------------------------------------------
	local panel, list, header = UiKit.makePanel(gui, "VisitPanel", "Visit a Studio", nil, nil, nil, UiKit.BLUE)
	UiKit.panelIcon(panel, header, "visit")

	local statusLabels: { [number]: TextLabel } = {} -- lot index -> its row's status text
	local shown = "" -- what the list was last built from (UiKit.signature)

	local function jump(index: number)
		visitRemote:FireServer(index)
		panel.Visible = false
	end

	local function now(): number
		return workspace:GetServerTimeNow()
	end

	local function build()
		UiKit.clear(list)
		table.clear(statusLabels)
		local all = studios()
		local mine = myLot()
		local here = standingOn()
		local order = 0

		-- Your own studio first, with the way home.
		if mine ~= nil then
			local own: Studio? = nil
			for _, studio in all do
				if studio.index == mine then
					own = studio
				end
			end
			order += 1
			local row = UiKit.addRow(list, order, 64)
			row.BackgroundColor3 = UiKit.ROW:Lerp(UiKit.BLUE, 0.25)
			local title = makeTitle(row, "Your studio", UiKit.WHITE, UDim2.new(0.6, -14, 0, 28), UDim2.fromOffset(14, 6))
			title.TextXAlignment = Enum.TextXAlignment.Left
			local likes = if own ~= nil then own.likes else 0
			local line = makeLabel(row, `{Visits.applauseText(likes)} applause from visitors`, UiKit.MUTED, UDim2.new(0.6, -14, 0, 20), UDim2.fromOffset(14, 36))
			line.TextXAlignment = Enum.TextXAlignment.Left
			if here == mine then
				makeTitle(row, "You're home", UiKit.CASH_GREEN, UDim2.new(0.36, 0, 0, 40), UDim2.new(0.62, 0, 0, 12))
			else
				local home = makeButton(row, "GO HOME", UiKit.BLUE, UDim2.new(0.36, 0, 0, 44), UDim2.new(0.62, 0, 0, 10))
				home.Activated:Connect(function()
					jump(mine)
				end)
			end
		end

		local others: { Studio } = {}
		for _, studio in all do
			if studio.index ~= mine then
				table.insert(others, studio)
			end
		end
		local t = now()
		-- The Spotlight first, then studios with a premiere about to happen, then the most applauded.
		table.sort(others, function(a, b)
			if a.spotlight ~= b.spotlight then
				return a.spotlight
			end
			local aReady = a.nextPremiere ~= nil and a.nextPremiere <= t
			local bReady = b.nextPremiere ~= nil and b.nextPremiere <= t
			if aReady ~= bReady then
				return aReady
			end
			if a.likes ~= b.likes then
				return a.likes > b.likes
			end
			return a.index < b.index
		end)

		order += 1
		local heading = UiKit.addRow(list, order, 30)
		UiKit.plainRow(heading)
		local headingText = makeTitle(heading, "Tour a studio and give it a round of applause!", UiKit.GOLD, UDim2.new(1, -8, 1, 0), UDim2.fromOffset(4, 0), 2)
		headingText.TextXAlignment = Enum.TextXAlignment.Left

		if #others == 0 then
			order += 1
			local row = UiKit.addRow(list, order, 84)
			UiKit.plainRow(row)
			makeTitle(row, "No other studios here yet", UiKit.WHITE, UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 6))
			makeLabel(row, "When someone claims a lot on this server, their studio shows up here.", UiKit.MUTED, UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 40))
		end

		for _, studio in others do
			order += 1
			local row = UiKit.addRow(list, order, 96)
			if studio.spotlight then
				local outline = row:FindFirstChild("Outline")
				if outline ~= nil and outline:IsA("UIStroke") then
					outline.Color = UiKit.PURPLE
					outline.Thickness = 3
				end
			end
			-- Owner's face in a round gold frame.
			local face = Instance.new("ImageLabel")
			face.Name = "Owner"
			face.BackgroundColor3 = UiKit.DARK
			face.Size = UDim2.fromOffset(70, 70)
			face.Position = UDim2.fromOffset(10, 13)
			face.Parent = row
			UiKit.corner(face, 35)
			UiKit.border(face, 3, UiKit.AWARD_GOLD)
			headshot(face, studio.ownerId)

			local name = makeTitle(row, studio.name, UiKit.WHITE, UDim2.new(0.62, -92, 0, 28), UDim2.fromOffset(92, 6))
			name.TextXAlignment = Enum.TextXAlignment.Left
			local stats = `{Visits.applauseText(studio.likes)}    🏆 {studio.trophies}`
			local statsLine = makeLabel(row, stats, UiKit.MUTED, UDim2.new(0.62, -92, 0, 20), UDim2.fromOffset(92, 38))
			statsLine.TextXAlignment = Enum.TextXAlignment.Left
			local starText = if studio.topStar ~= nil then `Top star: {studio.topStar}` else "No stars cast yet"
			local tier = if studio.topTier ~= nil then Actors.getTier(studio.topTier) else nil
			local star = makeLabel(row, starText, if tier ~= nil then tier.color else UiKit.FAINT, UDim2.new(0.62, -92, 0, 20), UDim2.fromOffset(92, 62))
			star.TextXAlignment = Enum.TextXAlignment.Left

			local status = Visits.status(studio.nextPremiere, t)
			local statusText = if studio.spotlight then "SPOTLIGHT: x2 Luck!" else status.text
			local statusLabel = makeTitle(row, statusText, if studio.spotlight then UiKit.PURPLE:Lerp(UiKit.WHITE, 0.3) else statusColor(status.kind), UDim2.new(0.36, 0, 0, 22), UDim2.new(0.62, 0, 0, 8), 2)
			if not studio.spotlight then
				statusLabels[studio.index] = statusLabel
			end
			local onIt = here == studio.index
			local visit = makeButton(row, if onIt then "YOU'RE HERE" else "VISIT", if onIt then UiKit.DISABLED else UiKit.GREEN, UDim2.new(0.36, 0, 0, 46), UDim2.new(0.62, 0, 0, 38))
			visit.Activated:Connect(function()
				if not onIt then
					jump(studio.index)
				end
			end)
		end
	end

	-- A short fingerprint of what the list shows, so it rebuilds only when that changes (countdowns
	-- tick in place).
	local function fingerprint(): string
		local t = now()
		local parts: { any } = {}
		for _, studio in studios() do
			table.insert(parts, {
				studio.index,
				studio.ownerId,
				studio.name,
				studio.likes,
				studio.trophies,
				studio.topStar or "",
				studio.spotlight,
				Visits.status(studio.nextPremiere, t).kind,
			} :: { any })
		end
		return UiKit.signature({ parts, myLot() or 0, standingOn() or 0 } :: { any })
	end

	local function open()
		if not panel.Visible then
			UiKit.togglePanel(panel, function()
				shown = fingerprint()
				build()
			end)
		end
	end
	visitButton.Activated:Connect(function()
		UiKit.togglePanel(panel, function()
			shown = fingerprint()
			build()
		end)
	end)
	Screens.register("Visit", open)

	-- Side menu chip: how many other studios there are to tour.
	local function updateChip()
		local mine = myLot()
		local count = 0
		for _, studio in studios() do
			if studio.index ~= mine then
				count += 1
			end
		end
		UiKit.chip(visitButton, if count > 0 then tostring(count) else nil)
	end

	-- Tour card --------------------------------------------------------------------------------
	local card = Instance.new("Frame")
	card.Name = "TourCard"
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.Position = UDim2.new(1, -14, 0.5, 0)
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	card.BackgroundColor3 = UiKit.NAVY
	card.BackgroundTransparency = 0.06
	card.Visible = false
	card.ZIndex = 0 -- under any open panel
	card.Parent = gui
	UiKit.corner(card, 16)
	UiKit.border(card, 4)
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	UiKit.onViewportChanged(function()
		cardScale.Scale = if UiKit.isCompact() then 0.78 else 1
		-- Touch screens: a little higher, clear of the jump button. Elsewhere a little lower, clear
		-- of the "Events (Studio)" test button that Studio playtests show at the right middle.
		card.Position = if UserInputService.TouchEnabled then UDim2.new(1, -14, 0.44, 0) else UDim2.new(1, -14, 0.5, 112)
	end)

	local touring = makeLabel(card, "NOW TOURING", UiKit.GOLD, UDim2.new(1, -96, 0, 16), UDim2.fromOffset(12, 12))
	touring.TextXAlignment = Enum.TextXAlignment.Left
	local cardName = makeTitle(card, "", UiKit.WHITE, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 28))
	cardName.TextXAlignment = Enum.TextXAlignment.Left
	local cardStats = makeLabel(card, "", UiKit.MUTED, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(12, 62))
	cardStats.TextXAlignment = Enum.TextXAlignment.Left
	local cardLine = makeTitle(card, "", UiKit.GOLD, UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 84), 2)
	cardLine.TextXAlignment = Enum.TextXAlignment.Left
	local applaud = makeButton(card, "👏 APPLAUD", UiKit.AWARD_GOLD, UDim2.new(1, -24, 0, 54), UDim2.fromOffset(12, 112))
	applaud.Name = "Applaud"
	applaud:SetAttribute("Silent", true) -- the clap itself makes the sound
	local applaudScale = Instance.new("UIScale")
	applaudScale.Parent = applaud
	local home = makeButton(card, "HOME", UiKit.BLUE, UDim2.fromOffset(66, 30), UDim2.new(1, -78, 0, 10))
	home.Name = "Home"
	UiKit.textConstraint(home, 18)

	local pulseTween: Tween? = nil
	local function setPulse(on: boolean)
		local tween = pulseTween
		if tween then
			if not on then
				tween:Cancel()
				pulseTween = nil
				applaudScale.Scale = 1
			end
		elseif on then
			local created = TweenService:Create(applaudScale, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.06 })
			created:Play()
			pulseTween = created
		end
	end

	local premiereUntil = 0
	local premiereText = ""
	local premiereColor = UiKit.GOLD

	local function refreshCard()
		local index = player:GetAttribute("TouringLot")
		if type(index) ~= "number" then
			card.Visible = false
			setPulse(false)
			return
		end
		local model = lotModel(index)
		local name = if model ~= nil then model:GetAttribute("StudioName") else nil
		cardName.Text = if type(name) == "string" then name else "A STUDIO"
		local likes = if model ~= nil then number(model:GetAttribute("Likes")) else 0
		local trophies = if model ~= nil then number(model:GetAttribute("Trophies")) else 0
		cardStats.Text = `{Visits.applauseText(likes)}    🏆 {trophies} Masterpiece{if trophies == 1 then "" else "s"}`
		home.Visible = myLot() ~= nil

		if os.clock() < premiereUntil then
			cardLine.Text = premiereText
			cardLine.TextColor3 = premiereColor
		else
			local nextPremiere = if model ~= nil then model:GetAttribute("NextPremiere") else nil
			local status = Visits.status(if type(nextPremiere) == "number" then nextPremiere else nil, now())
			cardLine.Text = if status.kind == "ready" then "Premiere ready! Stay and watch" else status.text
			cardLine.TextColor3 = statusColor(status.kind)
		end

		local counted = player:GetAttribute("TourCounted") == true
		local applauded = player:GetAttribute("TourApplauded") == true
		if not counted then
			applaud.Text = "Looking around..."
			UiKit.setEnabled(applaud, false, UiKit.AWARD_GOLD)
			setPulse(false)
		elseif not applauded then
			applaud.Text = "👏 APPLAUD"
			UiKit.setEnabled(applaud, true, UiKit.AWARD_GOLD)
			setPulse(true)
		else
			applaud.Text = "👏 CLAP AGAIN"
			UiKit.setEnabled(applaud, true, UiKit.TEAL)
			setPulse(os.clock() < premiereUntil)
		end
		if not card.Visible then
			card.Visible = true
			Sfx.play("notify")
		end
	end

	local lastPress = 0
	applaud.Activated:Connect(function()
		if player:GetAttribute("TourCounted") ~= true then
			UiKit.toast(gui, "Look around the studio first!")
			return
		end
		local clock = os.clock()
		if clock - lastPress < Visits.ApplaudCooldown then
			return
		end
		lastPress = clock
		applaudRemote:FireServer()
	end)
	home.Activated:Connect(function()
		local mine = myLot()
		if mine ~= nil then
			visitRemote:FireServer(mine)
		end
	end)

	for _, name in { "TouringLot", "TourCounted", "TourApplauded" } do
		player:GetAttributeChangedSignal(name):Connect(refreshCard)
	end

	-- World and notices -------------------------------------------------------------------------
	applauseRemote.OnClientEvent:Connect(function(index, clapperId, counts, _total)
		if not validLot(index) or type(clapperId) ~= "number" then
			return
		end
		if counts == true and index == myLot() then
			Sfx.play("applauseGot") -- wherever you are (the notice says who)
		end
		if not near(index) and clapperId ~= player.UserId then
			return
		end
		local clapper = Players:GetPlayerByUserId(clapperId)
		handsOver(if clapper ~= nil then clapper.Character else nil, if counts == true then 3 else 1)
		Sfx.play("applause", 0.95 + math.random() * 0.15)
		if counts == true then
			plusOne(index)
		end
		refreshCard()
	end)

	noticeRemote.OnClientEvent:Connect(function(text)
		if type(text) == "string" then
			UiKit.toast(gui, text)
			Sfx.play("notify")
		end
	end)

	arrivedRemote.OnClientEvent:Connect(function(index)
		if not validLot(index) then
			return
		end
		Sfx.play("visitJump")
		-- Face the studio: the camera behind you at the gate, looking up the red carpet.
		task.defer(function()
			local camera = workspace.CurrentCamera
			if camera ~= nil then
				local base = bases[index]
				local eye = base * Vector3.new(0, 11, LotModels.Layout.gateZ - 9)
				local target = base * Vector3.new(0, 4, 2)
				camera.CFrame = CFrame.lookAt(eye, target)
			end
		end)
	end)

	premiereRemote.OnClientEvent:Connect(function(index, title, resultId)
		if not validLot(index) or type(title) ~= "string" or type(resultId) ~= "string" then
			return
		end
		if index == myLot() or standingOn(Visits.WatchMargin) ~= index then
			return -- owners get the full premiere night; this is for the audience
		end
		local result = Movies.getResult(resultId)
		local resultName = if result ~= nil then result.name else resultId
		local color = if result ~= nil then result.color else UiKit.GOLD
		premiereText = `"{title}": {string.upper(resultName)}!`
		premiereColor = color
		premiereUntil = os.clock() + PREMIERE_SHOW_SECONDS
		if resultId == "Flop" then
			Sfx.play("premiereFlop")
		elseif resultId == "Hit" then
			Sfx.play("premiereHit")
		else
			Sfx.play("premiereBig")
			Fx.confetti(if resultId == "Blockbuster" then 30 else 60, { color, UiKit.WHITE })
			if resultId ~= "Masterpiece" then
				Fx.celebrate(index, "pull") -- a Masterpiece already gets the whole server's fireworks
			end
		end
		if player:GetAttribute("TouringLot") ~= index then
			UiKit.toast(gui, `Premiere next door: {premiereText}`)
		end
		refreshCard()
		task.delay(PREMIERE_SHOW_SECONDS + 0.1, refreshCard)
	end)

	-- Countdowns, the chip and lists that changed while open.
	task.spawn(function()
		while true do
			updateChip()
			if card.Visible then
				refreshCard()
			end
			if panel.Visible then
				local current = fingerprint()
				if current ~= shown then
					shown = current
					build()
				else
					local t = now()
					for index, label in statusLabels do
						local model = lotModel(index)
						local value = if model ~= nil then model:GetAttribute("NextPremiere") else nil
						local status = Visits.status(if type(value) == "number" then value else nil, t)
						label.Text = status.text
						label.TextColor3 = statusColor(status.kind)
					end
				end
			end
			task.wait(0.5)
		end
	end)
	refreshCard()
end

return VisitUi
