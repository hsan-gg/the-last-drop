// Plays the whole game in a real browser: keyboard input for everything the
// player does, with the driver hook only teleporting the player beside objects.
import { mkdirSync } from "node:fs";
import { chromium } from "playwright-core";

const OUT = process.env.OUT_DIR ?? "test/e2e/out";
mkdirSync(OUT, { recursive: true });
const problems = [];
const checks = [];

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH ?? "/usr/bin/chromium",
  headless: true,
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
page.on("pageerror", (e) => problems.push(`pageerror: ${e.message}`));
page.on("console", (m) => m.type() === "error" && problems.push(`console.error: ${m.text()}`));

const sleep = (ms) => page.waitForTimeout(ms);
const shot = (name) => page.screenshot({ path: `${OUT}/play_${name}.png` });
const check = (label, ok) => {
  checks.push({ label, ok: Boolean(ok) });
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}`);
};
const drive = async (command, argument = "") => {
  await page.evaluate(([c, a]) => { window.driveResult = undefined; window.godotDrive(c, a); }, [command, argument]);
  return JSON.parse(await page.evaluate(() => window.driveResult));
};
const state = () => drive("state");
const press = async (key, ms = 90) => { await page.keyboard.press(key, { delay: ms }); await sleep(120); };
const until = async (predicate, label, timeout = 8000) => {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const s = await state();
    if (predicate(s)) return s;
    await sleep(150);
  }
  problems.push(`timed out waiting for: ${label}`);
  return state();
};
const goto = async (target) => {
  const r = await drive("goto", target);
  if (!r.moved) problems.push(`could not move to ${target}`);
  await sleep(250);
};
const closeDialogue = async () => {
  for (let i = 0; i < 20; i++) {
    const s = await state();
    if (!s.dialogue_open) return;
    await press("e");
  }
  problems.push("dialogue never closed");
};
const interact = async (target) => { await goto(target); await press("e"); };

// Sorts the open pile with the correct keys. Optionally gets the first item wrong on purpose.
const sortOpenPile = async ({ blunder = false } = {}) => {
  let wrongDone = false;
  for (let guard = 0; guard < 60; guard++) {
    const s = await state();
    const sort = s.sorting;
    if (!sort || !sort.phase) return;
    if (sort.phase === "CHOOSING") {
      if (blunder && !wrongDone && sort.key !== "1") {
        wrongDone = true;
        await press("1");
        const after = await state();
        check("a wrong bin costs health", after.health < s.health);
        continue;
      }
      await press(sort.key);
    } else {
      await press("e");
    }
  }
  problems.push("sorting never finished");
};
const answerQuizIfShown = async () => {
  await sleep(400);
  const s = await state();
  if (!s.quiz || !s.quiz.phase) return false;
  await press(s.quiz.answer_key);
  await press("e");
  return true;
};
const solvePuzzle = async () => {
  const s = await until((x) => x.puzzle && x.puzzle.phase === "SOLVING", "puzzle open");
  for (const key of s.puzzle.keys) await press(key);
  await until((x) => x.puzzle.phase === "SOLVED", "puzzle solved");
  await press("e");
};

// ---- title and outpost
await page.goto(process.env.GAME_URL, { waitUntil: "load" });
await page.waitForSelector("canvas", { timeout: 60000 });
await page.waitForFunction(() => typeof window.godotDrive === "function", null, { timeout: 60000 });
await sleep(1500);
await shot("1_title");
await page.mouse.click(480, 270);
await press("Enter");
let s = await until((x) => x.area === "outpost", "outpost loaded");
check("starts in the outpost", s.area === "outpost");
await closeDialogue();
await shot("2_outpost");

await interact("WaterSource");
await closeDialogue();
await interact("ScrapPile");
await until((x) => x.sorting.phase === "CHOOSING", "sorting open");
await shot("3_sorting");
await sortOpenPile({ blunder: true });
check("quiz appears after a pile", await answerQuizIfShown());
s = await state();
check("outpost pile sorted", s.flags.pile_sorted_outpost);
check("quiz answer counted", (s.counters.quiz_correct || 0) + (s.counters.quiz_wrong || 0) >= 1);

await interact("RepairStation");
await closeDialogue();
s = await state();
check("treatment unit repaired", s.flags.treatment_repaired);
await interact("WaterSource");
await closeDialogue();
await interact("Recording");
await closeDialogue();
await shot("4_recording");
await press("q");
await sleep(200);
await shot("5_journal");
await press("q");
await interact("AreaExit");
s = await until((x) => x.area === "factory", "factory loaded", 12000);
check("gate leads to the factory", s.area === "factory");
await closeDialogue();

// ---- factory
await interact("ScrapPile");
await until((x) => x.sorting.phase === "CHOOSING", "factory sorting");
await sortOpenPile();
await answerQuizIfShown();
await interact("RepairStation");
await closeDialogue();
await interact("ArchiveTerminal");
await shot("6_puzzle");
await solvePuzzle();
await closeDialogue();
s = await state();
check("archive read after the puzzle", s.flags.archive_read);
await interact("AreaExit");
s = await until((x) => x.area === "dump", "dump loaded", 12000);
check("gate leads to the dump", s.area === "dump");
await closeDialogue();
await shot("7_dump");

// ---- dump
for (let i = 0; i < 3; i++) {
  await interact("ScrapPile");
  await until((x) => x.sorting.phase === "CHOOSING", `dump pile ${i}`);
  await sortOpenPile();
  await answerQuizIfShown();
  await sleep(300);
}
for (const [type, index] of [["ItemPickup", 0], ["ItemPickup", 0], ["ItemPickup", 0]]) await interact(`${type}:${index}`);
s = await state();
check("hidden finds collected", (s.counters.pickups || 0) >= 3);
await interact("RepairStation");
await closeDialogue();
await interact("Recording");
await closeDialogue();
await interact("ArchiveTerminal");
await solvePuzzle();
await closeDialogue();
s = await state();
check("shelter rebuilt", s.flags.shelter_built);
check("municipal records read", s.flags.dump_records_read);
check("a side quest was completed", Object.keys(s.flags).some((k) => /^quest_.*_done$/.test(k)));
check("no sorting mistakes beyond the one blunder", (s.counters.sort_mistakes || 0) === 1);
await shot("8_dump_done");

// ---- ending
s = await until((x) => x.scene !== "Dump", "ending scene", 12000);
await sleep(800);
await shot("9_ending_choice");
await press("Enter");
await closeDialogue();
await sleep(600);
await shot("10_ending_final");
s = await state();
check("an ending was chosen", Object.keys(s.flags).some((k) => /^ending_/.test(k)));

const failed = checks.filter((c) => !c.ok);
console.log(`\n${checks.length - failed.length}/${checks.length} checks passed`);
console.log(problems.length ? `PROBLEMS:\n${problems.join("\n")}` : "no console, page or flow problems");
await browser.close();
process.exit(failed.length || problems.length ? 1 : 0);
