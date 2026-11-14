--!strict
-- Pure fit maths for showing an actor figure in a fixed space (Rare Wall plinth, lot pedestal).
local ActorFit = {}

-- Tallest a figure may be at scale 1 (studs). The Golden Age Diva is the tallest normal actor (8.27); only the
-- Wobbly Witch (9.85), Cardboard Astronaut (8.86) and Time Tourist (8.38) are taller and get clamped.
ActorFit.MaxHeight = 8.3

-- The scale factor (<= 1, never grows a figure) that makes a figure of `width` x `height` studs fit inside
-- `maxWidth` x `maxHeight`. A limit of nil (or 0 for a measured size) is ignored.
function ActorFit.shrink(width: number, height: number, maxWidth: number?, maxHeight: number?): number
	local k = 1
	if maxWidth ~= nil and width > maxWidth and width > 0 then
		k = math.min(k, maxWidth / width)
	end
	if maxHeight ~= nil and height > maxHeight and height > 0 then
		k = math.min(k, maxHeight / height)
	end
	return k
end

-- Height of `model`'s highest part above its feet (the frame's origin), so a hovering figure (Kapow, Phantom) counts
-- its hover gap too.
function ActorFit.heightOf(model: Model, frame: CFrame): number
	local lo, hi = math.huge, -math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = frame:ToObjectSpace(part.CFrame)
			local half = part.Size / 2
			local reach = math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z
			lo = math.min(lo, cf.Position.Y - reach)
			hi = math.max(hi, cf.Position.Y + reach)
		end
	end
	return if hi > lo then math.max(hi, 0) else 0
end

-- Sideways size (along `frame`'s X) of every part of `model`.
function ActorFit.widthOf(model: Model, frame: CFrame): number
	local lo, hi = math.huge, -math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = frame:ToObjectSpace(part.CFrame)
			local half = part.Size / 2
			local reach = math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z
			lo = math.min(lo, cf.Position.X - reach)
			hi = math.max(hi, cf.Position.X + reach)
		end
	end
	return if hi > lo then hi - lo else 0
end

return ActorFit
