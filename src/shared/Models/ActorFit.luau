--!strict
-- Pure fit maths for showing an actor figure in a fixed space (Rare Wall plinth, lot pedestal).
local ActorFit = {}

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

-- Vertical size of every part of `model` (any axis-turned part counted by its full Y reach).
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
	return if hi > lo then hi - lo else 0
end

return ActorFit
