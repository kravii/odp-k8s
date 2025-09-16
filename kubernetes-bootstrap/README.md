# Kubernetes Cluster Bootstrap

Automated setup and management of HA Kubernetes clusters on baremetal servers.

## Overview

This project provides a complete solution for:
- Automated cluster bootstrap from inventory files
- Node preparation for baremetal servers
- Cluster scaling (add/remove nodes)
- Support for multiple OS distributions (Ubuntu, CentOS, RHEL, Rocky Linux)

## Features

- **Multi-format inventory support**: YAML, INI, CSV
- **HA Control Plane**: Automatic designation of first 3 nodes as control plane + worker
- **Parallel node preparation**: Efficient setup of multiple nodes simultaneously
- **Flexible OS support**: Ubuntu 22.04, CentOS/RHEL 8, Rocky Linux 9
- **Automated networking**: Flannel CNI with configurable CIDR ranges
- **Storage setup**: Local-path storage provisioner
- **Firewall configuration**: Automatic port management
- **Time synchronization**: NTP/chrony setup
- **Cluster scaling**: Add/remove nodes with proper cleanup

## Quick Start

### Prerequisites

- Python 3.7+
- SSH access to all target servers
- Root or sudo access on target servers
- Internet connectivity from all servers

### Installation

1. Clone or download this repository
2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

### Basic Usage

1. **Prepare inventory file** (see examples in `examples/` directory)
2. **Run cluster bootstrap**:
   ```bash
   python3 bootstrap_cluster.py examples/inventory.yaml
   ```

## Detailed Documentation

### 1. Host Inventory File

The inventory file contains information about all servers that will be part of the Kubernetes cluster.

#### Supported Formats

- **YAML** (recommended)
- **INI**
- **CSV**

#### Required Fields

- `hostname`: Server hostname or FQDN
- `ip_address`: Server IP address
- `username`: SSH username (default: root)
- `ssh_port`: SSH port (default: 22)
- `os`: Operating system (ubuntu, centos, rocky)
- `os_version`: OS version (22.04, 8, 9)

#### Example YAML Inventory

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
    
  - hostname: worker-01
    ip_address: 192.168.1.20
    username: root
    ssh_port: 22
    os: ubuntu
    os_version: "22.04"
```

### 2. Cluster Bootstrap

The main bootstrap script (`bootstrap_cluster.py`) performs the following steps:

1. **Parse inventory file**
2. **Designate roles**: First 3 nodes → control plane, remaining → workers
3. **Prepare all nodes**: Install dependencies, configure OS
4. **Initialize control plane**: Setup first master node
5. **Join additional masters**: Add remaining control plane nodes
6. **Join worker nodes**: Add all worker nodes
7. **Setup networking**: Install and configure CNI
8. **Setup storage**: Configure storage classes
9. **Verify cluster**: Check cluster health

#### Usage

```bash
# Basic bootstrap
python3 bootstrap_cluster.py inventory.yaml

# With custom configuration
python3 bootstrap_cluster.py inventory.yaml --config cluster-config.yaml

# Dry run (show what would be done)
python3 bootstrap_cluster.py inventory.yaml --dry-run
```

#### Configuration Options

Create a `cluster-config.yaml` file to customize:

```yaml
kubernetes_version: "1.28.0"
pod_network_cidr: "10.244.0.0/16"
service_cidr: "10.96.0.0/12"
container_runtime: "containerd"
cni_plugin: "flannel"
timezone: "UTC"
```

### 3. Node Preparation

The `prepare_node.sh` script prepares individual baremetal servers for Kubernetes.

#### What it does

- Updates system packages
- Configures timezone and NTP
- Disables swap
- Loads required kernel modules
- Installs container runtime (containerd/docker)
- Installs Kubernetes packages
- Configures firewall rules
- Prepares storage directories

#### Usage

```bash
# Run on target server
./scripts/prepare_node.sh --os ubuntu --version 22.04

# Or copy and run remotely
scp scripts/prepare_node.sh root@server:/tmp/
ssh root@server "chmod +x /tmp/prepare_node.sh && /tmp/prepare_node.sh"
```

### 4. Adding Nodes

Use `add_node.py` to add new nodes to an existing cluster.

#### Usage

```bash
# Add specific worker node
python3 scripts/add_node.py inventory.yaml master-node-ip --hostname new-worker-01

# Add specific control plane node
python3 scripts/add_node.py inventory.yaml master-node-ip --hostname new-master-01 --node-type control-plane

# Add node by IP
python3 scripts/add_node.py inventory.yaml master-node-ip --ip 192.168.1.30
```

### 5. Removing Nodes

Use `remove_node.py` to safely remove nodes from the cluster.

#### Usage

```bash
# Remove specific node
python3 scripts/remove_node.py inventory.yaml master-node-ip --node worker-01

# Force removal (skip drain errors)
python3 scripts/remove_node.py inventory.yaml master-node-ip --node worker-01 --force

# Remove without resetting the node
python3 scripts/remove_node.py inventory.yaml master-node-ip --node worker-01 --no-reset

# List all nodes
python3 scripts/remove_node.py inventory.yaml master-node-ip --list

# Get node status
python3 scripts/remove_node.py inventory.yaml master-node-ip --status worker-01
```

## File Structure

```
kubernetes-bootstrap/
├── bootstrap_cluster.py          # Main cluster bootstrap script
├── inventory_parser.py           # Inventory file parser
├── cluster-config.yaml           # Cluster configuration template
├── requirements.txt              # Python dependencies
├── README.md                     # This documentation
├── scripts/
│   ├── prepare_node.sh           # Node preparation script
│   ├── add_node.py               # Add node script
│   └── remove_node.py            # Remove node script
└── examples/
    ├── inventory.yaml            # YAML inventory example
    ├── inventory.ini             # INI inventory example
    └── inventory.csv             # CSV inventory example
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Verify SSH access to all servers
   - Check firewall rules
   - Ensure SSH keys are properly configured

2. **Package Installation Failed**
   - Check internet connectivity
   - Verify OS version compatibility
   - Check for proxy settings

3. **Cluster Join Failed**
   - Verify join tokens are valid
   - Check network connectivity between nodes
   - Ensure all required ports are open

4. **CNI Installation Failed**
   - Check pod network CIDR conflicts
   - Verify firewall rules for CNI traffic
   - Check node resources

### Debug Mode

Add `--verbose` flag to scripts for detailed output:

```bash
python3 bootstrap_cluster.py inventory.yaml --verbose
```

### Logs

Check system logs on nodes:
- `/var/log/syslog` (Ubuntu)
- `/var/log/messages` (CentOS/RHEL/Rocky)
- `journalctl -u kubelet` (systemd services)

## Security Considerations

- Change default SSH ports
- Use SSH keys instead of passwords
- Configure proper firewall rules
- Enable audit logging
- Use pod security standards
- Regular security updates

## Performance Tuning

- Adjust resource limits in cluster config
- Configure appropriate storage classes
- Tune CNI settings for your network
- Monitor cluster metrics

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review logs and error messages
3. Verify prerequisites and configuration
4. Test with minimal inventory first

## License

This project is provided as-is for educational and production use.