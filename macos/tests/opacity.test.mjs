import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const setter = path.resolve(here, "../scripts/set-opacity-macos.mjs");
const root = await fs.mkdtemp(path.join(os.tmpdir(), "dream-skin-opacity-"));
const themePath = path.join(root, "theme.json");

const run = (value) => new Promise((resolve, reject) => {
  const child = spawn(process.execPath, [setter, themePath, String(value)], { stdio: "ignore" });
  child.once("error", reject);
  child.once("close", resolve);
});

try {
  await fs.writeFile(themePath, JSON.stringify({
    schemaVersion: 1,
    id: "opacity-fixture",
    image: "background.jpg",
    art: { safeArea: "left" },
  }));
  assert.equal(await run(73), 0);
  const updated = JSON.parse(await fs.readFile(themePath, "utf8"));
  assert.equal(updated.art.opacity, 0.73);
  assert.equal(updated.art.safeArea, "left");
  assert.deepEqual((await fs.readdir(root)).sort(), ["theme.json"]);
  assert.notEqual(await run(101), 0);
  assert.equal(JSON.parse(await fs.readFile(themePath, "utf8")).art.opacity, 0.73);

  const concurrentValues = [10, 25, 50, 75, 90];
  const results = await Promise.all(concurrentValues.map(run));
  assert.ok(results.some((code) => code === 0));
  const concurrentTheme = JSON.parse(await fs.readFile(themePath, "utf8"));
  assert.ok(concurrentValues.includes(Math.round(concurrentTheme.art.opacity * 100)));
  assert.equal(concurrentTheme.art.safeArea, "left");
  assert.deepEqual((await fs.readdir(root)).sort(), ["theme.json"]);
} finally {
  await fs.rm(root, { recursive: true, force: true });
}

console.log("PASS: macOS opacity updates are atomic, bounded, concurrent-safe, and preserve theme metadata.");
