# Troubleshooting Guide

Common issues and solutions for Kubernetes cluster bootstrap and management.

## General Troubleshooting Steps

### 1. Check Prerequisites

Before troubleshooting, verify all prerequisites:

```bash
# Check Python version
python3 --version

# Check SSH access
ssh root@server-ip

# Check network connectivity
ping server-ip

# Check disk space
df -h

# Check memory
free -h
```

### 2. Enable Verbose Logging

Most scripts support verbose output:

```bash
python3 bootstrap_cluster.py inventory.yaml --verbose
```

### 3. Check Logs

Review relevant log files:

```bash
# System logs
journalctl -u kubelet
journalctl -u containerd
journalctl -u docker

# Kubernetes logs
kubectl logs -n kube-system <pod-name>
```

## Bootstrap Issues

### Issue: SSH Connection Failed

**Error**: `Failed to connect to host`

**Causes**:
- SSH service not running
- Firewall blocking SSH
- Wrong credentials
- Network connectivity issues

**Solutions**:
```bash
# Check SSH service
systemctl status sshd

# Check firewall
ufw status
firewall-cmd --list-all

# Test SSH manually
ssh -v root@server-ip

# Check network
ping server-ip
telnet server-ip 22
```

### Issue: Package Installation Failed

**Error**: `Package installation failed`

**Causes**:
- No internet connectivity
- Proxy settings
- Repository issues
- Insufficient disk space

**Solutions**:
```bash
# Check internet connectivity
curl -I https://packages.cloud.google.com

# Check proxy settings
echo $http_proxy
echo $https_proxy

# Check disk space
df -h

# Update package lists manually
apt update  # Ubuntu
yum update  # CentOS/RHEL
```

### Issue: Container Runtime Installation Failed

**Error**: `Container runtime installation failed`

**Causes**:
- Repository issues
- Version conflicts
- Insufficient resources

**Solutions**:
```bash
# Check containerd status
systemctl status containerd

# Check Docker status
systemctl status docker

# Check logs
journalctl -u containerd
journalctl -u docker

# Reinstall manually
apt remove containerd
apt install containerd
```

### Issue: Kubernetes Package Installation Failed

**Error**: `Kubernetes package installation failed`

**Causes**:
- Repository configuration issues
- Version conflicts
- GPG key problems

**Solutions**:
```bash
# Check repository configuration
cat /etc/apt/sources.list.d/kubernetes.list

# Update GPG keys
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg

# Clear package cache
apt clean
apt update
```

## Cluster Initialization Issues

### Issue: Control Plane Initialization Failed

**Error**: `kubeadm init failed`

**Causes**:
- Port conflicts
- Network issues
- Resource constraints
- Configuration errors

**Solutions**:
```bash
# Check port usage
netstat -tlnp | grep :6443

# Check network configuration
ip route
ip addr

# Check system resources
free -h
df -h

# Check kubeadm configuration
cat /tmp/kubeadm-config.yaml
```

### Issue: Join Token Invalid

**Error**: `Invalid join token`

**Causes**:
- Token expired
- Wrong token format
- Network connectivity issues

**Solutions**:
```bash
# Generate new token
kubeadm token create --print-join-command

# Check token validity
kubeadm token list

# Verify network connectivity
telnet master-ip 6443
```

### Issue: CNI Installation Failed

**Error**: `CNI installation failed`

**Causes**:
- Network conflicts
- Firewall rules
- Resource constraints

**Solutions**:
```bash
# Check Flannel pods
kubectl get pods -n kube-flannel

# Check Flannel logs
kubectl logs -n kube-flannel <pod-name>

# Check network configuration
ip route
iptables -L

# Reinstall Flannel
kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

## Node Join Issues

### Issue: Worker Node Join Failed

**Error**: `Worker node join failed`

**Causes**:
- Network connectivity
- Firewall rules
- Resource constraints
- Configuration mismatches

**Solutions**:
```bash
# Check network connectivity
ping master-ip
telnet master-ip 6443

# Check firewall rules
ufw status
firewall-cmd --list-all

# Check kubelet logs
journalctl -u kubelet

# Check node resources
free -h
df -h
```

### Issue: Control Plane Node Join Failed

**Error**: `Control plane node join failed`

**Causes**:
- Certificate issues
- etcd connectivity
- Load balancer configuration

**Solutions**:
```bash
# Check etcd health
kubectl get pods -n kube-system | grep etcd

# Check certificate validity
kubeadm certs check-expiration

# Check etcd logs
kubectl logs -n kube-system etcd-<node-name>
```

## Runtime Issues

### Issue: Pods Stuck in Pending

**Symptoms**: Pods not starting, stuck in Pending state

**Causes**:
- Resource constraints
- Node taints
- Storage issues
- Network problems

**Solutions**:
```bash
# Check pod status
kubectl get pods --all-namespaces

# Check node resources
kubectl top nodes

# Check node taints
kubectl describe nodes

# Check storage
kubectl get pv
kubectl get pvc
```

### Issue: Network Connectivity Issues

**Symptoms**: Pods can't communicate with each other

**Causes**:
- CNI configuration issues
- Firewall rules
- Network policies
- DNS problems

**Solutions**:
```bash
# Check CNI pods
kubectl get pods -n kube-flannel

# Check network policies
kubectl get networkpolicies

# Test pod-to-pod connectivity
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default

# Check DNS
kubectl get svc -n kube-system | grep dns
```

### Issue: Storage Issues

**Symptoms**: Pods can't mount volumes

**Causes**:
- Storage class issues
- Volume provisioning problems
- Permission issues

**Solutions**:
```bash
# Check storage classes
kubectl get storageclass

# Check persistent volumes
kubectl get pv

# Check persistent volume claims
kubectl get pvc

# Check storage provisioner logs
kubectl logs -n kube-system <provisioner-pod>
```

## Performance Issues

### Issue: Slow Cluster Operations

**Symptoms**: kubectl commands take long time

**Causes**:
- Resource constraints
- Network latency
- etcd performance issues
- API server overload

**Solutions**:
```bash
# Check API server metrics
kubectl top nodes

# Check etcd performance
kubectl get pods -n kube-system | grep etcd

# Check API server logs
kubectl logs -n kube-system kube-apiserver-<node-name>

# Monitor resource usage
htop
iostat
```

### Issue: High Resource Usage

**Symptoms**: Nodes running out of resources

**Causes**:
- Insufficient resources
- Resource leaks
- Inefficient workloads
- Missing resource limits

**Solutions**:
```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check resource quotas
kubectl describe quota --all-namespaces

# Check node capacity
kubectl describe nodes

# Add resource limits to workloads
```

## Security Issues

### Issue: RBAC Configuration Problems

**Symptoms**: Access denied errors

**Causes**:
- Incorrect RBAC configuration
- Missing permissions
- Wrong service accounts

**Solutions**:
```bash
# Check RBAC configuration
kubectl get roles
kubectl get rolebindings
kubectl get clusterroles
kubectl get clusterrolebindings

# Check service accounts
kubectl get serviceaccounts

# Check permissions
kubectl auth can-i <verb> <resource>
```

### Issue: Pod Security Issues

**Symptoms**: Pods failing security checks

**Causes**:
- Pod Security Standards violations
- Privileged containers
- Host network access

**Solutions**:
```bash
# Check pod security context
kubectl get pods -o yaml | grep securityContext

# Check pod security standards
kubectl get pods -o jsonpath='{.items[*].spec.securityContext}'

# Review security policies
kubectl get psp
```

## Recovery Procedures

### Cluster Recovery

If the cluster becomes unhealthy:

```bash
# Check cluster status
kubectl cluster-info

# Check all nodes
kubectl get nodes

# Check system pods
kubectl get pods --all-namespaces

# Restart failed components
kubectl delete pod <failed-pod> -n kube-system
```

### Node Recovery

If a node becomes unhealthy:

```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet logs
journalctl -u kubelet

# Restart kubelet
systemctl restart kubelet

# If needed, reset and rejoin
kubeadm reset
# Then rejoin using add_node.py
```

### Data Recovery

For data loss scenarios:

```bash
# Check etcd health
kubectl get pods -n kube-system | grep etcd

# Backup etcd
kubectl exec -n kube-system etcd-<node-name> -- etcdctl snapshot save /backup/etcd-snapshot.db

# Restore from backup if needed
kubectl exec -n kube-system etcd-<node-name> -- etcdctl snapshot restore /backup/etcd-snapshot.db
```

## Debugging Commands

### Useful Debug Commands

```bash
# Check cluster info
kubectl cluster-info dump

# Check node details
kubectl describe nodes

# Check pod details
kubectl describe pods --all-namespaces

# Check events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Check logs
kubectl logs --previous <pod-name>

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check network
kubectl get svc --all-namespaces
kubectl get endpoints --all-namespaces

# Check storage
kubectl get pv
kubectl get pvc --all-namespaces
```

### Log Analysis

```bash
# Search for errors
journalctl -u kubelet | grep -i error

# Check specific time range
journalctl -u kubelet --since "1 hour ago"

# Follow logs in real-time
journalctl -u kubelet -f

# Check container logs
docker logs <container-id>
crictl logs <container-id>
```

## Getting Help

### Information to Collect

When seeking help, collect:

1. **Cluster information**:
   ```bash
   kubectl version
   kubectl get nodes -o wide
   kubectl get pods --all-namespaces
   ```

2. **Error logs**:
   ```bash
   journalctl -u kubelet --no-pager
   kubectl logs <failed-pod> --previous
   ```

3. **System information**:
   ```bash
   uname -a
   cat /etc/os-release
   free -h
   df -h
   ```

4. **Network information**:
   ```bash
   ip route
   ip addr
   iptables -L
   ```

### Support Resources

- Kubernetes documentation
- GitHub issues
- Community forums
- Professional support

### Escalation Process

1. Check this troubleshooting guide
2. Search online for similar issues
3. Check Kubernetes documentation
4. Post in community forums
5. Contact professional support if needed