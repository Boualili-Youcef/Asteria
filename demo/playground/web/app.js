const $ = (id) => document.getElementById(id);
let loading = false;
let pending = null;
let posted = false;
let ordersReady = false;
async function api(path, options) {
  const response = await fetch(path, options);
  const result = await response.json();
  if (!response.ok)
    throw new Error(
      typeof result.detail === "string" ? result.detail : "Requête invalide",
    );
  return result;
}
function line(label, value) {
  const row = document.createElement("p");
  const title = document.createElement("small");
  title.textContent = label;
  const content = document.createElement("code");
  content.textContent = value;
  row.append(title, content);
  return row;
}
async function refresh() {
  if (loading) return;
  loading = true;
  try {
    const snapshot = await api("/api/snapshot");
    for (const name of ["orders", "worker"]) {
      const state = snapshot.services[name];
      $(name + "-health").textContent = "/health " + state.health;
      $(name + "-ready").textContent =
        "/ready " +
        state.ready +
        (state.ready === 200
          ? " · Dépendances disponibles"
          : " · Dépendance indisponible");
      $(name + "-ready").className = state.ready === 200 ? "ok" : "unready";
    }
    $("order-count").textContent = snapshot.orders_count;
    $("archive-count").textContent = snapshot.archives_count;
    $("connection").textContent =
      "Observations réelles · réseau Compose isolé · aucune connexion au cloud";
    ordersReady = snapshot.services.orders.ready === 200;
    $("submit").disabled = !ordersReady || posted;
    $("observed").textContent =
      "Dernière lecture locale : " +
      new Date(snapshot.observed_at * 1000).toLocaleTimeString("fr-FR");
    $("archives").replaceChildren();
    if (!snapshot.archives.length) {
      const empty = document.createElement("li");
      empty.textContent = "Aucun événement archivé. Créez une commande.";
      $("archives").append(empty);
    }
    for (const event of snapshot.archives) {
      const item = document.createElement("li");
      const status = document.createElement("span");
      status.className = "ok";
      status.textContent = event.type;
      const id = document.createElement("code");
      id.textContent = event.order_id;
      const date = document.createElement("small");
      date.textContent = new Date(event.processed_at).toLocaleString("fr-FR");
      item.append(status, id, date);
      $("archives").append(item);
    }
    if (pending && snapshot.archives.some((e) => e.order_id === pending.id)) {
      if ($("worker-status")) $("worker-status").remove();
      $("receipt").append(
        line("ARCHIVE CORRESPONDANTE OBSERVÉE", pending.id),
        line(
          "POST → OBSERVATION ARCHIVE (POLLING INCLUS)",
          Math.round(performance.now() - pending.start) + " ms",
        ),
      );
      pending = null;
    }
  } catch (error) {
    $("connection").textContent = "Observation indisponible : " + error.message;
    ordersReady = false;
    $("submit").disabled = true;
  } finally {
    loading = false;
  }
}
$("order-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  if (posted) return;
  posted = true;
  $("submit").disabled = true;
  const start = performance.now();
  $("receipt").textContent = "Création réelle en cours…";
  try {
    const result = await api("/api/orders", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ amount: $("amount").value }),
    });
    const read = await api(
      "/api/orders/" + encodeURIComponent(result.order.id),
    );
    if (read.id !== result.order.id)
      throw new Error("La lecture ne correspond pas à la création");
    $("receipt").replaceChildren(
      line("COMMANDE CRÉÉE ET RELUE", read.id),
      line("DURÉE API MESURÉE PAR LE BFF", result.api_duration_ms + " ms"),
    );
    const workerStatus = line(
      "WORKER",
      "En attente de l’archive correspondante…",
    );
    workerStatus.id = "worker-status";
    $("receipt").append(workerStatus);
    pending = { id: result.order.id, start };
    await refresh();
  } catch (error) {
    $("receipt").textContent = error.message;
    pending = null;
  } finally {
    posted = false;
    $("submit").disabled = !ordersReady;
  }
});
$("refresh").addEventListener("click", refresh);
refresh();
setInterval(refresh, 2000);
