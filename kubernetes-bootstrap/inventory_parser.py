#!/usr/bin/env python3
"""
Host Inventory Parser for Kubernetes Cluster Bootstrap
Supports YAML, INI, and CSV formats
"""

import yaml
import configparser
import csv
import json
import argparse
import sys
from pathlib import Path
from typing import List, Dict, Any


class InventoryParser:
    """Parse host inventory files in multiple formats"""
    
    def __init__(self, inventory_file: str):
        self.inventory_file = Path(inventory_file)
        self.hosts = []
        
    def parse(self) -> List[Dict[str, Any]]:
        """Parse inventory file based on extension"""
        if not self.inventory_file.exists():
            raise FileNotFoundError(f"Inventory file not found: {self.inventory_file}")
            
        extension = self.inventory_file.suffix.lower()
        
        if extension in ['.yaml', '.yml']:
            return self._parse_yaml()
        elif extension in ['.ini', '.cfg']:
            return self._parse_ini()
        elif extension == '.csv':
            return self._parse_csv()
        else:
            raise ValueError(f"Unsupported file format: {extension}")
    
    def _parse_yaml(self) -> List[Dict[str, Any]]:
        """Parse YAML inventory file"""
        with open(self.inventory_file, 'r') as f:
            data = yaml.safe_load(f)
        
        hosts = []
        
        # Handle different YAML structures
        if isinstance(data, dict):
            if 'hosts' in data:
                hosts_data = data['hosts']
            elif 'nodes' in data:
                hosts_data = data['nodes']
            else:
                # Assume the dict itself contains host info
                hosts_data = data
        elif isinstance(data, list):
            hosts_data = data
        else:
            raise ValueError("Invalid YAML structure")
        
        for host in hosts_data:
            if isinstance(host, dict):
                hosts.append(self._normalize_host(host))
            else:
                # Simple list of hostnames/IPs
                hosts.append(self._normalize_host({'hostname': host}))
        
        return hosts
    
    def _parse_ini(self) -> List[Dict[str, Any]]:
        """Parse INI inventory file"""
        config = configparser.ConfigParser()
        config.read(self.inventory_file)
        
        hosts = []
        
        for section_name in config.sections():
            section = config[section_name]
            host_info = {'hostname': section_name}
            
            # Map common INI keys to standard format
            key_mapping = {
                'ip': 'ip_address',
                'user': 'username',
                'port': 'ssh_port',
                'role': 'role',
                'group': 'group'
            }
            
            for key, value in section.items():
                mapped_key = key_mapping.get(key.lower(), key.lower())
                host_info[mapped_key] = value
            
            hosts.append(self._normalize_host(host_info))
        
        return hosts
    
    def _parse_csv(self) -> List[Dict[str, Any]]:
        """Parse CSV inventory file"""
        hosts = []
        
        with open(self.inventory_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                hosts.append(self._normalize_host(row))
        
        return hosts
    
    def _normalize_host(self, host_data: Dict[str, Any]) -> Dict[str, Any]:
        """Normalize host data to standard format"""
        normalized = {
            'hostname': '',
            'ip_address': '',
            'username': 'root',
            'ssh_port': 22,
            'role': 'worker',
            'group': 'default',
            'os': 'ubuntu',
            'os_version': '22.04'
        }
        
        # Map various possible keys to standard format
        key_mappings = {
            'hostname': ['hostname', 'host', 'name', 'fqdn'],
            'ip_address': ['ip_address', 'ip', 'address'],
            'username': ['username', 'user', 'login'],
            'ssh_port': ['ssh_port', 'port'],
            'role': ['role', 'type', 'node_type'],
            'group': ['group', 'cluster'],
            'os': ['os', 'operating_system'],
            'os_version': ['os_version', 'version']
        }
        
        for standard_key, possible_keys in key_mappings.items():
            for key in possible_keys:
                if key in host_data:
                    normalized[standard_key] = host_data[key]
                    break
        
        # Ensure we have either hostname or IP
        if not normalized['hostname'] and not normalized['ip_address']:
            raise ValueError("Host must have either hostname or IP address")
        
        # Use IP as hostname if hostname is missing
        if not normalized['hostname']:
            normalized['hostname'] = normalized['ip_address']
        
        return normalized
    
    def get_control_plane_nodes(self, count: int = 3) -> List[Dict[str, Any]]:
        """Get first N nodes as control plane nodes"""
        hosts = self.parse()
        control_plane = hosts[:count]
        
        # Update roles
        for host in control_plane:
            host['role'] = 'control-plane'
        
        return control_plane
    
    def get_worker_nodes(self, skip_first: int = 3) -> List[Dict[str, Any]]:
        """Get remaining nodes as worker nodes"""
        hosts = self.parse()
        workers = hosts[skip_first:]
        
        # Ensure all are marked as workers
        for host in workers:
            host['role'] = 'worker'
        
        return workers
    
    def get_all_nodes(self) -> List[Dict[str, Any]]:
        """Get all nodes with proper role assignment"""
        hosts = self.parse()
        
        # Assign roles: first 3 as control-plane, rest as workers
        for i, host in enumerate(hosts):
            if i < 3:
                host['role'] = 'control-plane'
            else:
                host['role'] = 'worker'
        
        return hosts


def main():
    """CLI interface for inventory parser"""
    parser = argparse.ArgumentParser(description='Parse Kubernetes cluster inventory files')
    parser.add_argument('inventory_file', help='Path to inventory file')
    parser.add_argument('--format', choices=['yaml', 'ini', 'csv'], 
                       help='Force specific format (auto-detected by default)')
    parser.add_argument('--output', choices=['json', 'yaml'], default='json',
                       help='Output format')
    parser.add_argument('--control-plane-count', type=int, default=3,
                       help='Number of control plane nodes')
    
    args = parser.parse_args()
    
    try:
        inventory = InventoryParser(args.inventory_file)
        nodes = inventory.get_all_nodes()
        
        if args.output == 'json':
            print(json.dumps(nodes, indent=2))
        else:
            print(yaml.dump(nodes, default_flow_style=False))
            
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()