-- This module contains the core logic for action modes, aka how the player receives input and how it
-- translates to output each time an 'action mode' such as 'observe' or 'use' is activated either by a
-- hotkey (ie 'o' for 'observe') or by input to console (ie 'o' or 'observe' for 'observe').

 -- table used for special console key input
local INPUT_DTABLE = {
    ["enter"] = function(player_comp)
        local return_value, custom_action
        -- reset console related values (action_state is set in player_commands())
        console_cmd(nil)
        player_comp.action_state = nil
        
        love.audio.stop(SOUNDS["button_select"])
        love.audio.play(SOUNDS["button_select"])

        -- check action command, note that 'console' action is forbidden
        if player_comp.local_string == "space" then
            player_comp.local_string = ""
        end

        -- if function received valid command, execute action
        return_value, custom_action = player_commands(player_comp, player_comp.local_string)

        -- check if player is trying a custom action on Usable Entity
        -- this means any command out of player_commands() local commands
        if custom_action then
            player_comp.action_state = "use"
            console_cmd("Where?")
        end
        
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
    ["observe"] = function(player_comp, player_entity, key)
        local valid_key
        local occupant_ref, entity_ref
        local occupant_str, entity_str

        valid_key, occupant_ref, entity_ref = target_selector(player_comp, player_entity, key)

        if not valid_key then return false end

        if occupant_ref then
            -- defaut action is to set name for string
            occupant_str = occupant_ref.name
            
            if occupant_ref.components["description"] then
                occupant_str = occupant_ref.components["description"].string
            end

            if occupant_ref.components["secret"] then
                occupant_str = occupant_ref.components["secret"].string
            end
        end
        if entity_ref then
            -- defaut action is to set name for string
            entity_str = entity_ref.name
            
            if entity_ref.components["description"] then
                entity_str = entity_ref.components["description"].string
            end

            if entity_ref.components["secret"] then
                entity_str = entity_ref.components["secret"].string
            end
        end


        if not occupant_str and not entity_str then
            console_event("Thee observe nothing")
        end

        if not occupant_str and entity_str then
            console_event("Thee observe ain " .. entity_str)
        end

        if occupant_str and not entity_str then
            console_event("Thee observe " .. occupant_str)
        end

        if occupant_str and entity_str then
            console_event("Thee observe " .. occupant_str .. ", standing on somethende")
        end

        -- being a free action it always returns nil, so it needs to set player_comp.action_state = nil
        player_comp.action_state = nil
        console_cmd(nil)

        return false
    end,
    ["talk"] = function(player_comp, entity, key)
        local return_value

        -- when message is ready, go to non accessible action_state and choose target
        if key == "enter" or key == "return" then
            player_comp.action_state = "/"
            console_cmd("Tell whom? ")

            return false
        end

        if not INPUT_DTABLE[key] then
            player_comp.local_string = text_input(player_comp.valid_input, key, player_comp.local_string, 41)
            -- immediately show console string on screen
            console_cmd("Your words: " .. player_comp.local_string)            
            -- always return false, since player is typing action
            return false
        end
        
        -- if backspace or enter command, activate
        return_value = INPUT_DTABLE[key](player_comp)

        if return_value then
            console_cmd("Your words: " .. return_value)
        end

        return false
    end,
    ["/"] = function(player_comp, player_entity, key)
        local valid_key
        local occupant_ref, entity_ref

        valid_key, occupant_ref, entity_ref = target_selector(player_comp, player_entity, key)
        
        if not valid_key then return false end

        -- if no target is found, return a 'nothing happens' message
        if not entity_ref then
            console_event("There is naught within")
            return false
        end

        -- if the target has a trigger comp, trigger immediately
        if entity_ref.components["sealed"] then
            return entity_ref.components["sealed"]:activate(entity_ref, player_entity, player_comp)
        end

        console_event("Nothing doth seem to happen")

        return true
    end,
    ["pickup"] = function(player_comp, player_entity, key)
        local valid_key
        local occupant_ref, entity_ref

        valid_key, occupant_ref, entity_ref = target_selector(player_comp, player_entity, key)
        
        if not valid_key then return false end

        if not player_entity.components["inventory"] then
            error_handler("Entity without inventory is trying to pickup")
            return false
        end

        -- if no target is found, return a 'nothing found' message
        if not entity_ref then
            console_event("There's non-other to pick up h're")
            return true
        end

        -- block any interaction with 'locked' or 'sealed' Entities
        if not entity_available(entity_ref) then return true end

        -- if the target has a trigger comp, trigger immediately
        if entity_ref.components["trigger"] then
            entity_ref.components["trigger"]:activate(entity_ref, player_entity)
        end

        -- if target is has destroyontrigger, don't bother picking up
        if not entity_ref.alive then
            return true
        end

        -- if target has no pickup comp then warn player
        if entity_ref.components["pickup"] then
            return player_entity.components["inventory"]:add(entity_ref)
        else
            console_event("Thee art unable to pick hider up")
            return false
        end
    end,
    ["use"] = function(player_comp, player_entity, key)
        local valid_key
        local occupant_ref, entity_ref
        
        valid_key, occupant_ref, entity_ref = target_selector(player_comp, player_entity, key)

        if not valid_key then return false end

        -- it is better to avoid player to activate objects when standing on them,
        -- since they could change physics and block him
        if player_comp.movement_inputs[key][1] == 0 and player_comp.movement_inputs[key][2] == 0 then
            console_event("Thou need to step back to accomplish this!")
            return false
        end

        if occupant_ref then
            local occupant_str = occupant_ref.name

            if occupant_ref.components["description"] then
                occupant_str = occupant_ref.components["description"].string
            end

            if occupant_ref.components["secret"] then
                occupant_str = occupant_ref.components["secret"].string
            end

            console_event(occupant_str .. " is hindering your action")
            return false
        end

        -- if no target is found, return a 'nothing found' message
        if not entity_ref then
            console_event("There is non-other usaeble h're")
            return true
        end

        -- block any interaction with 'locked' or 'sealed' Entities
        if not entity_available(entity_ref) then return true end

        -- if the target has a trigger 'triggeroncollision' comp, trigger immediately
        if entity_ref.components["trigger"] and entity_ref.components["trigger"].triggeroncollision then
            entity_ref.components["trigger"]:activate(entity_ref, player_entity)
        end

        -- if usable target is found activate, else warn player
        if entity_ref.components["usable"] then
            local console_string
            -- if local_string is empty, then player is acting a simple 'use' command
            -- in this case, set it to false to let Usable comp & console_event() know
            if player_comp.local_string == "" then player_comp.local_string = false end
            console_string = player_comp.local_string or "usae "

            console_event("Thee " .. console_string .. " " .. entity_ref.name)
            entity_ref.components["usable"]:activate(entity_ref, player_entity, player_comp.local_string)
        else
            console_event("Nothing doth happen")
        end

        return true
    end,
    ["unlock"] = function(player_comp, player_entity, key)
        local valid_key
        local occupant_ref, entity_ref

        valid_key, occupant_ref, entity_ref = target_selector(player_comp, player_entity, key)
        
        if not valid_key then return false end

        -- if no target is found, return a 'nothing found' message
        if not entity_ref then
            console_event("There be naught that can be unlocked h're")
            return true
        end

        -- if no unlockable target is found then warn player
        if entity_ref.components["locked"] then
            entity_ref.components["locked"]:activate(entity_ref, player_entity)
        else
            console_event("Thee can't unlock this")
        end

        return true
    end,
    ["equip"] = function(player_comp, entity, key)
        local slots_ref = entity.components["slots"]
        local target_item

        if not slots_ref then
            error_handler("Trying to equip without slots component")
            return false
        end

        slots_ref = slots_ref.slots -- player slots

        -- check if there's an item coupled with this letter
        if not g.current_inventory[key] then
            return false
        end

        -- check if the selected item is equipable
        if not g.current_inventory[key].components["equipable"] then
            console_event("Thee can't equip this")
            return true
        end

        -- check if the slot required by the item is available in Entity Slots component
        for _, suit_slot in ipairs(g.current_inventory[key].components["equipable"].suitable_slots) do
            if slots_ref[suit_slot] == "empty" then
                -- save occupied slot in equipped object for easier referencing
                g.current_inventory[key].components["equipable"].slot_reference = suit_slot
                -- store item inside slots component
                slots_ref[suit_slot] = g.current_inventory[key]
                print("Equipped object!")
                -- activate equip() func in 'equipable' component to trigger dedicated effects
                g.current_inventory[key].components["equipable"]:equip(g.current_inventory[key], entity)
                return true
            end
        end

        -- if no compatible/free slot is found on Entity, return false
        print("No compatible/free slot found")
        return false
    end,
    ["unequip"] = function(player_comp, player_entity, key)
        local slots_ref

        if not player_entity.components["slots"] then
            print("WARNING: Entity without slots is trying to unequip")
            return false
        end
        -- if an item player_entity was equipped and still is, we can assume its data is predictable
        slots_ref = player_entity.components["slots"].slots

        if g.current_inventory[key] then
            local item
            local success

            item = g.current_inventory[key]

            if not item.components["equipable"] then
                print("Trying to unequip an unequippable object!")
                return false
            end

            -- if this variable == false, then the item wasn't equipped in the first place
            if not item.components["equipable"].slot_reference then
                print("Trying to unequip a non-equipped, equippable object")
                return false
            end

            success = item.components["equipable"]:unequip(item, player_entity)

            -- if item isn't cursed, empty slots comp item reference and equipable comp slot reference
            if success then
                slots_ref[item.components["equipable"].slot_reference] = "empty"
                item.components["equipable"].slot_reference = false
            end
        else
            print("No item at this key address")
            return false
        end

        return true
    end,
    ["console"] = function(player_comp, entity, key)
        local return_value

        if not INPUT_DTABLE[key] then
            player_comp.local_string = text_input(player_comp.valid_input, key, player_comp.local_string, 9)
            -- immediately show console string on screen
            console_cmd("Thy action: " .. player_comp.local_string)            
            -- always return false, since player is typing action
            return false
        end
        
        -- if backspace or enter command, activate
        return_value = INPUT_DTABLE[key](player_comp)

        -- if backspace, modify string
        if return_value then
            console_cmd("Thy action: " .. player_comp.local_string)

            return false
        end
        
        return false
    end
}

-- this function contains a table that links hotkey/console commands to actual action modes
function player_commands(player_comp, input_key)
    local key = input_key

    local commands = {
        [":"] = function()
            if not player_comp.action_state then
                player_comp.action_state = "console"
                -- immediately show console and update ui canvas
                console_cmd("Thy action: ")

                return false
            end
        end,
        ["use"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "use"
                console_cmd("Use where?")            
                return false
            end
        end,
        ["unlock"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "unlock"
                console_cmd("Unlock where?")            
                return false
            end
        end,
        ["inventory"] = function()
            print("WARNING: inventory func in development")
            if not player_comp.action_state then
                g.view_inventory = not g.view_inventory
                return false
            end
        end,
        ["observe"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "observe"
                console_cmd("Observe where?")             
                return false
            end
        end,
        ["talk"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "talk"
                console_cmd("Your words: ")             
                return false
            end
        end,
        ["pickup"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "pickup"
                console_cmd("Pickup where?")          
                return false
            end
        end,
        ["equip"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "equip"
                console_cmd("Equip what?")
                return false
            end
        end,
        ["unequip"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "unequip"
                console_cmd("Unequip what?")
                return false
            end
        end
    }
    -- these are 'hotkeys', aka the action modes 'links' that can be activated by keyboard shortcut
    -- other than with console (note console can only be activated from a hotkey)
    commands["t"] = commands["talk"]
    commands["u"] = commands["use"]
    commands["i"] = commands["inventory"]
    commands["o"] = commands["observe"]
    commands["p"] = commands["pickup"]
    commands["space"] = commands[":"] -- note how console is under an inaccesible key

    -- if key is invalid, erase eventual console["string"] and return false
    if not commands[key] then
        console_cmd(nil)

        return false, true
    end

    player_comp.local_string = ""
    return commands[key](player_comp)
end