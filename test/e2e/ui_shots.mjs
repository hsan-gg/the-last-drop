// Screenshots the UI preview scene once per state (three seconds apart).
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
const names = ["menu_inventory", "menu_quests", "menu_options", "menu_controls", "menu_codex", "hud_tracker", "extra"];
await page.waitForTimeout(3600);
for (const name of names) {
  await page.screenshot({ path: `${OUT}/ui_${name}.png` });
  await page.waitForTimeout(2400);
}
await browser.close();
