#!/usr/bin/env bash
set -e

echo "[+] Initializing HashiCorp Vault configuration..."

VAULT_ADDR=${VAULT_ADDR:-"http://vault.vault.svc.cluster.local:8200"}
TOKEN=${VAULT_DEV_ROOT_TOKEN_ID:-"root-token-devops-platform"}

# Check connectivity
if ! curl -s -f -o /dev/null "$VAULT_ADDR/v1/sys/health" 2>/dev/null; then
    VAULT_ADDR="http://127.0.0.1:30200"
fi

echo "    Targeting Vault at: $VAULT_ADDR"

# Wait for Vault API to be accessible
echo "    Waiting for Vault API readiness..."
for i in $(seq 1 45); do
    if curl -s -f "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
        echo "    Vault API is accessible."
        break
    fi
    sleep 2
done

# 1. Enable KVv2 engine if not already enabled
AUTH_ENGINES=$(curl -s -H "X-Vault-Token: $TOKEN" "$VAULT_ADDR/v1/sys/mounts" 2>/dev/null || echo "{}")
if ! echo "$AUTH_ENGINES" | grep -q '"secret/"'; then
    echo "    Mounting KVv2 secrets engine at secret/..."
    curl -s -f -H "X-Vault-Token: $TOKEN" -X POST "$VAULT_ADDR/v1/sys/mounts/secret" \
        -d '{"type": "kv", "options": {"version": "2"}}' > /dev/null 2>&1 || true
else
    echo "    KVv2 secrets engine already mounted."
fi

# 2. Store database credentials (silent write, no secrets printed in logs)
echo "    Configuring database secret in Vault..."
curl -s -f -H "X-Vault-Token: $TOKEN" -X POST "$VAULT_ADDR/v1/secret/data/database/config" \
    -H "Content-Type: application/json" \
    -d '{"data": {"username": "dbadmin", "password": "SuperSecureVaultPassword2026!", "host": "db.production.svc.cluster.local", "port": "5432"}}' > /dev/null

# 3. Create/update policy
echo "    Applying sample-app-policy..."
curl -s -f -H "X-Vault-Token: $TOKEN" -X PUT "$VAULT_ADDR/v1/sys/policies/acl/sample-app-policy" \
    -H "Content-Type: application/json" \
    -d '{"policy": "path \"secret/data/database/config\" { capabilities = [\"read\"] }"}' > /dev/null

# 4. Enable Kubernetes Auth if not enabled
AUTH_METHODS=$(curl -s -H "X-Vault-Token: $TOKEN" "$VAULT_ADDR/v1/sys/auth" 2>/dev/null || echo "{}")
if ! echo "$AUTH_METHODS" | grep -q '"kubernetes/"'; then
    echo "    Enabling Kubernetes authentication..."
    curl -s -f -H "X-Vault-Token: $TOKEN" -X POST "$VAULT_ADDR/v1/sys/auth/kubernetes" \
        -H "Content-Type: application/json" \
        -d '{"type": "kubernetes"}' > /dev/null 2>&1 || true
else
    echo "    Kubernetes auth already enabled."
fi

# 5. Configure Kubernetes Auth
echo "    Configuring Kubernetes Auth endpoint..."
curl -s -f -H "X-Vault-Token: $TOKEN" -X POST "$VAULT_ADDR/v1/auth/kubernetes/config" \
    -H "Content-Type: application/json" \
    -d '{"kubernetes_host": "https://kubernetes.default.svc.cluster.local:443"}' > /dev/null

# 6. Configure Role sample-app-role
echo "    Configuring Vault role sample-app-role..."
curl -s -f -H "X-Vault-Token: $TOKEN" -X POST "$VAULT_ADDR/v1/auth/kubernetes/role/sample-app-role" \
    -H "Content-Type: application/json" \
    -d '{"bound_service_account_names": ["sample-app-sa"], "bound_service_account_namespaces": ["production"], "policies": ["sample-app-policy"], "ttl": "24h"}' > /dev/null

# 7. Verify secret retrieval status without printing secrets to logs
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Vault-Token: $TOKEN" "$VAULT_ADDR/v1/secret/data/database/config")
if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "[+] HashiCorp Vault configured and verified successfully (HTTP 200, secrets masked)."
else
    echo "[-] ERROR: Failed to verify Vault secret (HTTP $HTTP_STATUS)"
    exit 1
fi