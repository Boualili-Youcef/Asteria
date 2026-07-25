# notifications-worker — application manuelle

`notifications-worker.yaml` est appliqué directement par un opérateur avec
`kubectl apply`. Le worker ne possède pas d'Ingress : son Service ClusterIP
sert uniquement aux probes de validation et au scrape Prometheus.

La configuration `notifications-runtime` et le Secret
`notifications-postgres` sont créés hors Git. Aucun historique Helm, pipeline
de déploiement ou rollback commun n'existe pour ce workload.
