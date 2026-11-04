// Captures the sword swing frame by frame (time slowed right down) in each
// direction, plus the guard, for a visual check of the animation.
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
page.on("console", (m) => { if (m.type() === "error" || m.text().includes("ERROR")) console.log("console:", m.text().slice(0, 300)); });
const sleep = (ms) => page.waitForTimeout(ms);
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
const spawn = (await state()).player;
await drive("peace");
await drive("goto", "Chest");
await press("e");
for (let i = 0; i < 20 && (await state()).dialogue_open; i++) await press("e");
await drive("warp", `${spawn.x},${spawn.y}`);
await sleep(600);
const me = (await state()).player;
const cx = Math.round(me.screen_u * 960), cy = Math.round(me.screen_v * 540);
const clip = { x: Math.max(cx - 60, 0), y: Math.max(cy - 70, 0), width: 120, height: 100 };
console.log("player on screen at", cx, cy);
for (const [key, name] of [["d", "right"], ["s", "down"], ["a", "left"], ["w", "up"]]) {
  await press(key, 40);
  await sleep(200);
  await drive("timescale", "0.12");
  await page.keyboard.press("j");
  for (let f = 0; f < 8; f++) {
    await page.screenshot({ path: `${OUT}/swing_${name}_${f}.png`, clip });
    await sleep(110);
  }
  await drive("timescale", "1");
  await sleep(600);
}
await page.keyboard.down("k");
await sleep(80);
await page.screenshot({ path: `${OUT}/swing_guard.png`, clip });
await page.keyboard.up("k");
await browser.close();
