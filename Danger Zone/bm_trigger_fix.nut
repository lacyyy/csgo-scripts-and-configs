/////////////////////////////////////////////////////////////////////////////////////////////////////
// Purpose: This script makes Bump Mines trigger consistently, even if players move over them at
//          high speed. It does so by checking if the Bump Mine is triggered by a player every tick.
//          Originally, the game performs this check only every 0.1 seconds.
// 
// HOW TO INSTALL AND USE:
//   To install, put this file into the following folder:
//       Steam\steamapps\common\Counter-Strike Global Offensive\csgo\scripts\vscripts
//   Once loaded onto a map, enter this into the console: script_execute bm_trigger_fix
//
// CAUTION: If you join official servers after running this script with "script_execute" in your
//          local server, you will be kicked with the message "Pure server: client file does not
//          match server."! Luckily, this won't result in a ban or cooldown. To avoid this, simply
//          restart your game after using this script, if you want to play on official
//          servers afterwards.
//
// Made by lacyyy:
//   https://github.com/lacyyy
//   https://steamcommunity.com/profiles/76561198162669616
//
/////////////////////////////////////////////////////////////////////////////////////////////////////

// TODO:
// Add game text for trigger odds
// Add 0-damage explosion to destroy doors?
// Disclaimer in console that bumpmine boost cooldown can rarely be inaccurate:
//    A player gets twice the boost if they get simultaneously boosted by a player-triggered
//    bm and an environment-triggered bm
// Somehow show that the script is active (color of dummy bm or effect?)
// Disclaimer: there are some sound bugs
// Disclaimer: Bump Mine detonations don't break doors
// Disclaimer: Damage from being boosted into a wall might no longer occur
// Disclaimer: Player-activated Bump Mine detonations don't move physics items (crates...)? TODO confirm

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
    ScriptPrintMessageChatAll("\x01 Bumpmines now trigger more consistently!")
}

bmtf_init()
