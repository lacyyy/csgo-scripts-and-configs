/////////////////////////////////////////////////////////////////////////////////////////////////////
// Purpose: This script visualizes areas in which a player can trigger a Bump Mine. Only works in
//          local servers for the hosting player. Additionally, roughly estimates the chance of
//          triggering a bumpmine after moving through it.
// 
// HOW TO INSTALL AND USE:
//   To install, put this file into the following folder:
//       Steam\steamapps\common\Counter-Strike Global Offensive\csgo\scripts\vscripts
//   Once loaded onto a map, enter this into the game console: script_execute bm_trigger_vis
//
// Made by lacyyy:
//   https://github.com/lacyyy
//   https://steamcommunity.com/profiles/76561198162669616
//
/////////////////////////////////////////////////////////////////////////////////////////////////////

// TODO:    Calculate total jump chance

//BM_DEBUG_COUNTER <- 0 // fixme remove this later

// Only if player AABB intersects with bumpmine AABB, he triggers and gets boosted
BM_AABB_MINS <- Vector(-81,-81,-81)
BM_AABB_MAXS <- Vector( 81, 81, 81)

BM_ARM_DELAY <- 0.3 // in seconds
BM_ARM_DELAY_TICKS <- (BM_ARM_DELAY / FrameTime() + 0.5).tointeger() // Must be integer

PLAYER_AABB_WIDTH <- 32
PLAYER_AABB_HEIGHT_STANDING <- 72
PLAYER_AABB_HEIGHT_CROUCHING <- 54

BM_TRIG_MINS_STANDING  <- BM_AABB_MINS - Vector(PLAYER_AABB_WIDTH/2, PLAYER_AABB_WIDTH/2, PLAYER_AABB_HEIGHT_STANDING/2)
BM_TRIG_MAXS_STANDING  <- BM_AABB_MAXS + Vector(PLAYER_AABB_WIDTH/2, PLAYER_AABB_WIDTH/2, PLAYER_AABB_HEIGHT_STANDING/2)
BM_TRIG_MINS_CROUCHING <- BM_AABB_MINS - Vector(PLAYER_AABB_WIDTH/2, PLAYER_AABB_WIDTH/2, PLAYER_AABB_HEIGHT_CROUCHING/2)
BM_TRIG_MAXS_CROUCHING <- BM_AABB_MAXS + Vector(PLAYER_AABB_WIDTH/2, PLAYER_AABB_WIDTH/2, PLAYER_AABB_HEIGHT_CROUCHING/2)

BM_TRIG_VIS_LOGIC_RELAY_NAME <- "bm_trigger_vis_relay"

BM_TRIG_HISTORY_CNT <- 3 // how many recent bumpmines that no longer exist are visualized
BM_TRIG_TRAJECTORY_MAX_SIZE <- 50 // at most, how many player trajectory positions are saved per bumpmine
BM_TRIG_TRAJECTORY_DIST <- 180 // in units, at what player-bumpmine distance the player's trajectory is saved
BM_TRIG_TRAJECTORY_DIST_SQR <- BM_TRIG_TRAJECTORY_DIST * BM_TRIG_TRAJECTORY_DIST
BM_TRIG_UPDATE_INTERVAL <- 0.015625 // in seconds, how often trigger volumes are updated (bumpmines on moving objects)
BM_TRIG_TICKS_PER_UPDATE <- (BM_TRIG_UPDATE_INTERVAL / FrameTime() + 0.5).tointeger()
BM_TRIG_CHECK_INTERVAL <- 0.1 // in seconds, how often bumpmines are checked for triggering
BM_TRIG_CHECK_INTERVAL_TICKS <- (BM_TRIG_CHECK_INTERVAL / FrameTime() + 0.5).tointeger()
BM_TRIG_TICK_CNT <- 0
BM_TRIG_PLAYER_IN_BM_TRIG_CNT <- 0

// Bumpmine ellipsoid properties
ELL_VERT_SEMI_DIAMETER <- 138.11 / 2
ELL_HORI_SEMI_DIAMETER <-  93.62 / 2
ELL_Z_OFFSET <- 51.415 // in both +Z and -Z direction from bumpmine origin

BM_TRIG_VIS_FIRST_INIT <- Entities.FindByName(null, BM_TRIG_VIS_LOGIC_RELAY_NAME ) == null

// If script was run before, keep the old bumpmine tables to remember each bm's age!
if(BM_TRIG_VIS_FIRST_INIT) {
	// Tables of data of each bumpmine. Slots are bumpmine_projectile handles
	BM_TRIG_VIS_TABLE_bm_ticks <- {} // each value is an int, the number of ticks since it was placed
	BM_TRIG_VIS_TABLE_bm_ticks_killed <- {} // each value is an int, the number of ticks when the bm was detonated/deleted
	BM_TRIG_VIS_TABLE_bm_pos <- {} // each value is a vector, the bumpmine's origin position
	BM_TRIG_VIS_TABLE_bm_mesh <- {} // each value is an array of meshes, which are arrays of rings to draw
	BM_TRIG_VIS_TABLE_bm_triggered_prev <- {} // each value is a boolean, if a player is inside the trigger volume
	BM_TRIG_VIS_TABLE_bm_trig_cnt <- {} // each value is an int, the number of ticks a player was inside the trigger volume
	BM_TRIG_VIS_TABLE_bm_trig_pts <- {} // each value is an array of arrays containing each 2 vectors, player center point positions
		// around a bm, chronologically, and the point's visualized color
	
	// All placed bumpmines on the map need to be deleted because we don't know their age!
	local bm = null
	while(bm = Entities.FindByClassname(bm, "bumpmine_projectile")) {
		if(!bm.IsValid() || bm.GetMoveParent() == null)
			continue
		EntFireByHandle( bm, "DisableDraw", "", 0.05, null, null )
		EntFireByHandle( bm, "Kill", "", 0.1, null, null )
	}
}
function bm_trigger_vis_del_bm_table_entries(bm) {
	delete BM_TRIG_VIS_TABLE_bm_ticks[bm]
	delete BM_TRIG_VIS_TABLE_bm_ticks_killed[bm]
	delete BM_TRIG_VIS_TABLE_bm_pos[bm]
	delete BM_TRIG_VIS_TABLE_bm_mesh[bm]
	delete BM_TRIG_VIS_TABLE_bm_triggered_prev[bm]
	delete BM_TRIG_VIS_TABLE_bm_trig_cnt[bm]
	delete BM_TRIG_VIS_TABLE_bm_trig_pts[bm]
}

// script SendToConsole("play ui/beep07") // armed
// script SendToConsole("play buttons/button22") // not armed

// script SendToConsole("play buttons/button15")
// script SendToConsole("play common/beep")
// script SendToConsole("play common/talk")
// script SendToConsole("play items/flashlight1")
// script SendToConsole("play common/wpn_denyselect")
// script SendToConsole("play survival/breach_activate_01")
// script SendToConsole("play survival/breach_activate_nobombs_01")
// script SendToConsole("play survival/buy_item_failed_01")
// script SendToConsole("play survival/money_collect_01")
// script SendToConsole("play training/popup")
// script SendToConsole("play training/timer_bell")
// script SendToConsole("play ui/menu_invalid")
// script SendToConsole("play weapons/famas/famas_boltforward")
// script SendToConsole("play weapons/famas/famas_boltback")

function bm_trigger_vis_get_point_servercommand() {
	local sv_cmd = Entities.FindByClassname(null, "point_servercommand")
	if(!sv_cmd) { // Create if it doesn't exist
		sv_cmd = Entities.CreateByClassname("point_servercommand")
	}
	return sv_cmd
}

function bm_trigger_vis_run_server_commands(arr_commands) {
	local ent_sv_cmd = bm_trigger_vis_get_point_servercommand()
	foreach(cmd in arr_commands) {
		EntFireByHandle(ent_sv_cmd, "command", cmd, 0, null, null)
	}
}

function bm_trigger_vis_run_server_command(command, delay=0.0) {
	local ent_sv_cmd = bm_trigger_vis_get_point_servercommand()
	EntFireByHandle(ent_sv_cmd, "command", command, delay, null, null)
}

function bm_trigger_vis_calc_ellipsoid_surf_points(offset) {
	local VERT_STEP_ANGLE = 15 // in degrees
	local HORI_STEP_ANGLE = 35 // in degrees
	// Convert to radians
	VERT_STEP_ANGLE *= PI / 180
	HORI_STEP_ANGLE *= PI / 180
	
	local rings = []
	for(local vert_angle = -PI/2; vert_angle <= PI/2; vert_angle += VERT_STEP_ANGLE) {
		local layer_ring = []
		for(local hori_angle = 0; hori_angle < 2*PI; hori_angle += HORI_STEP_ANGLE) {
			local x = offset.x + ELL_HORI_SEMI_DIAMETER * cos(vert_angle) * cos(hori_angle)
			local y = offset.y + ELL_HORI_SEMI_DIAMETER * cos(vert_angle) * sin(hori_angle)
			local z = offset.z + ELL_VERT_SEMI_DIAMETER * sin(vert_angle)
			layer_ring.push(Vector(x,y,z))
		}
		rings.push(layer_ring)
	}
	return rings
}

function bm_trigger_is_valid_player(player) {
	if(!player || !player.IsValid()) return false
	if(player.GetTeam() == 0 || player.GetTeam() == 1) return false // 0 = no team, 1 = spectators
	return true
}

// Credit to zer0.k for reverse engineering the precise formula
function bm_trigger_accurate_check(bm, player) {
	local BM_AABB_DIST = 81
	local bm_origin = bm.GetOrigin()
	
	// Point of the player's AABB that is the nearest to the bumpmine
	local p_mins = player.GetOrigin() + player.GetBoundingMins()
	local p_maxs = player.GetOrigin() + player.GetBoundingMaxs()
	local nearest_p_point = Vector(bm_origin.x, bm_origin.y, bm_origin.z)
	if(nearest_p_point.x < p_mins.x) nearest_p_point.x = p_mins.x
	if(nearest_p_point.y < p_mins.y) nearest_p_point.y = p_mins.y
	if(nearest_p_point.z < p_mins.z) nearest_p_point.z = p_mins.z
	if(nearest_p_point.x > p_maxs.x) nearest_p_point.x = p_maxs.x
	if(nearest_p_point.y > p_maxs.y) nearest_p_point.y = p_maxs.y
	if(nearest_p_point.z > p_maxs.z) nearest_p_point.z = p_maxs.z
	
	// Return false if player AABB doesn't intersect with the bumpmine trigger AABB
	if(fabs(nearest_p_point.x - bm_origin.x) > BM_AABB_DIST) return false
	if(fabs(nearest_p_point.y - bm_origin.y) > BM_AABB_DIST) return false
	if(fabs(nearest_p_point.z - bm_origin.z) > BM_AABB_DIST) return false
	
	// Check if player center point is inside the bumpmine's trigger ellipsoid
	local p_center_dist_vec = player.GetCenter() - bm_origin
	local p_center_dist = p_center_dist_vec.Length()
	local x = fabs(p_center_dist_vec.Dot(bm.GetUpVector()) / (p_center_dist + 0.00000011920929)) - 0.02
	if(x < 0.0) x = 0.0
	if(x > 1.0) x = 1.0
	local final = ((x * -1.5) + 2.0) * p_center_dist
	return final <= 64.0
}

function bm_trigger_vis_do_point_rotation(point, pitch, yaw, roll) {
	local new_pt = Vector(point.x, point.y, point.z)
	local pitch_c = cos(-pitch * (PI / 180))
	local pitch_s = sin(-pitch * (PI / 180))
	local yaw_c   = cos(yaw * (PI / 180))
	local yaw_s   = sin(yaw * (PI / 180))
	local roll_c  = cos(roll * (PI / 180))
	local roll_s  = sin(roll * (PI / 180))
	// Order of axis rotations is important! First roll, then pitch, then yaw rotation!
	// (roll)  rotation around x axis
	local r_newY = new_pt.y * roll_c - new_pt.z * roll_s
	local r_newZ = new_pt.y * roll_s + new_pt.z * roll_c
	new_pt.y = r_newY
	new_pt.z = r_newZ
	// (pitch) rotation around y axis
	local p_newX = new_pt.x * pitch_c - new_pt.z * pitch_s
	local p_newZ = new_pt.x * pitch_s + new_pt.z * pitch_c
	new_pt.x = p_newX
	new_pt.z = p_newZ
	// (yaw)   rotation around z axis
	local y_newX = new_pt.x * yaw_c - new_pt.y * yaw_s
	local y_newY = new_pt.x * yaw_s + new_pt.y * yaw_c
	new_pt.x = y_newX
	new_pt.y = y_newY
	return new_pt
}

function bm_trigger_vis_reverse_point_rotation(point, pitch, yaw, roll) {
	local new_pt = Vector(point.x, point.y, point.z)
	// To reverse the rotation, rotate axes in reverse order with negated rotation values.
	local pitch_c = cos(-(-pitch * (PI / 180)))
	local pitch_s = sin(-(-pitch * (PI / 180)))
	local yaw_c   = cos(-(yaw * (PI / 180)))
	local yaw_s   = sin(-(yaw * (PI / 180)))
	local roll_c  = cos(-(roll * (PI / 180)))
	local roll_s  = sin(-(roll * (PI / 180)))
	// First yaw, then pitch, then roll rotation!
	// (yaw)   rotation around z axis
	local y_newX = new_pt.x * yaw_c - new_pt.y * yaw_s
	local y_newY = new_pt.x * yaw_s + new_pt.y * yaw_c
	new_pt.x = y_newX
	new_pt.y = y_newY
	// (pitch) rotation around y axis
	local p_newX = new_pt.x * pitch_c - new_pt.z * pitch_s
	local p_newZ = new_pt.x * pitch_s + new_pt.z * pitch_c
	new_pt.x = p_newX
	new_pt.z = p_newZ
	// (roll)  rotation around x axis
	local r_newY = new_pt.y * roll_c - new_pt.z * roll_s
	local r_newZ = new_pt.y * roll_s + new_pt.z * roll_c
	new_pt.y = r_newY
	new_pt.z = r_newZ
	return new_pt
}

function bm_trigger_vis_calc_closest_trigger_point(bumpmine, target_point) {
	local bm_origin = bumpmine.GetOrigin()
	local bm_angles = bumpmine.GetAngles()
	// Translate "targetpoint-bumpmine" relation to world origin and unrotate it with the bumpmine's rotation
	local ur_target_point = bm_trigger_vis_reverse_point_rotation(target_point - bm_origin, bm_angles.x, bm_angles.y, bm_angles.z)
	// Choose the ellipsoid that's closer to target_point
	local ur_ellipsoid_center = ur_target_point.z > 0 ? Vector(0,0,ELL_Z_OFFSET) : Vector(0,0,-ELL_Z_OFFSET)
	// Calculate horizontal and vertical angles of ur_target_dir
	local ur_target_dir = ur_target_point - ur_ellipsoid_center
	local ur_target_dir_xy = Vector(ur_target_dir.x, ur_target_dir.y, 0)
	local hori_angle = atan2(ur_target_dir.y, ur_target_dir.x) // undefined for x=0,y=0 !!!
	local vert_angle = acos((ur_target_dir.Dot(ur_target_dir_xy)) / (ur_target_dir.Length() * ur_target_dir_xy.Length()))
	// vert_angle is correct, but the ellipsoid surface point calculation below somehow interprets it in a manipulated way
	// I don't understand it, but this sine offset minimizes the error.
	vert_angle -= 0.175 * sin(vert_angle*2)
	// since acos only gives positive angles, adjust for downwards directions
	if(ur_target_dir.z < 0)
		vert_angle = -vert_angle
	// Determine ellipsoid surface point at those angles
	local ur_surf_pt_x = ur_ellipsoid_center.x + ELL_HORI_SEMI_DIAMETER * cos(vert_angle) * cos(hori_angle)
	local ur_surf_pt_y = ur_ellipsoid_center.y + ELL_HORI_SEMI_DIAMETER * cos(vert_angle) * sin(hori_angle)
	local ur_surf_pt_z = ur_ellipsoid_center.z + ELL_VERT_SEMI_DIAMETER * sin(vert_angle)
	local ur_surf_pt = Vector(ur_surf_pt_x, ur_surf_pt_y, ur_surf_pt_z)
	// Rotate surface point with bumpmine's angles
	local surf_pt = bm_trigger_vis_do_point_rotation(ur_surf_pt, bm_angles.x, bm_angles.y, bm_angles.z)
	// Make sure it's inside the bumpmine's trigger aabb
	if(surf_pt.x < BM_TRIG_MINS_STANDING.x) surf_pt.x = BM_TRIG_MINS_STANDING.x
	if(surf_pt.x > BM_TRIG_MAXS_STANDING.x) surf_pt.x = BM_TRIG_MAXS_STANDING.x
	if(surf_pt.y < BM_TRIG_MINS_STANDING.y) surf_pt.y = BM_TRIG_MINS_STANDING.y
	if(surf_pt.y > BM_TRIG_MAXS_STANDING.y) surf_pt.y = BM_TRIG_MAXS_STANDING.y
	if(surf_pt.z < BM_TRIG_MINS_STANDING.z) surf_pt.z = BM_TRIG_MINS_STANDING.z
	if(surf_pt.z > BM_TRIG_MAXS_STANDING.z) surf_pt.z = BM_TRIG_MAXS_STANDING.z
	// Translate to bumpmine origin
	surf_pt += bm_origin
	// Draw stuff
	local ellipsoid_center = bm_origin + bm_trigger_vis_do_point_rotation(ur_ellipsoid_center, bm_angles.x, bm_angles.y, bm_angles.z)
	local surf_pt_dist_sq   = (surf_pt      - ellipsoid_center).LengthSqr()
	local target_pt_dist_sq = (target_point - ellipsoid_center).LengthSqr()
	if(target_pt_dist_sq < surf_pt_dist_sq) // Don't return point if target is inside trigger volume
		return null
	return surf_pt
}

// Calculate lines to draw bumpmine trigger volume
function bm_trigger_vis_calc_bm_meshes(bumpmine) {
	local meshes = []
	
	// Calculate ellipsoid surface points
	local top_ellipsoid = bm_trigger_vis_calc_ellipsoid_surf_points(Vector(0,0,ELL_Z_OFFSET))
	local bottom_ellipsoid = []
	foreach(ring in top_ellipsoid) {
		local new_ring = []
		foreach(pt in ring) {
			new_ring.push(Vector(pt.x, pt.y, pt.z - 2 * ELL_Z_OFFSET))
		}
		bottom_ellipsoid.push(new_ring)
	}
	// Delete rings of top ellipsoid below z = 0
	local redundant_ring_indices_top = []
	foreach(idx, ring in top_ellipsoid) {
		if(ring.len() == 0) continue
		if(ring[0].z < 0) redundant_ring_indices_top.push(idx)
	}
	foreach(remove_count,ring_idx in redundant_ring_indices_top) {
		top_ellipsoid.remove(ring_idx - remove_count)
	}
	// Delete rings of bottom ellipsoid above z = 0
	local redundant_ring_indices_bottom = []
	foreach(idx, ring in bottom_ellipsoid) {
		if(ring.len() == 0) continue
		if(ring[0].z > 0) redundant_ring_indices_bottom.push(idx)
	}
	foreach(remove_count,ring_idx in redundant_ring_indices_bottom) {
		bottom_ellipsoid.remove(ring_idx - remove_count)
	}
	
	local total_ellipsoid_rings = top_ellipsoid
	total_ellipsoid_rings.extend(bottom_ellipsoid)
	meshes.push(total_ellipsoid_rings)
	
	// Rotate meshes according to the bumpmine's orientation and translate them to bumpmine's origin
	local origin = bumpmine.GetOrigin()
	local angles = bumpmine.GetAngles()
	local pitch_s = sin((-angles.x) * (PI / 180))
	local pitch_c = cos((-angles.x) * (PI / 180))
	local yaw_s   = sin(angles.y * (PI / 180))
	local yaw_c   = cos(angles.y * (PI / 180))
	local roll_s  = sin(angles.z * (PI / 180))
	local roll_c  = cos(angles.z * (PI / 180))
	foreach(mesh in meshes) {
		foreach(ring in mesh) {
			foreach(idx, point in ring) {
				// Order of axis rotations is important! First roll, then pitch, then yaw rotation!
				// (roll)  rotation around x axis
				local r_newY = point.y * roll_c - point.z * roll_s
				local r_newZ = point.y * roll_s + point.z * roll_c
				point.y = r_newY
				point.z = r_newZ
				// (pitch) rotation around y axis
				local p_newX = point.x * pitch_c - point.z * pitch_s
				local p_newZ = point.x * pitch_s + point.z * pitch_c
				point.x = p_newX
				point.z = p_newZ
				// (yaw)   rotation around z axis
				local y_newX = point.x * yaw_c - point.y * yaw_s
				local y_newY = point.x * yaw_s + point.y * yaw_c
				point.x = y_newX
				point.y = y_newY
				// Translate to bumpmine origin
				point += origin
				// Set new point in array
				ring[idx] = point
			}
		}
	}
	
	// Delete points that are cut off by the bumpmine trigger aabb check
	local PT_STANDING_MINS = origin + BM_TRIG_MINS_STANDING
	local PT_STANDING_MAXS = origin + BM_TRIG_MAXS_STANDING
	foreach(mesh in meshes) {
		foreach(ring in mesh) {
			//local cutoff_point_indices = []
			foreach(idx, point in ring) {
				if(point.x < PT_STANDING_MINS.x) point.x = PT_STANDING_MINS.x
				if(point.x > PT_STANDING_MAXS.x) point.x = PT_STANDING_MAXS.x
				if(point.y < PT_STANDING_MINS.y) point.y = PT_STANDING_MINS.y
				if(point.y > PT_STANDING_MAXS.y) point.y = PT_STANDING_MAXS.y
				if(point.z < PT_STANDING_MINS.z) point.z = PT_STANDING_MINS.z
				if(point.z > PT_STANDING_MAXS.z) point.z = PT_STANDING_MAXS.z
			}
		}
	}
	// Separate points that only trigger for a standing player from the rest
	local PT_CROUCHING_MINS = origin + BM_TRIG_MINS_CROUCHING
	local PT_CROUCHING_MAXS = origin + BM_TRIG_MAXS_CROUCHING
	local standing_only_mesh = []
	foreach(mesh in meshes) {
		foreach(ring in mesh) {
			local separated_points = []
			local separated_point_indices = []
			foreach(idx, point in ring) {
				if( point.x < PT_CROUCHING_MINS.x || point.x > PT_CROUCHING_MAXS.x ||
					point.y < PT_CROUCHING_MINS.y || point.y > PT_CROUCHING_MAXS.y ||
					point.z < PT_CROUCHING_MINS.z || point.z > PT_CROUCHING_MAXS.z) {
					separated_point_indices.push(idx)
				}
			}
			foreach(remove_count,pt_idx in separated_point_indices) {
				separated_points.push(ring[pt_idx - remove_count])
				ring.remove(pt_idx - remove_count)
			}
			standing_only_mesh.push(separated_points)
		}
	}
	meshes.push(standing_only_mesh)
	
	
	return meshes
}

// Oriented debug boxes always facing the player
function bm_trigger_vis_draw_progress_bar(player, bar_pos, n, max_n, col, draw_time) {
	//if(player.GetVelocity().Length() > 300.0) {
	//	local move_dir = player.GetVelocity()
	//	move_dir.z = 0
	//	move_dir.Norm()
	//	bar_pos = player.EyePosition() + move_dir * (bar_pos - player.EyePosition()).Length()
	//}
	
	local alter_msg = "►"
	for(local i = 0; i < n; i++) alter_msg += "■"
	for(local i = n; i < max_n; i++) alter_msg += "~"
	alter_msg += "◄"
	ScriptPrintMessageCenterAll(alter_msg)
	
	local disp_dir = bar_pos - player.EyePosition() // In what direction the bar is drawn, from the player's pov
	
	local disp_ang_v = atan2(Vector(disp_dir.x, disp_dir.y, 0).Length(), disp_dir.z) * 180.0 / PI
	disp_ang_v -= 90.0
	local disp_ang_h = atan2(disp_dir.y, disp_dir.x) * 180.0 / PI
	local bar_angles = Vector(disp_ang_v, disp_ang_h, 0) // pitch, yaw, roll
	
	local scale = 0.007 * disp_dir.Length()
	local bar_size = scale * 40.0
	local d = 0.1 // depth
	local c = scale * 4.0 // edge length
	
	// center row that advances
	DebugDrawBoxAngles(bar_pos, Vector(-d, 0.5*bar_size,-0.5*c), Vector(d,0.5*bar_size-(bar_size*n/max_n),0.5*c), bar_angles, col.x, col.y, col.z, 255, draw_time)
	// boundary
	DebugDrawBoxAngles(bar_pos, Vector(-d,-0.5*bar_size,-1.5*c), Vector(d,0.5*bar_size,-0.5*c), bar_angles, col.x/2, col.y/2, col.z/2, 255, draw_time)
	DebugDrawBoxAngles(bar_pos, Vector(-d,-0.5*bar_size, 0.5*c), Vector(d,0.5*bar_size, 1.5*c), bar_angles, col.x/2, col.y/2, col.z/2, 255, draw_time)
	DebugDrawBoxAngles(bar_pos, Vector(-d, 0.5*bar_size,-1.5*c), Vector(d,0.5*bar_size+c,1.5*c), bar_angles, col.x/2, col.y/2, col.z/2, 255, draw_time)
	DebugDrawBoxAngles(bar_pos, Vector(-d,-0.5*bar_size-c,-1.5*c), Vector(d,-0.5*bar_size,1.5*c), bar_angles, col.x/2, col.y/2, col.z/2, 255, draw_time)
	
	//// center column that rises
	//DebugDrawBoxAngles(bar_pos, Vector(-d,-0.5*c,-0.5*bar_size), Vector(d,0.5*c,(bar_size*n/max_n)-0.5*bar_size), bar_angles, col.x, col.y, col.z, 255, draw_time)
	//// boundary
	//DebugDrawBoxAngles(bar_pos, Vector(-d,-1.5*c,-0.5*bar_size), Vector(d,-0.5*c,0.5*bar_size), bar_angles, col.x/2, col.y/2, col.z/2, 255, draw_time)
	//DebugDrawBoxAngles(bar_pos, Vector(-d, 0.5*c,-0.5*bar_size), Vector(d, 1.5*c,0.5*bar_size), bar_angles, col.x/2, col.y/2, col.z/2, 255, draw_time)
	//DebugDrawBoxAngles(bar_pos, Vector(-d,-1.5*c, 0.5*bar_size), Vector(d,1.5*c,0.5*bar_size+c), bar_angles, col.x/2, col.y/2, col.z/2, 255, draw_time)
	//DebugDrawBoxAngles(bar_pos, Vector(-d,-1.5*c,-0.5*bar_size-c), Vector(d,1.5*c,-0.5*bar_size), bar_angles, col.x/2, col.y/2, col.z/2, 255, draw_time)
	
}

function bm_trigger_vis_draw_bm(bm) {
	local DRAW_TIME = 2 * FrameTime()
	
	local origin = BM_TRIG_VIS_TABLE_bm_pos[bm]
	
	// [DARK BLUE] Draw origin
	DebugDrawLine(origin - Vector(5,0,0), origin + Vector(5,0,0), 0, 0, 255, true, DRAW_TIME)
	DebugDrawLine(origin - Vector(0,5,0), origin + Vector(0,5,0), 0, 0, 255, true, DRAW_TIME)
	DebugDrawLine(origin - Vector(0,0,5), origin + Vector(0,0,5), 0, 0, 255, true, DRAW_TIME)
	
	// [PINK] Draw bumpmine trigger check
	local ticks_since_armed = BM_TRIG_VIS_TABLE_bm_ticks[bm] - BM_ARM_DELAY_TICKS
	if(ticks_since_armed >= 0 && ticks_since_armed % BM_TRIG_CHECK_INTERVAL_TICKS == 0) {
		DebugDrawBox(origin, Vector(-4,-4,-4), Vector(4,4,4), 255, 0, 255, 255, DRAW_TIME)
	}
	
	// [WHITE] Draw bumpmine AABB
	//DebugDrawBox(origin, BM_AABB_MINS, BM_AABB_MAXS, 255, 255, 255, 0, DRAW_TIME)
	
	// [YELLOW] Draw trigger cutoff box for both standing and crouching
	DebugDrawBox(origin, BM_TRIG_MINS_CROUCHING, BM_TRIG_MAXS_CROUCHING, 255, 255, 0, 0, DRAW_TIME)
	
	// [ORANGE] Draw trigger cutoff box for only standing
	local special_col = [255,160,0]
	local topBoxMins = Vector(BM_TRIG_MINS_CROUCHING.x, BM_TRIG_MINS_CROUCHING.y, BM_TRIG_MAXS_CROUCHING.z)
	DebugDrawBox(origin, topBoxMins, BM_TRIG_MAXS_STANDING, special_col[0], special_col[1], special_col[2], 0, DRAW_TIME)
	local bottomBoxMaxs = Vector(BM_TRIG_MAXS_STANDING.x, BM_TRIG_MAXS_STANDING.y, BM_TRIG_MINS_CROUCHING.z)
	DebugDrawBox(origin, BM_TRIG_MINS_STANDING, bottomBoxMaxs, special_col[0], special_col[1], special_col[2], 0, DRAW_TIME)
	
	// [PURPLE] Draw triggering player trajectory
	local traj = BM_TRIG_VIS_TABLE_bm_trig_pts[bm]
	for(local i = 0; i < traj.len(); i++) {
		local pt_pos = traj[i][0]
		local pt_col = traj[i][1]
		DebugDrawBox(pt_pos, Vector(-1,-1,-1), Vector(1,1,1), pt_col.x, pt_col.y, pt_col.z, 100, DRAW_TIME)
		if(i != traj.len() - 1)
			DebugDrawLine(pt_pos, traj[i+1][0], 127, 0, 255, false, DRAW_TIME)
	}
	
	local volume_colors = [
		[255,255,  0], // yellow
		special_col,   // orange
	]
	
	local bm_meshes = BM_TRIG_VIS_TABLE_bm_mesh[bm]
	foreach(mesh_idx,ring_array in bm_meshes) {
		local color_idx = mesh_idx % volume_colors.len()
		local volume_color = volume_colors[color_idx]
		local col_r = volume_color[0]
		local col_g = volume_color[1]
		local col_b = volume_color[2]
		
		foreach(ring in ring_array) {
			for(local i = 0; i < ring.len(); i++) {
				local next_idx = i + 1
				if(next_idx == ring.len()) {
					next_idx = 0
				}
				DebugDrawLine(ring[i], ring[next_idx], col_r, col_g, col_b, false, DRAW_TIME)
			}
		}
	}
}

function bm_trigger_vis_draw(players) {
	local DRAW_TIME = 2 * FrameTime()
	
	local is_any_player_in_any_bm_trig = false
	
	foreach(player in players) {
		local player_origin = player.GetOrigin()
		local player_bounding_mins = player.GetBoundingMins()
		local player_bounding_maxs = player.GetBoundingMaxs()
		local player_bbox_center = player.GetCenter()
		
		local is_player_crouching = player_bounding_maxs.z == PLAYER_AABB_HEIGHT_CROUCHING
		
		local is_player_triggering_accurately = false
		local is_player_bbox_touching_any_bm_bbox = false
		
		local bm = null
		while(bm = Entities.FindByClassname(bm, "bumpmine_projectile")) {
			if(bm.GetMoveParent() == null) // If bumpmine is not placed
				continue
			
			if(bm_trigger_accurate_check(bm, player)) {
				is_player_triggering_accurately = true
				is_any_player_in_any_bm_trig = true
			}
			
			local bm_origin = bm.GetOrigin()
			local bm_box_check_mins = bm_origin + (is_player_crouching ? BM_TRIG_MINS_CROUCHING : BM_TRIG_MINS_STANDING)
			local bm_box_check_maxs = bm_origin + (is_player_crouching ? BM_TRIG_MAXS_CROUCHING : BM_TRIG_MAXS_STANDING)
			
			local closest_trigger_pt = bm_trigger_vis_calc_closest_trigger_point(bm, player_bbox_center)
			
			// Check if player's bbox is touching the bumpmine's bbox
			if( player_bbox_center.x > bm_box_check_mins.x && player_bbox_center.x < bm_box_check_maxs.x &&
				player_bbox_center.y > bm_box_check_mins.y && player_bbox_center.y < bm_box_check_maxs.y &&
				player_bbox_center.z > bm_box_check_mins.z && player_bbox_center.z < bm_box_check_maxs.z) {
				is_player_bbox_touching_any_bm_bbox = true
			}
			
			// If player center point is inside the trigger volume
			if(closest_trigger_pt == null)
				continue
				
			local MAX_DRAW_DIST = 350
			local trigger_dist_sq = (closest_trigger_pt - player_bbox_center).LengthSqr()
			if(trigger_dist_sq < 0.5*MAX_DRAW_DIST*MAX_DRAW_DIST) { // If player is close enough to the trigger point
				local col = 255 * (1 - (trigger_dist_sq / (MAX_DRAW_DIST*MAX_DRAW_DIST)))
				DebugDrawLine(player_bbox_center, closest_trigger_pt, 0, col, col, true, DRAW_TIME)
				DebugDrawBox(closest_trigger_pt, Vector(-1,-1,-1), Vector(1,1,1), 0, col, col, 100, DRAW_TIME)
			}
		}
		
		if(is_player_triggering_accurately)
			DebugDrawBox(player_bbox_center, Vector(-1,-1,-1), Vector(1,1,1), 100, 255, 0, 100, DRAW_TIME)
		else
			DebugDrawBox(player_bbox_center, Vector(-1,-1,-1), Vector(1,1,1), 255, 100, 0, 100, DRAW_TIME)
		
		local center_col = is_player_bbox_touching_any_bm_bbox ? Vector(0,255,0) : Vector(255,0,0)
		DebugDrawLine(player_bbox_center - Vector(5,0,0), player_bbox_center + Vector(5,0,0), center_col.x, center_col.y, center_col.z, true, DRAW_TIME)
		DebugDrawLine(player_bbox_center - Vector(0,5,0), player_bbox_center + Vector(0,5,0), center_col.x, center_col.y, center_col.z, true, DRAW_TIME)
		DebugDrawLine(player_bbox_center - Vector(0,0,5), player_bbox_center + Vector(0,0,5), center_col.x, center_col.y, center_col.z, true, DRAW_TIME)
		
		// [RED] Draw bounding box, not oriented
		//DebugDrawBox(player_origin, player_bounding_mins, player_bounding_maxs, 255, 0, 0, 0, DRAW_TIME)
	}
	
	if(is_any_player_in_any_bm_trig) {
		BM_TRIG_PLAYER_IN_BM_TRIG_CNT++
		//printl("IN BM TRIGGER x" + BM_TRIG_PLAYER_IN_BM_TRIG_CNT)
		
		// Debug / Test code
		/*if(BM_TRIG_PLAYER_IN_BM_TRIG_CNT == 4) {
			local first_player = Entities.FindByClassname(null,"player")
			first_player.SetOrigin(first_player.GetOrigin() + Vector(0,0,200))
			BM_DEBUG_COUNTER++
			printl(BM_DEBUG_COUNTER)
		}*/
	} else {
		if(BM_TRIG_PLAYER_IN_BM_TRIG_CNT != 0) {
			//printl("NOT IN BM TRIGGER")
			BM_TRIG_PLAYER_IN_BM_TRIG_CNT = 0
		}
	}
	
	foreach(bm, x in BM_TRIG_VIS_TABLE_bm_ticks) {
		bm_trigger_vis_draw_bm(bm)
	}
}

function bm_trigger_vis_loop_tick()
{
	BM_TRIG_TICK_CNT++
	
	// Get players (in T or CT team)
	local players = []
	local ent_p = null, ent_b = null
	while(ent_p = Entities.FindByClassname(ent_p, "player")) if(bm_trigger_is_valid_player(ent_p)) players.push(ent_p)
	while(ent_b = Entities.FindByClassname(ent_b, "cs_bot")) if(bm_trigger_is_valid_player(ent_b)) players.push(ent_b)
	
	// Remove table slots of (old) invalid bumpmines or those that were freed from their parent
	local deletable_slots = []
	local killed_slots = []
	foreach(key, value in BM_TRIG_VIS_TABLE_bm_ticks) {
		if(!key.IsValid()) { // Bumpmines that were deleted or that detonated
			killed_slots.push(key)
			
			if(BM_TRIG_VIS_TABLE_bm_ticks_killed[key] == null) // If bm was killed just now
				BM_TRIG_VIS_TABLE_bm_ticks_killed[key] = BM_TRIG_VIS_TABLE_bm_ticks[key] // Remember the time when this bm was killed/detonated
			
		} else if(key.GetMoveParent() == null) { // Bumpmines that were freed from their parent, now falling
			deletable_slots.push(key)
		}
	}
	// Delete some of the oldest killed bumpmines, but keep some of the recent ones
	local too_old_bm_count = killed_slots.len() - BM_TRIG_HISTORY_CNT
	for(local i = 0; i < too_old_bm_count; i++) {
		local oldest_idx = null
		local oldest_ticks_since_kill = null // how many ticks ago a bm was killed
		for(local j = 0; j < killed_slots.len(); j++) {
			local curr_ticks_since_kill = BM_TRIG_VIS_TABLE_bm_ticks[killed_slots[j]] - BM_TRIG_VIS_TABLE_bm_ticks_killed[killed_slots[j]]
			if(oldest_idx == null || curr_ticks_since_kill > oldest_ticks_since_kill) {
				oldest_idx = j
				oldest_ticks_since_kill = curr_ticks_since_kill
			}
		}
		deletable_slots.append(killed_slots[oldest_idx])
		killed_slots.remove(oldest_idx)
	}
	// Delete table entries of unwanted bumpmines
	foreach(ds in deletable_slots)
		bm_trigger_vis_del_bm_table_entries(ds)
	
	// Increment tick count of every bm that we keep track of (even deleted ones), to remember its age
	foreach(bm, x in BM_TRIG_VIS_TABLE_bm_ticks)
		BM_TRIG_VIS_TABLE_bm_ticks[bm] += 1
	
	// Check if new bumpmines were placed
	local bm = null
	while(bm = Entities.FindByClassname(bm, "bumpmine_projectile")) {
		// Only continue if bumpmine exists and is placed on a surface or an entity
		if(!bm.IsValid() || bm.GetMoveParent() == null)
			continue
		
		// Add bumpmine to tables if it isn't yet
		if(!(bm in BM_TRIG_VIS_TABLE_bm_ticks)) {
			local bm_meshes = bm_trigger_vis_calc_bm_meshes(bm) // Bumpmine's individual trigger volume
			BM_TRIG_VIS_TABLE_bm_ticks[bm] <- 0
			BM_TRIG_VIS_TABLE_bm_ticks_killed[bm] <- null
			BM_TRIG_VIS_TABLE_bm_pos[bm] <- bm.GetOrigin()
			BM_TRIG_VIS_TABLE_bm_mesh[bm] <- bm_meshes
			BM_TRIG_VIS_TABLE_bm_triggered_prev[bm] <- false
			BM_TRIG_VIS_TABLE_bm_trig_cnt[bm] <- 0
			BM_TRIG_VIS_TABLE_bm_trig_pts[bm] <- []
			
			// Remove entries of nearby bm's that no longer exist
			local removable = []
			foreach(key, value in BM_TRIG_VIS_TABLE_bm_ticks) {
				if(key.IsValid()) continue
				if((BM_TRIG_VIS_TABLE_bm_pos[key] - bm.GetOrigin()).LengthSqr() > 200*200) continue
				removable.append(key)
			}
			foreach(bm in removable)
				bm_trigger_vis_del_bm_table_entries(bm)
		}
		
		
		// Do bumpmine trigger checking
		local bm_tick_age = BM_TRIG_VIS_TABLE_bm_ticks[bm]
		local is_bm_armed = bm_tick_age > BM_ARM_DELAY_TICKS - 1
		
		// Play arm and trigger check sounds
		if(!is_bm_armed) {
			// Play 3 "not armed" sounds (with default cvar values every ~0.1 sec)
			if(bm_tick_age == 0 || bm_tick_age == BM_ARM_DELAY_TICKS/3 || bm_tick_age == (2*BM_ARM_DELAY_TICKS)/3) {
				//bm_trigger_vis_run_server_command("play buttons/button22") // arming sound
			}
			// Draw arming visualization
			if(players.len() > 0)
				bm_trigger_vis_draw_progress_bar(players[0], bm.GetOrigin(), bm_tick_age, BM_ARM_DELAY_TICKS, Vector(255,0,0), 2*FrameTime())
		} else {
			if((bm_tick_age - BM_ARM_DELAY_TICKS) / BM_TRIG_CHECK_INTERVAL_TICKS < 3) { // Play "trigger check" sound at most 3 times
				
				if((bm_tick_age - BM_ARM_DELAY_TICKS) % BM_TRIG_CHECK_INTERVAL_TICKS == 0) {
					bm_trigger_vis_run_server_command("play buttons/button22")//ui/beep07") // trigger check sound
				
					// Draw trigger check visualization
					if(players.len() > 0)
						bm_trigger_vis_draw_progress_bar(players[0], bm.GetOrigin(), BM_ARM_DELAY_TICKS, BM_ARM_DELAY_TICKS, Vector(0,255,0), 2*FrameTime())
				} else {
					bm_trigger_vis_draw_progress_bar(players[0], bm.GetOrigin(), 0, BM_ARM_DELAY_TICKS, Vector(0,255,0), 2*FrameTime())
				}
			}
		}
		
		local triggered_curr = false // Is bumpmine being triggered in the current tick
		local closest_player = null, closest_player_dist_sqr = 1.e10
		foreach(p in players) {
			if(bm_trigger_accurate_check(bm, p)) {
				triggered_curr = true
				closest_player = p
				break
			}
			local p_dist_sqr = (p.GetOrigin() - bm.GetOrigin()).LengthSqr() // Just rough distance calculation
			if(p_dist_sqr < closest_player_dist_sqr) {
				closest_player = p
				closest_player_dist_sqr = p_dist_sqr
			}
		}
		
		if(triggered_curr) { // If bumpmine is triggered in this tick
			// Here the player triggered right after bm was armed, which triggers immediately,
			// 100% of the time -> Ignore this bumpmine
			//if(BM_TRIG_VIS_TABLE_bm_trig_cnt[bm] == -1)
			//	continue
			
			if(BM_TRIG_VIS_TABLE_bm_triggered_prev[bm] == false) { // If bumpmine was NOT triggered in last tick
				// Clear previous trigger count
				BM_TRIG_VIS_TABLE_bm_trig_cnt[bm] = 0
			}
			BM_TRIG_VIS_TABLE_bm_trig_cnt[bm] += 1
			
			// temp TEST CODE
			//if(BM_TRIG_VIS_TABLE_bm_trig_cnt[bm] >)
			//BM_TRIG_CHECK_INTERVAL_TICKS
			
		} else { // If bumpmine is NOT triggered in this tick
			// Here the player was outside the bm when it was armed -> set trigger count to zero
			//if(BM_TRIG_VIS_TABLE_bm_trig_cnt[bm] == -1)
			//	BM_TRIG_VIS_TABLE_bm_trig_cnt[bm] = 0
			
			if(BM_TRIG_VIS_TABLE_bm_triggered_prev[bm] == true) { // If bumpmine was triggered in last tick
				local msg = "\x01 \x04 Probability of triggering this bumpmine: "
				// + 0.0 to get float result
				local trigger_chance = 100 * BM_TRIG_VIS_TABLE_bm_trig_cnt[bm] / BM_TRIG_CHECK_INTERVAL_TICKS
				if(trigger_chance > 100) trigger_chance = 100
				msg += trigger_chance + "% "
				msg += "(" + BM_TRIG_VIS_TABLE_bm_trig_cnt[bm] + "/" + BM_TRIG_CHECK_INTERVAL_TICKS + " ticks)"
				ScriptPrintMessageChatAll(msg)
			}
		}
		
		// Start saving player positions once close enough
		if(closest_player != null && BM_TRIG_VIS_TABLE_bm_trig_pts[bm].len() < BM_TRIG_TRAJECTORY_MAX_SIZE) {
			// Get center point of player's bbox
			local cl_p = closest_player
			local cl_p_pos = cl_p.GetCenter()
			if((cl_p_pos - bm.GetOrigin()).LengthSqr() < BM_TRIG_TRAJECTORY_DIST_SQR) {
				local pt_color = null
				if(!is_bm_armed)
					pt_color = Vector(255,0,0)
				else if((bm_tick_age - BM_ARM_DELAY_TICKS) % BM_TRIG_CHECK_INTERVAL_TICKS == 0)
					pt_color = Vector(0,255,0)
				else
					pt_color = Vector(255,255,255)
				if(!triggered_curr)
					pt_color *= 0.4
				BM_TRIG_VIS_TABLE_bm_trig_pts[bm].append([cl_p_pos, pt_color])
			}
		}
		
		// Remember for the next tick, if bm was triggered in this tick
		BM_TRIG_VIS_TABLE_bm_triggered_prev[bm] = triggered_curr
	}
	
	// Update trigger mesh of bumpmines that are not placed on a static parent (in case bm was moved)
	if(BM_TRIG_TICK_CNT % BM_TRIG_TICKS_PER_UPDATE == 0) {
		foreach(key, value in BM_TRIG_VIS_TABLE_bm_ticks) {
			if(!key.IsValid() || key.GetMoveParent().GetClassname() == "worldspawn")
				continue
			local updated_bm_meshes = bm_trigger_vis_calc_bm_meshes(key)
			BM_TRIG_VIS_TABLE_bm_mesh[key] <- updated_bm_meshes
		}
	}
	// Draw!
	bm_trigger_vis_draw(players)
}

function bm_trigger_vis_create_relay()
{
	local relay = Entities.FindByName(null, BM_TRIG_VIS_LOGIC_RELAY_NAME )
	local has_old_relay_existed = relay != null
	if(!has_old_relay_existed) {
		relay = Entities.CreateByClassname( "logic_relay" )
		relay.__KeyValueFromString( "targetname", BM_TRIG_VIS_LOGIC_RELAY_NAME )
		relay.__KeyValueFromInt( "spawnflags", 2 ) // 2 -> Allow fast retrigger, don't trigger only once
		
		// Let relay trigger every tick
		local tickLength = FrameTime()
		// target name, input name, parameter, delay, max times to fire (-1 = infinity)
		local targetParams = BM_TRIG_VIS_LOGIC_RELAY_NAME + ":Trigger::" + tickLength + ":-1"	
		EntFireByHandle( relay, "AddOutput", "OnTrigger " + targetParams, 0, null, null )
	}
	
	relay.ValidateScriptScope()
	relay.GetScriptScope().OnTrigger <- bm_trigger_vis_loop_tick // Add a reference to the function
	
	if(!has_old_relay_existed) {
		relay.ConnectOutput( "OnTrigger", "OnTrigger" ) // On each OnTrigger output, execute the function
		EntFireByHandle( relay, "Trigger", "", 0.2, null, null ) // Start trigger loop
	}
}

function bm_trigger_vis_init() {
	bm_trigger_vis_create_relay()
}

bm_trigger_vis_init()
