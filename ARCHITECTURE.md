# Deployment Architecture — Shopizer on Colima + Kubernetes

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
│       │                  │                          │                │
└───────┼──────────────────┼──────────────────────────┼───────────────┘
        │                  │                          │
        ▼                  ▼                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│              GitHub Actions Artifact Storage                         │
│                                                                      │
│  shopizer-jar          shopizer-shop-build    shopizer-admin-dist    │
│  (shopizer.jar)        (build/ folder)        (dist/ folder)         │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               │  deploy-local.sh
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LOCAL MACHINE                                      │
│                                                                      │
│  1. Download artifacts (with progress bar)                           │
│  2. docker build → shopizer-backend:local                            │
│                  → shopizer-storefront:local                         │
│                  → shopizer-admin:local                              │
│  3. Load images into Colima containerd                               │
│  4. kubectl set image + rollout restart                              │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    COLIMA (local machine)                            │
│                    Kubernetes cluster                                │
│                                                                      │
│  namespace: shopizer                                                 │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                                                             │    │
│  │  ┌──────────────────┐   ┌──────────────────┐               │    │
│  │  │ shopizer-backend │   │shopizer-storefront│               │    │
│  │  │ image: local     │   │image: local       │               │    │
│  │  │ port: 8080       │   │port: 80           │               │    │
│  │  └────────┬─────────┘   └────────┬──────────┘               │    │
│  │           │                      │                           │    │
│  │  ┌────────▼─────────┐   ┌────────▼──────────┐               │    │
│  │  │ NodePort :30080  │   │NodePort :30300    │               │    │
│  │  └──────────────────┘   └───────────────────┘               │    │
│  │                                                             │    │
│  │  ┌──────────────────┐   ┌──────────────────┐               │    │
│  │  │  shopizer-admin  │   │     mysql         │               │    │
│  │  │  image: local    │   │  mysql:8.0        │               │    │
│  │  │  port: 80        │   │  port: 3306       │               │    │
│  │  └────────┬─────────┘   └──────────────────┘               │    │
│  │           │                  (internal only)                │    │
│  │  ┌────────▼─────────┐                                       │    │
│  │  │ NodePort :30400  │                                       │    │
│  │  └──────────────────┘                                       │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         BROWSER                                      │
│                                                                      │
│  localhost:30300  →  Storefront (React + Nginx)                      │
│  localhost:30400  →  Admin Panel (Angular + Nginx)                   │
│  localhost:30080  →  Backend API (Spring Boot + MySQL)               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Summary

```
┌──────────────────────┬────────────────────┬──────────────────────────┐
│ Component            │ Tech               │ URL                      │
├──────────────────────┼────────────────────┼──────────────────────────┤
│ shopizer-backend     │ Java 17 Spring Boot│ localhost:30080/api/v1/  │
│ shopizer-storefront  │ React + Nginx       │ localhost:30300           │
│ shopizer-admin       │ Angular + Nginx     │ localhost:30400           │
│ mysql                │ MySQL 8.0          │ internal :3306            │
└──────────────────────┴────────────────────┴──────────────────────────┘
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
        ├── load images → Colima containerd
        ├── kubectl set image (all 3 deployments)
        ├── kubectl rollout restart
        └── kubectl rollout status → ✅ done
```
