// Fights in a real browser: finds the sword, kills a zombie with real key
// presses, raises the guard against another, and checks XP and health.
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
const shot = (name) => page.screenshot({ path: `${OUT}/combat_${name}.png` });
const check = (label, ok) => { checks.push({ label, ok: Boolean(ok) }); console.log(`${ok ? "PASS" : "FAIL"}  ${label}`); };
const drive = async (command, argument = "") => {
  await page.evaluate(([c, a]) => { window.driveResult = undefined; window.godotDrive(c, a); }, [command, argument]);
  return JSON.parse(await page.evaluate(() => window.driveResult));
};
const state = () => drive("state");
const press = async (key, ms = 70) => { await page.keyboard.press(key, { delay: ms }); await sleep(90); };
const closeDialogue = async () => { for (let i = 0; i < 20; i++) { if (!(await state()).dialogue_open) return; await press("e"); } };
const nearestEnemy = (s) => {
  const live = s.enemies.filter((e) => e.state !== "DEAD");
  live.sort((a, b) => Math.hypot(a.x - s.player.x, a.y - s.player.y) - Math.hypot(b.x - s.player.x, b.y - s.player.y));
  return live[0];
};
// Turns the player toward a point by tapping the matching movement key.
const faceToward = async (s, target) => {
  const dx = target.x - s.player.x, dy = target.y - s.player.y;
  const key = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "d" : "a") : (dy > 0 ? "s" : "w");
  await press(key, 40);
};

await page.goto(process.env.GAME_URL, { waitUntil: "load" });
await page.waitForSelector("canvas", { timeout: 60000 });
await page.waitForFunction(() => typeof window.godotDrive === "function", null, { timeout: 60000 });
await sleep(1500);
await page.mouse.click(480, 270);
await press("Enter");
let s;
for (let i = 0; i < 80 && !(s = await state()).area; i++) {
  if (s.scene === "Cutscene") await press("Escape");
  else await sleep(250);
}
await closeDialogue();
s = await state();
check("zombies exist in a started run", s.enemies.length >= 2);
check("the player starts unarmed", s.player.weapon === "fists");

await drive("goto", "Chest");
await sleep(250);
await press("e");
await closeDialogue();
s = await state();
check("the chest gives a sword", s.player.weapon === "rusty_sword");
await shot("1_armed");

// Fight the nearest zombie with real keys.
await drive("goto", "Enemy:0");
await sleep(150);
let startHealth = (await state()).player.health;
for (let round = 0; round < 60; round++) {
  s = await state();
  const target = nearestEnemy(s);
  if (!target || s.counters.kills >= 1) break;
  await faceToward(s, target);
  await press("j", 60);
  if (round === 1) await shot("2_swing");
  await sleep(150);
}
s = await state();
check("a zombie was killed with the sword", (s.counters.kills || 0) >= 1);
check("killing it paid XP", s.player.xp > 0 || s.player.level > 1);
await shot("3_victory");

// Raise the guard against the next zombie and take its strike.
await drive("goto", "Enemy:0");
await sleep(150);
let guarded = false;
for (let round = 0; round < 40 && !guarded; round++) {
  s = await state();
  const target = nearestEnemy(s);
  if (!target) break;
  await faceToward(s, target);
  await page.keyboard.down("k");
  await sleep(700);
  s = await state();
  guarded = (s.counters.blocks || 0) + (s.counters.parries || 0) >= 1;
  if (round === 2) await shot("4_guarding");
  await page.keyboard.up("k");
  await sleep(100);
}
check("the guard blocked or parried a strike", guarded);

s = await state();
check("the player is still standing (collapses recover)", s.player.health > 0);
await shot("5_end");
const failed = checks.filter((c) => !c.ok);
console.log(`\n${checks.length - failed.length}/${checks.length} checks passed`);
console.log(problems.length ? `PROBLEMS:\n${problems.join("\n")}` : "no console or page problems");
await browser.close();
process.exit(failed.length || problems.length ? 1 : 0);
