extends RefCounted
## Station dialogue sound cues (verified DialogueWindow::loadContent): when a
## page shows one of these texts every playing sound stops and the cue's music
## and sound start. 1822 is the Void attack on Alioth: Void combat music (136)
## and the intro alert (162), both looping until the player leaves.
const CUES:={1822:{"music":136,"sound":162}}

static func cue(text_id: int) -> Dictionary:return CUES.get(text_id,{})
