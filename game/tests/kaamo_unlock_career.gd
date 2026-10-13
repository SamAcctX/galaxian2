extends SceneTree
## The Kaamo Club option on an earned career: saved, restored, one-way.
## Args: content bindings visuals; GOF2_SOURCE_SAVE = an earned station save.
const Library=preload("res://src/content/library.gd")
const Bindings=preload("res://src/content/resource_bindings.gd")
const Catalogues=preload("res://src/content/catalogues.gd")
const Archive=preload("res://src/simulation/station_archive.gd")
const SaveFile=preload("res://src/simulation/station_save_file.gd")
const Kaamo=preload("res://src/content/kaamo_club_definitions.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==3:verify(args)
	else:check(false,"Expected content, bindings and visuals")
	print("Kaamo career checks: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func verify(args: PackedStringArray) -> void:
	var library:=Library.new();var bindings:=Bindings.new();var cat:=Catalogues.new();var archive:=Archive.new();var file:=SaveFile.new()
	if not library.open(args[0]) or not bindings.open(args[1],library.manifest) or not library.select_language("gb") or not cat.open(library):check(false,library.error+bindings.error+cat.error);return
	var document:=file.load_document(OS.get_environment("GOF2_SOURCE_SAVE"),bindings,cat,library)
	if document.is_empty():check(false,file.error);return
	var station: RefCounted=archive.restore(bindings,cat,library,document)
	if station==null:check(false,archive.error);return
	var locations: RefCounted=archive.restored_locations
	var before: Dictionary=station.snapshot()
	check(not station.career_kaamo_unlocked(),"The earned career already owns the club")
	check(station.retain_kaamo_unlock(false) and station.snapshot()==before,"Keeping the club locked changed the career")
	var unlocked: RefCounted=station.fork()
	check(unlocked.retain_kaamo_unlock(true),unlocked.error)
	check(unlocked.career_kaamo_unlocked() and station.snapshot()==before,"The unlock did not stay with its own career")
	var state: Dictionary=unlocked.snapshot()
	check(Kaamo.state(state.progress)==Kaamo.OWNED,"The unlocked career does not own the club")
	var saved: Dictionary=archive.capture(unlocked,bindings,locations)
	check(not saved.is_empty(),archive.error)
	var restored: RefCounted=archive.restore(bindings,cat,library,saved)
	check(restored!=null and restored.career_kaamo_unlocked() and restored.snapshot()==state,"The saved unlock did not survive restoration: "+archive.error)
	check(restored.retain_kaamo_unlock(false) and restored.career_kaamo_unlocked(),"The unlock is not one-way")
	var tampered:=saved.duplicate(true)
	check(clear_option(tampered)>0,"The save does not hold the club option")
	check(archive.restore(bindings,cat,library,tampered)==null,"A save accepted a cleared club option")

## Every saved copy of the option, set to false; returns how many there were.
func clear_option(value: Variant) -> int:
	var count:=0
	if value is Dictionary:
		if value.has("kaamo_unlocked"):value.kaamo_unlocked=false;count+=1
		for child in value.values():count+=clear_option(child)
	elif value is Array:
		for child in value:count+=clear_option(child)
	return count

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
