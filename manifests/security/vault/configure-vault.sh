#!/bin/sh
set -e
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root-token-devops-platform"

echo "Configuring KV v2 secret..."
vault kv put secret/database/config username="dbadmin" password="SuperSecureVaultPassword2026!" host="db.production.svc.cluster.local" port="5432"

echo "Creating sample-app-policy..."
cat << 'EOF' > /tmp/sample-app-policy.hcl
path "secret/data/database/config" {
  capabilities = ["read"]
}
EOF
vault policy write sample-app-policy /tmp/sample-app-policy.hcl

echo "Enabling and configuring Kubernetes auth..."
vault auth enable kubernetes || true
vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc.cluster.local:443"

echo "Creating Kubernetes role for sample-app..."
vault write auth/kubernetes/role/sample-app-role \
    bound_service_account_names=sample-app-sa \
    bound_service_account_namespaces=production \
    policies=sample-app-policy \
    ttl=24h

echo "Vault configuration completed successfully!"
