#!/bin/bash

# Generate Ansible inventory from Terraform output
# This script creates the inventory file dynamically based on the number of nodes

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if terraform output exists
if [ ! -f "terraform/terraform.tfstate" ]; then
    print_warning "Terraform state not found. Please run 'terraform apply' first."
    exit 1
fi

# Get node count from terraform
NODE_COUNT=$(cd terraform && terraform output -raw node_count 2>/dev/null || echo "3")

print_status "Generating inventory for $NODE_COUNT nodes..."

# Create inventory file
cat > ansible/inventory/hosts.yml << EOF
all:
  children:
    k8s_nodes:
      hosts:
EOF

# Add nodes dynamically
for i in $(seq 1 $NODE_COUNT); do
    NODE_IP=$(cd terraform && terraform output -json node_ips | jq -r ".[$((i-1))]" 2>/dev/null || echo "NODE_IP_$i")
    NODE_PRIVATE_IP=$(cd terraform && terraform output -json node_private_ips | jq -r ".[$((i-1))]" 2>/dev/null || echo "NODE_PRIVATE_IP_$i")
    
    cat >> ansible/inventory/hosts.yml << EOF
        k8s-node-$i:
          ansible_host: "$NODE_IP"
          ansible_user: root
          node_ip: "$NODE_PRIVATE_IP"
          node_role: hybrid
          control_plane: $([ $i -le 3 ] && echo "true" || echo "false")
          worker: true
          node_index: $i
EOF
done

# Add remaining configuration
cat >> ansible/inventory/hosts.yml << EOF
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    
    control_plane:
      hosts:
EOF

# Add control plane nodes (first 3)
for i in $(seq 1 $((NODE_COUNT < 3 ? NODE_COUNT : 3))); do
    echo "        k8s-node-$i:" >> ansible/inventory/hosts.yml
done

cat >> ansible/inventory/hosts.yml << EOF
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    
    workers:
      hosts:
EOF

# Add all nodes as workers
for i in $(seq 1 $NODE_COUNT); do
    echo "        k8s-node-$i:" >> ansible/inventory/hosts.yml
done

cat >> ansible/inventory/hosts.yml << EOF
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    
    k8s_cluster:
      children:
        k8s_nodes:
      vars:
        # Cluster configuration
        cluster_name: "hetzner-k8s-cluster"
        kubernetes_version: "1.28"
        pod_cidr: "10.244.0.0/16"
        service_cidr: "10.96.0.0/12"
        
        # Load balancer configuration
        api_server_lb_ip: "$(cd terraform && terraform output -raw load_balancer_ip 2>/dev/null || echo "LOAD_BALANCER_IP")"
        
        # Container runtime
        container_runtime: containerd
        
        # CNI plugin
        cni_plugin: flannel
        
        # Storage configuration
        storage_class: local-path
        
        # Monitoring
        enable_monitoring: true
        
        # Rancher configuration
        rancher_password: "SecureRancherPassword123!"
        
        # Default user configuration
        acceldata_ssh_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhA... acceldata@cluster"
EOF

print_status "Inventory generated successfully!"
print_status "File: ansible/inventory/hosts.yml"
print_status "Nodes: $NODE_COUNT"
print_status "Control plane nodes: $((NODE_COUNT < 3 ? NODE_COUNT : 3))"
print_status "Worker nodes: $NODE_COUNT"

# Display the generated inventory
echo ""
print_status "Generated inventory preview:"
echo "================================"
head -20 ansible/inventory/hosts.yml
echo "..."
echo "================================"