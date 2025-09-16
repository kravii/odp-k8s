# Step-by-Step Setup Guide

This guide provides detailed instructions for setting up the Hetzner Kubernetes Cluster Management Platform on each node.

## Prerequisites

### Required Tools on Your Local Machine
```bash
# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install Ansible
pip3 install ansible

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install jq (for JSON parsing)
sudo apt update && sudo apt install -y jq
```

### Required Accounts
- Hetzner Cloud account with API token
- SSH key pair for server access

## Step 1: Infrastructure Setup

### 1.1 Configure Terraform Variables

```bash
# Navigate to terraform directory
cd terraform/

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
nano terraform.tfvars
```

**terraform.tfvars Configuration:**
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

### 1.2 Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply -auto-approve

# Get server information
terraform output
```

**Expected Output:**
```
node_ips = [
  "1.2.3.4",    # k8s-node-1
  "1.2.3.5",    # k8s-node-2
  "1.2.3.6",    # k8s-node-3
]
node_private_ips = [
  "10.0.1.10",  # k8s-node-1 private
  "10.0.1.11",  # k8s-node-2 private
  "10.0.1.12",  # k8s-node-3 private
]
load_balancer_ip = "1.2.3.7"
```

## Step 2: Generate Ansible Inventory

```bash
# Navigate to project root
cd ..

# Generate inventory from Terraform output
./scripts/generate-inventory.sh
```

**Generated inventory/hosts.yml:**
```yaml
all:
  children:
    k8s_nodes:
      hosts:
        k8s-node-1:
          ansible_host: "1.2.3.4"
          ansible_user: root
          node_ip: "10.0.1.10"
          node_role: hybrid
          control_plane: true
          worker: true
          node_index: 1
        k8s-node-2:
          ansible_host: "1.2.3.5"
          ansible_user: root
          node_ip: "10.0.1.11"
          node_role: hybrid
          control_plane: true
          worker: true
          node_index: 2
        k8s-node-3:
          ansible_host: "1.2.3.6"
          ansible_user: root
          node_ip: "10.0.1.12"
          node_role: hybrid
          control_plane: true
          worker: true
          node_index: 3
```

## Step 3: Deploy Kubernetes Cluster

### 3.1 Run Ansible Playbook

```bash
# Navigate to ansible directory
cd ansible/

# Run the main playbook
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

**This will execute the following on each node:**

#### On All Nodes (k8s-node-1, k8s-node-2, k8s-node-3):

**Step 1: Common Setup**
```bash
# Update package cache
apt update

# Install essential packages
apt install -y curl wget git vim htop net-tools bridge-utils iptables ipvsadm socat conntrack telnet unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load required kernel modules
modprobe br_netfilter ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack

# Configure sysctl for Kubernetes
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 0
vm.overcommit_memory = 1
vm.panic_on_oom = 0
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 1048576
fs.file-max = 52706963
fs.nr_open = 52706963
net.netfilter.nf_conntrack_max = 2310720
EOF

sysctl --system

# Create acceldata user
useradd -m -s /bin/bash acceldata
usermod -aG docker acceldata

# Add acceldata SSH key
mkdir -p /home/acceldata/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhA... acceldata@cluster" > /home/acceldata/.ssh/authorized_keys
chmod 700 /home/acceldata/.ssh
chmod 600 /home/acceldata/.ssh/authorized_keys
chown -R acceldata:acceldata /home/acceldata/.ssh

# Create Kubernetes directories
mkdir -p /etc/kubernetes /etc/kubernetes/pki /etc/kubernetes/manifests /var/lib/kubelet /var/lib/kube-proxy /var/lib/etcd /var/log/kubernetes

# Set hostname
hostnamectl set-hostname k8s-node-1  # (or k8s-node-2, k8s-node-3)
```

**Step 2: Install Docker and Containerd**
```bash
# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install containerd
apt update
apt install -y containerd.io docker-ce-cli

# Configure containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Start containerd
systemctl enable containerd
systemctl start containerd

# Install CNI plugins
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
tar -xzf cni-plugins-linux-amd64-v1.3.0.tgz -C /opt/cni/bin/
mkdir -p /etc/cni/net.d
```

**Step 3: Install Kubernetes Components**
```bash
# Add Kubernetes GPG key
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg

# Add Kubernetes repository
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes packages
apt update
apt install -y kubelet=1.28.0-00 kubeadm=1.28.0-00 kubectl=1.28.0-00

# Hold packages to prevent auto-updates
apt-mark hold kubelet kubeadm kubectl

# Configure kubelet
cat > /var/lib/kubelet/config.yaml << EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
clusterDomain: cluster.local
clusterDNS:
  - 10.96.0.10
cgroupDriver: systemd
containerRuntime: remote
containerRuntimeEndpoint: unix:///run/containerd/containerd.sock
EOF

# Enable kubelet
systemctl enable kubelet
```

#### On First Node Only (k8s-node-1):

**Step 4: Initialize Control Plane**
```bash
# Initialize Kubernetes cluster
kubeadm init \
  --control-plane-endpoint=1.2.3.7:6443 \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --kubernetes-version=1.28 \
  --cri-socket=unix:///run/containerd/containerd.sock \
  --node-name=k8s-node-1

# Create .kube directory for root
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

# Create .kube directory for acceldata user
mkdir -p /home/acceldata/.kube
cp /etc/kubernetes/admin.conf /home/acceldata/.kube/config
chown -R acceldata:acceldata /home/acceldata/.kube

# Save join commands
kubeadm token create --print-join-command > /tmp/control-plane-join-command
kubeadm token create --print-join-command > /tmp/worker-join-command
```

#### On Second and Third Nodes (k8s-node-2, k8s-node-3):

**Step 5: Join Control Plane**
```bash
# Copy join command from first node
scp root@1.2.3.4:/tmp/control-plane-join-command /tmp/

# Join as control plane node
bash /tmp/control-plane-join-command

# Create .kube directory for root
mkdir -p /root/.kube
scp root@1.2.3.4:/etc/kubernetes/admin.conf /root/.kube/config

# Create .kube directory for acceldata user
mkdir -p /home/acceldata/.kube
scp root@1.2.3.4:/etc/kubernetes/admin.conf /home/acceldata/.kube/config
chown -R acceldata:acceldata /home/acceldata/.kube
```

#### On First Node Only (k8s-node-1):

**Step 6: Deploy CNI Plugin**
```bash
# Deploy Flannel CNI plugin
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Wait for Flannel pods to be ready
kubectl wait --for=condition=Ready pods --all -n kube-flannel --timeout=300s
```

**Step 7: Deploy Storage Class**
```bash
# Deploy local-path provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

# Set local-path as default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**Step 8: Deploy Monitoring Stack**
```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus Stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=local-path \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set grafana.adminPassword=SecureGrafanaPassword123! \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.storageClassName=local-path \
  --set grafana.persistence.size=10Gi \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30000

# Wait for monitoring stack to be ready
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=600s
```

**Step 9: Deploy Rancher**
```bash
# Create cattle-system namespace
kubectl create namespace cattle-system

# Add Rancher Helm repository
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# Install cert-manager
helm install cert-manager https://charts.jetstack.io/charts/cert-manager-v1.13.0.tgz \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Wait for cert-manager to be ready
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s

# Install Rancher
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=1.2.3.7 \
  --set bootstrapPassword=SecureRancherPassword123! \
  --set ingress.tls.source=letsEncrypt \
  --set ingress.extraAnnotations."cert-manager\.io/cluster-issuer"="letsencrypt-prod" \
  --set ingress.extraAnnotations."nginx\.ingress\.kubernetes\.io/ssl-redirect"="true" \
  --set replicas=3 \
  --set resources.limits.cpu=1000m \
  --set resources.limits.memory=2Gi \
  --set resources.requests.cpu=500m \
  --set resources.requests.memory=1Gi \
  --set persistence.enabled=true \
  --set persistence.storageClass=local-path \
  --set persistence.size=10Gi

# Wait for Rancher to be ready
kubectl wait --for=condition=Ready pods --all -n cattle-system --timeout=600s
```

**Step 10: Configure User Management**
```bash
# Create user-management namespace
kubectl create namespace user-management

# Create default user namespaces
kubectl create namespace user-demo
kubectl create namespace user-test
kubectl create namespace user-dev

# Create Role for namespace users
kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-user
  namespace: user-demo
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims", "events", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

# Create ServiceAccounts and RoleBindings for demo users
kubectl create serviceaccount demo-user -n user-demo
kubectl create rolebinding demo-user-binding --role=namespace-user --serviceaccount=user-demo:demo-user -n user-demo

# Create ResourceQuota for demo user
kubectl apply -f - << EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-user-quota
  namespace: user-demo
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

**Step 11: Deploy GUI Management Interface**
```bash
# Create gui-management namespace
kubectl create namespace gui-management

# Deploy GUI backend
kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gui-backend
  namespace: gui-management
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gui-backend
  template:
    metadata:
      labels:
        app: gui-backend
    spec:
      containers:
      - name: backend
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

# Deploy GUI frontend
kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gui-frontend
  namespace: gui-management
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gui-frontend
  template:
    metadata:
      labels:
        app: gui-frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

# Create services
kubectl apply -f - << EOF
apiVersion: v1
kind: Service
metadata:
  name: gui-backend-service
  namespace: gui-management
spec:
  selector:
    app: gui-backend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: gui-frontend-service
  namespace: gui-management
spec:
  selector:
    app: gui-frontend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

## Step 4: Verify Cluster Setup

### 4.1 Check Cluster Status

```bash
# Get kubeconfig from first node
scp root@1.2.3.4:/etc/kubernetes/admin.conf ~/.kube/config

# Verify cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

**Expected Output:**
```
NAME         STATUS   ROLES           AGE   VERSION
k8s-node-1   Ready    control-plane   5m    v1.28.0
k8s-node-2   Ready    control-plane   4m    v1.28.0
k8s-node-3   Ready    control-plane   3m    v1.28.0
```

### 4.2 Check All Components

```bash
# Check control plane components
kubectl get pods -n kube-system

# Check CNI plugin
kubectl get pods -n kube-flannel

# Check monitoring stack
kubectl get pods -n monitoring

# Check Rancher
kubectl get pods -n cattle-system

# Check user management
kubectl get pods -n user-management

# Check GUI management
kubectl get pods -n gui-management
```

## Step 5: Access Management Interfaces

### 5.1 Get Load Balancer IP

```bash
# Get load balancer IP from Terraform output
cd terraform/
terraform output load_balancer_ip
```

**Example Output:**
```
"1.2.3.7"
```

### 5.2 Access URLs and Credentials

#### 🔐 **Rancher UI**
- **URL**: `https://1.2.3.7/rancher`
- **Username**: `admin`
- **Password**: `SecureRancherPassword123!`
- **Features**: Cluster management, application deployment, user management

#### 📊 **Grafana Dashboard**
- **URL**: `https://1.2.3.7/grafana`
- **Username**: `admin`
- **Password**: `SecureGrafanaPassword123!`
- **Features**: Monitoring dashboards, metrics visualization, alerting

#### 🖥️ **Custom Management GUI**
- **URL**: `https://1.2.3.7/gui`
- **Authentication**: No authentication required (internal use)
- **Features**: Server management, user management, resource configuration

#### 📈 **Prometheus UI**
- **URL**: `https://1.2.3.7/prometheus`
- **Authentication**: No authentication required
- **Features**: Metrics querying, target monitoring, alerting rules

### 5.3 Port Forwarding (Alternative Access)

If you prefer to access services via port forwarding:

```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Access at: http://localhost:3000

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Access at: http://localhost:9090

# Rancher
kubectl port-forward -n cattle-system svc/rancher 8080:80
# Access at: http://localhost:8080
```

## Step 6: Post-Setup Configuration

### 6.1 Configure Default User (acceldata)

The acceldata user is automatically configured on all nodes with:
- **Username**: `acceldata`
- **SSH Key**: As specified in terraform.tfvars
- **Kubernetes Access**: Full cluster access via kubeconfig
- **Docker Access**: Member of docker group

### 6.2 Test Cluster Functionality

```bash
# Deploy test application
kubectl create deployment nginx --image=nginx:alpine
kubectl expose deployment nginx --port=80 --type=ClusterIP

# Check application
kubectl get pods
kubectl get services

# Test resource quotas
kubectl run test-pod --image=busybox --rm -it --restart=Never --limits="cpu=100m,memory=128Mi" --requests="cpu=50m,memory=64Mi" -- /bin/sh
```

### 6.3 Monitor Cluster Health

```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods --all-namespaces

# Check cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Nodes Not Joining Cluster
```bash
# Check kubelet status
systemctl status kubelet

# Check kubelet logs
journalctl -u kubelet -f

# Check join token
kubeadm token list
```

#### 2. Pods Not Starting
```bash
# Check pod status
kubectl describe pod POD_NAME -n NAMESPACE

# Check pod logs
kubectl logs POD_NAME -n NAMESPACE

# Check events
kubectl get events -n NAMESPACE
```

#### 3. Services Not Accessible
```bash
# Check service endpoints
kubectl get endpoints -n NAMESPACE

# Check service details
kubectl describe service SERVICE_NAME -n NAMESPACE

# Test connectivity
kubectl exec -it POD_NAME -n NAMESPACE -- nslookup SERVICE_NAME
```

#### 4. Storage Issues
```bash
# Check persistent volumes
kubectl get pv

# Check persistent volume claims
kubectl get pvc --all-namespaces

# Check storage classes
kubectl get storageclass
```

## Security Considerations

### 1. Change Default Passwords
After initial setup, change the default passwords:
- Rancher admin password
- Grafana admin password

### 2. Configure Firewall Rules
The Terraform configuration automatically sets up firewall rules, but verify:
```bash
# Check firewall status
ufw status

# Check iptables rules
iptables -L
```

### 3. Enable RBAC
RBAC is enabled by default. Verify:
```bash
# Check RBAC configuration
kubectl get clusterroles
kubectl get clusterrolebindings
```

## Backup and Recovery

### 1. Backup etcd
```bash
# On control plane nodes
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### 2. Backup Kubernetes Resources
```bash
# Backup all resources
kubectl get all --all-namespaces -o yaml > k8s-backup-$(date +%Y%m%d).yaml
```

## Next Steps

1. **Customize monitoring dashboards** in Grafana
2. **Set up CI/CD pipelines** for application deployment
3. **Configure backup strategies** for production use
4. **Implement security policies** and network policies
5. **Scale the cluster** as needed by adding more nodes

## Support

- Check the logs for detailed error messages
- Review the monitoring dashboards for cluster health
- Use the GUI management interface for common operations
- Refer to Kubernetes documentation for advanced configurations