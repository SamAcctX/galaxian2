extends RefCounted
## Career difficulty: the one owner of which values a career may carry.
## New Game offers Easy, Normal, Hard and Extreme; Extreme asks first.
const EASY:=0.0
const NORMAL:=0.5
const HARD:=1.0
const EXTREME:=1.5
const LEVELS:=[EASY,NORMAL,HARD,EXTREME]
## Original text ids: header, prompt, one label per level, Extreme warning.
const TITLE_TEXT:=505
const PROMPT_TEXT:=506
const LABEL_TEXTS:=[507,508,509,25]
const EXTREME_WARNING_TEXT:=26

## Saves load numbers as floats; an int equal to a level is accepted too.
static func valid(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and LEVELS.has(float(value))

static func label_text(value: float) -> int:
	return LABEL_TEXTS[LEVELS.find(value)] if valid(value) else -1
