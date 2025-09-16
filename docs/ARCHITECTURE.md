# Architecture Overview

This document describes the architecture of the Hetzner Kubernetes Cluster Management Platform.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Hetzner Cloud Infrastructure                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Hybrid Node 1  │  │   Hybrid Node 2  │  │   Hybrid Node 3  │  │
│  │ Control Plane:   │  │ Control Plane:   │  │ Control Plane:   │  │
│  │ - API Server    │  │ - API Server    │  │ - API Server    │  │
│  │ - etcd          │  │ - etcd          │  │ - etcd          │  │
│  │ - Controller    │  │ - Controller    │  │ - Controller    │  │
│  │ - Scheduler     │  │ - Scheduler     │  │ - Scheduler     │  │
│  │ Worker:         │  │ Worker:         │  │ Worker:         │  │
│  │ - kubelet       │  │ - kubelet       │  │ - kubelet       │  │
│  │ - kube-proxy    │  │ - kube-proxy    │  │ - kube-proxy    │  │
│  │ - containerd    │  │ - containerd    │  │ - containerd    │  │
│  │ - CNI plugins   │  │ - CNI plugins   │  │ - CNI plugins   │  │
│  │ - Applications  │  │ - Applications  │  │ - Applications  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                     │                     │        │
│           └─────────────────────┼─────────────────────┘        │
│                                 │                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Hybrid Node 4  │  │   Hybrid Node 5  │  │   Hybrid Node N  │  │
│  │ Worker Only:     │  │ Worker Only:     │  │ Worker Only:     │  │
│  │ - kubelet        │  │ - kubelet        │  │ - kubelet        │  │
│  │ - kube-proxy     │  │ - kube-proxy     │  │ - kube-proxy     │  │
│  │ - containerd     │  │ - containerd     │  │ - containerd     │  │
│  │ - CNI plugins    │  │ - CNI plugins    │  │ - CNI plugins    │  │
│  │ - Applications   │  │ - Applications   │  │ - Applications   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                 │
┌─────────────────────────────────────────────────────────────────┐
│                    Management Layer                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │     Rancher     │  │    Grafana      │  │   Prometheus    │  │
│  │ - Cluster Mgmt  │  │ - Dashboards    │  │ - Metrics       │  │
│  │ - GUI Ops       │  │ - Visualization │  │ - Alerting      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Custom GUI     │  │ User Management │  │ Resource Pool   │  │
│  │ - Server Mgmt    │  │ - Namespaces    │  │ - CPU/RAM/Storage│  │
│  │ - Resource Mgmt  │  │ - RBAC          │  │ - Quotas        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### Infrastructure Layer

#### Hetzner Cloud Servers
- **Hybrid Nodes**: Nx servers (minimum 3) serving as both control plane and workers
- **Control Plane**: First 3 nodes run control plane components (API Server, etcd, Controller Manager, Scheduler)
- **Worker**: All nodes run worker components (kubelet, kube-proxy, applications)
- **Load Balancer**: Distributes API server traffic
- **Private Network**: Secure communication between nodes
- **Storage Volumes**: Persistent storage for applications

#### Network Architecture
```
Internet
    │
    ▼
┌─────────────┐
│ Load Balancer│
│ (Public IP) │
└─────────────┘
    │
    ▼
┌─────────────┐
│ Private     │
│ Network     │
│ 10.0.1.0/24│
└─────────────┘
    │
    ├── Hybrid Nodes (10.0.1.10-12) - Control Plane + Worker
    └── Additional Hybrid Nodes (10.0.1.13+) - Worker Only
```

### Kubernetes Layer

#### Control Plane Components
- **API Server**: Central management point
- **etcd**: Distributed key-value store
- **Controller Manager**: Manages cluster state
- **Scheduler**: Schedules pods to nodes

#### Worker Node Components
- **kubelet**: Node agent
- **kube-proxy**: Network proxy
- **containerd**: Container runtime
- **CNI Plugin**: Network plugin (Flannel)

#### Storage Layer
- **Local Path Provisioner**: Dynamic storage provisioning
- **Storage Classes**: Different storage types (SSD, HDD, NVMe)
- **Persistent Volumes**: Long-term storage

### Management Layer

#### Rancher
- **Cluster Management**: Multi-cluster management
- **GUI Operations**: Web-based cluster operations
- **User Management**: RBAC and user administration
- **Application Management**: Deploy and manage applications

#### Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alerting and notifications
- **Node Exporter**: Node-level metrics

#### Custom Management GUI
- **Server Management**: Add/remove servers
- **User Management**: Create users and namespaces
- **Resource Management**: Configure quotas and limits
- **Cluster Overview**: Real-time cluster status

## Data Flow

### Application Deployment Flow
```
Developer
    │
    ▼
┌─────────────┐
│ kubectl/    │
│ Helm        │
└─────────────┘
    │
    ▼
┌─────────────┐
│ API Server  │
│ (Load       │
│ Balancer)   │
└─────────────┘
    │
    ▼
┌─────────────┐
│ Controller  │
│ Manager     │
└─────────────┘
    │
    ▼
┌─────────────┐
│ Scheduler   │
└─────────────┘
    │
    ▼
┌─────────────┐
│ Worker      │
│ Node        │
│ (kubelet)   │
└─────────────┘
```

### Monitoring Data Flow
```
┌─────────────┐
│ Applications│
│ & Nodes     │
└─────────────┘
    │
    ▼
┌─────────────┐
│ Node        │
│ Exporter    │
└─────────────┘
    │
    ▼
┌─────────────┐
│ Prometheus  │
│ (Metrics)   │
└─────────────┘
    │
    ├── Grafana (Visualization)
    └── AlertManager (Alerts)
```

## Security Architecture

### Network Security
- **Private Network**: All cluster communication over private network
- **Firewall Rules**: Restrict access to necessary ports only
- **TLS Encryption**: All API communications encrypted
- **Network Policies**: Pod-to-pod communication control

### Access Control
- **RBAC**: Role-based access control for all users
- **Service Accounts**: Non-human access to cluster
- **Namespace Isolation**: Resource isolation between users
- **Resource Quotas**: Limit resource usage per namespace

### Container Security
- **Non-root Containers**: All containers run as non-root user
- **Read-only Root Filesystem**: Prevent container modifications
- **Security Contexts**: Define security constraints
- **Image Scanning**: Scan container images for vulnerabilities

## Resource Management

### Resource Pooling
- **CPU Pooling**: Unified CPU allocation across all nodes
- **Memory Pooling**: Unified memory allocation across all nodes
- **Storage Pooling**: Unified storage allocation across all nodes
- **Dynamic Scaling**: Add/remove resources as needed

### Resource Quotas
- **Namespace Quotas**: Limit resources per namespace
- **User Quotas**: Limit resources per user
- **Priority Classes**: Different resource priorities
- **Limit Ranges**: Default resource limits

## High Availability

### Control Plane HA
- **Multiple API Servers**: Load balanced across 3 nodes
- **etcd Clustering**: 3-node etcd cluster
- **Controller Redundancy**: Multiple controller instances
- **Scheduler Redundancy**: Multiple scheduler instances

### Application HA
- **Pod Distribution**: Pods distributed across nodes
- **Anti-affinity**: Prevent single points of failure
- **Health Checks**: Liveness and readiness probes
- **Auto-scaling**: Horizontal pod autoscaler

## Scalability

### Horizontal Scaling
- **Add Worker Nodes**: Scale compute capacity
- **Add Storage**: Scale storage capacity
- **Load Balancing**: Distribute load across nodes
- **Auto-scaling**: Automatic scaling based on metrics

### Vertical Scaling
- **Resource Limits**: Increase pod resource limits
- **Node Resources**: Upgrade node specifications
- **Storage Scaling**: Increase storage volumes
- **Network Scaling**: Increase network bandwidth

## Disaster Recovery

### Backup Strategy
- **etcd Backups**: Regular etcd snapshots
- **Configuration Backups**: Backup cluster configuration
- **Application Backups**: Backup application data
- **Infrastructure Backups**: Backup infrastructure state

### Recovery Procedures
- **Cluster Recovery**: Restore from etcd snapshots
- **Node Recovery**: Replace failed nodes
- **Application Recovery**: Restore application state
- **Data Recovery**: Restore from backups

## Performance Optimization

### Resource Optimization
- **Resource Requests**: Set appropriate resource requests
- **Resource Limits**: Set appropriate resource limits
- **Node Affinity**: Optimize pod placement
- **Storage Optimization**: Use appropriate storage classes

### Network Optimization
- **CNI Plugin**: Optimize network performance
- **Service Mesh**: Implement service mesh if needed
- **Load Balancing**: Optimize load balancing
- **DNS Optimization**: Optimize DNS resolution

## Monitoring and Observability

### Metrics Collection
- **Node Metrics**: CPU, memory, disk, network
- **Pod Metrics**: Resource usage, performance
- **Application Metrics**: Custom application metrics
- **Cluster Metrics**: Cluster health and performance

### Logging
- **Container Logs**: Application logs
- **System Logs**: Node and cluster logs
- **Audit Logs**: Security and access logs
- **Event Logs**: Cluster events

### Alerting
- **Resource Alerts**: High resource usage
- **Health Alerts**: Node and pod health
- **Security Alerts**: Security incidents
- **Performance Alerts**: Performance degradation

## Development Workflow

### Local Development
- **Telepresence**: Local development with cluster
- **kubectl**: Command-line cluster management
- **k9s**: Terminal-based cluster UI
- **Helm**: Package management

### CI/CD Integration
- **Git Integration**: Source code management
- **Build Pipeline**: Automated builds
- **Test Pipeline**: Automated testing
- **Deploy Pipeline**: Automated deployment

## Future Enhancements

### Planned Features
- **Multi-cluster Management**: Manage multiple clusters
- **Service Mesh**: Implement Istio or Linkerd
- **GitOps**: Git-based cluster management
- **Advanced Monitoring**: More detailed monitoring
- **Security Scanning**: Automated security scanning
- **Backup Automation**: Automated backup procedures