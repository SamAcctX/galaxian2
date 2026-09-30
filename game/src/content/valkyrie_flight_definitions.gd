extends RefCounted
## Valkyrie story flights. The original builds a story cast and radio once when
## a location is entered at a story cursor. The story then moves on silently
## after 10 s in space at the target station (kind 156) or at any other station
## (kind 160); the cast and radio keep running. Combat flights (kind 4) are
## built only at their target station and move on once their objective ships
## are destroyed. Read from the Mac mission factory, radio factory and level
## script.
const Campaign=preload("res://src/content/valkyrie_campaign_definitions.gd")
const FLIGHT_KINDS:=[1,4,6,10,156,160,163,164]
const ADVANCE_AFTER_MS:=10000
## Supernova's people-moving flights (kind 184) are scripted flights at their
## target station.
const STORY_FLIGHT_KINDS:=[184]
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
	73:[[0,2344,1337],[33,2345,1338],[0,2346,1339],[33,2347,1340],[0,2348,1341],[33,2349,1342],[0,2350,1343],[33,2351,1344],[0,2352,1345]]}
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
		[0,2329,1335],[26,2330,1336],[0,2331,1324],[26,2332,1325],[0,2333,1326],[26,2334,1327],[0,2335,1328]]}
## The call starts once the story has moved on (radio holds the result poll).
## Systems opened when a story flight moves the career on: [cursor]: systems.
const STORY_UNLOCKS:={61:[22]}
const CALL_AFTER_MS:=12000
## Carla's one-shot calls, armed while the cursor is in [from, to]: in flight
## outside the alien world, with no freelance job, 12 s into the flight
## (original: 12 s of play after the cursor moved). [speaker, text, voice];
## the first line comes 1.5 s after the call opens. Once heard, the career
## keeps "nag_heard" = from (saved in progress).
const NAG_CALLS:={93:{"to":110,"lines":[[6,3157,1553],[0,3158,1554]]}}
## Once this radio line has finished, every story ship turns hostile and the
## Vossk standing drops to its worst value (standing 0 = 100).
const TURN_HOSTILE_AFTER:={50:{"radio_index":2,"reputation_axis":0,"reputation_value":100}}

## The story job selected at this location, if the career is in a story flight.
static func story_job(bindings: RefCounted,cursor: Variant,station_id: Variant,progress: Dictionary={}) -> Dictionary:
	if not cursor is int or not station_id is int or not Campaign.saved_story(bindings,cursor) or not (CASTS.has(cursor) or COMBAT.has(cursor) or CONVOY.has(cursor) or CALLS.has(cursor) or SCRIPTED.has(cursor)):return {}
	var mission:=Campaign.mission(cursor)
	if mission.is_empty() or (int(mission.kind) not in FLIGHT_KINDS+STORY_FLIGHT_KINDS and not CALLS.has(cursor)):return {}
	if (COMBAT.has(cursor) or SCRIPTED.has(cursor)) and station_id!=int(mission.station_id):return {}
	var job:={"kind":int(mission.kind),"station_id":station_id,"reward":0,"bonus":0,"difficulty":1,"quantity":0,
		"story":false,"story_job":true,"campaign_cursor":cursor,"target_station_id":int(mission.station_id)}
	if CONVOY.has(cursor):
		var index: int=CONVOY[cursor].stations.find(station_id)
		var cleared:=int(progress.get("story_stations_mask",0))
		if index<0 or cleared & (1<<index):return {}
		var faction:=int(load("res://src/content/ordinary_world_definitions.gd").location(bindings,station_id).get("faction",-1))
		if faction<0:return {}
		job.merge({"convoy_index":index,"cleared_mask":cleared,"faction":faction})
	return job

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

static func _scripted_recipe(cursor: int) -> Dictionary:
	var plan: Dictionary=SCRIPTED[cursor];var groups:=[];var first:=0
	for row in plan.groups:
		var friendly: bool=row.friendly
		if row.has("static"):
			groups.append({"first_actor":first,"end_actor":first+1,"faction":int(row.faction),"origin":"zero","name_text_id":int(row.name_text_id),
				"static_object":_placed_static(plan,row),"ship_state":{"mode":5,"active":false,"targeting_blocked":true,"hidden":row.get("hidden",false)},
				"policy":{"initial_hostile":not friendly,"updated_hostile":not friendly,"friendly":friendly}})
			first+=1;continue
		var group:={"first_actor":first,"end_actor":first+int(row.count),"faction":int(row.faction),"population_group":"story","origin":"zero",
			"ship_state":{"mode":5,"active":false,"targeting_blocked":true} if row.get("sleeping",false) else {"mode":0,"active":true,"targeting_blocked":false},"route_start":int(row.get("route_start",-1)),"route_loop":row.get("route_loop",[]).duplicate(),
			"policy":{"initial_hostile":not friendly,"updated_hostile":not friendly,"friendly":friendly},
			"position":row.position.duplicate() if row.has("position") else {"kind":"path_scatter","index":int(row.get("index",0)),"offsets":row.offsets.duplicate(),"bounds":row.bounds.duplicate()}}
		if row.has("name_text_id"):group.name_text_id=int(row.name_text_id)
		if int(row.get("hull",-1))>=0:group.hull_catalogue_id=int(row.hull)
		if row.has("hull_override"):group.ship_state.hull_override=int(row.hull_override)
		if row.has("ship_state"):group.ship_state.merge(row.ship_state,true)
		# A transport of the group's race (the faction's freighter hull and assembly).
		if row.get("freighter",false):
			group.merge({"subtype":1,"population_group":"freighter"},true);group.ship_state.cruise_enabled=false
		groups.append(group);first+=int(row.count)
	var radio:=[]
	for row in plan.radio:radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":row[3],"values":row[4].duplicate()})
	var result: Array=RESULT_RADIO.get(cursor,[])
	var after: Array=plan.get("result_after",[])
	for index in result.size():
		var row: Array=result[index];var own: bool=index==0 and not after.is_empty()
		radio.append({"speaker_id":row[0],"text_id":row[1],"voice_event_id":row[2],"condition":int(after[0]) if own else 6,"values":after[1].duplicate() if own else [radio.size()-1]})
	# Story docking points: people board or leave here while the player is docked.
	var docks:={};var actor:=0
	for row in plan.groups:
		if row.has("dock"):docks[actor]={"mode":row.dock,"dockable":row.get("dockable",true),"transfer":row.get("dockable",true)}
		actor+=1 if row.has("static") else int(row.count)
	return {"actor_count":first,"ship_groups":groups,"placement":{"kind":"points","points":plan.points.duplicate()},"radio":radio,"docks":docks,"shuttles":plan.get("shuttles",{}).duplicate(true),
		"success":plan.success.duplicate(),"failure":plan.get("failure",{"kind":"never"}).duplicate(),"story":_advance(cursor),"turn_hostile":plan.get("turn_hostile",{}).duplicate(),"radio_actions":plan.get("radio_actions",[]).duplicate(true),"timed_actions":plan.get("timed_actions",[]).duplicate(true)}

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
	81:[[26,2421,1544,5,[16000]],[31,2422,1545,6,[0]],[26,2423,1546,6,[1]],[26,2424,1547,6,[2]]]}
const VOID_EXIT:={79:{"campaign_cursor":80,"station_id":100},81:{"campaign_cursor":82,"station_id":100,"auto":true}}
## A story that reaches this cursor in flight jumps there at once, without
## fuel (80's battle ends -> the alien world for 81).
const STORY_JUMP:={81:{"destination":-1}}

## A story move (Campaign.MOVE_ON_ENTRY) reached in flight is the same free
## jump. Assumption: the drive's jump stands in for the original's gate
## arrival or docking; the player docks themselves after a "docked" move.
static func story_jump(cursor: int) -> Dictionary:
	if STORY_JUMP.has(cursor):return STORY_JUMP[cursor].duplicate()
	var move: Dictionary=Campaign.story_move(cursor)
	return {} if move.is_empty() else {"destination":int(move.station_id)}

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
