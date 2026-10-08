--!strict
-- Studio screen: stages (start a movie, clapperboard, premiere), script shop, and cinema.
-- Styled after the design kit (see UiKit). The client shows server state and sends requests; it never decides
-- Cash, timers, or results. Remaining time is the server's end stamp minus the server's clock.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Movies = require(ReplicatedStorage.Shared.Movies)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local ClientState = require(script.Parent.ClientState)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Icon3D = require(script.Parent.Icon3D)
local Screens = require(script.Parent.Screens)
local ShopUi = require(script.Parent.ShopUi)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton, corner = UiKit.makeLabel, UiKit.makeButton, UiKit.corner
local WHITE = UiKit.WHITE

local ERRORS: { [string]: string } = {
	cash = "Not enough Cash",
	cooldown = "Slow down!",
	loading = "Still loading your data",
	invalid = "That didn't work",
	busy = "That stage is busy",
	noscript = "You need that script first",
	nocast = "Those actors aren't free",
	notready = "Not finished filming yet",
	none = "Nothing to premiere there",
	fame = "You need more Fame for that",
	maxed = "Already at max level",
	claimed = "Already claimed",
	unavailable = "Not complete yet",
	noskip = "You have no Skip Filming",
}

local GENRE_COLORS = UiKit.GENRE_COLORS

-- 3D icon for each premiere result (Cinema rows and the premiere reveal).
local RESULT_ICONS: { [string]: string } = {
	Flop = "popcorn",
	Hit = "ticket",
	Blockbuster = "star",
	Cult = "crown",
	Masterpiece = "trophy",
}

-- A small outlined 3D icon at a fixed spot (for rows whose left edge is not free all the way down).
local function smallIcon(parent: GuiObject, iconId: string, size: number, position: UDim2): Frame
	local art = Instance.new("Frame")
	art.Name = "Icon"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromOffset(size, size)
	art.Position = position
	art.ZIndex = parent.ZIndex + 1
	art.Parent = parent
	Icon3D.outlined(art, iconId)
	return art
end

local StudioUi = {}

local function fmtTime(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local h = total // 3600
	local m = (total % 3600) // 60
	local s = total % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- Star Power can be fractional (the 1.5x specialty bonus on a Power 1 actor), so show the decimal.
local function fmtPower(power: number): string
	if power == math.floor(power) then
		return Hud.comma(power)
	end
	return string.format("%.1f", power)
end

local function actorLabel(key: string): string
	local parts = string.split(key, ":")
	local actor = Actors.getActor(parts[1] or "")
	local variant = Actors.getVariant(parts[2] or "")
	if actor == nil or variant == nil then
		return key
	end
	return if variant.id == "Normal" then actor.name else `{actor.name} ({variant.name})`
end

function StudioUi.start(gui: ScreenGui, studioButton: TextButton)
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	if remotes == nil then
		warn("[StudioUi] Remotes folder never arrived")
		return
	end
	local studioRequest = remotes:WaitForChild("StudioRequest") :: RemoteEvent
	local buyScript = remotes:WaitForChild("BuyScript") :: RemoteEvent
	local startFilm = remotes:WaitForChild("StartFilm") :: RemoteEvent
	local clapRemote = remotes:WaitForChild("Clap") :: RemoteEvent
	local premiereRemote = remotes:WaitForChild("Premiere") :: RemoteEvent
	local premiereResult = remotes:WaitForChild("PremiereResult") :: RemoteEvent
	local studioError = remotes:WaitForChild("StudioError") :: RemoteEvent
	local announce = remotes:WaitForChild("Announce") :: RemoteEvent
	local useSkip = remotes:WaitForChild("UseSkip") :: RemoteEvent

	-- Local aliases of ClientState, refreshed whenever it changes (see the changed handler below).
	local state: any = ClientState.studio
	local syncedAt = ClientState.syncedAt
	local roster: { [string]: number } = ClientState.roster
	local tab = "Stages"

	local function serverNow(): number
		return if state ~= nil then state.serverNow + (os.clock() - syncedAt) else 0
	end

	local function filmAt(stage: number): any
		if state == nil then
			return nil
		end
		for _, film in state.films do
			if film.stage == stage then
				return film
			end
		end
		return nil
	end

	local function busyCopies(): { [string]: number }
		local busy: { [string]: number } = {}
		if state ~= nil then
			for _, film in state.films do
				for _, key in film.cast do
					busy[key] = (busy[key] or 0) + 1
				end
			end
		end
		return busy
	end

	-- Main panel -------------------------------------------------------------------------------
	local panel, list, header = UiKit.makePanel(gui, "StudioPanel", "Studio", 108, nil, nil, UiKit.BLUE)
	UiKit.panelIcon(panel, header, "movieCamera")

	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(10, 58)
	tabRow.Size = UDim2.new(1, -20, 0, 42)
	tabRow.Parent = panel
	local tabNames = { "Stages", "Scripts", "Cinema" }
	local tabButtons: { [string]: TextButton } = {}

	-- Stage rows that need a live countdown: updated in place so buttons are not rebuilt each tick.
	local timers: { { stage: number, time: TextLabel, fill: Frame, button: TextButton, skip: TextButton, ready: boolean } } = {}
	-- Stage the player wanted to skip when they had no token: used as soon as a bought one arrives.
	local pendingSkipStage: number? = nil

	-- Stages usable now (bought stages plus the +1 Sound Stage pass).
	local function stageCount(): number
		return if state ~= nil then state.stages or state.stageCount else 1
	end
	local renderedSignature = ""

	local render: () -> ()
	local openPicker: (stage: number) -> ()
	local refreshTimers: () -> ()

	local function stageSignature(): string
		if state == nil then
			return "loading"
		end
		local parts = { tab, tostring(stageCount()) }
		for stage = 1, Config.StageLimit do
			local film = filmAt(stage)
			table.insert(parts, if film ~= nil then film.title .. film.startTime else "-")
		end
		return table.concat(parts, "|")
	end

	local function renderStages()
		local order = 0
		for stage = 1, Config.StageLimit do
			order += 1
			-- A film still on a stage a rebirth closed keeps its row until it premieres.
			if stage > stageCount() and filmAt(stage) == nil then
				local row = UiKit.addRow(list, order, 58)
				row.BackgroundColor3 = UiKit.DARK
				UiKit.rowIcon(row, "lock", 46)
				-- With the +1 Sound Stage pass, every locked stage is one more Sound Stage upgrade away.
				local hasPass = state.passes ~= nil and state.passes.ExtraStage == true
				local how = if stage <= Config.MaxStages or hasPass then "Buy it in Upgrades" else "Unlock with the +1 Sound Stage pass in the Shop"
				local lockedTitle = UiKit.makeTitle(row, `Stage {stage}  -  locked`, UiKit.MUTED, UDim2.new(1, -74, 0, 26), UDim2.fromOffset(64, 5))
				lockedTitle.TextXAlignment = Enum.TextXAlignment.Left
				UiKit.textConstraint(lockedTitle, 22)
				local lockedHow = makeLabel(row, how, UiKit.FAINT, UDim2.new(1, -74, 0, 18), UDim2.fromOffset(64, 33))
				lockedHow.TextXAlignment = Enum.TextXAlignment.Left
				UiKit.textConstraint(lockedHow, 16)
				continue
			end
			local film = filmAt(stage)
			if film == nil then
				local row = UiKit.addRow(list, order, 76)
				UiKit.rowIcon(row, "movieCamera", 62)
				UiKit.makeTitle(row, `Stage {stage}  -  empty`, WHITE, UDim2.new(0.57, -84, 0, 34), UDim2.new(0, 78, 0.5, -17)).TextXAlignment = Enum.TextXAlignment.Left
				local go = makeButton(row, "Start movie", UiKit.GREEN, UDim2.new(0.4, 0, 0, 48), UDim2.new(0.57, 0, 0.5, -24))
				go.Name = "StartMovie"
				UiKit.pulse(go, 1.05)
				go.Activated:Connect(function()
					openPicker(stage)
				end)
				continue
			end
			local length = Movies.getLength(film.length)
			local row = UiKit.addRow(list, order, 132)
			row.Name = `Stage{stage}`
			-- The cast's portraits in the top right; the text uses the rest of the width.
			local castWidth = #film.cast * 54 + 6
			for slot, key in film.cast do
				UiKit.portrait(row, key, UDim2.fromOffset(50, 50), UDim2.new(1, -((#film.cast - slot + 1) * 54 + 4), 0, 8))
			end
			local title = UiKit.makeTitle(row, film.title, GENRE_COLORS[film.genre] or WHITE, UDim2.new(1, -(20 + castWidth), 0, 30), UDim2.fromOffset(10, 6))
			title.TextXAlignment = Enum.TextXAlignment.Left
			local sub = makeLabel(row, `Stage {stage}  -  {film.genre} {if length then length.name else film.length}`, UiKit.MUTED, UDim2.new(1, -(20 + castWidth), 0, 18), UDim2.fromOffset(10, 38))
			sub.TextXAlignment = Enum.TextXAlignment.Left
			local names = {}
			for _, key in film.cast do
				table.insert(names, actorLabel(key))
			end
			local cast = makeLabel(row, "Cast: " .. table.concat(names, ", "), WHITE, UDim2.new(1, -(20 + castWidth), 0, 18), UDim2.fromOffset(10, 58))
			cast.TextXAlignment = Enum.TextXAlignment.Left

			local bar = Instance.new("Frame")
			bar.BackgroundColor3 = UiKit.DARK
			bar.Position = UDim2.fromOffset(10, 82)
			bar.Size = UDim2.new(1, -20, 0, 12)
			bar.Parent = row
			corner(bar, 6)
			UiKit.border(bar, 2)
			local fill = Instance.new("Frame")
			fill.BackgroundColor3 = GENRE_COLORS[film.genre] or UiKit.GOLD
			fill.Size = UDim2.fromScale(0, 1)
			fill.Parent = bar
			corner(fill, 6)

			local time = UiKit.makeTitle(row, "", UiKit.GOLD, UDim2.new(0.38, 0, 0, 26), UDim2.new(0, 10, 1, -32))
			time.TextXAlignment = Enum.TextXAlignment.Left
			local button = makeButton(row, "", UiKit.RED, UDim2.new(0.36, 0, 0, 30), UDim2.new(0.43, 0, 1, -34))
			button.Name = "StageAction" -- CLAP, then PREMIERE (the tutorial points at it)
			button:SetAttribute("Silent", true) -- plays its own clapper sound
			local skip = makeButton(row, "Skip", UiKit.PURPLE, UDim2.new(0.18, 0, 0, 30), UDim2.new(0.8, 0, 1, -34))
			skip.Activated:Connect(function()
				if (state.skips or 0) > 0 then
					useSkip:FireServer(stage)
				elseif ShopUi.promptProduct("SkipFilming") then
					pendingSkipStage = stage
				else
					UiKit.toast(gui, "Skip Filming is coming soon")
				end
			end)
			table.insert(timers, { stage = stage, time = time, fill = fill, button = button, skip = skip, ready = false })
			button.Activated:Connect(function()
				-- Look the film up now: this row is updated in place, so `film` may be stale.
				local current = filmAt(stage)
				if current == nil then
					return
				end
				if current.endTime - serverNow() > 0 then
					clapRemote:FireServer(stage)
					Sfx.play("clap", 0.9 + math.random() * 0.25)
				else
					premiereRemote:FireServer(stage)
				end
			end)
		end
	end

	local function renderScripts()
		local order = 0
		local owned = {}
		for _, genre in Movies.Genres do
			for _, length in Movies.Lengths do
				local count = state.scripts[Movies.scriptKey(genre, length.id)]
				if count ~= nil and count > 0 then
					table.insert(owned, `{genre} {length.name} x{count}`)
				end
			end
		end
		order += 1
		local summary = UiKit.addRow(list, order, 52)
		UiKit.rowIcon(summary, "script", 42)
		local ownedLabel = makeLabel(summary, if #owned > 0 then "Owned: " .. table.concat(owned, ", ") else "No scripts yet - buy one below", UiKit.GOLD, UDim2.new(1, -68, 1, -8), UDim2.fromOffset(58, 4))
		ownedLabel.TextXAlignment = Enum.TextXAlignment.Left

		local cash = player:GetAttribute("Cash") or 0
		local fame = state.fame or 0
		for _, length in Movies.Lengths do
			order += 1
			local row = UiKit.addRow(list, order, 96)
			row.Name = "Script_" .. length.id
			local lengthLocked = fame < length.fame
			smallIcon(row, if lengthLocked then "lock" else "script", 36, UDim2.fromOffset(6, 2))
			local title = UiKit.makeTitle(row, `{length.name}  -  {fmtTime(length.seconds)}`, if lengthLocked then UiKit.FAINT else WHITE, UDim2.new(0.5, -40, 0, 26), UDim2.fromOffset(48, 6))
			title.TextXAlignment = Enum.TextXAlignment.Left
			local costText = if lengthLocked then `needs Fame {Hud.comma(length.fame)}` else `${Hud.comma(length.cost)}  -  base ${Hud.comma(length.base)}`
			local cost = makeLabel(row, costText, if lengthLocked then UiKit.WARN elseif cash >= length.cost then UiKit.GOLD else UiKit.WARN, UDim2.new(0.48, -10, 0, 22), UDim2.new(0.52, 0, 0, 6))
			cost.TextXAlignment = Enum.TextXAlignment.Right
			for slot, genre in Movies.Genres do
				local count = state.scripts[Movies.scriptKey(genre, length.id)] or 0
				local needFame = math.max(length.fame, Movies.GenreFame[genre] or 0)
				local locked = fame < needFame
				local text = if locked then `{genre}\nFame {needFame}` else genre
				local usable = not locked and cash >= length.cost
				local button = makeButton(row, text, GENRE_COLORS[genre], UDim2.new(0.19, 0, 0, 40), UDim2.new((slot - 1) * 0.2 + 0.005, 0, 0, 44))
				UiKit.setEnabled(button, usable, GENRE_COLORS[genre])
				-- Owned copies as a green chip on the corner, like the menu's counters.
				if count > 0 and not locked then
					UiKit.chip(button, `x{count}`)
				end
				button.Activated:Connect(function()
					buyScript:FireServer(genre, length.id)
				end)
			end
		end
	end

	local function renderCinema()
		local order = 0
		order += 1
		local top = UiKit.addRow(list, order, 52)
		UiKit.rowIcon(top, "coin", 42)
		local royalties = makeLabel(top, `Fame {Hud.comma(state.fame)}  -  royalties ${string.format("%.2f", state.rate)}/s`, UiKit.GOLD, UDim2.new(1, -68, 1, -8), UDim2.fromOffset(58, 4))
		royalties.TextXAlignment = Enum.TextXAlignment.Left
		if #state.cinema == 0 then
			order += 1
			local row = UiKit.addRow(list, order, 52)
			makeLabel(row, "No premieres yet - finish a movie!", UiKit.MUTED, UDim2.new(1, -20, 0.6, 0), UDim2.fromOffset(10, 10))
			return
		end
		for index = #state.cinema, 1, -1 do
			local movie = state.cinema[index]
			local result = Movies.getResult(movie.result)
			order += 1
			local row = UiKit.addRow(list, order, 60)
			UiKit.rowIcon(row, RESULT_ICONS[movie.result] or "popcorn", 48)
			local name = UiKit.makeTitle(row, movie.title, GENRE_COLORS[movie.genre] or WHITE, UDim2.new(0.55, -54, 0, 26), UDim2.fromOffset(64, 6))
			name.TextXAlignment = Enum.TextXAlignment.Left
			local detail = makeLabel(row, `{movie.genre}  -  ${Hud.comma(movie.payout)}`, UiKit.MUTED, UDim2.new(0.55, -54, 0, 18), UDim2.fromOffset(64, 34))
			detail.TextXAlignment = Enum.TextXAlignment.Left
			local tag = UiKit.makeTitle(row, if result then result.name else movie.result, if result then result.color else WHITE, UDim2.new(0.4, 0, 0, 30), UDim2.new(0.58, 0, 0.5, -15))
			tag.TextXAlignment = Enum.TextXAlignment.Right
		end
	end

	render = function()
		UiKit.clear(list)
		table.clear(timers)
		for name, button in tabButtons do
			UiKit.styleTab(button, name == tab)
		end
		if state == nil then
			local row = UiKit.addRow(list, 1, 52)
			makeLabel(row, "Loading your studio...", UiKit.MUTED, UDim2.new(1, -20, 0.6, 0), UDim2.fromOffset(10, 10))
			renderedSignature = "loading"
			return
		end
		header.Text = `Studio  -  Fame {Hud.comma(state.fame)}`
		panel:SetAttribute("Tab", tab)
		if tab == "Stages" then
			renderStages()
		elseif tab == "Scripts" then
			renderScripts()
		else
			renderCinema()
		end
		renderedSignature = stageSignature()
		-- Fill the new stage rows' timers and buttons now rather than at the next tick.
		refreshTimers()
	end

	for slot, name in tabNames do
		local button = makeButton(tabRow, name, UiKit.TAB_OFF, UDim2.new(0.32, 0, 1, 0), UDim2.new((slot - 1) * 0.34, 0, 0, 0))
		button.Name = name .. "Tab"
		tabButtons[name] = button
		button.Activated:Connect(function()
			tab = name
			render()
		end)
	end

	-- Start-movie picker -----------------------------------------------------------------------
	local picker, pickerList, pickerHeader = UiKit.makePanel(gui, "PickerPanel", "Start movie", 60, true, 130, UiKit.FRESH_GREEN)
	UiKit.panelIcon(picker, pickerHeader, "clapper")
	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.new(0, 10, 1, -126)
	footer.Size = UDim2.new(1, -20, 0, 118)
	footer.Parent = picker
	-- Cast slots: the picked actors' portraits (tap one to take it out), then empty "+" slots.
	local castSlots: { TextButton } = {}
	for slot = 1, Config.MaxCast do
		local slotButton = Instance.new("TextButton")
		slotButton.Name = `CastSlot{slot}`
		slotButton.Text = "+"
		slotButton.TextColor3 = UiKit.FAINT
		slotButton.Font = UiKit.DISPLAY_FONT
		slotButton.TextScaled = true
		slotButton.AutoButtonColor = false
		slotButton.BackgroundColor3 = UiKit.DARK
		slotButton.Size = UDim2.fromOffset(44, 44)
		slotButton.Position = UDim2.fromOffset((slot - 1) * 50, 0)
		slotButton.Parent = footer
		corner(slotButton, 8)
		UiKit.border(slotButton, 2)
		UiKit.textConstraint(slotButton, 30)
		castSlots[slot] = slotButton
	end
	local slotsWidth = Config.MaxCast * 50 + 6
	local summaryLabel = UiKit.makeTitle(footer, "", WHITE, UDim2.new(1, -slotsWidth, 0, 40), UDim2.fromOffset(slotsWidth, 2))
	summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
	UiKit.textConstraint(summaryLabel, 24)
	local previewLabel = makeLabel(footer, "", UiKit.GOLD, UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 48))
	local clearButton = makeButton(footer, "Clear cast", UiKit.BURGUNDY, UDim2.new(0.3, 0, 0, 42), UDim2.fromOffset(0, 76))
	local goButton = makeButton(footer, "Start filming", UiKit.GREEN, UDim2.new(0.66, 0, 0, 42), UDim2.new(0.34, 0, 0, 76))
	goButton.Name = "StartFilming"

	local pickStage = 1
	local pickScript: string? = nil
	local pickCast: { string } = {}
	local buildPicker: () -> ()

	local function pickedCount(key: string): number
		local n = 0
		for _, k in pickCast do
			if k == key then
				n += 1
			end
		end
		return n
	end

	local function updatePickerFooter()
		local names = {}
		for _, key in pickCast do
			table.insert(names, actorLabel(key))
		end
		summaryLabel.Text = if #names > 0 then table.concat(names, ", ") else "Tap actors to cast them"
		for slot, slotButton in castSlots do
			-- Only a slot whose actor changed gets a new portrait, so the others do not redraw.
			local key = pickCast[slot]
			if slotButton:GetAttribute("Key") ~= key then
				slotButton:SetAttribute("Key", key)
				local old = slotButton:FindFirstChild("Portrait")
				if old ~= nil then
					old:Destroy()
				end
				slotButton.Text = if key == nil then "+" else ""
				if key ~= nil then
					UiKit.portrait(slotButton, key, UDim2.fromScale(1, 1))
				end
			end
		end
		local genre: string? = nil
		local lengthId: string? = nil
		if pickScript ~= nil then
			local parts = string.split(pickScript, ":")
			genre, lengthId = parts[1], parts[2]
		end
		local length = if lengthId ~= nil then Movies.getLength(lengthId) else nil
		local ready = pickScript ~= nil and #pickCast >= 1 and length ~= nil
		if ready and genre ~= nil and length ~= nil then
			local power = Movies.castPower(pickCast, genre)
			local hit = Movies.getResult("Hit")
			local estimate = if hit ~= nil then Movies.payout(length, power, hit) else 0
			previewLabel.Text = `Star Power {fmtPower(power)}  -  a Hit pays ${Hud.comma(estimate)}`
		else
			previewLabel.Text = if pickScript == nil then "Pick a script first" else "Pick at least one actor"
		end
		UiKit.setEnabled(goButton, ready, UiKit.GREEN)
		-- What is picked so far, for the tutorial's pointer.
		picker:SetAttribute("Script", pickScript)
		picker:SetAttribute("Cast", #pickCast)
	end

	-- The picker's script buttons and actor cards stay between taps and are updated in place, so
	-- their 3D pictures are not rebuilt (which made them blink) every time an actor is picked.
	local scriptButtons: { [string]: TextButton } = {}
	type ActorCard = { card: TextButton, power: TextLabel, bonus: TextLabel }
	local actorCards: { [string]: ActorCard } = {}
	local actorGrid: Frame? = nil
	local noActorsRow: Frame? = nil
	-- What the picker was built from (owned scripts, actors with free copies): a sync that changes
	-- neither only refreshes it.
	local pickerBuiltFor = ""
	local function pickerSignature(): string
		local parts = {}
		if state ~= nil then
			for key, count in state.scripts do
				if count > 0 then
					table.insert(parts, `s{key}={count}`)
				end
			end
		end
		local busy = busyCopies()
		for key, count in roster do
			local free = count - (busy[key] or 0)
			if free > 0 then
				table.insert(parts, `a{key}={free}`)
			end
		end
		table.sort(parts)
		return table.concat(parts, "|")
	end

	local function refreshPicker()
		local genre = if pickScript ~= nil then string.split(pickScript, ":")[1] else nil
		for key, button in scriptButtons do
			local picked = key == pickScript
			button.BackgroundColor3 = if picked then UiKit.GREEN else GENRE_COLORS[string.split(key, ":")[1]] or UiKit.BLUE
			local outline = button:FindFirstChild("Outline")
			if outline ~= nil and outline:IsA("UIStroke") then
				outline.Color = if picked then UiKit.GOLD else UiKit.INK
				outline.Thickness = if picked then 4 else 3
			end
		end
		-- Free copies left after the cast so far; actors with none left hide. Best power first.
		local busy = busyCopies()
		local shown: { { key: string, power: number } } = {}
		for key, entry in actorCards do
			local free = (roster[key] or 0) - (busy[key] or 0) - pickedCount(key)
			local power = Movies.actorPower(key, genre or "")
			entry.card.Visible = free > 0
			entry.power.Text = `Power {fmtPower(power)}`
			UiKit.chip(entry.card, `x{math.max(free, 0)}`)
			local actor = Actors.getActor(string.split(key, ":")[1])
			local matches = genre ~= nil and actor ~= nil and actor.genre == genre
			entry.bonus.Visible = matches
			if genre ~= nil and matches then
				entry.bonus.Text = `{genre} x{Movies.SpecialtyBonus}`
				entry.bonus.BackgroundColor3 = GENRE_COLORS[genre] or UiKit.GOLD
			end
			if free > 0 then
				table.insert(shown, { key = key, power = power })
			end
		end
		table.sort(shown, function(a, b)
			if a.power ~= b.power then
				return a.power > b.power
			end
			return a.key < b.key
		end)
		for index, item in shown do
			actorCards[item.key].card.LayoutOrder = index
		end
		if actorGrid ~= nil then
			actorGrid.Visible = #shown > 0
		end
		if noActorsRow ~= nil then
			noActorsRow.Visible = #shown == 0
		end
		updatePickerFooter()
	end

	buildPicker = function()
		UiKit.clear(pickerList)
		table.clear(scriptButtons)
		table.clear(actorCards)
		pickerHeader.Text = `Start movie  -  Stage {pickStage}`
		local order = 0

		order += 1
		local h1 = UiKit.addRow(pickerList, order, 28)
		UiKit.makeTitle(h1, "1. Script", UiKit.GOLD, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
		local anyScript = false
		for _, genre in Movies.Genres do
			for _, length in Movies.Lengths do
				local key = Movies.scriptKey(genre, length.id)
				local count = if state ~= nil then state.scripts[key] or 0 else 0
				if count > 0 then
					anyScript = true
					order += 1
					local button = makeButton(pickerList, "", GENRE_COLORS[genre] or UiKit.BLUE, UDim2.new(1, -8, 0, 44))
					button.Name = "PickScript_" .. key
					button.LayoutOrder = order
					smallIcon(button, "script", 38, UDim2.fromOffset(8, 3))
					local label = UiKit.makeTitle(button, `{genre} {length.name}  x{count}  ({fmtTime(length.seconds)})`, WHITE, UDim2.new(1, -62, 1, -10), UDim2.fromOffset(54, 5), 2)
					UiKit.textConstraint(label, 22)
					button.Activated:Connect(function()
						pickScript = key
						refreshPicker()
					end)
					scriptButtons[key] = button
				end
			end
		end
		if not anyScript then
			order += 1
			local row = UiKit.addRow(pickerList, order, 44)
			makeLabel(row, "No scripts - buy one in the Scripts tab", UiKit.MUTED, UDim2.new(1, -20, 0.7, 0), UDim2.fromOffset(10, 6))
		end

		order += 1
		local h2 = UiKit.addRow(pickerList, order, 28)
		UiKit.makeTitle(h2, `2. Cast (up to {Config.MaxCast})`, UiKit.GOLD, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left

		order += 1
		local emptyRow = UiKit.addRow(pickerList, order, 44)
		makeLabel(emptyRow, "No free actors - cast some first", UiKit.MUTED, UDim2.new(1, -20, 0.7, 0), UDim2.fromOffset(10, 6))
		noActorsRow = emptyRow

		-- Every actor with a copy not busy filming gets a picture card in its rarity colors; tap one
		-- to cast it. refreshPicker hides the ones whose copies are all in the cast.
		order += 1
		local grid = Instance.new("Frame")
		grid.Name = "Actors"
		grid.LayoutOrder = order
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -8, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Parent = pickerList
		actorGrid = grid
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(1 / 3, -8, 0, if UiKit.isCompact() then 128 else 150)
		layout.CellPadding = UDim2.fromOffset(10, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 3)
		pad.PaddingTop = UDim.new(0, 8)
		pad.Parent = grid
		local busy = busyCopies()
		for key, count in roster do
			if count - (busy[key] or 0) <= 0 then
				continue
			end
			local parts = string.split(key, ":")
			local actor = Actors.getActor(parts[1])
			local card = Instance.new("TextButton")
			card.Name = key
			card.Text = ""
			card.AutoButtonColor = false
			card:SetAttribute("ChipInset", true) -- cards touch: keep the copies chip inside
			card.Parent = grid
			corner(card, 12)
			UiKit.rarityStyle(card, key, 3)
			local art = Instance.new("Frame")
			art.Name = "Art"
			art.BackgroundTransparency = 1
			art.Position = UDim2.fromScale(0.05, 0.03)
			art.Size = UDim2.fromScale(0.9, 0.56)
			art.Parent = card
			if actor ~= nil then
				local tier = Actors.getTier(actor.tier)
				Icon3D.glow(Icon3D.actor(art, actor.id, parts[2]), if tier ~= nil then tier.color else nil)
			end
			local name = UiKit.makeTitle(card, actorLabel(key), WHITE, UDim2.fromScale(0.94, 0.17), UDim2.fromScale(0.03, 0.6), 2)
			name.ZIndex = 3
			UiKit.textConstraint(name, 18)
			local power = UiKit.makeTitle(card, "", UiKit.GOLD, UDim2.fromScale(0.94, 0.15), UDim2.fromScale(0.03, 0.79), 2)
			power.ZIndex = 3
			UiKit.textConstraint(power, 18)
			-- Tag shown when the actor's specialty matches the picked script, over the foot of the
			-- picture (the owned-copies chip has the top corner).
			local bonus = UiKit.makeTitle(card, "", WHITE, UDim2.fromOffset(86, 22), UDim2.new(0.5, 0, 0.6, -2), 1.5)
			bonus.AnchorPoint = Vector2.new(0.5, 1)
			bonus.BackgroundTransparency = 0
			bonus.Rotation = -4
			bonus.ZIndex = 6
			bonus.Visible = false
			corner(bonus, 8)
			UiKit.border(bonus, 2)
			UiKit.textConstraint(bonus, 15)
			UiKit.bounce(card)
			card.Activated:Connect(function()
				Sfx.play("click")
				if #pickCast < Config.MaxCast then
					table.insert(pickCast, key)
					refreshPicker()
				else
					UiKit.toast(gui, `A movie takes at most {Config.MaxCast} actors`)
				end
			end)
			actorCards[key] = { card = card, power = power, bonus = bonus }
		end
		pickerBuiltFor = pickerSignature()
		refreshPicker()
	end

	openPicker = function(stage: number)
		pickStage = stage
		pickScript = nil
		pickCast = {}
		buildPicker()
		picker.Visible = true
	end

	clearButton.Activated:Connect(function()
		pickCast = {}
		refreshPicker()
	end)
	for slot, slotButton in castSlots do
		slotButton.Activated:Connect(function()
			if pickCast[slot] ~= nil then
				Sfx.play("click")
				table.remove(pickCast, slot)
				refreshPicker()
			end
		end)
	end
	goButton.Activated:Connect(function()
		if pickScript == nil or #pickCast < 1 then
			UiKit.toast(gui, "Pick a script and at least one actor")
			return
		end
		local parts = string.split(pickScript, ":")
		startFilm:FireServer(pickStage, parts[1], parts[2], table.clone(pickCast))
		picker.Visible = false
	end)

	-- Premiere reveal --------------------------------------------------------------------------
	local overlay = Instance.new("Frame")
	overlay.Name = "PremiereReveal"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiKit.DARK
	overlay.BackgroundTransparency = 0.25
	overlay.Active = true
	overlay.Visible = false
	overlay.ZIndex = 12
	overlay.Parent = gui
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.85, 0.6)
	card.BackgroundColor3 = UiKit.PANEL
	card.ZIndex = 13
	card.Parent = overlay
	corner(card, 20)
	local cardLimit = Instance.new("UISizeConstraint")
	cardLimit.MaxSize = Vector2.new(440, 480)
	cardLimit.Parent = card
	local stroke = UiKit.border(card, 6)

	local function cardLabel(y: number, h: number, size: number): TextLabel
		local label = UiKit.makeTitle(card, "", WHITE, UDim2.new(0.9, 0, h, 0), UDim2.new(0.05, 0, y, 0), if size >= 30 then 3 else 2)
		label.ZIndex = 14
		UiKit.textConstraint(label, size)
		return label
	end
	local premiereTitle = cardLabel(0.04, 0.12, 26)
	local resultLabel = cardLabel(0.18, 0.2, 44)
	local payoutLabel = cardLabel(0.42, 0.12, 30)
	local fameLabel = cardLabel(0.55, 0.09, 22)
	local castLabel = cardLabel(0.65, 0.09, 18)
	local continueButton = makeButton(card, "Continue", UiKit.GREEN, UDim2.fromScale(0.6, 0.15), UDim2.fromScale(0.2, 0.8))
	continueButton.ZIndex = 14
	-- The result's 3D icon, spinning on top of the card.
	local resultArt = Instance.new("Frame")
	resultArt.Name = "ResultArt"
	resultArt.BackgroundTransparency = 1
	resultArt.AnchorPoint = Vector2.new(0.5, 0.85)
	resultArt.Position = UDim2.fromScale(0.5, 0)
	resultArt.Size = UDim2.fromScale(0.32, 0.32)
	resultArt.ZIndex = 15
	resultArt.Parent = card
	local resultAspect = Instance.new("UIAspectRatioConstraint")
	resultAspect.Parent = resultArt
	local stopResultSpin: (() -> ())? = nil
	local function clearResultArt()
		if stopResultSpin ~= nil then
			stopResultSpin()
			stopResultSpin = nil
		end
		for _, child in resultArt:GetChildren() do
			if not child:IsA("UIAspectRatioConstraint") then
				child:Destroy()
			end
		end
	end
	continueButton.Activated:Connect(function()
		overlay.Visible = false
		clearResultArt()
	end)

	local premiereToken = 0
	local function showPremiere(result: any)
		local res = Movies.getResult(result.result)
		if res == nil then
			return
		end
		premiereToken += 1
		local mine = premiereToken
		clearResultArt()
		overlay.Visible = true
		for _, child in card:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = false
			end
		end
		stroke.Color = UiKit.FAINT
		premiereTitle.Visible = true
		premiereTitle.Text = `"{result.title}"`
		resultLabel.Visible = true
		resultLabel.TextColor3 = WHITE
		resultLabel.Text = "The reviews are in..."
		Sfx.play("premiereDrumroll")
		task.delay(1.2, function()
			if premiereToken ~= mine then
				return
			end
			for _, child in card:GetChildren() do
				if child:IsA("GuiObject") then
					child.Visible = true
				end
			end
			stroke.Color = res.color
			clearResultArt()
			stopResultSpin = Icon3D.spin(Icon3D.outlined(resultArt, RESULT_ICONS[res.id] or "popcorn"), 24)
			resultLabel.Text = res.name:upper() .. "!"
			Fx.premiere(res.id, res.color)
			resultLabel.TextColor3 = res.color
			payoutLabel.Text = `+${Hud.comma(result.payout)}`
			if (result.genreBonus or 1) > 1 then
				payoutLabel.Text ..= `  (genre set x{result.genreBonus})`
			end
			if result.awardNight then
				payoutLabel.Text ..= `  (Award Night x{Config.AwardNightPayoutMultiplier})`
			end
			if type(result.rebirthBonus) == "number" and result.rebirthBonus > 1 then
				payoutLabel.Text ..= `  (rebirth x{result.rebirthBonus})`
			end
			payoutLabel.TextColor3 = UiKit.CASH_GREEN
			fameLabel.Text = `+{Hud.comma(result.fame)} Fame  -  Star Power {fmtPower(result.power)}`
			fameLabel.TextColor3 = UiKit.GOLD
			local names = {}
			for _, key in result.cast do
				table.insert(names, actorLabel(key))
			end
			castLabel.Text = table.concat(names, ", ")
			castLabel.TextColor3 = UiKit.MUTED
		end)
	end

	-- Announcement banner ----------------------------------------------------------------------
	local banner = UiKit.makeTitle(gui, "", UiKit.WHITE, UDim2.new(0.9, 0, 0, 40), UDim2.new(0.05, 0, 0, 168))
	banner.Name = "Banner"
	banner.BackgroundTransparency = 0
	banner.BackgroundColor3 = UiKit.RED
	banner.Visible = false
	banner.ZIndex = 20
	corner(banner, 12)
	UiKit.border(banner, 3, UiKit.GOLD)
	local bannerPad = Instance.new("UIPadding")
	bannerPad.PaddingTop = UDim.new(0, 5)
	bannerPad.PaddingBottom = UDim.new(0, 5)
	bannerPad.Parent = banner
	local bannerToken = 0
	announce.OnClientEvent:Connect(function(text)
		if type(text) ~= "string" then
			return
		end
		bannerToken += 1
		local mine = bannerToken
		banner.Text = text
		banner.Visible = true
		task.delay(5, function()
			if bannerToken == mine then
				banner.Visible = false
			end
		end)
	end)

	-- Wiring -----------------------------------------------------------------------------------
	ClientState.changed:Connect(function(kind)
		state = ClientState.studio
		syncedAt = ClientState.syncedAt
		roster = ClientState.roster
		local function syncPicker()
			if not picker.Visible then
				return
			end
			if pickerSignature() ~= pickerBuiltFor then
				buildPicker()
			else
				refreshPicker()
			end
		end
		if kind ~= "studio" then
			syncPicker()
			return
		end
		if panel.Visible then
			-- Rebuild only when the layout changed; otherwise the tick loop refreshes timers in place.
			if tab ~= "Stages" or stageSignature() ~= renderedSignature then
				render()
			end
		end
		syncPicker()
		-- A Skip Filming bought from a stage's Skip button is used on that stage right away.
		local skipStage = pendingSkipStage
		if skipStage ~= nil and state ~= nil and (state.skips or 0) > 0 then
			pendingSkipStage = nil
			useSkip:FireServer(skipStage)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_userId, _productId, purchased)
		if not purchased then
			pendingSkipStage = nil
		end
	end)

	premiereResult.OnClientEvent:Connect(function(result)
		if type(result) == "table" then
			showPremiere(result)
		end
	end)

	studioError.OnClientEvent:Connect(function(reason)
		UiKit.toast(gui, ERRORS[reason] or "That didn't work")
	end)

	studioButton.Activated:Connect(function()
		picker.Visible = false
		UiKit.togglePanel(panel, render)
		studioRequest:FireServer()
	end)
	Screens.register("Studio", function()
		if not panel.Visible then
			picker.Visible = false
			UiKit.togglePanel(panel, render)
			studioRequest:FireServer()
		end
	end)

	-- Live countdowns: refresh timers in place (so buttons are never rebuilt under a tap). The loop
	-- only runs while the panel is open.
	refreshTimers = function()
		if tab ~= "Stages" or state == nil then
			return
		end
		local needsRender = false
		for _, entry in timers do
			local film = filmAt(entry.stage)
			if film == nil then
				needsRender = true
				break
			end
			local remaining = film.endTime - serverNow()
			local total = math.max(1, film.endTime - film.startTime)
			entry.fill.Size = UDim2.fromScale(math.clamp(1 - remaining / total, 0, 1), 1)
			local ready = remaining <= 0
			entry.skip.Visible = not ready
			if not ready then
				entry.skip.Text = if (state.skips or 0) > 0 then `Skip ({state.skips})` else "Skip"
			end
			if ready then
				if not entry.ready then
					UiKit.pulse(entry.button, 1.08)
				end
				entry.time.Text = "Ready!"
				entry.button.Text = "PREMIERE!"
				entry.button.BackgroundColor3 = UiKit.GREEN
			else
				entry.time.Text = fmtTime(remaining)
				entry.button.Text = `CLAP!  (-{Upgrades.clapSeconds(ClientState.stats())}s)`
				entry.button.BackgroundColor3 = UiKit.RED
			end
			entry.ready = ready
		end
		if needsRender then
			render()
		end
	end

	local ticking = false
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible or ticking then
			return
		end
		ticking = true
		task.spawn(function()
			while panel.Visible do
				refreshTimers()
				task.wait(0.25)
			end
			ticking = false
		end)
	end)
end

return StudioUi
