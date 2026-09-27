extends Control
## Passive credits view over a separately owned source exterior. The station
## owns its presentation clock and accepts the eventual continuation.
signal skip_requested
const Background=preload("res://src/presentation/main_menu_background.gd")
const RadioResources=preload("res://src/presentation/opening_radio_resources.gd")
const RadioPanel=preload("res://src/presentation/radio_panel.gd")
const Speech=preload("res://src/presentation/station_audio.gd")
const Resources=preload("res://src/content/audio_resources.gd")
const Streams=preload("res://src/presentation/audio_stream_control.gd")
const Presentation=preload("res://src/simulation/mission_presentation.gd")
var error:=""
var background: SubViewport
var radio: Control
var speech: Node
var music: Node
var _spec:={}
var _identity:={}
var _image: TextureRect
var _logo: TextureRect
var _credits: RichTextLabel
var _fade: ColorRect
var _sequence: RefCounted
var _last_background_ms:=0
var _active:=false
var _paused:=false
var _music_gain:=1.0
var _music_fade_ms:=0
var _release_remaining_ms:=0

func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;visible=false
	_image=TextureRect.new();_image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_image.stretch_mode=TextureRect.STRETCH_SCALE
	add_child(_image);_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radio=RadioPanel.new();add_child(radio);radio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_logo=TextureRect.new();_logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;add_child(_logo)
	_credits=RichTextLabel.new();_credits.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_credits.bbcode_enabled=false;_credits.scroll_active=false;_credits.fit_content=true
	_credits.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(_credits)
	_fade=ColorRect.new();_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;_fade.color=Color.BLACK
	add_child(_fade);_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)

func configure(library: RefCounted,bindings: RefCounted,visuals: RefCounted,sequence: RefCounted,spec: Dictionary,station_id: int,camera_seed: int=-1) -> bool:
	if _active or not _identity.is_empty() or not sequence is Presentation or not Presentation.valid_spec(spec):return reject("Prepare credits once with their native presentation")
	var state: Dictionary=sequence.snapshot()
	if state.get("base_content_id")!=bindings.base_content_id or state.get("binding_id")!=bindings.binding_id:return reject("Credits belong to another presentation")
	var menu=preload("res://src/content/main_menu_resources.gd").new()
	var art=preload("res://src/presentation/original_ui.gd").new()
	if spec.logo_image_id!=menu.LOGO_IMAGE_ID or not menu.configure(library,bindings,visuals) or not art.configure(library,bindings,visuals):return reject(menu.error+art.error)
	if int(spec.credits_text_id)>=library.strings.size() or library.strings[int(spec.credits_text_id)].is_empty():return reject("Original credits text is unavailable")
	var resources:=RadioResources.new()
	if not resources.prepare_events(library,bindings,visuals,spec.radio):return reject(resources.error)
	if not resources.portrait_diagnostics.is_empty():return reject("A credits radio portrait is unavailable")
	if not radio.configure(bindings.base_content_id,bindings.binding_id,library.active_language,resources.speakers,int(state.campaign_cursor)) or not radio.configure_art(library,bindings,visuals):return reject(radio.error)
	background=Background.new();add_child(background);background.set_process(false)
	if not background.build(library,bindings,visuals,station_id,camera_seed) or background.selection.station_id!=station_id or not background.build_planets(library,bindings,visuals,int(state.campaign_cursor)) or not background.set_camera_yaw_rate(float(spec.camera_yaw_rate)):return reject(background.error)
	_image.texture=background.get_texture()
	speech=Speech.new();add_child(speech)
	if not speech.configure_events(library,bindings,spec.radio):return reject(speech.error)
	var sounds:=Resources.new()
	if not sounds.configure(library,bindings):return reject(sounds.error)
	var clip: Dictionary=sounds.prepare(int(spec.music_event_id))
	if clip.has("unsupported") or not clip.get("stream") is AudioStream or clip.get("voice",false) or clip.get("spatial",true):return reject("The presentation music is unavailable: "+str(clip.get("unsupported",sounds.error)))
	music=Streams.player(clip.stream,false,"Music");_music_gain=float(clip.gain);_music_fade_ms=int(clip.fade_out_ms)
	music.volume_db=linear_to_db(_music_gain);add_child(music)
	_logo.texture=menu.logo;_credits.text=library.strings[int(spec.credits_text_id)]
	_credits.add_theme_font_override("normal_font",art.font)
	_spec=spec.duplicate(true);_sequence=sequence;_identity={"base_content_id":bindings.base_content_id,"binding_id":bindings.binding_id,"campaign_cursor":state.campaign_cursor}
	return present(sequence)

func activate() -> bool:
	if _identity.is_empty() or _active:return reject("Credits have not been prepared or already started")
	_active=true;visible=true;music.play();set_paused(_paused);_layout()
	return true

func present(sequence: RefCounted) -> bool:
	if _identity.is_empty() or not sequence is Presentation:return reject("Credits require their prepared presentation")
	var state: Dictionary=sequence.snapshot()
	for key in _identity:
		if state.get(key)!=_identity[key]:return reject("Credits changed their content or campaign")
	if int(state.background_elapsed_ms)<_last_background_ms:return reject("Credits cannot display an earlier background frame")
	if not radio.present(state.radio):return reject(radio.error)
	var dialogue:={"visible":state.radio.visible}
	if dialogue.visible:dialogue.voice_event_id=int(_spec.radio[int(state.radio.active_event)].voice_event_id)
	if not speech.present_mission(dialogue):return reject(speech.error)
	background.advance(float(int(state.background_elapsed_ms)-_last_background_ms))
	_last_background_ms=int(state.background_elapsed_ms)
	_image.visible=state.background_swapped
	background.set_active(_active and not _paused and state.background_swapped and not state.complete)
	_logo.visible=state.credits_visible;_credits.visible=state.credits_visible
	_fade.color=Color(0,0,0,float(state.fade_alpha))
	_sequence=sequence;_layout()
	return true

func set_paused(value: bool) -> void:
	_paused=value
	if music!=null:music.stream_paused=value
	if speech!=null:speech.set_paused(value)
	if background!=null:background.set_active(_active and not value and _sequence!=null and _sequence.snapshot().background_swapped and not _sequence.snapshot().complete)

func release() -> void:
	_active=false;visible=false;background.set_active(false);speech.clear()
	_release_remaining_ms=_music_fade_ms
	if _release_remaining_ms==0:music.stop()

func advance_release(milliseconds: int) -> bool:
	if _paused:return _release_remaining_ms>0
	_release_remaining_ms=maxi(0,_release_remaining_ms-maxi(0,milliseconds))
	if _release_remaining_ms==0:music.stop();return false
	music.volume_db=linear_to_db(maxf(0.000001,_music_gain*float(_release_remaining_ms)/float(_music_fade_ms)))
	return true

func _layout() -> void:
	if _sequence==null or _logo.texture==null or size.x<=0 or size.y<=0:return
	background.size=Vector2i(maxi(1,roundi(size.x)),maxi(1,roundi(size.y)))
	var unit:=size.x/1600.0
	var logo_size: Vector2=_logo.texture.get_size()*unit
	var layout: Dictionary=_sequence.credits_layout(size.y/unit,_logo.texture.get_height())
	_logo.size=logo_size;_logo.position=Vector2((size.x-logo_size.x)/2.0,float(layout.logo_y)*unit-logo_size.y/2.0)
	_credits.position=Vector2(50.0*unit,float(layout.credits_y)*unit)
	_credits.size=Vector2(maxf(1,size.x-100.0*unit),5000.0*unit)
	_credits.add_theme_font_size_override("normal_font_size",maxi(8,roundi(20.0*unit)))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _active and not _paused and _sequence.snapshot().can_skip:
		accept_event();skip_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and _active and not _paused and is_visible_in_tree() and _sequence.snapshot().can_skip:
		get_viewport().set_input_as_handled();skip_requested.emit()

func reject(message: String) -> bool:error=message;return false
