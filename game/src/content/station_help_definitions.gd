extends RefCounted
## First-visit help windows at stations (verified ModStation::OnKeyPress):
## the first time in a game run that the player opens a station screen, a
## one-button help window explains it. Ids are the touch texts; the desktop
## variants come from the content's desktop text table.
const SCREENS:={"hangar":611,"lounge":616,"map":617,"missions":624,"status":629}

static func text_id(screen: String) -> int:return int(SCREENS.get(screen,-1))

## The "?" button at the top right of station screens (verified Layout header
## help, image 1137): it reopens the current screen's help. Hangar tabs follow
## the original (Ship 612, Shop 611, Blueprints 614, materials of a selected
## blueprint 615, mounted/cargo items 613). The lounge's own text is not
## recovered (its button only explains item info, 632); 616 is used instead.
const BUTTON_IMAGE_ID:=1137
const BUTTON:={"station":633,"ship":612,"shop":611,"cargo":613,"blueprints":614,"materials":615,"lounge":616,"map":617,"missions":624,"status":629}

static func button_text_id(screen: String) -> int:return int(BUTTON.get(screen,-1))
