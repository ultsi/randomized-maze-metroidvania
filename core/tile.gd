class_name Tile extends RefCounted

enum Type {
    WALL,
    FLOOR,
    BREAKABLE_WALL
}

const WALL := Type.WALL
const FLOOR := Type.FLOOR

var type := Type.WALL
var object: GameObject
var pos: Vector2i
var ipos: int
var room: int
var breakable := false
var breakable_from: int

func is_wall() -> bool:
    return type == WALL

func is_floor() -> bool:
    return type == FLOOR

func has(obj_type: GameObject.Type) -> bool:
    return is_instance_valid(object) && object.type == obj_type


func add_game_object(obj: GameObject) -> void:
    obj.position = Vector2i(pos) * Vector2i(16, 16)
    object = obj
    obj.update()

func get_door() -> Door:
    if has(GameObject.Type.DOOR):
        return object

    return null
