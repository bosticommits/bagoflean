--!strict
-- The 21 castable actors and Director Lucien Vale. All original characters.
--
-- The actors are low-poly Blender models (art/blender/actors.py): a big-headed toy body shared by
-- the whole cast, props that say the role at a glance, and more flair the rarer they are. Each is
-- split into rig pieces (Body, Head, ArmL, ArmR and a Base in the rarity color) that ActorLife
-- moves on the client: an idle bob, a look round and now and then a wave. Once the owner imports
-- actors.fbx into ReplicatedStorage.LotMeshes (art/README.md) each piece is its mesh; until then
-- the same Blender shapes are built from parts (ActorShapes, written by the Blender script).
--
-- A figure is about 5.4 studs tall at scale 1, standing on its origin, facing -Z. Used for the
-- star on each lot's pedestal, the store keepers and the Top Studios wall; the same model can go
-- in a ViewportFrame. The director is still built from parts, below. The limited seasonal actors
-- (Actors.Limited) are one-piece Blender designs (art/blender/seasonal_actors.py), shown as their
-- meshes once imported and as SeasonalShapes parts until then.
local ActorShapes = require(script.Parent.ActorShapes)
local Build = require(script.Parent.Build)
local MascotModels = require(script.Parent.MascotModels)
local SeasonalShapes = require(script.Parent.SeasonalShapes)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local SKIN = {
	light = rgb(255, 222, 190),
	fair = rgb(240, 196, 156),
	tan = rgb(214, 160, 110),
	brown = rgb(165, 108, 68),
	deep = rgb(112, 70, 44),
	pale = rgb(236, 236, 228),
	monster = rgb(140, 196, 120),
}

-- Body landmarks (scale 1).
local HIP = 2.0
local SHOULDER = 3.9
local HEAD_W, HEAD_H, HEAD_D = 1.6, 1.5, 1.5
local HEAD_Y = SHOULDER + HEAD_H / 2 -- head centre
local HEAD_TOP = SHOULDER + HEAD_H
local FACE_Z = -HEAD_D / 2 -- front of the face
local CHEST_Z = -0.5 -- front of the torso
local HAND_R = v(1.45, 2.3, 0) -- right hand (the figure's right is +X)
local HAND_L = v(-1.45, 2.3, 0)

export type Look = {
	skin: Color3,
	shirt: Color3,
	sleeves: Color3?, -- defaults to shirt
	pants: Color3,
	shoes: Color3,
	hair: string?, -- short, swoop, long, bun, curly, slick, ponytail, spiky, bob, none
	hairColor: Color3?,
	mouth: string?, -- smile, grin, open, flat, smirk
	eyes: Color3?,
	gown: Color3?, -- long dress instead of legs
	wide: boolean?, -- broad hero build
	extra: ((b: Builder) -> ())?,
}

-- Body ------------------------------------------------------------------------------------------

local function face(b: Builder, look: Look)
	local eye = look.eyes or P.Charcoal
	for _, x in { -0.36, 0.36 } do
		b:block("Eye", v(0.24, 0.4, 0.1), v(x, HEAD_Y + 0.12, FACE_Z - 0.04), eye, if look.eyes ~= nil then NEON else nil)
		b:block("EyeShine", v(0.1, 0.1, 0.05), v(x + 0.05, HEAD_Y + 0.24, FACE_Z - 0.1), P.OffWhite)
	end
	local mouth = look.mouth or "smile"
	local y = HEAD_Y - 0.36
	local dark = rgb(120, 40, 50)
	if mouth == "open" then
		b:block("Mouth", v(0.42, 0.4, 0.1), v(0, y - 0.04, FACE_Z - 0.04), dark)
	elseif mouth == "grin" then
		b:block("Mouth", v(0.7, 0.26, 0.1), v(0, y, FACE_Z - 0.04), P.OffWhite)
		b:block("MouthLine", v(0.74, 0.06, 0.11), v(0, y - 0.13, FACE_Z - 0.04), dark)
	elseif mouth == "flat" then
		b:block("Mouth", v(0.5, 0.1, 0.1), v(0, y, FACE_Z - 0.04), dark)
	elseif mouth == "smirk" then
		b:block("Mouth", v(0.45, 0.1, 0.1), v(0.1, y, FACE_Z - 0.04), dark)
		b:block("MouthEnd", v(0.12, 0.12, 0.1), v(0.36, y + 0.06, FACE_Z - 0.04), dark)
	else
		b:block("Mouth", v(0.44, 0.1, 0.1), v(0, y - 0.04, FACE_Z - 0.04), dark)
		for _, x in { -0.26, 0.26 } do
			b:block("MouthEnd", v(0.12, 0.12, 0.1), v(x, y + 0.02, FACE_Z - 0.04), dark)
		end
	end
	for _, x in { -0.58, 0.58 } do
		b:block("Blush", v(0.26, 0.14, 0.06), v(x, HEAD_Y - 0.2, FACE_Z - 0.02), look.skin:Lerp(P.Carpet, 0.35))
	end
end

local function hair(b: Builder, style: string, color: Color3)
	if style == "none" then
		return
	end
	local w, d = HEAD_W + 0.12, HEAD_D + 0.12
	if style == "slick" then
		b:block("Hair", v(w, 0.3, d), v(0, HEAD_TOP + 0.1, 0.02), color)
		b:block("HairBack", v(w, 0.9, 0.3), v(0, HEAD_TOP - 0.4, HEAD_D / 2 + 0.05), color)
		return
	end
	b:block("Hair", v(w, 0.5, d), v(0, HEAD_TOP + 0.18, 0.02), color)
	b:block("HairBack", v(w, 1.1, 0.35), v(0, HEAD_TOP - 0.5, HEAD_D / 2 + 0.05), color)
	b:block("Fringe", v(w, 0.35, 0.3), v(0, HEAD_TOP - 0.12, FACE_Z - 0.05), color)
	if style == "swoop" then
		b:wedge("Swoop", v(w, 0.7, 0.9), CFrame.new(0.15, HEAD_TOP + 0.75, -0.25), color)
	elseif style == "spiky" then
		for i, x in { -0.5, 0, 0.5 } do
			b:wedge("Spike", v(0.5, 0.6 + (i % 2) * 0.2, 0.7), CFrame.new(x, HEAD_TOP + 0.7, 0.1) * CFrame.Angles(0, math.pi, 0), color)
		end
	elseif style == "long" or style == "bob" then
		local length = if style == "long" then 2.1 else 1.2
		for _, x in { -1, 1 } do
			b:block("HairSide", v(0.3, length, 1.2), v(x * (HEAD_W / 2 + 0.12), HEAD_TOP - length / 2, 0.2), color)
		end
		b:block("HairBackLong", v(w, length, 0.35), v(0, HEAD_TOP - length / 2, HEAD_D / 2 + 0.1), color)
	elseif style == "bun" then
		b:ball("Bun", 0.9, v(0, HEAD_TOP + 0.6, 0.4), color)
	elseif style == "ponytail" then
		b:ball("TailTie", 0.4, v(0, HEAD_TOP - 0.1, HEAD_D / 2 + 0.3), P.Carpet)
		b:block("Ponytail", v(0.55, 1.5, 0.5), CFrame.new(0, HEAD_TOP - 0.9, HEAD_D / 2 + 0.45) * CFrame.Angles(math.rad(-12), 0, 0), color)
	elseif style == "curly" then
		for i = 0, 7 do
			local a = math.rad(i * 45)
			b:ball("Curl", 0.75, v(math.cos(a) * 0.75, HEAD_TOP + 0.15, math.sin(a) * 0.7 + 0.05), color)
		end
		b:ball("Curl", 0.9, v(0, HEAD_TOP + 0.45, 0.1), color)
		for _, x in { -1, 1 } do
			b:ball("CurlSide", 0.7, v(x * 0.9, HEAD_Y - 0.1, 0.3), color)
		end
	end
end

local function body(b: Builder, look: Look)
	local sleeves = look.sleeves or look.shirt
	local torsoW = if look.wide then 2.4 else 2.0
	local armX = torsoW / 2 + 0.45
	if look.gown ~= nil then
		b:block("GownTop", v(2.1, 1.1, 1.15), v(0, HIP - 0.4, 0), look.gown, FABRIC)
		b:block("GownSkirt", v(2.5, 1.0, 1.5), v(0, 0.5, 0), look.gown, FABRIC)
		b:block("GownHem", v(2.6, 0.2, 1.6), v(0, 0.1, 0), look.gown:Lerp(P.Charcoal, 0.25), FABRIC)
	else
		for _, x in { -0.5, 0.5 } do
			b:block("Leg", v(0.95, 1.7, 1.0), v(x, 0.35 + 0.85, 0), look.pants)
			b:block("Shoe", v(1.0, 0.4, 1.25), v(x, 0.2, -0.1), look.shoes)
		end
	end
	b:block("Torso", v(torsoW, SHOULDER - HIP, 1.0), v(0, (HIP + SHOULDER) / 2, 0), look.shirt)
	for side = -1, 1, 2 do
		local x = side * armX
		b:block("Arm", v(0.85, 1.35, 0.95), v(x, SHOULDER - 0.68, 0), sleeves)
		b:block("Hand", v(0.75, 0.6, 0.8), v(x, SHOULDER - 1.65, 0), look.skin)
	end
	b:block("Head", v(HEAD_W, HEAD_H, HEAD_D), v(0, HEAD_Y, 0), look.skin)
	face(b, look)
	hair(b, look.hair or "short", look.hairColor or rgb(90, 60, 40))
end

-- Accessories -----------------------------------------------------------------------------------

local Acc = {}

function Acc.glasses(b: Builder, color: Color3)
	for _, x in { -0.38, 0.38 } do
		b:block("GlassesFrame", v(0.56, 0.5, 0.08), v(x, HEAD_Y + 0.12, FACE_Z - 0.1), color)
		b:block("GlassesLens", v(0.4, 0.34, 0.06), v(x, HEAD_Y + 0.12, FACE_Z - 0.15), P.Glass, GLASS)
	end
	b:block("GlassesBridge", v(0.3, 0.1, 0.08), v(0, HEAD_Y + 0.2, FACE_Z - 0.1), color)
end

function Acc.sunglasses(b: Builder, color: Color3?)
	b:block("Sunglasses", v(1.5, 0.42, 0.12), v(0, HEAD_Y + 0.14, FACE_Z - 0.1), color or P.Charcoal)
	b:block("SunglassesShine", v(0.25, 0.08, 0.05), v(-0.45, HEAD_Y + 0.24, FACE_Z - 0.18), P.OffWhite)
end

function Acc.visor(b: Builder, color: Color3)
	b:block("Visor", v(1.75, 0.45, 0.3), v(0, HEAD_Y + 0.14, FACE_Z - 0.08), color, NEON)
end

function Acc.cape(b: Builder, color: Color3, lining: Color3?)
	b:block("CapeCollar", v(2.4, 0.5, 0.5), v(0, SHOULDER + 0.1, 0.45), lining or color)
	b:block("Cape", v(2.2, 3.4, 0.2), CFrame.new(0, SHOULDER - 1.6, 0.75) * CFrame.Angles(math.rad(-6), 0, 0), color, FABRIC)
end

function Acc.scarf(b: Builder, color: Color3)
	b:block("Scarf", v(1.8, 0.45, 1.2), v(0, SHOULDER + 0.05, 0), color, FABRIC)
	b:block("ScarfTail", v(0.45, 1.1, 0.15), v(0.45, SHOULDER - 0.6, CHEST_Z - 0.1), color, FABRIC)
end

function Acc.tie(b: Builder, color: Color3)
	b:block("TieKnot", v(0.3, 0.25, 0.1), v(0, SHOULDER - 0.2, CHEST_Z - 0.05), color)
	b:block("Tie", v(0.3, 1.1, 0.08), v(0, SHOULDER - 0.85, CHEST_Z - 0.05), color)
end

function Acc.jacket(b: Builder, color: Color3, torsoW: number?)
	local w = torsoW or 2.0
	for _, side in { -1, 1 } do
		b:block("Lapel", v(w * 0.32, SHOULDER - HIP, 0.1), v(side * (w / 2 - w * 0.16), (HIP + SHOULDER) / 2, CHEST_Z - 0.04), color)
	end
end

function Acc.belt(b: Builder, color: Color3, buckle: Color3?)
	b:block("Belt", v(2.05, 0.3, 1.05), v(0, HIP + 0.15, 0), color)
	b:block("Buckle", v(0.4, 0.3, 0.1), v(0, HIP + 0.15, CHEST_Z - 0.05), buckle or P.Gold, METAL)
end

function Acc.necklace(b: Builder, color: Color3)
	for i = -2, 2 do
		b:ball("Pearl", 0.22, v(i * 0.22, SHOULDER - 0.15 - math.abs(i) * -0.04 - (2 - math.abs(i)) * 0.06, CHEST_Z - 0.06), color)
	end
end

function Acc.badge(b: Builder, color: Color3)
	b:block("Badge", v(0.4, 0.4, 0.1), CFrame.new(-0.55, SHOULDER - 0.55, CHEST_Z - 0.05) * CFrame.Angles(0, 0, math.rad(45)), color, METAL)
end

-- Hats sit on HEAD_TOP.
function Acc.cap(b: Builder, color: Color3)
	b:block("Cap", v(1.75, 0.5, 1.65), v(0, HEAD_TOP + 0.2, 0.05), color)
	b:block("CapBrim", v(1.6, 0.12, 0.8), v(0, HEAD_TOP, FACE_Z - 0.35), color)
end

function Acc.bowler(b: Builder, color: Color3)
	b:block("HatBrim", v(2.2, 0.15, 2.1), v(0, HEAD_TOP + 0.08, 0), color)
	b:block("HatCrown", v(1.5, 0.8, 1.45), v(0, HEAD_TOP + 0.55, 0), color)
	b:block("HatBand", v(1.55, 0.2, 1.5), v(0, HEAD_TOP + 0.28, 0), P.Charcoal:Lerp(color, 0.3))
end

function Acc.topHat(b: Builder, color: Color3, band: Color3)
	b:block("HatBrim", v(2.3, 0.15, 2.2), v(0, HEAD_TOP + 0.08, 0), color)
	b:block("HatCrown", v(1.5, 1.8, 1.45), v(0, HEAD_TOP + 1.05, 0), color)
	b:block("HatBand", v(1.55, 0.3, 1.5), v(0, HEAD_TOP + 0.35, 0), band)
end

function Acc.beret(b: Builder, color: Color3)
	b:block("Beret", v(1.9, 0.35, 1.8), CFrame.new(-0.15, HEAD_TOP + 0.15, 0) * CFrame.Angles(0, 0, math.rad(8)), color, FABRIC)
	b:ball("BeretNub", 0.3, v(-0.15, HEAD_TOP + 0.4, 0), color)
end

function Acc.headband(b: Builder, color: Color3)
	b:block("Headband", v(HEAD_W + 0.1, 0.3, HEAD_D + 0.1), v(0, HEAD_TOP - 0.3, 0), color, FABRIC)
	b:block("HeadbandTail", v(0.2, 0.8, 0.12), CFrame.new(0.3, HEAD_TOP - 0.7, HEAD_D / 2 + 0.15) * CFrame.Angles(0, 0, math.rad(20)), color, FABRIC)
end

function Acc.crown(b: Builder, color: Color3, gem: Color3)
	b:block("CrownBand", v(1.7, 0.5, 1.6), v(0, HEAD_TOP + 0.25, 0), color, METAL)
	for _, x in { -0.65, 0, 0.65 } do
		b:block("CrownPoint", v(0.35, 0.35, 0.35), CFrame.new(x, HEAD_TOP + 0.65, -0.65) * CFrame.Angles(0, 0, math.rad(45)), color, METAL)
		b:block("CrownPoint", v(0.35, 0.35, 0.35), CFrame.new(x, HEAD_TOP + 0.65, 0.65) * CFrame.Angles(0, 0, math.rad(45)), color, METAL)
	end
	b:block("CrownGem", v(0.3, 0.3, 0.1), v(0, HEAD_TOP + 0.25, -0.85), gem, NEON)
end

function Acc.tiara(b: Builder, color: Color3, gem: Color3)
	b:block("Tiara", v(1.5, 0.15, 0.15), v(0, HEAD_TOP + 0.45, -0.55), color, METAL)
	b:block("TiaraPeak", v(0.4, 0.4, 0.12), CFrame.new(0, HEAD_TOP + 0.65, -0.55) * CFrame.Angles(0, 0, math.rad(45)), color, METAL)
	b:block("TiaraGem", v(0.18, 0.18, 0.1), v(0, HEAD_TOP + 0.65, -0.63), gem, NEON)
end

function Acc.helmet(b: Builder, color: Color3, stripe: Color3)
	b:block("Helmet", v(1.85, 0.9, 1.75), v(0, HEAD_TOP + 0.05, 0.05), color)
	b:block("HelmetStripe", v(0.35, 0.95, 1.8), v(0, HEAD_TOP + 0.08, 0.05), stripe)
end

function Acc.halo(b: Builder, color: Color3)
	b:cylinder("Halo", 0.15, 1.9, v(0, HEAD_TOP + 1.1, 0.1), color, NEON)
	b:cylinder("HaloHole", 0.17, 1.4, v(0, HEAD_TOP + 1.1, 0.1), color:Lerp(P.OffWhite, 0.6), NEON)
end

-- Props in hand ---------------------------------------------------------------------------------

function Acc.clipboard(b: Builder)
	local at = HAND_L + v(0.1, 0.3, -0.75)
	b:block("Clipboard", v(1.0, 1.3, 0.12), CFrame.new(at) * CFrame.Angles(math.rad(-20), 0, 0), P.Wood)
	b:block("Paper", v(0.8, 1.0, 0.05), CFrame.new(at + v(0, -0.05, -0.08)) * CFrame.Angles(math.rad(-20), 0, 0), P.OffWhite)
	b:block("Clip", v(0.4, 0.2, 0.15), CFrame.new(at + v(0, 0.6, -0.1)) * CFrame.Angles(math.rad(-20), 0, 0), P.Steel, METAL)
end

function Acc.coffee(b: Builder)
	b:cylinder("CoffeeCup", 0.7, 0.5, HAND_R + v(0, 0.35, -0.45), P.OffWhite)
	b:cylinder("CoffeeLid", 0.12, 0.55, HAND_R + v(0, 0.75, -0.45), P.Carpet)
end

function Acc.productBox(b: Builder, color: Color3)
	local at = HAND_R + v(0, 0.6, -0.6)
	b:block("ProductBox", v(0.9, 1.3, 0.6), at, color)
	b:block("ProductLabel", v(0.92, 0.4, 0.62), at + v(0, 0.15, 0), P.OffWhite)
	b:ball("ProductStar", 0.3, at + v(0, 0.15, -0.32), P.Gold, NEON)
end

function Acc.rayGun(b: Builder, color: Color3)
	local at = HAND_R + v(0, 0.2, -0.6)
	b:block("RayGrip", v(0.3, 0.6, 0.35), at, P.Charcoal)
	b:cylinder("RayBody", 1.0, 0.45, CFrame.new(at + v(0, 0.35, -0.35)) * CFrame.Angles(math.rad(90), 0, 0), color)
	b:ball("RayTip", 0.35, at + v(0, 0.35, -0.9), P.Green, NEON)
end

function Acc.lantern(b: Builder)
	local at = HAND_R + v(0, -0.6, -0.2)
	b:block("LanternHandle", v(0.1, 0.5, 0.1), at + v(0, 0.55, 0), P.Charcoal)
	b:block("LanternFrame", v(0.7, 0.9, 0.7), at, P.Charcoal, METAL)
	b:block("LanternGlow", v(0.5, 0.7, 0.75), at, rgb(255, 170, 60), NEON)
end

function Acc.script(b: Builder)
	b:block("Script", v(0.9, 1.2, 0.15), CFrame.new(HAND_L + v(0.1, 0.3, -0.55)) * CFrame.Angles(math.rad(-15), 0, math.rad(8)), P.OffWhite)
	b:block("ScriptCover", v(0.92, 0.3, 0.17), CFrame.new(HAND_L + v(0.1, 0.75, -0.55)) * CFrame.Angles(math.rad(-15), 0, math.rad(8)), P.Carpet)
end

function Acc.guitar(b: Builder, color: Color3)
	local tilt = CFrame.new(0.1, 2.6, CHEST_Z - 0.35) * CFrame.Angles(0, 0, math.rad(-40))
	b:block("GuitarBody", v(1.4, 1.0, 0.35), tilt, color)
	b:block("GuitarBodyLow", v(1.0, 0.6, 0.35), tilt * CFrame.new(-0.6, 0, 0), color)
	b:block("GuitarHole", v(0.3, 0.3, 0.05), tilt * CFrame.new(0.1, 0, -0.18), P.Charcoal)
	b:block("GuitarNeck", v(1.8, 0.22, 0.2), tilt * CFrame.new(1.5, 0, 0), P.Wood)
	b:block("GuitarHead", v(0.4, 0.35, 0.22), tilt * CFrame.new(2.5, 0, 0), P.Charcoal)
end

function Acc.balloon(b: Builder, color: Color3)
	b:block("BalloonString", v(0.06, 2.6, 0.06), HAND_R + v(0, 1.5, 0), P.OffWhite)
	local at = HAND_R + v(0, 3.4, 0)
	b:ball("HeartLeft", 1.0, at + v(-0.3, 0.2, 0), color)
	b:ball("HeartRight", 1.0, at + v(0.3, 0.2, 0), color)
	b:block("HeartPoint", v(0.95, 0.95, 0.7), CFrame.new(at + v(0, -0.25, 0)) * CFrame.Angles(0, 0, math.rad(45)), color)
end

function Acc.cane(b: Builder, color: Color3)
	b:cylinder("Cane", 2.3, 0.2, HAND_R + v(0, -1.0, -0.5), color)
	b:block("CaneHook", v(0.6, 0.2, 0.2), HAND_R + v(-0.2, 0.15, -0.5), color)
end

function Acc.megaphone(b: Builder, color: Color3)
	local aim = CFrame.new(HAND_R + v(0, 0.5, -0.8)) * CFrame.Angles(math.rad(90), 0, 0)
	b:cylinder("MegaphoneGrip", 0.9, 0.35, aim * CFrame.new(0, 0.3, 0), P.Charcoal)
	b:cylinder("Megaphone", 0.6, 0.7, aim * CFrame.new(0, -0.3, 0), color)
	b:cylinder("MegaphoneBell", 0.4, 1.1, aim * CFrame.new(0, -0.75, 0), color)
end

function Acc.wand(b: Builder, star: Color3)
	b:cylinder("Wand", 1.5, 0.15, HAND_R + v(0, 0.75, -0.3), P.OffWhite)
	b:block("WandStar", v(0.6, 0.6, 0.15), CFrame.new(HAND_R + v(0, 1.65, -0.3)) * CFrame.Angles(0, 0, math.rad(45)), star, NEON)
end

function Acc.holoCube(b: Builder, color: Color3)
	b:block("HoloCube", v(0.8, 0.8, 0.8), CFrame.new(HAND_L + v(0, 1.3, -0.4)) * CFrame.Angles(math.rad(35), math.rad(45), 0), color, NEON)
end

function Acc.mirror(b: Builder)
	b:block("MirrorHandle", v(0.15, 0.6, 0.15), HAND_L + v(0, 0.3, -0.4), P.Gold, METAL)
	b:cylinder("MirrorFrame", 0.12, 0.8, CFrame.new(HAND_L + v(0, 0.95, -0.4)) * CFrame.Angles(math.rad(90), 0, 0), P.Gold, METAL)
	b:cylinder("MirrorGlass", 0.14, 0.6, CFrame.new(HAND_L + v(0, 0.95, -0.42)) * CFrame.Angles(math.rad(90), 0, 0), P.Glass, GLASS)
end

function Acc.rose(b: Builder)
	b:block("RoseStem", v(0.08, 0.9, 0.08), HAND_L + v(0, 0.45, -0.4), P.DarkGreen)
	b:ball("Rose", 0.4, HAND_L + v(0, 0.95, -0.4), P.Carpet)
end

function Acc.newspaper(b: Builder)
	b:block("Newspaper", v(1.0, 0.7, 0.12), CFrame.new(HAND_L + v(0.2, 0.3, -0.55)) * CFrame.Angles(math.rad(-10), 0, 0), P.OffWhite)
	b:block("Headline", v(0.8, 0.12, 0.13), CFrame.new(HAND_L + v(0.2, 0.5, -0.56)) * CFrame.Angles(math.rad(-10), 0, 0), P.Charcoal)
end

function Acc.filmReels(b: Builder, color: Color3)
	for i, x in { -1.6, 1.6 } do
		local at = CFrame.new(x, HEAD_Y + 0.6 + i * 0.3, 0.6) * CFrame.Angles(math.rad(90), 0, 0)
		b:cylinder("FloatingReel", 0.2, 1.1, at, color, METAL)
		b:cylinder("ReelCore", 0.22, 0.35, at, P.Charcoal)
	end
end

function Acc.aura(b: Builder, color: Color3)
	local glow = b:cylinder("AuraRing", 0.12, 3.6, v(0, 0.1, 0), color, NEON)
	glow.Transparency = 0.3
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = glow
end

local function figure(b: Builder, look: Look)
	body(b, look)
	if look.extra ~= nil then
		look.extra(b)
	end
end

local ActorModels = {}

export type Options = {
	-- Stand on a hex base in the rarity color (the menus' cards). Off where the figure already
	-- has something to stand on: a lot's pedestal, a store counter, the Top Studios plinths.
	base: boolean?,
}

-- Parts for one Blender shape. Roblox has no cone or oval cylinder: a cone is a few stacked
-- cylinders, each narrower than the last, and a flattened cylinder (a torso) is a block.
local function shapeParts(b: Builder, shape: ActorShapes.Shape): { BasePart }
	local material = if shape.neon then NEON else Enum.Material.SmoothPlastic
	local size = shape.size
	if shape.kind == "ball" then
		local p = b:block("Shape", size, shape.cf, shape.color, material)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return { p }
	elseif shape.kind == "cyl" and math.abs(size.X - size.Z) <= 0.15 * size.X then
		local top = shape.top or 1
		local tiers = if top < 0.95 then (if size.Y > 0.6 then 3 else 2) else 1
		local parts: { BasePart } = {}
		for i = 0, tiers - 1 do
			local t = (i + 0.5) / tiers
			local width = size.X * (1 + (top - 1) * t)
			local at = shape.cf * CFrame.new(0, -size.Y / 2 + size.Y * t, 0)
			table.insert(parts, b:cylinder("Shape", size.Y / tiers, math.max(width, 0.05), at, shape.color, material))
		end
		return parts
	elseif shape.kind == "cyl" then
		local top = shape.top or 1
		local k = (1 + top) / 2
		return { b:block("Shape", Vector3.new(size.X * k, size.Y, size.Z * k), shape.cf, shape.color, material) }
	end
	return { b:block("Shape", size, shape.cf, shape.color, material) }
end

-- Build an actor figure into a new Model under `parent`, standing at `base` (feet, or the
-- bottom of its base, at the origin, facing base.LookVector). Variants add effects: Shiny
-- sparkles, Award-Winning a gold medal and gold sparkles. Unknown ids build the Nervous Intern
-- so nothing breaks.
--
-- Every part carries a "Piece" attribute and the model the pivots ActorLife turns them round
-- ("Pivot<Piece>", in the model's own space, scaled), the arm that waves ("Wave") and whether
-- it hovers ("Float"). The model's pivot is its feet.
function ActorModels.build(parent: Instance, base: CFrame, actorId: string, variantId: string?, scale: number?, options: Options?): Model
	local rig = ActorShapes.Actors[actorId] or ActorShapes.Actors.NervousIntern
	local seasonal = SeasonalShapes.Shapes[actorId]
	local k = scale or 1
	local withBase = options ~= nil and options.base == true and seasonal == nil
	local lift = if withBase then ActorShapes.BaseHeight else 0
	local model = Instance.new("Model")
	model.Name = "Actor_" .. actorId
	model:SetAttribute("ActorId", actorId)
	model:SetAttribute("VariantId", variantId or "Normal")
	local feet = base * CFrame.new(0, lift * k, 0)
	local b = Build.new(model, feet, k)
	local meshed = false
	if seasonal ~= nil then
		-- A limited seasonal actor: one piece (its Blender mesh once imported, its shapes until then)
		-- that ActorLife only bobs.
		MascotModels.fill(b, actorId, seasonal, SeasonalShapes.Bounds[actorId])
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p:SetAttribute("Piece", "Body")
			end
		end
	else
		for _, name in ActorShapes.Pieces do
			local piece = rig.pieces[name]
			if piece == nil or (name == "Base" and not withBase) then
				continue
			end
			local parts: { BasePart } = {}
			local mesh = Build.mesh(b, `{actorId}_{name}`, CFrame.new(piece.center.X, piece.center.Y - piece.size.Y / 2, piece.center.Z), piece.size.Y)
			if mesh ~= nil then
				mesh.Name = name
				-- The baked vertex colors show on white.
				mesh.Color = Color3.new(1, 1, 1)
				mesh.Material = Enum.Material.SmoothPlastic
				meshed = true
				table.insert(parts, mesh)
			else
				for _, shape in piece.shapes do
					for _, p in shapeParts(b, shape) do
						table.insert(parts, p)
					end
				end
			end
			for _, p in parts do
				p:SetAttribute("Piece", name)
			end
			model:SetAttribute("Pivot" .. name, piece.pivot * k)
		end
	end
	if variantId == "Award" then
		b:block("MedalRibbon", v(0.32, 0.45, 0.08), v(0.45, 2.3, -0.78), P.Carpet):SetAttribute("Piece", "Body")
		local medal = b:cylinder("Medal", 0.12, 0.5, CFrame.new(0.45, 1.95, -0.8) * CFrame.Angles(math.rad(90), 0, 0), P.Gold, NEON)
		medal:SetAttribute("Piece", "Body")
	end
	if variantId == "Shiny" or variantId == "Award" then
		local anchor = b:block("SparkleAnchor", v(1, 1, 1), v(0, 3, 0), P.OffWhite)
		anchor.Transparency = 1
		anchor:SetAttribute("Piece", "Body")
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = if variantId == "Award" then P.Gold else Color3.fromRGB(150, 235, 255)
		sparkles.Parent = anchor
	end
	if meshed then
		model:SetAttribute("Meshed", true)
	end
	if rig.wave ~= nil and seasonal == nil then
		model:SetAttribute("Wave", rig.wave)
	end
	if rig.float and seasonal == nil then
		model:SetAttribute("Float", true)
	end
	model:SetAttribute("RigScale", k)
	Build.decorative(model)
	model.WorldPivot = feet
	-- ActorLife finds the figures by this tag, and streams them in whole (not in the art
	-- previews, which run outside Roblox).
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:AddTag("ActorRig")
	end)
	model.Parent = parent
	return model
end

-- Director Lucien Vale, the tutorial's host (not a castable actor): an original, world-renowned
-- director. Silver swept-back hair and trimmed beard, gold-rimmed glasses, a midnight velvet
-- tuxedo with black satin lapels piped in gold, shirt cuffs with gold links, a burgundy silk scarf
-- with a gold star brooch, and a black cane with a gold knob.
local DIRECTOR_LOOK: Look = {
	skin = SKIN.tan,
	shirt = rgb(38, 32, 84), -- midnight velvet
	pants = rgb(24, 24, 34),
	shoes = rgb(20, 20, 26),
	hair = "slick",
	hairColor = rgb(214, 216, 226),
	mouth = "smile",
	extra = function(b)
		local silver = rgb(214, 216, 226)
		local satin = rgb(16, 16, 24)
		local silk = rgb(140, 24, 44)
		-- Silver hair swept up at the brow and back.
		b:wedge("HairSweep", v(HEAD_W + 0.14, 0.4, 1.1), CFrame.new(0, HEAD_TOP + 0.45, -0.15) * CFrame.Angles(0, math.pi, 0), silver)
		-- Shirt front, satin lapels with gold piping, bow tie.
		b:block("ShirtFront", v(0.74, SHOULDER - HIP, 0.08), v(0, (HIP + SHOULDER) / 2, CHEST_Z - 0.03), P.OffWhite)
		Acc.jacket(b, satin)
		for _, side in { -1, 1 } do
			b:block("LapelPiping", v(0.07, SHOULDER - HIP, 0.12), v(side * 0.39, (HIP + SHOULDER) / 2, CHEST_Z - 0.05), P.Gold, METAL)
			b:block("BowTieWing", v(0.34, 0.26, 0.1), v(side * 0.2, SHOULDER - 0.2, CHEST_Z - 0.12), satin)
			-- White shirt cuffs with gold links, at the foot of each sleeve.
			b:block("Cuff", v(0.88, 0.16, 0.98), v(side * 1.45, SHOULDER - 1.3, 0), P.OffWhite)
			b:block("Cufflink", v(0.18, 0.14, 0.08), v(side * 1.45, SHOULDER - 1.3, -0.52), P.Gold, METAL)
		end
		b:block("BowTieKnot", v(0.14, 0.16, 0.12), v(0, SHOULDER - 0.2, CHEST_Z - 0.14), satin)
		for i = 0, 1 do
			b:ball("ShirtStud", 0.12, v(0, SHOULDER - 0.6 - i * 0.4, CHEST_Z - 0.09), P.Gold, METAL)
		end
		-- Burgundy silk scarf, draped open with gold-fringed ends and a gold star brooch.
		b:block("Scarf", v(1.85, 0.4, 1.22), v(0, SHOULDER + 0.06, 0), silk, FABRIC)
		for _, side in { -1, 1 } do
			b:block("ScarfTail", v(0.36, 1.45, 0.12), v(side * 0.68, SHOULDER - 0.72, CHEST_Z - 0.13), silk, FABRIC)
			b:block("ScarfFringe", v(0.38, 0.1, 0.13), v(side * 0.68, SHOULDER - 1.47, CHEST_Z - 0.13), P.Gold)
		end
		b:block("StarPin", v(0.26, 0.26, 0.08), CFrame.new(0.68, SHOULDER - 0.55, CHEST_Z - 0.21) * CFrame.Angles(0, 0, math.rad(45)), P.Gold, NEON)
		-- Silver moustache, a trimmed beard along the jaw (the smile shows between them), brows,
		-- and gold-rimmed glasses.
		b:block("Moustache", v(0.8, 0.13, 0.1), v(0, HEAD_Y - 0.25, FACE_Z - 0.07), silver)
		b:block("Beard", v(1.4, 0.26, 0.12), v(0, HEAD_Y - 0.63, FACE_Z - 0.03), silver)
		b:block("BeardChin", v(0.62, 0.32, 0.14), v(0, HEAD_Y - 0.84, FACE_Z - 0.03), silver)
		for _, side in { -1, 1 } do
			b:block("BeardSide", v(0.12, 0.6, 0.55), v(side * (HEAD_W / 2 + 0.02), HEAD_Y - 0.42, FACE_Z + 0.3), silver)
			b:block("Brow", v(0.42, 0.1, 0.06), CFrame.new(side * 0.37, HEAD_Y + 0.46, FACE_Z - 0.06) * CFrame.Angles(0, 0, math.rad(side * -6)), silver)
		end
		Acc.glasses(b, P.Gold)
		-- Black cane with a gold knob.
		b:cylinder("Cane", 2.3, 0.2, HAND_R + v(0, -1.0, -0.5), satin)
		b:ball("CaneKnob", 0.4, HAND_R + v(0, 0.2, -0.5), P.Gold, METAL)
		b:cylinder("CaneTip", 0.2, 0.22, HAND_R + v(0, -2.1, -0.5), P.Gold, METAL)
	end,
}

-- Build Director Lucien Vale into a new Model under `parent`, standing at `base` like an actor.
-- `bust` keeps only the head and shoulders, for a portrait.
function ActorModels.buildDirector(parent: Instance, base: CFrame, bust: boolean?): Model
	local model = Instance.new("Model")
	model.Name = "DirectorLucienVale"
	local b = Build.new(model, base)
	figure(b, DIRECTOR_LOOK)
	if bust then
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and base:PointToObjectSpace(part.CFrame.Position).Y < HIP + 0.55 then
				part:Destroy()
			end
		end
	end
	Build.decorative(model)
	model.Parent = parent
	return model
end

-- Rarity flair under the figure: a glowing ring for Star and up.
function ActorModels.aura(b: Builder, color: Color3)
	Acc.aura(b, color)
end

return ActorModels
