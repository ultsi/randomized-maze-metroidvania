static var POWERUPS: Array[Pup] = [
    Pup.new(
        Pup.Type.MoreSight,
        "+1 vision",
        [50, 100],
        func(state: GameState) -> bool:
            return state.starting_vision < 5
            ,
        func(state: GameState) -> GameState:
            state.starting_vision += 1
            return state
            ),

    Pup.new(
        Pup.Type.MoreTime,
        "+10s time",
        [30, 60],
        func(state: GameState) -> bool:
            return state.starting_time < 100
            ,
        func(state: GameState) -> GameState:
            state.starting_time += 10.0
            return state
            ),

    Pup.new(
        Pup.Type.Torch,
        "+1 torch",
        [10, 30],
        func(state: GameState) -> bool:
            return state.starting_torches < 10
            ,
        func(state: GameState) -> GameState:
            state.starting_torches += 1
            print("Bought torch, now starting torches is at ", state.starting_torches)
            return state
            ),

    Pup.new(
        Pup.Type.Torch,
        "+1 metro station",
        [10, 50],
        func(state: GameState) -> bool:
            return state.starting_metros < 4
            ,
        func(state: GameState) -> GameState:
            state.starting_metros += 1
            return state
            )
]
