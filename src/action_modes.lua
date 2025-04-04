--[[
    This module contains the core logic for action modes, aka how the player receives
    input and how it translates to output each time an 'action mode' such as 
    'observe' or 'use' is activated either by a hotkey (ie 'o' for 'observe') or by
    input to console (ie 'o' or 'observe' for 'observe').
]]--

 -- table used for special console key input
local INPUT_DTABLE = {
    ["enter"] = function(player_comp)
        local return_value, custom_action
        -- reset console related values (action_state is set in player_cmd())
        console_cmd(nil)
        player_comp.action_state = nil
        
        love.audio.stop(SOUNDS["button_select"])
        love.audio.play(SOUNDS["button_select"])

        -- check action command, note that 'console' action is forbidden
        if player_comp.string == "space" then
            player_comp.string = ""
        end

        -- if function received valid command, execute action
        return_value, custom_action = player_cmd(player_comp, player_comp.string)

        -- check if player is trying a custom action on Usable Entity
        -- this means any command out of player_cmd() local commands
        if custom_action then
            player_comp.action_state = "use"
            console_cmd("Whither?")
        end
        
        -- false value signals to console that action_mode needs to be changed
        return false
    end,
    ["backspace"] = function(player_comp)
        player_comp.string = text_backspace(player_comp.string)
        -- return false, since player is typing action
        return player_comp.string
    end
}
INPUT_DTABLE["return"] = INPUT_DTABLE["enter"]

--[[
    The Input/Output dtable manages the action modes that players can activate by
    hotkey or console command note that the 'console' mode is reserved for 'space'
    hotkey, to avoid looping through consoles.
    Lastly, be aware that player = player_component, and entity = player entity
]]--
IO_DTABLE = {
    ["observe"] = function(player_comp, player_entity, key)
        local valid_key
        local pawn, entity
        local pawn_str, entity_str

        valid_key, pawn, entity = target_selector(player_comp, player_entity, key)

        if not valid_key then return false end

        if pawn then
            -- defaut action is to set name for string
            pawn_str = string_selector(pawn)
        end

        if entity then
            -- defaut action is to set name for string
            entity_str = string_selector(entity)
        end


        if not pawn_str and not entity_str then
            console_event("Thou dost observe nothing")
        end

        if not pawn_str and entity_str then
            console_event("Thou dost observe ain " .. entity_str)
        end

        if pawn_str and not entity_str then
            console_event("Thou dost observe " .. pawn_str)
        end

        if pawn_str and entity_str then
            console_event(
                "Thou dost observe " .. pawn_str .. ", standing on somethende"
            )
        end

        -- observing is a 'free' action, so it resets action_state to 'nil'
        player_comp.action_state = nil
        console_cmd(nil)

        return false
    end,
    ["talk"] = function(player_comp, entity, key)
        local return_value

        -- when message is ready, switch to special action_state
        if key == "enter" or key == "return" then
            player_comp.action_state = "/"
            console_cmd("Whom dost thou tell? ")

            return false
        end

        if not INPUT_DTABLE[key] then
            player_comp.string = text_input(
                player_comp.valid_input, key, player_comp.string, 41
            )
            -- immediately show console string on screen
            console_cmd("Thy utterances: " .. player_comp.string)            
            -- always return false, since player is typing action
            return false
        end
        
        -- if backspace or enter command, activate
        return_value = INPUT_DTABLE[key](player_comp)

        if return_value then
            console_cmd("Thy utterances: " .. return_value)
        end

        return false
    end,
    ["/"] = function(player_comp, player_entity, key)
        local valid_key
        local entity

        valid_key, _, entity = target_selector(player_comp, player_entity, key)
        
        if not valid_key then return false end

        -- if no target is found, return a 'nothing happens' message
        if not entity then
            console_event("There is naught within")
            return false
        end

        -- if the target has a trigger comp, trigger immediately
        if entity.comps["sealed"] then
            return entity.comps["sealed"]:activate(entity, player_entity, player_comp)
        end

        console_event("Nothing doth seem to happen")

        return true
    end,
    ["pickup"] = function(player_comp, player_entity, key)
        local valid_key
        local pawn, entity

        valid_key, pawn, entity = target_selector(player_comp, player_entity, key)
        
        if not valid_key then return false end

        if not player_entity.comps["inventory"] then
            error_handler("Entity without inventory is trying to pickup")
            return false
        end

        -- if no target is found, return a 'nothing found' message
        if not entity then
            console_event("There's naught to pick up h're")
            return true
        end

        -- block any interaction with 'locked' or 'sealed' Entities
        if not entity_available(entity) then return true end

        -- if the target has a trigger comp, trigger immediately
        if entity.comps["trigger"] then
            entity.comps["trigger"]:activate(entity, player_entity)
        end

        -- if target is has destroyontrigger, don't bother picking up
        if not entity.alive then
            return true
        end

        -- if target has no pickup comp then warn player
        if entity.comps["pickup"] then
            return player_entity.comps["inventory"]:add(entity)
        else
            console_event("Thee art unable to pick hider up")
            return false
        end
    end,
    ["use"] = function(player_comp, player_entity, key)
        local valid_key
        local pawn, entity
        
        valid_key, pawn, entity = target_selector(player_comp, player_entity, key)

        if not valid_key then return false end

        if not g.view_inv then
            local input = player_comp.movement_inputs[key]
            -- player shouldn't be able to activate entities he's standing on,
            -- since they could change physics and block him improperly
            
            if input[1] == 0 and input[2] == 0 then
                console_event("Thou need to step back to accomplish this!")
                return false
            end
        end

        if pawn then
            local pawn_str = string_selector(pawn)

            console_event(pawn_str .. " is hindering your action")
            return false
        end

        -- if no target is found, return a 'nothing found' message
        if not entity then
            console_event("There is naught usaeble h're")
            return true
        end

        -- block any interaction with 'locked' or 'sealed' Entities
        if not entity_available(entity) then return true end

        -- if the target has a trigger 'trig_on_coll' comp, trigger immediately
        if entity.comps["trigger"] and entity.comps["trigger"].trig_on_coll then
            entity.comps["trigger"]:activate(entity, player_entity)
        end

        -- if usable target is found activate, else warn player
        if entity.comps["usable"] then
            local console_string
            local entity_str = string_selector(entity)

            -- if player_comp.string is empty, the command is a simple 'use'.
            -- Set it to false to let Usable comp & console_event() know this.
            if player_comp.string == "" then player_comp.string = false end
            console_string = player_comp.string or "usae "

            console_event("Thee " .. console_string .. " " .. entity_str)
            entity.comps["usable"]:activate(entity, player_entity, player_comp.string)
        else
            console_event("Nothing doth happen")
        end

        return true
    end,
    ["unlock"] = function(player_comp, player_entity, key)
        local valid_key
        local pawn, entity

        valid_key, pawn, entity = target_selector(player_comp, player_entity, key)
        
        if not valid_key then return false end

        -- if no target is found, return a 'nothing found' message
        if not entity then
            console_event("There be naught that can be unlocked h're")
            return true
        end

        -- if no unlockable target is found then warn player
        if entity.comps["locked"] then
            entity.comps["locked"]:activate(entity, player_entity)
        else
            console_event("Thee can't unlock this")
        end

        return true
    end,
    ["equip"] = function(player_comp, player_entity, key)
        local player_slots = player_entity.comps["slots"]
        local target_item
        local equipable_comp

        if not player_slots then
            error_handler("Trying to equip without slots component")
            return false
        end

        -- player slots
        player_slots = player_slots.slots

        -- check if there's an item coupled with this letter
        if not g.current_inv[key] then
            return false
        end

        -- check if the selected item is equipable
        if not g.current_inv[key].comps["equipable"] then
            console_event("Thee can't equip this")
            return true
        end

        -- item 'equipable' comp
        equipable_comp = g.current_inv[key].comps["equipable"]

        -- check if proper slot for the item is available in 'slots' component
        for _, slot in ipairs(equipable_comp.suitable_slots) do
            if player_slots[slot] == "empty" then
                -- save occupied slot in equipped object for easier referencing
                equipable_comp.slot_reference = slot
                -- store item inside slots component
                player_slots[slot] = g.current_inv[key]
                print("Equipped object!")
                -- activate equip() func in 'equipable' component
                -- this can trigger dedicated effects thanks to 'equip' tagged power
                equipable_comp:equip(g.current_inv[key], player_entity)
                return true
            end
        end

        -- if no compatible/free slot is found on Entity, return false
        console_event("Thou hast no vacant slot to don this")
        return false
    end,
    ["unequip"] = function(player_comp, player_entity, key)
        local player_slots

        if not player_entity.comps["slots"] then
            print("WARNING: Entity without slots is trying to unequip")
            return false
        end
        -- if an item player_entity was equipped and still is,
        -- we can assume its data is predictable
        player_slots = player_entity.comps["slots"].slots

        if g.current_inv[key] then
            local item
            local success

            item = g.current_inv[key]

            if not item.comps["equipable"] then
                print("Trying to unequip an unequippable object!")
                return false
            end

            -- if this variable == false, then the item wasn't equipped
            if not item.comps["equipable"].slot_reference then
                print("Trying to unequip a non-equipped, equippable object")
                return false
            end

            success = item.comps["equipable"]:unequip(item, player_entity)

            -- if item isn't cursed, empty player_slots component reference
            -- and also equipable component slot_reference
            if success then
                player_slots[item.comps["equipable"].slot_reference] = "empty"
                item.comps["equipable"].slot_reference = false
            end
        else
            print("No item at this key address")
            return false
        end

        return true
    end,
    ["bestow"] = function(player_comp, player_entity, key)
        local player_slots = player_entity.comps["slots"]
        local item

        if not player_slots then
            print("Entity without slots comp trying to bestow")
            return false
        end

        item = g.current_inv[key]

        -- check if there's an item coupled with this letter
        if not item then
            return false
        end

        -- if this variable == false, then the item is currently equipped
        if item.comps["equipable"] and item.comps["equipable"].slot_reference then
            console_event("Thee need to unequip this first")
            return false
        end


        -- at this point, a valid item was selected
        g.view_inv = false
        player_comp.action_state = "#"
        -- store selected item in player_comp.string
        player_comp.string = key
        console_cmd("Where do you bestow it?")

        return false
    end,
    ["#"] = function(player_comp, player_entity, key)
        local valid_key
        local pawn, entity
        local target_cell
        local item
        local item_key = player_comp.string
        local item_str

        valid_key, pawn, entity, target_cell = target_selector(player_comp, player_entity, key)

        if not valid_key then
            print("Invalid key")
            return false
        end

        if not target_cell or TILES_PHYSICS[target_cell.index] == "solid" then
            console_event("You cannot bestow anything here")
            return false
        end

        if pawn then
            local pawn_str = string_selector(pawn)

            console_event(pawn_str .. " is hindering your action")
            return false
        end

        if entity then
            local entity_str = string_selector(entity)

            console_event(entity_str .. " is already occupying this space")
            return false
        end

        -- at this point, everything is in check. Store item
        item = g.current_inv[item_key]

        -- set proper item string
        item_str = string_selector(item)

        -- then remove item from inventory using item_key position in alphabet
        player_entity.comps["inventory"]:remove(item_key)
        inventory_update(player_entity)
        player_comp.string = false

        -- then position item in target_cell and add to entities_group
        item.alive = true
        item.cell["cell"] = target_cell
        item.cell["grid_row"] = target_cell.y
        item.cell["grid_col"] = target_cell.x
        target_cell.entity = item
        table.insert(g.entities_group, item)

        -- insert item in visible or invisible group
        if not item.comps["invisible"] then
            -- adding entity in proper drawing order (back/front) based on their
            -- belonging to Players/NPCs or simple Entities
            table.insert(g.render_group, 1, item)
        else
            table.insert(g.hidden_group, item)
        end

        console_event("Thee bestow " .. item_str)

        return true
    end,
    ["quit"] = function(player_comp, player_entity, key)
        if key == "n" then
            player_comp.string = false
            console_cmd(nil)
            player_comp.action_state = nil

            return false
        end

        if key == "y" then
            love.event.quit()

            return false
        end

        player_comp.string = false
        console_event("Inscribe Y(ea) or N(ay)")

        return false
    end,
    ["loose"] = function(player_comp, player_entity, key)
        -- TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO 
        console_event("Check if ammo available, list of all in-weapon-range targets...")

        return true
    end,
    ["console"] = function(player_comp, entity, key)
        local return_value

        if not INPUT_DTABLE[key] then
            player_comp.string = text_input(
                player_comp.valid_input, key, player_comp.string, 9
            )
            -- immediately show console string on screen
            console_cmd("Thy action: " .. player_comp.string)            
            -- always return false, since player is typing action
            return false
        end
        
        -- if backspace or enter command, activate
        return_value = INPUT_DTABLE[key](player_comp)

        -- if backspace, modify string
        if return_value then
            console_cmd("Thy action: " .. player_comp.string)

            return false
        end
        
        return false
    end
}

-- this func links hotkey/console commands to corresponding action modes
function player_cmd(player_comp, input_key)
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
                console_cmd("Utilize what?")            
                return false
            end
        end,
        ["unlock"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "unlock"
                console_cmd("Unbar what?")
                return false
            end
        end,
        ["inventory"] = function()
            if not player_comp.action_state then
                g.view_inv = not g.view_inv
                -- necessary to update UI so that only console string is visible
                g.cnv_ui = ui_manager_play()
                return false
            end
        end,
        ["observe"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "observe"
                console_cmd("Observe what?")             
                return false
            end
        end,
        ["talk"] = function(player_comp)
            if not player_comp.action_state then
                player_comp.action_state = "talk"
                console_cmd("Thy utterances: ")             
                return false
            end
        end,
        ["pickup"] = function(player_comp)
            if not player_comp.action_state then
                -- avoid picking up entities already in inventory
                g.view_inv = false
                
                player_comp.action_state = "pickup"
                console_cmd("Pickup what?")          
                return false
            end
        end,
        ["equip"] = function(player_comp)
            if not player_comp.action_state then
                g.view_inv = true
                -- necessary to update UI so that only console string is visible
                g.cnv_ui = ui_manager_play()
                player_comp.action_state = "equip"
                console_cmd("Gear up thyself with what?")
                return false
            end
        end,
        ["unequip"] = function(player_comp)
            if not player_comp.action_state then
                g.view_inv = true
                -- necessary to update UI so that only console string is visible
                g.cnv_ui = ui_manager_play()
                player_comp.action_state = "unequip"
                console_cmd("Unequip from thyself what?")
                return false
            end
        end,
        ["loose"] = function(player_comp)
            if not player_comp.action_state then
                g.view_inv = false
                player_comp.action_state = "loose"
                console_cmd("Loose thy projectile where?")
                return false
            end
        end,
        ["bestow"] = function(player_comp)
            if not player_comp.action_state then
                g.view_inv = true
                -- necessary to update UI so that only console string is visible
                g.cnv_ui = ui_manager_play()
                -- used to drop stuff around or to place items in proper places
                player_comp.action_state = "bestow"
                console_cmd("Bestow what?")
                return false
            end
        end,
        ["quit"] = function()
            if not player_comp.action_state then
                player_comp.action_state = "quit"
                console_cmd("Art thou truly certain thou dost wish to depart?")          
                return false
            end
        end
    }
    -- these are 'hotkeys' or 'console commands'. They 'link' to actual action modes
    -- NOTE: console can only be activated from a hotkey, not from itself!
    commands["r"] = commands["unequip"]
    commands["remove"] = commands["unequip"]
    commands["t"] = commands["talk"]
    commands["u"] = commands["use"]
    commands["i"] = commands["inventory"]
    commands["o"] = commands["observe"]
    commands["p"] = commands["pickup"]
    commands["escape"] = commands["quit"]
    commands["g"] = commands["equip"]
    commands["gear up"] = commands["equip"]
    commands["l"] = commands["loose"]
    commands["b"] = commands["bestow"]
    commands["space"] = commands[":"] -- note how console is under is inaccesible


    -- if key is invalid, erase eventual console["string"] and return false
    if not commands[key] then
        console_cmd(nil)

        return false, true
    end

    player_comp.string = ""
    return commands[key](player_comp)
end