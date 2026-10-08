--!strict
-- The Top Studios board on the spawn plaza: the best studios by Fame across every server. Fame
-- never resets (not even on a Sequel) and is never spent, so it is a fair all-time score.
--
-- Each player's Fame is written to an OrderedDataStore now and then (only when it changed, and
-- once more when they leave), and the top of that list is read back once a minute. The board
-- shows that list merged with the players on this server, so it moves the moment someone here
-- earns Fame. If the DataStore is unavailable (Studio without API access, an outage), the board
-- keeps working with just this server's players.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local TopStudios = require(ReplicatedStorage.Shared.TopStudios)
local TopStudiosModels = require(ReplicatedStorage.Shared.Models.TopStudiosModels)
local DataService = require(script.Parent.DataService)

local STORE_NAME = "TopStudiosFame_v1"
local SAVE_SECONDS = 120 -- per player, and only when their Fame changed
local FETCH_SECONDS = 60
local DRAW_SECONDS = 5

local GOLD = Color3.fromRGB(245, 184, 46)
local SILVER = Color3.fromRGB(205, 214, 228)
local BRONZE = Color3.fromRGB(214, 140, 80)
local INK = Color3.fromRGB(11, 15, 31)
local ROW_DARK = Color3.fromRGB(27, 35, 64)
local ROW_LIGHT = Color3.fromRGB(38, 49, 88)

type Row = { frame: Frame, rank: TextLabel, face: ImageLabel, name: TextLabel, fame: TextLabel, medal: UIStroke? }

local store: OrderedDataStore? = nil
local storeOff = false -- set after an access error, so Studio without API access stays quiet
local warned = false

local saved: { TopStudios.Entry } = {}
local lastSaved: { [Player]: number } = {} -- Fame last written for each player here
local names: { [number]: string } = {}
local rows: { Row } = {}
local lastDrawn: string? = nil -- nil until the first draw, so an empty board is drawn too

local LeaderboardService = {}

local function note(err: any)
	local message = tostring(err)
	if string.find(message, "403") or string.find(string.lower(message), "access") then
		storeOff = true
	end
	if not warned then
		warned = true
		warn(`[MovieMogul] Top Studios board is showing this server only (DataStore unavailable: {message})`)
	end
end

local function getStore(): OrderedDataStore?
	if store ~= nil or storeOff then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		note(result)
	end
	return store
end

local function fameOf(player: Player): number?
	local data = DataService.getData(player)
	return if data ~= nil then math.floor(data.fame) else nil
end

-- Studio test players have UserIds of 0 or below; they show on the board but are never saved.
local function save(player: Player)
	local fame = fameOf(player)
	if fame == nil or fame <= 0 or player.UserId <= 0 or lastSaved[player] == fame then
		return
	end
	local ordered = getStore()
	if ordered == nil then
		return
	end
	local ok, err = pcall(function()
		ordered:SetAsync(tostring(player.UserId), fame)
	end)
	if ok then
		lastSaved[player] = fame
	else
		note(err)
	end
end

-- Names for saved players who are not on this server, looked up in one batch and remembered.
local function learnNames(entries: { TopStudios.Entry })
	local missing: { number } = {}
	for _, entry in entries do
		if names[entry.userId] == nil and entry.userId > 0 then
			table.insert(missing, entry.userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and type(infos) == "table" then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
	for _, userId in missing do
		if names[userId] == nil then
			local found, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			names[userId] = if found then name else "Studio " .. userId
		end
	end
end

local function fetch()
	local ordered = getStore()
	if ordered == nil then
		return
	end
	local ok, result = pcall(function()
		local pages = ordered:GetSortedAsync(false, TopStudios.BoardSize)
		local list: { TopStudios.Entry } = {}
		for _, item in pages:GetCurrentPage() do
			local userId = tonumber(item.key)
			if userId ~= nil and type(item.value) == "number" then
				table.insert(list, { userId = userId, fame = item.value })
			end
		end
		return list
	end)
	if ok then
		saved = result
		learnNames(saved)
	else
		note(result)
	end
end

-- Board screen -----------------------------------------------------------------------------------

local function text(parent: Instance, name: string, x: number, width: number, align: Enum.TextXAlignment, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, 0.1)
	label.Size = UDim2.fromScale(width, 0.8)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = align
	label.TextColor3 = color
	label.Text = ""
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	return label
end

-- One face of the board: 10 rows, filled in by draw().
local function buildFace(screen: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TopStudios" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Parent = screen
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.03, 0.04)
	list.Size = UDim2.fromScale(0.94, 0.92)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.012, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i = 1, TopStudios.BoardSize do
		local frame = Instance.new("Frame")
		frame.Name = "Row" .. i
		frame.LayoutOrder = i
		frame.Size = UDim2.fromScale(1, 0.088)
		frame.BackgroundColor3 = if i % 2 == 1 then ROW_LIGHT else ROW_DARK
		frame.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = frame
		local medal = if i == 1 then GOLD elseif i == 2 then SILVER elseif i == 3 then BRONZE else Color3.new(1, 1, 1)
		local rank = text(frame, "Rank", 0.01, 0.08, Enum.TextXAlignment.Center, medal)
		rank.Text = "#" .. i
		local headshot = Instance.new("ImageLabel")
		headshot.Name = "Face"
		headshot.BackgroundColor3 = medal:Lerp(ROW_DARK, 0.5)
		headshot.Position = UDim2.fromScale(0.1, 0.05)
		headshot.Size = UDim2.fromScale(0.06, 0.9)
		headshot.Image = ""
		headshot.Parent = frame
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = headshot
		local name = text(frame, "Name", 0.18, 0.5, Enum.TextXAlignment.Left, Color3.new(1, 1, 1))
		local fame = text(frame, "Fame", 0.68, 0.31, Enum.TextXAlignment.Right, GOLD)
		local outline: UIStroke? = nil
		if i <= 3 then
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = medal
			stroke.Thickness = 4
			stroke.Parent = frame
			outline = stroke
		end
		table.insert(rows, { frame = frame, rank = rank, face = headshot, name = name, fame = fame, medal = outline })
	end
end

local function draw()
	local live: { TopStudios.Entry } = {}
	for _, player in Players:GetPlayers() do
		local fame = fameOf(player)
		if fame ~= nil then
			names[player.UserId] = player.DisplayName
			table.insert(live, { userId = player.UserId, fame = fame })
		end
	end
	local top = TopStudios.merge(saved, live, TopStudios.BoardSize)
	-- Skip the redraw when nothing on the board changed.
	local signature = ""
	for _, entry in top do
		signature ..= `{entry.userId}={entry.fame}={names[entry.userId] or ""};`
	end
	if signature == lastDrawn then
		return
	end
	lastDrawn = signature
	local perFace = TopStudios.BoardSize
	for i, row in rows do
		local entry = top[(i - 1) % perFace + 1]
		if entry ~= nil then
			row.name.Text = names[entry.userId] or "..."
			row.fame.Text = "★ " .. TopStudios.short(entry.fame)
			row.face.Image = if entry.userId > 0 then `rbxthumb://type=AvatarHeadShot&id={entry.userId}&w=150&h=150` else ""
			row.face.Visible = true
			row.frame.BackgroundTransparency = 0
		else
			row.name.Text = if i % perFace == 1 and #top == 0 then "Earn Fame to get on the board!" else ""
			row.fame.Text = ""
			row.face.Image = ""
			row.face.Visible = false
			row.frame.BackgroundTransparency = 0.5
		end
		-- Silver and bronze outlines only once someone holds that place.
		if row.medal ~= nil then
			row.medal.Enabled = entry ~= nil
		end
	end
end

function LeaderboardService.start()
	local screen = TopStudiosModels.board(workspace:FindFirstChild("Town") or workspace, TopStudiosModels.Layout.board)
	buildFace(screen, Enum.NormalId.Front)
	buildFace(screen, Enum.NormalId.Back)
	draw()

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		lastSaved[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
		task.wait(3)
	end)

	task.spawn(function()
		local lastFetch, lastSaveRound = -math.huge, os.clock()
		while true do
			if os.clock() - lastFetch >= FETCH_SECONDS then
				lastFetch = os.clock()
				fetch()
			end
			if os.clock() - lastSaveRound >= SAVE_SECONDS then
				lastSaveRound = os.clock()
				for _, player in Players:GetPlayers() do
					task.spawn(save, player)
				end
			end
			draw()
			task.wait(DRAW_SECONDS)
		end
	end)
end

return LeaderboardService
