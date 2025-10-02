extends Node2D

@onready var new_game_ui := $UI/MarginContainer/NewGame as Control
@onready var new_game_button := $UI/MarginContainer/NewGame/HBoxContainer/VBoxContainer/NewGameButton as Button
@onready var continue_ui := $UI/MarginContainer/Continue as Control
@onready var continue_button := $UI/MarginContainer/Continue/HBoxContainer/VBoxContainer/ContinueButton as Button
@onready var pups_ui := $UI/MarginContainer/PowerUps as Control
@onready var pup1_label := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer/Pup1Label as Label
@onready var pup1_button := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer/Pup1Button as Button
@onready var pup2_button := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer2/Pup2Button as Button
@onready var pup2_label := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer2/Pup2Label as Label
@onready var pup3_button := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer3/Pup3Button as Button
@onready var pup3_label := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer3/Pup3Label as Label

var maze_scene := preload("res://core/maze_tilemap.tscn")
var maze: Maze

var difficulties: Array[int] = [5, 7, 9, 11, 13, 15, 17]

enum Pup {
	MoreTime,
	MoreSight,
	Torch
}

var money := 0
var current_difficulty := 0
var changing_maze := true
var meta_powerups: Array[Pup] = [Pup.MoreTime, Pup.MoreSight, Pup.Torch]
var starting_time := 0.0
var starting_vision := 0
var starting_torches := 0
var pup_costs := [10, 20, 30]

func _process(_delta: float) -> void:
	if !changing_maze && maze.player_won:
		changing_maze = true
		money += int(maze.time_to_clear)
		await get_tree().create_timer(2.0).timeout
		maze.queue_free()
		show_pups()


func _ready() -> void:
	continue_ui.hide()
	pups_ui.hide()
	new_game_ui.show()

	new_game_button.pressed.connect(new_game)
	pup1_button.pressed.connect(func() -> void: pup_selected(0))
	pup2_button.pressed.connect(func() -> void: pup_selected(1))
	pup3_button.pressed.connect(func() -> void: pup_selected(2))
	continue_button.pressed.connect(continue_pressed)


func new_game() -> void:
	var used_seed := int(Time.get_unix_time_from_system())
	seed(used_seed)
	print("New game using seed ", used_seed)
	new_game_ui.hide()

	new_maze()


func show_pups() -> void:
	new_game_ui.hide()
	continue_ui.hide()
	pups_ui.show()

	pup1_label.text = get_label_for_pup(meta_powerups[0])
	pup2_label.text = get_label_for_pup(meta_powerups[1])
	pup3_label.text = get_label_for_pup(meta_powerups[2])

	for i in range(0, 2):
		pup_costs[i] = randi_range(10, 50)

	pup1_button.text = "Buy ({0}$)".format([pup_costs[0]])
	pup1_button.disabled = pup_costs[0] > money
	pup2_button.text = "Buy ({0}$)".format([pup_costs[1]])
	pup2_button.disabled = pup_costs[1] > money
	pup3_button.text = "Buy ({0}$)".format([pup_costs[2]])
	pup3_button.disabled = pup_costs[2] > money


func pup_selected(index: int) -> void:
	print("Selected powerup ", index)

	if index == 0:
		starting_time += 10
	elif index == 1:
		starting_vision += 1
	elif index == 2:
		starting_torches += 1

	show_continue()

func get_label_for_pup(pup: Pup) -> String:
	match pup:
		Pup.MoreTime:
			return "+10s more time"
		Pup.MoreSight:
			return "+1 more vision"
		Pup.Torch:
			return "+1 torch"
	
	return "Not specified"

func show_continue() -> void:
	continue_ui.show()
	new_game_ui.hide()
	pups_ui.hide()


func continue_pressed() -> void:
	current_difficulty = mini(difficulties.size() - 1, current_difficulty + 1)
	new_maze()
	continue_ui.hide()
	
func new_maze() -> void:
	maze = maze_scene.instantiate()
	maze.ui_size = difficulties[current_difficulty]
	maze.time_to_clear = maze.ui_size * 10
	
	#pups
	maze.player_sight += starting_vision
	maze.time_to_clear += starting_time
	
	add_child(maze)
	changing_maze = false
