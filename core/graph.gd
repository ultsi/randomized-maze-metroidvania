@tool
class_name MazeGraph extends RefCounted

class RoomNode extends RefCounted:
	var id := 0
	var tiles: Dictionary[int, Tile] = {}

class Edge extends RefCounted:
	var a: int
	var b: int
	var dir: int = -1
	var tile: Tile
	var pos: Vector2i
	var ipos: int
	var is_one_way := false

	func id() -> String:
		var node_ids := [a, b]
		if a > b:
			node_ids = [b, a]
		return "{0}-{1}".format(node_ids)

var _size := wide * wide
var wide: int = 3:
	set(value):
		if wide > 0:
			wide = value
			_size = wide * wide

# tiles are all things in the maze, walls, floors, oneways etc
# tiles can have keys and doors in them (see Tile)
# tiles are just an array, and the index is the ipos (xy as an int)
var tiles: Array[Tile] = []

# edges are just edges in graph sense, connecting rooms to each other
# not each wall is an edge
var edges: Dictionary[int, Edge] = {}

# rooms are just nodes in graph sense, they can have a lot of tiles (floor)
# in them, and a few edges leading to other rooms
# here the key is the Room.id
var rooms: Dictionary[int, RoomNode] = {}

# these are just the potential edges collection the kruskal algorithm picks from
var kruskal_edges: Dictionary[int, Edge] = {}

func ipos_to_xy(i: int) -> Vector2i:
	var y := int(float(i) / wide)
	return Vector2i(i - y * wide, y)

func xy_to_ipos(xy: Vector2i) -> int:
	return xy.y * wide + xy.x

func tile_at(ipos: int) -> Tile:
	if ipos < 0 || ipos >= tiles.size():
		return null

	return tiles[ipos]

func room_add(room: RoomNode) -> void:
	rooms[room.id] = room

func room_with_id(id: int) -> RoomNode:
	if rooms.has(id):
		return rooms[id]

	return null

func room_erase_id(id: int) -> void:
	rooms.erase(id)

func room_at_ipos(ipos: int) -> RoomNode:
	var tile := tile_at(ipos)
	if !tile:
		return null

	return room_with_id(tile.room)

func edge_erase_all_refs(ipos: int) -> void:
	edges.erase(ipos)
	kruskal_edges.erase(ipos)

func reset() -> void:
	edges.clear()
	tiles.clear()
	tiles.resize(_size)

	for y in range(0, wide):
		for x in range(0, wide):
			var xy := Vector2i(x, y)
			var ipos := xy_to_ipos(xy)
			var tile := Tile.new()
			tile.pos = xy
			tile.ipos = ipos
			
			tile.type = Tile.WALL

			tiles[ipos] = tile

# this is kruskal first step
func form_initial_rooms() -> void:
	var big_room_id := 999
	# var big_room := RoomNode.new()
	# big_room.id = big_room_id
	# room_add(big_room)

	# for y in range(0, 5):
	# 	for x in range(0, 5):
	# 		var xy := Vector2i(wide / 2, wide / 2) + Vector2i(x, y)
	# 		var ipos := xy_to_ipos(xy)
	# 		var tile := tile_at(ipos)
	# 		tile.room = big_room.id
	# 		tile.type = Tile.FLOOR
	# 		big_room.tiles[ipos] = tile

	for ipos in range(0, tiles.size()):
		var xy := ipos_to_xy(ipos)
		var tile := tile_at(ipos)
		if tile.room == big_room_id || xy.x % 2 != 1 || xy.y % 2 != 1:
			#not a new room
			continue
		# it's a room!
		var room := RoomNode.new()
		room.id = rooms.size()

		tile.room = room.id
		tile.type = Tile.FLOOR

		room.tiles = {ipos: tile}
		room_add(room)

func form_initial_edges() -> void:
	for ipos in range(0, tiles.size()):
		var xy := ipos_to_xy(ipos)
		var tile := tile_at(ipos)
		if tile.is_floor() || xy.x % 2 == xy.y % 2 || xy.x <= 0 || xy.y <= 0 || xy.x >= wide - 1 || xy.y >= wide - 1:
			continue
		
		# valid edge between initial rooms
		var edge := Edge.new()
		edge.ipos = ipos
		edge.pos = xy
		edge.tile = tile

		#print("Found edge at xy ", xy, " size ", _size)

		if xy.y % 2 == 1:
			# edge is horizontally between rooms
			edge.a = room_at_ipos(ipos - 1).id
			edge.b = room_at_ipos(ipos + 1).id
		else:
			# edge is vertically between rooms
			edge.a = room_at_ipos(ipos - wide).id
			edge.b = room_at_ipos(ipos + wide).id

		edges[ipos] = edge
		#print("Added edge ", edge.id())

	kruskal_edges = edges.duplicate()


func combine_rooms_with_edge(edge: Edge) -> void:
	#print("Combining with edge ", edge.id())
	# var old_edge_id := edge.id()
	var room_a := room_with_id(edge.a)
	var room_b := room_with_id(edge.b)
	var old_id := room_b.id
	room_b.id = room_a.id

	# combine all tiles first
	for tile_ipos in room_b.tiles:
		#print("a", cell_i)
		room_a.tiles[tile_ipos] = room_b.tiles[tile_ipos]
	
	#edge tile is now a room tile as well
	room_a.tiles[edge.ipos] = edge.tile

	# set room id for all tiles correct
	# and the tile type
	for tile_ipos in room_a.tiles:
		room_a.tiles[tile_ipos].room = room_a.id
		room_a.tiles[tile_ipos].type = Tile.FLOOR
	
	edge_erase_all_refs(edge.ipos)
	room_erase_id(old_id)

	var edge_to_remove: Array[int] = []

	# update other edges links to room b to link to room b
	for edge_ipos in edges:
		var other_edge := edges[edge_ipos]
		# var edge_id := other_edge.id()
		if other_edge.a == old_id:
			other_edge.a = room_a.id
		if other_edge.b == old_id:
			other_edge.b = room_a.id

		if other_edge.a == other_edge.b:
			# edge is now connecting the room with itself instead of connecting to another room, remove it 
			edge_to_remove.append(edge_ipos)

	for edge_ipos in edge_to_remove:
		edge_erase_all_refs(edge_ipos)

	#print("Combined {0}, old_size: {1} new size:  {2}".format([old_edge_id, old_size, room_a.tiles.size()]))
	#print("Combined rooms with edge ", old_edge_id, " removed room ", old_id)
	
	#print("Rooms now: ", ",".join(rooms.keys().map(str)))
	#print("Edges now: ", ",".join(edges.values().map(func(e: Edge) -> String: return e.id())))


func one_step_kruskal() -> void:
	var edge: Edge = kruskal_edges.values().pick_random()
	if !edge:
		return
	kruskal_edges.erase(edge.ipos)
	
	#print("Trying edge ", edge.id())
	var room_a := room_with_id(edge.a)
	var room_b := room_with_id(edge.b)
	@warning_ignore("integer_division")
	if room_a.id != room_b.id && room_a.tiles.size() < wide / 4 * 3 && room_b.tiles.size() < wide / 4 * 3:
		combine_rooms_with_edge(edge)

func kruskal_forest() -> void:
	while !kruskal_edges.is_empty():
		one_step_kruskal()

	print("generated {0} rooms".format([rooms.size()]))

func find_edges_around_ipos(ipos: int) -> Array[Edge]:
	var found_edges: Array[Edge] = []
	if edges.has(ipos - 1):
		found_edges.append(edges[ipos - 1])
	if edges.has(ipos + 1):
		found_edges.append(edges[ipos + 1])
	if edges.has(ipos - wide):
		found_edges.append(edges[ipos - wide])
	if edges.has(ipos + wide):
		found_edges.append(edges[ipos + wide])
	return found_edges

func fix_single_tile_rooms() -> void:
	for room_id: int in rooms.keys():
		var room := room_with_id(room_id)
		if room == null:
			# need to check this because the combine_rooms_with_edge erases rooms as it goes
			# so this can be null after
			continue

		if room.tiles.size() > 1:
			continue

		var room_edges := find_edges_around_ipos(room.tiles.keys()[0])
		if room_edges.size() == 0:
			print("No edges found for room ", room_id)
			continue
		
		var selected_edge: Edge = room_edges.pick_random()
		combine_rooms_with_edge(selected_edge)
	
	print("fixed to {0} rooms".format([rooms.size()]))

class RoomEdges:
	var id: int
	var edges: Array[Edge] = []

func generate_door_from_edge(edge: Edge) -> void:
	var room_a := room_with_id(edge.a)
	
	#edge tile belongs now to room A
	room_a.tiles[edge.ipos] = edge.tile

	# set room id for all tiles correct
	# and the tile type
	for tile_ipos in room_a.tiles:
		room_a.tiles[tile_ipos].room = room_a.id
		room_a.tiles[tile_ipos].type = Tile.FLOOR

	edge.tile.room = 49
	
	edge_erase_all_refs(edge.ipos)
	

func generate_doors() -> void:
	var edges_by_room_id: Dictionary[int, RoomEdges] = {}

	for edge: Edge in edges.values():
		if edge.a == edge.b:
			print("Self referencing room edge found ", edge.id())
			continue
		if edges_by_room_id.has(edge.a):
			edges_by_room_id[edge.a].edges.append(edge)
		else:
			edges_by_room_id[edge.a] = RoomEdges.new()
			edges_by_room_id[edge.a].id = edge.a

		if edges_by_room_id.has(edge.b):
			edges_by_room_id[edge.b].edges.append(edge)
		else:
			edges_by_room_id[edge.b] = RoomEdges.new()
			edges_by_room_id[edge.b].id = edge.b

	var unique_edges: Dictionary[String, Edge] = {}

	for room_id in edges_by_room_id:
		var room := room_with_id(room_id)
		var room_edges := edges_by_room_id[room_id]
		if room_edges.edges.size() <= 1:
			continue
		room_edges.edges.shuffle()

		if room.tiles.size() == 1:
			print("Weird, room {0} has 1 tile only. Shouldn't happen? ".format([room_id]))
			var edge := room_edges.edges[0]
			unique_edges[edge.id()] = edge
			continue

		var max_edges := room_edges.edges.size()
		for i in range(randi_range(0, max_edges), max_edges):
			var edge := room_edges.edges[i]
			unique_edges[edge.id()] = edge
		
	for edge_id in unique_edges:
		var edge := unique_edges[edge_id]
		generate_door_from_edge(edge)

# func generate_doors_and_keys() -> void:
# 	var edge_dict: Dictionary[String, Edge] = {}
# 	for edge in edges.values():
# 		edge_dict[edge.id()] = edge

# 	var edges_by_node_id: Dictionary[int, Array] = {}

# 	for edge: Edge in edge_dict.values():
# 		if edge.a == edge.b:
# 			continue
# 		if edges_by_node_id.has(edge.a):
# 			edges_by_node_id[edge.a].append(edge)
# 		else:
# 			edges_by_node_id[edge.a] = [edge]

# 		if edges_by_node_id.has(edge.b):
# 			edges_by_node_id[edge.b].append(edge)
# 		else:
# 			edges_by_node_id[edge.b] = [edge]

# 	var valid_edges: Dictionary[String, Edge] = {}

# 	for node_id in edges_by_node_id:
# 		var edges := edges_by_node_id[node_id]
# 		var estr := edges.map(func(e: Edge) -> String: return e.id())
# 		print("Node {0} edges: {1}".format([node_id, str(estr)]))

# 	for node_id in edges_by_node_id:
# 		var node_edges := edges_by_node_id[node_id]
# 		node_edges.shuffle()
# 		if node_edges.size() == 1:
# 			valid_edges[node_edges[0].id()] = node_edges[0]
# 			continue

# 		var node := cells_nodes[node_id]
# 		if node.cells.size() == 1:
# 			var valid_edge: Edge
# 			for edge: Edge in node_edges:
# 				valid_edge = edge
# 				var node_a := cells_nodes[edge.a]
# 				var node_b := cells_nodes[edge.b]
# 				if node_a.cells.size() > 1 || node_b.cells.size() > 1:
# 					break
			
# 			valid_edges[valid_edge.id()] = valid_edge
# 			for edge in node_edges:
# 				if edge.id() == valid_edge.id():
# 					continue
# 				valid_edges.erase(edge.id())
# 			continue

# 		var max_edges := node_edges.size()
# 		for i in range(max_edges * randf(), max_edges):
# 			var valid_edge: Edge = node_edges[i]
# 			valid_edges[valid_edge.id()] = valid_edge

# 	var estr := valid_edges.values().map(func(e: Edge) -> String: return e.id())
# 	print("Valid edges: ", estr)
	
# 	# for node_id in edges_by_node_id:
# 	# 	var node := cells_nodes[node_id]
# 	# 	var node_edges := edges_by_node_id[node_id]
# 	# 	if node.cells.size() == 1 && node_edges.size() > 1:
# 	# 		print("LOL?", node.id)
# 	edges_by_node_id.clear()
# 	for edge: Edge in valid_edges.values():
# 		edge.type = TileSprite.CellType.DOOR
# 		edge.tile_sprite.cell_type = TileSprite.CellType.DOOR
# 		edge.tile.type = Tile.FLOOR
# 		edge.tile_sprite.group_id = edge.a
# 		if edges_by_node_id.has(edge.a):
# 			edges_by_node_id[edge.a].append(edge)
# 		else:
# 			edges_by_node_id[edge.a] = [edge]

# 		if edges_by_node_id.has(edge.b):
# 			edges_by_node_id[edge.b].append(edge)
# 		else:
# 			edges_by_node_id[edge.b] = [edge]

# 	# form directed graph here
# 	# important because player path is directed and that way
# 	# we then know which doors are actual blockers
# 	# and which ones are openable shortcuts from the other side
# 	var edge_queue: Array = edges_by_node_id[start_node.id]
# 	var door_number := 0
# 	var handled_edges: Dictionary[String, bool] = {}
# 	var visited_nodes: Dictionary[int, bool] = {start_node.id: true}
# 	player_path = [start_node.id]
# 	while !edge_queue.is_empty():
# 		var edge: Edge = edge_queue.pick_random()
# 		edge_queue.erase(edge)
# 		if handled_edges.has(edge.id()):
# 			continue
# 		handled_edges[edge.id()] = true
# 		if visited_nodes.has(edge.a) && visited_nodes.has(edge.b):
# 			edge.tile_sprite.door_number = -1
# 			edge.tile_sprite.cell_type = TileSprite.CellType.WALL
# 			edge.is_one_way = true
# 			edge.dir = edge.b if player_path.find(edge.a) < player_path.find(edge.b) else edge.a
# 			edge.tile_sprite.group_id = edge.dir
# 		else:
# 			edge.tile_sprite.door_number = door_number
# 			door_number += 1
# 			edge.tile_sprite.cell_type = TileSprite.CellType.DOOR

# 		if !visited_nodes.has(edge.a):
# 			if edges_by_node_id.has(edge.a):
# 				edge_queue.append_array(edges_by_node_id[edge.a])
# 				visited_nodes[edge.a] = true
# 				player_path.append(edge.a)
# 		if !visited_nodes.has(edge.b):
# 			if edges_by_node_id.has(edge.b):
# 				edge_queue.append_array(edges_by_node_id[edge.b])
# 				visited_nodes[edge.b] = true
# 				player_path.append(edge.b)