--[[
Plays each mascot's animations outside Roblox (with Lune) and writes every piece's transform per
frame to JSON, so art/preview/mascot_moves.py can render them with the real Blender meshes.

  lune run art/preview/mascot_moves.luau <out.json>

The little routine (trot, slow down, crouch, jump, land, look around) copies what
src/client/MascotWorld.luau does in the game, using the same MascotRig code for the pieces.
Run from the repo root.
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local H = require("../../tests/luau/harness")
local Mascots = H.require("Mascots")
local MascotModels = H.require("Models/MascotModels")
local MascotRig = H.require("Models/MascotRig")

local CFrame = roblox.CFrame
local FPS = 30
local SECONDS = 5

local function flat(cf: any): { number }
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

local out = {}
for _, mascot in Mascots.List do
	local folder = roblox.Instance.new("Folder")
	local model = MascotModels.build(folder, mascot.id)
	local rig = MascotRig.new(model, mascot.id, CFrame.identity, 1)
	assert(rig ~= nil)
	local hover = mascot.hover == true
	local gravity = if hover then 60 else 150
	local hop = if hover then 2.6 else 4.2
	local pose = MascotRig.pose()
	local y, vy, grounded = 0, 0, true
	local jumpAt, landedAt, seenLand = 2.2, -math.huge, -math.huge
	local jiggleV, speed = 0, 0
	local clapAt = 4.0
	local frames = {}
	local dt = 1 / FPS
	for frame = 0, FPS * SECONDS - 1 do
		local now = frame * dt
		-- Trot, then slow down and stop before the jump.
		local want = if now < 1.6 then 12 else 0
		speed += (want - speed) * (1 - math.exp(-6 * dt))
		if jumpAt ~= nil and now >= jumpAt + 0.12 then
			vy = math.sqrt(2 * gravity * hop)
			grounded = false
			jumpAt = nil
		end
		if not grounded then
			vy -= gravity * dt
			y += vy * dt
			if vy <= 0 and y <= 0 then
				y, vy, grounded, landedAt = 0, 0, true, now
			end
		end
		-- The pose, as MascotWorld.animate works it out.
		pose.time += dt
		pose.move += (math.clamp(speed / 8, 0, 1) - pose.move) * (1 - math.exp(-8 * dt))
		pose.gait += speed / 3.2 * 2 * math.pi * dt
		pose.air += ((if hover or grounded then 0 else 1) - pose.air) * (1 - math.exp(-14 * dt))
		pose.vy = vy
		local sinceLand = now - landedAt
		pose.land = if hover or sinceLand >= 0.3 then 0 else math.sin(sinceLand / 0.3 * math.pi)
		if landedAt ~= seenLand then
			seenLand = landedAt
			jiggleV += 7
		end
		jiggleV += (-90 * (pose.jiggle - math.clamp(-vy * 0.015, -0.7, 0.7)) - 9 * jiggleV) * dt
		pose.jiggle += jiggleV * dt
		pose.spin += dt * (1.5 + 7 * pose.move + (if hover then math.clamp(vy, 0, 10) * 0.5 else 0))
		local since = now - clapAt
		if sinceLand >= 0 and sinceLand < 0.3 then
			since = sinceLand
		end
		pose.clap = if since < 0 then 0 elseif since < 0.22 then (since / 0.22) ^ 2 * (3 - 2 * since / 0.22) elseif since < 0.27 then 1 - (since - 0.22) / 0.05 else 0
		-- The whole body, as MascotWorld.step moves it.
		local lift, tilt, pitch = 0, 0, 0
		if hover then
			lift = 1.4 + math.sin(pose.time * 2.2) * 0.25
			pitch = 0.22 * pose.move
			tilt = math.sin(pose.time * 1.3) * 0.04
		else
			lift = math.abs(math.sin(pose.gait)) * 0.16 * pose.move * (1 - pose.air)
			tilt = math.sin(pose.gait) * 0.05 * pose.move * (1 - pose.air)
			pitch = 0.06 * pose.move + math.clamp(-vy * 0.012, -0.3, 0.3) * pose.air
			if jumpAt ~= nil and now >= jumpAt then
				local crouch = math.clamp((now - jumpAt) / 0.12, 0, 1)
				lift -= 0.22 * crouch
				pitch += 0.08 * crouch
			end
			lift -= 0.2 * pose.land
			pitch += 0.12 * pose.land
		end
		local root = CFrame.new(0, y + lift, 0) * CFrame.Angles(-pitch, 0, tilt)
		MascotRig.solve(rig, pose, root)
		local pieces = {}
		for i, piece in rig.pieces do
			local stretch = { 1, 1, 1 }
			if piece.role == "flame" then
				for j in rig.parts do
					if rig.piece[j] == i then
						local s = rig.sizes[j] / rig.restSize[j]
						stretch = { s.X, s.Y, s.Z }
						break
					end
				end
			end
			pieces[piece.name] = { m = flat(root * rig.moved[i]), s = stretch, pivot = { piece.pivot.X, piece.pivot.Y, piece.pivot.Z } }
		end
		table.insert(frames, pieces)
	end
	out[mascot.id] = frames
end

fs.writeFile(process.args[1] or "mascot_moves.json", serde.encode("json", out))
print("Wrote", process.args[1] or "mascot_moves.json")
