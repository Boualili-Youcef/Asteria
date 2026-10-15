import { chromium } from "../web/node_modules/playwright/index.mjs";
import AxeBuilder from "../web/node_modules/@axe-core/playwright/dist/index.mjs";
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BIN || "/usr/bin/google-chrome",
  args: ["--no-sandbox"],
});
try {
  for (const [label, viewport] of [
    ["desktop", { width: 1440, height: 1000 }],
    ["mobile", { width: 390, height: 844 }],
  ]) {
    const context = await browser.newContext({ viewport });
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (m) => {
      if (m.type() === "error") errors.push(m.text());
    });
    await page.goto("http://127.0.0.1:4180");
    const create = page.getByRole("button", { name: "Créer la commande →" });
    await create.waitFor();
    for (let i = 0; i < 30 && (await create.isDisabled()); i++)
      await page.waitForTimeout(500);
    if (await create.isDisabled())
      throw new Error("Real dependencies did not become ready");
    await create.click();
    await page.getByText("COMMANDE CRÉÉE ET RELUE").waitFor();
    await page
      .getByText("ARCHIVE CORRESPONDANTE OBSERVÉE")
      .waitFor({ timeout: 15000 });
    if (
      await page.evaluate(
        () => document.documentElement.scrollWidth > innerWidth,
      )
    )
      throw new Error("Horizontal overflow");
    const axe = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
      .analyze();
    if (axe.violations.length)
      throw new Error(
        JSON.stringify(
          axe.violations.map((v) => ({
            id: v.id,
            targets: v.nodes.map((n) => n.target),
          })),
        ),
      );
    if (errors.length) throw new Error(errors.join("\n"));
    await page.screenshot({
      path: `/tmp/asteria-playground-${label}.png`,
      fullPage: true,
    });
    console.log(
      `${label}: real creation/read/archive, WCAG scan, no JS errors, no overflow — passed`,
    );
    await context.close();
  }
} finally {
  await browser.close();
}
