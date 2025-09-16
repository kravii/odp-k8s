# Hybrid Node Architecture

This document explains the hybrid node architecture where the same servers serve as both control plane and worker nodes.

## Overview

The Hetzner Kubernetes Cluster Management Platform now uses a **hybrid node architecture** where:

- **All nodes** serve as worker nodes (run applications)
- **First 3 nodes** additionally serve as control plane nodes (API Server, etcd, Controller Manager, Scheduler)
- **Additional nodes** (4th, 5th, etc.) serve only as worker nodes

## Benefits

### Cost Efficiency
- **No dedicated control plane nodes**: Eliminates the need for separate, smaller control plane servers
- **Better resource utilization**: Control plane components use minimal resources, leaving most capacity for applications
- **Simplified scaling**: Add more nodes without worrying about control plane vs worker ratios

### Simplified Management
- **Single node type**: All nodes have the same configuration and capabilities
- **Easier scaling**: Add nodes dynamically without complex role assignments
- **Unified monitoring**: All nodes can be monitored and managed uniformly

### High Availability
- **HA Control Plane**: First 3 nodes provide high availability for control plane components
- **Distributed Workloads**: Applications can run on any node, including control plane nodes
- **Fault Tolerance**: If a control plane node fails, applications continue running on other nodes

## Architecture Details

### Node Roles

```
Node 1: Control Plane + Worker
├── API Server
├── etcd
├── Controller Manager
├── Scheduler
├── kubelet
├── kube-proxy
└── Applications

Node 2: Control Plane + Worker
├── API Server
├── etcd
├── Controller Manager
├── Scheduler
├── kubelet
├── kube-proxy
└── Applications

Node 3: Control Plane + Worker
├── API Server
├── etcd
├── Controller Manager
├── Scheduler
├── kubelet
├── kube-proxy
└── Applications

Node 4+: Worker Only
├── kubelet
├── kube-proxy
└── Applications
```

### Resource Allocation

#### Control Plane Components
- **API Server**: ~200-500m CPU, ~200-500Mi memory
- **etcd**: ~100-200m CPU, ~200-400Mi memory
- **Controller Manager**: ~100-200m CPU, ~200-300Mi memory
- **Scheduler**: ~100-200m CPU, ~200-300Mi memory
- **Total**: ~500-1100m CPU, ~800-1500Mi memory

#### Available for Applications
- **Node 1-3**: Total resources minus control plane overhead
- **Node 4+**: Full node resources available for applications

### Example Resource Distribution

For a `cx31` server (2 vCPU, 8GB RAM):

```
Control Plane Overhead:
├── CPU: ~1.1 cores (55% of 2 cores)
└── Memory: ~1.5GB (19% of 8GB)

Available for Applications:
├── CPU: ~0.9 cores (45% of 2 cores)
└── Memory: ~6.5GB (81% of 8GB)
```

## Configuration Changes

### Terraform Changes

#### Before (Dedicated Nodes)
```hcl
variable "control_plane_count" {
  default = 3
}

variable "worker_node_count" {
  default = 3
}

resource "hcloud_server" "control_plane" {
  count = var.control_plane_count
  # ...
}

resource "hcloud_server" "worker_nodes" {
  count = var.worker_node_count
  # ...
}
```

#### After (Hybrid Nodes)
```hcl
variable "node_count" {
  default = 3
  validation {
    condition     = var.node_count >= 3
    error_message = "Node count must be at least 3 for high availability."
  }
}

resource "hcloud_server" "k8s_nodes" {
  count = var.node_count
  labels = {
    control_plane = count.index < 3 ? "true" : "false"
    worker = "true"
  }
  # ...
}
```

### Ansible Changes

#### Inventory Structure
```yaml
all:
  children:
    k8s_nodes:
      hosts:
        k8s-node-1:
          control_plane: true
          worker: true
        k8s-node-2:
          control_plane: true
          worker: true
        k8s-node-3:
          control_plane: true
          worker: true
    
    control_plane:
      hosts:
        k8s-node-1:
        k8s-node-2:
        k8s-node-3:
    
    workers:
      hosts:
        k8s-node-1:
        k8s-node-2:
        k8s-node-3:
```

## Deployment Process

### 1. Infrastructure Provisioning
```bash
# Configure Terraform
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with node_count and node_server_type

# Deploy infrastructure
terraform init
terraform apply
```

### 2. Inventory Generation
```bash
# Generate Ansible inventory from Terraform output
./scripts/generate-inventory.sh
```

### 3. Cluster Setup
```bash
# Deploy Kubernetes cluster
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## Scaling Considerations

### Adding Nodes

#### Automatic Scaling
```bash
# Update node count in terraform.tfvars
node_count = 5

# Apply changes
terraform apply

# Regenerate inventory
./scripts/generate-inventory.sh

# Update cluster (if needed)
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

#### Manual Scaling
1. Add new server via Hetzner Cloud console
2. Update inventory file
3. Run Ansible playbook to configure new node
4. Join node to cluster

### Resource Planning

#### Minimum Requirements
- **3 nodes**: Minimum for HA control plane
- **Server type**: At least 2 vCPU, 8GB RAM for hybrid operation
- **Storage**: 100GB+ for applications and system

#### Recommended Configuration
- **5+ nodes**: Better distribution of workloads
- **Server type**: 4+ vCPU, 16GB+ RAM for production workloads
- **Storage**: 500GB+ for production applications

## Monitoring and Observability

### Node Metrics
- **Control Plane Metrics**: API Server, etcd, Controller Manager, Scheduler performance
- **Worker Metrics**: kubelet, kube-proxy, application resource usage
- **Combined Metrics**: Overall node health and resource utilization

### Resource Tracking
```bash
# View node resource usage
kubectl top nodes

# View pod resource usage
kubectl top pods --all-namespaces

# Check control plane component health
kubectl get pods -n kube-system
```

### Grafana Dashboards
- **Node Overview**: Combined control plane and worker metrics
- **Control Plane Health**: API Server, etcd, Controller Manager status
- **Application Performance**: Pod and container metrics
- **Resource Utilization**: CPU, memory, storage usage across all nodes

## Troubleshooting

### Common Issues

#### Control Plane Components Not Starting
```bash
# Check control plane pod status
kubectl get pods -n kube-system | grep -E "(apiserver|etcd|controller|scheduler)"

# Check node resources
kubectl describe nodes

# Check system resources
kubectl top nodes
```

#### Resource Constraints
```bash
# Check resource quotas
kubectl get resourcequotas --all-namespaces

# Check node capacity
kubectl describe nodes | grep -A 5 "Capacity:"

# Check pod resource requests
kubectl describe pods --all-namespaces | grep -A 3 "Requests:"
```

#### Node Joining Issues
```bash
# Check node status
kubectl get nodes

# Check kubelet logs
journalctl -u kubelet -f

# Check join token
kubeadm token list
```

## Best Practices

### Resource Management
1. **Set appropriate resource requests and limits** for all pods
2. **Monitor control plane resource usage** to ensure adequate capacity
3. **Use node affinity** to distribute workloads evenly
4. **Implement resource quotas** to prevent resource exhaustion

### Security
1. **Apply security contexts** to all pods
2. **Use network policies** to control pod-to-pod communication
3. **Regular security updates** via Ansible
4. **Monitor access logs** and audit trails

### Backup and Recovery
1. **Regular etcd backups** from control plane nodes
2. **Application data backups** from worker nodes
3. **Configuration backups** of cluster state
4. **Test recovery procedures** regularly

## Migration from Dedicated Nodes

If you have an existing cluster with dedicated control plane and worker nodes:

### Option 1: Gradual Migration
1. Add new hybrid nodes to the cluster
2. Drain workloads from old worker nodes
3. Remove old worker nodes
4. Convert control plane nodes to hybrid nodes

### Option 2: Complete Rebuild
1. Backup cluster configuration and data
2. Destroy existing infrastructure
3. Deploy new hybrid node cluster
4. Restore applications and data

## Conclusion

The hybrid node architecture provides a cost-effective, scalable, and manageable solution for Kubernetes clusters on Hetzner Cloud. By eliminating the need for dedicated control plane nodes, you can:

- **Reduce costs** by using fewer, more powerful servers
- **Simplify management** with uniform node configuration
- **Improve resource utilization** by running applications on all nodes
- **Maintain high availability** with distributed control plane components

This architecture is particularly suitable for small to medium-sized clusters where cost efficiency and simplicity are important considerations.