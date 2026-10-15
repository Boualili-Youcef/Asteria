import raw from "./generated/manifest.json";
import { manifestSchema } from "./schema";
export const data = manifestSchema.parse(raw);
export const repo = "https://github.com/Boualili-Youcef/Asteria";
export const sourceUrl = (path: string) => `${repo}/blob/main/${path}`;
export const seconds = (n: number) =>
  `${n.toLocaleString("fr-FR", { minimumFractionDigits: 3, maximumFractionDigits: 3 })} s`;
export const dateLabel = new Intl.DateTimeFormat("fr-FR", {
  day: "numeric",
  month: "short",
  year: "numeric",
  timeZone: "UTC",
}).format(new Date(data.date));
export const replayDate = new Intl.DateTimeFormat("fr-FR", {
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
  timeZone: "UTC",
}).format(new Date(data.date));
export const scopes = {
  source: "Source · observation historique",
  demo: "Implémenté · démo isolée",
  staging: "Testé historiquement · staging",
  target: "Proposé · à faire",
};
