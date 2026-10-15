import { readFileSync, readdirSync, lstatSync } from "node:fs";
import { relative, resolve } from "node:path";
import { assertPublic } from "./ingest";
const dist = resolve(process.env.ASTERIA_DIST || "dist");
export function audit(directory: string) {
  const files = (path: string): string[] =>
    readdirSync(path).flatMap((n) => {
      const p = resolve(path, n);
      const stat = lstatSync(p);
      if (stat.isSymbolicLink())
        throw new Error(`Public symlink refused: ${p}`);
      return stat.isDirectory() ? files(p) : [p];
    });
  const all = files(directory);
  for (const path of all) {
    const name = relative(directory, path).replaceAll("\\", "/");
    if (
      !/^(?:index\.html|favicon\.svg|assets\/[A-Za-z0-9_-]+\.(?:js|css)|fonts\/(?:(?:dm-sans-400-700|manrope-400-800|ibm-plex-mono-(?:400|500))-latin(?:-ext)?\.woff2|(?:dmsans|manrope|ibmplexmono)-OFL\.txt))$/.test(
        name,
      )
    )
      throw new Error(`Unapproved public path: ${name}`);
    if (!/\.(?:html|js|css|svg|woff2|txt)$/.test(path))
      throw new Error(`Unexpected public file: ${path}`);
    if (/\.(?:html|js|css|svg|txt)$/.test(path)) {
      const content = readFileSync(path, "utf8");
      assertPublic(content);
      for (const match of content.matchAll(
        /url\(["']?(\/Asteria\/[^)"']+)["']?\)/g,
      )) {
        if (
          !all.includes(resolve(directory, match[1].slice("/Asteria/".length)))
        )
          throw new Error(`Missing CSS asset: ${match[1]}`);
      }
      if (
        /-----BEGIN .*PRIVATE KEY|client-certificate-data:|client-key-data:|"terraform_version"\s*:|gh[pousr]_[A-Za-z0-9]{20}/.test(
          content,
        )
      )
        throw new Error(`Secret-like content: ${path}`);
    }
  }
  const html = readFileSync(resolve(directory, "index.html"), "utf8");
  for (const match of html.matchAll(/(?:src|href)="(\/Asteria\/[^"?#]+)"/g)) {
    const relative = match[1].slice("/Asteria/".length);
    if (!all.includes(resolve(directory, relative)))
      throw new Error(`Missing Pages asset: ${relative}`);
  }
  if (!html.includes('lang="fr"') || !html.includes("/Asteria/assets/"))
    throw new Error("Invalid Pages entry");
  return all.length;
}
if (process.argv[1]?.endsWith("audit-dist.ts"))
  console.log(
    `Public bundle audited: ${audit(dist)} allowlisted files, Pages assets resolved.`,
  );
