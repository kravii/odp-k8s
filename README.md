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

## Quick Start

1. **Prerequisites**
   ```bash
   # Install required tools
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   
   # Install Terraform
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Install Ansible
   pip3 install ansible
   ```

2. **Configure Infrastructure**
   ```bash
   cd terraform/
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Hetzner API token and server specs
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy Kubernetes Cluster**
   ```bash
   cd ansible/
   ansible-playbook -i inventory/hosts.yml site.yml
   ```

4. **Access Management Interface**
   ```bash
   # Get Rancher URL
   kubectl get svc -n cattle-system rancher
   
   # Access monitoring dashboard
   kubectl port-forward -n monitoring svc/grafana 3000:80
   ```

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