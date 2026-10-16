#!/usr/bin/env bash
set -e

echo "=========================================================="
echo " Cleaning Up Kubernetes DevOps Platform                   "
echo "=========================================================="

# Delete Kind cluster
if kind get clusters 2>/dev/null | grep -q "devops-platform"; then
    echo "Deleting Kind cluster 'devops-platform'..."
    kind delete cluster --name devops-platform
    echo "Cluster deleted successfully."
else
    echo "No Kind cluster 'devops-platform' found."
fi

# Remove dangling containers if any
echo "Removing any dangling devops-platform containers..."
docker rm -f devops-platform-runner devops-platform-test 2>/dev/null || true

echo "=========================================================="
echo " Cleanup Complete!                                        "
echo "=========================================================="