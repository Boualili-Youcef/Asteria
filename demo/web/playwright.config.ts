import { defineConfig, devices } from "@playwright/test";
export default defineConfig({
  testDir: "tests/e2e",
  timeout: 30000,
  fullyParallel: false,
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:4175",
    trace: "retain-on-failure",
    launchOptions: {
      executablePath: process.env.CHROME_BIN || "/usr/bin/google-chrome",
      args: ["--no-sandbox"],
    },
  },
  projects: [
    { name: "desktop", use: { ...devices["Desktop Chrome"] } },
    {
      name: "mobile",
      use: { ...devices["iPhone 13"], defaultBrowserType: "chromium" },
    },
  ],
  webServer: {
    command: "npm run preview",
    url: "http://127.0.0.1:4175/Asteria/",
    reuseExistingServer: true,
  },
});
