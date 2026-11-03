# THE LAST DROP: Full Game Script

Status: draft for review. Chapters 0 and 1 of the shipped build match
`data/dialogue.json`; chapters 2 to 6 are new. Line style follows the existing
data: short lines (max ~140 chars), present tense, no lectures.

## Story spine

- **Protagonist:** an unnamed survivor. Never speaks aloud; the player's choices speak.
- **The Voice:** recordings left by **Ines Varga**, a water engineer who stayed behind
  to keep the restoration facility alive. Recording 1 is her "Day 412" message.
  The player assumes she is leading them to a miracle. She is leaving them a job.
- **False villain thread:** every region suggests a culprit (a corporation, a
  machine, a council). Each document is real but partial. Nobody is "the one".
- **The twist (chapter 5):** no single catastrophe, and the Last Drop is a
  restoration facility that needs people to run it.
- **The choice (chapter 5):** Preserve the knowledge or Share it.

## Pacing and design rules

1. One new mechanic per chapter. Older mechanics return inside later puzzles.
2. Every repair solves a survival need AND unlocks one lesson.
3. Lesson loop: Encounter, Experiment, Consequence, Principle, Real life (max 4 short lines on screen).
4. Wrong choices cost a little health and teach; they never soft-lock.
5. Recordings are the only long text. Everything else is one to three lines.
6. Each chapter ends with a recording that reframes the previous chapter.

## Survival systems and how they chain

| System | Restored in | Needs from |
|---|---|---|
| Water | Ch.0 treatment unit, Ch.2 filter chain | Reusable metal (Ch.1), power (Ch.4) |
| Shelter | Ch.1 | Sorted reusable materials |
| Food | Ch.3 | Water (Ch.2), clean compost (Ch.1 sorting) |
| Energy | Ch.4 | Safe battery handling (Ch.0), copper (Ch.1) |
| Health | Throughout | Avoiding hazards; clean water and food heal |

---

## Chapter 0: The Forgotten Outpost (built)

**Goal:** water, sorting, first clue. **Lesson set:** hazardous vs general waste, treatment.

**Intro** (id `intro`)
- You wake up in the ruins of a settlement. Nobody has lived here for a long time.
- Your throat is dry. Everything you need starts with clean water.
- Look around. Anything you find might help.

**Scrap pile / sorting:** items battery, chemical can, plastic bottle, scrap metal,
glass shard, pipe section. Bins: Hazardous, Recyclable, Reusable (1/2/3).

**Recording 1 (Ines, Day 412)**
- "Day 412. We keep saying someone else will deal with the waste."
- "It was never one disaster. It was a thousand small choices to look away."
- "If you can hear this, follow the old pipeline north. There is a source of pure water. They call it the Last Drop."

**Gate:** opens after recording 1.

---

## Chapter 1: The Battery Factory (built) then The Great Dump

### 1A Battery Factory (built)
**Goal:** hazardous sorting, generator, archive terminal.
- `factory_arrival`: "The old battery factory. Rusted shelves, cracked crates, a smell of chemicals." / "Careful here. Some of this is dangerous."
- Generator repaired: "The generator coughs, then catches. Lights flicker on across the factory."
- Terminal archive: first hint that the collapse was slow (see data file).

### 1B The Great Dump (new)
**Setting:** a megacity's tower tops poke out of a plastic hillside. Wind moves
bags like tumbleweeds. Gulls are gone; rats are fat.
**New mechanic:** *Material recovery runs.* The pile is bigger, items arrive on
a conveyor, and you have 20 seconds per batch. Add a fourth bin: **Compost** (organic).
**Hazard rule:** hazardous items touched without gloves cost health. Gloves are
a reusable craft from textile scrap.

**Arrival** (`dump_arrival`)
- Towers rise out of the plastic like broken teeth.
- Whatever people threw away, they never stopped throwing.
- Sorting here is slow and tedious. It is also the only way to build anything.

**Environmental clues (no dialogue, set dressing):**
- A faded recycling bin, lid sealed shut with a "NOT TODAY" sticker.
- A shopping cart of identical unopened gadgets.
- A drainage pipe stained green, running downhill toward the river.

**Items and lessons (add to `items.json` / `lessons.json`)**

| Item | Category | Lesson id |
|---|---|---|
| Phone | hazardous (e-waste) | ewaste_phone |
| Fluorescent tube | hazardous | tube_mercury |
| Food scraps | compost | food_compost |
| Cardboard | recyclable | paper_recycle |
| Glass jar | recyclable | glass_infinite |
| Textile scrap | reusable | textile_reuse |
| Tin can | recyclable | metal_recycle |
| Greasy pizza box | general (contaminated) | contamination_ruins |

**Lesson text**
- *ewaste_phone:* wrong: "Phones in the general pile leak lead and cadmium and bury gold and copper nobody gets back." right: "E-waste collection recovers metals and keeps toxins out of soil." principle: "Electronics are mines of reusable metal and sources of hazard." real life: "Take old phones to an e-waste drop-off or a take-back scheme."
- *tube_mercury:* wrong: "A cracked tube releases mercury vapour." right: "Whole tubes go to hazardous collection where the mercury is captured." principle: "Some everyday items hide hazardous contents." real life: "Never break old bulbs. Use a collection point."
- *food_compost:* wrong: "Food in the landfill rots without air and makes methane." right: "Composting turns it into soil." principle: "Organic waste is a resource when it stays out of landfill." real life: "Compost at home or use your local food-waste collection."
- *glass_infinite:* principle: "Glass can be recycled again and again without losing quality." real life: "Rinse and sort glass by local rules."
- *contamination_ruins:* wrong: "Grease and food on cardboard spoil a whole recycling batch." right: "Clean items recycle; dirty ones go to the general bin or compost where accepted." principle: "Clean sorting keeps recycling worth doing." real life: "Rinse containers; tear off clean paper from greasy parts."

**Craft outcomes**
- Gloves (textile + tin clasp): reduces hazard damage.
- Shelter panel (cardboard + scrap metal): fixes the roof of the Outpost, unlocks a safe rest spot (restores health slowly).

**Companion beat:** the first creature, a gaunt dog, follows from here. It never
speaks; it sniffs out hidden recyclables (optional collectible aid).

**Recording 2 (Ines, Day 301)**
- "We had sorting plants. Good ones. Then someone realised it was cheaper to ship the waste away than to fix them."
- "Away has an address. It is always someone else's backyard."
- "The river is next. Follow the green stain, and do not drink it."

**Dump exit:** requires shelter panel installed (proves reuse) OR recording found.

---

## Chapter 2: The Dead River

**Setting:** a wide grey river, lit orange by a dying sun. Barrels half-sunk.
A foam line marks the bank. A collapsed treatment plant stands on the far side.
**New mechanic:** *Filter chain.* The player assembles a sequence of stages to
treat sample water, then tests it with a strip. Stages: **Screen**, **Settle**,
**Sand/charcoal filter**, **Disinfect**, **Test**. Wrong order or missing stage
yields a different test result, explained by the strip colour.

**Arrival** (`river_arrival`)
- The river is the colour of old tea. The air tastes of metal.
- A treatment plant waits on the far bank, its basins dry.
- Clear water is not the same as safe water. Learn the difference.

**Key lessons**
- *clear_not_safe:* wrong: "You drink the clear sample. Clear can still hide metals and chemicals." right: "The test strip shows what your eyes cannot." principle: "Clear water is not necessarily safe." real life: "If water quality is uncertain, use a tested or treated source."
- *filter_limits:* "A sand filter removes particles. It does not remove dissolved chemicals." principle: "Each treatment stage solves a different problem." real life: "Know what your filter removes."
- *boil_limits:* "Boiling kills germs. It does not remove metals or chemicals, and it can concentrate them." principle: "Match the treatment to the contaminant."
- *runoff:* "Rain washed the dump's green leachate into the river. Where waste goes, water follows."

**Puzzle design (three nested checks)**
1. **Sample** at three points: upstream, near the dump pipe, downstream of the barrels. Test strips reveal different results (clean, high pH/metal, chemical).
2. **Source control:** use the sealed hazardous barrels (sorted in Ch.1) correctly or the chemical plume returns. Reuse of Ch.0 skills.
3. **Build the chain** with materials from the Dump (charcoal from a burnt crate, sand from the river bank, pipe sections). The plant needs power; a hand pump is the fallback (slow).

**Survival payoff:** a safe water station. Water meter refills each rest.

**Recording 3 (Ines, Day 188)**
- "The plant needed new filters. The budget meeting went on for two years."
- "Everyone knew. Everyone agreed it was serious. Nobody voted for the cost."
- "Plants do not fail. People defer them."

**Exit:** a levee gate opens when the water station runs.

---

## Chapter 3: The Silent Fields

**Setting:** grey cracked earth, a single dead tree, rows of empty greenhouse
frames. A silent wind turbine turns slowly. Seed packets scattered like confetti.
**New mechanic:** *Compost cycle.* A compost bin needs a balance of "browns"
(cardboard, dry leaves) and "greens" (food scraps), moisture and time. A
fast-forward day button advances a few days. Wrong mix: smell, flies, no soil.
Plastic or batteries in the bin ruin the batch and teach contamination.
**Soil test:** a three-colour kit (poor, fair, rich).

**Arrival** (`fields_arrival`)
- Nothing grows here. Not because it is dry. Because the soil forgot how.
- Soil is alive. Without life it is just dust.
- Maybe the Dump has something to give it back.

**Key lessons**
- *brown_green:* "Compost needs a mix of dry carbon-rich material and wet nitrogen-rich scraps." principle: "Balance makes soil." real life: "Layer dry leaves or cardboard with kitchen scraps."
- *no_plastic:* "Plastic and metal do not rot. They contaminate the soil." principle: "Only organic material belongs in compost."
- *soil_loss:* "Without living soil, rain washes the nutrients away." principle: "Soil takes centuries to build and moments to lose."
- *waste_to_food:* "Food scraps from the Dump became soil here. One system's waste is another's input." (This is the chapter's core insight.)

**Chain with earlier chapters**
- Needs water from Ch.2 (watering the bed).
- Needs correct sorting from Ch.1 (no hazardous contamination in compost).
- Harvest: first food item (a tomato). It restores health and ends the food meter drain.

**Recording 4 (Ines, Day 120)**
- "We stopped feeding the soil. We fed the crops instead. It worked, until it did not."
- "Waste was always just food for something else. We forgot that."
- "The factories will tell you the rest. Be careful what you open."

**Exit:** an old rail track leads toward the factories once the first harvest grows.

---

## Chapter 4: The Forgotten Industry

**Setting:** an industrial park at dusk. Smokestacks, pipes, warning signs in
three languages. Orange sky, green puddles, yellow barrels. Danger is visible.
**New mechanic:** *Hazard or resource?* A scanning tool (a Geiger-like clicker)
identifies unlabelled containers by symbols (corrosive, flammable, toxic,
battery). The player decides: leave, safely contain, or salvage. Resource
choices power the plant: solar panels, a wind turbine, an efficient motor.
**Energy minigame:** a small grid to route power. Efficient appliances draw
less; wasteful ones brown out the grid. Teaches efficiency as the cheapest source.

**Arrival** (`industry_arrival`)
- The chimneys are cold. The signs still warn you.
- Some of this is treasure. Some of it is poison. The labels will tell you which, if you can still read them.
- Do not guess.

**Key lessons**
- *hazard_symbols:* "Hazard symbols tell you what a container can do: burn, corrode, poison, explode." principle: "Read the label before you touch it."
- *panel_reuse:* "Solar panels and motors can be reused long after the factory has gone." principle: "Old equipment is a store of useful parts."
- *efficiency_first:* "The cheapest energy is the energy you do not use." principle: "Efficient devices make renewable power go further."
- *battery_storage:* "Batteries store the sun's energy for the night. At end of life they are hazardous waste again." principle: "Treat storage as part of the whole system."

**Choices with consequences**
- Salvage a chemical drum for its metal: leaking, health loss, water contaminated. Hint: Ch.2 knowledge.
- Contain it in a sealed bin and flag it for collection: safe, a small reward, a recording unlocks.

**Chain:** restoring power makes the Ch.2 water station run automatically and
powers the Last Sanctuary gate.

**Recording 5 (Ines, Day 60)**
- "We used to measure success in how much we made. Never in what it cost to make it."
- "The cheapest product always had a hidden bill. Someone else paid it. You are standing in it."
- "The Sanctuary is in the hills. The door still opens for anyone who brings power."

**Exit:** a power line leads to the hills once the grid is online.

---

## Chapter 5: The Last Sanctuary

**Setting:** a glass-and-concrete research centre carved into a hillside. Moss
on the walls. A dormant atrium garden. Lights come on in sequence as you power it.
**Mechanic:** *Archive reconstruction.* Six archive fragments (earned from each
region) are sorted on a timeline. Putting them in order reveals the story.
Optional: link each fragment to the choice that would have changed it.

**Arrival** (`sanctuary_arrival`)
- Moss grows on the glass. Someone kept the lights on, once.
- Every region you crossed left something here. Piece it together.

**The Archive timeline (fragments)**
1. **Overconsumption:** "Buy, use, discard. The loop was never closed."
2. **Neglected recycling:** "Plants closed. Collection stopped. Landfills filled."
3. **Delayed action:** "Policy was postponed again, for good reasons each time."
4. **Hidden costs:** "Cheap goods. Contaminated rivers. Different people paying."
5. **Collective inaction:** "Everyone waited for someone else to move first."
6. **Ines's last log:** (see below)

**Revelation one (the first twist)**
> "There was no single catastrophe. Humanity did not lose the world because it
> had no solutions. It lost the world because it repeatedly chose not to use them."

**Revelation two (the second twist)** (`sanctuary_truth`)
- You look for a spring. There isn't one.
- The Last Drop is a restoration facility. Research, equipment, water systems, seed banks.
- It will not rebuild the world by itself. It needs people, power and patience.

**Ines's final recording (Day 1)**
- "If you are listening, you found it. You powered it. That means you already know how."
- "It does not fix anything on its own. It is a tool. It needs hands."
- "The world was not destroyed in a single day. It will not be rebuilt in one either."
- "What you do with this place is up to you."

---

## Chapter 6: The Choice (ending)

**The decision:** a console shows two options.

**Option A: Preserve the knowledge**
- "Keep it safe. Protect your community first."
- Consequence line: the facility feeds a small, healthy settlement. The wider world stays out of reach.

**Option B: Share the knowledge**
- "Broadcast it. Let others build their own."
- Consequence line: signals go out across the dead world. Some answer. Some may misuse it.

**Epilogue modifiers (from `GameState` counters)**

| Condition | Epilogue line |
|---|---|
| Sorting accuracy >= 90% | "Your care showed in every system. Others will learn it from you." |
| Sorting accuracy 60 to 89% | "You learned as you went. Most things worked." |
| Sorting accuracy < 60% | "It was a hard road. The facility remembers every mistake, and so do you." |
| Water station + compost + power all restored | "Clean water. Living soil. Light. A foundation to build on." |
| Hazards salvaged unsafely (Ch.4) | "Some wounds in the land are still open." |

**Final card**
> "The world wasn't destroyed in a single day. And it won't be rebuilt in one either."

---

## Full codex (one entry per lesson, unlocked in order)

| Region | Entries |
|---|---|
| Outpost | Hazardous waste, water treatment, recycling basics |
| Factory | Battery chemistry, safe collection |
| Dump | E-waste, mercury, glass, contamination, composting intro |
| River | Clear vs safe, filter stages, boiling limits, runoff |
| Fields | Brown/green balance, no plastic, soil loss, waste-to-food |
| Industry | Hazard symbols, reuse of panels, efficiency, battery storage |
| Sanctuary | Systems thinking, shared responsibility |

Each codex entry carries: title, one-line principle, one real-life tip, and the
region where it was learned. The ending screen reads the codex to show what the
player learned.

## Data to add (when implementing)

- `data/chapters.json`: ordered list, areas per chapter, unlock flags.
- `data/dialogue.json`: add ids `dump_arrival`, `river_arrival`, `fields_arrival`, `industry_arrival`, `sanctuary_arrival`, `sanctuary_truth` and recordings 2 to 5 plus Ines's final recording.
- `data/lessons.json`: lessons above.
- `data/items.json`: new items and the `compost` category.
- `systems/`: `FilterRules`, `CompostRules`, `HazardRules`, `GridRules` with unit tests, following `SortingRules`.
- Content accuracy: before release, check each lesson against the UNEP SDG 12.4/12.5 pages and local municipal guidance. Rules vary by place, so word real-life tips as "follow your local scheme".
