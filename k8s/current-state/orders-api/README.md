# orders-api — chart Helm interne

Le répertoire `chart/` est une release Helm minimale et spécifique à Orders.
Il déploie un Deployment, un Service annoté pour Prometheus et l'Ingress
`orders.asteria.local`.

La configuration `orders-runtime` et le Secret `orders-postgres` sont des
prérequis externes au chart. Cette divergence avec Identity est volontaire :
le chart ne standardise pas les autres applications.
