import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve, dirname } from "node:path";
import { createHash } from "node:crypto";
import { manifestSchema, releaseSchema, rbacKeys } from "../src/schema";
import { nodes, edges } from "./topology";

export const root = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../..",
);
export const paths = {
  release: "demo/evidence/orders-release.json",
  flow: "demo/evidence/kubernetes-flow-20261014.json",
  ci: "demo/evidence/ci-verification-20261014.json",
  docker: "demo/evidence/ci-functional-20261014.json",
  baseline: "demo/evidence/scan-baseline-20261014.json",
  presentation: "demo/evidence/presentation.json",
  cloud: "demo/evidence/openstack-audit-20261014.json",
  runtime: "demo/evidence/kubernetes-audit-20261014.json",
};
export function readInputs() {
  return Object.fromEntries(
    Object.entries(paths).map(([key, path]) => [
      key,
      JSON.parse(readFileSync(resolve(root, path), "utf8")),
    ]),
  );
}
// Internal evidence is input only. Construct each public field explicitly; never spread a raw report.
export function transform(input: ReturnType<typeof readInputs>) {
  const {
    flow: f,
    ci,
    docker: d,
    baseline: b,
    cloud: c,
    runtime: r,
    presentation: p,
  } = input;
  const release = releaseSchema.parse(input.release);
  const requireProof = (ok: boolean, reason: string) => {
    if (!ok) throw new Error(`Evidence rejected: ${reason}`);
  };
  requireProof(p.mode === "dated-evidence-not-live", "presentation mode");
  requireProof(
    f.status === "passed" && f.promotion.status === "promoted",
    "K3s promotion",
  );
  for (const step of [
    "promotion",
    "failure_drill",
    "post_promotion_functional",
    "post_rollback_functional",
  ]) {
    requireProof(
      JSON.stringify(releaseSchema.parse(f[step].release)) ===
        JSON.stringify(release),
      `release mismatch: ${step}`,
    );
  }
  const image = `${release.image}@${release.digest}`;
  requireProof(
    f.promotion.observed_image === image &&
      f.promotion.runtime_image_ids.length > 0 &&
      f.promotion.runtime_image_ids.every((id: string) => id === image),
    "executed digest",
  );
  requireProof(
    f.failure_drill.status === "failed_then_rolled_back" &&
      f.failure_drill.previous_image === image &&
      f.failure_drill.observed_image === image &&
      f.failure_drill.runtime_image_ids.length > 0 &&
      f.failure_drill.runtime_image_ids.every((id: string) => id === image),
    "rollback",
  );
  requireProof(
    f.post_rollback_functional.status === "passed" &&
      f.post_promotion_functional.status === "passed",
    "business flow",
  );
  requireProof(
    ci.conclusion === "success" &&
      ci.run_id === release.run_id &&
      ci.commit === release.commit &&
      ci.image === image &&
      ci.url ===
        `https://github.com/Boualili-Youcef/Asteria/actions/runs/${release.run_id}`,
    "CI identity",
  );
  requireProof(
    ci.jobs.every((j: { conclusion: string }) => j.conclusion === "success") &&
      ci.scan.high_findings === 0 &&
      ci.scan.critical_findings === 0,
    "CI gates",
  );
  requireProof(
    ["test", "release"].every((name) =>
      ci.jobs.some((job: { name: string }) => job.name === name),
    ) &&
      [
        "Build once and publish immutable candidate",
        "Scan the published candidate before allowing promotion",
        "Smoke test immutable image",
        "Synthetic Orders event flow",
      ].every((name) =>
        ci.jobs.some((job: { steps: { name: string; conclusion: string }[] }) =>
          job.steps.some(
            (step) => step.name === name && step.conclusion === "success",
          ),
        ),
      ),
    "CI required steps",
  );
  requireProof(
    d.status === "passed" &&
      d.cleanup === "passed" &&
      d.cloud_mutations === false &&
      d.run_id === release.run_id &&
      d.source_commit === release.commit &&
      d.orders_image === image,
    "Docker identity",
  );
  requireProof(
    [
      "order_persisted_and_matching_notification_archived",
      "redis_failure_readiness_503_liveness_200",
      "redis_recovered_second_order_archived",
      "worker_counter_2",
    ].every((check) => d.checks.includes(check)) &&
      d.fault_mode === "redis_process_paused_network_preserved",
    "Docker required checks",
  );
  requireProof(
    f.historical_workloads_modified === false &&
      f.historical_business_data_accessed === false &&
      f.source_after.historical_deployments_healthy === true &&
      f.source_after.historical_deployment_images_unchanged === true,
    "historical safety",
  );
  requireProof(
    f.data_scope === "disposable_synthetic_only" &&
      f.data_tls === "not_enabled_internal_lab_exception" &&
      f.cross_namespace_refused === true &&
      f.network_probes["demo-network-allowed"].succeeded &&
      f.network_probes["demo-network-denied"].succeeded,
    "isolation",
  );
  requireProof(
    b.promotion === "blocked" && b.high_findings > 0,
    "baseline scan",
  );
  requireProof(
    f.failure_events.map((e: { event: string }) => e.event).join(",") ===
      "upgrade_started,upgrade_failed,rollback_started,rollback_verified",
    "event sequence",
  );
  requireProof(
    f.failure_events.every(
      (event: { elapsed_seconds: number }, index: number) =>
        Number.isFinite(event.elapsed_seconds) &&
        event.elapsed_seconds >= 0 &&
        (index === 0 ||
          event.elapsed_seconds >= f.failure_events[index - 1].elapsed_seconds),
    ) &&
      f.failure_events.at(-1).elapsed_seconds <=
        f.failure_drill.duration_seconds,
    "event timing",
  );
  const issuePath = "docs/phase-1-as-is/08-as-is-known-issues.md";
  const lines = readFileSync(resolve(root, issuePath), "utf8")
    .split("\n")
    .filter((l) => /^\| ASIS-\d{3} \|/.test(l));
  const domains = [
    "Réseau",
    "Réseau",
    "Continuité",
    "Sécurité",
    "Données",
    "Sécurité",
    "Données",
    "Continuité",
    "Applications",
    "Sécurité",
    "Sécurité",
    "Livraison",
    "Livraison",
    "Livraison",
    "Livraison",
    "Observabilité",
    "Observabilité",
    "Sécurité",
    "Infrastructure",
    "Infrastructure",
    "Réseau",
    "Continuité",
  ];
  const findings = lines.map((line, i) => {
    const [, id, text, severity] = line.split("|").map((s) => s.trim());
    return {
      id,
      text,
      severity,
      domain: domains[i],
      state: "Constat AS-IS · clôture globale non évaluée",
      source: issuePath,
    };
  });
  const business = [
    f.baseline_functional,
    f.post_promotion_functional,
    f.post_rollback_functional,
  ];
  requireProof(
    business.every(
      (v) =>
        v.order_created_and_read === true &&
        v.persisted_orders_for_id === 1 &&
        v.archived_notifications_for_id === 1 &&
        v.historical_data_accessed === false,
    ),
    "matching archives",
  );
  const data = manifestSchema.parse({
    schema: 2,
    mode: p.mode,
    date: f.date,
    sourceCommit: release.commit,
    release,
    metrics: {
      vms: c.source_state_instances,
      nodes: r.runtime.node_count,
      ready: r.runtime.nodes_ready,
      services: 3,
      findings: findings.length,
      cpu: c.limits.totalCoresUsed,
      cpuQuota: c.limits.maxTotalCores,
      ramGiB: c.limits.totalRAMUsed / 1024,
      ramQuotaGiB: c.limits.maxTotalRAMSize / 1024,
      promotion: f.promotion.duration_seconds,
      rollback: f.failure_drill.duration_seconds,
      postTest: f.post_rollback_functional.duration_seconds,
      orders: business.reduce((s, v) => s + v.persisted_orders_for_id, 0),
      archives: business.reduce(
        (s, v) => s + v.archived_notifications_for_id,
        0,
      ),
    },
    scan: {
      high: ci.scan.high_findings,
      critical: ci.scan.critical_findings,
      baselineHigh: b.high_findings,
      baselineCritical: b.critical_findings,
      baselineRun: b.run_id,
      scanner: ci.scan.scanner,
      targets: ci.scan.targets,
    },
    ci: {
      url: ci.url,
      jobs: ci.jobs.map(
        (j: {
          name: string;
          duration_seconds: number;
          steps: { name: string; duration_seconds: number }[];
        }) => ({
          name: j.name,
          seconds: j.duration_seconds,
          steps: j.steps.map((s) => ({
            name: s.name,
            seconds: s.duration_seconds,
          })),
        }),
      ),
    },
    events: f.failure_events.map(
      (e: { event: string; elapsed_seconds: number }) => ({
        event: e.event,
        seconds: e.elapsed_seconds,
      }),
    ),
    docker: {
      date: d.date,
      seconds: d.duration_seconds,
      fault: d.fault_mode,
      checks: d.checks.filter((check: string) =>
        [
          "order_persisted_and_matching_notification_archived",
          "redis_failure_readiness_503_liveness_200",
          "redis_recovered_second_order_archived",
          "worker_counter_2",
        ].includes(check),
      ),
    },
    security: {
      crossNamespace: f.cross_namespace_refused,
      allowed: f.network_probes["demo-network-allowed"].succeeded,
      denied: f.network_probes["demo-network-denied"].succeeded,
      rbac: Object.fromEntries(
        rbacKeys.map((key) => [
          key,
          f.bounded_operator.rbac_checks_passed[key],
        ]),
      ),
      historicalUnchanged:
        f.source_after.historical_deployment_images_unchanged,
    },
    findings,
    nodes,
    edges,
    // presentation.json remains an input, including its initial uncertainty. Runtime proof supersedes it visibly.
    presentation: {
      sourceState: p.source_state,
      steps: p.steps.map(
        (s: {
          title: string;
          description: string;
          short_status: string;
          proof: string;
        }) => ({
          title: s.title,
          description: s.description,
          status: s.short_status,
          source: s.proof,
        }),
      ),
    },
    sources: Object.values(paths)
      .concat(issuePath)
      .map((path) => ({
        path,
        sha256: createHash("sha256")
          .update(readFileSync(resolve(root, path)))
          .digest("hex"),
        context:
          path === paths.presentation
            ? "État éditorial initial, supplanté par les preuves K3s et CI"
            : path === issuePath
              ? "Audit fin de phase 1"
              : path === paths.docker
                ? "Docker sur GitHub Actions"
                : "Observation datée du lab",
        kind:
          path === paths.presentation
            ? "pedagogical"
            : path === issuePath
              ? "historical"
              : "recorded",
      })),
  });
  assertPublic(data);
  return data;
}
export function assertPublic(data: unknown) {
  const text = typeof data === "string" ? data : JSON.stringify(data);
  if (
    /(?:-----BEGIN .*PRIVATE KEY|gh[pousr]_[A-Za-z0-9]+|["\s](?:10\.(?:\d+\.){2}\d+|172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+|192\.168\.\d+\.\d+)|"(?:password|token|kubeconfig|terraform_state|private_key)"\s*:)/i.test(
      text,
    )
  )
    throw new Error("Non-public data rejected");
}
if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const output = resolve(root, "demo/web/src/generated");
  mkdirSync(output, { recursive: true });
  writeFileSync(
    resolve(output, "manifest.json"),
    JSON.stringify(transform(readInputs()), null, 2) + "\n",
  );
  console.log("Public manifest validated; raw evidence is never copied.");
}
