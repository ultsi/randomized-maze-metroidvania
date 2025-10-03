@tool
class_name MoreMoney extends Label

var _start_time := 0
var velocity := Vector2.ZERO
const DURATION := 1000.0

func _init() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    label_settings = preload("res://core/more_money.tres")


func _ready() -> void:
    _start_time = Time.get_ticks_msec()
    velocity = Vector2(randf() * 80 - 40, randf_range(0.5, 1.2) * -120)
    position = Vector2(0, 0)

func _process(delta: float) -> void:
    var phase := 1.0 - clampf((Time.get_ticks_msec() - _start_time) / DURATION, 0.0, 1.0)
    modulate.a = phase
    ##scale = Vector2(phase, phase)
    velocity.y += 500 * delta

    position = position + velocity * delta
