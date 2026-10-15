import { test, expect } from "@playwright/test";
import { existsSync } from "node:fs";
import { resolve } from "node:path";
test.beforeEach(async ({ page }) => {
  const errors: string[] = [];
  page.on("request", (request) => {
    if (
      /^https?:/.test(request.url()) &&
      new URL(request.url()).origin !== "http://127.0.0.1:4175"
    )
      errors.push(`Unexpected external request: ${request.url()}`);
  });
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => {
    if (m.type() === "error") errors.push(m.text());
  });
  await page.goto("/Asteria/");
  (page as unknown as { consoleErrors: string[] }).consoleErrors = errors;
});
test.afterEach(async ({ page }) => {
  expect(
    (page as unknown as { consoleErrors: string[] }).consoleErrors,
  ).toEqual([]);
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
});
test("overview, tour, URLs and browser history", async ({ page }) => {
  await expect(
    page.getByRole("heading", { name: /De l’infrastructure/ }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Explorer l’architecture", exact: true })
    .click();
  await expect(page).toHaveURL(/view=architecture/);
  await page.goBack();
  await expect(
    page.getByRole("heading", { name: /De l’infrastructure/ }),
  ).toBeVisible();
  await page.goto("/Asteria/?tour=1");
  await page.getByRole("button", { name: "Continuer" }).click();
  await expect(page.getByRole("heading", { name: /Le système/ })).toBeVisible();
  await page.getByRole("button", { name: "Fermer la visite guidée" }).click();
  await expect(page).not.toHaveURL(/tour=1/);
});
test("architecture node, keyboard, list, layers and edges", async ({
  page,
}) => {
  await page.goto("/Asteria/?view=architecture");
  if (
    (await page
      .getByRole("button", { name: "Mode liste" })
      .getAttribute("aria-pressed")) === "false"
  )
    await page.getByRole("button", { name: "Mode liste" }).click();
  await page.getByRole("button", { name: /Control plane K3s/ }).click();
  await expect(
    page.getByRole("heading", { name: "Responsabilité" }),
  ).toBeVisible();
  await expect(page).toHaveURL(/node=cp/);
  await page.getByRole("button", { name: "Fermer le détail" }).click();
  await page.getByRole("button", { name: "Applications & Data" }).click();
  await page
    .getByRole("button", { name: /orders-api démo asteria-demo/ })
    .click();
  await expect(
    page.getByText("Même API Orders déployée par Helm avec image immuable."),
  ).toBeVisible();
  await page.getByRole("button", { name: "Fermer le détail" }).click();
  await page.getByRole("button", { name: "Mode liste" }).click();
  const graphNode = page
    .locator(".react-flow__node")
    .filter({ hasText: "orders-api démo" });
  await graphNode.focus();
  await page.keyboard.press("Enter");
  await expect(
    page.getByRole("heading", { name: "orders-api démo" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Fermer le détail" }).click();
  await page.locator(".react-flow__edge").first().focus();
  await page.keyboard.press("Enter");
  await expect(page.getByText("FLUX SÉLECTIONNÉ")).toBeVisible();
});
test("delivery replay, real digest and scan", async ({ page }) => {
  await page.goto("/Asteria/?view=delivery&step=3");
  await expect(page.getByText("88 HIGH · 3 CRITICAL")).toBeVisible();
  await expect(page.getByText("Replay daté du 14/10/2026")).toBeVisible();
  await page.getByRole("button", { name: "Lire le replay" }).click();
  await page.getByRole("button", { name: "Pause", exact: true }).click();
  await page.getByRole("button", { name: "Étape suivante" }).click();
  await expect(
    page.getByRole("heading", { name: "Digest, SBOM & provenance" }),
  ).toBeVisible();
  await page.getByRole("button", { name: /10 Failure drill/ }).click();
  await expect(
    page.getByRole("heading", { name: "Échouer, revenir, revérifier" }),
  ).toBeVisible();
});
test("three incidents, measured event, comparison and probes", async ({
  page,
}) => {
  await page.goto("/Asteria/?view=incidents&step=4");
  await expect(page.getByText("rollback_verified")).toBeVisible();
  await expect(page.getByText("t + 209,504 s")).toBeVisible();
  await page.getByRole("button", { name: "Comparer avant / après" }).click();
  await expect(
    page.getByText(
      "Même digest sain avant/après, configuration de readiness rétablie.",
    ),
  ).toBeVisible();
  await page.getByRole("button", { name: /Redis non répondant/ }).click();
  await page.getByRole("button", { name: "Étape suivante" }).click();
  await page.getByRole("button", { name: "Étape suivante" }).click();
  await expect(
    page.getByRole("heading", { name: "/ready 503 · /health 200" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Inspecter les probes" }).click();
  await expect(page.getByText("GET /health → 200")).toBeVisible();
  await page.getByRole("button", { name: /Accès non autorisés/ }).click();
  await expect(page.getByText("Durée non mesurée")).toBeVisible();
});
test("service flow, engineering filters and evidence", async ({ page }) => {
  await page.goto("/Asteria/?view=services");
  await expect(page.getByText("Simulation pédagogique")).toBeVisible();
  await page.getByRole("button", { name: /01 POST order/ }).click();
  await page.getByRole("button", { name: "Suivant", exact: true }).click();
  await expect(page.getByText(/INSERT puis commit/)).toBeVisible();
  await page.goto("/Asteria/?view=engineering");
  await expect(page.getByText("22 constats affichés")).toBeVisible();
  await page.getByLabel("Rechercher les constats").fill("zzzz");
  await expect(page.getByText("Aucun constat ne correspond.")).toBeVisible();
  await page.getByRole("button", { name: "Réinitialiser les filtres" }).click();
  await page.getByLabel("Impact", { exact: true }).selectOption("Moyen");
  await expect(page.getByText("3 constats affichés")).toBeVisible();
  await page.goto("/Asteria/?view=proofs");
  await expect(
    page.getByRole("heading", {
      name: "Remonter à la source, sans raccourci.",
    }),
  ).toBeVisible();
  await page.goto("/Asteria/?view=unknown");
  await expect(page.getByRole("status")).toContainText(
    "Cette vue n’existe pas",
  );
});
test("screenshots, links and no horizontal overflow on all views", async ({
  page,
}, info) => {
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
    await page.evaluate(() => document.fonts.ready);
    await expect(page.locator("main h1")).toBeVisible();
    await page.screenshot({
      path: `test-results/${info.project.name}-${view}.png`,
      fullPage: true,
    });
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
      view,
    ).toBe(true);
    for (const a of await page.locator("a[href]").all()) {
      const href = await a.getAttribute("href");
      expect(href).not.toMatch(/undefined|\.\/\.\/|demo\/recruiter/);
      if (href?.startsWith("https://"))
        await expect(a).toHaveAttribute("rel", /noopener/);
      const sourcePrefix =
        "https://github.com/Boualili-Youcef/Asteria/blob/main/";
      if (href?.startsWith(sourcePrefix))
        expect(
          existsSync(
            resolve(
              process.cwd(),
              "../..",
              decodeURIComponent(href.slice(sourcePrefix.length)),
            ),
          ),
        ).toBe(true);
    }
  }
});
