// Opens each kind of hands-on puzzle and photographs it, for a visual check.
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
page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
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
await drive("peace");
await sleep(3000);
for (const id of ["seed_pairs", "shed_fusebox", "halden_safe", "dump_pairs", "compost_mix", "dump_line", "river_pumps"]) {
  await drive("puzzle", id);
  await sleep(700);
  if (id === "seed_pairs") { for (const k of ["e", "ArrowRight", "e"]) await press(k); await sleep(150); }
  if (id === "dump_pairs") { await press("e"); await press("ArrowRight"); await press("e"); await sleep(200); }
  if (id === "compost_mix") { await press("ArrowRight"); await press("ArrowRight"); await press("ArrowDown"); await press("ArrowRight"); await press("e"); }
  if (id === "shed_fusebox") { await press("e"); await press("ArrowRight"); }
  if (id === "dump_line") await sleep(1800);
  await page.screenshot({ path: `${OUT}/mini_${id}.png` });
  await press("Escape");
  await sleep(400);
}
await drive("craft");
await sleep(500);
await page.screenshot({ path: `${OUT}/mini_workbench.png` });
await press("Escape");
console.log(errors.length ? "errors:\n" + errors.slice(0, 5).join("\n") : "no errors");
await browser.close();
