// Lives, game over and conversations in a real browser: dialogue must not freeze
// the world, a hit must cut it short, and three collapses must end the run.
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
const shot = (name) => page.screenshot({ path: `${OUT}/survival_${name}.png` });
const check = (label, ok) => { checks.push({ label, ok: Boolean(ok) }); console.log(`${ok ? "PASS" : "FAIL"}  ${label}`); };
const drive = async (command, argument = "") => {
  await page.evaluate(([c, a]) => { window.driveResult = undefined; window.godotDrive(c, a); }, [command, argument]);
  return JSON.parse(await page.evaluate(() => window.driveResult));
};
const state = () => drive("state");
const press = async (key, ms = 70) => { await page.keyboard.press(key, { delay: ms }); await sleep(90); };
const until = async (predicate, label, timeout = 15000) => {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    const s = await state();
    if (predicate(s)) return s;
    if (s.scene === "Cutscene") await press("Escape");
    else await sleep(150);
  }
  problems.push(`timed out waiting for: ${label}`);
  return state();
};

await page.goto(process.env.GAME_URL, { waitUntil: "load" });
await page.waitForSelector("canvas", { timeout: 60000 });
await page.waitForFunction(() => typeof window.godotDrive === "function", null, { timeout: 60000 });
await sleep(1500);
await page.mouse.click(480, 270);
await press("Enter");
await sleep(500);
await press("Enter"); // confirm Medium
let s = await until((x) => x.area === "outpost" && x.dialogue_open, "outpost with its arrival dialogue");
check("a new run starts with three lives", s.player.lives === 3);
check("the arrival conversation is open", s.dialogue_open);

// The world keeps moving during a conversation.
const before = s.player.x;
await page.keyboard.down("d");
await sleep(500);
await page.keyboard.up("d");
s = await state();
check("the player can walk while a conversation is open", s.dialogue_open && Math.abs(s.player.x - before) > 5);
await shot("1_talking_and_walking");

// Being hit ends the conversation.
await drive("damage", "5");
await sleep(200);
s = await state();
check("being hit cuts the conversation short", !s.dialogue_open);

// Three collapses end the run.
await drive("damage", "1000");
await sleep(500);
s = await state();
check("a collapse costs a life", s.player.lives === 2);
await shot("2_life_lost");
await drive("damage", "1000");
await sleep(500);
s = await state();
check("another collapse costs another", s.player.lives === 1);
await drive("damage", "1000");
s = await until((x) => x.scene === "GameOver", "the game over screen");
check("losing the last life shows game over", s.scene === "GameOver");
await shot("3_game_over");
s = await until((x) => x.area === "outpost" && x.player.lives === 3, "the run restarting", 20000);
check("the run restarts with three lives", s.area === "outpost" && s.player.lives === 3);

const failed = checks.filter((c) => !c.ok);
console.log(`\n${checks.length - failed.length}/${checks.length} checks passed`);
console.log(problems.length ? `PROBLEMS:\n${problems.join("\n")}` : "no console or page problems");
await browser.close();
process.exit(failed.length || problems.length ? 1 : 0);
