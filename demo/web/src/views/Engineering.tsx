import { useState } from "react";
import { Search } from "lucide-react";
import { data } from "../data";
import { Badge, External, PageIntro } from "../components";
const decisions = [
  {
    title: "Adapter le réseau au cloud disponible",
    status: "Adaptation lab · source",
    problem:
      "Neutron ne fournit pas de self-service/L3 exploitable, Floating IP ou Octavia.",
    constraint: "Underlay provider partagé et quotas limités.",
    decision:
      "Ports et Security Groups Terraform ; contrôles hôte compensatoires. Pas d’invention de load balancer.",
    verification:
      "Inventaires et tests d’accès M03/M07/M10 ; le réseau reste privé.",
    limit: "Les frontières logiques ne créent pas des domaines de panne.",
    source: "docs/adr/ADR-001-provider-network-fallback.md",
  },
  {
    title: "Séparer la démo des données historiques",
    status: "Implémenté · source / démo",
    problem: "Une démonstration ne doit pas altérer le lab de référence.",
    constraint: "Pas de second compte accessible, pas de VM supplémentaire.",
    decision:
      "Namespace asteria-demo, données jetables et PostgreSQL/Redis/worker propres.",
    verification:
      "Images historiques inchangées, scénario métier et refus réseau enregistrés.",
    limit:
      "Pas de TLS data interne ni de stockage durable dans cette exception.",
    source: "docs/adr/ADR-015-demo-v1-source-only.md",
  },
  {
    title: "Introduire une identité d’administration",
    status: "Testé historiquement · T06",
    problem: "Clés longues et privilèges administratifs étendus dans l’AS-IS.",
    constraint: "Bastion unique, accès de secours à préserver.",
    decision:
      "Teleport CE, GitHub SSO/MFA, RBAC et certificats courts ; break-glass conservé.",
    verification: "Tests T06 et mesures du bastion documentés.",
    limit: "Pas de Teleport HA ni d’OIDC métier gratuit revendiqués.",
    source: "docs/adr/ADR-005-privileged-access.md",
  },
  {
    title: "Tester Cilium sans convertir le source",
    status: "Testé historiquement · staging",
    problem: "Renforcer les frontières et observer les refus réseau.",
    constraint: "Staging à deux VM, désormais inaccessible.",
    decision:
      "K3s/Cilium/Hubble sur le second projet ; source Flannel conservé.",
    verification:
      "Preuve T07 sur le staging, distincte de l’inventaire source.",
    limit:
      "Aucune bascule Cilium sur le source ; pas d’état courant du staging.",
    source: "docs/adr/ADR-002-kubernetes-distribution-and-cni.md",
  },
  {
    title: "Prouver la consommation d’une release",
    status: "Implémenté · démo source",
    problem: "ASIS-015 : image publiée et image exécutée divergeaient.",
    constraint: "Runner sans accès au cluster ; pas de GitOps achevé.",
    decision:
      "Artefact commit/run/digest, promotion privée bornée, comparaison imageID et probes.",
    verification:
      "Promotion et rollback K3s enregistrés, commandes et archives correspondantes.",
    limit:
      "Contrôles limités à Orders démo ; signatures non imposées à l’admission.",
    source: "docs/adr/ADR-015-demo-v1-source-only.md",
  },
  {
    title: "Définir la continuité avant la technologie",
    status: "Proposé · T08–T18 à faire",
    problem: "Control plane et données uniques ; restauration non démontrée.",
    constraint:
      "Quotas et une seule AZ, pas de domaines de panne indépendants.",
    decision:
      "Objectifs SLO/RPO/RTO dans T01, stratégie de restauration et migrations dans les ADR.",
    verification:
      "Documents de conception disponibles ; conformité runtime non acquise.",
    limit: "Ni HA, ni DR, ni SLO de production revendiqués.",
    source: "docs/adr/ADR-013-backup-and-recovery.md",
  },
];
export function Engineering() {
  const [query, setQuery] = useState(""),
    [severity, setSeverity] = useState("Tous"),
    [domain, setDomain] = useState("Tous");
  const findings = data.findings.filter(
    (f) =>
      (severity === "Tous" || f.severity === severity) &&
      (domain === "Tous" || f.domain === domain) &&
      `${f.id} ${f.text}`
        .toLocaleLowerCase("fr")
        .includes(query.toLocaleLowerCase("fr")),
  );
  const built = [
    [
      "01",
      "Contexte B2B",
      "Reconstituer une PME SaaS simulée et ses contraintes.",
      "PROJECT_CONTEXT.md",
    ],
    [
      "02",
      "OpenStack & Terraform",
      "Inventorier les capacités, provisionner cinq VM et leurs ports.",
      "infra/terraform/openstack/compute.tf",
    ],
    [
      "03",
      "Ansible & K3s",
      "Configurer les hôtes, PostgreSQL puis K3s et Flannel.",
      "infra/ansible/README.md",
    ],
    [
      "04",
      "Applications",
      "Construire trois services FastAPI et leurs probes.",
      "apps/README.md",
    ],
    [
      "05",
      "Audit AS-IS",
      "Documenter 22 constats et leurs impacts, sans réécrire le passé.",
      "docs/phase-1-as-is/08-as-is-known-issues.md",
    ],
    [
      "06",
      "Sécurité & staging",
      "Expérimenter Teleport T06 et Cilium T07 ; conserver leurs preuves historiques.",
      "PHASE_2_BACKLOG.md",
    ],
    [
      "07",
      "CI & démonstration",
      "Relier commit, digest exécuté, test métier et rollback Orders.",
      "docs/evidence/phase-2/Demo-v1-local-delivery.md",
    ],
  ];
  return (
    <>
      <PageIntro
        eyebrow="05 / ENGINEERING DECISIONS"
        title="Les choix comptent autant que les outils."
      >
        Problème, contrainte, décision, vérification et limite : une trajectoire
        documentée, sans taux de remédiation inventé.
      </PageIntro>
      <section className="built-section">
        <div className="section-title">
          <div>
            <span className="eyebrow">HOW IT WAS BUILT</span>
            <h2>De la contrainte au résultat.</h2>
          </div>
          <Badge>Phase 1 → T00–T07 → Demo v1</Badge>
        </div>
        <div className="built-track">
          {built.map(([n, t, b, p]) => (
            <div key={n}>
              <span>{n}</span>
              <div>
                <h3>{t}</h3>
                <p>{b}</p>
                <External path={p}>Source</External>
              </div>
            </div>
          ))}
        </div>
      </section>
      <div className="section-title">
        <div>
          <span className="eyebrow">ARBITRAGES STRUCTURANTS</span>
          <h2>Ce qui est réalisé, testé ou proposé.</h2>
        </div>
      </div>
      <section className="decision-grid">
        {decisions.map((d, i) => (
          <details className="decision" key={d.title}>
            <summary>
              <span className="eyebrow">DÉCISION 0{i + 1}</span>
              <h3>{d.title}</h3>
              <Badge
                tone={
                  d.status.startsWith("Implémenté")
                    ? "green"
                    : d.status.startsWith("Proposé")
                      ? "amber"
                      : "blue"
                }
              >
                {d.status}
              </Badge>
              <span className="detail-hint">Inspecter le raisonnement +</span>
            </summary>
            <dl>
              {[
                ["Problème", d.problem],
                ["Contrainte", d.constraint],
                ["Décision", d.decision],
                ["Vérification", d.verification],
                ["Limite", d.limit],
              ].map(([t, b]) => (
                <div key={t}>
                  <dt>{t}</dt>
                  <dd>{b}</dd>
                </div>
              ))}
            </dl>
            <External path={d.source}>Lire l’ADR et ses alternatives</External>
          </details>
        ))}
      </section>
      <section className="findings-section">
        <div className="section-title">
          <div>
            <span className="eyebrow">REGISTRE D’AUDIT / M16</span>
            <h2>
              {data.findings.length} constats, sans réécriture de l’AS-IS.
            </h2>
          </div>
          <External path="docs/phase-1-as-is/08-as-is-known-issues.md">
            Audit canonique
          </External>
        </div>
        <p className="muted">
          Impacts au moment de l’audit de phase 1. Les améliorations ciblées ne
          valent pas clôture globale ; T18 reste à faire.
        </p>
        <div className="filters">
          <label className="search-field">
            <Search size={17} />
            <input
              aria-label="Rechercher les constats"
              placeholder="Rechercher un constat, un risque…"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
          </label>
          <label>
            Impact
            <select
              aria-label="Impact"
              value={severity}
              onChange={(e) => setSeverity(e.target.value)}
            >
              {["Tous", "Élevé", "Moyen", "Faible"].map((s) => (
                <option key={s}>{s}</option>
              ))}
            </select>
          </label>
          <label>
            Domaine
            <select
              aria-label="Domaine"
              value={domain}
              onChange={(e) => setDomain(e.target.value)}
            >
              {["Tous", ...new Set(data.findings.map((f) => f.domain))].map(
                (s) => (
                  <option key={s}>{s}</option>
                ),
              )}
            </select>
          </label>
        </div>
        <p className="results-count" role="status">
          {findings.length} constat{findings.length !== 1 ? "s" : ""} affiché
          {findings.length !== 1 ? "s" : ""}
        </p>
        <div className="findings-table">
          {findings.map((f) => (
            <details key={f.id}>
              <summary>
                <code>{f.id}</code>
                <Badge tone={f.severity === "Élevé" ? "amber" : "neutral"}>
                  {f.severity}
                </Badge>
                <span>{f.text}</span>
                <small>{f.domain}</small>
              </summary>
              <div>
                <p>{f.state}</p>
                <External path={f.source}>
                  Retrouver le constat et ses preuves Mxx
                </External>
              </div>
            </details>
          ))}
          {findings.length === 0 && (
            <div className="empty-state">
              <Search size={26} />
              <h3>Aucun constat ne correspond.</h3>
              <button
                onClick={() => {
                  setQuery("");
                  setSeverity("Tous");
                  setDomain("Tous");
                }}
              >
                Réinitialiser les filtres
              </button>
            </div>
          )}
        </div>
      </section>
    </>
  );
}
