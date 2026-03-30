#!/bin/bash
# Seeds clothing category and sample products
# Run after deploy-local.sh

BASE="http://localhost:8080/api/v1"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

# Wait for backend
log "Waiting for backend..."
for i in $(seq 1 30); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' $BASE/store/DEFAULT)" = "200" ] && break
  sleep 5; printf "."
done
echo ""

# Admin token
ADMIN_TOKEN=$(curl -s -X POST "$BASE/private/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@shopizer.com","password":"password"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Create clothing category
log "Creating clothing category..."
curl -s -X POST "$BASE/private/category?store=DEFAULT" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"code":"clothing","sortOrder":1,"visible":true,"depth":1,
       "descriptions":[{"language":"en","name":"Clothing","friendlyUrl":"clothing","title":"Clothing"}]}' > /dev/null

# Seed products
log "Seeding products..."
python3 -c "
import urllib.request, json, sys

token = '$ADMIN_TOKEN'
products = [
  ('blue-tshirt-001',    'Blue Cotton T-Shirt',   29.99),
  ('black-jeans-002',    'Black Slim Jeans',       59.99),
  ('white-sneakers-003', 'White Sneakers',         89.99),
  ('red-hoodie-004',     'Red Hoodie',             49.99),
  ('green-jacket-005',   'Green Bomber Jacket',   119.99),
  ('grey-cap-006',       'Grey Baseball Cap',      19.99),
]
for sku, name, price in products:
    payload = json.dumps({
        'sku': sku, 'available': True, 'price': price, 'quantity': 20,
        'descriptions': [{'name': name, 'language': 'en', 'friendlyUrl': sku}],
        'productSpecifications': {'manufacturer': 'DEFAULT'},
        'categories': [{'code': 'clothing'}],
        'inventory': {'sku': sku, 'quantity': 20, 'price': {'defaultPrice': True, 'price': price}}
    }).encode()
    req = urllib.request.Request(
        'http://localhost:8080/api/v1/private/product?store=DEFAULT',
        data=payload,
        headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'},
        method='POST'
    )
    try:
        with urllib.request.urlopen(req) as r:
            resp = json.loads(r.read())
            print(f'  ✅ {name} → id={resp.get(\"id\")}')
    except Exception as e:
        print(f'  ⚠️  {name} already exists or error: {e}')
"

log "✅ Seed complete! Visit http://localhost:3000/category/clothing"
