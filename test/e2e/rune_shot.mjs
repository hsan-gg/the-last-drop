// Grants the runes, holds the flamethrower, photographs the rune bar and gauge.
import { chromium } from "playwright-core";
const OUT = process.env.OUT_DIR ?? "test/e2e/out";
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH ?? "/usr/bin/chromium", headless: true,
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
const sleep = (ms) => page.waitForTimeout(ms);
const drive = async (c, a = "") => { await page.evaluate(([c, a]) => { window.driveResult = undefined; window.godotDrive(c, a); }, [c, a]); return JSON.parse(await page.evaluate(() => window.driveResult)); };
const press = async (k) => { await page.keyboard.press(k, { delay: 70 }); await sleep(90); };
await page.goto(process.env.GAME_URL, { waitUntil: "load" });
await page.waitForFunction(() => typeof window.godotDrive === "function", null, { timeout: 60000 });
await sleep(1500); await page.mouse.click(480, 270); await press("Enter"); await sleep(500); await press("Enter");
let s; for (let i = 0; i < 80 && !(s = await drive("state")).area; i++) { if (s.scene === "Cutscene") await press("Escape"); else await sleep(250); }
for (let i = 0; i < 20 && (await drive("state")).dialogue_open; i++) await press("e");
await drive("peace");
for (const r of ["ember", "scatter", "tide"]) await drive("rune", r);
await sleep(4000);
await page.keyboard.down("1");
await sleep(700);
await page.screenshot({ path: `${OUT}/rune_hold.png` });
await page.keyboard.up("1");
await sleep(3500);
await page.screenshot({ path: `${OUT}/rune_idle.png` });
await browser.close();
