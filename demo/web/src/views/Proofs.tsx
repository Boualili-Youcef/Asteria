import { FileCheck2 } from "lucide-react";
import { data, dateLabel } from "../data";
import { Badge, Evidence, External, PageIntro } from "../components";
export function Proofs() {
  return (
    <>
      <PageIntro
        eyebrow="06 / EVIDENCE REGISTER"
        title="Remonter à la source, sans raccourci."
      >
        Le site compile une sélection publique typée. Il ne copie ni le dépôt,
        ni les rapports internes bruts dans le bundle.
      </PageIntro>
      <div className="proof-summary">
        <FileCheck2 size={35} />
        <div>
          <Badge tone="green">Invariants vérifiés au build</Badge>
          <h2>Commit = run CI = digest promu = image exécutée.</h2>
          <p>
            Rollback réussi, archives correspondantes et images historiques
            inchangées sont exigés. Une incohérence bloque le build.
          </p>
        </div>
      </div>
      <div className="proof-grid">
        {data.sources.map((s) => (
          <article className="panel source-card" key={s.path}>
            <Badge
              tone={
                s.kind === "recorded"
                  ? "green"
                  : s.kind === "historical"
                    ? "blue"
                    : "amber"
              }
            >
              {s.kind === "recorded"
                ? "Preuve enregistrée"
                : s.kind === "historical"
                  ? "Audit historique"
                  : "État éditorial initial"}
            </Badge>
            <h3>{s.path.split("/").at(-1)}</h3>
            <p>{s.context}</p>
            <code className="hash">
              SHA-256 source
              <br />
              {s.sha256}
            </code>
            <Evidence
              path={s.path}
              context={s.context}
              date={s.kind === "historical" ? "26 juil. 2026" : dateLabel}
            />
          </article>
        ))}
      </div>
      <section className="panel editorial-proof">
        <h2>Une présentation initiale, des preuves qui la dépassent.</h2>
        <p>
          <code>presentation.json</code> contenait des étapes encore « à valider
          ». Le manifeste les conserve pour l’audit ; les preuves CI et K3s du
          même jour apportent les résultats réellement observés.
        </p>
        <details>
          <summary>Inspecter l’état éditorial initial</summary>
          {data.presentation.steps.map((s) => (
            <div className="initial-step" key={s.title}>
              <strong>{s.title}</strong>
              <Badge>{s.status}</Badge>
              <p>{s.description}</p>
              <External path={s.source}>Source initiale</External>
            </div>
          ))}
        </details>
      </section>
      <div className="limit-box">
        <h3>Limites du registre</h3>
        <p>
          Les SHA-256 permettent de contrôler la correspondance avec les
          fichiers du dépôt. Ils ne sont ni une signature, ni une attestation
          indépendante. Le site ne vérifie pas l’état courant du cloud.
        </p>
      </div>
    </>
  );
}
