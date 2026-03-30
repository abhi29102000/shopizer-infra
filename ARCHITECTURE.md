# Deployment Architecture — Shopizer on Colima + Docker Compose

## Full Flow

```
Developer pushes code
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS (CI)                               │
│                                                                      │
│  shopizer          shopizer-shop-reactjs      shopizer-admin         │
│  ─────────         ─────────────────────      ─────────────          │
│  mvn test          npm test                   npm build              │
│  mvn package       npm build                  upload dist/           │
│  upload JAR        upload build/                                     │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               │  GitHub Actions Artifact Storage
                               │  shopizer-jar / shopizer-shop-build / shopizer-admin-dist
                               │
                               │  deploy-local.sh
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LOCAL MACHINE                                      │
│                                                                      │
│  1. Download artifacts (with % progress bar)                         │
│  2. docker build → shopizer-backend:local                            │
│                  → shopizer-storefront:local                         │
│                  → shopizer-admin:local                              │
│  3. docker compose up -d --force-recreate                            │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    COLIMA (Docker runtime)                           │
│                    Docker Compose                                    │
│                                                                      │
│  ┌──────────────────┐   ┌──────────────────┐                        │
│  │ shopizer-backend │   │shopizer-storefront│                        │
│  │ :8080            │   │:3000             │                        │
│  └──────────────────┘   └──────────────────┘                        │
│                                                                      │
│  ┌──────────────────┐   ┌──────────────────┐                        │
│  │  shopizer-admin  │   │     mysql         │                        │
│  │  :4200           │   │  internal :3306   │                        │
│  └──────────────────┘   └──────────────────┘                        │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         BROWSER                                      │
│                                                                      │
│  localhost:3000   →  Storefront (React + Nginx)                      │
│  localhost:4200   →  Admin Panel (Angular + Nginx)                   │
│  localhost:8080   →  Backend API (Spring Boot + MySQL)               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## deploy-local.sh Flow

```
export GITHUB_TOKEN=xxx
bash deploy-local.sh
        │
        ├── fetch latest CI run IDs (GitHub API)
        ├── download shopizer-jar        [##########] 100%
        ├── download shopizer-shop-build [##########] 100%
        ├── download shopizer-admin-dist [##########] 100%
        ├── docker build shopizer-backend:local
        ├── docker build shopizer-storefront:local
        ├── docker build shopizer-admin:local
        └── docker compose up -d --force-recreate → ✅ done
```
