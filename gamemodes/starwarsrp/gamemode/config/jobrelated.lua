-- People often copy jobs. When they do, the GM table does not exist anymore.
-- This line makes the job code work both inside and outside of gamemode files.
-- You should not copy this line into your code.
local GAMEMODE = GAMEMODE or GM

TEAM_CADET = DarkRP.createJob("Clone Cadet", {
	color = Color(120, 120, 120, 255),
	model = {"models/player/testc/cgi cadet.mdl"},
	description = [[Clone Cadet]],
	weapons = {"climb_swep2", "salute", "weapon_752_dc15atrainingnodmg"},
	command = "cadet",
	max = 0,
	salary = GAMEMODE.Config.normalsalary,
	admin = 0,
	vote = false,
	hasLicense = false,
	candemote = false,
	category = "Cadets",
	sortOrder = 1,
	PlayerLoadout = function(ply)
		ply:SetHealth(100)
		ply:SetMaxHealth(100)
	end,
})

TEAM_CLONE = DarkRP.createJob("Clone Trooper", {
	color = Color(120, 120, 120, 255),
	model = {"models/player/testp2c/cgi ctp2.mdl"},
	description = [[Clone Trooper]],
	weapons = { "itemstore_pickup", "climb_swep2", "tfa_dc15a_expanded", "salute", "clone_card_c31"},
	command = "ct",
	max = 0,
	salary = 25,
	admin = 0,
	vote = false,
	hasLicense = false,
    category = "Clone Trooper",
    sortOrder = 101,
	PlayerLoadout = function(ply)
		ply:SetHealth(100)
		ply:SetMaxHealth(100)
	end,
})

-- Compatibility for when default teams are disabled
TEAM_CADET = TEAM_CADET  or -1

-- Agendas
DarkRP.createAgenda("Change this to what job functions as cops", {TEAM_CADET}, {TEAM_CADET})

-- Group chats
--DarkRP.createGroupChat(TEAM_CADET)
GAMEMODE:AddGroupChat(TEAM_CADET)
GAMEMODE:AddGroupChat(TEAM_CLONE)

-- Initial team when first spawning
GAMEMODE.DefaultTeam = TEAM_CADET

-- Teams that belong to Civil Protection
GAMEMODE.CivilProtection = {
    [TEAM_CADET] = true,
}

-- Default categories
DarkRP.createCategory{
    name = "Clone Troopers",
    categorises = "jobs",
    startExpanded = true,
    color = Color(0, 107, 0, 255),
    canSee = fp{fn.Id, true},
    sortOrder = 100,
}

DarkRP.createCategory{
    name = "Cadets",
    categorises = "jobs",
    startExpanded = true,
    color = Color(0, 107, 0, 255),
    canSee = fp{fn.Id, true},
    sortOrder = 1,
}
