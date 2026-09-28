extends "res://tests/khador_application.gd"
## An earned hull flies with one retained audible engine and returns to its save.
func resumed_contract_valid(state: Dictionary) -> bool:return state.campaign_cursor>=18

func verify_free_application() -> void:
	var original: Dictionary=app.session.station_owner().snapshot()
	app.set_player_mode(true)
	if not app.request_departure() or not app.enter_first_flight(now_us,4096,flight_world_seconds()) or not await release_application_flight():check(false,app.status.text);return
	var audio: Node=app.session.flight_audio
	var state: Dictionary=app.session.snapshot()
	check(audio!=null and audio.snapshot().active.has("player_engine"),"Ordinary flight has no retained engine playback")
	if failures:return
	var engine: Node=audio._players.player_engine.node
	check(audio.snapshot().engine_id==state.player_engine.source_id and state.player.ship_id==original.loadout.ship_id,"Flight sound lost the actual purchased hull")
	var before: Dictionary=state.player_engine.duplicate(true)
	for tick in 3:
		app.session.rebase_time(now_us);now_us+=100000
		if not app.session.step(now_us,Vector2(0.5,-0.4),false):check(false,app.session.error);return
		app.present_session()
	check(audio._players.player_engine.node==engine and app.session.snapshot().player_engine.parameters!=before.parameters,"Steering restarted the engine or never reached its parameters")
	var accepted: Dictionary=audio.snapshot()
	var frame: Dictionary=audio.prepare_full_hold(app.session._world)
	check(not frame.is_empty(),audio.error)
	if failures:return
	audio.commit_frame(frame)
	check(frame.get("repeat",false) and audio.snapshot().revision==accepted.revision and audio._players.player_engine.node==engine,"Repeated presentation restarted the retained loop")
	await capture_free_application("ordinary-engine-flight")
	if DisplayServer.get_name()!="headless":await record_engine(engine)
	if failures:return
	app.session.rebase_time(now_us)
	if not await dock_application():return
	var landed: Dictionary=app.session.station_owner().snapshot()
	var saved: Dictionary=app._save_file.load_document(app.station_save_path(),definitions,catalogue,source)
	check(not saved.is_empty() and saved.inventory.loadout==landed.loadout and saved.inventory.cargo==landed.cargo,"Engine flight lost the actual saved hull or cargo")
	check(landed.campaign_cursor==original.campaign_cursor and landed.contracts.credits==original.contracts.credits,"Engine playback changed earned story or credits")
	if not retain_recovery_save("returned"):return
	await capture_free_application("ordinary-engine-return")

func record_engine(engine: Node) -> void:
	# Capture only this real engine's two channels; other scene sounds keep their
	# normal buses. No synthetic clip or warmed engine enters the recording.
	var bus: int=AudioServer.bus_count
	AudioServer.add_bus();AudioServer.set_bus_name(bus,"EngineCapture")
	var recorder:=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus,recorder)
	for channel in engine._channels:channel.node.bus="EngineCapture"
	recorder.set_recording_active(true)
	await create_timer(0.7).timeout
	app.set_user_paused(true)
	check(engine.stream_paused,"Pause left the retained engine running")
	await create_timer(0.4).timeout
	recorder.set_recording_active(false)
	var wave:=recorder.get_recording()
	var peak:=0;var tail:=0
	if wave!=null:
		for at in range(0,wave.data.size(),2):peak=maxi(peak,absi(wave.data.decode_s16(at)))
		var tail_bytes:=int(wave.mix_rate*0.1)*2*(2 if wave.stereo else 1)
		for at in range(maxi(0,wave.data.size()-tail_bytes),wave.data.size(),2):tail=maxi(tail,absi(wave.data.decode_s16(at)))
		wave.save_to_wav(OS.get_environment("GOF2_CAPTURE_DIR").path_join("ordinary-engine.wav"))
	check(wave!=null and peak>0 and tail==0,"The live engine PCM is silent or continues during pause")
	for channel in engine._channels:channel.node.bus="FX"
	AudioServer.remove_bus(bus)
	app.set_user_paused(false)
	check(not engine.stream_paused and app.session.can_control(),"Resume failed to release the retained engine")
