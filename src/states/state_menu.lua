StateMenu = BaseState:extend()

-- not 'space' at the end of the string, to make spacebar a valid key
local valid_input = "qwertyuiopasdfghjklzxcvbnm1234567890space"

local input_phase

local n_of_players
local current_player
-- clearing g.players_party in case we are restarting game
g.players_party = {}

local input_name
local names_table

local text = {
    [1] = "Number of rogues: ",
    [2] = "Name of the ",
    [3] = "first ",
    [4] = "second ",
    [5] = "third ",
    [6] = "fourth "
}

-- menu dedicated canvas (state_play only)
local canvas_menu

function StateMenu:manage_input(key)
    table.insert(g.keys_pressed, key)
end

-- key_output variable
local key_output

-- input decision table 1 (for input_phase == 1)
local INPUT_DTABLE1 = {
    ["escape"] = love.event.quit,
    ["right"] = function()
        if n_of_players < 4 then
            n_of_players = n_of_players + 1
            love.audio.stop(SOUNDS["button_switch"])
            love.audio.play(SOUNDS["button_switch"])
        else
            love.audio.stop(SOUNDS["type_nil"])
            love.audio.play(SOUNDS["type_nil"])
        end
    end,
    ["left"] = function()
        if n_of_players > 1 then
            n_of_players = n_of_players - 1
            love.audio.stop(SOUNDS["button_switch"])
            love.audio.play(SOUNDS["button_switch"])
        else
            love.audio.stop(SOUNDS["type_nil"])
            love.audio.play(SOUNDS["type_nil"])
        end
    end,
    ["enter"] = function()
        love.audio.stop(SOUNDS["button_select"])
        love.audio.play(SOUNDS["button_select"])
        input_phase = 2
    end,
    ["'"] = function()
        g.game_state = StateCredits()
        g.game_state:init()
    end,
} 

local INPUT_DTABLE2 = {
    ["escape"] = INPUT_DTABLE1["escape"],
    ["enter"] = function()
        love.audio.stop(SOUNDS["button_select"])
        love.audio.play(SOUNDS["button_select"])
        -- set a name if player skipped name insertion
        if input_name == "" then input_name = "Nameless Wanderer" end

        -- saving players names, checking if all players have a name
        names_table[current_player] = input_name
        input_name = ""
        current_player = current_player + 1

        if current_player > n_of_players then
            -- finding and assigning to player_blueprint the player's blueprint
            local player_blueprint = nil
            player_blueprint = BLUEPRINTS_LIST["player"]

            -- checking if modders did not create a player blueprint to avoid a crash
            if player_blueprint == nil then
                error_handler("blueprints.csv does NOT contain a blueprint to spawn players!",
                "blueprints.csv always needs a blueprint with id = player (all lowercase).")
                g.game_state:exit()
                g.game_state = StateFatalError()
                g.game_state:init()
                goto continue_menu
            end

            -- if everything is fine, then continue spawning. Assigning  new players to g.players_party
            for i = 1, n_of_players do
                -- creating a new Entity() and feeding it all player_blueprint data + Players names
                --local new_player = Entity(player_blueprint.id, player_blueprint.tile, player_blueprint.features, names_table[i])
                local blueprint_plus_name = {["bp"] = BLUEPRINTS_LIST["player"],
                ["name"] = names_table[i]
                }
                -- NOTE: this is a first assignment to g.players_party. Players will need to be extracted from
                -- here and added again in entities_spawner(), this time with their input ('player') components!
                table.insert(g.players_party, blueprint_plus_name)
            end

            -- move to StatePlay(), giving 1 and "true" to :Init() for map_n and player_regen(eration)
            g.game_state = StatePlay()
            g.game_state:init(1, true)

            -- something went wrong? Then, move here
            ::continue_menu::
        end
    end,
    ["backspace"] = function()
        input_name = text_backspace(input_name)
    end
}

-- this cannot be done when initially declaring the tables
INPUT_DTABLE1["return"] = INPUT_DTABLE1["enter"]
INPUT_DTABLE2["return"] = INPUT_DTABLE2["enter"]
INPUT_DTABLE2["'"] = INPUT_DTABLE1["'"]

function StateMenu:init()
    -- resetting every global variable of interest but BLUEPRINTS_LIST, as it's set once in main.load() 
    g.players_party = {}
    g.camera["entity"] = nil
    g.npcs_group = {}
    g.render_group = {}
    g.invisible_group = {}
    g.canvas_static  = nil
    g.canvas_dynamic = nil
    g.cemetery = {}
    g.is_tweening = false
    g.console["event3"] = ""
    g.console["event2"] = ""
    g.console["event1"] = ""
    
        
    input_phase = 1
    n_of_players = 1
    current_player = 1
    input_name = ""
    names_table = {}
    -- stopping old soundtrack
    if g.game_track then
        love.audio.stop(g.game_track)
    end

    -- setting background color with calming pink for fatal errors
    love.graphics.setBackgroundColor(0 / 255, 0 / 255, 0 / 255)

    -- starting menu music
    g.game_track = MUSIC["menu"]
    g.game_track:setLooping(true)
    love.audio.play(g.game_track)
    
    g.game_state:refresh()
end

function StateMenu:update()
    -- checking for input to resolve turns
    for i,key in ipairs(g.keys_pressed) do
        if input_phase == 1 then
            key_output = INPUT_DTABLE1[key] or function()
                love.audio.stop(SOUNDS["type_nil"])
                love.audio.play(SOUNDS["type_nil"])
            end
        else
            key_output = INPUT_DTABLE2[key] or function()
                -- the input is an alphanumeric char, call dedicated function
                input_name = text_input(valid_input, key, input_name, 20)
            end
        end
        key_output()
        g.game_state:refresh()
    end
    g.keys_pressed = {}
end

function StateMenu:refresh()
    canvas_menu = ui_manager_menu(text, input_phase, n_of_players, current_player, input_name)

    -- reset default canvas to draw on it in draw() func
    love.graphics.setCanvas()
end

function StateMenu:draw()
    love.graphics.draw(canvas_menu, 0, 0)
end