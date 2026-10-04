extends RefCounted
## First-visit help windows at stations (verified ModStation::OnKeyPress):
## the first time in a game run that the player opens a station screen, a
## one-button help window explains it. Ids are the touch texts; the desktop
## variants come from the content's desktop text table.
const SCREENS:={"hangar":611,"lounge":616,"map":617,"missions":624,"status":629}

static func text_id(screen: String) -> int:return int(SCREENS.get(screen,-1))
