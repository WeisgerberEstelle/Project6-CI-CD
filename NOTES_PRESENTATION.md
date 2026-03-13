# Notes de présentation — Projet 6 CI/CD

## Structure du projet

```
Project6/
├── G-rez-l-int-gration-et-la-livraison-continue-Application-Angular/   (Front-end)
├── G-rez-l-int-gration-et-la-livraison-continue-Application-Java/      (Back-end)
├── .github/workflows/ci.yml                                            (Pipeline CI/CD)
├── run-tests.sh                                                        (Script de tests unifié)
└── test-results/                                                       (Rapports JUnit XML)
```

---

## Etape 1 — Environnement de travail

### Prérequis installés
- Node.js 20 + npm
- Java JDK 21 (Eclipse Temurin)
- Docker + Docker Compose
- Gradle 8.7 (embarqué via gradlew)

### Lancer les applications avec Docker
```bash
# Front-end Angular → http://localhost
cd G-rez-l-int-gration-et-la-livraison-continue-Application-Angular
docker compose up -d

# Back-end Spring Boot → http://localhost:8080
cd G-rez-l-int-gration-et-la-livraison-continue-Application-Java
docker compose up -d
```

### Ports utilisés
| Service    | Port |
|------------|------|
| Angular    | 80   |
| Spring Boot| 8080 |
| PostgreSQL | 5432 |

---

## Etape 2 — Dockerisation du front-end Angular

### Dockerfile (build multi-stage)
- **Stage 1 (build)** : image `node:20.19`, installe les dépendances avec `npm ci`, compile avec `npm run build`
- **Stage 2 (runtime)** : image `nginx:1.27`, copie uniquement le dossier `dist/` compilé et la config nginx
- Avantage : l'image finale est légère, elle ne contient ni Node ni le code source, juste les fichiers statiques

### .dockerignore
Exclut `node_modules`, `dist`, `.git`, `.angular`, `coverage` pour que le build Docker soit plus rapide et l'image plus propre.

### docker-compose.yml
Un seul service `app` qui build le Dockerfile et mappe le port 80.

### Accès front
Ouvrir http://localhost dans le navigateur. On voit l'application Olympic Games Participation Tracker.

---

## Etape 3 — Dockerisation du back-end Spring Boot

### Dockerfile (build multi-stage)
- **Stage 1 (build)** : image `eclipse-temurin:21-jdk`, compile avec `./gradlew bootWar`
- **Stage 2 (runtime)** : image `eclipse-temurin:21-jre` (plus légère qu'un JDK complet), exécute le WAR
- Avantage : l'image finale contient uniquement le JRE et le fichier WAR, pas le JDK ni Gradle

### docker-compose.yml — 2 services
1. **app** (Spring Boot)
   - Variables d'environnement pour se connecter à la base : `SPRING_DATASOURCE_URL`, `USERNAME`, `PASSWORD`
   - `depends_on` avec `condition: service_healthy` → attend que PostgreSQL soit prêt avant de démarrer

2. **db** (PostgreSQL 13)
   - Variables : `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
   - Volume nommé `pgdata` → les données persistent même si on supprime le conteneur
   - Health check : `pg_isready` vérifie toutes les 5s que la base est prête (5 tentatives max)

### Accès back
Ouvrir http://localhost:8080 dans le navigateur. L'API Workshop Organizer répond.

---

## Etape 4 — Script de tests unifié

### Fichier : run-tests.sh

### Fonctionnement
1. **Nettoyage** : supprime le dossier `test-results/` des exécutions précédentes
2. **Détection automatique** des projets :
   - Si `package.json` existe → projet Angular → exécute `npm test`
   - Si `gradlew` existe → projet Java → exécute `./gradlew clean test`
3. **Rapports JUnit XML** : copiés dans `test-results/<nom-du-projet>/`
4. **Code de sortie** : 0 si tous les tests passent, 1 si au moins un échec

### Configuration des rapports
- Angular : `karma-junit-reporter` configuré dans `karma.conf.js`, génère les XML dans `reports/`
- Java : Gradle génère nativement les rapports JUnit dans `build/test-results/test/`

### Execution
```bash
bash run-tests.sh
# → Angular : 5 tests SUCCESS
# → Java : 2 tests PASSED
# → Rapports dans test-results/
```

---

## Etape 5 — Pipeline CI/CD (GitHub Actions)

### Fichier : .github/workflows/ci.yml

### Déclencheurs
- `push` sur toutes les branches
- `pull_request` sur la branche main

### Structure des jobs

```
setup → test → build-angular → release-angular → retag-angular
                build-java   → release-java   → retag-java
```

1. **setup** : calcule les noms d'images en minuscules pour GHCR
2. **test** : exécute `run-tests.sh`, publie les rapports de tests via `dorny/test-reporter` (visibles dans l'onglet Checks de la PR)
3. **build-angular / build-java** : construisent les images Docker et les poussent sur GitHub Container Registry (ghcr.io)
4. **release-angular / release-java** : exécutent semantic-release (uniquement sur main)
5. **retag-angular / retag-java** : re-taguent les images avec la version sémantique

### Cache des dépendances
- npm : `actions/setup-node` avec `cache: npm`
- Gradle : `actions/setup-java` avec `cache: gradle`
- Docker : BuildKit cache avec `type=gha` (GitHub Actions cache)

### Tags des images Docker
- `type=ref,event=branch` → tag avec le nom de la branche (ex: `main`)
- `type=sha,prefix={{branch}}-` → tag avec le SHA du commit (ex: `main-abc1234`)
- Après release → tag avec la version sémantique (ex: `1.1.2`)

### Actions
Aller sur l'onglet Actions du repo GitHub :
https://github.com/WeisgerberEstelle/Project6-CI-CD/actions
---

## Etape 6 — Releases et versioning sémantique

### Configuration : .releaserc.json (dans chaque app)

### Plugins semantic-release
1. `@semantic-release/commit-analyzer` → analyse les commits pour déterminer le type de version
2. `@semantic-release/release-notes-generator` → génère le changelog automatiquement
3. `@semantic-release/github` → crée la release GitHub
4. `@semantic-release/exec` → met à jour la version dans les fichiers du projet

### Conventional Commits
Les messages de commit suivent une convention qui détermine le bump de version :
- `fix: ...` → version patch (1.0.0 → 1.0.1)
- `feat: ...` → version minor (1.0.0 → 1.1.0)
- `BREAKING CHANGE` → version major (1.0.0 → 2.0.0)
- `chore: ...`, `docs: ...` → pas de nouvelle version

### Synchronisation de la version
- **Angular** : `npm version` met à jour `package.json`
- **Java** : `sed` met à jour le champ `version` dans `build.gradle`

### Releases créées
Visibles sur : https://github.com/WeisgerberEstelle/Project6-CI-CD/releases
- Angular : v1.0.0 → v1.1.2
- Java : v1.0.0 → v1.1.2
Chaque release contient un changelog auto-généré listant les commits inclus.

### Images GHCR
Visibles sur : https://github.com/WeisgerberEstelle?tab=packages
Chaque image est taguée avec la version sémantique (ex: `angular-app:1.1.2`).

---

## Résumé du flux complet

### Push sur une branche (ex: feat/...)
```
Commit → Push → Tests → Build image → Push sur GHCR
                                        Tags: feat-xxx + feat-xxx-abc1234
                                        (pas de release, pas de retag)
```

### Merge sur main
```
Merge → Push → Tests → Build image → Push sur GHCR
                                      Tags: main + main-abc1234
                                             ↓
                                      semantic-release analyse les commits
                                             ↓
                                      Release GitHub créée avec changelog
                                             ↓
                                      Retag image avec version sémantique
                                      (ex: angular-app:1.2.0)
```
