@tool class_name MazeTileMapBak extends TileMapLayer

@export_range(3, 30, 2) var ui_size := 3:
	set(value):
		ui_size = value
		_reset_grid()

@export_tool_button("Generate until cellgroups = size") var kruskal_multi_btn := kruskal_until_sqrt_group

@onready var tiles_parent := $Tiles as Node2D
@onready var player := $Player as Sprite2D
@onready var keys_label := $KeysLabel as Label
@onready var playerpos_label := $PlayerPos as Label

var size := 9
var size2 := size * size

const WALL := 9
const ORIG_CELL := 0
const JOINED_CELLS := 1

class GroupNeighbor:
	var connecting_wall := -1
	var group: CellGroup

class CellsNode:
	var id := 0
	var cells: Dictionary[int, TileSprite] = {}
	var edges: Array[Edge] = []
	var keys := []
	var processed_step := 0

class Edge:
	var a: Node
	var b: Node
	var type := TileSprite.CellType.WALL
	var one_way_from := Node

	func id() -> String:
		var node_ids := [a.id, b.id]
		if a.id > b.id:
			node_ids = [b.id, a.id]
		return "{0}-{1}".format(node_ids)


class CellGroup:
	var id := 0
	var cells: Dictionary[int, int] = {}
	var nbors: Dictionary[int, GroupNeighbor] = {}
	var keys := []
	var nbors_processed_step := 0
	var min_key_required_to_access := 10000

var tiles: Array[TileSprite] = []
var walls: Dictionary[int, int] = {}
var potential_walls: Dictionary[int, int] = {}
var cell_groups: Dictionary[int, CellGroup] = {}
var cells: Dictionary[int, int] = {}
var group_counts: Dictionary[int, int] = {}
var player_pos := Vector2i.ZERO
var _last_move := 0
var player_spawn_cell_group: CellGroup
var collected_keys: Array[int] = []
var player_path: Array[int] = []
var player_sight := 3

var powerups: Array[String] = ["metro1", "sight", "metro2", "sight2"]
var plus_sight_cell := -1


func i_to_xy(i: int) -> Vector2i:
	var y := int(float(i) / size)
	return Vector2i(i - y * size, y)

func xy_to_i(xy: Vector2i) -> int:
	return xy.y * size + xy.x

func _init() -> void:
	tile_set = preload("res://materials/tileset.tres")

func _ready() -> void:
	seed(4)
	await _reset_grid()
	if !Engine.is_editor_hint():
		kruskal_until_sqrt_group()
		_form_cell_group_progress_graph()
		var cell_i: int = _get_player_spawn_cell()
		player_pos = i_to_xy(cell_i)

func _reset_grid() -> void:
	size = ui_size * 2 + 1
	size2 = size * size
	walls.clear()
	potential_walls.clear()
	cells.clear()
	tiles.clear()
	clear()
	if !is_node_ready():
		return

	tiles.resize(size2)

	for child in tiles_parent.get_children():
		print("freeing child ", child)
		child.queue_free()
		print("freed")


	for y in range(0, size):
		for x in range(0, size):
			var tile_sprite := TileSprite.new()
			var xy := Vector2i(x, y)
			var i := xy_to_i(xy)
			tile_sprite.world_grid_pos = xy
			tiles_parent.add_child(tile_sprite)
			tiles[i] = tile_sprite
			tile_sprite.owner = self

			var type := TileSprite.CellType.WALL
			if x % 2 == 1 && y % 2 == 1:
				type = TileSprite.CellType.ORIG_CELL
				var group := CellGroup.new()
				group.id = cell_groups.size()
				group.cells[i] = group.id
				cell_groups[group.id] = group
				var group_id := cells.size()
				cells[i] = group_id
				tile_sprite.group_id = group.id
			if x % 2 != y % 2 && x > 0 && y > 0 && x < size - 1 && y < size - 1:
				walls[i] = 1
				potential_walls[i] = 1
			tile_sprite.cell_type = type

	draw_grid()


func draw_grid() -> void:
	for y in range(0, size):
		for x in range(0, size):
			var xy := Vector2i(x, y)
			var i := xy_to_i(xy)
			var type := tiles[i].cell_type
			var tile_sprite := tiles[i]
			tile_sprite.cell_type = type
			
var biggest_cell_group: CellGroup
func count_cell_groups() -> int:
	group_counts.clear()
	for i in cell_groups:
		var group := cell_groups[i]
		if !biggest_cell_group || biggest_cell_group.cells_count < group.cells_count:
			biggest_cell_group = group

	return group_counts.size()

func get_biggest_group_count() -> int:
	if !biggest_cell_group:
		return 1000000
	
	return biggest_cell_group.cells_count


func _set_player_spawn_group() -> void:
	if cell_groups.size() < 3:
		var cell_group_id: int = cells.values().pick_random()
		player_spawn_cell_group = cell_groups[cell_group_id]
		return

	var cell_groups_sorted: Array[CellGroup] = cell_groups.values()
	cell_groups_sorted.sort_custom(func(a: CellGroup, b: CellGroup) -> bool: return a.cells.size() > b.cells.size())
	player_spawn_cell_group = cell_groups_sorted[2]


func _get_player_spawn_cell() -> int:
	if !player_spawn_cell_group:
		return cells.keys().pick_random()

	var player_spawn_cell: int = player_spawn_cell_group.cells.keys().pick_random()
	# confirm that it's not a door, key etc
	return player_spawn_cell


func _update_cell_group_to_other(from: int, to: int) -> void:
	for i in cells:
		var group_id := cells[i]
		var tile_sprite := tiles[i]
		if group_id == from:
			cells[i] = to
			tile_sprite.group_id = to
			var from_group := cell_groups[from]
			var to_group := cell_groups[to]
			from_group.cells.erase(i)
			to_group.cells[i] = to_group.id
			if from_group.cells.is_empty():
				cell_groups.erase(from)


func kruskal_until_sqrt_group() -> void:
	var safety := 100
	while cell_groups.size() > size && safety > 0:
		safety -= 1
		var wall: int = potential_walls.keys().pick_random()
		var wall_xy := i_to_xy(wall)

		var cell1_xy := Vector2i.ZERO
		var cell2_xy := Vector2i.ZERO
		if wall_xy.x % 2 == 1:
			# cells are up and down
			cell1_xy = wall_xy + Vector2i(0, -1)
			cell2_xy = wall_xy + Vector2i(0, 1)
		else:
			cell1_xy = wall_xy + Vector2i(-1, 0)
			cell2_xy = wall_xy + Vector2i(1, 0)

		if cell1_xy == Vector2i.ZERO || cell2_xy == Vector2i.ZERO:
			return
		
		var cell1_group_id := cells[xy_to_i(cell1_xy)]
		var cell2_group_id := cells[xy_to_i(cell2_xy)]
		var cell1_count := cell_groups[cell1_group_id].cells.size()
		var cell2_count := cell_groups[cell2_group_id].cells.size()
		potential_walls.erase(wall)
		if cell1_group_id != cell2_group_id && cell1_count < size / 2 && cell2_count < size / 2:
			tiles[wall].cell_type = TileSprite.CellType.JOINED_CELLS
			_update_cell_group_to_other(cell2_group_id, cell1_group_id)
			walls.erase(wall)
			draw_grid()

	draw_grid()

func is_walkable(xy: Vector2i) -> bool:
	var i := xy_to_i(xy)
	if i <= 0 || i > size2:
		return false
	if tiles[i].is_door():
		return collected_keys.has(tiles[i].door_number)
	
	return tiles[i].cell_type != TileSprite.CellType.WALL

func _vector2_strongest_value(vec2: Vector2) -> Vector2i:
	if vec2 == Vector2.ZERO:
		return Vector2i.ZERO
	if absi(vec2.x) > absi(vec2.y):
		return Vector2i(signi(vec2.x) * 1, 0)
	
	return Vector2i(0, signi(vec2.y) * 1)

func floodfill_sight(pos: int, sight_left := 0, visited: Dictionary[int, bool] = {}) -> void:
	if pos < 0 || pos > tiles.size() - 1:
		return

	visited[pos] = true
	tiles[pos].show()
	# if !tiles[pos].is_wall() && tiles[pos - 1 - size] && tiles[pos - 1 - size].is_wall():
	# 	tiles[pos - 1 - size].show()
	# if !tiles[pos].is_wall() && tiles[pos + 1 - size] && tiles[pos + 1 - size].is_wall():
	# 	tiles[pos + 1 - size].show()
	# if !tiles[pos].is_wall() && tiles[pos - 1 + size] && tiles[pos - 1 + size].is_wall():
	# 	tiles[pos - 1 + size].show()
	# if !tiles[pos].is_wall() && tiles[pos + 1 + size] && tiles[pos + 1 + size].is_wall():
	# 	tiles[pos + 1 + size].show()

	if sight_left == 0:
		return

	if tiles[pos].is_wall() || tiles[pos].is_door():
		return
	
	floodfill_sight(pos - 1, sight_left - 1, visited)
	floodfill_sight(pos + 1, sight_left - 1, visited)
	floodfill_sight(pos - size, sight_left - 1, visited)
	floodfill_sight(pos + size, sight_left - 1, visited)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var dir := Vector2i.ZERO
	if Input.is_action_just_pressed("up"):
		dir = Vector2i(0, -1)
	elif Input.is_action_just_pressed("down"):
		dir = Vector2i(0, 1)
	elif Input.is_action_just_pressed("left"):
		dir = Vector2i(-1, 0)
	elif Input.is_action_just_pressed("right"):
		dir = Vector2i(1, 0)

	if Input.is_action_just_pressed("plussight"):
		player_sight += 1
	if Input.is_action_just_pressed("minussight"):
		player_sight -= 1
	
	if is_walkable(player_pos + dir):
		player_pos += dir
		_last_move = Time.get_ticks_msec()

	player.position = player_pos * Vector2i(16, 16) + Vector2i(8, 8)

	var player_i := xy_to_i(player_pos)
	if tiles[player_i] != null:
		if tiles[player_i].is_key():
			collected_keys.append(tiles[player_i].key_number)
			tiles[player_i].cell_type = TileSprite.CellType.ORIG_CELL
		if tiles[player_i].cell_type == TileSprite.CellType.PLUSSIGHT:
			player_sight *= 2
			tiles[player_i].cell_type = TileSprite.CellType.ORIG_CELL
		if tiles[player_i].is_door():
			tiles[player_i].cell_type = TileSprite.CellType.OPENED_DOOR

	var won: bool = tiles[player_i] != null && tiles[player_i].group_id == player_path.back()

	for tile_i in range(0, tiles.size()):
		if won || true:
			tiles[tile_i].show()
		else:
			tiles[tile_i].hide()
	
	if !won:
		floodfill_sight(player_i, player_sight)
		
	keys_label.text = ",".join(collected_keys.map(str))
	playerpos_label.text = str(player_pos)

func _get_cell_nbor_groups(cell_i: int) -> Array[GroupNeighbor]:
	var i_dirs: Array[int] = [1, -1, -size, size]
	var nbor_groups: Array[GroupNeighbor] = []
	for i_dir in i_dirs:
		var wall_i := cell_i + i_dir
		var cell_i2 := cell_i + i_dir * 2
		if walls.has(wall_i) && cells.has(cell_i2) && cells[cell_i2] != cells[cell_i]:
			var group_nbor := GroupNeighbor.new()
			group_nbor.connecting_wall = wall_i
			group_nbor.group = cell_groups[cells[cell_i2]]
			nbor_groups.append(group_nbor)

	return nbor_groups

func _get_neighbor_groups(this_group: CellGroup) -> Array[GroupNeighbor]:
	var nbor_groups: Dictionary[int, GroupNeighbor] = {}
	print("Finding neighbors for group ", this_group)
	for cell_i in this_group.cells:
		print("Finding neighbor groups for cell ", (i_to_xy(cell_i)))
		var cell_nbor_groups := _get_cell_nbor_groups(cell_i)
		print("Found {0} neighbor groups".format([cell_nbor_groups.size()]))
		for nbor_group in cell_nbor_groups:
			if !nbor_groups.has(nbor_group.group.id) || randf() < 0.5:
				nbor_groups[nbor_group.group.id] = nbor_group


	# for nbor_group: GroupNeighbor in nbor_groups.values():
	# 	var wall_i := nbor_group.connecting_wall
	# 	potential_walls.erase(wall_i)
	# 	walls.erase(wall_i)
	# 	grid[wall_i] = TileSprite.CellType.DOOR
	# 	#tiles[wall_i].label_text = str(nbor_group.group.id)

	return nbor_groups.values()

func _sever_nbors_randomly(group: CellGroup, prev: Dictionary[int, bool] = {}, depth := 0) -> void:
	# DFS step
	if depth > 100:
		print("depth over 100")
		return

	if group.nbors.size() > 0:
		for nbor_id in group.nbors:
			var nbor := group.nbors[nbor_id].group
			if !prev.has(nbor_id):
				prev[group.id] = true
				_sever_nbors_randomly(nbor, prev, depth + 1)
	

	group.nbors_processed_step = 2
	if group.nbors.size() == 1:
		return
	print("severing group {0} nbors at depth {1}, prev_groups {2}".format([group.id, depth, prev]))

	var can_be_severed: Array[int] = []
	
	if group.cells.size() > 1:
		for nbor_id in group.nbors:
			var nbor := group.nbors[nbor_id].group
			if nbor.nbors_processed_step == 2:
				continue
			
			if nbor.nbors.size() == 1:
				continue
			can_be_severed.append(nbor_id)
	else:
		can_be_severed = group.nbors.keys().slice(0, -1)

	var severed := can_be_severed.size() - 2
	for i in range(0, can_be_severed.size() - 1):
		var nbor_id: int = can_be_severed.pick_random()
		can_be_severed.erase(nbor_id)
		print("Severed tie between {0} and {1}, severed options: {2}".format([group.id, nbor_id, severed]))
		var nbor := group.nbors[nbor_id].group
		nbor.nbors.erase(group.id)
		group.nbors.erase(nbor.id)

class Door extends RefCounted:
	var group1: CellGroup
	var group2: CellGroup
	var number := 0
	var i := 0

	func id() -> String:
		var groups := [group1.id, group2.id]
		if group2.id > group1.id:
			groups = [group2.id, group1.id]
		return "{0}-{1}".format(groups)

class Doors extends RefCounted:
	var doors: Array[Door] = []

	func add_door(door: Door) -> void:
		doors.append(door)
	
	func doors_count() -> int:
		return doors.size()


func _get_doors_for_group(group: CellGroup, preexisting: Dictionary[String, Door] = {}) -> Array[Door]:
	group.nbors_processed_step = 3
	var doors: Array[Door] = []
	for nbor_id in group.nbors:
		var nbor := group.nbors[nbor_id]
		var wall_i := nbor.connecting_wall
		var door := Door.new()
		door.group1 = group
		door.group2 = nbor.group
		door.i = wall_i

		if preexisting.has(door.id()):
			continue

		preexisting[door.id()] = door
		doors.append(door)

	return doors


func _place_doors_and_keys2(starting_group: CellGroup) -> void:
	var possible_doors_out: Array[Door] = _get_doors_for_group(starting_group)
	var existing_doors: Dictionary[String, Door] = {}
	var door_number := 0
	player_path = [starting_group.id]
	

	while !possible_doors_out.is_empty():
		var door: Door = possible_doors_out.pick_random()
		possible_doors_out.erase(door)
		existing_doors[door.id()] = door
		door_number += 1
		door.number = door_number

		if !player_path.has(door.group2.id):
			player_path.append(door.group2.id)

		if door.group2.id == starting_group.id:
			door.number = door.group1.min_key_required_to_access
		elif door.group2.min_key_required_to_access > door.number:
			door.group2.min_key_required_to_access = door.number
		else:
			door.number = door.group2.min_key_required_to_access
		
		if door.group1.nbors_processed_step < 3:
			possible_doors_out.append_array(_get_doors_for_group(door.group1, existing_doors))
		elif door.group2.nbors_processed_step < 3:
			possible_doors_out.append_array(_get_doors_for_group(door.group2, existing_doors))

		# visited_groups[door.group2.id] = door.group2
		var wall_i := door.i
		tiles[wall_i].door_number = door.number
		tiles[wall_i].cell_type = TileSprite.CellType.DOOR

	var doors_sorted: Array[Door] = existing_doors.values()
	doors_sorted.sort_custom(func(a: Door, b: Door) -> bool: return a.number < b.number)
	door_number = 0
	var prev_door_number := -1
	var keys_needed_dict: Dictionary[int, bool] = {}
	for i in range(0, doors_sorted.size()):
		var door := doors_sorted[i]
		if prev_door_number < door.number:
			door_number += 1
			prev_door_number = door.number
		door.number = door_number
		tiles[door.i].door_number = door.number
		tiles[door.i].cell_type = TileSprite.CellType.DOOR
		keys_needed_dict[door.number] = true

	print(player_path)
	return
	
	var key_i: int = player_spawn_cell_group.cells.keys().pick_random()
	#tiles[key_i].cell_type = TileSprite.CellType.KEY
	var keys_needed: Array[int] = keys_needed_dict.keys()
	keys_needed.sort()

	for group: CellGroup in cell_groups.values():
		print(group.id, "-minkey: ", group.min_key_required_to_access)

	var plus_sight_group_id: int = player_path.slice(size / 4, -3).pick_random()
	var plus_sight_group := cell_groups[plus_sight_group_id]
	while plus_sight_group.cells.size() == 1:
		plus_sight_group_id = player_path.slice(size / 2, -3).pick_random()
		plus_sight_group = cell_groups[plus_sight_group_id]

	plus_sight_cell = plus_sight_group.cells.keys().pick_random()
	while tiles[plus_sight_cell].is_key():
		plus_sight_cell = plus_sight_group.cells.keys().pick_random()
	
	tiles[plus_sight_cell].cell_type = TileSprite.CellType.PLUSSIGHT

	var key_placed := false
	for group_id in player_path:
		if keys_needed.is_empty():
			break
		var group := cell_groups[group_id]
		var key: int = keys_needed.pop_front()
		key_i = group.cells.keys().pick_random()
		tiles[key_i].key_number = key
		print(i_to_xy(key_i), tiles[key_i].key_number)
		tiles[key_i].cell_type = TileSprite.CellType.KEY
		key_placed = true
	# while !keys_needed.is_empty():
	# 	var key: int = keys_needed.pop_front()
	# 	if !key:
	# 		return

	# 	for group: CellGroup in cell_groups.values():
	# 		if group.min_key_required_to_access == key - 1:
	# 			key_i = group.cells.keys().pick_random()
	# 			tiles[key_i].key_number = key
	# 			print(i_to_xy(key_i), tiles[key_i].key_number)
	# 			tiles[key_i].cell_type = TileSprite.CellType.KEY
	# 			key_placed = true
	

func _place_doors_and_keys(starting_group: CellGroup) -> void:
	var bfs_groups: Array[CellGroup] = [starting_group]
	var doors_into_group: Dictionary[int, Doors] = {}
	var door_number := 0
	var keys_needed: Array[int] = []
	while !bfs_groups.is_empty():
		var group: CellGroup = bfs_groups.pick_random()
		bfs_groups.erase(group)
		if group.nbors_processed_step >= 3:
			continue
		
		group.nbors_processed_step = 3
		for nbor_id in group.nbors:
			var nbor := group.nbors[nbor_id]
			var wall_i := nbor.connecting_wall
			potential_walls.erase(wall_i)
			walls.erase(wall_i)
			if tiles[wall_i].cell_type != TileSprite.CellType.DOOR:
				tiles[wall_i].cell_type = TileSprite.CellType.DOOR
				var what_door_number := door_number
				if !doors_into_group.has(nbor.group.id):
					print("Didnt find preexisting doors into group {0}".format([nbor.group.id]))
					var doors := Doors.new()
					var door := Door.new()
					door.group1 = group
					door.group2 = nbor.group
					door.number = what_door_number
					door.i = wall_i
					doors.add_door(door)
					doors_into_group[nbor.group.id] = doors
					keys_needed.append(what_door_number)
					door_number += 1
				else:
					var doors: Doors = doors_into_group[nbor.group.id]
					print("Found doors into nbor {0}, ".format([nbor.group.id]), doors.doors)
					what_door_number = doors.doors[0].number
					
					var door := Door.new()
					door.group1 = group
					door.group2 = nbor.group
					door.number = what_door_number
					door.i = wall_i
					doors.doors.append(door)

				tiles[wall_i].door_number = what_door_number
			bfs_groups.append(nbor.group)
	
	var key_i: int = player_spawn_cell_group.cells.keys().pick_random()
	tiles[key_i].cell_type = TileSprite.CellType.KEY
	tiles[key_i].key_number = keys_needed.pop_front()

	while !keys_needed.is_empty():
		var key: int = keys_needed.pop_front()
		var key_placed := false
		for group_id in doors_into_group:
			if key_placed:
				break
			var doors_obj := doors_into_group[group_id]
			for door in doors_obj.doors:
				if key_placed:
					break
				if door.number < key:
					key_i = cell_groups[group_id].cells.keys().pick_random()
					tiles[key_i].key_number = key
					print(tiles[key_i].key_number)
					tiles[key_i].cell_type = TileSprite.CellType.KEY
					key_placed = true
					doors_into_group.erase(group_id)


func _form_cell_group_progress_graph() -> void:
	_set_player_spawn_group()
	var next_groups_to_process: Array[CellGroup] = [player_spawn_cell_group]
	while !next_groups_to_process.is_empty():
		var next_group: CellGroup = next_groups_to_process.pop_front()
		next_group.nbors_processed_step = 1
		var nbors := _get_neighbor_groups(next_group)
		
		for nbor in nbors:
			if !next_group.nbors.has(nbor.group.id):
				next_group.nbors[nbor.group.id] = nbor
				var this_neighbor := GroupNeighbor.new()
				this_neighbor.connecting_wall = nbor.connecting_wall
				this_neighbor.group = next_group
				nbor.group.nbors[next_group.id] = this_neighbor
				if nbor.group.nbors_processed_step == 0:
					next_groups_to_process.append(nbor.group)

	var door_number := 0
	var keys_needed: Array[int] = []

	# dfs through player spawn nbors
	_sever_nbors_randomly(player_spawn_cell_group)
	_place_doors_and_keys2(player_spawn_cell_group)
	draw_grid()

	# get possible path ways starting from player spawn group
