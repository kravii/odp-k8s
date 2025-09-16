# Hetzner Kubernetes Cluster Management Platform

A comprehensive solution for automated Kubernetes cluster setup and management on Hetzner baremetal servers with GUI-based administration.

## Features

- 🚀 **Automated K8s Setup**: HA control plane across 3 nodes with automated installation
- 🔧 **Resource Pooling**: Unified CPU/RAM/Storage management across all servers
- 🖥️ **GUI Management**: Web interface for server addition/removal and resource configuration
- 👥 **User Management**: Account creation with namespace mapping and resource quotas
- 📊 **Monitoring**: Real-time dashboard for baremetal utilization (CPU/RAM/Storage/IO-OPS)
- 🔑 **Default User**: Generic acceldata user with SSH key for all containers/pods
- 🛠️ **Dev Tools**: Integrated Helm, kubectl, k9s, and Telepresence

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Hetzner Baremetal Servers                │
├─────────────────────────────────────────────────────────────┤
│  Hybrid Nodes (N nodes, minimum 3)                         │
│  - Control Plane Components (first 3 nodes)                │
│    * API Server                                            │
│    * etcd                                                  │
│    * Controller Manager                                    │
│    * Scheduler                                             │
│  - Worker Components (all nodes)                           │
│    * kubelet                                               │
│    * kube-proxy                                            │
│    * Application Workloads                                 │
│    * Resource Pooling                                      │
│    * Storage Management                                    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Management Layer                         │
├─────────────────────────────────────────────────────────────┤
│  Rancher UI  │  Monitoring  │  User Management  │  Resource │
│              │  Dashboard   │  System          │  Quotas   │
└─────────────────────────────────────────────────────────────┘
```

## Mac Setup Guide

This guide provides step-by-step instructions for setting up the Hetzner Kubernetes cluster from a Mac machine.

### Prerequisites

#### 1. Install Homebrew (if not already installed)

```bash
# Install Homebrew package manager
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to your PATH (for Apple Silicon Macs)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc

# Verify installation
brew --version
```

#### 2. Install Required Tools

```bash
# Install Terraform
brew install terraform

# Install Ansible
brew install ansible

# Install Python 3 (if not already installed)
brew install python@3.11

# Install Git (if not already installed)
brew install git

# Install kubectl
brew install kubectl

# Install Helm
brew install helm

# Install Docker Desktop (for local development)
brew install --cask docker

# Install SSH client (usually pre-installed on macOS)
# Verify SSH is available
ssh -V
```

#### 3. Install Additional Development Tools

```bash
# Install k9s (Kubernetes terminal UI)
brew install k9s

# Install Telepresence (for local development)
brew install datawire/blackbird/telepresence

# Install jq (JSON processor)
brew install jq

# Install curl (usually pre-installed)
brew install curl
```

#### 4. Verify All Installations

```bash
# Check all tools are installed correctly
terraform --version
ansible --version
python3 --version
git --version
kubectl version --client
helm version
docker --version
k9s version
telepresence version
jq --version
```

### Step 1: Clone and Setup Project

```bash
# Clone the repository
git clone <repository-url>
cd hetzner-k8s-cluster

# Create project directory structure
mkdir -p ~/k8s-projects/hetzner-cluster
cd ~/k8s-projects/hetzner-cluster

# Copy the project files
cp -r /path/to/cloned/repo/* .
```

### Step 2: Configure Hetzner Cloud Access

#### 2.1 Get Hetzner API Token

1. Go to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Create a new project or select existing one
3. Go to "Security" → "API Tokens"
4. Create a new token with read/write permissions
5. Copy the token (you'll need it for configuration)

#### 2.2 Generate SSH Key Pair

```bash
# Generate SSH key pair (if you don't have one)
ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f ~/.ssh/hetzner_k8s_key

# Add SSH key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/hetzner_k8s_key

# Display public key (you'll need this for Terraform configuration)
cat ~/.ssh/hetzner_k8s_key.pub
```

### Step 3: Configure Terraform

#### 3.1 Create Terraform Configuration

```bash
# Navigate to terraform directory
cd terraform/

# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit the configuration file
nano terraform.tfvars
```

#### 3.2 Configure terraform.tfvars

Edit the file with your specific configuration:

```hcl
# Hetzner Cloud Configuration
hcloud_token = "your-hetzner-api-token-here"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhA... your-email@example.com"

# Server Configuration
location = "nbg1"  # Options: nbg1, fsn1, hel1, ash, hil
server_image = "ubuntu-22.04"

# Cluster Configuration
cluster_name = "hetzner-k8s-cluster"
kubernetes_version = "1.28"
node_count = 3  # Minimum 3 for HA, all nodes serve as both control plane and workers

# Server Type (see https://www.hetzner.com/cloud for available types)
node_server_type = "cx31"  # 2 vCPU, 8GB RAM - suitable for both control plane and worker workloads

# Storage Configuration
additional_storage_size = 100  # GB

# Network Configuration
pod_cidr = "10.244.0.0/16"
service_cidr = "10.96.0.0/12"

# Application Passwords
rancher_password = "SecureRancherPassword123!"
grafana_password = "SecureGrafanaPassword123!"

# Default User Configuration
acceldata_ssh_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhA... acceldata@cluster"
```

#### 3.3 Initialize and Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration (this will create your servers)
terraform apply

# Note the output values (IP addresses, etc.)
terraform output
```

### Step 4: Configure Ansible Inventory

#### 4.1 Generate Inventory from Terraform Output

```bash
# Navigate back to project root
cd ..

# Generate inventory automatically from Terraform output
./scripts/generate-inventory.sh
```

#### 4.2 Manual Inventory Configuration (Alternative)

If the automatic generation doesn't work, manually edit the inventory:

```bash
# Edit the inventory file
nano ansible/inventory/hosts.yml
```

Add your server details:

```yaml
all:
  children:
    k8s_nodes:
      hosts:
        k8s-node-1:
          ansible_host: "YOUR_NODE_IP_1"
          node_ip: "YOUR_NODE_PRIVATE_IP_1"
          control_plane: true
          worker: true
        k8s-node-2:
          ansible_host: "YOUR_NODE_IP_2"
          node_ip: "YOUR_NODE_PRIVATE_IP_2"
          control_plane: true
          worker: true
        k8s-node-3:
          ansible_host: "YOUR_NODE_IP_3"
          node_ip: "YOUR_NODE_PRIVATE_IP_3"
          control_plane: true
          worker: true
```

### Step 5: Deploy Kubernetes Cluster

#### 5.1 Configure SSH Access

```bash
# Test SSH access to all servers
ssh -i ~/.ssh/hetzner_k8s_key root@YOUR_NODE_IP_1
ssh -i ~/.ssh/hetzner_k8s_key root@YOUR_NODE_IP_2
ssh -i ~/.ssh/hetzner_k8s_key root@YOUR_NODE_IP_3

# Exit from each server
exit
```

#### 5.2 Run Ansible Playbook

```bash
# Navigate to ansible directory
cd ansible/

# Run the main playbook
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# Monitor the progress (this may take 15-30 minutes)
```

#### 5.3 Verify Cluster Deployment

```bash
# Copy kubeconfig from first node
scp -i ~/.ssh/hetzner_k8s_key root@YOUR_NODE_IP_1:/etc/kubernetes/admin.conf ~/.kube/config

# Verify cluster access
kubectl get nodes
kubectl get pods --all-namespaces
```

### Step 6: Access Management Interfaces

#### 6.1 Get Load Balancer IP

```bash
# Get the load balancer IP from Terraform output
cd terraform/
terraform output load_balancer_ip
```

#### 6.2 Access Web Interfaces

```bash
# Rancher UI
open https://LOAD_BALANCER_IP/rancher
# Username: admin
# Password: SecureRancherPassword123! (from terraform.tfvars)

# Grafana Dashboard
open https://LOAD_BALANCER_IP/grafana
# Username: admin
# Password: SecureGrafanaPassword123! (from terraform.tfvars)

# Custom GUI Management Interface
open https://LOAD_BALANCER_IP/gui
```

#### 6.3 Port Forwarding (Alternative Access)

```bash
# Port forward Grafana to local machine
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Access at: http://localhost:3000

# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Access at: http://localhost:9090

# Port forward Rancher
kubectl port-forward -n cattle-system svc/rancher 8080:80
# Access at: http://localhost:8080
```

### Step 7: Install Development Tools

#### 7.1 Run Development Tools Script

```bash
# Navigate to project root
cd ..

# Run the development tools installation script
./scripts/install-dev-tools.sh
```

#### 7.2 Verify Development Tools

```bash
# Check all tools are working
kubectl version --client
helm version
k9s version
telepresence version

# Test cluster connection
kubectl get nodes
kubectl get pods --all-namespaces
```

### Step 8: Create Development Workspace

#### 8.1 Setup Development Environment

```bash
# Navigate to development workspace
cd ~/k8s-dev-workspace

# Test cluster connection
./scripts/connect-cluster.sh

# Start k9s terminal UI
k9s
```

#### 8.2 Test Telepresence

```bash
# Run Telepresence demo
./scripts/telepresence-demo.sh
```

### Step 9: User Management

#### 9.1 Create Users via GUI

1. Access the GUI management interface at `https://LOAD_BALANCER_IP/gui`
2. Navigate to "User Management"
3. Click "Create User"
4. Fill in user details:
   - Username
   - Namespace
   - CPU limit
   - Memory limit

#### 9.2 Create Users via CLI

```bash
# Create namespace
kubectl create namespace user-example

# Create ServiceAccount
kubectl create serviceaccount example-user -n user-example

# Create Role
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-user
  namespace: user-example
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

# Create RoleBinding
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: example-user-binding
  namespace: user-example
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: namespace-user
subjects:
- kind: ServiceAccount
  name: example-user
  namespace: user-example
EOF

# Create ResourceQuota
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: example-user-quota
  namespace: user-example
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    persistentvolumeclaims: "10"
    pods: "20"
EOF
```

### Step 10: Monitoring and Maintenance

#### 10.1 Monitor Cluster Health

```bash
# Check node status
kubectl get nodes -o wide

# Check pod status
kubectl get pods --all-namespaces

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check cluster info
kubectl cluster-info
```

#### 10.2 Backup Configuration

```bash
# Backup cluster configuration
make backup

# Or manually backup
kubectl get all --all-namespaces -o yaml > backup-$(date +%Y%m%d).yaml
```

### Mac-Specific Troubleshooting

#### Common Issues and Solutions

#### 1. Homebrew Installation Issues

```bash
# If Homebrew installation fails
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# For Apple Silicon Macs, add to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

#### 2. SSH Key Issues

```bash
# If SSH key is not recognized
ssh-add -K ~/.ssh/hetzner_k8s_key

# For macOS Monterey and later
ssh-add --apple-use-keychain ~/.ssh/hetzner_k8s_key
```

#### 3. Docker Desktop Issues

```bash
# Start Docker Desktop
open -a Docker

# Verify Docker is running
docker --version
docker ps
```

#### 4. Terraform Permission Issues

```bash
# If Terraform fails with permission errors
chmod +x terraform
sudo chown -R $(whoami) /usr/local/bin/terraform
```

#### 5. Ansible Connection Issues

```bash
# Test Ansible connectivity
ansible all -i inventory/hosts.yml -m ping

# If SSH key issues, specify key explicitly
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --private-key=~/.ssh/hetzner_k8s_key
```

#### 6. kubectl Configuration Issues

```bash
# If kubectl can't connect to cluster
kubectl config get-contexts
kubectl config use-context kubernetes-admin@hetzner-k8s-cluster

# Verify kubeconfig
kubectl config view
```

#### 7. Port Forwarding Issues

```bash
# If port forwarding fails
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 --address 0.0.0.0

# Check if ports are in use
lsof -i :3000
lsof -i :9090
lsof -i :8080
```

### Useful Mac Commands

#### Quick Access Commands

```bash
# Open web interfaces
open https://LOAD_BALANCER_IP/rancher
open https://LOAD_BALANCER_IP/grafana
open https://LOAD_BALANCER_IP/gui

# Quick kubectl aliases (from install-dev-tools.sh)
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
```

#### Makefile Commands

```bash
# Full deployment
make deploy

# Check cluster status
make status

# Install development tools
make dev-tools

# Port forward services
make port-forward-grafana
make port-forward-prometheus
make port-forward-rancher

# Monitor resources
make monitor-nodes
make monitor-pods

# Create users
make create-user USERNAME=john NAMESPACE=john-namespace

# Set resource quotas
make set-quota NAMESPACE=john-namespace

# Backup cluster
make backup

# Clean up
make clean
```

### Next Steps

1. **Customize Monitoring**: Modify Grafana dashboards for your specific needs
2. **Set Up CI/CD**: Configure GitHub Actions or Jenkins for automated deployments
3. **Configure Backup**: Set up regular etcd and application backups
4. **Implement Security**: Enable RBAC, network policies, and pod security standards
5. **Scale Cluster**: Add more nodes as your workload grows
6. **Deploy Applications**: Start deploying your applications to the cluster

### Support and Resources

- **Documentation**: Check `docs/` directory for detailed guides
- **Issues**: Report issues on GitHub Issues
- **Discussions**: Join GitHub Discussions for community support
- **Monitoring**: Use Grafana dashboards to monitor cluster health
- **Logs**: Check application logs using `kubectl logs` or k9s

## Directory Structure

```
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Hetzner server provisioning
│   ├── variables.tf          # Input variables
│   └── outputs.tf            # Output values
├── ansible/                  # Configuration management
│   ├── playbooks/           # K8s cluster setup
│   ├── roles/               # Reusable Ansible roles
│   └── inventory/           # Server inventory
├── kubernetes/              # K8s manifests
│   ├── monitoring/          # Prometheus, Grafana
│   ├── rancher/             # Rancher deployment
│   ├── user-management/     # User accounts & namespaces
│   └── resource-quotas/      # Resource management
├── gui/                     # Web interface
│   ├── frontend/            # React/Vue.js application
│   └── backend/             # API server
├── scripts/                 # Utility scripts
└── docs/                    # Documentation
```

## Components

### Infrastructure Management
- **Terraform**: Hetzner server provisioning and networking
- **Ansible**: OS configuration and Kubernetes installation
- **Rancher**: Cluster management and GUI operations

### Resource Management
- **Resource Pooling**: Unified CPU/RAM/Storage across servers
- **Dynamic Scaling**: Add/remove servers via GUI
- **Quota Management**: Per-namespace resource limits

### User Management
- **Account System**: User creation with namespace mapping
- **SSH Access**: Default acceldata user with generic SSH key
- **RBAC**: Role-based access control

### Monitoring & Observability
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboard
- **Node Exporter**: Baremetal metrics
- **AlertManager**: Alerting system

### Development Tools
- **Helm**: Package management
- **kubectl**: Command-line interface
- **k9s**: Terminal UI
- **Telepresence**: Local development

## Configuration

### Environment Variables
```bash
export HETZNER_API_TOKEN="your-api-token"
export RANCHER_PASSWORD="secure-password"
export GRAFANA_PASSWORD="monitoring-password"
export ACCELDATA_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2E..."
```

### Server Requirements
- **Hybrid Nodes**: Nx servers (minimum 3, recommended 2+ vCPU, 8GB+ RAM, 100GB+ SSD)
- **Control Plane**: First 3 nodes serve as control plane (API Server, etcd, Controller Manager, Scheduler)
- **Worker**: All nodes serve as workers (kubelet, kube-proxy, application workloads)
- **Storage**: Additional disks for persistent storage

## Security

- TLS encryption for all communications
- RBAC for user access control
- Network policies for pod isolation
- Regular security updates via Ansible

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- Documentation: [docs/](docs/)
- Issues: GitHub Issues
- Discussions: GitHub Discussions