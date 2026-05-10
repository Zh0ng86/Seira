@tool
class_name MapManager extends Node2D

@export var DUNGEON_MIN_W : int = 50
@export var DUNGEON_MIN_H: int = 40
@export var MAX_ENEMIES_PER_ROOM : int = 3
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Wall
@onready var cam: Camera2D = $Camera2D

@export_tool_button("Generate Map") var map_gen_button = build_rooms

var player_node
var stair_node

func _ready():
	var rooms = build_rooms()
	# Place stairs in last room, player at first
	_place_stairs(rooms[-1])
	_place_player(rooms[0])

	# Scatter enemies (skip room 0 = player start)
	for i in range(1, rooms.size()):
		_spawn_enemies_in_room(rooms[i])
	GameManager._dungeon_scene = self

func _process(delta: float) -> void:
	if player_node: 
		cam.position = player_node.position
		if Input.is_key_pressed(KEY_V):
			player_node.position = stair_node.position - Vector2(10, 10)


func build_rooms():
	var data = DungeonGenerator.generate(DUNGEON_MIN_W , DUNGEON_MIN_H, 10)
	
	floor_layer.z_index = -2
	wall_layer.z_index = -1
	floor_layer.clear()
	wall_layer.clear()
	
	 # Step 1 - collect all floor positions
	var floor_cells: Dictionary = {}
	var wall_cells: Dictionary = {}
	
	for room in data.rooms:
		for y in range(-1, room.size.y + 1):
			for x in range(-1, room.size.x + 1):
				var pos = Vector2i(room.position.x + x, room.position.y + y)
				floor_cells[pos] = true
	
	for corridor in data.corridors:
		var p1: Vector2i = corridor[0]
		var p2: Vector2i = corridor[1]
		var cx = p1.x
		while cx != p2.x:
			for offset in [-1, 0, 1]:
				floor_cells[Vector2i(cx, p1.y + offset)] = true
			cx += sign(p2.x - p1.x)
		var cy = p1.y
		while cy != p2.y:
			for offset in [-1, 0, 1]:
				floor_cells[Vector2i(p2.x + offset, cy)] = true
			cy += sign(p2.y - p1.y)
	
	# Step 2 - place floor tiles
	var floor_array: Array[Vector2i] = []
	for pos in floor_cells:
		floor_array.append(pos)
	floor_layer.set_cells_terrain_connect(floor_array, 0, 0)
	
	# Step 3 - place wall tiles only on the border around floor
	var neighbours = [
		Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1),
		Vector2i(-1, 0),                 Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
	]
	for pos in floor_cells:
		for n in neighbours:
			var neighbour = pos + n
			if not floor_cells.has(neighbour):
				wall_cells[neighbour] = true
	
	var all_floor: Array[Vector2i] = []
	for pos in floor_cells:
		all_floor.append(pos)
	# Also paint floor under wall cells so no grey void shows
	for pos in wall_cells:
		all_floor.append(pos)
	
	floor_layer.set_cells_terrain_connect(all_floor, 0, 0)
	
	# Paint walls on top — separate layer so floor shows beneath
	var wall_array: Array[Vector2i] = []
	for pos in wall_cells:
		wall_array.append(pos)
	wall_layer.set_cells_terrain_connect(wall_array, 0, 0)
	
	return data.rooms

func _place_player(room: Rect2i): 
	if Scenes.CHAR_SCENES.has(GameManager.roaming_char):
		var char = Scenes.CHAR_SCENES[GameManager.roaming_char].instantiate()
		
		var center_tile = Vector2i(
			room.position.x + room.size.x / 2,
			room.position.y + room.size.y / 2
		)
		char.global_position = floor_layer.map_to_local(center_tile)
		add_child(char)

		cam.make_current()
		player_node = char
		GameManager.can_move = true
		player_node.add_to_group("player")

func _place_stairs(room: Rect2i): 
	var center_tile = Vector2i(
		room.position.x + room.size.x / 2,
		room.position.y + room.size.y / 2
	)
	
	var stair = Scenes.STAIR_SCENE.instantiate()
	stair.global_position = floor_layer.map_to_local(center_tile)
	add_child(stair)
	stair_node = stair
	
func _spawn_enemies_in_room(room: Rect2i):
	if not Scenes.ENEMY_SCENES or Scenes.ENEMY_SCENES.is_empty():
		return
	
	var enemy_count = randi_range(1, MAX_ENEMIES_PER_ROOM)
	
	var room_cells: Array[Vector2i] = []
	for x in range(room.position.x, room.position.x + room.size.x - 1):
		for y in range(room.position.y, room.position.y + room.size.y - 1):
			var cell = Vector2i(x, y)
			if floor_layer.get_cell_source_id(cell) != -1:
				room_cells.append(cell)
	
	if room_cells.is_empty():
		return
	
	room_cells.shuffle()
	
	for i in range(min(enemy_count, room_cells.size())):
		var enemy_scene = Scenes.ENEMY_SCENES.values().pick_random()
		var enemy = enemy_scene.instantiate()
		enemy.global_position = floor_layer.map_to_local(room_cells[i])
		add_child(enemy)
	
