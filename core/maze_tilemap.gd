@tool class_name MazeTileMap extends TileMapLayer

@export_range(3, 30, 2) var ui_size := 3:
	set(value):
		ui_size = value
		_reset_grid()

@export_tool_button("One step kruskal") var one_step := one_step_kruskal

@export_tool_button("Generate kruskal forest") var kruskal_multi_btn := kruskal_forest

@onready var tiles_parent := $Tiles as Node2D
@onready var player := $Player as Sprite2D
@onready var keys_label := $KeysLabel as Label
@onready var playerpos_label := $PlayerPos as Label

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
var collected_keys: Array[int] = []
var player_path: Array[int] = []
var player_sight := 3
var start_node: CellsNode

var metro_stations: Dictionary[int, MetroStation] = {}
var player_metros: Array[MetroStation] = []

enum PowerUp {
	Metro,
	PlusSight
}

var powerups: Array[PowerUp] = [PowerUp.Metro, PowerUp.PlusSight, PowerUp.Metro, PowerUp.PlusSight]
var plus_sight_cell := -1


func i_to_xy(i: int) -> Vector2i:
	var y := int(float(i) / size)
	return Vector2i(i - y * size, y)

func xy_to_i(xy: Vector2i) -> int:
	return xy.y * size + xy.x

func _init() -> void:
	tile_set = preload("res://materials/tileset.tres")

func _ready() -> void:
	seed(2)
	await _reset_grid()
	if !Engine.is_editor_hint():
		kruskal_forest()
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
	clear()
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
		visual_tiles[pos_i].cell_type = TileSprite.CellType.JOINED_CELLS
		_combine_cells_nodes(edge)
		draw_grid()


func kruskal_forest() -> void:
	var safety := 100
	while cells_nodes.size() > size && safety > 0:
		print(cells_nodes.size())
		safety -= 1
		one_step_kruskal()

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

		var node := cells_nodes[node_id]
		if node.cells.size() == 1:
			var tmp := node_edges.duplicate()
			var randomized_edges: Array[Edge] = []
			for i in range(0, tmp.size()):
				var edge: Edge = tmp.pick_random()
				tmp.erase(edge)
				randomized_edges.append(edge)
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

		var max_edges := maxi(node.cells.size() / 2, 2)
		for i in range(0, max_edges):
			var valid_edge: Edge = node_edges.pick_random()
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
	
	for i in range(0, player_path.size()):
		var key_i: int = cells_nodes[player_path[i]].cells.keys().pick_random()
		visual_tiles[key_i].key_number = i
		visual_tiles[key_i].cell_type = TileSprite.CellType.KEY

	var next_powerup_node := player_path.size() / 4
	var increment := (player_path.size() - next_powerup_node) / powerups.size()
	print("Powerups starting from {0} with increment of {1}. Total area size {2}, powerups count {3}".format([next_powerup_node, increment, player_path.size(), powerups.size()]))
	for powerup in powerups:
		var node_id := player_path[next_powerup_node]
		var node := cells_nodes[node_id]
		var safety := 3
		while node.cells.size() == 1 && safety > 0:
			next_powerup_node += 1
			node_id = player_path[next_powerup_node]
			node = cells_nodes[node_id]
			safety -= 1
		var powerup_i: int = node.cells.keys().pick_random()
		safety = 3
		while visual_tiles[powerup_i].cell_type != TileSprite.CellType.ORIG_CELL && safety > 0:
			powerup_i = node.cells.keys().pick_random()
			safety -= 1

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
		return collected_keys.has(visual_tiles[i].door_number)
	
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

	if Input.is_action_just_pressed("metro1") && player_metros.size() >= 1:
		player_pos = i_to_xy(player_metros[0].i)

	if Input.is_action_just_pressed("metro2") && player_metros.size() >= 2:
		player_pos = i_to_xy(player_metros[1].i)

	if Input.is_action_just_pressed("metro3") && player_metros.size() >= 3:
		player_pos = i_to_xy(player_metros[2].i)

	if Input.is_action_just_pressed("metro4") && player_metros.size() >= 4:
		player_pos = i_to_xy(player_metros[3].i)

	player.position = player_pos * Vector2i(16, 16) + Vector2i(8, 8)

	var player_i := xy_to_i(player_pos)
	if visual_tiles[player_i] != null:
		if visual_tiles[player_i].is_key():
			collected_keys.append(visual_tiles[player_i].key_number)
			visual_tiles[player_i].cell_type = TileSprite.CellType.ORIG_CELL
		if visual_tiles[player_i].cell_type == TileSprite.CellType.PLUSSIGHT:
			player_sight += 2
			visual_tiles[player_i].cell_type = TileSprite.CellType.ORIG_CELL
		if visual_tiles[player_i].is_door():
			visual_tiles[player_i].cell_type = TileSprite.CellType.OPENED_DOOR
		if visual_tiles[player_i].cell_type == TileSprite.CellType.ONEWAY_WALL:
			edges[player_i].is_one_way = false
			visual_tiles[player_i].cell_type = TileSprite.CellType.BROKEN_WALL
		if visual_tiles[player_i].cell_type == TileSprite.CellType.METRO && !metro_stations[player_i].activated:
			metro_stations[player_i].activated = true
			player_metros.append(metro_stations[player_i])
			

	var won: bool = visual_tiles[player_i] != null && visual_tiles[player_i].group_id != -1 && visual_tiles[player_i].group_id == player_path.back()
	for tile_i in range(0, visual_tiles.size()):
		if won:
			visual_tiles[tile_i].show()
		else:
			visual_tiles[tile_i].hide()
	
	if !won:
		floodfill_sight(player_i, player_sight)
		
	keys_label.text = ",".join(collected_keys.map(str))
	playerpos_label.text = str(player_pos)

	if dir != Vector2i.ZERO:
		print(player_pos, visual_tiles[player_i].group_id)
		if edges.has(player_i):
			print(edges[player_i].id(), edges[player_i].dir)
