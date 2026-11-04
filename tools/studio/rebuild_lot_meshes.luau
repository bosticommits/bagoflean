--!strict
-- Run this file from Roblox Studio's Command Bar after Rojo has synced the project.
-- It stages and validates every mesh before replacing ReplicatedStorage.LotMeshes.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local shared = ReplicatedStorage:FindFirstChild("Shared")
assert(shared ~= nil, "Rojo has not synced ReplicatedStorage.Shared")
local manifestModule = shared:FindFirstChild("LotMeshManifest")
assert(manifestModule ~= nil and manifestModule:IsA("ModuleScript"), "LotMeshManifest is missing; sync Rojo first")

local manifest = require(manifestModule)
assert(manifest.version == 1, `Unsupported LotMeshManifest version: {tostring(manifest.version)}`)
assert(#manifest.meshes > 0, "LotMeshManifest has no mesh entries")

type CollisionFidelity = typeof(Enum.CollisionFidelity.Default)
type RenderFidelity = typeof(Enum.RenderFidelity.Automatic)
type Material = typeof(Enum.Material.Plastic)

local COLLISION_FIDELITIES: { [string]: CollisionFidelity } = {
	Default = Enum.CollisionFidelity.Default,
	Box = Enum.CollisionFidelity.Box,
	Hull = Enum.CollisionFidelity.Hull,
	PreciseConvexDecomposition = Enum.CollisionFidelity.PreciseConvexDecomposition,
	Tunable = Enum.CollisionFidelity.Tunable,
}
local RENDER_FIDELITIES: { [string]: RenderFidelity } = {
	Automatic = Enum.RenderFidelity.Automatic,
	Performance = Enum.RenderFidelity.Performance,
	Precise = Enum.RenderFidelity.Precise,
}
local MATERIALS: { [string]: Material } = {
	Plastic = Enum.Material.Plastic,
	SmoothPlastic = Enum.Material.SmoothPlastic,
}

local staging = Instance.new("Folder")
staging.Name = "LotMeshes__Staging_" .. HttpService:GenerateGUID(false)

local groups: { [string]: Model? } = {}
local names: { [string]: boolean } = {}
local created = 0

local function parentFor(entry): Instance
	if entry.group == "" then
		return staging
	end
	local group = groups[entry.group]
	if group ~= nil then
		return group
	end
	local newGroup = Instance.new("Model")
	newGroup.Name = entry.group
	newGroup.Parent = staging
	groups[entry.group] = newGroup
	return newGroup
end

local function buildStaging()
	for index, entry in manifest.meshes do
		assert(type(entry.name) == "string" and entry.name ~= "", "Manifest entry has an invalid name")
		assert(not names[entry.name], `Duplicate mesh name in manifest: {entry.name}`)
		names[entry.name] = true
		assert(type(entry.assetId) == "number" and entry.assetId > 0, `Invalid asset ID for {entry.name}`)
		assert(type(entry.size) == "table" and #entry.size == 3, `Invalid size for {entry.name}`)

		local collisionFidelity = COLLISION_FIDELITIES[entry.collisionFidelity]
		local renderFidelity = RENDER_FIDELITIES[entry.renderFidelity]
		local material = MATERIALS[entry.material]
		assert(collisionFidelity ~= nil, `Invalid collision fidelity for {entry.name}`)
		assert(renderFidelity ~= nil, `Invalid render fidelity for {entry.name}`)
		assert(material ~= nil, `Invalid material for {entry.name}`)

		local part = AssetService:CreateMeshPartAsync(Content.fromAssetId(entry.assetId), {
			CollisionFidelity = collisionFidelity,
			RenderFidelity = renderFidelity,
		})
		part.Name = entry.name
		part.Size = Vector3.new(entry.size[1], entry.size[2], entry.size[3])
		part.Color = Color3.fromRGB(entry.color[1], entry.color[2], entry.color[3])
		part.Material = material
		part.MaterialVariant = entry.materialVariant
		part.TextureID = entry.textureId
		part.Transparency = entry.transparency
		part.Reflectance = entry.reflectance
		part.Anchored = entry.anchored
		part.CanCollide = entry.canCollide
		part.CanTouch = entry.canTouch
		part.CanQuery = entry.canQuery
		part.CastShadow = entry.castShadow
		part.DoubleSided = entry.doubleSided

		local actualId = tonumber(tostring(part.MeshId):match("%d+"))
		assert(actualId == entry.assetId, `Mesh ID mismatch for {entry.name}: expected {entry.assetId}, got {tostring(part.MeshId)}`)
		part.Parent = parentFor(entry)
		created += 1

		if index % 8 == 0 then
			task.wait()
		end
	end
	assert(created == #manifest.meshes, `Built {created} of {#manifest.meshes} manifest entries`)
	return true
end

local ok, buildError = pcall(buildStaging)
if not ok then
	staging:Destroy()
	error(`LotMeshes rebuild stopped before replacing the existing folder: {tostring(buildError)}`)
end

local current = ReplicatedStorage:FindFirstChild("LotMeshes")
if current ~= nil and not current:IsA("Folder") then
	staging:Destroy()
	error("ReplicatedStorage.LotMeshes exists but is not a Folder; existing content was left untouched")
end

local backup: Instance? = nil
if current ~= nil then
	local backupRoot = ServerStorage:FindFirstChild("LotMeshesBackup")
	if backupRoot ~= nil and not backupRoot:IsA("Folder") then
		staging:Destroy()
		error("ServerStorage.LotMeshesBackup exists but is not a Folder; existing content was left untouched")
	end
	if backupRoot == nil then
		backupRoot = Instance.new("Folder")
		backupRoot.Name = "LotMeshesBackup"
		backupRoot.Parent = ServerStorage
	end
	current.Name = "LotMeshes_" .. os.date("!%Y%m%d_%H%M%S")
	current.Parent = backupRoot
	backup = current
end

staging.Name = "LotMeshes"
staging.Parent = ReplicatedStorage

if staging.Parent ~= ReplicatedStorage then
	if backup ~= nil then
		backup.Name = "LotMeshes"
		backup.Parent = ReplicatedStorage
	end
	staging:Destroy()
	error("Could not install rebuilt LotMeshes; previous folder was restored when available")
end

print(`LotMeshes rebuilt successfully: {created} mesh parts from manifest v{manifest.version}`)
if backup ~= nil then
	print(`Previous folder preserved at ServerStorage.LotMeshesBackup.{backup.Name}`)
end
