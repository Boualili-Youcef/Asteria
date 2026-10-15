import { lazy, Suspense, useEffect, useRef, useState } from "react";
import {
  ArrowRight,
  ArrowUpRight,
  Box,
  ChevronRight,
  CircuitBoard,
  Command,
  FileCheck2,
  GitBranch,
  Github,
  Layers3,
  Menu,
  Route,
  ShieldCheck,
  Sparkles,
  X,
} from "lucide-react";
import { data, dateLabel, repo, seconds } from "./data";
import { Badge, Evidence, External } from "./components";
import { Delivery, Incidents, Services, Engineering, Proofs } from "./views";
const Architecture = lazy(() => import("./Architecture"));
const items = [
  ["overview", "Vue d’ensemble", Layers3],
  ["architecture", "Architecture", CircuitBoard],
  ["delivery", "Delivery Journey", GitBranch],
  ["incidents", "Incident Lab", ShieldCheck],
  ["services", "Service Catalog", Box],
  ["engineering", "Décisions & évolution", Route],
  ["proofs", "Registre de preuves", FileCheck2],
] as const;
export type View = (typeof items)[number][0];
export function readRoute() {
  const p = new URLSearchParams(location.search);
  const candidate = p.get("view") || "overview";
  return {
    view: items.some((i) => i[0] === candidate)
      ? (candidate as View)
      : ("overview" as View),
    invalid: !items.some((i) => i[0] === candidate),
    params: p,
  };
}
export default function App() {
  const [route, setRoute] = useState(readRoute),
    [menu, setMenu] = useState(false);
  const main = useRef<HTMLElement>(null);
  useEffect(() => {
    const sync = () => setRoute(readRoute());
    window.addEventListener("popstate", sync);
    return () => window.removeEventListener("popstate", sync);
  }, []);
  const update = (
    changes: Record<string, string | number | null>,
    replace = false,
  ) => {
    const p = new URLSearchParams(location.search);
    Object.entries(changes).forEach(([k, v]) =>
      v === null ? p.delete(k) : p.set(k, String(v)),
    );
    const url = `${location.pathname}?${p}`;
    if (replace) history.replaceState({}, "", url);
    else history.pushState({}, "", url);
    setRoute(readRoute());
  };
  const navigate = (view: View) => {
    update({
      view,
      step: null,
      node: null,
      layer: null,
      incident: null,
      service: null,
    });
    setMenu(false);
    window.scrollTo(0, 0);
    main.current?.focus();
  };
  const tour = route.params.get("tour") === "1";
  const tourPages: View[] = [
    "overview",
    "architecture",
    "delivery",
    "incidents",
    "engineering",
  ];
  const tourIndex = Math.max(0, tourPages.indexOf(route.view));
  const step = (key: string, total: number) =>
    Math.min(total - 1, Math.max(0, Math.trunc(Number(route.params.get(key))) || 0));
  const title = items.find((i) => i[0] === route.view)![1];
  useEffect(() => {
    document.title = `${title} · Asteria Platform Console`;
  }, [title]);
  return (
    <>
      <a className="skip" href="#main">
        Aller au contenu
      </a>
      <aside
        className={`sidebar ${menu ? "open" : ""}`}
        aria-label="Navigation principale"
      >
        <a
          className="brand"
          href="?view=overview"
          onClick={(e) => {
            e.preventDefault();
            navigate("overview");
          }}
        >
          <span className="brand-mark">
            A<span>·</span>
          </span>
          <span>
            ASTERIA<small>PLATFORM CONSOLE</small>
          </span>
        </a>
        <div className="workspace">
          <span className="workspace-icon">
            <Command size={16} />
          </span>
          <div>
            Platform Engineering<small>Lab OpenStack / K3s</small>
          </div>
          <Badge>LAB</Badge>
        </div>
        <div className="nav-label">EXPLORER LE SYSTÈME</div>
        <nav>
          {items.map(([id, label, Icon], i) => (
            <a
              href={`?view=${id}`}
              key={id}
              aria-current={route.view === id ? "page" : undefined}
              onClick={(e) => {
                e.preventDefault();
                navigate(id);
              }}
            >
              <Icon size={18} />
              <span>{label}</span>
              <small>0{i + 1}</small>
            </a>
          ))}
        </nav>
        <button
          className="tour-launch"
          onClick={() => {
            navigate("overview");
            update({ view: "overview", tour: 1 });
          }}
        >
          <Sparkles size={17} />
          <span>
            Visite guidée<small>5 étapes · moins de 3 minutes</small>
          </span>
          <ArrowRight size={16} />
        </button>
        <div className="sidebar-bottom">
          <div className="snapshot-label">
            <span /> PREUVES ARCHIVÉES
          </div>
          <p>
            {dateLabel}
            <br />
            Aucune connexion au cluster
          </p>
          <a href={repo} target="_blank" rel="noopener noreferrer">
            <Github size={16} /> Explorer le dépôt <ArrowUpRight size={14} />
          </a>
          <small>Conçu & construit par Youcef Boualili</small>
        </div>
      </aside>
      <div className="app-shell">
        <header className="topbar">
          <button
            className="mobile-menu"
            onClick={() => setMenu(!menu)}
            aria-label={menu ? "Fermer le menu" : "Ouvrir le menu"}
            aria-expanded={menu}
          >
            {menu ? <X /> : <Menu />}
          </button>
          <span>
            Asteria <ChevronRight size={13} /> <strong>{title}</strong>
          </span>
          <div>
            <span className="static-indicator" /> Console statique{" "}
            <span className="top-date">/ {dateLabel}</span>
          </div>
        </header>
        {tour && (
          <section className="tour-bar" aria-label="Visite guidée">
            <div>
              <Sparkles size={18} />
              <span>
                <strong>Visite guidée · {tourIndex + 1}/5</strong>
                <small>
                  {
                    [
                      "Comprendre le problème et le résultat.",
                      "Explorer les frontières : source, démo, historique.",
                      "Suivre la preuve du commit au digest exécuté.",
                      "Observer un échec et son retour arrière.",
                      "Comprendre les choix et les limites restantes.",
                    ][tourIndex]
                  }
                </small>
              </span>
            </div>
            <div>
              <button
                disabled={tourIndex === 0}
                onClick={() => navigate(tourPages[tourIndex - 1])}
              >
                Retour
              </button>
              <button
                className="primary compact"
                onClick={() =>
                  tourIndex === 4
                    ? update({ tour: null })
                    : navigate(tourPages[tourIndex + 1])
                }
              >
                {tourIndex === 4 ? "Terminer" : "Continuer"}
                <ArrowRight size={14} />
              </button>
              <button
                aria-label="Fermer la visite guidée"
                onClick={() => update({ tour: null })}
              >
                <X size={17} />
              </button>
            </div>
          </section>
        )}
        <main id="main" ref={main} tabIndex={-1}>
          {route.invalid && (
            <p className="notice" role="status">
              Cette vue n’existe pas. La vue d’ensemble reste disponible.
            </p>
          )}
          {route.view === "overview" && <Overview navigate={navigate} />}
          {route.view === "architecture" && (
            <Suspense fallback={<p role="status">Chargement du graphe…</p>}>
              <Architecture params={route.params} update={update} />
            </Suspense>
          )}
          {route.view === "delivery" && (
            <Delivery
              index={step("step", 10)}
              change={(i) => update({ step: i }, true)}
            />
          )}
          {route.view === "incidents" && (
            <Incidents params={route.params} update={update} />
          )}
          {route.view === "services" && (
            <Services params={route.params} update={update} />
          )}
          {route.view === "engineering" && <Engineering />}
          {route.view === "proofs" && <Proofs />}
        </main>
        <footer className="footer">
          <span>
            ASTERIA{" "}
            <span className="muted">
              / Un lab explicable, une livraison traçable.
            </span>
          </span>
          <span>Ni HA, ni DR, ni SLO de production démontrés.</span>
        </footer>
      </div>
    </>
  );
}
function Overview({ navigate }: { navigate: (v: View) => void }) {
  const m = data.metrics;
  return (
    <>
      <div className="overview-heading">
        <span className="eyebrow">
          <span className="tiny-cross">✳</span> LAB PLATFORM ENGINEERING
        </span>
        <Badge>DONNÉES DÉMONSTRATIVES · PREUVES DATÉES</Badge>
      </div>
      <section className="hero">
        <div>
          <h1>
            De l’infrastructure
            <br />
            au déploiement <em>vérifié.</em>
          </h1>
          <p>
            Construire une plateforme ne s’arrête pas à publier une image.
            <br className="desktop-break" /> Asteria relie le code, ce que K3s
            exécute et la preuve du retour arrière.
          </p>
          <div className="hero-actions">
            <button
              className="primary"
              onClick={() => navigate("architecture")}
            >
              Explorer l’architecture <ArrowRight size={17} />
            </button>
            <button onClick={() => navigate("delivery")}>
              <GitBranch size={17} /> Voir une release de bout en bout
            </button>
          </div>
          <div className="hero-note">
            <span className="small-line" /> Infrastructure privée. Exploration
            publique. Aucun accès cloud requis.
          </div>
        </div>
        <div className="hero-emblem" aria-hidden="true">
          <div className="orbit o1" />
          <div className="orbit o2" />
          <div className="orbit o3" />
          <div className="emblem-core">
            A<span>ASTERIA / SYSTEM 01</span>
          </div>
          <span className="coord c1">INFRASTRUCTURE</span>
          <span className="coord c2">DELIVERY VERIFIED</span>
          <span className="orbit-dot d1" />
          <span className="orbit-dot d2" />
        </div>
      </section>
      <div className="metric-caption">
        EMPREINTE & RÉSULTATS OBSERVÉS{" "}
        <span>{dateLabel} · Lab source et namespace de démo</span>
      </div>
      <section className="metrics" aria-label="Résultats datés">
        {[
          [m.vms, "VM OpenStack", "Source privé"],
          [m.nodes, "nœuds K3s", `${m.ready}/${m.nodes} Ready à la collecte`],
          [m.services, "microservices", "Python / FastAPI"],
          [m.findings, "constats audités", "Audit M16 · fin de phase 1"],
          [seconds(m.promotion), "promotion K3s", "Digest exécuté vérifié"],
          [
            seconds(m.rollback),
            "drill & rollback",
            "Inclut timeout Helm 180 s",
          ],
        ].map(([v, l, n]) => (
          <div key={l}>
            <strong>{v}</strong>
            <span>{l}</span>
            <small>{n}</small>
          </div>
        ))}
      </section>
      <div className="overview-grid">
        <section className="panel topology-preview">
          <div className="panel-heading">
            <div>
              <span className="eyebrow">01 / SYSTEM MAP</span>
              <h2>Une infrastructure, des frontières claires.</h2>
            </div>
            <button
              className="icon-button"
              aria-label="Ouvrir le graphe d’architecture"
              onClick={() => navigate("architecture")}
            >
              <ArrowUpRight size={20} />
            </button>
          </div>
          <div
            className="mini-map"
            aria-label="Schéma conceptuel OpenStack, cluster K3s et namespace de démo"
          >
            <div className="map-rail">
              <span>OPENSTACK PRIVÉ</span>
              <small>Terraform · Ansible</small>
            </div>
            <div className="map-source">
              <div className="mini-node">
                <Command size={18} />
                <strong>Bastion</strong>
                <small>Accès privé</small>
              </div>
              <span className="map-connector">→</span>
              <div className="cluster-box">
                <span>
                  K3s source <Badge>Flannel</Badge>
                </span>
                <div className="mini-workers">
                  <div>
                    Control plane<small>SQLite · unique</small>
                  </div>
                  <div>
                    2 workers<small>Applications</small>
                  </div>
                </div>
                <div className="demo-boundary">
                  <span className="mini-dot" /> asteria-demo{" "}
                  <small>Orders → Redis → Worker → PostgreSQL</small>
                </div>
              </div>
              <span className="map-connector">↔</span>
              <div className="mini-node">
                <Layers3 size={19} />
                <strong>PostgreSQL</strong>
                <small>VM historique</small>
              </div>
            </div>
            <div className="map-foot">
              <span>
                <i /> Source historique
              </span>
              <span>
                <i className="green" /> Démo isolée
              </span>
              <small>Schéma explicatif · pas de télémétrie</small>
            </div>
          </div>
          <button
            className="text-action"
            onClick={() => navigate("architecture")}
          >
            Explorer les composants et leurs flux <ArrowRight size={16} />
          </button>
        </section>
        <section className="panel proof-highlight">
          <span className="eyebrow">02 / LA PREUVE PAR L’ÉCHEC</span>
          <Badge tone="green">Rollback vérifié</Badge>
          <h2>
            Une release qui échoue.
            <br />
            Un service qui revient.
          </h2>
          <p>
            Une readiness invalide bloque la candidate. Helm revient à la
            révision saine ; digest, probes et parcours métier sont revérifiés.
          </p>
          <div className="result-line">
            <span>Readiness invalide</span>
            <span className="line-dots" />
            <Badge tone="green">Révision saine</Badge>
          </div>
          <button className="text-action" onClick={() => navigate("incidents")}>
            Rejouer l’incident enregistré <ArrowRight size={16} />
          </button>
          <Evidence />
        </section>
      </div>
      <section className="progression">
        <div>
          <span className="eyebrow">LE POINT DE DÉPART</span>
          <h3>Fonctionnel, mais fragile.</h3>
          <p>
            Trois modes de déploiement. Des images publiées que le cluster ne
            consomme pas. Un audit de {m.findings} constats.
          </p>
        </div>
        <ArrowRight className="progress-arrow" />
        <div>
          <span className="eyebrow">L’AMÉLIORATION CIBLÉE</span>
          <h3>Rendre la livraison traçable.</h3>
          <p>
            Tests et scan bloquant, artefact immuable, promotion privée et
            droits limités dans une démo isolée.
          </p>
        </div>
        <ArrowRight className="progress-arrow" />
        <div>
          <span className="eyebrow mint">LE RÉSULTAT DÉMONTRÉ</span>
          <h3>Vérifier jusqu’au métier.</h3>
          <p>
            {m.orders} commandes relues, {m.archives} archives correspondantes.
            Un retour arrière contrôlé. Les limites restent visibles.
          </p>
        </div>
      </section>
      <div className="overview-bottom">
        <p>
          <strong>
            Une démarche d’ingénierie, pas une promesse de production.
          </strong>
          <br />
          Le staging Cilium est historique et inaccessible. Le source reste sur
          Flannel. T08–T18 ne sont pas terminées.
        </p>
        <External path="docs/adr/ADR-015-demo-v1-source-only.md">
          Lire le périmètre et les limites
        </External>
      </div>
    </>
  );
}
