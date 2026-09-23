#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1

readonly EC2_USER="ec2-user"
readonly KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
readonly KUBERNETES_NAMESPACE="aws-grafana"
readonly MONITORING_NAMESPACE="monitoring"
readonly APP_IMAGE="aws-grafana-demo:latest"
readonly HELM_VERSION="${HELM_VERSION:-v3.16.4}"

GIT_REPO="${1:-SpecialMeDevOps/aws-grafana-kubernetes-ec2-iac}"
RAW_BASE="https://raw.githubusercontent.com/${GIT_REPO}/main"

on_error() {
  local exit_code=$?
  echo "Bootstrap failed at line ${BASH_LINENO[0]} with exit code ${exit_code}." >&2
  echo "Review ${LOG_FILE} for the complete bootstrap log." >&2
  exit "$exit_code"
}
trap on_error ERR

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must run as root through EC2 cloud-init." >&2
  exit 1
fi

if [[ ! -f /etc/system-release ]] || ! grep -Eq "Amazon Linux (2|release 2)" /etc/system-release; then
  echo "Unsupported operating system. This bootstrap requires Amazon Linux 2." >&2
  cat /etc/system-release 2>/dev/null || true
  exit 1
fi

echo "Starting Amazon Linux 2 bootstrap for ${GIT_REPO}."

echo "Installing required Amazon Linux packages."
yum update -y
yum install -y curl ca-certificates git jq tar gzip unzip socat conntrack-tools iptables policycoreutils-python

echo "Installing Docker from the Amazon Linux Extras channel."
if ! command -v amazon-linux-extras >/dev/null 2>&1; then
  echo "amazon-linux-extras is required on Amazon Linux 2 but was not found." >&2
  exit 1
fi
amazon-linux-extras install -y docker
yum install -y docker
systemctl enable --now docker
usermod -aG docker "$EC2_USER"

docker --version
if ! systemctl is-active --quiet docker; then
  echo "Docker is not active after installation." >&2
  systemctl status docker --no-pager >&2
  exit 1
fi
echo "Docker is active."

echo "Installing K3s single-node Kubernetes."
mkdir -p /etc/rancher/k3s
cat >/etc/rancher/k3s/config.yaml <<'EOF'
disable:
  - traefik
write-kubeconfig-mode: "0644"
kube-apiserver-arg:
  - service-node-port-range=3000-32767
EOF
if ! systemctl cat k3s.service >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -
else
  systemctl restart k3s
fi
systemctl enable --now k3s

k3s --version
ln -sfn /usr/local/bin/k3s /usr/local/bin/kubectl
kubectl version --client

mkdir -p /root/.kube "/home/${EC2_USER}/.kube"
install -o root -g root -m 600 "$KUBECONFIG_PATH" /root/.kube/config
install -o "$EC2_USER" -g "$EC2_USER" -m 600 "$KUBECONFIG_PATH" "/home/${EC2_USER}/.kube/config"
cat >/etc/profile.d/kubeconfig.sh <<'EOF'
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
EOF
chmod 644 /etc/profile.d/kubeconfig.sh
export KUBECONFIG="$KUBECONFIG_PATH"

if ! systemctl is-active --quiet k3s; then
  echo "K3s is not active after installation." >&2
  systemctl status k3s --no-pager >&2
  exit 1
fi
kubectl wait --for=condition=Ready node --all --timeout=300s
kubectl get nodes

echo "Installing Helm ${HELM_VERSION}."
machine_arch="$(uname -m)"
case "$machine_arch" in
  x86_64) helm_arch="amd64" ;;
  aarch64|arm64) helm_arch="arm64" ;;
  *)
    echo "Unsupported CPU architecture for Helm: ${machine_arch}" >&2
    exit 1
    ;;
esac
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${helm_arch}.tar.gz" -o /tmp/helm.tar.gz
tar -xzf /tmp/helm.tar.gz -C /tmp
install -m 0755 "/tmp/linux-${helm_arch}/helm" /usr/local/bin/helm
rm -rf /tmp/helm.tar.gz "/tmp/linux-${helm_arch}"
helm version --short

echo "Downloading application and Kubernetes manifests."
mkdir -p /opt/aws-grafana-app /tmp/kubernetes
curl -fsSL "${RAW_BASE}/app/index.html" -o /opt/aws-grafana-app/index.html
curl -fsSL "${RAW_BASE}/app/style.css" -o /opt/aws-grafana-app/style.css
curl -fsSL "${RAW_BASE}/app/nginx.conf" -o /opt/aws-grafana-app/nginx.conf
curl -fsSL "${RAW_BASE}/app/Dockerfile" -o /opt/aws-grafana-app/Dockerfile
curl -fsSL "${RAW_BASE}/kubernetes/namespace.yaml" -o /tmp/kubernetes/namespace.yaml
curl -fsSL "${RAW_BASE}/kubernetes/deployment.yaml" -o /tmp/kubernetes/deployment.yaml
curl -fsSL "${RAW_BASE}/kubernetes/service.yaml" -o /tmp/kubernetes/service.yaml

echo "Building and importing the application image into K3s containerd."
cd /opt/aws-grafana-app
docker build -t "$APP_IMAGE" .
docker --version
docker save "$APP_IMAGE" -o /tmp/aws-grafana-demo.tar
k3s ctr images import /tmp/aws-grafana-demo.tar
rm -f /tmp/aws-grafana-demo.tar

echo "Deploying the application to Kubernetes."
kubectl apply -f /tmp/kubernetes/namespace.yaml
kubectl apply -f /tmp/kubernetes/deployment.yaml
kubectl apply -f /tmp/kubernetes/service.yaml
kubectl -n "$KUBERNETES_NAMESPACE" rollout status deployment/aws-grafana-demo --timeout=300s

echo "Installing Prometheus and Grafana with kube-prometheus-stack."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace "$MONITORING_NAMESPACE" \
  --create-namespace \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=3000 \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait \
  --timeout 15m

kubectl -n "$MONITORING_NAMESPACE" wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=grafana --timeout=600s
kubectl -n "$MONITORING_NAMESPACE" wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=prometheus --timeout=600s

echo "Verifying installed components."
docker --version
systemctl is-active --quiet docker
k3s --version
kubectl version --client
helm version --short
kubectl get nodes
kubectl get pods -A
kubectl get svc -A

get_public_ip() {
  local token
  token="$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")"
  curl -fsS -H "X-aws-ec2-metadata-token: ${token}" \
    http://169.254.169.254/latest/meta-data/public-ipv4
}

public_ip="$(get_public_ip)"
echo "Bootstrap completed successfully."
echo "Application: http://${public_ip}:30080"
echo "Grafana: http://${public_ip}:3000"
