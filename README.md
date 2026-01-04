# 1701 Random Pet

A World of Warcraft 1.12 addon that randomly selects and summons a companion pet from your collection.

## Installation

1. Download or clone this repository
2. Copy the `1701-Random-Pet` folder to your `Interface/AddOns` directory
3. Rename the folder to `1701_Random_Pet` (replace hyphen with underscore)
4. Restart WoW or type `/reload`

## Usage

```
/pet [filter]
```

### Examples

| Command | Description |
|---------|-------------|
| `/pet` | Summon a random pet from all available |
| `/pet cat` | Summon a random cat pet |
| `/pet whelp` | Summon a random whelpling |
| `/pet frog` | Summon a random frog |
| `/pet mechanical` | Summon a random mechanical pet |
| `/pet debug` | Show detected pets and spellbook contents |

### Aliases

- `/pet`
- `/randompet`

## Features

- Scans your bags for companion pet items (carriers, cages, crates, eggs, etc.)
- Supports Turtle WoW's `ZzCompanions` spellbook tab
- Keyword filtering to summon specific pet types
- Debug mode to troubleshoot pet detection
- Pattern matching for 100+ vanilla WoW companion pets

## Supported Pet Types

- **Cats**: Black Tabby, Bombay, Cornish Rex, Siamese, White Kitten, etc.
- **Birds**: Parrots, Cockatiels, Macaws, Owls, Chickens
- **Snakes**: Black Kingsnake, Brown Snake, Crimson Snake
- **Rabbits**: Snowshoe Rabbit, Spring Rabbit
- **Frogs**: Wood Frog, Tree Frog, Jubling
- **Mechanical**: Squirrel, Chicken, Bombling, Lil' Smoky, Yeti
- **Whelplings**: Azure, Crimson, Dark, Emerald, Sprite Darter
- **Dogs**: Pug, Worg Pup
- **And many more...**

## API

The addon exports functions for use by other addons:

```lua
-- Get all available pets (optionally filtered)
local pets = RandomPet1701.GetAllPets(filter)

-- Summon a random pet (optionally filtered)
RandomPet1701.DoRandomPet(filter)
```

## Compatibility

- World of Warcraft 1.12 (Vanilla)
- Turtle WoW

## License

MIT
