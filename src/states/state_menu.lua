StateMenu = BaseState:extend()

-- not 'space' at the end of the string, to make spacebar a valid key
local valid_input = "qwertyuiopasdfghjklzxcvbnm1234567890space"

local in_phase

local n_of_pcs
local current_pc
-- clearing g.party_group in case we are restarting game
g.party_group = {}

local in_name
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
local cnv_menu

function StateMenu:manage_input(key)
    table.insert(g.keys_pressed, key)
end

-- key_output variable
local key_output

-- input decision table 1 (for in_phase == 1)
local INPUT_DTABLE1 = {
    ["escape"] = love.event.quit,
    ["right"] = function()
        if n_of_pcs < 4 then
            n_of_pcs = n_of_pcs + 1
            play_sound(SOUNDS["button_switch"])
        else
            play_sound(SOUNDS["type_nil"])
        end
    end,
    ["left"] = function()
        if n_of_pcs > 1 then
            n_of_pcs = n_of_pcs - 1
            play_sound(SOUNDS["button_switch"])
        else
            play_sound(SOUNDS["type_nil"])
        end
    end,
    ["enter"] = function()
        play_sound(SOUNDS["button_select"])
        in_phase = 2
    end,
    ["'"] = function()
        g.game_state = StateCredits()
        g.game_state:init()
    end,
} 

local INPUT_DTABLE2 = {
    ["escape"] = INPUT_DTABLE1["escape"],
    ["enter"] = function()
        play_sound(SOUNDS["button_select"])
        -- set a name if player skipped name insertion
        if in_name == "" then in_name = "Nameless Wanderer" end

        -- saving players names, checking if all players have a name
        names_table[current_pc] = in_name
        in_name = ""
        current_pc = current_pc + 1

        if current_pc > n_of_pcs then
            -- finding and assigning to player_bp the player's blueprint
            local pc_bp = nil
            pc_bp = BP_LIST["player"]

            -- check if player blueprint is missing, to avoid a crash
            if pc_bp == nil then
                error_handler(
                    "blueprints.csv does NOT contain a blueprint to spawn players!",
                    "blueprints.csv always needs a blueprint with id = player."
                )
                g.game_state:exit()
                g.game_state = StateFatalError()
                g.game_state:init()
                goto continue_menu
            end

            -- all fine, continue spawning. Assigning  new players to g.party_group
            for i = 1, n_of_pcs do
                --[[
                    Creating a new Entity() and feeding it all player_bp data
                    + Players names.
                    local new_player = Entity(player_bp.id, player_bp.tile,
                    player_bp.features, names_table[i])
                ]]--
                local bp_plus_name = {["bp"] = BP_LIST["player"],
                ["name"] = names_table[i]
                }
                --[[
                    NOTE: this is a first assignment to g.party_group. Players will
                    need to be extracted from here and added again in
                    entities_spawner(), this time with their input ('player') comps!
                ]]--
                table.insert(g.party_group, bp_plus_name)
            end

            -- move to StatePlay(), giving 1 and "true" to :Init() for map_n and
            -- player_regen (regeneration)
            g.game_state = StatePlay()
            g.game_state:init(1, true)

            -- something went wrong? Then, move here
            ::continue_menu::
        end
    end,
    ["backspace"] = function()
        in_name = text_backspace(in_name)
    end
}

-- this cannot be done when initially declaring the tables
INPUT_DTABLE1["return"] = INPUT_DTABLE1["enter"]
INPUT_DTABLE2["return"] = INPUT_DTABLE2["enter"]
INPUT_DTABLE2["'"] = INPUT_DTABLE1["'"]

function StateMenu:init()
    -- reset all proper global values (not BP_LIST, as it's set once in main.load())
    g.party_group = {}
    g.camera["entity"] = nil
    g.npcs_group = {}
    g.render_group = {}
    g.hidden_group = {}
    g.cnv_static  = nil
    g.cnv_dynamic = nil
    g.cemetery = {}
    g.tweening = {}
    g.console["event5"] = ""
    g.console["event4"] = ""
    g.console["event3"] = ""
    g.console["event2"] = ""
    g.console["event1"] = ""
    
        
    in_phase = 1
    n_of_pcs = 1
    current_pc = 1
    in_name = ""
    names_table = {}
    -- stopping old soundtrack
    if g.game_track then
        love.audio.stop(g.game_track)
    end

    -- setting background color to black for menu
    love.graphics.setBackgroundColor(
        (mod.BKG_R or 12) / 255, (mod.BKG_G or 8) / 255, (mod.BKG_B or 42) / 255
    )

    -- starting menu music
    g.game_track = MUSIC["menu"]
    g.game_track:setLooping(true)
    love.audio.play(g.game_track)

    -- store all borderes images in costant BORDERS
    borders_manager()
    
    g.game_state:refresh()
end

function StateMenu:update()
    -- checking for input to resolve turns
    for i,key in ipairs(g.keys_pressed) do
        if in_phase == 1 then
            key_output = INPUT_DTABLE1[key] or function()
                play_sound(SOUNDS["type_nil"])
            end
        else
            key_output = INPUT_DTABLE2[key] or function()
                -- the input is an alphanumeric char, call dedicated function
                in_name = text_input(valid_input, key, in_name, 20)
            end
        end
        key_output()
        g.game_state:refresh()
    end
    g.keys_pressed = {}
end

function StateMenu:refresh()
    cnv_menu = ui_manager_menu(text, in_phase, n_of_pcs, current_pc, in_name)

    -- reset default canvas to draw on it in draw() func
    love.graphics.setCanvas()
end

function StateMenu:draw()
    love.graphics.draw(cnv_menu, 0, 0)
end