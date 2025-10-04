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
	var old_edge_id := edge.id()
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
		var edge_id := other_edge.id()
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
	var ipos := edge.ipos
	var room_a := room_with_id(edge.a)
	var room_b := room_with_id(edge.b)
	if room_a.id != room_b.id && room_a.tiles.size() < wide / 2 && room_b.tiles.size() < wide / 2:
		combine_rooms_with_edge(edge)

func kruskal_forest() -> void:
	while !kruskal_edges.is_empty():
		one_step_kruskal()

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
