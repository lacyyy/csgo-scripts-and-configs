/////////////////////////////////////////////////////////////////////////////////////////////////////
// Purpose: I used this to reverse engineer the areas in which a player triggers a Bump Mine.
//          This script creates a 3D-grid of sample points around a Bump Mine where each point
//          tells whether or not the player triggers the Bump Mine. A scan file is created
//          which, after cleaning it manually up, can be displayed in CS:GO with the
//          dzsim_bm_trigger_area_display.nut script.
//          I only made this for my own usage, so it's not well explained and you can't just run it.
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

// binary search?

// setpos 32.764366 127.761345 164.778168;setang -0.067123 -178.890167 0.000000
// setpos 33.114319 129.307739 379.726044;setang 6.433177 -177.931000 0.000000

// 45 degree tilted bumpmine, end positions of peanut
// setpos -82.739906 127.093452 192.649277;setang 6.817052 -92.681633 0.000000
// setpos 78.156578 129.186432 361.967041;setang 4.265396 -84.281570 0.000000

// Display entity angles:  ent_pivot bumpmine_projectile
// Display eye position:   ent_viewoffset bumpmine_projectile

BM_TEST_POS <- Vector(0, 128, 272) // bumpmine_projectile position
BM_TEST_ANGLES <- Vector(0,0,0) // bumpmine_projectile facing direction
BM_TEST_CROUCHING <- false
BM_TEST_BOOST_AREA <- false // If true, ignites the bumpmine every time on its own
BM_TEST_DRAW_DEBUG_INFO <- true

// To un-rotate the sample points, use the inverse of the bumpmine's angles
BM_TEST_ANGLES_INV_SIN <- Vector(sin(-(-BM_TEST_ANGLES.x) * (PI / 180)), sin(-BM_TEST_ANGLES.y * (PI / 180)), sin(-BM_TEST_ANGLES.z * (PI / 180)))
BM_TEST_ANGLES_INV_COS <- Vector(cos(-(-BM_TEST_ANGLES.x) * (PI / 180)), cos(-BM_TEST_ANGLES.y * (PI / 180)), cos(-BM_TEST_ANGLES.z * (PI / 180)))

const BM_DETONATE_DELAY = 0.55 // Time duration between bumpmine surface placement and earliest detonation
const PLAYER_STANDING_HEIGHT = 72.0
const PLAYER_CROUCHING_HEIGHT = 54.0

/*
BUMPMINE FIRST AABB check:
	- player aabb has to intersect with bumpmine trigger aabb = Vector(81,81,81)
BUMPMINE ELIPSOID PROPERTIES:
Top elipsoid:
	- extends AT LEAST 120.47 units above the bumpmine origin
	- max width AT LEAST 93.62 units, 51.415 units above the bumpmine origin
	- width of top ellipsoid 10 units above the bumpmine origin is 75.28 units
	- width of top ellipsoid 92.83 units above the bumpmine origin is ~~ 75.28 units??
BUMPMINE BOOST RECEIVE CHECK:
	- player aabb has to intersect with bumpmine boost aabb = Vector(162,162,162)
*/


BM_SCAN_AREA_X_WIDTH <- 220//220//260
BM_SCAN_AREA_Y_WIDTH <- 260//220//260
BM_SCAN_AREA_HEIGHT_ABOVE <- 110 // above the bumps origin
BM_SCAN_AREA_HEIGHT_BELOW <- 170 // below the bumps origin
BM_SCAN_STEP_SIZE <- Vector(10,10,10) // distance between each sample point, on each axis

BM_SCAN_AREA_MINS <- BM_TEST_POS + Vector(-BM_SCAN_AREA_X_WIDTH/2, -BM_SCAN_AREA_Y_WIDTH/2, -BM_SCAN_AREA_HEIGHT_BELOW)
BM_SCAN_AREA_MAXS <- BM_TEST_POS + Vector( BM_SCAN_AREA_X_WIDTH/2,  BM_SCAN_AREA_Y_WIDTH/2,  BM_SCAN_AREA_HEIGHT_ABOVE)

BM_SCAN_INITIALIZED <- false
BM_SCAN_FINISHED <- false
BM_SCAN_CUR_POS <- Vector()

BM_SCAN_CURRENT_LAYER_RESULTS <- [] // containing row arrays, containing hit vectors or "null" for each non-hit
BM_SCAN_HIT_RINGS <- [] // containing ring arrays, containing position vectors

function dzsim_get_point_servercommand() {
	local sv_cmd = Entities.FindByClassname(null, "point_servercommand")
	if(!sv_cmd) { // Create if it doesn't exist
		sv_cmd = Entities.CreateByClassname("point_servercommand")
	}
	return sv_cmd
}

function dzsim_run_server_commands(arr_commands) {
	local ent_sv_cmd = dzsim_get_point_servercommand()
	foreach(cmd in arr_commands) {
		EntFireByHandle(ent_sv_cmd, "command", cmd, 0, null, null)
	}
}

function dzsim_run_server_command(command, delay=0.0) {
	local ent_sv_cmd = dzsim_get_point_servercommand()
	EntFireByHandle(ent_sv_cmd, "command", command, delay, null, null)
}

function dzsim_start_scan_result_logging() {
	local rand_num = RandomInt(1000, 9999)
	local log_file_name = "bm_scan_"
	if(BM_TEST_BOOST_AREA) log_file_name += "boost_"
	else                   log_file_name += "trigg_"
	log_file_name += BM_TEST_ANGLES.x.tointeger() + "p" + BM_TEST_ANGLES.y.tointeger() + "y" + BM_TEST_ANGLES.z.tointeger() + "r_"
	if(BM_TEST_CROUCHING) log_file_name += "crouching_"
	else                  log_file_name += "standing_"
	log_file_name += BM_SCAN_STEP_SIZE.x.tointeger() + "x" + BM_SCAN_STEP_SIZE.y.tointeger() + "y" + BM_SCAN_STEP_SIZE.z.tointeger() + "z_"
	log_file_name += rand_num
	dzsim_run_server_command("con_logfile \"scripts/vscripts/" + log_file_name + ".log\"") // Starts logging with a small delay
	// Log first line with a dzsim_run_server_command(), because it's delayed, unlike printl()
	dzsim_run_server_command("echo \"" + log_file_name + " <- [\"")
}

function dzsim_log_hit_ring(ring) {
	if(ring.len() == 0) {
		return
	}
	local next_line = "["
	for(local i = 0; i < ring.len(); i++) {
		next_line += "Vector(" + ring[i].x + "," + ring[i].y + "," + ring[i].z + "),"
		if(next_line.len() > 120) { // Limit line length
			printl(next_line)
			next_line = ""
		}
	}
	next_line += "],"
	if(next_line.len() > 0) {
		printl(next_line)
	}
	dzsim_run_server_command("clear") // Console text causes lag
}

function dzsim_end_scan_result_logging() {
	printl("]")
	dzsim_run_server_command("con_logfile \"\"") // Stop logging
}

function dzsim_bm_parse_hit_rings_from_layer_scan(layer_scan_results) {
	if(layer_scan_results.len() == 0) { return [] }
	
	local row_count    = layer_scan_results.len()
	local column_count = layer_scan_results[0].len() // Assume all rows have the same length
	
	enum CWDir { // Moore neighborhood directions, clockwise
		N=0, NE=1, E=2, SE=3, S=4, SW=5, W=6, NW=7, TOTAL_COUNT=8
	}
	
	local processed_sample_table = [] // 2d array, telling if a sample point was already included in a ring
	for(local i = 0; i < row_count; i++)
		processed_sample_table.push(array(column_count, false)) // Init every sample point to false
	
	local parsed_rings = []
	
	// Look for non-null unprocessed samples to start a new ring at
	foreach(ringStartRowIdx,row in layer_scan_results) {
		local skipSamplesUntilNullSample = false
		foreach(ringStartColIdx,sample_pt in row) {
			if(sample_pt == null) {
				skipSamplesUntilNullSample = false
				continue
			}
			if(skipSamplesUntilNullSample) {
				continue
			}
			if(processed_sample_table[ringStartRowIdx][ringStartColIdx] == true) {
				// Current sample is already in a ring -> skip this ring's area
				skipSamplesUntilNullSample = true
				continue
			}
			
			// We found the ring start, now traverse the ring
			local ring = []
			local rowIdx = ringStartRowIdx
			local colIdx = ringStartColIdx
			local approachDir = CWDir.W // From which direction we entered the current sample
			while(true) {
				// Add current sample to the ring and mark it as processed
				ring.append(layer_scan_results[rowIdx][colIdx])
				processed_sample_table[rowIdx][colIdx] = true
				// Determine in which direction to start looking
				local diagonalApproach = (approachDir == CWDir.NE || approachDir == CWDir.SE || approachDir == CWDir.SW || approachDir == CWDir.NW)
				local lookDir = diagonalApproach ? (approachDir + 2) : (approachDir + 3) // Skip redundant neighbour checks
				if(lookDir >= CWDir.TOTAL_COUNT) lookDir -= CWDir.TOTAL_COUNT
				// Check neighbouring samples in clockwise order
				local neighRowIdx=null, neighColIdx=null
				while(true) {
					switch(lookDir) {
						case CWDir.N : neighRowIdx = rowIdx - 1; neighColIdx = colIdx    ; break;
						case CWDir.NE: neighRowIdx = rowIdx - 1; neighColIdx = colIdx + 1; break;
						case CWDir.E : neighRowIdx = rowIdx    ; neighColIdx = colIdx + 1; break;
						case CWDir.SE: neighRowIdx = rowIdx + 1; neighColIdx = colIdx + 1; break;
						case CWDir.S : neighRowIdx = rowIdx + 1; neighColIdx = colIdx    ; break;
						case CWDir.SW: neighRowIdx = rowIdx + 1; neighColIdx = colIdx - 1; break;
						case CWDir.W : neighRowIdx = rowIdx    ; neighColIdx = colIdx - 1; break;
						case CWDir.NW: neighRowIdx = rowIdx - 1; neighColIdx = colIdx - 1; break;
					}
					// Check if neighbour is non-null
					if(neighRowIdx >= 0 && neighRowIdx < row_count && neighColIdx >= 0 && neighColIdx < column_count) {
						if(layer_scan_results[neighRowIdx][neighColIdx] != null) {
							// Select this neighbour and repeat the process
							rowIdx = neighRowIdx
							colIdx = neighColIdx
							approachDir = lookDir + 4 // Apply 180° turn to get approachDir from lookDir
							if(approachDir >= CWDir.TOTAL_COUNT) approachDir -= CWDir.TOTAL_COUNT
							break
						}
					}
					// If the ring start sample only has null neighbours, abort
					if(lookDir == approachDir) { // Even the neighbour we approached from is null
						rowIdx = ringStartRowIdx
						colIdx = ringStartColIdx
						break
					}
					// Look at next neighbour in clockwise direction
					lookDir++
					if(lookDir >= CWDir.TOTAL_COUNT) lookDir -= CWDir.TOTAL_COUNT
				}
				// We've gone full circle and reached the ring start -> This ring is finished
				if(rowIdx == ringStartRowIdx && colIdx == ringStartColIdx)
					break
			}
			parsed_rings.push(ring)
		}
	}
	return parsed_rings
}

function dzsim_bm_loop_init() {
	DZSIM_LOOP_FORCED_PLUS_ATTACK <- false
	DZSIM_LOOP_IS_BM_TELEPORTED <- false
	DZSIM_LOOP_IS_BM_PLACED <- false
}

function dzsim_bm_scan_init() {
	BM_SCAN_FINISHED = false
	BM_SCAN_CUR_POS = Vector(BM_SCAN_AREA_MINS.x, BM_SCAN_AREA_MINS.y, BM_SCAN_AREA_MINS.z) // Copy vector, don't reference
	BM_SCAN_CURRENT_LAYER_RESULTS = [[]] // containing first row array
	BM_SCAN_HIT_RINGS = []
	local bot = Entities.FindByClassname(null, "cs_bot")
	bot.SetVelocity(Vector(0,0,0))
	bot.SetOrigin(BM_SCAN_CUR_POS)
	dzsim_start_scan_result_logging()
	ScriptPrintMessageChatAll("\x01 \x04 Changing the cvar \"host_timescale\" in the middle of the scan could very well break the scan.")
}

// Scan step check
function dzsim_bm_scan_step() {
	if(!BM_SCAN_INITIALIZED || BM_SCAN_FINISHED)
		return
	
	local bot = Entities.FindByClassname(null, "cs_bot")
	
	// Check if bot received boost by looking at bot's velocity
	local bot_velocity = bot.GetVelocity()
	local boost_received = bot_velocity.x != 0 || bot_velocity.y != 0 || bot_velocity.z != 0
	
	// If we are doing a trigger scan, not a boost scan -> If no boost was received, check if bumpmine is stuck on bot's body
	if(!BM_TEST_BOOST_AREA && !boost_received) {
		local bm = Entities.FindByClassname(null, "bumpmine_projectile")
		if(bm == null) {
			ScriptPrintMessageChatAll("\x01 \x02 Strange: No bumpmines found, even though bot's velocity is 0!")
		} else {
			local move_parent = bm.GetMoveParent()
			if(move_parent == null) {
				ScriptPrintMessageChatAll("\x01 \x02 Strange: Bumpmine has no move parent, checked at the scan step!")
			} else if(move_parent.GetClassname() == "player") { // Human players AND bots have the classname "player"
				// If bumpmine is stuck on bot's body, count it as triggered and delete it
				bm.Destroy()
				boost_received = true
			}
		}
	}
	
	if(!boost_received)
	{
		// Append null to current row, marking a non-hit
		BM_SCAN_CURRENT_LAYER_RESULTS.top().push(null)
		// If we are doing a trigger scan, not a boost scan, we assume the bumpmine is still present, because no boost.
		// -> Schedule next scan step check, once bump could have detonated
		// If we are doing a boost scan, not a trigger scan, the bumpmine always detonates and the next scan step check
		// always gets scheduled by the dzsim_bm_loop_tick() function once a new bumpmine was placed
		if(!BM_TEST_BOOST_AREA)
			dzsim_run_server_command("script dzsim_bm_scan_step()", BM_DETONATE_DELAY)
		// Below this if-else clause, advance bot to next sample point
	}
	else // Bumpmine was triggered and boost was received
	{
		local bot_height = null
		if(BM_TEST_CROUCHING) { bot_height = PLAYER_CROUCHING_HEIGHT }
		else                  { bot_height = PLAYER_STANDING_HEIGHT }
		local bot_bbox_center = BM_SCAN_CUR_POS + Vector(0, 0, bot_height / 2)
		bot_bbox_center -= BM_TEST_POS // Translate to world origin to rotate
		// Un-rotate the sample point with the inverse of the bumpmine's angles
		local hit_pos = Vector(bot_bbox_center.x, bot_bbox_center.y, bot_bbox_center.z)
		// To undo the rotation, rotate axes in reverse order: First yaw, then pitch, then roll rotation!
		// (yaw)   rotation around z axis
		local y_newX = hit_pos.x * BM_TEST_ANGLES_INV_COS.y - hit_pos.y * BM_TEST_ANGLES_INV_SIN.y
		local y_newY = hit_pos.x * BM_TEST_ANGLES_INV_SIN.y + hit_pos.y * BM_TEST_ANGLES_INV_COS.y
		hit_pos.x = y_newX
		hit_pos.y = y_newY
		// (pitch) rotation around y axis
		local p_newX = hit_pos.x * BM_TEST_ANGLES_INV_COS.x - hit_pos.z * BM_TEST_ANGLES_INV_SIN.x
		local p_newZ = hit_pos.x * BM_TEST_ANGLES_INV_SIN.x + hit_pos.z * BM_TEST_ANGLES_INV_COS.x
		hit_pos.x = p_newX
		hit_pos.z = p_newZ
		// (roll)  rotation around x axis
		local r_newY = hit_pos.y * BM_TEST_ANGLES_INV_COS.z - hit_pos.z * BM_TEST_ANGLES_INV_SIN.z
		local r_newZ = hit_pos.y * BM_TEST_ANGLES_INV_SIN.z + hit_pos.z * BM_TEST_ANGLES_INV_COS.z
		hit_pos.y = r_newY
		hit_pos.z = r_newZ
		// Append hit position vector to current row
		BM_SCAN_CURRENT_LAYER_RESULTS.top().push(hit_pos)
		// Since bumpmine was detonated and destroyed, the next scan step check will be initiated by
		// the dzsim_bm_loop_tick() function, once the new bumpmine has been placed
		// -> just advance bot to next sample point and don't schedule next scan step check here
	}
	
	// Advance bot position to next sample point
	BM_SCAN_CUR_POS.x += BM_SCAN_STEP_SIZE.x // Advance x
	if(BM_SCAN_CUR_POS.x > BM_SCAN_AREA_MAXS.x) {
		BM_SCAN_CUR_POS.x = BM_SCAN_AREA_MINS.x
		
		// If this is the last row of the last layer -> slow down
		if(BM_SCAN_CUR_POS.z + BM_SCAN_STEP_SIZE.z > BM_SCAN_AREA_MAXS.z) {
			if(BM_SCAN_CUR_POS.y + 2 * BM_SCAN_STEP_SIZE.y > BM_SCAN_AREA_MAXS.y) {
				dzsim_run_server_command("host_timescale 1")
			}
		}
		
		BM_SCAN_CUR_POS.y += BM_SCAN_STEP_SIZE.y // Advance y
		if(BM_SCAN_CUR_POS.y > BM_SCAN_AREA_MAXS.y) {
			BM_SCAN_CUR_POS.y = BM_SCAN_AREA_MINS.y
			
			// Convert hit positions of previous layer to hit rings
			local hit_rings = dzsim_bm_parse_hit_rings_from_layer_scan(BM_SCAN_CURRENT_LAYER_RESULTS)
			foreach(ring in hit_rings) {
				BM_SCAN_HIT_RINGS.push(ring)
				// Log new ring data
				dzsim_log_hit_ring(ring)
			}
			
			// Clear previous layer array
			BM_SCAN_CURRENT_LAYER_RESULTS.clear()
			BM_SCAN_CURRENT_LAYER_RESULTS.push([]) // Add first row array
			
			// Check overall scan progress
			local scan_progress = (BM_SCAN_CUR_POS.z - BM_SCAN_AREA_MINS.z) / (BM_SCAN_AREA_MAXS.z - BM_SCAN_AREA_MINS.z)
			ScriptPrintMessageChatAll("scan progress: " + (scan_progress*100).tointeger() + "%")
			
			//local sample_points_per_layer = (BM_SCAN_AREA_WIDTH * BM_SCAN_AREA_WIDTH) / (BM_SCAN_STEP_SIZE * BM_SCAN_STEP_SIZE)
			//dzsim_draw(BM_DETONATE_DELAY * sample_points_per_layer + FrameTime())
			
			BM_SCAN_CUR_POS.z += BM_SCAN_STEP_SIZE.z // Advance z
			if(BM_SCAN_CUR_POS.z > BM_SCAN_AREA_MAXS.z) {
				BM_SCAN_CUR_POS = BM_TEST_POS + Vector(0,0,2*BM_SCAN_AREA_HEIGHT_ABOVE)
				// end of scan
				BM_SCAN_FINISHED = true
				dzsim_run_server_command("fps_max 120") // save cpu power
				
				dzsim_end_scan_result_logging()
				
				printl("bumpmine scan finished!")
			}
		} else { // If there still are rows to be scanned in the current layer
			BM_SCAN_CURRENT_LAYER_RESULTS.push([]) // Add new row array
		}
	}
	
	bot.SetVelocity(Vector(0,0,0))
	bot.SetOrigin(BM_SCAN_CUR_POS)
	
	if(BM_TEST_DRAW_DEBUG_INFO) {
		dzsim_draw(BM_DETONATE_DELAY + FrameTime())
	}
}

function dzsim_bm_get_bm_projectile() {
	local bm = Entities.FindByClassname(null, "bumpmine_projectile")
	if(bm == null) {
		dzsim_run_server_command("use weapon_bumpmine")
		dzsim_run_server_command("+attack")
		DZSIM_LOOP_FORCED_PLUS_ATTACK = true
	} else {
		if(DZSIM_LOOP_FORCED_PLUS_ATTACK) {
			dzsim_run_server_command("-attack")
			DZSIM_LOOP_FORCED_PLUS_ATTACK = false
		}
	}
	return bm
}

function dzsim_bm_loop_tick()
{
	if(BM_SCAN_FINISHED) {
		if(BM_TEST_DRAW_DEBUG_INFO) {
			dzsim_draw(FrameTime() * 2) // might cause crash at end of big scan
		}
		return
	}
	
	local bm = dzsim_bm_get_bm_projectile()
	if(bm == null) {
		DZSIM_LOOP_IS_BM_TELEPORTED = false
		DZSIM_LOOP_IS_BM_PLACED = false
	} else {
		if(!DZSIM_LOOP_IS_BM_TELEPORTED) {
			bm.SetOrigin(BM_TEST_POS + Vector(0,0,2))
			bm.SetVelocity(Vector(0,0,-400))
			DZSIM_LOOP_IS_BM_TELEPORTED = true
		}
		// If bumpmine has just been placed on a surface OR a player's body
		if(!DZSIM_LOOP_IS_BM_PLACED && bm.GetMoveParent() != null) {
			// Set position and orientation once it is in a "placed" state
			bm.SetOrigin(BM_TEST_POS)
			bm.SetAngles(BM_TEST_ANGLES.x, BM_TEST_ANGLES.y, BM_TEST_ANGLES.z)
			if(BM_TEST_BOOST_AREA) { // Always trigger bumpmine to see where the player receives boost
				EntFireByHandle(bm, "Ignite", "", 0, null, null)
			}
			DZSIM_LOOP_IS_BM_PLACED = true
			// Wait until bumpmine could have detonated, then sample the result and advance a scan step
			dzsim_run_server_command("script dzsim_bm_scan_step()", BM_DETONATE_DELAY)
		}
	}
}

function dzsim_bm_create_relay()
{
	local LOGIC_RELAY_NAME = "dzsim_bm_relay"
	
	local relay = Entities.FindByName(null, LOGIC_RELAY_NAME )
	local has_old_relay_existed = relay != null
	if(!has_old_relay_existed) {
		relay = Entities.CreateByClassname( "logic_relay" )
		relay.__KeyValueFromString( "targetname", LOGIC_RELAY_NAME )
		relay.__KeyValueFromInt( "spawnflags", 2 ) // 2 -> Allow fast retrigger, don't trigger only once
		
		// Let relay trigger itself each tick so bots stand still
		local tickLength = FrameTime() // Reciprocal of the server tickrate (might change once fps > 1000)
		// target name, input name, parameter, delay, max times to fire (-1 = infinity)
		local targetParams = LOGIC_RELAY_NAME + ":Trigger::" + tickLength + ":-1"	
		EntFireByHandle( relay, "AddOutput", "OnTrigger " + targetParams, 0, null, null )
	}
	
	relay.ValidateScriptScope()
	relay.GetScriptScope().OnTrigger <- dzsim_bm_loop_tick // Add a reference to the function
	
	if(!has_old_relay_existed) {
		relay.ConnectOutput( "OnTrigger", "OnTrigger" ) // On each OnTrigger output, execute the function
		EntFireByHandle( relay, "Trigger", "", 0.2, null, null ) // Start trigger loop
	}
}

function dzsim_delayed_init() {
	BM_SCAN_INITIALIZED = true
	dzsim_bm_loop_init()
	dzsim_bm_scan_init()
	dzsim_bm_create_relay()
}

function dzsim_draw(draw_time) {
	// models\weapons\v_bumpmine.mdl
	// models\weapons\w_eq_bumpmine.mdl
	// models\weapons\w_eq_bumpmine_dropped.mdl
	// models\weapons\v_models\eq_bumpmine\v_bumpmine.qc
	// models\weapons\world\w_eq_bumpmine\w_eq_bumpmine.qc
	// models\weapons\world\w_eq_bumpmine\w_eq_bumpmine_dropped.qc
	
	//"weapon_bumpmine_prefab"
	//{
	//	"prefab"		"equipment"
	//	"item_class"		"weapon_bumpmine"
	//	"image_inventory"		"econ/weapons/base_weapons/weapon_bumpmine"
	//	"icon_default_image"		"materials/icons/inventory_icon_weapon_breachcharge.vtf"
	//	"model_player"		"models/weapons/v_bumpmine.mdl"
	//	"model_world"		"models/weapons/w_eq_bumpmine.mdl"
	//	"model_dropped"		"models/weapons/w_eq_bumpmine_dropped.mdl"
	//	"attributes"
	//	{
	//		"max player speed"		"245"
	//		"in game price"		"300"
	//		"armor ratio"		"1.200000"
	//		"penetration"		"1"
	//		"crosshair min distance"		"8"
	//		"damage"		"5"
	//		"range"		"350"
	//		"range modifier"		"0.990000"
	//		"throw velocity"		"750.000000"
	//		"primary clip size"		"3"
	//		"weapon weight"		"2"
	//		"max player speed alt"		"245"
	//	}
	//	"visuals"
	//	{
	//		"weapon_type"		"Bump Mine"
	//		"player_animation_extension"		"gren"
	//		"primary_ammo"		"AMMO_TYPE_BUMPMINE"
	//		"sound_single_shot"		"HEGrenade.Throw"
	//		"sound_nearlyempty"		"Default.nearlyempty"
	//	}
	//}
	
	////////////////////////////
	
	// 83.030350 // triggers
	// 82.985146 // does not trigger
	
	// 81.0461 - 81.0305
	
	// player origin.z = 164.031250
	
	// ideas:
	// 
	
	local PLAYER_FEET_LEVEL = 0.031250
	
	local BM_SURF_DISTANCE = 0.7312 // Bumpmine origin is slightly distanced from the surface it was placed on
	
	// difference between bump.origin.z and player.origin.z, determined from bump on flat ground
	local BM_HITCYLINDER_HEIGHT_UP = 81.03125
	
	local BM_HITCYLIN_BASE_RADIUS = 43.5 // testing shows it's: 43 < x < 44
	local BM_HITCYLIN_TOP_RADIUS = 43.5//27 // testing shows it's: 25 < x < 30
	
	////////////////////////////
	
	local players = [Entities.FindByClassname(null, "player"), Entities.FindByClassname(null, "cs_bot")]
	foreach(player in players) {
		if(!player) {
			continue
		}
		
		local player_origin = player.GetOrigin()
		local player_bounding_mins = player.GetBoundingMins()
		local player_bounding_maxs = player.GetBoundingMaxs()
		local player_bbox_center = player_origin + player_bounding_mins + (player_bounding_maxs - player_bounding_mins) * 0.5
		
		//printl("-- player")
		//printl("GetOrigin() = " + player_origin)
		//printl("GetBoundingMins() = " + player_bounding_mins)
		//printl("GetBoundingMaxs() = " + player_bounding_maxs)
		//printl("GetBoundingMinsOriented() = " + player.GetBoundingMinsOriented()) // player turning angle should be irrelevant
		//printl("GetBoundingMaxsOriented() = " + player.GetBoundingMaxsOriented()) // player turning angle should be irrelevant
		
		
		DebugDrawLine(player_bbox_center - Vector(5,0,0), player_bbox_center + Vector(5,0,0), 255, 255, 255, true, draw_time)
		DebugDrawLine(player_bbox_center - Vector(0,5,0), player_bbox_center + Vector(0,5,0), 255, 255, 255, true, draw_time)
		DebugDrawLine(player_bbox_center - Vector(0,0,5), player_bbox_center + Vector(0,0,5), 255, 255, 255, true, draw_time)
		
		// [RED] Draw bounding box, not oriented
		DebugDrawBox(player_origin, player_bounding_mins, player_bounding_maxs, 255, 0, 0, 0, draw_time)
	}
	
	
	if(!BM_SCAN_FINISHED && BM_TEST_DRAW_DEBUG_INFO) {
		local pitch_s = sin((-BM_TEST_ANGLES.x) * (PI / 180))
		local pitch_c = cos((-BM_TEST_ANGLES.x) * (PI / 180))
		local yaw_s   = sin(BM_TEST_ANGLES.y * (PI / 180))
		local yaw_c   = cos(BM_TEST_ANGLES.y * (PI / 180))
		local roll_s  = sin(BM_TEST_ANGLES.z * (PI / 180))
		local roll_c  = cos(BM_TEST_ANGLES.z * (PI / 180))
		local green_val = 0
		foreach(row in BM_SCAN_CURRENT_LAYER_RESULTS) {
			foreach(sample in row) {
				if(sample != null) {
					local rotated_pt = Vector(sample.x, sample.y, sample.z)
					// Order of axis rotations is important! First roll, then pitch, then yaw rotation!
					// (roll)  rotation around x axis
					local r_newY = rotated_pt.y * roll_c - rotated_pt.z * roll_s
					local r_newZ = rotated_pt.y * roll_s + rotated_pt.z * roll_c
					rotated_pt.y = r_newY
					rotated_pt.z = r_newZ
					// (pitch) rotation around y axis
					local p_newX = rotated_pt.x * pitch_c - rotated_pt.z * pitch_s
					local p_newZ = rotated_pt.x * pitch_s + rotated_pt.z * pitch_c
					rotated_pt.x = p_newX
					rotated_pt.z = p_newZ
					// (yaw)   rotation around z axis
					local y_newX = rotated_pt.x * yaw_c - rotated_pt.y * yaw_s
					local y_newY = rotated_pt.x * yaw_s + rotated_pt.y * yaw_c
					rotated_pt.x = y_newX
					rotated_pt.y = y_newY
					
					DebugDrawLine(BM_TEST_POS, BM_TEST_POS + rotated_pt, 0, green_val, 255-green_val, false, draw_time)
				}
			}
			green_val += 30
		}
	}
	
	local ent = null
	while(ent = Entities.FindByClassname(ent, "bumpmine_projectile")) {
		local origin = ent.GetOrigin()
		local angles = ent.GetAngles()
		//local velocity = ent.GetVelocity()
		
		//local bounding_mins = ent.GetBoundingMins()
		//local bounding_maxs = ent.GetBoundingMaxs()
		//local bounding_mins_oriented = ent.GetBoundingMinsOriented()
		//local bounding_maxs_oriented = ent.GetBoundingMaxsOriented()
		
		//local up_vector = ent.GetUpVector()
		//local forward_vector = ent.GetForwardVector()
		//local left_vector = ent.GetLeftVector()
		
	
		//printl("-- bumpmine_projectile");
		//printl("GetOrigin() = " + origin)
		//printl("GetAngles() = " + angles)
		
		//printl("GetVelocity() = " + velocity)
		//printl("GetAngularVelocity() = " + ent.GetAngularVelocity())
		
		//rintl("GetBoundingMins() = " + bounding_mins)
		//printl("GetBoundingMaxs() = " + bounding_maxs)
		//printl("GetBoundingMinsOriented() = " + bounding_mins_oriented)
		//printl("GetBoundingMaxsOriented() = " + bounding_maxs_oriented)
		
		//printl("GetUpVector() = " + up_vector)
		//printl("GetForwardVector() = " + forward_vector)
		//printl("GetLeftVector() = " + left_vector)
		
		//printl("GetMoveParent()     = " + ent.GetMoveParent())     // (null : 0x00000000) when falling or ([0] worldspawn) when fixed
		//printl("GetRootMoveParent() = " + ent.GetRootMoveParent()) // ([97] bumpmine_projectile) when falling or ([0] worldspawn) when fixed
		
		// [DARK BLUE] Draw origin
		DebugDrawLine(origin - Vector(5,0,0), origin + Vector(5,0,0), 0, 0, 255, true, draw_time)
		DebugDrawLine(origin - Vector(0,5,0), origin + Vector(0,5,0), 0, 0, 255, true, draw_time)
		DebugDrawLine(origin - Vector(0,0,5), origin + Vector(0,0,5), 0, 0, 255, true, draw_time)
		
		// [PINK] Draw bounding box, not oriented
		//DebugDrawBox(ent.GetOrigin(), bounding_mins, bounding_maxs, 255, 0, 255, 0, draw_time)
		// [DARK PURPLE] Draw bounding box, oriented mins maxs
		//DebugDrawBox(ent.GetOrigin(), bounding_mins_oriented, bounding_maxs_oriented, 127, 0, 255, 30, draw_time)
		
		// [GREEN] Draw bounding box, oriented
		//DebugDrawBoxAngles(ent.GetOrigin(), bounding_mins, bounding_maxs, angles, 0, 200, 0, 20, draw_time)
		
		// [YELLOW] Draw velocity
		//DebugDrawLine(origin, origin + velocity * 0.1, 255, 255, 0, true, draw_time)
		
		// [ORANGE] Draw up vector
		//DebugDrawLine(origin, origin + up_vector * 20, 255, 120, 0, true, draw_time)
		// [RED] Draw left/forward vector
		//DebugDrawLine(origin, origin + forward_vector * 20, 255, 0, 0, true, draw_time)
		//DebugDrawLine(origin, origin + left_vector    * 20, 255, 0, 0, true, draw_time)
		
		// [AQUA] Draw hitcircle
		//local circle_pt_count = 0
		//local basecircle_points = []
		//local topcircle_points = []
		//for(local i = 0; i < 2 * PI; i += PI / 16) {
		//	local s = sin(i)
		//	local c = cos(i)
		//	basecircle_points.append(Vector(s * BM_HITCYLIN_BASE_RADIUS, c * BM_HITCYLIN_BASE_RADIUS, 0))
		//	topcircle_points .append(Vector(s * BM_HITCYLIN_TOP_RADIUS , c * BM_HITCYLIN_TOP_RADIUS , BM_HITCYLINDER_HEIGHT_UP))
		//	circle_pt_count++
		//}
		
		local pitch_s = sin((-angles.x) * (PI / 180))
		local pitch_c = cos((-angles.x) * (PI / 180))
		local yaw_s   = sin(angles.y * (PI / 180))
		local yaw_c   = cos(angles.y * (PI / 180))
		local roll_s  = sin(angles.z * (PI / 180))
		local roll_c  = cos(angles.z * (PI / 180))
		
		local rotated_rings = []
		foreach(ring in BM_SCAN_HIT_RINGS) {
			local rotated_ring = []
			foreach(point in ring) {
				local new_point = Vector(point.x, point.y, point.z)
				// Order of axis rotations is important! First roll, then pitch, then yaw rotation!
				// (roll)  rotation around x axis
				local r_newY = new_point.y * roll_c - new_point.z * roll_s
				local r_newZ = new_point.y * roll_s + new_point.z * roll_c
				new_point.y = r_newY
				new_point.z = r_newZ
				// (pitch) rotation around y axis
				local p_newX = new_point.x * pitch_c - new_point.z * pitch_s
				local p_newZ = new_point.x * pitch_s + new_point.z * pitch_c
				new_point.x = p_newX
				new_point.z = p_newZ
				// (yaw)   rotation around z axis
				local y_newX = new_point.x * yaw_c - new_point.y * yaw_s
				local y_newY = new_point.x * yaw_s + new_point.y * yaw_c
				new_point.x = y_newX
				new_point.y = y_newY
				
				// Translate to bumpmine origin
				rotated_ring.push(origin + new_point)
			}
			rotated_rings.push(rotated_ring)
		}
		
		foreach(ring in rotated_rings) {
			for(local i = 0; i < ring.len(); i++) {
				local next_idx = i + 1
				if(next_idx == ring.len()) {
					next_idx = 0
				}
				DebugDrawLine(ring[i], ring[next_idx], 255, 255, 0, false, draw_time)
			}
		}
		
		//local hitbody_r = 0
		//local hitbody_g = 255
		//local hitbody_b = 255
		//
		//for(local i = 0; i < circle_pt_count; i++) {
		//	local pt_idx = i
		//	local pt_idx_next = i+1
		//	if(pt_idx_next == circle_pt_count)
		//		pt_idx_next = 0
		//	
		//	// Draw base circle
		//	DebugDrawLine(basecircle_points[pt_idx], basecircle_points[pt_idx_next], hitbody_r, hitbody_g, hitbody_b, false, draw_time)
		//	// Draw top circle
		//	DebugDrawLine(topcircle_points[pt_idx], topcircle_points[pt_idx_next], hitbody_r, hitbody_g, hitbody_b, false, draw_time)
		//	// Connect base and top circle
		//	DebugDrawLine(basecircle_points[pt_idx], topcircle_points[pt_idx], hitbody_r, hitbody_g, hitbody_b, false, draw_time)
		//}
		
		
		// ent_fire bumpmine_projectile RunScriptCode "self.SetVelocity(Vector(0,0,0));self.SetAngles(0,0,0);self.SetAngularVelocity(0,0,0);"
		
		// [AQUA] Draw hitbox, not oriented
		//local HITBOX_SIZE = 16 //  > x < 30
		//DebugDrawBox(ent.GetOrigin(), Vector(-HITBOX_SIZE,-HITBOX_SIZE,-HITBOX_SIZE), Vector(HITBOX_SIZE,HITBOX_SIZE,HITBOX_SIZE), 0, 255, 255, 0, draw_time)
		
		//DebugDrawBox(ent.GetOrigin(), Vector(-20,-20,-20), Vector(20,20,20), 0, 255, 255, 1.0, draw_time)
		//DebugDrawBoxAngles(ent.GetOrigin(), Vector(-20,-20,-20), Vector(20,20,20), Vector(0,0,45), 0, 255, 255, 1.0, draw_time)
		
		// float TraceLine(Vector start, Vector end, handle ignore)
		// float TraceLinePlayersIncluded(Vector start, Vector end, handle ignore)
	}
}

function dzsim_init() {
	
	if(ScriptGetGameMode() != 0 || ScriptGetGameType() != 6) { // Ensure we are in the Danger Zone gamemode
		dzsim_run_server_command("game_mode 0;game_type 6;map " + GetMapName())
		return
	}
	
	printl("")
	printl("")
	printl("---- DZSim Test Script: Bumpmine Trigger area scan")
	
	local commands = [
		"sv_cheats 1",
		"sv_infinite_ammo 1",
		"sv_regeneration_force_on 1",
		"sv_dz_parachute_reuse 0",
		"sv_dz_warmup_tablet 0",
		"sv_gravity 0",
		"mp_warmup_pausetimer 1",
		"fps_max 900",
		"bot_stop 1",
		"bot_mimic 0",
		"bot_kick",
		"bot_quota 1",
		"bot_quota_mode normal",
		"developer 1",
		"ent_remove_all bumpmine_projectile"
	]
	
	if(BM_TEST_CROUCHING) {
		commands.append("bot_crouch 1")
	} else {
		commands.append("bot_crouch 0")
	}
	
	if(Entities.FindByClassname(null, "weapon_bumpmine") == null) {
		commands.append("give weapon_bumpmine")
	}
	
	dzsim_run_server_commands(commands)
	dzsim_run_server_command("-attack", 0.5)
	dzsim_run_server_command("-attack", 0.6)
	
	// Wait before initializing and setting BM_SCAN_INITIALIZED to true, because
	// pending function calls to dzsim_bm_scan_step() need to happen and stop recursing
	dzsim_run_server_command("script dzsim_delayed_init()", 2 * BM_DETONATE_DELAY)
}

//////////////////////////////

dzsim_init()
