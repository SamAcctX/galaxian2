extends "res://tests/void_ambush_loss_application.gd"
## Reuse the earned departure checkpoint, but take the distinct root-input
## freighter-loss branch. Resume reads only that native isolated checkpoint.
const FreighterLossDriver=preload("res://tests/fixtures/mission_freighter_loss_driver.gd")
var freighter_driver: RefCounted

func verify_free_application() -> void:
	var original:=await enter_earned_ambush()
	if original.is_empty():return
	var input_path:=OS.get_environment("GOF2_SOURCE_SAVE")
	check(retry_station==original and not retry_bytes.is_empty(),"Freighter loss did not retain the exact pre-departure station")
	check(retry_path==app.station_save_path() and retry_path.begins_with(chapter_directory+"/") and retry_path!=input_path,"Freighter retry slot is not isolated from the earned source")
	check(FileAccess.get_file_as_bytes(retry_path)==retry_bytes,"The earned gate/portal prefix changed its retry checkpoint")
	check(app.session.flight_owner().station_response_flags()==void_route_history,"Earned freighter-loss entry discarded the actual navigation history")
	if failures:return
	freighter_driver=FreighterLossDriver.new()
	var passed: bool=await freighter_driver.run(app,root,now_us,check,capture_free_application)
	now_us=freighter_driver.now_us
	if not passed or failures:return
	await capture_free_application("void41-loss-freighter-host-exited")
	check(FileAccess.get_file_as_bytes(retry_path)==retry_bytes,"Freighter failure or Host acknowledgement overwrote the retry checkpoint")
	check(FileAccess.get_sha256(input_path)==OS.get_environment("GOF2_SOURCE_SAVE_SHA256"),"Freighter failure changed the original earned input")
	if failures:return
	resume_application_focus()
	if not app.load_station(now_us):check(false,app._save_notice.text);return
	var resumed: Dictionary=app.session.station_owner().snapshot()
	check(resumed==retry_station,"Freighter-loss Resume changed the exact earned Néhma station")
	for field in ["campaign_cursor","mission","loadout","player_cache","equipment","contracts","station_response_flags"]:
		check(resumed.get(field)==original.get(field),"Freighter-loss Resume changed saved "+field)
	check(not app._transition_failed and app.game_over_result().is_empty(),"Resume kept a stale failure boundary")
	check(app.station_save_path()==retry_path and not app._save_file.recovered_backup,"Resume substituted another checkpoint or backup")
	check(FileAccess.get_file_as_bytes(retry_path)==retry_bytes and FileAccess.get_sha256(input_path)==OS.get_environment("GOF2_SOURCE_SAVE_SHA256"),"Freighter-loss Resume changed a checkpoint or original input")
	await capture_free_application("void41-loss-freighter-resumed-nehma")
	if not failures:
		print("Earned Néhma -> actual gate/mission40/portal -> root-input freighter destruction -> native failure -> Host exit -> exact same-process Néhma Resume; no successor save")
		print("Freighter retry: ",retry_path,"; cursor ",resumed.campaign_cursor," station ",resumed.loadout.station_id,"; shots/contacts ",freighter_driver.shots,"/",freighter_driver.contacts)

func capture_free_application(label: String) -> void:
	# The inherited capture helper can rebase a focus pause. Keep its clock
	# synchronized at every driver capture, not only after the flight returns.
	if freighter_driver!=null:now_us=freighter_driver.now_us
	if label=="void41-nehma40-source":
		await super.capture_free_application("void41-loss-freighter-source")
	elif label=="void41-arrival":
		await super.capture_free_application("void41-loss-freighter-earned-entry")
	elif label.begins_with("freighter-input-"):
		await super.capture_free_application("void41-loss-"+label)
	elif label.begins_with("void41-loss-freighter-"):
		await super.capture_free_application(label)
