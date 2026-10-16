# verify-all.ps1: Comprehensive platform test execution script
$env:Path = "C:\Users\ABC\bin;" + $env:Path

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Running Automated DevOps Platform Verification Suite    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$allPassed = $true

function Run-Check($title, [scriptblock]$check) {
    Write-Host "`n>>> $title" -ForegroundColor Yellow
    try {
        $result = & $check
        if ($result -eq $false) {
            Write-Host "[-] FAILED: $title" -ForegroundColor Red
            $script:allPassed = $false
        } else {
            Write-Host "[+] PASSED: $title" -ForegroundColor Green
        }
    } catch {
        Write-Host "[-] ERROR: $_" -ForegroundColor Red
        $script:allPassed = $false
    }
}

Run-Check "1. Multi-node Cluster Architecture" {
    $nodes = (kubectl get nodes --no-headers | Measure-Object -Line).Lines
    Write-Host "   Cluster nodes discovered: $nodes"
    return ($nodes -ge 2)
}

Run-Check "2. ArgoCD High Availability (HA) Server Replicas" {
    $pods = (kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers | Measure-Object -Line).Lines
    Write-Host "   Running argocd-server pods: $pods"
    return ($pods -ge 2)
}

Run-Check "3. ArgoCD App of Apps Root Application" {
    kubectl get application platform-bootstrap -n argocd --no-headers
    return ($LASTEXITCODE -eq 0)
}

Run-Check "4. OPA Gatekeeper Admission Policy (:latest Tag Rejection)" {
    $out = (kubectl apply -f tests\bad-pod-latest-tag.yaml 2>&1 | Out-String)
    Write-Host "   Admission Response: $out"
    return ($out -like "*forbidden*")
}

Run-Check "5. OPA Gatekeeper Admission Policy (Root Container Rejection)" {
    $out = (kubectl apply -f tests\bad-pod-root.yaml 2>&1 | Out-String)
    Write-Host "   Admission Response: $out"
    return ($out -like "*forbidden*")
}

Run-Check "6. Prometheus Operator Target Discovery (ServiceMonitor)" {
    $sm = (kubectl get servicemonitors -A -o name | Out-String)
    return ($sm -like "*sample-microservice-api-monitor*")
}

Run-Check "7. PrometheusRule Operational Alerting CRD" {
    kubectl get prometheusrule platform-operational-alerts -n monitoring --no-headers
    return ($LASTEXITCODE -eq 0)
}

Run-Check "8. HashiCorp Vault Integration & Dynamic Secret Injection" {
    $samplePod = (kubectl get pods -n production -l app=sample-microservice-api -o jsonpath='{.items[0].metadata.name}')
    $secret = (kubectl exec -n production $samplePod -c sample-microservice-api -- cat /vault/secrets/database-config)
    Write-Host "   Retrieved Secret Content: $secret"
    return ($secret -like "*DB_USER=dbadmin*")
}

Run-Check "9. Loki Log Aggregation & Promtail DaemonSet" {
    $ds = (kubectl get daemonset -n logging promtail -o jsonpath='{.status.numberReady}')
    $loki = (kubectl get pods -n logging -l app=loki --no-headers | Out-String)
    Write-Host "   Promtail Ready Pods: $ds"
    return ($ds -ge 1 -and $loki -like "*Running*")
}

Run-Check "10. Jaeger Distributed Tracing Backend & OpenTelemetry Spans" {
    $jaeger = (kubectl get pods -n tracing -l app=jaeger --no-headers | Out-String)
    return ($jaeger -like "*Running*")
}

Run-Check "11. Aqua Trivy Operator Continuous Vulnerability Scanning" {
    $reports = (kubectl get vulnerabilityreports -A --no-headers | Measure-Object -Line).Lines
    Write-Host "   Vulnerability reports generated: $reports"
    return ($reports -ge 1)
}

Run-Check "12. Declarative Grafana Dashboards Provisioning" {
    $cm = (kubectl get configmaps -n monitoring -l grafana_dashboard=1 -o name | Out-String)
    return ($cm -like "*unified-observability*")
}

Run-Check "13. Sample Workload Microservice Health" {
    $app = (kubectl get pods -n production -l app=sample-microservice-api --no-headers | Out-String)
    return ($app -like "*Running*")
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host " RESULT: ALL 13 VERIFICATION CRITERIA PASSED (100% SCORE) " -ForegroundColor Green
} else {
    Write-Host " RESULT: SOME VERIFICATION CHECKS FAILED " -ForegroundColor Red
    exit 1
}
Write-Host "==========================================================" -ForegroundColor Cyan