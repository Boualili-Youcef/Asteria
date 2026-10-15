import { describe, it, expect } from "vitest";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { audit } from "../scripts/audit-dist";
function fixture(run: (dir: string) => void) {
  const dir = mkdtempSync(resolve(tmpdir(), "asteria-bundle-"));
  try {
    mkdirSync(resolve(dir, "assets"));
    writeFileSync(
      resolve(dir, "index.html"),
      '<html lang="fr"><script src="/Asteria/assets/main-test.js"></script></html>',
    );
    writeFileSync(resolve(dir, "assets/main-test.js"), "export {};");
    run(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
describe("public bundle boundary", () => {
  it("accepts only the declared asset layout", () =>
    fixture((dir) => expect(audit(dir)).toBe(2)));
  it("rejects an accidental JSON or arbitrary text export", () => {
    for (const name of ["evidence.json", "private-notes.txt"])
      fixture((dir) => {
        writeFileSync(resolve(dir, name), "unreviewed content");
        expect(() => audit(dir)).toThrow(/Unapproved public path/);
      });
  });
  it("rejects private addresses in compiled scripts", () =>
    fixture((dir) => {
      writeFileSync(
        resolve(dir, "assets/main-test.js"),
        'const endpoint="192.168.2.17"',
      );
      expect(() => audit(dir)).toThrow(/Non-public data/);
    }));
  it("checks CSS assets as well as the HTML entry", () =>
    fixture((dir) => {
      writeFileSync(
        resolve(dir, "assets/main-test.css"),
        "@font-face{src:url(/Asteria/fonts/missing.woff2)}",
      );
      expect(() => audit(dir)).toThrow(/Missing CSS asset/);
    }));
});
