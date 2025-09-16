# Kubernetes Cluster Setup Guide

Step-by-step guide for setting up a Kubernetes cluster using the bootstrap scripts.

## Prerequisites

### System Requirements

- **Minimum 3 servers** for HA control plane
- **Recommended specs per server**:
  - CPU: 2+ cores
  - RAM: 4+ GB
  - Storage: 20+ GB
  - Network: 1+ Gbps

### Software Requirements

- **Operating Systems**:
  - Ubuntu 22.04 LTS
  - CentOS 8 / RHEL 8
  - Rocky Linux 9

- **Network Requirements**:
  - All servers must be able to communicate with each other
  - Internet access for package downloads
  - No conflicting IP ranges

### Access Requirements

- SSH access to all servers
- Root or sudo privileges
- SSH key-based authentication (recommended)

## Step 1: Prepare Your Environment

### 1.1 Download the Bootstrap Scripts

```bash
# Clone or download the repository
git clone <repository-url>
cd kubernetes-bootstrap

# Install Python dependencies
pip install -r requirements.txt
```

### 1.2 Configure SSH Access

Ensure you can SSH to all servers without password prompts:

```bash
# Test SSH access
ssh root@192.168.1.10
ssh root@192.168.1.11
ssh root@192.168.1.12
```

### 1.3 Verify Network Connectivity

Test connectivity between servers:

```bash
# From each server, ping all other servers
ping 192.168.1.10
ping 192.168.1.11
ping 192.168.1.12
```

## Step 2: Create Inventory File

### 2.1 Choose Format

Select one of the supported formats:
- **YAML** (recommended for readability)
- **INI** (good for simple configurations)
- **CSV** (easy to generate from spreadsheets)

### 2.2 Create Inventory

Copy one of the example files and modify:

```bash
cp examples/inventory.yaml my-cluster-inventory.yaml
```

Edit the file with your server details:

```yaml
hosts:
  - hostname: master-01
    ip_address: 192.168.1.10
    username: root
    ssh_port: 22
    os: ubuntu
    os_version: "22.04"
    
  - hostname: master-02
    ip_address: 192.168.1.11
    username: root
    ssh_port: 22
    os: ubuntu
    os_version: "22.04"
    
  - hostname: master-03
    ip_address: 192.168.1.12
    username: root
    ssh_port: 22
    os: ubuntu
    os_version: "22.04"
    
  - hostname: worker-01
    ip_address: 192.168.1.20
    username: root
    ssh_port: 22
    os: ubuntu
    os_version: "22.04"
```

### 2.3 Validate Inventory

Test the inventory parser:

```bash
python3 inventory_parser.py my-cluster-inventory.yaml
```

## Step 3: Configure Cluster Settings

### 3.1 Create Configuration File

Copy the template and customize:

```bash
cp cluster-config.yaml my-cluster-config.yaml
```

### 3.2 Key Settings

Edit the following settings based on your environment:

```yaml
# Kubernetes version
kubernetes_version: "1.28.0"

# Network ranges (ensure no conflicts)
pod_network_cidr: "10.244.0.0/16"
service_cidr: "10.96.0.0/12"

# Container runtime
container_runtime: "containerd"

# Timezone
timezone: "America/New_York"

# NTP servers
ntp_servers:
  - "pool.ntp.org"
  - "time.google.com"
```

## Step 4: Run Cluster Bootstrap

### 4.1 Dry Run (Recommended)

First, run a dry run to verify everything looks correct:

```bash
python3 bootstrap_cluster.py my-cluster-inventory.yaml --config my-cluster-config.yaml --dry-run
```

### 4.2 Full Bootstrap

If the dry run looks good, run the actual bootstrap:

```bash
python3 bootstrap_cluster.py my-cluster-inventory.yaml --config my-cluster-config.yaml
```

### 4.3 Monitor Progress

The bootstrap process will:
1. Prepare all nodes (installing packages, configuring OS)
2. Initialize the first control plane node
3. Join additional control plane nodes
4. Join worker nodes
5. Setup networking (Flannel CNI)
6. Setup storage (local-path provisioner)
7. Verify cluster health

## Step 5: Verify Cluster

### 5.1 Check Node Status

SSH to the first master node and check:

```bash
ssh root@192.168.1.10
kubectl get nodes -o wide
```

All nodes should show `Ready` status.

### 5.2 Check Pod Status

```bash
kubectl get pods --all-namespaces
```

All system pods should be running.

### 5.3 Test Cluster Functionality

Deploy a test application:

```bash
kubectl run nginx --image=nginx --port=80
kubectl expose pod nginx --type=NodePort --port=80
kubectl get services
```

## Step 6: Post-Setup Configuration

### 6.1 Configure kubectl Access

Copy kubeconfig to your local machine:

```bash
scp root@192.168.1.10:/etc/kubernetes/admin.conf ~/.kube/config
```

### 6.2 Install kubectl Locally

```bash
# Ubuntu/Debian
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# macOS
brew install kubectl
```

### 6.3 Test Local Access

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

## Troubleshooting Common Issues

### Issue: SSH Connection Failed

**Symptoms**: Script fails with SSH connection errors

**Solutions**:
- Verify SSH access: `ssh root@server-ip`
- Check firewall rules
- Ensure SSH keys are configured
- Test with verbose SSH: `ssh -v root@server-ip`

### Issue: Package Installation Failed

**Symptoms**: Node preparation fails during package installation

**Solutions**:
- Check internet connectivity
- Verify OS version compatibility
- Check for proxy settings
- Update package lists manually

### Issue: Cluster Join Failed

**Symptoms**: Nodes fail to join the cluster

**Solutions**:
- Check network connectivity between nodes
- Verify firewall rules for Kubernetes ports
- Check join token validity
- Review kubelet logs: `journalctl -u kubelet`

### Issue: CNI Not Working

**Symptoms**: Pods stuck in Pending state

**Solutions**:
- Check pod network CIDR conflicts
- Verify Flannel pods are running
- Check firewall rules for CNI traffic
- Review CNI logs: `kubectl logs -n kube-flannel`

## Next Steps

After successful cluster setup:

1. **Install Ingress Controller** (nginx, traefik)
2. **Setup Monitoring** (Prometheus, Grafana)
3. **Configure Logging** (ELK stack, Fluentd)
4. **Setup Backup** (Velero)
5. **Configure Security** (RBAC, Pod Security Standards)
6. **Deploy Applications**

## Maintenance

### Regular Tasks

- **Update packages**: Run `prepare_node.sh` periodically
- **Backup etcd**: Regular etcd snapshots
- **Monitor resources**: Check node and pod resource usage
- **Security updates**: Keep Kubernetes and OS updated

### Scaling Operations

- **Add nodes**: Use `add_node.py` script
- **Remove nodes**: Use `remove_node.py` script
- **Update inventory**: Keep inventory file current

## Support

For additional help:
- Check the main README.md
- Review script logs and error messages
- Test with minimal inventory first
- Verify all prerequisites are met