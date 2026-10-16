# Kubernetes-Based DevOps Platform with ArgoCD HA, Prometheus, Loki, Jaeger, Vault, and OPA Gatekeeper

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31-blue.svg?logo=kubernetes)](https://kubernetes.io/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v2.x-2496ED.svg?logo=docker)](https://docs.docker.com/compose/)
[![ArgoCD HA](https://img.shields.io/badge/ArgoCD-HA%20v2.12-orange.svg?logo=argo)](https://argoproj.github.io/cd/)
[![Prometheus](https://img.shields.io/badge/Prometheus-v2.54-red.svg?logo=prometheus)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-v11.2-F46800.svg?logo=grafana)](https://grafana.com/)
[![Loki](https://img.shields.io/badge/Loki-v3.1-orange.svg?logo=grafana)](https://grafana.com/oss/loki/)
[![Jaeger](https://img.shields.io/badge/Jaeger-v1.60-blue.svg?logo=jaeger)](https://www.jaegertracing.io/)
[![HashiCorp Vault](https://img.shields.io/badge/Vault-v2.0-yellow.svg?logo=vault)](https://www.vaultproject.io/)
[![OPA Gatekeeper](https://img.shields.io/badge/Gatekeeper-v3.17-blueviolet.svg?logo=open-policy-agent)](https://open-policy-agent.github.io/gatekeeper/)
[![Aqua Trivy](https://img.shields.io/badge/Trivy-Operator-teal.svg?logo=aquasec)](https://aquasecurity.github.io/trivy-operator/)

A production-grade, containerized Kubernetes Internal Developer Platform (IDP) enabling declarative continuous delivery via ArgoCD High Availability (HA), end-to-end full-stack observability (metrics, logs, traces), dynamic runtime secrets management via HashiCorp Vault, and policy guardrails via OPA Gatekeeper.

Designed for instant, single-command bootstrapping on **Windows 11 (via Docker Desktop with WSL2)** while maintaining full production parity with AWS EKS infrastructure-as-code modules.

---

## 1. Quickstart (Single-Command Dockerized Workflow)

The platform is fully containerized. A dedicated orchestrator container communicates directly with the Docker engine via the shared Docker socket, handling cluster lifecycle, image builds, ArgoCD HA deployment, and declarative GitOps reconciliation.

### 1.1 Start Platform
Run from the repository root:
```bash
docker compose up --build -d
```
> **What happens under the hood:**
> 1. Verifies Docker daemon connectivity via `/var/run/docker.sock`.
> 2. Provisions multi-node Kubernetes cluster (`devops-platform`) with host port bindings.
> 3. Builds and loads `sample-microservice-api:v1.0.0` and `local-git-server:v1.0.0` into the cluster nodes.
> 4. Deploys ArgoCD in High Availability mode (minimum 2 replicas each for `argocd-server` and `argocd-repo-server`) and starts the in-cluster Git server.
> 5. Commits and syncs the platform configuration to the internal Git server.
> 6. Registers the root ArgoCD **App of Apps** (`platform-bootstrap`), which automatically discovers, deploys, and declaratively manages all platform components in staged sync waves.
> 7. Performs idempotent Vault secrets and Kubernetes auth initialization once the Vault pod reaches Ready.
> 8. Transitions the orchestrator container to an idle daemon state (`devops-platform-runner`).

To stream bootstrap logs in real-time:
```bash
docker compose logs -f platform-runner
```

---

### 1.2 Run Automated Verification Suite
Run the automated test scorecard inside a clean, dedicated test container:
```bash
docker compose run --rm test
```
*Expected Result:* Returns exit code `0` with all 13 core requirements validated.

---

### 1.3 Lifecycle Management: Shutdown vs Cleanup

| Action | Command | Impact |
| :--- | :--- | :--- |
| **Non-Destructive Stop** | `docker compose down` | Stops runner containers. The underlying Kind cluster, deployed applications, and state are preserved. |
| **Resume Platform** | `docker compose up -d` | Instantly reconnects to existing cluster without re-creating nodes. |
| **Destructive Reset** | `docker compose run --rm cleanup` | Completely deletes the Kind cluster, removes volumes, and cleans up all platform containers. |

---

## 2. Host Prerequisites & Docker Desktop Setup

### Host Requirements
- **Operating System**: Windows 11 (build 22000+) 64-bit with WSL2 enabled *(also verified on Ubuntu 22.04+ and macOS Sonoma with Docker Desktop)*.
- **Hardware Resources**: Minimum 16 GB Physical RAM, 4 CPU cores (recommended: 6 CPU cores, 16+ GB RAM).
- **Engine**: Docker Desktop v4.28+ with Linux Container Mode.

### Docker Desktop Settings (Windows 11)
To ensure smooth execution of multi-node Kubernetes nodes and observability stacks:
1. Open Docker Desktop -> **Settings** -> **General** -> Enable **Use the WSL 2 based engine**.
2. Go to **Resources** -> **WSL Integration** -> Enable integration with your default WSL2 distribution.
3. Configure `~/.wslconfig` (or Docker Desktop Advanced Resource Limits) to allocate:
   ```ini
   [wsl2]
   memory=8GB
   processors=4
   swap=4GB
   ```
4. Ensure Docker Desktop is running before launching `docker compose up --build -d`.

### Security Note on Docker Socket Access
The runner service requires `/var/run/docker.sock` to manage the Kind cluster lifecycle (`kind create cluster`, `docker network connect`, `kind load docker-image`). This mount gives the runner container administrative control over the Docker daemon. This design is standard for local CI/CD runners and Kind management tools, but in shared multi-tenant environments, appropriate role-based access control and container isolation should be enforced.

---

## 3. Verified Endpoints & Host Port Mappings

All endpoints are mapped to localhost on the host machine via Kind `extraPortMappings` and Kubernetes `NodePort` services. Each endpoint has been verified accessible from Windows 11:

| Component | Host URL | Port Type | Credentials / Authentication | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Sample Microservice API** | [http://localhost:30000](http://localhost:30000) | NodePort `30000` | Public HTTP | Express API, Vault secret reader, `/metrics` |
| **Vault Secret Endpoint** | [http://localhost:30000/secret](http://localhost:30000/secret) | NodePort `30000` | In-Memory Vault Agent | Proves runtime secret injection into workload |
| **ArgoCD Server UI & API** | [https://localhost:30443](https://localhost:30443) | NodePort `30443` | User: `admin`<br>Pass: *(ArgoCD secret)* | Declarative GitOps continuous delivery |
| **Grafana Dashboards** | [http://localhost:31000](http://localhost:31000) | NodePort `31000` | User: `admin`<br>Pass: `admin` | Unified Observability (Metrics, Logs, Traces) |
| **Prometheus Server** | [http://localhost:30900](http://localhost:30900) | NodePort `30900` | Public HTTP | PromQL query engine, target scrape discovery |
| **Jaeger Tracing UI** | [http://localhost:31686](http://localhost:31686) | NodePort `31686` | Public HTTP | OpenTelemetry span exploration & latency analysis |
| **HashiCorp Vault API** | [http://localhost:30200](http://localhost:30200) | NodePort `30200` | Token: `root-token-devops-platform` | Secrets engine, K8s auth, dynamic credentials |
| **In-Cluster GitOps Server** | `git://localhost:30080/repo.git` | NodePort `30080` | Anonymous Git daemon | Self-contained GitOps repository target |

---

## 4. Architecture & System Design

```mermaid
flowchart TD
    subgraph Host["Host Machine (Windows 11)"]
        Browser["Host Browser / Tools"]
        Compose["docker compose up --build -d"]
    end

    subgraph Docker["Docker Engine (WSL2 Backend)"]
        Runner["devops-platform-runner<br/>(Orchestrator Container)"]
        Compose --> Runner
        Runner -->|Manages via /var/run/docker.sock| KindCluster["Kind Multi-Node Cluster"]
        
        subgraph KindCluster["Kind Cluster: devops-platform"]
            CP["devops-platform-control-plane"]
            Worker["devops-platform-worker"]
            
            subgraph GitOps["GitOps Subsystem"]
                GitServer["git-server:9418<br/>(In-Cluster Bare Git Repo)"]
                ArgoCD["ArgoCD HA Controller<br/>(2x Server, 2x Repo-Server, Redis-HA)"]
                AppOfApps["platform-bootstrap<br/>(Root Application)"]
            end
            
            subgraph Security["Security & Policy Guardrails"]
                Gatekeeper["OPA Gatekeeper<br/>(Webhook + Constraints)"]
                Vault["HashiCorp Vault<br/>(KVv2 + K8s Auth)"]
                Trivy["Aqua Trivy Operator<br/>(CVE Image Scans)"]
            end
            
            subgraph Observability["Full-Stack Observability"]
                Prom["Prometheus Operator<br/>(ServiceMonitors + Alerts)"]
                Loki["Loki Log Aggregator"]
                Promtail["Promtail DaemonSet<br/>(Tails Node Logs)"]
                Jaeger["Jaeger Distributed Tracing"]
                Grafana["Grafana Unified Dashboards"]
            end
            
            subgraph Workloads["Application Tier (Namespace: production)"]
                SampleApp["sample-microservice-api<br/>(Non-root UID 10001, OTel Traces, Prom Metrics)"]
                VaultAgent["Vault Agent Sidecar<br/>(/vault/secrets/database-config)"]
            end
        end
    end

    Browser -->|Port 30000| SampleApp
    Browser -->|Port 30443| ArgoCD
    Browser -->|Port 31000| Grafana
    Browser -->|Port 31686| Jaeger
    Browser -->|Port 30200| Vault
    Browser -->|Port 30900| Prom

    Runner -->|Git Push| GitServer
    AppOfApps -->|Reads Manifests| GitServer
    AppOfApps -->|Deploys via Waves| Security
    AppOfApps -->|Deploys via Waves| Observability
    AppOfApps -->|Deploys via Waves| Workloads
    VaultAgent -->|Fetches Secrets| Vault
    Prom -->|Scrapes /metrics| SampleApp
    SampleApp -->|Exports Spans| Jaeger
    Promtail -->|Ships Logs| Loki
```

### GitOps App of Apps Hierarchy & Sync Waves
To avoid race conditions and ensure zero duplicate resource ownership, only ArgoCD HA and the in-cluster Git server are bootstrapped directly. ArgoCD App of Apps owns every subsequent platform component using declarative sync waves:

```
platform-bootstrap (Root Application)
 │
 ├── Wave 0: gatekeeper-system       --> OPA Gatekeeper CRDs, Controller, and Webhook
 │
 ├── Wave 1: gatekeeper-templates    --> ConstraintTemplates (k8sblocklatesttag, k8srequirenonroot)
 ├── Wave 1: hashicorp-vault         --> Vault Server (dev KVv2) & Agent Injector Webhook
 ├── Wave 1: prometheus-stack        --> Kube-Prometheus-Stack, Alertmanager, Grafana
 ├── Wave 1: loki-stack              --> Loki StatefulSet & Promtail DaemonSet
 ├── Wave 1: jaeger-tracing          --> Jaeger All-In-One Tracing Collector & Query UI
 │
 ├── Wave 2: gatekeeper-constraints  --> K8sBlockLatestTag & K8sRequireNonRoot Constraints
 ├── Wave 2: observability-dashboards--> Grafana Unified Observability & Alert ConfigMaps
 ├── Wave 2: trivy-operator          --> Aqua Trivy Security Scanner Operator
 │
 └── Wave 3: sample-app              --> Node.js Microservice with Vault Agent Sidecar
```

---

## 5. Security Guardrails & Policy Enforcement

### 5.1 OPA Gatekeeper Admission Policies
Two strict admission constraint policies are actively enforced at the API admission boundary:
1. **Block `:latest` Image Tags (`k8sblocklatesttag`)**: Rejects any container or initContainer with an image tag ending in `:latest`. Workloads must use explicit semantic versions or immutable SHAs.
   - *Test Evidence:* Attempting to apply `tests/bad-pod-latest-tag.yaml` immediately fails with:
     `Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request: [block-latest-tag-constraint] Container 'nginx' uses the 'latest' tag, which is forbidden.`
2. **Require Non-Root Execution (`k8srequirenonroot`)**: Rejects any container configured with `runAsUser: 0` or omitting non-root security contexts.
   - *Test Evidence:* Attempting to apply `tests/bad-pod-root.yaml` immediately fails with:
     `Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request: [require-non-root-constraint] Container 'nginx' specifies runAsUser: 0 (root), which is forbidden.`

### 5.2 Dynamic Secrets with HashiCorp Vault
- **Zero Static Secrets**: No database passwords or API keys are stored in Git or Kubernetes Secret objects.
- **Runtime Agent Injection**: The sample application deployment utilizes HashiCorp Vault Agent Injector annotations (`vault.hashicorp.com/agent-inject: "true"`).
- **ServiceAccount Authentication**: The pod authenticates using the Kubernetes ServiceAccount token (`sample-app-sa`) mapped to the `sample-app-role` policy in Vault.
- **In-Memory Mount**: Secrets are injected into an ephemeral `tmpfs` volume at `/vault/secrets/database-config`:
  ```ini
  DB_USER=dbadmin
  DB_PASSWORD=SuperSecureVaultPassword2026!
  DB_HOST=db.production.svc.cluster.local
  DB_PORT=5432
  ```
- **Secret Masking & Idempotency**: The Vault setup script (`scripts/setup-vault.sh`) is 100% idempotent and verifies secret creation via HTTP status codes without ever writing plain-text passwords into container stdout or logs.

---

## 6. Observability & Telemetry

### 6.1 Metrics (Prometheus Operator)
- Custom `ServiceMonitor` (`sample-microservice-api-monitor`) scrapes Express HTTP metrics on port `3000` via endpoint `/metrics` every 10 seconds.
- Custom `PrometheusRule` (`platform-operational-alerts`) defines operational alerts:
  - `HighCPUUsage`: Warns when node CPU utilization exceeds 85% for 5 minutes.
  - `DeploymentReplicasMismatch`: Critical alert triggered when available replicas do not match spec replicas.

### 6.2 Logs (Grafana Loki & Promtail)
- `promtail` DaemonSet runs on all cluster nodes, tailing container log streams from `/var/log/pods`.
- Winston JSON structured logs from `sample-microservice-api` are parsed and indexed by pod labels, trace IDs, and HTTP route metadata.

### 6.3 Distributed Tracing (OpenTelemetry & Jaeger)
- `sample-app/tracing.js` instruments the Express application via `@opentelemetry/sdk-node`.
- Spans are exported via OTLP HTTP (`http://jaeger-collector.tracing.svc.cluster.local:4318/v1/traces`).
- Custom spans (`process-business-data`) trace business logic execution and propagate trace context to HTTP responses and log entries.

### 6.4 Single Pane of Glass (Grafana)
- Provisioned via declarative ConfigMaps with label `grafana_dashboard: "1"`.
- Features the **Unified Observability Dashboard**: connects PromQL request rate panels, Loki log streams, and Jaeger distributed trace links in a synchronized layout.

---

## 7. Cloud Parity Matrix: AWS EKS vs Local Kind

| Dimension | Production Cloud Architecture (`iac/cloud/`) | Local Workstation Environment (`iac/local/` & Kind) | Parity Status |
| :--- | :--- | :--- | :--- |
| **Kubernetes Runtime** | Managed AWS EKS v1.31 Control Plane | Kind v1.31 (Docker-in-Docker Engine) | **Equivalent API** |
| **Network Architecture** | AWS VPC, 3 Public / 3 Private Subnets, NAT Gateways | Docker Bridge Network (`kind`), isolated container CIDR | **Local Equivalent** |
| **Worker Topology** | EKS Managed Node Groups with Cluster Autoscaler (2-6 nodes) | Multi-Node Kind Cluster (1 control-plane, 1 dedicated worker) | **Simulated Multi-Node** |
| **Workload Distribution** | Distributed across multi-AZ worker nodes | Multi-node Kind cluster with control-plane taint removed | **Full Distribution** |
| **Continuous Delivery** | ArgoCD HA with AWS Secrets Manager integration | ArgoCD HA (2 server replicas, 2 repo-server replicas, redis-ha) | **Identical Controller** |
| **Git Source** | Enterprise GitHub / GitLab webhook-driven pull | In-cluster bare Git daemon (`local-git-server:9418`) | **Local Equivalent (Self-Contained)** |
| **Policy Enforcement** | OPA Gatekeeper admission webhooks | OPA Gatekeeper v3.17 with identical Rego constraint rules | **100% Identical** |
| **Secrets Engine** | HashiCorp Vault Cluster on AWS EC2/EKS | HashiCorp Vault v2.0 with Agent Injector & K8s Auth Method | **100% Identical** |
| **Vulnerability Scanning** | Aqua Trivy Operator continuous CVE scanning | Aqua Trivy Operator scanning local image archives | **100% Identical** |
| **Workload Microservice** | Multi-stage Docker image, non-root user UID 10001 | Same image loaded into Kind nodes via `kind load docker-image` | **100% Identical** |

---

## 8. Verification Scorecard & Test Results

The platform incorporates two comprehensive test runners:
1. **Dockerized Runner**: `docker compose run --rm test` (executed inside isolated test container).
2. **Host PowerShell Runner**: `powershell -ExecutionPolicy Bypass -File tests\verify-all.ps1` (executed directly from Windows host).

### Automated Scorecard (13 of 13 Checks Passed - 100%)

| # | Check / Requirement | Target Resource / Verification Method | Execution Status |
| :---: | :--- | :--- | :---: |
| **1** | Multi-Node Cluster Architecture | `kubectl get nodes` (Discovered `>= 2` nodes) | **PASSED** |
| **2** | ArgoCD HA Server & Repo-Server | `argocd-server >= 2` pods, `argocd-repo-server >= 2` pods | **PASSED** |
| **3** | ArgoCD App of Apps Root | `kubectl get application platform-bootstrap -n argocd` | **PASSED** |
| **4** | OPA Gatekeeper `:latest` Rejection | `kubectl apply -f tests/bad-pod-latest-tag.yaml` (Denied: HTTP 403 Forbidden) | **PASSED** |
| **5** | OPA Gatekeeper Root User Rejection | `kubectl apply -f tests/bad-pod-root.yaml` (Denied: HTTP 403 Forbidden) | **PASSED** |
| **6** | ServiceMonitor Discovery | `kubectl get servicemonitors` (`sample-microservice-api-monitor`) | **PASSED** |
| **7** | PrometheusRule Operational Alerts | `kubectl get prometheusrules -n monitoring platform-operational-alerts` | **PASSED** |
| **8** | Vault Dynamic Secret Injection | `cat /vault/secrets/database-config` in sample-app pod (`DB_USER=dbadmin`) | **PASSED** |
| **9** | Loki & Promtail DaemonSet | `kubectl get daemonset -n logging promtail` (2/2 ready) & Loki Running | **PASSED** |
| **10** | Jaeger Distributed Tracing | `kubectl get pods -n tracing -l app=jaeger` (Running) | **PASSED** |
| **11** | Trivy Operator CVE Scanning | `kubectl get vulnerabilityreports -A` (`16+` reports generated) | **PASSED** |
| **12** | Declarative Grafana Dashboards | `kubectl get configmaps -n monitoring -l grafana_dashboard=1` | **PASSED** |
| **13** | Sample Microservice Workload | `kubectl get pods -n production -l app=sample-microservice-api` (2/2 Running) | **PASSED** |

---

## Video Demo

https://youtu.be/PUcVOAEdmus

---

## 9. Troubleshooting & FAQ

### Port `30000` / `30443` / `31000` Already In Use
If another process on Windows is listening on one of the mapped ports:
```powershell
Get-NetTCPConnection -LocalPort 30000, 30443, 31000, 31686, 30200, 30900 | Select-Object LocalPort, OwningProcess
```
Terminate the conflicting process or modify the port mapping in `iac/local/kind-config.yaml`.

### Cluster Reset
If you need to perform a clean-slate rebuild:
```bash
docker compose run --rm cleanup
docker compose up --build -d
```

---


## 10. License
This project is open-source and licensed under the **Apache 2.0 License**.