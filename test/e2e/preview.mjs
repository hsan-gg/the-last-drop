// Screenshots an area of a preview build: spawn, then a short walk each way.
import { mkdirSync } from "node:fs";
import { chromium } from "playwright-core";

const URL = process.env.GAME_URL;
const OUT = process.env.OUT_DIR ?? "test/e2e/out";
const NAME = process.env.AREA ?? "area";
const CHROMIUM = process.env.CHROMIUM_PATH ?? "/usr/bin/chromium";
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({
  executablePath: CHROMIUM,
  headless: true,
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
await page.goto(URL, { waitUntil: "load" });
await page.waitForSelector("canvas", { timeout: 60000 });
await page.waitForTimeout(4000);
await page.mouse.click(480, 270);
for (let i = 0; i < 8; i++) {
  await page.keyboard.press("e");
  await page.waitForTimeout(450);
}
const shot = (suffix) => page.screenshot({ path: `${OUT}/preview_${NAME}_${suffix}.png` });
const walk = async (key, ms) => {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
  await page.waitForTimeout(300);
};
await shot("1_spawn");
await walk("d", 2200);
await shot("2_east");
await walk("w", 2200);
await shot("3_north");
await browser.close();
