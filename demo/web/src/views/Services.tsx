import { useState } from "react";
import { ArrowRight, Box, Database } from "lucide-react";
import { data } from "../data";
import { Badge, Evidence, External, PageIntro } from "../components";
type Update = (
  v: Record<string, string | number | null>,
  replace?: boolean,
) => void;
const services = [
  {
    id: "identity-api",
    label: "Identity",
    role: "Créer et retrouver un utilisateur.",
    description:
      "API de persistance des utilisateurs. Ce service ne fournit ni login métier, ni JWT, ni fournisseur OIDC.",
    deps: ["PostgreSQL historique"],
    deployment: "YAML brut · team-identity",
    manifest: "k8s/current-state/identity-api/identity-api.yaml",
    endpoints: [
      "POST /api/v1/users",
      "GET /api/v1/users/{user_id}",
      "GET /health",
      "GET /ready",
      "GET /metrics",
    ],
    risk: "Pas d’authentification métier. Schéma créé au démarrage, sans migrations versionnées.",
  },
  {
    id: "orders-api",
    label: "Orders",
    role: "Persister une commande, publier un événement.",
    description:
      "Crée et relit les commandes en PostgreSQL, puis publie order.created dans une liste Redis.",
    deps: ["PostgreSQL", "Redis"],
    deployment: "Helm · team-orders / asteria-demo",
    manifest: "k8s/current-state/orders-api/chart/values.yaml",
    endpoints: [
      "POST /api/v1/orders",
      "GET /api/v1/orders/{order_id}",
      "GET /health",
      "GET /ready",
      "GET /metrics",
    ],
    risk: "Commit PostgreSQL avant publication Redis, sans outbox. Une commande peut exister sans événement.",
  },
  {
    id: "notifications-worker",
    label: "Notifications",
    role: "Consommer et archiver les événements.",
    description:
      "Une boucle BLPOP lit la liste Redis et archive le payload dans PostgreSQL. Aucun email n’est envoyé.",
    deps: ["Redis", "PostgreSQL"],
    deployment:
      "YAML manuel · team-notifications ; image M13 en cache pour la démo",
    manifest:
      "k8s/current-state/notifications-worker/notifications-worker.yaml",
    endpoints: ["GET /status", "GET /health", "GET /ready", "GET /metrics"],
    risk: "BLPOP retire le message avant l’archive. Un crash peut perdre l’événement ; ni ACK durable, ni DLQ.",
  },
];
export function Services({
  params,
  update,
}: {
  params: URLSearchParams;
  update: Update;
}) {
  const s = services.find((v) => v.id === params.get("service")) || services[1];
  const [flow, setFlow] = useState(0);
  const stages = [
    [
      "POST order",
      "Validation du payload customer_id et amount. Exemple pédagogique : client demo, montant 42,00. Aucun appel à une API publique.",
    ],
    [
      "PostgreSQL",
      "INSERT puis commit de la commande. Le code retourne un UUID ; aucune transaction n’englobe Redis.",
    ],
    [
      "Redis",
      "RPUSH order.created sur asteria:notifications. Si Redis échoue ici, la commande est déjà persistée.",
    ],
    [
      "Worker",
      "BLPOP retire l’événement de la liste. La boucle appelle archive_notification ; pas d’ACK durable.",
    ],
    [
      "Archive SQL",
      "INSERT du payload JSONB dans processed_notifications. Les tests recherchent le même order_id.",
    ],
  ];
  return (
    <>
      <PageIntro
        eyebrow="04 / SERVICE CATALOG"
        title="Trois services. Un parcours explicable."
      >
        Les vrais composants Python/FastAPI du dépôt : responsabilités,
        endpoints et risques connus.
      </PageIntro>
      <div className="service-cards">
        {services.map((v) => (
          <button
            className={v.id === s.id ? "active" : ""}
            key={v.id}
            onClick={() => update({ service: v.id })}
            aria-pressed={v.id === s.id}
          >
            <Box size={25} />
            <span className="eyebrow">{v.label}</span>
            <strong>{v.id}</strong>
            <p>{v.role}</p>
            <span className="service-card-footer">
              Inspecter le service <ArrowRight size={16} />
            </span>
          </button>
        ))}
      </div>
      <section className="panel service-detail">
        <div>
          <Badge tone="blue">Code réel · API privée de démonstration</Badge>
          <h2>{s.id}</h2>
          <p>{s.description}</p>
          <h3>Déploiement historique</h3>
          <p>{s.deployment}</p>
          <h3>Dépendances</h3>
          <div className="tag-row">
            {s.deps.map((v) => (
              <Badge key={v}>{v}</Badge>
            ))}
          </div>
          <div className="limit-box">
            <strong>Risque connu · ASIS-009 / ASIS-010</strong>
            <p>{s.risk}</p>
          </div>
          <div className="source-list">
            <External path={`apps/${s.id}/app/main.py`}>Code FastAPI</External>
            <External path={s.manifest}>Manifest / chart</External>
            <External path={`apps/${s.id}/tests/test_app.py`}>
              Tests applicatifs
            </External>
          </div>
        </div>
        <div className="endpoints">
          <span className="eyebrow">CONTRAT HTTP</span>
          {s.endpoints.map((ep) => (
            <code key={ep}>
              <span className={ep.startsWith("POST") ? "post" : ""}>
                {ep.split(" ")[0]}
              </span>
              {ep.split(" ")[1]}
            </code>
          ))}
          <p>
            <strong>/health</strong> vérifie le processus ;{" "}
            <strong>/ready</strong> vérifie les dépendances.{" "}
            <strong>/metrics</strong> expose Prometheus. Ce site n’interroge
            aucun de ces endpoints.
          </p>
        </div>
      </section>
      <section className="panel application-flow">
        <div className="panel-heading">
          <div>
            <span className="eyebrow">APPLICATION FLOW</span>
            <h2>Suivre une commande jusqu’à son archive.</h2>
          </div>
          <Badge tone="amber">Simulation pédagogique</Badge>
        </div>
        <div className="order-track">
          {stages.map(([label], i) => (
            <button
              key={label}
              aria-pressed={flow === i}
              className={flow === i ? "active" : ""}
              onClick={() => setFlow(i)}
            >
              <span>0{i + 1}</span>
              {i === 1 || i === 4 ? <Database size={23} /> : <Box size={23} />}
              <strong>{label}</strong>
              {i < 4 && <ArrowRight className="flow-arrow" size={16} />}
            </button>
          ))}
        </div>
        <div className="flow-explanation" aria-live="polite">
          <span className="eyebrow">ÉTAPE {flow + 1}</span>
          <h3>{stages[flow][0]}</h3>
          <p>{stages[flow][1]}</p>
          <div className="tag-row">
            <button disabled={flow === 0} onClick={() => setFlow(flow - 1)}>
              Précédent
            </button>
            <button disabled={flow === 4} onClick={() => setFlow(flow + 1)}>
              Suivant <ArrowRight size={15} />
            </button>
          </div>
        </div>
        <Evidence context="K3s · scénario métier synthétique vérifié" />
        <p className="muted">
          Le schéma explique le code ; les {data.metrics.orders} commandes et{" "}
          {data.metrics.archives} archives sont, elles, issues de
          l’enregistrement K3s.
        </p>
      </section>
    </>
  );
}
