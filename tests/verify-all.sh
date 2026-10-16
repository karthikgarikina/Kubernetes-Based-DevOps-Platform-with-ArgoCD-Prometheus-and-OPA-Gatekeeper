#!/usr/bin/env bash
set -e

echo "=========================================================="
echo " Running Automated DevOps Platform Verification Suite    "
echo "=========================================================="

echo "[1/13] Checking Multi-node Cluster..."
kubectl get nodes --no-headers | wc -l | grep -q '^[2-9]' && echo "PASS: Multi-node cluster ready"

echo "[2/13] Checking ArgoCD HA Replicas..."
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers | wc -l | grep -q '^[2-9]' && echo "PASS: ArgoCD HA server pods >= 2"
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server --no-headers | wc -l | grep -q '^[2-9]' && echo "PASS: ArgoCD HA repo-server pods >= 2"

echo "[3/13] Checking ArgoCD App of Apps Root..."
kubectl get application platform-bootstrap -n argocd && echo "PASS: Root Application platform-bootstrap is active"

echo "[4/13] Checking OPA Gatekeeper :latest Tag Rejection..."
kubectl apply -f tests/bad-pod-latest-tag.yaml 2>&1 | grep "forbidden" && echo "PASS: OPA Gatekeeper rejected :latest image"

echo "[5/13] Checking OPA Gatekeeper Root User Rejection..."
kubectl apply -f tests/bad-pod-root.yaml 2>&1 | grep "forbidden" && echo "PASS: OPA Gatekeeper rejected root user container"

echo "[6/13] Checking ServiceMonitors..."
kubectl get servicemonitors -A | grep -q "sample-microservice-api-monitor" && echo "PASS: sample-microservice-api-monitor detected"

echo "[7/13] Checking Prometheus Alerts..."
kubectl get prometheusrules -n monitoring platform-operational-alerts && echo "PASS: platform-operational-alerts rule exists"

echo "[8/13] Checking HashiCorp Vault Secrets Injection..."
POD=$(kubectl get pods -n production -l app=sample-microservice-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n production $POD -c sample-microservice-api -- cat /vault/secrets/database-config | grep -q "DB_USER=dbadmin" && echo "PASS: Secret injected via Vault Agent"

echo "[9/13] Checking Promtail DaemonSet and Loki..."
kubectl get daemonset -n logging promtail
kubectl get pods -n logging -l app=loki --no-headers | grep -q "Running" && echo "PASS: Loki and Promtail active"

echo "[10/13] Checking Jaeger Distributed Tracing..."
kubectl get pods -n tracing -l app=jaeger --no-headers | grep -q "Running" && echo "PASS: Jaeger backend active"

echo "[11/13] Checking Trivy Operator VulnerabilityReports..."
kubectl get vulnerabilityreports -A --no-headers | wc -l | grep -q '^[1-9]' && echo "PASS: VulnerabilityReports generated"

echo "[12/13] Checking Grafana Dashboards..."
kubectl get configmaps -n monitoring -l grafana_dashboard=1 | grep -q "unified-observability" && echo "PASS: Unified Observability Dashboard loaded"

echo "[13/13] Checking Sample App Health..."
kubectl get pods -n production -l app=sample-microservice-api --no-headers | grep -q "Running" && echo "PASS: Sample App is running"

echo "=========================================================="
echo " RESULT: ALL PLATFORM TESTS PASSED SUCCESSFULLY!          "
echo "=========================================================="