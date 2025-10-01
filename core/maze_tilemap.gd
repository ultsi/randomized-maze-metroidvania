@tool class_name Maze extends Node2D

@export_range(3, 30, 2) var ui_size := 3:
	set(value):
		ui_size = value
		_reset_grid()

@export_tool_button("One step kruskal") var one_step := one_step_kruskal

@export_tool_button("Generate kruskal forest") var kruskal_multi_btn := kruskal_forest
@export_tool_button("Fix single cells") var fix_singles_btn := fix_single_cell_nodes
@export_tool_button("Generate doors and keys") var doors_keys_btn := func() -> void:
	set_start_node()
	generate_doors_and_keys()
@export_tool_button("Animate message label") var animate_message_btn := _animate_message_label

@onready var tiles_parent := $Tiles as Node2D
@onready var player := $Player as Sprite2D
@onready var camera := $Player/Camera2D as Camera2D
@onready var keys_label := $Player/Camera2D/UI/TopLeft/KeysLabel as Label
@onready var playerpos_label := $Player/Camera2D/UI/TopLeft/PosLabel as Label
@onready var time_label := $Player/Camera2D/UI/TopCenter/TimeLabel as Label
@onready var audio_key_pickup := $AudioKeyPickup as AudioStreamPlayer2D
@onready var audio_door_open := $AudioDoorOpen as AudioStreamPlayer2D
@onready var audio_break_wall_impact := $AudioBreakWallImpact as AudioStreamPlayer2D
@onready var audio_break_wall := $AudioBreakWall as AudioStreamPlayer2D
@onready var audio_metro_open := $AudioMetroOpen as AudioStreamPlayer2D
@onready var audio_metro_use := $AudioMetroUse as AudioStreamPlayer2D
@onready var audio_powerup_pickup := $AudioPowerupPickup as AudioStreamPlayer2D

var size := 9
var size2 := size * size
const WALL := 9
const ORIG_CELL := 0
const JOINED_CELLS := 1

class CellsNode:
	var id := 0
	var cells: Dictionary[int, TileSprite] = {}
	var edges: Array[Edge] = []
	var keys := []
	var processed_step := 0

class Edge:
	var a: int
	var b: int
	var type := TileSprite.CellType.WALL
	var dir: int = -1
	var tile: TileSprite
	var pos: Vector2i
	var i: int
	var is_one_way := false

	func id() -> String:
		var node_ids := [a, b]
		if a > b:
			node_ids = [b, a]
		return "{0}-{1}".format(node_ids)

class MetroStation:
	var i: int
	var activated := false


var visual_tiles: Array[TileSprite] = []
var edges: Dictionary[int, Edge] = {}
var cells_nodes: Dictionary[int, CellsNode] = {}
var player_pos := Vector2i.ZERO
var keys_inventory: Array[int] = []
var player_path: Array[int] = []
var player_sight := 3
var player_won := false
var start_node: CellsNode

var metro_stations: Dictionary[int, MetroStation] = {}
var player_metros: Array[MetroStation] = []

enum PowerUp {
	Metro,
	PlusSight
}

var powerups: Array[PowerUp] = [PowerUp.Metro, PowerUp.PlusSight, PowerUp.Metro, PowerUp.PlusSight, PowerUp.Metro, PowerUp.PlusSight]
var plus_sight_cell := -1
var bottom_message_scene := preload("res://core/bottom_message.tscn")
var _last_action_time := 0
var time_to_clear := 60.0


func i_to_xy(i: int) -> Vector2i:
	var y := int(float(i) / size)
	return Vector2i(i - y * size, y)

func xy_to_i(xy: Vector2i) -> int:
	return xy.y * size + xy.x

func _animate_message_label() -> void:
	pass

func _ready() -> void:
	#seed(4)
	await _reset_grid()
	if !Engine.is_editor_hint():
		powerups.resize(ui_size / 4)
		kruskal_forest()
		fix_single_cell_nodes()
		set_start_node()
		player_pos = i_to_xy(start_node.cells.keys().pick_random())
		generate_doors_and_keys()

func _get_cells_node_at_i(i: int) -> CellsNode:
	if i < 0 || i > visual_tiles.size() - 1:
		return

	return cells_nodes[visual_tiles[i].group_id]

func _reset_grid() -> void:
	size = ui_size * 2 + 1
	size2 = size * size
	edges.clear()
	visual_tiles.clear()
	if !is_node_ready():
		return

	visual_tiles.resize(size2)

	for child in tiles_parent.get_children():
		#print("freeing child ", child)
		child.queue_free()
		#print("freed")


	for y in range(0, size):
		for x in range(0, size):
			var tile_sprite := TileSprite.new()
			var xy := Vector2i(x, y)
			var i := xy_to_i(xy)
			tile_sprite.world_grid_pos = xy
			tiles_parent.add_child(tile_sprite)
			visual_tiles[i] = tile_sprite
			tile_sprite.owner = self

			var type := TileSprite.CellType.WALL
			if x % 2 == 1 && y % 2 == 1:
				type = TileSprite.CellType.ORIG_CELL

				var cells_node := CellsNode.new()
				cells_node.cells[i] = tile_sprite
				cells_node.id = cells_nodes.size()
				cells_nodes[cells_node.id] = cells_node
				tile_sprite.group_id = cells_node.id

			tile_sprite.cell_type = type

	for y in range(0, size):
		for x in range(0, size):
			if x % 2 != y % 2 && x > 0 && y > 0 && x < size - 1 && y < size - 1:
				# valid edge
				var xy := Vector2i(x, y)
				var i := xy_to_i(xy)
				var tile_sprite := visual_tiles[i]
				var edge := Edge.new()
				edge.tile = tile_sprite
				edge.pos = xy
				edge.i = i
				if y % 2 == 0:
					edge.a = _get_cells_node_at_i(i - size).id
					edge.b = _get_cells_node_at_i(i + size).id
				else:
					edge.a = _get_cells_node_at_i(i - 1).id
					edge.b = _get_cells_node_at_i(i + 1).id

				#print("found edge ", edge.id())

				edges[i] = edge

	draw_grid()


func draw_grid() -> void:
	for y in range(0, size):
		for x in range(0, size):
			var xy := Vector2i(x, y)
			var i := xy_to_i(xy)
			var type := visual_tiles[i].cell_type
			var tile_sprite := visual_tiles[i]
			tile_sprite.cell_type = type


func set_start_node() -> void:
	if cells_nodes.size() < 3:
		start_node = cells_nodes.values().pick_random()
		return

	var start_nodes_sorted: Array[CellsNode] = cells_nodes.values()
	start_nodes_sorted.sort_custom(func(a: CellsNode, b: CellsNode) -> bool: return a.cells.size() > b.cells.size())
	start_node = start_nodes_sorted[2]


func new_message(text: String, speed_scale := 0.5) -> void:
	var message: BottomMessage = bottom_message_scene.instantiate()
	message.text = text
	message.speed_scale = 1.0
	camera.add_child(message)


func _combine_cells_nodes(edge: Edge) -> void:
	var old_edge_id := edge.id()
	var cna := cells_nodes[edge.a]
	var cnb := cells_nodes[edge.b]
	var old_size := cna.cells.size()
	var old_id := cnb.id
	cnb.id = cna.id
	#print("Combining {0}, a cells: {1}, b cells {2}".format([old_edge_id, cna.cells.size(), cnb.cells.size()]))
	for cell_i in cnb.cells:
		#print("a", cell_i)
		cna.cells[cell_i] = cnb.cells[cell_i]

	for cell_i in cna.cells:
		#print("b", cell_i)
		cna.cells[cell_i].group_id = cna.id

	#print("Combined {0}, old_size: {1} new size:  {2}".format([old_edge_id, old_size, cna.cells.size()]))
	cells_nodes.erase(old_id)

	for i_edge: Edge in edges.values():
		if i_edge.a == old_id:
			i_edge.a = cnb.id
		if i_edge.b == old_id:
			i_edge.b = cnb.id
	
	visual_tiles[edge.i].cell_type = TileSprite.CellType.JOINED_CELLS

func find_potential_kruskal_edge() -> Edge:
	const max_tries := 3
	for i in range(0, max_tries):
		var edge: Edge = edges.values().pick_random()
		if edge.type != TileSprite.CellType.WALL:
			continue

		if i == max_tries - 1:
			return null

		var cna := cells_nodes[edge.a]
		var cnb := cells_nodes[edge.b]
		if cna == cnb:
			#print("found edge with same cellsnodes")
			continue

		var a_size := cna.cells.size()
		var b_size := cnb.cells.size()

		if a_size == 1 && b_size < size / 2:
			return edge

		if b_size == 1 && a_size < size / 2:
			return edge

		if a_size < size / 2 && b_size < size / 2:
			return edge

	return null
		

func one_step_kruskal() -> void:
	var edge: Edge = find_potential_kruskal_edge()
	if !edge:
		return
	edges.erase(edge.i)
	var pos_i := xy_to_i(edge.pos)
	var cellnode_a := cells_nodes[edge.a]
	var cellnode_b := cells_nodes[edge.b]
	if edge.type == TileSprite.CellType.WALL && cellnode_a.id != cellnode_b.id && cellnode_a.cells.size() < size / 2 && cellnode_b.cells.size() < size / 2:
		_combine_cells_nodes(edge)
		draw_grid()


func kruskal_forest() -> void:
	var safety := 100
	while cells_nodes.size() > size && safety > 0:
		print(cells_nodes.size())
		safety -= 1
		one_step_kruskal()

	draw_grid()

func find_edges_for_cell(cell_i: int) -> Array[Edge]:
	var found_edges: Array[Edge] = []
	if edges.has(cell_i - 1):
		found_edges.append(edges[cell_i - 1])
	if edges.has(cell_i + 1):
		found_edges.append(edges[cell_i + 1])
	if edges.has(cell_i - size):
		found_edges.append(edges[cell_i - size])
	if edges.has(cell_i + size):
		found_edges.append(edges[cell_i + size])
	return found_edges

func fix_single_cell_nodes() -> void:
	for node_id: int in cells_nodes.keys():
		if !cells_nodes.has(node_id):
			continue
		var node := cells_nodes[node_id]
		if node.cells.size() > 1:
			print("Node {0} has too many cells ({1})".format([node_id, node.cells.size()]))
			continue

		var node_edges := find_edges_for_cell(node.cells.keys()[0])
		if node_edges.size() == 0:
			print("No edges found for node_id ", node_id)
			continue
		
		var selected_edge: Edge = node_edges.pick_random()
		_combine_cells_nodes(selected_edge)
		draw_grid()

func generate_doors_and_keys() -> void:
	var edge_dict: Dictionary[String, Edge] = {}
	for edge in edges.values():
		edge_dict[edge.id()] = edge

	var edges_by_node_id: Dictionary[int, Array] = {}

	for edge: Edge in edge_dict.values():
		if edge.a == edge.b:
			continue
		if edges_by_node_id.has(edge.a):
			edges_by_node_id[edge.a].append(edge)
		else:
			edges_by_node_id[edge.a] = [edge]

		if edges_by_node_id.has(edge.b):
			edges_by_node_id[edge.b].append(edge)
		else:
			edges_by_node_id[edge.b] = [edge]

	var valid_edges: Dictionary[String, Edge] = {}

	for node_id in edges_by_node_id:
		var edges := edges_by_node_id[node_id]
		var estr := edges.map(func(e: Edge) -> String: return e.id())
		print("Node {0} edges: {1}".format([node_id, str(estr)]))

	for node_id in edges_by_node_id:
		var node_edges := edges_by_node_id[node_id]
		if node_edges.size() == 1:
			valid_edges[node_edges[0].id()] = node_edges[0]
			continue

		var tmp := node_edges.duplicate()
		var randomized_edges: Array[Edge] = []
		for i in range(0, tmp.size()):
			var edge: Edge = tmp.pick_random()
			tmp.erase(edge)
			randomized_edges.append(edge)
		var node := cells_nodes[node_id]
		if node.cells.size() == 1:
			var valid_edge: Edge
			for edge: Edge in randomized_edges:
				valid_edge = edge
				var node_a := cells_nodes[edge.a]
				var node_b := cells_nodes[edge.b]
				if node_a.cells.size() > 1 || node_b.cells.size() > 1:
					break
			
			valid_edges[valid_edge.id()] = valid_edge
			for edge in node_edges:
				if edge.id() == valid_edge.id():
					continue
				valid_edges.erase(edge.id())
			continue

		var max_edges := randomized_edges.size()
		for i in range(max_edges * randf(), max_edges):
			var valid_edge: Edge = randomized_edges[i]
			valid_edges[valid_edge.id()] = valid_edge

	var estr := valid_edges.values().map(func(e: Edge) -> String: return e.id())
	print("Valid edges: ", estr)
	
	# for node_id in edges_by_node_id:
	# 	var node := cells_nodes[node_id]
	# 	var node_edges := edges_by_node_id[node_id]
	# 	if node.cells.size() == 1 && node_edges.size() > 1:
	# 		print("LOL?", node.id)
	edges_by_node_id.clear()
	for edge: Edge in valid_edges.values():
		edge.type = TileSprite.CellType.DOOR
		edge.tile.cell_type = TileSprite.CellType.DOOR
		if edges_by_node_id.has(edge.a):
			edges_by_node_id[edge.a].append(edge)
		else:
			edges_by_node_id[edge.a] = [edge]

		if edges_by_node_id.has(edge.b):
			edges_by_node_id[edge.b].append(edge)
		else:
			edges_by_node_id[edge.b] = [edge]

	# form directed graph here
	# important because player path is directed and that way
	# we then know which doors are actual blockers
	# and which ones are openable shortcuts from the other side
	var edge_queue: Array = edges_by_node_id[start_node.id]
	var door_number := 0
	var handled_edges: Dictionary[String, bool] = {}
	var visited_nodes: Dictionary[int, bool] = {start_node.id: true}
	player_path = [start_node.id]
	while !edge_queue.is_empty():
		var edge: Edge = edge_queue.pick_random()
		edge_queue.erase(edge)
		if handled_edges.has(edge.id()):
			continue
		handled_edges[edge.id()] = true
		if visited_nodes.has(edge.a) && visited_nodes.has(edge.b):
			edge.tile.door_number = -1
			edge.tile.cell_type = TileSprite.CellType.WALL
			edge.is_one_way = true
			edge.dir = edge.b if player_path.find(edge.a) < player_path.find(edge.b) else edge.a
			edge.tile.group_id = edge.dir
		else:
			edge.tile.door_number = door_number
			door_number += 1
			edge.tile.cell_type = TileSprite.CellType.DOOR

		if !visited_nodes.has(edge.a):
			if edges_by_node_id.has(edge.a):
				edge_queue.append_array(edges_by_node_id[edge.a])
				visited_nodes[edge.a] = true
				player_path.append(edge.a)
		if !visited_nodes.has(edge.b):
			if edges_by_node_id.has(edge.b):
				edge_queue.append_array(edges_by_node_id[edge.b])
				visited_nodes[edge.b] = true
				player_path.append(edge.b)
	
	for i in range(0, player_path.size() - 1):
		var key_i: int = cells_nodes[player_path[i]].cells.keys().pick_random()
		visual_tiles[key_i].key_number = i
		visual_tiles[key_i].cell_type = TileSprite.CellType.KEY

	var next_powerup_node := player_path.size() / 4
	var increment := (player_path.size() - next_powerup_node) / powerups.size()
	print("Powerups starting from {0} with increment of {1}. Total area size {2}, powerups count {3}".format([next_powerup_node, increment, player_path.size(), powerups.size()]))
	for powerup in powerups:
		if next_powerup_node >= player_path.size():
			return
		var node_id := player_path[next_powerup_node]
		var node := cells_nodes[node_id]
		var safety := 3
		while node.cells.size() == 1 && safety > 0:
			next_powerup_node += 1
			if next_powerup_node >= player_path.size():
				return
			node_id = player_path[next_powerup_node]
			node = cells_nodes[node_id]
			safety -= 1
		var powerup_i: int = node.cells.keys().pick_random()
		safety = 3
		while visual_tiles[powerup_i].cell_type != TileSprite.CellType.ORIG_CELL && safety > 0:
			powerup_i = node.cells.keys().pick_random()
			safety -= 1
		if safety == 0:
			continue

		if powerup == PowerUp.PlusSight:
			visual_tiles[powerup_i].cell_type = TileSprite.CellType.PLUSSIGHT
		elif powerup == PowerUp.Metro:
			visual_tiles[powerup_i].cell_type = TileSprite.CellType.METRO
			var station := MetroStation.new()
			station.i = powerup_i
			station.activated = false
			metro_stations[powerup_i] = station

		next_powerup_node += increment


func is_walkable(xy: Vector2i) -> bool:
	var i := xy_to_i(xy)
	if i <= 0 || i > size2:
		return false
	if visual_tiles[i].is_door():
		return keys_inventory.has(visual_tiles[i].door_number)
	
	return visual_tiles[i].cell_type != TileSprite.CellType.WALL

func _vector2_strongest_value(vec2: Vector2) -> Vector2i:
	if vec2 == Vector2.ZERO:
		return Vector2i.ZERO
	if absi(vec2.x) > absi(vec2.y):
		return Vector2i(signi(vec2.x) * 1, 0)
	
	return Vector2i(0, signi(vec2.y) * 1)

func floodfill_sight(pos: int, sight_left := 0, visited: Dictionary[int, bool] = {}) -> void:
	if pos < 0 || pos > visual_tiles.size() - 1:
		return

	visited[pos] = true
	visual_tiles[pos].show()
	var player_i := xy_to_i(player_pos)
	var group_id := visual_tiles[player_i].group_id
	if group_id >= 0 && edges.has(pos):
		var edge := edges[pos]
		if edge.is_one_way:
			if edge.dir != group_id:
				visual_tiles[pos].cell_type = TileSprite.CellType.WALL
			else:
				visual_tiles[pos].cell_type = TileSprite.CellType.ONEWAY_WALL
				visual_tiles[pos].cell_type = TileSprite.CellType.ONEWAY_WALL


	# if !visual_tiles[pos].is_wall() && visual_tiles[pos - 1 - size] && visual_tiles[pos - 1 - size].is_wall():
	# 	visual_tiles[pos - 1 - size].show()
	# if !visual_tiles[pos].is_wall() && visual_tiles[pos + 1 - size] && visual_tiles[pos + 1 - size].is_wall():
	# 	visual_tiles[pos + 1 - size].show()
	# if !visual_tiles[pos].is_wall() && visual_tiles[pos - 1 + size] && visual_tiles[pos - 1 + size].is_wall():
	# 	visual_tiles[pos - 1 + size].show()
	# if !visual_tiles[pos].is_wall() && visual_tiles[pos + 1 + size] && visual_tiles[pos + 1 + size].is_wall():
	# 	visual_tiles[pos + 1 + size].show()

	if sight_left == 0:
		return

	if visual_tiles[pos].is_wall() || visual_tiles[pos].is_door():
		return
	
	floodfill_sight(pos - 1, sight_left - 1, visited)
	floodfill_sight(pos + 1, sight_left - 1, visited)
	floodfill_sight(pos - size, sight_left - 1, visited)
	floodfill_sight(pos + size, sight_left - 1, visited)


func is_action_valid(action: String) -> bool:
	var time := Time.get_ticks_msec()
	return Input.is_action_just_pressed(action) || (Input.is_action_pressed(action) && time - _last_action_time > 100)


func get_movement_dir() -> Vector2i:
	var time := Time.get_ticks_msec()
	var dir := Vector2i.ZERO
	if is_action_valid("up"):
		dir = Vector2i(0, -1)
		_last_action_time = time
	elif is_action_valid("down"):
		dir = Vector2i(0, 1)
		_last_action_time = time
	elif is_action_valid("left"):
		dir = Vector2i(-1, 0)
		_last_action_time = time
	elif is_action_valid("right"):
		dir = Vector2i(1, 0)
		_last_action_time = time

	return dir

func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return

	time_to_clear = maxf(0, time_to_clear - dt)

	var dir := get_movement_dir()

	if Input.is_action_just_pressed("plussight"):
		player_sight += 1
	if Input.is_action_just_pressed("minussight"):
		player_sight -= 1
	
	if is_walkable(player_pos + dir):
		player_pos += dir

	if Input.is_action_just_pressed("metro1") && player_metros.size() >= 1:
		player_pos = i_to_xy(player_metros[0].i)
		audio_metro_use.play()

	if Input.is_action_just_pressed("metro2") && player_metros.size() >= 2:
		player_pos = i_to_xy(player_metros[1].i)
		audio_metro_use.play()

	if Input.is_action_just_pressed("metro3") && player_metros.size() >= 3:
		player_pos = i_to_xy(player_metros[2].i)
		audio_metro_use.play()

	if Input.is_action_just_pressed("metro4") && player_metros.size() >= 4:
		player_pos = i_to_xy(player_metros[3].i)
		audio_metro_use.play()

	player.position = player_pos * Vector2i(16, 16) + Vector2i(8, 8)

	var player_i := xy_to_i(player_pos)
	if visual_tiles[player_i] != null:
		if visual_tiles[player_i].is_key():
			keys_inventory.append(visual_tiles[player_i].key_number)
			visual_tiles[player_i].cell_type = TileSprite.CellType.ORIG_CELL
			audio_key_pickup.play()
			new_message("You picked up key {0}".format([str(visual_tiles[player_i].key_number)]))
		if visual_tiles[player_i].cell_type == TileSprite.CellType.PLUSSIGHT:
			player_sight += 2
			visual_tiles[player_i].cell_type = TileSprite.CellType.ORIG_CELL
			audio_powerup_pickup.play()
			new_message("You now see further", 0.5)
		if visual_tiles[player_i].is_door():
			visual_tiles[player_i].cell_type = TileSprite.CellType.OPENED_DOOR
			audio_door_open.play()
			keys_inventory.erase(visual_tiles[player_i].door_number)
		if visual_tiles[player_i].cell_type == TileSprite.CellType.ONEWAY_WALL:
			edges[player_i].is_one_way = false
			audio_break_wall.play()
			visual_tiles[player_i].cell_type = TileSprite.CellType.BROKEN_WALL
		if visual_tiles[player_i].cell_type == TileSprite.CellType.METRO && !metro_stations[player_i].activated:
			metro_stations[player_i].activated = true
			player_metros.append(metro_stations[player_i])
			audio_metro_open.play()
			new_message("Metro activated! Press {0} to warp to it.".format([player_metros.size()]), 0.5)
			visual_tiles[player_i].constant_light = true
			
	var win_condition: bool = (visual_tiles[player_i] != null && visual_tiles[player_i].group_id != -1 && visual_tiles[player_i].group_id == player_path.back())
	if win_condition && !player_won:
		player_won = true
		new_message("You won!!!")
	for tile_i in range(0, visual_tiles.size()):
		if player_won || visual_tiles[tile_i].constant_light:
			visual_tiles[tile_i].show()
		else:
			visual_tiles[tile_i].hide()
	
	if !player_won:
		floodfill_sight(player_i, player_sight)
		
	keys_label.text = ",".join(keys_inventory.map(str))
	playerpos_label.text = str(player_pos)
	time_label.text = "{0}s".format([str(snappedf(time_to_clear, 0.1))])

	# if dir != Vector2i.ZERO:
	# 	print(player_pos, visual_tiles[player_i].group_id)
	# 	if edges.has(player_i):
	# 		print(edges[player_i].id(), edges[player_i].dir)
