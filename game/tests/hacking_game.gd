extends SceneTree
## The hacking puzzle: fresh puzzles need more than their difficulty in moves,
## each button turns its block clockwise, and a solved board wins after 1.5 s.
const Hacking=preload("res://src/simulation/hacking_game.gd")
var checks:=0
var failures:=0

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)

func _initialize() -> void:
	for difficulty in [1,4]:
		for seed_value in 20:
			var game:=Hacking.new()
			check(game.configure(difficulty,seed_value),game.error)
			var state: Dictionary=game.snapshot()
			check(state.board!=state.target and not Hacking._solvable_within(state.board,state.target,difficulty),"A fresh puzzle is solvable in %d moves"%difficulty)
			if difficulty==1:check(state.target.count(0)==2 and state.target.count(2)==2,"Difficulty 1 is three pairs")
			else:check(state.target.duplicate().has(5) and state.target.count(5)==1,"Difficulty 4 uses six symbols")
	# Left: 0->1, 1->4, 4->3, 3->0.
	check(Hacking._turned([0,1,2,3,4,5],"left")==[3,0,2,4,1,5],"The left button turns the left block clockwise")
	check(Hacking._turned([0,1,2,3,4,5],"right")==[0,4,1,3,5,2],"The right button turns the right block clockwise")
	# Solve one puzzle by search, pressing through the timed turns.
	var game:=Hacking.new();game.configure(4,7)
	var path:=solve(game.snapshot().board,game.snapshot().target)
	check(not path.is_empty(),"The puzzle has a solution")
	for button in path:
		check(game.press(button),"A press was refused")
		check(not game.press("left"),"A press during a turn was accepted")
		game.advance(299);check(game.snapshot().turning==button,"The turn ended early")
		game.advance(1)
	check(game.snapshot().board==game.snapshot().target and not game.won(),"The solved board won before the blink")
	check(not game.press("left"),"A press after solving was accepted")
	game.advance(1499);check(not game.won(),"The blink ended early")
	game.advance(1);check(game.won(),"The solved puzzle did not win after 1.5 s")
	print("Hacking game: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)

func solve(board: Array,target: Array) -> Array:
	var queue:=[[board,[]]];var seen:={str(board):true}
	while not queue.is_empty():
		var row: Array=queue.pop_front()
		if row[0]==target:return row[1]
		for button in ["left","right"]:
			var next: Array=Hacking._turned(row[0],button)
			if not seen.has(str(next)):seen[str(next)]=true;queue.append([next,row[1]+[button]])
	return []
