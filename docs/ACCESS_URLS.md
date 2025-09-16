# Access URLs and Credentials

This document provides a quick reference for all accessible UI links and their credentials.

## 🌐 Management Interfaces

### 🔐 Rancher UI
- **URL**: `https://LOAD_BALANCER_IP/rancher`
- **Username**: `admin`
- **Password**: `SecureRancherPassword123!`
- **Purpose**: Cluster management, application deployment, user management
- **Features**:
  - Multi-cluster management
  - Application marketplace
  - User and RBAC management
  - Monitoring and logging
  - Backup and restore

### 📊 Grafana Dashboard
- **URL**: `https://LOAD_BALANCER_IP/grafana`
- **Username**: `admin`
- **Password**: `SecureGrafanaPassword123!`
- **Purpose**: Monitoring dashboards and metrics visualization
- **Features**:
  - Kubernetes cluster monitoring
  - Node and pod metrics
  - Baremetal server monitoring
  - Custom dashboards
  - Alerting rules

### 🖥️ Custom Management GUI
- **URL**: `https://LOAD_BALANCER_IP/gui`
- **Authentication**: No authentication required
- **Purpose**: Custom cluster management interface
- **Features**:
  - Server management (add/remove nodes)
  - User management (create users and namespaces)
  - Resource quota management
  - Cluster overview and status

### 📈 Prometheus UI
- **URL**: `https://LOAD_BALANCER_IP/prometheus`
- **Authentication**: No authentication required
- **Purpose**: Metrics querying and monitoring
- **Features**:
  - Metrics querying (PromQL)
  - Target monitoring
  - Alerting rules
  - Service discovery

## 🔧 Alternative Access Methods

### Port Forwarding
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

# AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
# Access at: http://localhost:9093
```

## 🔑 Default User Access

### acceldata User
- **Username**: `acceldata`
- **SSH Access**: Available on all nodes
- **SSH Key**: As configured in terraform.tfvars
- **Kubernetes Access**: Full cluster access via kubeconfig
- **Docker Access**: Member of docker group

### SSH Access to Nodes
```bash
# Access any node via SSH
ssh acceldata@NODE_IP

# Or as root
ssh root@NODE_IP
```

## 📋 Quick Commands

### Get Load Balancer IP
```bash
cd terraform/
terraform output load_balancer_ip
```

### Check Cluster Status
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Access Services
```bash
# List all services
kubectl get services --all-namespaces

# Get service details
kubectl describe service SERVICE_NAME -n NAMESPACE
```

## 🛡️ Security Notes

### Change Default Passwords
After initial setup, change these default passwords:
- **Rancher**: Change admin password in Rancher UI
- **Grafana**: Change admin password in Grafana UI

### Access Control
- **Rancher**: Full cluster management access
- **Grafana**: Read-only monitoring access
- **Custom GUI**: Internal management interface
- **Prometheus**: Read-only metrics access

## 🔍 Troubleshooting Access

### Service Not Accessible
```bash
# Check service status
kubectl get services -n NAMESPACE

# Check pod status
kubectl get pods -n NAMESPACE

# Check ingress
kubectl get ingress --all-namespaces
```

### Authentication Issues
```bash
# Check Rancher pods
kubectl get pods -n cattle-system

# Check Grafana pods
kubectl get pods -n monitoring

# Check logs
kubectl logs -n cattle-system deployment/rancher
kubectl logs -n monitoring deployment/prometheus-grafana
```

### Network Issues
```bash
# Check load balancer
kubectl get services -n cattle-system

# Check firewall rules
kubectl get networkpolicies --all-namespaces

# Test connectivity
curl -k https://LOAD_BALANCER_IP/rancher
curl -k https://LOAD_BALANCER_IP/grafana
```

## 📱 Mobile Access

All interfaces are responsive and can be accessed from mobile devices:
- **Rancher**: Mobile-friendly cluster management
- **Grafana**: Mobile dashboards and monitoring
- **Custom GUI**: Mobile-optimized management interface

## 🔄 Service URLs Summary

| Service | URL | Username | Password | Purpose |
|---------|-----|----------|----------|---------|
| Rancher | `https://LB_IP/rancher` | admin | SecureRancherPassword123! | Cluster Management |
| Grafana | `https://LB_IP/grafana` | admin | SecureGrafanaPassword123! | Monitoring |
| Custom GUI | `https://LB_IP/gui` | - | - | Management Interface |
| Prometheus | `https://LB_IP/prometheus` | - | - | Metrics Querying |

## 🚀 Quick Start

1. **Get Load Balancer IP**: `terraform output load_balancer_ip`
2. **Access Rancher**: `https://LB_IP/rancher` (admin / SecureRancherPassword123!)
3. **Access Grafana**: `https://LB_IP/grafana` (admin / SecureGrafanaPassword123!)
4. **Access Custom GUI**: `https://LB_IP/gui`
5. **Access Prometheus**: `https://LB_IP/prometheus`

## 📞 Support

- **Documentation**: Check `docs/` directory for detailed guides
- **Logs**: Use `kubectl logs` to check service logs
- **Monitoring**: Use Grafana dashboards for cluster health
- **Management**: Use Rancher UI for cluster operations