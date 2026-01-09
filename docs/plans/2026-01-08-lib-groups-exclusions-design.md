# Random Pet: Lib Integration, Groups & Exclusions

## Overview

Integrate the shared `1701_Lib.lua` library and add grouping/exclusion functionality to match Random-Mount's feature set.

## Data Structure

```lua
RandomPet1701_Data = {
    exclusions = { "Pet Name 1", "Pet Name 2", ... },
    groups = {
        favorites = { "Pet A", "Pet B", ... },
        whelplings = { "Azure Whelpling", "Dark Whelpling", ... },
    },
}
```

Stored as `SavedVariablesPerCharacter` for per-character pet preferences.

## Command Structure

| Command | Action |
|---------|--------|
| `/pet` | Random pet from all available (respects exclusions) |
| `/pet <filter>` | Random pet matching filter (respects exclusions) |
| `/pet <groupname>` | Random pet from group (ignores exclusions) |
| `/pet debug` | Show detected pets and spellbook contents |
| `/pet exclude <filter>` | Add matching pets to exclusion list |
| `/pet unexclude <filter>` | Remove from exclusion list |
| `/pet excludelist` | Show all excluded pets |
| `/pet group add <name> <filter>` | Add matching pets to group |
| `/pet group remove <name> <filter>` | Remove pets from group |
| `/pet group list <name>` | Show pets in group |
| `/pet groups` | List all groups with counts |

## Behavior Rules

- **Exact match bypasses exclusions**: `/pet "Azure Whelpling"` works even if excluded
- **Groups ignore exclusions**: Selecting from a group never checks exclusions
- **Excluded pets skipped when adding to groups**: Unless exact match
- **Empty groups auto-deleted**: When last pet removed from group
- **Reserved commands**: `debug`, `exclude`, `unexclude`, `excludelist`, `group`, `groups`

## Implementation Changes

### 1701_Random_Pet.toc

- Load `1701_Lib.lua` before main addon
- Add `SavedVariablesPerCharacter: RandomPet1701_Data`
- Bump version to `1.1.0`

### 1701_Random_Pet.lua

1. **Remove duplicate functions** - Delete local `MatchesFilter`, use `Lib1701.MatchesFilter`

2. **Add `GetAllPetNames()`** - Returns `{name = "Pet Name"}` format for Lib1701 functions

3. **Add `ShouldIncludePet(petName, filter, skipExclusions)`**:
   - Exact match → include (bypasses exclusions)
   - Excluded → skip (unless skipExclusions)
   - Filter match → include

4. **Update `GetAllPets(filter, skipExclusions)`** - Accept skipExclusions for group selections

5. **Expand slash command handler** - Route to exclusion/group handlers

6. **Initialize SavedVariables** - Ensure data tables exist on VARIABLES_LOADED

7. **Use `Lib1701.Message()`** - Consistent message formatting

## Files Changed

| File | Change |
|------|--------|
| `1701_Random_Pet.toc` | Add lib, SavedVariables, version bump |
| `1701_Random_Pet.lua` | Refactor + new commands |
| `1701_Lib.lua` | No changes (already v3) |

## Version

Bump to `1.1.0` to match Random-Mount's versioning pattern for this feature set.
