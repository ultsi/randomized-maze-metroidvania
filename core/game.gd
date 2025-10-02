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
var powerup_defs := preload("res://core/pups_defs.gd").POWERUPS

var changing_maze := true
var next_possible_pups: Array[Pup] = []
var pup_costs := [10, 20, 30]
var state := GameState.new()

func _process(_delta: float) -> void:
	if changing_maze || !maze || !is_instance_valid(maze):
		return
	
	if maze.player_won:
		changing_maze = true
		await get_tree().create_timer(4.0).timeout
		state.money = roundi(maze.visual_money)
		maze.queue_free()
		show_pups()
	elif maze.player_lost:
		changing_maze = true
		await get_tree().create_timer(4.0).timeout
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

func get_next_possible_pups() -> void:
	next_possible_pups = []
	for pup in powerup_defs:
		if pup.passes_prerequisites(state):
			next_possible_pups.append(pup)

	next_possible_pups.shuffle()


func new_game() -> void:
	var used_seed := int(Time.get_unix_time_from_system())
	seed(used_seed)
	print("New game using seed ", used_seed)
	new_game_ui.hide()
	state.reset()

	get_next_possible_pups()

	new_maze()


func show_pups() -> void:
	new_game_ui.hide()
	pups_ui.show()

	get_next_possible_pups()
	for i in range(0, mini(next_possible_pups.size(), pup_costs.size())):
		pup_costs[i] = randi_range(next_possible_pups[i].cost_range[0], next_possible_pups[i].cost_range[1])
	
	update_pups()

func update_pups() -> void:
	if next_possible_pups.size() >= 1:
		pup1_label.text = next_possible_pups[0].shop_description
		pup1_button.text = "Buy ({0}$)".format([pup_costs[0]])
		pup1_button.disabled = pup_costs[0] > state.money || !next_possible_pups[0].passes_prerequisites(state)
		pup1_label.show()
		pup1_button.show()
	if next_possible_pups.size() >= 2:
		pup2_label.text = next_possible_pups[1].shop_description
		pup2_button.text = "Buy ({0}$)".format([pup_costs[1]])
		pup2_button.disabled = pup_costs[1] > state.money || !next_possible_pups[1].passes_prerequisites(state)
		pup2_label.show()
		pup2_button.show()
	if next_possible_pups.size() >= 3:
		pup3_label.text = next_possible_pups[2].shop_description
		pup3_button.text = "Buy ({0}$)".format([pup_costs[2]])
		pup3_button.disabled = pup_costs[2] > state.money || !next_possible_pups[2].passes_prerequisites(state)
		pup3_label.show()
		pup3_button.show()
	
	money_label.text = "{0}$".format([str(state.money)])


func pup_selected(index: int) -> void:
	print("Selected powerup ", index)

	state.money -= pup_costs[index]
	state = next_possible_pups[index].buy(state)

	pup_costs[index] = randi_range(next_possible_pups[index].cost_range[0], next_possible_pups[index].cost_range[1])

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
	maze.metros += state.starting_metros
	maze.visual_money = state.money
	
	add_child(maze)
	changing_maze = false
