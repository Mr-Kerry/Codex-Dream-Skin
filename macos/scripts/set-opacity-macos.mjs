import fs from "node:fs/promises";
import { randomUUID } from "node:crypto";

const [themePath, rawPercent] = process.argv.slice(2);
if (!themePath || rawPercent === undefined) throw new Error("Usage: set-opacity-macos.mjs <theme.json> <percent>");
const percent = Number(rawPercent);
if (!Number.isFinite(percent) || percent < 0 || percent > 100) throw new Error("Opacity must be between 0 and 100.");
const theme = JSON.parse(await fs.readFile(themePath, "utf8"));
if (!theme || typeof theme !== "object" || Array.isArray(theme)) throw new Error("Theme must be an object.");
theme.art = theme.art && typeof theme.art === "object" && !Array.isArray(theme.art) ? theme.art : {};
theme.art.opacity = Math.round(percent) / 100;
const temporary = `${themePath}.${process.pid}.${randomUUID()}.tmp`;
try {
  await fs.writeFile(temporary, `${JSON.stringify(theme, null, 2)}\n`, { mode: 0o600, flag: "wx" });
  await fs.rename(temporary, themePath);
  await fs.chmod(themePath, 0o600);
} finally {
  await fs.rm(temporary, { force: true }).catch(() => {});
}
