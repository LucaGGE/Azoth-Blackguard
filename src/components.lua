--[[
    Implemented components. NOTE: some will be checked for when a blueprint is
    created (i.e. npc, player), as they will be added to special groups, needed to
    avoid searching for specific components each time an event is fired (i.e. when
    Player gives input, or the Player position).
]]

-- note this is NOT found in BLUEPRINTS_TABLE, as it is restricted to the game menu
Player = Object:extend()
function Player:new()
    -- players are automatically part of this group
    self.group = "players"
    self.action_state = nil
    self.valid_input = "qwertyuiopasdfghjklzxcvbnmspace"
    self.string = "" -- stores player input for all action_modes
    self.turns = 0 -- useful to keep track of for hunger and HP regen
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
    return player_manage_input(entity, key, self)
end

Movable = Object:extend()
function Movable:new(args)
    self.mov_type = {}

    for _, mov in pairs(args) do
        -- adding movement abilities as: mov_ability = true
        self.mov_type[mov] = true
    end
end

--[[
    NOTE: if something can move, it can attack.
    Moving against another entity = attacking it (groups prevent this movement).
    This also means that something can have a movable comp but no mov_type,
    and it can still attack - think of a living tree that can bash players with its
    branches but that cannot move around!
]]
function Movable:move_entity(owner, dir)
    return movable_move_entity(owner, dir, self)
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
    return npc_activate(owner, self)
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
    self.fire_once = string_to_bool[args[2]]
    self.trig_on_coll = string_to_bool[args[3]]
    self.event = args[4]
end

function Trigger:activate(owner, target, activator)
    return trigger_activate(owner, target, activator, self)
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

-- to have a simple 'use' input working, have a power named 'use'
function Usable:activate(target, input_entity, input_key)
    return usable_activate(target, input_entity, input_key, self)
end

-- simple class used only to jump between levels or from game to menu (game end)
Exit = Object:extend()
function Exit:new(args)
    -- string to print on level change
    self.event_string = args[1]
end

function Exit:activate(owner, entity)
    return exit_activate(owner, entity, self)
end

--[[
    Container class to store all the entity's stats. NPCs need this comp or they
    won't have hp (this translates to them being immortal).
    If a Player doesn't have it, the system adds it with hp = 1, gold = 0
]]--
Stats = Object:extend()
function Stats:new(stats_table)
    self.stat = {}

    local funcs = {
        ["die_set"] = function(input)
            return input
        end,
        ["generate_k"] = function (input)
            return dice_roll(input)
        end
    }

    local STAT_DTABLE = {
        ["hp"] = funcs["generate_k"],
        ["maxhp"] = funcs["generate_k"],
        ["dmg"] = funcs["die_set"],
        ["mana"] = funcs["generate_k"],
        ["gold"] = funcs["generate_k"],
        ["hunger"] = funcs["generate_k"]
    }

    for i, stat in ipairs(stats_table) do
        local stat_input = str_slicer(stat, "=", 1)
        local stat_name = stat_input[1]
        
        -- check if stat is a valid stat
        if STAT_DTABLE[stat_name] then
            local stat_value

            -- convert and store constant numerical stats to numbers
            if stat_input[2]:match("%d") then
                stat_value = tonumber(stat_input[2])
            end

            -- store as constant or dice depending if value was already assigned
            stat_value = stat_value or STAT_DTABLE[stat_name](stat_input[2])
            self.stat[stat_name] = stat_value
        else
            error_handler("WARNING: trying to assign invalid stat: " .. stat_name)
        end
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
    return inventory_add(item, self)
end

-- removes item from inventory by coupling item_key letter with
-- its indexed position inside self.items
function Inventory:remove(item_key)
    return inventory_remove(item_key, self)
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
    return equipable_equip(owner, target)
end

function Equipable:unequip(owner, target)
    return equipable_unequip(owner, target)
end

-- same as 'locked', but requires 'say' interaction to unlock
Sealed = Object:extend()
function Sealed:new(input)

end

function Sealed:activate(target, entity, player_comp)
    return sealed_activate(target, entity, player_comp)
end

-- when is requested to unlock from console, searches in requester inventory for an
-- Entity with a 'key' comp with corresponding name.
-- As the 'key' component, name = Entity.name
Locked = Object:extend()
function Locked:new(input)

end

function Locked:activate(owner, entity)
    return locked_activate(owner, entity)
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

-- note how changing the Entity's name will change its cell of interest,
-- since the Entity's name correspond to row, col coordinates
function Linked:activate(owner)
    return linked_activate(owner)
end

-- shooter Entities will consume ammo and use their properties to establish effects
-- and type of damage. Actual damage is established by shooter Entity.
Shooter = Object:extend()
function Shooter:new(args)
    -- amount of ammo consumed per use
    self.shots = tonumber(args[1])
    -- types of compatible ammo
    self.munitions = {}

    -- remove first arg, as it is now useless
    table.remove(args, 1)

    -- adding all compatible ammo types (will check if their id is valid on loose)
    for _, ammo_type in ipairs(args) do
        table.insert(self.munitions, ammo_type)
    end
end

-- stack Entities will look for same id Entities each time they are moved in cell or
-- picked up (even if equipped). Stack number corresponds to stat = hp.
Stack = Object:extend()
function Stack:new(args)

end