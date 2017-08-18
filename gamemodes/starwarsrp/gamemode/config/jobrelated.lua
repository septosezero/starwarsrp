-- People often copy jobs. When they do, the GM table does not exist anymore.
-- This line makes the job code work both inside and outside of gamemode files.
-- You should not copy this line into your code.
local GAMEMODE = GAMEMODE or GM

--	Below is an example of how a job should look
--TEAM_CADET = DarkRP.createJob("Clone Cadet", {
--	color = Color(120, 120, 120, 255),
--	model = {"models/player/testc/cgi cadet.mdl"},
--	description = [[Clone Cadet]],
--	weapons = {"climb_swep2", "salute", "weapon_752_dc15atrainingnodmg"},
--	command = "cadet",
--	max = 0,
--	salary = GAMEMODE.Config.normalsalary,
--	admin = 0,
--	vote = false,
--	hasLicense = false,
--	candemote = false,
--	category = "Cadets",
--	sortOrder = 1,
--	PlayerLoadout = function(ply)
--		ply:SetHealth(100)
--		ply:SetMaxHealth(100)
--	end,
--})

-- Compatibility for when default teams are disabled DO NOT CHANGE
TEAM_CADET = TEAM_CADET  or -1

-- Agendas
-- Example
--DarkRP.createAgenda("Cadet's Agenda", {TEAM_CADET}, {TEAM_CADET})
-- First TEAM_ is who can edit separate in the brackets with commas
--The second TEAM_ is who can view it.

-- Group chats
--GAMEMODE:AddGroupChat(TEAM_CADET, TEAM_1)
GAMEMODE:AddGroupChat(TEAM_CADET)

-- Initial team when first spawning
--Change this to your default job
GAMEMODE.DefaultTeam = TEAM_CADET

-- Teams that belong to Civil Protection they have /wanted /warrant
GAMEMODE.CivilProtection = {
}

-- Categories
-- How one should look like
--DarkRP.createCategory{
--    name = "Cadets",
--    categorises = "jobs",
--    startExpanded = true,
--    color = Color(0, 107, 0, 255),
--    canSee = fp{fn.Id, true},
--    sortOrder = 1,
--}
