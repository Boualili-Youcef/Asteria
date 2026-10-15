import { useCallback, useState } from "react";
import { ArrowRight, Check, ChevronRight, ShieldCheck } from "lucide-react";
import { data, dateLabel, replayDate, seconds } from "../data";
import {
  Badge,
  Evidence,
  External,
  PageIntro,
  ReplayControls,
  useReplay,
} from "../components";
type Update = (
  v: Record<string, string | number | null>,
  replace?: boolean,
) => void;
const kproof = "demo/evidence/kubernetes-flow-20261014.json";
export function Incidents({
  params,
  update,
}: {
  params: URLSearchParams;
  update: Update;
}) {
  const choice = ["readiness", "redis", "access"].includes(
    params.get("incident") || "",
  )
    ? params.get("incident")!
    : "readiness";
  const [compare, setCompare] = useState(false),
    [probe, setProbe] = useState(false);
  const scenarios = {
    readiness: {
      title: "Readiness invalide",
      context: "K3s source · asteria-demo",
      source: kproof,
      date: dateLabel,
      summary:
        "La candidate ne devient pas prête. Helm échoue, puis le script restaure et vérifie la révision saine.",
      duration: seconds(data.metrics.rollback),
      states: [
        {
          name: "Précondition",
          event: "Révision saine enregistrée",
          time: null,
          body: "Le digest promu est sain. Le script relève l’image et la révision Helm précédentes. Le test métier après promotion réussit.",
        },
        ...data.events.map((e, i) => ({
          name: ["Injection", "Détection", "Recovery", "Vérification"][i],
          event: e.event,
          time: e.seconds,
          body: [
            "Une nouvelle révision remplace la readiness par un chemin inexistant. La liveness reste indépendante.",
            "La nouvelle révision ne devient pas Ready. Le timeout Helm configuré est de 180 s ; l’événement d’échec est enregistré plus tard.",
            "Le script lance le rollback vers la révision saine relevée avant l’essai.",
            "Le rollback vérifie digest, imageID, rollout et probes. Un test métier distinct confirme ensuite une nouvelle archive.",
          ][i],
        })),
      ],
    },
    redis: {
      title: "Redis non répondant",
      context: "Docker sur GitHub Actions · processus Redis en pause",
      source: "demo/evidence/ci-functional-20261014.json",
      date: data.docker.date,
      summary:
        "Une dépendance indisponible doit retirer Orders du trafic prêt, sans déclarer le processus applicatif mort.",
      duration: `${seconds(data.docker.seconds)} · scénario Docker complet`,
      states: [
        {
          name: "Précondition",
          event: "Commande et archive correspondantes",
          time: null,
          body: "Une première commande est créée et relue ; le worker archive son événement.",
        },
        {
          name: "Injection",
          event: data.docker.fault,
          time: null,
          body: "Le processus Redis est mis en pause, réseau conservé. Ce n’est pas un arrêt du cluster K3s.",
        },
        {
          name: "Détection",
          event: "/ready 503 · /health 200",
          time: null,
          body: "La readiness dépend de PostgreSQL et Redis. La liveness ne vérifie que le processus. Le refus est attendu.",
        },
        {
          name: "Recovery",
          event: "Redis reprend",
          time: null,
          body: "Le test restaure le processus Redis. La disponibilité de la dépendance est revérifiée.",
        },
        {
          name: "Vérification",
          event: "Deuxième commande archivée",
          time: null,
          body: "Une seconde commande rejoint son archive et le compteur worker est observé à 2. Le nettoyage du test réussit.",
        },
      ],
    },
    access: {
      title: "Accès non autorisés",
      context: "K3s source · NetworkPolicy / RBAC",
      source: kproof,
      date: dateLabel,
      summary:
        "Le succès d’un client légitime ne suffit pas. Les clients et opérations non autorisés doivent être refusés.",
      duration: "Durée non mesurée",
      states: [
        {
          name: "Précondition",
          event: "Identité et namespace bornés",
          time: null,
          body: "Rôle de promotion dédié dans asteria-demo. Les workloads et données historiques restent hors périmètre.",
        },
        {
          name: "Contrôle positif",
          event: "Client autorisé accepté",
          time: null,
          body: "La probe demo-network-allowed réussit. Créer un Deployment dans asteria-demo est autorisé.",
        },
        {
          name: "Contrôle négatif réseau",
          event: "Client interdit / inter-namespace refusés",
          time: null,
          body: "demo-network-denied réussit son test de refus ; le refus inter-namespaces est enregistré.",
        },
        {
          name: "Contrôle négatif RBAC",
          event: "Secrets historiques / namespaces / nodes refusés",
          time: null,
          body: "Les résultats attendus sont obtenus pour get secrets team-orders, create namespaces et delete nodes. Les booléens true de la preuve valident le test, pas l’autorisation.",
        },
        {
          name: "Vérification",
          event: "Images historiques inchangées",
          time: null,
          body: "L’enregistrement final confirme la santé historique et des images inchangées. Ce résultat ne clôture pas les défauts d’isolation globaux.",
        },
      ],
    },
  };
  const s = scenarios[choice as keyof typeof scenarios];
  const index = Math.min(
    s.states.length - 1,
    Math.max(0, Math.trunc(Number(params.get("step"))) || 0),
  );
  const change = useCallback(
    (i: number) => update({ step: i }, true),
    [update],
  );
  const replay = useReplay(index, s.states.length, change);
  const current = s.states[index];
  return (
    <>
      <PageIntro
        eyebrow="03 / INCIDENT LAB"
        title="Comprendre l’échec. Vérifier la reprise."
      >
        Trois scénarios enregistrés, leurs contrôles et leurs limites. Aucune
        panne distante n’est provoquée.
      </PageIntro>
      <div className="incident-selector">
        {Object.entries(scenarios).map(([key, v]) => (
          <button
            key={key}
            aria-pressed={key === choice}
            onClick={() => {
              update({ incident: key, step: 0 });
              replay.setPlaying(false);
              setProbe(false);
            }}
          >
            <ShieldCheck size={21} />
            <span>
              {v.title}
              <small>
                {key === "redis"
                  ? "Test Docker enregistré"
                  : "Preuve K3s enregistrée"}
              </small>
            </span>
            <ArrowRight size={16} />
          </button>
        ))}
      </div>
      <div className="replay-header">
        <Badge tone="blue">Replay daté du {replayDate}</Badge>
        <span>{s.context}</span>
        <strong>{s.duration}</strong>
      </div>
      <div className="incident-body panel">
        <div className="incident-story">
          <span className="eyebrow">
            {current.name} · {index + 1}/{s.states.length}
          </span>
          <h2>{s.title}</h2>
          <p>{s.summary}</p>
          <div className="state-track" aria-label="États de l’incident">
            {s.states.map((st, i) => (
              <button
                key={i}
                className={i === index ? "active" : i < index ? "done" : ""}
                aria-current={index === i ? "step" : undefined}
                onClick={() => {
                  change(i);
                  replay.setPlaying(false);
                }}
              >
                <span>{i < index ? <Check size={15} /> : i + 1}</span>
                <small>{st.name}</small>
              </button>
            ))}
          </div>
          <div className="event-inspector" aria-live="polite">
            <div>
              <Badge
                tone={
                  index === s.states.length - 1
                    ? "green"
                    : index === 2
                      ? "amber"
                      : "blue"
                }
              >
                {current.name}
              </Badge>
              <code>
                {current.time === null
                  ? "Horodatage individuel non enregistré"
                  : `t + ${seconds(current.time)}`}
              </code>
            </div>
            <h3>{current.event}</h3>
            <p>{current.body}</p>
          </div>
          <ReplayControls
            index={index}
            total={s.states.length}
            onChange={change}
            {...replay}
          />
          <small className="muted">
            Les étapes sans mesure ne reçoivent aucune durée estimée. Ordre de
            lecture pédagogique pour les contrôles d’accès.
          </small>
        </div>
        <aside className="incident-side">
          <div className="eyebrow">ATTENDU → OBSERVÉ</div>
          <h3>Le résultat à vérifier</h3>
          <div className="check-row">
            <Check size={17} />
            <span>
              {choice === "readiness"
                ? "Retour au digest sain"
                : choice === "redis"
                  ? "Liveness indépendante des dépendances"
                  : "Succès légitime et refus illégitime"}
            </span>
          </div>
          <div className="check-row">
            <Check size={17} />
            <span>
              {choice === "access"
                ? "Images historiques inchangées"
                : "Parcours métier après reprise validé"}
            </span>
          </div>
          <button aria-expanded={compare} onClick={() => setCompare(!compare)}>
            {compare ? "Masquer" : "Comparer avant / après"}
            <ArrowRight size={15} />
          </button>
          {compare && (
            <div className="before-after">
              <div>
                <small>AVANT</small>
                <strong>
                  {choice === "access"
                    ? "Périmètre démo limité"
                    : "Service sain"}
                </strong>
              </div>
              <div>
                <small>APRÈS</small>
                <strong>
                  {choice === "access"
                    ? "Refus vérifiés"
                    : "État sain revérifié"}
                </strong>
              </div>
              <p>
                {choice === "readiness"
                  ? "Même digest sain avant/après, configuration de readiness rétablie."
                  : choice === "redis"
                    ? "Redis disponible et seconde commande archivée."
                    : "Aucune permission globale ajoutée."}
              </p>
            </div>
          )}
          <button aria-expanded={probe} onClick={() => setProbe(!probe)}>
            Inspecter les probes <ChevronRight size={15} />
          </button>
          {probe && (
            <div className="probe-details">
              <code>GET /health → 200</code>
              <p>Le processus répond ; aucune connexion DB/Redis requise.</p>
              <code>GET /ready → 503 si dépendance indisponible</code>
              <p>
                PostgreSQL et Redis doivent répondre. Une readiness 404 dans le
                drill est une configuration invalide, distincte de la panne
                Redis.
              </p>
              <External path="apps/orders-api/app/main.py">
                Code exact des probes
              </External>
            </div>
          )}
          <div className="limit-box">
            <strong>Ce que cela ne démontre pas</strong>
            <p>
              Ni HA, ni restauration de données, ni SLO. Les lectures HTTP
              datées ne prouvent pas une disponibilité continue.
            </p>
          </div>
          <Evidence path={s.source} context={s.context} date={s.date} />
        </aside>
      </div>
    </>
  );
}
