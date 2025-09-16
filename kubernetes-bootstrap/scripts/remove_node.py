#!/usr/bin/env python3
"""
Remove Node from Kubernetes Cluster Script
Safely removes a node from an existing Kubernetes cluster
"""

import argparse
import subprocess
import sys
import time
import yaml
from pathlib import Path
from typing import Dict, Any, List
import json

from inventory_parser import InventoryParser


class NodeRemover:
    """Class for removing nodes from Kubernetes cluster"""
    
    def __init__(self, inventory_file: str, master_node: str):
        self.inventory_file = inventory_file
        self.master_node = master_node
        self.inventory = InventoryParser(inventory_file)
        self.nodes = self.inventory.get_all_nodes()
        
        # Find master node info
        self.master_info = None
        for node in self.nodes:
            if node['hostname'] == master_node or node['ip_address'] == master_node:
                self.master_info = node
                break
        
        if not self.master_info:
            raise ValueError(f"Master node not found: {master_node}")
    
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
    
    def get_node_info(self, node_identifier: str) -> Dict[str, Any]:
        """Get node information from cluster"""
        print(f"Getting information for node: {node_identifier}")
        
        # Try to get node info from kubectl
        cmd = f"kubectl get nodes {node_identifier} -o json"
        returncode, stdout, stderr = self.run_ssh_command(self.master_info, cmd)
        
        if returncode != 0:
            print(f"Node {node_identifier} not found in cluster: {stderr}")
            return None
        
        try:
            node_info = json.loads(stdout)
            return node_info
        except json.JSONDecodeError:
            print(f"Failed to parse node information: {stdout}")
            return None
    
    def drain_node(self, node_identifier: str, force: bool = False) -> bool:
        """Drain pods from the node"""
        print(f"Draining node: {node_identifier}")
        
        # Check if node exists
        node_info = self.get_node_info(node_identifier)
        if not node_info:
            return False
        
        # Build drain command
        drain_cmd = f"kubectl drain {node_identifier}"
        
        # Add options based on node type
        if node_info.get('spec', {}).get('unschedulable') is None:
            drain_cmd += " --ignore-daemonsets"
        
        if force:
            drain_cmd += " --force --grace-period=0"
        
        drain_cmd += " --delete-emptydir-data"
        
        print(f"Running drain command: {drain_cmd}")
        returncode, stdout, stderr = self.run_ssh_command(self.master_info, drain_cmd, timeout=600)
        
        if returncode != 0:
            print(f"Failed to drain node {node_identifier}: {stderr}")
            if not force:
                print("Use --force to force drain even if there are errors")
            return False
        
        print(f"Successfully drained node: {node_identifier}")
        return True
    
    def delete_node(self, node_identifier: str) -> bool:
        """Delete node from cluster"""
        print(f"Deleting node from cluster: {node_identifier}")
        
        cmd = f"kubectl delete node {node_identifier}"
        returncode, stdout, stderr = self.run_ssh_command(self.master_info, cmd)
        
        if returncode != 0:
            print(f"Failed to delete node {node_identifier}: {stderr}")
            return False
        
        print(f"Successfully deleted node from cluster: {node_identifier}")
        return True
    
    def reset_node(self, node_info: Dict[str, Any]) -> bool:
        """Reset node (remove Kubernetes components)"""
        print(f"Resetting node: {node_info['hostname']}")
        
        # Run kubeadm reset
        reset_cmd = "kubeadm reset --force"
        returncode, stdout, stderr = self.run_ssh_command(node_info, reset_cmd, timeout=300)
        
        if returncode != 0:
            print(f"Failed to reset node {node_info['hostname']}: {stderr}")
            return False
        
        # Clean up iptables rules
        cleanup_cmd = "iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X"
        returncode, stdout, stderr = self.run_ssh_command(node_info, cleanup_cmd)
        
        # Clean up network interfaces
        network_cmd = "ip link delete cni0 2>/dev/null || true && ip link delete flannel.1 2>/dev/null || true"
        returncode, stdout, stderr = self.run_ssh_command(node_info, network_cmd)
        
        # Clean up directories
        cleanup_dirs_cmd = "rm -rf /var/lib/cni /var/lib/kubelet /etc/cni /etc/kubernetes"
        returncode, stdout, stderr = self.run_ssh_command(node_info, cleanup_dirs_cmd)
        
        print(f"Successfully reset node: {node_info['hostname']}")
        return True
    
    def remove_node(self, node_identifier: str, force: bool = False, reset: bool = True) -> bool:
        """Remove a node from the cluster"""
        print(f"Removing node: {node_identifier}")
        
        # Get node info from inventory
        node_info = None
        for node in self.nodes:
            if node['hostname'] == node_identifier or node['ip_address'] == node_identifier:
                node_info = node
                break
        
        if not node_info:
            print(f"Node {node_identifier} not found in inventory")
            return False
        
        # Step 1: Drain the node
        if not self.drain_node(node_identifier, force):
            if not force:
                print("Drain failed. Use --force to continue anyway.")
                return False
        
        # Step 2: Delete node from cluster
        if not self.delete_node(node_identifier):
            return False
        
        # Step 3: Reset node (optional)
        if reset:
            if not self.reset_node(node_info):
                print(f"Warning: Failed to reset node {node_info['hostname']}")
        
        print(f"Successfully removed node: {node_identifier}")
        return True
    
    def list_nodes(self) -> List[str]:
        """List all nodes in the cluster"""
        print("Listing cluster nodes...")
        
        cmd = "kubectl get nodes -o jsonpath='{.items[*].metadata.name}'"
        returncode, stdout, stderr = self.run_ssh_command(self.master_info, cmd)
        
        if returncode != 0:
            print(f"Failed to list nodes: {stderr}")
            return []
        
        nodes = stdout.strip().split()
        print(f"Found {len(nodes)} nodes in cluster:")
        for node in nodes:
            print(f"  - {node}")
        
        return nodes
    
    def get_node_status(self, node_identifier: str) -> Dict[str, Any]:
        """Get detailed status of a node"""
        print(f"Getting status for node: {node_identifier}")
        
        cmd = f"kubectl describe node {node_identifier}"
        returncode, stdout, stderr = self.run_ssh_command(self.master_info, cmd)
        
        if returncode != 0:
            print(f"Failed to get node status: {stderr}")
            return None
        
        print(stdout)
        return {'output': stdout}


def main():
    """CLI interface"""
    parser = argparse.ArgumentParser(description='Remove node(s) from Kubernetes cluster')
    parser.add_argument('inventory_file', help='Path to inventory file')
    parser.add_argument('master_node', help='Master node hostname or IP')
    parser.add_argument('--node', help='Node hostname or IP to remove')
    parser.add_argument('--force', action='store_true',
                       help='Force removal even if drain fails')
    parser.add_argument('--no-reset', action='store_true',
                       help='Do not reset the node after removal')
    parser.add_argument('--list', action='store_true',
                       help='List all nodes in cluster')
    parser.add_argument('--status', help='Get status of specific node')
    
    args = parser.parse_args()
    
    try:
        remover = NodeRemover(args.inventory_file, args.master_node)
        
        if args.list:
            remover.list_nodes()
            return
        
        if args.status:
            remover.get_node_status(args.status)
            return
        
        if not args.node:
            print("Please specify --node to remove, or use --list to see available nodes")
            sys.exit(1)
        
        success = remover.remove_node(
            args.node, 
            force=args.force, 
            reset=not args.no_reset
        )
        
        sys.exit(0 if success else 1)
    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()