import { spawn } from "node:child_process";
import { resolve } from "node:path";
import playwright from "../../apps/web_generator/node_modules/@playwright/test/index.js";

const { chromium } = playwright;

const root = resolve(import.meta.dirname, "../..");
const webRoot = resolve(root, "apps/web_generator");
const url = "http://127.0.0.1:4173/cycle/";
const warmups = Number(process.env.MEASURE_WARMUPS ?? 5);
const iterations = Number(process.env.MEASURE_ITERATIONS ?? 30);
const server = spawn(
  process.execPath,
  [resolve(webRoot, "node_modules/vite/bin/vite.js"), "--host", "127.0.0.1", "--port", "4173"],
  { cwd: webRoot, stdio: "ignore" },
);

try {
  await waitForServer();
  const browser = await chromium.launch({ headless: true });
  try {
    const firstLoadLocal = await samples(async () => {
      const context = await browser.newContext();
      const page = await context.newPage();
      const started = performance.now();
      await page.goto(url, { waitUntil: "networkidle" });
      await page.locator("html[data-cycle-ready='true']").waitFor();
      const elapsed = performance.now() - started;
      await context.close();
      return elapsed;
    });

    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto(url, { waitUntil: "networkidle" });
    await page.locator("html[data-cycle-ready='true']").waitFor();
    const generationStandard = await samples(() => measureGeneration(page));
    await page.getByTestId("template-row").getByRole("combobox").selectOption({ label: "Boring But Big" });
    await page.locator("[data-cycle-region='additional-options']").waitFor();
    const generationBbb = await samples(() => measureGeneration(page));
    await context.close();

    process.stdout.write(`${JSON.stringify({
      measuredAt: new Date().toISOString(),
      browser: "chromium",
      warmups,
      iterations,
      milliseconds: {
        firstLoadLocal: summarize(firstLoadLocal),
        generationStandard: summarize(generationStandard),
        generationBbb: summarize(generationBbb),
      },
    }, null, 2)}\n`);
  } finally {
    await browser.close();
  }
} finally {
  server.kill();
}

async function waitForServer() {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {
      // The Vite process has not bound its local port yet.
    }
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 50));
  }
  throw new Error("Local Vite server did not become ready");
}

async function samples(operation) {
  for (let index = 0; index < warmups; index += 1) await operation();
  const values = [];
  for (let index = 0; index < iterations; index += 1) values.push(await operation());
  return values;
}

async function measureGeneration(page) {
  return page.evaluate(() => new Promise((resolveMeasurement, reject) => {
    const status = document.querySelector("[data-cycle-region='status']");
    const title = document.querySelector(".output-title input");
    if (!(status instanceof HTMLElement) || !(title instanceof HTMLInputElement)) {
      reject(new Error("Generation controls unavailable"));
      return;
    }
    const started = performance.now();
    const observer = new MutationObserver(() => {
      if (!/up to date|à jour/i.test(status.textContent ?? "")) return;
      observer.disconnect();
      resolveMeasurement(performance.now() - started);
    });
    observer.observe(status, { childList: true, characterData: true, subtree: true });
    title.value = `${title.value.replace(/\s·\d+$/, "")} ·${Math.round(started)}`;
    title.dispatchEvent(new Event("input", { bubbles: true }));
  }));
}

function summarize(values) {
  const sorted = [...values].sort((left, right) => left - right);
  const quantile = (ratio) => sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * ratio))];
  return {
    median: round(quantile(0.5)),
    p95: round(quantile(0.95)),
    minimum: round(sorted[0]),
    maximum: round(sorted.at(-1)),
  };
}

function round(value) {
  return Math.round(value * 100) / 100;
}
