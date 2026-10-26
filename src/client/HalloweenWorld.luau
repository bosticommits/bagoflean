--!strict
-- Fright Night decor (each player's own copy): while the FrightNight season runs
-- (SpecialEvents.seasonAt, the same weeks as its festival and limited actor), jack-o'-lanterns,
-- hay bales, candy buckets and two scarecrows stand round the plaza, the lot gates and the
-- boulevard lamps, and a light purple haze tints the town. Models come from
-- art/blender/halloween_kit.py through MapKit (meshes once imported, parts until then). All of it
-- is decoration: nothing collides or blocks clicks, and only the four plaza pumpkins carry a light.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Models.Build)
local MapKit = require(ReplicatedStorage.Shared.Models.MapKit)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local SpecialEvents = require(ReplicatedStorage.Shared.SpecialEvents)

local HalloweenWorld = {}

local SEASON = "FrightNight"
local CHECK_EVERY = 60 -- seconds
local LAWN_Y = 0.34 -- the lawns along the lot fronts (MapModels)
local PLAZA_Y = 0.48
local SIDEWALK_Y = 0.2
local GLOW = { range = 12, brightness = 1.2, color = Color3.fromRGB(255, 170, 70) }

type Piece = { name: string, at: Vector3, yaw: number, scale: number?, light: boolean? }

-- Where everything stands. Kit models face -Z; yaw turns them (radians).
local function layout(): { Piece }
	local pieces: { Piece } = {}
	local function add(name: string, x: number, y: number, z: number, yaw: number, scale: number?, light: boolean?)
		table.insert(pieces, { name = name, at = Vector3.new(x, y, z), yaw = yaw, scale = scale, light = light })
	end
	-- Plaza: a big jack-o'-lantern beside each palm planter on the diagonals, grinning at the fountain.
	local radius = MapModels.Layout.plazaRadius - 4
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90 + 14)
		local x, z = math.sin(angle) * radius, -math.cos(angle) * radius
		add("JackOLantern", x, PLAZA_Y, z, math.atan2(x, z), 1, true)
	end
	-- Lot gates: on the lawns either side of each gate, facing the boulevard.
	for index = 1, 6 do
		local center = MapModels.lotBase(index).Position
		local side = if center.Z < 0 then -1 else 1
		local z = side * 41
		local yaw = if side < 0 then math.pi else 0
		add("JackOLantern", center.X - 9, LAWN_Y, z, yaw + 0.2)
		add("PumpkinPlain", center.X - 12, LAWN_Y, z + side * 1.5, yaw)
		add("HayBale", center.X + 10, LAWN_Y, z, yaw)
		add("CandyBucket", center.X + 8.6, LAWN_Y + 1.8, z, yaw - 0.3)
		if center.X == 0 then
			add("Scarecrow", 20, LAWN_Y, side * 43, yaw - 0.15)
		end
	end
	-- Boulevard: small jack-o'-lanterns at the feet of the lamps by the plaza ends.
	for _, x in { 32, 80 } do
		for _, dir in { -1, 1 } do
			for _, side in { -1, 1 } do
				add("JackOLanternSmall", dir * x + 1.8, SIDEWALK_Y, side * 12.4, if side < 0 then math.pi else 0, 0.8)
			end
		end
	end
	return pieces
end

local folder: Folder? = nil
local tint: ColorCorrectionEffect? = nil
local airWas: Color3? = nil

local function build()
	local root = Instance.new("Folder")
	root.Name = "FrightNightDecor"
	for _, piece in layout() do
		local b = Build.new(root, CFrame.new(piece.at) * CFrame.Angles(0, piece.yaw, 0))
		local model = MapKit.place(b, piece.name, CFrame.identity, { scale = piece.scale, solid = false, light = if piece.light then GLOW else nil })
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
	end
	root.Parent = workspace
	folder = root
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "FrightNightTint"
	effect.TintColor = Color3.fromRGB(250, 242, 255)
	effect.Parent = Lighting
	tint = effect
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if air ~= nil then
		airWas = air.Color
		air.Color = air.Color:Lerp(Color3.fromRGB(200, 160, 230), 0.35)
	end
end

local function clear()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
	if tint ~= nil then
		tint:Destroy()
		tint = nil
	end
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if air ~= nil and airWas ~= nil then
		air.Color = airWas
	end
	airWas = nil
end

function HalloweenWorld.start()
	task.spawn(function()
		while true do
			local season = SpecialEvents.seasonAt(workspace:GetServerTimeNow())
			local on = season ~= nil and season.id == SEASON
			if on and folder == nil then
				local ok, err = pcall(build)
				if not ok then
					warn(`[HalloweenWorld] {err}`)
				end
			elseif not on and folder ~= nil then
				clear()
			end
			task.wait(CHECK_EVERY)
		end
	end)
end

return HalloweenWorld
