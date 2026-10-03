extends RefCounted
## Supernova Challenge (main menu text 282): a separate timed run with a fixed
## ship against recurring Void fighters. Behaviour notes:
## local/research/supernova-challenge/leads.md.
## Values recovered from the original: ship 46 with three primaries (231, 230,
## 231), equipment 73, 54, 59, 83, 206, 75, 76 and five Patala (216); career
## story cursor 152 at station 111; the player at (-30000, 5000, -80000);
## eight race-10 hull-44 fighters with 300 hull, always hostile, no cloak, at
## fixed points; a 151 s limit; dead fighters return every 7.5 s 50-80 km
## (x, z) and 10-20 km (y) from the player.
const CURSOR:=152
const STATION_ID:=111
const SHIP_ID:=46
## [item, slot within its category, quantity]
const EQUIPMENT:=[[231,0,1],[230,1,1],[231,2,1],[216,0,5],
	[73,0,1],[54,1,1],[59,2,1],[83,3,1],[206,4,1],[75,5,1],[76,6,1]]
const PLAYER_POSITION:=Vector3(-30000,5000,-80000)
const VOID_STARTS:=[Vector3(-44299,1507,-27330),Vector3(-26881,-19046,-8000),Vector3(-46732,-5078,-10557),
	Vector3(-23820,18543,-27063),Vector3(-32703,-1456,-33452),Vector3(-42863,11801,-29354),
	Vector3(-23002,-8641,-5828),Vector3(-46488,5601,-20346)]
const VOID_FACTION:=10
const VOID_HULL:=44
const VOID_MAX_HULL:=300
const DURATION_MS:=151000
const RESPAWN_MS:=7500
## Respawn box around the player: per axis [minimum, maximum] distance, sign random.
const RESPAWN_BOX:=[[50000,80000],[10000,20000],[50000,80000]]
## Kill score: base + bonus x (combo clock / window); combo voice events.
const SCORE:={"window_ms":7500,"kill_base":1000,"kill_bonus":2000,"combo_bonus_unit":1000,"combo_bonus_growth":0.05,
	"voice_base":2281,"voice_last_combo":9,"voice_max":2291,"duration_ms":DURATION_MS}
const TEXT:={"title":282,"highscore":283,"new_highscore":284,"your_score":285,"confirm":287,"play_again":289}

## The story job a challenge career selects at its station (see StoryFlights).
static func job(cursor: Variant,station_id: Variant,progress: Dictionary) -> Dictionary:
	if not progress.get("supernova_challenge",false) or cursor!=CURSOR or station_id!=STATION_ID:return {}
	return {"kind":-1,"station_id":STATION_ID,"reward":0,"bonus":0,"difficulty":1,"quantity":0,"story":false,"story_job":true,
		"campaign_cursor":CURSOR,"target_station_id":STATION_ID,"supernova_challenge":true}

## Recipe parts for the shared contract cast factory and runner.
static func recipe() -> Dictionary:
	var count:=VOID_STARTS.size()
	var group:={"first_actor":0,"end_actor":count,"faction":VOID_FACTION,"population_group":"story","origin":"zero","hull_catalogue_id":VOID_HULL,
		"ship_state":{"mode":0,"active":true,"targeting_blocked":false,"hull_override":VOID_MAX_HULL},
		"policy":{"initial_hostile":true,"updated_hostile":true,"friendly":false},
		"position":{"kind":"positions","points":VOID_STARTS.duplicate()}}
	return {"actor_count":count,"ship_groups":[group],"placement":{"kind":"points","points":[Vector3.ZERO]},"radio":[],
		"timed_actions":[{"after_ms":0,"action":"respawn","first_actor":0,"end_actor":count,"every_ms":RESPAWN_MS,"box":RESPAWN_BOX.duplicate(true)}],
		"player_survives":true,"kill_score":SCORE.duplicate(true),
		"success":{"kind":"never"},"story":{},"turn_hostile":{}}
