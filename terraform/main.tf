terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Create SSH key for cluster access
resource "hcloud_ssh_key" "k8s_cluster_key" {
  name       = "k8s-cluster-key"
  public_key = var.ssh_public_key
}

# Create private network for cluster communication
resource "hcloud_network" "k8s_network" {
  name     = "k8s-cluster-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k8s_subnet" {
  network_id   = hcloud_network.k8s_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# Create placement group for HA nodes
resource "hcloud_placement_group" "k8s_nodes" {
  name = "k8s-nodes"
  type = "spread"
}

# Kubernetes Nodes (Hybrid Control Plane + Worker)
resource "hcloud_server" "k8s_nodes" {
  count              = var.node_count
  name               = "k8s-node-${count.index + 1}"
  image              = var.server_image
  server_type        = var.node_server_type
  location           = var.location
  ssh_keys           = [hcloud_ssh_key.k8s_cluster_key.id]
  placement_group_id = hcloud_placement_group.k8s_nodes.id
  
  network {
    network_id = hcloud_network.k8s_network.id
    ip         = "10.0.1.${10 + count.index}"
  }

  labels = {
    role = "hybrid"
    node = "k8s-node-${count.index + 1}"
    control-plane = count.index < 3 ? "true" : "false"  # First 3 nodes are control plane
    worker = "true"  # All nodes are workers
  }

  depends_on = [hcloud_network_subnet.k8s_subnet]
}

# Additional storage volumes for persistent data
resource "hcloud_volume" "node_storage" {
  count    = var.node_count
  name     = "k8s-node-storage-${count.index + 1}"
  size     = var.additional_storage_size
  location = var.location
}

resource "hcloud_volume_attachment" "node_storage" {
  count     = var.node_count
  volume_id = hcloud_volume.node_storage[count.index].id
  server_id = hcloud_server.k8s_nodes[count.index].id
  automount = true
}

# Load balancer for API server
resource "hcloud_load_balancer" "k8s_api" {
  name               = "k8s-api-lb"
  load_balancer_type = "lb11"
  location           = var.location
  network_zone       = "eu-central"
}

resource "hcloud_load_balancer_network" "k8s_api" {
  load_balancer_id = hcloud_load_balancer.k8s_api.id
  network_id       = hcloud_network.k8s_network.id
}

resource "hcloud_load_balancer_target" "k8s_api" {
  count            = 3  # First 3 nodes are control plane
  type             = "server"
  load_balancer_id = hcloud_load_balancer.k8s_api.id
  server_id        = hcloud_server.k8s_nodes[count.index].id
}

resource "hcloud_load_balancer_service" "k8s_api" {
  load_balancer_id = hcloud_load_balancer.k8s_api.id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443
}

# Firewall rules
resource "hcloud_firewall" "k8s_firewall" {
  name = "k8s-cluster-firewall"

  rule {
    direction = "in"
    port      = "22"
    protocol  = "tcp"
    source_ips = ["0.0.0.0/0"]
  }

  rule {
    direction = "in"
    port      = "6443"
    protocol  = "tcp"
    source_ips = ["0.0.0.0/0"]
  }

  rule {
    direction = "in"
    port      = "2379-2380"
    protocol  = "tcp"
    source_ips = [hcloud_network.k8s_network.ip_range]
  }

  rule {
    direction = "in"
    port      = "10250"
    protocol  = "tcp"
    source_ips = [hcloud_network.k8s_network.ip_range]
  }

  rule {
    direction = "in"
    port      = "10251"
    protocol  = "tcp"
    source_ips = [hcloud_network.k8s_network.ip_range]
  }

  rule {
    direction = "in"
    port      = "10252"
    protocol  = "tcp"
    source_ips = [hcloud_network.k8s_network.ip_range]
  }

  rule {
    direction = "in"
    port      = "30000-32767"
    protocol  = "tcp"
    source_ips = ["0.0.0.0/0"]
  }
}

# Attach firewall to all servers
resource "hcloud_firewall_attachment" "k8s_nodes" {
  count        = var.node_count
  firewall_id  = hcloud_firewall.k8s_firewall.id
  resource_ids = [hcloud_server.k8s_nodes[count.index].id]
  resource_type = "server"
}