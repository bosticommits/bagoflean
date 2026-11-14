--!strict
-- Camera for the lot billboard's actor portrait (a ViewportFrame on a SurfaceGui). Cameras do not replicate, so the
-- server works the framing out, stores it as attributes on the ViewportFrame and tags it; every client builds its own
-- Camera from those attributes (src/client/LotPortraits.luau).
local PortraitCamera = {}

PortraitCamera.Tag = "LotPortrait"
PortraitCamera.FieldOfView = 30
PortraitCamera.Aspect = 0.63 -- the viewport is 0.34 x 0.88 of the billboard: 4.42 wide by 7.04 tall studs
PortraitCamera.MinDistance = 13.3
PortraitCamera.Direction = Vector3.new(-3, 0.8, -13).Unit

-- Where to aim and how far back to stand, for a figure whose bounding box spans `bottom`..`top` high and `width` wide.
-- Normal figures (up to 5.6 tall, 3.4 wide) keep the original framing; the tall actors (up to ~11 studs) would be cut
-- off by a fixed frame.
function PortraitCamera.fit(top: number, bottom: number, width: number): (number, number)
	local targetY = if top <= 5.6 and bottom >= 0 then 2.8 else (top + bottom) / 2
	local halfHeight = math.max(top - targetY, targetY - bottom, 2.8) * 1.08
	local halfWidth = width / 2 * 1.08
	local tanHalf = math.tan(math.rad(PortraitCamera.FieldOfView / 2))
	local distance = math.max(PortraitCamera.MinDistance, halfHeight / tanHalf, halfWidth / (tanHalf * PortraitCamera.Aspect))
	return targetY, distance
end

-- Server: remember the framing on the viewport (before it is parented, so clients see it with the viewport).
function PortraitCamera.store(viewport: ViewportFrame, targetY: number, distance: number)
	viewport:SetAttribute("PortraitTargetY", targetY)
	viewport:SetAttribute("PortraitDistance", distance)
	viewport:AddTag(PortraitCamera.Tag)
end

-- Client (or server): build a Camera from the stored framing. Returns false until both attributes have arrived.
function PortraitCamera.apply(viewport: ViewportFrame): boolean
	local targetY = viewport:GetAttribute("PortraitTargetY")
	local distance = viewport:GetAttribute("PortraitDistance")
	if type(targetY) ~= "number" or type(distance) ~= "number" then
		return false
	end
	local camera = viewport.CurrentCamera
	if camera == nil then
		camera = Instance.new("Camera")
		camera.Parent = viewport
		viewport.CurrentCamera = camera
	end
	local target = Vector3.new(0, targetY, 0)
	camera.FieldOfView = PortraitCamera.FieldOfView
	camera.CFrame = CFrame.lookAt(target + PortraitCamera.Direction * distance, target)
	return true
end

return PortraitCamera
