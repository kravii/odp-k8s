#!/bin/bash
# Kubernetes Node Preparation Script
# Prepares a baremetal server for Kubernetes cluster

set -euo pipefail

# Default values
OS="ubuntu"
OS_VERSION="22.04"
TIMEZONE="UTC"
CONTAINER_RUNTIME="containerd"
KUBERNETES_VERSION="1.28.0"
NTP_SERVERS="pool.ntp.org time.google.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --os)
                OS="$2"
                shift 2
                ;;
            --version)
                OS_VERSION="$2"
                shift 2
                ;;
            --timezone)
                TIMEZONE="$2"
                shift 2
                ;;
            --container-runtime)
                CONTAINER_RUNTIME="$2"
                shift 2
                ;;
            --kubernetes-version)
                KUBERNETES_VERSION="$2"
                shift 2
                ;;
            --ntp-servers)
                NTP_SERVERS="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Kubernetes Node Preparation Script

Usage: $0 [OPTIONS]

Options:
    --os OS                     Operating system (ubuntu, centos, rocky)
    --version VERSION           OS version (e.g., 22.04, 8, 9)
    --timezone TIMEZONE         Timezone (default: UTC)
    --container-runtime RUNTIME Container runtime (containerd, docker)
    --kubernetes-version VERSION Kubernetes version (default: 1.28.0)
    --ntp-servers SERVERS       NTP servers (space-separated)
    --help                      Show this help message

Examples:
    $0 --os ubuntu --version 22.04
    $0 --os centos --version 8 --timezone America/New_York
EOF
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        OS_VERSION="$VERSION_ID"
        log_info "Detected OS: $OS $OS_VERSION"
    else
        log_warning "Cannot detect OS from /etc/os-release, using defaults"
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -y
            apt-get upgrade -y
            apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates
            ;;
        centos|rhel|rocky|almalinux)
            yum update -y
            yum install -y curl wget gnupg2 yum-utils device-mapper-persistent-data lvm2
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    log_success "System packages updated"
}

# Configure timezone and NTP
configure_time() {
    log_info "Configuring timezone and NTP..."
    
    # Set timezone
    timedatectl set-timezone "$TIMEZONE"
    log_success "Timezone set to $TIMEZONE"
    
    # Configure NTP
    case $OS in
        ubuntu|debian)
            systemctl stop systemd-timesyncd || true
            apt-get install -y chrony
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y chrony
            ;;
    esac
    
    # Configure chrony
    cat > /etc/chrony.conf << EOF
# Use NTP servers
$(for server in $NTP_SERVERS; do echo "server $server iburst"; done)

# Allow NTP client access from local network
allow 192.168.0.0/16
allow 10.0.0.0/8
allow 172.16.0.0/12

# Record the rate at which the system clock gains/losses time
driftfile /var/lib/chrony/drift

# Enable kernel synchronization of the real-time clock
rtcsync

# Step the system clock instead of slewing it if the adjustment is larger than 1 second
makestep 1.0 3

# Disable chrony listening on the command port
cmdport 0
EOF
    
    systemctl enable chronyd
    systemctl restart chronyd
    
    # Verify time sync
    chrony sources -v
    log_success "NTP configured and synchronized"
}

# Disable swap
disable_swap() {
    log_info "Disabling swap..."
    
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    log_success "Swap disabled"
}

# Configure kernel modules
configure_kernel_modules() {
    log_info "Configuring kernel modules..."
    
    cat > /etc/modules-load.d/k8s.conf << EOF
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF
    
    # Load modules
    modprobe br_netfilter
    modprobe ip_vs
    modprobe ip_vs_rr
    modprobe ip_vs_wrr
    modprobe ip_vs_sh
    modprobe nf_conntrack
    
    # Make modules persistent
    echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.d/k8s.conf
    echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/k8s.conf
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/k8s.conf
    echo 'vm.swappiness = 0' >> /etc/sysctl.d/k8s.conf
    
    sysctl --system
    
    log_success "Kernel modules configured"
}

# Install container runtime
install_container_runtime() {
    log_info "Installing container runtime: $CONTAINER_RUNTIME"
    
    case $CONTAINER_RUNTIME in
        containerd)
            install_containerd
            ;;
        docker)
            install_docker
            ;;
        *)
            log_error "Unsupported container runtime: $CONTAINER_RUNTIME"
            exit 1
            ;;
    esac
}

install_containerd() {
    log_info "Installing containerd..."
    
    case $OS in
        ubuntu|debian)
            # Install containerd
            apt-get install -y containerd
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y containerd
            ;;
    esac
    
    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    
    # Use systemd cgroup driver
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    systemctl enable containerd
    systemctl restart containerd
    
    log_success "Containerd installed and configured"
}

install_docker() {
    log_info "Installing Docker..."
    
    case $OS in
        ubuntu|debian)
            # Add Docker repository
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            apt-get update -y
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        centos|rhel|rocky|almalinux)
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
    esac
    
    # Configure Docker
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
    
    systemctl enable docker
    systemctl restart docker
    
    log_success "Docker installed and configured"
}

# Install Kubernetes packages
install_kubernetes() {
    log_info "Installing Kubernetes packages..."
    
    case $OS in
        ubuntu|debian)
            # Add Kubernetes repository
            curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
            
            apt-get update -y
            apt-get install -y kubelet=${KUBERNETES_VERSION}-1.1 kubeadm=${KUBERNETES_VERSION}-1.1 kubectl=${KUBERNETES_VERSION}-1.1
            ;;
        centos|rhel|rocky|almalinux)
            # Add Kubernetes repository
            cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION%.*}/rpm/repodata/repomd.xml.key
EOF
            
            yum install -y kubelet-${KUBERNETES_VERSION}-1.1 kubeadm-${KUBERNETES_VERSION}-1.1 kubectl-${KUBERNETES_VERSION}-1.1
            ;;
    esac
    
    # Hold packages to prevent automatic updates
    case $OS in
        ubuntu|debian)
            apt-mark hold kubelet kubeadm kubectl
            ;;
        centos|rhel|rocky|almalinux)
            yum versionlock add kubelet kubeadm kubectl
            ;;
    esac
    
    systemctl enable kubelet
    
    log_success "Kubernetes packages installed"
}

# Configure firewall
configure_firewall() {
    log_info "Configuring firewall..."
    
    # Control plane ports
    CONTROL_PLANE_PORTS="6443 2379 2380 10250 10251 10252 10259 10257"
    # Worker ports
    WORKER_PORTS="10250 30000:32767"
    # Common ports
    COMMON_PORTS="22 80 443 53"
    
    case $OS in
        ubuntu|debian)
            # Install ufw if not present
            apt-get install -y ufw
            
            # Allow common ports
            for port in $COMMON_PORTS; do
                ufw allow $port
            done
            
            # Allow control plane ports
            for port in $CONTROL_PLANE_PORTS; do
                ufw allow $port
            done
            
            # Allow worker ports
            ufw allow 10250
            ufw allow 30000:32767/tcp
            
            # Enable firewall
            ufw --force enable
            ;;
        centos|rhel|rocky|almalinux)
            # Install firewalld if not present
            yum install -y firewalld
            systemctl enable firewalld
            systemctl start firewalld
            
            # Allow common ports
            for port in $COMMON_PORTS; do
                firewall-cmd --permanent --add-port=$port/tcp
            done
            
            # Allow control plane ports
            for port in $CONTROL_PLANE_PORTS; do
                firewall-cmd --permanent --add-port=$port/tcp
            done
            
            # Allow worker ports
            firewall-cmd --permanent --add-port=10250/tcp
            firewall-cmd --permanent --add-port=30000-32767/tcp
            
            # Reload firewall
            firewall-cmd --reload
            ;;
    esac
    
    log_success "Firewall configured"
}

# Prepare storage directories
prepare_storage() {
    log_info "Preparing storage directories..."
    
    # Create directories for local-path storage
    mkdir -p /opt/local-path-provisioner
    
    # Set permissions
    chmod 755 /opt/local-path-provisioner
    
    log_success "Storage directories prepared"
}

# Main execution
main() {
    log_info "Starting Kubernetes node preparation..."
    log_info "OS: $OS $OS_VERSION"
    log_info "Container Runtime: $CONTAINER_RUNTIME"
    log_info "Kubernetes Version: $KUBERNETES_VERSION"
    log_info "Timezone: $TIMEZONE"
    
    # Detect OS if not specified
    if [[ "$OS" == "ubuntu" && "$OS_VERSION" == "22.04" ]]; then
        detect_os
    fi
    
    # Execute preparation steps
    update_system
    configure_time
    disable_swap
    configure_kernel_modules
    install_container_runtime
    install_kubernetes
    configure_firewall
    prepare_storage
    
    log_success "Node preparation completed successfully!"
    log_info "Node is ready to join Kubernetes cluster"
}

# Parse arguments and run main
parse_args "$@"
main