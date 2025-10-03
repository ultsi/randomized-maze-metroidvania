@tool
class_name MeshTileMap extends Node2D

@export_range(1, 100, 1) var wide := 3

var multimesh: MultiMesh

class AtlasTiles:
	const VERT := Vector2i(5, 6)
	const HORIZ := Vector2i(6, 5)
	const CORNER_NE := Vector2i(5, 5)
	const CORNER_NW := Vector2i(15, 5)
	const CORNER_SE := Vector2i(9, 13)
	const CORNER_SW := Vector2i(7, 13)
	const INNER_N := Vector2i(11, 15)
	const INNER_E := Vector2i(15, 2)
	const INNER_W := Vector2i(5, 9)
	const INNER_S := Vector2i(11, 5)
	const CENTER := Vector2i(8, 3)

	const DOOR := Vector2i(7, 4)

var grid: Array[Tile.Type] = []
var grid_nbors: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
var cw_nbors: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2(-1, 0), Vector2i(-1, -11)
]
var shuffle_start := 0
var fly_dir := Vector2.ONE
@export var shuffling := false:
	set(value):
		shuffling = value
		shuffle_start = Time.get_ticks_msec()

func _ready() -> void:
	reset()

func calc_pos_nbors_mask(pos: Vector2i, match_type: Tile.Type) -> int:
	# clockwise
	var mask := 0
	for i in range(0, 8):
		var bits := 1 << (7 - i)
		var dir := cw_nbors[i]
		var nbor_pos := pos + dir
		if nbor_pos.x < 0 || nbor_pos.x >= wide || nbor_pos.y < 0 || nbor_pos.y >= wide:
			continue
		var nbor_i := nbor_pos.x + nbor_pos.y * wide
		if grid[nbor_i] == match_type:
			mask += bits

	return mask

func calc_grid_nbors() -> void:
	grid_nbors.resize(grid.size())
	for i in range(0, grid.size()):
		var y := int(float(i) / wide)
		grid_nbors[i] = calc_pos_nbors_mask(Vector2i(i - y * wide, y), grid[i])

func get_wall_tile_for_pos(pos: int) -> Vector2i:
	var mask := grid_nbors[pos]
	# vertical
	if (mask & 0b10101010) == 0b10001000:
		return AtlasTiles.VERT
		# bottom and top
	if (mask & 0b10101010) == 0b10000000:
		return Vector2i(7, 7)
	if (mask & 0b10101010) == 0b00001000:
		return Vector2i(7, 11)
	
	#horizontal
	if (mask & 0b10101010) == 0b00100010:
		return Vector2i(6, 9)
	# special cases
	#left 
	if (mask & 0b10101010) == 0b00000010:
		return Vector2i(13, 2)
	if (mask & 0b10101010) == 0b00100000:
		return Vector2i(13, 7)

	# corners
	if (mask & 0b10111010) == 0b00101000:
		return AtlasTiles.CORNER_NW

	if (mask & 0b10111010) == 0b00001010:
		return AtlasTiles.CORNER_NE

	if (mask & 0b10111010) == 0b10100000:
		return AtlasTiles.CORNER_SE
	
	if (mask & 0b10111010) == 0b10100000:
		return AtlasTiles.CORNER_SW


	# inners
	if (mask & 0b10101010) == 0b10100010:
		return AtlasTiles.INNER_N

	if (mask & 0b10101010) == 0b10101000:
		return AtlasTiles.INNER_E

	if (mask & 0b10101010) == 0b00101010:
		return AtlasTiles.INNER_S

	if (mask & 0b10101010) == 0b10001010:
		return AtlasTiles.INNER_W

	# center
	if (mask & 0b10101010) == 0b10101010:
		return AtlasTiles.CENTER

	print("default for ", pos, " and mask ", String.num_int64(mask, 2).pad_zeros(8))
	return Vector2i(5, 15)

func get_tile_for_pos(pos: int) -> Vector2i:
	if grid[pos] == Tile.WALL:
		return get_wall_tile_for_pos(pos)


	return Vector2i(6, 7)

func draw_grid() -> void:
	calc_grid_nbors()
	for y in range(0, wide):
		for x in range(0, wide):
			var i := x + y * wide
			var t2d := global_transform
			t2d.origin += Vector2(16 * x, 16 * y) + Vector2(8, 8)
			var tile := get_tile_for_pos(i)
			var palette_idx := 0 if grid[i] == Tile.WALL else 1
			multimesh.set_instance_transform_2d(i, t2d)
			multimesh.set_instance_custom_data(i, Color(tile.x / 16.0, tile.y / 16.0, palette_idx, 1))
			#multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, 1.0))

func set_color(i: int, color: Color) -> void:
	multimesh.set_instance_color(i, color)


func reset() -> void:
	var multimesh_inst := $MultiMeshInstance2D as MultiMeshInstance2D
	multimesh = multimesh_inst.multimesh
	multimesh.instance_count = 0
	multimesh.visible_instance_count = -1
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.transform_format = MultiMesh.TRANSFORM_2D

	multimesh.instance_count = wide * wide

	grid.resize(wide * wide)

	draw_grid()

func _process(delta: float) -> void:
	if !shuffling:
		return


	for y in range(0, wide):
		for x in range(0, wide):
			var i := x + y * wide
			var t2d := global_transform
			var angle := i + Time.get_ticks_msec() / 500.0
			var peak := 2
			t2d.origin += Vector2(16 * x, 16 * y) + Vector2(8, 8) + Vector2(cos(angle), sin(angle)) * peak
			multimesh.set_instance_transform_2d(i, t2d)
