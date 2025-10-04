@tool
class_name TileSprite extends Sprite2D

const colors: Array[Color] = [
	Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1), Color(1, 1, 0), Color(1, 0, 1),
	Color(0, 1, 1), Color(1, 0.5, 0), Color(0.5, 1, 0), Color(0, 1, 0.5), Color(0.5, 0, 1),
	Color(1, 0, 0.5), Color(0.5, 1, 1), Color(1, 1, 0.5), Color(0.5, 0.5, 1), Color(1, 0.5, 1),
	Color(0.25, 0.75, 0.25), Color(0.75, 0.25, 0.75), Color(0.25, 0.25, 0.75), Color(0.75, 0.75, 0.25), Color(0.25, 0.75, 0.75),
	Color(0.6, 0.2, 0.2), Color(0.2, 0.6, 0.2), Color(0.2, 0.2, 0.6), Color(0.6, 0.6, 0.2), Color(0.6, 0.2, 0.6),
	Color(0.2, 0.6, 0.6), Color(0.9, 0.3, 0.3), Color(0.3, 0.9, 0.3), Color(0.3, 0.3, 0.9), Color(0.9, 0.9, 0.3),
	Color(0.9, 0.3, 0.9), Color(0.3, 0.9, 0.9), Color(0.8, 0.4, 0.2), Color(0.2, 0.8, 0.4), Color(0.4, 0.2, 0.8),
	Color(0.8, 0.2, 0.4), Color(0.4, 0.8, 0.2), Color(0.2, 0.4, 0.8), Color(0.7, 0.3, 0.5), Color(0.5, 0.7, 0.3),
	Color(0.3, 0.5, 0.7), Color(0.7, 0.5, 0.3), Color(0.5, 0.3, 0.7), Color(0.3, 0.7, 0.5), Color(0.6, 0.3, 0.6),
	Color(0.3, 0.6, 0.3), Color(0.6, 0.6, 0.3), Color(0.3, 0.6, 0.6), Color(0.6, 0.3, 0.3), Color(0.3, 0.3, 0.6)
]

@export_range(0, 200, 1) var group_id := -1:
	set(value):
		group_id = value
		update()
@export var cell_type := CellType.WALL:
	set(value):
		cell_type = value
		update()

@export var world_grid_pos := Vector2i.ZERO:
	set(value):
		world_grid_pos = value
		update()

@export var label_text := "":
	set(value):
		label_text = value
		update()

enum CellType {
	WALL,
	ORIG_CELL,
	JOINED_CELLS,
	DOOR,
	OPENED_DOOR,
	ONEWAY_WALL,
	BROKEN_WALL,
	KEY,
	PLUSSIGHT,
	METRO,
	TORCH
}

var shader: ShaderMaterial
var label: Label
var door_number := -1
var key_number := -1
var constant_light := false
@export var player_vision := 0:
	set(value):
		player_vision = value
		update()

static func get_cell_tile_for_type(type: CellType) -> Vector2i:
	match type:
		CellType.WALL:
			return Vector2i(5, 6)
		CellType.ORIG_CELL:
			return Vector2i(6, 7)
		CellType.JOINED_CELLS:
			return Vector2i(6, 7)
		CellType.DOOR:
			return Vector2i(7, 4)
		CellType.OPENED_DOOR:
			return Vector2i(1, 2)
		CellType.ONEWAY_WALL:
			return Vector2i(8, 5)
		CellType.BROKEN_WALL:
			return Vector2i(8, 6)
		CellType.KEY:
			return Vector2i(2, 1)
		CellType.PLUSSIGHT:
			return Vector2i(3, 1)
		CellType.METRO:
			return Vector2i(2, 2)
		CellType.TORCH:
			return Vector2i(4, 1)
	
	return Vector2i(1, 0)

func _init() -> void:
	texture = PlaceholderTexture2D.new()
	texture.size = Vector2(16, 16)
	material = preload("res://core/tile_sprite_shader.tres").duplicate()
	shader = material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	for child in get_children():
		print("freeing tilesprite child ", child)
		child.queue_free()
		print("freed")
	label = Label.new()
	add_child(label)
	label.owner = self
	label.z_index = 2
	label.anchor_top = 0.0
	label.anchor_right = 0.0
	label.anchor_bottom = 0.0
	label.anchor_left = 0.0
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.text = "A"
	label.label_settings = preload("res://core/tile_sprite_label_settings.tres")
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	update()

func update() -> void:
	if !is_node_ready():
		return
	
	position = world_grid_pos * Vector2i(16, 16) + Vector2i(8, 8)

	shader.set_shader_parameter("tile_pos", get_cell_tile_for_type(cell_type))
	shader.set_shader_parameter("tint_amount", 0.0 if cell_type == CellType.ORIG_CELL else 0.0)

	var orig_color := colors[group_id % 50]
	var color := orig_color
	# if player_vision < 4:
	# 	color = color
	# 	color.a = 1.0
	# 	modulate.a = color.a
	# elif player_vision < 6:
	# 	color = color * 0.5
	# 	color.a = 0.5
	# 	modulate.a = color.a
	# elif player_vision < 8:
	# 	color = color * 0.25
	# 	color.a = 0.25
	# 	modulate.a = color.a
	# elif player_vision < 10:
	# 	color = color * 0.125
	# 	color.a = 0.125
	# 	modulate.a = color.a
	# elif player_vision < 12:
	# 	color = color * 0.075
	# 	color.a = 0.075
	# 	modulate.a = color.a
	# else:
	# 	color = color * 0.0
	# 	color.a = 0.0
	# 	modulate.a = color.a

	# if constant_light:
	# 	color.a = 1.0
	# 	modulate.a = color.a
	# 	color.r = maxf(color.r, orig_color.r * 0.2)
	# 	color.g = maxf(color.g, orig_color.g * 0.2)
	# 	color.b = maxf(color.b, orig_color.b * 0.2)

	shader.set_shader_parameter("tint", color)

	if cell_type == CellType.KEY:
		label.text = str(key_number)
		label.hide()
	elif cell_type == CellType.DOOR:
		label.text = str(door_number)
		label.show()
	elif cell_type == CellType.ORIG_CELL:
		label.text = str(group_id)
		label.hide()
	elif cell_type == CellType.ONEWAY_WALL:
		label.text = str(group_id)
		label.hide()
	else:
		label.hide()

func is_door() -> bool:
	return cell_type == CellType.DOOR

func is_key() -> bool:
	return cell_type == CellType.KEY

func is_wall() -> bool:
	return cell_type == CellType.WALL
