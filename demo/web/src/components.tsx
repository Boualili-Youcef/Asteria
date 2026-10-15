import {
  ArrowUpRight,
  Check,
  ChevronLeft,
  ChevronRight,
  Pause,
  Play,
  RotateCcw,
  FileText,
} from "lucide-react";
import { useEffect, useState } from "react";
import { dateLabel, sourceUrl } from "./data";
export function External({
  path,
  children,
}: {
  path: string;
  children: React.ReactNode;
}) {
  const href = path.startsWith("https://") ? path : sourceUrl(path);
  return (
    <a href={href} target="_blank" rel="noopener noreferrer">
      {children}
      <ArrowUpRight size={13} aria-hidden="true" />
    </a>
  );
}
export function Badge({
  children,
  tone = "neutral",
}: {
  children: React.ReactNode;
  tone?: "neutral" | "green" | "amber" | "blue";
}) {
  return (
    <span className={`badge ${tone}`}>
      {tone === "green" && <Check size={12} />} {children}
    </span>
  );
}
export function Evidence({
  path = "demo/evidence/kubernetes-flow-20261014.json",
  context = "K3s source · données synthétiques",
  date = dateLabel,
}: {
  path?: string;
  context?: string;
  date?: string;
}) {
  return (
    <div className="evidence">
      <FileText size={15} aria-hidden="true" />
      <div>
        <span>
          {date} · {context}
        </span>
        <External path={path}>
          Voir la preuve <code>{path.split("/").at(-1)}</code>
        </External>
      </div>
    </div>
  );
}
export function PageIntro({
  eyebrow,
  title,
  children,
}: {
  eyebrow: string;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <header className="page-intro">
      <div className="eyebrow">{eyebrow}</div>
      <h1>{title}</h1>
      <p>{children}</p>
    </header>
  );
}
export function ReplayControls({
  index,
  total,
  onChange,
  playing,
  setPlaying,
}: {
  index: number;
  total: number;
  onChange: (i: number) => void;
  playing: boolean;
  setPlaying: (b: boolean) => void;
}) {
  return (
    <div className="replay-controls">
      <button
        onClick={() => {
          onChange(0);
          setPlaying(false);
        }}
        aria-label="Recommencer le replay"
      >
        <RotateCcw size={16} />
      </button>
      <button
        disabled={index === 0}
        onClick={() => {
          onChange(index - 1);
          setPlaying(false);
        }}
        aria-label="Étape précédente"
      >
        <ChevronLeft size={18} />
      </button>
      <button
        className="play-button"
        onClick={() => {
          if (index === total - 1) onChange(0);
          setPlaying(!playing);
        }}
      >
        {playing ? <Pause size={15} /> : <Play size={15} />}{" "}
        {playing ? "Pause" : "Lire le replay"}
      </button>
      <button
        disabled={index === total - 1}
        onClick={() => {
          onChange(index + 1);
          setPlaying(false);
        }}
        aria-label="Étape suivante"
      >
        <ChevronRight size={18} />
      </button>
      <span className="mono" aria-live="polite">
        {index + 1} / {total}
      </span>
    </div>
  );
}
export function useReplay(
  index: number,
  total: number,
  change: (i: number) => void,
) {
  const [playing, setPlaying] = useState(false);
  useEffect(() => {
    if (!playing) return;
    const timer = window.setTimeout(() => {
      if (index >= total - 1) setPlaying(false);
      else change(index + 1);
    }, 2200);
    return () => clearTimeout(timer);
  }, [playing, index, total, change]);
  return { playing, setPlaying };
}
