// Screenshots the new systems in action: runes, an NPC talking, the boss.
import { mkdirSync } from "node:fs";
import { chromium } from "playwright-core";

const OUT = process.env.OUT_DIR ?? "test/e2e/out";
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH ?? "/usr/bin/chromium",
  headless: true,
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
const errors = [];
page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
const sleep = (ms) => page.waitForTimeout(ms);
const drive = async (command, argument = "") => {
  await page.evaluate(([c, a]) => window.godotDrive(c, a), [command, argument]);
  await sleep(120);
  return JSON.parse(await page.evaluate(() => window.driveResult));
};
const state = () => drive("state");
const shot = (name) => page.screenshot({ path: `${OUT}/show_${name}.png` });
const press = async (key, hold = 60) => { await page.keyboard.down(key); await sleep(hold); await page.keyboard.up(key); await sleep(80); };
const closeDialogue = async () => { for (let i = 0; i < 20; i++) { if (!(await state()).dialogue_open) return; await press("e"); } };

await page.goto(process.env.GAME_URL, { waitUntil: "load" });
await page.waitForFunction(() => typeof window.godotDrive === "function", null, { timeout: 60000 });
await sleep(1500);
await page.mouse.click(480, 270);
await press("Enter"); await sleep(400); await press("Enter");
for (let i = 0; i < 60 && !(await state()).area; i++) { if ((await state()).scene === "Cutscene") await press("Escape"); else await sleep(250); }
await closeDialogue();
for (const rune of ["ember", "scatter", "tide"]) await drive("rune", rune);
await sleep(4500); // let the rune cards pass
await drive("scene", "industry");
for (let i = 0; i < 40 && (await state()).area !== "industry"; i++) await sleep(250);
await closeDialogue();
await sleep(1200);
await shot("1_industry_arrival");
await drive("goto", "Npc:1");
await press("e");
await sleep(900);
await shot("2_npc_talk");
await closeDialogue();
await drive("goto", "Enemy:0");
await sleep(200);
await page.keyboard.down("d"); await sleep(80); await page.keyboard.up("d");
await page.keyboard.down("1");
await sleep(700);
await shot("3_flamethrower");
await page.keyboard.up("1");
await sleep(500);
await shot("4_burning");
await press("2", 40);
await sleep(30);
await shot("5_shotgun");
await sleep(600);
await press("3", 40);
await sleep(120);
await shot("6_tide");
let s = await state();
const golem = s.enemies.findIndex((e) => e.id === "golem");
if (golem >= 0) {
  await drive("goto", `Enemy:${golem}`);
  await sleep(300);
  await press("j"); await sleep(300); await press("j");
  await sleep(600);
  await shot("7_boss");
}
console.log(errors.length ? `ERRORS:\n${errors.slice(0, 10).join("\n")}` : "no console errors");
await browser.close();
