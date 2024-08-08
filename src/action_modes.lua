-- This module contains the core logic for action modes, aka how the player receives input and how it
-- translates to output each time an 'action mode' such as 'observe' or 'use' is activated either by a
-- hotkey (ie 'o' for 'observe') or by input to console (ie 'o' or 'observe' for 'observe').

 -- table used for special console key input
local INPUT_DTABLE = {
    ["enter"] = function(player_comp)
        local return_value
        print("check input dtable")
        -- reset console related values (action_state is set in player_commands())
        g.console_string = nil
        player_comp.action_state = nil
        
        love.audio.stop(SOUNDS["button_select"])
        love.audio.play(SOUNDS["button_select"])

        -- check action commang, note that 'console' action is forbidden
        if player_comp.local_string == "space" then
            player_comp.local_string = ""
        end

        -- if function received valid command, execute action
        return_value = player_commands(player_comp, player_comp.local_string)

        -- false value signals to console that action_mode needs to be changed
        return false
    end,
    ["backspace"] = function(player_comp)
        player_comp.local_string = text_backspace(player_comp.local_string)
        -- return false, since player is typing action
        return player_comp.local_string
    end
}
INPUT_DTABLE["return"] = INPUT_DTABLE["enter"]

-- the Input/Output dtable manages the action modes that players can activate by hotkey or console command
-- note that the 'console' mode is reserved for 'space' hotkey, to avoid looping through consoles.
-- Lastly, be aware that player = player_component, and entity = player entity
IO_DTABLE = {
    ["observe"] = function(player_comp, entity, key)
        local target_cell
        
        if player_comp.movement_inputs[key] then
            target_cell = g.grid[entity.cell["grid_row"] + player_comp.movement_inputs[key][1]]
            [entity.cell["grid_column"] + player_comp.movement_inputs[key][2]]
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
        local return_value

        if not INPUT_DTABLE[key] then
            player_comp.local_string = text_input(player_comp.valid_input, key, player_comp.local_string, 9)
            g.console_string = "Thy action: " .. player_comp.local_string
            -- immediately show console string on screen
            g.canvas_ui = ui_manager_play()
            print(player_comp.local_string)
            
            -- always return false, since player is typing action
            return false
        end
        
        -- if backspace or enter command, activate
        return_value = INPUT_DTABLE[key](player_comp)

        if return_value then
            g.console_string = "Thy action: " .. return_value
            g.canvas_ui = ui_manager_play()
        else
            -- reset local_string and enter new action_mode
            player_comp.local_string = ""
            --g.game_state:refresh()
        end

        return false
    end
}

-- this function contains a table that links hotkey/console commands to actual action modes
function player_commands(player_comp, key)
    local commands = {
        [":"] = function()
            if not player_comp.action_state then
                player_comp.action_state = "console"

                -- immediately show console and update ui canvas
                g.console_string = "Thy action: "
                g.canvas_ui = ui_manager_play()

                return false
            end
        end,
        ["use"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "use"
                g.console_string = "Use where?"
                g.canvas_ui = ui_manager_play()                
                return false
            end
        end,
        ["inventory"] = function()
            g.console_string = "inventory"
            return true
        end,
        ["observe"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "observe"
                g.console_string = "Observe where?"
                g.canvas_ui = ui_manager_play()                
                return false
            end
        end,
        ["pickup"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "pickup"
                g.console_string = "Pickup where?"
                g.canvas_ui = ui_manager_play()                
                return false
            end
        end
    }
    -- these are 'hotkeys', aka the action modes 'links' that can be activated by keyboard shortcut
    -- other than with console (note console can only be activated from a hotkey)
    commands["u"] = commands["use"]
    commands["i"] = commands["inventory"]
    commands["o"] = commands["observe"]
    commands["p"] = commands["pickup"]
    commands["space"] = commands[":"] -- note how console is under an inaccesible key

    -- if key is invalid, erase eventual console_string and return false
    if not commands[key] then
        g.console_string = ""
        g.canvas_ui = ui_manager_play()
        return false
    end

    return commands[key](player_comp)
end