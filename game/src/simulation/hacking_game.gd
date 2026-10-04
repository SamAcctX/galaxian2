extends RefCounted
## Supernova hacking puzzle: a 3x2 board of symbol tiles to arrange into the
## target pattern with two buttons. Cells: 0 1 2 on top, 3 4 5 below. Left
## turns the left 2x2 block clockwise, right the right block. A turn slides
## for 300 ms; a solved board blinks 1.5 s before the hack counts as won.
## There is no way to lose; undocking simply drops the puzzle.
const Random=preload("res://src/simulation/seeded_random.gd")

const TURN_MS:=300
const WIN_BLINK_MS:=1500
const BLINK_STEP_MS:=100
## Each button moves the tile in the first cell to the second, and so on.
const CYCLES:={"left":[0,1,4,3],"right":[1,2,5,4]}
## Symbol pools per difficulty (1 at cursor 91, 4 elsewhere).
const MIN_DIFFICULTY:=1
const MAX_DIFFICULTY:=4

var error:=""
var _state:={}

## A fresh random puzzle that needs more than `difficulty` moves to solve.
func configure(difficulty: int,seed_value: int) -> bool:
	error=""
	if difficulty<MIN_DIFFICULTY or difficulty>MAX_DIFFICULTY:return _reject("Unsupported hacking difficulty")
	var random:=Random.new();random.seed_from(seed_value)
	var pool:=_pool(difficulty,random)
	# Shuffle the pool into the target layout.
	for index in range(pool.size()-1,0,-1):
		var other:=random.next_int(index+1);var held: int=pool[index];pool[index]=pool[other];pool[other]=held
	var board:=pool.duplicate()
	# Scramble: alternate right/left turns, 1 or 2 quarter turns each, until
	# the board can't be solved in `difficulty` moves or fewer.
	var attempts:=0
	while _solvable_within(board,pool,difficulty):
		for step in 2*difficulty:
			var button:="right" if step%2==0 else "left"
			for turn in 1+random.next_int(2):board=_turned(board,button)
		attempts+=1
		if attempts>1000:return _reject("The hacking puzzle could not be scrambled")
	_state={"difficulty":difficulty,"target":pool,"board":board,"turning":"","turn_ms":0,"solved_ms":-1,"won":false,"moves":0}
	return true

func snapshot() -> Dictionary:return _state.duplicate(true)

## One button press; ignored while a turn slides or once solved.
func press(button: String) -> bool:
	error=""
	if _state.is_empty() or not CYCLES.has(button):return _reject("Unknown hacking button")
	if busy():return false
	_state.turning=button;_state.turn_ms=0;_state.moves=int(_state.moves)+1
	return true

func busy() -> bool:return _state.is_empty() or not String(_state.turning).is_empty() or int(_state.solved_ms)>=0

func advance(delta_ms: int) -> void:
	if _state.is_empty() or _state.won:return
	if not String(_state.turning).is_empty():
		_state.turn_ms=int(_state.turn_ms)+delta_ms
		if int(_state.turn_ms)>=TURN_MS:
			_state.board=_turned(_state.board,_state.turning);_state.turning="";_state.turn_ms=0
			if _state.board==_state.target:_state.solved_ms=0
		return
	if int(_state.solved_ms)>=0:
		_state.solved_ms=int(_state.solved_ms)+delta_ms
		if int(_state.solved_ms)>=WIN_BLINK_MS:_state.won=true

## While solved, the tiles alternate normal and highlight art every 100 ms.
func highlighted() -> bool:return int(_state.get("solved_ms",-1))>=0 and (int(_state.solved_ms)/BLINK_STEP_MS)%2==0

func won() -> bool:return bool(_state.get("won",false))

static func _pool(difficulty: int,random: RefCounted) -> Array:
	match difficulty:
		1:return [0,0,1,1,2,2]
		2:return [0,1,2,3,random.next_int(4),random.next_int(4)]
		3:return [0,1,2,3,4,random.next_int(5)]
	return [0,1,2,3,4,5]

static func _turned(board: Array,button: String) -> Array:
	var cycle: Array=CYCLES[button];var next:=board.duplicate()
	for index in cycle.size():next[cycle[(index+1)%cycle.size()]]=board[cycle[index]]
	return next

## Breadth-first: can the board reach the target in at most `moves` presses?
static func _solvable_within(board: Array,target: Array,moves: int) -> bool:
	var frontier:=[board];var seen:={str(board):true}
	for depth in moves+1:
		var next:=[]
		for layout in frontier:
			if layout==target:return true
			for button in CYCLES:
				var turned:=_turned(layout,button)
				if not seen.has(str(turned)):seen[str(turned)]=true;next.append(turned)
		frontier=next
	return false

func _reject(message: String) -> bool:
	error=message;return false
