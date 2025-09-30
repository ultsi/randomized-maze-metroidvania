@tool
class_name TileSprite extends Sprite2D

var colors = [
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

@export_range(0, 200, 1) var group_id := 0:
	set(value):
		group_id = value
		_update()
@export var cell_type := CellType.WALL:
	set(value):
		cell_type = value
		_update()

@export var world_grid_pos := Vector2i.ZERO:
	set(value):
		world_grid_pos = value
		_update()

@export var label_text := "":
	set(value):
		label_text = value
		_update()

enum CellType {
	WALL,
	ORIG_CELL,
	JOINED_CELLS,
	DOOR,
	OPENED_DOOR,
	KEY,
	PLUSSIGHT,
}

var shader: ShaderMaterial
var label: Label
var door_number := -1
var key_number := -1

static func get_cell_tile_for_type(type: CellType) -> Vector2i:
	match type:
		CellType.WALL:
			return Vector2i(1, 0)
		CellType.ORIG_CELL:
			return Vector2i(0, 0)
		CellType.JOINED_CELLS:
			return Vector2i(0, 1)
		CellType.DOOR:
			return Vector2i(1, 1)
		CellType.OPENED_DOOR:
			return Vector2i(1, 2)
		CellType.KEY:
			return Vector2i(2, 1)
		CellType.PLUSSIGHT:
			return Vector2i(3, 1)
	
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
	_update()

func _update() -> void:
	if !is_node_ready():
		return
	
	position = world_grid_pos * Vector2i(16, 16) + Vector2i(8, 8)

	shader.set_shader_parameter("tile_pos", get_cell_tile_for_type(cell_type))
	shader.set_shader_parameter("tint", colors[group_id % 50])
	shader.set_shader_parameter("tint_amount", 0.5 if cell_type == CellType.ORIG_CELL else 0.01)

	if cell_type == CellType.KEY:
		label.text = str(key_number)
		label.show()
	elif cell_type == CellType.DOOR:
		label.text = str(door_number)
		label.show()
	elif cell_type == CellType.ORIG_CELL:
		label.text = str(group_id)
		label.show()
	else:
		label.hide()

func is_door() -> bool:
	return cell_type == CellType.DOOR

func is_key() -> bool:
	return cell_type == CellType.KEY

func is_wall() -> bool:
	return cell_type == CellType.WALL
