// Plays on an emulated phone held sideways (touch only, no keyboard): the
// title by tapping, the stick and the buttons with several fingers at once
// (through Chrome's DevTools touch input), the menu, a puzzle board by
// tapping, and the "turn your phone" screen in portrait.
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
const context = await browser.newContext({
  viewport: { width: 844, height: 390 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
  userAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36",
});
const page = await context.newPage();
page.on("pageerror", (e) => problems.push(`pageerror: ${e.message}`));
page.on("console", (m) => m.type() === "error" && problems.push(`console.error: ${m.text()}`));
const cdp = await context.newCDPSession(page);
const sleep = (ms) => page.waitForTimeout(ms);
const shot = (name) => page.screenshot({ path: `${OUT}/mobile_${name}.png` });
const check = (label, ok) => { checks.push({ label, ok: Boolean(ok) }); console.log(`${ok ? "PASS" : "FAIL"}  ${label}`); };
const drive = async (command, argument = "") => {
  await page.evaluate(([c, a]) => { window.driveResult = undefined; window.godotDrive(c, a); }, [command, argument]);
  return JSON.parse(await page.evaluate(() => window.driveResult));
};
const state = () => drive("state");

// Game pixels -> page pixels, through the canvas's place on the page.
let view = { w: 480, h: 270 };
const toPage = async (x, y) => {
  const rect = await page.evaluate(() => { const r = document.getElementById("canvas").getBoundingClientRect(); return { left: r.left, top: r.top, width: r.width, height: r.height }; });
  return { x: rect.left + (x * rect.width) / view.w, y: rect.top + (y * rect.height) / view.h };
};
// Fingers: the full set of points that are down after each change.
const fingers = new Map();
const sendFingers = async (type) => {
  const touchPoints = [...fingers.entries()].map(([id, p]) => ({ x: p.x, y: p.y, id, radiusX: 4, radiusY: 4, force: 1 }));
  await cdp.send("Input.dispatchTouchEvent", { type, touchPoints: type === "touchEnd" ? [] : touchPoints });
};
const down = async (id, x, y) => { fingers.set(id, await toPage(x, y)); await sendFingers("touchStart"); await sleep(60); };
const move = async (id, x, y) => { fingers.set(id, await toPage(x, y)); await sendFingers("touchMove"); await sleep(60); };
const up = async (id) => {
  fingers.delete(id);
  await sendFingers(fingers.size === 0 ? "touchEnd" : "touchMove");
  await sleep(60);
};
const tap = async (x, y, hold = 90) => { await down(9, x, y); await sleep(hold); await up(9); await sleep(120); };
const touch = async () => { const t = await drive("touch"); view = { w: t.view_w, h: t.view_h }; return t; };
const button = (t, id) => t.buttons.find((b) => b.id === id);
const tapButton = async (id, hold = 90) => {
  const t = await touch();
  const b = button(t, id);
  if (!b) return false;
  await tap(b.x, b.y, hold);
  return true;
};
const tapText = async (text) => {
  const at = await drive("button", text);
  if (!at.found) return false;
  await touch();
  await tap(at.x, at.y);
  return true;
};

await page.goto(process.env.GAME_URL, { waitUntil: "load" });
await page.waitForFunction(() => typeof window.godotDrive === "function", null, { timeout: 60000 });
await sleep(1500);
check("the page has a manifest for installing the app", await page.evaluate(() => Boolean(document.querySelector('link[rel="manifest"]'))));
await touch();
await tap(view.w / 2, 20);
await sleep(300);
let t = await touch();
check("touching the screen turns the touch controls on", t.active);
check("the picture widens to the phone's shape", t.view_w > 500);
await shot("1_title");

check("START answers a tap", await tapText("START"));
await sleep(600);
await shot("2_difficulty");
check("a difficulty answers a tap", await tapText("MEDIUM"));
let s;
for (let i = 0; i < 80 && !(s = await state()).area; i++) {
  if (s.scene === "Cutscene") {
    await shot("3_cutscene");
    await tapButton("back");
  }
  await sleep(250);
}
check("the run starts by touch alone", Boolean(s.area));
await sleep(800);
for (let i = 0; i < 25 && (await state()).dialogue_open; i++) {
  await tapButton("ok");
  await sleep(150);
}
check("conversations close with the OK button", !(await state()).dialogue_open);
await drive("peace");
await sleep(400);
t = await touch();
check("out in the world the play buttons are up", t.mode === "PLAY" && Boolean(button(t, "attack")) && Boolean(button(t, "interact")));
await shot("4_play");

// Walk with the left thumb.
const before = (await state()).player;
const stickAt = { x: 70, y: view.h - 60 };
await down(1, stickAt.x, stickAt.y);
for (let step = 1; step <= 6; step++) await move(1, stickAt.x + step * 6, stickAt.y);
await sleep(700);
await shot("5_walking");
// A second finger guards while the thumb keeps walking.
const guard = button(await touch(), "block");
await down(2, guard.x, guard.y);
await sleep(250);
const guarding = (await state()).player;
check("a second finger guards while walking", guarding.combat === "BLOCK");
await up(2);
await sleep(300);
const walked = (await state()).player;
await up(1);
check("the stick walks the player", walked.x - before.x > 12);
await sleep(300);
const resting = (await state()).player;
await sleep(400);
check("lifting the thumb stops", Math.abs((await state()).player.x - resting.x) < 2);

// The sword (a tap anywhere else must not swing it).
await tap(view.w * 0.62, view.h * 0.35);
await sleep(60);
check("a tap on open ground does not swing the sword", (await state()).player.combat !== "ATTACK");
await tapButton("attack", 40);
await sleep(30);
const swinging = (await state()).player.combat;
check("the sword button swings", swinging === "ATTACK" || (await state()).player.combat === "ATTACK");
await sleep(500);

// The menu, and back.
await tapButton("menu");
await sleep(400);
s = await state();
check("the menu button opens the menu", s.menu_open);
t = await touch();
check("over the menu the buttons turn into OK and BACK", t.mode === "PANEL" && Boolean(button(t, "back")) && Boolean(button(t, "ok")));
await shot("6_menu");
check("the OPTIONS tab answers a tap", await tapText("OPTIONS"));
await sleep(300);
const listTop = (await drive("scroll")).scroll;
await down(3, view.w / 2, view.h * 0.75);
for (let step = 1; step <= 8; step++) await move(3, view.w / 2, view.h * 0.75 - step * 12);
await up(3);
await sleep(300);
check("a swipe scrolls the options list", (await drive("scroll")).scroll > listTop);
await shot("6b_options");
await tapButton("back");
await sleep(400);
check("BACK closes the menu", !(await state()).menu_open);

// A board you play by tapping: the fuse box circuit.
await drive("puzzle", "shed_fusebox");
await sleep(500);
await shot("7_circuit");
t = await touch();
check("a puzzle board brings up OK and BACK", t.mode === "PANEL" && Boolean(button(t, "ok")));
await tapButton("back");
await sleep(400);
check("BACK leaves the puzzle", (await touch()).mode === "PLAY");

// Portrait: the page asks you to turn the phone.
await page.setViewportSize({ width: 390, height: 844 });
await sleep(500);
check("held upright, the page asks to turn the phone", await page.evaluate(() => getComputedStyle(document.getElementById("rotate")).display === "flex"));
await shot("8_portrait");
await page.setViewportSize({ width: 844, height: 390 });
await sleep(500);
check("held sideways, the game is back", await page.evaluate(() => getComputedStyle(document.getElementById("rotate")).display === "none"));

// Putting the app away saves the run and pauses it.
await page.evaluate(() => {
  Object.defineProperty(document, "visibilityState", { configurable: true, get: () => "hidden" });
  document.dispatchEvent(new Event("visibilitychange"));
});
await sleep(400);
s = await state();
check("hiding the page saves the run", s.has_save);
check("hiding the page opens the pause menu", s.menu_open);
await page.evaluate(() => {
  Object.defineProperty(document, "visibilityState", { configurable: true, get: () => "visible" });
  document.dispatchEvent(new Event("visibilitychange"));
});
await sleep(300);

const passed = checks.filter((c) => c.ok).length;
console.log(`\n${passed}/${checks.length} checks passed`);
console.log(problems.length ? `problems:\n${problems.join("\n")}` : "no console or page problems");
await browser.close();
process.exit(passed === checks.length && problems.length === 0 ? 0 : 1);
