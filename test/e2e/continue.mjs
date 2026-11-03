// Saves by playing into a region, reloads the page, and continues the run.
import { chromium } from "playwright-core";

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH ?? "/usr/bin/chromium",
  headless: true,
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
const sleep = (ms) => page.waitForTimeout(ms);
const drive = async (command, argument = "") => {
  await page.evaluate(([c, a]) => window.godotDrive(c, a), [command, argument]);
  await sleep(120);
  return JSON.parse(await page.evaluate(() => window.driveResult));
};
const state = () => drive("state");
const press = async (key) => { await page.keyboard.down(key); await sleep(60); await page.keyboard.up(key); await sleep(80); };
const checks = [];
const check = (label, ok) => { checks.push(ok); console.log(`${ok ? "PASS" : "FAIL"}  ${label}`); };
const boot = async () => {
  await page.goto(process.env.GAME_URL, { waitUntil: "load" });
  await page.waitForFunction(() => typeof window.godotDrive === "function", null, { timeout: 60000 });
  await sleep(1500);
  await page.mouse.click(480, 270);
};

await boot();
await press("Enter"); await sleep(400); await press("Enter");
for (let i = 0; i < 60 && !(await state()).area; i++) { if ((await state()).scene === "Cutscene") await press("Escape"); else await sleep(250); }
await drive("flag", "water_secure");
await drive("rune", "scatter");
await drive("scene", "factory");
for (let i = 0; i < 40 && (await state()).area !== "factory"; i++) await sleep(250);
await sleep(800);
let s = await state();
check("reached the factory", s.area === "factory");
check("a save was written", s.has_save);
await sleep(2500); // the browser's storage syncs a moment after the write

await boot();
s = await state();
console.log("after reload:", s.scene, "has_save", s.has_save, "persistent", s.userfs_persistent, "settings", s.settings_file);
await press("Enter"); // focus is on CONTINUE
for (let i = 0; i < 40 && !(await state()).area; i++) await sleep(250);
s = await state();
check("continuing returns to the factory", s.area === "factory");
check("the story so far is remembered", Boolean(s.flags.water_secure));
await browser.close();
console.log(`${checks.filter(Boolean).length}/${checks.length} checks passed`);
process.exit(checks.every(Boolean) ? 0 : 1);
