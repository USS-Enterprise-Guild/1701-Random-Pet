# Lib Integration, Groups & Exclusions Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add grouping and exclusion functionality to Random Pet addon, mirroring Random Mount's feature set.

**Architecture:** Integrate existing `1701_Lib.lua` shared library, add SavedVariables for persistent data, expand slash command handler to route exclusion/group commands.

**Tech Stack:** WoW 1.12 Lua, SavedVariables API, 1701_Lib.lua shared library

---

### Task 1: Update TOC File

**Files:**
- Modify: `1701_Random_Pet.toc`

**Step 1: Add lib loading and SavedVariables**

Update the TOC file to load the library before the main addon and declare saved variables:

```toc
## Interface: 11200
## Title: 1701 Addons - Random Pet
## Notes: Random companion pet selector with optional keyword filtering
## Author: Claude
## Version: 1.1.0
## SavedVariablesPerCharacter: RandomPet1701_Data

1701_Lib.lua
1701_Random_Pet.lua
```

**Step 2: Verify syntax**

Run: `lua -c 1701_Random_Pet.toc 2>&1 || echo "TOC files are not Lua - visual inspection only"`
Expected: TOC is plain text, visual inspection confirms correct format

**Step 3: Commit**

```bash
git add 1701_Random_Pet.toc
git commit -m "feat: add lib loading and SavedVariables to TOC"
```

---

### Task 2: Add SavedVariables Initialization

**Files:**
- Modify: `1701_Random_Pet.lua:472-478` (event handler section)

**Step 1: Update VARIABLES_LOADED handler**

Replace the existing event handler to initialize saved data:

```lua
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
    end
    if not RandomPet1701_Data.groups then
        RandomPet1701_Data.groups = {}
    end

    SLASH_RANDOMPET17011 = "/pet"
    SLASH_RANDOMPET17012 = "/randompet"
    SlashCmdList["RANDOMPET1701"] = SlashCmdHandler
end)
```

**Step 2: Verify Lua syntax**

Run: `lua -c 1701_Random_Pet.lua`
Expected: No syntax errors

**Step 3: Commit**

```bash
git add 1701_Random_Pet.lua
git commit -m "feat: initialize SavedVariables on load"
```

---

### Task 3: Add Helper Functions

**Files:**
- Modify: `1701_Random_Pet.lua` (after GetAllPets function, around line 334)

**Step 1: Add GetAllPetNames helper**

Add function that returns pet names in format expected by Lib1701:

```lua
-- Get all pet names for Lib1701 functions
local function GetAllPetNames()
    local pets = GetAllPets(nil)
    local names = {}
    for _, pet in ipairs(pets) do
        table.insert(names, { name = pet.name })
    end
    return names
end
```

**Step 2: Add ShouldIncludePet function**

Add function to check if pet should be included (respecting exclusions):

```lua
-- Check if pet should be included based on filter and exclusions
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
```

**Step 3: Verify Lua syntax**

Run: `lua -c 1701_Random_Pet.lua`
Expected: No syntax errors

**Step 4: Commit**

```bash
git add 1701_Random_Pet.lua
git commit -m "feat: add GetAllPetNames and ShouldIncludePet helpers"
```

---

### Task 4: Update GetAllPets to Use Lib and Respect Exclusions

**Files:**
- Modify: `1701_Random_Pet.lua:318-334` (GetAllPets function)

**Step 1: Update GetAllPets signature and logic**

Replace the GetAllPets function to accept skipExclusions parameter:

```lua
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
```

**Step 2: Remove local MatchesFilter function**

Delete the local MatchesFilter function (lines 230-235) since we now use Lib1701.MatchesFilter:

```lua
-- DELETE THIS FUNCTION:
-- Check if item name matches the filter
local function MatchesFilter(itemName, filter)
    if not filter or filter == "" then
        return true
    end
    return string.find(string.lower(itemName), string.lower(filter))
end
```

**Step 3: Update GetBagPets and GetSpellPets**

Update these functions to not filter internally (remove MatchesFilter calls):

In GetBagPets (around line 248):
```lua
if itemName and IsPetItem(itemName) then  -- Remove: and MatchesFilter(itemName, filter)
```

In GetSpellPets (around line 286):
```lua
if spellName then  -- Remove: and MatchesFilter(spellName, filter)
```

And around line 303:
```lua
if IsPetSpell(spellName) then  -- Remove: and MatchesFilter(spellName, filter)
```

**Step 4: Verify Lua syntax**

Run: `lua -c 1701_Random_Pet.lua`
Expected: No syntax errors

**Step 5: Commit**

```bash
git add 1701_Random_Pet.lua
git commit -m "refactor: use Lib1701 for filtering, add exclusion support"
```

---

### Task 5: Add Exclusion Command Handlers

**Files:**
- Modify: `1701_Random_Pet.lua` (add after ShouldIncludePet, before DoRandomPet)

**Step 1: Add exclusion command handlers**

```lua
-- Message prefix
local MSG_PREFIX = "1701_Random_Pet"

-- Handle /pet exclude <filter>
local function DoExclude(filter)
    if not filter or filter == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet exclude <filter>")
        return
    end

    local added, alreadyExcluded = Lib1701.AddExclusions(
        RandomPet1701_Data.exclusions,
        filter,
        GetAllPetNames
    )

    if table.getn(added) > 0 then
        Lib1701.Message(MSG_PREFIX, "Excluded: " .. table.concat(added, ", ") .. " (" .. table.getn(added) .. " pets)")
    elseif table.getn(alreadyExcluded) > 0 then
        Lib1701.Message(MSG_PREFIX, "Already excluded: " .. table.concat(alreadyExcluded, ", "))
    else
        Lib1701.Message(MSG_PREFIX, "No pets found matching '" .. filter .. "'")
    end
end

-- Handle /pet unexclude <filter>
local function DoUnexclude(filter)
    if not filter or filter == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet unexclude <filter>")
        return
    end

    local removed, notFound = Lib1701.RemoveExclusions(
        RandomPet1701_Data.exclusions,
        filter
    )

    if table.getn(removed) > 0 then
        Lib1701.Message(MSG_PREFIX, "Unexcluded: " .. table.concat(removed, ", ") .. " (" .. table.getn(removed) .. " pets)")
    else
        Lib1701.Message(MSG_PREFIX, "No excluded pets found matching '" .. filter .. "'")
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
```

**Step 2: Verify Lua syntax**

Run: `lua -c 1701_Random_Pet.lua`
Expected: No syntax errors

**Step 3: Commit**

```bash
git add 1701_Random_Pet.lua
git commit -m "feat: add exclusion command handlers"
```

---

### Task 6: Add Group Command Handlers

**Files:**
- Modify: `1701_Random_Pet.lua` (add after exclusion handlers)

**Step 1: Add group command handlers**

```lua
-- Reserved command names (cannot be used as group names)
local RESERVED_COMMANDS = {
    debug = true,
    exclude = true,
    unexclude = true,
    excludelist = true,
    group = true,
    groups = true,
}

-- Handle /pet group add <name> <filter>
local function DoGroupAdd(groupName, filter)
    if not groupName or groupName == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group add <groupname> <filter>")
        return
    end

    if RESERVED_COMMANDS[string.lower(groupName)] then
        Lib1701.Message(MSG_PREFIX, "Cannot use reserved name '" .. groupName .. "' as group name")
        return
    end

    if not filter or filter == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group add <groupname> <filter>")
        return
    end

    local added, skipped, isNewGroup = Lib1701.AddToGroup(
        RandomPet1701_Data.groups,
        groupName,
        filter,
        GetAllPetNames,
        RandomPet1701_Data.exclusions
    )

    local msg = ""
    if isNewGroup then
        msg = "Created group '" .. groupName .. "': "
    else
        msg = "Added to '" .. groupName .. "': "
    end

    if table.getn(added) > 0 then
        msg = msg .. table.concat(added, ", ") .. " (" .. table.getn(added) .. " pets"
        if table.getn(skipped) > 0 then
            msg = msg .. ", skipped " .. table.getn(skipped) .. " excluded"
        end
        msg = msg .. ")"
        Lib1701.Message(MSG_PREFIX, msg)
    elseif table.getn(skipped) > 0 then
        Lib1701.Message(MSG_PREFIX, "All matching pets are excluded (" .. table.getn(skipped) .. " skipped)")
    else
        Lib1701.Message(MSG_PREFIX, "No pets found matching '" .. filter .. "'")
    end
end

-- Handle /pet group remove <name> <filter>
local function DoGroupRemove(groupName, filter)
    if not groupName or groupName == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group remove <groupname> <filter>")
        return
    end

    if not filter or filter == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group remove <groupname> <filter>")
        return
    end

    local removed, groupDeleted = Lib1701.RemoveFromGroup(
        RandomPet1701_Data.groups,
        groupName,
        filter
    )

    if table.getn(removed) > 0 then
        local msg = "Removed from '" .. groupName .. "': " .. table.concat(removed, ", ")
        if groupDeleted then
            msg = msg .. " (group deleted)"
        end
        Lib1701.Message(MSG_PREFIX, msg)
    else
        local members = Lib1701.GetGroup(RandomPet1701_Data.groups, groupName)
        if not members then
            Lib1701.Message(MSG_PREFIX, "Group '" .. groupName .. "' not found")
        else
            Lib1701.Message(MSG_PREFIX, "No pets in '" .. groupName .. "' matching '" .. filter .. "'")
        end
    end
end

-- Handle /pet group list <name>
local function DoGroupList(groupName)
    if not groupName or groupName == "" then
        Lib1701.Message(MSG_PREFIX, "Usage: /pet group list <groupname>")
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
```

**Step 2: Verify Lua syntax**

Run: `lua -c 1701_Random_Pet.lua`
Expected: No syntax errors

**Step 3: Commit**

```bash
git add 1701_Random_Pet.lua
git commit -m "feat: add group command handlers"
```

---

### Task 7: Update DoRandomPet for Groups

**Files:**
- Modify: `1701_Random_Pet.lua` (DoRandomPet function)

**Step 1: Update DoRandomPet to handle group selection**

Replace the DoRandomPet function:

```lua
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
```

**Step 2: Verify Lua syntax**

Run: `lua -c 1701_Random_Pet.lua`
Expected: No syntax errors

**Step 3: Commit**

```bash
git add 1701_Random_Pet.lua
git commit -m "feat: add group pet selection"
```

---

### Task 8: Update Slash Command Handler

**Files:**
- Modify: `1701_Random_Pet.lua` (SlashCmdHandler function)

**Step 1: Replace slash command handler with full routing**

```lua
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
```

**Step 2: Verify Lua syntax**

Run: `lua -c 1701_Random_Pet.lua`
Expected: No syntax errors

**Step 3: Commit**

```bash
git add 1701_Random_Pet.lua
git commit -m "feat: expand slash command handler for all commands"
```

---

### Task 9: Update Debug Output and Message Formatting

**Files:**
- Modify: `1701_Random_Pet.lua` (DoDebug function and any remaining AddMessage calls)

**Step 1: Update DoDebug to use Lib1701.Message where appropriate**

Update the first line of DoDebug:

```lua
local function DoDebug()
    Lib1701.Message(MSG_PREFIX, "Debug: Scanning...")
```

**Step 2: Verify Lua syntax**

Run: `lua -c 1701_Random_Pet.lua`
Expected: No syntax errors

**Step 3: Commit**

```bash
git add 1701_Random_Pet.lua
git commit -m "refactor: use Lib1701.Message for consistent formatting"
```

---

### Task 10: Final Verification and Cleanup

**Files:**
- Review: `1701_Random_Pet.lua`
- Review: `1701_Random_Pet.toc`

**Step 1: Verify complete Lua syntax**

Run: `lua -c 1701_Random_Pet.lua`
Expected: No syntax errors

**Step 2: Review file for any remaining issues**

Check for:
- Duplicate function definitions
- Unused variables
- Consistent use of Lib1701 functions
- MSG_PREFIX used consistently

**Step 3: Final commit if any cleanup needed**

```bash
git add -A
git commit -m "chore: final cleanup and verification"
```

---

### Task 11: Update Header Comments

**Files:**
- Modify: `1701_Random_Pet.lua` (header comment block)

**Step 1: Update header to document new commands**

```lua
--[[
  1701 Random Pet - Random Companion Pet Selector for WoW 1.12 / Turtle WoW
  Version 1.1.0

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
    - Exact match (e.g., /pet "Azure Whelpling") bypasses exclusions
    - Groups ignore exclusions entirely
    - Uses 1701_Lib.lua shared library
]]
```

**Step 2: Commit**

```bash
git add 1701_Random_Pet.lua
git commit -m "docs: update header comments with new commands"
```

---

## Summary

| Task | Description | Commits |
|------|-------------|---------|
| 1 | Update TOC file | 1 |
| 2 | SavedVariables initialization | 1 |
| 3 | Add helper functions | 1 |
| 4 | Update GetAllPets with exclusions | 1 |
| 5 | Exclusion command handlers | 1 |
| 6 | Group command handlers | 1 |
| 7 | DoRandomPet for groups | 1 |
| 8 | Slash command routing | 1 |
| 9 | Debug/message formatting | 1 |
| 10 | Final verification | 0-1 |
| 11 | Header comments | 1 |

**Total: 10-11 commits**
