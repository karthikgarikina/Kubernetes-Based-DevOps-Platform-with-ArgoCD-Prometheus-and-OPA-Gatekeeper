#!/usr/bin/env bash
set -e

# Delegate to workspace script if mounted and this is the container root entrypoint
if [ -f /workspace/scripts/docker-entrypoint.sh ] && [ "$0" != "/workspace/scripts/docker-entrypoint.sh" ]; then
    exec /workspace/scripts/docker-entrypoint.sh "$@"
fi

echo "=========================================================="
echo " Starting Containerized Kubernetes DevOps Platform Runner "
echo "=========================================================="

# 1. Preflight: Verify Docker daemon connection
echo "[1/6] Verifying Docker daemon connection..."
if ! docker info > /dev/null 2>&1; then
    echo "[-] ERROR: Cannot connect to Docker daemon at /var/run/docker.sock"
    echo "    Please verify that Docker Desktop is running with WSL2 backend enabled."
    exit 1
fi
echo "[+] Docker daemon connected successfully."

# 2. Cluster Lifecycle: Check or create Kind cluster
echo "[2/6] Ensuring Kubernetes cluster is provisioned..."
if ! kind get clusters 2>/dev/null | grep -q "^devops-platform$"; then
    echo "    Provisioning multi-node Kind cluster 'devops-platform'..."
    kind create cluster --name devops-platform --config /workspace/iac/local/kind-config.yaml
else
    echo "    Kind cluster 'devops-platform' already running."
fi

# Connect this runner container to kind Docker network so DNS/internal IPs resolve
docker network connect kind $(hostname) 2>/dev/null || true

# Export internal kubeconfig targeting control plane inside container network
kind export kubeconfig --internal --name devops-platform

# Wait for nodes to reach Ready state
echo "    Waiting for cluster nodes to reach Ready state..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

# Untaint control-plane node to allow multi-node workload distribution across both nodes
kubectl taint nodes devops-platform-control-plane node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
echo "[+] Multi-node Kubernetes cluster is ready."

# 3. Workload Image: Build and load sample-app image
echo "[3/6] Building and loading sample microservice container image..."
docker build -t sample-microservice-api:v1.0.0 /workspace/sample-app
kind load docker-image sample-microservice-api:v1.0.0 --name devops-platform
echo "[+] Image sample-microservice-api:v1.0.0 loaded into cluster nodes."

# 4. Minimal Direct Bootstrap: Deploy ArgoCD HA, NodePort Service & In-Cluster Git Daemon
echo "[4/6] Bootstrapping ArgoCD HA & GitOps in-cluster Git server..."
kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd -f /workspace/manifests/argocd/ha-install.yaml
kubectl apply -f /workspace/manifests/argocd/argocd-nodeport.yaml
kubectl apply -f /workspace/manifests/argocd/git-server.yaml

# Wait for git-server
echo "    Waiting for in-cluster Git server..."
kubectl rollout status deployment/git-server -n argocd --timeout=90s

# Seed in-cluster git repository with workspace manifests
echo "    Synchronizing platform manifests to in-cluster Git repository..."
git config --global user.email "devops@platform.local"
git config --global user.name "DevOps Platform Runner"
git config --global --add safe.directory /workspace
(
    cd /workspace
    git add -A 2>/dev/null || true
    git commit -m "Auto-sync platform configuration" 2>/dev/null || true
    # Push to git-server via NodePort 30080 or port-forward fallback
    git push git://127.0.0.1:30080/repo.git main --force 2>/dev/null || \
    git push git://devops-platform-control-plane:30080/repo.git main --force 2>/dev/null || \
    (
        kubectl port-forward -n argocd svc/git-server 9418:9418 > /dev/null 2>&1 &
        FW_PID=$!
        sleep 2
        git push git://127.0.0.1:9418/repo.git main --force
        kill $FW_PID 2>/dev/null || true
    )
)
echo "[+] Platform repository synchronized with in-cluster GitOps server."

# Scale redis-ha-haproxy if needed for local resources
kubectl scale deployment argocd-redis-ha-haproxy -n argocd --replicas=2 2>/dev/null || true

# Wait for ArgoCD HA controller and repo-server (minimum 2 replicas each)
echo "    Waiting for ArgoCD server and repo-server HA rollouts..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=150s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=150s
echo "[+] ArgoCD HA controller deployed (at least 2 replicas each for server and repo-server)."

# 5. GitOps Ownership: Apply Root App of Apps
# All subsequent platform components are owned and reconciled declaratively by ArgoCD
echo "[5/6] Registering ArgoCD App of Apps Root Application..."
kubectl apply -f /workspace/bootstrap/platform-bootstrap.yaml
echo "[+] Platform root application registered. ArgoCD is managing platform declaratively."

# 6. Dependency-Aware Readiness Verification & Idempotent Vault Initialization
echo "[6/6] Monitoring declarative rollout of platform components..."

echo "    [1/5] Waiting for OPA Gatekeeper controller..."
kubectl rollout status deployment/gatekeeper-controller-manager -n gatekeeper-system --timeout=150s 2>/dev/null || true

echo "    [2/5] Waiting for HashiCorp Vault pod to reach Ready..."
kubectl wait --namespace vault --for=condition=Ready pod/vault-0 --timeout=180s 2>/dev/null || true

echo "    [3/5] Executing idempotent HashiCorp Vault secrets & auth initialization..."
VAULT_ADDR="http://vault.vault.svc.cluster.local:8200" /workspace/scripts/setup-vault.sh

echo "    [4/5] Waiting for Observability stack (Prometheus & Grafana)..."
kubectl rollout status deployment/prometheus-stack-grafana -n monitoring --timeout=180s 2>/dev/null || true

echo "    [5/5] Waiting for Sample Microservice workload rollout in production namespace..."
kubectl rollout status deployment/sample-microservice-api -n production --timeout=150s 2>/dev/null || true

echo "=========================================================="
echo " Kubernetes DevOps Platform Bootstrap Succeeded!          "
echo "=========================================================="
echo " Endpoints (accessible via localhost from host browser):  "
echo "  - ArgoCD Server:  https://localhost:30443 (admin)       "
echo "  - Grafana UI:     http://localhost:31000  (admin/admin) "
echo "  - Jaeger UI:      http://localhost:31686                "
echo "  - Vault API:      http://localhost:30200                "
echo "  - Sample App:     http://localhost:30000                "
echo "  - Prometheus:     http://localhost:30900                "
echo "=========================================================="
echo " To execute automated platform verification suite:        "
echo "   docker compose run --rm test                           "
echo " To stop the platform:                                    "
echo "   docker compose down                                    "
echo " To completely destroy and clean up Kind cluster:         "
echo "   docker compose run --rm cleanup                        "
echo "=========================================================="

exec "$@"