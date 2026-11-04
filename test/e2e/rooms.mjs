// Walks into buildings with real key presses: Tobi's house (radio puzzle,
// workbench), back out through the door, then down into the old metro.
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
const shot = (name) => page.screenshot({ path: `${OUT}/rooms_${name}.png` });
const check = (label, ok) => { checks.push({ label, ok: Boolean(ok) }); console.log(`${ok ? "PASS" : "FAIL"}  ${label}`); };
const drive = async (command, argument = "") => {
  await page.evaluate(([c, a]) => { window.driveResult = undefined; window.godotDrive(c, a); }, [command, argument]);
  return JSON.parse(await page.evaluate(() => window.driveResult));
};
const state = () => drive("state");
const press = async (key, ms = 70) => { await page.keyboard.press(key, { delay: ms }); await sleep(90); };
const closeDialogue = async () => { for (let i = 0; i < 20; i++) { if (!(await state()).dialogue_open) return; await press("e"); } };
const waitForArea = async (id) => { for (let i = 0; i < 40; i++) { if ((await state()).area === id) return true; await sleep(250); } return false; };

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
await closeDialogue();
await drive("peace");

check("the Outpost has three buildings", (await drive("goto", "Building:2")).moved);
// Buildings come in map order: the metro stairs, the shed, then Tobi's house.
await drive("goto", "Building:2");
await sleep(200);
await press("e");
check("the front door leads into a room", await waitForArea("tobi_house"));
await sleep(800);
await shot("1_inside");

await drive("goto", "Workbench");
await press("w", 60);
await press("e");
await sleep(300);
check("the workbench opens", (await state()).menu_open !== undefined);
await shot("2_workbench");
await press("Escape");
await sleep(300);

await drive("goto", "PuzzleStation");
await press("w", 60);
await press("e");
await sleep(600);
await shot("3_radio");
await press("Escape");
await sleep(400);

// Step onto the doormat and out through the door.
await drive("goto", "Door");
const below = (await state()).player;
await drive("warp", `${below.x},${below.y - 32}`);  // on the doormat, just inside
await sleep(300);
await page.keyboard.down("s");
await sleep(900);
await page.keyboard.up("s");
check("walking out of the door goes back outside", await waitForArea("outpost"));
s = await state();
check("you come out in front of the house", s.player && s.area === "outpost");
await shot("4_outside");

await drive("goto", "Building:0");
await sleep(200);
await press("e");
check("the metro stairs lead underground", await waitForArea("metro"));
await sleep(1200);
await shot("5_metro");

const failed = checks.filter((c) => !c.ok);
console.log(`\n${checks.length - failed.length}/${checks.length} checks passed`);
const serious = problems.filter((p) => !p.includes("favicon"));
if (serious.length) console.log("problems:\n" + serious.slice(0, 10).join("\n"));
await browser.close();
process.exit(failed.length || serious.length ? 1 : 0);
