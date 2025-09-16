output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value       = hcloud_server.control_plane[*].ipv4_address
}

output "worker_node_ips" {
  description = "IP addresses of worker nodes"
  value       = hcloud_server.worker_nodes[*].ipv4_address
}

output "control_plane_private_ips" {
  description = "Private IP addresses of control plane nodes"
  value       = hcloud_server.control_plane[*].network[0].ip
}

output "worker_node_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = hcloud_server.worker_nodes[*].network[0].ip
}

output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = hcloud_load_balancer.k8s_api.ipv4
}

output "network_id" {
  description = "ID of the private network"
  value       = hcloud_network.k8s_network.id
}

output "network_cidr" {
  description = "CIDR block of the private network"
  value       = hcloud_network.k8s_network.ip_range
}

output "ssh_key_id" {
  description = "ID of the SSH key"
  value       = hcloud_ssh_key.k8s_cluster_key.id
}

output "server_inventory" {
  description = "Ansible inventory for all servers"
  value = {
    control_plane = [
      for i, server in hcloud_server.control_plane : {
        name = server.name
        ip   = server.ipv4_address
        private_ip = server.network[0].ip
        role = "control-plane"
      }
    ]
    workers = [
      for i, server in hcloud_server.worker_nodes : {
        name = server.name
        ip   = server.ipv4_address
        private_ip = server.network[0].ip
        role = "worker"
      }
    ]
  }
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig"
  value       = "kubectl config set-cluster ${var.cluster_name} --server=https://${hcloud_load_balancer.k8s_api.ipv4}:6443 --certificate-authority=/etc/kubernetes/pki/ca.crt"
}

output "rancher_url" {
  description = "URL to access Rancher UI"
  value       = "https://${hcloud_load_balancer.k8s_api.ipv4}/rancher"
}

output "grafana_url" {
  description = "URL to access Grafana dashboard"
  value       = "https://${hcloud_load_balancer.k8s_api.ipv4}/grafana"
}