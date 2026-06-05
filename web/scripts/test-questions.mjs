// Fast headless check (AI coach OFF) that the daily check-in questions are
// personalized to the user's purpose and ritual goals. No WebGPU/model needed.

import { chromium } from "playwright";

const URL = "http://localhost:5173";
const PURPOSE = "Be present for my kids while building something that matters";
const GOALS = {
  physical: "lights out by 11pm and a 15-min morning walk",
  emotional: "one gratitude note before bed",
  mental: "one phone-free 90-min focus block",
  spiritual: "five quiet minutes on what matters",
};

const log = (...a) => console.log(...a);
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage();

try {
  await page.goto(URL, { waitUntil: "domcontentloaded" });

  // Onboarding step 0 — set purpose.
  await page.locator("textarea").first().fill(PURPOSE);
  await page.getByRole("button", { name: "Next" }).click();

  // Step 1 — ritual goals (inputs are in ENERGIES order: phys, emo, men, spi).
  const inputs = page.locator('input[type="text"]');
  await inputs.nth(0).fill(GOALS.physical);
  await inputs.nth(1).fill(GOALS.emotional);
  await inputs.nth(2).fill(GOALS.mental);
  await inputs.nth(3).fill(GOALS.spiritual);
  await page.getByRole("button", { name: "Next" }).click();

  // Step 2 — finish.
  await page.getByRole("button", { name: "Begin" }).click();

  // Open the check-in.
  await page.getByRole("button", { name: /daily check-in/i }).click();
  await page.getByText("How is your energy today?").waitFor({ timeout: 10000 });

  const purposeLine = await page.locator("p.italic").first().textContent().catch(() => "");
  const questions = await page.locator("p.text-\\[16px\\]").allTextContents();

  log("\n── PURPOSE REMINDER ──");
  log(purposeLine?.trim());
  log("\n── CHECK-IN QUESTIONS ──");
  questions.forEach((q, i) => log(`${i + 1}. ${q.trim()}`));

  // Assertions.
  const joined = questions.join("\n");
  const checks = [
    ["physical goal woven in", joined.includes(GOALS.physical)],
    ["emotional goal woven in", joined.includes(GOALS.emotional)],
    ["mental goal woven in", joined.includes(GOALS.mental)],
    ["spiritual goal woven in", joined.includes(GOALS.spiritual)],
    ["purpose woven into spiritual q", joined.includes(PURPOSE)],
    ["purpose reminder shown", (purposeLine ?? "").includes(PURPOSE)],
  ];
  log("\n── CHECKS ──");
  let allPass = true;
  for (const [name, ok] of checks) {
    log(`${ok ? "✓" : "✗"} ${name}`);
    if (!ok) allPass = false;
  }
  log(`\n${allPass ? "ALL CHECKS PASSED" : "SOME CHECKS FAILED"}`);
  process.exitCode = allPass ? 0 : 1;
} finally {
  await browser.close();
}
