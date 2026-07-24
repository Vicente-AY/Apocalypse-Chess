extends Sprite2D

const BOARD_SIZE = 5
const CELL_WIDTH = 96

const TEXTURE_HOLDER = preload("res://Scenes/texture_holder.tscn")

const BKnight = preload("res://Assets/BKnight.svg")
const BPawn = preload("res://Assets/BPawn.svg")

const WKnight = preload("res://Assets/WKnight.svg")
const WPawn = preload("res://Assets/WPawn.svg")

const PIECE_MOVE = preload("uid://byowoqtvl4a85")

@onready var pieces = $Pieces
@onready var dots = $Dots
@onready var turn = $Turn



var board : Array
#true white turn, false black turn
var white = true
#true selecting a piece, false selecting the move
var selectPiece = true
#List of all posible moves to the selected piece
var moves = []
var selected_piece : Vector2
var promotion_square = null
var white_pen_points = 0
var black_pen_points = 0
var white_move = []
var black_move = []


# Called when the node enters the scene tree for the first time.
func _ready():
	
	centered = false
	
	#Initial piece position
	#-2 Black Knight
	#-1 Black Pawn
	#2 White Knight
	#1 White Pawn
	board.append([2, 1, 1, 1, 2])
	board.append([1, 0, 0, 0, 1])
	board.append([0, 0, 0, 0, 0])
	board.append([-1, 0, 0, 0, -1])
	board.append([-2, -1, -1, -1, -2])
	
	display_board()

func _input(event):
	
	var hMousePosition = null
	var vMousePosition = null
	var piece_value = 0
	var clicked_own_piece = false
	
	if !(event is InputEventMouseButton && event.pressed && event.button_index == MOUSE_BUTTON_LEFT):
		return
	if is_mouse_out(): 
		selectPiece = true
		delete_available_moves()
		return
	
	hMousePosition = abs(snapped(get_global_mouse_position().x, 0) / CELL_WIDTH)
	vMousePosition = abs(snapped(get_global_mouse_position().y, 0)) / CELL_WIDTH
	
	piece_value = board[vMousePosition][hMousePosition]
	
	if (white && piece_value > 0
	|| !white && piece_value < 0):
		clicked_own_piece = true
	
	if(selectPiece):
		if(clicked_own_piece):
			selected_piece = Vector2(vMousePosition, hMousePosition)
			show_options()
			selectPiece = false;
	else:
		#set_moves(vMousePosition, hMousePosition)
		plan_move(vMousePosition, hMousePosition)

func is_mouse_out():
	if (get_global_mouse_position().x < 0 
	|| get_global_mouse_position().x > 480
	|| get_global_mouse_position().y > 0 
	|| get_global_mouse_position().y < -480):
		return true
	return false

func display_board():
	
	for child in pieces.get_children():
		child.queue_free()
	
	for i in BOARD_SIZE:
		for j in BOARD_SIZE:
			put_pieces(i, j)

func put_pieces(i, j):
	var holder = TEXTURE_HOLDER.instantiate()
	holder.scale = Vector2(2, 2)
	pieces.add_child(holder)
	holder.global_position = Vector2(j * CELL_WIDTH + (CELL_WIDTH / 2), -i * CELL_WIDTH - (CELL_WIDTH / 2))
	
	match board[i][j]:
		-2: holder.texture = BKnight
		-1: holder.texture = BPawn
		2: holder.texture = WKnight
		1: holder.texture = WPawn

func show_options():
	moves = get_moves()
	if moves == []:
		selectPiece = true
		return
	show_available_moves()

#deprecated function
#func set_moves(vMousePos, hMousePos):
	#
	#var count = count_pieces()
	#var moving_piece = null
	#
	#for i in moves:
		#if(!(i.x == vMousePos && i.y == hMousePos)):
			#continue
		#
		#moving_piece = board[selected_piece.x][selected_piece.y]
		#
		#board[vMousePos][hMousePos] = board[selected_piece.x][selected_piece.y]
		#board[selected_piece.x][selected_piece.y] = 0
		#
		##deprecated
		##promotion(count, moving_piece, vMousePos, hMousePos)
		#
		#count = count_pieces()
		#check_victory(count)
		#
		#white = !white
		#display_board()
		#break
	#
	#delete_available_moves()
	#selectPiece = true
	#selected_piece = Vector2(-1, -1)

func plan_move(vMousePos, hMousePos):
	
	var target_move = Vector2(vMousePos, hMousePos)
	
	if(!(moves.has(target_move))):
		delete_available_moves()
		selectPiece = true
		return
	
	if(white):
		white_move.append(selected_piece)
		white_move.append(target_move)
		delete_available_moves()
		selectPiece = true
		white = !white
	else:
		black_move.append(selected_piece)
		black_move.append(target_move)
		delete_available_moves()
		selectPiece = true
		white = !white
		resolve_turn()
		display_board()
		white_move = []
		black_move = []

func resolve_turn():
	
	var white_piece = white_move[0]
	var white_dest = white_move[1]
	var white_piece_val = board[white_piece.x][white_piece.y]
	
	var black_piece = black_move[0]
	var black_dest = black_move[1]
	var black_piece_val = board[black_piece.x][black_piece.y]
	
	var battle_res = 0
	
	if(white_dest == black_dest && board[white_dest.x][white_dest.y] == 0):
		battle_res = white_piece_val + black_piece_val
		match battle_res:
			0: same_piece_battle(white_piece, white_dest, black_piece, black_dest)
			1, -1: different_piece_battle(battle_res, white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val)
	elif(white_dest == black_dest && board[white_dest.x][white_dest.y] != 0):
		match board[white_dest.x][white_dest.y]:
			1, 2: white_recapture(white_piece, white_dest, white_piece_val, black_piece)
			-1, -2: black_recapture(white_piece, black_piece, black_dest, black_piece_val)
	elif(white_dest == black_piece && black_dest == white_piece && white_piece_val == 1 && black_piece_val == -1):
		same_piece_battle(white_piece, white_dest, black_piece, black_dest)
	else:
		var white_ilegal = ilegal_movement(white_piece, white_dest, white_piece_val, black_piece)
		var black_ilegal = ilegal_movement(black_piece, black_dest, black_piece_val, white_piece)
		
		if(!white_ilegal && !black_ilegal):
			simultaneous_movement(white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val)
		elif(!white_ilegal):
			no_battle(white_piece, white_dest, white_piece_val)
		elif(!black_ilegal):
			no_battle(black_piece, black_dest, black_piece_val)
	
	promotion(white_piece_val, white_dest)
	promotion(black_piece_val, black_dest)
	check_victory()

func ilegal_movement(_piece, _dest, _piece_val, enemy_piece):
	
	var destiny_val = board[_dest.x][_dest.y]
	
	if(_piece_val == 1 && check_pawn_move_forward(_piece, _dest, _piece_val)):
		if(_dest != enemy_piece && destiny_val != 0):
			white_pen_points += 1
			print("White tried an illegal pawn capture")
			return true
	if(_piece_val == -1 && check_pawn_move_forward(_piece, _dest, _piece_val)):
		if(_dest != enemy_piece && destiny_val != 0):
			black_pen_points += 1
			print("Black tried an illegal pawn capture")
			return true
	if((_piece_val > 0 && destiny_val > 0)):
		white_pen_points += 1
		print("White commited an illegal move")
		return true
	if(_piece_val < 0 && destiny_val < 0):
		black_pen_points += 1
		print("Black commited an illegal move")
		return true
	
	return false

func check_pawn_move_forward(_piece: Vector2, _dest: Vector2, _piece_val: int):
	
	var direction = Vector2(1,0) if _piece_val > 0 else Vector2(-1,0)
	
	return (_piece + direction) == _dest

func white_recapture(white_piece, white_dest, white_piece_val, black_piece):
	
	board[white_dest.x][white_dest.y] = white_piece_val
	board[white_piece.x][white_piece.y] = 0
	board[black_piece.x][black_piece.y] = 0

func black_recapture(white_piece, black_piece, black_dest, black_piece_val):
	
	board[black_dest.x][black_dest.y] = black_piece_val
	board[black_piece.x][black_piece.y] = 0
	board[white_piece.x][white_piece.y] = 0

func no_battle(_piece, _dest, _piece_val):
	
	board[_piece.x][_piece.y] = 0
	board[_dest.x][_dest.y] = _piece_val

func simultaneous_movement(white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val):
	
	board[white_piece.x][white_piece.y] = 0
	board[black_piece.x][black_piece.y] = 0
	
	board[white_dest.x][white_dest.y] = white_piece_val
	board[black_dest.x][black_dest.y] = black_piece_val

func same_piece_battle(white_piece, white_dest, black_piece, black_dest):
	
	var white_piece_val = board[white_piece.x][white_piece.y]
	var black_piece_val = board[black_piece.x][black_piece.y]
	
	if(check_pawn_move_forward(white_piece, white_dest, white_piece_val)
	&& check_pawn_move_forward(black_piece, black_dest, black_piece_val)
	&& (white_dest == black_piece && black_dest == white_piece)):
			white_pen_points += 1
			black_pen_points += 1
			print("Both tried an illegal pawn capture")
			return
	
	board[white_piece.x][white_piece.y] = 0
	board[black_piece.x][black_piece.y] = 0
		
	board[white_dest.x][white_dest.y] = 0
	board[black_dest.x][black_dest.y] = 0
	
	print("Battle at " + str(white_dest) + " Both eliminated")

func different_piece_battle(battle_res, white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val):
	
	if(battle_res > 0):
		board[white_dest.x][white_dest.y] = white_piece_val
		
		print("Battle at " + str(white_dest) + " White wins the battle!")
	else:
		board[black_dest.x][black_dest.y] = black_piece_val
		
		print("Battle at " + str(black_dest) + " Black wins the battle!")
	
	board[white_piece.x][white_piece.y] = 0
	board[black_piece.x][black_piece.y] = 0

func promotion(moving_piece, _dest):
	
	var count = count_pieces()
	
	#promotion white pawn
	if((moving_piece == 1 && _dest.x == BOARD_SIZE -1) && (board[_dest.x][_dest.y] == 1)):
		if(count["white_knights"] < 2 && count["white_pawns"] > 1):
			board[_dest.x][_dest.y] = 2
			print("Pawn promoted!")
		else:
			print("Ilegal promotion")
			board[_dest.x][_dest.y] = 0
			board[_dest.x -1][_dest.y] = moving_piece
			white_pen_points += 1
	#promotion black pawn
	if((moving_piece == -1 && _dest.x == 0) && (board[_dest.x][_dest.y] == -1)):
		if(count["black_knights"] < 2 && count["black_pawns"] > 1):
			board[_dest.x][_dest.y] = -2
			print("Pawn promoted!")
		else:
			print("Ilegal promotion")
			board[_dest.x][_dest.y] = 0
			board[_dest.x +1][_dest.y] = moving_piece
			black_pen_points += 1

func get_moves():
	
	var _moves
	match abs(board[selected_piece.x][selected_piece.y]):
		1: _moves = get_pawn_moves()
		2: _moves = get_knight_moves()
	return _moves

func get_pawn_moves():
	
	var _moves = []
	var directions
	var count = count_pieces()
	var is_blocked = false
	
	if(white):
		if(selected_piece.x == BOARD_SIZE -2 && count["white_knights"] > 1):
			is_blocked = true
	else:
		if(selected_piece.x == 1 && count["black_knights"] > 1):
			is_blocked = true
	
	if(is_blocked):
		_moves = get_all_posible_moves()
		return _moves
	
	if(white):
		directions = Vector2(1, 0)
	else:
		directions = Vector2(-1, 0)
	
	var pos = selected_piece + directions
	if is_valid_pos(pos):
		_moves.append(pos)
	
	pos = selected_piece + Vector2(directions.x, 1)
	if (is_valid_pos(pos) && (is_enemy(pos) || is_ally(pos))):
		_moves.append(pos)
	pos = selected_piece + Vector2(directions.x, -1)
	if (is_valid_pos(pos) && (is_enemy(pos) || is_ally(pos))):
		_moves.append(pos)
	
	return _moves

func get_all_posible_moves():
	
	var _moves = []
	
	for row in BOARD_SIZE:
		if((white && row == BOARD_SIZE -1) || (!white && row == 0)):
			continue
		for col in BOARD_SIZE:
			var pos = Vector2(row, col)
			if(board[row][col]) == 0:
				_moves.append(pos)
	
	return _moves

func get_knight_moves():
	
	var _moves = []
	var directions = [Vector2(2, 1), Vector2(2, -1), Vector2(1, 2), Vector2(-1, 2),
	Vector2(-2, 1), Vector2(-2, -1), Vector2(-1, -2), Vector2(1, -2)]
	
	for i in directions:
		var pos = selected_piece + i
		if is_valid_pos(pos):
			_moves.append(pos)
		
	return _moves

func is_valid_pos(pos : Vector2):
	
	if (pos.x >= 0 && pos.x < BOARD_SIZE
	&& pos.y >= 0 && pos.y < BOARD_SIZE):
		return true
	return false

func is_empty(pos : Vector2):
	if(board[pos.x][pos.y] == 0):
		return true
	return false

func is_enemy(pos: Vector2):
	if(white):
		if(board[pos.x][pos.y] < 0):
			return true
		return false
	if(!white):
		if(board[pos.x][pos.y] > 0):
			return true
		return false

func is_ally(pos: Vector2):
	if(white):
		if(board[pos.x][pos.y] > 0):
			return true
		return false
	if(!white):
		if(board[pos.x][pos.y] < 0):
			return true
		return false

func show_available_moves():
	for i in moves:
		var holder = TEXTURE_HOLDER.instantiate()
		dots.add_child(holder)
		holder.texture = PIECE_MOVE
		holder.scale = Vector2(0.01, 0.01)
		
		holder.global_position = Vector2(i.y * CELL_WIDTH + (CELL_WIDTH / 2),
		 -i.x * CELL_WIDTH - (CELL_WIDTH / 2))

func delete_available_moves():
	for child in dots.get_children():
		child.queue_free()

func promote(_var : Vector2):
	promotion_square = _var

func count_pieces() -> Dictionary:
	var counts = {
		"white_pawns": 0,
		"white_knights": 0,
		"black_pawns": 0,
		"black_knights": 0
	}
	
	for i in BOARD_SIZE:
		for j in BOARD_SIZE:
			if(board[j][i] == 1):
				counts["white_pawns"] += 1
			if(board[j][i] == -1):
				counts["black_pawns"] += 1
			if(board[j][i] == 2):
				counts["white_knights"] += 1
			if(board[j][i] == -2):
				counts["black_knights"] += 1
	return counts

func check_victory():
	
	var count = count_pieces()
	
	if ((count["black_pawns"] < 1 && count["white_pawns"] < 1) || (white_pen_points > 1 && black_pen_points > 1)):
		print("Draw!")
		get_tree().change_scene_to_file("res://Scenes/draw.tscn")
		return
	if (count["black_pawns"] < 1  || black_pen_points > 1):
		print("White Victory!")
		get_tree().change_scene_to_file("res://Scenes/white_win.tscn")
		return
	if (count["white_pawns"] < 1 || white_pen_points > 1):
		print("Black Victory!")
		get_tree().change_scene_to_file("res://Scenes/black_win.tscn")
		return
