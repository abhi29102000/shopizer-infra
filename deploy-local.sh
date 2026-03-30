#!/bin/bash
set -e

GITHUB_TOKEN="${GITHUB_TOKEN:?Error: GITHUB_TOKEN env variable is not set. Run: export GITHUB_TOKEN=your_token}"
WORK_DIR="/tmp/shopizer-deploy"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p $WORK_DIR

log() { echo "[$(date '+%H:%M:%S')] $1"; }

# ── Helper: download artifact from GitHub ─────────────────────────────────────
download_artifact() {
  local REPO=$1 RUN_ID=$2 ARTIFACT_NAME=$3 DEST=$4

  log "Downloading $ARTIFACT_NAME from $REPO (run $RUN_ID)..."
  ARTIFACT_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/abhi29102000/$REPO/actions/runs/$RUN_ID/artifacts" | \
    python3 -c "import sys,json; arts=json.load(sys.stdin)['artifacts']; print(next(a['id'] for a in arts if a['name']=='$ARTIFACT_NAME'))")

  curl -L -# -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/abhi29102000/$REPO/actions/artifacts/$ARTIFACT_ID/zip" \
    -o "$WORK_DIR/$ARTIFACT_NAME.zip"

  mkdir -p "$DEST"
  unzip -q -o "$WORK_DIR/$ARTIFACT_NAME.zip" -d "$DEST"
  log "✅ $ARTIFACT_NAME downloaded"
}

# ── Get latest successful CI run IDs ──────────────────────────────────────────
log "Fetching latest CI run IDs..."
BACKEND_RUN=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/abhi29102000/shopizer/actions/workflows/ci.yml/runs?status=success&per_page=1" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['workflow_runs'][0]['id'])")

STOREFRONT_RUN=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/abhi29102000/shopizer-shop-reactjs/actions/workflows/ci.yml/runs?status=success&per_page=1" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['workflow_runs'][0]['id'])")

ADMIN_RUN=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/abhi29102000/shopizer-admin/actions/workflows/ci.yml/runs?status=success&per_page=1" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['workflow_runs'][0]['id'])")

log "Backend run: $BACKEND_RUN | Storefront run: $STOREFRONT_RUN | Admin run: $ADMIN_RUN"

# ── Download artifacts ─────────────────────────────────────────────────────────
download_artifact "shopizer"              $BACKEND_RUN    "shopizer-jar"        "$WORK_DIR/backend"
download_artifact "shopizer-shop-reactjs" $STOREFRONT_RUN "shopizer-shop-build" "$WORK_DIR/storefront"
download_artifact "shopizer-admin"        $ADMIN_RUN      "shopizer-admin-dist" "$WORK_DIR/admin"

# ── Build Docker images ────────────────────────────────────────────────────────
log "Building backend image..."
mkdir -p $WORK_DIR/backend-ctx/target $WORK_DIR/backend-ctx/files
cp $WORK_DIR/backend/shopizer.jar $WORK_DIR/backend-ctx/target/
cp /Users/abhisheksharma/Documents/aiworkshop/shopizer/sm-shop/SALESMANAGER.h2.db $WORK_DIR/backend-ctx/
cp /Users/abhisheksharma/Documents/aiworkshop/shopizer/sm-shop/Dockerfile $WORK_DIR/backend-ctx/
docker build $WORK_DIR/backend-ctx -t shopizer-backend:local

log "Building storefront image..."
mkdir -p $WORK_DIR/storefront-ctx/build $WORK_DIR/storefront-ctx/conf/conf.d
cp -r $WORK_DIR/storefront/. $WORK_DIR/storefront-ctx/build/
cp /Users/abhisheksharma/Documents/aiworkshop/shopizer-shop-reactjs/env.sh $WORK_DIR/storefront-ctx/
cp /Users/abhisheksharma/Documents/aiworkshop/shopizer-shop-reactjs/.env $WORK_DIR/storefront-ctx/
cp /Users/abhisheksharma/Documents/aiworkshop/shopizer-shop-reactjs/conf/conf.d/default.conf $WORK_DIR/storefront-ctx/conf/conf.d/
cat > $WORK_DIR/storefront-ctx/Dockerfile <<'EOF'
FROM nginx:stable-alpine
RUN rm -rf /etc/nginx/conf.d
COPY conf /etc/nginx
COPY build /usr/share/nginx/html
RUN apk add --no-cache bash
COPY env.sh /usr/share/nginx/html/env.sh
COPY .env /usr/share/nginx/html/.env
RUN chmod +x /usr/share/nginx/html/env.sh
EXPOSE 80
CMD ["/bin/bash", "-c", "/usr/share/nginx/html/env.sh && nginx -g 'daemon off;'"]
EOF
docker build $WORK_DIR/storefront-ctx -t shopizer-storefront:local

log "Building admin image..."
mkdir -p $WORK_DIR/admin-ctx/dist
cp -r $WORK_DIR/admin/. $WORK_DIR/admin-ctx/dist/
cp /Users/abhisheksharma/Documents/aiworkshop/shopizer-admin/docker/nginx.conf $WORK_DIR/admin-ctx/
cat > $WORK_DIR/admin-ctx/Dockerfile <<'EOF'
FROM nginx:alpine
COPY dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
CMD ["/bin/sh", "-c", "envsubst < /usr/share/nginx/html/assets/env.template.js > /usr/share/nginx/html/assets/env.js && exec nginx -g 'daemon off;'"]
EOF
docker build $WORK_DIR/admin-ctx -t shopizer-admin:local

# ── Deploy with Docker Compose ─────────────────────────────────────────────────
log "Deploying with Docker Compose..."
cd "$SCRIPT_DIR"
docker compose up -d --force-recreate

log "✅ Deployment complete!"
echo ""
docker compose ps
echo ""
echo "Backend:    http://localhost:8080/api/v1/store/DEFAULT"
echo "Storefront: http://localhost:3000"
echo "Admin:      http://localhost:4200"
