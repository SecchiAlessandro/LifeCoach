// Drives the running dev server (http://localhost:5173) through onboarding →
// enable on-device AI coach → wait for the WebLLM model to load → run a
// check-in → capture the AI-generated coaching. Uses the system Chrome (headed,
// its own temp profile) so WebGPU is available.

import { chromium } from "playwright";

const URL = "http://localhost:5173";
const SHOT = "/tmp/fe_ai_coach.png";

const log = (...a) => console.log(`[${new Date().toLocaleTimeString()}]`, ...a);

const browser = await chromium.launch({
  channel: "chrome",
  headless: false,
  args: ["--enable-unsafe-webgpu", "--ignore-gpu-blocklist"],
});
const page = await browser.newPage();
page.on("console", (m) => {
  const t = m.text();
  if (/error|fail|webgpu|gpu/i.test(t)) log("  console:", t.slice(0, 200));
});

try {
  log("WebGPU check…");
  await page.goto(URL, { waitUntil: "domcontentloaded" });
  const hasGPU = await page.evaluate(() => "gpu" in navigator);
  log("navigator.gpu present:", hasGPU);

  // --- Onboarding (fresh profile → IndexedDB empty) ---
  log("Onboarding…");
  await page.getByRole("button", { name: "Next" }).click();
  await page.getByRole("button", { name: "Next" }).click();
  await page.getByRole("button", { name: "Begin" }).click();
  await page.getByRole("button", { name: /daily check-in/i }).waitFor({ timeout: 15000 });
  log("  onboarded → dashboard");

  // --- Settings → enable AI coach ---
  log("Enabling AI coach…");
  await page.getByRole("button", { name: "Settings" }).click();
  await page.getByRole("switch").click();

  // Wait for model ready, logging progress.
  log("Loading model (this downloads ~350MB once)…");
  let lastText = "";
  const ready = await (async () => {
    for (let i = 0; i < 240; i++) { // up to ~12 min
      const err = await page.locator("text=/WebGPU|error/i").first().textContent().catch(() => null);
      if (await page.getByText(/Model ready/i).count()) return true;
      const prog = await page
        .locator("text=/fetched|completed|Loading|Fetching|param cache|GPU shader/i")
        .first()
        .textContent()
        .catch(() => null);
      if (prog && prog !== lastText) {
        lastText = prog;
        log("  ", prog.slice(0, 110));
      }
      if (err && /WebGPU isn't|Error|failed/i.test(err)) {
        log("  ERROR:", err);
        return false;
      }
      await page.waitForTimeout(3000);
    }
    return false;
  })();

  if (!ready) {
    log("Model did not reach ready state.");
    await page.screenshot({ path: SHOT, fullPage: true });
    throw new Error("model-not-ready");
  }
  log("Model ready ✓");

  // --- Today → run a check-in ---
  log("Running a check-in…");
  await page.getByRole("button", { name: "Today" }).click();
  await page.getByRole("button", { name: /daily check-in/i }).click();
  await page.getByText("How is your energy today?").waitFor({ timeout: 10000 });
  // Leave sliders at their default (5) and submit.
  await page.getByRole("button", { name: /See my energy/i }).click();

  // Wait for generation to finish (modal closes, coach card shows · AI).
  await page.getByText("· AI").waitFor({ timeout: 120000 });
  log("AI coaching generated ✓");

  // Extract the coach card text.
  const coaching = await page.evaluate(() => {
    const ps = Array.from(document.querySelectorAll("p"));
    // The coaching prose is the longest paragraph on the dashboard.
    const txt = ps.map((p) => p.textContent || "").sort((a, b) => b.length - a.length)[0] || "";
    return txt.trim();
  });
  log("──────── AI COACH OUTPUT ────────");
  console.log(coaching);
  log("─────────────────────────────────");

  await page.screenshot({ path: SHOT, fullPage: true });
  log("Screenshot:", SHOT);
} finally {
  await browser.close();
}
