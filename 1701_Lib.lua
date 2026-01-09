--[[
    1701 Shared Library - Common utilities for 1701 addons

    Uses version gating so multiple addons can embed this file.
    Only the first (or newer) version initializes.
]]

local LIB_VERSION = 5
if Lib1701 and Lib1701.version >= LIB_VERSION then
    return
end

Lib1701 = {
    version = LIB_VERSION,
}

-- Message formatting with consistent addon prefix
function Lib1701.Message(prefix, text)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF" .. prefix .. ":|r " .. text)
end

-- Parse comma-separated values, trim whitespace from each
function Lib1701.ParseCSV(input)
    local results = {}
    if not input or input == "" then
        return results
    end

    -- Split by comma
    local pattern = "([^,]+)"
    for item in string.gfind(input, pattern) do
        -- Trim whitespace
        local trimmed = string.gsub(item, "^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then
            table.insert(results, trimmed)
        end
    end

    return results
end

-- Extract name from a spell/item link, or return original text
-- Handles: |cffffffff|Hspell:12345|h[Spell Name]|h|r -> "Spell Name"
-- Also handles plain [Name] -> "Name"
function Lib1701.ExtractLinkName(text)
    if not text then
        return nil
    end

    -- Try to extract name from full link format: |c...|H...|h[Name]|h|r
    local _, _, name = string.find(text, "|h%[(.-)%]|h")
    if name then
        return name
    end

    -- Try plain bracket format: [Name]
    _, _, name = string.find(text, "^%[(.-)%]$")
    if name then
        return name
    end

    -- Return original text (trimmed)
    return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

-- Parse input as comma-separated list, extracting link names
-- Returns table of names (strings)
function Lib1701.ParseInputList(input)
    local items = Lib1701.ParseCSV(input)
    local results = {}

    for _, item in ipairs(items) do
        local name = Lib1701.ExtractLinkName(item)
        if name and name ~= "" then
            table.insert(results, name)
        end
    end

    return results
end

-- Check if name matches filter (substring, case-insensitive)
function Lib1701.MatchesFilter(name, filter)
    if not name then
        return false
    end
    if not filter or filter == "" then
        return true
    end
    return string.find(string.lower(name), string.lower(filter)) ~= nil
end

-- Check if name exactly matches filter (case-insensitive)
function Lib1701.IsExactMatch(name, filter)
    if not name then
        return false
    end
    if not filter or filter == "" then
        return false
    end
    return string.lower(name) == string.lower(filter)
end

-- Validate group name: alphanumeric, hyphen, underscore only
-- Returns: isValid (bool), errorMsg (string or nil)
function Lib1701.IsValidGroupName(name)
    if not name or name == "" then
        return false, "Group name cannot be empty"
    end

    -- Check for link characters (item/spell links)
    if string.find(name, "|") or string.find(name, "%[") or string.find(name, "%]") then
        return false, "Group name cannot be an item or spell link"
    end

    -- Check for valid characters only (alphanumeric, hyphen, underscore)
    if string.find(name, "[^%w%-_]") then
        return false, "Group name can only contain letters, numbers, hyphens, and underscores"
    end

    return true, nil
end

-- Check if a name is in the exclusion list
function Lib1701.IsExcluded(exclusions, name)
    if not exclusions or not name then
        return false
    end
    local lowerName = string.lower(name)
    for _, excluded in ipairs(exclusions) do
        if string.lower(excluded) == lowerName then
            return true
        end
    end
    return false
end

-- Add items matching filter to exclusion list
-- Returns: added (table), alreadyExcluded (table)
function Lib1701.AddExclusions(exclusions, filter, getAllItemsFn)
    if not exclusions then
        return {}, {}
    end

    local added = {}
    local alreadyExcluded = {}

    if not getAllItemsFn then
        return added, alreadyExcluded
    end

    local allItems = getAllItemsFn()
    for _, item in ipairs(allItems) do
        if Lib1701.MatchesFilter(item.name, filter) then
            if Lib1701.IsExcluded(exclusions, item.name) then
                table.insert(alreadyExcluded, item.name)
            else
                table.insert(exclusions, item.name)
                table.insert(added, item.name)
            end
        end
    end

    return added, alreadyExcluded
end

-- Remove items matching filter from exclusion list
-- Returns: removed (table), notFound (table)
function Lib1701.RemoveExclusions(exclusions, filter)
    if not exclusions then
        return {}, {}
    end

    local removed = {}
    local toRemove = {}

    -- Find matching exclusions
    for i, excluded in ipairs(exclusions) do
        if Lib1701.MatchesFilter(excluded, filter) then
            table.insert(toRemove, i)
            table.insert(removed, excluded)
        end
    end

    -- Remove in reverse order to preserve indices
    for i = table.getn(toRemove), 1, -1 do
        table.remove(exclusions, toRemove[i])
    end

    -- If nothing matched, report as not found
    local notFound = {}
    if table.getn(removed) == 0 then
        table.insert(notFound, filter)
    end

    return removed, notFound
end

-- Get a group by name (case-insensitive)
function Lib1701.GetGroup(groups, groupName)
    if not groups or not groupName then
        return nil
    end
    local lowerName = string.lower(groupName)
    for name, members in pairs(groups) do
        if string.lower(name) == lowerName then
            return members, name  -- return members and actual stored name
        end
    end
    return nil, nil
end

-- Add items matching filter to a group (creates group if needed)
-- Respects exclusions when adding via filter
-- Returns: added (table), skipped (table), isNewGroup (bool)
function Lib1701.AddToGroup(groups, groupName, filter, getAllItemsFn, exclusions)
    local added = {}
    local skipped = {}

    if not groups then
        return {}, {}, false
    end

    if not getAllItemsFn then
        return added, skipped, false
    end

    -- Get or create group
    local members, storedName = Lib1701.GetGroup(groups, groupName)
    local isNewGroup = (members == nil)
    if isNewGroup then
        storedName = groupName
        groups[storedName] = {}
        members = groups[storedName]
    end

    local allItems = getAllItemsFn()
    for _, item in ipairs(allItems) do
        if Lib1701.MatchesFilter(item.name, filter) then
            -- Check if exact match (bypasses exclusions)
            local isExact = Lib1701.IsExactMatch(item.name, filter)

            -- Check if excluded (unless exact match)
            if not isExact and Lib1701.IsExcluded(exclusions, item.name) then
                table.insert(skipped, item.name)
            else
                -- Check if already in group
                local alreadyInGroup = false
                for _, member in ipairs(members) do
                    if string.lower(member) == string.lower(item.name) then
                        alreadyInGroup = true
                        break
                    end
                end

                if not alreadyInGroup then
                    table.insert(members, item.name)
                    table.insert(added, item.name)
                end
            end
        end
    end

    -- If nothing was added to a new group, remove the empty group
    if isNewGroup and table.getn(members) == 0 then
        groups[storedName] = nil
        isNewGroup = false
    end

    return added, skipped, isNewGroup
end

-- Remove items matching filter from a group
-- Returns: removed (table), groupDeleted (bool)
function Lib1701.RemoveFromGroup(groups, groupName, filter)
    local removed = {}

    local members, storedName = Lib1701.GetGroup(groups, groupName)
    if not members then
        return removed, false
    end

    local toRemove = {}
    for i, member in ipairs(members) do
        if Lib1701.MatchesFilter(member, filter) then
            table.insert(toRemove, i)
            table.insert(removed, member)
        end
    end

    -- Remove in reverse order
    for i = table.getn(toRemove), 1, -1 do
        table.remove(members, toRemove[i])
    end

    -- Delete group if empty
    local groupDeleted = false
    if table.getn(members) == 0 then
        groups[storedName] = nil
        groupDeleted = true
    end

    return removed, groupDeleted
end
