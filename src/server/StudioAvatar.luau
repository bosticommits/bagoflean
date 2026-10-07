--!strict
-- The owner's avatar towering over the back of their studio, like the reference games' plots: the
-- player's own look, many times life size, shown from the waist up and fading out toward the
-- bottom, with their name in big letters over the head. Everyone on the server sees whose studio
-- is whose from across the town.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLabel = require(ReplicatedStorage.Shared.WorldLabel)

local StudioAvatar = {}

local SCALE = 6.5
-- Lot space (-Z faces the boulevard): centred behind the cinema, which hides the waist from the
-- street.
local SPOT = Vector3.new(0, 14, 23)
local NAME_HEIGHT = 5 -- studs, over the head

-- How see-through a part is by its height in the body (0 soles, 1 top of the head): solid head and
-- shoulders, fading down the chest, gone below the waist.
local WAIST = 0.48
local function fade(height: number): number
	if height < WAIST - 0.06 then
		return 1
	end
	return math.clamp(0.05 + (0.7 - height) / 0.28 * 0.75, 0.05, 0.85)
end

-- A copy of the player's current look (their character's applied description, so it works for
-- every player, Studio test players included). Nil if Roblox could not build one.
local function figureOf(player: Player): Model?
	local deadline = os.clock() + 30
	while player.Character == nil and player.Parent ~= nil and os.clock() < deadline do
		task.wait(0.5)
	end
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:WaitForChild("Humanoid", 15)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return nil
	end
	local ok, figure = pcall(function()
		local description = humanoid:GetAppliedDescription()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or figure == nil then
		warn(`[MovieMogul] could not build {player.Name}'s studio avatar: {figure}`)
		return nil
	end
	return figure
end

-- Fills `holder` with `player`'s giant avatar and name for the lot at `base`. Yields while Roblox
-- builds the avatar; `stillWanted()` is checked after, so a player who left meanwhile gets nothing.
function StudioAvatar.build(holder: Model, base: CFrame, player: Player, stillWanted: () -> boolean)
	-- The name goes up at once; the figure follows when it is ready.
	local nameAnchor = Instance.new("Part")
	nameAnchor.Name = "NameAnchor"
	nameAnchor.Anchored = true
	nameAnchor.CanCollide = false
	nameAnchor.CanQuery = false
	nameAnchor.CanTouch = false
	nameAnchor.Transparency = 1
	nameAnchor.Size = Vector3.new(1, 1, 1)
	nameAnchor.CFrame = base * CFrame.new(SPOT + Vector3.new(0, 3 * SCALE + NAME_HEIGHT, 0))
	nameAnchor.Parent = holder
	local name = WorldLabel.new(nameAnchor, player.DisplayName, 34, NAME_HEIGHT, {
		color = Color3.fromRGB(255, 214, 64),
		offset = Vector3.new(),
		maxDistance = 400,
		outline = 4,
	})
	name.Name = "OwnerName"

	local figure = figureOf(player)
	if figure == nil then
		return
	end
	if not stillWanted() or holder.Parent == nil then
		figure:Destroy()
		return
	end
	figure.Name = "Avatar"
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.EvaluateStateMachine = false
	end
	for _, d in figure:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
		end
	end
	figure:ScaleTo(SCALE)

	-- Face the boulevard with the waist on the spot, then fade it by height. Heights are measured
	-- on the body alone, so a tall hat does not move the fade.
	local target = base * CFrame.new(SPOT)
	figure:PivotTo(target)
	local low, high = math.huge, -math.huge
	for _, d in figure:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d:FindFirstAncestorOfClass("Accessory") == nil then
			low = math.min(low, d.Position.Y - d.Size.Y / 2)
			high = math.max(high, d.Position.Y + d.Size.Y / 2)
		end
	end
	if low >= high then
		figure:Destroy()
		return
	end
	local tall = high - low
	local shift = target.Position.Y - (low + tall * WAIST)
	figure:PivotTo(figure:GetPivot() + Vector3.new(0, shift, 0))
	low += shift
	local top = -math.huge -- hats included, for the name
	for _, d in figure:GetDescendants() do
		if d:IsA("BasePart") then
			local amount = fade((d.Position.Y - low) / tall)
			if d.Name == "HumanoidRootPart" or amount >= 1 then
				d.Transparency = 1
			else
				d.Transparency = math.max(d.Transparency, amount)
				top = math.max(top, d.Position.Y + d.Size.Y / 2)
			end
			for _, child in d:GetChildren() do
				if child:IsA("Decal") then
					child.Transparency = math.max(child.Transparency, amount)
				end
			end
		end
	end
	figure.Parent = holder
	-- The name sits just over the head.
	nameAnchor.Position = Vector3.new(target.Position.X, top + NAME_HEIGHT * 0.7, target.Position.Z)
end

return StudioAvatar
