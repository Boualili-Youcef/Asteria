import { afterEach, describe, it, expect } from "vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { Delivery, Engineering, Services, Incidents } from "../src/views";
import { Badge } from "../src/components";
afterEach(cleanup);
describe("critical console interactions", () => {
  it("does not conflate a rejected scan with the successful candidate", () => {
    render(<Delivery index={3} change={() => {}} />);
    expect(screen.getByText("88 HIGH · 3 CRITICAL")).toBeTruthy();
    expect(screen.getByText("0 HIGH · 0 CRITICAL détectée")).toBeTruthy();
    expect(screen.getByText("Replay daté du 14/10/2026")).toBeTruthy();
  });
  it("filters 22 findings and recovers from empty search", () => {
    render(<Engineering />);
    expect(screen.getByText("22 constats affichés")).toBeTruthy();
    fireEvent.change(screen.getByLabelText("Rechercher les constats"), {
      target: { value: "nothing-will-match" },
    });
    expect(screen.getByText("Aucun constat ne correspond.")).toBeTruthy();
    fireEvent.click(screen.getByText("Réinitialiser les filtres"));
    expect(screen.getByText("22 constats affichés")).toBeTruthy();
  });
  it("labels the order flow as pedagogy and steps through the real failure boundary", () => {
    render(<Services params={new URLSearchParams()} update={() => {}} />);
    expect(screen.getByText("Simulation pédagogique")).toBeTruthy();
    fireEvent.click(screen.getByRole("button", { name: /03 Redis/ }));
    expect(screen.getByText(/Si Redis échoue ici/)).toBeTruthy();
  });
  it("shows the recorded rollback event time rather than the whole drill duration", () => {
    render(
      <Incidents params={new URLSearchParams("step=4")} update={() => {}} />,
    );
    expect(screen.getByText("rollback_verified")).toBeTruthy();
    expect(screen.getByText("t + 209,504 s")).toBeTruthy();
    fireEvent.click(screen.getByText("Comparer avant / après"));
    expect(
      screen.getByText(
        "Même digest sain avant/après, configuration de readiness rétablie.",
      ),
    ).toBeTruthy();
  });
  it("renders a neutral unavailable state without a verified badge", () => {
    render(<Badge>Non disponible</Badge>);
    expect(screen.queryByText("Preuve vérifiée")).toBeNull();
    expect(screen.getByText("Non disponible")).toBeTruthy();
  });
});
