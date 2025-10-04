@abstract class_name GameObject extends Node2D

enum Type {
    DOOR,
    KEY,
    METRO,
    POWERUP,
    TORCH
}

var type := Type.DOOR

func update() -> void:
    pass