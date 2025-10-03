class_name Tile extends RefCounted

enum Type {
    WALL,
    FLOOR
}

const WALL := Type.WALL
const FLOOR := Type.FLOOR

var type := Type.WALL
var color := Color.WHITE
var object: GameObject
var pos: Vector2i
var pos_i: int

func is_wall() -> bool:
    return type == WALL

func is_floor() -> bool:
    return type == FLOOR

func has(obj_type: GameObject.Type) -> bool:
    return is_instance_valid(object) && object.type == obj_type
