--[[
    Implemented components. NOTE: some will be checked for when a blueprint is
    created (i.e. npc, player), as they will be added to special groups, needed to
    avoid searching for specific components each time an event is fired (i.e. when
    Player gives input, or the Player position).
]]

-- this stores all the legal movement-phys MOV_TO_PHYS (see VALID_PHYSICS)
local MOV_TO_PHYS = {
    ["ruck"] = "difficult",
    ["swim"] = "liquid",
    ["climb"] = "climbable",
    ["fly"] = "void",
    ["phase"] = "solid",
    ["walk"] = "ground"
}

-- note this is NOT found in BLUEPRINTS_TABLE, as it is restricted to the game menu
Player = Object:extend()
function Player:new()
    -- players are automatically part of this group
    self.group = "players"
    self.action_state = nil
    self.valid_input = "qwertyuiopasdfghjklzxcvbnmspace"
    self.string = "" -- stores player input for all action_modes
    -- this variable contains all the movement inputs key-values
    -- for both keypad and keyboard, with key corresponding to (row, column)
    self.movement_inputs = {
        ["kp7"] = {-1,-1}, ["q"] = {-1,-1},
        ["kp8"] = {-1,0}, ["w"] = {-1,0},
        ["kp9"] = {-1,1}, ["e"] = {-1,1},
        ["kp6"] = {0,1}, ["d"] = {0,1},
        ["kp3"] = {1,1}, ["c"] = {1,1},
        ["kp2"] = {1,0}, ["x"] = {1,0},
        ["kp1"] = {1,-1}, ["z"] = {1,-1},
        ["kp4"] = {0,-1}, ["a"] = {0,-1},
        ["kp5"] = {0, 0}, ["s"] = {0, 0}
    }
end

function Player:manage_input(entity, key)
    if key == "escape" then 
        self.action_state = nil
        self.string = ""
        console_cmd(nil)

        return false
    end

    if not self.action_state then
        local mov_input = self.movement_inputs[key]

        -- checking if player is trying to use a hotkey
        if not mov_input and not self.action_state then
            -- hotkeys allow access only to a few selected states/interactions.
            -- NOTE: 'self' = this comp, and 'entity' = player entity
            return player_cmd(self, key)
        end

        -- check if player has inventory open, to avoid undesired movement input
        if g.view_inv then
            return false
        end
    
        -- check if player is skipping turn (possible even without a mov comp)
        if mov_input[1] == 0 and mov_input[2] == 0 then
            love.audio.stop(SOUNDS["wait"])
            love.audio.play(SOUNDS["wait"])
            return true
        end

        -- 'Movable' component can be modified/added/removed during gameplay,
        -- so it is imperative to check for it each time
        if not entity.comps["movable"] then
            print("INFO: The entity does not contain a movement component")
            return false
        end

        -- if no guard statements were activated, player is legally trying to move
        return entity.comps["movable"]:move_entity(entity, mov_input)
    end

    -- managing self.action_state mode of input  
    if IO_DTABLE[self.action_state] then
        return IO_DTABLE[self.action_state](self, entity, key)
    end

    -- if no valid input was received for the mode, return false
    print("Called IO_DTABLE[self.action_state] where self.action_state is an invalid key!")
    return false
end

Movable = Object:extend()
function Movable:new(optional_args)
    self.movement_type = {}
    for i,v in ipairs(optional_args) do
        -- adding movement abilities
        table.insert(self.movement_type, v)
    end
end

--[[
    NOTE: if something can move, it can attack.
    Moving against another entity = attacking it (groups prevent this movement).
    This also means that something can have a movable comp but no movement_type,
    and it can still attack - think of a living tree that can bash players with its
    branches but that cannot move around!
]]
function Movable:move_entity(owner, dir)
    -- destination, the target cell
    local destination
    -- target entity, the target cell eventual entity
    local entity
    -- necessary to check if adjacent cells are transversable when moving diagonally
    local adj_tiles = {}
    local row_mov = owner.cell["grid_row"] + dir[1]
    local col_mov = owner.cell["grid_col"] + dir[2]
    local succ_score = 7 -- score to succeed, throw need to be less or equal
    local succ_atk = false -- by default, not needed and set to false

    -- making sure that the comp owner isn't trying to move out of g.grid
    if col_mov > g.grid_x or col_mov <= 0 or row_mov > g.grid_y or row_mov <= 0 then
        destination = nil
        print("Trying to move out of g.grid boundaries")
        return false
    end

    -- if cell exists and is part of the g.grid, store it as destination
    destination = g.grid[owner.cell["grid_row"] + dir[1]][owner.cell["grid_col"] + dir[2]]
    -- store its eventual Entity for later reference
    entity = destination.entity

    -- checking for additional tiles to check, since diagonal mov requires entity
    -- to be able to traverse all of them!
    if dir[1] ~= 0 and dir[2] ~= 0 then
        -- since movement is diagonal, add to adj_tiles the adjacent tiles
        local adj_tile
        adj_tile = g.grid[owner.cell["grid_row"]][owner.cell["grid_col"] + dir[2]]
        table.insert(adj_tiles, TILES_PHYSICS[adj_tile.index])
        adj_tile = g.grid[owner.cell["grid_row"] + dir[1]][owner.cell["grid_col"]]
        table.insert(adj_tiles, TILES_PHYSICS[adj_tile.index])
    end

    -- now checking if tile feature is compatible with movement abilities
    table.insert(adj_tiles, TILES_PHYSICS[destination.index])
    for i, phys in ipairs(adj_tiles) do
        local can_traverse = false
        for i2, mov_type in ipairs(self.movement_type) do
            if MOV_TO_PHYS[mov_type] == phys or MOV_TO_PHYS[mov_type] == "wiggle" then
                can_traverse = true
                break
            end
        end
        -- if even one cell isn't compatible with Entity mov, Entity is blocked
        if not can_traverse then
            print("Incompatible tile terrain in path for entity")
            return false
        end 
    end

    -- check if owner movement is impeded by an obstacle Entity
    if entity and entity.comps["obstacle"] then
        print("Cell is blocked by obstacle: " .. entity.id)
        return false
    end

    -- checking for NPC/Player Entities. These always have precedence of interaction
    if destination.pawn then
        local pilot = owner.pilot
        local pawn = destination.pawn
        -- moving against an Entity = interaction. If part of different groups
        -- or of special 'self' group, the interaction results in an attack
        if pilot.group ~= "self" and pilot.group == pawn.pilot.group then
            print("Entity interacts with another Entity of the same group")
            return true
        end

        -- Player/Civilised interaction is always peaceful
        if pilot.group == "players" and pawn.pilot.nature == "civilized" then
            print("Player dialogues with civilized creature")
            -- this will actually lead to a dialogue func() that will return true/false
            return true
        end
        if pilot.group == "civilised" and pawn.pilot.nature == "player" then
            print("Player dialogues with civilized creature")
            -- this will actually lead to a dialogue func() that will return true/false
            return true
        end

        -- an enemy was found. Check if it has stats and can take damage
        if not pawn.comps["stats"] then
            print("Target entity has no Stats component")
            return false
        end

        local target_stats = pawn.comps["stats"].stats
        if not target_stats["hp"] then
            print("Target entity has no HP and cannot die")
            return false
        end

        -- if target is invisible, you need to roll a lower number
        if pawn.comps["invisible"] then
            print("Trying to hit invisible entity, success when: roll <= 4")
            succ_score = 4
        end

        -- dices get rolled to identify successful hit and eventual damage
        succ_atk = dice_roll("1d12+1", succ_score)
        
        if succ_atk then 
            love.audio.stop(SOUNDS["hit_blow"])
            love.audio.play(SOUNDS["hit_blow"])
            for power_tag, power_class in pairs(owner.powers) do
                power_class:activate(pawn)
            end
        else
            love.audio.play(SOUNDS["hit_miss"])
        end

        if target_stats["hp"] <= 0 then
            target_stats["hp"] = 0
            -- Entity will be removed from render_group and cell during refresh()
            pawn.alive = false
            -- if a player just died, save all deceased's relevant info in cemetery
            -- variable for recap in Game Over screen
            if pawn.comps["player"] then
                local deceased = {["player"] = pawn.name,
                ["killer"] = owner.name,
                ["loot"] = pawn.comps["stats"].stats["gold"],
                ["place"] = "Black Swamps"
                }
                table.insert(g.cemetery, deceased)
                -- send a 'game over' string to console in red color
                console_event(
                    deceased["player"] .. " got slain by " .. deceased["killer"], {[1] = 0.93, [2] = 0.18, [3] = 0.27}
                )
            end
        end

        return true
    end

    -- if no pawns are found in target cell, you're good to go
    owner.cell["cell"].pawn = nil -- freeing old cell
    owner.cell["grid_row"] = owner.cell["grid_row"] + dir[1]
    owner.cell["grid_col"] = owner.cell["grid_col"] + dir[2]
    owner.cell["cell"] = destination -- storing new cell
    owner.cell["cell"].pawn = owner -- occupying new cell
    
    -- playing sound based on tile type, check if valid to avoid crashes
    if SOUNDS[TILES_PHYSICS[destination.index]] then
        love.audio.stop(SOUNDS[TILES_PHYSICS[destination.index]])
        love.audio.play(SOUNDS[TILES_PHYSICS[destination.index]])
    else
        print("WARNING: destination has no related sound")
    end

    -- lastly, check if there's an item Entity in the new cell
    if not entity then
        return true
    end
    -- see if the Entity is an exit
    if entity.comps["exit"] then
        entity.comps["exit"]:activate(entity, owner)
        return true
    end

    -- see if Entity is has trigger component
    if entity.comps["trigger"] and entity.comps["trigger"].trig_on_coll then
        -- trigger may work or not, but Entity still moved, so return true
        entity.comps["trigger"]:activate(entity, owner)
        return true
    end

    -- if a non-reactive, non-NPC, non-Player, non-Obstacle Entity is in target cell
    -- simply ignore it anad return true for successful movement 
    return true
end

Npc = Object:extend()
function Npc:new(args)
    -- assigning important NPC variables thanks to an initial table
    local variables_group = {
        ["group"] = true,
        ["enemies"] = {},
        ["nature"] = true,
        ["sight"] = true,
        ["hearing"] = true
    }
    for i, var in ipairs(args) do
        local new_var = str_slicer(var, "=", 1)
        -- if it is a valid table variable, assign values to it
        if not variables_group[new_var[1]] then
            goto continue
        end
        -- "enemies" is the only 'array' variable 
        if new_var[1] == "enemies" then
            -- each enemy group will be stored in 'enemies'
            local enemies = str_slicer(new_var[2], "-", 1)

            for k, value in ipairs(enemies) do              
                table.insert(variables_group[new_var[1]], value)
            end
        else
            -- check if variable was improperly fed multiple values
            local sub_values = str_slicer(new_var[2], "-", 1)

            if sub_values[2] then
                error_handler(
                    "Trying to assign multiple values to NPC variable: " .. new_var[1],
                    'Only "enemies" variable can take multiple args, all but first arg ignored.'
                )
            end

            variables_group[new_var[1]] = sub_values[1]
        end
        ::continue::
    end

    self.group = variables_group["group"]
    self.enemies = variables_group["enemies"]
    self.nature = variables_group["nature"]
    self.sight = tonumber(variables_group["sight"])
    self.hearing = tonumber(variables_group["hearing"])
    self.target = false -- stores current locked target
end

function Npc:activate(owner)
    -- if NPC cannot move, skip turn
    if not owner.comps["movable"] then
        return false
    end

    -- choose path of action depending on nature
    return ai_behavior(owner, self)
end

Trap = Object:extend()
function Trap:new()
end

-- this is a 'flag' class for all the entities that are not Players but phisically
-- occupy entire cells and block other Entity movements (trees, boulders, doors...)
Obstacle = Object:extend()
function Obstacle:new()

end

-- this comp warns the game when an entity behaves in a trigger volume fashion
Trigger = Object:extend()
function Trigger:new(args)
    local string_to_bool = {
        ["false"] = false,
        ["true"] = true
    }
    self.destroyontrigger = string_to_bool[args[1]]
    self.trig_on_coll = string_to_bool[args[2]]
    self.event_string = args[3]
end

function Trigger:activate(owner, entity)  
    -- check if owner Entity has a dedicated power flagged as 'trigger'
    if owner.powers["trigger"] then
        owner.powers["trigger"]:activate(entity)
    else
        print("Blank trigger: a destroyontrigger Entity has no 'trigger' power to activate")
    end

    -- print trigger event string (i.e. 'A trap activates!')
    if self.event_string then
        console_event(entity.name .. " " .. self.event_string)
    end
    
    -- if owner is to 'destroyontrigger', destroy it
    if self.destroyontrigger then
        -- will be removed from render_group and cell during refresh()
        owner.alive = false
    end
end

-- Pickup is a 'flag' class, where its only utility is to let other Entities know
-- that owner Entity can be picked up
Pickup = Object:extend()
function Pickup:new()
end

-- Usable is a for all objects that can be somehow used and then trigger an event
Usable = Object:extend()
function Usable:new(args)
    local string_to_bool = {
        ["false"] = false,
        ["true"] = true
    }
    local key_power
    self.uses = {}
    self.destroyonuse = string_to_bool[args[1]]
    for i, arg in ipairs(args) do
        if i == 1 then
            self.destroyonuse = string_to_bool[arg]
            goto continue
        end

        key_power = str_slicer(arg, "=", 1)
        if not key_power then
            print("Warning: blank Usable component has no key-action couple")
            return false
        end
        self.uses[key_power[1]] = key_power[2]

        ::continue::
    end
end

-- to have simple 'use' working, have a power named 'use'
function Usable:activate(target, input_entity, input_key)
    local key = input_key or "use"
    local entity = input_entity

    -- trigger always hits activating Entity, even if linked comp is present
    if target.comps["trigger"] then
        target.comps["trigger"]:activate(target, entity)
    end

    -- if Entity is destroyontrigger, don't bother with rest of code
    if not target.alive then
        return false
    end

    if not self.uses[key] then
        console_event("Nothing doth happen")
    end

    if not target.powers[self.uses[key]] then
        error_handler(
            "Usable comp has valid key-power couple called, but no corresponding power"
        )

        return false
    end

    -- activate target power
    target.powers[self.uses[key]]:activate(target, entity)
    -- if destroyonuse, destroy used object (useful for consumables)
    if self.destroyonuse then
        target.alive = false
    end

    -- if self.uses[key] ~= 'linked', no need to proceed
    if self.uses[key] ~= "linked" then
        print("Power does not call for linked activation")
        return true
    end
    
    -- search for linked comp and store eventual linked Entity
    if target.comps["linked"] then
        print("Linked component was found")
        local row, col = target.comps["linked"]:activate(target)
        row = tonumber(row)
        col = tonumber(col)
        -- check immediately for NPC/Player
        entity = g.grid[row][col] and g.grid[row][col].pawn or false
        -- if absent, check for Entity
        if not entity then entity = g.grid[row][col].entity or false end
    else
        -- no linked component, return true
        return true
    end

    -- if linked but Entity is missing in cell, nothing happened and return true
    if not entity then
        console_event("The target is absent")

        return true
    end

    if not entity.powers["linked"] then
        print("WARNING: linked Entity has no dedicated 'linked' power")

        return true
    end

    -- at this point we know everything is in check, proceed
    entity.powers["linked"]:activate(entity)

    return true
end

-- simple class used only to jump between levels or from game to menu (game end)
Exit = Object:extend()
function Exit:new(args)
    -- string to print on level change
    self.event_string = args[1]
end

function Exit:activate(owner, entity)
    console_event(self.event_string)
    if entity.comps["player"] then
        -- the entity's name indicates the level to load
        if owner.name ~= "menu" then
            g.game_state:exit()
            print("Exit id: "..owner.id)
            print("Level name: "..owner.name)
            g.game_state:init(owner.name, false)
        else
            g.game_state = StateMenu()
            g.game_state:init()
        end
    end
end

--[[
    container class to store all the entity's stats. NPCs need this comp or they
    won't have hp (this translates to them being immortal).
    If a Player doesn't have it, the system adds it with hp = 1, gold = 0
]]--
Stats = Object:extend()
function Stats:new(stats_table)
    self.stats = {}
    for i, stat in ipairs(stats_table) do
        local new_stat = str_slicer(stat, "=", 1)
        -- automatically convert numerical stats to numbers
        if new_stat[2]:match("%d") then
            new_stat[2] = tonumber(new_stat[2])
        end
        -- code below translates as "self.stats[stat_name] = stat_value"
        self.stats[new_stat[1]] = new_stat[2]
    end
end

-- this component stores resistances and immunity to effects
Profile = Object:extend()
function Profile:new(input_table)
    self.profile = {}
    for i, stat in ipairs(input_table) do
        local new_stat = str_slicer(stat, "=", 1)
        -- automatically convert numerical stats to numbers
        if new_stat[2]:match("%d") then
            new_stat[2] = tonumber(new_stat[2])
        end
        -- code below translates as "self.profile[stat_name] = stat_value"
        self.profile[new_stat[1]] = new_stat[2]
    end
end

-- for all entities that are invisible by default (i.e. traps, invisible creatures)
-- simple 'tag' component telling system 'do not draw me by default'
Invisible = Object:extend()
function Invisible:new()
end

--[[
    Simple component that stores a key and removes 'locked' component from an Entity
    with corresponding name, i.e. if name = door_a45, remove 'locked' from Entity
    with name = door_a45. Can also used to activate golems, unlock quests, etc.
]]--
Key = Object:extend()
function Key:new()
end

-- for all Entities that can store items (i.e. Players, NPCs, chests, libraries...)
Inventory = Object:extend()
function Inventory:new(arg)
    self.items = {}
    self.spaces = 0 -- available spaces
    self.capacity = 0 -- max number of spaces

    -- setting Inventory's capacity as n of Entities
    if not arg[1] or tonumber(arg[1]) > 26 then
        error_handler("Inventory comp has number of spaces > 26 or none, set to 26")
        self.spaces = tonumber(arg[1])
        self.capacity = tonumber(arg[1])
    else
        self.spaces = tonumber(arg[1])
        self.capacity = tonumber(arg[1])
    end
end

function Inventory:add(item)
    if self.spaces > 0 then
        local item_ref = item.name

        if item.comps["description"] then
            item_ref = item.comps["description"].string
        end

        if item.comps["secret"] then
            item_ref = item.comps["secret"].string
        end

        self.spaces = self.spaces - 1
        table.insert(self.items, item)
        console_event("Thee pick up " .. item_ref)
        item.alive = false

        return true
    else
        console_event("Thy inventory is full")

        return false
    end
end

-- removes item from inventory by coupling item_key letter with
-- its indexed position inside self.items
function Inventory:remove(item_key)
    local inv_str = "abcdefghijklmnopqrstuvwxyz"

    for i = 1, string.len(inv_str) do
        if string.sub(inv_str, i, i) == item_key then
            table.remove(self.items, i)
            print("Removing object from inventory...")

            return true
        end
    end
end

-- for all Entities that can equip Equipable Entities, matches Equipable comp tags
-- with own tags (i.e. Equipable on: horns works with Slots : horns)
Slots = Object:extend()
function Slots:new(args)
    -- slot is available if == true and ~= Entity
    self.slots = {}
    for _,slot in ipairs(args) do
        -- adding all input slots from args (true = available)
        self.slots[slot] = "empty"
    end
end

--[[
    For all Entities that can be equipped (i.e. rings, amulets, crowns...),
    that need to know in which slot they can fit (i.e. head, hand, tentacle...).
    Multiple suitable slots can be accepted (i.e. right hand, left hand...).
    Also note that once equipped, objects will trigger and/or apply effects.
    The last simply artificially changes Player's characteristics.
]]
Equipable = Object:extend()
function Equipable:new(args)
    local string_to_bool = {
        ["false"] = false,
        ["true"] = true
    }
    -- cursed objects cannot be normally unequipped
    self.cursed = string_to_bool[args[1]]
    self.suitable_slots = {}
    self.slot_reference = false
    -- now remove first arg, as it becomes useless
    table.remove(args, 1)

    for i, slot in ipairs(args) do
        -- adding all compatible slots for an Equipable
        table.insert(self.suitable_slots, slot)
    end
end

function Equipable:equip(owner, target)
    target.tile = self.appearance

    if not owner.powers["equip"] then
        print("Warning: trying to activate equip power, but none is found")
        return false
    end

    owner.powers["equip"]:activate(target)
    return true
end

function Equipable:unequip(owner, target)
    -- check if owner is cursed and cannot be removed. If so, reveal item
    if owner.comps["equipable"].cursed then
        console_event("Thy item is cursed and may not be removed!", {0.6, 0.2, 1})

        -- reveal Entity real description
        if owner.comps["secret"] then
            owner.comps["secret"] = nil
        end

        return false
    end

    if not owner.powers["unequip"] then
        print("Warning: trying to activate unequip power, but none is found")
        return false
    end

    owner.powers["unequip"]:activate(target)
    return true
end

-- same as 'locked', but requires 'say' interaction to unlock
Sealed = Object:extend()
function Sealed:new(input)

end

function Sealed:activate(target, entity, player_comp)
    if target.name == player_comp.string then
        console_event("Thou dost unseal it!")
        if target.comps["trigger"] then
            target.comps["trigger"]:activate(target, entity)
        end

        -- if Entity gets successfully unsealed, remove 'seled' comp
        target.comps["sealed"] = nil
        player_comp.string = ""
        return true
    end

    console_event("There is no response")

    return false
end

-- when is requested to unlock from console, searches in requester inventory for an
-- Entity with a 'key' comp with corresponding name.
-- As the 'key' component, name = Entity.name
Locked = Object:extend()
function Locked:new(input)

end

function Locked:activate(target, entity)
    if entity.comps["inventory"] then
        for _, item in ipairs(entity.comps["inventory"].items) do
            if item.comps["key"] and item.name == target.name then
                console_event("Thou dost unlock it!")
                if target.comps["trigger"] then
                    target.comps["trigger"]:activate(target, entity)
                end

                -- if Entity was successfully unlocked, remove 'Locked' comp
                target.comps["locked"] = nil
                return true
            end
        end
        console_event("Thou dost miss the key")
        
        return true
    end
    error_handler("Entity without invetory is trying to use key to unlock")
    return false
end

-- simple comp that prevents acces to Entity name, id or description
-- can only removed by effect 
Secret = Object:extend()
function Secret:new(input)
    self.string = input[1]
end

Description = Object:extend()
function Description:new(input)
    self.string = input[1]
end

-- linked Entities will activate other Entities in specific row, column
-- position of other Entities is defined by linked Entity name that
-- indicates the cell to search for
Linked = Object:extend()
function Linked:new(input)

end

-- note how changing the Entity's name will change its cell of interest
function Linked:activate(owner)
    local row_column = str_slicer(owner.name, "-", 1)
    local row = row_column[1]
    local column = row_column[2]

    return row, column
end

-- shooter Entities will consume ammo and use their properties to establish effects
-- and type of damage. Actual damage is established by shooter Entity.
Shooter = Object:extend()
function Shooter:new(args)
    -- amount of ammo consumed per use
    self.consume = tonumber(args[1])
    -- types of compatible ammo
    self.compatible = {}

    -- remove first arg, as it is now useless
    table.remove(args, 1)

    -- TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO TO DO 
    -- this check needs to be done when going to shoot, or it will require ordered blueprints (unacceptable)
    for _, ammo_type in ipairs(args) do
        --[[
        -- checking if ammo_type is a valid Entity BP id or not
        if not BP_LIST[ammo_type] then
            error_handler(
                "Assigning to shooter Entity invalid ammo_type with id " .. ammo_type
            )

            return false
        end
        ]]--
        print(ammo_type)

        -- adding all compatible ammo types
        table.insert(self.compatible, ammo_type)
    end
end

-- stack Entities will look for same id Entities each time they are moved in cell or
-- picked up (even if equipped). Stack number corresponds to stat = hp.
Stack = Object:extend()
function Stack:new(args)

end
