import { ArrowRight, Check, ChevronRight, GitBranch } from "lucide-react";
import { data, dateLabel, replayDate, repo, seconds } from "../data";
import {
  Badge,
  Evidence,
  External,
  PageIntro,
  ReplayControls,
  useReplay,
} from "../components";
const kproof = "demo/evidence/kubernetes-flow-20261014.json";
export function Delivery({
  index,
  change,
}: {
  index: number;
  change: (i: number) => void;
}) {
  const r = data.release,
    m = data.metrics,
    s = data.scan;
  const stages = [
    {
      title: "Commit",
      sub: "Une version identifiable",
      body: "Le commit qui a produit l’image est conservé dans la release. Il relie le code, le run CI et le digest.",
      value: r.commit,
      source: `${repo}/commit/${r.commit}`,
      detail:
        "La preuve correspond au commit de la release, pas au dernier commit du site.",
    },
    {
      title: "Tests",
      sub: "Les gardes avant l’image",
      body: "Tests Orders et contrôles opérateur réussis dans le job test. Les échecs de rollback sont testés sans cluster.",
      value: `Job test : ${seconds(data.ci.jobs[0].seconds)}`,
      source: ".github/workflows/orders-demo.yml",
      detail:
        "Le job ne prouve pas encore un déploiement Kubernetes. Les contrôles réels suivent dans une session privée.",
    },
    {
      title: "Docker build",
      sub: "Construire une seule fois",
      body: "Une variante minimale Python Alpine est construite à partir des mêmes sources applicatives, puis publiée dans GHCR.",
      value: r.image,
      source: "demo/orders.Dockerfile",
      detail:
        "Le runtime Debian historique avait été refusé au gate. Les services historiques restent inchangés.",
    },
    {
      title: "Trivy scan",
      sub: "Refuser plutôt qu’excepter",
      body: `Base historique : ${s.baselineHigh} HIGH / ${s.baselineCritical} CRITICAL, candidate refusée. Image de démo : ${s.high} HIGH / ${s.critical} CRITICAL détectée dans le périmètre scanné.`,
      value: `${s.scanner} · ${s.targets.join(" + ")}`,
      source: "demo/evidence/ci-verification-20261014.json",
      detail:
        "Ce sont des signalements par paquet/CVE. Zéro HIGH/CRITICAL détectée ne signifie pas « sans vulnérabilité ».",
    },
    {
      title: "GHCR",
      sub: "Digest, SBOM & provenance",
      body: "L’image est consommée par digest. Le workflow produit une SBOM et une provenance à la construction.",
      value: r.digest,
      source: ".github/workflows/orders-demo.yml",
      detail:
        "Aucune signature ou provenance n’est vérifiée à l’admission K3s. Produire une attestation ne suffit pas à en imposer la consommation.",
    },
    {
      title: "Release",
      sub: "Un contrat de promotion",
      body: "release.json conserve le commit, l’image, le digest et le run réussi. Le script refuse une CI incohérente ou un artefact incomplet.",
      value: `Run ${r.run_id} · conclusion success`,
      source: "demo/evidence/orders-release.json",
      detail:
        "Artefact de preuve versionné. La rétention des artefacts GitHub Actions est limitée ; la copie validée reste dans le dépôt.",
    },
    {
      title: "Promotion privée",
      sub: "La CI publie. L’opérateur promeut.",
      body: "Helm 3.19.0, token court et rôle borné dans asteria-demo. Le contexte et les identités sont vérifiés avant toute action.",
      value: seconds(m.promotion),
      source: "demo/scripts/promote.py",
      detail:
        "Une première tentative avec Helm 3.15 RC a échoué puis a été annulée. La cause profonde du timeout n’est pas isolée ; la reprise avec Helm stable a réussi.",
    },
    {
      title: "Probes & imageID",
      sub: "Ce que K3s exécute réellement",
      body: "Le digest demandé est retrouvé dans l’image observée et les imageID. Rollout, /health, /ready et /metrics sont vérifiés.",
      value: r.digest,
      source: kproof,
      detail:
        "Ce lien entre publication et exécution corrige le défaut central ASIS-015 dans le seul périmètre de démo.",
    },
    {
      title: "Test métier",
      sub: "Aller jusqu’à l’archive",
      body: `Les validations K3s enregistrent ${m.orders} commandes persistées et relues, avec ${m.archives} archives correspondantes. Le même order_id est recherché côté worker.`,
      value: `Après rollback : ${seconds(m.postTest)}`,
      source: "demo/scripts/kubernetes-e2e.py",
      detail:
        "Scénarios synthétiques avant promotion, après promotion et après rollback. Aucun accès aux données historiques.",
    },
    {
      title: "Failure drill",
      sub: "Échouer, revenir, revérifier",
      body: "Une readiness inexistante fait échouer la nouvelle révision. Le rollback rétablit le digest précédent, puis probes et parcours métier sont revérifiés.",
      value: seconds(m.rollback),
      source: kproof,
      detail:
        "La durée inclut le timeout Helm de 180 s. Un rollback d’application ne démontre ni une restauration de données ni un DR.",
    },
  ];
  const current = stages[index];
  const replay = useReplay(index, stages.length, change);
  return (
    <>
      <PageIntro
        eyebrow="02 / DELIVERY JOURNEY"
        title="Publié ne veut pas dire déployé."
      >
        Suivez la release enregistrée : du commit à l’image réellement exécutée,
        jusqu’au retour arrière.
      </PageIntro>
      <div className="replay-header">
        <Badge tone="blue">Replay daté du {replayDate}</Badge>
        <span>Aucune CI ni opération cluster déclenchée</span>
        <External path={data.ci.url}>Run #{r.run_id}</External>
      </div>
      <div className="delivery-layout">
        <nav className="delivery-steps" aria-label="Étapes de livraison">
          {stages.map((s, i) => (
            <button
              key={s.title}
              aria-current={index === i ? "step" : undefined}
              onClick={() => {
                change(i);
                replay.setPlaying(false);
              }}
            >
              <span className={`step-number ${i < index ? "done" : ""}`}>
                {i < index ? (
                  <Check size={14} />
                ) : (
                  String(i + 1).padStart(2, "0")
                )}
              </span>
              <span>
                {s.title}
                <small>
                  {i < 6
                    ? "GitHub Actions / registre"
                    : "K3s privé / opérateur"}
                </small>
              </span>
              {index === i && <ChevronRight size={16} />}
            </button>
          ))}
        </nav>
        <section className="journey-stage">
          <div className="stage-header">
            <span className="eyebrow">
              ÉTAPE {String(index + 1).padStart(2, "0")} / {stages.length}
            </span>
            <Badge tone="green">Preuve vérifiée</Badge>
          </div>
          <div className="stage-symbol">
            <GitBranch size={32} />
          </div>
          <h2>{current.sub}</h2>
          <p>{current.body}</p>
          <div className="terminal">
            <div>
              <span />
              <span />
              <span />
              <small>RECORDED EVIDENCE / {dateLabel}</small>
            </div>
            <code>{current.value}</code>
          </div>
          {index === 3 && (
            <div className="scan-comparison">
              <div>
                <Badge tone="amber">Refusée</Badge>
                <strong>
                  {s.baselineHigh} HIGH · {s.baselineCritical} CRITICAL
                </strong>
                <External
                  path={`https://github.com/Boualili-Youcef/Asteria/actions/runs/${s.baselineRun}`}
                >
                  Base Debian historique
                </External>
              </div>
              <ArrowRight size={20} />
              <div>
                <Badge tone="green">Gate réussi</Badge>
                <strong>
                  {s.high} HIGH · {s.critical} CRITICAL détectée
                </strong>
                <small>Image Demo · périmètre Trivy</small>
              </div>
            </div>
          )}
          <details key={index}>
            <summary>Pourquoi ce contrôle ? Quelle limite ?</summary>
            <p>{current.detail}</p>
          </details>
          <Evidence
            path={current.source}
            context={
              index < 6
                ? "CI GitHub Actions / GHCR"
                : "K3s source · asteria-demo"
            }
          />
          <ReplayControls
            index={index}
            total={stages.length}
            onChange={change}
            {...replay}
          />
          <small className="muted">
            Lecture à cadence pédagogique ; les durées affichées restent celles
            des preuves.
          </small>
        </section>
      </div>
      <section className="digest-bridge">
        <div>
          <span className="eyebrow">CI A PUBLIÉ</span>
          <strong>Un artefact immuable</strong>
          <code>{r.digest}</code>
        </div>
        <span className="bridge-check">
          <Check size={24} />
        </span>
        <div>
          <span className="eyebrow mint">K3S A EXÉCUTÉ</span>
          <strong>Le même digest, observé</strong>
          <code>{r.digest}</code>
        </div>
      </section>
    </>
  );
}
