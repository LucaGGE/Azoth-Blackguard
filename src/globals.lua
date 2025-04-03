g = {
    game_track = nil, -- the game's soundtrack
    w_width = 1280, -- screen size must be an odd number to have perfect pixels
    w_height = 720,
    cnv_static, -- game canvas for un-moving, un-changing visuals
    cnv_dynamic, -- game canvas for dynamic, changing visuals
    cnv_ui, -- used only during state_play because of state stacking
    cnv_inv, -- used only during state_play to show player's inventory
    grid = {}, -- grid system main data
    grid_x = 0, -- this is established by the CSV files containing the map
    grid_y = 0, -- this is established by the CSV files containing the map
    camera = {["entity"] = nil, ["x"] = 0, ["y"] = 0}, -- the entity to center to the screen
    render_group = {}, -- contains all the entities to be drawn
    hidden_group = {}, -- contains all the invisible entities
    party_group = {}, -- contains both the entities reacting to input and their Player component
    npcs_group = {}, -- contains all NPCs
    entities_group = {}, -- contains all the other entities, ref needed to apply effects on
    current_inv = {}, -- current player's inventory
    view_inv = false, -- view inventory or not
    cemetery = {}, -- a table containing deaths data (player, killer, gold...)
    tweening = false, -- suspends player input during animations
    game_state, -- the current game state
    error_messages = {}, -- holds all error messages to print on screen
    console = {
        ["string"] = nil,
        ["event1"] = nil,
        ["event2"] = nil,
        ["event3"] = nil,
        ["color1"] = {[1] = 0.28, [2] = 0.46, [3] = 0.73},
        ["color2"] = {[1] = 0.28, [2] = 0.46, [3] = 0.73},
        ["color3"] = {[1] = 0.28, [2] = 0.46, [3] = 0.73}
    }, -- console's content
    keys_pressed = {} -- variable for storing and clearing keys pressed each update
}