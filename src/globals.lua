g = {
    game_track = nil, -- the game's soundtrack
    w_width = 640, -- screen size must be an odd number to have perfect pixels
    w_height = 512,
    cnv_static, -- game canvas for un-moving, un-changing visuals
    cnv_dynamic, -- game canvas for dynamic, changing visuals
    cnv_ui, -- used only during state_play because of state stacking
    cnv_inv, -- used only during state_play to show player's inventory
    grid = {}, -- grid system main data
    grid_x = 0, -- this is established by the CSV files containing the map
    grid_y = 0, -- this is established by the CSV files containing the map
    camera = {["entity"] = nil, ["x"] = 0, ["y"] = 0}, -- screen 'pivot' Entity
    render_group = {}, -- contains: all the Entities to be drawn
    hidden_group = {}, -- contains: all the invisible Entities
    party_group = {}, -- contains: Entities reacting to input, their Player comp
    npcs_group = {}, -- contains: all NPCs
    entities_group = {}, -- contains: all the other Entities, for effects applying
    active_panel = {}, -- current player's panel
    panel_on = false, -- current player's panel visibility
    cemetery = {}, -- a table containing deaths data (player, killer, gold...)
    tweening = {}, -- suspends player input during animations
    game_state, -- the current game state
    error_messages = {}, -- holds all error messages to print on screen
    new_event = false,
    hp_rgb = {0.28, 0.46, 0.73, 1},
    gold_rgb = {0.28, 0.46, 0.73, 1},
    hunger_msg = true,
    console = {
        ["string"] = nil,
        ["event1"] = nil,
        ["event2"] = nil,
        ["event3"] = nil,
        ["event4"] = nil,
        ["event5"] = nil,
        ["rgb1"] = {[1] = 0.28, [2] = 0.46, [3] = 0.73},
        ["rgb2"] = {[1] = 0.28, [2] = 0.46, [3] = 0.73},
        ["rgb3"] = {[1] = 0.28, [2] = 0.46, [3] = 0.73},
        ["rgb4"] = {[1] = 0.28, [2] = 0.46, [3] = 0.73},
        ["rgb5"] = {[1] = 0.28, [2] = 0.46, [3] = 0.73}
    }, -- console's content
    keys_pressed = {} -- variable for storing and clearing keys pressed each update
}