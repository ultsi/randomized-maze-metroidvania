@tool
class_name Door extends GameObject

@onready var sprite := $Sprite2D as Sprite2D
@onready var label := $Sprite2D/Label as Label

var number := 0:
    set(value):
        number = value
        update()

var color1: Color:
    set(value):
        color1 = value
        update()
var color2: Color:
    set(value):
        color2 = value
        update()
var top_down: bool:
    set(value):
        top_down = value
        update()

var _shader: ShaderMaterial

func _init() -> void:
    type = Type.DOOR

func _ready() -> void:
    _shader = sprite.material.duplicate()
    sprite.material = _shader

func update() -> void:
    if !is_node_ready():
        return
    label.text = str(number)
    _shader.set_shader_parameter("color1", color1)
    _shader.set_shader_parameter("color2", color2)
    _shader.set_shader_parameter("top_down", top_down)
