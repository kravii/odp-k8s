# Hetzner Kubernetes Cluster Setup Guide

This guide will walk you through setting up a complete Kubernetes cluster on Hetzner baremetal servers with all the required features.

## Prerequisites

### Required Tools
- Terraform >= 1.0
- Ansible >= 2.9
- kubectl >= 1.28
- Helm >= 3.0
- Git

### Required Accounts
- Hetzner Cloud account with API token
- SSH key pair for server access

### System Requirements
- Control Plane: 3x servers (minimum 2 vCPU, 4GB RAM)
- Worker Nodes: Nx servers (minimum 2 vCPU, 8GB RAM)
- Additional storage: 100GB+ per worker node

## Step 1: Infrastructure Setup

### 1.1 Configure Terraform

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your configuration:

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
control_plane_count = 3
worker_node_count = 3

# Server Types
control_plane_server_type = "cx21"  # 2 vCPU, 4GB RAM
worker_server_type = "cx31"         # 2 vCPU, 8GB RAM

# Storage Configuration
additional_storage_size = 100  # GB

# Application Passwords
rancher_password = "SecureRancherPassword123!"
grafana_password = "SecureGrafanaPassword123!"

# Default User Configuration
acceldata_ssh_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhA... acceldata@cluster"
```

### 1.2 Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

This will create:
- 3 control plane servers
- 3 worker nodes
- Private network
- Load balancer
- Firewall rules
- Additional storage volumes

### 1.3 Get Server Information

```bash
terraform output
```

Note down the IP addresses and other outputs for the next steps.

## Step 2: Kubernetes Cluster Setup

### 2.1 Configure Ansible Inventory

Update `ansible/inventory/hosts.yml` with the server IPs from Terraform output:

```yaml
all:
  children:
    control_plane:
      hosts:
        k8s-control-plane-1:
          ansible_host: "YOUR_CONTROL_PLANE_IP_1"
          node_ip: "YOUR_CONTROL_PLANE_PRIVATE_IP_1"
        k8s-control-plane-2:
          ansible_host: "YOUR_CONTROL_PLANE_IP_2"
          node_ip: "YOUR_CONTROL_PLANE_PRIVATE_IP_2"
        k8s-control-plane-3:
          ansible_host: "YOUR_CONTROL_PLANE_IP_3"
          node_ip: "YOUR_CONTROL_PLANE_PRIVATE_IP_3"
    
    workers:
      hosts:
        k8s-worker-1:
          ansible_host: "YOUR_WORKER_IP_1"
          node_ip: "YOUR_WORKER_PRIVATE_IP_1"
        k8s-worker-2:
          ansible_host: "YOUR_WORKER_IP_2"
          node_ip: "YOUR_WORKER_PRIVATE_IP_2"
        k8s-worker-3:
          ansible_host: "YOUR_WORKER_IP_3"
          node_ip: "YOUR_WORKER_PRIVATE_IP_3"
```

### 2.2 Deploy Kubernetes Cluster

```bash
cd ansible/
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

This will:
- Install Docker and containerd
- Install Kubernetes components
- Initialize the cluster with HA control plane
- Join worker nodes
- Deploy CNI plugin (Flannel)
- Set up storage classes
- Deploy monitoring stack
- Install Rancher
- Configure user management
- Deploy GUI management interface

### 2.3 Verify Cluster Setup

```bash
# Get kubeconfig from first control plane node
scp root@CONTROL_PLANE_IP_1:/etc/kubernetes/admin.conf ~/.kube/config

# Verify cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

## Step 3: Access Management Interfaces

### 3.1 Rancher UI

Access Rancher at: `https://LOAD_BALANCER_IP/rancher`

Default credentials:
- Username: `admin`
- Password: `SecureRancherPassword123!` (from terraform.tfvars)

### 3.2 Grafana Dashboard

Access Grafana at: `https://LOAD_BALANCER_IP/grafana`

Default credentials:
- Username: `admin`
- Password: `SecureGrafanaPassword123!` (from terraform.tfvars)

### 3.3 GUI Management Interface

Access the custom GUI at: `https://LOAD_BALANCER_IP/gui`

This provides:
- Server management (add/remove servers)
- User management (create users and namespaces)
- Resource quota management
- Cluster overview

## Step 4: Development Tools Setup

### 4.1 Install Development Tools

```bash
./scripts/install-dev-tools.sh
```

This installs:
- kubectl
- Helm
- k9s
- Telepresence

### 4.2 Connect to Cluster

```bash
cd ~/k8s-dev-workspace
./scripts/connect-cluster.sh
```

### 4.3 Start k9s Terminal UI

```bash
k9s
```

## Step 5: User Management

### 5.1 Create Users via GUI

1. Access the GUI management interface
2. Navigate to "User Management"
3. Click "Create User"
4. Fill in user details:
   - Username
   - Namespace
   - CPU limit
   - Memory limit

### 5.2 Create Users via CLI

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

## Step 6: Monitoring Setup

### 6.1 Access Monitoring Dashboards

- **Grafana**: `https://LOAD_BALANCER_IP/grafana`
- **Prometheus**: `https://LOAD_BALANCER_IP/prometheus`

### 6.2 View Cluster Metrics

```bash
# Node metrics
kubectl top nodes

# Pod metrics
kubectl top pods --all-namespaces

# Resource usage
kubectl describe nodes
```

### 6.3 Set Up Alerts

Alerts are pre-configured for:
- High CPU usage (>80%)
- High memory usage (>85%)
- High disk usage (>90%)
- Node down
- Pod crash looping

## Step 7: Resource Management

### 7.1 View Resource Pool Status

```bash
kubectl get configmap resource-pool-status -n kube-system -o yaml
```

### 7.2 Configure Resource Quotas

```bash
# Update resource quota
kubectl patch resourcequota example-user-quota -n user-example --type='merge' -p='{"spec":{"hard":{"requests.cpu":"4","requests.memory":"8Gi"}}}'
```

### 7.3 Add/Remove Servers

Use the GUI management interface or Rancher UI to:
- Add new servers to the cluster
- Remove servers from the cluster
- Scale worker nodes

## Troubleshooting

### Common Issues

1. **Cluster not accessible**
   ```bash
   # Check firewall rules
   kubectl get nodes
   kubectl get pods -n kube-system
   ```

2. **Pods not starting**
   ```bash
   # Check pod status
   kubectl describe pod POD_NAME -n NAMESPACE
   kubectl logs POD_NAME -n NAMESPACE
   ```

3. **Storage issues**
   ```bash
   # Check storage classes
   kubectl get storageclass
   kubectl get pv
   kubectl get pvc --all-namespaces
   ```

4. **Network issues**
   ```bash
   # Check CNI plugin
   kubectl get pods -n kube-flannel
   kubectl get nodes -o wide
   ```

### Logs and Debugging

```bash
# Control plane logs
kubectl logs -n kube-system kube-apiserver-CONTROL_PLANE_NODE
kubectl logs -n kube-system kube-controller-manager-CONTROL_PLANE_NODE
kubectl logs -n kube-system kube-scheduler-CONTROL_PLANE_NODE

# Node logs
journalctl -u kubelet -f
journalctl -u containerd -f
```

## Security Considerations

1. **Change default passwords** after initial setup
2. **Enable RBAC** for all users
3. **Use network policies** for pod isolation
4. **Regular security updates** via Ansible
5. **Monitor access logs** via Grafana

## Backup and Recovery

### Backup etcd

```bash
# On control plane node
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Backup Kubernetes Resources

```bash
# Backup all resources
kubectl get all --all-namespaces -o yaml > k8s-backup-$(date +%Y%m%d).yaml
```

## Next Steps

1. **Customize monitoring** dashboards in Grafana
2. **Set up CI/CD** pipelines
3. **Configure backup** strategies
4. **Implement security** policies
5. **Scale the cluster** as needed

## Support

- Check the logs for detailed error messages
- Review the monitoring dashboards
- Use the GUI management interface for common operations
- Refer to Kubernetes documentation for advanced configurations