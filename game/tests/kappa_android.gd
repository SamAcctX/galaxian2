extends SceneTree
## The Kappa chapter's Android-only rules, without imported content.
const Rescue=preload("res://src/content/kappa_rescue_definitions.gd")
const Briefing=preload("res://src/content/mining_briefing_definitions.gd")
var checks:=0
var failures:=0

class Bindings extends RefCounted:
	var source_architecture: String
	var mido_travel: Dictionary
	var mining_briefing: Dictionary
	var desktop: Dictionary
	func desktop_text_id(id: int) -> int:return int(desktop.get(id,id))

func _initialize() -> void:
	verify()
	print("Kappa Android rules: %d checks; %d failures"%[checks,failures])
	quit(1 if failures else 0)

func verify() -> void:
	var instruction:=int(Rescue.MAC_VALUES.instruction.source_text_id)
	# Android has no desktop text: the instruction keeps its touch wording.
	var android:=Bindings.new()
	android.source_architecture="android-armv7";android.mido_travel={"kappa_rescue":Rescue.MAC_VALUES.duplicate(true)}
	android.mining_briefing=Briefing.ANDROID_VALUES.duplicate(true);android.mining_briefing.provenance={}
	var briefing:=Rescue.presentation_briefing(android)
	check(not briefing.is_empty() and int(briefing.events[-1].text_id)==instruction,"The Android rescue lost its touch instruction")
	android.desktop={instruction:instruction+1}
	check(Rescue.presentation_briefing(android).is_empty(),"The Android rescue accepted a desktop substitute")
	# The Mac requires its desktop wording.
	var mac:=Bindings.new()
	mac.source_architecture="x86_64";mac.mido_travel=android.mido_travel;mac.mining_briefing=Briefing.MAC_VALUES.duplicate(true);mac.mining_briefing.provenance={}
	check(Rescue.presentation_briefing(mac).is_empty(),"The Mac rescue went without its desktop instruction")
	mac.desktop={instruction:instruction+1}
	check(not Rescue.presentation_briefing(mac).is_empty(),"The Mac rescue lost its desktop instruction")

func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(message)
