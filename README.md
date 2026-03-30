# shopizer-infra

Kubernetes deployment infrastructure for the Shopizer ecommerce platform on Colima.

## Repositories

| Service | Repo | CI Artifact |
|---|---|---|
| Backend (Spring Boot) | [shopizer](https://github.com/abhi29102000/shopizer) | `shopizer-jar` |
| Storefront (React) | [shopizer-shop-reactjs](https://github.com/abhi29102000/shopizer-shop-reactjs) | `shopizer-shop-build` |
| Admin (Angular) | [shopizer-admin](https://github.com/abhi29102000/shopizer-admin) | `shopizer-admin-dist` |

---

## Architecture

```
Developer pushes code
        │
        ▼
┌─────────────────────────────────────────────────────┐
│  GitHub Actions CI  (each service repo)              │
│                                                      │
│  shopizer        → test → build JAR   → upload      │
│  shopizer-shop   → test → build/      → upload      │
│  shopizer-admin  →        build dist/ → upload      │
└─────────────────────────────────────────────────────┘
        │
        │  artifacts stored in GitHub Actions
        ▼
┌─────────────────────────────────────────────────────┐
│  deploy-local.sh  (run on your machine)              │
│                                                      │
│  1. Fetch latest CI run IDs from GitHub API          │
│  2. Download JAR / build / dist artifacts            │
│  3. Build Docker images locally                      │
│  4. Load images into Colima containerd               │
│  5. kubectl set image → rolling update               │
└─────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────┐
│  Colima Kubernetes  (local machine)                  │
│  namespace: shopizer                                 │
│                                                      │
│  shopizer-backend      → localhost:30080             │
│  shopizer-storefront   → localhost:30300             │
│  shopizer-admin        → localhost:30400             │
│  mysql                 → internal :3306              │
└─────────────────────────────────────────────────────┘
```

---

## Local Deployment — Step by Step

### Prerequisites

```bash
# Install Colima and kubectl
brew install colima kubectl

# Start Colima with Kubernetes
colima start --kubernetes --cpu 4 --memory 8

# Verify cluster is running
kubectl get nodes
```

### 1. Clone this repo

```bash
git clone https://github.com/abhi29102000/shopizer-infra.git
cd shopizer-infra
```

### 2. First-time cluster setup

Apply namespace, deployments and services (only needed once):

```bash
kubectl apply -f k8s/namespace.yaml

# Deploy MySQL
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: shopizer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: "password"
            - name: MYSQL_DATABASE
              value: "SALESMANAGER"
            - name: MYSQL_USER
              value: "shopizer"
            - name: MYSQL_PASSWORD
              value: "password"
          ports:
            - containerPort: 3306
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: shopizer
spec:
  selector:
    app: mysql
  ports:
    - port: 3306
      targetPort: 3306
EOF

# Deploy the 3 services (backend, storefront, admin)
kubectl apply -f k8s/backend/
kubectl apply -f k8s/storefront/
kubectl apply -f k8s/admin/

# Set imagePullPolicy to Never (use local images)
kubectl patch deployment shopizer-backend -n shopizer \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"shopizer-backend","imagePullPolicy":"Never"}]}}}}'
kubectl patch deployment shopizer-storefront -n shopizer \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"shopizer-storefront","imagePullPolicy":"Never"}]}}}}'
kubectl patch deployment shopizer-admin -n shopizer \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"shopizer-admin","imagePullPolicy":"Never"}]}}}}'
```

### 3. Deploy latest code

Set your GitHub token and run the deploy script:

```bash
export GITHUB_TOKEN=your_github_personal_access_token
bash deploy-local.sh
```

The script will:
1. Fetch the latest successful CI run IDs automatically
2. Download artifacts (JAR / build / dist) with progress bar
3. Build Docker images locally
4. Load images into Colima
5. Rolling update all 3 pods

### 4. Access the services

| Service | URL |
|---|---|
| Backend API | http://localhost:30080/api/v1/store/DEFAULT |
| Storefront | http://localhost:30300 |
| Admin Panel | http://localhost:30400 |

---

## Rollback

```bash
kubectl rollout undo deployment/shopizer-backend    -n shopizer
kubectl rollout undo deployment/shopizer-storefront -n shopizer
kubectl rollout undo deployment/shopizer-admin      -n shopizer
```

## Check status

```bash
kubectl get pods -n shopizer
```
