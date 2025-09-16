#!/bin/bash

# Development Tools Installation Script
# Installs Helm, kubectl, k9s, and Telepresence for Kubernetes development

set -e

echo "🚀 Installing Kubernetes Development Tools..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="darwin"
else
    print_error "Unsupported OS: $OSTYPE"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
else
    print_error "Unsupported architecture: $ARCH"
    exit 1
fi

print_status "Detected OS: $OS, Architecture: $ARCH"

# Create tools directory
TOOLS_DIR="$HOME/.k8s-tools"
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"

# Install kubectl
print_status "Installing kubectl..."
KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify kubectl installation
if kubectl version --client >/dev/null 2>&1; then
    print_status "kubectl installed successfully"
else
    print_error "kubectl installation failed"
    exit 1
fi

# Install Helm
print_status "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm installation
if helm version >/dev/null 2>&1; then
    print_status "Helm installed successfully"
else
    print_error "Helm installation failed"
    exit 1
fi

# Install k9s
print_status "Installing k9s..."
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
curl -LO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${OS}_${ARCH}.tar.gz"
tar -xzf "k9s_${OS}_${ARCH}.tar.gz"
sudo mv k9s /usr/local/bin/

# Verify k9s installation
if k9s version >/dev/null 2>&1; then
    print_status "k9s installed successfully"
else
    print_error "k9s installation failed"
    exit 1
fi

# Install Telepresence
print_status "Installing Telepresence..."
if [[ "$OS" == "linux" ]]; then
    curl -s https://packagecloud.io/install/repositories/datawireio/telepresence/script.deb.sh | sudo bash
    sudo apt install -y telepresence
elif [[ "$OS" == "darwin" ]]; then
    if command -v brew >/dev/null 2>&1; then
        brew install datawire/blackbird/telepresence
    else
        print_warning "Homebrew not found. Please install Telepresence manually from https://www.telepresence.io/docs/latest/install/"
    fi
fi

# Verify Telepresence installation
if telepresence version >/dev/null 2>&1; then
    print_status "Telepresence installed successfully"
else
    print_warning "Telepresence installation may have failed. Please verify manually."
fi

# Create k9s configuration
print_status "Creating k9s configuration..."
mkdir -p "$HOME/.config/k9s"
cat > "$HOME/.config/k9s/config.yml" << EOF
k9s:
  refreshRate: 2
  maxConnRetry: 5
  readOnly: false
  noExitOnCtrlC: false
  ui:
    enableMouse: true
    headless: false
    logoless: false
    noIcons: false
    skin: "default"
  skipLatestRevCheck: false
  disablePodCounting: false
  shellPod:
    image: busybox
    namespace: default
    limits:
      cpu: 100m
      memory: 100Mi
  imageScans:
    enable: false
    exclusions:
      namespaces: []
      labels: {}
  logger:
    tail: 100
    buffer: 5000
    sinceSeconds: -1
    fullScreen: false
    textWrap: false
    showTime: false
  thresholds:
    cpu:
      critical: 90
      warn: 70
    memory:
      critical: 90
      warn: 80
EOF

# Create kubectl aliases
print_status "Creating kubectl aliases..."
cat >> "$HOME/.bashrc" << EOF

# Kubernetes aliases
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kdel='kubectl delete'
alias kex='kubectl exec -it'
alias klog='kubectl logs -f'
alias kctx='kubectl config current-context'
alias kns='kubectl config set-context --current --namespace'

# Quick namespace switching
alias kprod='kubectl config set-context --current --namespace=production'
alias kstaging='kubectl config set-context --current --namespace=staging'
alias kdev='kubectl config set-context --current --namespace=development'

# Pod management
alias kpods='kubectl get pods --all-namespaces'
alias ksvc='kubectl get services --all-namespaces'
alias knodes='kubectl get nodes'

# Resource management
alias ktop='kubectl top nodes'
alias ktop-pods='kubectl top pods --all-namespaces'

EOF

# Create Telepresence configuration
print_status "Creating Telepresence configuration..."
mkdir -p "$HOME/.config/telepresence"
cat > "$HOME/.config/telepresence/config.yml" << EOF
telepresence:
  # Global settings
  logLevel: info
  
  # Connection settings
  connect:
    timeout: 30s
    
  # DNS settings
  dns:
    localIp: 127.0.0.1
    
  # Proxy settings
  proxy:
    httpProxy: ""
    httpsProxy: ""
    noProxy: ""
    
  # Intercept settings
  intercept:
    timeout: 30s
    
  # Preview URL settings
  preview:
    enabled: true
    domain: "preview.telepresence.io"
EOF

# Create development workspace
print_status "Creating development workspace..."
DEV_WORKSPACE="$HOME/k8s-dev-workspace"
mkdir -p "$DEV_WORKSPACE"/{manifests,helm-charts,scripts,configs}

# Create sample manifests
cat > "$DEV_WORKSPACE/manifests/sample-app.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        runAsNonRoot: true
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        securityContext:
          runAsUser: 1000
          runAsGroup: 1000
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: var-tmp
          mountPath: /var/tmp
      volumes:
      - name: tmp
        emptyDir: {}
      - name: var-tmp
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app-service
  namespace: default
spec:
  selector:
    app: sample-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# Create sample Helm chart
print_status "Creating sample Helm chart..."
helm create "$DEV_WORKSPACE/helm-charts/sample-chart"

# Create useful scripts
cat > "$DEV_WORKSPACE/scripts/port-forward.sh" << 'EOF'
#!/bin/bash
# Port forwarding script for common services

case "$1" in
    "grafana")
        kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
        ;;
    "prometheus")
        kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
        ;;
    "rancher")
        kubectl port-forward -n cattle-system svc/rancher 8080:80
        ;;
    "sample-app")
        kubectl port-forward svc/sample-app-service 8080:80
        ;;
    *)
        echo "Usage: $0 {grafana|prometheus|rancher|sample-app}"
        echo "Available services:"
        echo "  grafana     - Grafana dashboard (port 3000)"
        echo "  prometheus  - Prometheus UI (port 9090)"
        echo "  rancher     - Rancher UI (port 8080)"
        echo "  sample-app  - Sample application (port 8080)"
        ;;
esac
EOF

chmod +x "$DEV_WORKSPACE/scripts/port-forward.sh"

# Create cluster connection script
cat > "$DEV_WORKSPACE/scripts/connect-cluster.sh" << 'EOF'
#!/bin/bash
# Connect to the Hetzner Kubernetes cluster

echo "🔗 Connecting to Hetzner Kubernetes cluster..."

# Check if kubeconfig exists
if [ ! -f "$HOME/.kube/config" ]; then
    echo "❌ kubeconfig not found. Please run the Ansible playbook first."
    exit 1
fi

# Set cluster context
kubectl config use-context kubernetes-admin@hetzner-k8s-cluster

# Verify connection
if kubectl cluster-info >/dev/null 2>&1; then
    echo "✅ Successfully connected to cluster"
    echo "📊 Cluster info:"
    kubectl cluster-info
    echo ""
    echo "🖥️  Nodes:"
    kubectl get nodes
    echo ""
    echo "📦 Pods:"
    kubectl get pods --all-namespaces
else
    echo "❌ Failed to connect to cluster"
    exit 1
fi
EOF

chmod +x "$DEV_WORKSPACE/scripts/connect-cluster.sh"

# Create Telepresence demo script
cat > "$DEV_WORKSPACE/scripts/telepresence-demo.sh" << 'EOF'
#!/bin/bash
# Telepresence demo script

echo "🚀 Telepresence Demo"
echo "==================="

# Check if Telepresence is installed
if ! command -v telepresence >/dev/null 2>&1; then
    echo "❌ Telepresence not installed. Please install it first."
    exit 1
fi

echo "1. Connecting to cluster..."
telepresence connect

echo "2. Listing services in cluster..."
telepresence list

echo "3. Intercepting sample-app service..."
telepresence intercept sample-app --port 8080:80

echo "4. Your local service is now accessible at:"
echo "   http://sample-app.default:8080"
echo ""
echo "5. To stop the intercept, run:"
echo "   telepresence leave sample-app"
echo ""
echo "6. To disconnect from cluster, run:"
echo "   telepresence quit"
EOF

chmod +x "$DEV_WORKSPACE/scripts/telepresence-demo.sh"

# Create README for development workspace
cat > "$DEV_WORKSPACE/README.md" << EOF
# Kubernetes Development Workspace

This workspace contains tools and configurations for developing with the Hetzner Kubernetes cluster.

## Tools Installed

- **kubectl**: Kubernetes command-line tool
- **Helm**: Package manager for Kubernetes
- **k9s**: Terminal-based UI for Kubernetes
- **Telepresence**: Local development with Kubernetes

## Quick Start

1. **Connect to cluster**:
   \`\`\`bash
   ./scripts/connect-cluster.sh
   \`\`\`

2. **Start k9s**:
   \`\`\`bash
   k9s
   \`\`\`

3. **Port forward services**:
   \`\`\`bash
   ./scripts/port-forward.sh grafana    # Grafana dashboard
   ./scripts/port-forward.sh prometheus # Prometheus UI
   ./scripts/port-forward.sh rancher     # Rancher UI
   \`\`\`

4. **Use Telepresence**:
   \`\`\`bash
   ./scripts/telepresence-demo.sh
   \`\`\`

## Useful Commands

- \`k\` - kubectl shortcut
- \`kg pods\` - get pods
- \`kctx\` - current context
- \`kns <namespace>\` - switch namespace
- \`ktop\` - top nodes
- \`ktop-pods\` - top pods

## Development Workflow

1. Create manifests in \`manifests/\`
2. Use Helm charts in \`helm-charts/\`
3. Test with Telepresence for local development
4. Deploy with kubectl or Helm

## Resources

- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Helm Documentation](https://helm.sh/docs/)
- [k9s Documentation](https://k9scli.io/)
- [Telepresence Documentation](https://www.telepresence.io/docs/)
EOF

print_status "Development tools installation completed!"
print_status "Workspace created at: $DEV_WORKSPACE"
print_status ""
print_status "Next steps:"
print_status "1. Source your bashrc: source ~/.bashrc"
print_status "2. Connect to cluster: $DEV_WORKSPACE/scripts/connect-cluster.sh"
print_status "3. Start k9s: k9s"
print_status "4. Try Telepresence: $DEV_WORKSPACE/scripts/telepresence-demo.sh"
print_status ""
print_status "Happy coding! 🚀"