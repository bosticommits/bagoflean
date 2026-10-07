--!strict
-- Puts the lot pieces together: the fixed scenery every lot has, plus the parts that change with
-- the owner's progress. LotService rebuilds each changing section only when its inputs change;
-- the preview tool (art/preview) calls build() to draw a whole lot at once.
local Actors = require(script.Parent.Parent.Actors)
local ActorModels = require(script.Parent.ActorModels)
local Build = require(script.Parent.Build)
local LotModels = require(script.Parent.LotModels)

local L = LotModels.Layout
local P = Build.Palette

local LotLook = {}

LotLook.MaxTrophiesShown = 5
LotLook.cinemaTier = LotModels.cinemaTier

-- What a lot shows. nil progress means an unclaimed lot.
export type Progress = {
	stages: number,
	cinema: number, -- Cinema Size upgrade level
	office: number, -- Offline Earnings upgrade level
	trophies: number,
	filming: { [number]: boolean }, -- stage number -> a movie is filming there
	star: string?, -- the owner's rarest actor id
	variant: string?,
}

export type Static = {
	claimPad: Part,
	collectPad: Part,
	billboard: BasePart,
	cinemaAnchor: Part,
}

local function at(base: CFrame, p: Vector3): CFrame
	return base * CFrame.new(p)
end

-- Scenery and gameplay pads that never change. Pads and the "Cinema" anchor go straight under
-- `model` (the tutorial and effects look them up by name).
function LotLook.static(model: Model, base: CFrame, lotNumber: number, accent: Color3): Static
	local scenery = Instance.new("Model")
	scenery.Name = "Scenery"
	scenery.Parent = model
	local b = Build.new(scenery, base)

	local carpetLength = L.size / 2 + L.cinemaFront
	LotModels.ground(b, L.size, carpetLength)
	LotModels.hedges(b, L.size, L.gateGap)
	LotModels.gate(b:sub(Vector3.new(0, 1, L.gateZ)), L.gateGap, lotNumber)
	for _, p in L.palms do
		LotModels.palm(b:sub(p + Vector3.new(0, 1, 0)), 15, 7)
	end
	for _, p in L.lamps do
		LotModels.lamp(b:sub(p + Vector3.new(0, 1, 0)))
	end
	LotModels.ticketKiosk(b:sub(L.kiosk + Vector3.new(0, 1, 0)))
	LotModels.stanchions(b:sub(Vector3.new(0, 1, 0)), L.stanchionFromZ, L.stanchionToZ, L.stanchionX)
	local billboard = LotModels.billboard(b:sub(L.billboard + Vector3.new(0, 1, 0)))

	local pads = Build.new(model, base)
	local claimPad = pads:block("ClaimPad", Vector3.new(10, 0.4, 8), L.claimPad + Vector3.new(0, 1.4, 0), Color3.fromRGB(60, 200, 90), Enum.Material.Neon)
	local collectPad = pads:block("CollectPad", Vector3.new(8, 0.4, 8), L.collectPad + Vector3.new(0, 1.4, 0), P.Gold, Enum.Material.Neon)
	-- Invisible marker over the cinema: celebrations play above it.
	local cinemaAnchor = pads:block("Cinema", Vector3.new(20, 16, 14), Vector3.new(0, 9, L.cinemaFront + 7), P.Cream)
	cinemaAnchor.Transparency = 1
	cinemaAnchor.CanCollide = false
	cinemaAnchor.CanQuery = false
	cinemaAnchor.CanTouch = false
	return {
		claimPad = claimPad,
		collectPad = collectPad,
		billboard = billboard,
		cinemaAnchor = cinemaAnchor,
	}
end

function LotLook.stages(parent: Instance, base: CFrame, progress: Progress?, accent: Color3)
	local count = if progress ~= nil then progress.stages else 1
	for i = 1, math.min(count, #L.stages) do
		local b = Build.new(parent, at(base, L.stages[i] + Vector3.new(0, 1, 0)))
		LotModels.soundStage(b, i, {
			owned = progress ~= nil,
			accent = accent,
			filming = progress ~= nil and progress.filming[i] == true,
		})
		if progress ~= nil then
			-- A film camera out front, on the side nearer the middle of the lot.
			local inward = if L.stages[i].X > 0 then -4 else 4
			LotModels.filmCamera(Build.new(parent, at(base, L.stages[i] + Vector3.new(inward, 1, -9.4))))
		end
	end
end

-- Returns the marquee label.
function LotLook.cinema(parent: Instance, base: CFrame, level: number, accent: Color3): TextLabel
	local b = Build.new(parent, at(base, Vector3.new(0, 1, L.cinemaFront)))
	return LotModels.cinema(b, LotModels.cinemaTier(level), accent)
end

function LotLook.office(parent: Instance, base: CFrame, level: number, accent: Color3)
	LotModels.office(Build.new(parent, at(base, L.office + Vector3.new(0, 1, 0))), level, accent)
end

-- Trophy cabinet; returns its base part (nil when there are no trophies).
function LotLook.trophies(parent: Instance, base: CFrame, count: number): BasePart?
	if count <= 0 then
		return nil
	end
	local b = Build.new(parent, at(base, L.trophyCase + Vector3.new(0, 1, 0)))
	LotModels.trophyCase(b, math.min(count, LotLook.MaxTrophiesShown))
	return parent:FindFirstChild("CaseBase") :: BasePart?
end

-- The owner's top star on a pedestal by the red carpet (an empty, grey pedestal when none).
function LotLook.star(parent: Instance, base: CFrame, actorId: string?, variantId: string?): BasePart
	local b = Build.new(parent, at(base, L.pedestal + Vector3.new(0, 1, 0)))
	local actor = if actorId ~= nil then Actors.getActor(actorId) else nil
	local tier = if actor ~= nil then Actors.getTier(actor.tier) else nil
	local rank = 0
	if tier ~= nil then
		for i, t in Actors.Tiers do
			if t.id == tier.id then
				rank = i
			end
		end
	end
	local color = if tier ~= nil then tier.color else P.Grey
	local rare = rank >= 4 -- Star and up glow
	local ring = LotModels.pedestal(b, color, rare)
	if actor ~= nil then
		local figureBase = b:at(Vector3.new(0, 1.6, 0))
		ActorModels.build(parent, figureBase, actor.id, variantId, 1.3)
		if rare then
			ActorModels.aura(Build.new(parent, figureBase), color)
		end
	end
	return ring
end

-- Everything at once (used by the preview tool).
function LotLook.build(folder: Instance, base: CFrame, lotNumber: number, progress: Progress?)
	local accent = P.Carpet
	local model = Instance.new("Model")
	model.Name = "Lot" .. lotNumber
	model.Parent = folder
	LotLook.static(model, base, lotNumber, accent)
	LotLook.stages(model, base, progress, accent)
	LotLook.cinema(model, base, if progress ~= nil then progress.cinema else 0, accent)
	LotLook.office(model, base, if progress ~= nil then progress.office else 0, accent)
	if progress ~= nil then
		LotLook.trophies(model, base, progress.trophies)
	end
	LotLook.star(model, base, if progress ~= nil then progress.star else nil, if progress ~= nil then progress.variant else nil)
end

return LotLook
