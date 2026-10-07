-- Preview scenes for dump.luau. Each builds into `folder` using the real game modules.
local scenes = {}

local function modules(load)
	return load("src/shared/Models/Build.luau"), load("src/shared/Models/LotModels.luau")
end

function scenes.stage(folder, load, roblox)
	local Build, LotModels = modules(load)
	local b = Build.new(folder, roblox.CFrame.new())
	LotModels.soundStage(b:sub(roblox.Vector3.new(-8, 0, 0)), 1, { owned = false, accent = Build.Palette.Carpet, filming = false })
	LotModels.soundStage(b:sub(roblox.Vector3.new(8, 0, 0)), 2, { owned = true, accent = Build.Palette.Carpet, filming = true })
end

function scenes.cinema(folder, load, roblox)
	local Build, LotModels = modules(load)
	local b = Build.new(folder, roblox.CFrame.new())
	local x = -45
	for tier = 1, 4 do
		LotModels.cinema(b:sub(roblox.Vector3.new(x, 0, 0)), tier, Build.Palette.Blue)
		x += 30
	end
end

function scenes.office(folder, load, roblox)
	local Build, LotModels = modules(load)
	local b = Build.new(folder, roblox.CFrame.new())
	for level = 0, 5 do
		LotModels.office(b:sub(roblox.Vector3.new(-35 + level * 14, 0, 0)), level, Build.Palette.Carpet)
	end
end

function scenes.props(folder, load, roblox)
	local Build, LotModels = modules(load)
	local V = roblox.Vector3.new
	local b = Build.new(folder, roblox.CFrame.new())
	LotModels.palm(b:sub(V(-14, 0, 0)), 16)
	LotModels.lamp(b:sub(V(-8, 0, 0)))
	LotModels.ticketKiosk(b:sub(V(-3, 0, 0)))
	LotModels.billboard(b:sub(V(8, 0, 0)))
	LotModels.trophyCase(b:sub(V(-3, 0, -6)), 5)
	LotModels.pedestal(b:sub(V(4, 0, -7)), Build.Palette.Gold, true)
	LotModels.searchlight(b:sub(V(18, 0, 0)), 20)
end

-- All 21 actors in rarity order, 7 per row.
function scenes.actors(folder, load, roblox)
	local Actors = load("src/shared/Actors.luau")
	local ActorModels = load("src/shared/Models/ActorModels.luau")
	for i, actor in Actors.List do
		local col = (i - 1) % 7
		local row = (i - 1) // 7
		ActorModels.build(folder, roblox.CFrame.new((3 - col) * 5.5, 0, row * 7), actor.id, "Normal")
	end
end

-- One actor: arg is "ActorId" or "ActorId:VariantId".
function scenes.actor(folder, load, roblox, arg)
	local ActorModels = load("src/shared/Models/ActorModels.luau")
	local id, variant = string.match(arg, "^([^:]+):?(.*)$")
	ActorModels.build(folder, roblox.CFrame.new(), id, if variant == "" then "Normal" else variant)
end

function scenes.variants(folder, load, roblox)
	local ActorModels = load("src/shared/Models/ActorModels.luau")
	for i, variant in { "Normal", "Shiny", "Award" } do
		ActorModels.build(folder, roblox.CFrame.new((2 - i) * 5, 0, 0), "BoxOfficeKing", variant)
	end
end

-- A whole lot at a given progress level, composed the same way LotService does it.
local function lot(folder, load, roblox, progress)
	local Build, LotModels = modules(load)
	local ok, LotLook = pcall(load, "src/shared/Models/LotLook.luau")
	assert(ok, LotLook)
	LotLook.build(folder, roblox.CFrame.new(), 1, progress)
end

function scenes.lotEmpty(folder, load, roblox)
	lot(folder, load, roblox, nil)
end

function scenes.lotStarter(folder, load, roblox)
	lot(folder, load, roblox, { stages = 1, cinema = 0, office = 0, trophies = 0, filming = {}, star = "NervousIntern", variant = "Normal" })
end

function scenes.lotMid(folder, load, roblox)
	lot(folder, load, roblox, { stages = 2, cinema = 3, office = 2, trophies = 2, filming = { true }, star = "SpaceCaptain", variant = "Shiny" })
end

function scenes.lotMax(folder, load, roblox)
	lot(folder, load, roblox, { stages = 5, cinema = 6, office = 5, trophies = 7, filming = { true, false, true, true, true }, star = "PhantomAuteur", variant = "Award" })
end

-- The menu button icons in a row (arg: one icon id to show just that one).
function scenes.icons(folder, load, roblox, arg)
	local IconModels = load("src/shared/Models/IconModels.luau")
	local ids = if arg ~= nil and arg ~= "" then { arg } else IconModels.Ids
	for i, id in ids do
		IconModels.build(folder, id, roblox.CFrame.new((i - (#ids + 1) / 2) * 5, 0, 0))
	end
end

-- The whole town: the six lots at mixed progress (placed the way LotService places them), plus
-- the boulevard, plaza, paths and store stands from MapModels.
function scenes.map(folder, load)
	local LotLook = load("src/shared/Models/LotLook.luau")
	local MapModels = load("src/shared/Models/MapModels.luau")
	local levels = {
		nil,
		{ stages = 1, cinema = 0, office = 0, trophies = 0, filming = {}, star = "NervousIntern", variant = "Normal" },
		{ stages = 2, cinema = 2, office = 1, trophies = 1, filming = { true }, star = "ActionVeteran", variant = "Normal" },
		{ stages = 3, cinema = 4, office = 3, trophies = 3, filming = { true, true }, star = "ScreamQueen", variant = "Shiny" },
		{ stages = 4, cinema = 5, office = 4, trophies = 5, filming = { false, true }, star = "SciFiVisionary", variant = "Normal" },
		{ stages = 5, cinema = 6, office = 5, trophies = 9, filming = { true, true, true, true, true }, star = "MogulsMuse", variant = "Award" },
	}
	for index = 1, 6 do
		LotLook.build(folder, MapModels.lotBase(index), index, levels[index])
	end
	MapModels.build(folder)
end

return scenes
