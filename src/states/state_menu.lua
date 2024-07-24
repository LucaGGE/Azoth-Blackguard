StateMenu = BaseState:extend()

-- not the 'space' at the end of the string, to make spacebar a valid input
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

function StateMenu:manage_input(key)
    table.insert(g.keys_pressed, key)
end

function StateMenu:init()
    -- resetting every global variable but BLUEPRINTS_LIST, as it's set once in main.load() 
    g.npcs_group = {}
    g.players_party = {}
    g.camera["entity"] = nil
    g.render_group = {}
    g.canvas_base  = nil
    g.canvas_final = nil
    g.is_tweening = false
    g.cemetery = {}
        
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
end

function StateMenu:update()
    -- checking for input to resolve turns
    if g.keys_pressed[1] then
        for i,key in ipairs(g.keys_pressed) do  
            if key == "escape" then
                love.event.quit()   
            elseif key == "right" then
                if input_phase == 1 and n_of_players < 4 then
                    n_of_players = n_of_players + 1
                    love.audio.stop(SOUNDS["button_switch"])
                    love.audio.play(SOUNDS["button_switch"])
                else
                    love.audio.stop(SOUNDS["type_nil"])
                    love.audio.play(SOUNDS["type_nil"])
                end
            elseif key == "left" then
                if input_phase == 1 and n_of_players > 1 then
                    n_of_players = n_of_players - 1
                    love.audio.stop(SOUNDS["button_switch"])
                    love.audio.play(SOUNDS["button_switch"])
                else
                    love.audio.stop(SOUNDS["type_nil"])
                    love.audio.play(SOUNDS["type_nil"])
                end
            elseif key == "enter" or key == "return" then
                love.audio.stop(SOUNDS["button_select"])
                love.audio.play(SOUNDS["button_select"])
                if input_phase == 1 then
                    -- pass to next phase: inputting a name for all players
                    input_phase = 2
                else
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
                            error_handler("entities.csv does NOT contain a blueprint to spawn players!",
                            "entities.csv always needs a blueprint with id = player (all lowercase).")
                            g.game_state:exit()
                            g.game_state = StateFatalError()
                            g.game_state:init()
                            goto continue_menu
                        end

                        -- if everything is fine, then continue spawning. Assigning  new players to g.players_party
                        for i = 1, n_of_players do
                            -- creating a new Entity() and feeding it all player_blueprint data + Players names
                            --local new_player = Entity(player_blueprint.id, player_blueprint.tile, player_blueprint.features, names_table[i])
                            local blueprint = {["bp"] = BLUEPRINTS_LIST["player"],
                            ["name"] = names_table[i]
                            }
                            -- NOTE: this is a first assignment to g.players_party. Players will need to be extracted from
                            -- here and added again, this time with their input (player) components!
                            table.insert(g.players_party, blueprint)
                        end

                        -- move to StatePlay(), giving 1 and "true" to :Init() for map_n and player_regen(eration)
                        g.game_state = StatePlay()
                        g.game_state:init(1, true)

                        -- something went wrong? Then, move here
                        ::continue_menu::
                    end
                end
            elseif key == "backspace" then
                input_name = string.sub(input_name, 1, -2)
                love.audio.stop(SOUNDS["type_backspace"])
                love.audio.play(SOUNDS["type_backspace"])
            elseif key == "'" then
                g.game_state = StateCredits()
                g.game_state:init()
            else
                if input_phase ~= 1 then
                    -- if the character is legal (in valid_input variable) then append it
                    if string.find(valid_input, key) and #input_name < 20 then
                        if key == "space" then
                            input_name = input_name .. " "
                        elseif love.keyboard.isDown("rshift") or love.keyboard.isDown("lshift") then
                            input_name = input_name .. string.upper(key)
                        else
                            input_name = input_name .. key
                        end
                        love.audio.stop(SOUNDS["type_input"])
                        love.audio.play(SOUNDS["type_input"])
                    elseif #input_name >= 20 then
                        love.audio.stop(SOUNDS["type_nil"])
                        love.audio.play(SOUNDS["type_nil"])
                    end
                end
            end
        end
        g.keys_pressed = {}
    end
end

function StateMenu:draw()
    love.graphics.setFont(FONTS["title"])
    love.graphics.printf(GAME_TITLE, 0, g.window_height / 5, g.window_width, 'center')

    love.graphics.setFont(FONTS["subtitle"])
    if input_phase == 1 then
        love.graphics.printf(text[input_phase] .. n_of_players, 0, g.window_height / 5 + (FONT_SIZE_TITLE * 2), g.window_width, 'center')
    else
        love.graphics.printf(text[input_phase] .. text[current_player + 2] .. "rogue:\n" .. input_name,
        0, g.window_height / 5 + (FONT_SIZE_TITLE * 2), g.window_width, 'center')
    end
end