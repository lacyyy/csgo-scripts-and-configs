/////////////////////////////////////////////////////////////////////////////////////////////////////
// Purpose: This script was used to practice for the sixth episode of the Bump Mine Competition
//          "Danger Zone's Got Talent": https://youtube.com/playlist?list=PLyCGb0pwEr_SHF2ef6XJBpvQUfpY_oaXe
// 
// Disclaimer: This script contains code from https://github.com/samisalreadytaken/vs_library
//             It is licensed under an MIT license. Copyright (c) samisalreadytaken
// 
// HOW TO INSTALL AND USE:
//   To install, put this file into the following folder:
//       Steam\steamapps\common\Counter-Strike Global Offensive\csgo\scripts\vscripts
//   In CSGO, load the correct map by entering this into the console: game_mode 0;game_type 6;map dz_ember
//   To start and reset the practice, enter this into the console: script_execute dz_got_talent_e6
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

// To update this, use command "getpos_exact" and take the first 3 values
BOT_POSITION <- Vector(1618.865234, -1476.367676, -773.640686)

DEFAULT_BOT_DIRECTION <- 180.0

// To update this, use command "getpos_exact" and take the first 3 values
DEFAULT_PLAYER_START_POS <- Vector(3346.325928, 3105.773438, -1974.889526)

// To update this, use command "getpos" and take the *last* 3 values
DEFAULT_PLAYER_START_ANGLES <- Vector(2.649976, -145.992126, 0.000000)

///////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////

// spec_freeze_* commands possibly affect PLAYER_RESPAWN_DELAY and DEATH_DROP_COOLDOWN!
// Don't change spec_freeze_* commands without testing!

// Time duration between player/bot death and respawn
const PLAYER_RESPAWN_DELAY = 0.9 
// Player doesn't drop items upon death if his last death was less than this many seconds ago!
const DEATH_DROP_COOLDOWN = 10.8 // Testing shows it's between 10.7344 and 10.8281

function dzgt_e6_get_player() { // human player, no bot
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

function dzgt_e6_get_point_servercommand() {
	local sv_cmd = Entities.FindByClassname(null, "point_servercommand")
	if(!sv_cmd) { // Create if it doesn't exist
		sv_cmd = Entities.CreateByClassname("point_servercommand")
	}
	return sv_cmd
}

function dzgt_e6_run_server_commands(arr_commands) {
	local ent_sv_cmd = dzgt_e6_get_point_servercommand()
	foreach(cmd in arr_commands) {
		EntFireByHandle(ent_sv_cmd, "command", cmd, 0, null, null)
	}
}

function dzgt_e6_run_server_command(command, delay=0.0) {
	local ent_sv_cmd = dzgt_e6_get_point_servercommand()
	EntFireByHandle(ent_sv_cmd, "command", command, delay, null, null)
}

function setstart() { // Called by user with:   script setstart()
	local player = dzgt_e6_get_player()
	if(player) {
		PLAYER_START_POS = player.GetOrigin()
		PLAYER_START_ANGLES = player.GetAngles() // Only gives player's yaw rotation. Pitch and Roll are 0
		RESPAWN_ITEM_START_POS <- Vector(PLAYER_START_POS.x, PLAYER_START_POS.y, PLAYER_START_POS.z + 30)
		ScriptPrintMessageChatAll("\x01 \x04 New start position was set!")
		dzgt_e6_reset() // Reset to remember the equipped weapons
	} else {
		ScriptPrintMessageChatAll("\x01 \x02 Couldn't set start position: No player found")
	}
}
function Setstart() { setstart() }
function SetStart() { setstart() }
function setStart() { setstart() }
function SETSTART() { setstart() }

function dzgt_e6_loop_tick()
{
    dzgt_e6_check_for_new_round()

    /*
    if (WANT_BOT_GLOW_ENABLED != HAVE_BOT_GLOW_ENABLED) {
        if(WANT_BOT_GLOW_ENABLED) {
            EntFireByHandle(self, "RunScriptCode", "dzgt_e6_enable_bot_glow()", 0.1, null, null) // Delay because glow.nut script might not have run yet
        } else {
            EntFireByHandle(self, "RunScriptCode", "dzgt_e6_disable_bot_glow()", 0.1, null, null) // Delay because glow.nut script might not have run yet
        }
    }
    */

	// Just get the first bot
	local bot = Entities.FindByClassname(null, "cs_bot")
    //if(bot == null)
    //    HAVE_BOT_GLOW_ENABLED = false // Make sure glow gets enabled for the next bot that appears
    

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
	local player = dzgt_e6_get_player()
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

function dzgt_e6_check_for_new_round() {
    // Our dummy entity gets deleted by the game every time a new warmup or round starts
    if (DUMMY_ENTITY == null || !DUMMY_ENTITY.IsValid()) {
        DUMMY_ENTITY = Entities.CreateByClassname("logic_script")
        dzgt_e6_on_new_round()
    }
}

// This function gets called when this script gets run for the first time,
// when warmup starts/restarts/ends and when a new round starts
function dzgt_e6_on_new_round() {
    // Our geyser setup must be delayed because dz_ember's geyser script must initialize itself first
    EntFireByHandle(self, "RunScriptCode", "dzgt_e6_setup_geysers()", 0.3, null, null)
}

function dzgt_e6_setup_geysers() {
    // @geysers_script must have already run its script before being able to access its scope
    local geyser_script_scope = Entities.FindByName(null, "@geysers_script").GetScriptScope()
    geyser_script_scope.UpdateGeyserTimers = function(){} // This makes geysers stay on/off forever

    // Enable all geysers
    for(local i = 0; i < geyser_script_scope.numOfGeysers; i++) {
        // Enable with a delay greater than 2 seconds in order to overwrite other
        // potentially pending enable/disable calls that have a delay of 2 seconds
        EntFire("@geysers_script", "RunScriptCode", ("EnableGeyser2(" + i + ")"), 2.50, null);
    }
}

function ENABLEGEYSER(i) { enablegeyser(i) }
function EnableGeyser(i) { enablegeyser(i) }
function Enablegeyser(i) { enablegeyser(i) }
function enablegeyser(i) {
    // @geysers_script must have already run its script before being able to access its scope
    local geyser_script_scope = Entities.FindByName(null, "@geysers_script").GetScriptScope()
    if (i < 0 || i >= geyser_script_scope.numOfGeysers) {
        ScriptPrintMessageChatAll("\x01 \x02Not allowed! Choose a number from 0 to " + (geyser_script_scope.numOfGeysers - 1))
        return
    }
    geyser_script_scope.EnableGeyser(i)
    ScriptPrintMessageChatAll("Geyser " + i + " has been enabled.")
}

function DISABLEGEYSER(i) { disablegeyser(i) }
function DisableGeyser(i) { disablegeyser(i) }
function Disablegeyser(i) { disablegeyser(i) }
function disablegeyser(i) {
    // @geysers_script must have already run its script before being able to access its scope
    local geyser_script_scope = Entities.FindByName(null, "@geysers_script").GetScriptScope()
    if (i < 0 || i >= geyser_script_scope.numOfGeysers) {
        ScriptPrintMessageChatAll("\x01 \x02Not allowed! Choose a number from 0 to " + (geyser_script_scope.numOfGeysers - 1))
        return
    }
    geyser_script_scope.DisableGeyser(i)
    ScriptPrintMessageChatAll("Geyser " + i + " has been disabled.")
}

const DZGT_E6_TIMER_NAME = "dzgt_ep6_timer"

/*
function BOT_GLOW_ON() { bot_glow_on() }
function Bot_Glow_On() { bot_glow_on() }
function bot_glow_on() { WANT_BOT_GLOW_ENABLED = true }

function BOT_GLOW_OFF() { bot_glow_off() }
function Bot_Glow_Off() { bot_glow_off() }
function bot_glow_off() { WANT_BOT_GLOW_ENABLED = false }


function dzgt_e6_enable_bot_glow() {
    if(HAVE_BOT_GLOW_ENABLED) return
    local bot = Entities.FindByClassname(null, "cs_bot")
    if(bot == null) return
    Glow.Set(bot, "255 100 0", 0, 10000)
    ScriptPrintMessageChatAll("Bot glow has been enabled.")
    HAVE_BOT_GLOW_ENABLED = true
}

function dzgt_e6_disable_bot_glow() {
    if(!HAVE_BOT_GLOW_ENABLED) return
    local bot = Entities.FindByClassname(null, "cs_bot")
    if(bot == null) return
    Glow.Disable(bot)
    ScriptPrintMessageChatAll("Bot glow has been disabled.")
    HAVE_BOT_GLOW_ENABLED = false
}
*/

function dzgt_e6_is_initialized() {
	return Entities.FindByName(null, DZGT_E6_TIMER_NAME) != null
}

function dzgt_e6_create_timer()
{
    // Create a new timer
    local timer = Entities.CreateByClassname( "logic_timer" )
    timer.ConnectOutput( "OnTimer", "OnTimer" )

    // This is a hack that turns our logic_timer into a preserved entity,
    // causing it to NOT get reset/destroyed during a round reset!
    timer.__KeyValueFromString("classname", "info_target")

    timer.__KeyValueFromString( "targetname", DZGT_E6_TIMER_NAME )
    timer.__KeyValueFromFloat( "refiretime", 0.0 ) // Fire timer every tick

    timer.ValidateScriptScope()
    timer.GetScriptScope().OnTimer <- dzgt_e6_loop_tick
    
    EntFireByHandle( timer, "Enable", "", 0.0, null, null )
}

function dzgt_e6_on_player_death()
{
	if(!activator) return
	
	// WARNING: Giving bots a targetname will change them into a player,
	//          making the cs_bot check fail! (according to Valve Dev Community)
	
    local player = dzgt_e6_get_player()

	// Check if the first bot in the list died
	if(activator == Entities.FindByClassname(null, "cs_bot"))
	{
		BOT_DEATH_TIME = Time() // Remember death time to know when he respawns
		BOT_EQUIPPED = false // Equip bot once he spawns

        DispatchParticleEffect("firework_crate_explosion_02", activator.GetOrigin(), Vector())
        DispatchParticleEffect("weapon_confetti_omni", activator.GetOrigin(), Vector())
        
        if(player != null) {
            player.EmitSound("UI.ArmsRace.BecomeMatchLeader")

            // Alternative kill sounds:
            //player.EmitSound("Music.CP_PointCaptured_CT")
            //player.EmitSound("Music.CP_PointCaptured_T")
            //player.EmitSound("Music.Kill_01")
            //player.EmitSound("Music.Kill_02")
            //player.EmitSound("Music.Kill_03")
            //player.EmitSound("Player.GhostKnifeSwish")
            //player.EmitSound("tr.BellNormal")
            //player.EmitSound("tr.ScoreRegular")
            //player.EmitSound("UI.ArmsRace.LevelUp")
            //player.EmitSound("windchimes.snd01")
        }
        return
	}
	
	// Check if the first player in the list died
	if(activator == player)
	{
		local last_death_time = PLAYER_DEATH_TIME
		PLAYER_DEATH_TIME = Time()
		PLAYER_DEATH_POS = player.GetOrigin()
		IS_PLAYER_DEAD = true
		
		// Reset player once he has respawned
		EntFire(DZGT_E6_TIMER_NAME, "RunScriptCode", "dzgt_e6_run_script()", PLAYER_RESPAWN_DELAY)
		
		// If player died because of script initialization, equip him once he respawned
		if(DZGT_E6_FIRST_INIT) {
			dzgt_e6_run_server_command("give weapon_bumpmine", PLAYER_RESPAWN_DELAY + 0.1)
			// Give knife later so player first picks up the knife they had before, if they had one
			dzgt_e6_run_server_command("give weapon_knife_butterfly", PLAYER_RESPAWN_DELAY + 0.6)
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

function dzgt_e6_create_playerdeath_listener()
{
	local ent = Entities.CreateByClassname( "trigger_brush" )
	ent.__KeyValueFromString( "targetname", "game_playerdie" )
	ent.SetOrigin(Vector(-1100 1300 -1100))
	ent.ValidateScriptScope()
	ent.GetScriptScope().OnUse <- dzgt_e6_on_player_death // Add a reference to the function
	ent.ConnectOutput( "OnUse", "OnUse" ) // On each OnUse output, execute the function
}

function dzgt_e6_init()
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
	
    DUMMY_ENTITY <- null // Some entity that's used for detection of a new round

    /*
    WANT_BOT_GLOW_ENABLED <- true
    HAVE_BOT_GLOW_ENABLED <- false
    */

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
	
	dzgt_e6_run_server_commands(commands)
	
	// Teleport bot to his position shortly, once he's spawned in
	local bot_pos_string = BOT_POSITION.x + " " + BOT_POSITION.y + " " + BOT_POSITION.z
	EntFire("cs_bot", "AddOutput", "origin " + bot_pos_string, 0.05)
	
	dzgt_e6_create_timer()
	dzgt_e6_create_playerdeath_listener()
	dzgt_e6_print_help()
}

function dzgt_e6_print_equip_help()
{
	printl("");printl("");printl("")
	printl("--- SOME COMMANDS TO EQUIP WEAPONS AND UTILITY ---")
	printl("")
	printl("DIFFERENT KNIVES (If you have a knife skin, you first need to unequip it in the main menu):")
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

function dzgt_e6_reset()
{
	// Don't do anything if player just died and hasn't respawned yet!
	if(IS_PLAYER_DEAD && Time() - PLAYER_DEATH_TIME < PLAYER_RESPAWN_DELAY - 0.05) {
		return
	}
	
	// Select first player in the list
	local player = dzgt_e6_get_player()
	if(player)
	{
		local playerscope = player.GetScriptScope()
		
		if(IS_PLAYER_DEAD) // If this is the first reset after the player's death and respawn
		{
			if(PLAYER_RESPAWN_WITH_EXOJUMP) {
				dzgt_e6_run_server_command("exojump")
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
		dzgt_e6_run_server_command("noclip 0")
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
	
	dzgt_e6_print_equip_help()
	
	dzgt_e6_run_server_command("r_cleardecals") // Only happens for hosting player
}

function dzgt_e6_check_game_settings()
{
	local illegalMap = GetMapName().find("dz_ember") == null
	local illegalGamemode = ScriptGetGameMode() != 0 || ScriptGetGameType() != 6
	local illegalTickrate = FrameTime() != 0.015625 // 64 tick is required
	
	if(illegalMap)
	{
		ScriptPrintMessageChatAll("\x01 \x09 This practice script was made to be played on dz_ember, not "
			+ GetMapName())
		ScriptPrintMessageCenterAll("This script won't work, it was made for dz_ember!")
	}
	if(illegalGamemode)
	{
		ScriptPrintMessageChatAll("\x01 \x02 !!! ILLEGAL GAMEMODE !!!")
		ScriptPrintMessageChatAll("\x01 \x02 You must play in the Danger Zone gamemode. To do that,")
		ScriptPrintMessageChatAll("\x01 \x02 enter the following into the console:")
		ScriptPrintMessageChatAll("\x01 \x09 game_mode 0;game_type 6;map dz_ember")
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

function dzgt_e6_print_help()
{
    ScriptPrintMessageChatAll("\x01 \x04| \x01 The DZGT practice can begin! Bump Mines now trigger")
	ScriptPrintMessageChatAll("\x01 \x04| \x01 consistently! To change your starting position, enter the")
    ScriptPrintMessageChatAll("\x01 \x04| \x01 following into the console:")
	ScriptPrintMessageChatAll("\x01 \x04| \x05 script setstart()")
	ScriptPrintMessageChatAll("\x01 \x04| \x01 To change the bot's viewing direction, enter the following")
	ScriptPrintMessageChatAll("\x01 \x04| \x01 with any angle value into the console:")
	ScriptPrintMessageChatAll("\x01 \x04| \x05 script BOT_DIRECTION = 270")
    ScriptPrintMessageChatAll("\x01 \x04| \x01 To enable/disable a specific geyser, enter the following")
	ScriptPrintMessageChatAll("\x01 \x04| \x01 into the console (replace x with a number from 0 to 10):")
	ScriptPrintMessageChatAll("\x01 \x04| \x05 script enablegeyser(x)")
    ScriptPrintMessageChatAll("\x01 \x04| \x05 script disablegeyser(x)")
    //ScriptPrintMessageChatAll("\x01 \x04| \x01 To enable/disable the bot's glow, use:")
	//ScriptPrintMessageChatAll("\x01 \x04| \x05 script bot_glow_on()")
    //ScriptPrintMessageChatAll("\x01 \x04| \x05 script bot_glow_off()")
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////

function dzgt_e6_run_script() {
    // Script initialization and reset only make sense in warmup
    if(ScriptIsWarmupPeriod())
    {
        // Check if this script was run before
        if(!dzgt_e6_is_initialized()) {
            DZGT_E6_FIRST_INIT <- true
            dzgt_e6_init()
            
            // Kill player to remove parachute and exojump
            dzgt_e6_run_server_command("noclip 0")
            dzgt_e6_run_server_command("kill", 0.1) // Kill with delay to make sure the player death listener is initialized
            // Player gets equipped with exojump, knife, bumpmines once they respawn
        } else {
            DZGT_E6_FIRST_INIT <- false
            dzgt_e6_reset()
        }
    }
    else
    {
        dzgt_e6_run_server_command("mp_warmup_start")
        dzgt_e6_run_server_command("mp_warmup_pausetimer 1")
        
        ScriptPrintMessageChatAll("\x01 \x02| \x01 The practice script only works in warmup!")
        ScriptPrintMessageChatAll("\x01 \x02| \x01 Execute the script again to start.")
        ScriptPrintMessageChatAll("\x01 \x02| \x01 ")
        ScriptPrintMessageChatAll("\x01 \x02| \x01 If the zone appears in warmup, reload the map:")
        ScriptPrintMessageChatAll("\x01 \x02| \x04 game_mode 0;game_type 6;map dz_ember")
    }
    // Check if we're on the correct map, gamemode and tickrate
    dzgt_e6_check_game_settings()
}

dzgt_e6_run_script()

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// Made for Sandwich's "Danger Zone's Got Talent" bumpmine competition: https://youtu.be/WZkVBxdewTo
// Script made by lacyyy: https://steamcommunity.com/profiles/76561198162669616
///////////////////////////////////////////////////////////////////////////////////////////////////////////

// Here follows a script that makes Bump Mines trigger consistently taken from https://github.com/lacyyy/csgo-scripts-and-configs
///////////////////////////////////////////////////////////////////////////////////////////////////////////

// BM_TRIGGER_FIX_* name prefixes are abbreviated as BMTF_*

// -- GAME CONSTANTS --
::BMTF_BM_ARM_DELAY <- 0.3 // in seconds (update this value if cvar value sv_bumpmine_arm_delay is different)
::BMTF_BM_ARM_DELAY_TICKS <- (BMTF_BM_ARM_DELAY / FrameTime() + 0.5).tointeger()
::BMTF_BM_DETONATE_DELAY <- 0.25 // in seconds (update this value if cvar value sv_bumpmine_detonate_delay is different)
::BMTF_BM_DETONATE_DELAY_TICKS <- (BMTF_BM_DETONATE_DELAY / FrameTime() + 0.5).tointeger()
::BMTF_BM_THINK_INTERVAL <- 0.1 // bumpmine trigger check interval in seconds
::BMTF_BM_THINK_INTERVAL_TICKS <- (BMTF_BM_THINK_INTERVAL / FrameTime() + 0.5).tointeger()
::BMTF_BM_BOOST_COOLDOWN <- 0.4 // in seconds, per player, between each bumpmine detonation
::BMTF_BM_BOOST_SPEED <- 1200 // Velocity added to player during bm detonation
::BMTF_BM_AABB_DIST <- 81 // Length of bumpmine trigger check AABB in +X,-X,+Y,-Y,+Z,-Z direction
::BMTF_PLAYER_AABB_WIDTH <- 32
::BMTF_PLAYER_AABB_HEIGHT_STANDING <- 72
::BMTF_PLAYER_AABB_HEIGHT_CROUCHING <- 54
// Max distance (from bm origin to player center) that a player can trigger a bm(exact value is ca. 121), squared
::BMTF_MAX_PLAYER_BM_TRIG_DIST_SQR <- 150*150 // Used to speed up trigger calculations

// -- SCRIPT DATA --
::BMTF_LOGIC_TIMER_NAME <- "bm_trigger_fix_timer"
::BMTF_FIRST_INIT <- Entities.FindByName(null, BMTF_LOGIC_TIMER_NAME ) == null

// If script was run before, keep the old bumpmine tables to remember each bm's age!
if (BMTF_FIRST_INIT) {
    ::BMTF_TABLE_player_last_boost <- {} // Each value is the Time() value from when the player was last boosted

    // Tables of data of each bumpmine. Slots are bumpmine_projectile handles

    // Each value is an int, the number of ticks since the bm was placed
    ::BMTF_TABLE_bm_ticks <- {}
    // Each value is the player that triggered the bm, or null if not yet triggered by a player.
    // This value is null for a real/original bm and non-null for a dummy bm
    ::BMTF_TABLE_bm_triggering_player <- {}
    // Each value is an int, the value of BMTF_TABLE_bm_ticks when the bm was first triggered by a player
    ::BMTF_TABLE_bm_trigger_tick <- {}
    
    // All placed bumpmines on the map are assumed to be armed (even though they might not be).
    // We don't care because this inaccuracy only occurs when running the script for the first time.
    local bm = null
    while (bm = Entities.FindByClassname(bm, "bumpmine_projectile")) {
        if (!bm.IsValid() || bm.GetMoveParent() == null)
            continue
        BMTF_TABLE_bm_ticks[bm] <- 2 * BMTF_BM_ARM_DELAY_TICKS // Pretend that bm is armed
        BMTF_TABLE_bm_triggering_player[bm] <- null
        BMTF_TABLE_bm_trigger_tick[bm] <- -1
    }

}

::bmtf_del_bm_table_entries <- function(bm) {
    delete BMTF_TABLE_bm_ticks[bm]
    delete BMTF_TABLE_bm_triggering_player[bm]
    delete BMTF_TABLE_bm_trigger_tick[bm]
}

::bmtf_is_alive_player <- function(player) {
    // If player is dead, in no team or a spectator, their health is 0
    if (!player || !player.IsValid() || player.GetHealth() == 0) return false
    return true
}

// Credit to zer0.k for reverse engineering the precise formula
::bmtf_accurate_bm_trigger_check <- function(bm, player) {
    local bm_origin = bm.GetOrigin()
    local p_center_dist_vec = player.GetCenter() - bm_origin

    // Abort if player is too far away (purely for optimization)
    if (p_center_dist_vec.LengthSqr() > BMTF_MAX_PLAYER_BM_TRIG_DIST_SQR) return false

    // Point of the player's AABB that is the nearest to the bumpmine
    local p_mins = player.GetOrigin() + player.GetBoundingMins()
    local p_maxs = player.GetOrigin() + player.GetBoundingMaxs()
    local nearest_p_point = Vector(bm_origin.x, bm_origin.y, bm_origin.z)
    if (nearest_p_point.x < p_mins.x) nearest_p_point.x = p_mins.x
    if (nearest_p_point.y < p_mins.y) nearest_p_point.y = p_mins.y
    if (nearest_p_point.z < p_mins.z) nearest_p_point.z = p_mins.z
    if (nearest_p_point.x > p_maxs.x) nearest_p_point.x = p_maxs.x
    if (nearest_p_point.y > p_maxs.y) nearest_p_point.y = p_maxs.y
    if (nearest_p_point.z > p_maxs.z) nearest_p_point.z = p_maxs.z
    
    // Return false if player AABB doesn't intersect with the bumpmine trigger AABB
    if (fabs(nearest_p_point.x - bm_origin.x) > BMTF_BM_AABB_DIST) return false
    if (fabs(nearest_p_point.y - bm_origin.y) > BMTF_BM_AABB_DIST) return false
    if (fabs(nearest_p_point.z - bm_origin.z) > BMTF_BM_AABB_DIST) return false
    
    // Check if player center point is inside the bumpmine's trigger ellipsoid
    local p_center_dist = p_center_dist_vec.Length()
    local x = fabs(p_center_dist_vec.Dot(bm.GetUpVector()) / (p_center_dist + 0.00000011920929)) - 0.02
    if (x < 0.0) x = 0.0
    if (x > 1.0) x = 1.0
    local final = ((x * -1.5) + 2.0) * p_center_dist
    return final <= 64.0
}

::bmtf_loop_tick <- function()
{
    local current_time = Time()
    local deletable_slots = []

    // Get players that are allowed to trigger bumpmines (alive and in T or CT team)
    local alive_players = []
    local ent_p = null, ent_b = null
    while (ent_p = Entities.FindByClassname(ent_p, "player")) if (bmtf_is_alive_player(ent_p)) alive_players.push(ent_p)
    while (ent_b = Entities.FindByClassname(ent_b, "cs_bot")) if (bmtf_is_alive_player(ent_b)) alive_players.push(ent_b)

    // Remove slots of invalid players
    deletable_slots = []
    foreach (p, x in BMTF_TABLE_player_last_boost) {
        if(!p || !p.IsValid())
            deletable_slots.push(p)
    }
    foreach (p in deletable_slots)
        delete BMTF_TABLE_player_last_boost[p]
    // Add slots of new players
    foreach (p in alive_players) {
        if (p.IsValid() && !(p in BMTF_TABLE_player_last_boost))
            BMTF_TABLE_player_last_boost[p] <- -999
    }

    // Delete table slots of bumpmines we no longer care about
    deletable_slots = []
    foreach (bm, value in BMTF_TABLE_bm_ticks) {
        local is_dummy_bm = BMTF_TABLE_bm_triggering_player[bm] != null
        // Bumpmines that detonated, were deleted or were freed from their parent, now falling, BUT:
        // We keep dummy bumpmines because they are currently detonating (dummy detonation is handled by this script)!
        if (!bm.IsValid() || (!is_dummy_bm && bm.GetMoveParent() == null))
            deletable_slots.push(bm)
    }
    foreach (bm in deletable_slots)
        bmtf_del_bm_table_entries(bm)

    // Increment tick count of every bm that we keep track of to know its age
    foreach (bm, x in BMTF_TABLE_bm_ticks)
        BMTF_TABLE_bm_ticks[bm] += 1

    // Check if new bumpmines were placed
    local bm = null
    while (bm = Entities.FindByClassname(bm, "bumpmine_projectile")) {
        // Only add bm to tables if bm is not already in tables and is not a dummy bm(which is already
        // tracked in tables), but instead an original bm placed on a surface or entity
        if (!bm.IsValid() || bm.GetMoveParent() == null || bm in BMTF_TABLE_bm_ticks)
            continue
        // Add bumpmine to tables
        BMTF_TABLE_bm_ticks[bm] <- 0
        BMTF_TABLE_bm_triggering_player[bm] <- null
        BMTF_TABLE_bm_trigger_tick[bm] <- -1
    }

    // Check if bumpmines are detonating(apply boost) or being triggered by players
    local bm_check_list = [] // Copy list, I don't trust Squirrel with simultaneous table iteration and modification
    foreach (bm, x in BMTF_TABLE_bm_ticks)
        bm_check_list.push(bm)
    foreach (bm in bm_check_list) {
        local bm_origin = bm.GetOrigin()
        local is_detonating_dummy_bm = BMTF_TABLE_bm_triggering_player[bm] != null
        
        if (!is_detonating_dummy_bm) { // If it's an original bm, check if it's being triggered by a player
            // Skip if bm is not armed yet. Measuring this arming time must be precise.
            // If we would underestimate arming time here, the player could trigger a bm too early.
            // If we would overestimate arming time here, the player could trigger the bm during the time period
            // in which the bm is actually armed and this script thinks the bm isn't armed yet, possibly leading
            // to boosting the player without this script knowing, possibly leading to an illegal boost
            // afterwards (due to a wrong boost cooldown).
            if (BMTF_TABLE_bm_ticks[bm] < BMTF_BM_ARM_DELAY_TICKS) 
                continue
            
            foreach (p in alive_players) {
                if (bmtf_accurate_bm_trigger_check(bm, p)) {
                    // Replace bm with our own bm dummy that performs no game logic on its own
                    local dummy_bm = Entities.CreateByClassname("bumpmine_projectile") // new bm is not solid
                    dummy_bm.SetModel(bm.GetModelName())
                    dummy_bm.SetOrigin(bm.GetOrigin())
                    local bm_angles = bm.GetAngles()
                    dummy_bm.SetAngles(bm_angles.x, bm_angles.y, bm_angles.z)
                    if (bm.GetMoveParent() != null)
                        EntFireByHandle(dummy_bm, "SetParent", "!activator", 0.0, bm.GetMoveParent(), null)
                    
                    // Play trigger sound
                    dummy_bm.EmitSound("Survival.BumpMinePreDetonate") // looped buzzing sound: Survival.BumpIdle

                    // Remove original bm table slots and add slots for new dummy bm
                    BMTF_TABLE_bm_ticks[dummy_bm] <- BMTF_TABLE_bm_ticks[bm]
                    BMTF_TABLE_bm_triggering_player[dummy_bm] <- p // Remember triggering player to ensure they get boosted later on
                    BMTF_TABLE_bm_trigger_tick[dummy_bm] <- BMTF_TABLE_bm_ticks[bm] // Remember tick of triggering
                    bmtf_del_bm_table_entries(bm)

                    // This deletion process is important: If we don't DisableDraw and then Kill slightly later,
                    // the buzzing sound will stay and cause audio errors at some point. Additionally we set
                    // the bm's parent to null so that it's ignored by our loop code! To make sure the bm does
                    // not attach itself to a new parent during the kill delay, teleport the bm into the void!
                    EntFireByHandle(bm, "SetParent", "", 0.0, null,null) // Get ignored by this script until killed
                    EntFireByHandle(bm, "AddOutput", "origin 16000 16000 16000", 0.0, null, null )
                    bm.SetVelocity(Vector(0,0,0)) // idk maybe this helps avoid errors
                    EntFireByHandle(bm, "DisableDraw", "", 0.0, null, null ) // Remove sound
                    EntFireByHandle(bm, "Kill", "", 4*FrameTime(), null, null ) // Delete with slight delay
                    break
                }
            }
        }
        else { // If it's a detonating dummy bm, apply player boost if detonation is happening
            local detonate = BMTF_TABLE_bm_ticks[bm] - BMTF_TABLE_bm_trigger_tick[bm] >= BMTF_BM_DETONATE_DELAY_TICKS
            if (detonate) {
                // Boost triggering player and other players closeby
                local boosted_players = []
                
                foreach (p in alive_players) {
                    local is_player_in_boost_area = false;

                    if (p == BMTF_TABLE_bm_triggering_player[bm]) {
                        is_player_in_boost_area = true // Always boost the player that triggered the bm
                    }
                    else { // Boost other players if their AABB intersects with bm AABB
                        local p_center_dist_vec = p.GetCenter() - bm_origin
                        // Point of the player's AABB that is the nearest to the bumpmine
                        local p_mins = p.GetOrigin() + p.GetBoundingMins()
                        local p_maxs = p.GetOrigin() + p.GetBoundingMaxs()
                        local nearest_p_point = Vector(bm_origin.x, bm_origin.y, bm_origin.z)
                        if (nearest_p_point.x < p_mins.x) nearest_p_point.x = p_mins.x
                        if (nearest_p_point.y < p_mins.y) nearest_p_point.y = p_mins.y
                        if (nearest_p_point.z < p_mins.z) nearest_p_point.z = p_mins.z
                        if (nearest_p_point.x > p_maxs.x) nearest_p_point.x = p_maxs.x
                        if (nearest_p_point.y > p_maxs.y) nearest_p_point.y = p_maxs.y
                        if (nearest_p_point.z > p_maxs.z) nearest_p_point.z = p_maxs.z
                        // Boost if player's AABB intersects with the bumpmine trigger AABB
                        if (fabs(nearest_p_point.x - bm_origin.x) < BMTF_BM_AABB_DIST &&
                            fabs(nearest_p_point.y - bm_origin.y) < BMTF_BM_AABB_DIST &&
                            fabs(nearest_p_point.z - bm_origin.z) < BMTF_BM_AABB_DIST)
                            is_player_in_boost_area = true
                    }

                    if (is_player_in_boost_area) {
                        // Only boost player if their last boost wasn't too recent
                        if (current_time - BMTF_TABLE_player_last_boost[p] > BMTF_BM_BOOST_COOLDOWN)
                            boosted_players.push(p)
                        // In any case, give every player a screen shake effect
                        // ...
                    }
                }

                foreach (p in boosted_players) {
                    BMTF_TABLE_player_last_boost[p] = current_time // Remember each player's most recent boost time
                    
                    local boost_dir = p.GetCenter() + Vector(0,0,8) - bm.GetOrigin()
                    if (boost_dir.z < 0) { // Different method for z < 0
                        boost_dir = p.GetOrigin() + Vector(0,0,p.GetBoundingMaxs().z) - bm.GetOrigin()
                    }
                    boost_dir.Norm()
                    p.SetVelocity(p.GetVelocity() + boost_dir * BMTF_BM_BOOST_SPEED)
                }

                // Play sound, particle and screenshake effect
                bm.EmitSound("Survival.BumpMineDetonate") 
                DispatchParticleEffect("bumpmine_detonate", bm_origin, Vector(0,0,0))
                local env_shake = Entities.CreateByClassname("env_shake")
                env_shake.__KeyValueFromVector( "origin", bm_origin )
                env_shake.__KeyValueFromFloat( "amplitude", 12.0 )
                env_shake.__KeyValueFromFloat( "duration", 1.0 )
                env_shake.__KeyValueFromFloat( "radius", 780.0 )
                env_shake.__KeyValueFromFloat( "frequency", 40.0 )
                EntFireByHandle(env_shake, "StartShake", "", 0.0, null, null)
                EntFireByHandle(env_shake, "Kill", "", 0.05, null, null)

                // bumpmine_active
                // bumpmine_active_glow
                // bumpmine_active_glow2
                // bumpmine_active_glow_outer
                // bumpmine_detonate <-----
                // bumpmine_detonate_distort sort of but smaller?
                // bumpmine_detonate_ring <----
                // bumpmine_detonate_sparks xxx
                // bumpmine_detonate_sparks_core xxx
                // bumpmine_detonate_sparks_glow ???
                // bumpmine_detonate_splash_up not used
                // bumpmine_player_trail ???

                bm.Destroy()
            }
        }
    }
}

::bmtf_create_timer <- function()
{
    // Delete previously existing entities with the same name
    local ent = null
    while(ent = Entities.FindByName(ent, BMTF_LOGIC_TIMER_NAME)) {
        ent.Destroy()
    }

    // Create a new timer
    local timer = Entities.CreateByClassname( "logic_timer" )
    timer.ConnectOutput( "OnTimer", "OnTimer" )

    // This is a hack that turns our logic_timer into a preserved entity,
    // causing it to NOT get reset/destroyed during a round reset!
    timer.__KeyValueFromString("classname", "info_target")

    timer.__KeyValueFromString( "targetname", BMTF_LOGIC_TIMER_NAME )
    timer.__KeyValueFromFloat( "refiretime", 0.0 ) // Fire timer every tick

    timer.ValidateScriptScope()
    timer.GetScriptScope().OnTimer <- bmtf_loop_tick
    
    EntFireByHandle( timer, "Enable", "", 0.0, null, null )
}

::bmtf_init <- function() {
    bmtf_create_timer()
    //ScriptPrintMessageChatAll("\x01 Bumpmines now trigger more consistently!")
}

bmtf_init()

/////////////////////////////////////////////////////////////////////////////////////////////////
// Here follows code from glow.nut (taken from https://github.com/samisalreadytaken/vs_library)
// Copyright (c) samisalreadytaken
// Licensed under MIT license

//-----------------------------------------------------------------------
//                       github.com/samisalreadytaken
//- v1.0.12 -------------------------------------------------------------
//
// Easy glow handling (using prop_dynamic_glow entities).
// It can be used on any entity that has a model.
//
// Glow.Set( hPlayer, color, nType, flDistance )
// Glow.Disable( hPlayer )
//

if ( !("Glow" in ::getroottable()) || typeof ::Glow != "table" || !("Set" in ::Glow) )
{
    local AddEvent = "DoEntFireByInstanceHandle" in getroottable() ?
        DoEntFireByInstanceHandle : EntFireByHandle;
    local Create = CreateProp;
    local _list = [];

    //-----------------------------------------------------------------------
    // Get the linked glow entity. null if none
    //
    // Input  : handle src_ent
    // Output : handle glow_ent
    //-----------------------------------------------------------------------
    local Get = function( src ) : ( _list )
    {
        if ( !src || !src.IsValid() || src.GetModelName() == "" )
            return;

        for ( local i = _list.len(); i--; )
        {
            local v = _list[i];
            if (v)
            {
                if ( v.GetOwner() == src )
                    return v;
            }
            else _list.remove(i);
        }
    }

    //-----------------------------------------------------------------------
    // Set glow. Update if src already has a linked glow.
    //
    // Input  : handle src_ent
    //          string|Vector colour
    //          int style: 0 (Default (through walls))
    //                     1 (Shimmer (doesn't glow through walls))
    //                     2 (Outline (doesn't glow through walls))
    //                     3 (Outline Pulse (doesn't glow through walls))
    //          float distance
    // Output : handle glow_ent
    //-----------------------------------------------------------------------
    local Set = function( src, color, style, dist ) : ( _list, AddEvent, Create, Get )
    {
        local glow = Get(src);

        if ( !glow )
        {
            foreach( v in _list )
                if ( v && !v.GetOwner() )
                {
                    glow = v;
                    break;
                };

            if (glow)
            {
                glow.SetModel( src.GetModelName() );
            }
            else
            {
                glow = Create( "prop_dynamic_glow", src.GetOrigin(), src.GetModelName(), 0 );
                _list.insert( _list.len(), glow.weakref() );
            };

            glow.__KeyValueFromInt( "rendermode", 6 );
            glow.__KeyValueFromInt( "renderamt", 0 );

            // SetParent
            AddEvent( glow, "SetParent", "!activator", 0.0, src, null );

            // synchronous link
            glow.SetOwner( src );

            // MakePersistent
            glow.__KeyValueFromString( "classname", "soundent" );
        };

        switch ( typeof color )
        {
            case "string":
                glow.__KeyValueFromString( "glowcolor", color );
                break;
            case "Vector":
                glow.__KeyValueFromVector( "glowcolor", color );
                break;
            default:
                throw "parameter 2 has an invalid type '" + typeof color + "' ; expected 'string|Vector'";;
        }

        glow.__KeyValueFromInt( "glowstyle", style );
        glow.__KeyValueFromFloat( "glowdist", dist );
        glow.__KeyValueFromInt( "glowenabled", 1 );
        glow.__KeyValueFromInt( "effects", 18561 ); // (1<<0)|(1<<7)|(1<<11)|(1<<14)

        // Enable again asynchronously in case a Disable input was fired to this glow in this frame,
        // as disabling is not synchronous (clients need to have received the disable msg first,
        // which has to be via the input).
        AddEvent( glow, "SetGlowEnabled", "", 0.1, null, null );

        return glow;
    }

    //-----------------------------------------------------------------------
    // Disable and unlink if src has glow linked with it
    //
    // Input  : handle src_ent
    // Output : handle glow_ent
    //-----------------------------------------------------------------------
    local Disable = function( src ) : ( AddEvent, Get )
    {
        local glow = Get(src);

        if (glow)
        {
            glow.__KeyValueFromInt( "effects", 18593 ); // AddEffects( EF_NODRAW )
            AddEvent( glow, "SetParent", "", 0.0, null, null );
            AddEvent( glow, "SetGlowDisabled", "", 0.0, null, null );
            glow.SetOwner( null );
        };

        return glow;
    }

    ::Glow <-
    {
        m_list = _list,

        Get = Get,
        Set = Set,
        Disable = Disable
    }
};;