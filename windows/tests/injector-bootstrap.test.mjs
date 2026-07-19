import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import { earlyPayloadFor } from "../scripts/injector.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const injectorPath = path.resolve(here, "../scripts/injector.mjs");
const source = await fs.readFile(injectorPath, "utf8");

function createFixture() {
  const observers = [];
  const timers = new Map();
  let nextTimer = 1;
  const markers = { shell: false, sidebar: false };
  const context = {
    window: { installs: [] },
    document: {
      documentElement: {},
      body: {},
      querySelector(selector) {
        if (selector === "main.main-surface") return markers.shell ? {} : null;
        if (selector === "aside.app-shell-left-panel") return markers.sidebar ? {} : null;
        return null;
      },
    },
    MutationObserver: class {
      constructor(callback) {
        this.callback = callback;
        this.connected = true;
        observers.push(this);
      }
      observe() {}
      disconnect() { this.connected = false; }
    },
    setTimeout(callback) {
      const id = nextTimer++;
      timers.set(id, callback);
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
  };
  return { context, markers, observers };
}

const guarded = createFixture();
vm.runInNewContext(earlyPayloadFor('window.installs.push("guarded")', "guarded"), guarded.context);
assert.deepEqual(guarded.context.window.installs, [], "Auxiliary app targets must remain untouched.");
guarded.markers.shell = true;
guarded.observers[0].callback([]);
assert.deepEqual(guarded.context.window.installs, ["guarded"],
  "A current Codex main surface must remain sufficient when the legacy sidebar is absent.");

const generations = createFixture();
vm.runInNewContext(earlyPayloadFor('window.installs.push("old")', "old"), generations.context);
vm.runInNewContext(earlyPayloadFor('window.installs.push("new")', "new"), generations.context);
generations.markers.shell = true;
generations.markers.sidebar = true;
for (const observer of generations.observers) observer.callback([]);
assert.deepEqual(
  generations.context.window.installs,
  ["new"],
  "A stale early script must yield to the newest watcher generation.",
);
assert.equal(generations.context.window.__CODEX_DREAM_SKIN_EARLY_APPLIED__, "new");

const registrationStart = source.indexOf("earlyScriptId = await registerEarlyPayload");
const evaluateStart = source.indexOf("await session.evaluate(earlyPayloadFor", registrationStart);
const probeStart = source.indexOf("const probe = await waitForCodexProbe", registrationStart);
const probeFunctionStart = source.indexOf("async function probeSession");
const probeFunctionEnd = source.indexOf("async function waitForCodexProbe", probeFunctionStart);
const probeSource = source.slice(probeFunctionStart, probeFunctionEnd);
assert.ok(registrationStart >= 0 && evaluateStart > registrationStart && probeStart > evaluateStart,
  "New targets must register and run the early payload before full shell probing.");
assert.ok(probeFunctionStart >= 0 && probeFunctionEnd > probeFunctionStart,
  "The Codex renderer probe must remain discoverable.");
assert.doesNotMatch(probeSource, /#root/,
  "An empty application root must not be accepted before the Codex main surface is ready.");
assert.match(probeSource, /main\.main-surface, \[role="main"\]/,
  "The renderer probe must wait for a real Codex main surface.");
assert.match(probeSource, /location\?\.protocol === 'app:'/,
  "Current Codex app renderers must remain discoverable after shell class changes.");
assert.match(source, /if \(earlyInjectionFallback\) attachLoadFallback\(/,
  "Load-event reinjection must be attached only when early injection falls back.");
assert.match(source, /if \(!fallbackTargets\.get\(id\)\) return;/,
  "Fallback listeners must stay inert after a successful early registration.");
assert.match(source, /Page\.removeScriptToEvaluateOnNewDocument/,
  "Watcher shutdown and theme refresh must unregister persistent Page scripts.");
assert.match(source, /opacity:\s*normalizedUnit\(art\.opacity, "art\.opacity"\)/,
  "Theme loading must preserve the tray-controlled background opacity.");
assert.match(source, /stabilityCheck = 'passed'/,
  "One-shot opacity refresh must remain stable before the tray reports synchronization.");
assert.match(source, /Math\.abs\(result\.artOpacity - expectedOpacity\)/,
  "One-shot verification must compare the rendered opacity with the saved theme value.");
assert.match(source, /options\.mode === "once"\)[\s\S]*?setTimeout\(resolve, 120\)/,
  "One-shot opacity application must not retain the old startup delay.");

console.log("PASS: Windows early injection waits for the main surface, is generation-safe, ordered before probing, and fallback-scoped.");
