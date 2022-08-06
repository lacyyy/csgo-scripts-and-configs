/////////////////////////////////////////////////////////////////////////////////////////////////////
// Purpose: I used this to reverse engineer the areas in which a player triggers a Bump Mine.
//          This script displays a scan file created by the dzsim_bm_trigger_area_scan.nut script.
//          I only made this for my own usage, so it's not well explained and you can't just run it.
//
// Made by lacyyy:
//   https://github.com/lacyyy
//   https://steamcommunity.com/profiles/76561198162669616
//
/////////////////////////////////////////////////////////////////////////////////////////////////////

const DRAW_TICK_COUNT = 20

TICKS_SINCE_LAST_DRAW <- 0

printl("")
printl("")
printl("---- DZSim Test Script: Bumpmine Trigger Area Display")


SendToConsole("sv_cheats 1")
SendToConsole("sv_infinite_ammo 1")
SendToConsole("sv_gravity 800")
SendToConsole("mp_warmup_pausetimer 1")
SendToConsole("fps_max 120")
SendToConsole("sv_regeneration_force_on 1")
SendToConsole("bot_stop 1")
SendToConsole("bot_mimic 0")
SendToConsole("bot_kick")
SendToConsole("bot_quota 1")
SendToConsole("bot_quota_mode normal")

SendToConsole("developer 1")

if(Entities.FindByClassname(null, "weapon_bumpmine") == null) {
	SendToConsole("give weapon_bumpmine")
}

// Display entity angles
// ent_pivot bumpmine_projectile

// Display eye position:
// ent_viewoffset bumpmine_projectile

function dzsim_bm_calc_ellipsoid_surf_points(offset) {
	local VERT_STEP_ANGLE = 3 // in degrees
	local HORI_STEP_ANGLE = 10 // in degrees
	// Convert to radians
	VERT_STEP_ANGLE *= PI / 180
	HORI_STEP_ANGLE *= PI / 180
	// Bumpmine ellipsoid properties
	local ELL_VERT_SEMI_DIAMETER = 138.11 / 2
	local ELL_HORI_SEMI_DIAMETER =  93.62 / 2
	
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

function dzsim_bm_draw() {
	local DRAW_TIME = FrameTime() * (DRAW_TICK_COUNT + 2)
	local HIT_RING_SCANS = [
		//bm_scan_90p0y0r_crouching_5step_8639,
		//bm_scan_90p90y0r_standing_10step_1838,
		//bm_scan_90p45y0r_standing_10step_9524,
		//bm_scan_45p0y0r_standing_5step_5591,
		//bm_scan_90p22y0r_standing_10step_5896,
		//bm_scan_90p11y0r_standing_5x5y10z_4994,
		bm_scan_0p0y0r_standing_10step_2675,
		//bm_scan_0p0y0r_crouching_10step_9711,
		
		//bm_scan_0p0y0r_standing_10x10y3z_5424,
		//bm_scan_0p0y0r_crouching_10x10y3z_5722,
		
		//bm_scan_30p0y0r_standing_2x2y1z_1387,
		//bm_scan_0p0y0r_standing_1x2y2z_9401,
		//bm_scan_0p0y0r_standing_0x0y0z_2230,
		//bm_scan_0p0y0r_standing_0x0y1z_5274,
		//bm_scan_0p0y0r_standing_0x0y0z_7208,
		//bm_scan_0p0y0r_standing_0x0y0z_8267,
		//bm_scan_0p0y0r_standing_0x0y0z_4496,
		
		//ELLIPSOID_RINGS,
		
		//BM_SCAN_HIT_RINGS_2575,
		//BM_SCAN_HIT_RINGS_9960,
		//bm_scan_boost_0p0y0r_standing_10x10y10z_4565,
		//bm_scan_boost_0p0y0r_crouching_20x20y10z_4456,
		//bm_scan_boost_20p40y0r_standing_20x20y10z_3767,
		//bm_scan_boost_90p0y0r_standing_20x20y10z_2734,
	]
	
	// Add ellipsoid debug lines to rings
	local ellipsoidDebugRings = []
	// Top ellipsoid peak lines
	ellipsoidDebugRings.push([Vector(0,-50,120.47),Vector(0,50,120.47)])
	ellipsoidDebugRings.push([Vector(-50,0,120.47),Vector(50,0,120.47)])
	// Top ellipsoid center lines
	ellipsoidDebugRings.push([Vector(0,-50,51.415),Vector(0,50,51.415)])
	ellipsoidDebugRings.push([Vector(-50,0,51.415),Vector(50,0,51.415)])
	// Top ellipsoid bottom lines
	ellipsoidDebugRings.push([Vector(0,-50,-17.64),Vector(0,50,-17.64)])
	ellipsoidDebugRings.push([Vector(-50,0,-17.64),Vector(50,0,-17.64)])
	// Bottom ellipsoid peak lines
	ellipsoidDebugRings.push([Vector(0,-50,17.64),Vector(0,50,17.64)])
	ellipsoidDebugRings.push([Vector(-50,0,17.64),Vector(50,0,17.64)])
	// Bottom ellipsoid center lines
	ellipsoidDebugRings.push([Vector(0,-50,-51.415),Vector(0,50,-51.415)])
	ellipsoidDebugRings.push([Vector(-50,0,-51.415),Vector(50,0,-51.415)])
	// Bottom ellipsoid bottom lines
	ellipsoidDebugRings.push([Vector(0,-50,-120.47),Vector(0,50,-120.47)])
	ellipsoidDebugRings.push([Vector(-50,0,-120.47),Vector(50,0,-120.47)])
	HIT_RING_SCANS.push(ellipsoidDebugRings)
	
	

	local PLAYER_FEET_LEVEL = 0.031250
	local BM_SURF_DISTANCE = 0.7312 // Bumpmine origin is slightly distanced from the surface it was placed on
	
	////////////////////////////
	
	local player = null
	while(player = Entities.FindByClassname(player, "player")) {
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
		
		DebugDrawLine(player_bbox_center - Vector(5,0,0), player_bbox_center + Vector(5,0,0), 255, 255, 255, true, DRAW_TIME)
		DebugDrawLine(player_bbox_center - Vector(0,5,0), player_bbox_center + Vector(0,5,0), 255, 255, 255, true, DRAW_TIME)
		DebugDrawLine(player_bbox_center - Vector(0,0,5), player_bbox_center + Vector(0,0,5), 255, 255, 255, true, DRAW_TIME)
		
		// [RED] Draw bounding box, not oriented
		DebugDrawBox(player_origin, player_bounding_mins, player_bounding_maxs, 255, 0, 0, 0, DRAW_TIME)
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
		
		//printl("GetMoveParent()     = " + ent.GetMoveParent())     // (null : 0x00000000) when falling or ([0] worldspawn) when fixed
		//printl("GetRootMoveParent() = " + ent.GetRootMoveParent()) // ([97] bumpmine_projectile) when falling or ([0] worldspawn) when fixed
		
		// [DARK BLUE] Draw origin
		DebugDrawLine(origin - Vector(5,0,0), origin + Vector(5,0,0), 0, 0, 255, true, DRAW_TIME)
		DebugDrawLine(origin - Vector(0,5,0), origin + Vector(0,5,0), 0, 0, 255, true, DRAW_TIME)
		DebugDrawLine(origin - Vector(0,0,5), origin + Vector(0,0,5), 0, 0, 255, true, DRAW_TIME)
		
		// [GREEN] Draw bumpmine aabb
		local bm_aabb = Vector(81,81,81)
		DebugDrawBox(origin, bm_aabb * -1, bm_aabb, 0, 255, 0, 0, DRAW_TIME)
		
		local pitch_s = sin((-angles.x) * (PI / 180))
		local pitch_c = cos((-angles.x) * (PI / 180))
		local yaw_s   = sin(angles.y * (PI / 180))
		local yaw_c   = cos(angles.y * (PI / 180))
		local roll_s  = sin(angles.z * (PI / 180))
		local roll_c  = cos(angles.z * (PI / 180))
		
		local volume_colors = [
			[  0,255,127], // lime?
			[  0,255,255], // cyan
			[  0,127,255], // aqua
			[  0,  0,255], // blue
			[255,  0,  0], // red
			[255,127,  0], // orange
			[255,255,  0], // yellow
		]
		
		foreach(scan_idx,ring_scan in HIT_RING_SCANS) {
			local color_idx = scan_idx % volume_colors.len()
			local volume_color = volume_colors[color_idx]
			local col_r = volume_color[0]
			local col_g = volume_color[1]
			local col_b = volume_color[2]
			
			foreach(ring in ring_scan) {
				local rotated_ring = []
				foreach(point in ring) {
					local new_point = Vector(point.x, point.y, point.z + 0.1*scan_idx)
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
				
				// Draw rotated ring!
				for(local i = 0; i < rotated_ring.len(); i++) {
					local next_idx = i + 1
					if(next_idx == rotated_ring.len()) {
						next_idx = 0
					}
					DebugDrawLine(rotated_ring[i], rotated_ring[next_idx], col_r, col_g, col_b, false, DRAW_TIME)
				}
				//col_b += 40
				//col_r -= 40
			}
		}
	}
	
	////////////////////////////
	
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
	
	////local PLAYER_FEET_LEVEL = 0.031250
	////
	////local BM_SURF_DISTANCE = 0.7312 // Bumpmine origin is slightly distanced from the surface it was placed on
	////
	////// difference between bump.origin.z and player.origin.z, determined from bump on flat ground
	////local BM_HITCYLINDER_HEIGHT_UP = 81.03125
	////
	////local BM_HITCYLIN_BASE_RADIUS = 43.5 // testing shows it's: 43 < x < 44
	////local BM_HITCYLIN_TOP_RADIUS = 43.5//27 // testing shows it's: 25 < x < 30
	////
	////////////////////////////////
	////
	////local player = Entities.FindByClassname(null, "player")
	////local player_origin = player.GetOrigin()
	////printl("-- player")
	////printl("GetOrigin() = " + player_origin)
	////printl("GetBoundingMins() = " + player.GetBoundingMins())
	////printl("GetBoundingMaxs() = " + player.GetBoundingMaxs())
	//////printl("GetBoundingMinsOriented() = " + player.GetBoundingMinsOriented()) // player turning angle should be irrelevant
	//////printl("GetBoundingMaxsOriented() = " + player.GetBoundingMaxsOriented()) // player turning angle should be irrelevant
	////
	////DebugDrawLine(player_origin - Vector(5,0,0), player_origin + Vector(5,0,0), 255, 255, 255, true, DRAW_TIME)
	////DebugDrawLine(player_origin - Vector(0,5,0), player_origin + Vector(0,5,0), 255, 255, 255, true, DRAW_TIME)
	////DebugDrawLine(player_origin - Vector(0,0,5), player_origin + Vector(0,0,5), 255, 255, 255, true, DRAW_TIME)
	////
	////
	////local ent = null
	////while(ent = Entities.FindByClassname(ent, "bumpmine_projectile")) {
	////	local origin = ent.GetOrigin()
	////	local angles = ent.GetAngles()
	////	local velocity = ent.GetVelocity()
	////	
	////	local bounding_mins = ent.GetBoundingMins()
	////	local bounding_maxs = ent.GetBoundingMaxs()
	////	local bounding_mins_oriented = ent.GetBoundingMinsOriented()
	////	local bounding_maxs_oriented = ent.GetBoundingMaxsOriented()
	////	
	////	local up_vector = ent.GetUpVector()
	////	local forward_vector = ent.GetForwardVector()
	////	local left_vector = ent.GetLeftVector()
	////	
	////
	////	printl("-- bumpmine_projectile");
	////	printl("GetOrigin() = " + origin)
	////	printl("GetAngles() = " + angles)
	////	
	////	printl("GetVelocity() = " + velocity)
	////	printl("GetAngularVelocity() = " + ent.GetAngularVelocity())
	////	
	////	local z_diff = player_origin.z - origin.z
	////	printl("z diff to player = " + z_diff)
	////	//rintl("GetBoundingMins() = " + bounding_mins)
	////	//printl("GetBoundingMaxs() = " + bounding_maxs)
	////	//printl("GetBoundingMinsOriented() = " + bounding_mins_oriented)
	////	//printl("GetBoundingMaxsOriented() = " + bounding_maxs_oriented)
	////	
	////	//printl("GetUpVector() = " + up_vector)
	////	//printl("GetForwardVector() = " + forward_vector)
	////	//printl("GetLeftVector() = " + left_vector)
	////	
	////	
	////	//printl("GetMoveParent()     = " + ent.GetMoveParent())     // (null : 0x00000000) when falling or ([0] worldspawn) when fixed
	////	//printl("GetRootMoveParent() = " + ent.GetRootMoveParent()) // ([97] bumpmine_projectile) when falling or ([0] worldspawn) when fixed
	////	
	////	
	////	
	////	// [DARK BLUE] Draw origin
	////	DebugDrawLine(origin - Vector(5,0,0), origin + Vector(5,0,0), 0, 0, 255, true, DRAW_TIME)
	////	DebugDrawLine(origin - Vector(0,5,0), origin + Vector(0,5,0), 0, 0, 255, true, DRAW_TIME)
	////	DebugDrawLine(origin - Vector(0,0,5), origin + Vector(0,0,5), 0, 0, 255, true, DRAW_TIME)
	////	
	////	// [PINK] Draw bounding box, not oriented
	////	//DebugDrawBox(ent.GetOrigin(), bounding_mins, bounding_maxs, 255, 0, 255, 0, DRAW_TIME)
	////	// [DARK PURPLE] Draw bounding box, oriented mins maxs
	////	//DebugDrawBox(ent.GetOrigin(), bounding_mins_oriented, bounding_maxs_oriented, 127, 0, 255, 30, DRAW_TIME)
	////	
	////	// [GREEN] Draw bounding box, oriented
	////	DebugDrawBoxAngles(ent.GetOrigin(), bounding_mins, bounding_maxs, angles, 0, 200, 0, 20, DRAW_TIME)
	////	
	////	// [YELLOW] Draw velocity
	////	//DebugDrawLine(origin, origin + velocity * 0.1, 255, 255, 0, true, DRAW_TIME)
	////	
	////	// [ORANGE] Draw up vector
	////	DebugDrawLine(origin, origin + up_vector * 20, 255, 120, 0, true, DRAW_TIME)
	////	// [RED] Draw left/forward vector
	////	DebugDrawLine(origin, origin + forward_vector * 20, 255, 0, 0, true, DRAW_TIME)
	////	DebugDrawLine(origin, origin + left_vector    * 20, 255, 0, 0, true, DRAW_TIME)
	////	
	////	// [AQUA] Draw hitcircle
	////	local circle_pt_count = 0
	////	local basecircle_points = []
	////	local topcircle_points = []
	////	for(local i = 0; i < 2 * PI; i += PI / 16) {
	////		local s = sin(i)
	////		local c = cos(i)
	////		basecircle_points.append(Vector(s * BM_HITCYLIN_BASE_RADIUS, c * BM_HITCYLIN_BASE_RADIUS, 0))
	////		topcircle_points .append(Vector(s * BM_HITCYLIN_TOP_RADIUS , c * BM_HITCYLIN_TOP_RADIUS , BM_HITCYLINDER_HEIGHT_UP))
	////		circle_pt_count++
	////	}
	////	
	////	local pitch_s = sin((-angles.x) * (PI / 180))
	////	local pitch_c = cos((-angles.x) * (PI / 180))
	////	local yaw_s   = sin(angles.y * (PI / 180))
	////	local yaw_c   = cos(angles.y * (PI / 180))
	////	local roll_s  = sin(angles.z * (PI / 180))
	////	local roll_c  = cos(angles.z * (PI / 180))
	////	
	////	local pt_lists = [basecircle_points, topcircle_points]
	////	foreach(pt_list in pt_lists) {
	////		for(local i = 0; i < pt_list.len(); i++) {
	////			local pt = pt_list[i]
	////			// Order of axis rotations is important! First roll, then pitch, then yaw rotation!
	////			// (roll)  rotation around x axis
	////			local r_newY = pt.y * roll_c - pt.z * roll_s
	////			local r_newZ = pt.y * roll_s + pt.z * roll_c
	////			pt.y = r_newY
	////			pt.z = r_newZ
	////			// (pitch) rotation around y axis
	////			local p_newX = pt.x * pitch_c - pt.z * pitch_s
	////			local p_newZ = pt.x * pitch_s + pt.z * pitch_c
	////			pt.x = p_newX
	////			pt.z = p_newZ
	////			// (yaw)   rotation around z axis
	////			local y_newX = pt.x * yaw_c - pt.y * yaw_s
	////			local y_newY = pt.x * yaw_s + pt.y * yaw_c
	////			pt.x = y_newX
	////			pt.y = y_newY
	////			
	////			// Translate to bumpmine origin
	////			pt += origin
	////			
	////			pt_list[i] = pt
	////		}
	////	}
	////	
	////	local hitbody_r = 0
	////	local hitbody_g = 255
	////	local hitbody_b = 255
	////	
	////	for(local i = 0; i < circle_pt_count; i++) {
	////		local pt_idx = i
	////		local pt_idx_next = i+1
	////		if(pt_idx_next == circle_pt_count)
	////			pt_idx_next = 0
	////		
	////		// Draw base circle
	////		DebugDrawLine(basecircle_points[pt_idx], basecircle_points[pt_idx_next], hitbody_r, hitbody_g, hitbody_b, false, DRAW_TIME)
	////		// Draw top circle
	////		DebugDrawLine(topcircle_points[pt_idx], topcircle_points[pt_idx_next], hitbody_r, hitbody_g, hitbody_b, false, DRAW_TIME)
	////		// Connect base and top circle
	////		DebugDrawLine(basecircle_points[pt_idx], topcircle_points[pt_idx], hitbody_r, hitbody_g, hitbody_b, false, DRAW_TIME)
	////	}
	////	
	////	
	////	// ent_fire bumpmine_projectile RunScriptCode "self.SetVelocity(Vector(0,0,0));self.SetAngles(0,0,0);self.SetAngularVelocity(0,0,0);"
	////	
	////	// [AQUA] Draw hitbox, not oriented
	////	//local HITBOX_SIZE = 16 //  > x < 30
	////	//DebugDrawBox(ent.GetOrigin(), Vector(-HITBOX_SIZE,-HITBOX_SIZE,-HITBOX_SIZE), Vector(HITBOX_SIZE,HITBOX_SIZE,HITBOX_SIZE), 0, 255, 255, 0, DRAW_TIME)
	////	
	////	//DebugDrawBox(ent.GetOrigin(), Vector(-20,-20,-20), Vector(20,20,20), 0, 255, 255, 1.0, DRAW_TIME)
	////	//DebugDrawBoxAngles(ent.GetOrigin(), Vector(-20,-20,-20), Vector(20,20,20), Vector(0,0,45), 0, 255, 255, 1.0, DRAW_TIME)
	////	
	////	// float TraceLine(Vector start, Vector end, handle ignore)
	////	// float TraceLinePlayersIncluded(Vector start, Vector end, handle ignore)
	////}
}

function dzsim_bm_loop_tick()
{
	if(TICKS_SINCE_LAST_DRAW >= DRAW_TICK_COUNT) {
		TICKS_SINCE_LAST_DRAW = 0
		dzsim_bm_draw()
	} else {
		TICKS_SINCE_LAST_DRAW++
	}
	//SendToConsole("script dzsim_bm()")
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

function dzsim_bm() {
	dzsim_bm_create_relay()
	
	local ELLIPSOID_Z_OFFSET = 51.415
	ELLIPSOID_RINGS <- dzsim_bm_calc_ellipsoid_surf_points(Vector(0,0,ELLIPSOID_Z_OFFSET))
	local bottom_ellipsoid = []
	foreach(ring in ELLIPSOID_RINGS) {
		local new_ring = []
		foreach(pt in ring) {
			new_ring.push(Vector(pt.x, pt.y, pt.z - 2 * ELLIPSOID_Z_OFFSET))
		}
		bottom_ellipsoid.push(new_ring)
	}
	ELLIPSOID_RINGS.extend(bottom_ellipsoid)
	
	
	//IncludeScript("bm_scan_90p0y0r_crouching_5step_8639")
	//IncludeScript("bm_scan_45p0y0r_standing_5step_5591")
	//IncludeScript("bm_scan_90p90y0r_standing_10step_1838")
	//IncludeScript("bm_scan_90p45y0r_standing_10step_9524")
	//IncludeScript("bm_scan_90p22y0r_standing_10step_5896")
	//IncludeScript("bm_scan_90p11y0r_standing_5x5y10z_4994")
	IncludeScript("bm_scan_0p0y0r_standing_10step_2675")
	//IncludeScript("bm_scan_0p0y0r_crouching_10step_9711")
	//IncludeScript("bm_scan_0p0y0r_standing_10x10y3z_5424")
	//IncludeScript("bm_scan_0p0y0r_crouching_10x10y3z_5722")
	//IncludeScript("bm_scan_30p0y0r_standing_2x2y1z_1387") // only top of elipsoid scan
	//IncludeScript("bm_scan_0p0y0r_standing_1x2y2z_9401") // only middle of top elipsoid scan
	//IncludeScript("bm_scan_0p0y0r_standing_0x0y0z_2230") // only middle of top elipsoid scan
	//IncludeScript("bm_scan_0p0y0r_standing_0x0y1z_5274") // only mid-bottom layer of top ellipsoid scan
	//IncludeScript("bm_scan_0p0y0r_standing_0x0y0z_7208") // only mid-top layer of top ellipsoid scan
	//IncludeScript("bm_scan_0p0y0r_standing_0x0y0z_8267") // only mid-top layer of top ellipsoid scan
	//IncludeScript("bm_scan_0p0y0r_standing_0x0y0z_4496") // only mid layer of top ellipsoid scan
	//IncludeScript("bm_scan_boost_0p0y0r_standing_10x10y10z_4565")
	//IncludeScript("bm_scan_boost_0p0y0r_crouching_20x20y10z_4456")
	//IncludeScript("bm_scan_boost_20p40y0r_standing_20x20y10z_3767")
	//IncludeScript("bm_scan_boost_90p0y0r_standing_20x20y10z_2734")
	//IncludeScript("")
	//IncludeScript("")
	//IncludeScript("")
	//IncludeScript("")
	//IncludeScript("")
	//IncludeScript("")
	
	
}


dzsim_bm()