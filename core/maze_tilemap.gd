@tool class_name MazeTileMap extends TileMapLayer

@export_range(3, 30, 2) var ui_size := 3:
	set(value):
		ui_size = value
		_reset_grid()

@export_tool_button("One step kruskal") var kruskal_btn := one_step_kruskal
@export_tool_button("Generate until cellgroups = size") var kruskal_multi_btn := kruskal_until_sqrt_group

@onready var tiles_parent := $Tiles as Node2D

@onready var player := $Player as Sprite2D

var size := 9
var size2 := size * size

const WALL := 9
const ORIG_CELL := 0
const JOINED_CELLS := 1

class GroupNeighbor:
	var connecting_wall := -1
	var group: CellGroup

class CellGroup:
	var id := 0
	var cells: Dictionary[int, int] = {}
	var nbors: Dictionary[int, GroupNeighbor] = {}
	var keys := []
	var nbors_processed_step := 0

var tiles: Array[TileSprite] = []
var grid: Dictionary[int, TileSprite.CellType] = {}
var walls: Dictionary[int, int] = {}
var potential_walls: Dictionary[int, int] = {}
var cell_groups: Dictionary[int, CellGroup] = {}
var cells: Dictionary[int, int] = {}
var group_counts: Dictionary[int, int] = {}
var player_pos := Vector2i.ZERO
var _last_move := 0
var player_spawn_cell_group: CellGroup


func i_to_xy(i: int) -> Vector2i:
	var y := int(float(i) / size)
	return Vector2i(i - y * size, y)

func xy_to_i(xy: Vector2i) -> int:
	return xy.y * size + xy.x

func _init() -> void:
	tile_set = preload("res://materials/tileset.tres")

func _ready() -> void:
	seed(12333)
	await _reset_grid()
	if !Engine.is_editor_hint():
		kruskal_until_sqrt_group()
		_form_cell_group_progress_graph()
		var cell_i: int = _get_player_spawn_cell()
		player_pos = i_to_xy(cell_i)

func _reset_grid() -> void:
	size = ui_size * 2 + 1
	size2 = size * size
	grid.clear()
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

	await get_tree().create_timer(0.01).timeout


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
			grid[i] = type
			tile_sprite.cell_type = type

	draw_grid()


func draw_grid() -> void:
	for y in range(0, size):
		for x in range(0, size):
			var xy := Vector2i(x, y)
			var i := xy_to_i(xy)
			var type := grid[i]
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


func one_step_kruskal() -> void:
	var wall: int = walls.keys().pick_random()
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
		print("Something wrong, wall at ", wall_xy, " found cells at (0,0)", cell1_xy, cell2_xy)
		return
	
	var cell1 := cells[xy_to_i(cell1_xy)]
	var cell2 := cells[xy_to_i(cell2_xy)]
	walls.erase(wall)
	if cell1 != cell2:
		grid[xy_to_i(wall_xy)] = TileSprite.CellType.JOINED_CELLS
		_update_cell_group_to_other(cell2, cell1)

		print("Walls left: {0}. Cell groups: {1}".format([walls.size(), cell_groups.size()]))
		draw_grid()


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
			grid[xy_to_i(wall_xy)] = TileSprite.CellType.JOINED_CELLS
			_update_cell_group_to_other(cell2_group_id, cell1_group_id)
			walls.erase(wall)
			draw_grid()

	draw_grid()

func is_walkable(xy: Vector2i) -> bool:
	var i := xy_to_i(xy)
	if i <= 0 || i > size2:
		return false
	return grid[i] != TileSprite.CellType.WALL

func _vector2_strongest_value(vec2: Vector2) -> Vector2i:
	if vec2 == Vector2.ZERO:
		return Vector2i.ZERO
	if absi(vec2.x) > absi(vec2.y):
		return Vector2i(signi(vec2.x) * 1, 0)
	
	return Vector2i(0, signi(vec2.y) * 1)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var dir_norm := _vector2_strongest_value(dir)

	if is_walkable(player_pos + dir_norm) && Time.get_ticks_msec() - _last_move > 100:
		player_pos += dir_norm
		_last_move = Time.get_ticks_msec()

	player.position = player_pos * Vector2i(16, 16) + Vector2i(8, 8)

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
	
	print("severing group {0} nbors at depth {1}, prev_groups {2}".format([group.id, depth, prev]))

	group.nbors_processed_step = 2
	if group.nbors.size() == 1:
		return

	var can_be_severed: Array[int] = []
	for nbor_id in group.nbors:
		var nbor := group.nbors[nbor_id].group
		if nbor.nbors_processed_step == 2:
			continue
		
		if nbor.nbors.size() == 1:
			continue
		can_be_severed.append(nbor_id)

	var severed := can_be_severed.size() - 1
	if severed > 0:
		for nbor_id in can_be_severed:
			if severed > 0 && randf() < 0.5:
				severed -= 1
				print("Severed tie between {0} and {1}".format([group.id, nbor_id]))
				var nbor := group.nbors[nbor_id].group
				nbor.nbors.erase(group.id)
				group.nbors.erase(nbor.id)

class Door extends RefCounted:
	var group1: CellGroup
	var group2: CellGroup
	var number := 0

class Doors extends RefCounted:
	var doors: Array[Door] = []

	func add_door(door: Door) -> void:
		doors.append(door)
	
	func doors_count() -> int:
		return doors.size()

func form_groups_id(group1: CellGroup, group2: CellGroup) -> String:
	var group_ids := [group1.id, group2.id]
	if group1.id > group2.id:
		group_ids = [group2.id, group1.id]

	return "{0}-{1}".format(group_ids)


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
			if grid[wall_i] != TileSprite.CellType.DOOR:
				grid[wall_i] = TileSprite.CellType.DOOR
				var what_door_number := door_number
				if !doors_into_group.has(nbor.group.id):
					print("Didnt find preexisting doors into group {0}".format([nbor.group.id]))
					var doors := Doors.new()
					var door := Door.new()
					door.group1 = group
					door.group2 = nbor.group
					door.number = what_door_number
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
					doors.doors.append(door)

				tiles[wall_i].label_text = str(what_door_number)
			bfs_groups.append(nbor.group)
	
	var key_i: int = player_spawn_cell_group.cells.keys().pick_random()
	grid[key_i] = TileSprite.CellType.KEY
	tiles[key_i].cell_type = TileSprite.CellType.KEY
	tiles[key_i].label_text = "0"

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
					grid[key_i] = TileSprite.CellType.KEY
					tiles[key_i].cell_type = TileSprite.CellType.KEY
					tiles[key_i].label_text = str(key)
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
	_place_doors_and_keys(player_spawn_cell_group)
	draw_grid()

	# get possible path ways starting from player spawn group
