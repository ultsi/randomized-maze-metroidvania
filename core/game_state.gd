class_name GameState extends RefCounted

const DIFFICULTY_LEVELS: Array[int] = [5, 5, 5, 5, 9, 11, 13, 15, 17]

var money := 0
var difficulty := 0
var starting_time := 0.0
var starting_vision := 0
var starting_torches := 0
var starting_metros := 0

func _init() -> void:
    reset()

func reset() -> void:
    money = 0
    difficulty = 0
    starting_time = 0.0
    starting_vision = 0
    starting_torches = 2
    starting_metros = 0
