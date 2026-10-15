import {
  Background,
  Controls,
  MarkerType,
  ReactFlow,
  ReactFlowProvider,
  useReactFlow,
  type Node,
  type Edge,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { useEffect, useMemo, useState } from "react";
import { ArrowRight, List, Maximize2, X } from "lucide-react";
import { data, dateLabel, scopes } from "./data";
import { Badge, Evidence, External, PageIntro } from "./components";
type Props = {
  params: URLSearchParams;
  update: (v: Record<string, string | number | null>) => void;
};
export default function Architecture(props: Props) {
  return (
    <ReactFlowProvider>
      <Explorer {...props} />
    </ReactFlowProvider>
  );
}
function Explorer({ params, update }: Props) {
  const layer = params.get("layer") || "infra";
  const activeLayer = ["infra", "apps", "delivery"].includes(layer)
    ? layer
    : "infra";
  const [list, setList] = useState(
      () => window.matchMedia("(max-width:720px)").matches,
    ),
    [improvements, setImprovements] = useState(true);
  const selected = params.get("node"),
    [edgeId, setEdgeId] = useState<string | null>(null);
  const { fitView } = useReactFlow();
  const visible = useMemo(
    () =>
      data.nodes.filter(
        (n) =>
          n.layer === activeLayer && (improvements || n.scope === "source"),
      ),
    [activeLayer, improvements],
  );
  const nodes: Node[] = visible.map((n) => ({
    id: n.id,
    position: { x: n.x, y: n.y },
    data: {
      label: (
        <>
          <span className="node-type">
            {n.scope === "demo"
              ? "DÉMO ISOLÉE"
              : n.scope === "staging"
                ? "HISTORIQUE STAGING"
                : n.scope === "target"
                  ? "PROPOSÉ"
                  : "SOURCE"}
          </span>
          <strong>{n.title}</strong>
          <small>{n.subtitle}</small>
        </>
      ),
    },
    className: `system-node scope-${n.scope}`,
    selected: n.id === selected,
    ariaLabel: `${n.title}, ${scopes[n.scope]}`,
    style: { width: 222 },
    draggable: false,
  }));
  const edges: Edge[] = data.edges
    .filter(
      (e) =>
        visible.some((n) => n.id === e.from) &&
        visible.some((n) => n.id === e.to),
    )
    .map((e) => ({
      id: e.id,
      source: e.from,
      target: e.to,
      label: e.label,
      type: "smoothstep",
      markerEnd: { type: MarkerType.ArrowClosed, color: "#7797a7" },
      className: e.conceptual ? "conceptual" : "",
      focusable: true,
      ariaLabel: `Flux ${e.label}, de ${e.from} vers ${e.to}`,
      interactionWidth: 26,
      selected: e.id === edgeId,
    }));
  useEffect(() => {
    const t = setTimeout(() => fitView({ padding: 0.16, duration: 0 }), 80);
    return () => clearTimeout(t);
  }, [activeLayer, fitView, improvements, list]);
  const detail = visible.find((n) => n.id === selected),
    edge = data.edges.find((e) => e.id === edgeId);
  return (
    <>
      <PageIntro
        eyebrow="01 / ARCHITECTURE EXPLORER"
        title="Le système, frontière par frontière."
      >
        Sélectionnez un composant ou un flux. Explorez son rôle, sa limite et
        les fichiers qui le démontrent.
      </PageIntro>
      <div className="toolbar">
        <div className="segmented" aria-label="Couche du graphe">
          {[
            ["infra", "Infrastructure"],
            ["apps", "Applications & Data"],
            ["delivery", "Delivery & Security"],
          ].map(([id, label]) => (
            <button
              key={id}
              aria-pressed={activeLayer === id}
              onClick={() => {
                update({ layer: id, node: null });
                setEdgeId(null);
              }}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="graph-options">
          <label className="check-label">
            <input
              type="checkbox"
              checked={improvements}
              onChange={(e) => setImprovements(e.target.checked)}
            />{" "}
            Inclure démo / évolution
          </label>
          <button aria-pressed={list} onClick={() => setList(!list)}>
            <List size={16} /> Mode liste
          </button>
        </div>
      </div>
      <div className="graph-workspace">
        <section
          className="graph-panel"
          aria-label="Graphe interactif d’architecture"
        >
          <div className="graph-caption">
            <span>OPENSTACK → VM → K3s → WORKLOADS</span>
            <button
              onClick={() => fitView({ padding: 0.16 })}
              aria-label="Recentrer le graphe"
            >
              <Maximize2 size={15} /> Recentrer
            </button>
          </div>
          {list ? (
            <div className="node-list">
              {visible.map((n) => (
                <button
                  key={n.id}
                  onClick={() => {
                    update({ node: n.id });
                    setEdgeId(null);
                  }}
                  aria-pressed={selected === n.id}
                >
                  <span>
                    <strong>{n.title}</strong>
                    <small>{n.subtitle}</small>
                  </span>
                  <Badge tone={n.scope === "demo" ? "green" : "neutral"}>
                    {n.scope === "target" ? "Proposé" : n.scope}
                  </Badge>
                  <ArrowRight size={16} />
                </button>
              ))}
            </div>
          ) : (
            <div
              className="flow-canvas"
              onKeyDown={(event) => {
                if (event.key !== "Enter" && event.key !== " ") return;
                const target = event.target as Element;
                const node = target
                  .closest(".react-flow__node")
                  ?.getAttribute("data-id");
                const edge = target
                  .closest(".react-flow__edge")
                  ?.getAttribute("data-id");
                if (node) {
                  event.preventDefault();
                  update({ node });
                  setEdgeId(null);
                } else if (edge) {
                  event.preventDefault();
                  setEdgeId(edge);
                  update({ node: null });
                }
              }}
            >
              <ReactFlow
                nodes={nodes}
                edges={edges}
                onNodeClick={(_, n) => {
                  update({ node: n.id });
                  setEdgeId(null);
                }}
                onEdgeClick={(_, e) => {
                  setEdgeId(e.id);
                  update({ node: null });
                }}
                onPaneClick={() => {
                  update({ node: null });
                  setEdgeId(null);
                }}
                nodesDraggable={false}
                fitView
                minZoom={0.35}
                maxZoom={1.6}
                colorMode="dark"
                proOptions={{ hideAttribution: true }}
                aria-label="Architecture Asteria"
              >
                <Background color="#2a3947" gap={22} size={1} />
                <Controls showInteractive={false} />
              </ReactFlow>
            </div>
          )}
          <div className="graph-legend">
            <span>
              <i /> Source / observation datée
            </span>
            <span>
              <i className="green" /> Démo isolée
            </span>
            <span>
              <i className="purple" /> Staging historique
            </span>
            <span>
              <i className="amber" /> Proposé
            </span>
            <small>Pointillés : relation conceptuelle ou placement</small>
          </div>
        </section>
        <aside
          className="detail-panel"
          aria-label="Détail du composant"
          aria-live="polite"
        >
          {detail ? (
            <>
              <div className="detail-top">
                <span className="eyebrow">COMPOSANT SÉLECTIONNÉ</span>
                <button
                  aria-label="Fermer le détail"
                  onClick={() => update({ node: null })}
                >
                  <X size={16} />
                </button>
              </div>
              <Badge
                tone={
                  detail.scope === "demo"
                    ? "green"
                    : detail.scope === "target"
                      ? "amber"
                      : "blue"
                }
              >
                {scopes[detail.scope]}
              </Badge>
              <h2>{detail.title}</h2>
              <p className="mono muted">{detail.subtitle}</p>
              <h3>Responsabilité</h3>
              <p>{detail.role}</p>
              <h3>Flux entrants / sortants</h3>
              <ul className="flow-links">
                {data.edges
                  .filter((e) => e.from === detail.id || e.to === detail.id)
                  .map((e) => (
                    <li key={e.id}>
                      <button
                        onClick={() => {
                          setEdgeId(e.id);
                          update({ node: null });
                        }}
                      >
                        {
                          data.nodes.find(
                            (n) =>
                              n.id === (e.from === detail.id ? e.to : e.from),
                          )?.title
                        }
                        <span>{e.label}</span>
                      </button>
                    </li>
                  ))}
              </ul>
              <div className="limit-box">
                <strong>Limite explicite</strong>
                <p>{detail.limitation}</p>
              </div>
              <h3>Sources du dépôt</h3>
              <div className="source-list">
                {detail.sources.map((p) => (
                  <External key={p} path={p}>
                    {p}
                  </External>
                ))}
              </div>
            </>
          ) : edge ? (
            <>
              <div className="detail-top">
                <span className="eyebrow">FLUX SÉLECTIONNÉ</span>
                <button
                  aria-label="Fermer le flux"
                  onClick={() => setEdgeId(null)}
                >
                  <X size={16} />
                </button>
              </div>
              <Badge tone={edge.conceptual ? "amber" : "blue"}>
                {edge.conceptual ? "Schéma explicatif" : "Flux documenté"}
              </Badge>
              <h2>{edge.label}</h2>
              <p>
                {data.nodes.find((n) => n.id === edge.from)?.title} →{" "}
                {data.nodes.find((n) => n.id === edge.to)?.title}
              </p>
              <h3>Pourquoi ce flux ?</h3>
              <p>{edge.guarantee}</p>
              <Evidence
                path="docs/diagrams/as-is-architecture.mmd"
                context="Architecture historique + démo"
              />
            </>
          ) : (
            <div className="detail-empty">
              <span className="detail-glyph">⌘</span>
              <h2>Chaque composant a une raison d’être.</h2>
              <p>
                Sélectionnez un nœud pour comprendre sa responsabilité.
                Sélectionnez une flèche pour inspecter son niveau de garantie.
              </p>
              <small>
                Clavier : Tab pour les nœuds et les flux, Entrée pour
                sélectionner. Sur mobile, utilisez le mode liste.
              </small>
              <Evidence
                path="demo/evidence/kubernetes-audit-20261014.json"
                context="Inventaire source daté"
              />
            </div>
          )}
        </aside>
      </div>
      <div className="notice">
        <strong>Budget Nova observé le {dateLabel} :</strong> {data.metrics.cpu}
        /{data.metrics.cpuQuota} vCPU et {data.metrics.ramGiB}/
        {data.metrics.ramQuotaGiB} Gio alloués. Ce n’est pas une mesure CPU/RAM
        instantanée.
        <br />
        Les frontières affichées sont logiques. Le réseau provider est partagé.
        Le namespace de démo possède ses propres données ; le staging Cilium est
        un autre environnement historique, aujourd’hui inaccessible.
      </div>
    </>
  );
}
