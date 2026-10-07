--!strict
-- Visual and sound "moments": rare-pull reveals, premiere results, and lot celebrations.
-- Everything here is client-only presentation. It uses built-in textures (rbxasset://) so it needs
-- no uploaded art, and every effect cleans itself up through Debris.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Actors = require(game:GetService("ReplicatedStorage").Shared.Actors)
local Sfx = require(script.Parent.Sfx)

local CONFETTI_TEXTURE = "rbxasset://textures/particles/SquareParticle.png"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 205, 70),
	Color3.fromRGB(255, 90, 110),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(140, 255, 140),
	Color3.fromRGB(200, 120, 255),
}

local Fx = {}

local fxGui: ScreenGui? = nil
local random = Random.new()

local function overlay(): ScreenGui
	local gui = fxGui
	if gui == nil or gui.Parent == nil then
		gui = Instance.new("ScreenGui")
		gui.Name = "MovieMogulFx"
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 20 -- above the game UI, never blocks input (no Active frames)
		gui.ResetOnSpawn = false
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		fxGui = gui
	end
	return gui :: ScreenGui
end

-- A quick full-screen tint that fades out.
function Fx.flash(color: Color3, strength: number)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - strength
	frame.BorderSizePixel = 0
	frame.Parent = overlay()
	TweenService:Create(frame, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(frame, 0.7)
end

-- Paper confetti falling from the top of the screen. `count` scales with how special the moment is.
function Fx.confetti(count: number, colors: { Color3 }?)
	local palette = colors or CONFETTI_COLORS
	local gui = overlay()
	for _ = 1, count do
		local piece = Instance.new("Frame")
		local size = random:NextInteger(6, 12)
		piece.Size = UDim2.fromOffset(size, size * 1.6)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.new(random:NextNumber(0.1, 0.9), 0, 0, -20)
		piece.Rotation = random:NextNumber(0, 360)
		piece.BackgroundColor3 = palette[random:NextInteger(1, #palette)]
		piece.BorderSizePixel = 0
		piece.Parent = gui
		local duration = random:NextNumber(1.4, 2.4)
		local drift = random:NextNumber(-0.15, 0.15)
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + drift, 0, 1, 40),
			Rotation = piece.Rotation + random:NextNumber(-540, 540),
		}):Play()
		Debris:AddItem(piece, duration + 0.1)
	end
end

local function tierIndex(tierId: string): number
	for index, tier in Actors.Tiers do
		if tier.id == tierId then
			return index
		end
	end
	return 1
end

-- Casting reveal: the rarer the tier and variant, the bigger the moment.
function Fx.castReveal(tierId: string, variantId: string)
	local rank = tierIndex(tierId) -- 1 Newcomer .. 7 Icon
	local tier = Actors.getTier(tierId)
	local color = if tier ~= nil then tier.color else Color3.new(1, 1, 1)
	if rank <= 2 then
		Sfx.play("pop")
	elseif rank <= 4 then
		Sfx.play("stinger")
		Fx.confetti(20 + rank * 5, { color, Color3.new(1, 1, 1) })
	else
		Sfx.play("stinger")
		Sfx.play("jingle")
		Fx.flash(color, 0.5)
		Fx.confetti(70 + rank * 10)
	end
	if variantId == "Shiny" or variantId == "Award" then
		local variant = Actors.getVariant(variantId)
		Sfx.play("stinger", 1.25)
		Fx.confetti(30, { if variant ~= nil then variant.color else Color3.new(1, 1, 1), Color3.new(1, 1, 1) })
	end
end

-- Premiere result: a flop gets a sad whistle, a Masterpiece gets everything.
function Fx.premiere(resultId: string, color: Color3)
	if resultId == "Flop" then
		Sfx.play("low")
	elseif resultId == "Hit" then
		Sfx.play("pop")
	elseif resultId == "Blockbuster" then
		Sfx.play("stinger")
		Fx.confetti(30, { color, Color3.new(1, 1, 1) })
	elseif resultId == "Cult" then
		Sfx.play("stinger")
		Fx.confetti(50, { color, Color3.fromRGB(255, 205, 70) })
	else
		Sfx.play("stinger")
		Sfx.play("jingle")
		Fx.flash(color, 0.6)
		Fx.confetti(140)
	end
end

local function emitter(parent: Instance, texture: string, colors: { Color3 }, speed: NumberRange, lifetime: NumberRange, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Rate = 0 -- burst only, through :Emit()
	e.Speed = speed
	e.Lifetime = lifetime
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, -18, 0)
	e.Drag = 1.5
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new(size)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = 0.3
	local keypoints = {}
	for index, c in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), c))
	end
	e.Color = if #keypoints >= 2 then ColorSequence.new(keypoints) else ColorSequence.new(colors[1])
	e.Parent = parent
	return e
end

-- Red-carpet celebration over a lot, seen by everyone on the server.
-- "masterpiece": fireworks and confetti for ~6 s. "pull": a shorter sparkle burst.
function Fx.celebrate(lotIndex: number, kind: string)
	local lots = workspace:FindFirstChild("Lots")
	local lot = if lots ~= nil then lots:FindFirstChild("Lot" .. lotIndex) else nil
	local cinema = if lot ~= nil then lot:FindFirstChild("Cinema") else nil
	if cinema == nil or not cinema:IsA("BasePart") then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "CelebrationFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = cinema.Position + Vector3.new(0, cinema.Size.Y / 2 + 6, 0)
	anchor.Parent = workspace

	local masterpiece = kind == "masterpiece"
	local confetti = emitter(anchor, CONFETTI_TEXTURE, CONFETTI_COLORS, NumberRange.new(25, 45), NumberRange.new(2.5, 4), 0.6)
	local sparkles = emitter(anchor, SPARKLE_TEXTURE, { Color3.fromRGB(255, 230, 140), Color3.new(1, 1, 1) }, NumberRange.new(10, 30), NumberRange.new(1, 2), 2)
	sparkles.LightEmission = 1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Range = 40
	light.Brightness = 0
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Brightness = if masterpiece then 6 else 3 }):Play()

	local bursts = if masterpiece then 9 else 3
	task.spawn(function()
		for _ = 1, bursts do
			if anchor.Parent == nil then
				return
			end
			confetti:Emit(if masterpiece then 80 else 40)
			sparkles:Emit(if masterpiece then 30 else 15)
			task.wait(0.6)
		end
	end)
	Debris:AddItem(anchor, bursts * 0.6 + 4.5)
end

function Fx.start(remotes: Instance)
	local celebrateRemote = remotes:WaitForChild("Celebrate", 10)
	if celebrateRemote == nil or not celebrateRemote:IsA("RemoteEvent") then
		warn("[Fx] Celebrate remote never arrived")
		return
	end
	celebrateRemote.OnClientEvent:Connect(function(lotIndex, kind)
		if type(lotIndex) == "number" and type(kind) == "string" then
			Fx.celebrate(lotIndex, kind)
		end
	end)
end

return Fx
