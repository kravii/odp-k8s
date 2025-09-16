#!/usr/bin/env python3
"""
Add Node to Kubernetes Cluster Script
Adds a new node to an existing Kubernetes cluster
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


class NodeAdder:
    """Class for adding nodes to Kubernetes cluster"""
    
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
    
    def get_join_token(self) -> str:
        """Get join token from master node"""
        print("Getting join token from master node...")
        
        # Get control plane join command
        cmd = "kubeadm token create --print-join-command"
        returncode, stdout, stderr = self.run_ssh_command(self.master_info, cmd)
        
        if returncode != 0:
            print(f"Failed to get join token: {stderr}")
            return None
        
        return stdout.strip()
    
    def get_control_plane_join_command(self) -> str:
        """Get control plane join command"""
        print("Getting control plane join command...")
        
        # Get control plane join command with certificate key
        cmd = "kubeadm init phase upload-certs --upload-certs --print-join-command"
        returncode, stdout, stderr = self.run_ssh_command(self.master_info, cmd)
        
        if returncode != 0:
            print(f"Failed to get control plane join command: {stderr}")
            return None
        
        return stdout.strip()
    
    def prepare_new_node(self, node_info: Dict[str, Any]) -> bool:
        """Prepare a new node for joining the cluster"""
        print(f"Preparing new node: {node_info['hostname']}")
        
        # Copy node preparation script
        script_path = Path(__file__).parent / 'prepare_node.sh'
        if not self.copy_file_to_host(node_info, str(script_path), '/tmp/prepare_node.sh'):
            print(f"Failed to copy preparation script to {node_info['hostname']}")
            return False
        
        # Make script executable and run it
        commands = [
            'chmod +x /tmp/prepare_node.sh',
            f'/tmp/prepare_node.sh --os {node_info["os"]} --version {node_info["os_version"]}'
        ]
        
        for cmd in commands:
            returncode, stdout, stderr = self.run_ssh_command(node_info, cmd, timeout=600)
            if returncode != 0:
                print(f"Error on {node_info['hostname']}: {stderr}")
                return False
        
        print(f"Successfully prepared node: {node_info['hostname']}")
        return True
    
    def join_worker_node(self, node_info: Dict[str, Any], join_command: str) -> bool:
        """Join a worker node to the cluster"""
        print(f"Joining worker node: {node_info['hostname']}")
        
        returncode, stdout, stderr = self.run_ssh_command(node_info, join_command, timeout=600)
        
        if returncode != 0:
            print(f"Failed to join worker node {node_info['hostname']}: {stderr}")
            return False
        
        print(f"Successfully joined worker node: {node_info['hostname']}")
        return True
    
    def join_control_plane_node(self, node_info: Dict[str, Any], join_command: str) -> bool:
        """Join a control plane node to the cluster"""
        print(f"Joining control plane node: {node_info['hostname']}")
        
        returncode, stdout, stderr = self.run_ssh_command(node_info, join_command, timeout=600)
        
        if returncode != 0:
            print(f"Failed to join control plane node {node_info['hostname']}: {stderr}")
            return False
        
        print(f"Successfully joined control plane node: {node_info['hostname']}")
        return True
    
    def verify_node_joined(self, node_info: Dict[str, Any]) -> bool:
        """Verify that the node has successfully joined the cluster"""
        print(f"Verifying node {node_info['hostname']} has joined...")
        
        # Check if node appears in kubectl get nodes
        cmd = f"kubectl get nodes | grep {node_info['hostname']}"
        returncode, stdout, stderr = self.run_ssh_command(self.master_info, cmd)
        
        if returncode != 0:
            print(f"Node {node_info['hostname']} not found in cluster")
            return False
        
        # Check if node is Ready
        cmd = f"kubectl get nodes {node_info['hostname']} -o jsonpath='{{.status.conditions[?(@.type==\"Ready\")].status}}'"
        returncode, stdout, stderr = self.run_ssh_command(self.master_info, cmd)
        
        if returncode != 0 or stdout.strip() != "True":
            print(f"Node {node_info['hostname']} is not Ready")
            return False
        
        print(f"Node {node_info['hostname']} successfully joined and is Ready")
        return True
    
    def add_node(self, node_info: Dict[str, Any], node_type: str = 'worker') -> bool:
        """Add a single node to the cluster"""
        print(f"Adding {node_type} node: {node_info['hostname']}")
        
        # Prepare the node
        if not self.prepare_new_node(node_info):
            return False
        
        # Get appropriate join command
        if node_type == 'control-plane':
            join_command = self.get_control_plane_join_command()
        else:
            join_command = self.get_join_token()
        
        if not join_command:
            return False
        
        # Join the node
        if node_type == 'control-plane':
            success = self.join_control_plane_node(node_info, join_command)
        else:
            success = self.join_worker_node(node_info, join_command)
        
        if not success:
            return False
        
        # Wait a bit for node to register
        time.sleep(30)
        
        # Verify the node joined
        return self.verify_node_joined(node_info)
    
    def add_nodes_from_inventory(self, new_nodes: List[Dict[str, Any]], node_type: str = 'worker') -> bool:
        """Add multiple nodes from inventory"""
        print(f"Adding {len(new_nodes)} {node_type} nodes...")
        
        # Get join command once
        if node_type == 'control-plane':
            join_command = self.get_control_plane_join_command()
        else:
            join_command = self.get_join_token()
        
        if not join_command:
            return False
        
        success_count = 0
        for node_info in new_nodes:
            if self.add_node(node_info, node_type):
                success_count += 1
            else:
                print(f"Failed to add node: {node_info['hostname']}")
        
        print(f"Successfully added {success_count}/{len(new_nodes)} nodes")
        return success_count == len(new_nodes)


def main():
    """CLI interface"""
    parser = argparse.ArgumentParser(description='Add node(s) to Kubernetes cluster')
    parser.add_argument('inventory_file', help='Path to inventory file')
    parser.add_argument('master_node', help='Master node hostname or IP')
    parser.add_argument('--node-type', choices=['worker', 'control-plane'], default='worker',
                       help='Type of node to add')
    parser.add_argument('--hostname', help='Specific hostname to add (from inventory)')
    parser.add_argument('--ip', help='Specific IP address to add')
    parser.add_argument('--all-new', action='store_true',
                       help='Add all nodes from inventory that are not in cluster')
    
    args = parser.parse_args()
    
    try:
        adder = NodeAdder(args.inventory_file, args.master_node)
        
        if args.hostname or args.ip:
            # Add specific node
            target_node = None
            for node in adder.nodes:
                if (args.hostname and node['hostname'] == args.hostname) or \
                   (args.ip and node['ip_address'] == args.ip):
                    target_node = node
                    break
            
            if not target_node:
                print(f"Node not found in inventory: {args.hostname or args.ip}")
                sys.exit(1)
            
            success = adder.add_node(target_node, args.node_type)
            sys.exit(0 if success else 1)
        
        elif args.all_new:
            # Add all nodes not currently in cluster
            # This would require checking which nodes are already in the cluster
            print("Adding all new nodes from inventory...")
            # For now, add all nodes from inventory
            success = adder.add_nodes_from_inventory(adder.nodes, args.node_type)
            sys.exit(0 if success else 1)
        
        else:
            print("Please specify --hostname, --ip, or --all-new")
            sys.exit(1)
    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()