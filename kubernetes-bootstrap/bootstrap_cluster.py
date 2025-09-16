#!/usr/bin/env python3
"""
Kubernetes Cluster Bootstrap Script
Automated setup of HA Kubernetes cluster from inventory file
"""

import argparse
import json
import subprocess
import sys
import time
import yaml
from pathlib import Path
from typing import List, Dict, Any
import concurrent.futures
import threading

from inventory_parser import InventoryParser


class KubernetesBootstrap:
    """Main class for Kubernetes cluster bootstrap"""
    
    def __init__(self, inventory_file: str, config_file: str = None):
        self.inventory_file = inventory_file
        self.config_file = config_file
        self.inventory = InventoryParser(inventory_file)
        self.nodes = self.inventory.get_all_nodes()
        self.control_plane_nodes = self.inventory.get_control_plane_nodes(3)
        self.worker_nodes = self.inventory.get_worker_nodes(3)
        self.cluster_config = self._load_cluster_config()
        self.lock = threading.Lock()
        
    def _load_cluster_config(self) -> Dict[str, Any]:
        """Load cluster configuration"""
        default_config = {
            'kubernetes_version': '1.28.0',
            'pod_network_cidr': '10.244.0.0/16',
            'service_cidr': '10.96.0.0/12',
            'container_runtime': 'containerd',
            'cni_plugin': 'flannel',
            'storage_class': 'local-path',
            'timezone': 'UTC',
            'ntp_servers': ['pool.ntp.org', 'time.google.com'],
            'firewall_rules': {
                'control_plane_ports': [6443, 2379, 2380, 10250, 10251, 10252, 10259, 10257],
                'worker_ports': [10250, 30000, 32767],
                'common_ports': [22, 80, 443, 53]
            }
        }
        
        if self.config_file and Path(self.config_file).exists():
            with open(self.config_file, 'r') as f:
                user_config = yaml.safe_load(f)
                default_config.update(user_config)
        
        return default_config
    
    def run_ssh_command(self, host: Dict[str, Any], command: str, timeout: int = 300) -> tuple:
        """Run SSH command on remote host"""
        ssh_cmd = [
            'ssh', '-o', 'StrictHostKeyChecking=no',
            '-o', 'UserKnownHostsFile=/dev/null',
            '-o', 'ConnectTimeout=10',
            '-p', str(host['ssh_port']),
            f"{host['username']}@{host['ip_address']}",
            command
        ]
        
        try:
            result = subprocess.run(
                ssh_cmd, 
                capture_output=True, 
                text=True, 
                timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Command timed out"
        except Exception as e:
            return -1, "", str(e)
    
    def copy_file_to_host(self, host: Dict[str, Any], local_file: str, remote_path: str) -> bool:
        """Copy file to remote host using scp"""
        scp_cmd = [
            'scp', '-o', 'StrictHostKeyChecking=no',
            '-o', 'UserKnownHostsFile=/dev/null',
            '-P', str(host['ssh_port']),
            local_file,
            f"{host['username']}@{host['ip_address']}:{remote_path}"
        ]
        
        try:
            result = subprocess.run(scp_cmd, capture_output=True, text=True)
            return result.returncode == 0
        except Exception as e:
            print(f"Error copying file to {host['hostname']}: {e}")
            return False
    
    def prepare_node(self, host: Dict[str, Any]) -> bool:
        """Prepare a single node for Kubernetes"""
        print(f"Preparing node: {host['hostname']}")
        
        # Copy node preparation script
        if not self.copy_file_to_host(host, 'scripts/prepare_node.sh', '/tmp/prepare_node.sh'):
            print(f"Failed to copy preparation script to {host['hostname']}")
            return False
        
        # Make script executable and run it
        commands = [
            'chmod +x /tmp/prepare_node.sh',
            f'/tmp/prepare_node.sh --os {host["os"]} --version {host["os_version"]} --timezone {self.cluster_config["timezone"]}'
        ]
        
        for cmd in commands:
            returncode, stdout, stderr = self.run_ssh_command(host, cmd, timeout=600)
            if returncode != 0:
                print(f"Error on {host['hostname']}: {stderr}")
                return False
        
        print(f"Successfully prepared node: {host['hostname']}")
        return True
    
    def prepare_all_nodes(self) -> bool:
        """Prepare all nodes in parallel"""
        print("Preparing all nodes...")
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            future_to_host = {
                executor.submit(self.prepare_node, host): host 
                for host in self.nodes
            }
            
            results = []
            for future in concurrent.futures.as_completed(future_to_host):
                host = future_to_host[future]
                try:
                    success = future.result()
                    results.append(success)
                    if not success:
                        print(f"Failed to prepare {host['hostname']}")
                except Exception as e:
                    print(f"Exception preparing {host['hostname']}: {e}")
                    results.append(False)
        
        return all(results)
    
    def initialize_control_plane(self) -> bool:
        """Initialize the first control plane node"""
        master_node = self.control_plane_nodes[0]
        print(f"Initializing control plane on {master_node['hostname']}")
        
        # Generate kubeadm config
        kubeadm_config = self._generate_kubeadm_config()
        
        # Copy config to master node
        config_file = '/tmp/kubeadm-config.yaml'
        with open(config_file, 'w') as f:
            yaml.dump(kubeadm_config, f)
        
        if not self.copy_file_to_host(master_node, config_file, '/tmp/kubeadm-config.yaml'):
            return False
        
        # Initialize cluster
        init_cmd = 'kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs'
        returncode, stdout, stderr = self.run_ssh_command(master_node, init_cmd, timeout=900)
        
        if returncode != 0:
            print(f"Failed to initialize control plane: {stderr}")
            return False
        
        # Extract join commands
        self._extract_join_commands(stdout)
        
        print(f"Successfully initialized control plane on {master_node['hostname']}")
        return True
    
    def _generate_kubeadm_config(self) -> Dict[str, Any]:
        """Generate kubeadm configuration"""
        config = {
            'apiVersion': 'kubeadm.k8s.io/v1beta3',
            'kind': 'InitConfiguration',
            'localAPIEndpoint': {
                'advertiseAddress': self.control_plane_nodes[0]['ip_address'],
                'bindPort': 6443
            },
            'nodeRegistration': {
                'kubeletExtraArgs': {
                    'cgroup-driver': 'systemd'
                }
            }
        }
        
        cluster_config = {
            'apiVersion': 'kubeadm.k8s.io/v1beta3',
            'kind': 'ClusterConfiguration',
            'kubernetesVersion': self.cluster_config['kubernetes_version'],
            'controlPlaneEndpoint': f"{self.control_plane_nodes[0]['ip_address']}:6443",
            'networking': {
                'podSubnet': self.cluster_config['pod_network_cidr'],
                'serviceSubnet': self.cluster_config['service_cidr']
            },
            'etcd': {
                'local': {
                    'dataDir': '/var/lib/etcd'
                }
            }
        }
        
        return {**config, **cluster_config}
    
    def _extract_join_commands(self, init_output: str):
        """Extract join commands from kubeadm init output"""
        lines = init_output.split('\n')
        self.control_plane_join_cmd = None
        self.worker_join_cmd = None
        
        for line in lines:
            if 'kubeadm join' in line and '--control-plane' in line:
                self.control_plane_join_cmd = line.strip()
            elif 'kubeadm join' in line and '--control-plane' not in line:
                self.worker_join_cmd = line.strip()
    
    def join_control_plane_nodes(self) -> bool:
        """Join remaining control plane nodes"""
        if len(self.control_plane_nodes) <= 1:
            return True
        
        print("Joining additional control plane nodes...")
        
        for node in self.control_plane_nodes[1:]:
            print(f"Joining control plane node: {node['hostname']}")
            
            returncode, stdout, stderr = self.run_ssh_command(
                node, 
                self.control_plane_join_cmd, 
                timeout=600
            )
            
            if returncode != 0:
                print(f"Failed to join control plane node {node['hostname']}: {stderr}")
                return False
            
            print(f"Successfully joined control plane node: {node['hostname']}")
        
        return True
    
    def join_worker_nodes(self) -> bool:
        """Join worker nodes"""
        if not self.worker_nodes:
            return True
        
        print("Joining worker nodes...")
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            future_to_host = {
                executor.submit(self._join_worker_node, host): host 
                for host in self.worker_nodes
            }
            
            results = []
            for future in concurrent.futures.as_completed(future_to_host):
                host = future_to_host[future]
                try:
                    success = future.result()
                    results.append(success)
                    if not success:
                        print(f"Failed to join worker node {host['hostname']}")
                except Exception as e:
                    print(f"Exception joining worker node {host['hostname']}: {e}")
                    results.append(False)
        
        return all(results)
    
    def _join_worker_node(self, host: Dict[str, Any]) -> bool:
        """Join a single worker node"""
        print(f"Joining worker node: {host['hostname']}")
        
        returncode, stdout, stderr = self.run_ssh_command(
            host, 
            self.worker_join_cmd, 
            timeout=600
        )
        
        if returncode != 0:
            print(f"Failed to join worker node {host['hostname']}: {stderr}")
            return False
        
        print(f"Successfully joined worker node: {host['hostname']}")
        return True
    
    def setup_networking(self) -> bool:
        """Setup CNI networking"""
        master_node = self.control_plane_nodes[0]
        print("Setting up CNI networking...")
        
        # Install Flannel
        flannel_cmd = f"kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
        returncode, stdout, stderr = self.run_ssh_command(master_node, flannel_cmd)
        
        if returncode != 0:
            print(f"Failed to install Flannel: {stderr}")
            return False
        
        print("Successfully installed Flannel CNI")
        return True
    
    def setup_storage(self) -> bool:
        """Setup local-path storage class"""
        master_node = self.control_plane_nodes[0]
        print("Setting up local-path storage...")
        
        # Install local-path-provisioner
        storage_cmd = "kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
        returncode, stdout, stderr = self.run_ssh_command(master_node, storage_cmd)
        
        if returncode != 0:
            print(f"Failed to install local-path storage: {stderr}")
            return False
        
        # Set as default storage class
        default_cmd = "kubectl patch storageclass local-path -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
        returncode, stdout, stderr = self.run_ssh_command(master_node, default_cmd)
        
        if returncode != 0:
            print(f"Failed to set default storage class: {stderr}")
            return False
        
        print("Successfully setup local-path storage")
        return True
    
    def verify_cluster(self) -> bool:
        """Verify cluster is working properly"""
        master_node = self.control_plane_nodes[0]
        print("Verifying cluster...")
        
        # Check node status
        nodes_cmd = "kubectl get nodes -o wide"
        returncode, stdout, stderr = self.run_ssh_command(master_node, nodes_cmd)
        
        if returncode != 0:
            print(f"Failed to get nodes: {stderr}")
            return False
        
        print("Cluster nodes:")
        print(stdout)
        
        # Check pod status
        pods_cmd = "kubectl get pods --all-namespaces"
        returncode, stdout, stderr = self.run_ssh_command(master_node, pods_cmd)
        
        if returncode != 0:
            print(f"Failed to get pods: {stderr}")
            return False
        
        print("Cluster pods:")
        print(stdout)
        
        return True
    
    def bootstrap_cluster(self) -> bool:
        """Main bootstrap process"""
        print("Starting Kubernetes cluster bootstrap...")
        print(f"Control plane nodes: {len(self.control_plane_nodes)}")
        print(f"Worker nodes: {len(self.worker_nodes)}")
        
        steps = [
            ("Preparing all nodes", self.prepare_all_nodes),
            ("Initializing control plane", self.initialize_control_plane),
            ("Joining control plane nodes", self.join_control_plane_nodes),
            ("Joining worker nodes", self.join_worker_nodes),
            ("Setting up networking", self.setup_networking),
            ("Setting up storage", self.setup_storage),
            ("Verifying cluster", self.verify_cluster)
        ]
        
        for step_name, step_func in steps:
            print(f"\n--- {step_name} ---")
            if not step_func():
                print(f"Bootstrap failed at: {step_name}")
                return False
        
        print("\n🎉 Kubernetes cluster bootstrap completed successfully!")
        print(f"Cluster has {len(self.control_plane_nodes)} control plane nodes and {len(self.worker_nodes)} worker nodes")
        
        return True


def main():
    """CLI interface"""
    parser = argparse.ArgumentParser(description='Bootstrap Kubernetes cluster')
    parser.add_argument('inventory_file', help='Path to inventory file')
    parser.add_argument('--config', help='Path to cluster configuration file')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without executing')
    
    args = parser.parse_args()
    
    try:
        bootstrap = KubernetesBootstrap(args.inventory_file, args.config)
        
        if args.dry_run:
            print("Dry run mode - showing cluster configuration:")
            print(f"Control plane nodes: {len(bootstrap.control_plane_nodes)}")
            print(f"Worker nodes: {len(bootstrap.worker_nodes)}")
            print(f"Kubernetes version: {bootstrap.cluster_config['kubernetes_version']}")
            print(f"Pod network CIDR: {bootstrap.cluster_config['pod_network_cidr']}")
            return
        
        success = bootstrap.bootstrap_cluster()
        sys.exit(0 if success else 1)
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()