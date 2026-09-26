extends "res://tests/dekato_station_resume.gd"
## Actual39 save/load first; then a labelled, unsaved dialogue-only presentation.
const NehmaChecks=preload("res://tests/fixtures/nehma_return_checks.gd")
const NehmaPanel=preload("res://src/presentation/station_dialogue_panel.gd")
const NehmaSpeech=preload("res://src/presentation/station_audio.gd")

func verify_free_application() -> void:
	var addon: Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("GOF2_NEHMA_SOURCE_ARGS")))
	if not addon is Array or addon.size()!=3:check(false,"Supply explicit Néhma source arguments");return
	var file:=StationFile.new();var document:=file.read_document(OS.get_environment("GOF2_SOURCE_SAVE"))
	var guards:=NehmaChecks.new()
	guards.verify(definitions,source,catalogue,document,OS.get_cmdline_user_args()[1],str(addon[1]))
	checks+=guards.checks;failures+=guards.failures
	check(guards.completed,"Retained Néhma source checks did not finish")
	if failures:return
	await super.verify_free_application()
	if failures:return
	var before: Dictionary=app.session.station_owner().snapshot()
	var visit:=NehmaChecks.Visit.new()
	if not visit.configure_station(definitions,source,catalogue,39,NehmaChecks.MISSION39):check(false,visit.error);return
	var context:={"base_content_id":definitions.base_content_id,"binding_id":definitions.binding_id,"station_id":30}
	if not visit.poll_station(context,true):check(false,visit.error);return
	var overlay:=Control.new();root.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label:=Label.new();overlay.add_child(label)
	label.text="Dialogue component only — the saved career remains at Dekato22 / mission39"
	label.position=Vector2(24,104)
	var panel:=NehmaPanel.new();overlay.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not panel.configure_campaign_visit(source,definitions,visual,39,NehmaChecks.MISSION39,true):
		check(false,panel.error);overlay.free();return
	var speech:=NehmaSpeech.new();overlay.add_child(speech)
	if not speech.configure_campaign_visit(source,definitions,39,NehmaChecks.MISSION39,true):
		check(false,speech.error);overlay.free();return
	for index in 10:
		if not panel.present(visit.snapshot()):check(false,panel.error);break
		if not speech.present(index):check(false,speech.error);break
		await process_frame
		check(panel.visible and panel._counter.text=="%d / 10"%(index+1),"The rendered dialogue lost its page counter")
		check(not label.get_global_rect().intersects(app.status.get_global_rect()),"The component caption overlaps the application toolbar")
		check(speech.snapshot().history.size()==index+1 and speech.snapshot().history[-1].source_id==401+index and speech._player!=null and speech._player.playing,"The original station voice did not play in page order")
		var held: Dictionary=visit.snapshot()
		var spoken: Dictionary=speech.snapshot()
		check(speech.present(index) and speech.snapshot()==spoken and visit.snapshot()==held,"Presenting the same voice restarted speech or acknowledged dialogue")
		if index==1:
			speech.set_paused(true)
			check(speech._player.stream_paused and visit.snapshot()==held,"Pausing speech advanced the story")
			speech.set_paused(false)
		if index in [0,4,7,9]:await capture_free_application("nehma39-component-page-%02d"%(index+1))
		if not visit.navigate("next"):check(false,visit.error);break
	check(speech.present(-1) and speech._player==null and not speech.present(10),"Closing dialogue retained speech or admitted a nonexistent eleventh voice")
	check(visit.transition().get("mission")==NehmaChecks.MISSION40 and app.session.station_owner().snapshot()==before,"Component dialogue changed the real career or lost its pending source successor")
	overlay.free()
	check(FileAccess.get_sha256(OS.get_environment("GOF2_SOURCE_SAVE"))==OS.get_environment("GOF2_SOURCE_SAVE_SHA256"),"Presentation changed the earned39 save")
