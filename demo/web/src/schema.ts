import { z } from "zod";
export const Kind = z.enum([
  "recorded",
  "historical",
  "proposal",
  "pedagogical",
]);
const source = z
  .string()
  .regex(
    /^(demo\/|docs\/|apps\/|infra\/|k8s\/|\.github\/|PROJECT_CONTEXT|PHASE_2_BACKLOG|README)/,
  )
  .refine(
    (p) => !p.includes("..") && !p.includes("://"),
    "Repository-relative source only",
  );
export const releaseSchema = z
  .object({
    schema: z.literal(1),
    commit: z.string().regex(/^[0-9a-f]{40}$/),
    image: z.literal("ghcr.io/boualili-youcef/asteria/orders-api"),
    digest: z.string().regex(/^sha256:[0-9a-f]{64}$/),
    run_id: z.string().regex(/^[1-9][0-9]*$/),
  })
  .strict();
export const rbacKeys = [
  "create deployments -n asteria-demo",
  "create pods --subresource=portforward -n asteria-demo",
  "get secrets -n team-orders",
  "create namespaces",
  "delete nodes",
] as const;
export const nodeSchema = z
  .object({
    id: z.string(),
    title: z.string(),
    subtitle: z.string(),
    layer: z.enum(["infra", "apps", "delivery"]),
    scope: z.enum(["source", "demo", "staging", "target"]),
    kind: Kind,
    x: z.number(),
    y: z.number(),
    role: z.string(),
    limitation: z.string(),
    sources: z.array(source).min(1),
  })
  .strict();
export const edgeSchema = z
  .object({
    id: z.string(),
    from: z.string(),
    to: z.string(),
    label: z.string(),
    guarantee: z.string(),
    conceptual: z.boolean(),
  })
  .strict();
export const manifestSchema = z
  .object({
    schema: z.literal(2),
    mode: z.literal("dated-evidence-not-live"),
    date: z.string().datetime({ offset: true }),
    sourceCommit: z.string().regex(/^[a-f0-9]{40}$/),
    release: releaseSchema,
    metrics: z
      .object({
        vms: z.number(),
        nodes: z.number(),
        ready: z.number(),
        services: z.number(),
        findings: z.number(),
        cpu: z.number(),
        cpuQuota: z.number(),
        ramGiB: z.number(),
        ramQuotaGiB: z.number(),
        promotion: z.number(),
        rollback: z.number(),
        postTest: z.number(),
        orders: z.number(),
        archives: z.number(),
      })
      .strict(),
    scan: z
      .object({
        high: z.number(),
        critical: z.number(),
        baselineHigh: z.number(),
        baselineCritical: z.number(),
        baselineRun: z.string(),
        scanner: z.string(),
        targets: z.array(z.string()),
      })
      .strict(),
    ci: z
      .object({
        url: z.string().url(),
        jobs: z.array(
          z
            .object({
              name: z.string(),
              seconds: z.number(),
              steps: z.array(
                z.object({ name: z.string(), seconds: z.number() }).strict(),
              ),
            })
            .strict(),
        ),
      })
      .strict(),
    events: z.array(
      z.object({ event: z.string(), seconds: z.number() }).strict(),
    ),
    docker: z
      .object({
        date: z.string(),
        seconds: z.number(),
        fault: z.string(),
        checks: z.array(z.string()),
      })
      .strict(),
    security: z
      .object({
        crossNamespace: z.literal(true),
        allowed: z.literal(true),
        denied: z.literal(true),
        rbac: z
          .object({
            "create deployments -n asteria-demo": z.literal(true),
            "create pods --subresource=portforward -n asteria-demo":
              z.literal(true),
            "get secrets -n team-orders": z.literal(true),
            "create namespaces": z.literal(true),
            "delete nodes": z.literal(true),
          })
          .strict(),
        historicalUnchanged: z.literal(true),
      })
      .strict(),
    findings: z
      .array(
        z
          .object({
            id: z.string(),
            text: z.string(),
            severity: z.enum(["Élevé", "Moyen", "Faible"]),
            domain: z.string(),
            state: z.string(),
            source,
          })
          .strict(),
      )
      .length(22),
    nodes: z.array(nodeSchema),
    edges: z.array(edgeSchema),
    presentation: z
      .object({
        sourceState: z.string(),
        steps: z.array(
          z
            .object({
              title: z.string(),
              description: z.string(),
              status: z.string(),
              source,
            })
            .strict(),
        ),
      })
      .strict(),
    sources: z.array(
      z
        .object({
          path: source,
          sha256: z.string().regex(/^[a-f0-9]{64}$/),
          context: z.string(),
          kind: Kind,
        })
        .strict(),
    ),
  })
  .strict();
export type Manifest = z.infer<typeof manifestSchema>;
export type SystemNode = z.infer<typeof nodeSchema>;
