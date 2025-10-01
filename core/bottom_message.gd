class_name BottomMessage extends Label

var speed_scale := 1.0
@onready var animation_player := $AnimationPlayer as AnimationPlayer

func _ready() -> void:
    animation_player.speed_scale = speed_scale
    animation_player.play("message")
    animation_player.animation_finished.connect(_finished)

func _finished(_anim: String) -> void:
    queue_free()
