'use strict';
const repo = 'https://github.com/Boualili-Youcef/Asteria/blob/demo/recruiter-v1/';
document.querySelectorAll('[data-repo]').forEach(link => { link.href = repo + link.dataset.repo; });
const tabs = [...document.querySelectorAll('[data-tab]')];
function route() {
  const name = location.hash.slice(1);
  const selected = tabs.some(tab => tab.dataset.tab === name) ? name : 'deploy';
  tabs.forEach(tab => {
    const active = tab.dataset.tab === selected;
    if (active) tab.setAttribute('aria-current', 'page'); else tab.removeAttribute('aria-current');
    document.getElementById(tab.dataset.tab).hidden = !active;
  });
}
window.addEventListener('hashchange', route);
route();
fetch('evidence.json').then(response => {
  if (!response.ok) throw new Error('Evidence unavailable');
  return response.json();
}).then(data => {
  document.getElementById('source-state').textContent = data.source_state;
  document.getElementById('observed-at').textContent = data.observed_at;
  const list = document.getElementById('steps');
  if (data.baseline_scan) {
    const proof = document.getElementById('scan-proof');
    proof.hidden = false;
    proof.textContent = `Refus réellement observé en CI : la candidate utilisant la base historique Debian a été bloquée sur ${data.baseline_scan.high_findings} signalements HIGH et ${data.baseline_scan.critical_findings} CRITICAL. Cette preuve de scan est distincte du rollback K3s encore non validé.`;
  }
  if (data.functional_replay) {
    const replay = data.functional_replay;
    const descriptions = {
      order_persisted_and_matching_notification_archived: 'La commande synthétique a été persistée dans PostgreSQL et son événement retrouvé dans l’archive du worker.',
      redis_failure_readiness_503_liveness_200: 'Redis a été arrêté dans le seul environnement de test : Orders a retourné 503 sur /ready et 200 sur /health.',
      redis_recovered_second_order_archived: 'Après redémarrage de Redis, /ready est revenu à 200 et une deuxième commande a été archivée.',
      worker_counter_2: 'Le compteur du worker indique deux événements traités. Les conteneurs et le réseau du test ont ensuite été nettoyés.'
    };
    let index = 0;
    function showReplay() {
      document.getElementById('replay-title').textContent = `Étape ${index + 1} / ${replay.checks.length}`;
      document.getElementById('replay-description').textContent = descriptions[replay.checks[index]] || 'Consulter le résultat JSON.';
    }
    document.getElementById('functional-replay').hidden = false;
    document.getElementById('replay-date').textContent = `${replay.date} · durée totale mesurée : ${replay.duration_seconds} s`;
    document.getElementById('replay-proof').href = repo + replay.proof;
    document.getElementById('replay-next').addEventListener('click', () => { index = (index + 1) % replay.checks.length; showReplay(); });
    showReplay();
  }
  function select(index) {
    const step = data.steps[index];
    list.querySelectorAll('button').forEach((button, i) => button.setAttribute('aria-pressed', String(i === index)));
    document.getElementById('step-number').textContent = `ÉTAPE ${String(index + 1).padStart(2, '0')} / ${data.steps.length}`;
    document.getElementById('step-status').textContent = step.status;
    document.getElementById('step-title').textContent = step.title;
    document.getElementById('step-description').textContent = step.description;
    document.getElementById('step-command').textContent = step.command;
    document.getElementById('step-proof').href = step.proof.startsWith('https://github.com/Boualili-Youcef/Asteria/') ? step.proof : repo + step.proof;
  }
  data.steps.forEach((step, index) => {
    const li = document.createElement('li');
    const button = document.createElement('button');
    const number = document.createElement('span'); number.className = 'step-index'; number.textContent = String(index + 1).padStart(2, '0');
    const title = document.createElement('span'); title.textContent = step.title;
    const status = document.createElement('small'); status.textContent = step.short_status;
    button.append(number, title, status); button.addEventListener('click', () => select(index));
    li.append(button); list.append(li);
  });
  data.measures.forEach(item => {
    const block = document.createElement('article'); block.className = 'measure';
    const value = document.createElement('strong'); value.textContent = item.value;
    const label = document.createElement('span'); label.textContent = item.label;
    const note = document.createElement('p'); note.textContent = item.note;
    block.append(value, label, note); document.getElementById('measures').append(block);
  });
  select(0);
}).catch(() => { document.getElementById('load-error').hidden = false; });
