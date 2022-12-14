/////////////////////////////////////////////////////////////////////////////////////////////////////
// Purpose: This script was used to practice for the fourth episode of the Bump Mine Competition
//          "Danger Zone's Got Talent": https://youtube.com/playlist?list=PLyCGb0pwEr_SHF2ef6XJBpvQUfpY_oaXe
// 
// HOW TO INSTALL AND USE:
//   To install, put this file into the following folder:
//       Steam\steamapps\common\Counter-Strike Global Offensive\csgo\scripts\vscripts
//   In CSGO, load the correct map by entering this into the console: game_mode 0;game_type 6;map dz_county
//   To start and reset the practice, enter this into the console: script_execute dz_got_talent_e4
//
// CAUTION: If you join official servers after running this script with "script_execute" in your
//          local server, you will be kicked with the message "Pure server: client file does not
//          match server."! Luckily, this won't result in a ban or cooldown. To avoid this, simply
//          restart your game after using this scripts, if you want to play on official
//          servers afterwards.
//
// Made by lacyyy:
//   https://github.com/lacyyy
//   https://steamcommunity.com/profiles/76561198162669616
//
/////////////////////////////////////////////////////////////////////////////////////////////////////


DEFAULT_BOT_DIRECTION <- 90.0


DEFAULT_PLAYER_START_POS <- Vector(-2011.770630, 7831.002441, -2081.597412)
DEFAULT_PLAYER_START_ANGLES <- Vector(0.0, 301.052856, 0.0)


BOT_POSITION <- Vector(-119.000961, 6437.772949, -1551.966797)

// Determine position precisely with: ent_fire !self RunScriptCode "printl(self.GetOrigin())"

///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////

const LOGIC_RELAY_NAME = "dzgt_ep4_relay"

// spec_freeze_* commands possibly affect PLAYER_RESPAWN_DELAY and DEATH_DROP_COOLDOWN!
// Don't change spec_freeze_* commands without testing!

// Time duration between player/bot death and respawn
const PLAYER_RESPAWN_DELAY = 0.9 
// Player doesn't drop items upon death if his last death was less than this many seconds ago!
const DEATH_DROP_COOLDOWN = 10.8 // Testing shows it's between 10.7344 and 10.8281

function dzgt_e4_get_player() { // human player, no bot
	local t_player = null
	while(t_player = Entities.FindByClassname(t_player, "player")) {
		if(t_player.GetTeam() == 2) { // Return player if he's in the terrorist team
			return t_player
		}
	}
	local ct_player = null
	while(ct_player = Entities.FindByClassname(ct_player, "player")) {
		if(ct_player.GetTeam() == 3) { // Return player if he's in the counter-terrorist team
			return ct_player
		}
	}
	return null // No player is in the t or ct team
}

function dzgt_e4_get_point_servercommand() {
	local sv_cmd = Entities.FindByClassname(null, "point_servercommand")
	if(!sv_cmd) { // Create if it doesn't exist
		sv_cmd = Entities.CreateByClassname("point_servercommand")
	}
	return sv_cmd
}

function dzgt_e4_run_server_commands(arr_commands) {
	local ent_sv_cmd = dzgt_e4_get_point_servercommand()
	foreach(cmd in arr_commands) {
		EntFireByHandle(ent_sv_cmd, "command", cmd, 0, null, null)
	}
}

function dzgt_e4_run_server_command(command, delay=0.0) {
	local ent_sv_cmd = dzgt_e4_get_point_servercommand()
	EntFireByHandle(ent_sv_cmd, "command", command, delay, null, null)
}

function setstart() { // Called by user with:   script setstart()
	local player = dzgt_e4_get_player()
	if(player) {
		PLAYER_START_POS = player.GetOrigin()
		PLAYER_START_ANGLES = player.GetAngles() // Only gives player's yaw rotation. Pitch and Roll are 0
		RESPAWN_ITEM_START_POS <- Vector(PLAYER_START_POS.x, PLAYER_START_POS.y, PLAYER_START_POS.z + 30)
		ScriptPrintMessageChatAll("\x01 \x04 New start position was set!")
		dzgt_e4_reset() // Reset to remember the equipped weapons
	} else {
		ScriptPrintMessageChatAll("\x01 \x02 Couldn't set start position: No player found")
	}
}
function Setstart() { setstart() }
function SetStart() { setstart() }
function setStart() { setstart() }
function SETSTART() { setstart() }

function dzgt_e4_loop_tick()
{
	// Just get the first bot
	local bot = Entities.FindByClassname(null, "cs_bot")
	if(bot)
	{
		bot.SetAngles(0,BOT_DIRECTION,0);
		if(!BOT_EQUIPPED) {
			// Equip bot once he has spawned
			if(Time() > BOT_DEATH_TIME + PLAYER_RESPAWN_DELAY) {
				local equipper = Entities.CreateByClassname( "game_player_equip" )
				equipper.__KeyValueFromInt( "spawnflags", 3 ) // 1 - Use Only, 2 - Strip All Weapons First
				equipper.__KeyValueFromInt( "weapon_fists", 0 )
				equipper.ValidateScriptScope()
				EntFireByHandle( equipper, "Use", "", 0, bot, null )
				EntFireByHandle( equipper, "Kill", "", 0.1, null, null )
				
				BOT_EQUIPPED = true
			}
		}
	}
	
	// Just get the first player
	local player = dzgt_e4_get_player()
	if(player)
	{
		local noclipping = player.IsNoclipping()
		if(noclipping != player.GetScriptScope().prev_IsNoclipping) {
			if(noclipping) {
				player.SetHealth(120)
				ScriptPrintMessageChatAll("\x01 Noclip \x02ON")
			} else {
				ScriptPrintMessageChatAll("\x01 Noclip OFF")
			}
			player.GetScriptScope().prev_IsNoclipping = noclipping
		}
	}
}

function dzgt_e4_create_relay()
{
	local relay = Entities.CreateByClassname( "logic_relay" )
	relay.__KeyValueFromString( "targetname", LOGIC_RELAY_NAME )
	relay.__KeyValueFromInt( "spawnflags", 2 ) // 2 -> Allow fast retrigger, don't trigger only once
	
	// Let relay trigger itself each tick so bots stand still
	local tickLength = FrameTime() // Reciprocal of the server tickrate (might change once fps > 1000)
	// target name, input name, parameter, delay, max times to fire (-1 = infinity)
	local targetParams = LOGIC_RELAY_NAME + ":Trigger::" + tickLength + ":-1"	
	EntFireByHandle( relay, "AddOutput", "OnTrigger " + targetParams, 0, null, null )
	
	relay.ValidateScriptScope()
	relay.GetScriptScope().OnTrigger <- dzgt_e4_loop_tick // Add a reference to the function
	relay.ConnectOutput( "OnTrigger", "OnTrigger" ) // On each OnTrigger output, execute the function
	
	EntFireByHandle( relay, "Trigger", "", 0.1, null, null ) // Start trigger loop
}

function dzgt_e4_on_player_death()
{
	if(!activator) return
	
	// WARNING: Giving bots a targetname will change them into a player,
	//          making the cs_bot check fail! (according to Valve Dev Community)
	
	// Check if the first bot in the list died
	if(activator == Entities.FindByClassname(null, "cs_bot"))
	{
		BOT_DEATH_TIME = Time() // Remember death time to know when he respawns
		BOT_EQUIPPED = false // Equip bot once he spawns
		return
	}
	
	// Check if the first player in the list died
	local player = dzgt_e4_get_player()
	if(activator == player)
	{
		local last_death_time = PLAYER_DEATH_TIME
		PLAYER_DEATH_TIME = Time()
		PLAYER_DEATH_POS = player.GetOrigin()
		IS_PLAYER_DEAD = true
		
		// Reset player once he has respawned
		EntFireByHandle(player, "RunScriptFile", "dz_got_talent_e4", PLAYER_RESPAWN_DELAY, null, null)
		
		// If player died because of script initialization, equip him once he respawned
		if(DZGT_E4_FIRST_INIT) {
			dzgt_e4_run_server_command("give weapon_bumpmine", PLAYER_RESPAWN_DELAY + 0.1)
			// Give knife later so player first picks up the knife they had before, if they had one
			dzgt_e4_run_server_command("give weapon_knife_butterfly", PLAYER_RESPAWN_DELAY + 0.6)
		}
		
		// If player died too quickly, his weapons might not have been dropped
		if(PLAYER_DEATH_TIME - last_death_time < DEATH_DROP_COOLDOWN) {
			local msg = "The game doesn't drop your weapons if you die earlier than "
			msg += DEATH_DROP_COOLDOWN + " seconds after your previous death! "
			msg += "Try to not die so quickly again!"
			ScriptPrintMessageChatAll("\x01 \x02" + msg)
		}
		
		return
	}
}

function dzgt_e4_create_playerdeath_listener()
{
	local ent = Entities.CreateByClassname( "trigger_brush" )
	ent.__KeyValueFromString( "targetname", "game_playerdie" )
	ent.SetOrigin(Vector(-1100 1300 -1100))
	ent.ValidateScriptScope()
	ent.GetScriptScope().OnUse <- dzgt_e4_on_player_death // Add a reference to the function
	ent.ConnectOutput( "OnUse", "OnUse" ) // On each OnUse output, execute the function
}

function dzgt_e4_is_initialized() {
	return Entities.FindByName(null, LOGIC_RELAY_NAME) != null
}

function dzgt_e4_init()
{
	// Declare these global variables only during initialization
	BOT_DIRECTION       <- DEFAULT_BOT_DIRECTION
	PLAYER_START_POS    <- DEFAULT_PLAYER_START_POS
	PLAYER_START_ANGLES <- DEFAULT_PLAYER_START_ANGLES
	PLAYER_RESPAWN_WITH_EXOJUMP <- true
	
	BOT_EQUIPPED <- false // If bot holds the correct weapons
	BOT_DEATH_TIME <- Time() - PLAYER_RESPAWN_DELAY + 0.2 // Results in the bot getting equipped shortly
	PLAYER_DEATH_TIME <- -999
	IS_PLAYER_DEAD <- false
	PLAYER_DEATH_POS <- null
	RESPAWN_ITEM_START_POS <- Vector(PLAYER_START_POS.x, PLAYER_START_POS.y, PLAYER_START_POS.z + 30)
	
	// Create noclip table slots for every player on the server
	local player = null
	while(player = Entities.FindByClassname(player, "player")) {
		player.ValidateScriptScope()
		local playerScope = player.GetScriptScope()
		playerScope.prev_IsNoclipping <- false
	}
	
	
	local commands = [
		"sv_cheats 1",
		"sv_dz_warmup_tablet 0",
		"sv_dz_parachute_reuse 0",
		"sv_infinite_ammo 1",
		"mp_autokick 0",
		"mp_dronegun_stop 1",
		"mp_respawn_immunitytime -1", // Disable respawn immunity
		"mp_warmup_pausetimer 1",
		"bot_stop 1",
		"bot_loadout \"\"",
		"bot_mimic 0",
		"bot_kick",
		"bot_quota 1",
		"bot_quota_mode normal",
		// Shorten respawn time after player/bot died. spec_freeze_* commands possibly
		// affect PLAYER_RESPAWN_DELAY and DEATH_DROP_COOLDOWN, test after changing them!
		"spec_freeze_time 0.5",
		"spec_freeze_time_lock 0",
		"spec_freeze_panel_extended_time 0",
		"spec_freeze_deathanim_time 0"
	]
	
	dzgt_e4_run_server_commands(commands)
	
	// Teleport bot to his position shortly, once he's spawned in
	local bot_pos_string = BOT_POSITION.x + " " + BOT_POSITION.y + " " + BOT_POSITION.z
	EntFire("cs_bot", "AddOutput", "origin " + bot_pos_string, 0.05)
	
	dzgt_e4_create_relay()
	dzgt_e4_create_playerdeath_listener()
	dzgt_e4_print_help()
}

function dzgt_e4_print_equip_help()
{
	printl("");printl("");printl("")
	printl("--- SOME COMMANDS TO EQUIP WEAPONS AND UTILITY ---")
	printl("")
	printl("DIFFERENT KNIVES:")
	printl("    give weapon_knife")
	printl("    give weapon_knife_t")
	printl("    give weapon_knife_css")
	printl("    give weapon_bayonet")
	printl("    give weapon_knife_flip")
	printl("    give weapon_knife_gut")
	printl("    give weapon_knife_karambit")
	printl("    give weapon_knife_m9_bayonet")
	printl("    give weapon_knife_tactical")
	printl("    give weapon_knife_butterfly")
	printl("    give weapon_knife_falchion")
	printl("    give weapon_knife_push")
	printl("    give weapon_knife_survival_bowie")
	printl("    give weapon_knife_ursus")
	printl("    give weapon_knife_gypsy_jackknife")
	printl("    give weapon_knife_stiletto")
	printl("    give weapon_knife_widowmaker")
	printl("    give weapon_knife_canis")
	printl("    give weapon_knife_cord")
	printl("    give weapon_knife_skeleton")
	printl("    give weapon_knife_outdoor")
	printl("")
	printl("EXPLOSIVES:")
	printl("    give weapon_breachcharge")
	printl("    give weapon_hegrenade")
	printl("    give weapon_c4")
	printl("")
	printl("OTHER DANGER ZONE ITEMS:")
	printl("    give weapon_bumpmine")
	printl("    give weapon_taser")
	printl("    give weapon_healthshot")
	printl("    give weapon_shield")
	printl("    give weapon_molotov")
	printl("    give weapon_axe")
	printl("    give weapon_hammer")
	printl("    give weapon_spanner")
	printl("    give prop_weapon_upgrade_armor_helmet")
	printl("")
	printl("DEFAULT:")
	printl("    exojump;give weapon_bumpmine;give weapon_knife_butterfly")
	printl("")
}

function dzgt_e4_reset()
{
	// Don't do anything if player just died and hasn't respawned yet!
	if(IS_PLAYER_DEAD && Time() - PLAYER_DEATH_TIME < PLAYER_RESPAWN_DELAY - 0.05) {
		return
	}
	
	// Select first player in the list
	local player = dzgt_e4_get_player()
	if(player)
	{
		local playerscope = player.GetScriptScope()
		
		if(IS_PLAYER_DEAD) // If this is the first reset after the player's death and respawn
		{
			if(PLAYER_RESPAWN_WITH_EXOJUMP) {
				dzgt_e4_run_server_command("exojump")
			}
			
			local ent = null
			while(ent = Entities.FindByClassname(ent, "weapon_*")) {
				// Delete player's starting pistol
				if(ent.GetOwner() == player && ent.GetClassname() != "weapon_fists") {
					ent.Destroy()
				}
			}
			
			// Teleport dropped weapons from death position to start position
			// Dropped C4 sadly doesn't get teleported :(
			local wpn = null
			while(wpn = Entities.FindByClassnameWithin(wpn, "weapon_*", PLAYER_DEATH_POS, 1000)) {
				if(wpn.IsValid() && wpn.GetOwner() == null && wpn.GetClassname() != "weapon_fists") {
					wpn.SetOrigin(RESPAWN_ITEM_START_POS)
					//wpn.SetVelocity(Vector(0,0,0))
				}
			}
			
			IS_PLAYER_DEAD = false // Mark that the player is no longer dead
		}
		else
		{ // Normal reset, delete every weapon without an owner
			local ent = null
			while(ent = Entities.FindByClassname(ent, "weapon_*")) {
				if(ent.GetOwner() == null) {
					ent.Destroy()
				}
			}
		}
		
		player.SetVelocity(Vector(0,0,0))
		player.SetAngles(0, PLAYER_START_ANGLES.y, 0) // player's .GetAngles() only gives yaw rotation
		player.SetOrigin(PLAYER_START_POS)
		player.SetHealth(120)
		dzgt_e4_run_server_command("noclip 0")
	}
	
	local bot = Entities.FindByClassname(null, "cs_bot")
	if(bot)
	{
		bot.SetVelocity(Vector(0,0,0))
		bot.SetAngles(0.0, BOT_DIRECTION, 0.0)
		bot.SetOrigin(BOT_POSITION)
		bot.SetHealth(120)
		
		// If bot is currently dead and awaiting respawn, teleport him right after his respawn
		local timeTillBotSpawn = (BOT_DEATH_TIME + PLAYER_RESPAWN_DELAY) - Time()
		if(timeTillBotSpawn >= 0.0)
		{
			local bot_pos_string = BOT_POSITION.x + " " + BOT_POSITION.y + " " + BOT_POSITION.z
			EntFireByHandle(bot, "AddOutput", "origin " + bot_pos_string, timeTillBotSpawn, null, null)
		}
	}
	
	local entities_to_kill = [
		"weapon_tablet",
		"bumpmine_projectile",
		"breachcharge_projectile",
		"planted_c4_survival",
		"hegrenade_projectile",
		"decoy_projectile",
		"flashbang_projectile",
		"molotov_projectile", // Bug: molotov sound stays on new entities after reset
		"smokegrenade_projectile"
	]
	
	foreach(item in entities_to_kill) {
		EntFire(item, "AddOutput", "origin 0 0 8000")
		EntFire(item, "DisableDraw")
		EntFire(item, "Kill", "", 0.1) // Delayed kill so the teleport actually happens
	}
	
	dzgt_e4_print_equip_help()
	
	dzgt_e4_run_server_command("r_cleardecals") // Only happens for hosting player
}

function dzgt_e4_check_game_settings()
{
	local illegalMap = GetMapName().find("dz_county") == null
	local illegalGamemode = ScriptGetGameMode() != 0 || ScriptGetGameType() != 6
	local illegalTickrate = FrameTime() != 0.015625 // 64 tick is required
	
	if(illegalMap)
	{
		ScriptPrintMessageChatAll("\x01 \x09 This practice script was made to be played on dz_county, not "
			+ GetMapName())
		ScriptPrintMessageCenterAll("This script won't work, it was made for dz_county!")
	}
	if(illegalGamemode)
	{
		ScriptPrintMessageChatAll("\x01 \x02 !!! ILLEGAL GAMEMODE !!!")
		ScriptPrintMessageChatAll("\x01 \x02 You must play in the Danger Zone gamemode. To do that,")
		ScriptPrintMessageChatAll("\x01 \x02 enter the following into the console:")
		ScriptPrintMessageChatAll("\x01 \x09 game_mode 0;game_type 6;map dz_county")
		if(!illegalMap && !illegalTickrate) {
			ScriptPrintMessageCenterAll("Illegal gamemode! Load the map in the Danger Zone gamemode!")
		}
	}
	if(illegalTickrate)
	{
		local tickrate = (1.0 / FrameTime()).tointeger();
		ScriptPrintMessageChatAll("\x01 \x02 !!! ILLEGAL TICKRATE !!!")
		ScriptPrintMessageChatAll("\x01 \x02 The only allowed tickrate is 64, yours is currently "
			+ tickrate + ".")
		ScriptPrintMessageChatAll("\x01 \x02 Restart CSGO without the \"-tickrate x\" launch option.")
		if(!illegalMap) {
			ScriptPrintMessageCenterAll("Illegal tickrate! Restart CSGO with a tickrate of 64!")
		}
	}
}

function dzgt_e4_print_help()
{
	ScriptPrintMessageChatAll("\x01 \x04| \x01 The practice can begin! To change your starting position,")
	ScriptPrintMessageChatAll("\x01 \x04| \x01 enter the following into the console:")
	ScriptPrintMessageChatAll("\x01 \x04| \x05 script setstart()")
	ScriptPrintMessageChatAll("\x01 \x04| \x01 To change the bot's viewing direction, enter the following")
	ScriptPrintMessageChatAll("\x01 \x04| \x01 with any angle value into the console:")
	ScriptPrintMessageChatAll("\x01 \x04| \x05 script BOT_DIRECTION = 270")
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////

// Script initialization and reset only make sense in warmup
if(ScriptIsWarmupPeriod())
{
	// Check if this script was run before
	if(!dzgt_e4_is_initialized()) {
		DZGT_E4_FIRST_INIT <- true
		dzgt_e4_init()
		
		// Kill player to remove parachute and exojump
		dzgt_e4_run_server_command("noclip 0")
		dzgt_e4_run_server_command("kill", 0.1) // Kill with delay to make sure the player death listener is initialized
		// Player gets equipped with exojump, knife, bumpmines once he respawns
	} else {
		DZGT_E4_FIRST_INIT <- false
		dzgt_e4_reset()
	}
}
else
{
	dzgt_e4_run_server_command("mp_warmup_start")
	dzgt_e4_run_server_command("mp_warmup_pausetimer 1")
	
	ScriptPrintMessageChatAll("\x01 \x02| \x01 The practice script only works in warmup!")
	ScriptPrintMessageChatAll("\x01 \x02| \x01 Execute the script again to start.")
	ScriptPrintMessageChatAll("\x01 \x02| \x01 ")
	ScriptPrintMessageChatAll("\x01 \x02| \x01 If the zone appears in warmup, reload the map:")
	ScriptPrintMessageChatAll("\x01 \x02| \x04 game_mode 0;game_type 6;map dz_county")
}
// Check if we're on the correct map, gamemode and tickrate
dzgt_e4_check_game_settings()
