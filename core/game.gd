extends Node2D

var maze_scene := preload("res://core/maze_tilemap.tscn")
var maze: Maze

var difficulties: Array[int] = [5, 7, 9, 11, 13, 15, 17]

var current_difficulty := 0
var changing_maze := true

func _process(_delta: float) -> void:
	if !changing_maze && maze.player_won:
		changing_maze = true
		await get_tree().create_timer(2.0).timeout
		current_difficulty = mini(difficulties.size() - 1, current_difficulty + 1)
		await new_maze()


func _ready() -> void:
	var used_seed := int(Time.get_unix_time_from_system())
	seed(used_seed)
	print("Using seed ", used_seed)
	new_maze()

func new_maze() -> void:
	if maze:
		maze.queue_free()
		await get_tree().create_timer(0.01).timeout

	maze = maze_scene.instantiate()
	maze.ui_size = difficulties[current_difficulty]
	maze.time_to_clear = maze.ui_size * 15
	add_child(maze)
	changing_maze = false
