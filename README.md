# shopizer-infra

Local deployment infrastructure for the Shopizer ecommerce platform using Docker Compose + Colima.

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
GitHub Actions CI (each repo) → uploads artifact to GitHub
        │
        │  deploy-local.sh
        ▼
Colima (Docker runtime) + Docker Compose
        │
        ├── mysql:8.0          → internal
        ├── shopizer-backend   → localhost:8080
        ├── shopizer-storefront→ localhost:3000
        └── shopizer-admin     → localhost:4200
```

---

## Prerequisites

```bash
# Install Colima
brew install colima

# Start Colima (Docker only, no Kubernetes)
colima start --cpu 4 --memory 8

# Verify Docker is working
docker ps
```

---

## Local Deployment

### 1. Clone this repo

```bash
git clone https://github.com/abhi29102000/shopizer-infra.git
cd shopizer-infra
```

### 2. Run the deploy script

```bash
export GITHUB_TOKEN=your_github_personal_access_token
bash deploy-local.sh
```

The script will:
1. Fetch the latest successful CI run IDs automatically
2. Download artifacts (JAR / build / dist) with progress bar
3. Build Docker images locally
4. Start all services with `docker compose up`

### 3. Access the services

| Service | URL |
|---|---|
| Backend API | http://localhost:8080/api/v1/store/DEFAULT |
| Storefront | http://localhost:3000 |
| Admin Panel | http://localhost:4200 |

---

## Useful Commands

```bash
# Check running containers
docker compose ps

# View logs
docker compose logs -f backend

# Stop all services
docker compose down

# Rollback (re-run with previous images)
docker compose up -d --force-recreate
```
