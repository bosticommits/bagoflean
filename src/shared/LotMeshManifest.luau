--!strict
-- Canonical snapshot of the mesh templates currently used by the place.
-- Rebuild them in Studio with tools/studio/rebuild_lot_meshes.luau.

local STANDARD = {
	color = { 255, 255, 255 },
	material = "SmoothPlastic",
	anchored = true,
	canCollide = true,
	canTouch = true,
	canQuery = true,
	castShadow = true,
	transparency = 0,
	reflectance = 0,
	textureId = "",
	materialVariant = "",
	collisionFidelity = "Default",
	renderFidelity = "Automatic",
	doubleSided = false,
}

local TOWN_LIFE = {
	color = { 163, 162, 165 },
	material = "Plastic",
	anchored = false,
	canCollide = true,
	canTouch = true,
	canQuery = true,
	castShadow = true,
	transparency = 0,
	reflectance = 0,
	textureId = "",
	materialVariant = "",
	collisionFidelity = "Default",
	renderFidelity = "Automatic",
	doubleSided = false,
}

local function mesh(name: string, group: string, assetId: number, size: { number }, style: { [string]: any })
	local entry = table.clone(style)
	entry.name = name
	entry.group = group
	entry.assetId = assetId
	entry.size = size
	return table.freeze(entry)
end

local meshes = {
	mesh("CrateParachute", "", 116815856348761, { 14.999999, 5.199999, 14.999999 }, STANDARD),
	mesh("MysteryCrate", "", 88005215370364, { 5.539999, 4.400000, 5.539999 }, STANDARD),
	mesh("MysteryCrateLid", "", 123576858933913, { 5.5, 1.610000, 5.5 }, STANDARD),

	mesh("CandyBucket", "HalloweenKit", 75106286362772, { 1.883258, 1.967000, 1.973919 }, STANDARD),
	mesh("GoldenPumpkin", "HalloweenKit", 113305079822269, { 3.092279, 3.170914, 3.203622 }, STANDARD),
	mesh("HalloweenHayBale", "HalloweenKit", 89692216572014, { 3.600000, 2.093122, 2.120000 }, STANDARD),
	mesh("JackOLantern", "HalloweenKit", 129079916049212, { 3.865349, 3.963643, 3.949527 }, STANDARD),
	mesh("JackOLanternSmall", "HalloweenKit", 81698825209086, { 2.415843, 2.510037, 2.407440 }, STANDARD),
	mesh("PumpkinPlain", "HalloweenKit", 85628296671830, { 2.577090, 1.986683, 2.382199 }, STANDARD),
	mesh("Scarecrow", "HalloweenKit", 88914094680497, { 5, 7.257846, 2.5 }, STANDARD),

	mesh("FanSign", "TownLifeKit", 114099363425287, { 2.4, 4, 0.232 }, TOWN_LIFE),
	mesh("Guitar", "TownLifeKit", 74504352681424, { 3.770087, 1.3, 0.441658 }, TOWN_LIFE),
	mesh("HotDogCart", "TownLifeKit", 98520605367119, { 6, 6.98, 6 }, TOWN_LIFE),
	mesh("PaparazziCamera", "TownLifeKit", 115276836382933, { 1.375, 1.650000, 1.35 }, TOWN_LIFE),
	mesh("TipHat", "TownLifeKit", 96409110094846, { 1.657377, 1.123261, 1.7 }, TOWN_LIFE),
	mesh("TownFanAArm", "TownLifeKit", 140341094955148, { 0.64, 1.83, 0.74 }, TOWN_LIFE),
	mesh("TownFanAHead", "TownLifeKit", 103638257101399, { 1.56, 2.27, 1.54 }, TOWN_LIFE),
	mesh("TownFanALeg", "TownLifeKit", 136034703009078, { 0.86, 2, 1.22 }, TOWN_LIFE),
	mesh("TownFanATorso", "TownLifeKit", 81817952143913, { 1.84, 2.12, 1.04 }, TOWN_LIFE),
	mesh("TownFanBArm", "TownLifeKit", 100824957183037, { 0.64, 1.83, 0.74 }, TOWN_LIFE),
	mesh("TownFanBHead", "TownLifeKit", 124213890876542, { 1.56, 1.76, 2.03 }, TOWN_LIFE),
	mesh("TownFanBLeg", "TownLifeKit", 134130022981539, { 0.86, 2, 1.22 }, TOWN_LIFE),
	mesh("TownFanBTorso", "TownLifeKit", 76936081000875, { 1.84, 2.12, 1.122 }, TOWN_LIFE),
	mesh("TownFanCArm", "TownLifeKit", 110510938722294, { 0.64, 1.83, 0.74 }, TOWN_LIFE),
	mesh("TownFanCHead", "TownLifeKit", 72033678197363, { 2.198888, 2.17, 1.54 }, TOWN_LIFE),
	mesh("TownFanCLeg", "TownLifeKit", 116182725213285, { 0.86, 2, 1.22 }, TOWN_LIFE),
	mesh("TownFanCTorso", "TownLifeKit", 130286197064811, { 1.84, 2.12, 1.04 }, TOWN_LIFE),
	mesh("TownFanDArm", "TownLifeKit", 137214147593847, { 0.64, 1.83, 0.74 }, TOWN_LIFE),
	mesh("TownFanDHead", "TownLifeKit", 109562820414194, { 1.56, 2.1, 1.54 }, TOWN_LIFE),
	mesh("TownFanDLeg", "TownLifeKit", 136034703009078, { 0.86, 2, 1.22 }, TOWN_LIFE),
	mesh("TownFanDTorso", "TownLifeKit", 94813839242984, { 1.84, 2.12, 1.065 }, TOWN_LIFE),
	mesh("TownMimeArm", "TownLifeKit", 122167625948114, { 0.64, 1.83, 0.74 }, TOWN_LIFE),
	mesh("TownMimeHead", "TownLifeKit", 139743719834620, { 1.711704, 1.915024, 1.84 }, TOWN_LIFE),
	mesh("TownMimeLeg", "TownLifeKit", 84918164147200, { 0.86, 2, 1.22 }, TOWN_LIFE),
	mesh("TownMimeTorso", "TownLifeKit", 85016849722132, { 1.84, 2.12, 1.07 }, TOWN_LIFE),
	mesh("TownPhotogArm", "TownLifeKit", 77602514527440, { 0.64, 1.83, 0.74 }, TOWN_LIFE),
	mesh("TownPhotogHead", "TownLifeKit", 138611546994978, { 1.58, 1.73, 1.88 }, TOWN_LIFE),
	mesh("TownPhotogLeg", "TownLifeKit", 89553283699018, { 0.86, 2, 1.22 }, TOWN_LIFE),
	mesh("TownPhotogTorso", "TownLifeKit", 104830808162087, { 1.84, 2.12, 1.11 }, TOWN_LIFE),
	mesh("TownVendorArm", "TownLifeKit", 133024487000831, { 0.64, 1.83, 0.74 }, TOWN_LIFE),
	mesh("TownVendorHead", "TownLifeKit", 98919708445251, { 1.632198, 2.6, 1.674173 }, TOWN_LIFE),
	mesh("TownVendorLeg", "TownLifeKit", 106112739386473, { 0.86, 2, 1.22 }, TOWN_LIFE),
	mesh("TownVendorTorso", "TownLifeKit", 140272451223697, { 1.84, 2.12, 1.105 }, TOWN_LIFE),
}

assert(#meshes == 43, "LotMeshManifest must contain exactly 43 templates")

return table.freeze({
	version = 1,
	meshes = table.freeze(meshes),
})
