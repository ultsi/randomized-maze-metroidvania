class_name Pup extends RefCounted
enum Type {
	MoreTime,
	MoreSight,
	Torch,
	Metro,
	AnyKey,
	PercentageCounter
}

var type := Type.MoreSight
var cost_range: Array[int] = [10, 50]
var shop_description := "Powerup"
var buy_action: Callable

func _init(p_type: Type, p_shop_description: String, p_cost_range: Array[int], p_buy_action: Callable) -> void:
    type = p_type
    shop_description = p_shop_description
    cost_range = p_cost_range
    buy_action = p_buy_action

func buy(state: GameState) -> GameState:
    return buy_action.call(state)
