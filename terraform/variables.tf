variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location"
  type        = string
  default     = "nbg1"
}

variable "server_image" {
  description = "Server image to use"
  type        = string
  default     = "ubuntu-22.04"
}

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "control_plane_server_type" {
  description = "Server type for control plane nodes"
  type        = string
  default     = "cx21"  # 2 vCPU, 4GB RAM
}

variable "worker_server_type" {
  description = "Server type for worker nodes"
  type        = string
  default     = "cx31"  # 2 vCPU, 8GB RAM
}

variable "additional_storage_size" {
  description = "Size of additional storage volume in GB"
  type        = number
  default     = 100
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "hetzner-k8s-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.28"
}

variable "pod_cidr" {
  description = "CIDR block for pods"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR block for services"
  type        = string
  default     = "10.96.0.0/12"
}

variable "rancher_password" {
  description = "Password for Rancher admin user"
  type        = string
  sensitive   = true
}

variable "grafana_password" {
  description = "Password for Grafana admin user"
  type        = string
  sensitive   = true
}

variable "acceldata_ssh_key" {
  description = "SSH public key for acceldata user"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDhA..."
}