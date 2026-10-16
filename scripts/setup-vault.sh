VAULT="http://vault.vault.svc.cluster.local:8200"
TOKEN="root-token-devops-platform"

echo "1. Storing Database Credentials in Vault KVv2..."
curl -s -H "X-Vault-Token: $TOKEN" -X POST "$VAULT/v1/secret/data/database/config" \
  -d '{"data": {"username": "dbadmin", "password": "SuperSecureVaultPassword2026!", "host": "db.production.svc.cluster.local", "port": "5432"}}'
echo ""

echo "2. Writing Access Policy..."
curl -s -H "X-Vault-Token: $TOKEN" -X PUT "$VAULT/v1/sys/policies/acl/sample-app-policy" \
  -d '{"policy": "path \"secret/data/database/config\" { capabilities = [\"read\"] }"}'
echo ""

echo "3. Enabling Kubernetes Auth..."
curl -s -H "X-Vault-Token: $TOKEN" -X POST "$VAULT/v1/sys/auth/kubernetes" \
  -d '{"type": "kubernetes"}' || true
echo ""

echo "4. Configuring Kubernetes Auth..."
curl -s -H "X-Vault-Token: $TOKEN" -X POST "$VAULT/v1/auth/kubernetes/config" \
  -d '{"kubernetes_host": "https://kubernetes.default.svc.cluster.local:443"}'
echo ""

echo "5. Creating Role sample-app-role..."
curl -s -H "X-Vault-Token: $TOKEN" -X POST "$VAULT/v1/auth/kubernetes/role/sample-app-role" \
  -d '{"bound_service_account_names": ["sample-app-sa"], "bound_service_account_namespaces": ["production"], "policies": ["sample-app-policy"], "ttl": "24h"}'
echo ""

echo "6. Verifying Secret Retrieval..."
curl -s -H "X-Vault-Token: $TOKEN" "$VAULT/v1/secret/data/database/config"
echo ""
echo "HashiCorp Vault successfully configured!"