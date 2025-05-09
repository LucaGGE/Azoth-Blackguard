--[[
    This module contains the core logic for action modes, aka how the player receives
    input and how it translates to output each time an 'action mode' such as 
    'observe' or 'use' is activated either by a hotkey (ie 'o' for 'observe') or by
    input to console (ie 'o' or 'observe' for 'observe').
]]--

 -- table used for special console key input (player only)
local INPUT_DTABLE = {
    ["enter"] = function(pc_comp)
        local return_value, custom_action
        -- reset console related values (action_state is set in player_cmd())
        console_cmd(nil)
        pc_comp.action_state = nil
        
        play_sound(SOUNDS["button_select"])

        -- check action command, note that 'console' action is forbidden
        if pc_comp.string == "space" then
            pc_comp.string = ""
        end

        -- if function received valid command, execute action
        return_value, custom_action = pc_cmd(pc_comp, pc_comp.string)

        -- check if player is trying a custom action on Usable Entity
        -- this means any command out of player_cmd() local commands
        if custom_action then
            pc_comp.action_state = "use"
            console_cmd("Whither?")
        end
        
        -- false value signals to console that action_mode needs to be changed
        return false
    end,
    ["backspace"] = function(pc_comp)
        pc_comp.string = text_backspace(pc_comp.string)
        -- return false, since player is typing action
        return pc_comp.string
    end
}
INPUT_DTABLE["return"] = INPUT_DTABLE["enter"]

--[[
    The Input/Output dtable manages the action modes that players can activate by
    hotkey or console command. Not that some action modes are only available from
    other action modes (/talk, /bestow).
    Action modes can also be accessed by NPCs in a more limited way.
    'talk' and 'console' are player-exclusive and need access to local INPUT_DTABLE,
    hence they are not in util.lua.
]]--
IO_DTABLE = {
    ["observe"] = function(pc_comp, pc_entity, key)
        return observe_func(pc_comp, pc_entity, key)
    end,
    ["talk"] = function(pc_comp, entity, key)
        local return_value

        -- when message is ready, switch to special action_state
        if key == "enter" or key == "return" then
            pc_comp.action_state = "/talk"
            console_cmd("Whom dost thou tell? ")

            return false
        end

        if not INPUT_DTABLE[key] then
            pc_comp.string = text_input(pc_comp.valid_input, key, pc_comp.string, 41)
            -- immediately show console string on screen
            console_cmd("Thy utterances: " .. pc_comp.string)            
            -- always return false, since player is typing action
            return false
        end
        
        -- if backspace or enter command, activate
        return_value = INPUT_DTABLE[key](pc_comp)

        if return_value then
            console_cmd("Thy utterances: " .. return_value)
        end

        return false
    end,
    ["/talk"] = function(pc_comp, pc_entity, key)
        return talk_func(pc_comp, pc_entity, key)
    end,
    ["pickup"] = function(pc_comp, pc_entity, key)
        return pickup_check_func(pc_comp, pc_entity, key)
    end,
    ["use"] = function(pc_comp, pc_entity, key)
        return use_func(pc_comp, pc_entity, key)
    end,
    ["unlock"] = function(pc_comp, pc_entity, key)
        return unlock_func(pc_comp, pc_entity, key)
    end,
    ["equip"] = function(pc_comp, pc_entity, key)
        return equip_func(pc_comp, pc_entity, key)
    end,
    ["unequip"] = function(pc_comp, pc_entity, key)
        return unequip_func(pc_comp, pc_entity, key)
    end,
    ["bestow"] = function(pc_comp, pc_entity, key)
        return bestow_select_func(pc_comp, pc_entity, key)
    end,
    ["/bestow"] = function(pc_comp, pc_entity, key)
        return bestow_place_func(pc_comp, pc_entity, key)
    end,
    ["quit"] = function(pc_comp, pc_entity, key)
        return quit_func(pc_comp, pc_entity, key)
    end,
    ["loose"] = function(pc_comp, pc_entity, key)
        return loose_func(pc_comp, pc_entity, key)
    end,
    ["console"] = function(pc_comp, entity, key)
        local return_value

        if not INPUT_DTABLE[key] then
            pc_comp.string = text_input(
                pc_comp.valid_input, key, pc_comp.string, 9
            )
            -- immediately show console string on screen
            console_cmd("Thy action: " .. pc_comp.string)            
            -- always return false, since player is typing action
            return false
        end
        
        -- if backspace or enter command, activate
        return_value = INPUT_DTABLE[key](pc_comp)

        -- if backspace, modify string
        if return_value then
            console_cmd("Thy action: " .. pc_comp.string)

            return false
        end
        
        return false
    end
}

-- this func links hotkey/std console commands to corresponding action modes
function pc_cmd(pc_comp, input_key)
    local key = input_key

    local commands = {
        ["/console"] = function()
            if not pc_comp.action_state then
                pc_comp.action_state = "console"
                -- immediately show console and update ui canvas
                console_cmd("Thy action: ")

                return false
            end
        end,
        ["use"] = function(pc_comp)
            if not pc_comp.action_state then
                pc_comp.action_state = "use"
                console_cmd("Utilize what?")            
                return false
            end
        end,
        ["unlock"] = function(pc_comp)
            if not pc_comp.action_state then
                pc_comp.action_state = "unlock"
                console_cmd("Unbar what?")
                return false
            end
        end,
        ["inventory"] = function()
            if not pc_comp.action_state then
                g.panel_on = not g.panel_on
                -- necessary to update UI so that only console string is visible
                g.cnv_ui = ui_manager_play()
                return false
            end
        end,
        ["observe"] = function(pc_comp)
            if not pc_comp.action_state then
                pc_comp.action_state = "observe"
                console_cmd("Observe what?")             
                return false
            end
        end,
        ["talk"] = function(pc_comp)
            if not pc_comp.action_state then
                pc_comp.action_state = "talk"
                console_cmd("Thy utterances: ")             
                return false
            end
        end,
        ["pickup"] = function(pc_comp)
            if not pc_comp.action_state then
                -- avoid picking up entities already in inventory
                g.panel_on = false
                
                pc_comp.action_state = "pickup"
                console_cmd("Pickup what?")          
                return false
            end
        end,
        ["equip"] = function(pc_comp)
            if not pc_comp.action_state then
                -- necessary to update UI so that only console string is visible
                g.cnv_ui = ui_manager_play()
                pc_comp.action_state = "equip"
                console_cmd("Gear up thyself with what?")
                return false
            end
        end,
        ["unequip"] = function(pc_comp)
            if not pc_comp.action_state then
                g.panel_on = true
                -- necessary to update UI so that only console string is visible
                g.cnv_ui = ui_manager_play()
                pc_comp.action_state = "unequip"
                console_cmd("Unequip from thyself what?")
                return false
            end
        end,
        ["loose"] = function(pc_comp)
            if not pc_comp.action_state then
                g.panel_on = false
                pc_comp.action_state = "loose"
                console_cmd("Loose thy projectile where?")
                return false
            end
        end,
        ["bestow"] = function(pc_comp)
            if not pc_comp.action_state then
                g.panel_on = true
                -- necessary to update UI so that only console string is visible
                g.cnv_ui = ui_manager_play()
                -- used to drop stuff around or to place items in proper places
                pc_comp.action_state = "bestow"
                console_cmd("Bestow what?")
                return false
            end
        end,
        ["quit"] = function()
            if not pc_comp.action_state then
                pc_comp.action_state = "quit"
                console_cmd("Art thou truly certain thou dost wish to depart?")          
                return false
            end
        end
    }
    -- these are 'hotkeys' or 'console commands', they link to actual action modes
    -- NOTE: console can only be activated from a hotkey, not from itself!
    commands["r"] = commands["unequip"]
    commands["remove"] = commands["unequip"]
    commands["t"] = commands["talk"]
    commands["u"] = commands["use"]
    commands["i"] = commands["inventory"]
    commands["o"] = commands["observe"]
    commands["p"] = commands["pickup"]
    commands["escape"] = commands["quit"]
    commands["q"] = commands["quit"]
    commands["g"] = commands["equip"]
    commands["gear up"] = commands["equip"]
    commands["l"] = commands["loose"]
    commands["b"] = commands["bestow"]
    commands["space"] = commands["/console"]


    -- if key is invalid, erase eventual console["string"] and return false
    if not commands[key] then
        console_cmd(nil)

        return false, true
    end

    pc_comp.string = ""
    return commands[key](pc_comp)
end