#!/usr/bin/env python3
"""Build a static-only public bundle from an explicit allowlist."""
import argparse
import json
import re
from pathlib import Path
import shutil

ROOT = Path(__file__).absolute().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
output = args.output.absolute()
if output.exists() and any(output.iterdir()):
    raise SystemExit('Refusing to overwrite a nonempty output directory')
if output == ROOT or output in ROOT.parents:
    raise SystemExit('Refusing to write over repository or parent directory')
data = json.loads((ROOT / 'demo/evidence/presentation.json').read_text())
if data.get('mode') != 'dated-evidence-not-live':
    raise SystemExit('A public evidence mode must be explicit')
baseline_path = ROOT / 'demo/evidence/scan-baseline-20261014.json'
if baseline_path.is_file():
    baseline = json.loads(baseline_path.read_text())
    data['baseline_scan'] = {key: baseline[key] for key in
                            ['high_findings', 'critical_findings', 'run_id', 'promotion']}
    data['steps'][1].update(status='SCAN RÉEL · BASE HISTORIQUE REFUSÉE', short_status='BLOQUÉ',
        description='Le scan CI de la base Debian historique a bloqué la candidate : 88 signalements HIGH et 3 CRITICAL. Aucun artefact de promotion réussi n’a été émis. La variante Demo minimale doit passer le même contrôle avant acceptation.',
        command='Trivy image --severity HIGH,CRITICAL --exit-code 1',
        proof='https://github.com/Boualili-Youcef/Asteria/actions/runs/' + baseline['run_id'])
release_path = ROOT / 'demo/evidence/orders-release.json'
if release_path.is_file():
    release = json.loads(release_path.read_text())
    if (release.get('schema') != 1 or
            release.get('image') != 'ghcr.io/boualili-youcef/asteria/orders-api' or
            not re.fullmatch('sha256:[0-9a-f]{64}', release.get('digest', '')) or
            not re.fullmatch('[0-9a-f]{40}', release.get('commit', '')) or
            not re.fullmatch('[1-9][0-9]*', release.get('run_id', ''))):
        raise SystemExit('Invalid recorded release')
    data['steps'][1].update(status='CI ET SCAN RÉUSSIS · DIGEST ENREGISTRÉ', short_status='VÉRIFIÉ',
        description='Image construite et publiée par le run ' + release['run_id'] +
        ', pour le commit ' + release['commit'] + '. Tests, scan HIGH/CRITICAL et smoke réussis. SBOM et provenance attachés ; ils ne sont pas encore vérifiés à l’admission K3s.',
        command=release['image'] + '@' + release['digest'],
        proof='https://github.com/Boualili-Youcef/Asteria/actions/runs/' + release['run_id'])
report_path = ROOT / 'demo/evidence/local-e2e-20261014-r2.json'
if report_path.is_file():
    report = json.loads(report_path.read_text())
    if report.get('status') == 'passed' and report.get('cleanup') == 'passed' and report.get('cloud_mutations') is False:
        data['functional_replay'] = {
            'date': report['date'], 'duration_seconds': report['duration_seconds'],
            'checks': report['checks'], 'proof': str(report_path.relative_to(ROOT))}
        step = data['steps'][3]
        step.update(status='TEST DOCKER RÉEL RÉUSSI', short_status='VÉRIFIÉ',
                    description='Le test Docker a créé puis relu une commande et retrouvé son événement archivé par le worker. Une panne Redis a produit /ready=503 et /health=200, puis une deuxième commande a été archivée après reprise. Nettoyage vérifié. Durée totale : ' + str(report['duration_seconds']) + ' s. Ce résultat ne démontre pas un déploiement K3s.',
                    proof=str(report_path.relative_to(ROOT)))
output.mkdir(parents=True, exist_ok=True)
for name in ['index.html', 'style.css', 'app.js']:
    shutil.copyfile(ROOT / 'demo/web' / name, output / name)
(output / 'evidence.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
print(f'Static site built: {output} (four public files, no repository or credentials copied)')
