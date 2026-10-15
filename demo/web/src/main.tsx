import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./style.css";
class Boundary extends React.Component<
  { children: React.ReactNode },
  { failed: boolean }
> {
  state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  render() {
    return this.state.failed ? (
      <main className="fatal">
        <h1>La console n’a pas pu s’ouvrir.</h1>
        <p>Rechargez la page ou consultez les preuves dans le dépôt.</p>
        <a href="https://github.com/Boualili-Youcef/Asteria/tree/main/demo/evidence">
          Ouvrir les preuves
        </a>
      </main>
    ) : (
      this.props.children
    );
  }
}
createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <Boundary>
      <App />
    </Boundary>
  </React.StrictMode>,
);
