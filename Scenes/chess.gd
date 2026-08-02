extends Sprite2D

#constantes del juego
const BOARD_SIZE = 5
const CELL_WIDTH = 96

#texturas
const TEXTURE_HOLDER = preload("res://Scenes/texture_holder.tscn")

const BKnight = preload("res://Assets/BKnight.svg")
const BPawn = preload("res://Assets/BPawn.svg")

const WKnight = preload("res://Assets/WKnight.svg")
const WPawn = preload("res://Assets/WPawn.svg")

const PIECE_MOVE = preload("uid://byowoqtvl4a85")

var turn_num = 1

@onready var pieces = $Pieces
@onready var dots = $Dots
@onready var turn = $Turn

@onready var white_scroll: ScrollContainer = $"../white_log/white_scroll"
@onready var white_moves_log: VBoxContainer = $"../white_log/white_scroll/white_moves_log"
@onready var black_scroll: ScrollContainer = $"../black_log/black_scroll"
@onready var black_moves_log: VBoxContainer = $"../black_log/black_scroll/black_moves_log"

@onready var white_ilegal_move_1: Sprite2D = $"../white_log/white_ilegal_move_1"
@onready var white_ilegal_move_2: Sprite2D = $"../white_log/white_ilegal_move_2"
@onready var black_ilegal_move_1: Sprite2D = $"../black_log/black_ilegal_move_1"
@onready var black_ilegal_move_2: Sprite2D = $"../black_log/black_ilegal_move_2"


const LOG_FONT_SIZE = 20

var board : Array
#true white turn, false black turn
var white = true
#true selecting a piece, false selecting the move
var selectPiece = true
#List of all posible moves to the selected piece
var moves = []
#pieza seleccionada por el jugador
var selected_piece : Vector2
var promotion_square = null
#puntos de penalizacion por movimientos ilegales
var white_pen_points = 0
var black_pen_points = 0
#variables que guardan la pieza seleccionada y su destino
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
	
	#posicion del cursor horizonal y vertial
	var hMousePosition = null
	var vMousePosition = null
	#valor de la pieza (1, 2, -1, -2)
	var piece_value = 0
	#si el jugador a seleccionado su porpia pieza
	var clicked_own_piece = false
	
	#si el jugador no presiona el boton izquierdo del raton no hacemos nada
	if !(event is InputEventMouseButton && event.pressed && event.button_index == MOUSE_BUTTON_LEFT):
		return
	#si clica fuera del tablero borramos todo, volvemos al modo de seleccionar pieza y no hacemos nada
	if is_mouse_out(): 
		selectPiece = true
		delete_available_moves()
		return
	
	#si clica en posicion valida guardamos la posición del ratón
	hMousePosition = abs(snapped(get_global_mouse_position().x, 0) / CELL_WIDTH)
	vMousePosition = abs(snapped(get_global_mouse_position().y, 0)) / CELL_WIDTH
	
	#guardamos el valor de la pieza dependiendo de donde a hecho click el jugador
	piece_value = board[vMousePosition][hMousePosition]
	
	#establecemos si el jugador ha clicado en una pieza
	if (white && piece_value > 0
	|| !white && piece_value < 0):
		clicked_own_piece = true
	
	#si estamos en fase de seleccionar pieza y ha clicado una pieza propia
	#guardamos la pieza, mostramos la opciones de movimiento y cambiamos de fase
	if(selectPiece):
		if(clicked_own_piece):
			selected_piece = Vector2(vMousePosition, hMousePosition)
			show_options()
			selectPiece = false;
	#si no estamos en la fase de seleccionar pieza movemos
	else:
		#set_moves(vMousePosition, hMousePosition)
		plan_move(vMousePosition, hMousePosition)

#funcion que establece si el ratón está dentro o fura del tablero
func is_mouse_out():
	if (get_global_mouse_position().x < 0 
	|| get_global_mouse_position().x > 480
	|| get_global_mouse_position().y > 0 
	|| get_global_mouse_position().y < -480):
		return true
	return false

#funcion que muestra el tablero y las piezas
func display_board():
	
	for child in pieces.get_children():
		child.queue_free()
	
	for i in BOARD_SIZE:
		for j in BOARD_SIZE:
			put_pieces(i, j)

#funcion auxiliar que pone las piezas según su textura
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

#funcion que muestra las opciones de movimiento disponibles
func show_options():
	moves = get_moves()
	#si la pieza seleccionada no tiene movimientos volvemos a la fase de seleccion de pieza
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

#funcion que guarda los movimientos de ambos jugadores. recibe el ultimo click hecho por el jugador
func plan_move(vMousePos, hMousePos):
	
	#el ultimo click es donde quiere mover la pieza el jugador
	var target_move = Vector2(vMousePos, hMousePos)
	
	#si el movimiento no es valido borramos las opciones disponibles y volvemos a la seleccion de pieza
	if(!(moves.has(target_move))):
		delete_available_moves()
		selectPiece = true
		return
	
	#si el movimiento es valido guardamos la pieza seleccionada y el movimiento que desea hacer
	#borramos los movimientos, cambiamos el modo a seleccion de pieza y cambiamos de turno
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
		#en caso de acabar el turno de las negras resolvemos el turno, actualizamos las texturas
		#y borramos los movimientos de los jugadores
		resolve_turn()
		display_board()
		white_move = []
		black_move = []

#funcion que realiza los turnos de ambos jugadores simultaneamente con los movimientos establecidos
func resolve_turn():
	
	#sacamos los valores del array para mejor lectura del codigo
	var white_piece = white_move[0]
	var white_dest = white_move[1]
	var white_piece_val = board[white_piece.x][white_piece.y]
	var white_ilegal = false
	var white_ilegal_prom = false
	
	var black_piece = black_move[0]
	var black_dest = black_move[1]
	var black_piece_val = board[black_piece.x][black_piece.y]
	var black_ilegal = false
	var black_ilegal_prom = false
	
	var ilegal_double_pawn_cap = false
	
	#resultado de si dos piezas caen en en la misma posicion
	var battle_res = 0
	
	#si dos piezas caen en la misma casilla y esta está vacia
	if(white_dest == black_dest && board[white_dest.x][white_dest.y] == 0):
		#el resultado de la batalla es la resta de los valroes de las piezas (negras son valores negativos)
		battle_res = white_piece_val + black_piece_val
		#si el resultado da 0 significa que ambos jugadores movieron el mismo tipo de pieza
		#si es 1 o -1, los jugadores movieron piezas diferentes
		match battle_res:
			0: ilegal_double_pawn_cap = same_piece_battle(white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val)
			1, -1: different_piece_battle(battle_res, white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val)
	#si el movimiento se realiza hacia la misma casilla pero esta está ocupada realizamos la recaptura
	elif(white_dest == black_dest && board[white_dest.x][white_dest.y] != 0):
		#si el valor de la casilla es positivo se realiza una recaptura a favor de las blancas
		#si no, recaptura en favor de las negras
		match board[white_dest.x][white_dest.y]:
			1, 2: white_recapture(white_piece, white_dest, white_piece_val, black_piece)
			-1, -2: black_recapture(white_piece, black_piece, black_dest, black_piece_val)
	#si dos peones intentan capturarse a si mismos lo tratamos como una batalla de pieza igual
	elif(white_dest == black_piece && black_dest == white_piece && white_piece_val == 1 && black_piece_val == -1):
		ilegal_double_pawn_cap = same_piece_battle(white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val)
	#si no hay choque entre piezas se realizan los movimientos pertinentes
	else:
		#comprobamos que los movimientos de ambos jugadores son legales
		white_ilegal = ilegal_movement(white_piece, white_dest, white_piece_val, black_piece)
		black_ilegal = ilegal_movement(black_piece, black_dest, black_piece_val, white_piece)
		
		#si ninguno de los jugadores ha realizado un movimiento ilegal realizamos el movimiento simultaneo
		#si solo un jugador ha realizado un movimiento legal, movemos su pieza.
		if(!white_ilegal && !black_ilegal):
			simultaneous_movement(white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val)
		elif(!white_ilegal):
			no_battle(white_piece, white_dest, white_piece_val)
		elif(!black_ilegal):
			no_battle(black_piece, black_dest, black_piece_val)
	
	#al final de ejecutar ambos turnos comprobamos si hay promocion de pieza y si hay ganador
	white_ilegal_prom = promotion(white_piece_val, white_dest)
	black_ilegal_prom = promotion(black_piece_val, black_dest)
	#true/false, blancas/negras
	write_log(white_piece, white_dest, white_piece_val, true, white_ilegal, white_ilegal_prom, ilegal_double_pawn_cap)
	write_log(black_piece, black_dest, black_piece_val, false, black_ilegal, black_ilegal_prom, ilegal_double_pawn_cap)
	turn_num += 1
	check_victory()

#funcion que comprueba si un movimiento es ilegal
func ilegal_movement(_piece, _dest, _piece_val, enemy_piece):
	
	#guardamos el valor de destino (0 significa que esta vacio)
	var destiny_val = board[_dest.x][_dest.y]
	#variable que indica que jugador esta cometiendo el movimiento
	var is_white = null
	
	#si la pieza es un peon y se mueve hacia adelante
	#comprobamos que el destino no es 0 y ademas que no sea la pieza que mueve el rival
	#si es un movimiento ilegal mostramos el indicador en pantalla
	if(_piece_val == 1 && check_pawn_move_forward(_piece, _dest, _piece_val)):
		is_white = true
		if(_dest != enemy_piece && destiny_val != 0):
			white_pen_points += 1
			show_ilegal_moves(is_white)
			print("White tried an illegal pawn capture")
			return true
	#comprobamos lo mismo para las negras
	if(_piece_val == -1 && check_pawn_move_forward(_piece, _dest, _piece_val)):
		is_white = false
		if(_dest != enemy_piece && destiny_val != 0):
			black_pen_points += 1
			show_ilegal_moves(is_white)
			print("Black tried an illegal pawn capture")
			return true
	#comprobamos que la pieza no se mueva a la casilla de una pieza aliada
	if((_piece_val > 0 && destiny_val > 0)):
		is_white = true
		white_pen_points += 1
		show_ilegal_moves(is_white)
		print("White commited an illegal move")
		return true
	if(_piece_val < 0 && destiny_val < 0):
		is_white = false
		black_pen_points += 1
		show_ilegal_moves(is_white)
		print("Black commited an illegal move")
		return true
	
	return false

#metodo que comprueba si la pieza seleccionada se mueve hacia adelante
func check_pawn_move_forward(_piece: Vector2, _dest: Vector2, _piece_val: int):
	
	#ejecutamos por separado un supuesto movimiento hacia adelante
	var direction = Vector2(1,0) if _piece_val > 0 else Vector2(-1,0)
	
	#si el movimiento anterior es igual al destino devolvemos true
	return (_piece + direction) == _dest

#metodo que ejecuta una recaptura blanca
func white_recapture(white_piece, white_dest, white_piece_val, black_piece):
	
	#al ser una recaptura blanca el destino lo mantienen la pieza blanca que se mueve
	board[white_dest.x][white_dest.y] = white_piece_val
	#los origenes de ambos jugadores quedan vacios
	board[white_piece.x][white_piece.y] = 0
	board[black_piece.x][black_piece.y] = 0

#metodo que ejecuta una recaptura negra
func black_recapture(white_piece, black_piece, black_dest, black_piece_val):
	
	#al ser una recaptura negra el destino lo mantiene la pieza que el jugador negro mueve
	board[black_dest.x][black_dest.y] = black_piece_val
	#el origen de las piezas queda vacio
	board[black_piece.x][black_piece.y] = 0
	board[white_piece.x][white_piece.y] = 0

#metodo que ejecuta el movimiento de un jugador si uno de ellos intenta un movimiento ilegal
func no_battle(_piece, _dest, _piece_val):
	
	#vaciamos el origen
	board[_piece.x][_piece.y] = 0
	#añadimos la pieza al destino
	board[_dest.x][_dest.y] = _piece_val

#funcion que ejecuta el movimiento de ambos jugadores y estos no se mueven a la misma casilla
func simultaneous_movement(white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val):
	
	#ambos origienes quedan vacios
	board[white_piece.x][white_piece.y] = 0
	board[black_piece.x][black_piece.y] = 0
	
	#la piezas seleccionadas se añaden al su nueva casilla
	board[white_dest.x][white_dest.y] = white_piece_val
	board[black_dest.x][black_dest.y] = black_piece_val

#funcion que ejecuta un movimiento a la misma casilla con piezas identicas en valor
func same_piece_battle(white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val):
	
	#comprobamos si los dos intentan capturarse los peones de forma ilegal
	if(check_pawn_move_forward(white_piece, white_dest, white_piece_val)
	&& check_pawn_move_forward(black_piece, black_dest, black_piece_val)
	&& (white_dest == black_piece && black_dest == white_piece)):
		#de ser así añadimos puntos de penalizacion a ambos jugadores
			white_pen_points += 1
			black_pen_points += 1
			#mostramos ambos movimientos ilegales en pantalla
			show_ilegal_moves(true)
			show_ilegal_moves(false)
			print("Both tried an illegal pawn capture")
			return true
	
	#en caso contrario eliminamos el origen y destino de ambas piezas
	board[white_piece.x][white_piece.y] = 0
	board[black_piece.x][black_piece.y] = 0
		
	board[white_dest.x][white_dest.y] = 0
	board[black_dest.x][black_dest.y] = 0
	
	print("Battle at " + str(white_dest) + " Both eliminated")
	
	return false

#funcion que ejecuta un movimiento a la misma casilla con piezas de valor diferente
func different_piece_battle(battle_res, white_piece, white_dest, white_piece_val, black_piece, black_dest, black_piece_val):
	
	#si el resultado es mayor que 0 las blancas usaron una pieza de mayor valor
	#sera la pieza blanca quien mantenga la posicion
	if(battle_res > 0):
		board[white_dest.x][white_dest.y] = white_piece_val
		
		print("Battle at " + str(white_dest) + " White wins the battle!")
	#en caso contrario las negras mantienen la posicion
	else:
		board[black_dest.x][black_dest.y] = black_piece_val
		
		print("Battle at " + str(black_dest) + " Black wins the battle!")
	
	#vacioamos el origen de ambas piezas
	board[white_piece.x][white_piece.y] = 0
	board[black_piece.x][black_piece.y] = 0

#funcion que controla las promociones de peones
func promotion(moving_piece, _dest):
	
	#contamos las piezas actualmente en el tablero
	var count = count_pieces()
	var is_white = null
	
	#white pawn promotion
	#comprobamos si el peon ha llegado al final de su tablero
	if((moving_piece == 1 && _dest.x == BOARD_SIZE -1) && (board[_dest.x][_dest.y] == 1)):
		is_white = true
		#establecemos la validez de la promocion en funcion de las reglas de apocapyse chess
		if(count["white_knights"] < 2 && count["white_pawns"] > 1):
			board[_dest.x][_dest.y] = 2
			print("Pawn promoted!")
			return false
		#si no las cumple comete un movimiento ilegal y deshacemos el movimiento realizado
		else:
			print("Ilegal promotion")
			board[_dest.x][_dest.y] = 0
			board[_dest.x -1][_dest.y] = moving_piece
			white_pen_points += 1
			show_ilegal_moves(is_white)
			return true
	#promotion black pawn
	#establecemos lo mismo para las piezas negras variando los valores de referencia
	if((moving_piece == -1 && _dest.x == 0) && (board[_dest.x][_dest.y] == -1)):
		is_white = false
		if(count["black_knights"] < 2 && count["black_pawns"] > 1):
			board[_dest.x][_dest.y] = -2
			print("Pawn promoted!")
			return false
		else:
			print("Ilegal promotion")
			board[_dest.x][_dest.y] = 0
			board[_dest.x +1][_dest.y] = moving_piece
			black_pen_points += 1
			show_ilegal_moves(is_white)
			return true
	
	return false

#funcion que devuelve los movimientos que puede hacer una pieza en funcion de su valor
#si es un valor 1 devolverá los movimientos de un peon, en caso de ser un 2 los del caballero
func get_moves():
	
	var _moves
	match abs(board[selected_piece.x][selected_piece.y]):
		1: _moves = get_pawn_moves()
		2: _moves = get_knight_moves()
	return _moves

#funcion que recoge los movimientos posibles del peon seleccionado
func get_pawn_moves():
	
	var _moves = []
	var directions = Vector2()
	var count = count_pieces()
	var is_blocked = false
	
	#si el jugador selecciona un peon que está al borde de la promoción y tiene dos caballeros
	#este no podrá moverlo al final del tablero, por lo que bloquearemos el movimiento y devolverá
	#los movimientos de la funcion get_all_posible_moves()
	if(white):
		if(selected_piece.x == BOARD_SIZE -2 && count["white_knights"] > 1):
			is_blocked = true
	else:
		if(selected_piece.x == 1 && count["black_knights"] > 1):
			is_blocked = true
	
	if(is_blocked):
		_moves = get_all_posible_moves()
		return _moves
	
	#si el turno es de las blancas las piezas se mueven hacia arriba
	#de lo contrario se mueven hacia abajo
	if(white):
		directions = Vector2(1, 0)
	else:
		directions = Vector2(-1, 0)
	
	#realizamos el supuesto movimiento en una variabla a parte
	var pos = selected_piece + directions
	#si el movimiento está dentro del tablero lo añadimos a la lista de movimientos posibles
	if is_valid_pos(pos):
		_moves.append(pos)
	
	#realizamos otro supuesto de movimiento en diagonal
	pos = selected_piece + Vector2(directions.x, 1)
	#si la posicion es valida y además hay un enemigo o un aliado lo añadimos a la lista de 
	#movimientos posibles
	if (is_valid_pos(pos) && (is_enemy(pos) || is_ally(pos))):
		_moves.append(pos)
	pos = selected_piece + Vector2(directions.x, -1)
	if (is_valid_pos(pos) && (is_enemy(pos) || is_ally(pos))):
		_moves.append(pos)
	
	return _moves

#funcion auxiliar de get_pawn_moves que se ejecuta para poder mover el peon
#a cualquier parte vacia del tablero si este llega a la ultima fila y no cumple
#con las reglas de promocion
func get_all_posible_moves():
	
	var _moves = []
	
	#hacemos un for con las filas
	for row in BOARD_SIZE:
		#establecemos que si es la ultima fila para cada jugador, este no cuente
		#como movimiento posible
		if((white && row == BOARD_SIZE -1) || (!white && row == 0)):
			continue
		#si no es la ultima fila y la casilla está vacia lo añadimos como movimiento posible
		for col in BOARD_SIZE:
			var pos = Vector2(row, col)
			if(board[row][col]) == 0:
				_moves.append(pos)
	
	return _moves

#funcion que devuelve los posibles movimientos del caballero
func get_knight_moves():
	
	var _moves = []
	
	#establecesmo todos los posibles movimientos del caballero
	var directions = [Vector2(2, 1), Vector2(2, -1), Vector2(1, 2), Vector2(-1, 2),
	Vector2(-2, 1), Vector2(-2, -1), Vector2(-1, -2), Vector2(1, -2)]
	
	#recorremos todas las opciones y, si esta esta dentro del tablero lo añadimos
	#a la lista de movimientos posibles
	for i in directions:
		var pos = selected_piece + i
		if is_valid_pos(pos):
			_moves.append(pos)
		
	return _moves

#funcion que establece si un movimiento esta dentro del tablero
func is_valid_pos(pos : Vector2):
	
	if (pos.x >= 0 && pos.x < BOARD_SIZE
	&& pos.y >= 0 && pos.y < BOARD_SIZE):
		return true
	return false

#funcion que establece si una casilla está ocupada por una pieza
func is_empty(pos : Vector2):
	if(board[pos.x][pos.y] == 0):
		return true
	return false

#funcion que establece si una casilla está ocupada por una pieza enemiga
func is_enemy(pos: Vector2):
	if(white):
		if(board[pos.x][pos.y] < 0):
			return true
		return false
	if(!white):
		if(board[pos.x][pos.y] > 0):
			return true
		return false

#funcion que establece si una casilla está ocupada por una pieza aliada
func is_ally(pos: Vector2):
	if(white):
		if(board[pos.x][pos.y] > 0):
			return true
		return false
	if(!white):
		if(board[pos.x][pos.y] < 0):
			return true
		return false

#funcion que muestra sobre la textura del tablero la textura PIECE_MOVE
#para que el jugador vea las posiciones donde se puede mover
func show_available_moves():
	for i in moves:
		var holder = TEXTURE_HOLDER.instantiate()
		dots.add_child(holder)
		holder.texture = PIECE_MOVE
		holder.scale = Vector2(0.01, 0.01)
		
		holder.global_position = Vector2(i.y * CELL_WIDTH + (CELL_WIDTH / 2),
		 -i.x * CELL_WIDTH - (CELL_WIDTH / 2))

#funcion que borra la textura del tablero
func delete_available_moves():
	for child in dots.get_children():
		child.queue_free()

#funcion que establece y devuelve un diccionario y cuenta las piezas del tablero actual
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
#funcion que devuleve los movimientos legales que puede hcaer un peon
func get_pawn_legal_moves(count: Dictionary, piece: Vector2, is_white: bool):
	
	var directions = Vector2()
	var _moves = []
	
	#establecemos la direccion del peon segun el valor del booleano pasado por parametro
	if(is_white):
		directions = Vector2(1, 0)
	else:
		directions = Vector2(-1, 0)
	
	#si la direccion es valida y esta vacia está vacia y no esta moviendo
	#el ultimo peon del jugador a la ultima fila añadimos el movimiento a la lista
	var pos = piece + directions
	if ((is_valid_pos(pos) && is_empty(pos))
		&& !((white && pos.x == BOARD_SIZE -1 && count["white_pawns"] == 1) 
		|| (!white && pos.x == 0 && count["black_pawns"] == 1))):
		_moves.append(pos)
	
	#si el movimiento en diagonal valido y hay un enemigo añadimos el movimiento
	pos = piece + Vector2(directions.x, 1)
	if (is_valid_pos(pos) && (is_enemy(pos))):
		_moves.append(pos)
	pos = piece + Vector2(directions.x, -1)
	if (is_valid_pos(pos) && (is_enemy(pos))):
		_moves.append(pos)
	
	return _moves

#funcion que devuleve la lista de movimientos legales del caballero
func get_knight_legal_moves(piece: Vector2, is_white: bool):
	
	var _moves = []
	var directions = [Vector2(2, 1), Vector2(2, -1), Vector2(1, 2), Vector2(-1, 2),
	Vector2(-2, 1), Vector2(-2, -1), Vector2(-1, -2), Vector2(1, -2)]
	
	#si la posicion es valida y está vacia o ocupada por un enemigo añadimos el posible movimiento
	for i in directions:
		var pos = piece + i
		if (is_valid_pos(pos) && (is_empty(pos) || (is_enemy_of(pos, is_white)))):
			_moves.append(pos)
		
	return _moves

#funcion que determina si una pieza es enemiga en funcion de la posicion que de destino y la pieza seleccionada
func is_enemy_of(pos, is_white):
	
	if(is_white):
		return board[pos.x][pos.y] < 0
	return board[pos.x][pos.y] > 0

#funcion que determina las condiciones de victoria
func check_victory():
	
	#contamos las piezas
	var count = count_pieces()
	
	#si ambos jugadores se quedan sin peones o llegan a dos puntos de penalización al mismo tiempo
	#lo clasificamos como empate y cambiamos la escena a la de empate
	if ((count["black_pawns"] < 1 && count["white_pawns"] < 1) || (white_pen_points > 1 && black_pen_points > 1)):
		print("Draw!")
		get_tree().change_scene_to_file("res://Scenes/draw.tscn")
		return
	#en caso que se eliminen antes todos los peones de un jugador o alguno llege a dos puntos de penalizacion
	#cambiamos la escena para dicho jugador
	if (count["black_pawns"] < 1  || black_pen_points > 1):
		print("White Victory!")
		get_tree().change_scene_to_file("res://Scenes/white_win.tscn")
		return
	if (count["white_pawns"] < 1 || white_pen_points > 1):
		print("Black Victory!")
		get_tree().change_scene_to_file("res://Scenes/black_win.tscn")
		return
	
	#establecemos la otra forma de victoria mediante si tienen o no movimientos legales
	var white_has_move = false
	var black_has_move = false
	var piece = null
	
	#recorremos el tablero
	for i in BOARD_SIZE:
		for j in BOARD_SIZE:
			#cuando encontremos una pieza la seleccionamos
			if (board[i][j] != 0):
				piece = Vector2(i, j)
			#buscamos si la pieza seleccionada tiene movimientos legales o no
			match board[i][j]:
				#pasamos true como parametro si la pieza es blanca, false si es negra
				1: if !(get_pawn_legal_moves(count, piece, true).is_empty()):
					white_has_move = true
				-1: if !(get_pawn_legal_moves(count, piece, false).is_empty()):
					black_has_move = true
				2: if !(get_knight_legal_moves(piece, true).is_empty()):
					white_has_move = true
				-2: if !(get_knight_legal_moves(piece, false).is_empty()):
					black_has_move = true
	
	#regla adicional
	#si ninguno de los jugadores tiene movimientos legales se establecen tablas
	if(!white_has_move && !black_has_move):
		print("Draw!")
		get_tree().change_scene_to_file("res://Scenes/draw.tscn")
	#si un jugador se queda sin movimientos legales ganará el otro jugador
	elif(!white_has_move):
		print("Black Victory!")
		get_tree().change_scene_to_file("res://Scenes/black_win.tscn")
	elif(!black_has_move):
		print("White Victory!")
		get_tree().change_scene_to_file("res://Scenes/white_win.tscn")

#funcion que traduce un vector2 a un movimiento en el tablero
func translate_pos(pos: Vector2):
	
	var cols = ["A", "B", "C", "D", "E"]
	
	var col_letter = cols[int(pos.y)]
	var row_number = str(int(pos.x) +1)
	
	return col_letter + row_number

func write_log(_piece: Vector2, _dest: Vector2, _piece_val: int, is_white: bool, ilegal_m: bool, ilegal_prom: bool, double_pawn_c: bool):
	
	var text = ""
	
	text = translate_pos(_piece) + " -> " + translate_pos(_dest)
	
	var log_text = "Turn " + str(turn_num) + " " + text + "\n"
	
	var label = Label.new()
	label.text = log_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", LOG_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.BLACK if is_white else Color.WHITE)
	
	if (ilegal_m || ilegal_prom || double_pawn_c):
		var background = StyleBoxFlat.new()
		background.bg_color = Color.RED
		
		label.add_theme_stylebox_override("normal", background)
	
	if(is_white):
		white_moves_log.add_child(label)
		_scroll_to_bottom(white_scroll)
	else:
		black_moves_log.add_child(label)
		_scroll_to_bottom(black_scroll)
	
	return label


#funcion auxiliar que se encarga de scrolear automaticamente el listado de
#movimientos
func _scroll_to_bottom(scroll: ScrollContainer) -> void:
	
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

#funcion que se encarga de mostrar el grafico indicativo de los movimientos ilegales de cada jugador
func show_ilegal_moves(is_white):
	
	if(is_white):
		if(white_pen_points == 1):
			white_ilegal_move_1.show()
		else:
			white_ilegal_move_2.show()
	else:
		if(black_pen_points == 1):
			black_ilegal_move_1.show()
		else:
			black_ilegal_move_2.show()
