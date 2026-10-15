import { describe, it, expect } from "vitest";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { assertPublic, readInputs, root, transform } from "../scripts/ingest";
import { nodes, edges } from "../scripts/topology";
import { manifestSchema } from "../src/schema";
describe("public evidence contract", () => {
  it("rejects empty runtime IDs, CI jobs and Docker checks", () => {
    let raw = readInputs();
    raw.flow.promotion.runtime_image_ids = [];
    expect(() => transform(raw)).toThrow(/executed digest/);
    raw = readInputs();
    raw.ci.jobs = [];
    expect(() => transform(raw)).toThrow(/required steps/);
    raw = readInputs();
    raw.docker.checks = [];
    expect(() => transform(raw)).toThrow(/required checks/);
  });
  it("rejects missing RBAC checks and invalid event times", () => {
    let raw = readInputs();
    delete raw.flow.bounded_operator.rbac_checks_passed["delete nodes"];
    expect(() => transform(raw)).toThrow();
    raw = readInputs();
    raw.flow.failure_events[1].elapsed_seconds = -1;
    expect(() => transform(raw)).toThrow(/event timing/);
  });
  it("never forwards unknown nested RBAC metadata", () => {
    const raw = readInputs();
    raw.flow.bounded_operator.rbac_checks_passed[
      "private operator annotation"
    ] = true;
    expect(JSON.stringify(transform(raw))).not.toContain(
      "private operator annotation",
    );
  });
  it("binds the CI, runtime, rollback and business proof", () => {
    const m = transform(readInputs());
    expect(m.metrics.orders).toBe(3);
    expect(m.metrics.archives).toBe(3);
    expect(m.release.run_id).toBe("38622409565");
    expect(m.events.at(-1)?.seconds).toBe(209.504);
    expect(m.metrics.rollback).toBe(209.505);
  });
  it.each([
    "flow",
    "ci",
    "release",
    "docker",
    "presentation",
    "cloud",
    "runtime",
  ])("rejects missing %s", (key) => {
    const raw = readInputs();
    delete raw[key];
    expect(() => transform(raw)).toThrow();
  });
  it.each([
    "promotion",
    "failure_drill",
    "post_promotion_functional",
    "post_rollback_functional",
  ])("rejects a release mismatch at %s", (key) => {
    const raw = readInputs();
    raw.flow[key].release.digest = "sha256:" + "0".repeat(64);
    expect(() => transform(raw)).toThrow();
  });
  it.each(["run_id", "commit", "image"])("rejects CI %s mismatch", (key) => {
    const raw = readInputs();
    raw.ci[key] = "mismatch";
    expect(() => transform(raw)).toThrow(/CI identity/);
  });
  it("rejects digest published but not executed", () => {
    const raw = readInputs();
    raw.flow.promotion.runtime_image_ids = ["wrong"];
    expect(() => transform(raw)).toThrow(/executed digest/);
  });
  it("rejects rollback failure and a false unchanged history assertion", () => {
    let raw = readInputs();
    raw.flow.failure_drill.status = "failed";
    expect(() => transform(raw)).toThrow(/rollback/);
    raw = readInputs();
    raw.flow.historical_workloads_modified = true;
    expect(() => transform(raw)).toThrow(/historical safety/);
  });
  it("rejects fabricated verified scans and unarchived commands", () => {
    let raw = readInputs();
    raw.ci.scan.high_findings = 1;
    expect(() => transform(raw)).toThrow(/CI gates/);
    raw = readInputs();
    raw.flow.post_rollback_functional.archived_notifications_for_id = 0;
    expect(() => transform(raw)).toThrow(/matching archives/);
  });
  it("never forwards unknown private report fields", () => {
    const raw = readInputs();
    raw.flow.password = "should-never-be-public";
    raw.cloud.private_network = "192.168.10.23";
    const m = transform(raw);
    expect(JSON.stringify(m)).not.toContain("should-never");
    expect(JSON.stringify(m)).not.toContain("192.168.10.23");
  });
  it.each([
    { password: "secret" },
    { token: "sensitive" },
    { ip: "192.168.1.50" },
    { private_key: "key" },
  ])("rejects non-public data %j", (input) => {
    expect(() => assertPublic(input)).toThrow();
  });
  it("keeps historical, proposal and pedagogical labels distinct", () => {
    const m = transform(readInputs());
    expect(m.nodes.find((n) => n.id === "staging")?.kind).toBe("historical");
    expect(m.nodes.find((n) => n.id === "target")?.kind).toBe("proposal");
    expect(
      m.sources.find((s) => s.path.endsWith("presentation.json"))?.kind,
    ).toBe("pedagogical");
    expect(m.nodes.find((n) => n.id === "flannel")?.scope).toBe("source");
  });
  it("strict schema rejects extra public fields", () => {
    expect(() =>
      manifestSchema.parse({
        ...transform(readInputs()),
        secret: "unexpected",
      }),
    ).toThrow();
  });
  it("links only to existing repository sources and complete node pairs", () => {
    for (const n of nodes) {
      for (const path of n.sources) {
        expect(existsSync(resolve(root, path)), path).toBe(true);
      }
    }
    for (const e of edges) {
      expect(nodes.some((n) => n.id === e.from)).toBe(true);
      expect(nodes.some((n) => n.id === e.to)).toBe(true);
    }
  });
  it("all service endpoints shown exist in the real application code", () => {
    for (const [app, route] of [
      ["orders-api", "/api/v1/orders"],
      ["identity-api", "/api/v1/users"],
      ["notifications-worker", "/status"],
    ]) {
      expect(
        readFileSync(resolve(root, `apps/${app}/app/main.py`), "utf8"),
      ).toContain(`"${route}"`);
    }
  });
});
