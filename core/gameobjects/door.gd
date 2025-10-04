@tool
class_name Door extends GameObject

@onready var sprite := $TileSprite as TileSprite

func _init() -> void:
    type = Type.DOOR

func _ready() -> void:
    sprite = TileSprite.new()
    sprite.cell_type = TileSprite.CellType.DOOR

func update() -> void:
    sprite._update()
