--!strict
-- Turns the town's sky through the day (Shared/DayNight: the same on every server). After dark the
-- lamps and signs glow brighter, the searchlights sweep the sky and a soft blue tint keeps the night
-- dusky, never black. MapService sets the base look; AreaMood's area tint adds on top.
--
-- Special events own the sky while they run: Golden Hour and the Pumpkin Patch put their own
-- "SpecialEventTint" in Lighting and set the clock themselves, so the cycle waits until that is
-- gone, then eases the clock back to the time of day. Lamps and the tint follow whatever clock the
-- sky shows, so they stay right during events too. Only this player's screen changes.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DayNight = require(ReplicatedStorage.Shared.DayNight)

local DayNightWorld = {}

local TICK = 0.1 -- seconds between sky updates
local SWEEP_STEP = 1 / 20 -- seconds between searchlight moves (only after dark)
local HANDBACK = 0.06 -- share of the gap the clock closes each tick after an event
local NIGHT_TINT = Color3.fromRGB(196, 210, 255)
local NIGHT_AMBIENT = Color3.fromRGB(118, 128, 178)
local NIGHT_SHIFT = Color3.fromRGB(150, 175, 255)
local LIGHT_DAY, LIGHT_NIGHT = 0.6, 1.6 -- lamp brightness, times its own
local BEAM_DAY, BEAM_NIGHT = 0.8, 0.5 -- searchlight beam transparency
local SWEEP = math.rad(18)

local darkness = 0

-- 0 in daylight to 1 at night, for other modules (TownLife's premiere lights).
function DayNightWorld.darkness(): number
	return darkness
end

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function DayNightWorld.start()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "DayNightTint"
	tint.Parent = Lighting
	local base = {
		brightness = Lighting.Brightness,
		ambient = Lighting.OutdoorAmbient,
		shift = Lighting.ColorShift_Top,
	}

	-- Lamps and searchlight beams on the map and the lots, with their own brightness.
	local lights: { [Light]: number } = {}
	local beams: { [BasePart]: CFrame } = {}
	local function found(item: Instance)
		if item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
			if lights[item] == nil then
				lights[item] = item.Brightness
				item.Brightness = item.Brightness * lerpNumber(LIGHT_DAY, LIGHT_NIGHT, darkness)
			end
		elseif item.Name == "SearchlightBeam" and item:IsA("BasePart") and beams[item] == nil then
			beams[item] = item.CFrame
		end
	end
	local function watch(folder: Instance)
		for _, item in folder:GetDescendants() do
			found(item)
		end
		folder.DescendantAdded:Connect(found)
		folder.DescendantRemoving:Connect(function(item)
			lights[item :: any] = nil
			beams[item :: any] = nil
		end)
	end
	task.spawn(function()
		for _, name in { "Town", "Lots" } do
			local folder = Workspace:WaitForChild(name, 60)
			if folder ~= nil then
				watch(folder)
			end
		end
	end)

	local shown = -1
	local function apply(n: number)
		darkness = n
		-- Small steps are skipped (lamps are many), but full day and full night always land.
		if n == shown or (math.abs(n - shown) < 0.01 and n > 0 and n < 1) then
			return
		end
		shown = n
		Lighting.Brightness = lerpNumber(base.brightness, base.brightness * 0.6, n)
		Lighting.OutdoorAmbient = base.ambient:Lerp(NIGHT_AMBIENT, n)
		Lighting.ColorShift_Top = base.shift:Lerp(NIGHT_SHIFT, n)
		tint.TintColor = Color3.new(1, 1, 1):Lerp(NIGHT_TINT, n)
		tint.Brightness = 0.05 * n
		tint.Saturation = 0.08 * n
		local scale = lerpNumber(LIGHT_DAY, LIGHT_NIGHT, n)
		for light, brightness in lights do
			light.Brightness = brightness * scale
		end
		for beam in beams do
			beam.Transparency = lerpNumber(BEAM_DAY, BEAM_NIGHT, n)
		end
	end

	local first = true
	task.spawn(function()
		while true do
			local clock = DayNight.at(Workspace:GetServerTimeNow())
			if Lighting:FindFirstChild("SpecialEventTint") == nil then
				local gap = (clock - Lighting.ClockTime + 12) % 24 - 12
				Lighting.ClockTime = if first or math.abs(gap) < 0.1 then clock else (Lighting.ClockTime + gap * HANDBACK) % 24
				first = false
			end
			apply(DayNight.darkness(Lighting.ClockTime))
			task.wait(TICK)
		end
	end)

	-- Searchlights sway side to side round their drums after dark; back to rest by day.
	local wait = 0
	local resting = true
	RunService.Heartbeat:Connect(function(dt)
		wait -= dt
		if wait > 0 then
			return
		end
		wait = SWEEP_STEP
		if darkness < 0.2 then
			if not resting then
				resting = true
				for beam, rest in beams do
					beam.CFrame = rest
				end
			end
			return
		end
		resting = false
		local t = os.clock()
		for beam, rest in beams do
			local drum = (rest * CFrame.new(0, -21.7, 0)).Position -- LotModels.searchlight's drum pivot
			local phase = drum.X * 0.05 + drum.Z * 0.03
			local turn = CFrame.Angles(0, math.sin(t * 0.5 + phase) * SWEEP * darkness, 0)
			beam.CFrame = CFrame.new(drum) * turn * CFrame.new(-drum) * rest
		end
	end)
end

return DayNightWorld
