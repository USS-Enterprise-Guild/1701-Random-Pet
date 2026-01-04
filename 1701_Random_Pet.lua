--[[
  1701 Random Pet - Random Companion Pet Selector for WoW 1.12 / Turtle WoW

  Usage: /pet [filter]

  Examples:
    /pet         - Random pet from all available
    /pet cat     - Random cat pet
    /pet whelp   - Random whelpling
    /pet debug   - Show detected pets and spellbook contents
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

-- Class pet spells (Hunter pets are not companions, but some classes might have)
local CLASS_PET_SPELLS = {
    -- These would be companion summoning spells, not hunter pets
}

-- Check if a spell name matches pet patterns
local function IsPetSpell(spellName)
    if not spellName then return false end

    -- Check class pet spells
    if CLASS_PET_SPELLS[spellName] then
        return true
    end

    local lowerName = string.lower(spellName)

    -- Check for common pet keywords
    if string.find(lowerName, "companion") or
       string.find(lowerName, "minipet") or
       string.find(lowerName, "mini%-pet") or
       string.find(lowerName, "summon") and (
           string.find(lowerName, "whelp") or
           string.find(lowerName, "pet") or
           string.find(lowerName, "cat") or
           string.find(lowerName, "frog") or
           string.find(lowerName, "rabbit")
       ) then
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

-- Check if item name matches the filter
local function MatchesFilter(itemName, filter)
    if not filter or filter == "" then
        return true
    end
    return string.find(string.lower(itemName), string.lower(filter))
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
                if itemName and IsPetItem(itemName) and MatchesFilter(itemName, filter) then
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

-- Scan spellbook for pet spells (uses ZPets tab on Turtle WoW)
local function GetSpellPets(filter)
    local pets = {}

    -- Find the ZPets tab (Turtle WoW specific)
    local numTabs = GetNumSpellTabs()
    local petTabOffset = nil
    local petTabCount = nil

    for tab = 1, numTabs do
        local name, texture, offset, numSpells = GetSpellTabInfo(tab)
        if name == "ZPets" or name == "Companions" or name == "Pets" then
            petTabOffset = offset
            petTabCount = numSpells
            break
        end
    end

    -- If pet tab found, get all spells from it
    if petTabOffset and petTabCount then
        for i = 1, petTabCount do
            local spellIndex = petTabOffset + i
            local spellName = GetSpellName(spellIndex, BOOKTYPE_SPELL)
            if spellName and MatchesFilter(spellName, filter) then
                table.insert(pets, {
                    type = "spell",
                    name = spellName,
                    spellIndex = spellIndex
                })
            end
        end
    else
        -- Fallback: scan all spells using pattern matching (for non-Turtle WoW)
        local i = 1
        while true do
            local spellName = GetSpellName(i, BOOKTYPE_SPELL)
            if not spellName then
                break
            end

            if IsPetSpell(spellName) and MatchesFilter(spellName, filter) then
                table.insert(pets, {
                    type = "spell",
                    name = spellName,
                    spellIndex = i
                })
            end
            i = i + 1
        end
    end

    return pets
end

-- Get all available pets
local function GetAllPets(filter)
    local allPets = {}

    -- Get bag pets
    local bagPets = GetBagPets(filter)
    for _, pet in ipairs(bagPets) do
        table.insert(allPets, pet)
    end

    -- Get spell pets
    local spellPets = GetSpellPets(filter)
    for _, pet in ipairs(spellPets) do
        table.insert(allPets, pet)
    end

    return allPets
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
local function DoRandomPet(filter)
    -- Trim whitespace from filter
    if filter then
        filter = string.gsub(filter, "^%s*(.-)%s*$", "%1")
        if filter == "" then
            filter = nil
        end
    end

    local pets = GetAllPets(filter)

    if table.getn(pets) == 0 then
        if filter then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_Random_Pet:|r No pets found matching '" .. filter .. "'")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_Random_Pet:|r No pets found in your bags or spellbook.")
        end
        return
    end

    -- Pick a random pet
    local pet = pets[math.random(1, table.getn(pets))]
    UsePet(pet)
end

-- Debug function to show detected pets and spellbook contents
local function DoDebug()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF1701_Random_Pet Debug:|r Scanning...")

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

    -- Scan spellbook for pet-like spells
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00Scanning all spells for pet-like names:|r")
    local i = 1
    local totalSpells = 0
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            break
        end
        totalSpells = i

        local lowerName = string.lower(spellName)
        local looksLikePet = IsPetSpell(spellName) or
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
            local detected = IsPetSpell(spellName) and " |cFF00FF00[DETECTED]|r" or " |cFFFF0000[MISSED]|r"
            DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ": " .. spellName .. detected)
        end
        i = i + 1
    end
    DEFAULT_CHAT_FRAME:AddMessage("Total spells scanned: " .. totalSpells)
end

-- Slash command handler
local function SlashCmdHandler(msg)
    -- Trim whitespace
    if msg then
        msg = string.gsub(msg, "^%s*(.-)%s*$", "%1")
    end

    if msg == "debug" then
        DoDebug()
    else
        DoRandomPet(msg)
    end
end

-- Create addon frame for event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function()
    SLASH_RANDOMPET17011 = "/pet"
    SLASH_RANDOMPET17012 = "/randompet"
    SlashCmdList["RANDOMPET1701"] = SlashCmdHandler
end)

-- Export for external use
RandomPet1701.GetAllPets = GetAllPets
RandomPet1701.DoRandomPet = DoRandomPet
