# Backcountry

A realistic wilderness survival game for [Luanti](https://www.luanti.org/) 5.9+,
playable alone or as a group. No Minetest Game or other mods are needed.

Your body is the game. Calories, water, rest and body temperature all move
with what you do and where you stand, and the world is procedurally generated
across climates from tundra to desert, so "where" matters a great deal.

## Install and play

Put this folder in Luanti's `games` directory (on macOS:
`~/Library/Application Support/minetest/games/backcountry`), pick
**Backcountry** in the main menu, and create a new world. The Valleys map
generator (the default here) gives rivers and real altitude; v7, v5 and
Carpathian also work.

Leave **Enable Damage** on. Hunger, cold and injury use the game's own
condition meter and work either way, but drowning and fire burns come from the
engine and only apply with damage enabled.

For a group, host the world from Luanti's "Host Server" option and have the
others join. Everyone starts in the same place.

## What is simulated

- **Energy** – resting, walking, sprinting, swimming and every block dug or
  placed cost calories. Shivering costs more. A heavy pack costs more still.
- **Water** – steady loss, faster with work and sweat. Untreated water can
  give you dysentery; still water more often than running; boiled never.
- **Rest** – only sleep restores it. When everyone in the group is asleep the
  night passes in moments.
- **Body temperature** – air temperature (biome, season, time of day,
  altitude, weather front, depth underground) adjusted for wind, wetness,
  clothing, sun, exertion, fire and shelter. Hypothermia and heat stroke both
  kill.
- **Shelter by physics** – there is no shelter block. Any sealed air space
  traps heat, more so the smaller it is and the better its walls insulate.
  Walls and trees block wind; a roof keeps you dry; a fire warms a sealed room
  and good walls stay warm after it dies. Doors matter.
- **Weather and seasons** – fronts of cloud, rain, snow and storm; a year of
  40 days (configurable) that starts on the first day of summer.
- **Fire** – friction fire with a bow drill and tinder, with a chance that
  depends on tinder, rain, wind, cold hands and practice. Fuel, embers,
  cooking, boiling, rain drowning an open fire.
- **Food** – foraging, fishing (bait, time of day, weather, overfishing),
  fish traps, snares, hunting with thrown rocks, spears and bows. Animals
  notice movement, noise and scent on the wind. Meat spoils with temperature;
  drying and cold preserve it.
- **Camp cookery** – make meals to share. Each cooking slot shows its progress,
  and a drying rack shows what is hanging on each line. An empty pot left
  outdoors can catch rain.
- **Fieldcraft** – inspect signs left by passing wildlife, tend a berry patch,
  and mark trails between places worth visiting again.
- **Injury and illness** – bleeding, wounds, infection, sprains, food
  poisoning, dysentery, poisoning, each with its own treatment.
- **Carrying** – everything has weight.

## Help built into the game

Open the inventory for the journal:

- **Condition** – every vital with its current rate, a breakdown of exactly
  what is adding to or taking from how warm you feel, what kind of shelter you
  are in, and plain advice for each problem.
  It also reads the lie of the land for water: which way the nearest open
  water is and roughly how far, confirmed against the real terrain, and it
  tells you unasked once you are thirsty.
  You can also turn on a bearing to your camp cairn or your most recent lost pack.
- **Field Guide** – the basics of water, fire, shelter, food, hunting,
  medicine and weather.
- **Crafting** – the recipes you know. More appear as you handle new
  materials. Anything you have made once by hand can be laid out in the craft
  grid from here (double-click it, or press the button) when you carry the
  materials; those recipes show in green. Make a thing five times and it is
  second nature: if another recipe needs it and you only carry the raw
  materials, it is made on the way. Ask for a bow with no cordage and enough
  grass, and the cordage is twisted first.
  Filter by **Have materials** to see what you can make now, or pin one
  recipe to see what you still need while gathering. **Return materials**
  puts the contents of the craft grid back in your pack when they fit.
- **Notes** – a suggested order of goals (the next one is always on screen),
  and discoveries.

The guide deliberately does not tell you everything. Which mushrooms are safe
changes with every world. Several plants, a couple of fire-making tricks, and
a few things about animals are left to find out; the journal records them when
you do. Tips and the on-screen goal can be switched off in the Notes tab.

## Controls

Standard Luanti controls, plus: right-click water with an empty hand to
drink; hold Aux1 (E) while moving forward to sprint; sneak to stalk game, and
sneak + use a mushroom to taste rather than eat it. Use a held garment to
swap it with the one you are wearing. `/bc` gives operators
commands for testing (`/bc info`, `/bc weather storm`, `/bc day 25`, ...).

## Settings

`bc_year_length` (days per year, default 40), `bc_hints` (tips on/off),
`bc_wildlife` (animal density multiplier), `bc_fahrenheit` (switch the
default from Celsius to Fahrenheit), `bc_energy_use` (how fast calories burn; below 1 makes food last
longer), `bc_fuel_life` (how long fuel burns; above 1 makes a fire last
longer). Each player can also switch between Celsius and Fahrenheit with the
button in the journal's Notes tab.

## Where a world starts

A new world's starting point is liveable country with confirmed open water
within about 90 m (usually much closer). The search works outward from the
origin and settles within a second or so of the world starting. Worlds made
before this check existed have their starting point moved the next time they
load; that only affects where new arrivals and the dead wake up.

## Layout

```
mods/bc_sim/   the survival rules as pure Lua with no engine calls
mods/bc/       world, items, fire, shelter, wildlife, HUD and journal
tests/         sim_spec.lua (unit tests), engine_probe/ and showcase/ (world mods)
tools/         asset generators and the engine test runner
```

## Tests

```
luajit tests/sim_spec.lua                     # survival rules, no engine needed
python3 tools/run_engine_tests.py             # loads the game in the real engine, checks world and systems
python3 tools/run_engine_tests.py --client    # also joins with a real client and exercises every player path
python3 tools/run_engine_tests.py --client --headless   # same player checks without opening a window
python3 tools/run_engine_tests.py --show 70   # stages a camp scene to look at
```

The engine tests run in a throwaway world with their own config; your worlds
and settings are not touched.

## Assets

`tools/make_assets.py` builds the original textures and models. Field tools,
cookery and wildlife signs have their own generators in `tools/`. Ambient
sounds are synthesized by `tools/make_sounds.py`. Footsteps, impacts and other foley are
from [Kenney](https://kenney.nl) asset packs (CC0). See CREDITS.md.

## License

Code is MIT; textures, models and sounds are CC0-1.0. See LICENSE, which also
carries the credits and the AI disclosure.
