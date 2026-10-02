extends RefCounted
## Valkyrie story flights. The original builds a story cast and radio once when
## a location is entered at a story cursor. The story then moves on silently
## after 10 s in space at the target station (kind 156) or at any other station
## (kind 160); the cast and radio keep running. Combat flights (kind 4) are
## built only at their target station and move on once their objective ships
## are destroyed. Read from the Mac mission factory, radio factory and level
## script.
const Campaign=preload("res://src/content/valkyrie_campaign_definitions.gd")
const Wanted=preload("res://src/simulation/wanted_board.gd")
const FLIGHT_KINDS:=[1,4,6,10,156,160,163,164]
const ADVANCE_AFTER_MS:=10000
## Supernova's people-moving flights (kind 184) are scripted flights at their
## target station.
const STORY_FLIGHT_KINDS:=[184,170,174,168]
## Scripted flights whose result conversation plays in flight (over the radio,
## after the recipe's own lines); the lines live in the dialogue RESULT table.
const IN_FLIGHT_RESULTS:=[95,97,99,102,109,114,119,125,126,133,135]
## [speaker, text, voice, condition, value]: 5 = after the level time,
## 6 = after the given earlier line.
const RADIO:={
	49:[[0,2109,1469,5,8000]],
	50:[[63,2110,1470,5,8000],[0,2111,1471,6,0],[63,2112,1472,6,1],[0,2113,1473,6,2]],
	51:[[63,2114,1474,5,8000],[0,2115,1475,6,0]],
	52:[[63,2116,1476,5,8000],[0,2117,1477,6,0]],
	63:[[0,2212,1488,5,8000],[0,2213,1489,6,0]],
	56:[[27,2143,1481,5,8000],[0,2144,1482,6,0],[28,2145,1483,16,0],[0,2146,1484,20,3],[0,2147,1485,6,3],[27,2148,1486,28,0]],
}
## Condition 16 = a non-friendly ship is awake, 20 = ships destroyed,
## 28 = the player's armour is gone. Combat flights play their result lines
## over the radio once the objective ships are gone (assumption: the original
## shows them as its in-flight result conversation).
const RESULT_RADIO:={94:[[0,2537,1605],[37,2538,1606],[0,2539,1607],[37,2540,1608],[0,2541,1609],[37,2542,1610],[0,2543,1611]],
	92:[[0,2512,1587],[2,2513,1588],[0,2514,1589],[2,2515,1590],[0,2516,1591],[2,2517,1592],[0,2518,1593]],80:[[0,2415,1391],[6,2416,1392],[0,2417,1393],[6,2418,1394],[0,2419,1395],[6,2420,1396]],56:[[27,2149,1206],[0,2150,1207]],63:[[28,2215,1260],[0,2216,1261]],
	64:[[0,2224,1262],[20,2225,1263],[0,2226,1264],[20,2227,1265],[0,2228,1266]],
	67:[[0,2288,1296],[20,2289,1297],[0,2290,1298],[20,2291,1299],[0,2292,1300],[20,2293,1301],[0,2294,1302],[0,2295,1303]],
	70:[[0,2313,1314]],
	73:[[0,2344,1337],[33,2345,1338],[0,2346,1339],[33,2347,1340],[0,2348,1341],[33,2349,1342],[0,2350,1343],[33,2351,1344],[0,2352,1345]],
	142:[[0,2946,1925],[2,2947,1926],[0,2948,1927],[2,2949,1928],[0,2950,1929]],
	145:[[6,2964,1936]],
	154:[[0,3040,1984],[26,3041,1985],[0,3042,1986],[56,3043,1987],[0,3044,1988],[26,3045,1989],[56,3046,1990],[0,3047,1991],[26,3048,1992],[56,3049,1993],[0,3050,1994],[26,3051,1995],[0,3052,1996],[56,3053,1997],[55,3054,1998],[0,3055,1999]],
	158:[[0,3094,2010],[1,3095,2011],[0,3096,2012],[1,3097,2013],[0,3098,2014]],
	160:[[6,3111,2026],[17,3112,2027],[6,3113,2028]],
	161:[[4,3115,2029],[0,3116,2030],[38,3117,2031],[0,3118,2032],[38,3119,2033],[40,3120,2034]]}
## [count, faction, hull, hostile]. All Vossk (faction 1); hull 13 is their
## large ship, built as the Vossk freighter-class assembly (subtype 1).
const CASTS:={
	49:[[5,1,9,false]],
	50:[[4,1,9,false]],
	51:[[1,1,13,true],[5,1,9,true]],
	52:[[2,1,13,true],[6,1,9,true]],
}
const LARGE_HULL:=13
## Combat flights: waypoints in world units, then groups of
## [count, faction, hull (-1 = the faction's random fighter), role, waypoint].
## Escorts start asleep beside the player with near-infinite hull and fly the
## waypoints; targets sleep at a waypoint until the player comes near.
const COMBAT:={
	56:{"points":[Vector3(0,0,-60000),Vector3(-12000,-7000,-110000),Vector3(15000,3000,-160000)],
		"groups":[[3,8,24,"escort",0],[2,8,-1,"target",0],[4,8,-1,"target",1]]},
	# 63: six sleeping pirates -10..+30 km per axis around the outpost at the
	# origin; three destroyed is enough, then the rest give up their guns.
	# Line 2214 is never shown by the original (its trigger never holds).
	# The outpost sits at the origin +-10 km; it does not count toward the three.
	63:{"points":[Vector3.ZERO],"static":{"model":14243,"name_text_id":430,"jitter":10000},"groups":[[6,8,-1,"target",0]],"scatter":[-10000,40000],"success_count":3,"disarm":true},
}
const ESCORT_HULL:=9999999
## Scripted flights (kind 4) with their own cast, radio [speaker, text, voice,
## condition, values] and success. 64: Khador's prototype (race 0, hull 38)
## flies from the origin toward +x escorted by eight awake pirates. The pirates
## give up at "Fall back!" and the flight succeeds once "Cowards!" is over.
## Assumptions: Khador's ship cannot be destroyed (the original fails the
## mission then; no in-flight failure screen yet), the player is not moved
## 40 km back, the cutscene cameras and the pirates' flight away are not built,
## and the result lines play over the radio instead of opening a dialogue.
const SCRIPTED:={
	# Talk arrivals ("talk_arrival"): in space at the talk's station the lines
	# play and the story stays put; docking still holds the talk.
	# 62: Keith at Kothar, no cast.
	62:{"points":[Vector3.ZERO],"groups":[],"radio":[[0,2198,1487,5,[8000]]],"success":{"kind":"never"},"talk_arrival":true},
	# 65: Khador's Typhon (unkillable) 3 km to the player's side. Assumptions:
	# on the world -x side, and it waits there instead of flying to the station.
	65:{"points":[Vector3.ZERO],"groups":[{"count":1,"faction":0,"hull":38,"friendly":true,"hull_override":ESCORT_HULL,"name_text_id":1606,
			"position":{"kind":"player_offset","offset":Vector3(-3000,0,0),"bound":Vector3(1,1,1)}}],
		"radio":[[0,2240,1498,5,[12000]],[20,2241,1499,6,[0]],[0,2242,1500,6,[1]]],"success":{"kind":"never"},"talk_arrival":true},
	# 119: cutaway at Thynome (N1): caption at 2 s, the result 2 s after it ends,
	# then the story moves on (MOVE_ON_ENTRY 120).
	119:{"points":[Vector3.ZERO],"groups":[],"radio":[[17,2734,-1,5,[2000]]],
		"timed_actions":[{"after_ms":0,"action":"cutaway"}],"result_after":[35,[0,2000,1]],
		"success":{"kind":"radio_finished","index":11}},
	# 126: cutaway at Katashán (N1): caption at 2 s, the result 2 s after it ends,
	# then the story moves on (MOVE_ON_ENTRY 127).
	126:{"points":[Vector3.ZERO],"groups":[],"radio":[[17,2817,-1,5,[2000]]],
		"timed_actions":[{"after_ms":0,"action":"cutaway"}],"result_after":[35,[0,2000,1]],
		"success":{"kind":"radio_finished","index":6}},
	# 133: cutaway at Katashán (N1): caption at 2 s, the result 2 s after it ends,
	# then the story moves on (MOVE_ON_ENTRY 134).
	133:{"points":[Vector3.ZERO],"groups":[],"radio":[[17,2856,-1,5,[2000]]],
		"timed_actions":[{"after_ms":0,"action":"cutaway"}],"result_after":[35,[0,2000,1]],
		"success":{"kind":"radio_finished","index":3}},
	# 120: Valadon. Two stealth fighters (race 10, hull 44, hostile) appear
	# beside the player, one 4 km ahead and one 4 km behind; Keith at 1.5 s;
	# done when his line is over (the fight is optional; they stay).
	# Assumption: the sideways part of their offset (not recovered) is 0.
	120:{"points":[Vector3(0,0,-80000)],
		"groups":[{"count":1,"faction":10,"hull":44,"friendly":false,"position":{"kind":"player_offset","offset":Vector3(0,0,4000),"bound":Vector3.ZERO}},
			{"count":1,"faction":10,"hull":44,"friendly":false,"position":{"kind":"player_offset","offset":Vector3(0,0,-4000),"bound":Vector3.ZERO}}],
		"radio":[[0,2746,2121,5,[1500]]],
		"success":{"kind":"radio_finished","index":0}},
	# 123: Névan clearance. No cast; security at 8 s, Moonsprocket, security,
	# Keith; done when Keith's line is over.
	123:{"points":[Vector3.ZERO],"groups":[],
		"radio":[[22,2774,2122,5,[8000]],[38,2775,2123,6,[0]],[22,2776,2124,6,[1]],[0,2777,2125,6,[2]]],
		"success":{"kind":"radio_finished","index":3}},
	# 125: Kappa, the freighter's black box. #0-#1 pirates awake at the
	# origin; #2-#7 pirates hidden and asleep; #8-#10 Secure Containers
	# (18785, hacking docks, off until the site is reached); #11-#14 debris.
	# Line #1 gives the player a course to (-70000,0,-130000) (action route);
	# reaching it (52) names the containers and plays #2. After #2: #2-#5
	# appear 1-2 km around the player, 7 s scene (#3); then they attack and
	# the containers can be hacked (#4). Each won hack (50): #5 black box,
	# #6 nothing (and #6-#7 appear and attack), #7 "Bingo!". Then Brent's
	# result over the radio; the story moves on (Katashán launch, 126).
	# Assumptions: the debris spread (random in the original) is fixed.
	125:{"points":[Vector3.ZERO,Vector3(-70000,0,-130000)],
		"groups":[{"count":2,"faction":8,"hull":-1,"friendly":false,"index":0,"offsets":[-1500,-1500,-1500],"bounds":[3000,3000,3000]},
			{"count":6,"faction":8,"hull":-1,"friendly":false,"sleeping":true,"hidden":true,"index":0,"offsets":[-1500,-1500,-1500],"bounds":[3000,3000,3000]},
			{"count":1,"faction":8,"friendly":true,"static":{"model":18785,"jitter":0,"offset":Vector3(-80000,0,-160000)},"name_text_id":3201,"name_number":1,"dock":"hack","dockable":false,"hidden":true},
			{"count":1,"faction":8,"friendly":true,"static":{"model":18785,"jitter":0,"offset":Vector3(-72000,0,-190000)},"name_text_id":3201,"name_number":2,"dock":"hack","dockable":false,"hidden":true},
			{"count":1,"faction":8,"friendly":true,"static":{"model":18785,"jitter":0,"offset":Vector3(-66000,53000,-170000)},"name_text_id":3201,"name_number":3,"dock":"hack","dockable":false,"hidden":true},
			{"count":1,"faction":8,"friendly":true,"static":{"model":18786,"jitter":0,"offset":Vector3(-72000,0,-145000)},"name_text_id":-1},
			{"count":1,"faction":8,"friendly":true,"static":{"model":18786,"jitter":0,"offset":Vector3(-68000,-200,-149000)},"name_text_id":-1},
			{"count":1,"faction":8,"friendly":true,"static":{"model":18786,"jitter":0,"offset":Vector3(-64000,-400,-153000)},"name_text_id":-1},
			{"count":1,"faction":8,"friendly":true,"static":{"model":18786,"jitter":0,"offset":Vector3(-60000,-600,-157000)},"name_text_id":-1}],
		"radio":[[0,2793,2126,5,[1500]],[0,2803,2136,6,[0]],[0,2804,2137,52,[0]],[10,2805,2138,6,[2]],
			[0,2806,2139,35,[3,7000,0]],[0,2807,2140,50,[1]],[0,2809,2142,50,[2]],[0,2810,2143,50,[3]]],
		"radio_actions":[{"radio_index":1,"action":"route","points":[Vector3(-70000,0,-130000)]},
			{"radio_index":2,"action":"show","first_actor":8,"end_actor":11},
			{"radio_index":3,"action":"show","first_actor":2,"end_actor":6,"center":"player","radius":[1000,2000]},
			{"radio_index":3,"action":"lock_player","hidden":true,"invulnerable":true,"duration_ms":7000},
			{"radio_index":4,"action":"wake","first_actor":2,"end_actor":6},
			{"radio_index":4,"action":"dockable","first_actor":8,"end_actor":11,"enabled":true},
			{"radio_index":6,"action":"show","first_actor":6,"end_actor":8,"center":"player","radius":[1000,2000],"wake":true}],
		"success":{"kind":"radio_finished","index":13}},
	# 131: Var Lupra, the plasma array platform. No cast; the player is held
	# for the fly-past; Keith at 3 s; control returns and the flight is done
	# when his line is over. Assumption: no camera path (fixed view).
	131:{"points":[Vector3.ZERO],"groups":[],
		"radio":[[0,2848,2144,5,[3000]]],
		"timed_actions":[{"after_ms":0,"action":"lock_player","invulnerable":true,"until":[35,[0,0,1]]}],
		"success":{"kind":"radio_finished","index":0}},
	# 135: Coromesk mining contract (kind 174; gate: a mining drill). The
	# orbit's asteroids all give Titanium (155). #0 the Mining Plant (19080,
	# "Mining Plant", docking point "deliver": one Titanium from the hold per
	# second, status +1, HUD event 0x2a); #1-#2 pirates hidden and asleep.
	# The foreman's briefing at 1.5 s. Docked at the plant or 60 s: the
	# pirates appear 25/26 km out (+5 km up) from the player and attack (#4);
	# status >= 70: #6; every 75 s from #4 the dead ones come back at the same
	# offsets, and the first return after #6 plays #7. Status 140: the
	# foreman's result, then the story moves on (136).
	# Assumptions: the briefing plays in flight (Coromesk has no station);
	# a docking delivers what is in the hold (the limit is not recovered).
	135:{"points":[Vector3.ZERO],"asteroid_ore":155,
		"groups":[{"count":1,"faction":8,"friendly":true,"static":{"model":19080,"jitter":0},"name_text_id":3199,"dock":"deliver","dockable":true},
			{"count":2,"faction":8,"hull":-1,"friendly":false,"sleeping":true,"hidden":true,"index":0,"offsets":[0,0,0],"bounds":[1,1,1]}],
		"radio":[[49,2868,2035,5,[1500]],[0,2869,2036,6,[0]],[49,2870,2037,6,[1]],[0,2871,2038,6,[2]],
			[49,2872,2145,36,[[32,[0]],[5,[60000]]]],[0,2873,2146,6,[4]],[0,2874,2147,51,[70]],[0,2875,2148,53,[6]]],
		"radio_actions":[{"radio_index":4,"action":"show","first_actor":1,"end_actor":3,"center":"player","offset":Vector3(25000,5000,25000),"step":Vector3(1000,0,0),"wake":true},
			{"radio_index":4,"action":"respawn","first_actor":1,"end_actor":3,"every_ms":75000,"center":"player","offset":Vector3(25000,5000,25000),"step":Vector3(1000,0,0)}],
		"result_after":[51,[140]],
		"success":{"kind":"radio_finished","index":9}},
	# 137: B'akrram. No cast; Vossk control at 1.5 s, four more lines; done
	# when "You may proceed to the conference area." is over.
	137:{"points":[Vector3.ZERO],"groups":[],
		"radio":[[50,2884,2149,5,[1500]],[0,2885,2150,6,[0]],[50,2886,2151,6,[1]],[0,2887,2152,6,[2]],[50,2888,2153,6,[3]]],
		"success":{"kind":"radio_finished","index":4}},
	# 139: Bra'Murr, the Vossk prism (kind 168; gate: a Vossk ship). #0-#1
	# Vossk Battleships (19051, "Battleship 1/2", hacking docks, cannot be
	# destroyed); #2-#6 and #7-#11 Vossk fighters looping near each ship,
	# friendly. Keith at 8 s. The first won hack (either ship): no prism, its
	# dock closes, #1 and every Vossk ship turns hostile, #2-#3. The second
	# won hack: that ship becomes a transfer point with the player docked
	# (story_aboard reset to 0; +1 per 1.5 s while docked); #4. Ten counted:
	# #5 (the result line) and the story moves on (140).
	# Assumptions: the ten turrets on the battleships are not built (their
	# placement is not recovered and story turrets do not fire yet).
	139:{"points":[Vector3(-50000,-1500,70000),Vector3(-200000,-1500,30000),Vector3(-70000,0,80000),Vector3(-30000,0,60000),Vector3(-220000,0,40000),Vector3(-180000,0,20000)],
		"groups":[{"count":1,"faction":1,"friendly":true,"static":{"model":19051,"jitter":0,"offset":Vector3.ZERO},"index":0,"name_text_id":1656,"name_number":1,"dock":"hack","dockable":true,"unharmable":true},
			{"count":1,"faction":1,"friendly":true,"static":{"model":19051,"jitter":0,"offset":Vector3.ZERO},"index":1,"name_text_id":1656,"name_number":2,"dock":"hack","dockable":true,"unharmable":true},
			{"count":5,"faction":1,"hull":-1,"friendly":true,"index":0,"route_start":2,"route_loop":[2,3],"offsets":[-1000,-1000,-1000],"bounds":[2000,2000,2000]},
			{"count":5,"faction":1,"hull":-1,"friendly":true,"index":1,"route_start":4,"route_loop":[4,5],"offsets":[-1000,-1000,-1000],"bounds":[2000,2000,2000]}],
		"radio":[[0,2913,2237,5,[8000]],[0,2914,2154,50,[1]],[50,2915,2155,6,[1]],[50,2916,2156,6,[2]],[0,2917,2157,50,[2]],[0,2918,1902,33,[10]]],
		"radio_actions":[{"radio_index":1,"action":"dockable","target":"last_hacked","enabled":false},
			{"radio_index":4,"action":"transfer","target":"last_hacked","mode":"board","reset":true}],
		"turn_hostile":{"radio_index":1},
		"success":{"kind":"radio_finished","index":5}},
	# 95: cutaway at Thynome (N1): the player is held out of sight while the
	# camera drifts; caption at 2 s; the result 2 s after it ends; the story
	# moves on when the last line is over (MOVE_ON_ENTRY 96).
	95:{"points":[Vector3.ZERO],"groups":[],"radio":[[17,2544,-1,5,[2000]]],
		"timed_actions":[{"after_ms":0,"action":"cutaway"}],"result_after":[35,[0,2000,1]],
		"success":{"kind":"radio_finished","index":16}},
	# 99: cutaway at Thynome (N1): the player is held out of sight while the
	# camera drifts; caption at 2 s; the result 2 s after it ends; the story
	# moves on when the last line is over (MOVE_ON_ENTRY 100).
	99:{"points":[Vector3.ZERO],"groups":[],"radio":[[17,2589,-1,5,[2000]]],
		"timed_actions":[{"after_ms":0,"action":"cutaway"}],"result_after":[35,[0,2000,1]],
		"success":{"kind":"radio_finished","index":12}},
	# 109: cutaway at Midantha (N1): the player is held out of sight while the
	# camera drifts; caption at 2 s; the result 2 s after it ends; the story
	# moves on when the last line is over (MOVE_ON_ENTRY 110).
	109:{"points":[Vector3.ZERO],"groups":[],"radio":[[17,2676,-1,5,[2000]]],
		"timed_actions":[{"after_ms":0,"action":"cutaway"}],"result_after":[35,[0,2000,1]],
		"success":{"kind":"radio_finished","index":4}},
	# 97: Genoh pirate battle. #0-#11 pirates (their random fighters), #12-#15
	# Nivelian fighters and #16-#18 Nivelian capital ships (hull 15, held in
	# place), all around (0,0,50000). Three lines from 1.5 s; all twelve
	# pirates dead -> the result over the radio -> 98 (Paréah opens).
	# Assumption: the spawn spread (+-5 km; the original's own scatter).
	97:{"points":[Vector3(0,0,50000)],
		"groups":[{"count":12,"faction":8,"hull":-1,"friendly":false,"index":0,"offsets":[-5000,-5000,-5000],"bounds":[10000,10000,10000]},
			{"count":4,"faction":2,"hull":-1,"friendly":true,"index":0,"offsets":[-5000,-5000,-5000],"bounds":[10000,10000,10000]},
			# Assumption: the three capitals (hull 15, built from parts) are drawn
			# as the Nivelian freighter assembly.
			{"count":3,"faction":2,"hull":-1,"friendly":true,"freighter":true,"moving":false,"index":0,"offsets":[-8000,-2000,-8000],"bounds":[16000,4000,16000]}],
		"radio":[[0,2571,2089,5,[1500]],[22,2572,2090,6,[0]],[0,2573,2091,6,[1]]],
		"result_after":[30,[12,0,12]],
		"success":{"kind":"radio_finished","index":5}},
	# 100: Alioth stealth ambush. Two stealth fighters (race 10, hull 44)
	# 20-70 / 10-60 / 20-70 km from the player on a random side of each axis
	# (N4), awake and hostile; they cloak by themselves (N5). Done when the
	# second line is over; the fight goes on (no follow-up move).
	100:{"points":[Vector3.ZERO],
		"groups":[{"count":2,"faction":10,"hull":44,"friendly":false,"position":{"kind":"player_band","min":Vector3(20000,10000,20000),"max":Vector3(70000,60000,70000)}}],
		"radio":[[0,2602,2092,5,[1500]],[0,2603,2093,6,[0]]],
		"success":{"kind":"radio_finished","index":1}},
	# 102: Tadram carrier evacuation (kind 184, 1700 people). #0 the carrier
	# (unloading point, never destroyed) at (-50000,1000,70000); #1 Tadram's
	# exterior (turned 180 deg, not dockable); #2-#5 Terran dropships (Rhino,
	# hull 51) looping carrier <-> station, 20 s at each stop, unloading at
	# the carrier (N2: one person per 0.2 s); #6-#9 stealth fighters, hidden
	# and asleep. Opening scene until 2 s after line #2 (player held, hidden);
	# 30 s later the fighters appear around a random dropship (1 in 5: the
	# player) 35-45 km out, 10 s scene, then they attack (#3) and dead ones
	# come back every 60 s. Keith counts lost dropships (#4-#6). Status <= 9:
	# 8 s scene, "Everyone's on board" (#7), 4 s later Keith (#8), then Carla's
	# call (result) and the story moves on. Failure: all four dropships dead.
	# Assumptions: #1 stands at the origin (OPEN), the dropships' route is the
	# two stops, the stop time 20 s is read from the route values.
	102:{"points":[Vector3(-50000,1000,70000),Vector3.ZERO],
		"groups":[{"count":1,"faction":0,"friendly":true,"static":{"model":18804,"jitter":0},"index":0,"name_text_id":-1,"dock":"leave","dockable":true,"unharmable":true},
			{"count":1,"faction":0,"friendly":true,"static":{"model":21113,"jitter":0,"offset":Vector3.ZERO,"rotation":Vector3(0,PI,0)},"index":1,"name_text_id":-1},
			{"count":1,"faction":0,"hull":51,"friendly":true,"index":0,"offsets":[10000,6000,-20000],"bounds":[1,1,1],"route_start":0,"route_loop":[0,1],"stop_ms":20000},
			{"count":1,"faction":0,"hull":51,"friendly":true,"index":0,"offsets":[30000,8000,-35000],"bounds":[1,1,1],"route_start":0,"route_loop":[0,1],"stop_ms":20000},
			{"count":1,"faction":0,"hull":51,"friendly":true,"index":0,"offsets":[35000,8000,-40000],"bounds":[1,1,1],"route_start":0,"route_loop":[0,1],"stop_ms":20000},
			{"count":1,"faction":0,"hull":51,"friendly":true,"index":0,"offsets":[40000,8000,-45000],"bounds":[1,1,1],"route_start":0,"route_loop":[0,1],"stop_ms":20000},
			{"count":4,"faction":10,"hull":44,"friendly":false,"sleeping":true,"hidden":true,"position":{"kind":"player_offset","offset":Vector3(1000000,1000000,1000000),"bound":Vector3(1,1,1)}}],
		"radio":[[18,2614,2094,5,[8000]],[18,2615,2095,6,[0]],[18,2616,2096,6,[1]],[18,2617,2097,35,[2,42000,1]],
			[0,2618,2098,30,[1,2,6]],[0,2619,2099,30,[2,2,6]],[0,2620,2100,30,[3,2,6]],
			[18,2621,2101,34,[9,8000]],[0,2622,2102,35,[7,4000,1]]],
		"radio_actions":[{"radio_index":0,"action":"lock_player","hidden":true,"invulnerable":true,"until":[35,[2,2000,1]]},
			{"radio_index":2,"on":"finished","delay_ms":32000,"action":"show","first_actor":6,"end_actor":10,"near_actors":[2,6],"player_chance":0.2,"radius":[35000,45000],"target":"near"},
			{"radio_index":2,"on":"finished","delay_ms":32000,"action":"lock_player","duration_ms":10000,"invulnerable":true},
			{"radio_index":3,"action":"wake","first_actor":6,"end_actor":10},
			{"radio_index":3,"action":"respawn","first_actor":6,"end_actor":10,"every_ms":60000,"near_actors":[2,6],"player_chance":0.2,"radius":[35000,45000],"until_radio":7},
			{"radio_index":7,"action":"lock_player","hidden":true,"duration_ms":12000,"invulnerable":true}],
		# Dropships unload at the carrier, one person per 0.2 s while there (N2).
		"shuttles":{"first_actor":2,"end_actor":6,"dock":0,"visit_ms":20000,"transfer_ms":200},
		"success":{"kind":"radio_finished","index":14},"failure":{"kind":18,"first_actor":2,"end_actor":6}},
	# 105: Naneroh bomb run (gate: Gamma Shield II fitted). The player flies a
	# route 300 km toward the sun (N3); #0-#1 Cronus escorts beside them with
	# weapons off; #2-#4 stealth fighters hidden and asleep far away. Opening
	# scene (player on autopilot) until 6 s after the escort's line #1; the
	# escorts then turn aside and leave. #5 at 24 s after #3: the fighters
	# appear ahead (10 s scene) and attack; from #7 dead ones return every
	# 110 s. At the sun point the player becomes unharmable and "Bombs away!"
	# (#8); 16 s bomb scene: the supernova grows, flash at ~9 s; the story
	# moves on to 106 at Luur (gate, vitals and gamma kept). Gamma applies.
	# Assumptions: the route length (not recovered) lets a cruising player
	# arrive soon after "my eyes are hurting" (~150 s, gamma about half gone);
	# escorts 3 km either side, the fighters appear 20 km ahead,
	# the sun point counts as reached within 10 km, the scene tail is 16 s.
	105:{"points":[Vector3(7000000,7000000,7000000)],"player_route":{"toward_sun":300000,"reach_radius":10000},
		"groups":[{"count":2,"faction":0,"hull":37,"friendly":true,"position":{"kind":"player_side","side":3000},"follow_player_route":true,"ship_state":{"firing_allowed":false}},
			{"count":3,"faction":10,"hull":44,"friendly":false,"sleeping":true,"hidden":true,"index":0,"offsets":[-1000,-1000,-1000],"bounds":[2000,2000,2000]}],
		"radio":[[20,2646,2103,5,[0]],[61,2647,2104,5,[13000]],[0,2648,2105,35,[1,6000,1]],[20,2649,2106,35,[2,10000,0]],[0,2650,2107,6,[3]],
			[0,2651,2108,35,[3,24000,0]],[20,2652,2109,6,[5]],[0,2653,2110,35,[5,70000,0]],[0,2654,2111,37,[[6,[7]],[38,[]]]]],
		"radio_actions":[{"radio_index":0,"action":"lock_player","autopilot":true,"until":[35,[1,6000,1]]},
			{"radio_index":1,"on":"finished","action":"retire","first_actor":0,"end_actor":2},
			{"radio_index":5,"action":"show","first_actor":2,"end_actor":5,"ahead_of_player":20000,"radius":[0,3000]},
			{"radio_index":5,"action":"lock_player","hidden":true,"duration_ms":10000,"invulnerable":true},
			{"radio_index":5,"delay_ms":10000,"action":"wake","first_actor":2,"end_actor":5},
			{"radio_index":7,"action":"respawn","first_actor":2,"end_actor":5,"every_ms":110000,"ahead_of_player":20000,"radius":[0,3000],"until_radio":8},
			{"radio_index":8,"action":"lock_player","hidden":true,"invulnerable":true,"duration_ms":16000},
			{"radio_index":8,"on":"finished","delay_ms":2500,"action":"supernova","grow":true}],
		"success":{"kind":"radio_finished","index":8,"hold_ms":16000}},
	# 106: Luur aftermath, all one scene (player held). #0 a stealth fighter
	# (1 hp, cannot cloak, friendly) far out on a route, hidden until line #2
	# ends; then the camera follows it; line #4 over -> it breaks apart; 3 s
	# later "On second thoughts..." (#5); when it ends the story moves twice
	# (107 skipped) and the player arrives at Thynome through the gate.
	106:{"points":[Vector3(-500000,0,-1700000),Vector3(-500000,0,-3700000)],
		"groups":[{"count":1,"faction":10,"hull":44,"friendly":true,"hidden":true,"hull_override":1,"cloaking":false,"index":0,"offsets":[0,0,0],"bounds":[1,1,1],"route_start":0,"ship_state":{"firing_allowed":false}}],
		"radio":[[0,2655,2112,5,[1500]],[20,2656,2113,6,[0]],[20,2657,2114,6,[1]],[0,2658,2115,6,[2]],[0,2659,2116,6,[3]],[0,2660,2117,35,[4,3000,1]]],
		"timed_actions":[{"after_ms":0,"action":"lock_player","invulnerable":true,"until":[35,[5,0,1]]}],
		"radio_actions":[{"radio_index":2,"on":"finished","action":"show","first_actor":0,"end_actor":1,"camera":true},
			{"radio_index":4,"on":"finished","action":"destroy","first_actor":0,"end_actor":1}],
		"success":{"kind":"radio_finished","index":5}},
	# 114: Marktesh asteroid ambush. Six pirates (hull doubled) asleep at
	# asteroids of the field around (0,0,30000); one wakes within 7 km and
	# then all six attack (the existing sleeping wake with range 50 km).
	# Keith at 8 s; the pirate's line when one is awake; all dead -> the
	# result line over the radio.
	114:{"points":[Vector3(0,0,30000)],
		"groups":[{"count":6,"faction":8,"hull":-1,"friendly":false,"sleeping":true,"hull_scale":2,"wake_range":7000,"wake_all_range":50000,"position":{"kind":"asteroids","from":"middle"}}],
		"radio":[[0,2697,2118,5,[8000]],[10,2698,2119,16,[0]],[0,2699,2120,6,[1]]],
		"result_after":[30,[6,0,6]],
		"success":{"kind":"radio_finished","index":3}},
	# 92: Tadram hand-over and the cloaked ambush. #0 the freighter (people
	# leave while docked, one per 1.5 s, status -1 each); #1-#3 unknown ships
	# (race 10, hull 44) parked asleep. All ten off: they appear around the
	# player (line #4) and docking ends; after line #5 they cloak (vanish) and
	# 22 s after it come back awake (line #6); all three dead: line #8, the
	# player is held and unharmed 10 s and the freighter leaves 7 s in; line #9
	# at 10 s; Gunant's call follows over the radio. Failure: the freighter
	# destroyed. Assumptions: they appear 20 km from the player; no cutscene
	# cameras (player held and unharmed instead); a cloak shows as the ships
	# vanishing until they attack.
	# 94: Luur platform evacuation. #0 the station platform (people board),
	# #1-#6 the unknown ships parked asleep, #7 the freighter (people leave,
	# the status counts 83 down), #8-#23 unarmed Midorian fighters shuttling
	# platform <-> freighter. Over 6 aboard or at 60 s two raiders appear
	# (line #3) and attack 6 s later; two more 100 s later, the last two another
	# 100 s later. Status 0: Bargand's lines, then the story moves on (95,
	# Thynome gate). Failure: the freighter destroyed. Assumptions: the first
	# pair appears on a 20 km ring round the platform; the player is held
	# (unharmable) instead of the short cutscene; boarding stops at the berths.
	94:{"points":[Vector3.ZERO,Vector3(30000,-5000,40000),Vector3(-35500,3000,20000),Vector3(-29500,3000,20000),Vector3(-300000,300000,-300000),Vector3(20000,-3000,30000)],
		"groups":[{"count":1,"faction":3,"friendly":true,"static":{"model":18781,"jitter":0,"offset":Vector3.ZERO},"name_text_id":3197,"dock":"board","dockable":true},
			{"count":6,"faction":10,"hull":44,"friendly":false,"sleeping":true,"index":4,"offsets":[-1000,-1000,-1000],"bounds":[2000,2000,2000]},
			{"count":1,"faction":3,"friendly":true,"index":1,"static":{"model":17049,"jitter":0,"offset":Vector3.ZERO},"name_text_id":3198,"dock":"leave","dockable":true},
			{"count":16,"faction":3,"friendly":true,"index":0,"route_loop":[0,5,1],"offsets":[-3000,-3000,-3000],"bounds":[6000,6000,6000]}],
		# The fighters carry most of the 83 (verified PlayerFighter::update):
		# 12 s at the freighter, one person per 1.5 s, until the rest fit the
		# player's berths. Assumption: they fly through instead of stopping.
		"shuttles":{"first_actor":8,"end_actor":24,"dock":7,"visit_ms":12000,"hold_at_berths":true},
		"radio":[[0,2530,2082,5,[1500]],[59,2531,2083,6,[0]],[0,2532,2084,6,[1]],
			[0,2533,2085,36,[33,7,5,60000]],[0,2534,2086,6,[3]],[0,2535,2087,6,[4]]],
		"radio_actions":[{"radio_index":0,"action":"disarm","first_actor":8,"end_actor":24},
			{"radio_index":3,"action":"place","first_actor":1,"end_actor":3,"center":Vector3.ZERO,"radius":20000.0},
			{"radio_index":3,"action":"lock_player","duration_ms":6000,"invulnerable":true},
			{"radio_index":3,"delay_ms":6000,"action":"wake","first_actor":1,"end_actor":3},
			{"radio_index":3,"delay_ms":106000,"action":"place","first_actor":3,"end_actor":5,"center":Vector3(-35500,3000,20000),"radius":1500.0,"wake":true},
			{"radio_index":3,"delay_ms":206000,"action":"place","first_actor":5,"end_actor":7,"center":Vector3(-29500,3000,20000),"radius":1500.0,"wake":true}],
		"result_after":[34,[0]],
		"success":{"kind":"radio_finished","index":12},"failure":{"kind":1,"actor_id":7}},
	92:{"points":[Vector3(80000,0,110000),Vector3(70000,-100000,-140000),Vector3(-300000,300000,-300000)],
		"groups":[{"count":1,"faction":3,"friendly":true,"static":{"model":17049,"jitter":0,"offset":Vector3.ZERO},"name_text_id":3198,"dock":"leave","dockable":true},
			{"count":3,"faction":10,"hull":44,"friendly":false,"sleeping":true,"index":2,"offsets":[-1000,-1000,-1000],"bounds":[2000,2000,2000]}],
		"radio":[[59,2502,2071,5,[1500]],[0,2503,2073,6,[0]],[59,2504,2074,6,[1]],[0,2505,2075,6,[2]],
			[0,2506,2076,34,[0]],[0,2507,2077,6,[4]],[0,2508,2078,35,[5,22000,1]],[0,2509,2079,6,[6]],
			[0,2510,2080,9,[1,2,3]],[59,2511,2081,35,[8,10000,0]]],
		"radio_actions":[{"radio_index":4,"action":"place","first_actor":1,"end_actor":4,"center":"player","radius":20000.0},
			{"radio_index":4,"action":"dockable","first_actor":0,"end_actor":1,"enabled":false},
			{"radio_index":4,"action":"lock_player","duration_ms":6000,"invulnerable":true},
			{"radio_index":5,"on":"finished","action":"retire","first_actor":1,"end_actor":4},
			{"radio_index":6,"action":"place","first_actor":1,"end_actor":4,"center":"player","radius":15000.0,"wake":true},
			{"radio_index":8,"action":"lock_player","duration_ms":10000,"invulnerable":true},
			{"radio_index":8,"delay_ms":7000,"action":"retire","first_actor":0,"end_actor":1}],
		"success":{"kind":"radio_finished","index":16},"failure":{"kind":1,"actor_id":0}},
	# 91: Valpatro rescue (empty orbit, gamma rays). #0 the damaged freighter
	# turns dockable and named as line #3 starts. Docked: line #5; after it the
	# ten miners board one per 1.5 s; at ten line #6; undocked after #6 -> 3 s
	# -> the freighter explodes and the story moves on (the drive takes the
	# player to Tadram, vitals and gamma kept). Assumptions: no cutscene camera;
	# docking = holding within range of the freighter; the alarm loop and the
	# freighter's 1/20 hull (it cannot be harmed) are left out.
	91:{"points":[Vector3(-20000,0,60000)],
		"groups":[{"count":1,"faction":3,"friendly":true,"static":{"model":18766,"jitter":0,"offset":Vector3.ZERO},"name_text_id":3200,"dock":"board","dockable":false}],
		"radio":[[0,2493,2063,5,[1500]],[60,2494,2064,6,[0]],[0,2495,2065,6,[1]],[60,2496,2066,6,[2]],[0,2497,2067,6,[3]],
			[60,2498,2068,32,[0]],[60,2499,2069,33,[10]]],
		"radio_actions":[{"radio_index":3,"action":"dockable","first_actor":0,"end_actor":1,"enabled":true},
			{"radio_index":5,"on":"finished","action":"transfer","first_actor":0,"end_actor":1},
			{"radio_index":6,"on":"finished","when":"undocked","delay_ms":3000,"action":"destroy","first_actor":0,"end_actor":1}],
		"success":{"kind":1,"actor_id":0}},
	# 87: Carla and Keith fly to Thynome. No cast; six lines from 1.5 s; done
	# when the last is over (then the 88 talk on docking at Thynome).
	87:{"points":[Vector3.ZERO],"groups":[],
		"radio":[[6,2469,2057,5,[1500]],[0,2470,2058,6,[0]],[6,2471,2059,6,[1]],[0,2472,2060,6,[2]],[6,2473,2061,6,[3]],[0,2474,2062,6,[4]]],
		"success":{"kind":"radio_finished","index":5}},
	# 89: the supernova at Naneroh (empty orbit; the cast brings the station).
	# #0 a container, #1 the station, #2 its burning twin (hidden), #3-#10
	# Midorian fighters, #11 a Midorian capital ship. Caption at 2 s; at 39 s
	# the twin replaces the station and every ship dies; at 54 s the story
	# moves on and the drive takes the player to Thynome (MOVE_ON_ENTRY 90).
	# Assumptions: no camera work or flash yet (player held and unharmed
	# instead), the fighters wait at their loop points, a Midorian transport
	# beside the station stands in for the capital ship (its hull 15 has no
	# ordinary mesh), success at 54 s (39 + 7 + 8).
	89:{"points":[Vector3.ZERO,Vector3(-63000,0,75000),Vector3(-60000,0,110000),Vector3(-63000,-5000,75000),Vector3(-60000,-5000,110000),Vector3(-77000,-3000,90000)],
		"groups":[{"count":1,"faction":3,"friendly":true,"static":{"model":16992,"jitter":0},"name_text_id":-1},
			{"count":1,"faction":3,"friendly":true,"static":{"model":21076,"jitter":0,"offset":Vector3.ZERO,"rotation":Vector3(0,PI,0)},"index":5,"name_text_id":-1},
			{"count":1,"faction":3,"friendly":true,"static":{"model":21876,"jitter":0,"offset":Vector3.ZERO,"rotation":Vector3(0,PI,0)},"index":5,"name_text_id":-1,"hidden":true},
			{"count":4,"faction":3,"hull":-1,"friendly":true,"index":1,"offsets":[-1000,-1000,-1000],"bounds":[2000,2000,2000]},
			{"count":4,"faction":3,"hull":-1,"friendly":true,"index":3,"offsets":[-1000,-1000,-1000],"bounds":[2000,2000,2000]},
			{"count":1,"faction":3,"hull":-1,"friendly":true,"freighter":true,"index":5,"offsets":[-8000,-2000,-8000],"bounds":[4000,4000,4000]}],
		"radio":[[17,2483,-1,5,[2000]]],
		"timed_actions":[{"after_ms":0,"action":"lock_player","duration_ms":54000,"invulnerable":true},
			{"after_ms":39000,"action":"hide","first_actor":1,"end_actor":2},{"after_ms":39000,"action":"show","first_actor":2,"end_actor":3},
			{"after_ms":39000,"action":"destroy","first_actor":3,"end_actor":12}],
		"success":{"kind":"elapsed","after_ms":54000}},
	# 80: Battle of Kothar. #0 the Valkyrie battlestation (hostile, not
	# destroyable), #1-#12 its weak points, #13-#18 pirates and #19-#21 Ward
	# defenders around (0,0,80000). "Retreat!" once #1-#18 are gone; the
	# station jumps away after "I'm not done with you". Success once Carla's
	# result lines are over; then STORY_JUMP takes the ship to the alien world.
	# Assumptions: no cutscenes (Alice-drive beam on Kothar, station
	# close-ups), line #10 follows #9 directly (original: ~4 s later), the
	# weak points do not aim or fire (the turret barrels are not drawn), the
	# player start is the default one (original: (-70000,0,-30000)), the
	# station is unnamed and drawn in its first pose.
	80:{"points":[Vector3(0,0,160000),Vector3(0,0,80000)],
		"groups":[{"count":1,"faction":8,"friendly":false,"static":{"model":16928,"jitter":0,"offset":Vector3.ZERO,"rotation":Vector3(0,PI,0)},"name_text_id":-1},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14363,"jitter":0,"offset":Vector3(-3994.97,23359.0,-7378.1),"rotation":Vector3(0,0,1.5708)},"name_text_id":1655},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14363,"jitter":0,"offset":Vector3(3994.96,23359.0,-7378.1),"rotation":Vector3(0,0,-1.5708)},"name_text_id":1655},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14365,"jitter":0,"offset":Vector3(1988.03,-37327.1,-4511.46),"rotation":Vector3(0,0,-1.5708)},"name_text_id":1654},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14365,"jitter":0,"offset":Vector3(-1995.02,-37327.1,-4511.46),"rotation":Vector3(0,0,1.5708)},"name_text_id":1654},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14363,"jitter":0,"offset":Vector3(-3264.75,-22848.6,791.524),"rotation":Vector3(0,0,1.5708)},"name_text_id":1655},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14363,"jitter":0,"offset":Vector3(3273.29,-22848.6,791.524),"rotation":Vector3(0,0,-1.5708)},"name_text_id":1655},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14363,"jitter":0,"offset":Vector3(-29726.7,-10994.8,-3765.53),"rotation":Vector3(0,0,3.1416)},"name_text_id":1655},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14363,"jitter":0,"offset":Vector3(29716.2,-10994.8,-3765.53),"rotation":Vector3(0,0,3.1416)},"name_text_id":1655},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14363,"jitter":0,"offset":Vector3(29716.2,4854.22,-3758.77),"rotation":Vector3(0,0,0.0)},"name_text_id":1655},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14365,"jitter":0,"offset":Vector3(17013.0,-764.391,-1690.65),"rotation":Vector3(0,0,0.0)},"name_text_id":1654},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14365,"jitter":0,"offset":Vector3(-17013.3,-764.512,-1690.65),"rotation":Vector3(0,0,0.0)},"name_text_id":1654},
			{"count":1,"faction":8,"friendly":false,"static":{"model":14363,"jitter":0,"offset":Vector3(-29726.7,4854.22,-3758.77),"rotation":Vector3(0,0,0.0)},"name_text_id":1655},
			{"count":6,"faction":8,"hull":-1,"friendly":false,"index":1,"offsets":[-20000,-20000,-20000],"bounds":[40000,40000,40000]},
			{"count":3,"faction":0,"hull":17,"friendly":true,"index":1,"offsets":[-20000,-20000,-20000],"bounds":[40000,40000,40000]}],
		"radio":[[0,2403,1532,5,[8000]],[6,2404,1533,5,[25000]],[26,2405,1536,6,[1]],[0,2406,1537,6,[2]],[6,2407,1538,6,[3]],
			[26,2408,1539,6,[4]],[6,2409,1540,6,[5]],[26,2410,1541,6,[6]],[0,2411,1542,6,[7]],
			[26,2412,1543,30,[18,1,19]],[26,2413,1534,6,[9]],[0,2414,1535,6,[10]]],
		"radio_actions":[{"radio_index":11,"action":"retire","on":"finished","first_actor":0,"end_actor":1}],
		"success":{"kind":"radio_finished","index":17}},
	# 78: escape from the Valkyrie. Twenty pirates sleep in a row ~160 km out;
	# they wake at ~47 s. Only the Khador Drive ends the flight (DRIVE): the
	# story moves on as it charges. Assumptions: no cinematic cameras or
	# player lock, the two sliding hangar objects are left out, the row is a
	# 40x10x10 km box.
	78:{"points":[Vector3(0,0,160000)],
		"groups":[{"count":20,"faction":8,"hull":-1,"friendly":false,"sleeping":true,"offsets":[-17000,-5000,-5000],"bounds":[40000,10000,10000]}],
		"radio":[[0,2398,1527,5,[2000]],[0,2399,1528,5,[30000]],[0,2400,1529,5,[44000]],[11,2401,1530,6,[2]]],
		"timed_actions":[{"after_ms":42000,"action":"hide_station"},{"after_ms":47000,"action":"wake","first_actor":0,"end_actor":20}],
		"success":{"kind":"drive_started"}},
	64:{"points":[Vector3.ZERO,Vector3(100000,0,0)],
		"groups":[{"count":1,"faction":0,"hull":38,"friendly":true,"route_start":1,"hull_override":ESCORT_HULL,"offsets":[-1,-1,-1],"bounds":[2,2,2]},
			{"count":8,"faction":8,"hull":-1,"friendly":false,"route_start":1,"offsets":[-2500,-2500,-2500],"bounds":[5000,5000,5000]}],
		"radio":[[0,2217,1491,5,[8000]],[20,2218,1492,6,[0]],[0,2219,1493,6,[1]],[30,2220,1494,30,[2,2,6]],[0,2221,1495,6,[3]],[30,2222,1496,20,[5]],[0,2223,1497,6,[5]]],
		"radio_actions":[{"radio_index":5,"action":"disarm","first_actor":1,"end_actor":9}],
		"success":{"kind":"radio_finished","index":6}},
	# 67: the outpost (friendly for now) at the waypoint with four sleeping
	# pirates; four more wait parked and arrive at line #5; Tenner flies along.
	# Assumptions: no cutscenes, Tenner never hides inside the station, the
	# outpost-destroyed failure holds all mission, the unused 5th reserve is left out.
	# The reserve waits parked out of sight (the original's 800 km per axis is
	# beyond the remake's single-precision flight range).
	67:{"points":[Vector3(220000,-20000,-10000),Vector3(-300000,300000,-300000)],
		"groups":[{"count":1,"faction":8,"friendly":true,"static":{"model":14243,"jitter":0},"name_text_id":430},
			{"count":4,"faction":8,"hull":-1,"friendly":false,"sleeping":true,"offsets":[-20000,-20000,-20000],"bounds":[40000,40000,40000]},
			{"count":4,"faction":8,"hull":-1,"friendly":false,"sleeping":true,"index":1,"offsets":[-1000,-1000,-1000],"bounds":[2000,2000,2000]},
			{"count":1,"faction":0,"hull":27,"friendly":true,"name_text_id":1622,"hull_override":ESCORT_HULL,"position":{"kind":"player_offset","offset":Vector3(2000,500,-7000),"bound":Vector3(1,1,1)}}],
		"radio":[[0,2276,1501,16,[0]],[31,2277,1502,6,[0]],[30,2278,1505,6,[1]],[0,2279,1506,20,[2]],[31,2280,1507,6,[3]],[0,2281,1508,6,[4]],
			[0,2282,1509,20,[8]],[31,2283,1510,6,[6]],[0,2284,1511,6,[7]],[31,2285,1512,6,[8]],[0,2286,1503,6,[9]],[31,2287,1504,6,[10]]],
		"radio_actions":[{"radio_index":5,"action":"place","first_actor":5,"end_actor":9,"center":Vector3(220000,-20000,-10000),"radius":20000.0}],
		"success":{"kind":"radio_finished","index":11},"failure":{"kind":1,"actor_id":0}},
	# 69: Trot Lykkt (Netor's assistant, hull 12, friendly) leaves Inari Onu
	# with four ordinary Terran fighters around (0,0,20000). Done when
	# "After him!" is over; the story moves on to 70 silently.
	# Assumptions: no cutscene, so Trot starts beside the player (the original
	# puts him at 4x the second planet's position, seen only by the cutscene
	# camera) and flies out along -z to 10x his first point. He leaves the scene
	# when line #1 is over (action "retire", feature G; ignored until then).
	69:{"points":[Vector3(0,0,20000),Vector3(0,0,-150000),Vector3(0,0,-1500000)],
		"groups":[{"count":1,"faction":0,"hull":12,"friendly":true,"name_text_id":1620,"route_start":1,"position":{"kind":"player_offset","offset":Vector3(3000,1000,-9000),"bound":Vector3(1,1,1)}},
			{"count":4,"faction":0,"hull":-1,"friendly":true,"offsets":[-20000,-20000,-20000],"bounds":[40000,40000,40000]}],
		"radio":[[0,2307,1513,5,[8000]],[0,2308,1514,6,[0]]],
		"radio_actions":[{"radio_index":1,"on":"finished","action":"retire","first_actor":0,"end_actor":1}],
		"success":{"kind":"radio_finished","index":1}},
	# 70: Trot at Lopat, friendly until "Surrender, or I'll open fire!" is over,
	# then hostile. His hull is 2.5x an ordinary ship's (the later "max x3" only
	# rescales the bar). Done when he is destroyed; 2313 then plays.
	# Assumptions: the player is not moved 120 km back and Trot starts 40 km
	# away flying toward the station (the original: 1/4 of the way from the gate
	# toward the moved player); no cutscenes; his Disruptor is the enhanced
	# story gun (feature H would give him item 183 at 2.5x damage).
	70:{"points":[Vector3.ZERO],
		"groups":[{"count":1,"faction":0,"hull":12,"friendly":true,"name_text_id":1620,"route_start":0,"ship_state":{"hull_scales":[2.5],"enhanced_weapon":true},
			"position":{"kind":"player_offset","offset":Vector3(-5000,2000,-40000),"bound":Vector3(1,1,1)}}],
		"radio":[[0,2309,1515,5,[8000]],[0,2310,1516,6,[0]],[34,2311,1517,6,[1]],[0,2312,1518,6,[2]]],
		"turn_hostile":{"radio_index":1,"reputation_axis":-1,"reputation_value":0},
		"success":{"kind":18,"first_actor":0,"end_actor":1},"result_after":[1,[0]]},
	# 73: the Teres convoy. Four sleeping pirates at the first waypoint, four
	# more parked; four friendly Terran transports near the second waypoint.
	# EMP a transport: "That should do it!", then "even more of them!" brings
	# the reserve around the player awake. Done when all eight pirates are
	# gone; failed when all four transports are. Assumptions: default player
	# start (the original's is not recovered); transports +-20 km around the
	# waypoint; a disabled transport restarts when the EMP wears off; the
	# player flies to Kothar with the Khador drive (feature J would dock him).
	73:{"points":[Vector3(80000,0,60000),Vector3(150000,0,-50000),Vector3(-800000,-800000,-800000)],
		"groups":[{"count":4,"faction":8,"hull":-1,"friendly":false,"sleeping":true,"offsets":[-20000,-20000,-20000],"bounds":[40000,40000,40000]},
			{"count":4,"faction":8,"hull":-1,"friendly":false,"sleeping":true,"index":2,"offsets":[-1000,-1000,-1000],"bounds":[2000,2000,2000]},
			{"count":4,"faction":0,"hull":-1,"friendly":true,"freighter":true,"index":1,"offsets":[-20000,-20000,-20000],"bounds":[40000,40000,40000]}],
		"radio":[[0,2336,1519,5,[8000]],[0,2337,1520,16,[0]],[11,2338,1521,6,[1]],[0,2339,1522,6,[2]],[0,2340,1523,29,[8,50000]],
			[33,2341,1524,31,[8,12,0]],[0,2342,1525,31,[8,12,1]],[0,2343,1526,6,[6]]],
		"radio_actions":[{"radio_index":7,"action":"place","first_actor":4,"end_actor":8,"center":"player","radius":40000.0,"wake":true}],
		"success":{"kind":18,"first_actor":0,"end_actor":8},"failure":{"kind":18,"first_actor":8,"end_actor":12},"result_after":[30,[8,0,8]]},
	# 142: Kernstal plasma lesson. #0 Gunant Breh (Midorian, hull 30,
	# invulnerable) starts beside the player and flies to the waypoint, stopping
	# within 3 km of it. Lines: 1.5 s; player at the waypoint (N6 cond 41); the
	# lesson; once a gas cloud has been ionized (43) and a plasma (201-204, the
	# original also accepts 205) is in the hold (42): "There you go!". The
	# result lines follow; success on the last. Gas clouds: the Kernstal field
	# gets 3 extra clouds and the first at (92000,0,36000) (N2). Assumptions:
	# the waypoint counts as reached within 3 km; Gunant 1.5 km to the right.
	142:{"points":[Vector3(90000,0,42000)],
		"groups":[{"count":1,"faction":3,"hull":30,"friendly":true,"name_text_id":1588,"hull_override":ESCORT_HULL,"route_start":0,"route_stop_within":3000,
			"position":{"kind":"player_offset","offset":Vector3(1500,0,0),"bound":Vector3(1,1,1)}}],
		"gas_clouds":{"extra":3,"first_position":Vector3(92000,0,36000)},
		# A course to the waypoint from the start; reached within 3 km (assumption).
		"radio_actions":[{"radio_index":0,"action":"route","points":[Vector3(90000,0,42000)],"reach":3000.0}],
		"radio":[[2,2941,2158,5,[1500]],[2,2942,2159,52,[0]],[0,2943,2160,6,[1]],[2,2944,2161,6,[2]],
			[2,2945,2162,37,[[57,[0]],[56,[201,202,203,204,205]]]]],
		"success":{"kind":"radio_finished","index":9}},
	# 144: cutaway at Var Lupra (kind 170). #0 Trunt Harval (Nivelian
	# Scimitar 49) and #1-#12 stealth fighters (race 10, hull 44), asleep at the
	# first point, facing the second. Four lines from 7 s; then the fighters fly
	# on (no attack) and cloak 1 s later, Harval follows at 4 s; 7 s after the
	# last line the story moves on to 145 (a fresh flight at the Var Lupra
	# launch point). Assumptions: no camera work (player locked, unharmable);
	# the wedge formation is a 13x5 km box behind Harval; all cloak at 1 s
	# (original: 10% chance per tick each).
	144:{"points":[Vector3(60000,10000,100000),Vector3(-50000,0,50000)],
		"groups":[{"count":1,"faction":2,"hull":49,"friendly":false,"sleeping":true,"unharmable":true,"name_text_id":1625,"index":0,"route_start":1,"offsets":[-1,-1,-1],"bounds":[2,2,2]},
			{"count":12,"faction":10,"hull":44,"friendly":false,"sleeping":true,"unharmable":true,"index":0,"route_start":1,"offsets":[-6500,-400,-5000],"bounds":[13000,700,5200]}],
		"radio":[[39,2957,2163,5,[7000]],[39,2958,2164,6,[0]],[0,2959,2165,6,[1]],[39,2960,2166,6,[2]]],
		"timed_actions":[{"after_ms":0,"action":"lock_player","duration_ms":-1,"invulnerable":true}],
		"radio_actions":[{"radio_index":3,"on":"finished","action":"wake","first_actor":1,"end_actor":13,"attack_range":0},
			{"radio_index":3,"on":"finished","delay_ms":1000,"action":"cloak","first_actor":1,"end_actor":13,"duration_ms":-1},
			{"radio_index":3,"on":"finished","delay_ms":4000,"action":"wake","first_actor":0,"end_actor":1,"attack_range":0}],
		"success":{"kind":"radio_finished","index":3,"hold_ms":7000}},
	# 145: Harval destroys the plasma array (not winnable by combat). #0
	# Harval at (30000,0,80000), #1-#12 stealth fighters around the first
	# point, all unharmable and asleep; #13 the array (named, unharmable), #14
	# its damaged twin (hidden). 7 s: "They're after the plasma array!",
	# "Say goodbye". Then (player locked 16 s): 1 s they fire on the array
	# (N7 attack), 5.3 s the twin replaces it and they fly off, 15.3 s they are
	# gone; "That should teach you a lesson" 16 s after; Carla's result line;
	# success. Assumptions: the array stands at the origin (original: origin
	# +-10 km random); the damaged twin's model is OPEN (same mesh placeholder);
	# the attackers are unharmable (the original's flight cannot be won).
	145:{"points":[Vector3(-45000,0,60000),Vector3(30000,0,80000)],
		"groups":[{"count":1,"faction":2,"hull":49,"friendly":false,"sleeping":true,"unharmable":true,"name_text_id":1625,"index":1,"route_start":0,"offsets":[-1,-1,-1],"bounds":[2,2,2]},
			{"count":12,"faction":10,"hull":44,"friendly":false,"sleeping":true,"unharmable":true,"index":0,"offsets":[-1000,-1000,-2500],"bounds":[2000,2000,5000]},
			{"count":1,"faction":3,"friendly":true,"static":{"model":19050,"jitter":0},"name_text_id":3196,"unharmable":true},
			{"count":1,"faction":3,"friendly":true,"static":{"model":19050,"jitter":0},"name_text_id":3196,"unharmable":true,"hidden":true,"damaged":true}],
		"radio":[[0,2961,2167,5,[7000]],[39,2962,2168,6,[0]],[39,2963,2169,35,[1,16000,1]]],
		"radio_actions":[{"radio_index":1,"on":"finished","action":"lock_player","duration_ms":16000,"invulnerable":true},
			{"radio_index":1,"on":"finished","delay_ms":1000,"action":"attack","first_actor":0,"end_actor":13,"target_actor":13},
			{"radio_index":1,"on":"finished","delay_ms":5300,"action":"hide","first_actor":13,"end_actor":14},
			{"radio_index":1,"on":"finished","delay_ms":5300,"action":"show","first_actor":14,"end_actor":15},
			{"radio_index":1,"on":"finished","delay_ms":5300,"action":"retire","first_actor":0,"end_actor":13}],
		"success":{"kind":"radio_finished","index":3}},
	# 154: the Valkyrie ambush, built in the alien world (station -1, N4).
	# #0 the Terran Rhino (hull 51) with the energy cells beside the player,
	# invulnerable; #1 Valkyrie (named, docking = hacking, N8); #2-#21 twenty
	# Void fighters shown asleep near it. 9 s: "a welcoming party!"; Alice and
	# Keith (#1-#6). After "Proceed to Valkyrie" the freighter flies in (player
	# locked 8 s); "Void minions, terminate him!" and they attack; Keith's
	# "90 seconds", the captain, Keith. After line #8 a 91 s countdown (N9):
	# dock at Valkyrie and win the hack -> "Ready to go on board" (the countdown
	# stops) -> the result
	# (Alice arrested) -> success; then back at the last docked station's gate
	# (MOVE_ON_ENTRY 155). Failure: the countdown runs out. Assumptions: the
	# freighter's ~1 s cutscene steps are one 8 s lock; all fighters target the
	# player (original: every third the freighter); the ring is a 3.4 km box;
	# the fighters are the alien world's own Void hull (8).
	# Valkyrie stands at the centre of the fighters' ring (point 2).
	154:{"points":[Vector3(200000,0,70000),Vector3(-10000,1000,15000),Vector3(0,0,40000)],
		"groups":[{"count":1,"faction":0,"hull":51,"friendly":true,"sleeping":true,"hull_override":ESCORT_HULL,"route_start":1,
			"position":{"kind":"player_offset","offset":Vector3(1500,0,1500),"bound":Vector3(1,1,1)}},
			{"count":1,"faction":3,"friendly":true,"static":{"model":16928,"layers":[16929,16930],"jitter":0,"offset":Vector3.ZERO},"index":2,"name_text_id":76,"dock":"hack","dockable":false,"unharmable":true},
			{"count":20,"faction":9,"hull":8,"friendly":false,"sleeping":true,"index":2,"offsets":[-1700,-200,-200],"bounds":[3400,200,1700]}],
		"radio":[[0,3028,2172,5,[9000]],[26,3029,2173,6,[0]],[0,3030,2174,6,[1]],[26,3031,2175,6,[2]],[0,3032,2176,6,[3]],[26,3033,2177,6,[4]],[0,3034,2178,6,[5]],
			[26,3035,2179,35,[6,8000,1]],[0,3036,2180,6,[7]],[55,3037,2181,6,[8]],[0,3038,2182,6,[9]],[0,3039,2183,50,[1]]],
		"radio_actions":[{"radio_index":6,"on":"finished","action":"lock_player","duration_ms":8000,"invulnerable":true},
			{"radio_index":6,"on":"finished","action":"wake","first_actor":0,"end_actor":1},
			{"radio_index":7,"action":"wake","first_actor":2,"end_actor":22,"attack_range":50000},
			{"radio_index":8,"on":"finished","action":"dockable","first_actor":1,"end_actor":2,"enabled":true},
			{"radio_index":8,"on":"finished","action":"countdown","duration_ms":91000},
			{"radio_index":11,"action":"countdown","stop":true}],
		"success":{"kind":"radio_finished","index":27},"failure":{"kind":"countdown"}},
	# 157: the final battle at Var Lupra. #0-#9 Terran fighters (random
	# hulls) on a route, #10 the Terran carrier (18804), #11-#20 stealth fighters
	# and #21 Trunt Harval (hidden, asleep, in formation far out), #22 Alice
	# (Midorian Cicero 20, hidden), #23 Valkyrie with the array (station 101's
	# exterior). 7 s: "the whole Terran armada is here!"; lines #1-#3 during a
	# locked scene (the enemies appear 16 s in); 42 s after #0: Brent's order
	# and the attack. Harval under half hull: Carla "Control has been hit!".
	# Once Harval is under 1/4 hull, or 200 s have passed with 9 of the 11
	# enemies (#11-#21) dead: Alice appears and boards (#8-#11, player locked),
	# Harval blocks the way (#12), Keith pleads (#13-#15, 12 s after #10), Alice
	# fires the array (#16). Then the supernova reverses (N5) and 6.5 s later
	# the story moves on: through the gate to Luur, vitals kept (MOVE 158).
	# Assumptions: no camera work; Harval cannot drop below 20% here (the lead's
	# "kept topped up"); Valkyrie does not move away; Harval's 25 s flag toggle
	# (likely cloak) is left out; line #4 ignores the "#3 finished" guard.
	157:{"points":[Vector3(70000,0,20000),Vector3(30000,10000,60000),Vector3(-110000,10000,170000),Vector3(-110000,0,20000),
			Vector3(-120000,0,20000),Vector3(120000,0,-72000),Vector3(20000,0,-4000)],
		# Assumption: the armada is round the player on arrival ("the whole Terran
		# armada is here!") and fights there instead of flying its route away.
		"groups":[{"count":10,"faction":0,"hull":-1,"friendly":true,"position":{"kind":"player_offset","offset":Vector3(-3000,-1000,-3000),"bound":Vector3(6000,2000,6000)}},
			{"count":1,"faction":0,"friendly":true,"static":{"model":18804,"jitter":10000},"name_text_id":-1},
			{"count":10,"faction":10,"hull":44,"friendly":false,"sleeping":true,"hidden":true,"index":2,"offsets":[-5000,-100,5000],"bounds":[10000,200,6000]},
			{"count":1,"faction":2,"hull":49,"friendly":false,"sleeping":true,"hidden":true,"name_text_id":1625,"hull_floor":0.2,"index":2,"offsets":[-1,-1,-1],"bounds":[2,2,2]},
			{"count":1,"faction":3,"hull":20,"friendly":true,"sleeping":true,"hidden":true,"name_text_id":1612,"index":4,"offsets":[-3000,-3000,-3000],"bounds":[6000,6000,6000]},
			{"count":1,"faction":0,"friendly":true,"static":{"model":16928,"layers":[16929,16930],"jitter":0,"offset":Vector3.ZERO},"index":4,"name_text_id":-1,"name_station_id":101,"unharmable":true}],
		"radio":[[0,3066,2184,5,[7000]],[38,3067,2185,6,[0]],[0,3068,2186,6,[1]],[39,3069,2187,6,[2]],
			[1,3070,2188,35,[0,42000,1]],[0,3071,2189,6,[4]],[6,3072,2190,12,[21]],[0,3073,2191,6,[6]],
			[6,3074,2192,36,[[54,[21,25,100]],[37,[[5,[200000]],[30,[9,11,22]]]]]],[26,3075,2193,6,[8]],[6,3076,2194,6,[9]],[1,3077,2195,6,[10]],
			[39,3078,2196,6,[11]],[0,3079,2197,37,[[35,[10,12000,1]],[6,[12]]]],[26,3080,2198,6,[13]],[0,3081,2199,6,[14]],[26,3082,2200,6,[15]]],
		"radio_actions":[{"radio_index":0,"on":"finished","action":"lock_player","duration_ms":42000,"invulnerable":true},
			{"radio_index":0,"on":"finished","delay_ms":16000,"action":"place","first_actor":11,"end_actor":21,"center":Vector3(120000,0,-72000),"radius":15000.0},
			{"radio_index":0,"on":"finished","delay_ms":16000,"action":"place","first_actor":21,"end_actor":22,"center":Vector3(20000,0,-4000),"radius":3000.0},
			{"radio_index":4,"action":"wake","first_actor":11,"end_actor":22},
			{"radio_index":8,"action":"lock_player","until_radio":10,"invulnerable":true},
			{"radio_index":8,"action":"place","first_actor":22,"end_actor":23,"center":Vector3(-120000,0,20000),"radius":8000.0},
			{"radio_index":10,"on":"finished","action":"retire","first_actor":22,"end_actor":23},
			{"radio_index":16,"on":"finished","action":"supernova_reversal"}],
		"success":{"kind":"radio_finished","index":16,"hold_ms":6500}},
	# 158: Luur, after the reversal. #0 Trunt Harval (race 10 in the original
	# cast, Scimitar 49, named, hull x3) and #1-#3 three hostile 100-hull objects
	# (model 18882, origin +-10 km). 10 s: "The sun is back to normal!"; the
	# confession (#1-#4), after which he attacks; taunts at 3/4, 1/2, 1/4 hull
	# (N6 cond 40, 12); "The end of a tyrant." when he dies; Brent's result;
	# success on the last. Assumptions: Harval waits 20 km ahead of the gate
	# arrival and wakes after #4 (his start point and wake moment are not read).
	158:{"points":[Vector3(0,0,20000)],
		"groups":[{"count":1,"faction":10,"hull":49,"friendly":false,"sleeping":true,"name_text_id":1625,"ship_state":{"hull_scales":[3.0]},"index":0,"offsets":[-1,-1,-1],"bounds":[2,2,2]},
			{"count":1,"faction":10,"friendly":false,"static":{"model":18882,"jitter":10000},"name_text_id":-1,"hull":100},
			{"count":1,"faction":10,"friendly":false,"static":{"model":18882,"jitter":10000},"name_text_id":-1,"hull":100},
			{"count":1,"faction":10,"friendly":false,"static":{"model":18882,"jitter":10000},"name_text_id":-1,"hull":100}],
		"radio":[[0,3083,2201,5,[10000]],[0,3084,2202,6,[0]],[39,3085,2203,6,[1]],[0,3086,2204,6,[2]],[39,3087,2205,6,[3]],
			[39,3088,2206,54,[0,75,100]],[0,3089,2207,6,[5]],[39,3090,2208,12,[0]],[0,3091,2209,6,[7]],[39,3092,2210,54,[0,25,100]],[0,3093,2211,1,[0]]],
		"radio_actions":[{"radio_index":4,"on":"finished","action":"wake","first_actor":0,"end_actor":1,"attack_range":50000}],
		"success":{"kind":"radio_finished","index":15}},
	# 160: cutaway at Thynome (kind 170, sketch of s84-94): caption at 2 s, the
	# result 2 s after it; success on the last line; then MOVE_ON_ENTRY 161.
	160:{"points":[Vector3.ZERO],"groups":[],
		"radio":[[17,3110,-1,5,[2000]]],"result_after":[35,[0,2000,1]],
		"timed_actions":[{"after_ms":0,"action":"cutaway"}],
		"success":{"kind":"radio_finished","index":3}},
	# 161: cutaway at Maissa (kind 170, sketch of s84-94): caption at 2 s, the
	# result 2 s after it; success on the last line; then MOVE_ON_ENTRY 162.
	161:{"points":[Vector3.ZERO],"groups":[],
		"radio":[[17,3114,-1,5,[2000]]],"result_after":[35,[0,2000,1]],
		"timed_actions":[{"after_ms":0,"action":"cutaway"}],
		"success":{"kind":"radio_finished","index":6}},
}

## Convoy hunts (kind 163): at each listed station a transport of the system's
## race waits with five fighters around a point far from the station. Within
## CONVOY_RANGE the convoy turns hostile; destroying the transport clears the
## station. Every other ship destroyed with the mission item adds to the career's
## story counter. Radio texts step by two per cleared station.
## Assumptions: the transport keeps the +x side (the original picks either side),
## its two attached containers and the extra traffic ships are not built.
const CONVOY:={59:{"stations":[56,45,22],"item_id":179,"approach_text":2180,"destroyed_text":2179,"final":[0,2179,1228],
	"voices":{2174:1130,2175:1131,2176:1132,2177:1133,2178:1134}}}
const CONVOY_RANGE:=50000
const CONVOY_ESCORTS:=5
## Incoming calls (kind 164): after 10 s in space anywhere the story moves on
## and the mission's result conversation plays over the radio, one line after
## another (assumption, as for the combat results: the original shows it as an
## in-flight conversation). [speaker, text, voice].
const CALLS:={84:[[6,2463,1565],[0,2464,1566]],
	61:[[15,2190,1239],[0,2191,1240],[6,2192,1241],[0,2193,1242],[6,2194,1243],[0,2195,1244],[6,2196,1245],[0,2197,1246]],
	72:[[0,2321,1322],[26,2322,1323],[0,2323,1329],[26,2324,1330],[0,2325,1331],[26,2326,1332],[0,2327,1333],[26,2328,1334],
		[0,2329,1335],[26,2330,1336],[0,2331,1324],[26,2332,1325],[0,2333,1326],[26,2334,1327],[0,2335,1328]],
155:[[0,3056,2000],[1,3057,2001],[0,3058,2002],[26,3059,2003]]}
## The call starts once the story has moved on (radio holds the result poll).
## Systems opened when a story flight moves the career on: [cursor]: systems.
const STORY_UNLOCKS:={61:[22],97:[29]}
const CALL_AFTER_MS:=12000
## Search sites (R1): while the cursor is here, the first flight at each
## listed station marks it searched (progress "story_search_mask", one bit per
## station in list order) and Keith says one random opener at 1.5 s, then one
## random "no reading" line. The star map and radar mark unsearched stations.
## The real site (55, Kappa) is the scripted flight. [text, voice].
const SEARCH_SITES:={125:{"stations":[15,30,40,45,60,70,80,85,95],
	"openers":[[2793,2126],[2794,2127],[2795,2128],[2796,2129]],"misses":[[2799,2132],[2800,2133],[2801,2134],[2802,2135]]}}
## Carla's one-shot calls, armed while the cursor is in [from, to]: in flight
## outside the alien world, with no freelance job, 12 s into the flight
## (original: 12 s of play after the cursor moved). [speaker, text, voice];
## the first line comes 1.5 s after the call opens. Once heard, the career
## keeps "nag_heard" = from (saved in progress).
const NAG_CALLS:={93:{"to":110,"lines":[[6,3157,1553],[0,3158,1554]]},111:{"to":142,"lines":[[6,3159,1555],[0,3160,1556]]},
143:{"to":161,"lines":[[6,3161,1557],[0,3162,1558]]}}
## Once this radio line has finished, every story ship turns hostile and the
## Vossk standing drops to its worst value (standing 0 = 100).
const TURN_HOSTILE_AFTER:={50:{"radio_index":2,"reputation_axis":0,"reputation_value":100}}

## The story job selected at this location, if the career is in a story flight.
static func story_job(bindings: RefCounted,cursor: Variant,station_id: Variant,progress: Dictionary={}) -> Dictionary:
	if cursor is int and station_id is int and Campaign.saved_story(bindings,cursor) and _wanted_entry(cursor)>=0:return _wanted_job(cursor,station_id,progress)
	var job:=_story_flight_job(bindings,cursor,station_id,progress)
	# Where no story flight waits, a Most Wanted criminal may (bounties).
	if job.is_empty() and cursor is int and station_id is int and Campaign.saved_story(bindings,cursor):job=_bounty_job(cursor,station_id,progress)
	# Otherwise Carla may nag once per stage (NAG_CALLS).
	if job.is_empty() and cursor is int and station_id is int and Campaign.saved_story(bindings,cursor):job=_nag_job(cursor,station_id,progress)
	return job

## Carla's call for the stage the cursor is in, until heard. Not at the story
## mission's own station (that stop belongs to the story). No cursor move.
static func _nag_job(cursor: int,station_id: int,progress: Dictionary) -> Dictionary:
	for from in NAG_CALLS:
		if cursor<int(from) or cursor>int(NAG_CALLS[from].to) or int(progress.get("nag_heard",-1))>=int(from):continue
		if station_id==int(Campaign.mission(cursor).get("station_id",-1)):return {}
		return {"kind":-1,"station_id":station_id,"reward":0,"bonus":0,"difficulty":1,"quantity":0,
			"story":false,"story_job":true,"campaign_cursor":cursor,"target_station_id":station_id,"nag":int(from)}
	return {}

static func _story_flight_job(bindings: RefCounted,cursor: Variant,station_id: Variant,progress: Dictionary) -> Dictionary:
	if cursor is int and station_id is int and Campaign.saved_story(bindings,cursor) and SEARCH_SITES.has(cursor) and SEARCH_SITES[cursor].stations.has(station_id):
		var index: int=SEARCH_SITES[cursor].stations.find(station_id)
		var searched:=int(progress.get("story_stations_mask",0))
		if searched & (1<<index):return {}
		return {"kind":-1,"station_id":station_id,"reward":0,"bonus":0,"difficulty":1,"quantity":0,"story":false,"story_job":true,
			"campaign_cursor":cursor,"target_station_id":int(Campaign.mission(cursor).station_id),"search_index":index,"cleared_mask":searched}
	if not cursor is int or not station_id is int or not Campaign.saved_story(bindings,cursor) or not (CASTS.has(cursor) or COMBAT.has(cursor) or CONVOY.has(cursor) or CALLS.has(cursor) or SCRIPTED.has(cursor)):return {}
	var mission:=Campaign.mission(cursor)
	if mission.is_empty() or (int(mission.kind) not in FLIGHT_KINDS+STORY_FLIGHT_KINDS and not CALLS.has(cursor) and not SCRIPTED.get(cursor,{}).get("talk_arrival",false)):return {}
	if (COMBAT.has(cursor) or SCRIPTED.has(cursor)) and station_id!=int(mission.station_id):return {}
	# A talk arrival is not the talk itself: like a search site it has no kind.
	var job:={"kind":-1 if SCRIPTED.get(cursor,{}).get("talk_arrival",false) else int(mission.kind),"station_id":station_id,"reward":0,"bonus":0,"difficulty":1,"quantity":0,
		"story":false,"story_job":true,"campaign_cursor":cursor,"target_station_id":int(mission.station_id)}
	if CONVOY.has(cursor):
		var index: int=CONVOY[cursor].stations.find(station_id)
		var cleared:=int(progress.get("story_stations_mask",0))
		if index<0 or cleared & (1<<index):return {}
		var faction:=int(load("res://src/content/ordinary_world_definitions.gd").location(bindings,station_id).get("faction",-1))
		if faction<0:return {}
		job.merge({"convoy_index":index,"cleared_mask":cleared,"faction":faction})
	return job

## The story's Most Wanted criminal (W1: Pal Tyyrt at 128, Kehnor at 130)
## is met flying at the station where he currently is (progress "wanted").
## The job carries his stats, his hull and the board state after he gives up;
## `progress.wanted_job` rebuilds a retained job unchanged.
static func _wanted_entry(cursor: int) -> int:
	for entry in Campaign.WANTED.story_entries:
		if int(Campaign.WANTED.story_entries[entry])==cursor:return int(entry)
	return -1

static func _wanted_job(cursor: int,station_id: int,progress: Dictionary) -> Dictionary:
	var index:=_wanted_entry(cursor)
	var wanted: Variant=progress.get("wanted_job")
	if wanted==null:
		var state: Variant=progress.get("wanted")
		if Wanted.criminal_at(state,station_id)!=index:return {}
		var stats: Dictionary=state.entries[index].stats
		var hull:=Wanted.spawn_hull(stats,int(progress.get("rank",0)),cursor,false,float(progress.get("difficulty",0.5)))
		wanted={"index":index,"stats":stats.duplicate(true),"hull":hull,"after":Wanted.surrendered(state,index)}
	if not wanted is Dictionary or int(wanted.get("index",-1))!=index:return {}
	return {"kind":-1,"station_id":station_id,"reward":0,"bonus":0,"difficulty":1,"quantity":0,
		"story":false,"story_job":true,"campaign_cursor":cursor,"target_station_id":station_id,"wanted":wanted.duplicate(true)}

## A board criminal (not the story's) at this station: killing him pays the
## bounty and counts toward the board's next tier; the story stays put.
static func _bounty_job(cursor: int,station_id: int,progress: Dictionary) -> Dictionary:
	var wanted: Variant=progress.get("wanted_job")
	if wanted==null:
		var state: Variant=progress.get("wanted")
		var index:=Wanted.criminal_at(state,station_id)
		if index<Wanted.STORY_ENTRIES:return {}
		var stats: Dictionary=state.entries[index].stats
		var hull:=Wanted.spawn_hull(stats,int(progress.get("rank",0)),cursor,false,float(progress.get("difficulty",0.5)))
		wanted={"index":index,"stats":stats.duplicate(true),"hull":hull,"after":Wanted.killed(state,index)}
	if not wanted is Dictionary or int(wanted.get("index",-1))<Wanted.STORY_ENTRIES:return {}
	return {"kind":-1,"station_id":station_id,"reward":0,"bonus":0,"difficulty":1,"quantity":0,
		"story":false,"story_job":true,"campaign_cursor":cursor,"target_station_id":station_id,"wanted":wanted.duplicate(true)}

## Board criminals' lines: Keith on finding one (random), the criminal when
## hit (entries 2 and 6 only; speaker 10, a pirate: assumption), Keith on the
## kill (random). [text, voice].
const BOUNTY_UNCOVER:=[[3130,2232],[3131,2233],[3132,2234],[3133,2235],[3134,2236]]
const BOUNTY_ATTACK:=[[3135,2222],[3136,2223],[3137,2224],[3138,2225],[3139,2226]]
const BOUNTY_ATTACK_ENTRIES:=[2,6]
const BOUNTY_KILL:=[[3140,2227],[3141,2228],[3142,2229],[3143,2230],[3144,2231]]

## [speaker, text, voice]: his lines when the player targets him ("uncover",
## Keith first) and when first hit ("attack"). Speakers 45/46 are the
## original's Pal Tyyrt and Kehnor.
const WANTED_RADIO:={0:{"uncover":[[0,3123,2215],[45,3124,2216]],"attack":[[45,3121,2213],[0,3122,2214]]},
	1:{"uncover":[[0,3128,2220],[46,3129,2221]],"attack":[[46,3125,2217],[0,3126,2218],[46,3127,2219]]}}
## Where he flies as the player arrives. Assumption: ahead of the player
## (the original puts him at the orbit's first route point).
const WANTED_OFFSET:=Vector3(0,0,-15000)

## His ship (and wingmen at half his hull) of his race, not yet hostile.
## Targeting him or hitting him makes them hostile; below a third of his hull
## he gives up (stops fighting), the cursor's result plays over the radio and
## the story moves on with him off the board (not dead, no bounty).
static func _wanted_recipe(job: Dictionary) -> Dictionary:
	var cursor:=int(job.campaign_cursor);var wanted: Dictionary=job.wanted;var stats: Dictionary=wanted.stats
	# Flown as pirates whatever his race: hitting him never costs standing
	# (the original changes no standing for wanted ships). His ship is his own.
	var faction:=8
	var calm:={"initial_hostile":false,"updated_hostile":false,"friendly":false}
	var groups:=[{"first_actor":0,"end_actor":1,"faction":faction,"population_group":"story","origin":"zero","hull_catalogue_id":int(stats.ship),
		"display_name":String(stats.name),"cargo_override":{"entries":[{"item_id":int(stats.loot[0]),"quantity":int(stats.loot[1])}],"special":false},
		"ship_state":{"mode":0,"active":true,"targeting_blocked":false,"hull_override":int(wanted.hull)},"policy":calm.duplicate(),
		"position":{"kind":"player_offset","offset":WANTED_OFFSET,"bound":Vector3.ZERO}}]
	var count:=1+int(stats.wingmen)
	if count>1:
		groups.append({"first_actor":1,"end_actor":count,"faction":faction,"population_group":"story","origin":"zero",
			"ship_state":{"mode":0,"active":true,"targeting_blocked":false,"hull_override":int(wanted.hull)/2},"policy":calm.duplicate(),
			"position":{"kind":"player_offset","offset":WANTED_OFFSET-Vector3(1500,0,1500),"bound":Vector3(3000,1000,3000)}})
	var story: bool=int(wanted.index)<Wanted.STORY_ENTRIES
	var roll:=absi(hash([int(wanted.index),int(job.station_id),int(wanted.hull)]))
	var lines: Dictionary=WANTED_RADIO.get(int(wanted.index),{}) if story else {"uncover":[[0]+BOUNTY_UNCOVER[roll%5]],
		"attack":[[10]+BOUNTY_ATTACK[(roll/5)%5]] if int(wanted.index) in BOUNTY_ATTACK_ENTRIES else []}
	var radio:=[];var actions:=[]
	for part in ["uncover","attack"]:
		var first:=radio.size()
		for row in lines.get(part,[]):
			var own: bool=radio.size()==first
			radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":(55 if part=="uncover" else 54) if own else 6,
				"values":([0] if part=="uncover" else [0,1,1]) if own else [radio.size()-1]})
		if radio.size()>first:actions.append({"radio_index":first,"action":"hostile"})
	if not story:
		# Found or hit, he fights; dead, Keith's line and the bounty.
		var kill: Array=BOUNTY_KILL[(roll/25)%5]
		radio.append({"speaker_id":0,"text_id":kill[0],"voice_event_id":kill[1],"condition":1,"values":[0]})
		var bounty:={"from_cursor":cursor,"campaign_cursor":cursor,"mission":Campaign.mission(cursor),
			"previous_mission":{"reward":int(stats.reward)},"progress":{"wanted":wanted.after.duplicate(true)}}
		return {"actor_count":count,"ship_groups":groups,"radio":radio,"radio_actions":actions,
			"success":{"kind":18,"first_actor":0,"end_actor":1},"story":bounty,"turn_hostile":{}}
	var result: Array=Campaign.Dialogue.RESULT.get(cursor,[])
	var surrender:=radio.size()
	for row in result:
		radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":54 if radio.size()==surrender else 6,
			"values":[0,1,Wanted.SURRENDER_DIVISOR] if radio.size()==surrender else [radio.size()-1]})
	actions.append({"radio_index":surrender,"action":"stand_down","first_actor":0,"end_actor":count})
	var advance:=_advance(cursor);advance.progress={"wanted":wanted.after.duplicate(true)}
	return {"actor_count":count,"ship_groups":groups,"radio":radio,"radio_actions":actions,
		"success":{"kind":"radio_finished","index":radio.size()-1},"story":advance,"turn_hostile":{}}

## Kills that count toward a convoy mission's story counter.
static func counts_kill(cursor: Variant,kill: Dictionary,excluded: Array) -> bool:
	return cursor is int and CONVOY.has(cursor) and int(kill.get("item_id",-1))==int(CONVOY[cursor].item_id) and not excluded.has(kill.get("actor_id"))

## Hulls a story recipe names explicitly for its ships.
static func named_hulls(job: Dictionary) -> Array:
	var result:=[]
	for group in recipe(job).get("ship_groups",[]):
		if group.has("hull_catalogue_id"):result.append(int(group.hull_catalogue_id))
	return result

static func is_story_job(mission: Variant) -> bool:
	return mission is Dictionary and mission.get("story_job",false)==true

## Recipe parts for the shared contract cast factory and result runner.
static func recipe(job: Dictionary) -> Dictionary:
	var cursor:=int(job.campaign_cursor)
	if job.has("wanted"):return _wanted_recipe(job)
	if job.has("nag"):
		var lines:=[]
		for row in NAG_CALLS[int(job.nag)].lines:lines.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":5 if lines.is_empty() else 6,"values":[CALL_AFTER_MS if lines.is_empty() else lines.size()-1]})
		var heard:={"from_cursor":cursor,"campaign_cursor":cursor,"mission":Campaign.mission(cursor),"previous_mission":{"reward":0},"progress":{"nag_heard":int(job.nag)}}
		return {"actor_count":0,"ship_groups":[],"radio":lines,"success":{"kind":"radio_finished","index":lines.size()-1},"story":heard,"turn_hostile":{}}
	if job.has("search_index"):return _search_recipe(job)
	if COMBAT.has(cursor):return _combat_recipe(job)
	if CONVOY.has(cursor):return _convoy_recipe(job)
	if SCRIPTED.has(cursor):return _scripted_recipe(cursor)
	if CALLS.has(cursor):
		var radio:=[]
		for row in CALLS[cursor]:radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":5 if radio.is_empty() else 6,"values":[CALL_AFTER_MS if radio.is_empty() else radio.size()-1]})
		return {"actor_count":0,"ship_groups":[],"radio":radio,"success":{"kind":"elapsed","after_ms":ADVANCE_AFTER_MS},"story":_advance(cursor),"turn_hostile":{}}
	var groups:=[];var first:=0
	for row in CASTS[cursor]:
		var hostile: bool=row[3]
		var group:={"first_actor":first,"end_actor":first+int(row[0]),"faction":int(row[1]),
			"population_group":"story","origin":"zero","position":{"kind":"player_offset","offset":Vector3(-6000,-2000,6000),"bound":Vector3(12000,4000,12000)},
			"ship_state":{"mode":0,"active":true,"targeting_blocked":false},
			"policy":{"initial_hostile":hostile,"updated_hostile":hostile,"friendly":not hostile}}
		if int(row[2])==LARGE_HULL:group.merge({"subtype":1,"population_group":"freighter","ship_state":{"mode":0,"active":true,"targeting_blocked":false,"cruise_enabled":false},"position":{"kind":"player_offset","offset":Vector3(-8000,-3000,12000),"bound":Vector3(16000,6000,16000)}},true)
		else:group.hull_catalogue_id=int(row[2])
		groups.append(group)
		first+=int(row[0])
	var at_target: bool=int(job.station_id)==int(job.target_station_id)
	var arrives: bool=at_target if int(job.kind)==156 else not at_target
	return {"actor_count":first,"ship_groups":groups,"radio":_radio(cursor,0),
		"success":{"kind":"elapsed","after_ms":ADVANCE_AFTER_MS} if arrives else {"kind":"never"},
		"story":_advance(cursor),"turn_hostile":TURN_HOSTILE_AFTER.get(cursor,{}).duplicate(true)}

static func _combat_recipe(job: Dictionary) -> Dictionary:
	var cursor:=int(job.campaign_cursor)
	var plan: Dictionary=COMBAT[cursor]
	var groups:=[];var first:=0;var targets:=[];var escorts:=0
	# A static object (the pirate outpost) is actor 0. It is not an enemy for
	# the objective count; the sleeping pirates around it wake near it.
	if plan.has("static"):
		groups.append({"first_actor":0,"end_actor":1,"faction":8,"origin":"zero","name_text_id":int(plan.static.name_text_id),
			"static_object":{"model":int(plan.static.model),"jitter":int(plan.static.jitter)},
			"ship_state":{"mode":5,"active":false,"targeting_blocked":true},"policy":{"initial_hostile":true,"updated_hostile":true}})
		first=1
	for row in plan.groups:
		var escort: bool=row[3]=="escort"
		var group:={"first_actor":first,"end_actor":first+int(row[0]),"faction":int(row[1]),"population_group":"story","origin":"zero",
			"ship_state":{"mode":5,"active":false,"targeting_blocked":true},
			"policy":{"initial_hostile":not escort,"updated_hostile":not escort,"friendly":escort}}
		if int(row[2])>=0:group.hull_catalogue_id=int(row[2])
		if escort:
			escorts+=int(row[0])
			group.position={"kind":"player_offset","offset":Vector3.ZERO,"bound":Vector3(7000,7000,7000)}
			group.route_start=int(row[4])
			group.ship_state.hull_override=ESCORT_HULL
		else:
			var scatter: Array=plan.get("scatter",[-1500,3000])
			group.position={"kind":"path_scatter","index":int(row[4]),"offsets":[scatter[0],scatter[0],scatter[0]],"bounds":[scatter[1],scatter[1],scatter[1]]}
			targets.append_array(range(first,first+int(row[0])))
		groups.append(group)
		first+=int(row[0])
	var success:={"kind":18,"first_actor":targets.min(),"end_actor":targets.max()+1}
	if plan.has("success_count"):success.count=int(plan.success_count)
	return {"actor_count":first,"ship_groups":groups,"placement":{"kind":"points","points":plan.points.duplicate()},
		"radio":_radio(cursor,int(plan.get("success_count",targets.size()))),"success":success,
		"story":_advance(cursor),"turn_hostile":{},"disarm_on_advance":[targets.min(),targets.max()+1] if plan.get("disarm",false) else []}

## Hidden ships wait far off-scene, where nothing wakes them, until a
## "show" or "place" action brings them in.
const HIDDEN_PARK:={"kind":"player_offset","offset":Vector3(1000000,1000000,1000000),"bound":Vector3(1,1,1)}

static func _scripted_recipe(cursor: int) -> Dictionary:
	var plan: Dictionary=SCRIPTED[cursor];var groups:=[];var first:=0;var cloakers:=[];var wakes:=[]
	for row in plan.groups:
		var friendly: bool=row.friendly
		if row.has("static"):
			groups.append({"first_actor":first,"end_actor":first+1,"faction":int(row.faction),"origin":"zero","name_text_id":int(row.name_text_id),
				"static_object":_placed_static(plan,row).merged({"hull_override":int(row.hull)} if row.has("hull") else {}),"ship_state":{"mode":5,"active":false,"targeting_blocked":true,"hidden":row.get("hidden",false)},
				"policy":{"initial_hostile":not friendly,"updated_hostile":not friendly,"friendly":friendly}})
			first+=1;continue
		var group:={"first_actor":first,"end_actor":first+int(row.count),"faction":int(row.faction),"population_group":"story","origin":"zero",
			"ship_state":{"mode":5,"active":false,"targeting_blocked":true} if row.get("sleeping",false) else {"mode":0,"active":true,"targeting_blocked":false},"route_start":int(row.get("route_start",-1)),"route_loop":row.get("route_loop",[]).duplicate(),
			"policy":{"initial_hostile":not friendly,"updated_hostile":not friendly,"friendly":friendly},
			"position":row.position.duplicate() if row.has("position") else HIDDEN_PARK.duplicate() if row.get("hidden",false) else {"kind":"path_scatter","index":int(row.get("index",0)),"offsets":row.offsets.duplicate(),"bounds":row.bounds.duplicate()}}
		if row.has("name_text_id"):group.name_text_id=int(row.name_text_id)
		if int(row.get("hull",-1))>=0:group.hull_catalogue_id=int(row.hull)
		if row.has("hull_override"):group.ship_state.hull_override=int(row.hull_override)
		if row.has("hull_scale"):group.ship_state.hull_scales=[float(row.hull_scale)]
		# Unharmable story ships (144/145) and a hull floor (157: Harval stays above 20%).
		if row.get("unharmable",false):group.ship_state.hull_override=ESCORT_HULL
		if row.has("hull_floor"):group.ship_state.hull_floor=float(row.hull_floor)
		# 114: pirates hidden at the field's asteroids (the middle ones first).
		if row.get("position",{}).get("kind","")=="asteroids":group.position={"kind":"scenery_midpoint","offset":Vector3.ZERO}
		if row.has("wake_range"):wakes.append({"first_actor":first,"end_actor":first+int(row.count),"range":float(row.wake_range),"all_range":float(row.get("wake_all_range",row.wake_range))})
		if row.has("ship_state"):group.ship_state.merge(row.ship_state,true)
		# A transport of the group's race (the faction's freighter hull and assembly).
		if row.get("freighter",false):
			group.merge({"subtype":1,"population_group":"freighter"},true);group.ship_state.cruise_enabled=false
		# Race-10 stealth fighters cloak on their own unless the row says not.
		if int(row.faction)==10 and row.get("cloaking",true):cloakers.append_array(range(first,first+int(row.count)))
		groups.append(group);first+=int(row.count)
	var radio:=[]
	for row in plan.radio:radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":row[3],"values":row[4].duplicate()})
	var result: Array=RESULT_RADIO.get(cursor,Campaign.Dialogue.RESULT.get(cursor,[]) if cursor in IN_FLIGHT_RESULTS else [])
	var after: Array=plan.get("result_after",[])
	for index in result.size():
		var row: Array=result[index];var own: bool=index==0 and not after.is_empty()
		radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":int(after[0]) if own else 6,"values":after[1].duplicate() if own else [radio.size()-1]})
	# Story docking points: people board or leave here while the player is docked.
	var docks:={};var actor:=0
	for row in plan.groups:
		if row.has("dock"):docks[actor]={"mode":row.dock,"dockable":row.get("dockable",true),"transfer":row.get("dockable",true)}
		actor+=1 if row.has("static") else int(row.count)
	return {"actor_count":first,"ship_groups":groups,"placement":{"kind":"points","points":plan.points.duplicate()},"radio":radio,"docks":docks,"shuttles":plan.get("shuttles",{}).duplicate(true),"cloakers":cloakers,"proximity_wakes":wakes,"player_route":plan.get("player_route",{}).duplicate(),
		"success":plan.success.duplicate(),"failure":plan.get("failure",{"kind":"never"}).duplicate(),"story":_advance(cursor),"turn_hostile":plan.get("turn_hostile",{}).duplicate(),"radio_actions":plan.get("radio_actions",[]).duplicate(true),"timed_actions":plan.get("timed_actions",[]).duplicate(true),"asteroid_ore":int(plan.get("asteroid_ore",-1)),"gas_clouds":plan.get("gas_clouds",{}).duplicate(true)}

## A static row with an offset stands at its point plus that offset (80: the
## battlestation and its weak points); without one it keeps the origin.
static func _placed_static(plan: Dictionary,row: Dictionary) -> Dictionary:
	var placed: Dictionary=row.static.duplicate()
	if placed.has("offset"):placed.offset=Vector3(plan.points[int(row.get("index",0))])+Vector3(placed.offset)
	return placed

static func _convoy_recipe(job: Dictionary) -> Dictionary:
	var cursor:=int(job.campaign_cursor);var plan: Dictionary=CONVOY[cursor]
	var mask:=int(job.cleared_mask) | (1<<int(job.convoy_index))
	var left:=0
	for index in plan.stations.size():
		if not mask & (1<<index):left+=1
	var neutral:={"initial_hostile":false,"updated_hostile":false,"friendly":false}
	var state:={"mode":0,"active":true,"targeting_blocked":false}
	var groups:=[
		{"first_actor":0,"end_actor":1,"faction":int(job.faction),"subtype":1,"population_group":"freighter","origin":"zero",
			"ship_state":state.merged({"cruise_enabled":false}),"policy":neutral.duplicate(),
			"position":{"kind":"path_scatter","index":0,"offsets":[-15000,-1500,-25000],"bounds":[30000,3000,50000]}},
		{"first_actor":1,"end_actor":1+CONVOY_ESCORTS,"faction":int(job.faction),"population_group":"story","origin":"zero",
			"ship_state":state.duplicate(),"policy":neutral.duplicate(),"route_start":0,
			"position":{"kind":"path_scatter","index":0,"offsets":[-4000,-1500,-4000],"bounds":[8000,3000,8000]}}]
	# Text for this station: 2174/2176/2178 on approach, 2175/2177 when the
	# transport dies; the last station ends with the result line instead.
	var approach:=int(plan.approach_text)-2*(left+1);var destroyed:=int(plan.destroyed_text)-2*left
	var radio:=[{"speaker_id":0,"text_id":approach,"voice_event_id":int(plan.voices[approach]),"condition":29,"values":[0,CONVOY_RANGE]}]
	var last: Array=plan.final if left==0 else [0,destroyed,int(plan.voices[destroyed])]
	radio.append({"speaker_id":int(last[0]),"text_id":int(last[1]),"voice_event_id":int(last[2]),"condition":1,"values":[0]})
	var story:=_advance(cursor) if left==0 else {"from_cursor":cursor,"campaign_cursor":cursor,"mission":Campaign.mission(cursor),"previous_mission":Campaign.mission(cursor)}
	story.progress={"story_stations_mask":mask}
	return {"actor_count":1+CONVOY_ESCORTS,"ship_groups":groups,"placement":{"kind":"points","points":[Vector3(95000,-4500,145000)]},
		"radio":radio,"success":{"kind":18,"first_actor":0,"end_actor":1},"story":story,"turn_hostile":{"radio_index":0},
		"story_excluded_actors":[0]}

## A search site: Keith's opener at 1.5 s, then a "no reading" line; when
## it ends the station counts as searched (the story stays at the cursor).
## Assumption: the lines are picked per station (random in the original).
static func _search_recipe(job: Dictionary) -> Dictionary:
	var cursor:=int(job.campaign_cursor);var plan: Dictionary=SEARCH_SITES[cursor]
	var roll:=absi(hash([cursor,int(job.station_id)]))
	var opener: Array=plan.openers[roll%plan.openers.size()];var miss: Array=plan.misses[(roll/7)%plan.misses.size()]
	var radio:=[{"speaker_id":0,"text_id":int(opener[0]),"voice_event_id":int(opener[1]),"condition":5,"values":[1500]},
		{"speaker_id":0,"text_id":int(miss[0]),"voice_event_id":int(miss[1]),"condition":6,"values":[0]}]
	var story:={"from_cursor":cursor,"campaign_cursor":cursor,"mission":Campaign.mission(cursor),"previous_mission":Campaign.mission(cursor)}
	story.progress={"story_stations_mask":int(job.cleared_mask) | (1<<int(job.search_index))}
	return {"actor_count":0,"ship_groups":[],"radio":radio,"success":{"kind":"radio_finished","index":1},"story":story,"turn_hostile":{}}

static func _radio(cursor: int,targets: int) -> Array:
	var radio:=[]
	for row in RADIO.get(cursor,[]):radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":row[3],"values":[row[4]]})
	var result: Array=RESULT_RADIO.get(cursor,[])
	for index in result.size():
		var row: Array=result[index]
		var after: Array=[20,targets] if index==0 else [6,radio.size()-1]
		radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":after[0],"values":[after[1]]})
	return radio

## Khador Drive rules a story flight sets (owner: the drive's mission check).
## allow: usable whatever the mission kind; destination: the only jump, with
## no star map (-1 = the alien world).
const DRIVE:={78:{"allow":true,"destination":-1}}

static func drive_rule(cursor: int) -> Dictionary:return DRIVE.get(cursor,{}).duplicate()

## Story in the alien world. 79: arriving there, "Let's try this again!"
## at 6 s; the story reaches 80 and the drive's way out leads to Kothar.
## Assumptions: the ordinary alien-world fighters stand in for the seven
## Void ships; the cursor moves as the player leaves (the original moves it
## at 5 s, which the player cannot see in flight).
## 81: Alice stranded; after the last line the drive jumps back to Kothar
## by itself ("auto") and the story reaches 82 there.
## Assumptions (81): the player is not hidden or made unharmable, the camera is
## the normal flight camera, the ordinary alien-world ships stand in for the
## eight VoidX and the Valkyrie is not drawn; the player docks at Kothar.
const VOID_RADIO:={79:[[0,2402,1531,5,[6000]]],
	81:[[26,2421,1544,5,[16000]],[31,2422,1545,6,[0]],[26,2423,1546,6,[1]],[26,2424,1547,6,[2]]],
	147:[[0,2977,2170,5,[7000]],[0,2978,2171,6,[0]],[26,2979,1949,6,[1]],[0,2980,1950,6,[2]],[26,2981,1951,6,[3]],[0,2982,1952,6,[4]],
		[26,2983,1953,6,[5]],[0,2984,1954,6,[6]],[26,2985,1955,6,[7]],[0,2986,1956,6,[8]]],
	152:[[0,3009,1965,5,[5000]],[26,3010,1966,6,[0]],[26,3011,1967,6,[1]],[0,3012,1968,6,[2]],[26,3013,1969,6,[3]],[0,3014,1970,6,[4]],
		[26,3015,1971,6,[5]],[0,3016,1972,6,[6]]]}
const VOID_EXIT:={79:{"campaign_cursor":80,"station_id":100},81:{"campaign_cursor":82,"station_id":100,"auto":true},
147:{"campaign_cursor":148,"station_id":-1},154:{"campaign_cursor":155,"station_id":-1,"auto":true},152:{"campaign_cursor":153,"station_id":-1}}
## A story that reaches this cursor in flight jumps there at once, without
## fuel (80's battle ends -> the alien world for 81).
const STORY_JUMP:={81:{"destination":-1}}

## A story move (Campaign.MOVE_ON_ENTRY) reached in flight is the same free
## jump. Assumption: the drive's jump stands in for the original's gate
## arrival or docking; the player docks themselves after a "docked" move.
static func story_jump(cursor: int) -> Dictionary:
	if STORY_JUMP.has(cursor):return STORY_JUMP[cursor].duplicate()
	var move: Dictionary=Campaign.story_move(cursor)
	# Station -1 (155): back through the last docked station's gate, which the
	# Void's ordinary way out already does; no jump.
	return {} if move.is_empty() or int(move.station_id)<0 else {"destination":int(move.station_id)}

static func void_radio(cursor: int) -> Array:
	var rows:=[]
	for row in VOID_RADIO.get(cursor,[]):rows.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":row[3],"values":row[4].duplicate()})
	return rows

static func void_exit(cursor: int) -> Dictionary:return VOID_EXIT.get(cursor,{}).duplicate()

static func _advance(cursor: int) -> Dictionary:
	var next:=Campaign.next_cursor(cursor)
	var advance:={"from_cursor":cursor,"campaign_cursor":next,"mission":Campaign.mission(next),"previous_mission":Campaign.mission(cursor)}
	# Entering the next mission may open a system (mission 62 opens Kothar's).
	if STORY_UNLOCKS.has(cursor):advance.unlock_system_ids=STORY_UNLOCKS[cursor].duplicate()
	if Campaign.REMOVED_GOODS.has(next):advance.story_removed_goods=Campaign.REMOVED_GOODS[next].duplicate(true)
	if Campaign.UNVISIT.has(next):advance.story_unvisit=Campaign.UNVISIT[next].duplicate()
	if Campaign.STORY_STATUS.has(next):advance.story_status=int(Campaign.STORY_STATUS[next])
	if Campaign.MOVE_ON_ENTRY.has(next):advance.story_move=Campaign.MOVE_ON_ENTRY[next].duplicate()
	return advance
