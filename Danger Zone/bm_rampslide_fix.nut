// ==== THIS VERSION OF THIS SCRIPT IS WORK IN PROGRESS ====

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Purpose: Ensure that the player is able to consistently rampslide if they have
//          the sufficient speed.
//          This script is only meant to be used with a single player on the server.
// 
// HOW TO INSTALL AND USE:
//   To install, put this file into the following folder:
//       Steam\steamapps\common\Counter-Strike Global Offensive\csgo\scripts\vscripts
//   In CSGO, load any map by entering this into the console: game_mode 0;game_type 6;map dz_blacksite
//   To start and reset the practice, enter this into the console: script_execute bm_rampslide_fix
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

// TODO: disclaimer: mention "rampslide fail" aka "rampbug"
// TODO: disclaimer: Doesn't fix all rampsliding fails (like hitting invisible geometry edges)
// TODO: disclaimer: Side effects of this script running:
//                     - In most cases, rampsliding is consistent
//                     - TODO: All bots remain stationary when on ground as long as this script is running?
//                     - In most cases, fall damage no longer occurs on sloped ground
//                     - When landing on the ground without rampsliding, your movement jitters for a short time
//                     - walking and rampsliding on sloped surfaces of very small/thin objects is inaccurate
//                     - walking and rampsliding on sloped player clips that use tools/toolsplayerclip is inaccurate (They're the pink objects made visible with "r_drawclipbrushes 2") [Blacksite&Vineyard don't have these surfaces]
//                     - falling onto ramps with non-solid entities (e.g. chickens, dropped weapons) on them may rarely cause a rampslide fail
//                     - When falling on some edges, you may slide off with significant speed, when you shouldn't. 
// TODO: - THEORY: bhops are no longer affected (but delayed by 2 ticks) - ask NOVA to test
// 538.474
// 547.708
// 557.068
// 566.55
// 576.147
// 585.853
// 366.064
// 534.691
// 528.243
// 522.016
// 516.015
// 513.565

// 566.666
// 575.719
// 584.898
// 594.199
// 603.615
// 393.866
// 560.38
// 554.223
// 548.282
// 542.563
// 537.075
// 531.824
// 526.817

// TODO: check compatibility with other teleporting scripts 
// TODO: - THEORY: getting a speed boost from landing on flat ground right before a ramp is easier than in real game (less easier in 128 tick? recommend 128t?)
//     - script p<-Entities.FindByClassname(null,"player")
//     - bind u "script {p.SetOrigin(Vector(1273.056030, -7549.588379, 900.173462))}{p.SetVelocity(Vector(-800,800,0))};setang 40 135"
// TODO: chat msg: intended for 1 player, disable with <cmd>
// TODO: disclaimer: rarely you can slide on surfaces that shouldn't be slidable (happens more often on small surfaces??)
// TODO: check if illegal surfaces became slidable
// TODO: add fall sound on slide fail?
// TODO: credit NOVA for testing
// TODO: test rampslide fail rate 128 tick with/without script and with 2-consecutive ground detections
//  - bind u "script {p.SetOrigin(Vector(2040.770020, -5333.669922, 1509.379883))}{p.SetVelocity(Vector(1550,-200,0))}"
//    - on 128 tick:
//        - no script: 11/100, 15/100, 14/100
//        - w/ script: 18/100
//    - on 64 tick:
//        - no script: 5/100, 10/100, 5/100
//        - w/ script: 12/100

// If the vertical component of the player's velocity is greater than this,
// they are guaranteed to not enter walk mode. Otherwise, the game attempts
// to find ground beneath the player that they can walk on (not too steep).
// If walkable ground is found, the player enters walk mode, otherwise they
// stay in air mode. Whether or not a surface is walkable is determined by
// the cvar "sv_standable_normal".
const MIN_NO_GROUND_CHECKS_VEL_Z = 140.0

const DEFAULT_VAL_sv_standable_normal = 0.7

function bmrsf_get_player() { // human player, no bot
    local p = null
    while(p = Entities.FindByClassname(p, "player")) {
        if(p.GetTeam() == 2 || p.GetTeam() == 3) // If player is in T or CT team
            return p
    }
    return null
}

// Very small/thin objects beneath the player might be missed by this ground check
function bmrsf_is_player_on_ground(player) {
    local center = player.GetOrigin()
    local maxs = player.GetBoundingMaxs()
    local mins = player.GetBoundingMins()
    
    // How far the game searches beneath the player for ground to stand on
    const GROUND_CHECK_DIST = 2.0

    // Do many ground checks in an evenly spaced grid beneath the player BBOX.
    // Make sure that checks happen at the outermost edges of the BBOX.
    const STEP_SIZE = 3.0
    local x_end = center.x + maxs.x
    local y_end = center.y + maxs.y

    local y = center.y + mins.y
    while (true) {
        local x = center.x + mins.x
        while (true) {
            // Check for ground at one point
            local pt = Vector(x, y, center.z)
            local trace_start = pt + Vector(0, 0, -0.02)
            local trace_end = pt + Vector(0, 0, -GROUND_CHECK_DIST)

            // Unlike TraceLine(), TraceLinePlayersIncluded() hits entities such as:
            // Exploding barrels, turrets, cage doors, players, crates, dynamic props (e.g. rescue zone boats), drones, chickens, dropped weapons.
            // Problem are non-solid entities (e.g. chickens, dropped weapons, ...) that get hit by the trace,
            // we are looking for solid ground to stand on... Ignoring that many different entities is probably too costly.
            // -> Accept falsely detecting chickens and dropped weapons as ground to stand on (falling on them is rare).

            // Separate problem with detecting some surfaces that are solid to players: 
            // TraceLinePlayersIncluded() and TraceLine() don't hit "tools/toolsplayerclip" brushes (luckily, these aren't common on DZ maps).
            // TraceLinePlayersIncluded() also doesn't hit "tools/toolsclip" brushes (these ARE common).

            // --> Use both TraceLine() and TraceLinePlayersIncluded() to detect both "tools/toolsclip" brushes and relevant entities.

            if(TraceLine(trace_start, trace_end, null) != 1.0)
                return true
            if(TraceLinePlayersIncluded(trace_start, trace_end, null) != 1.0)
                return true
            
            if (x == x_end)
                break
            x += STEP_SIZE
            if (x > x_end)
                x = x_end
        }
        
        if (y == y_end)
            break
        y += STEP_SIZE
        if (y > y_end)
            y = y_end
    }

    return false
}

function bmrsf_loop_tick()
{
    local player = bmrsf_get_player()
    if (player == null)
        return
    
    // If required from previous tick, replay the player's previous movement
    if(::BMRSF_REWIND_TO_LAST_LEGAL_STATE_IN_NEXT_TICK) {
        ::BMRSF_REWIND_TO_LAST_LEGAL_STATE_IN_NEXT_TICK = false

        player.SetVelocity(::BMRSF_LAST_KNOWN_LEGAL_PLY_VEL)

        // I'm not entirely sure here, it feels like the __KeyValueFromVector()
        // method gives a smoother teleportation compared to SetOrigin()...
        player.__KeyValueFromVector("origin", ::BMRSF_LAST_KNOWN_LEGAL_PLY_POS);
        //player.SetOrigin(::BMRSF_MOVEMENT_REPLAY_PLY_POS)
        
        // Don't check enabling/disabling rampslide mode after this,
        // let the game decide if player may rampslide for this tick.
        return
    }

    ///////////////////////////////////////////////////////////////////////

    if (::BMRSF_DO_EXTRA_ILLEGAL_RAMPSLIDE_CHECK_IN_NEXT_TICK) {
        ::BMRSF_DO_EXTRA_ILLEGAL_RAMPSLIDE_CHECK_IN_NEXT_TICK = false

        if (player.GetVelocity().z < MIN_NO_GROUND_CHECKS_VEL_Z) {
            // Disable consistent rampslide mode
            ::BMRSF_CONSISTENT_SLIDES_ENABLED = false
            SendToConsole("sv_standable_normal " + DEFAULT_VAL_sv_standable_normal)

            // Disabling the consistent slide mode takes effect next tick.
            // Replay the player's movement of the last "legal" tick in the next tick
            // to make sure the player definitely stops rampsliding.
            ::BMRSF_REWIND_TO_LAST_LEGAL_STATE_IN_NEXT_TICK = true
        }
        
        return
    }

    // Player may not rampslide when on ground and with insufficent Z velocity
    if (bmrsf_is_player_on_ground(player) && player.GetVelocity().z < MIN_NO_GROUND_CHECKS_VEL_Z) {
        if(::BMRSF_CONSISTENT_SLIDES_ENABLED) {
            ::BMRSF_LAST_KNOWN_LEGAL_PLY_POS = player.GetOrigin()
            ::BMRSF_LAST_KNOWN_LEGAL_PLY_VEL = player.GetVelocity()

            ::BMRSF_DO_EXTRA_ILLEGAL_RAMPSLIDE_CHECK_IN_NEXT_TICK = true
        }
    }
    else {
        if(!::BMRSF_CONSISTENT_SLIDES_ENABLED) {
            // Enable consistent rampslide mode
            ::BMRSF_CONSISTENT_SLIDES_ENABLED = true

            // This cvar value must be as high as possible, while staying below 1.0 :
            // A higher value makes shallower surfaces consistently slidable.
            // A value below 1.0 makes completely flat surfaces NOT slidable.
            // This is an important requirement because we might fail to detect that
            // we're standing on flat ground (e.g. tools/toolsplayerclip brushes that
            // are missed by our trace checks). Even in these fail cases we are then
            // able to walk on the undetected flat ground thanks to the cvar value
            // being below 1.0 .
            SendToConsole("sv_standable_normal 0.999")
        }
    }
}

const BMRSF_TIMER_NAME = "bmrsf_timer"

function STOP_RS_FIX() {
    EntFire(BMRSF_TIMER_NAME, "Kill")
}
function stop_rs_fix() { STOP_RS_FIX() }
function Stop_Rs_Fix() { STOP_RS_FIX() }

function bmrsf_print_info() {
    // TODO write this
    ScriptPrintMessageChatAll("\x01 \x04 Rampsliding is now more consistent!")
    ScriptPrintMessageChatAll("\x01 \x09  - This script is unfinished and has a number of side effects!")
    ScriptPrintMessageChatAll("\x01 \x09  - Using this script is NOT allowed during the DZGT recording session!")
    
    //ScriptPrintMessageChatAll("\x01 \x05 - Bright green text")
    //ScriptPrintMessageChatAll("\x01 \x04 - Side effect 1")
    //ScriptPrintMessageChatAll("\x01 \x04 - Side effect 2")
    //ScriptPrintMessageChatAll("\x01 \x04 - Side effect 3")
    //ScriptPrintMessageChatAll("\x01 \x04 - Side effect 4")
    //ScriptPrintMessageChatAll("\x01 \x04 - Side effect 5")
    //ScriptPrintMessageChatAll("\x01 \x02 - Red text 1")
    //ScriptPrintMessageChatAll("\x01 \x09 - Yellow text 1")
}

function bmrsf_init()
{
    SendToConsole("sv_standable_normal " + DEFAULT_VAL_sv_standable_normal)
    ::BMRSF_CONSISTENT_SLIDES_ENABLED <- false
    ::BMRSF_DO_EXTRA_ILLEGAL_RAMPSLIDE_CHECK_IN_NEXT_TICK <- false
    ::BMRSF_REWIND_TO_LAST_LEGAL_STATE_IN_NEXT_TICK <- false
    ::BMRSF_LAST_KNOWN_LEGAL_PLY_POS <- null // Player position vector
    ::BMRSF_LAST_KNOWN_LEGAL_PLY_VEL <- null // Player velocity vector
    
    ///////////////////////////////////////////////////////////////////////

    // Delete previously existing entities with the same name
    local x = null
    while(x = Entities.FindByName(x, BMRSF_TIMER_NAME)) {
        x.Destroy()
    }
    
    // Create a new timer
    BMRSF_TIMER <- Entities.CreateByClassname( "logic_timer" )
    BMRSF_TIMER.ConnectOutput( "OnTimer", "OnTimer" )

    // This is a hack that turns our logic_timer into a preserved entity,
    // causing it to NOT get reset/destroyed during a round reset!
    BMRSF_TIMER.__KeyValueFromString("classname", "info_target")

    BMRSF_TIMER.__KeyValueFromString( "targetname", BMRSF_TIMER_NAME )
    BMRSF_TIMER.__KeyValueFromFloat( "refiretime", 0.0 ) // Fire timer every tick

    BMRSF_TIMER.ValidateScriptScope()
    BMRSF_TIMER.GetScriptScope().OnTimer <- bmrsf_loop_tick
    
    EntFireByHandle( BMRSF_TIMER, "Enable", "", 0.0, null, null )
}

bmrsf_init()
bmrsf_print_info()
