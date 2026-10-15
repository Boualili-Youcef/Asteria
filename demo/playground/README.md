# Asteria Orders Playground — Local Docker live

Produit local opt-in, indépendant de la console GitHub Pages et du cluster
Kubernetes. Vraies applications Orders/Notifications, PostgreSQL et Redis ;
données synthétiques exclusivement. Aucun VPN, compte cloud ou GitHub requis.

## Démarrer

Prérequis : Docker avec Compose et Python 3. Depuis la racine :

```bash
bash demo/playground/start.sh
# Ouvrir http://127.0.0.1:4180
```

Le premier lancement télécharge Orders au digest de la release enregistrée et construit le worker et le BFF. Orders réutilise donc exactement l’image CI vérifiée ; aucun compte GHCR n’est nécessaire.
Le script crée `demo/playground/.env` en 0600 avec trois mots de passe aléatoires,
hors Git. Il ne renouvelle pas un secret existant. Ne jamais supprimer ce fichier
en conservant la base : les identités doivent rester concordantes.

L’UI crée une vraie commande, la relit par son UUID et observe son archive
PostgreSQL. Les compteurs sont des lectures SQL, pas des animations simulées.
Le délai POST → archive observée est mesuré dans le navigateur et inclut le
polling de deux secondes. Le BFF mesure séparément la durée de l’appel API.

## Tests et exercice Redis

```bash
python3 demo/playground/test_integration.py
```

Le test crée deux commandes jetables, exige leurs archives correspondantes
directement en PostgreSQL, arrête Redis sur ce seul projet Compose, observe
`/health=200` / `/ready=503`, le redémarre dans un `finally`, puis vérifie la
reprise. Il contrôle aussi les entrées invalides, le refus d’une Origin étrangère,
les ports et le refus d’écriture du rôle de lecture. Il ne nettoie aucune donnée.

Pour l’exercice manuel :

```bash
cd demo/playground
docker compose stop redis
# Observer /ready 503 et /health 200 sur l’UI.
docker compose start redis
# Attendre /ready 200 puis créer une nouvelle commande.
```

L’image Redis du replay CI était mise en pause ; cet exercice local arrête le
conteneur. Les deux tests vérifient une dépendance indisponible, sans prétendre
que les injections sont identiques. Ne pas comparer leurs durées comme un benchmark.

Après `npm ci` dans `demo/web`, test navigateur local avec Chrome :

```bash
node demo/playground/test-ui.mjs
```

Il crée des commandes synthétiques supplémentaires sur desktop et mobile,
attend les archives correspondantes, vérifie les erreurs console et WCAG,
et écrit deux captures dans `/tmp/asteria-playground-{desktop,mobile}.png`.

## Sécurité et limites

Seul le BFF/UI est publié : `127.0.0.1:4180`. PostgreSQL, Redis, Orders et Worker
n’ont aucun port hôte. Le réseau data Compose est interne ; seul le BFF rejoint aussi un bridge frontend pour publier la boucle locale. Le BFF a un rôle SQL
lecture seule distinct, sans privilèges Docker. Ses upstreams sont fixes ;
aucun endpoint ne lance de shell. Host/Origin sont bornés, aucune CORS permissive.
Les secrets restent côté serveur. Images/applications non root, capabilities
retirées, filesystem applicatif en lecture seule.

Ce n’est pas une plateforme authentifiée : d’autres processus du poste peuvent
appeler localhost. Ne pas exposer le port sur le réseau. Pas de TLS data interne,
HA/DR, migration automatique, outbox, ACK durable ou DLQ. Les données restent
jetables. Le worker archive des événements, il n’envoie aucun email.

Pas de bouton de chaos ni de reset. En cas de perte d’événement, les compteurs
peuvent diverger réellement. Une erreur de publication peut survenir après le
commit SQL ; inspecter la base avant de répéter une requête.

## Arrêter et nettoyer volontairement

```bash
cd demo/playground
docker compose down
# Conserve le volume et .env : redémarrage possible avec les mêmes données.
```

Uniquement pour effacer volontairement toutes les données de CE playground :

```bash
cd demo/playground
docker compose down --volumes
```

Ne pas lancer de prune global. Le nom de projet est `asteria-playground` ; le
volume est `asteria-playground_playground-data`. Le test de livraison arrête ses
conteneurs après validation, conserve le volume synthétique et les secrets
locaux pour redémarrage. Aucun autre projet Docker n’est ciblé.
