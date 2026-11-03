// Checks that music is really playing: player state, playback position and bus peaks.
import { chromium } from "playwright-core";
const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM_PATH ?? "/usr/bin/chromium",
  headless: true,
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--autoplay-policy=no-user-gesture-required"],
});
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
page.on("console", (m) => { if (/audio|Audio|error|ERROR/.test(m.text())) console.log("console:", m.text()); });
await page.goto(process.env.GAME_URL, { waitUntil: "load" });
await page.waitForFunction(() => typeof window.godotDrive === "function", null, { timeout: 60000 });
const state = async () => { await page.evaluate(() => window.godotDrive("state", "")); await page.waitForTimeout(150); return JSON.parse(await page.evaluate(() => window.driveResult)); };
await page.waitForTimeout(2500);
let s = await state();
console.log("before click", s.scene, s.music, JSON.stringify(s.audio));
await page.mouse.click(480, 270);
await page.waitForTimeout(2500);
s = await state();
console.log("after click", s.scene, s.music, JSON.stringify(s.audio));
const ctx = await page.evaluate(() => { try { return (window.Godot && "x") || typeof AudioContext; } catch (e) { return String(e); } });
console.log("ctx", ctx);
await browser.close();
