# Deployment Architecture — Shopizer on Colima + Kubernetes

## CI/CD Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER                                    │
│                    git push → GitHub                                 │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS (CI)                               │
│                                                                      │
│  shopizer          shopizer-shop-reactjs      shopizer-admin         │
│  ─────────         ─────────────────────      ─────────────          │
│  mvn test          npm test                   npm build              │
│  mvn package       npm build                  docker build           │
│  docker build      docker build               docker push → GHCR    │
│  docker push       docker push → GHCR                               │
│       │                  │                          │                │
└───────┼──────────────────┼──────────────────────────┼───────────────┘
        │                  │                          │
        ▼                  ▼                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│              GHCR (GitHub Container Registry)                        │
│                                                                      │
│  ghcr.io/.../shopizer:sha      ghcr.io/.../shopizer-shop:latest     │
│  ghcr.io/.../shopizer:latest   ghcr.io/.../shopizer-admin:latest    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS (CD)                               │
│                                                                      │
│  kubectl set image deployment/shopizer-backend ...                   │
│  kubectl set image deployment/shopizer-storefront ...                │
│  kubectl set image deployment/shopizer-admin ...                     │
│  kubectl rollout status ...                                          │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  KUBECONFIG_DATA secret
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
│  │  │ Deployment       │   │Deployment         │               │    │
│  │  │ replicas: 1      │   │replicas: 1        │               │    │
│  │  │ port: 8080       │   │port: 80           │               │    │
│  │  └────────┬─────────┘   └────────┬──────────┘               │    │
│  │           │                      │                           │    │
│  │  ┌────────▼─────────┐   ┌────────▼──────────┐               │    │
│  │  │ NodePort :30080  │   │NodePort :30300    │               │    │
│  │  └──────────────────┘   └───────────────────┘               │    │
│  │                                                             │    │
│  │  ┌──────────────────┐                                       │    │
│  │  │  shopizer-admin  │                                       │    │
│  │  │  Deployment      │                                       │    │
│  │  │  replicas: 1     │                                       │    │
│  │  │  port: 80        │                                       │    │
│  │  └────────┬─────────┘                                       │    │
│  │           │                                                 │    │
│  │  ┌────────▼─────────┐                                       │    │
│  │  │ NodePort :30400  │                                       │    │
│  │  └──────────────────┘                                       │    │
│  │                                                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         BROWSER                                      │
│                                                                      │
│  localhost:30300  →  Storefront (React)                              │
│  localhost:30400  →  Admin Panel (Angular)                           │
│  localhost:30080  →  Backend API (Spring Boot)                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Summary

```
┌──────────────────────┬────────────────────┬──────────────────────────┐
│ Component            │ Tech               │ Exposed At               │
├──────────────────────┼────────────────────┼──────────────────────────┤
│ shopizer-backend     │ Java 17 Spring Boot│ localhost:30080/api/v1/  │
│ shopizer-storefront  │ React + Nginx       │ localhost:30300           │
│ shopizer-admin       │ Angular + Nginx     │ localhost:30400           │
└──────────────────────┴────────────────────┴──────────────────────────┘
```

---

## Trigger Flow

```
push to main
     │
     ├── CI runs (test → build → docker push to GHCR)
     │
     └── CD triggers on CI success
              │
              └── kubectl set image → rolling update → pods replaced
                       │
                       ├── success → deploy complete
                       └── failure → kubectl rollout undo
```

---

## Key Design Decisions

- **GHCR** — free, integrated with GitHub, no extra credentials beyond `GITHUB_TOKEN`
- **NodePort** — simplest for local Colima, no cloud load balancer needed
- **`kubectl set image`** — zero-downtime rolling update per deployment
- **`KUBECONFIG_DATA` secret** — base64-encoded kubeconfig lets GitHub Actions reach Colima
