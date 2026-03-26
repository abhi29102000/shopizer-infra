# CD Deployment Plan — Shopizer on Colima + Kubernetes

## Overview

```
GitHub Actions CI          GHCR                  GitHub Actions CD        Colima (k8s)
─────────────────    →    ──────────────    →    ──────────────────   →   ─────────────
build + test               Docker images          kubectl apply             running pods
push image                 ghcr.io/...            rolling update
```

---

## 1. Images produced by existing CI

| Repo | Image |
|---|---|
| shopizer (backend) | `ghcr.io/<org>/shopizer:<sha>` |
| shopizer-shop-reactjs | `ghcr.io/<actor>/shopizer-shop:latest` |
| shopizer-admin | `ghcr.io/<actor>/shopizer-admin:latest` |

---

## 2. Prerequisites

```bash
# Install Colima + kubectl
brew install colima kubectl

# Start Colima with Kubernetes
colima start --kubernetes --cpu 4 --memory 8

# Verify
kubectl get nodes
```

---

## 3. Kubernetes Manifests

All manifests are in the `k8s/` directory of this repo.

```
k8s/
├── namespace.yaml
├── backend/
│   ├── deployment.yaml
│   └── service.yaml
├── storefront/
│   ├── deployment.yaml
│   └── service.yaml
└── admin/
    ├── deployment.yaml
    └── service.yaml
```

---

## 4. CD GitHub Actions Workflow

Add a `cd.yml` to each repo's `.github/workflows/`. Triggers after CI pushes the image.

### Required GitHub Secret (add to each repo)
```
KUBECONFIG_DATA    # base64-encoded ~/.kube/config from Colima
```

Get it:
```bash
cat ~/.kube/config | base64 | pbcopy
```

---

### `shopizer` — `.github/workflows/cd.yml`
```yaml
name: CD

on:
  workflow_run:
    workflows: ["CI"]
    branches: [main]
    types: [completed]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG_DATA }}" | base64 -d > ~/.kube/config

      - name: Deploy backend
        run: |
          kubectl set image deployment/shopizer-backend \
            shopizer-backend=ghcr.io/${{ github.repository }}:${{ github.sha }} \
            -n shopizer
          kubectl rollout status deployment/shopizer-backend -n shopizer --timeout=120s
```

---

### `shopizer-shop-reactjs` — `.github/workflows/cd.yml`
```yaml
name: CD

on:
  workflow_run:
    workflows: ["CI"]
    branches: [main]
    types: [completed]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - name: Set kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG_DATA }}" | base64 -d > ~/.kube/config

      - name: Deploy storefront
        run: |
          kubectl set image deployment/shopizer-storefront \
            shopizer-storefront=ghcr.io/${{ github.actor }}/shopizer-shop:latest \
            -n shopizer
          kubectl rollout status deployment/shopizer-storefront -n shopizer --timeout=120s
```

---

### `shopizer-admin` — `.github/workflows/cd.yml`
```yaml
name: CD

on:
  workflow_run:
    workflows: ["CI"]
    branches: [main]
    types: [completed]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    steps:
      - name: Set kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG_DATA }}" | base64 -d > ~/.kube/config

      - name: Deploy admin
        run: |
          kubectl set image deployment/shopizer-admin \
            shopizer-admin=ghcr.io/${{ github.actor }}/shopizer-admin:latest \
            -n shopizer
          kubectl rollout status deployment/shopizer-admin -n shopizer --timeout=120s
```

---

## 5. Fix needed in shopizer-admin CI

The admin CI builds the image locally but never pushes to GHCR. Add to existing `ci.yml`:

```yaml
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Push Docker image
        run: |
          docker tag shopizer-admin:${{ github.sha }} ghcr.io/${{ github.actor }}/shopizer-admin:latest
          docker push ghcr.io/${{ github.actor }}/shopizer-admin:latest
```

---

## 6. Deployment Order (first time)

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/backend/
kubectl apply -f k8s/storefront/
kubectl apply -f k8s/admin/
```

---

## 7. Access URLs

| Service | URL |
|---|---|
| Backend API | `http://localhost:30080/api/v1/store/DEFAULT` |
| Storefront | `http://localhost:30300` |
| Admin | `http://localhost:30400` |

---

## 8. Rollback

```bash
kubectl rollout undo deployment/shopizer-backend -n shopizer
kubectl rollout undo deployment/shopizer-storefront -n shopizer
kubectl rollout undo deployment/shopizer-admin -n shopizer
```
