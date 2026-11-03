// Screenshots the intro cutscene beat by beat (E advances, so each shot is a fresh beat).
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
await page.goto(process.env.GAME_URL, { waitUntil: "load" });
await page.waitForSelector("canvas", { timeout: 60000 });
await page.waitForTimeout(2500);
await page.mouse.click(480, 270);
for (let beat = 0; beat < 9; beat++) {
  await page.waitForTimeout(2600);
  await page.screenshot({ path: `${OUT}/cut_${beat}.png` });
  await page.keyboard.press("e");
  await page.waitForTimeout(150);
  await page.keyboard.press("e");
}
await browser.close();
