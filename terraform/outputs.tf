output "node_ips" {
  description = "IP addresses of all Kubernetes nodes"
  value       = hcloud_server.k8s_nodes[*].ipv4_address
}

output "node_private_ips" {
  description = "Private IP addresses of all Kubernetes nodes"
  value       = hcloud_server.k8s_nodes[*].network[0].ip
}

output "control_plane_ips" {
  description = "IP addresses of control plane nodes (first 3 nodes)"
  value       = slice(hcloud_server.k8s_nodes[*].ipv4_address, 0, 3)
}

output "control_plane_private_ips" {
  description = "Private IP addresses of control plane nodes (first 3 nodes)"
  value       = slice(hcloud_server.k8s_nodes[*].network[0].ip, 0, 3)
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
    nodes = [
      for i, server in hcloud_server.k8s_nodes : {
        name = server.name
        ip   = server.ipv4_address
        private_ip = server.network[0].ip
        role = "hybrid"
        control_plane = i < 3 ? "true" : "false"
        worker = "true"
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