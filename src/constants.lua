-- variable containing the path to the necessary CSV files
-- the two current local paths I use are "F:/Development/Dev_Games/GOBLET/source/rogue24-goblet/modding/" or "C:/Users/foxre/"
-- you'll need to modify these to your local path since the system, to date, cannot find other than LUA files in the relative path
PATH_TO_CSV = mod.path_to_csv or "C:/Users/foxre/"

GAME_TITLE = type(mod.game_title) == "string" and mod.game_title or "GOBLET"

--[[
    Pay attention to tiles_features_pairs. It will store tile index = tile type,
    to easily check how to interact with a specific tile. Also note that each tile can 
    have one 'physical state' at a given time, but it can change anytime.
    Tile indexes without a type will give a 'nil' value, and since the can_transverse
    var in Movable:move_entity func is false by default, they won't allow for any movement.
]]
TILES_FEATURES_PAIRS = {["empty"] = "ground"} -- empty cells are considered ground

-- list of all entity blueprints registered from dedicated CSV file
BLUEPRINTS_LIST = {}

-- duration of normal tweening animations
TWEENING_TIME = 0.25

-- sizes relative to all available fonts
FONT_SIZE_TITLE = mod.font_size_title or 60
FONT_SIZE_SUBTITLE = mod.font_size_subtitle or 30
FONT_SIZE_DEFAULT = mod.font_size_default or 24

MUSIC = {
    ["swamp"] = love.audio.newSource("sfx/st_swamp.ogg", "static"),
    ["gameover_sting"] = love.audio.newSource("sfx/sting_gameover.ogg", "static"),
    ["gameover"] = love.audio.newSource("sfx/st_gameover.ogg", "static"),
    ["menu"] = love.audio.newSource("sfx/st_menu.ogg", "static"),
}

SOUNDS = {
    ["ground"] = love.audio.newSource("sfx/step_ground.ogg", "static"),
    ["solid"] = love.audio.newSource("sfx/step_solid.ogg", "static"),
    ["climbable"] = love.audio.newSource("sfx/step_climbable.ogg", "static"),
    ["tricky"] = love.audio.newSource("sfx/step_tricky.ogg", "static"),
    ["liquid"] = love.audio.newSource("sfx/step_liquid.ogg", "static"),
    ["wait"] = love.audio.newSource("sfx/step_wait.wav", "static"),
    ["button_select"] = love.audio.newSource("sfx/button_select.wav", "static"),
    ["button_switch"] = love.audio.newSource("sfx/button_switch.wav", "static"),
    ["type_input"] = love.audio.newSource("sfx/type_input.wav", "static"),
    ["type_backspace"] = love.audio.newSource("sfx/type_backspace.wav", "static"),
    ["type_nil"] = love.audio.newSource("sfx/type_nil.wav", "static"),
    ["puzzle_success"] = love.audio.newSource("sfx/puzzle_success.wav", "static"),
    ["puzzle_fail"] = love.audio.newSource("sfx/puzzle_fail.wav", "static"),
    ["hit_blow"] = love.audio.newSource("sfx/hit_blow.ogg", "static"),
    ["hit_miss"] = love.audio.newSource("sfx/hit_miss.wav", "static"),
    ["sfx_gold"] = love.audio.newSource("sfx/sfx_gold.wav", "static"),
}

FONTS = {
    ["title"] = love.graphics.newFont("fonts/Bitmgothic.ttf", FONT_SIZE_TITLE),
    ["subtitle"] = love.graphics.newFont("fonts/Bitmgothic.ttf", FONT_SIZE_SUBTITLE),
    ["default"] = love.graphics.newFont("fonts/BitPotion.ttf", FONT_SIZE_DEFAULT),
    ["narration"] = love.graphics.newFont("fonts/Pixellove.ttf", FONT_SIZE_DEFAULT),
}

--[[
    All the valid components for COMPONENTS_INTERFACE function.
    NOTE: this table requires components.lua to be required first.
    Still, components can use constants.lua variables since they're called inside
    the classes and not executed until main.lua has finished loading everything.
]]

COMPONENTS_TABLE = {
    ["player"] = Player,
    ["npc"] = Npc,
    ["stats"] = Stats,
    ["trap"] = Trap,
    ["trigger"] = Trigger,
    ["pickup"] = Pickup,
    ["usable"] = Usable,
    ["bulky"] = Bulky,
    ["movable"] = Movable,
    ["statchange"] = StatChange,
    ["exit"] = Exit,
    ["dies"] = Dies,
    ["invisible"] = Invisible
}

-- the Input/Output dtable manages the action states that players can activate by hotkey or console command
-- note that the 'console' mode is reserved for 'space' hotkey, to avoid looping through consoles.
-- Lastly, be aware that player = player_component, and entity = player entity
IO_DTABLE = {
    ["observe"] = function(player_comp, entity, key)
        local target_cell

        g.console_string = "Observe where?"
        g.canvas_ui = ui_manager_play()
        
        if player_comp.movement_inputs[key] then
            target_cell = g.grid[entity.cell["grid_row"] + player_comp.movement_inputs[key][1]]
            [entity.cell["grid_column"] + player_comp.movement_inputs[key][2]]
        else
            -- if input is not a valid direction, turn is not valid
            return false
        end

        -- this will be printed to the game's UI console
        print(target_cell.occupant and target_cell.occupant["id"] or "Nothing")
        print(target_cell.entity and target_cell.entity["id"] or "Nothing")
        -- being a free action it always returns nil, so it needs to set player_comp.action_state = nil
        player_comp.action_state = nil
        return false
    end,
    ["pickup"] = function(player_comp, entity, key)
        local target_cell
        local target

        g.console_string = "Pickup where?"
        g.canvas_ui = ui_manager_play()
        
        if player_comp.movement_inputs[key] then
            target_cell = g.grid[entity.cell["grid_row"] + player_comp.movement_inputs[key][1]]
            [entity.cell["grid_column"] + player_comp.movement_inputs[key][2]]
        else
            -- if input is not a valid direction, turn is not valid
            return false
        end

        -- store the target entity, if present
        target = target_cell.entity

        -- if no target is found, return a 'nothing found' message
        if not target_cell.entity then
            print("There's nothing to pick up there")
            return true
        end

        -- if the target has a trigger 'triggeroncollision' comp, trigger immediately
        if target.components["trigger"] and target.components["trigger"].triggeroncollision then
            print("The object triggers!")
            target.components["trigger"]:activate(target, entity)
        end

        -- if no pickup target is found then warn player
        if target_cell.entity.components["pickup"] then
            target.components["pickup"]:activate(target, entity)
            print("You pickup " .. tostring(target.id))
        else
            print("You can't pick this up")
        end

        return true
    end,
    ["use"] = function(player_comp, entity, key)
        local target_cell
        local target

        g.console_string = "Use where?"
        g.canvas_ui = ui_manager_play()
        
        if player_comp.movement_inputs[key] then
            target_cell = g.grid[entity.cell["grid_row"] + player_comp.movement_inputs[key][1]]
            [entity.cell["grid_column"] + player_comp.movement_inputs[key][2]]
        else
            -- if input is not a valid direction, turn is not valid
            return false
        end

        -- store the target entity, if present
        target = target_cell.entity

        -- if no target is found, return a 'nothing found' message
        if not target_cell.entity then
            print("Nothing to use there")
            return true
        end

        -- if the target has a trigger 'triggeroncollision' comp, trigger immediately
        if target.components["trigger"] and target.components["trigger"].triggeroncollision then
            print("The object triggers!")
            target.components["trigger"]:activate(target, entity)
        end

        -- if no usable target is found then warn player
        if target_cell.entity.components["usable"] then
            print("You use " .. tostring(target))
            target.components["usable"]:activate(target, entity)
        else
            print("You can't use this")
        end

        return true
    end,
    ["console"] = function(player_comp, entity, key)
        print("called...")
        local key_output
        local return_value
        
        key_output = player_comp.INPUT_DTABLE[key] or function()
            player_comp.local_string = text_input(player_comp.valid_input, key, player_comp.local_string, 9)
            
            -- always return false, since player is typing action
            return false
        end
        -- call INPUT_DTABLE func or function()
        return_value = key_output()
        print(player_comp.local_string)
        g.console_string = "Thy action: " .. player_comp.local_string
        -- immediately show console string on screen
        g.canvas_ui = ui_manager_play()

        return return_value
    end
}