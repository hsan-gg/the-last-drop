# Roadmap

Deadline: three weeks from 2026-11-03. Every region is built to the same bar:
one new mechanic, one repair with a survival benefit, one recording, lessons
that follow Encounter, Experiment, Consequence, Principle, Real life.

## Definition of done for a chapter

1. Map (`tools/generate_maps.py`, then hand-polished) passes the reachability test.
2. Items, lessons, repair, objectives, dialogue in `data/`; `chapters.json` status `built`.
3. Rule classes in `systems/` with unit tests; scenes only present them.
4. Placeholder art in `tools/assets_*.py`, replaced by the chosen style pack later.
5. A scripted playthrough in `test/integration/`.
6. `bash scripts/test.sh` and `bash scripts/e2e.sh` both green.

## Status

| Chapter | Status |
|---|---|
| 0 Outpost, 1 Factory | built |
| 2 Great Dump | built (compost bin, shelter roof) |
| 3 Dead River | next: filter-chain mechanic (`FilterRules`) |
| 4 Silent Fields | compost cycle (`CompostRules`) |
| 5 Forgotten Industry | hazard scan and power grid (`HazardRules`, `GridRules`) |
| 6 Last Sanctuary | archive timeline, Preserve or Share, final ending |

## Cross-cutting, after the chapters

- Save and load; options menu with Juicee accessibility toggles.
- Art pass in the chosen style, audio pass, lighting.
- Touch controls and mobile layout for the web build.
- Content accuracy review of every lesson against UNEP and local guidance.
