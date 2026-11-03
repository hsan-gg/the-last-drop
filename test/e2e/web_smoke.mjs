import { mkdirSync } from "node:fs";
import { chromium } from "playwright-core";

const URL = process.env.GAME_URL ?? "http://127.0.0.1:8765/index.html";
const OUT = process.env.OUT_DIR ?? "test/e2e/out";
const CHROMIUM = process.env.CHROMIUM_PATH ?? "/usr/bin/chromium";
const problems = [];
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({
  executablePath: CHROMIUM,
  headless: true,
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"],
});
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });

page.on("pageerror", (e) => problems.push(`pageerror: ${e.message}`));
page.on("console", (m) => {
  if (m.type() === "error") problems.push(`console.error: ${m.text()}`);
});
page.on("requestfailed", (r) => problems.push(`requestfailed: ${r.url()}`));

const shot = (name) => page.screenshot({ path: `${OUT}/${name}.png` });
const tap = async (key, ms = 120) => {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
};

const t0 = Date.now();
await page.goto(URL, { waitUntil: "load" });
await page.waitForSelector("canvas", { timeout: 60000 });
await page.waitForTimeout(4000);
console.log(`canvas ready after ${((Date.now() - t0) / 1000).toFixed(1)}s`);
await shot("web_1_title");

await page.mouse.click(480, 270);
await page.keyboard.press("Enter");
await page.waitForTimeout(2500);
await shot("web_2_intro");

for (let i = 0; i < 4; i++) {
  await tap("e");
  await page.waitForTimeout(700);
}
await page.keyboard.down("d");
await page.waitForTimeout(1500);
await page.keyboard.up("d");
await shot("web_3_walk");

console.log(problems.length ? `PROBLEMS:\n${problems.join("\n")}` : "no console or page errors");
await browser.close();
process.exit(problems.length ? 1 : 0);
