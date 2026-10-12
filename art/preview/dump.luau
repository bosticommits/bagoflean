--[[
Runs the code-built models outside Roblox with Lune and dumps every part to JSON, so
render.py can draw a preview without opening Studio.

  lune run art/preview/dump.luau <scene> <out.json> [arg]

Scenes are listed in SCENES below. Run from the repo root.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Instance = roblox.Instance

-- Load a src/shared module with a fake `script` so `require(script.Parent.X)` works.
local loaded = {}
local function load(path: string): any
	if loaded[path] then
		return loaded[path]
	end
	local dir = string.match(path, "^(.*)/[^/]+$")
	local function folder(d: string): any
		return setmetatable({}, {
			__index = function(_, name)
				if name == "Parent" then
					return folder(string.match(d, "^(.*)/[^/]+$") or "")
				end
				return { __path = d .. "/" .. name .. ".luau" }
			end,
		})
	end
	local parent = folder(dir)
	local env: { [string]: any } = {}
	for k, v in roblox :: any do
		env[k] = v
	end
	env.script = { Parent = parent }
	env.require = function(target)
		return load(target.__path)
	end
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = chunk()
	loaded[path] = result
	return result
end

local function dumpParts(root): { any }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local cf = d.CFrame
			local shape = "Block"
			if d.ClassName == "WedgePart" then
				shape = "Wedge"
			elseif d.ClassName == "CornerWedgePart" then
				shape = "CornerWedge"
			elseif d.ClassName == "Part" then
				shape = d.Shape.Name
				local mesh = d:FindFirstChildWhichIsA("SpecialMesh")
				if mesh ~= nil and mesh.MeshType == roblox.Enum.MeshType.Sphere then
					shape = "Ellipsoid" -- a block wearing a sphere mesh (the mascots)
				end
			end
			table.insert(out, {
				name = d.Name,
				shape = shape,
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				cframe = { cf:GetComponents() },
				color = { d.Color.R, d.Color.G, d.Color.B },
				material = d.Material.Name,
				transparency = d.Transparency,
			})
		end
	end
	return out
end

local scene, outPath = process.args[1], process.args[2]
local folder = Instance.new("Folder")
local scenes = load("art/preview/scenes.luau")
local fn = scenes[scene]
assert(fn, "unknown scene " .. tostring(scene))
fn(folder, load, roblox, process.args[3])
local parts = dumpParts(folder)
fs.writeFile(outPath, serde.encode("json", parts))
print(`{scene}: {#parts} parts`)
