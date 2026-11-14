--!strict
-- Gives every lot billboard portrait its Camera. The server builds the figure inside the ViewportFrame but a Camera
-- made there never reaches clients, so the portrait stays blank; the server stores the framing as attributes (see
-- PortraitCamera) and this builds the Camera locally. Covers billboards that stream in late and a top actor that changes
-- (the server rebuilds the viewport, or just rewrites its attributes).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PortraitCamera = require(ReplicatedStorage.Shared.PortraitCamera)

local LotPortraits = {}

local function watch(viewport: Instance)
	if not viewport:IsA("ViewportFrame") then
		return
	end
	PortraitCamera.apply(viewport)
	-- Attributes can land after the tag, and change when the top actor does.
	viewport:GetAttributeChangedSignal("PortraitTargetY"):Connect(function()
		PortraitCamera.apply(viewport)
	end)
	viewport:GetAttributeChangedSignal("PortraitDistance"):Connect(function()
		PortraitCamera.apply(viewport)
	end)
end

function LotPortraits.start()
	CollectionService:GetInstanceAddedSignal(PortraitCamera.Tag):Connect(watch)
	for _, viewport in CollectionService:GetTagged(PortraitCamera.Tag) do
		watch(viewport)
	end
end

return LotPortraits
