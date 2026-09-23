#!/usr/bin/env bash
set -euxo pipefail

LOG_FILE="/var/log/bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1

GIT_REPO="${1:-SpecialMeDevOps/aws-grafana-kubernetes-ec2-iac}"
RAW_BASE="https://raw.githubusercontent.com/${GIT_REPO}/main"
export DEBIAN_FRONTEND=noninteractive

if ! command -v curl >/dev/null 2>&1; then
  apt-get update
  apt-get install -y curl ca-certificates gnupg lsb-release software-properties-common
fi

# Install Docker
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git jq

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >/etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker.io
systemctl enable --now docker
usermod -aG docker ubuntu || true

# Install Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install K3s (single-node Kubernetes)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chown root:root /root/.kube/config
chmod 600 /root/.kube/config
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Wait until the single node is ready
kubectl wait --for=condition=Ready node --all --timeout=300s

# Download app source and Kubernetes manifests
mkdir -p /opt/aws-grafana-app /tmp/kubernetes
curl -fsSL "${RAW_BASE}/app/index.html" -o /opt/aws-grafana-app/index.html
curl -fsSL "${RAW_BASE}/app/style.css" -o /opt/aws-grafana-app/style.css
curl -fsSL "${RAW_BASE}/app/nginx.conf" -o /opt/aws-grafana-app/nginx.conf
curl -fsSL "${RAW_BASE}/app/Dockerfile" -o /opt/aws-grafana-app/Dockerfile
curl -fsSL "${RAW_BASE}/kubernetes/namespace.yaml" -o /tmp/kubernetes/namespace.yaml
curl -fsSL "${RAW_BASE}/kubernetes/deployment.yaml" -o /tmp/kubernetes/deployment.yaml
curl -fsSL "${RAW_BASE}/kubernetes/service.yaml" -o /tmp/kubernetes/service.yaml

# Build the app image for the local Kubernetes node
cd /opt/aws-grafana-app
DockerfileVersion=$(docker --version | awk '{print $3}' | cut -d. -f1)
if [ "$DockerfileVersion" = "" ]; then
  echo "Docker version detection failed" >&2
  exit 1
fi

docker build -t aws-grafana-demo:latest .
docker save aws-grafana-demo:latest -o /tmp/aws-grafana-demo.tar
/usr/local/bin/k3s ctr images import /tmp/aws-grafana-demo.tar

# Deploy application to Kubernetes
kubectl apply -f /tmp/kubernetes/namespace.yaml
kubectl apply -f /tmp/kubernetes/deployment.yaml
kubectl apply -f /tmp/kubernetes/service.yaml
kubectl -n aws-grafana rollout status deployment/aws-grafana-demo --timeout=300s

# Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=3000 \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

kubectl -n monitoring wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana --timeout=300s || true

# Final verification output
kubectl get nodes
kubectl get pods -A
kubectl get svc -A

echo "Bootstrap completed successfully."
echo "Grafana: http://$(curl -fsSL http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "Application: http://$(curl -fsSL http://169.254.169.254/latest/meta-data/public-ipv4):30080"
