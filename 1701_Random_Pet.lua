--[[
  1701 Random Pet - Random Companion Pet Selector for WoW 1.12 / Turtle WoW
  Version 1.4.0

  Usage: /pet [filter|groupname|command]

  Commands:
    /pet                      - Random pet from all available
    /pet <filter>             - Random pet matching filter
    /pet <groupname>          - Random pet from group

    /pet exclude <filter>     - Exclude matching pets
    /pet unexclude <filter>   - Remove from exclusions
    /pet excludelist          - Show excluded pets

    /pet group add <n> <f>    - Add matching pets to group
    /pet group remove <n> <f> - Remove from group
    /pet group list <name>    - Show pets in group
    /pet groups               - List all groups

    /pet debug                - Show detected pets

  Notes:
    - Shift-click spell links are supported (e.g., /pet exclude [Pet Name])
    - Comma-separated lists are supported (e.g., /pet exclude cat, whelp, frog)
    - Exact match (e.g., /pet "Azure Whelpling") bypasses exclusions
    - Groups ignore exclusions entirely
    - Uses 1701_Lib.lua shared library
]]

RandomPet1701 = {}

-- Known companion pet item names (partial matches supported)
-- This list covers vanilla WoW companion pets
local PET_PATTERNS = {
    -- Cats
    "Cat Carrier",
    "Black Tabby",
    "Bombay",
    "Cornish Rex",
    "Orange Tabby",
    "Silver Tabby",
    "Siamese",
    "White Kitten",

    -- Birds
    "Parrot Cage",
    "Cockatiel",
    "Green Wing Macaw",
    "Hyacinth Macaw",
    "Senegal",
    "Ancona Chicken",
    "Chicken Egg",
    "Westfall Chicken",
    "Prairie Chicken",
    "Owl",
    "Great Horned Owl",
    "Hawk Owl",

    -- Snakes
    "Black Kingsnake",
    "Brown Snake",
    "Crimson Snake",

    -- Rabbits and Hares
    "Rabbit Crate",
    "Snowshoe Rabbit",
    "Spring Rabbit",

    -- Frogs and Toads
    "Wood Frog",
    "Tree Frog",
    "Jubling",
    "Mojo",

    -- Mechanical Pets
    "Mechanical Chicken",
    "Mechanical Squirrel",
    "Pet Bombling",
    "Lil' Smoky",
    "Lifelike Mechanical Toad",
    "Tranquil Mechanical Yeti",

    -- Dragonlings and Whelplings
    "Whelpling",
    "Azure Whelpling",
    "Crimson Whelpling",
    "Dark Whelpling",
    "Emerald Whelpling",
    "Tiny Crimson Whelpling",
    "Tiny Emerald Whelpling",
    "Sprite Darter",
    "Sprite Darter Egg",

    -- Dogs
    "Pug",
    "Worg Pup",
    "Worg Carrier",

    -- Insects and Spiders
    "Firefly",
    "Tree Frog Box",
    "Cockroach",
    "Spider",

    -- Undead Pets
    "Undead Minipet",
    "Ghostly Skull",
    "Haunted Memento",

    -- Rodents
    "Rat",
    "Prairie Dog",
    "Squirrel",
    "Tiny Snowman",

    -- Aquatic
    "Fishing Raft",
    "Magical Crawdad",
    "Sea Turtle",
    "Mr. Pinchy",

    -- Holiday Pets
    "Snowman Kit",
    "Jingling Bell",
    "Father Winter's Helper",
    "Winter Reindeer",
    "Pint-Sized Pink Pachyderm",
    "Romantic Picnic Basket",
    "Love Bird",
    "Truesilver Shafted Arrow",

    -- Faction Pets
    "Argent Dawn",
    "Argent Squire",
    "Argent Gruntling",

    -- Vendor/Quest Pets
    "Tiny Snowman",
    "Captured Firefly",
    "Disgusting Oozeling",
    "Murky",
    "Lurky",
    "Terky",
    "Gurky",
    "Murloc Egg",

    -- Rare/World Drop Pets
    "Panda Cub",
    "Mini Diablo",
    "Zergling",
    "Spirit of Competition",

    -- ZG Pets
    "Hakkari",

    -- Onyxia
    "Onyxian Whelpling",

    -- Raid Pets
    "Chrominius",
    "Mini Mindslayer",
    "Anubisath Idol",
    "Viscidus Globule",

    -- Turtle WoW / Private Server Pets
    "Pet",
    "Companion",
    "Minipet",
    "Mini-pet",

    -- Generic patterns to catch variations
    "Carrier",
    "Cage",
    "Crate",
    "Box",
    "Egg",
}

-- Check if an item name matches pet patterns
local function IsPetItem(itemName)
    if not itemName then return false end

    local lowerName = string.lower(itemName)

    -- Check for common pet keywords
    if string.find(lowerName, "companion") or
       string.find(lowerName, "minipet") or
       string.find(lowerName, "mini%-pet") or
       string.find(lowerName, "whelpling") or
       string.find(lowerName, "carrier") or
       string.find(lowerName, "cage") or
       string.find(lowerName, "crate") then
        return true
    end

    -- Check against known pet patterns
    for _, pattern in ipairs(PET_PATTERNS) do
        if string.find(lowerName, string.lower(pattern)) then
            return true
        end
    end

    return false
end

-- Check if pet should be included based on filter and exclusions
-- Must be defined before GetAllPets which uses it
local function ShouldIncludePet(petName, filter, skipExclusions)
    -- Exact match bypasses exclusions
    if Lib1701.IsExactMatch(petName, filter) then
        return true
    end

    -- Check exclusions (unless skipped)
    if not skipExclusions and Lib1701.IsExcluded(RandomPet1701_Data.exclusions, petName) then
        return false
    end

    -- Apply filter
    return Lib1701.MatchesFilter(petName, filter)
end

-- Scan bags for pet items
local function GetBagPets(filter)
    local pets = {}

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                -- Extract item name from link
                local _, _, itemName = string.find(itemLink, "%[(.+)%]")
                if itemName and IsPetItem(itemName) then
                    table.insert(pets, {
                        type = "item",
                        name = itemName,
                        bag = bag,
                        slot = slot
                    })
                end
            end
        end
    end

    return pets
end

-- Get pets from ZzCompanions spellbook tab
local function GetSpellPets()
    local pets = {}

    -- Find the ZzCompanions tab
    local numTabs = GetNumSpellTabs()
    for tab = 1, numTabs do
        local name, texture, offset, numSpells = GetSpellTabInfo(tab)
        if name == "ZzCompanions" then
            for i = 1, numSpells do
                local spellIndex = offset + i
                local spellName = GetSpellName(spellIndex, BOOKTYPE_SPELL)
                if spellName then
                    table.insert(pets, {
                        type = "spell",
                        name = spellName,
                        spellIndex = spellIndex
                    })
                end
            end
            break
        end
    end

    return pets
end

-- Get all available pets
local function GetAllPets(filter, skipExclusions)
    local allPets = {}

    -- Get bag pets
    local bagPets = GetBagPets(nil)  -- Get all, filter later
    for _, pet in ipairs(bagPets) do
        if ShouldIncludePet(pet.name, filter, skipExclusions) then
            table.insert(allPets, pet)
        end
    end

    -- Get spell pets
    local spellPets = GetSpellPets(nil)  -- Get all, filter later
    for _, pet in ipairs(spellPets) do
        if ShouldIncludePet(pet.name, filter, skipExclusions) then
            table.insert(allPets, pet)
        end
    end

    return allPets
end

-- Get all pet names for Lib1701 functions
local function GetAllPetNames()
    local pets = GetAllPets(nil, true)  -- Skip exclusions to see all available pets
    local names = {}
    for _, pet in ipairs(pets) do
        table.insert(names, { name = pet.name })
    end
    return names
end

-- Message prefix
local MSG_PREFIX = "1701_Random_Pet"

-- Handle /pet exclude <filter> (supports comma-separated lists and spell links)
local function DoExclude(input)
    if not input or input == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet exclude <filter|[link]>, ...")
        return
    end

    local filters = Lib1701.ParseInputList(input)
    if table.getn(filters) == 0 then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet exclude <filter|[link]>, ...")
        return
    end

    local allAdded = {}
    local allAlreadyExcluded = {}
    local notFound = {}

    for _, filter in ipairs(filters) do
        local added, alreadyExcluded = Lib1701.AddExclusions(
            RandomPet1701_Data.exclusions,
            filter,
            GetAllPetNames
        )

        for _, name in ipairs(added) do
            table.insert(allAdded, name)
        end
        for _, name in ipairs(alreadyExcluded) do
            table.insert(allAlreadyExcluded, name)
        end
        if table.getn(added) == 0 and table.getn(alreadyExcluded) == 0 then
            table.insert(notFound, filter)
        end
    end

    if table.getn(allAdded) > 0 then
        Lib1701.Message(MSG_PREFIX, "Excluded: " .. table.concat(allAdded, ", ") .. " (" .. table.getn(allAdded) .. " pets)")
    end
    if table.getn(allAlreadyExcluded) > 0 then
        Lib1701.Message(MSG_PREFIX, "Already excluded: " .. table.concat(allAlreadyExcluded, ", "))
    end
    if table.getn(notFound) > 0 then
        Lib1701.Message(MSG_PREFIX, "No pets found matching: " .. table.concat(notFound, ", "))
    end
end

-- Handle /pet unexclude <filter> (supports comma-separated lists and spell links)
local function DoUnexclude(input)
    if not input or input == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet unexclude <filter|[link]>, ...")
        return
    end

    local filters = Lib1701.ParseInputList(input)
    if table.getn(filters) == 0 then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet unexclude <filter|[link]>, ...")
        return
    end

    local allRemoved = {}
    local allNotFound = {}

    for _, filter in ipairs(filters) do
        local removed = Lib1701.RemoveExclusions(
            RandomPet1701_Data.exclusions,
            filter
        )

        for _, name in ipairs(removed) do
            table.insert(allRemoved, name)
        end
        if table.getn(removed) == 0 then
            table.insert(allNotFound, filter)
        end
    end

    if table.getn(allRemoved) > 0 then
        Lib1701.Message(MSG_PREFIX, "Unexcluded: " .. table.concat(allRemoved, ", ") .. " (" .. table.getn(allRemoved) .. " pets)")
    end
    if table.getn(allNotFound) > 0 then
        Lib1701.Message(MSG_PREFIX, "No excluded pets found matching: " .. table.concat(allNotFound, ", "))
    end
end

-- Handle /pet excludelist
local function DoExcludeList()
    local exclusions = RandomPet1701_Data.exclusions
    if table.getn(exclusions) == 0 then
        Lib1701.Message(MSG_PREFIX, "No pets excluded")
        return
    end

    Lib1701.Message(MSG_PREFIX, "Excluded pets (" .. table.getn(exclusions) .. "):")
    for _, name in ipairs(exclusions) do
        DEFAULT_CHAT_FRAME:AddMessage("  - " .. name)
    end
end

-- Reserved command names (cannot be used as group names)
local RESERVED_COMMANDS = {
    debug = true,
    exclude = true,
    unexclude = true,
    excludelist = true,
    group = true,
    groups = true,
}

-- Handle /pet group add <name> <filter> (supports comma-separated lists and spell links)
local function DoGroupAdd(groupName, input)
    if not groupName or groupName == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group add <groupname> <filter|[link]>, ...")
        return
    end

    -- Validate group name format
    local isValid, errMsg = Lib1701.IsValidGroupName(groupName)
    if not isValid then
        Lib1701.Message(MSG_PREFIX, errMsg)
        return
    end

    if RESERVED_COMMANDS[string.lower(groupName)] then
        Lib1701.Message(MSG_PREFIX, "Cannot use reserved name '" .. groupName .. "' as group name")
        return
    end

    if not input or input == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group add <groupname> <filter|[link]>, ...")
        return
    end

    local filters = Lib1701.ParseInputList(input)
    if table.getn(filters) == 0 then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group add <groupname> <filter|[link]>, ...")
        return
    end

    local allAdded = {}
    local allSkipped = {}
    local notFound = {}
    local groupCreated = false

    for _, filter in ipairs(filters) do
        local added, skipped, isNewGroup = Lib1701.AddToGroup(
            RandomPet1701_Data.groups,
            groupName,
            filter,
            GetAllPetNames,
            RandomPet1701_Data.exclusions
        )

        if isNewGroup then
            groupCreated = true
        end

        for _, name in ipairs(added) do
            table.insert(allAdded, name)
        end
        for _, name in ipairs(skipped) do
            table.insert(allSkipped, name)
        end
        if table.getn(added) == 0 and table.getn(skipped) == 0 then
            table.insert(notFound, filter)
        end
    end

    local msg = ""
    if groupCreated then
        msg = "Created group '" .. groupName .. "': "
    else
        msg = "Added to '" .. groupName .. "': "
    end

    if table.getn(allAdded) > 0 then
        msg = msg .. table.concat(allAdded, ", ") .. " (" .. table.getn(allAdded) .. " pets"
        if table.getn(allSkipped) > 0 then
            msg = msg .. ", skipped " .. table.getn(allSkipped) .. " excluded"
        end
        msg = msg .. ")"
        Lib1701.Message(MSG_PREFIX, msg)
    elseif table.getn(allSkipped) > 0 then
        Lib1701.Message(MSG_PREFIX, "All matching pets are excluded (" .. table.getn(allSkipped) .. " skipped)")
    end
    if table.getn(notFound) > 0 then
        Lib1701.Message(MSG_PREFIX, "No pets found matching: " .. table.concat(notFound, ", "))
    end
end

-- Handle /pet group remove <name> <filter> (supports comma-separated lists and spell links)
local function DoGroupRemove(groupName, input)
    if not groupName or groupName == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group remove <groupname> <filter|[link]>, ...")
        return
    end

    -- Validate group name format
    local isValid, errMsg = Lib1701.IsValidGroupName(groupName)
    if not isValid then
        Lib1701.Message(MSG_PREFIX, errMsg)
        return
    end

    if not input or input == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group remove <groupname> <filter|[link]>, ...")
        return
    end

    local filters = Lib1701.ParseInputList(input)
    if table.getn(filters) == 0 then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group remove <groupname> <filter|[link]>, ...")
        return
    end

    -- Check if group exists first
    local members = Lib1701.GetGroup(RandomPet1701_Data.groups, groupName)
    if not members then
        Lib1701.Message(MSG_PREFIX, "Group '" .. groupName .. "' not found")
        return
    end

    local allRemoved = {}
    local notFound = {}
    local wasDeleted = false

    for _, filter in ipairs(filters) do
        local removed, groupDeleted = Lib1701.RemoveFromGroup(
            RandomPet1701_Data.groups,
            groupName,
            filter
        )

        if groupDeleted then
            wasDeleted = true
        end

        for _, name in ipairs(removed) do
            table.insert(allRemoved, name)
        end
        if table.getn(removed) == 0 then
            table.insert(notFound, filter)
        end
    end

    if table.getn(allRemoved) > 0 then
        local msg = "Removed from '" .. groupName .. "': " .. table.concat(allRemoved, ", ")
        if wasDeleted then
            msg = msg .. " (group deleted)"
        end
        Lib1701.Message(MSG_PREFIX, msg)
    end
    if table.getn(notFound) > 0 and not wasDeleted then
        Lib1701.Message(MSG_PREFIX, "No pets in '" .. groupName .. "' matching: " .. table.concat(notFound, ", "))
    end
end

-- Handle /pet group list <name>
local function DoGroupList(groupName)
    if not groupName or groupName == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group list <groupname>")
        return
    end

    -- Validate group name format
    local isValid, errMsg = Lib1701.IsValidGroupName(groupName)
    if not isValid then
        Lib1701.Message(MSG_PREFIX, errMsg)
        return
    end

    local members, storedName = Lib1701.GetGroup(RandomPet1701_Data.groups, groupName)
    if not members then
        Lib1701.Message(MSG_PREFIX, "Group '" .. groupName .. "' not found")
        return
    end

    Lib1701.Message(MSG_PREFIX, "Group '" .. storedName .. "' (" .. table.getn(members) .. " pets):")
    for _, name in ipairs(members) do
        DEFAULT_CHAT_FRAME:AddMessage("  - " .. name)
    end
end

-- Handle /pet groups
local function DoGroupsList()
    local groups = RandomPet1701_Data.groups
    local count = 0
    for _ in pairs(groups) do
        count = count + 1
    end

    if count == 0 then
        Lib1701.Message(MSG_PREFIX, "No groups defined")
        return
    end

    Lib1701.Message(MSG_PREFIX, "Pet groups (" .. count .. "):")
    for name, members in pairs(groups) do
        DEFAULT_CHAT_FRAME:AddMessage("  - " .. name .. " (" .. table.getn(members) .. " pets)")
    end
end

-- Use a pet
local function UsePet(pet)
    if pet.type == "item" then
        UseContainerItem(pet.bag, pet.slot)
    elseif pet.type == "spell" then
        CastSpell(pet.spellIndex, BOOKTYPE_SPELL)
    end
end

-- Main pet function
local function DoRandomPet(filter, skipExclusions)
    -- Trim whitespace from filter
    if filter then
        filter = string.gsub(filter, "^%s*(.-)%s*$", "%1")
        if filter == "" then
            filter = nil
        end
    end

    local pets = GetAllPets(filter, skipExclusions)

    if table.getn(pets) == 0 then
        if filter then
            Lib1701.Message(MSG_PREFIX, "No pets found matching '" .. filter .. "'")
        else
            Lib1701.Message(MSG_PREFIX, "No pets found in your bags or spellbook.")
        end
        return
    end

    -- Pick a random pet
    local pet = pets[math.random(1, table.getn(pets))]
    UsePet(pet)
end

-- Select random pet from a group
local function DoGroupPet(groupName)
    local members = Lib1701.GetGroup(RandomPet1701_Data.groups, groupName)
    if not members or table.getn(members) == 0 then
        Lib1701.Message(MSG_PREFIX, "Group '" .. groupName .. "' is empty or not found")
        return
    end

    -- Pick random name from group
    local petName = members[math.random(1, table.getn(members))]

    -- Find the pet by exact name (skip exclusions for groups)
    local pets = GetAllPets(petName, true)

    -- Filter to exact match
    local exactPet = nil
    for _, pet in ipairs(pets) do
        if string.lower(pet.name) == string.lower(petName) then
            exactPet = pet
            break
        end
    end

    if exactPet then
        UsePet(exactPet)
    else
        Lib1701.Message(MSG_PREFIX, "Pet '" .. petName .. "' not found (may no longer be available)")
    end
end

-- Debug function to show detected pets and spellbook contents
local function DoDebug()
    Lib1701.Message(MSG_PREFIX, "Debug: Scanning...")

    -- Show spell tab info
    local numTabs = GetNumSpellTabs()
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF00FFSpellbook Tabs (" .. numTabs .. "):|r")
    for tab = 1, numTabs do
        local name, texture, offset, numSpells = GetSpellTabInfo(tab)
        DEFAULT_CHAT_FRAME:AddMessage("  Tab " .. tab .. ": " .. (name or "?") .. " (offset=" .. offset .. ", count=" .. numSpells .. ")")
    end

    -- Show detected pets
    local pets = GetAllPets(nil)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00Detected Pets (" .. table.getn(pets) .. "):|r")
    for _, pet in ipairs(pets) do
        DEFAULT_CHAT_FRAME:AddMessage("  [" .. pet.type .. "] " .. pet.name)
    end

    -- Scan bags for potential pets
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Scanning bags for pet-like items:|r")
    local bagCount = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local _, _, itemName = string.find(itemLink, "%[(.+)%]")
                if itemName then
                    local lowerName = string.lower(itemName)
                    local looksLikePet = IsPetItem(itemName) or
                        string.find(lowerName, "pet") or
                        string.find(lowerName, "companion") or
                        string.find(lowerName, "whelp") or
                        string.find(lowerName, "cat") or
                        string.find(lowerName, "parrot") or
                        string.find(lowerName, "frog") or
                        string.find(lowerName, "snake") or
                        string.find(lowerName, "rabbit") or
                        string.find(lowerName, "turtle") or
                        string.find(lowerName, "murloc")

                    if looksLikePet then
                        bagCount = bagCount + 1
                        local detected = IsPetItem(itemName) and " |cFF00FF00[DETECTED]|r" or " |cFFFF0000[MISSED]|r"
                        DEFAULT_CHAT_FRAME:AddMessage("  Bag " .. bag .. " Slot " .. slot .. ": " .. itemName .. detected)
                    end
                end
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("Pet-like items in bags: " .. bagCount)
end

-- Slash command handler
local function SlashCmdHandler(msg)
    -- Trim whitespace
    if msg then
        msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
    end

    if not msg or msg == "" then
        DoRandomPet(nil)
        return
    end

    -- Parse first word as command
    local _, _, cmd, rest = string.find(msg, "^(%S+)%s*(.*)")
    cmd = string.lower(cmd or "")
    rest = rest or ""

    -- Handle commands
    if cmd == "debug" then
        DoDebug()
    elseif cmd == "exclude" then
        DoExclude(rest)
    elseif cmd == "unexclude" then
        DoUnexclude(rest)
    elseif cmd == "excludelist" then
        DoExcludeList()
    elseif cmd == "groups" then
        DoGroupsList()
    elseif cmd == "group" then
        -- Parse subcommand: add/remove/list
        local _, _, subcmd, groupName, filter = string.find(rest, "^(%S+)%s+(%S+)%s*(.*)")
        subcmd = string.lower(subcmd or "")

        if subcmd == "add" then
            DoGroupAdd(groupName, filter)
        elseif subcmd == "remove" then
            DoGroupRemove(groupName, filter)
        elseif subcmd == "list" then
            DoGroupList(groupName)
        else
            Lib1701.Message(MSG_PREFIX, "Usage: /pet group <add|remove|list> <groupname> [filter]")
        end
    else
        -- Check if it's a group name
        local members = Lib1701.GetGroup(RandomPet1701_Data.groups, cmd)
        if members then
            DoGroupPet(cmd)
        else
            -- Treat as filter
            DoRandomPet(msg)
        end
    end
end

-- Default exclusions (utility companions that shouldn't be randomly summoned)
local DEFAULT_EXCLUSIONS = {
    "Mechanical Auctioneer",
    "Field Repair Bot 75B",
    "Caravan Kodo",
    "Forworn Mule",
    "Famous Fashionista Glitterglam",
    "Squire Boltfling",
    "Caretaker Brambleclaw",
    "Summon: Auctioneer",
}

-- Create addon frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function()
    -- Initialize saved variables
    if not RandomPet1701_Data then
        RandomPet1701_Data = {}
    end
    if not RandomPet1701_Data.exclusions then
        RandomPet1701_Data.exclusions = {}
        -- Add default exclusions for new installs
        for _, name in ipairs(DEFAULT_EXCLUSIONS) do
            table.insert(RandomPet1701_Data.exclusions, name)
        end
    end
    if not RandomPet1701_Data.groups then
        RandomPet1701_Data.groups = {}
    end

    SLASH_RANDOMPET17011 = "/pet"
    SLASH_RANDOMPET17012 = "/randompet"
    SlashCmdList["RANDOMPET1701"] = SlashCmdHandler
end)

-- Export for external use
RandomPet1701.GetAllPets = GetAllPets
RandomPet1701.DoRandomPet = DoRandomPet
