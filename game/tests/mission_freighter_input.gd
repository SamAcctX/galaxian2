extends "res://tests/mission_arrival_input.gd"
## Ordinary input earns the freighter defeat and consumes the actual Host exit.
## The preceding gate/portal fixture remains detached, not an earned journey.
const LossDriver=preload("res://tests/fixtures/mission_freighter_loss_driver.gd")
var loss_app: Control

func verify_component(world: RefCounted) -> void:
	var entry: RefCounted=world.entry_owner();var context:=Context.new()
	if not context.admit(bindings,catalogues,entry.snapshot().context,entry.equipment_owner().snapshot().loadout):check(false,context.error);return
	var frame:=FlightFrame.new()
	if not frame.configure(bindings,catalogues,library,context,world):check(false,frame.error);return
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	loss_app=await make_host(frame)
	if loss_app==null:return
	var driver:=LossDriver.new()
	var passed: bool=await driver.run(loss_app,root,now_us,check,capture_loss)
	if passed:print("Native input-driven freighter loss -> root acknowledgement -> actual Host exit; detached earlier entry, no earned Resume claim")
	loss_app.free();await process_frame

func capture_loss(label: String) -> void:
	await capture(loss_app,label)
