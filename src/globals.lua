g = {
    game_track = nil, -- the game's soundtrack
    window_width = 1280, -- screen size must be an odd number to have perfect pixels
    window_height = 720,
    canvas_static, -- game canvases: base for statics, and final for statics + dynamics
    canvas_dynamic,
    canvas_ui, -- used only during state_play because of state stacking
    canvas_inv, -- used only during state_play to show player's inventory
    grid = {}, -- grid system main data
    grid_x = 0, -- this is established by the CSV files containing the map
    grid_y = 0, -- this is established by the CSV files containing the map
    camera = {["entity"] = nil, ["x"] = 0, ["y"] = 0}, -- the entity to center to the screen
    render_group = {}, -- contains all the entities to be drawn
    invisible_group = {}, -- contains all the invisible entities
    players_party = {}, -- contains both the entities reacting to input and their Player component
    npcs_group = {}, -- contains all the NPCs
    entities_group = {}, -- contains all the other entities, ref needed to apply effects on
    current_inventory = {}, -- current player's inventory
    cemetery = {}, -- a table containing deaths data (player, killer, gold...)
    is_tweening = false, -- suspends player input during animations
    TILESET = love.graphics.newImage(mod.PATH_TO_TILESET or "graphics/tileset.png"),
    game_state, -- the current game state
    error_messages = {}, -- holds all error messages to print on screen
    console = {
        ["string"] = nil,
        ["event1"] = nil,
        ["event2"] = nil,
        ["event3"] = nil,
        ["color1"] = {[1] = 0.78, [2] = 0.96, [3] = 0.94},
        ["color2"] = {[1] = 0.78, [2] = 0.96, [3] = 0.94},
        ["color3"] = {[1] = 0.78, [2] = 0.96, [3] = 0.94}
    }, -- console's content
    keys_pressed = {} -- variable for storing and clearing keys pressed each update
}