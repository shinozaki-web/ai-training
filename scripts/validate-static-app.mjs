import { readFile, readdir } from "node:fs/promises";
import { access } from "node:fs/promises";
import path from "node:path";
import vm from "node:vm";

const root = process.cwd();
const files = await readdir(root);
const htmlFiles = files.filter((file) => file.endsWith(".html"));
const failures = [];

for (const file of htmlFiles) {
  const fullPath = path.join(root, file);
  const html = await readFile(fullPath, "utf8");

  for (const match of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    const target = match[1];
    if (/^(?:https?:|#|mailto:|javascript:)/.test(target)) continue;
    const cleanTarget = target.split(/[?#]/)[0];
    try {
      await access(path.join(root, cleanTarget));
    } catch {
      failures.push(`${file}: missing local asset ${cleanTarget}`);
    }
  }

  for (const [index, match] of [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].entries()) {
    const source = match[1].trim();
    if (!source) continue;
    try {
      new vm.Script(source, { filename: `${file}:inline-script-${index + 1}` });
    } catch (error) {
      failures.push(error.message);
    }
  }
}

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(`Validated ${htmlFiles.length} HTML files.`);
