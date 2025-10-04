class_name Tile extends RefCounted

enum Type {
    WALL,
    FLOOR
}

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

const WALL := Type.WALL
const FLOOR := Type.FLOOR

var type := Type.WALL
var object: GameObject
var pos: Vector2i
var ipos: int
var room: int

func is_wall() -> bool:
    return type == WALL

func is_floor() -> bool:
    return type == FLOOR

func has(obj_type: GameObject.Type) -> bool:
    return is_instance_valid(object) && object.type == obj_type

func get_color() -> Color:
    var mult := 1.0
    if ipos % 2 == 0:
        mult = 0.9
    # elif ipos % 3 == 1:
    #     mult = 0.95
    return colors[room % 50] * mult

func add_game_object(obj: GameObject) -> void:
    obj.position = Vector2i(pos) * Vector2i(16, 16)
    object = obj
    obj.update()

func get_door() -> Door:
    if has(GameObject.Type.DOOR):
        return object

    return null
