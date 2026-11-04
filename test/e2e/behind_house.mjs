// Walks to the Outpost house, takes a picture of its shaded front, then walks
// round behind it (the roof turns see-through) and takes another.
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
const check = (label, ok) => { checks.push(Boolean(ok)); console.log(`${ok ? "PASS" : "FAIL"}  ${label}`); };
const drive = async (command, argument = "") => {
  await page.evaluate(([c, a]) => { window.driveResult = undefined; window.godotDrive(c, a); }, [command, argument]);
  return JSON.parse(await page.evaluate(() => window.driveResult));
};
const state = () => drive("state");
const press = async (key, ms = 70) => { await page.keyboard.press(key, { delay: ms }); await sleep(90); };

await page.goto(process.env.GAME_URL, { waitUntil: "load" });
await page.waitForFunction(() => typeof window.godotDrive === "function", null, { timeout: 60000 });
await sleep(1500);
await page.mouse.click(480, 270);
await press("Enter");
await sleep(500);
await press("Enter");
let s;
for (let i = 0; i < 80 && !(s = await state()).area; i++) {
  if (s.scene === "Cutscene") await press("Escape");
  else await sleep(250);
}
for (let i = 0; i < 20 && (await state()).dialogue_open; i++) await press("e");
await drive("peace");

// Tobi's house is Building:2 (map order). Stand in front of it.
await drive("goto", "Building:2");
await sleep(500);
await page.screenshot({ path: `${OUT}/house_front.png` });
const door = (await state()).player;
// Walk up and round behind it: warp to the open ground beside, then up and in.
await drive("warp", `${door.x + 52},${door.y - 6}`);
await sleep(300);
await page.keyboard.down("w");
await sleep(1500);
await page.keyboard.up("w");
await page.keyboard.down("a");
await sleep(700);
await page.keyboard.up("a");
await sleep(600);
const behind = (await state()).player;
check("the player got up behind the house (above its door)", behind.y < door.y - 56);
await page.screenshot({ path: `${OUT}/house_behind.png` });

// Thirst and exhaustion warnings.
await drive("damage", "0");
await drive("water", "20");
await sleep(500);
await page.screenshot({ path: `${OUT}/warning_thirsty.png` });
{ const w = await state(); console.log("thirsty ->", JSON.stringify(w.warning), "nodes", w.warning_node, "water", w.water);
  check("no warning yet at 20 water", String(w.warning) === ""); }
await drive("water", "0");
await sleep(500);
await page.screenshot({ path: `${OUT}/warning_exhausted.png` });
{ const w = await state(); check("the warning shows once slowed, at 0 water", String(w.warning).startsWith("THIRSTY")); }

const passed = checks.filter(Boolean).length;
console.log(`${passed}/${checks.length} checks passed`);
console.log(problems.length ? `problems:\n${problems.join("\n")}` : "no console or page problems");
await browser.close();
process.exit(passed === checks.length && problems.length === 0 ? 0 : 1);
