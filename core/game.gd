class_name Game extends Node2D

@onready var new_game_ui := $UI/MarginContainer/NewGame as Control
@onready var new_game_button := $UI/MarginContainer/NewGame/HBoxContainer/VBoxContainer/NewGameButton as Button
@onready var continue_button := $UI/MarginContainer/PowerUps/HBoxContainer3/VBoxContainer/ContinueButton as Button
@onready var pups_ui := $UI/MarginContainer/PowerUps as Control
@onready var pup1_label := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer/Pup1Label as Label
@onready var pup1_button := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer/Pup1Button as Button
@onready var pup2_button := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer2/Pup2Button as Button
@onready var pup2_label := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer2/Pup2Label as Label
@onready var pup3_button := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer3/Pup3Button as Button
@onready var pup3_label := $UI/MarginContainer/PowerUps/HBoxContainer/VBoxContainer3/Pup3Label as Label
@onready var money_label := $UI/MarginContainer/PowerUps/HBoxContainer2/MoneyLabel as Label

var maze_scene := preload("res://core/maze_tilemap.tscn")
var maze: Maze

var changing_maze := true
var meta_powerups: Array[Pup] = preload("res://core/pups_defs.gd").POWERUPS
var pup_costs := [10, 20, 30]
var state := GameState.new()

func _process(_delta: float) -> void:
	if changing_maze || !maze || !is_instance_valid(maze):
		return
	
	if maze.player_won:
		changing_maze = true
		state.money += int(maze.time_to_clear)
		await get_tree().create_timer(2.0).timeout
		maze.queue_free()
		show_pups()
	elif maze.player_lost:
		changing_maze = true
		await get_tree().create_timer(2.0).timeout
		maze.queue_free()
		show_new_game()


func _ready() -> void:
	show_new_game()

	new_game_button.pressed.connect(new_game)
	pup1_button.pressed.connect(func() -> void: pup_selected(0))
	pup2_button.pressed.connect(func() -> void: pup_selected(1))
	pup3_button.pressed.connect(func() -> void: pup_selected(2))
	continue_button.pressed.connect(continue_pressed)

func show_new_game() -> void:
	pups_ui.hide()
	new_game_ui.show()


func new_game() -> void:
	var used_seed := int(Time.get_unix_time_from_system())
	seed(used_seed)
	print("New game using seed ", used_seed)
	new_game_ui.hide()
	state.money = 0
	state.difficulty = 0
	state.starting_time = 0.0
	state.starting_vision = 0
	state.starting_torches = 2

	new_maze()


func show_pups() -> void:
	new_game_ui.hide()
	pups_ui.show()

	meta_powerups.shuffle()

	for i in range(0, 2):
		pup_costs[i] = randi_range(meta_powerups[i].cost_range[0], meta_powerups[i].cost_range[1])
	
	update_pups()

func update_pups() -> void:
	pup1_label.text = meta_powerups[0].shop_description
	pup2_label.text = meta_powerups[1].shop_description
	pup3_label.text = meta_powerups[2].shop_description
	
	pup1_button.text = "Buy ({0}$)".format([pup_costs[0]])
	pup1_button.disabled = pup_costs[0] > state.money

	pup2_button.text = "Buy ({0}$)".format([pup_costs[1]])
	pup2_button.disabled = pup_costs[1] > state.money

	pup3_button.text = "Buy ({0}$)".format([pup_costs[2]])
	pup3_button.disabled = pup_costs[2] > state.money

	money_label.text = "{0}$".format([str(state.money)])


func pup_selected(index: int) -> void:
	print("Selected powerup ", index)

	state.money -= pup_costs[index]
	state = meta_powerups[index].buy(state)

	update_pups()

func continue_pressed() -> void:
	state.difficulty = mini(GameState.DIFFICULTY_LEVELS.size() - 1, state.difficulty + 1)
	new_maze()
	pups_ui.hide()
	

func new_maze() -> void:
	maze = maze_scene.instantiate()
	maze.ui_size = GameState.DIFFICULTY_LEVELS[state.difficulty]
	maze.time_to_clear = maze.ui_size * 12
	
	#pups
	maze.player_sight += state.starting_vision
	maze.time_to_clear += state.starting_time
	maze.torches += state.starting_torches
	print("torches: ", state.starting_torches)
	
	add_child(maze)
	changing_maze = false
