import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
test("WCAG checks, keyboard focus and reduced motion", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  for (const view of [
    "overview",
    "architecture",
    "delivery",
    "incidents",
    "services",
    "engineering",
    "proofs",
  ]) {
    await page.goto(`/Asteria/?view=${view}`);
    await expect(page.locator("main h1")).toBeVisible();
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
      .analyze();
    expect
      .soft(
        results.violations.map((v) => ({
          id: v.id,
          nodes: v.nodes.map((n) => ({
            target: n.target,
            summary: n.failureSummary,
          })),
        })),
        view,
      )
      .toEqual([]);
  }
  await page.goto("/Asteria/");
  await page.keyboard.press("Tab");
  await expect(
    page.getByRole("link", { name: "Aller au contenu" }),
  ).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("#main")).toBeFocused();
});
