# Kubernetes Cluster Scaling Guide

Guide for adding and removing nodes from your Kubernetes cluster.

## Overview

The scaling scripts allow you to:
- Add new worker nodes
- Add new control plane nodes
- Remove existing nodes safely
- Update inventory files

## Adding Nodes

### Prerequisites for New Nodes

Before adding a node, ensure the new server:
- Has the same OS and version as existing nodes
- Can communicate with all cluster nodes
- Has SSH access configured
- Meets minimum hardware requirements

### Step 1: Prepare New Node

#### Option A: Use the Node Preparation Script

```bash
# Copy script to new server
scp scripts/prepare_node.sh root@new-server:/tmp/

# Run preparation script
ssh root@new-server "chmod +x /tmp/prepare_node.sh && /tmp/prepare_node.sh --os ubuntu --version 22.04"
```

#### Option B: Manual Preparation

If you prefer manual setup:

1. **Update system packages**
2. **Configure timezone and NTP**
3. **Disable swap**
4. **Install container runtime**
5. **Install Kubernetes packages**
6. **Configure firewall**

### Step 2: Update Inventory File

Add the new node to your inventory file:

```yaml
hosts:
  # ... existing nodes ...
  
  - hostname: worker-04
    ip_address: 192.168.1.23
    username: root
    ssh_port: 22
    os: ubuntu
    os_version: "22.04"
```

### Step 3: Add Node to Cluster

#### Add Worker Node

```bash
python3 scripts/add_node.py inventory.yaml master-node-ip --hostname worker-04
```

#### Add Control Plane Node

```bash
python3 scripts/add_node.py inventory.yaml master-node-ip --hostname master-04 --node-type control-plane
```

#### Add Node by IP

```bash
python3 scripts/add_node.py inventory.yaml master-node-ip --ip 192.168.1.23
```

### Step 4: Verify Node Addition

Check that the node has joined successfully:

```bash
# SSH to master node
ssh root@master-node-ip

# Check node status
kubectl get nodes

# Check node details
kubectl describe node worker-04
```

## Removing Nodes

### Step 1: Drain the Node

The removal process automatically drains the node, but you can do it manually first:

```bash
# SSH to master node
ssh root@master-node-ip

# Drain the node
kubectl drain worker-04 --ignore-daemonsets --delete-emptydir-data
```

### Step 2: Remove Node from Cluster

#### Basic Removal

```bash
python3 scripts/remove_node.py inventory.yaml master-node-ip --node worker-04
```

#### Force Removal

If drain fails, use force:

```bash
python3 scripts/remove_node.py inventory.yaml master-node-ip --node worker-04 --force
```

#### Remove Without Reset

If you want to keep the node configured for future use:

```bash
python3 scripts/remove_node.py inventory.yaml master-node-ip --node worker-04 --no-reset
```

### Step 3: Update Inventory File

Remove the node from your inventory file:

```yaml
hosts:
  # Remove the node entry
  # - hostname: worker-04
  #   ip_address: 192.168.1.23
  #   ...
```

### Step 4: Verify Node Removal

Check that the node has been removed:

```bash
# SSH to master node
ssh root@master-node-ip

# List all nodes
kubectl get nodes

# The removed node should not appear in the list
```

## Advanced Scaling Operations

### Adding Multiple Nodes

To add multiple nodes at once:

1. **Update inventory file** with all new nodes
2. **Prepare all nodes** using parallel execution:

```bash
# Prepare multiple nodes in parallel
for node in worker-04 worker-05 worker-06; do
    ssh root@$node "chmod +x /tmp/prepare_node.sh && /tmp/prepare_node.sh" &
done
wait
```

3. **Add nodes** one by one or modify the script for batch addition

### Control Plane Scaling

#### Adding Control Plane Nodes

Control plane nodes require special handling:

1. **Ensure odd number**: Always maintain odd number of control plane nodes (3, 5, 7)
2. **Use proper join command**: Control plane nodes need certificate keys
3. **Verify etcd health**: Check etcd cluster health after addition

```bash
# Check etcd health
kubectl get pods -n kube-system | grep etcd
```

#### Removing Control Plane Nodes

Removing control plane nodes requires careful planning:

1. **Maintain quorum**: Never reduce below 3 control plane nodes
2. **Drain properly**: Ensure all workloads are moved
3. **Update load balancer**: If using external load balancer

### Worker Node Scaling

#### Horizontal Pod Autoscaler

After adding worker nodes, configure HPA for automatic scaling:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

#### Cluster Autoscaler

For cloud environments, consider cluster autoscaler:

```bash
# Install cluster autoscaler
kubectl apply -f cluster-autoscaler.yaml
```

## Monitoring Scaling Operations

### Check Cluster Health

After scaling operations, verify cluster health:

```bash
# Check all nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods --all-namespaces

# Check cluster info
kubectl cluster-info
```

### Resource Monitoring

Monitor resource usage after scaling:

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods --all-namespaces

# Check resource quotas
kubectl describe quota --all-namespaces
```

## Troubleshooting Scaling Issues

### Node Join Failures

**Symptoms**: Node fails to join cluster

**Solutions**:
- Check network connectivity
- Verify join token validity
- Check firewall rules
- Review kubelet logs: `journalctl -u kubelet`

### Pod Scheduling Issues

**Symptoms**: Pods not scheduling on new nodes

**Solutions**:
- Check node taints and tolerations
- Verify node labels
- Check resource availability
- Review scheduler logs

### Network Issues

**Symptoms**: Pods can't communicate across nodes

**Solutions**:
- Check CNI pod status
- Verify network policies
- Check firewall rules
- Test pod-to-pod connectivity

## Best Practices

### Scaling Guidelines

1. **Plan capacity**: Add nodes before reaching resource limits
2. **Monitor metrics**: Use monitoring tools to track resource usage
3. **Test scaling**: Test scaling operations in non-production first
4. **Document changes**: Keep inventory files updated
5. **Backup etcd**: Regular etcd backups before major changes

### Security Considerations

1. **Node isolation**: Ensure proper network segmentation
2. **Access control**: Limit SSH access to new nodes
3. **Updates**: Keep new nodes updated with security patches
4. **Monitoring**: Monitor new nodes for security issues

### Performance Optimization

1. **Resource allocation**: Properly size nodes for workloads
2. **Network optimization**: Optimize CNI settings
3. **Storage planning**: Plan storage requirements
4. **Load balancing**: Distribute workloads evenly

## Automation Examples

### Automated Node Addition Script

```bash
#!/bin/bash
# add-node.sh

INVENTORY_FILE="inventory.yaml"
MASTER_NODE="192.168.1.10"
NEW_NODE_IP="$1"
NEW_NODE_HOSTNAME="$2"

if [ -z "$NEW_NODE_IP" ] || [ -z "$NEW_NODE_HOSTNAME" ]; then
    echo "Usage: $0 <node-ip> <node-hostname>"
    exit 1
fi

# Prepare the node
echo "Preparing node $NEW_NODE_HOSTNAME..."
scp scripts/prepare_node.sh root@$NEW_NODE_IP:/tmp/
ssh root@$NEW_NODE_IP "chmod +x /tmp/prepare_node.sh && /tmp/prepare_node.sh"

# Add to inventory (manual step)
echo "Please add the following to your inventory file:"
echo "  - hostname: $NEW_NODE_HOSTNAME"
echo "    ip_address: $NEW_NODE_IP"
echo "    username: root"
echo "    ssh_port: 22"
echo "    os: ubuntu"
echo "    os_version: \"22.04\""

# Add to cluster
echo "Adding node to cluster..."
python3 scripts/add_node.py $INVENTORY_FILE $MASTER_NODE --hostname $NEW_NODE_HOSTNAME

echo "Node addition completed!"
```

### Health Check Script

```bash
#!/bin/bash
# health-check.sh

MASTER_NODE="192.168.1.10"

echo "Checking cluster health..."

# Check nodes
echo "=== Nodes ==="
ssh root@$MASTER_NODE "kubectl get nodes"

# Check pods
echo "=== System Pods ==="
ssh root@$MASTER_NODE "kubectl get pods --all-namespaces | grep -v Running"

# Check resources
echo "=== Node Resources ==="
ssh root@$MASTER_NODE "kubectl top nodes"

echo "Health check completed!"
```

## Support

For scaling issues:
1. Check cluster health first
2. Review logs and error messages
3. Verify network connectivity
4. Test with single node operations
5. Consult Kubernetes documentation for advanced scenarios