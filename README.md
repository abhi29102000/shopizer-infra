# shopizer-infra

Kubernetes deployment plan and architecture for the Shopizer ecommerce platform.

## Contents

| File | Description |
|---|---|
| `DEPLOYMENT_PLAN.md` | Full CD deployment plan using GitHub Actions + Colima + Kubernetes |
| `ARCHITECTURE.md` | Deployment architecture diagram |
| `k8s/` | Kubernetes manifests for all 3 services |

## Services

| Service | Repo | Port |
|---|---|---|
| Backend (Spring Boot) | [shopizer](https://github.com/abhi29102000/shopizer) | 30080 |
| Storefront (React) | [shopizer-shop-reactjs](https://github.com/abhi29102000/shopizer-shop-reactjs) | 30300 |
| Admin (Angular) | [shopizer-admin](https://github.com/abhi29102000/shopizer-admin) | 30400 |

## Quick Start

```bash
# Start Colima with Kubernetes
colima start --kubernetes --cpu 4 --memory 8

# Deploy all services
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/backend/
kubectl apply -f k8s/storefront/
kubectl apply -f k8s/admin/
```
