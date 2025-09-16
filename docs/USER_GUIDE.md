# User Guide

This guide provides comprehensive instructions for using the Hetzner Kubernetes Cluster Management Platform.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Accessing the Cluster](#accessing-the-cluster)
3. [User Management](#user-management)
4. [Resource Management](#resource-management)
5. [Application Deployment](#application-deployment)
6. [Monitoring and Observability](#monitoring-and-observability)
7. [Development Tools](#development-tools)
8. [Troubleshooting](#troubleshooting)

## Getting Started

### Prerequisites

Before using the cluster, ensure you have:

- Access credentials (username/password or kubeconfig)
- Basic understanding of Kubernetes concepts
- kubectl installed on your local machine
- SSH access to cluster nodes (if needed)

### Initial Setup

1. **Get Cluster Access**
   ```bash
   # Download kubeconfig from cluster admin
   scp admin@CLUSTER_IP:/etc/kubernetes/admin.conf ~/.kube/config
   
   # Verify access
   kubectl get nodes
   ```

2. **Set Default Namespace**
   ```bash
   # Switch to your namespace
   kubectl config set-context --current --namespace=your-namespace
   ```

## Accessing the Cluster

### Web Interfaces

#### Rancher UI
- **URL**: `https://CLUSTER_IP/rancher`
- **Username**: `admin`
- **Password**: Provided by cluster administrator
- **Features**: Cluster management, application deployment, user management

#### Grafana Dashboard
- **URL**: `https://CLUSTER_IP/grafana`
- **Username**: `admin`
- **Password**: Provided by cluster administrator
- **Features**: Monitoring dashboards, metrics visualization, alerting

#### Custom Management GUI
- **URL**: `https://CLUSTER_IP/gui`
- **Features**: Server management, user management, resource configuration

### Command Line Access

#### kubectl
```bash
# Basic commands
kubectl get pods
kubectl get services
kubectl get nodes

# Describe resources
kubectl describe pod POD_NAME
kubectl describe node NODE_NAME

# Logs
kubectl logs POD_NAME
kubectl logs -f POD_NAME  # Follow logs
```

#### k9s Terminal UI
```bash
# Start k9s
k9s

# Navigation shortcuts
: pods          # View pods
: services      # View services
: nodes         # View nodes
: namespaces    # View namespaces
: quit          # Exit k9s
```

## User Management

### Creating Users

#### Via GUI
1. Access the Custom Management GUI
2. Navigate to "User Management"
3. Click "Create User"
4. Fill in user details:
   - Username
   - Namespace
   - CPU limit (e.g., "2")
   - Memory limit (e.g., "4Gi")
5. Click "Create"

#### Via CLI
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
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
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
```

### Managing User Access

#### View User Permissions
```bash
# List ServiceAccounts
kubectl get serviceaccounts --all-namespaces

# View RoleBindings
kubectl get rolebindings --all-namespaces

# Describe user permissions
kubectl describe rolebinding USER_BINDING -n NAMESPACE
```

#### Update User Permissions
```bash
# Update Role
kubectl patch role namespace-user -n user-example --type='merge' -p='{"rules":[{"apiGroups":[""],"resources":["pods","services"],"verbs":["get","list","watch","create","update","patch","delete"]}]}'
```

## Resource Management

### Resource Quotas

#### View Current Quotas
```bash
# List resource quotas
kubectl get resourcequotas --all-namespaces

# Describe quota details
kubectl describe resourcequota QUOTA_NAME -n NAMESPACE
```

#### Create Resource Quota
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: user-quota
  namespace: user-example
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
    persistentvolumeclaims: "10"
    pods: "20"
    services: "10"
EOF
```

#### Update Resource Quota
```bash
# Increase CPU limit
kubectl patch resourcequota user-quota -n user-example --type='merge' -p='{"spec":{"hard":{"requests.cpu":"4","limits.cpu":"8"}}}'
```

### Limit Ranges

#### Create Limit Range
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: user-limits
  namespace: user-example
spec:
  limits:
  - default:
      cpu: "1"
      memory: 2Gi
    defaultRequest:
      cpu: "0.5"
      memory: 1Gi
    type: Container
EOF
```

### Resource Monitoring

#### View Resource Usage
```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods --all-namespaces

# Pod resource usage in specific namespace
kubectl top pods -n user-example
```

#### Resource Requests and Limits

When creating pods, always specify resource requests and limits:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
spec:
  containers:
  - name: app
    image: nginx:alpine
    resources:
      requests:
        cpu: "0.5"
        memory: "1Gi"
      limits:
        cpu: "1"
        memory: "2Gi"
```

## Application Deployment

### Using kubectl

#### Deploy Simple Application
```bash
# Create deployment
kubectl create deployment nginx --image=nginx:alpine

# Scale deployment
kubectl scale deployment nginx --replicas=3

# Expose deployment
kubectl expose deployment nginx --port=80 --type=ClusterIP

# Get service information
kubectl get services
```

#### Deploy from YAML
```bash
# Create from file
kubectl apply -f app.yaml

# Update from file
kubectl apply -f app.yaml

# Delete from file
kubectl delete -f app.yaml
```

### Using Helm

#### Install Helm Chart
```bash
# Add Helm repository
helm repo add stable https://charts.helm.sh/stable
helm repo update

# Install chart
helm install my-app stable/nginx

# List installed charts
helm list

# Upgrade chart
helm upgrade my-app stable/nginx

# Uninstall chart
helm uninstall my-app
```

#### Create Custom Helm Chart
```bash
# Create new chart
helm create my-chart

# Package chart
helm package my-chart

# Install from package
helm install my-app ./my-chart-0.1.0.tgz
```

### Using Rancher UI

1. **Access Rancher UI**
2. **Navigate to "Apps & Marketplace"**
3. **Select application to deploy**
4. **Configure application settings**
5. **Deploy application**

## Monitoring and Observability

### Grafana Dashboards

#### Access Dashboards
1. Open Grafana at `https://CLUSTER_IP/grafana`
2. Navigate to "Dashboards"
3. Select dashboard:
   - **Kubernetes Cluster**: Overall cluster health
   - **Node Metrics**: Individual node performance
   - **Pod Metrics**: Pod performance and resource usage
   - **Baremetal Monitoring**: Server hardware metrics

#### Create Custom Dashboard
1. Click "Create" → "Dashboard"
2. Add panels for metrics you want to monitor
3. Configure queries using Prometheus data source
4. Save dashboard

### Prometheus Metrics

#### Access Prometheus
- **URL**: `https://CLUSTER_IP/prometheus`
- **Features**: Query metrics, view targets, configure alerts

#### Common Queries
```promql
# CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"})

# Pod count
count(kube_pod_info)
```

### Alerting

#### View Alerts
```bash
# List alerting rules
kubectl get prometheusrules -n monitoring

# View alert status
kubectl describe prometheusrules -n monitoring
```

#### Configure Alerts
Alerts are pre-configured for:
- High CPU usage (>80%)
- High memory usage (>85%)
- High disk usage (>90%)
- Node down
- Pod crash looping

## Development Tools

### Telepresence

#### Install Telepresence
```bash
# Linux
curl -s https://packagecloud.io/install/repositories/datawireio/telepresence/script.deb.sh | sudo bash
sudo apt install -y telepresence

# macOS
brew install datawire/blackbird/telepresence
```

#### Use Telepresence
```bash
# Connect to cluster
telepresence connect

# List services
telepresence list

# Intercept service
telepresence intercept SERVICE_NAME --port LOCAL_PORT:REMOTE_PORT

# Leave intercept
telepresence leave SERVICE_NAME

# Disconnect
telepresence quit
```

### Local Development Workflow

1. **Start Telepresence**
   ```bash
   telepresence connect
   ```

2. **Run Application Locally**
   ```bash
   # Your application can now access cluster services
   # using cluster DNS names (e.g., service.namespace.svc.cluster.local)
   ```

3. **Intercept Service for Testing**
   ```bash
   telepresence intercept my-service --port 8080:80
   ```

4. **Test with Cluster Services**
   ```bash
   # Access your local service via cluster DNS
   curl http://my-service.default.svc.cluster.local:8080
   ```

## Troubleshooting

### Common Issues

#### Pod Not Starting
```bash
# Check pod status
kubectl describe pod POD_NAME -n NAMESPACE

# Check pod logs
kubectl logs POD_NAME -n NAMESPACE

# Check events
kubectl get events -n NAMESPACE
```

#### Resource Quota Exceeded
```bash
# Check quota usage
kubectl describe resourcequota -n NAMESPACE

# Check pod resource requests
kubectl describe pod POD_NAME -n NAMESPACE
```

#### Network Issues
```bash
# Check service endpoints
kubectl get endpoints -n NAMESPACE

# Check service details
kubectl describe service SERVICE_NAME -n NAMESPACE

# Test connectivity
kubectl exec -it POD_NAME -n NAMESPACE -- nslookup SERVICE_NAME
```

#### Storage Issues
```bash
# Check persistent volumes
kubectl get pv

# Check persistent volume claims
kubectl get pvc -n NAMESPACE

# Check storage classes
kubectl get storageclass
```

### Debugging Commands

#### Cluster Information
```bash
# Cluster info
kubectl cluster-info

# Node details
kubectl describe nodes

# Component status
kubectl get componentstatuses
```

#### Resource Usage
```bash
# Top nodes
kubectl top nodes

# Top pods
kubectl top pods --all-namespaces

# Resource usage by namespace
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top pods --all-namespaces --sort-by=memory
```

#### Logs and Events
```bash
# System logs
kubectl logs -n kube-system kube-apiserver-NODE_NAME
kubectl logs -n kube-system kube-controller-manager-NODE_NAME
kubectl logs -n kube-system kube-scheduler-NODE_NAME

# All events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Getting Help

#### Documentation
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Rancher Documentation](https://rancher.com/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

#### Community Support
- [Kubernetes Slack](https://kubernetes.slack.com/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/kubernetes)
- [GitHub Issues](https://github.com/kubernetes/kubernetes/issues)

#### Cluster Administrator
- Contact your cluster administrator for:
  - Access issues
  - Resource quota increases
  - New user creation
  - Infrastructure problems
  - Security concerns